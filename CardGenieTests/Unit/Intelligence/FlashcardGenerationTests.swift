//
//  FlashcardGenerationTests.swift
//  CardGenieTests
//
//  Tests for flashcard generation pipeline from content to cards.
//

import XCTest
import SwiftData
@testable import CardGenie

@MainActor
final class FlashcardGenerationTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var generator: FlashcardGenerator!

    override func setUp() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Flashcard.self, FlashcardSet.self, NoteChunk.self, SourceDocument.self,
            configurations: configuration
        )
        context = ModelContext(container)

        // Use mock LLM for testing
        generator = FlashcardGenerator(llm: MockLLMEngine())
    }

    override func tearDown() async throws {
        generator = nil
        container = nil
        context = nil
    }

    // MARK: - Card Generation Tests

    func testGenerateCardsFromSingleChunk() async throws {
        let chunk = createTestChunk(text: "Paris is the capital of France. It is located on the Seine River.")
        let deck = createTestDeck()

        let cards = try await generator.generateCards(from: [chunk], deck: deck)

        XCTAssertFalse(cards.isEmpty, "Should generate at least one card")
        XCTAssertTrue(deck.cards.count > 0, "Deck should contain generated cards")

        // Verify cards have required properties
        for card in cards {
            XCTAssertFalse(card.question.isEmpty, "Card should have a question")
            XCTAssertFalse(card.answer.isEmpty, "Card should have an answer")
            XCTAssertNotNil(card.set, "Card should belong to a set")
            XCTAssertEqual(card.linkedEntryID, chunk.id, "Card should link back to source chunk")
        }
    }

    func testGenerateCardsFromMultipleChunks() async throws {
        let chunks = [
            createTestChunk(text: "Rome is the capital of Italy."),
            createTestChunk(text: "Tokyo is the capital of Japan."),
            createTestChunk(text: "Berlin is the capital of Germany.")
        ]
        let deck = createTestDeck()

        let cards = try await generator.generateCards(from: chunks, deck: deck)

        XCTAssertGreaterThanOrEqual(cards.count, chunks.count, "Should generate at least one card per chunk")
    }

    func testGeneratedCardTypes() async throws {
        let chunk = createTestChunk(text: "The Eiffel Tower was designed by Gustave Eiffel in 1889.")
        let deck = createTestDeck()

        let cards = try await generator.generateCards(from: [chunk], deck: deck)

        // Check that we get different card types
        let types = Set(cards.map { $0.type })
        XCTAssertFalse(types.isEmpty, "Should generate cards of various types")

        // Verify each type is valid
        for card in cards {
            XCTAssertTrue([FlashcardType.qa, .cloze, .definition].contains(card.type))
        }
    }

    func testGeneratedCardsHaveValidSpacedRepetitionProperties() async throws {
        let chunk = createTestChunk(text: "Test content for spaced repetition.")
        let deck = createTestDeck()

        let cards = try await generator.generateCards(from: [chunk], deck: deck)

        for card in cards {
            XCTAssertEqual(card.interval, 0, "New cards should start with 0 interval")
            XCTAssertEqual(card.easeFactor, 2.5, accuracy: 0.01, "New cards should have default ease factor")
            XCTAssertEqual(card.reviewCount, 0, "New cards should have 0 reviews")
            XCTAssertLessThanOrEqual(card.nextReviewDate, Date(), "New cards should be due immediately")
        }
    }

    // MARK: - Deck Creation Tests

    func testFindOrCreateFlashcardSet() {
        let topicLabel = "Geography"

        // First call should create a new set
        let set1 = context.findOrCreateFlashcardSet(topicLabel: topicLabel)
        XCTAssertEqual(set1.topicLabel, topicLabel)
        XCTAssertEqual(set1.tag, topicLabel.lowercased())

        // Second call should return the same set
        let set2 = context.findOrCreateFlashcardSet(topicLabel: topicLabel)
        XCTAssertEqual(set1.id, set2.id, "Should return existing set, not create new one")
    }

    func testFindOrCreateFlashcardSetNormalization() {
        // Test whitespace trimming
        let set1 = context.findOrCreateFlashcardSet(topicLabel: "  Science  ")
        XCTAssertEqual(set1.topicLabel, "Science")

        // Test case-insensitive tag matching
        let set2 = context.findOrCreateFlashcardSet(topicLabel: "SCIENCE")
        let set3 = context.findOrCreateFlashcardSet(topicLabel: "science")

        XCTAssertEqual(set1.tag, set2.tag, "Tags should be normalized to lowercase")
        XCTAssertEqual(set2.tag, set3.tag, "Tags should match regardless of input case")
    }

    func testFindOrCreateFlashcardSetEmptyLabel() {
        let set = context.findOrCreateFlashcardSet(topicLabel: "   ")
        XCTAssertEqual(set.topicLabel, "General", "Empty topic should default to 'General'")
    }

    // MARK: - Card Association Tests

    func testCardsAddedToDeck() async throws {
        let chunk = createTestChunk(text: "Test content")
        let deck = createTestDeck()
        let initialCount = deck.cards.count

        _ = try await generator.generateCards(from: [chunk], deck: deck)

        XCTAssertGreaterThan(deck.cards.count, initialCount, "Cards should be added to deck")
    }

    func testDeckPerformanceMetricsUpdate() async throws {
        let chunk = createTestChunk(text: "Test content")
        let deck = createTestDeck()

        let cards = try await generator.generateCards(from: [chunk], deck: deck)

        // Update metrics manually (normally done after study sessions)
        deck.updatePerformanceMetrics()

        XCTAssertEqual(deck.cardCount, cards.count)
        XCTAssertGreaterThan(deck.averageEase, 0)
    }

    // MARK: - Source Document Generation Tests

    func testGenerateFromSourceDocument() async throws {
        let sourceDoc = createTestSourceDocument()

        // Add chunks
        sourceDoc.chunks.append(createTestChunk(text: "First chunk about history."))
        sourceDoc.chunks.append(createTestChunk(text: "Second chunk about geography."))

        let deck = try await generator.generateFromSource(sourceDoc, context: context)

        XCTAssertFalse(deck.cards.isEmpty, "Should generate cards from source document")
        XCTAssertEqual(deck.topicLabel, sourceDoc.fileName.replacingOccurrences(of: ".pdf", with: ""))
        XCTAssertEqual(deck.tag, sourceDoc.kind.rawValue)

        // Verify cards link back to chunks
        for card in deck.cards {
            let linkedChunk = sourceDoc.chunks.first { $0.id == card.linkedEntryID }
            XCTAssertNotNil(linkedChunk, "Card should link to a chunk in the source document")
        }
    }

    // MARK: - Edge Cases

    func testGenerateFromEmptyChunks() async throws {
        let deck = createTestDeck()
        let cards = try await generator.generateCards(from: [], deck: deck)

        XCTAssertTrue(cards.isEmpty, "Should return empty array for empty chunks")
    }

    func testGenerateFromVeryShortText() async throws {
        let chunk = createTestChunk(text: "Hi.")
        let deck = createTestDeck()

        // Should not crash on very short text
        _ = try? await generator.generateCards(from: [chunk], deck: deck)

        // If it generated cards, they should still be valid
        for card in deck.cards {
            XCTAssertFalse(card.question.isEmpty)
            XCTAssertFalse(card.answer.isEmpty)
        }
    }

    func testGenerateFromVeryLongText() async throws {
        let longText = String(repeating: "The capital of France is Paris. ", count: 100)
        let chunk = createTestChunk(text: longText)
        let deck = createTestDeck()

        _ = try await generator.generateCards(from: [chunk], deck: deck)

        // Should handle long text without issues
        XCTAssertFalse(deck.cards.isEmpty, "Should generate cards from long text")
    }

    func testConcurrentGeneration() async throws {
        let chunks = (0..<5).map { i in
            createTestChunk(text: "Test chunk \(i) with some content about capitals.")
        }
        let deck = createTestDeck()

        // Generate from multiple chunks concurrently
        await withTaskGroup(of: [Flashcard].self) { group in
            for chunk in chunks {
                group.addTask {
                    try! await self.generator.generateCards(from: [chunk], deck: deck)
                }
            }
        }

        XCTAssertGreaterThan(deck.cards.count, 0, "Should generate cards from concurrent requests")
    }

    // MARK: - Performance Tests

    func testGenerationPerformance() {
        let chunks = (0..<10).map { i in
            createTestChunk(text: "Test content \(i) about various topics including history, geography, and science.")
        }
        let deck = createTestDeck()

        measure {
            Task {
                _ = try? await generator.generateCards(from: chunks, deck: deck)
            }
        }
    }

    // MARK: - Helper Methods

    private func createTestChunk(text: String) -> NoteChunk {
        let chunk = NoteChunk(text: text, chunkIndex: 0)
        context.insert(chunk)
        return chunk
    }

    private func createTestDeck() -> FlashcardSet {
        let deck = FlashcardSet(topicLabel: "Test Deck", tag: "test")
        context.insert(deck)
        return deck
    }

    private func createTestSourceDocument() -> SourceDocument {
        let doc = SourceDocument(
            kind: .pdf,
            fileName: "TestDocument.pdf",
            fileSize: 1024
        )
        context.insert(doc)
        return doc
    }
}

// MARK: - Mock LLM Engine

/// Mock LLM engine for testing that returns predictable responses
class MockLLMEngine: LLMEngine {
    func complete(_ prompt: String) async throws -> String {
        // Return mock flashcard data based on prompt type
        if prompt.contains("question-answer") || prompt.contains("Q1") {
            return """
            Q1: What is the capital of France?
            A1: Paris

            Q2: Where is the Eiffel Tower located?
            A2: Paris, France
            """
        } else if prompt.contains("cloze") || prompt.contains("CLOZE") {
            return """
            CLOZE: [...] is the capital of France.
            ANSWER: Paris
            """
        } else if prompt.contains("definition") {
            return """
            TERM: Capital
            DEFINITION: The city or town that functions as the seat of government
            """
        } else {
            // Default Q&A response
            return """
            Q1: What is the main topic?
            A1: Test topic

            Q2: What is being tested?
            A2: Flashcard generation
            """
        }
    }

    func embedText(_ text: String) async throws -> [Float] {
        // Return mock embedding
        return Array(repeating: 0.1, count: 384)
    }

    func streamComplete(_ prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let response = try await self.complete(prompt)
                continuation.yield(response)
                continuation.finish()
            }
        }
    }

    var isAvailable: Bool {
        return true
    }
}
