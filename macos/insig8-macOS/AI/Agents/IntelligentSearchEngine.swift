import Foundation
import SwiftData
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
class IntelligentSearchEngine: ObservableObject {
    private let vectorDB: VectorDatabase
    private let model: AILanguageModelSession
    private let modelContainer: ModelContainer
    private let clipboardManager: ClipboardHistoryManager
    private let browserHistoryReader: BrowserHistoryReader
    
    // Search enhancement prompts
    private let searchEnhancementPrompt = """
    You are an AI assistant that helps users find information.
    
    Given a user query, determine:
    1. What type of information they're looking for
    2. Which data sources to search (clipboard, browser history, documents, etc.)
    3. Relevant keywords and synonyms
    4. Time-based constraints
    
    Return a JSON response with:
    {
        "intent": "string describing user intent",
        "searchSources": ["clipboard", "browser", "meetings", "commitments", "screen_captures"],
        "keywords": ["relevant", "keywords", "and", "synonyms"],
        "timeConstraint": "recent|today|week|month|all",
        "expandedQuery": "enhanced search query"
    }
    
    User query: 
    """
    
    init(vectorDB: VectorDatabase, model: AILanguageModelSession, container: ModelContainer) {
        self.vectorDB = vectorDB
        self.model = model
        self.modelContainer = container
        self.clipboardManager = ClipboardHistoryManager(container: container)
        self.browserHistoryReader = BrowserHistoryReader()
    }
    
    func searchClipboardHistory(_ query: String) async -> [ClipboardItem] {
        return await clipboardManager.searchHistory(query)
    }
    
    func searchBrowsingHistory(_ query: String) async -> [BrowserHistoryItem] {
        return await browserHistoryReader.search(query)
    }
    
    func semanticSearch(_ query: String) async -> [SearchResult] {
        // Enhance the query using AI
        let enhancedQuery = await enhanceSearchQuery(query)
        
        // Perform vector search
        let vectorResults = await vectorDB.hybridSearch(enhancedQuery.expandedQuery)
        
        // Convert to SearchResult format
        var searchResults: [SearchResult] = []
        
        for result in vectorResults {
            let searchResult = SearchResult(
                id: result.id,
                title: extractTitle(from: result),
                content: result.content,
                type: result.type,
                relevanceScore: Double(result.similarity),
                timestamp: Date(), // Would be extracted from metadata
                metadata: result.metadata
            )
            searchResults.append(searchResult)
        }
        
        // Add results from specific sources if requested
        if enhancedQuery.searchSources.contains("clipboard") {
            let clipboardResults = await searchClipboardHistory(query)
            searchResults.append(contentsOf: clipboardResults.map { convertToSearchResult($0) })
        }
        
        if enhancedQuery.searchSources.contains("browser") {
            let browserResults = await searchBrowsingHistory(query)
            searchResults.append(contentsOf: browserResults.map { convertToSearchResult($0) })
        }
        
        // Sort by relevance and apply time constraints
        return applyTimeConstraints(
            sortByRelevance(searchResults),
            constraint: enhancedQuery.timeConstraint
        )
    }
    
    func findRelatedContent(_ item: Any) async -> [RelatedItem] {
        var relatedItems: [RelatedItem] = []
        
        // Generate embedding for the item
        let embedding = await generateEmbeddingForItem(item)
        guard !embedding.isEmpty else { return [] }
        
        // Find similar items in vector database
        let similarResults = await vectorDB.search(embedding, limit: 10)
        
        for result in similarResults {
            let relatedItem = RelatedItem(
                id: result.id,
                title: extractTitle(from: result),
                type: result.type,
                relationshipType: determineRelationshipType(result, to: item),
                similarity: Double(result.similarity)
            )
            relatedItems.append(relatedItem)
        }
        
        return relatedItems
    }
    
    func searchByType(_ query: String, type: ContextType, limit: Int = 10) async -> [SearchResult] {
        let vectorResults = await vectorDB.semanticSearch(query, limit: limit * 2)
        
        let filteredResults = vectorResults.filter { $0.type == type }
        
        return Array(filteredResults.prefix(limit)).map { result in
            SearchResult(
                id: result.id,
                title: extractTitle(from: result),
                content: result.content,
                type: result.type,
                relevanceScore: Double(result.similarity),
                timestamp: Date(),
                metadata: result.metadata
            )
        }
    }
    
    func searchCommitments(_ query: String) async -> [Commitment] {
        let context = ModelContext(modelContainer)
        let vectorResults = await vectorDB.semanticSearch(query, limit: 20)
        
        let commitmentIds = vectorResults
            .filter { $0.type == .commitment }
            .map { $0.id }
        
        var commitments: [Commitment] = []
        
        for id in commitmentIds {
            let descriptor = FetchDescriptor<Commitment>(
                predicate: #Predicate { $0.id == id }
            )
            
            if let commitment = try? context.fetch(descriptor).first {
                commitments.append(commitment)
            }
        }
        
        return commitments
    }
    
    func searchMeetings(_ query: String) async -> [MeetingSession] {
        let context = ModelContext(modelContainer)
        let vectorResults = await vectorDB.semanticSearch(query, limit: 20)
        
        let meetingIds = vectorResults
            .filter { $0.type == .meeting }
            .map { $0.id }
        
        var meetings: [MeetingSession] = []
        
        for id in meetingIds {
            let descriptor = FetchDescriptor<MeetingSession>(
                predicate: #Predicate { $0.id == id }
            )
            
            if let meeting = try? context.fetch(descriptor).first {
                meetings.append(meeting)
            }
        }
        
        return meetings
    }
    
    func globalSearch(_ query: String, limit: Int = 20) async -> GlobalSearchResults {
        // Perform comprehensive search across all data sources
        let semanticResults = await semanticSearch(query)
        let commitments = await searchCommitments(query)
        let meetings = await searchMeetings(query)
        let clipboardItems = await searchClipboardHistory(query)
        
        return GlobalSearchResults(
            semanticResults: Array(semanticResults.prefix(limit)),
            commitments: Array(commitments.prefix(5)),
            meetings: Array(meetings.prefix(5)),
            clipboardItems: Array(clipboardItems.prefix(5)),
            totalResults: semanticResults.count + commitments.count + meetings.count + clipboardItems.count
        )
    }
    
    // MARK: - Private Methods
    
    private func enhanceSearchQuery(_ query: String) async -> EnhancedSearchQuery {
        do {
            let prompt = searchEnhancementPrompt + query
            let response = try await model.respond(to: prompt)
            
            if let enhancedQuery = parseSearchEnhancementResponse(response.content) {
                return enhancedQuery
            }
        } catch {
            print("Failed to enhance search query: \(error)")
        }
        
        // Fallback to basic query enhancement
        return EnhancedSearchQuery(
            intent: "Find information related to: \(query)",
            searchSources: ["clipboard", "browser", "meetings", "commitments"],
            keywords: query.components(separatedBy: .whitespacesAndNewlines),
            timeConstraint: "all",
            expandedQuery: query
        )
    }
    
    private func parseSearchEnhancementResponse(_ response: String) -> EnhancedSearchQuery? {
        guard let data = response.data(using: .utf8) else { return nil }
        
        do {
            return try JSONDecoder().decode(EnhancedSearchQuery.self, from: data)
        } catch {
            print("Failed to parse search enhancement response: \(error)")
            return nil
        }
    }
    
    private func extractTitle(from result: VectorSearchResult) -> String {
        // Extract appropriate title based on content type
        switch result.type {
        case .commitment:
            return "Commitment: \(String(result.content.prefix(50)))..."
        case .meeting:
            return result.metadata["title"] as? String ?? "Meeting"
        case .clipboardItem:
            return "Clipboard: \(String(result.content.prefix(30)))..."
        case .screenCapture:
            return "Screen: \(result.metadata["detectedApp"] as? String ?? "Unknown App")"
        case .browserHistory:
            return result.metadata["title"] as? String ?? result.metadata["url"] as? String ?? "Web Page"
        }
    }
    
    private func generateEmbeddingForItem(_ item: Any) async -> [Float] {
        let embeddingGenerator = EmbeddingGenerator()
        
        // Extract text content based on item type
        let text: String
        
        if let commitment = item as? Commitment {
            text = commitment.description
        } else if let meeting = item as? MeetingSession {
            text = meeting.summary.isEmpty ? meeting.transcript : meeting.summary
        } else if let clipboardItem = item as? ClipboardItem {
            text = clipboardItem.content
        } else if let screenCapture = item as? ScreenCapture {
            text = screenCapture.extractedText
        } else {
            return []
        }
        
        return await embeddingGenerator.generateEmbedding(for: text)
    }
    
    private func determineRelationshipType(_ result: VectorSearchResult, to item: Any) -> RelationshipType {
        // Simple relationship determination
        // In a more sophisticated system, this would analyze the content and context
        
        if result.similarity > 0.9 {
            return .semantic
        } else if result.similarity > 0.7 {
            return .contextual
        } else {
            return .temporal
        }
    }
    
    private func convertToSearchResult(_ clipboardItem: ClipboardItem) -> SearchResult {
        return SearchResult(
            id: clipboardItem.id,
            title: "Clipboard: \(String(clipboardItem.content.prefix(30)))...",
            content: clipboardItem.content,
            type: .clipboardItem,
            relevanceScore: 0.8, // Default relevance for clipboard items
            timestamp: clipboardItem.timestamp,
            metadata: [
                "contentType": clipboardItem.contentType.rawValue,
                "sourceApp": clipboardItem.sourceApp ?? "Unknown"
            ]
        )
    }
    
    private func convertToSearchResult(_ browserItem: BrowserHistoryItem) -> SearchResult {
        return SearchResult(
            id: browserItem.id,
            title: browserItem.title,
            content: browserItem.url,
            type: .browserHistory,
            relevanceScore: 0.7, // Default relevance for browser history
            timestamp: browserItem.visitTime,
            metadata: [
                "url": browserItem.url,
                "visitCount": browserItem.visitCount
            ]
        )
    }
    
    private func sortByRelevance(_ results: [SearchResult]) -> [SearchResult] {
        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }
    
    private func applyTimeConstraints(_ results: [SearchResult], constraint: String) -> [SearchResult] {
        let now = Date()
        let calendar = Calendar.current
        
        let cutoffDate: Date
        
        switch constraint {
        case "recent":
            cutoffDate = calendar.date(byAdding: .hour, value: -24, to: now) ?? now
        case "today":
            cutoffDate = calendar.startOfDay(for: now)
        case "week":
            cutoffDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        case "month":
            cutoffDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        default: // "all"
            return results
        }
        
        return results.filter { $0.timestamp >= cutoffDate }
    }
}

// MARK: - Clipboard History Manager

class ClipboardHistoryManager {
    private let modelContainer: ModelContainer
    private var isMonitoring = false
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount = 0
    private var monitoringTimer: Timer?
    
    init(container: ModelContainer) {
        self.modelContainer = container
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        lastChangeCount = pasteboard.changeCount
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task {
                await self.checkForClipboardChanges()
            }
        }
        
        isMonitoring = true
        print("Clipboard monitoring started")
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        isMonitoring = false
        print("Clipboard monitoring stopped")
    }
    
    func searchHistory(_ query: String) async -> [ClipboardItem] {
        let context = ModelContext(modelContainer)
        let lowercaseQuery = query.lowercased()
        
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { 
                $0.content.localizedStandardContains(lowercaseQuery)
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to search clipboard history: \(error)")
            return []
        }
    }
    
    func getEmbedding(for item: ClipboardItem) async -> [Float] {
        if !item.embedding.isEmpty {
            return item.embedding
        }
        
        let embeddingGenerator = EmbeddingGenerator()
        let embedding = await embeddingGenerator.generateEmbedding(for: item.content)
        
        // Update the item with the generated embedding
        let context = ModelContext(modelContainer)
        item.embedding = embedding
        
        do {
            try context.save()
        } catch {
            print("Failed to save clipboard item embedding: \(error)")
        }
        
        return embedding
    }
    
    private func checkForClipboardChanges() async {
        let currentChangeCount = pasteboard.changeCount
        
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            await processClipboardContent()
        }
    }
    
    private func processClipboardContent() async {
        guard let content = pasteboard.string(forType: .string), !content.isEmpty else {
            return
        }
        
        // Determine content type
        let contentType: ClipboardContentType
        if content.hasPrefix("http://") || content.hasPrefix("https://") {
            contentType = .url
        } else if content.contains("\n") || content.count > 100 {
            contentType = .text
        } else {
            contentType = .text
        }
        
        // Get source application
        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
        
        // Create clipboard item
        let clipboardItem = ClipboardItem(
            content: content,
            contentType: contentType,
            sourceApp: sourceApp
        )
        
        // Generate embedding
        clipboardItem.embedding = await getEmbedding(for: clipboardItem)
        
        // Save to database
        let context = ModelContext(modelContainer)
        context.insert(clipboardItem)
        
        do {
            try context.save()
        } catch {
            print("Failed to save clipboard item: \(error)")
        }
    }
}

// MARK: - Browser History Reader

class BrowserHistoryReader {
    func search(_ query: String) async -> [BrowserHistoryItem] {
        // This would integrate with browser history databases
        // For now, return empty array as it requires specific browser integration
        return []
    }
    
    private func readSafariHistory() -> [BrowserHistoryItem] {
        // Would read from Safari's History.db
        return []
    }
    
    private func readChromeHistory() -> [BrowserHistoryItem] {
        // Would read from Chrome's History database
        return []
    }
}

// MARK: - Supporting Types

struct EnhancedSearchQuery: Codable {
    let intent: String
    let searchSources: [String]
    let keywords: [String]
    let timeConstraint: String
    let expandedQuery: String
}

struct GlobalSearchResults {
    let semanticResults: [SearchResult]
    let commitments: [Commitment]
    let meetings: [MeetingSession]
    let clipboardItems: [ClipboardItem]
    let totalResults: Int
}

struct BrowserHistoryItem {
    let id: UUID
    let url: String
    let title: String
    let visitTime: Date
    let visitCount: Int
    
    init(url: String, title: String, visitTime: Date, visitCount: Int = 1) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.visitTime = visitTime
        self.visitCount = visitCount
    }
}