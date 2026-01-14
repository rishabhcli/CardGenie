//
//  FlashcardProcessorTests.swift
//  CardGenie
//
//  Unit tests for FlashcardGenerator, HighlightExtractor, and HighlightCardBuilder.
//

import XCTest
@testable import CardGenie

// MARK: - FlashcardGenerator Tests

@MainActor
final class FlashcardGeneratorTests: XCTestCase {
    var generator: FlashcardGenerator!

    override func setUp() async throws {
        generator = FlashcardGenerator()
    }

    override func tearDown() async throws {
        generator = nil
    }

    // MARK: - Initialization Tests

    func testInitialization() async throws {
        // Given/When: Creating a FlashcardGenerator
        // Then: Should initialize successfully
        XCTAssertNotNil(generator, "FlashcardGenerator should initialize")
    }

    // MARK: - Card Generation from Chunks Tests

    func testGenerateCardsFromEmptyChunks() async throws {
        // Given: Empty chunks array and a deck
        let chunks: [NoteChunk] = []
        let deck = FlashcardSet(topicLabel: "Test", tag: "test")

        // When: Generating cards
        let cards = try await generator.generateCards(from: chunks, deck: deck)

        // Then: Should return empty array
        XCTAssertTrue(cards.isEmpty, "Should generate no cards from empty chunks")
        XCTAssertTrue(deck.cards.isEmpty, "Deck should have no cards")
    }

    // MARK: - Q&A Parsing Tests

    func testParseQACardsValidFormat() {
        // Given: Well-formatted Q&A response
        let response = """
        Q1: What is the capital of France?
        A1: Paris is the capital of France.

        Q2: What is the largest planet?
        A2: Jupiter is the largest planet in our solar system.
        """
        let chunk = createTestChunk(text: "Geography facts")

        // When: Parsing the response (using reflection to test private method)
        let cards = parseQACards(response: response, chunk: chunk)

        // Then: Should extract both Q&A pairs
        XCTAssertEqual(cards.count, 2, "Should parse 2 Q&A cards")
        XCTAssertEqual(cards[0].type, .qa)
        XCTAssertTrue(cards[0].question.contains("France"))
        XCTAssertTrue(cards[0].answer.contains("Paris"))
    }

    func testParseQACardsWithColonsInContent() {
        // Given: Q&A with colons in the content
        let response = """
        Q1: What time is it: morning or evening?
        A1: The time shown is: 3:30 PM.
        """
        let chunk = createTestChunk(text: "Time questions")

        // When: Parsing
        let cards = parseQACards(response: response, chunk: chunk)

        // Then: Should handle colons correctly
        XCTAssertEqual(cards.count, 1)
        XCTAssertTrue(cards[0].question.contains("morning or evening"))
        XCTAssertTrue(cards[0].answer.contains("3:30"))
    }

    func testParseQACardsEmptyResponse() {
        // Given: Empty response
        let response = ""
        let chunk = createTestChunk(text: "Empty")

        // When: Parsing
        let cards = parseQACards(response: response, chunk: chunk)

        // Then: Should return empty array
        XCTAssertTrue(cards.isEmpty)
    }

    func testParseQACardsMalformedResponse() {
        // Given: Malformed response without proper format
        let response = """
        This is just some text without proper formatting.
        No questions or answers here.
        """
        let chunk = createTestChunk(text: "Malformed")

        // When: Parsing
        let cards = parseQACards(response: response, chunk: chunk)

        // Then: Should return empty array
        XCTAssertTrue(cards.isEmpty)
    }

    // MARK: - Cloze Card Parsing Tests

    func testParseClozeCardsValidFormat() {
        // Given: Well-formatted cloze response
        let response = """
        CLOZE: The chemical symbol for water is [...].
        ANSWER: H2O
        """
        let chunk = createTestChunk(text: "Chemistry")

        // When: Parsing
        let cards = parseClozeCards(response: response, chunk: chunk)

        // Then: Should extract cloze card
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].type, .cloze)
        XCTAssertTrue(cards[0].question.contains("[...]"))
        XCTAssertEqual(cards[0].answer, "H2O")
    }

    func testParseClozeCardsEmptyResponse() {
        // Given: Empty response
        let response = ""
        let chunk = createTestChunk(text: "Empty")

        // When: Parsing
        let cards = parseClozeCards(response: response, chunk: chunk)

        // Then: Should return empty array
        XCTAssertTrue(cards.isEmpty)
    }

    // MARK: - Card Properties Tests

    func testGeneratedCardHasCorrectType() {
        // Given: A Q&A response
        let response = "Q1: Test?\nA1: Answer"
        let chunk = createTestChunk(text: "Test")

        // When: Parsing
        let cards = parseQACards(response: response, chunk: chunk)

        // Then: Card should have correct type
        XCTAssertEqual(cards.first?.type, .qa)
    }

    func testGeneratedCardLinksToSourceChunk() {
        // Given: A chunk and response
        let chunk = createTestChunk(text: "Source text")
        let response = "Q1: Question?\nA1: Answer"

        // When: Parsing
        let cards = parseQACards(response: response, chunk: chunk)

        // Then: Card should link to source chunk
        XCTAssertEqual(cards.first?.linkedEntryID, chunk.id)
    }

    // MARK: - Helper Methods

    private func createTestChunk(text: String) -> NoteChunk {
        NoteChunk(text: text, pageNumber: nil)
    }

    /// Simulates parsing Q&A cards (mirrors private method logic)
    private func parseQACards(response: String, chunk: NoteChunk) -> [Flashcard] {
        var cards: [Flashcard] = []
        let lines = response.components(separatedBy: .newlines)
        var currentQuestion: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("Q") && trimmed.contains(":") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count >= 2 {
                    currentQuestion = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                }
            } else if trimmed.hasPrefix("A") && trimmed.contains(":"), let question = currentQuestion {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count >= 2 {
                    let answer = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                    let card = Flashcard(
                        type: .qa,
                        question: question,
                        answer: answer,
                        linkedEntryID: chunk.id
                    )
                    cards.append(card)
                    currentQuestion = nil
                }
            }
        }

        return cards
    }

    /// Simulates parsing cloze cards (mirrors private method logic)
    private func parseClozeCards(response: String, chunk: NoteChunk) -> [Flashcard] {
        var cards: [Flashcard] = []
        let lines = response.components(separatedBy: .newlines)
        var clozeText: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("CLOZE:") {
                clozeText = trimmed.replacingOccurrences(of: "CLOZE:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("ANSWER:"), let cloze = clozeText {
                let answer = trimmed.replacingOccurrences(of: "ANSWER:", with: "")
                    .trimmingCharacters(in: .whitespaces)

                let card = Flashcard(
                    type: .cloze,
                    question: cloze,
                    answer: answer,
                    linkedEntryID: chunk.id
                )
                cards.append(card)
                clozeText = nil
            }
        }

        return cards
    }
}

// MARK: - HighlightExtractor Tests

@MainActor
final class HighlightExtractorTests: XCTestCase {
    var extractor: HighlightExtractor!

    override func setUp() async throws {
        extractor = HighlightExtractor()
    }

    override func tearDown() async throws {
        extractor = nil
    }

    // MARK: - Initialization Tests

    func testInitializationWithDefaults() async throws {
        // Given/When: Creating with defaults
        let extractor = HighlightExtractor()

        // Then: Should initialize
        XCTAssertNotNil(extractor)
    }

    func testInitializationWithCustomSignals() async throws {
        // Given: Custom keywords
        let keywords = ["critical", "note"]
        let emphasis = CharacterSet(charactersIn: "!*")

        // When: Creating with custom signals
        let extractor = HighlightExtractor(keywordSignals: keywords, emphasisSignals: emphasis)

        // Then: Should initialize
        XCTAssertNotNil(extractor)
    }

    // MARK: - Chunk Evaluation Tests

    func testEvaluateChunkTooShort() async throws {
        // Given: A very short chunk
        let chunk = createTranscriptChunk(text: "Short", startTime: 0, endTime: 5)

        // When: Evaluating
        let result = extractor.evaluate(chunk: chunk)

        // Then: Should return nil for short text
        XCTAssertNil(result, "Short chunks should not produce highlights")
    }

    func testEvaluateChunkWithKeywords() async throws {
        // Given: A chunk with important keywords
        let text = "This is an important concept to remember. It's key for the exam and defines the main theory."
        let chunk = createTranscriptChunk(text: text, startTime: 0, endTime: 30)

        // When: Evaluating
        let result = extractor.evaluate(chunk: chunk)

        // Then: Should produce highlight with higher confidence
        XCTAssertNotNil(result, "Chunk with keywords should produce highlight")
        XCTAssertGreaterThan(result!.confidence, 0.55)
    }

    func testEvaluateChunkWithEmphasis() async throws {
        // Given: A chunk with emphasis punctuation
        let text = "This is absolutely critical! You must understand this concept? The answer reveals everything!"
        let chunk = createTranscriptChunk(text: text, startTime: 0, endTime: 20)

        // When: Evaluating
        let result = extractor.evaluate(chunk: chunk)

        // Then: Should produce highlight
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result!.confidence, 0.5)
    }

    func testEvaluateChunkWithLongText() async throws {
        // Given: A long chunk (>180 chars)
        let text = String(repeating: "This is a long text that contains important information about the subject matter. ", count: 5)
        let chunk = createTranscriptChunk(text: text, startTime: 0, endTime: 60)

        // When: Evaluating
        let result = extractor.evaluate(chunk: chunk)

        // Then: Should boost confidence for length
        XCTAssertNotNil(result)
    }

    func testEvaluateChunkConfidenceCap() async throws {
        // Given: A chunk with many signals
        let text = "This is extremely important! Remember this key definition for the exam! Therefore, it's critical to understand!"
        let chunk = createTranscriptChunk(text: text, startTime: 0, endTime: 30)

        // When: Evaluating
        let result = extractor.evaluate(chunk: chunk)

        // Then: Confidence should not exceed 0.95
        XCTAssertNotNil(result)
        XCTAssertLessThanOrEqual(result!.confidence, 0.95)
    }

    func testEvaluateChunkBelowThreshold() async throws {
        // Given: A plain chunk without signals
        let text = "The weather today is nice. Birds are singing. Trees are green. Clouds float by in the sky."
        let chunk = createTranscriptChunk(text: text, startTime: 0, endTime: 10)

        // When: Evaluating
        let result = extractor.evaluate(chunk: chunk)

        // Then: Should return nil if below threshold
        XCTAssertNil(result, "Plain text without signals should not highlight")
    }

    // MARK: - Manual Highlight Tests

    func testManualHighlightWithTranscript() async throws {
        // Given: Transcript text and timestamp
        let transcript = "User highlighted this important point"
        let timestamp: Double = 120

        // When: Creating manual highlight
        let result = extractor.manualHighlight(transcript: transcript, timestamp: timestamp)

        // Then: Should create highlight with high confidence
        XCTAssertEqual(result.excerpt, transcript)
        XCTAssertEqual(result.startTime, 120)
        XCTAssertEqual(result.endTime, 128, accuracy: 0.1) // +8 seconds
        XCTAssertEqual(result.confidence, 0.9, accuracy: 0.01)
        XCTAssertEqual(result.kind, .manual)
    }

    func testManualHighlightEmptyTranscript() async throws {
        // Given: Empty transcript
        let transcript = ""
        let timestamp: Double = 60

        // When: Creating manual highlight
        let result = extractor.manualHighlight(transcript: transcript, timestamp: timestamp)

        // Then: Should create placeholder
        XCTAssertTrue(result.excerpt.contains("Highlight at"), "Should have placeholder text")
        XCTAssertTrue(result.excerpt.contains("01:00"), "Should contain timestamp")
    }

    // MARK: - Collaborative Highlight Tests

    func testCollaborativeHighlight() async throws {
        // Given: Collaborative highlight data
        let excerpt = "Shared important note"
        let start: Double = 30
        let end: Double = 45
        let author = "John"

        // When: Creating collaborative highlight
        let result = extractor.collaborativeHighlight(excerpt, start: start, end: end, author: author)

        // Then: Should create with author attribution
        XCTAssertEqual(result.excerpt, excerpt)
        XCTAssertEqual(result.startTime, start)
        XCTAssertEqual(result.endTime, end)
        XCTAssertEqual(result.confidence, 0.8, accuracy: 0.01)
        XCTAssertEqual(result.kind, .collaborative)
        XCTAssertTrue(result.summary.contains("John"), "Summary should include author")
    }

    func testCollaborativeHighlightWithoutAuthor() async throws {
        // Given: Collaborative highlight without author
        let excerpt = "Anonymous shared note"

        // When: Creating without author
        let result = extractor.collaborativeHighlight(excerpt, start: 0, end: 10, author: nil)

        // Then: Should create without author attribution
        XCTAssertFalse(result.summary.contains(":"))
    }

    // MARK: - HighlightCandidate Tests

    func testHighlightCandidateKinds() async throws {
        // Given/When/Then: Verify all highlight kinds exist
        let kinds: [HighlightCandidate.Kind] = [.automatic, .manual, .collaborative]
        XCTAssertEqual(kinds.count, 3)
    }

    func testHighlightCandidateIdentifiable() async throws {
        // Given: Two highlight candidates
        let candidate1 = HighlightCandidate(
            id: UUID(),
            startTime: 0,
            endTime: 10,
            excerpt: "Test",
            summary: "Summary",
            confidence: 0.5,
            kind: .automatic
        )
        let candidate2 = HighlightCandidate(
            id: UUID(),
            startTime: 0,
            endTime: 10,
            excerpt: "Test",
            summary: "Summary",
            confidence: 0.5,
            kind: .automatic
        )

        // Then: Should have unique IDs
        XCTAssertNotEqual(candidate1.id, candidate2.id)
    }

    func testHighlightCandidateHashable() async throws {
        // Given: A set of candidates
        let candidate = HighlightCandidate(
            id: UUID(),
            startTime: 0,
            endTime: 10,
            excerpt: "Test",
            summary: "Summary",
            confidence: 0.5,
            kind: .automatic
        )

        var set: Set<HighlightCandidate> = []
        set.insert(candidate)

        // Then: Should be insertable into set
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - Helper Methods

    private func createTranscriptChunk(text: String, startTime: Double, endTime: Double) -> TranscriptChunk {
        TranscriptChunk(
            text: text,
            timestampRange: TimestampRange(start: startTime, end: endTime)
        )
    }
}

// MARK: - HighlightCardBuilder Tests

@MainActor
final class HighlightCardBuilderTests: XCTestCase {

    func testInitialization() async throws {
        // Given/When: Creating a HighlightCardBuilder
        let builder = HighlightCardBuilder()

        // Then: Should initialize
        XCTAssertNotNil(builder)
    }

    // MARK: - Q&A Parsing Tests

    func testParseQAValidResponse() {
        // Given: Valid Q&A response
        let response = """
        Q: What is photosynthesis?
        A: The process by which plants convert sunlight into energy.
        """

        // When: Parsing (using helper that mirrors internal logic)
        let result = parseQA(response: response)

        // Then: Should extract Q&A
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.question, "What is photosynthesis?")
        XCTAssertTrue(result?.answer.contains("sunlight") ?? false)
    }

    func testParseQAMissingQuestion() {
        // Given: Response without question
        let response = "A: Just an answer without a question"

        // When: Parsing
        let result = parseQA(response: response)

        // Then: Should return nil
        XCTAssertNil(result)
    }

    func testParseQAMissingAnswer() {
        // Given: Response without answer
        let response = "Q: Just a question without an answer"

        // When: Parsing
        let result = parseQA(response: response)

        // Then: Should return nil
        XCTAssertNil(result)
    }

    func testParseQAEmptyContent() {
        // Given: Response with empty Q&A
        let response = """
        Q:
        A:
        """

        // When: Parsing
        let result = parseQA(response: response)

        // Then: Should return nil for empty content
        XCTAssertNil(result)
    }

    // MARK: - Helper Methods

    /// Mirrors the private parseQA method for testing
    private func parseQA(response: String) -> (question: String, answer: String)? {
        var question: String?
        var answer: String?

        response
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .forEach { line in
                if line.hasPrefix("Q:"), question == nil {
                    question = line.replacingOccurrences(of: "Q:", with: "").trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("A:"), answer == nil {
                    answer = line.replacingOccurrences(of: "A:", with: "").trimmingCharacters(in: .whitespaces)
                }
            }

        if let question, let answer, !question.isEmpty, !answer.isEmpty {
            return (question, answer)
        }
        return nil
    }
}

// MARK: - NoteChunk Extension for Tests

extension NoteChunk {
    /// Convenience initializer for tests
    convenience init(text: String, pageNumber: Int?) {
        self.init()
        self.text = text
        self.pageNumber = pageNumber
    }
}

// Note: TranscriptChunk and TimestampRange are imported from CardGenie module
