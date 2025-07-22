import Foundation
import SwiftData
import Combine
import UserNotifications
#if canImport(FoundationModels)
import FoundationModels
#endif

@Observable
class CommitmentTracker: ObservableObject {
    private let model: AILanguageModelSession?
    private let vectorDB: VectorDatabase
    private let modelContainer: ModelContainer
    private let reminderScheduler: ReminderScheduler
    
    private var cancellables = Set<AnyCancellable>()
    
    // AI prompt templates
    private let commitmentDetectionPrompt = """
    You are an AI assistant that detects commitments and promises in communication.
    
    Analyze the given message and identify:
    1. Any commitments or promises made by the user
    2. The recipient of the commitment
    3. The expected timeline
    4. The specific action promised
    
    Return a JSON response with:
    - hasCommitment (boolean): Whether a commitment was detected
    - description (string): Description of the commitment
    - recipient (string): Who the commitment is made to
    - urgencyLevel (string): "low", "medium", "high", or "urgent"
    - suggestedReminderHours (number): Hours until reminder should fire
    - deadline (string?): Inferred deadline if mentioned
    
    Examples of commitments:
    - "I'll get back to you shortly"
    - "Let me look into this and respond"
    - "I'll send you the document by tomorrow"
    - "Will check and update you"
    - "I'll follow up on this"
    
    Message to analyze:
    """
    
    init(model: AILanguageModelSession?, vectorDB: VectorDatabase, container: ModelContainer) {
        self.model = model
        self.vectorDB = vectorDB
        self.modelContainer = container
        self.reminderScheduler = ReminderScheduler()
    }
    
    func analyzeMessage(_ message: String, context: MessageContext) async -> Commitment? {
        #if canImport(FoundationModels)
        if #available(macOS 15.1, *), let model = model as? LanguageModelSession {
            do {
                // Use Apple Intelligence with structured output
                let prompt = """
                Analyze this message for commitments: \"\(message)\"
                
                Context: Platform: \(context.platform), Sender: \(context.sender), Time: \(context.timestamp)
                
                Look for promises, commitments, or follow-up actions.
                """
                
                let detection: CommitmentDetection = try await model.generate(prompt: prompt)
                
                if detection.hasCommitment {
                    let commitment = try await createCommitmentFromDetection(detection, message: message, context: context)
                    
                    // Schedule reminder
                    scheduleReminder(for: commitment)
                    
                    // Store in vector database
                    try await vectorDB.store(commitment)
                    
                    return commitment
                }
            } catch {
                print("Failed to analyze message with Apple Intelligence: \(error)")
                // Fall back to pattern-based detection
                return await analyzeMessageWithFallback(message, context: context)
            }
        } else {
            // Use fallback for older systems
            return await analyzeMessageWithFallback(message, context: context)
        }
        #else
        // Use fallback when Foundation Models not available
        return await analyzeMessageWithFallback(message, context: context)
        #endif
    }
    
    private func analyzeMessageWithFallback(_ message: String, context: MessageContext) async -> Commitment? {
        // Use the old JSON-based approach or pattern matching
        do {
            let prompt = commitmentDetectionPrompt + "\"\(message)\"\n\nContext: Platform: \(context.platform), Sender: \(context.sender), Time: \(context.timestamp)"
            
            let response = try await model?.respond(to: prompt)
            
            if let response = response,
               let commitmentData = parseCommitmentResponse(response.content) {
                let commitment = try await createCommitment(from: commitmentData, message: message, context: context)
                
                // Schedule reminder
                scheduleReminder(for: commitment)
                
                // Store in vector database
                try await vectorDB.store(commitment)
                
                return commitment
            }
        } catch {
            print("Failed to analyze message for commitments: \(error)")
        }
        
        return nil
    }
    
    func trackCommitmentProgress(_ commitment: Commitment) async {
        // Check if recipient has responded
        let hasResponse = await checkForResponse(commitment)
        
        if hasResponse {
            await updateCommitmentStatus(commitment.id, status: .completed)
        } else if let dueDate = commitment.dueDate, dueDate < Date() {
            await updateCommitmentStatus(commitment.id, status: .overdue)
        }
    }
    
    func scheduleReminder(for commitment: Commitment) {
        let reminderTime = calculateReminderTime(for: commitment)
        reminderScheduler.scheduleReminder(
            id: commitment.id.uuidString,
            title: "Commitment Reminder",
            body: "Remember to follow up: \(commitment.description)",
            fireDate: reminderTime,
            userInfo: ["commitmentId": commitment.id.uuidString]
        )
    }
    
    func updateCommitmentStatus(_ id: UUID, status: CommitmentStatus) async {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Commitment>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            if let commitment = try context.fetch(descriptor).first {
                commitment.status = status
                commitment.updatedAt = Date()
                try context.save()
                
                // Cancel reminder if completed
                if status == .completed || status == .dismissed {
                    reminderScheduler.cancelReminder(id: id.uuidString)
                }
                
                print("Updated commitment \(id) to status: \(status)")
            }
        } catch {
            print("Failed to update commitment status: \(error)")
        }
    }
    
    func snoozeCommitment(_ id: UUID, until date: Date) async {
        await updateCommitmentStatus(id, status: .snoozed)
        
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Commitment>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            if let commitment = try context.fetch(descriptor).first {
                commitment.dueDate = date
                try context.save()
                
                // Reschedule reminder
                reminderScheduler.cancelReminder(id: id.uuidString)
                scheduleReminder(for: commitment)
            }
        } catch {
            print("Failed to snooze commitment: \(error)")
        }
    }
    
    func getActiveCommitments() -> [Commitment] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Commitment>(
            predicate: #Predicate { commitment in
                commitment.status.rawValue == "pending" || 
                commitment.status.rawValue == "in_progress" || 
                commitment.status.rawValue == "overdue" 
            },
            sortBy: [SortDescriptor(\.urgencyScore, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch active commitments: \(error)")
            return []
        }
    }
    
    func getOverdueCommitments() -> [Commitment] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Commitment>(
            predicate: #Predicate { commitment in
                commitment.status.rawValue == "overdue"
            }
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch overdue commitments: \(error)")
            return []
        }
    }
    
    // MARK: - Private Methods
    
    private func parseCommitmentResponse(_ response: String) -> CommitmentDetectionResult? {
        // Parse JSON response from AI model
        guard let data = response.data(using: .utf8) else { return nil }
        
        do {
            let result = try JSONDecoder().decode(CommitmentDetectionResult.self, from: data)
            return result.hasCommitment ? result : nil
        } catch {
            print("Failed to parse commitment response: \(error)")
            
            // Fallback parsing for non-JSON responses
            return parseCommitmentResponseFallback(response)
        }
    }
    
    private func parseCommitmentResponseFallback(_ response: String) -> CommitmentDetectionResult? {
        // Simple pattern matching as fallback
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
        
        let lowercaseResponse = response.lowercased()
        let hasCommitment = commitmentPatterns.contains { lowercaseResponse.contains($0) }
        
        if hasCommitment {
            return CommitmentDetectionResult(
                hasCommitment: true,
                description: "Follow-up commitment detected",
                recipient: "Unknown",
                urgencyLevel: "medium",
                suggestedReminderHours: 3,
                deadline: nil
            )
        }
        
        return nil
    }
    
    private func createCommitment(from data: CommitmentDetectionResult, message: String, context: MessageContext) async throws -> Commitment {
        let priority = mapUrgencyToPriority(data.urgencyLevel)
        let dueDate = calculateDueDate(from: data.deadline, suggestedHours: data.suggestedReminderHours)
        
        let source: CommitmentSource
        switch context.platform.lowercased() {
        case "slack":
            source = .slack(channelId: context.threadId ?? "unknown")
        case "email":
            source = .email(messageId: context.threadId ?? "unknown")
        case "teams":
            source = .teams(conversationId: context.threadId ?? "unknown")
        default:
            source = .screenCapture(timestamp: context.timestamp)
        }
        
        let commitment = Commitment(
            description: data.description,
            source: source,
            recipient: data.recipient,
            dueDate: dueDate,
            status: .pending,
            priority: priority,
            context: message,
            relatedMessages: [message],
            urgencyScore: mapUrgencyToScore(data.urgencyLevel)
        )
        
        // Generate embedding
        commitment.embedding = await commitment.generateEmbedding()
        
        // Save to database
        let modelContext = ModelContext(modelContainer)
        modelContext.insert(commitment)
        try modelContext.save()
        
        return commitment
    }
    
    #if canImport(FoundationModels)
    @available(macOS 15.1, *)
    private func createCommitmentFromDetection(_ detection: CommitmentDetection, message: String, context: MessageContext) async throws -> Commitment {
        let priority = mapUrgencyToPriority(detection.urgencyLevel)
        let dueDate = Date().addingTimeInterval(TimeInterval(detection.suggestedReminderHours * 3600))
        
        let source: CommitmentSource
        switch context.platform.lowercased() {
        case "slack":
            source = .slack(channelId: context.threadId ?? "unknown")
        case "email":
            source = .email(messageId: context.threadId ?? "unknown")
        case "teams":
            source = .teams(conversationId: context.threadId ?? "unknown")
        default:
            source = .screenCapture(timestamp: context.timestamp)
        }
        
        let commitment = Commitment(
            description: detection.description,
            source: source,
            recipient: detection.recipient,
            dueDate: dueDate,
            status: .pending,
            priority: priority,
            context: message,
            relatedMessages: [message],
            urgencyScore: mapUrgencyToScore(detection.urgencyLevel)
        )
        
        // Generate embedding
        commitment.embedding = await commitment.generateEmbedding()
        
        // Save to database
        let context = ModelContext(modelContainer)
        context.insert(commitment)
        try context.save()
        
        return commitment
    }
    #endif
    
    private func checkForResponse(_ commitment: Commitment) async -> Bool {
        // Search for messages from the recipient after the commitment was made
        let searchQuery = "from:\(commitment.recipient) after:\(commitment.createdAt)"
        let results = await vectorDB.semanticSearch(searchQuery, limit: 5)
        
        // Check if any results indicate a response
        for result in results {
            if result.similarity > 0.8 && result.metadata["timestamp"] as? Date ?? Date.distantPast > commitment.createdAt {
                return true
            }
        }
        
        return false
    }
    
    private func calculateReminderTime(for commitment: Commitment) -> Date {
        if let dueDate = commitment.dueDate {
            // Remind 30 minutes before due date, or now if overdue
            return Date(timeInterval: -1800, since: dueDate)
        } else {
            // Default reminder based on urgency
            let hours: TimeInterval
            switch commitment.priority {
            case .urgent:
                hours = 1
            case .high:
                hours = 2
            case .medium:
                hours = 4
            case .low:
                hours = 8
            }
            return Date(timeInterval: hours * 3600, since: Date())
        }
    }
    
    private func calculateDueDate(from deadline: String?, suggestedHours: Double) -> Date? {
        if let deadline = deadline {
            // Parse deadline string (simplified implementation)
            if deadline.contains("tomorrow") {
                return Calendar.current.date(byAdding: .day, value: 1, to: Date())
            } else if deadline.contains("today") {
                return Calendar.current.date(byAdding: .hour, value: 8, to: Date())
            } else if deadline.contains("week") {
                return Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())
            }
        }
        
        // Fallback to suggested hours
        return Date(timeInterval: suggestedHours * 3600, since: Date())
    }
    
    private func mapUrgencyToPriority(_ urgency: String) -> Priority {
        switch urgency.lowercased() {
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
    
    private func mapUrgencyToScore(_ urgency: String) -> Double {
        switch urgency.lowercased() {
        case "urgent":
            return 0.9
        case "high":
            return 0.7
        case "medium":
            return 0.5
        case "low":
            return 0.3
        default:
            return 0.5
        }
    }
}

// MARK: - Supporting Types

// CommitmentDetectionResult moved to AISharedTypes.swift for reuse

// MARK: - Reminder Scheduler

class ReminderScheduler {
    private let notificationCenter = UNUserNotificationCenter.current()
    
    init() {
        requestNotificationPermission()
    }
    
    private func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission denied: \(error)")
            }
        }
    }
    
    func scheduleReminder(id: String, title: String, body: String, fireDate: Date, userInfo: [String: Any] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
        let timeInterval = fireDate.timeIntervalSinceNow
        guard timeInterval > 0 else { return } // Don't schedule past dates
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule reminder: \(error)")
            } else {
                print("Reminder scheduled for \(fireDate)")
            }
        }
    }
    
    func cancelReminder(id: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [id])
    }
    
    func cancelAllReminders() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
}