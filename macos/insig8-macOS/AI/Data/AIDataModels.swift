import Foundation
import SwiftData

// MARK: - User Models

@Model
class User {
    var id: UUID
    var name: String
    var email: String
    var preferences: UserPreferences
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, email: String, preferences: UserPreferences = UserPreferences()) {
        self.id = id
        self.name = name
        self.email = email
        self.preferences = preferences
        self.createdAt = Date()
    }
}

@Model
class UserPreferences {
    var reminderFrequency: ReminderFrequency
    var enableScreenMonitoring: Bool
    var enableMeetingRecording: Bool
    var autoGenerateActionItems: Bool
    var prioritySettings: PrioritySettings
    
    init(
        reminderFrequency: ReminderFrequency = .smart,
        enableScreenMonitoring: Bool = true,
        enableMeetingRecording: Bool = true,
        autoGenerateActionItems: Bool = true,
        prioritySettings: PrioritySettings = PrioritySettings()
    ) {
        self.reminderFrequency = reminderFrequency
        self.enableScreenMonitoring = enableScreenMonitoring
        self.enableMeetingRecording = enableMeetingRecording
        self.autoGenerateActionItems = autoGenerateActionItems
        self.prioritySettings = prioritySettings
    }
}

// MARK: - Commitment Models

@Model
class Commitment: VectorStorable {
    var id: UUID
    var commitmentText: String
    var source: CommitmentSource
    var recipient: String
    var dueDate: Date?
    var status: CommitmentStatus
    var priority: Priority
    var context: String
    var relatedMessages: [String]
    var embedding: [Float]
    var createdAt: Date
    var updatedAt: Date
    var urgencyScore: Double
    
    init(
        id: UUID = UUID(),
        description: String,
        source: CommitmentSource,
        recipient: String,
        dueDate: Date? = nil,
        status: CommitmentStatus = .pending,
        priority: Priority = .medium,
        context: String = "",
        relatedMessages: [String] = [],
        urgencyScore: Double = 0.5
    ) {
        self.id = id
        self.commitmentText = description
        self.source = source
        self.recipient = recipient
        self.dueDate = dueDate
        self.status = status
        self.priority = priority
        self.context = context
        self.relatedMessages = relatedMessages
        self.embedding = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.urgencyScore = urgencyScore
    }
    
    func generateEmbedding() async -> [Float] {
        // Implementation will use NaturalLanguage framework
        return []
    }
}

// MARK: - Meeting Models

@Model
class MeetingSession: VectorStorable {
    var id: UUID
    var title: String
    var startTime: Date
    var endTime: Date?
    var participants: [String]
    var transcript: String
    var summary: String
    var actionItems: [ActionItem]
    var recording: AudioRecording?
    var embedding: [Float]
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        startTime: Date = Date(),
        participants: [String] = [],
        transcript: String = "",
        summary: String = ""
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = nil
        self.participants = participants
        self.transcript = transcript
        self.summary = summary
        self.actionItems = []
        self.recording = nil
        self.embedding = []
        self.createdAt = Date()
    }
    
    func generateEmbedding() async -> [Float] {
        // Generate embedding from summary and transcript
        return []
    }
}

@Model
class ActionItem {
    var id: UUID
    var itemDescription: String
    var assignee: String?
    var dueDate: Date?
    var status: ActionItemStatus
    var meetingId: UUID
    var priority: Priority
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        description: String,
        assignee: String? = nil,
        dueDate: Date? = nil,
        status: ActionItemStatus = .open,
        meetingId: UUID,
        priority: Priority = .medium
    ) {
        self.id = id
        self.itemDescription = description
        self.assignee = assignee
        self.dueDate = dueDate
        self.status = status
        self.meetingId = meetingId
        self.priority = priority
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Clipboard and Screen Models

@Model
class ClipboardItem: VectorStorable {
    var id: UUID
    var content: String
    var contentType: ClipboardContentType
    var timestamp: Date
    var sourceApp: String?
    var embedding: [Float]
    
    init(
        id: UUID = UUID(),
        content: String,
        contentType: ClipboardContentType,
        sourceApp: String? = nil
    ) {
        self.id = id
        self.content = content
        self.contentType = contentType
        self.timestamp = Date()
        self.sourceApp = sourceApp
        self.embedding = []
    }
    
    func generateEmbedding() async -> [Float] {
        // Generate embedding from content
        return []
    }
}

@Model
class ScreenCapture: VectorStorable {
    var id: UUID
    var timestamp: Date
    var imageData: Data
    var extractedText: String
    var detectedApp: String
    var context: ScreenContext
    var embedding: [Float]
    
    init(
        id: UUID = UUID(),
        imageData: Data,
        extractedText: String = "",
        detectedApp: String = "",
        context: ScreenContext = ScreenContext()
    ) {
        self.id = id
        self.timestamp = Date()
        self.imageData = imageData
        self.extractedText = extractedText
        self.detectedApp = detectedApp
        self.context = context
        self.embedding = []
    }
    
    func generateEmbedding() async -> [Float] {
        // Generate embedding from extracted text
        return []
    }
}

@Model
class AIContext {
    var id: UUID
    var userId: UUID
    var contextType: ContextType
    var data: String
    var timestamp: Date
    var embedding: [Float]
    var relevanceScore: Double
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        contextType: ContextType,
        data: String,
        relevanceScore: Double = 0.0
    ) {
        self.id = id
        self.userId = userId
        self.contextType = contextType
        self.data = data
        self.timestamp = Date()
        self.embedding = []
        self.relevanceScore = relevanceScore
    }
}

// MARK: - Supporting Types and Enums

enum CommitmentSource: Codable {
    case slack(channelId: String)
    case email(messageId: String)
    case teams(conversationId: String)
    case manual
    case screenCapture(timestamp: Date)
    
    var displayName: String {
        switch self {
        case .slack: return "Slack"
        case .email: return "Email"
        case .teams: return "Teams"
        case .manual: return "Manual"
        case .screenCapture: return "Screen Capture"
        }
    }
}

enum CommitmentStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case overdue = "overdue"
    case dismissed = "dismissed"
    case snoozed = "snoozed"
}

enum ActionItemStatus: String, Codable, CaseIterable {
    case open = "open"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
}

enum Priority: Int, Codable, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case urgent = 4
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
}

enum ClipboardContentType: String, Codable, CaseIterable {
    case text = "text"
    case url = "url"
    case file = "file"
    case image = "image"
}

enum ContextType: String, Codable, CaseIterable {
    case commitment = "commitment"
    case meeting = "meeting"
    case screenCapture = "screen_capture"
    case clipboardItem = "clipboard_item"
    case browserHistory = "browser_history"
}

enum ReminderFrequency: String, Codable, CaseIterable {
    case never = "never"
    case smart = "smart"
    case hourly = "hourly"
    case daily = "daily"
    case custom = "custom"
}

struct PrioritySettings: Codable {
    var urgentThreshold: Double = 0.8
    var highThreshold: Double = 0.6
    var mediumThreshold: Double = 0.4
    var enableSmartPriority: Bool = true
}

struct ScreenContext: Codable {
    var activeWindow: String = ""
    var visibleText: [String] = []
    var detectedElements: [String] = []
    var timeSpent: TimeInterval = 0
    var userInteraction: Bool = false
}

struct AudioRecording: Codable {
    var filePath: String
    var duration: TimeInterval
    var sampleRate: Double
    var channels: Int
    var fileSize: Int64
}

// MARK: - Vector Storage Protocol

protocol VectorStorable {
    var embedding: [Float] { get set }
    func generateEmbedding() async -> [Float]
}

// MARK: - Search Result Types

struct VectorSearchResult {
    let id: UUID
    let similarity: Float
    let content: String
    let metadata: [String: Any]
    let type: ContextType
}

struct SearchResult {
    let id: UUID
    let title: String
    let content: String
    let type: ContextType
    let relevanceScore: Double
    let timestamp: Date
    let metadata: [String: Any]
}

struct RelatedItem {
    let id: UUID
    let title: String
    let type: ContextType
    let relationshipType: RelationshipType
    let similarity: Double
}

enum RelationshipType: String, CaseIterable {
    case temporal = "temporal"
    case semantic = "semantic"
    case contextual = "contextual"
    case causal = "causal"
}