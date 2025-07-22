import Foundation
import SwiftData
import NaturalLanguage
import Accelerate

// MARK: - Error Types

enum VectorDatabaseError: Error {
    case unsupportedItemType
    case embeddingGenerationFailed
    case storageError(String)
    case searchError(String)
}

class VectorDatabase {
    private let modelContainer: ModelContainer
    private let embeddingGenerator: EmbeddingGenerator
    private let searchEngine: VectorSearchEngine
    
    // Performance settings
    private let maxVectorDimensions = 1536
    private let searchLimit = 64
    private let similarityThreshold: Float = 0.7
    
    init(container: ModelContainer) {
        self.modelContainer = container
        self.embeddingGenerator = EmbeddingGenerator()
        self.searchEngine = VectorSearchEngine()
    }
    
    // MARK: - Storage Operations
    
    func store<T: VectorStorable>(_ item: inout T) async throws {
        // Generate embedding if not present
        if item.embedding.isEmpty {
            let embedding = await item.generateEmbedding()
            item.embedding = embedding
        }
        
        // Use appropriate ModelActor for thread-safe storage
        switch item {
        case let commitment as Commitment:
            let actor = CommitmentActor(modelContainer: modelContainer)
            await actor.saveCommitment(commitment)
        case let screenCapture as ScreenCapture:
            let actor = ScreenCaptureActor(modelContainer: modelContainer)
            await actor.saveScreenCapture(screenCapture)
        case let clipboardItem as ClipboardItem:
            let actor = ClipboardItemActor(modelContainer: modelContainer)
            await actor.saveClipboardItem(clipboardItem)
        case let meetingSession as MeetingSession:
            let actor = MeetingSessionActor(modelContainer: modelContainer)
            await actor.saveMeetingSession(meetingSession)
        default:
            throw VectorDatabaseError.unsupportedItemType
        }
    }
    
    func storeBatch<T: VectorStorable>(_ items: [T]) async throws {
        for var item in items {
            try await store(&item)
        }
    }
    
    // MARK: - Search Operations
    
    func search(_ query: [Float], limit: Int = 10) async -> [VectorSearchResult] {
        let context = ModelContext(modelContainer)
        
        // Search across all vector-enabled models
        var results: [VectorSearchResult] = []
        
        // Search commitments
        results.append(contentsOf: await searchCommitments(query, context: context, limit: limit))
        
        // Search meetings
        results.append(contentsOf: await searchMeetings(query, context: context, limit: limit))
        
        // Search clipboard items
        results.append(contentsOf: await searchClipboardItems(query, context: context, limit: limit))
        
        // Search screen captures
        results.append(contentsOf: await searchScreenCaptures(query, context: context, limit: limit))
        
        // Sort by similarity and return top results
        return Array(results.sorted { $0.similarity > $1.similarity }.prefix(limit))
    }
    
    func semanticSearch(_ text: String, limit: Int = 10) async -> [VectorSearchResult] {
        let embedding = await embeddingGenerator.generateEmbedding(for: text)
        return await search(embedding, limit: limit)
    }
    
    func findSimilar<T: VectorStorable>(to item: T, limit: Int = 5) async -> [T] {
        guard !item.embedding.isEmpty else { return [] }
        
        let results = await search(item.embedding, limit: limit + 1) // +1 to exclude self
        let context = ModelContext(modelContainer)
        
        var similarItems: [T] = []
        
        for result in results {
            // For models with UUID id, compare directly
            let itemId = (item as? Commitment)?.id ?? UUID()
            if result.id != itemId {
                // Handle specific model types
                if T.self == Commitment.self {
                    if let foundCommitment = try? context.fetch(FetchDescriptor<Commitment>()).first(where: { commitment in
                        return commitment.id == result.id
                    }) {
                        if let typedItem = foundCommitment as? T {
                            similarItems.append(typedItem)
                        }
                    }
                }
            }
        }
        
        return Array(similarItems.prefix(limit))
    }
    
    // MARK: - Hybrid Search (BM25 + Semantic)
    
    func hybridSearch(_ text: String, limit: Int = 10) async -> [VectorSearchResult] {
        // Combine keyword search (BM25-like) with semantic search
        let semanticResults = await semanticSearch(text, limit: limit * 2)
        let keywordResults = await keywordSearch(text, limit: limit * 2)
        
        // Merge and rank using Reciprocal Rank Fusion (RRF)
        return mergeSearchResults(semanticResults: semanticResults, keywordResults: keywordResults, limit: limit)
    }
    
    // MARK: - Private Implementation
    
    private func searchCommitments(_ query: [Float], context: ModelContext, limit: Int) async -> [VectorSearchResult] {
        let descriptor = FetchDescriptor<Commitment>()
        
        do {
            let commitments = try context.fetch(descriptor)
            return commitments.compactMap { commitment in
                guard !commitment.embedding.isEmpty else { return nil }
                let similarity = cosineSimilarity(query, commitment.embedding)
                guard similarity > similarityThreshold else { return nil }
                
                return VectorSearchResult(
                    id: commitment.id,
                    similarity: similarity,
                    content: commitment.commitmentText,
                    metadata: [
                        "recipient": commitment.recipient,
                        "status": commitment.status.rawValue,
                        "priority": String(commitment.priority.rawValue)
                    ],
                    type: .commitment
                )
            }.sorted { $0.similarity > $1.similarity }
        } catch {
            print("Error searching commitments: \(error)")
            return []
        }
    }
    
    private func searchMeetings(_ query: [Float], context: ModelContext, limit: Int) async -> [VectorSearchResult] {
        let descriptor = FetchDescriptor<MeetingSession>()
        
        do {
            let meetings = try context.fetch(descriptor)
            return meetings.compactMap { meeting in
                guard !meeting.embedding.isEmpty else { return nil }
                let similarity = cosineSimilarity(query, meeting.embedding)
                guard similarity > similarityThreshold else { return nil }
                
                return VectorSearchResult(
                    id: meeting.id,
                    similarity: similarity,
                    content: meeting.summary.isEmpty ? meeting.transcript : meeting.summary,
                    metadata: [
                        "title": meeting.title,
                        "participants": meeting.participants.joined(separator: ", "),
                        "startTime": meeting.startTime.ISO8601Format()
                    ],
                    type: .meeting
                )
            }.sorted { $0.similarity > $1.similarity }
        } catch {
            print("Error searching meetings: \(error)")
            return []
        }
    }
    
    private func searchClipboardItems(_ query: [Float], context: ModelContext, limit: Int) async -> [VectorSearchResult] {
        let descriptor = FetchDescriptor<ClipboardItem>()
        
        do {
            let items = try context.fetch(descriptor)
            return items.compactMap { item in
                guard !item.embedding.isEmpty else { return nil }
                let similarity = cosineSimilarity(query, item.embedding)
                guard similarity > similarityThreshold else { return nil }
                
                return VectorSearchResult(
                    id: item.id,
                    similarity: similarity,
                    content: item.content,
                    metadata: [
                        "contentType": item.contentType.rawValue,
                        "sourceApp": item.sourceApp ?? "Unknown",
                        "timestamp": item.timestamp.ISO8601Format()
                    ],
                    type: .clipboardItem
                )
            }.sorted { $0.similarity > $1.similarity }
        } catch {
            print("Error searching clipboard items: \(error)")
            return []
        }
    }
    
    private func searchScreenCaptures(_ query: [Float], context: ModelContext, limit: Int) async -> [VectorSearchResult] {
        let descriptor = FetchDescriptor<ScreenCapture>()
        
        do {
            let captures = try context.fetch(descriptor)
            return captures.compactMap { capture in
                guard !capture.embedding.isEmpty else { return nil }
                let similarity = cosineSimilarity(query, capture.embedding)
                guard similarity > similarityThreshold else { return nil }
                
                return VectorSearchResult(
                    id: capture.id,
                    similarity: similarity,
                    content: capture.extractedText,
                    metadata: [
                        "detectedApp": capture.detectedApp,
                        "timestamp": capture.timestamp.ISO8601Format()
                    ],
                    type: .screenCapture
                )
            }.sorted { $0.similarity > $1.similarity }
        } catch {
            print("Error searching screen captures: \(error)")
            return []
        }
    }
    
    private func keywordSearch(_ text: String, limit: Int) async -> [VectorSearchResult] {
        // Simple keyword-based search implementation
        // In a production system, this would use a proper BM25 implementation
        let context = ModelContext(modelContainer)
        let keywords = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        var results: [VectorSearchResult] = []
        
        // Search in commitments
        let commitmentDescriptor = FetchDescriptor<Commitment>()
        if let commitments = try? context.fetch(commitmentDescriptor) {
            for commitment in commitments {
                let score = calculateKeywordScore(keywords, in: commitment.commitmentText.lowercased())
                if score > 0 {
                    results.append(VectorSearchResult(
                        id: commitment.id,
                        similarity: Float(score),
                        content: commitment.commitmentText,
                        metadata: ["type": "commitment"],
                        type: .commitment
                    ))
                }
            }
        }
        
        return Array(results.sorted { $0.similarity > $1.similarity }.prefix(limit))
    }
    
    private func calculateKeywordScore(_ keywords: [String], in text: String) -> Double {
        var score = 0.0
        let textWords = text.components(separatedBy: .whitespacesAndNewlines)
        
        for keyword in keywords {
            let matches = textWords.filter { $0.contains(keyword) }.count
            score += Double(matches) / Double(textWords.count)
        }
        
        return score / Double(keywords.count)
    }
    
    private func mergeSearchResults(semanticResults: [VectorSearchResult], keywordResults: [VectorSearchResult], limit: Int) -> [VectorSearchResult] {
        // Reciprocal Rank Fusion implementation
        var combinedScores: [UUID: Double] = [:]
        
        // Add semantic scores
        for (index, result) in semanticResults.enumerated() {
            combinedScores[result.id, default: 0] += 1.0 / Double(index + 1)
        }
        
        // Add keyword scores
        for (index, result) in keywordResults.enumerated() {
            combinedScores[result.id, default: 0] += 1.0 / Double(index + 1)
        }
        
        // Create merged results (deduplicate by id)
        var seenIds: Set<UUID> = []
        var allResults: [VectorSearchResult] = []
        
        for result in semanticResults + keywordResults {
            if !seenIds.contains(result.id) {
                allResults.append(result)
                seenIds.insert(result.id)
            }
        }
        let sortedResults = allResults.sorted { 
            combinedScores[$0.id, default: 0] > combinedScores[$1.id, default: 0]
        }
        
        return Array(sortedResults.prefix(limit))
    }
    
    // MARK: - Utility Functions
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count && !a.isEmpty else { return 0.0 }
        
        var dotProduct: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0
        
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_svesq(a, 1, &normA, vDSP_Length(a.count))
        vDSP_svesq(b, 1, &normB, vDSP_Length(b.count))
        
        let magnitude = sqrt(normA * normB)
        return magnitude > 0 ? dotProduct / magnitude : 0.0
    }
}

// MARK: - Supporting Classes

class EmbeddingGenerator {
    private let embeddingModel: NLEmbedding?
    
    init() {
        // Initialize with local embedding model
        self.embeddingModel = NLEmbedding.wordEmbedding(for: .english)
    }
    
    func generateEmbedding(for text: String) async -> [Float] {
        guard let embeddingModel = embeddingModel else {
            return []
        }
        
        // For longer texts, use a more sophisticated approach
        if text.count > 512 {
            return await generateChunkedEmbedding(for: text)
        }
        
        // Get embedding vector
        if let vector = embeddingModel.vector(for: text) {
            return vector.map { Float($0) }
        }
        
        return []
    }
    
    private func generateChunkedEmbedding(for text: String) async -> [Float] {
        let chunks = chunkText(text, maxLength: 512)
        var embeddings: [[Float]] = []
        
        for chunk in chunks {
            if let vector = embeddingModel?.vector(for: chunk) {
                embeddings.append(vector.map { Float($0) })
            }
        }
        
        // Average the embeddings
        return averageEmbeddings(embeddings)
    }
    
    private func chunkText(_ text: String, maxLength: Int) -> [String] {
        let sentences = text.components(separatedBy: ". ")
        var chunks: [String] = []
        var currentChunk = ""
        
        for sentence in sentences {
            if (currentChunk + sentence).count <= maxLength {
                currentChunk += (currentChunk.isEmpty ? "" : ". ") + sentence
            } else {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                currentChunk = sentence
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks
    }
    
    private func averageEmbeddings(_ embeddings: [[Float]]) -> [Float] {
        guard !embeddings.isEmpty else { return [] }
        
        let dimensions = embeddings[0].count
        var averaged = Array(repeating: Float(0), count: dimensions)
        
        for embedding in embeddings {
            for i in 0..<dimensions {
                averaged[i] += embedding[i]
            }
        }
        
        let count = Float(embeddings.count)
        for i in 0..<dimensions {
            averaged[i] /= count
        }
        
        return averaged
    }
}

class VectorSearchEngine {
    // This would implement HNSW or other efficient vector search algorithms
    // For now, we'll use brute force search with cosine similarity
    
    func search(query: [Float], in vectors: [[Float]], limit: Int) -> [(index: Int, similarity: Float)] {
        var results: [(index: Int, similarity: Float)] = []
        
        for (index, vector) in vectors.enumerated() {
            let similarity = cosineSimilarity(query, vector)
            results.append((index: index, similarity: similarity))
        }
        
        return Array(results.sorted { $0.similarity > $1.similarity }.prefix(limit))
    }
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count && !a.isEmpty else { return 0.0 }
        
        var dotProduct: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0
        
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_svesq(a, 1, &normA, vDSP_Length(a.count))
        vDSP_svesq(b, 1, &normB, vDSP_Length(b.count))
        
        let magnitude = sqrt(normA * normB)
        return magnitude > 0 ? dotProduct / magnitude : 0.0
    }
}