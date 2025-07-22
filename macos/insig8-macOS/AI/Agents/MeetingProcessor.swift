import Foundation
import SwiftData
import Speech
import AVFoundation
import Combine
#if canImport(FoundationModels)
import FoundationModels
#endif

actor MeetingProcessor: ObservableObject {
    private let model: AILanguageModelSession?
    private let modelContainer: ModelContainer
    private let speechTranscriber: SpeechTranscriber
    private let audioCapture: AudioCaptureManager
    
    private var currentMeetingSession: MeetingSession?
    private var _isRecording = false
    private var cancellables = Set<AnyCancellable>()
    
    var isRecording: Bool {
        get { _isRecording }
        set { _isRecording = newValue }
    }
    
    // AI Prompts
    private let actionItemPrompt = """
    You are an AI assistant that extracts action items from meeting transcripts.
    
    Analyze the transcript and identify:
    1. Specific action items with clear owners
    2. Deadlines or timeframes
    3. Priority levels
    4. Dependencies between tasks
    
    Return a JSON array of action items with this format:
    {
        "actionItems": [
            {
                "description": "string",
                "assignee": "string or null",
                "dueDate": "ISO date string or null",
                "priority": "low|medium|high|urgent"
            }
        ]
    }
    
    Transcript to analyze:
    """
    
    private let summaryPrompt = """
    You are an AI assistant that creates concise meeting summaries.
    
    Create a summary including:
    1. Key decisions made
    2. Main discussion points
    3. Action items overview
    4. Next steps
    
    Keep it concise but comprehensive. Format as structured text.
    
    Transcript to summarize:
    """
    
    init(model: AILanguageModelSession?, container: ModelContainer) {
        self.model = model
        self.modelContainer = container
        self.speechTranscriber = SpeechTranscriber()
        self.audioCapture = AudioCaptureManager()
        
        Task {
            await setupNotifications()
        }
    }
    
    func startMeetingRecording() async throws {
        guard !_isRecording else {
            throw MeetingProcessorError.alreadyRecording
        }
        
        // Request microphone permission
        try await requestMicrophonePermission()
        
        // Create new meeting session
        currentMeetingSession = MeetingSession(
            title: "Meeting \(Date().formatted(date: .abbreviated, time: .shortened))",
            startTime: Date()
        )
        
        // Start audio capture
        try await audioCapture.startCapture()
        
        // Start real-time transcription
        try await speechTranscriber.startTranscription()
        
        _isRecording = true
        
        // Set up real-time processing
        setupRealTimeProcessing()
        
        print("Meeting recording started")
    }
    
    func stopMeetingRecording() async throws -> MeetingSession? {
        guard _isRecording, let meetingSession = currentMeetingSession else {
            throw MeetingProcessorError.notRecording
        }
        
        // Stop audio capture and transcription
        await audioCapture.stopCapture()
        await speechTranscriber.stopTranscription()
        
        // Update meeting session
        meetingSession.endTime = Date()
        meetingSession.transcript = speechTranscriber.getFullTranscript()
        
        // Generate summary and action items
        await processMeetingContent(meetingSession)
        
        // Save to database
        let context = ModelContext(modelContainer)
        context.insert(meetingSession)
        try context.save()
        
        // Reset state
        _isRecording = false
        currentMeetingSession = nil
        
        print("Meeting recording stopped and processed")
        return meetingSession
    }
    
    func transcribeAudio(_ audio: AudioData) async -> MeetingTranscript? {
        return await speechTranscriber.transcribe(audio)
    }
    
    func generateActionItems(_ transcript: String) async -> [ActionItem] {
        #if canImport(FoundationModels)
        if #available(macOS 15.1, *), let model = model as? LanguageModelSession {
            do {
                // Use Apple Intelligence with structured output
                let prompt = "Extract action items from this meeting transcript: \(transcript)"
                let extraction: ActionItemExtraction = try await model.generate(prompt: prompt)
                
                guard let meetingId = currentMeetingSession?.id else { return [] }
                
                var actionItems: [ActionItem] = []
                
                for itemData in extraction.actionItems {
                    let actionItem = ActionItem(
                        description: itemData.description,
                        assignee: itemData.assignee,
                        dueDate: parseDate(itemData.dueDate),
                        status: .open,
                        meetingId: meetingId,
                        priority: mapPriorityString(itemData.priority)
                    )
                    actionItems.append(actionItem)
                }
                
                return actionItems
            } catch {
                print("Failed to extract action items with Apple Intelligence: \(error)")
                return await generateActionItemsWithFallback(transcript)
            }
        } else {
            return await generateActionItemsWithFallback(transcript)
        }
        #else
        return await generateActionItemsWithFallback(transcript)
        #endif
    }
    
    private func generateActionItemsWithFallback(_ transcript: String) async -> [ActionItem] {
        do {
            let prompt = actionItemPrompt + transcript
            let response = try await model?.respond(to: prompt)
            
            if let response = response,
               let actionItemsData = parseActionItemsResponse(response.content),
               let meetingId = currentMeetingSession?.id {
                
                var actionItems: [ActionItem] = []
                
                for itemData in actionItemsData.actionItems {
                    let actionItem = ActionItem(
                        description: itemData.description,
                        assignee: itemData.assignee,
                        dueDate: parseDate(itemData.dueDate),
                        status: .open,
                        meetingId: meetingId,
                        priority: Priority(rawValue: itemData.priority.hashValue) ?? .medium
                    )
                    actionItems.append(actionItem)
                }
                
                return actionItems
            }
        } catch {
            print("Failed to generate action items: \(error)")
        }
        
        return []
    }
    
    func summarizeMeeting(_ transcript: String) async -> String {
        #if canImport(FoundationModels)
        if #available(macOS 15.1, *), let model = model as? LanguageModelSession {
            do {
                // Use Apple Intelligence with structured output
                let prompt = "Summarize this meeting transcript: \(transcript)"
                let summary: MeetingSummary = try await model.generate(prompt: prompt)
                
                return """
                **Key Decisions:**
                \(summary.keyDecisions.map { "• \($0)" }.joined(separator: "\n"))
                
                **Main Discussion Points:**
                \(summary.mainDiscussionPoints.map { "• \($0)" }.joined(separator: "\n"))
                
                **Next Steps:**
                \(summary.nextSteps.map { "• \($0)" }.joined(separator: "\n"))
                
                **Summary:**
                \(summary.overallSummary)
                """
            } catch {
                print("Failed to generate summary with Apple Intelligence: \(error)")
                return await summarizeMeetingWithFallback(transcript)
            }
        } else {
            return await summarizeMeetingWithFallback(transcript)
        }
        #else
        return await summarizeMeetingWithFallback(transcript)
        #endif
    }
    
    private func summarizeMeetingWithFallback(_ transcript: String) async -> String {
        do {
            let prompt = summaryPrompt + transcript
            let response = try await model?.respond(to: prompt)
            return response?.content ?? "Summary generation failed"
        } catch {
            print("Failed to generate meeting summary: \(error)")
            return "Summary generation failed"
        }
    }
    
    func getMeetingHistory(limit: Int = 10) -> [MeetingSession] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<MeetingSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        do {
            let meetings = try context.fetch(descriptor)
            return Array(meetings.prefix(limit))
        } catch {
            print("Failed to fetch meeting history: \(error)")
            return []
        }
    }
    
    func searchMeetings(query: String) async -> [MeetingSession] {
        // Use vector database for semantic search
        // This would be implemented with the vector database
        return []
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        // Listen for transcription updates
        speechTranscriber.transcriptionPublisher
            .sink { [weak self] transcript in
                Task {
                    await self?.processRealtimeTranscript(transcript)
                }
            }
            .store(in: &cancellables)
    }
    
    private func requestMicrophonePermission() async throws {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        switch status {
        case .authorized:
            break
        case .denied, .restricted, .notDetermined:
            throw MeetingProcessorError.microphonePermissionDenied
        @unknown default:
            throw MeetingProcessorError.microphonePermissionDenied
        }
        
        // On macOS, audio permission is handled by the system
        // No additional audio session permission needed
    }
    
    private func setupRealTimeProcessing() {
        // Set up timer for periodic processing during meeting
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await self.processIncrementalTranscript()
            }
        }
    }
    
    private func processRealtimeTranscript(_ transcript: String) async {
        guard let meetingSession = currentMeetingSession else { return }
        
        // Update the current transcript
        meetingSession.transcript = transcript
        
        // Detect speaker changes and important moments
        await detectImportantMoments(in: transcript)
    }
    
    private func processIncrementalTranscript() async {
        guard let meetingSession = currentMeetingSession else { return }
        
        let currentTranscript = speechTranscriber.getFullTranscript()
        
        // Process new content for action items
        if currentTranscript.count > meetingSession.transcript.count + 100 {
            let newContent = String(currentTranscript.suffix(currentTranscript.count - meetingSession.transcript.count))
            let newActionItems = await generateActionItems(newContent)
            meetingSession.actionItems.append(contentsOf: newActionItems)
        }
    }
    
    private func processMeetingContent(_ meetingSession: MeetingSession) async {
        let transcript = meetingSession.transcript
        
        // Generate summary
        let summary = await summarizeMeeting(transcript)
        meetingSession.summary = summary
        
        // Generate action items
        let actionItems = await generateActionItems(transcript)
        meetingSession.actionItems = actionItems
        
        // Generate embedding for vector search
        let embeddingText = "\(meetingSession.title) \(summary) \(transcript)"
        meetingSession.embedding = await generateEmbedding(for: embeddingText)
        
        // Extract participants (simplified)
        meetingSession.participants = extractParticipants(from: transcript)
    }
    
    private func detectImportantMoments(in transcript: String) async {
        // Detect key phrases that indicate important moments
        let importantPhrases = [
            "action item", "todo", "follow up", "deadline",
            "decision", "agree", "next steps", "assign"
        ]
        
        let lowercaseTranscript = transcript.lowercased()
        
        for phrase in importantPhrases {
            if lowercaseTranscript.contains(phrase) {
                // Could trigger real-time notifications or highlights
                print("Important moment detected: \(phrase)")
            }
        }
    }
    
    private func extractParticipants(from transcript: String) -> [String] {
        // Simple participant extraction
        // In a real implementation, this would use speaker diarization
        
        var participants = Set<String>()
        let lines = transcript.components(separatedBy: .newlines)
        
        for line in lines {
            // Look for speaker patterns like "Speaker 1:", "John:", etc.
            if let colonIndex = line.firstIndex(of: ":") {
                let speaker = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                if !speaker.isEmpty && speaker.count < 50 {
                    participants.insert(speaker)
                }
            }
        }
        
        return Array(participants)
    }
    
    private func generateEmbedding(for text: String) async -> [Float] {
        let embeddingGenerator = EmbeddingGenerator()
        return await embeddingGenerator.generateEmbedding(for: text)
    }
    
    private func parseActionItemsResponse(_ response: String) -> ActionItemsResponse? {
        guard let data = response.data(using: .utf8) else { return nil }
        
        do {
            return try JSONDecoder().decode(ActionItemsResponse.self, from: data)
        } catch {
            print("Failed to parse action items response: \(error)")
            return nil
        }
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    private func mapPriorityString(_ priority: String) -> Priority {
        switch priority.lowercased() {
        case "urgent":
            return .urgent
        case "high":
            return .high
        case "medium":
            return .medium
        case "low":
            return .low
        default:
            return .medium
        }
    }
}

// MARK: - Enhanced Speech Transcriber with Native Features

class SpeechTranscriber: ObservableObject {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    private var fullTranscript = ""
    private var speakerSegments: [SpeakerSegment] = []
    private var currentSpeaker: String?
    private let transcriptionSubject = PassthroughSubject<String, Never>()
    private let speakerChangeSubject = PassthroughSubject<SpeakerSegment, Never>()
    
    // Audio analysis for speaker detection
    private var lastAudioLevel: Float = 0.0
    private var speechPauseThreshold: TimeInterval = 2.0
    private var lastSpeechTime: Date = Date()
    
    var transcriptionPublisher: AnyPublisher<String, Never> {
        transcriptionSubject.eraseToAnyPublisher()
    }
    
    var speakerChangePublisher: AnyPublisher<SpeakerSegment, Never> {
        speakerChangeSubject.eraseToAnyPublisher()
    }
    
    init() {
        // Auto-detect user's language preference
        let preferredLanguage = Locale.preferredLanguages.first ?? "en-US"
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: preferredLanguage))
        speechRecognizer?.defaultTaskHint = .dictation
        
        print("Speech recognition configured for language: \(preferredLanguage)")
    }
    
    func startTranscription() async throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw MeetingProcessorError.speechRecognitionUnavailable
        }
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Create enhanced recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw MeetingProcessorError.recognitionRequestFailed
        }
        
        // Enhanced Speech framework configuration
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        
        // Enable on-device recognition for privacy (macOS 13+)
        if #available(macOS 13, *) {
            // Note: requiresOnDeviceRecognization is not available in current SDK
            // recognitionRequest.requiresOnDeviceRecognization = true
            // recognitionRequest.addsPunctuation = true
        }
        
        // Enhanced audio configuration for better quality
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install audio tap with enhanced buffer processing
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, when in
            // Analyze audio levels for speaker detection
            self?.analyzeAudioBuffer(buffer, timestamp: when.sampleTime)
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start enhanced recognition with confidence scoring
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let bestTranscription = result.bestTranscription
                let transcript = bestTranscription.formattedString
                
                // Process with confidence scoring
                self.processTranscriptionResult(result)
                
                // Update full transcript
                self.fullTranscript = transcript
                self.transcriptionSubject.send(transcript)
                
                // Detect speaker changes based on transcription patterns
                self.detectSpeakerChanges(from: bestTranscription)
            }
            
            if let error = error {
                print("Speech recognition error: \(error)")
            }
        }
        
        print("✅ Enhanced speech recognition started with native Speech framework")
    }
    
    func stopTranscription() async {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // On macOS, no need to deactivate audio session
    }
    
    func transcribe(_ audio: AudioData) async -> MeetingTranscript? {
        // Convert AudioData to transcript
        // This would use SFSpeechRecognizer for one-shot transcription
        return nil
    }
    
    func getFullTranscript() -> String {
        return fullTranscript
    }
    
    func getSpeakerSegments() -> [SpeakerSegment] {
        return speakerSegments
    }
    
    // MARK: - Enhanced Native Speech Processing
    
    private func analyzeAudioBuffer(_ buffer: AVAudioPCMBuffer, timestamp: AVAudioFramePosition) {
        // Analyze audio levels for speaker change detection
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        var sum: Float = 0.0
        let frameCount = Int(buffer.frameLength)
        
        for i in 0..<frameCount {
            sum += abs(channelData[i])
        }
        
        let averageLevel = sum / Float(frameCount)
        
        // Detect significant audio level changes (potential speaker change)
        if abs(averageLevel - lastAudioLevel) > 0.1 {
            lastSpeechTime = Date()
            lastAudioLevel = averageLevel
        }
    }
    
    private func processTranscriptionResult(_ result: SFSpeechRecognitionResult) {
        let transcription = result.bestTranscription
        
        // Log confidence scores for quality assessment
        let segments = transcription.segments
        var lowConfidenceCount = 0
        var totalConfidence: Float = 0.0
        
        for segment in segments {
            totalConfidence += segment.confidence
            if segment.confidence < 0.5 {
                lowConfidenceCount += 1
            }
        }
        
        let averageConfidence = totalConfidence / Float(segments.count)
        
        if averageConfidence < 0.7 {
            print("⚠️ Low transcription confidence: \(averageConfidence)")
        }
        
        // Log segments with very low confidence for debugging
        if lowConfidenceCount > segments.count / 2 {
            print("⚠️ Many low-confidence segments detected - consider improving audio quality")
        }
    }
    
    private func detectSpeakerChanges(from transcription: SFTranscription) {
        let currentTime = Date()
        let segments = transcription.segments
        
        // Simple speaker change detection based on pause patterns
        for segment in segments {
            // If there's a significant pause, assume potential speaker change
            if segment.timestamp > speechPauseThreshold {
                let newSpeaker = identifySpeaker(from: segment)
                
                if newSpeaker != currentSpeaker {
                    let speakerSegment = SpeakerSegment(
                        speaker: newSpeaker,
                        text: segment.substring,
                        startTime: currentTime.addingTimeInterval(-segment.duration),
                        endTime: currentTime,
                        confidence: segment.confidence
                    )
                    
                    speakerSegments.append(speakerSegment)
                    speakerChangeSubject.send(speakerSegment)
                    currentSpeaker = newSpeaker
                }
            }
        }
    }
    
    private func identifySpeaker(from segment: SFTranscriptionSegment) -> String {
        // Simple speaker identification based on audio characteristics
        // In a real implementation, this could use voice characteristics analysis
        let confidence = segment.confidence
        let audioLevel = lastAudioLevel
        
        // Basic heuristic: assign speakers based on confidence and audio level patterns
        if confidence > 0.8 && audioLevel > 0.5 {
            return "Speaker 1"
        } else if confidence > 0.6 {
            return "Speaker 2"
        } else {
            return "Unknown Speaker"
        }
    }
}

// MARK: - Audio Capture Manager

class AudioCaptureManager {
    private var audioRecorder: AVAudioRecorder?
    private var isCapturing = false
    
    func startCapture() async throws {
        guard !isCapturing else { return }
        
        // On macOS, AVAudioRecorder works without AVAudioSession setup
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("meeting_\(Date().timeIntervalSince1970).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
        audioRecorder?.record()
        
        isCapturing = true
    }
    
    func stopCapture() async {
        audioRecorder?.stop()
        audioRecorder = nil
        isCapturing = false
    }
}

// MARK: - Supporting Types

struct ActionItemsResponse: Codable {
    let actionItems: [ActionItemData]
}

// ActionItemData defined in AISharedTypes.swift

// MARK: - Enhanced Speech Processing Types

struct SpeakerSegment {
    let speaker: String
    let text: String
    let startTime: Date
    let endTime: Date
    let confidence: Float
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
}

enum MeetingProcessorError: Error, LocalizedError {
    case alreadyRecording
    case notRecording
    case microphonePermissionDenied
    case speechRecognitionUnavailable
    case recognitionRequestFailed
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Meeting recording is already in progress"
        case .notRecording:
            return "No meeting recording is currently active"
        case .microphonePermissionDenied:
            return "Microphone permission is required for meeting recording"
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available"
        case .recognitionRequestFailed:
            return "Failed to create speech recognition request"
        }
    }
}