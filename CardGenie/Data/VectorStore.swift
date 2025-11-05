//
//  VectorStore.swift
//  CardGenie
//
//  Local vector store for RAG (Retrieval-Augmented Generation).
//

import Foundation
import SwiftData

// MARK: - Vector Store

/// Simple in-memory vector store with cosine similarity search
@MainActor
final class VectorStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Search

    /// Find top-k most similar chunks to query
    func search(query: String, topK: Int = 6, embeddingEngine: EmbeddingEngine) async throws -> [NoteChunk] {
        // Get query embedding
        let queryEmbeddings = try await embeddingEngine.embed([query])
        guard let queryVector = queryEmbeddings.first else {
            return []
        }

        // Fetch all chunks with embeddings
        let descriptor = FetchDescriptor<NoteChunk>(
            predicate: #Predicate { chunk in
                chunk.embedding != nil
            }
        )

        let allChunks = try modelContext.fetch(descriptor)

        // Calculate cosine similarities
        var scored: [(chunk: NoteChunk, score: Float)] = []

        for chunk in allChunks {
            guard let chunkVector = chunk.getEmbedding() else { continue }

            let similarity = cosineSimilarity(queryVector, chunkVector)
            scored.append((chunk, similarity))
        }

        // Sort by score descending and take top-k
        let topChunks = scored
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map { $0.chunk }

        return Array(topChunks)
    }

    /// Search within specific source document
    func searchInSource(
        query: String,
        sourceID: UUID,
        topK: Int = 6,
        embeddingEngine: EmbeddingEngine
    ) async throws -> [NoteChunk] {
        let allResults = try await search(query: query, topK: topK * 2, embeddingEngine: embeddingEngine)

        return allResults
            .filter { $0.sourceDocument?.id == sourceID }
            .prefix(topK)
            .map { $0 }
    }

    // MARK: - Cosine Similarity

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
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

// MARK: - RAG Chat Manager

/// Manages chat interactions with local RAG
@MainActor
final class RAGChatManager {
    private let vectorStore: VectorStore
    private let llm: LLMEngine
    private let embedding: EmbeddingEngine

    init(
        vectorStore: VectorStore,
        llm: LLMEngine? = nil,
        embedding: EmbeddingEngine? = nil
    ) {
        self.vectorStore = vectorStore
        self.llm = llm ?? AIEngineFactory.createLLMEngine()
        self.embedding = embedding ?? AIEngineFactory.createEmbeddingEngine()
    }

    // MARK: - Chat

    /// Ask a question about the lecture/notes with RAG
    func ask(question: String, sourceID: UUID? = nil) async throws -> ChatResponse {
        // Retrieve relevant chunks
        let chunks: [NoteChunk]
        if let sourceID = sourceID {
            chunks = try await vectorStore.searchInSource(
                query: question,
                sourceID: sourceID,
                topK: 6,
                embeddingEngine: embedding
            )
        } else {
            chunks = try await vectorStore.search(
                query: question,
                topK: 6,
                embeddingEngine: embedding
            )
        }

        guard !chunks.isEmpty else {
            return ChatResponse(
                answer: "I couldn't find relevant information in your notes to answer this question.",
                citations: []
            )
        }

        // Build context from chunks
        let context = chunks.enumerated().map { index, chunk in
            var text = "[\(index + 1)] \(chunk.text)"

            // Add source metadata
            if let page = chunk.pageNumber {
                text += " (Page \(page))"
            } else if let timeRange = chunk.timeRange {
                text += " (\(timeRange.formatted))"
            }

            return text
        }.joined(separator: "\n\n")

        // Build prompt
        let prompt = """
        Answer the question using ONLY the information from the provided lecture notes.
        Cite your sources using [1], [2], etc. If the notes don't contain the answer, say so.

        LECTURE NOTES:
        \(context)

        QUESTION: \(question)

        ANSWER (cite sources):
        """

        // Get LLM response
        let answer = try await llm.complete(prompt)

        // Build citations
        let citations = chunks.enumerated().map { index, chunk in
            Citation(
                index: index + 1,
                text: chunk.text.prefix(200),
                pageNumber: chunk.pageNumber,
                timeRange: chunk.timeRange,
                sourceDocument: chunk.sourceDocument
            )
        }

        return ChatResponse(answer: answer, citations: citations)
    }
}

// MARK: - Chat Response

struct ChatResponse {
    let answer: String
    let citations: [Citation]
}

struct Citation {
    let index: Int
    let text: String.SubSequence
    let pageNumber: Int?
    let timeRange: TimestampRange?
    let sourceDocument: SourceDocument?

    var displayText: String {
        var text = "[\(index)]"

        if let page = pageNumber {
            text += " Page \(page)"
        } else if let time = timeRange {
            text += " \(time.formatted)"
        }

        if let source = sourceDocument {
            text += " - \(source.fileName)"
        }

        return text
    }
}
