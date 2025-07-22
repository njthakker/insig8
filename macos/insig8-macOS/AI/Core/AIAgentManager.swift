import Foundation
import SwiftData
import SwiftUI
import Combine
import Speech
import NaturalLanguage
import CoreML

// Import Apple Intelligence if available
#if canImport(FoundationModels)
import FoundationModels
#endif

@Observable
@MainActor
class AIAgentManager: ObservableObject {
    private var foundationModel: AILanguageModelSession?
    private var commitmentTracker: CommitmentTracker?
    private var meetingProcessor: MeetingProcessor?
    private var searchEngine: IntelligentSearchEngine?
    private var screenMonitor: ScreenMonitor?
    private var vectorDatabase: VectorDatabase?
    
    private var modelContainer: ModelContainer?
    private var cancellables = Set<AnyCancellable>()
    
    // Configuration
    private let maxMemoryUsage: Int = 500_000_000 // 500MB
    private let peakMemoryUsage: Int = 2_000_000_000 // 2GB
    
    static let shared = AIAgentManager()
    
    private init() {}
    
    func initialize() async throws {
        try await setupModelContainer()
        try await setupFoundationModel()
        try await initializeAgents()
        
        print("AI Agent Manager initialized successfully")
    }
    
    private func setupModelContainer() async throws {
        let schema = Schema([
            Commitment.self,
            MeetingSession.self,
            ActionItem.self,
            ClipboardItem.self,
            ScreenCapture.self,
            AIContext.self,
            User.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }
    
    private func setupFoundationModel() async throws {
        #if canImport(FoundationModels)
        if #available(macOS 15.1, *) {
            do {
                self.foundationModel = try await LanguageModelSession()
                print("✅ Apple Intelligence initialized successfully")
            } catch {
                print("⚠️ Failed to initialize Apple Intelligence: \(error)")
                print("ℹ️ AI features will use fallback implementations")
                self.foundationModel = nil
            }
        } else {
            print("ℹ️ Apple Intelligence requires macOS 15.1+")
            self.foundationModel = nil
        }
        #else
        print("ℹ️ Foundation Models not available - AI features will use fallback implementations")
        self.foundationModel = nil
        #endif
    }
    
    private func initializeAgents() async throws {
        guard let modelContainer = modelContainer else {
            throw AIError.dependenciesNotInitialized
        }
        
        // Initialize vector database (always available)
        self.vectorDatabase = VectorDatabase(container: modelContainer)
        
        // Initialize agents with optional foundationModel (will use fallbacks if nil)
        self.commitmentTracker = CommitmentTracker(
            model: foundationModel, // Can be nil, will use fallbacks
            vectorDB: vectorDatabase!,
            container: modelContainer
        )
        
        self.meetingProcessor = MeetingProcessor(
            model: foundationModel, // Can be nil, will use fallbacks
            container: modelContainer
        )
        
        self.searchEngine = IntelligentSearchEngine(
            vectorDB: vectorDatabase!,
            model: foundationModel, // Can be nil, will use fallbacks
            container: modelContainer
        )
        
        self.screenMonitor = ScreenMonitor(
            commitmentTracker: commitmentTracker!,
            vectorDB: vectorDatabase!
        )
        
        // Start monitoring services
        try await screenMonitor?.startMonitoring()
        
        if foundationModel != nil {
            print("✅ AI Agents initialized with Apple Intelligence")
        } else {
            print("ℹ️ AI Agents initialized with fallback implementations")
        }
    }
    
    func processUserAction(_ action: UserAction) async {
        switch action {
        case .detectCommitment(let message, let context):
            _ = await commitmentTracker?.analyzeMessage(message, context: context)
        case .startMeetingRecording:
            try? await meetingProcessor?.startMeetingRecording()
        case .stopMeetingRecording:
            _ = try? await meetingProcessor?.stopMeetingRecording()
            // Handle session result
        case .searchContent(let query):
            _ = await searchEngine?.semanticSearch(query)
            // Handle search results
        }
    }
    
    func getActiveCommitments() -> [Commitment] {
        guard let modelContainer = modelContainer else { return [] }
        
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Commitment>(
            predicate: #Predicate { commitment in
                commitment.status.rawValue == "pending" || commitment.status.rawValue == "in_progress"
            }
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch active commitments: \(error)")
            return []
        }
    }
    
    func processMeetingAudio(_ audio: AudioData) async -> MeetingTranscript? {
        return await meetingProcessor?.transcribeAudio(audio)
    }
    
    // MARK: - Public API for AIBridge
    
    // Commitment Tracker Interface
    func analyzeMessage(_ message: String, context: MessageContext) async -> Commitment? {
        return await commitmentTracker?.analyzeMessage(message, context: context)
    }
    
    func updateCommitmentStatus(_ uuid: UUID, status: CommitmentStatus) async {
        await commitmentTracker?.updateCommitmentStatus(uuid, status: status)
    }
    
    func snoozeCommitment(_ uuid: UUID, until: Date) async {
        await commitmentTracker?.snoozeCommitment(uuid, until: until)
    }
    
    // Meeting Processor Interface
    func startMeetingRecording() async throws {
        try await meetingProcessor?.startMeetingRecording()
    }
    
    func stopMeetingRecording() async throws -> MeetingSession? {
        return try await meetingProcessor?.stopMeetingRecording()
    }
    
    func getMeetingHistory(limit: Int) -> [MeetingSession] {
        return meetingProcessor?.getMeetingHistory(limit: limit) ?? []
    }
    
    // Search Engine Interface
    func semanticSearch(_ query: String) async -> [SearchResult] {
        return await searchEngine?.semanticSearch(query) ?? []
    }
    
    func globalSearch(_ query: String, limit: Int) async -> GlobalSearchResults? {
        return await searchEngine?.globalSearch(query, limit: limit)
    }
    
    func searchCommitments(_ query: String) async -> [Commitment] {
        return await searchEngine?.searchCommitments(query) ?? []
    }
    
    func searchMeetings(_ query: String) async -> [MeetingSession] {
        return await searchEngine?.searchMeetings(query) ?? []
    }
    
    func searchClipboardHistory(_ query: String) async -> [ClipboardItem] {
        return await searchEngine?.searchClipboardHistory(query) ?? []
    }
    
    // Screen Monitor Interface
    func startScreenMonitoring() async throws {
        try await screenMonitor?.startMonitoring()
    }
    
    func stopScreenMonitoring() {
        screenMonitor?.stopMonitoring()
    }
    
    func detectUnrespondedMessages() async -> [UnrespondedMessage] {
        return await screenMonitor?.detectUnrespondedMessages() ?? []
    }
    
    func shutdown() {
        screenMonitor?.stopMonitoring()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

enum UserAction {
    case detectCommitment(message: String, context: MessageContext)
    case startMeetingRecording
    case stopMeetingRecording
    case searchContent(query: String)
}

struct MessageContext {
    let platform: String
    let sender: String
    let timestamp: Date
    let threadId: String?
}

struct AudioData {
    let data: Data
    let sampleRate: Double
    let channels: Int
}

struct MeetingTranscript {
    let text: String
    let speakers: [String]
    let timestamp: Date
    let confidence: Double
}

// AIError is defined in AISharedTypes.swift - remove duplicate