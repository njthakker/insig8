// MARK: - AI Shared Types
// This file provides all AI types with proper compatibility handling

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Real Apple Intelligence implementation when available
#if canImport(FoundationModels)
@available(macOS 15.1, *)
public typealias AILanguageModelSession = LanguageModelSession

@available(macOS 15.1, *)
public let isAIAvailable = true

#else
// Fallback for older systems
public class AILanguageModelSession {
    public init() {}
    
    public func respond(to prompt: String) async throws -> AIResponse {
        throw AIError.unavailable
    }
}

public let isAIAvailable = false
#endif

// Create a common interface for AI responses
public struct AIResponse {
    public let content: String
    
    public init(content: String) {
        self.content = content
    }
    
    #if canImport(FoundationModels)
    @available(macOS 15.1, *)
    public init(from modelResponse: LanguageModelStreamingResponse.Update) {
        self.content = modelResponse.text ?? ""
    }
    #endif
}

// Screen capture compatibility
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
// Use real types when available
#else
// Mock types when ScreenCaptureKit not available
public class SCCaptureEngine {
    // Empty mock implementation
}

public class SCCaptureStream {
    // Empty mock implementation  
}

public class SCCaptureScreenshot {
    public let surface: MockSurface = MockSurface()
}

public class MockSurface {
    public let data: Data = Data()
}
#endif

// AI Response and Error types
public enum AIError: LocalizedError {
    case unavailable
    case serviceOffline
    case processingFailed(String)
    case initializationFailed(String)
    case modelNotAvailable
    case modelUnavailable
    case notAvailable
    case unsupportedVersion
    case dependenciesNotInitialized
    case unsupportedOS
    case permissionDenied(String)
    case vectorDatabaseError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "AI services are not available on this device"
        case .serviceOffline:
            return "On device agent offline"
        case .processingFailed(let reason):
            return "AI processing failed: \(reason)"
        case .initializationFailed(let reason):
            return "Failed to initialize AI model: \(reason)"
        case .modelNotAvailable:
            return "AI model not available"
        case .modelUnavailable:
            return "AI model is unavailable"
        case .notAvailable:
            return "Feature not available"
        case .unsupportedVersion:
            return "Unsupported version"
        case .dependenciesNotInitialized:
            return "AI dependencies not properly initialized"
        case .unsupportedOS:
            return "macOS 26 or later is required for AI features"
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        case .vectorDatabaseError(let error):
            return "Vector database error: \(error.localizedDescription)"
        }
    }
}

// Shared data structures for AI operations
public struct CommitmentDetectionResult: Codable {
    public let hasCommitment: Bool
    public let description: String
    public let recipient: String
    public let urgencyLevel: String
    public let suggestedReminderHours: Double
    public let deadline: String?
    public let confidence: Float
    public let commitmentType: String
    public let method: AnalysisMethod
    
    public init(hasCommitment: Bool, description: String = "", recipient: String = "", urgencyLevel: String = "medium", suggestedReminderHours: Double = 4.0, deadline: String? = nil, confidence: Float = 0.0, commitmentType: String = "", method: AnalysisMethod = .ruleBased) {
        self.hasCommitment = hasCommitment
        self.description = description
        self.recipient = recipient
        self.urgencyLevel = urgencyLevel
        self.suggestedReminderHours = suggestedReminderHours
        self.deadline = deadline
        self.confidence = confidence
        self.commitmentType = commitmentType
        self.method = method
    }
}

public enum AnalysisMethod: Codable {
    case coreML
    case naturalLanguage
    case appleLLM
    case ruleBased
}

// Generable structs for structured outputs
#if canImport(FoundationModels)
import FoundationModels

@available(macOS 15.1, *)
@Generable
public struct CommitmentDetection {
    public let hasCommitment: Bool
    public let description: String
    public let recipient: String
    public let urgencyLevel: String // "low", "medium", "high"
    public let suggestedReminderHours: Int
}

@available(macOS 15.1, *)
@Generable
public struct ActionItemExtraction {
    public let actionItems: [ActionItemData]
}

@available(macOS 15.1, *)
@Generable
public struct ActionItemData {
    public let description: String
    public let assignee: String?
    public let priority: String // "low", "medium", "high"
    public let dueDate: String? // ISO8601 format
}

@available(macOS 15.1, *)
@Generable
public struct MeetingSummary {
    public let keyDecisions: [String]
    public let mainDiscussionPoints: [String]
    public let nextSteps: [String]
    public let overallSummary: String
}

@available(macOS 15.1, *)
@Generable
public struct MessageAnalysis {
    public let sentiment: String // "positive", "negative", "neutral"
    public let sentimentScore: Double // -1.0 to 1.0
    public let urgencyLevel: String // "low", "medium", "high", "urgent"
    public let hasQuestion: Bool
    public let requiresResponse: Bool
    public let suggestedResponseTime: Int // hours
    public let keyTopics: [String]
    public let mentionedPeople: [String]
}

@available(macOS 15.1, *)
@Generable
public struct EmailComposition {
    public let subject: String
    public let body: String
    public let tone: String // "professional", "friendly", "formal", "casual"
    public let recipients: [String]
    public let priority: String // "low", "medium", "high"
    public let suggestedSendTime: String? // ISO8601 format
}

@available(macOS 15.1, *)
@Generable
public struct DocumentSummary {
    public let title: String
    public let mainPoints: [String]
    public let keyFindings: [String]
    public let actionItems: [String]
    public let summary: String
    public let wordCount: Int
    public let readingTimeMinutes: Int
}

@available(macOS 15.1, *)
@Generable
public struct ScreenContextAnalysis {
    public let currentActivity: String
    public let detectedApps: [String]
    public let importantMessages: [ImportantMessage]
    public let suggestions: [ContextualSuggestion]
    public let productivityScore: Double // 0.0 to 1.0
    public let focusLevel: String // "high", "medium", "low"
}

@available(macOS 15.1, *)
@Generable
public struct ImportantMessage {
    public let sender: String
    public let platform: String // "slack", "email", "teams", etc.
    public let content: String
    public let urgencyLevel: String
    public let requiresResponse: Bool
    public let timeSinceReceived: Int // minutes
}

@available(macOS 15.1, *)
@Generable
public struct ContextualSuggestion {
    public let type: String // "respond", "schedule", "focus", "break", "follow_up"
    public let title: String
    public let description: String
    public let confidence: Double // 0.0 to 1.0
    public let actionRequired: Bool
    public let estimatedTimeMinutes: Int
}

@available(macOS 15.1, *)
@Generable
public struct WorkflowOptimization {
    public let inefficiencies: [WorkflowInefficiency]
    public let suggestions: [OptimizationSuggestion]
    public let potentialTimeSavings: Int // minutes per day
    public let implementationDifficulty: String // "easy", "medium", "hard"
}

@available(macOS 15.1, *)
@Generable
public struct WorkflowInefficiency {
    public let description: String
    public let frequency: String // "daily", "weekly", "monthly"
    public let timeWasted: Int // minutes
    public let category: String // "communication", "task_switching", "interruptions"
}

@available(macOS 15.1, *)
@Generable
public struct OptimizationSuggestion {
    public let title: String
    public let description: String
    public let expectedBenefit: String
    public let implementation: String
    public let category: String
}

@available(macOS 15.1, *)
@Generable
public struct TimeManagementInsights {
    public let totalActiveTime: Int // minutes
    public let focusedTime: Int // minutes
    public let distractedTime: Int // minutes
    public let topDistractions: [String]
    public let mostProductiveHours: [Int] // hours of day
    public let taskSwitchingFrequency: Int // switches per hour
    public let recommendations: [TimeManagementTip]
}

@available(macOS 15.1, *)
@Generable
public struct TimeManagementTip {
    public let tip: String
    public let rationale: String
    public let difficulty: String // "easy", "medium", "hard"
    public let expectedImpact: String // "low", "medium", "high"
}

@available(macOS 15.1, *)
@Generable
public struct PersonalizedResponse {
    public let responseText: String
    public let tone: String
    public let confidence: Double
    public let alternativeResponses: [String]
    public let suggestedFollowUp: String?
    public let estimatedResponseTime: String // "immediate", "within_hour", "end_of_day"
}

@available(macOS 15.1, *)
@Generable
public struct BehaviorPattern {
    public let patternName: String
    public let description: String
    public let frequency: String
    public let triggers: [String]
    public let impacts: [String] // positive or negative impacts
    public let confidence: Double
    public let suggestions: [BehaviorSuggestion]
}

@available(macOS 15.1, *)
@Generable
public struct BehaviorSuggestion {
    public let suggestion: String
    public let reasoning: String
    public let difficulty: String
    public let expectedOutcome: String
}

@available(macOS 15.1, *)
@Generable
public struct SmartNotification {
    public let priority: String // "low", "medium", "high", "urgent"
    public let title: String
    public let message: String
    public let actionRequired: Bool
    public let suggestedActions: [String]
    public let timing: String // "now", "later", "tomorrow"
    public let category: String // "commitment", "meeting", "message", "reminder"
}

@available(macOS 15.1, *)
@Generable
public struct ProductivityInsights {
    public let dailyScore: Double // 0.0 to 1.0
    public let weeklyTrend: String // "improving", "stable", "declining"
    public let strengths: [String]
    public let improvementAreas: [String]
    public let achievedGoals: Int
    public let missedDeadlines: Int
    public let recommendations: [ProductivityRecommendation]
}

@available(macOS 15.1, *)
@Generable
public struct ProductivityRecommendation {
    public let title: String
    public let description: String
    public let category: String // "focus", "organization", "communication", "health"
    public let priority: String
    public let estimatedImpact: String
}

@available(macOS 15.1, *)
@Generable
public struct SearchIntent {
    public let queryType: String // "commitment", "meeting", "clipboard", "general"
    public let keywords: [String]
    public let timeConstraint: String? // "today", "this_week", "this_month", "all"
    public let expandedQuery: String
}

@available(macOS 15.1, *)
@Generable
public struct UnrespondedMessageDetection {
    public let hasUnrespondedMessage: Bool
    public let sender: String
    public let platform: String // "slack", "teams", "email", "other"
    public let messagePreview: String
    public let expiryHours: Int
}

#else
// Fallback implementations for when Apple Intelligence is not available
// These provide the same interface but without @Generable functionality

public struct CommitmentDetection {
    public let hasCommitment: Bool
    public let description: String
    public let recipient: String
    public let urgencyLevel: String // "low", "medium", "high"
    public let suggestedReminderHours: Int
    
    public init(hasCommitment: Bool, description: String, recipient: String, urgencyLevel: String, suggestedReminderHours: Int) {
        self.hasCommitment = hasCommitment
        self.description = description
        self.recipient = recipient
        self.urgencyLevel = urgencyLevel
        self.suggestedReminderHours = suggestedReminderHours
    }
}

public struct ActionItemExtraction {
    public let actionItems: [ActionItemData]
    
    public init(actionItems: [ActionItemData]) {
        self.actionItems = actionItems
    }
}

public struct ActionItemData: Codable {
    public let description: String
    public let assignee: String?
    public let priority: String // "low", "medium", "high"
    public let dueDate: String? // ISO8601 format
    
    public init(description: String, assignee: String?, priority: String, dueDate: String?) {
        self.description = description
        self.assignee = assignee
        self.priority = priority
        self.dueDate = dueDate
    }
}

public struct MeetingSummary {
    public let keyDecisions: [String]
    public let mainDiscussionPoints: [String]
    public let nextSteps: [String]
    public let overallSummary: String
    
    public init(keyDecisions: [String], mainDiscussionPoints: [String], nextSteps: [String], overallSummary: String) {
        self.keyDecisions = keyDecisions
        self.mainDiscussionPoints = mainDiscussionPoints
        self.nextSteps = nextSteps
        self.overallSummary = overallSummary
    }
}

public struct MessageAnalysis {
    public let sentiment: String // "positive", "negative", "neutral"
    public let sentimentScore: Double // -1.0 to 1.0
    public let urgencyLevel: String // "low", "medium", "high", "urgent"
    public let hasQuestion: Bool
    public let requiresResponse: Bool
    public let suggestedResponseTime: Int // hours
    public let keyTopics: [String]
    public let entities: [String]
    
    public init(sentiment: String, sentimentScore: Double, urgencyLevel: String, hasQuestion: Bool, requiresResponse: Bool, suggestedResponseTime: Int, keyTopics: [String], entities: [String]) {
        self.sentiment = sentiment
        self.sentimentScore = sentimentScore
        self.urgencyLevel = urgencyLevel
        self.hasQuestion = hasQuestion
        self.requiresResponse = requiresResponse
        self.suggestedResponseTime = suggestedResponseTime
        self.keyTopics = keyTopics
        self.entities = entities
    }
}

public struct UnrespondedMessageDetection {
    public let hasUnrespondedMessage: Bool
    public let sender: String
    public let platform: String // "slack", "teams", "email", "other"
    public let messagePreview: String
    public let expiryHours: Int
    
    public init(hasUnrespondedMessage: Bool, sender: String, platform: String, messagePreview: String, expiryHours: Int) {
        self.hasUnrespondedMessage = hasUnrespondedMessage
        self.sender = sender
        self.platform = platform
        self.messagePreview = messagePreview
        self.expiryHours = expiryHours
    }
}

#endif