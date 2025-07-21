import Foundation

// MARK: - AI Compatibility Layer
// This provides fallback implementations when advanced AI features are not available

#if canImport(FoundationModels)
import FoundationModels
typealias AILanguageModelSession = LanguageModelSession
let isAIAvailable = true
#else
// No fallback AI - just show offline message
class AILanguageModelSession {
    func respond(to prompt: String) async throws -> AIResponse {
        throw AIError.serviceOffline
    }
}
let isAIAvailable = false
#endif

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

// MARK: - Feature Availability Checks
struct AICapabilities {
    static var isFoundationModelsAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return true
        }
        #endif
        return false
    }
    
    static var isScreenCaptureAvailable: Bool {
        #if canImport(ScreenCaptureKit)
        if #available(macOS 12.3, *) {
            return true
        }
        #endif
        return false
    }
    
    static var isSpeechRecognitionAvailable: Bool {
        if #available(macOS 10.15, *) {
            return true
        }
        return false
    }
}

// MARK: - Fallback AI Processing
class FallbackAIProcessor {
    static func detectCommitment(in text: String) -> CommitmentDetectionResult? {
        // Simple pattern-based commitment detection as fallback
        let commitmentPatterns = [
            "i'll get back",
            "i'll look into",
            "i'll send",
            "i'll follow up",
            "i'll check",
            "i'll update",
            "will respond",
            "will send",
            "will get back"
        ]
        
        let lowercaseText = text.lowercased()
        let hasCommitment = commitmentPatterns.contains { lowercaseText.contains($0) }
        
        if hasCommitment {
            return CommitmentDetectionResult(
                hasCommitment: true,
                description: "Commitment detected: \(text)",
                recipient: "Unknown",
                urgencyLevel: "medium",
                suggestedReminderHours: 3.0,
                deadline: nil
            )
        }
        
        return nil
    }
    
    static func extractActionItems(from transcript: String) -> [ActionItemData] {
        // Simple keyword-based action item extraction
        let actionKeywords = ["action", "todo", "task", "follow up", "assign", "deadline"]
        let lines = transcript.components(separatedBy: .newlines)
        
        var actionItems: [ActionItemData] = []
        
        for line in lines {
            let lowercaseLine = line.lowercased()
            if actionKeywords.contains(where: { lowercaseLine.contains($0) }) {
                actionItems.append(ActionItemData(
                    description: line,
                    assignee: nil,
                    dueDate: nil,
                    priority: "medium"
                ))
            }
        }
        
        return actionItems
    }
    
    static func summarizeText(_ text: String) -> String {
        // Simple text summarization - just take first few sentences
        let sentences = text.components(separatedBy: ". ")
        let summary = sentences.prefix(3).joined(separator: ". ")
        return summary + (sentences.count > 3 ? "..." : "")
    }
}

struct CommitmentDetectionResult: Codable {
    let hasCommitment: Bool
    let description: String
    let recipient: String
    let urgencyLevel: String
    let suggestedReminderHours: Double
    let deadline: String?
}

struct ActionItemData: Codable {
    let description: String
    let assignee: String?
    let dueDate: String?
    let priority: String
}

// MARK: - Screen Capture Compatibility
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
// Use real types when available
#else
// Mock types when ScreenCaptureKit not available
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
#endif