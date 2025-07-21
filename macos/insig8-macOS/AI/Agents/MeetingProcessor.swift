import Foundation
import SwiftData
import Speech
import AVFoundation
import Combine

// AI Compatibility - Mock implementation for now
class AILanguageModelSession {
    func respond(to prompt: String) async throws -> AIResponse {
        throw AIError.serviceOffline
    }
}

struct AIResponse {
    let content: String
}

enum AIError: Error {
    case serviceOffline
    case modelNotAvailable
    case processingFailed
    
    var localizedDescription: String {
        switch self {
        case .serviceOffline:
            return "On device agent offline"
        case .modelNotAvailable:
            return "AI model not available"
        case .processingFailed:
            return "AI processing failed"
        }
    }
}

@Observable
class MeetingProcessor: ObservableObject {
    private let model: AILanguageModelSession
    private let modelContainer: ModelContainer
    private let speechTranscriber: SpeechTranscriber
    private let audioCapture: AudioCaptureManager
    
    private var currentMeetingSession: MeetingSession?
    private var isRecording = false
    private var cancellables = Set<AnyCancellable>()
    
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
    
    init(model: AILanguageModelSession, container: ModelContainer) {
        self.model = model
        self.modelContainer = container
        self.speechTranscriber = SpeechTranscriber()
        self.audioCapture = AudioCaptureManager()
        
        setupNotifications()
    }
    
    func startMeetingRecording() async throws {
        guard !isRecording else {
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
        
        isRecording = true
        
        // Set up real-time processing
        setupRealTimeProcessing()
        
        print("Meeting recording started")
    }
    
    func stopMeetingRecording() async throws -> MeetingSession? {
        guard isRecording, let meetingSession = currentMeetingSession else {
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
        isRecording = false
        currentMeetingSession = nil
        
        print("Meeting recording stopped and processed")
        return meetingSession
    }
    
    func transcribeAudio(_ audio: AudioData) async -> MeetingTranscript? {
        return await speechTranscriber.transcribe(audio)
    }
    
    func generateActionItems(_ transcript: String) async -> [ActionItem] {
        do {
            let prompt = actionItemPrompt + transcript
            let response = try await model.respond(to: prompt)
            
            if let actionItemsData = parseActionItemsResponse(response.content),
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
        do {
            let prompt = summaryPrompt + transcript
            let response = try await model.respond(to: prompt)
            return response.content
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
        let status = await SFSpeechRecognizer.requestAuthorization()
        
        switch status {
        case .authorized:
            break
        case .denied, .restricted, .notDetermined:
            throw MeetingProcessorError.microphonePermissionDenied
        @unknown default:
            throw MeetingProcessorError.microphonePermissionDenied
        }
        
        // Also request AVAudioSession permission
        let audioPermission = await AVAudioSession.sharedInstance().requestRecordPermission()
        if !audioPermission {
            throw MeetingProcessorError.microphonePermissionDenied
        }
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
}

// MARK: - Speech Transcriber

class SpeechTranscriber: ObservableObject {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    private var fullTranscript = ""
    private let transcriptionSubject = PassthroughSubject<String, Never>()
    
    var transcriptionPublisher: AnyPublisher<String, Never> {
        transcriptionSubject.eraseToAnyPublisher()
    }
    
    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.defaultTaskHint = .dictation
    }
    
    func startTranscription() async throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw MeetingProcessorError.speechRecognitionUnavailable
        }
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw MeetingProcessorError.recognitionRequestFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        if #available(macOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        // Set up audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                let transcript = result.bestTranscription.formattedString
                self?.fullTranscript = transcript
                self?.transcriptionSubject.send(transcript)
            }
            
            if let error = error {
                print("Speech recognition error: \(error)")
            }
        }
    }
    
    func stopTranscription() async {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    func transcribe(_ audio: AudioData) async -> MeetingTranscript? {
        // Convert AudioData to transcript
        // This would use SFSpeechRecognizer for one-shot transcription
        return nil
    }
    
    func getFullTranscript() -> String {
        return fullTranscript
    }
}

// MARK: - Audio Capture Manager

class AudioCaptureManager {
    private var audioRecorder: AVAudioRecorder?
    private var isCapturing = false
    
    func startCapture() async throws {
        guard !isCapturing else { return }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [])
        try audioSession.setActive(true)
        
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
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

// MARK: - Supporting Types

struct ActionItemsResponse: Codable {
    let actionItems: [ActionItemData]
}

struct ActionItemData: Codable {
    let description: String
    let assignee: String?
    let dueDate: String?
    let priority: String
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