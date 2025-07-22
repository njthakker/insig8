import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// Placeholder types for building without FoundationModels
#if !canImport(FoundationModels)
struct SystemLanguageModel {
    static let `default` = SystemLanguageModel()
    var isAvailable: Bool { false }
}

struct LanguageModelSession {
    func respond(to prompt: Prompt) async throws -> LanguageModelResponse {
        throw AIError.notAvailable
    }
}

struct Prompt {
    let text: String
    init(_ text: String) { self.text = text }
}

struct LanguageModelResponse {
    let text: String
}

struct CommitmentAnalysis {
    let hasCommitment: Bool
    let description: String
    let recipient: String
    let urgencyLevel: String
    let suggestedReminderHours: Double
    let deadline: String?
}
#endif

/// Apple Intelligence Manager for on-device AI processing
class AppleIntelligenceManager {
    #if canImport(FoundationModels)
    private var languageModel: SystemLanguageModel?
    private var session: LanguageModelSession?
    #else
    private var languageModel: SystemLanguageModel?
    private var session: LanguageModelSession?
    #endif
    
    init() {
        #if canImport(FoundationModels)
        if #available(macOS 15.1, *) {
            self.languageModel = SystemLanguageModel.default
        }
        #endif
    }
    
    /// Analyze commitment in text using Apple Intelligence
    func analyzeCommitment(_ text: String) async throws -> CommitmentAnalysis? {
        #if canImport(FoundationModels)
        if #available(macOS 15.1, *) {
            guard let languageModel = languageModel, languageModel.isAvailable else {
                throw AIError.modelUnavailable
            }
            
            let session = LanguageModelSession()
            let prompt = Prompt("""
                Analyze this message for commitments or promises:
                "\(text)"
                
                Extract any commitments with timeline and identify if follow-up is needed.
                Return structured data about any commitments found.
                """)
                
            let response = try await session.respond(to: prompt)
            return parseCommitmentResponse(response.text)
        } else {
            throw AIError.unsupportedVersion
        }
        #else
        throw AIError.notAvailable
        #endif
    }
    
    /// Generate action items from meeting transcript using Apple Intelligence  
    func extractActionItems(_ prompt: String) async throws -> [ActionItem] {
        #if canImport(FoundationModels)
        if #available(macOS 15.1, *) {
            guard let languageModel = languageModel, languageModel.isAvailable else {
                throw AIError.modelUnavailable
            }
            
            let session = LanguageModelSession()
            let structuredPrompt = Prompt("""
                Extract action items from this meeting transcript:
                \(prompt)
                
                For each action item, identify:
                - The task description
                - Who is responsible
                - Any mentioned deadline
                - Priority level
                
                Return as structured list of action items.
                """)
            
            let response = try await session.respond(to: structuredPrompt)
            return parseActionItems(response.text)
        } else {
            throw AIError.unsupportedVersion
        }
        #else
        throw AIError.notAvailable
        #endif
    }
    
    /// Enhance search query using Apple Intelligence
    func enhanceSearchQuery(_ query: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 15.1, *) {
            guard let languageModel = languageModel, languageModel.isAvailable else {
                return query // Return original query if AI not available
            }
            
            let session = LanguageModelSession()
            let prompt = Prompt("""
                Enhance this search query to improve search results:
                "\(query)"
                
                Return an enhanced version that would find more relevant results.
                Only return the enhanced query text, nothing else.
                """)
            
            let response = try await session.respond(to: prompt)
            return response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return query
        }
        #else
        return query
        #endif
    }
    
    /// Generate meeting summary using Apple Intelligence
    func generateMeetingSummary(_ transcript: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 15.1, *) {
            guard let languageModel = languageModel, languageModel.isAvailable else {
                throw AIError.modelUnavailable
            }
            
            let session = LanguageModelSession()
            let prompt = Prompt("""
                Create a concise meeting summary from this transcript:
                \(transcript)
                
                Include:
                1. Key decisions made
                2. Main discussion points
                3. Action items identified
                4. Next steps
                
                Format as a professional meeting summary.
                """)
            
            let response = try await session.respond(to: prompt)
            return response.text
        } else {
            throw AIError.unsupportedVersion
        }
        #else
        throw AIError.notAvailable
        #endif
    }
    
    /// Check if Apple Intelligence is available
    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 15.1, *) {
            return languageModel?.isAvailable ?? false
        }
        #endif
        return false
    }
    
    // MARK: - Private Parsing Methods
    
    private func parseCommitmentResponse(_ text: String) -> CommitmentAnalysis? {
        // Parse the AI response into structured CommitmentAnalysis
        // This would include more sophisticated parsing logic
        let hasCommitment = text.lowercased().contains("commitment") || 
                           text.lowercased().contains("promise") ||
                           text.lowercased().contains("will do") ||
                           text.lowercased().contains("agree to")
        
        guard hasCommitment else { return nil }
        
        // Extract timeline if mentioned
        let timeline = extractTimeline(from: text)
        
        // Determine urgency level
        let urgency = determineUrgency(from: text)
        
        // Check if follow-up is needed
        let followUpNeeded = text.lowercased().contains("follow up") ||
                            text.lowercased().contains("check back") ||
                            urgency == .high || urgency == .urgent
        
        return CommitmentAnalysis(
            hasCommitment: hasCommitment,
            commitment: extractCommitmentText(from: text),
            timeline: timeline,
            urgency: urgency,
            followUpNeeded: followUpNeeded
        )
    }
    
    private func parseActionItems(_ text: String) -> [ActionItem] {
        var actionItems: [ActionItem] = []
        
        // Simple parsing logic - in a real implementation, this would be more sophisticated
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                let taskDescription = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                
                let actionItem = ActionItem(
                    id: UUID(),
                    description: taskDescription,
                    assignee: extractAssignee(from: taskDescription),
                    dueDate: extractDueDate(from: taskDescription),
                    status: .open,
                    meetingId: UUID(), // Placeholder - will be set by caller
                    priority: determineActionItemPriority(from: taskDescription)
                )
                
                actionItems.append(actionItem)
            }
        }
        
        return actionItems
    }
    
    private func extractTimeline(from text: String) -> String? {
        // Extract timeline mentions like "by Friday", "next week", etc.
        let timelinePatterns = [
            "by \\w+",
            "next \\w+", 
            "this \\w+",
            "within \\d+ \\w+",
            "in \\d+ \\w+"
        ]
        
        for pattern in timelinePatterns {
            if let range = text.range(of: pattern, options: .regularExpression, range: nil, locale: nil) {
                return String(text[range])
            }
        }
        
        return nil
    }
    
    private func determineUrgency(from text: String) -> Priority {
        let urgentKeywords = ["urgent", "asap", "immediately", "critical", "emergency"]
        let highKeywords = ["important", "priority", "soon", "quickly", "today"]
        let lowKeywords = ["when you can", "no rush", "eventually", "sometime"]
        
        let lowercaseText = text.lowercased()
        
        if urgentKeywords.contains(where: { lowercaseText.contains($0) }) {
            return .urgent
        } else if highKeywords.contains(where: { lowercaseText.contains($0) }) {
            return .high
        } else if lowKeywords.contains(where: { lowercaseText.contains($0) }) {
            return .low
        } else {
            return .medium
        }
    }
    
    private func extractCommitmentText(from text: String) -> String? {
        // Extract the actual commitment text
        // This is a simplified implementation
        let sentences = text.components(separatedBy: ". ")
        
        for sentence in sentences {
            if sentence.lowercased().contains("will") ||
               sentence.lowercased().contains("commit") ||
               sentence.lowercased().contains("promise") {
                return sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return nil
    }
    
    private func extractAssignee(from text: String) -> String? {
        // Look for patterns like "John will", "Sarah should", etc.
        let assigneePatterns = [
            "\\b[A-Z][a-z]+ will\\b",
            "\\b[A-Z][a-z]+ should\\b",
            "\\b[A-Z][a-z]+ to\\b"
        ]
        
        for pattern in assigneePatterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                let match = String(text[range])
                return match.components(separatedBy: " ").first
            }
        }
        
        return nil
    }
    
    private func extractDueDate(from text: String) -> Date? {
        // Extract due dates - this would be more sophisticated in practice
        let datePatterns = [
            "due \\w+",
            "by \\w+",
            "deadline \\w+"
        ]
        
        // Simplified date parsing - real implementation would use DateFormatter
        let calendar = Calendar.current
        
        if text.lowercased().contains("today") {
            return Date()
        } else if text.lowercased().contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: Date())
        } else if text.lowercased().contains("next week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: Date())
        }
        
        return nil
    }
    
    private func determineActionItemPriority(from text: String) -> Priority {
        return determineUrgency(from: text) // Reuse the same logic
    }
}

// MARK: - Guided Generation Support

#if canImport(FoundationModels)
@available(macOS 15.1, *)
@Generable
struct CommitmentAnalysis: Sendable {
    let hasCommitment: Bool
    let commitment: String?
    let timeline: String?
    let urgency: Priority
    let followUpNeeded: Bool
}

@available(macOS 15.1, *)
@Generable 
struct MeetingSummary: Sendable {
    let keyDecisions: [String]
    let mainDiscussionPoints: [String]
    let nextSteps: [String]
    let overallSummary: String
}

@available(macOS 15.1, *)
@Generable
struct ActionItem: Sendable {
    let id: UUID
    let task: String
    let assignee: String?
    let deadline: Date?
    let priority: Priority
    
    // Computed property for backward compatibility
    var description: String {
        return task
    }
}
#endif

// AIError enum is defined in AISharedTypes.swift