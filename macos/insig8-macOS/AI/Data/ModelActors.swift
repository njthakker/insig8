import Foundation
import SwiftData

// MARK: - ModelActor Implementations for Thread-Safe Database Operations

@ModelActor
actor CommitmentActor {
    func saveCommitment(_ commitment: Commitment) {
        modelContext.insert(commitment)
        try? modelContext.save()
    }
    
    func fetchCommitments(predicate: Predicate<Commitment>? = nil) -> [Commitment] {
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func updateCommitment(_ commitment: Commitment) {
        commitment.updatedAt = Date()
        try? modelContext.save()
    }
    
    func deleteCommitment(_ commitment: Commitment) {
        modelContext.delete(commitment)
        try? modelContext.save()
    }
    
    func fetchActiveCommitments() -> [Commitment] {
        let predicate = #Predicate<Commitment> { $0.status != CommitmentStatus.completed && $0.status != CommitmentStatus.dismissed }
        let descriptor = FetchDescriptor<Commitment>(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func fetchOverdueCommitments() -> [Commitment] {
        let now = Date()
        let predicate = #Predicate<Commitment> { 
            $0.dueDate != nil && $0.dueDate! < now && $0.status != CommitmentStatus.completed 
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

@ModelActor
actor MeetingSessionActor {
    func saveMeetingSession(_ session: MeetingSession) {
        modelContext.insert(session)
        try? modelContext.save()
    }
    
    func fetchMeetingSessions(predicate: Predicate<MeetingSession>? = nil) -> [MeetingSession] {
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func updateMeetingSession(_ session: MeetingSession) {
        try? modelContext.save()
    }
    
    func deleteMeetingSession(_ session: MeetingSession) {
        modelContext.delete(session)
        try? modelContext.save()
    }
    
    func fetchRecentSessions(limit: Int = 10) -> [MeetingSession] {
        var descriptor = FetchDescriptor<MeetingSession>(
            sortBy: [SortDescriptor(\MeetingSession.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func fetchOngoingSessions() -> [MeetingSession] {
        let predicate = #Predicate<MeetingSession> { $0.endTime == nil }
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

@ModelActor
actor ActionItemActor {
    func saveActionItem(_ item: ActionItem) {
        modelContext.insert(item)
        try? modelContext.save()
    }
    
    func fetchActionItems(predicate: Predicate<ActionItem>? = nil) -> [ActionItem] {
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func updateActionItem(_ item: ActionItem) {
        item.updatedAt = Date()
        try? modelContext.save()
    }
    
    func deleteActionItem(_ item: ActionItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
    
    func fetchOpenActionItems() -> [ActionItem] {
        let predicate = #Predicate<ActionItem> { $0.status == ActionItemStatus.open }
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func fetchActionItemsForMeeting(_ meetingId: UUID) -> [ActionItem] {
        let predicate = #Predicate<ActionItem> { $0.meetingId == meetingId }
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

@ModelActor
actor ClipboardItemActor {
    func saveClipboardItem(_ item: ClipboardItem) {
        modelContext.insert(item)
        try? modelContext.save()
    }
    
    func fetchClipboardItems(predicate: Predicate<ClipboardItem>? = nil) -> [ClipboardItem] {
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func deleteClipboardItem(_ item: ClipboardItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
    
    func fetchRecentClipboardItems(limit: Int = 50) -> [ClipboardItem] {
        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\ClipboardItem.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func cleanupOldClipboardItems(olderThan date: Date) {
        let predicate = #Predicate<ClipboardItem> { $0.timestamp < date }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        if let itemsToDelete = try? modelContext.fetch(descriptor) {
            for item in itemsToDelete {
                modelContext.delete(item)
            }
            try? modelContext.save()
        }
    }
}

@ModelActor
actor ScreenCaptureActor {
    func saveScreenCapture(_ capture: ScreenCapture) {
        modelContext.insert(capture)
        try? modelContext.save()
    }
    
    func fetchScreenCaptures(predicate: Predicate<ScreenCapture>? = nil) -> [ScreenCapture] {
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func deleteScreenCapture(_ capture: ScreenCapture) {
        modelContext.delete(capture)
        try? modelContext.save()
    }
    
    func fetchRecentScreenCaptures(limit: Int = 20) -> [ScreenCapture] {
        var descriptor = FetchDescriptor<ScreenCapture>(
            sortBy: [SortDescriptor(\ScreenCapture.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func fetchScreenCapturesForApp(_ appName: String) -> [ScreenCapture] {
        let predicate = #Predicate<ScreenCapture> { $0.detectedApp == appName }
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func cleanupOldScreenCaptures(olderThan date: Date) {
        let predicate = #Predicate<ScreenCapture> { $0.timestamp < date }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        if let capturesToDelete = try? modelContext.fetch(descriptor) {
            for capture in capturesToDelete {
                modelContext.delete(capture)
            }
            try? modelContext.save()
        }
    }
}

@ModelActor
actor AIContextActor {
    func saveAIContext(_ context: AIContext) {
        modelContext.insert(context)
        try? modelContext.save()
    }
    
    func fetchAIContexts(predicate: Predicate<AIContext>? = nil) -> [AIContext] {
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func updateAIContext(_ context: AIContext) {
        // AIContext doesn't have updatedAt property, just save the changes
        try? modelContext.save()
    }
    
    func deleteAIContext(_ context: AIContext) {
        modelContext.delete(context)
        try? modelContext.save()
    }
    
    func fetchContextsForUser(_ userId: UUID) -> [AIContext] {
        let predicate = #Predicate<AIContext> { $0.userId == userId }
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

@ModelActor
actor UserActor {
    func saveUser(_ user: User) {
        modelContext.insert(user)
        try? modelContext.save()
    }
    
    func fetchUsers(predicate: Predicate<User>? = nil) -> [User] {
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func updateUser(_ user: User) {
        try? modelContext.save()
    }
    
    func deleteUser(_ user: User) {
        modelContext.delete(user)
        try? modelContext.save()
    }
    
    func fetchUserByEmail(_ email: String) -> User? {
        let predicate = #Predicate<User> { $0.email == email }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }
}

// MARK: - Unified Database Manager

@MainActor
class DatabaseManager: ObservableObject {
    private let modelContainer: ModelContainer
    
    // Model actors
    private let commitmentActor: CommitmentActor
    private let meetingActor: MeetingSessionActor
    private let actionItemActor: ActionItemActor
    private let clipboardActor: ClipboardItemActor
    private let screenCaptureActor: ScreenCaptureActor
    private let contextActor: AIContextActor
    private let userActor: UserActor
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.commitmentActor = CommitmentActor(modelContainer: modelContainer)
        self.meetingActor = MeetingSessionActor(modelContainer: modelContainer)
        self.actionItemActor = ActionItemActor(modelContainer: modelContainer)
        self.clipboardActor = ClipboardItemActor(modelContainer: modelContainer)
        self.screenCaptureActor = ScreenCaptureActor(modelContainer: modelContainer)
        self.contextActor = AIContextActor(modelContainer: modelContainer)
        self.userActor = UserActor(modelContainer: modelContainer)
    }
    
    // Commitment operations
    func saveCommitment(_ commitment: Commitment) async {
        await commitmentActor.saveCommitment(commitment)
    }
    
    func fetchCommitments() async -> [Commitment] {
        await commitmentActor.fetchCommitments()
    }
    
    func fetchActiveCommitments() async -> [Commitment] {
        await commitmentActor.fetchActiveCommitments()
    }
    
    func fetchOverdueCommitments() async -> [Commitment] {
        await commitmentActor.fetchOverdueCommitments()
    }
    
    // Meeting operations
    func saveMeetingSession(_ session: MeetingSession) async {
        await meetingActor.saveMeetingSession(session)
    }
    
    func fetchRecentMeetingSessions(limit: Int = 10) async -> [MeetingSession] {
        await meetingActor.fetchRecentSessions(limit: limit)
    }
    
    // Screen capture operations
    func saveScreenCapture(_ capture: ScreenCapture) async {
        await screenCaptureActor.saveScreenCapture(capture)
    }
    
    func fetchRecentScreenCaptures(limit: Int = 20) async -> [ScreenCapture] {
        await screenCaptureActor.fetchRecentScreenCaptures(limit: limit)
    }
    
    // Clipboard operations
    func saveClipboardItem(_ item: ClipboardItem) async {
        await clipboardActor.saveClipboardItem(item)
    }
    
    func fetchRecentClipboardItems(limit: Int = 50) async -> [ClipboardItem] {
        await clipboardActor.fetchRecentClipboardItems(limit: limit)
    }
    
    // Cleanup operations
    func performDataCleanup() async {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        
        // Cleanup old clipboard items (older than 1 week)
        await clipboardActor.cleanupOldClipboardItems(olderThan: oneWeekAgo)
        
        // Cleanup old screen captures (older than 1 month)
        await screenCaptureActor.cleanupOldScreenCaptures(olderThan: oneMonthAgo)
    }
}