import Foundation
import Vision
import SwiftData
import Combine

// Screen Capture Compatibility - Mock implementation for now
class SCCaptureEngine {
    // Empty mock implementation
}

class SCCaptureStream {
    // Empty mock implementation  
}

class SCCaptureScreenshot {
    let surface: MockSurface = MockSurface()
}

class MockSurface {
    let data: Data = Data()
}

@Observable
class ScreenMonitor: ObservableObject {
    private var captureEngine: SCCaptureEngine?
    private var stream: SCCaptureStream?
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
        
        // Set up capture engine
        try await setupCaptureEngine()
        
        // Start periodic screen capture
        startPeriodicCapture()
        
        isMonitoring = true
        print("Screen monitoring started")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        captureTimer?.invalidate()
        captureTimer = nil
        
        Task {
            await stopCaptureEngine()
        }
        
        isMonitoring = false
        print("Screen monitoring stopped")
    }
    
    func captureCurrentScreen() async -> ScreenCapture? {
        guard let captureEngine = captureEngine else {
            print("Capture engine not initialized")
            return nil
        }
        
        do {
            // Get available displays
            let availableContent = try await SCShareableContent.current
            guard let display = availableContent.displays.first else {
                print("No displays available for capture")
                return nil
            }
            
            // Create filter for the display
            let filter = SCContentFilter(display: display, excludingWindows: [])
            
            // Configure capture
            let configuration = SCCaptureConfiguration()
            configuration.width = Int(display.width)
            configuration.height = Int(display.height)
            configuration.pixelFormat = kCVPixelFormatType_32BGRA
            configuration.showsCursor = false
            
            // Capture screenshot
            let sample = try await captureEngine.captureSingleFrame(contentFilter: filter, configuration: configuration)
            
            // Convert to image data
            guard let imageData = extractImageData(from: sample) else {
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
    
    private func setupCaptureEngine() async throws {
        self.captureEngine = SCCaptureEngine()
    }
    
    private func stopCaptureEngine() async {
        stream = nil
        captureEngine = nil
    }
    
    private func startPeriodicCapture() {
        captureTimer = Timer.scheduledTimer(withTimeInterval: captureInterval, repeats: true) { _ in
            Task {
                await self.captureCurrentScreen()
            }
        }
    }
    
    private func extractImageData(from sample: SCCaptureScreenshot) -> Data? {
        // Convert SCCaptureScreenshot to Data
        // This is a simplified implementation
        return sample.surface.data
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

// MARK: - OCR Processor

class OCRProcessor {
    func extractText(from imageData: Data) async -> String {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ""
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("OCR error: \(error)")
                    continuation.resume(returning: "")
                    return
                }
                
                let recognizedText = request.results?.compactMap { result in
                    (result as? VNRecognizedTextObservation)?.topCandidates(1).first?.string
                }.joined(separator: " ") ?? ""
                
                continuation.resume(returning: recognizedText)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform OCR: \(error)")
                continuation.resume(returning: "")
            }
        }
    }
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

import CommonCrypto