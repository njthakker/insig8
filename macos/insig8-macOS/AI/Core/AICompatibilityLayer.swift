import Foundation

// MARK: - AI Compatibility Layer
// This provides feature detection and fallback implementations

// MARK: - Feature Availability Checks
struct AICapabilities {
    static var isFoundationModelsAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 15.1, *) {
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
// These are only used when real AI models are not available
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
    
    static func extractActionItems(from transcript: String) -> [ExtractedActionItem] {
        // Simple keyword-based action item extraction
        let actionKeywords = ["action", "todo", "task", "follow up", "assign", "deadline"]
        let lines = transcript.components(separatedBy: .newlines)
        
        var actionItems: [ExtractedActionItem] = []
        
        for line in lines {
            let lowercaseLine = line.lowercased()
            if actionKeywords.contains(where: { lowercaseLine.contains($0) }) {
                actionItems.append(ExtractedActionItem(
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

// MARK: - Fallback Result Types
struct CommitmentDetectionResult: Codable {
    let hasCommitment: Bool
    let description: String
    let recipient: String
    let urgencyLevel: String
    let suggestedReminderHours: Double
    let deadline: String?
}

struct ExtractedActionItem: Codable {
    let description: String
    let assignee: String?
    let dueDate: String?
    let priority: String
}