import Foundation
import Vision
import SwiftData
import Combine
import CommonCrypto
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif

@Observable
class ScreenMonitor: ObservableObject {
    private let commitmentTracker: CommitmentTracker
    private let vectorDB: VectorDatabase
    private let ocrProcessor: OCRProcessor
    private let contextAnalyzer: ContextAnalyzer
    
    private var cancellables = Set<AnyCancellable>()
    private var isMonitoring = false
    private var lastCaptureHash: String = ""
    private let captureInterval: TimeInterval = 5.0 // Capture every 5 seconds
    
    // Configuration
    private let maxMemoryUsage = 100_000_000 // 100MB for screen monitoring
    private var captureTimer: Timer?
    
    init(commitmentTracker: CommitmentTracker, vectorDB: VectorDatabase) {
        self.commitmentTracker = commitmentTracker
        self.vectorDB = vectorDB
        self.ocrProcessor = OCRProcessor()
        self.contextAnalyzer = ContextAnalyzer()
    }
    
    func startMonitoring() async throws {
        guard !isMonitoring else { return }
        
        // Request screen recording permission
        try await requestScreenCapturePermission()
        
        // Start periodic screen capture
        startPeriodicCapture()
        
        isMonitoring = true
        print("Screen monitoring started")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        captureTimer?.invalidate()
        captureTimer = nil
        
        isMonitoring = false
        print("Screen monitoring stopped")
    }
    
    func captureCurrentScreen() async -> ScreenCapture? {
#if canImport(ScreenCaptureKit) && os(macOS)
        if #available(macOS 12.3, *) {
            do {
                // Get available displays
                let availableContent = try await SCShareableContent.current
                guard let display = availableContent.displays.first else {
                    print("No displays available for capture")
                    return nil
                }
                
                // Create filter for the display
                let filter = SCContentFilter(display: display, excludingWindows: [])
                
                // Configure capture settings
                let configuration = SCStreamConfiguration()
                configuration.width = Int(display.width)
                configuration.height = Int(display.height)
                configuration.pixelFormat = kCVPixelFormatType_32BGRA
                configuration.showsCursor = false
                
                // Use SCScreenshotManager for single frame capture
                let screenshot = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: configuration
                )
            
            // Convert to image data
            guard let imageData = extractImageData(from: screenshot) else {
                print("Failed to extract image data")
                return nil
            }
            
            // Check if screen has changed significantly
            let currentHash = imageData.sha256
            if currentHash == lastCaptureHash {
                return nil // No significant change
            }
            lastCaptureHash = currentHash
            
            // Extract text using OCR
            let extractedText = await ocrProcessor.extractText(from: imageData)
            
            // Detect current application
            let detectedApp = getCurrentApplication()
            
            // Analyze context
            let context = await contextAnalyzer.analyzeScreen(
                text: extractedText,
                app: detectedApp,
                timestamp: Date()
            )
            
            // Create screen capture record
            let screenCapture = ScreenCapture(
                imageData: imageData,
                extractedText: extractedText,
                detectedApp: detectedApp,
                context: context
            )
            
            // Generate embedding for searchability
            screenCapture.embedding = await generateEmbedding(for: extractedText)
            
            // Store in vector database
            try await vectorDB.store(screenCapture)
            
            // Analyze for unresponded messages
            await analyzeForUnrespondedMessages(screenCapture)
            
            return screenCapture
            
        } catch {
            print("Failed to capture screen: \(error)")
            return nil
        }
        } else {
            print("ScreenCaptureKit not available on this macOS version")
            return nil
        }
#else
        print("ScreenCaptureKit not available")
        return nil
#endif
    }
    
    func detectUnrespondedMessages() async -> [UnrespondedMessage] {
        // This method analyzes recent screen captures to find unresponded messages
        // Implementation would search for message patterns and check if user has responded
        
        let recentCaptures = await getRecentScreenCaptures(timeWindow: 3600) // Last hour
        var unrespondedMessages: [UnrespondedMessage] = []
        
        for capture in recentCaptures {
            let messages = await contextAnalyzer.detectMessages(in: capture.extractedText, app: capture.detectedApp)
            
            for message in messages {
                if await isMessageUnresponded(message, in: capture) {
                    let unresponsed = UnrespondedMessage(
                        id: UUID(),
                        sender: message.sender,
                        platform: capture.detectedApp,
                        content: message.content,
                        timestamp: message.timestamp,
                        expiryHours: calculateExpiryHours(for: message)
                    )
                    unrespondedMessages.append(unresponsed)
                }
            }
        }
        
        return unrespondedMessages
    }
    
    // MARK: - Private Methods
    
    private func requestScreenCapturePermission() async throws {
        let availableContent = try await SCShareableContent.current
        
        // This will trigger the permission request
        guard !availableContent.displays.isEmpty else {
            throw ScreenMonitorError.noDisplaysAvailable
        }
        
        // Check if we have screen recording permission
        if !hasScreenRecordingPermission() {
            throw ScreenMonitorError.permissionDenied
        }
    }
    
    private func hasScreenRecordingPermission() -> Bool {
        // Check screen recording permission
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
    }
    
    
    private func startPeriodicCapture() {
        captureTimer = Timer.scheduledTimer(withTimeInterval: captureInterval, repeats: true) { _ in
            Task {
                await self.captureCurrentScreen()
            }
        }
    }
    
    private func extractImageData(from screenshot: CGImage) -> Data? {
        // Convert CGImage to Data
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        
        CGImageDestinationAddImage(destination, screenshot, nil)
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data
    }
    
    private func getCurrentApplication() -> String {
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            return frontmostApp.localizedName ?? frontmostApp.bundleIdentifier ?? "Unknown"
        }
        return "Unknown"
    }
    
    private func generateEmbedding(for text: String) async -> [Float] {
        // Use the vector database's embedding generator
        let embeddingGenerator = EmbeddingGenerator()
        return await embeddingGenerator.generateEmbedding(for: text)
    }
    
    private func analyzeForUnrespondedMessages(_ capture: ScreenCapture) async {
        let detectedMessages = await contextAnalyzer.detectMessages(
            in: capture.extractedText,
            app: capture.detectedApp
        )
        
        for message in detectedMessages {
            if message.isQuestionOrRequest {
                // Create a commitment if this looks like something that needs a response
                let messageContext = MessageContext(
                    platform: capture.detectedApp,
                    sender: message.sender,
                    timestamp: message.timestamp,
                    threadId: nil
                )
                
                await commitmentTracker.analyzeMessage(
                    "Respond to \(message.sender): \(message.content)",
                    context: messageContext
                )
            }
        }
    }
    
    private func getRecentScreenCaptures(timeWindow: TimeInterval) async -> [ScreenCapture] {
        // This would fetch recent screen captures from the database
        // Simplified implementation
        return []
    }
    
    private func isMessageUnresponded(_ message: DetectedMessage, in capture: ScreenCapture) async -> Bool {
        // Check if the user has responded to this message
        // This would involve analyzing subsequent screen captures or outgoing messages
        
        // For now, consider any question/request as potentially unresponded
        return message.isQuestionOrRequest && message.timestamp.timeIntervalSinceNow > -3600 // Within last hour
    }
    
    private func calculateExpiryHours(for message: DetectedMessage) -> Double {
        // Calculate appropriate expiry time based on message urgency and context
        switch message.urgency {
        case .urgent:
            return 1.0
        case .high:
            return 4.0
        case .medium:
            return 24.0
        case .low:
            return 72.0
        }
    }
}

// MARK: - Enhanced OCR Processor with Advanced Vision Features

class OCRProcessor {
    @available(macOS 13.0, *)
    private var documentTextRequest: VNRecognizeTextRequest?
    private var rectangleDetector: VNDetectRectanglesRequest?
    
    init() {
        setupAdvancedVisionRequests()
    }
    
    func extractText(from imageData: Data) async -> String {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ""
        }
        
        return await performEnhancedOCR(on: cgImage)
    }
    
    func extractDocumentText(from imageData: Data) async -> DocumentOCRResult {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return DocumentOCRResult(text: "", confidence: 0.0, layoutInfo: [])
        }
        
        return await performDocumentOCR(on: cgImage)
    }
    
    func detectTextRectangles(from imageData: Data) async -> [TextRectangle] {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }
        
        return await detectTextRegions(in: cgImage)
    }
    
    // MARK: - Private Enhanced Vision Methods
    
    private func setupAdvancedVisionRequests() {
        // Set up document text recognition for better structured text extraction
        if #available(macOS 13.0, *) {
            documentTextRequest = VNRecognizeTextRequest()
            documentTextRequest?.recognitionLevel = .accurate
            documentTextRequest?.usesLanguageCorrection = true
            documentTextRequest?.automaticallyDetectsLanguage = true
        }
        
        // Set up rectangle detection for UI elements
        rectangleDetector = VNDetectRectanglesRequest()
        rectangleDetector?.minimumAspectRatio = 0.1
        rectangleDetector?.maximumAspectRatio = 10.0
        rectangleDetector?.minimumSize = 0.01
        rectangleDetector?.maximumObservations = 50
    }
    
    private func performEnhancedOCR(on cgImage: CGImage) async -> String {
        return await withCheckedContinuation { continuation in
            // Use multiple recognition strategies for better accuracy
            var allText: [String] = []
            let group = DispatchGroup()
            
            // Strategy 1: Standard text recognition
            group.enter()
            performStandardTextRecognition(on: cgImage) { text in
                allText.append(text)
                group.leave()
            }
            
            // Strategy 2: Document text recognition (macOS 13+)
            if #available(macOS 13.0, *) {
                group.enter()
                performDocumentTextRecognition(on: cgImage) { text in
                    allText.append(text)
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                // Combine results and remove duplicates
                let combinedText = allText.joined(separator: " ")
                let cleanedText = self.removeDuplicateText(combinedText)
                continuation.resume(returning: cleanedText)
            }
        }
    }
    
    private func performStandardTextRecognition(on cgImage: CGImage, completion: @escaping (String) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("Standard OCR error: \(error)")
                completion("")
                return
            }
            
            let recognizedText = request.results?.compactMap { result in
                guard let observation = result as? VNRecognizedTextObservation else { return nil }
                return observation.topCandidates(1).first?.string
            }.joined(separator: " ") ?? ""
            
            completion(recognizedText)
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // Enhanced recognition options
        request.recognitionLanguages = ["en-US", "en-GB"] // Add more as needed
        request.customWords = ["Slack", "Teams", "Discord", "Zoom"] // App-specific vocabulary
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform standard OCR: \(error)")
            completion("")
        }
    }
    
    @available(macOS 13.0, *)
    private func performDocumentTextRecognition(on cgImage: CGImage, completion: @escaping (String) -> Void) {
        guard let documentRequest = documentTextRequest else {
            completion("")
            return
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([documentRequest])
            
            let recognizedText = documentRequest.results?.compactMap { result in
                guard let observation = result as? VNRecognizedTextObservation else { return nil }
                return observation.topCandidates(1).first?.string
            }.joined(separator: " ") ?? ""
            
            completion(recognizedText)
        } catch {
            print("Failed to perform document OCR: \(error)")
            completion("")
        }
    }
    
    private func performDocumentOCR(on cgImage: CGImage) async -> DocumentOCRResult {
        return await withCheckedContinuation { continuation in
            guard #available(macOS 13.0, *),
                  let documentRequest = documentTextRequest else {
                continuation.resume(returning: DocumentOCRResult(text: "", confidence: 0.0, layoutInfo: []))
                return
            }
            
            documentRequest.completionHandler = { request, error in
                if let error = error {
                    print("Document OCR error: \(error)")
                    continuation.resume(returning: DocumentOCRResult(text: "", confidence: 0.0, layoutInfo: []))
                    return
                }
                
                var layoutInfo: [TextLayoutInfo] = []
                var allText: [String] = []
                var totalConfidence: Float = 0.0
                var observationCount = 0
                
                for result in request.results ?? [] {
                    guard let observation = result as? VNRecognizedTextObservation else { continue }
                    
                    if let topCandidate = observation.topCandidates(1).first {
                        allText.append(topCandidate.string)
                        totalConfidence += topCandidate.confidence
                        observationCount += 1
                        
                        let layoutElement = TextLayoutInfo(
                            text: topCandidate.string,
                            boundingBox: observation.boundingBox,
                            confidence: topCandidate.confidence
                        )
                        layoutInfo.append(layoutElement)
                    }
                }
                
                let averageConfidence = observationCount > 0 ? totalConfidence / Float(observationCount) : 0.0
                let combinedText = allText.joined(separator: " ")
                
                let result = DocumentOCRResult(
                    text: combinedText,
                    confidence: averageConfidence,
                    layoutInfo: layoutInfo
                )
                
                continuation.resume(returning: result)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([documentRequest])
            } catch {
                print("Failed to perform document OCR: \(error)")
                continuation.resume(returning: DocumentOCRResult(text: "", confidence: 0.0, layoutInfo: []))
            }
        }
    }
    
    private func detectTextRegions(in cgImage: CGImage) async -> [TextRectangle] {
        return await withCheckedContinuation { continuation in
            let request = VNDetectTextRectanglesRequest { request, error in
                if let error = error {
                    print("Text rectangle detection error: \(error)")
                    continuation.resume(returning: [])
                    return
                }
                
                let rectangles = request.results?.compactMap { result in
                    guard let observation = result as? VNTextObservation else { return nil }
                    
                    return TextRectangle(
                        boundingBox: observation.boundingBox,
                        confidence: observation.confidence
                    )
                } ?? []
                
                continuation.resume(returning: rectangles)
            }
            
            request.reportCharacterBoxes = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                print("Failed to detect text rectangles: \(error)")
                continuation.resume(returning: [])
            }
        }
    }
    
    private func removeDuplicateText(_ text: String) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let uniqueWords = Array(Set(words))
        return uniqueWords.joined(separator: " ")
    }
}

// MARK: - Enhanced OCR Types

struct DocumentOCRResult {
    let text: String
    let confidence: Float
    let layoutInfo: [TextLayoutInfo]
}

struct TextLayoutInfo {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
}

struct TextRectangle {
    let boundingBox: CGRect
    let confidence: Float
}

// MARK: - Context Analyzer

class ContextAnalyzer {
    func analyzeScreen(text: String, app: String, timestamp: Date) async -> ScreenContext {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let visibleText = Array(words.prefix(100)) // Limit to first 100 words
        
        let detectedElements = detectUIElements(in: text, app: app)
        
        return ScreenContext(
            activeWindow: app,
            visibleText: visibleText,
            detectedElements: detectedElements,
            timeSpent: 0, // Would be calculated based on continuous monitoring
            userInteraction: false // Would be detected through additional monitoring
        )
    }
    
    func detectMessages(in text: String, app: String) async -> [DetectedMessage] {
        var messages: [DetectedMessage] = []
        
        // Simple message detection patterns for different apps
        switch app.lowercased() {
        case let appName where appName.contains("slack"):
            messages.append(contentsOf: detectSlackMessages(in: text))
        case let appName where appName.contains("teams"):
            messages.append(contentsOf: detectTeamsMessages(in: text))
        case let appName where appName.contains("mail"):
            messages.append(contentsOf: detectEmailMessages(in: text))
        default:
            break
        }
        
        return messages
    }
    
    private func detectUIElements(in text: String, app: String) -> [String] {
        var elements: [String] = []
        
        // Detect common UI elements
        let patterns = [
            "Send", "Reply", "Forward", "Delete",
            "Save", "Cancel", "OK", "Submit",
            "Message", "Chat", "Email", "Call"
        ]
        
        for pattern in patterns {
            if text.localizedCaseInsensitiveContains(pattern) {
                elements.append(pattern)
            }
        }
        
        return elements
    }
    
    private func detectSlackMessages(in text: String) -> [DetectedMessage] {
        // Simplified Slack message detection
        // In a real implementation, this would use more sophisticated parsing
        
        let lines = text.components(separatedBy: .newlines)
        var messages: [DetectedMessage] = []
        
        for line in lines {
            if let message = parseSlackLine(line) {
                messages.append(message)
            }
        }
        
        return messages
    }
    
    private func detectTeamsMessages(in text: String) -> [DetectedMessage] {
        // Similar to Slack but adapted for Teams UI patterns
        return []
    }
    
    private func detectEmailMessages(in text: String) -> [DetectedMessage] {
        // Email-specific message detection
        return []
    }
    
    private func parseSlackLine(_ line: String) -> DetectedMessage? {
        // Simple pattern matching for Slack messages
        // Format: "Username: Message content"
        
        let components = line.components(separatedBy: ": ")
        guard components.count >= 2 else { return nil }
        
        let sender = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let content = components[1...].joined(separator: ": ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        let isQuestion = content.contains("?") || content.lowercased().contains("can you") || content.lowercased().contains("could you")
        let urgency = determineUrgency(from: content)
        
        return DetectedMessage(
            id: UUID(),
            sender: sender,
            content: content,
            timestamp: Date(),
            isQuestionOrRequest: isQuestion,
            urgency: urgency
        )
    }
    
    private func determineUrgency(from content: String) -> MessageUrgency {
        let lowercaseContent = content.lowercased()
        
        if lowercaseContent.contains("urgent") || lowercaseContent.contains("asap") || lowercaseContent.contains("immediately") {
            return .urgent
        } else if lowercaseContent.contains("important") || lowercaseContent.contains("priority") {
            return .high
        } else if lowercaseContent.contains("when you can") || lowercaseContent.contains("no rush") {
            return .low
        } else {
            return .medium
        }
    }
}

// MARK: - Supporting Types

struct DetectedMessage {
    let id: UUID
    let sender: String
    let content: String
    let timestamp: Date
    let isQuestionOrRequest: Bool
    let urgency: MessageUrgency
}

struct UnrespondedMessage {
    let id: UUID
    let sender: String
    let platform: String
    let content: String
    let timestamp: Date
    let expiryHours: Double
}

enum MessageUrgency: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
}

enum ScreenMonitorError: Error, LocalizedError {
    case permissionDenied
    case noDisplaysAvailable
    case captureEngineInitFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission is required"
        case .noDisplaysAvailable:
            return "No displays available for screen capture"
        case .captureEngineInitFailed:
            return "Failed to initialize screen capture engine"
        }
    }
}

// MARK: - Data Extension

extension Data {
    var sha256: String {
        let digest = withUnsafeBytes { bytes in
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256(bytes.bindMemory(to: UInt8.self).baseAddress, CC_LONG(count), &digest)
            return digest
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

