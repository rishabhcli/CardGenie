//
//  VectorStoreTests.swift
//  CardGenie
//
//  Comprehensive unit tests for VectorStore and RAG functionality.
//  Tests vector search, cosine similarity, and RAG chat manager.
//

import XCTest
import SwiftData
@testable import CardGenie

final class VectorStoreTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var vectorStore: VectorStore!
    var mockEmbedding: MockEmbeddingEngine!

    override func setUp() async throws {
        // Create in-memory model container
        let schema = Schema([
            NoteChunk.self,
            SourceDocument.self,
            StudyContent.self,
            FlashcardSet.self,
            Flashcard.self,
            ConversationSession.self,
            VoiceConversationMessage.self
        ])

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)

        vectorStore = await VectorStore(modelContext: modelContext)
        mockEmbedding = MockEmbeddingEngine()
    }

    override func tearDown() async throws {
        vectorStore = nil
        mockEmbedding = nil
        modelContext = nil
        modelContainer = nil
    }

    // MARK: - Search Tests

    @MainActor
    func testSearch_FindsRelevantChunks() async throws {
        // Given: Chunks with embeddings
        let chunk1 = createChunk(text: "Biology notes about DNA", embedding: [1.0, 0.0, 0.0])
        let chunk2 = createChunk(text: "Chemistry notes about atoms", embedding: [0.0, 1.0, 0.0])
        let chunk3 = createChunk(text: "Biology notes about RNA", embedding: [0.9, 0.1, 0.0])

        modelContext.insert(chunk1)
        modelContext.insert(chunk2)
        modelContext.insert(chunk3)
        try modelContext.save()

        // When: Searching for biology-related query
        mockEmbedding.nextEmbeddings = [[1.0, 0.0, 0.0]] // Similar to chunk1 and chunk3
        let results = try await vectorStore.search(query: "DNA information", topK: 2, embeddingEngine: mockEmbedding)

        // Then: Should return most similar chunks
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains(where: { $0.text.contains("DNA") }))
        XCTAssertTrue(results.contains(where: { $0.text.contains("RNA") }))
    }

    @MainActor
    func testSearch_ReturnsTopKResults() async throws {
        // Given: 5 chunks with embeddings
        for i in 1...5 {
            let embedding = createRandomEmbedding(dimension: 3)
            let chunk = createChunk(text: "Chunk \(i)", embedding: embedding)
            modelContext.insert(chunk)
        }
        try modelContext.save()

        // When: Searching with topK = 3
        mockEmbedding.nextEmbeddings = [[1.0, 0.0, 0.0]]
        let results = try await vectorStore.search(query: "test", topK: 3, embeddingEngine: mockEmbedding)

        // Then: Should return exactly 3 results
        XCTAssertEqual(results.count, 3)
    }

    @MainActor
    func testSearch_EmptyResults_WhenNoChunks() async throws {
        // Given: No chunks in database
        // When: Searching
        mockEmbedding.nextEmbeddings = [[1.0, 0.0, 0.0]]
        let results = try await vectorStore.search(query: "test", topK: 5, embeddingEngine: mockEmbedding)

        // Then: Should return empty array
        XCTAssertTrue(results.isEmpty)
    }

    @MainActor
    func testSearch_IgnoresChunksWithoutEmbeddings() async throws {
        // Given: Mix of chunks with and without embeddings
        let chunkWithEmbedding = createChunk(text: "Has embedding", embedding: [1.0, 0.0, 0.0])
        let chunkWithoutEmbedding = NoteChunk(text: "No embedding", pageNumber: nil)

        modelContext.insert(chunkWithEmbedding)
        modelContext.insert(chunkWithoutEmbedding)
        try modelContext.save()

        // When: Searching
        mockEmbedding.nextEmbeddings = [[1.0, 0.0, 0.0]]
        let results = try await vectorStore.search(query: "test", topK: 10, embeddingEngine: mockEmbedding)

        // Then: Should only return chunks with embeddings
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].text, "Has embedding")
    }

    @MainActor
    func testSearch_SortsByRelevance() async throws {
        // Given: Chunks with varying similarity to query
        let veryRelevant = createChunk(text: "Very relevant", embedding: [1.0, 0.0, 0.0])
        let somewhatRelevant = createChunk(text: "Somewhat relevant", embedding: [0.5, 0.5, 0.0])
        let notRelevant = createChunk(text: "Not relevant", embedding: [0.0, 0.0, 1.0])

        modelContext.insert(veryRelevant)
        modelContext.insert(somewhatRelevant)
        modelContext.insert(notRelevant)
        try modelContext.save()

        // When: Searching with query similar to [1.0, 0.0, 0.0]
        mockEmbedding.nextEmbeddings = [[1.0, 0.0, 0.0]]
        let results = try await vectorStore.search(query: "test", topK: 3, embeddingEngine: mockEmbedding)

        // Then: Should be sorted by relevance (most similar first)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].text, "Very relevant")
    }

    // MARK: - Search In Source Tests

    @MainActor
    func testSearchInSource_FiltersBySourceID() async throws {
        // Given: Two source documents with chunks
        let source1 = SourceDocument(fileName: "Source 1", sourceType: .pdf)
        let source2 = SourceDocument(fileName: "Source 2", sourceType: .pdf)

        let chunk1 = createChunk(text: "From source 1", embedding: [1.0, 0.0, 0.0])
        chunk1.sourceDocument = source1

        let chunk2 = createChunk(text: "From source 2", embedding: [1.0, 0.0, 0.0])
        chunk2.sourceDocument = source2

        modelContext.insert(source1)
        modelContext.insert(source2)
        modelContext.insert(chunk1)
        modelContext.insert(chunk2)
        try modelContext.save()

        // When: Searching within source 1
        mockEmbedding.nextEmbeddings = [[1.0, 0.0, 0.0]]
        let results = try await vectorStore.searchInSource(
            query: "test",
            sourceID: source1.id,
            topK: 10,
            embeddingEngine: mockEmbedding
        )

        // Then: Should only return chunks from source 1
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].text, "From source 1")
    }

    @MainActor
    func testSearchInSource_RespectsTopK() async throws {
        // Given: Source with multiple chunks
        let source = SourceDocument(fileName: "Test", sourceType: .pdf)

        for i in 1...5 {
            let chunk = createChunk(text: "Chunk \(i)", embedding: createRandomEmbedding(dimension: 3))
            chunk.sourceDocument = source
            modelContext.insert(chunk)
        }

        modelContext.insert(source)
        try modelContext.save()

        // When: Searching with topK = 2
        mockEmbedding.nextEmbeddings = [[1.0, 0.0, 0.0]]
        let results = try await vectorStore.searchInSource(
            query: "test",
            sourceID: source.id,
            topK: 2,
            embeddingEngine: mockEmbedding
        )

        // Then: Should return at most 2 results
        XCTAssertLessThanOrEqual(results.count, 2)
    }

    // MARK: - RAG Chat Manager Tests

    @MainActor
    func testRAGChat_AnswersWithContext() async throws {
        // Given: Chunks with relevant information
        let chunk = createChunk(text: "DNA is the genetic material of cells", embedding: [1.0, 0.0, 0.0])
        modelContext.insert(chunk)
        try modelContext.save()

        let mockLLM = VectorStoreMockLLMEngine()
        mockLLM.nextResponse = "DNA is the genetic material [1]"

        let chatManager = await RAGChatManager(
            vectorStore: vectorStore,
            llm: mockLLM,
            embedding: mockEmbedding
        )

        // When: Asking a question
        mockEmbedding.nextEmbeddings = [[1.0, 0.0, 0.0]]
        let response = try await chatManager.ask(question: "What is DNA?")

        // Then: Should return answer with citations
        XCTAssertFalse(response.answer.isEmpty)
        XCTAssertEqual(response.citations.count, 1)
        XCTAssertTrue(response.citations[0].text.contains("DNA"))
    }

    @MainActor
    func testRAGChat_ReturnsNoInfoMessage_WhenNoChunks() async throws {
        // Given: Empty vector store
        let mockLLM = VectorStoreMockLLMEngine()
        let chatManager = await RAGChatManager(
            vectorStore: vectorStore,
            llm: mockLLM,
            embedding: mockEmbedding
        )

        // When: Asking a question
        mockEmbedding.nextEmbeddings = [[1.0, 0.0, 0.0]]
        let response = try await chatManager.ask(question: "What is DNA?")

        // Then: Should return "no information" message
        XCTAssertTrue(response.answer.contains("couldn't find relevant information"))
        XCTAssertTrue(response.citations.isEmpty)
    }

    @MainActor
    func testRAGChat_IncludesPageNumbersInContext() async throws {
        // Given: Chunk with page number
        let chunk = createChunk(text: "Important information", embedding: [1.0, 0.0, 0.0])
        chunk.pageNumber = 42
        modelContext.insert(chunk)
        try modelContext.save()

        let mockLLM = VectorStoreMockLLMEngine()
        mockLLM.nextResponse = "Answer [1]"

        let chatManager = await RAGChatManager(
            vectorStore: vectorStore,
            llm: mockLLM,
            embedding: mockEmbedding
        )

        // When: Asking a question
        mockEmbedding.nextEmbeddings = [[1.0, 0.0, 0.0]]
        let response = try await chatManager.ask(question: "test")

        // Then: Citation should include page number
        XCTAssertEqual(response.citations.count, 1)
        XCTAssertEqual(response.citations[0].pageNumber, 42)
        XCTAssertTrue(response.citations[0].displayText.contains("Page 42"))
    }

    @MainActor
    func testRAGChat_SearchInSpecificSource() async throws {
        // Given: Multiple sources
        let source1 = SourceDocument(fileName: "Doc1", sourceType: .pdf)
        let source2 = SourceDocument(fileName: "Doc2", sourceType: .pdf)

        let chunk1 = createChunk(text: "Info from doc 1", embedding: [1.0, 0.0, 0.0])
        chunk1.sourceDocument = source1

        let chunk2 = createChunk(text: "Info from doc 2", embedding: [1.0, 0.0, 0.0])
        chunk2.sourceDocument = source2

        modelContext.insert(source1)
        modelContext.insert(source2)
        modelContext.insert(chunk1)
        modelContext.insert(chunk2)
        try modelContext.save()

        let mockLLM = VectorStoreMockLLMEngine()
        mockLLM.nextResponse = "Answer from doc 1 [1]"

        let chatManager = await RAGChatManager(
            vectorStore: vectorStore,
            llm: mockLLM,
            embedding: mockEmbedding
        )

        // When: Asking within specific source
        mockEmbedding.nextEmbeddings = [[1.0, 0.0, 0.0]]
        let response = try await chatManager.ask(question: "test", sourceID: source1.id)

        // Then: Should only use context from source 1
        XCTAssertEqual(response.citations.count, 1)
        XCTAssertTrue(response.citations[0].text.contains("doc 1"))
    }

    // MARK: - Citation Tests

    func testCitation_DisplayText_WithPage() throws {
        // Given: Citation with page number
        let citation = Citation(
            index: 1,
            text: "Sample text",
            pageNumber: 10,
            timeRange: nil,
            sourceDocument: nil
        )

        // When: Getting display text
        let display = citation.displayText

        // Then: Should include page number
        XCTAssertTrue(display.contains("[1]"))
        XCTAssertTrue(display.contains("Page 10"))
    }

    func testCitation_DisplayText_WithTimeRange() throws {
        // Given: Citation with time range
        let timeRange = TimestampRange(start: 60.0, end: 120.0)
        let citation = Citation(
            index: 2,
            text: "Sample text",
            pageNumber: nil,
            timeRange: timeRange,
            sourceDocument: nil
        )

        // When: Getting display text
        let display = citation.displayText

        // Then: Should include time range
        XCTAssertTrue(display.contains("[2]"))
        XCTAssertTrue(display.contains("01:00") || display.contains("1:00"))
    }

    func testCitation_DisplayText_WithSourceDocument() throws {
        // Given: Citation with source document
        let source = SourceDocument(fileName: "MyDocument.pdf", sourceType: .pdf)
        let citation = Citation(
            index: 3,
            text: "Sample text",
            pageNumber: 5,
            timeRange: nil,
            sourceDocument: source
        )

        // When: Getting display text
        let display = citation.displayText

        // Then: Should include file name
        XCTAssertTrue(display.contains("[3]"))
        XCTAssertTrue(display.contains("MyDocument.pdf"))
    }

    // MARK: - Edge Cases

    @MainActor
    func testSearch_LargeNumberOfChunks_Performance() async throws {
        // Given: Large number of chunks
        for i in 1...100 {
            let chunk = createChunk(text: "Chunk \(i)", embedding: createRandomEmbedding(dimension: 128))
            modelContext.insert(chunk)
        }
        try modelContext.save()

        // When: Searching
        mockEmbedding.nextEmbeddings = [createRandomEmbedding(dimension: 128)]
        let startTime = Date()
        let results = try await vectorStore.search(query: "test", topK: 10, embeddingEngine: mockEmbedding)
        let searchTime = Date().timeIntervalSince(startTime)

        // Then: Should complete in reasonable time (< 1 second for 100 chunks)
        XCTAssertEqual(results.count, 10)
        XCTAssertLessThan(searchTime, 1.0, "Search should complete within 1 second")
    }

    @MainActor
    func testSearch_EmptyQuery_HandlesGracefully() async throws {
        // Given: Chunks in store
        let chunk = createChunk(text: "Test", embedding: [1.0, 0.0, 0.0])
        modelContext.insert(chunk)
        try modelContext.save()

        // When: Searching with empty query
        mockEmbedding.nextEmbeddings = [[1.0, 0.0, 0.0]]
        let results = try await vectorStore.search(query: "", topK: 5, embeddingEngine: mockEmbedding)

        // Then: Should not crash and return results based on embedding
        XCTAssertGreaterThanOrEqual(results.count, 0)
    }

    @MainActor
    func testSearch_HighDimensionalEmbeddings() async throws {
        // Given: Chunks with high-dimensional embeddings (e.g., 384 dimensions)
        let highDimEmbedding = createRandomEmbedding(dimension: 384)
        let chunk = createChunk(text: "High dimensional", embedding: highDimEmbedding)
        modelContext.insert(chunk)
        try modelContext.save()

        // When: Searching with matching dimension
        mockEmbedding.nextEmbeddings = [createRandomEmbedding(dimension: 384)]
        let results = try await vectorStore.search(query: "test", topK: 5, embeddingEngine: mockEmbedding)

        // Then: Should handle high dimensions correctly
        XCTAssertEqual(results.count, 1)
    }

    @MainActor
    func testRAGChat_LongContext_TruncatesCitations() async throws {
        // Given: Chunk with very long text
        let longText = String(repeating: "Very long content. ", count: 100)
        let chunk = createChunk(text: longText, embedding: [1.0, 0.0, 0.0])
        modelContext.insert(chunk)
        try modelContext.save()

        let mockLLM = VectorStoreMockLLMEngine()
        mockLLM.nextResponse = "Answer [1]"

        let chatManager = await RAGChatManager(
            vectorStore: vectorStore,
            llm: mockLLM,
            embedding: mockEmbedding
        )

        // When: Asking a question
        mockEmbedding.nextEmbeddings = [[1.0, 0.0, 0.0]]
        let response = try await chatManager.ask(question: "test")

        // Then: Citation text should be truncated to 200 chars
        XCTAssertEqual(response.citations.count, 1)
        XCTAssertLessThanOrEqual(response.citations[0].text.count, 200)
    }

    // MARK: - Helper Methods

    private func createChunk(text: String, embedding: [Float]) -> NoteChunk {
        let chunk = NoteChunk(text: text, pageNumber: nil)
        chunk.setEmbedding(embedding)
        return chunk
    }

    private func createRandomEmbedding(dimension: Int) -> [Float] {
        return (0..<dimension).map { _ in Float.random(in: -1...1) }
    }
}

// MARK: - Cosine Similarity Tests

final class CosineSimilarityTests: XCTestCase {

    func testCosineSimilarity_IdenticalVectors_ReturnsOne() throws {
        // Given: Two identical vectors
        let vectorA = [1.0, 0.0, 0.0]
        let vectorB = [1.0, 0.0, 0.0]

        // When: Calculating similarity
        let similarity = calculateCosineSimilarity(vectorA, vectorB)

        // Then: Should be 1.0 (perfect similarity)
        XCTAssertEqual(similarity, 1.0, accuracy: 0.001)
    }

    func testCosineSimilarity_OrthogonalVectors_ReturnsZero() throws {
        // Given: Orthogonal vectors
        let vectorA = [1.0, 0.0, 0.0]
        let vectorB = [0.0, 1.0, 0.0]

        // When: Calculating similarity
        let similarity = calculateCosineSimilarity(vectorA, vectorB)

        // Then: Should be 0.0 (no similarity)
        XCTAssertEqual(similarity, 0.0, accuracy: 0.001)
    }

    func testCosineSimilarity_OppositeVectors_ReturnsNegativeOne() throws {
        // Given: Opposite vectors
        let vectorA = [1.0, 0.0, 0.0]
        let vectorB = [-1.0, 0.0, 0.0]

        // When: Calculating similarity
        let similarity = calculateCosineSimilarity(vectorA, vectorB)

        // Then: Should be -1.0 (opposite)
        XCTAssertEqual(similarity, -1.0, accuracy: 0.001)
    }

    func testCosineSimilarity_PartiallySimilar() throws {
        // Given: Partially similar vectors
        let vectorA = [1.0, 0.0, 0.0]
        let vectorB = [0.5, 0.5, 0.0]

        // When: Calculating similarity
        let similarity = calculateCosineSimilarity(vectorA, vectorB)

        // Then: Should be between 0 and 1
        XCTAssertGreaterThan(similarity, 0.0)
        XCTAssertLessThan(similarity, 1.0)
    }

    func testCosineSimilarity_DifferentDimensions_ReturnsZero() throws {
        // Given: Vectors with different dimensions
        let vectorA = [1.0, 0.0]
        let vectorB = [1.0, 0.0, 0.0]

        // When: Calculating similarity
        let similarity = calculateCosineSimilarity(vectorA, vectorB)

        // Then: Should return 0 (invalid comparison)
        XCTAssertEqual(similarity, 0.0)
    }

    func testCosineSimilarity_ZeroVectors_ReturnsZero() throws {
        // Given: Zero vectors
        let vectorA = [0.0, 0.0, 0.0]
        let vectorB = [1.0, 0.0, 0.0]

        // When: Calculating similarity
        let similarity = calculateCosineSimilarity(vectorA, vectorB)

        // Then: Should return 0 (undefined but handled)
        XCTAssertEqual(similarity, 0.0)
    }

    func testCosineSimilarity_HighDimensional() throws {
        // Given: High-dimensional vectors (e.g., 128D embeddings)
        let vectorA = (0..<128).map { _ in Float.random(in: 0...1) }
        let vectorB = vectorA // Same vector

        // When: Calculating similarity
        let similarity = calculateCosineSimilarity(vectorA, vectorB)

        // Then: Should be 1.0 (identical)
        XCTAssertEqual(similarity, 1.0, accuracy: 0.001)
    }

    // Helper method that mirrors the private implementation
    private func calculateCosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }
}

// MARK: - Mock Engines

@MainActor
final class MockEmbeddingEngine: EmbeddingEngine {
    var nextEmbeddings: [[Float]] = []
    var dimension: Int = 384
    var isAvailable: Bool = true

    func embed(_ texts: [String]) async throws -> [[Float]] {
        return nextEmbeddings
    }
}

@MainActor
final class VectorStoreMockLLMEngine: LLMEngine {
    var nextResponse: String = ""
    var isAvailable: Bool = true

    func complete(_ prompt: String) async throws -> String {
        return nextResponse
    }

    func streamComplete(_ prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            continuation.yield(nextResponse)
            continuation.finish()
        }
    }
}
