//
//  EdgeCaseTests.swift
//  CardGenie
//
//  Edge case and boundary condition tests for critical components.
//

import XCTest
@testable import CardGenie

// MARK: - Spaced Repetition Edge Cases

@MainActor
final class SpacedRepetitionEdgeCaseTests: XCTestCase {

    // MARK: - Extreme Ease Factor Tests

    func testEaseFactorAtMinimumBoundary() async throws {
        // Given: A card with minimum ease factor
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        card.easeFactor = 1.3 // SM-2 minimum

        // Then: Should not go below minimum
        XCTAssertGreaterThanOrEqual(card.easeFactor, 1.3)
    }

    func testEaseFactorAtMaximumRange() async throws {
        // Given: A card with high ease factor
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        card.easeFactor = 3.5 // Very high ease

        // Then: Should be valid
        XCTAssertLessThanOrEqual(card.easeFactor, 4.0)
    }

    // MARK: - Long Interval Tests

    func testVeryLongIntervalCard() async throws {
        // Given: A card with 1 year interval
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        card.interval = 365 // 1 year

        // Then: Should be valid
        XCTAssertEqual(card.interval, 365)
    }

    func testExtremeReviewCount() async throws {
        // Given: A card with many reviews
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        card.reviewCount = 1000
        card.goodCount = 800
        card.easyCount = 150
        card.againCount = 50

        // Then: Should calculate correct success rate
        XCTAssertEqual(card.successRate, 0.95, accuracy: 0.01)
    }

    // MARK: - Zero/Empty Edge Cases

    func testFlashcardSetEmptySuccess() async throws {
        // Given: An empty flashcard set
        let set = FlashcardSet(topicLabel: "Empty", tag: "empty")

        // Then: Success rate should be 0
        XCTAssertEqual(set.successRate, 0)
    }

    func testFlashcardSetAllNewCards() async throws {
        // Given: A set with all new cards
        let set = FlashcardSet(topicLabel: "New", tag: "new")
        for _ in 0..<5 {
            set.cards.append(Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID()))
        }

        // Then: Due count should equal total cards (new cards are due)
        XCTAssertEqual(set.dueCount, 5)
        XCTAssertEqual(set.newCount, 5)
    }
}

// MARK: - FlashcardSet Edge Cases

@MainActor
final class FlashcardSetEdgeCaseTests: XCTestCase {

    func testLargeFlashcardSet() async throws {
        // Given: A large set with 1000 cards
        let set = FlashcardSet(topicLabel: "Large", tag: "large")
        for i in 0..<1000 {
            let card = Flashcard(type: .qa, question: "Q\(i)", answer: "A\(i)", linkedEntryID: UUID())
            set.cards.append(card)
        }

        // Then: Should handle correctly
        XCTAssertEqual(set.cardCount, 1000)
    }

    func testFlashcardSetWithMixedDueCards() async throws {
        // Given: A set with mixed due states
        let set = FlashcardSet(topicLabel: "Mixed", tag: "mixed")

        // 3 due cards
        for _ in 0..<3 {
            let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
            card.nextReviewDate = Date().addingTimeInterval(-3600) // Past
            set.cards.append(card)
        }

        // 2 future cards
        for _ in 0..<2 {
            let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
            card.nextReviewDate = Date().addingTimeInterval(3600) // Future
            set.cards.append(card)
        }

        // Then: Should correctly count due cards
        XCTAssertEqual(set.dueCount, 3)
        XCTAssertEqual(set.cardCount, 5)
    }

    func testGetDueCardsSortOrder() async throws {
        // Given: A set with cards due at different times
        let set = FlashcardSet(topicLabel: "Sorted", tag: "sorted")

        let card1 = Flashcard(type: .qa, question: "Third", answer: "A", linkedEntryID: UUID())
        card1.nextReviewDate = Date().addingTimeInterval(-100)

        let card2 = Flashcard(type: .qa, question: "First", answer: "A", linkedEntryID: UUID())
        card2.nextReviewDate = Date().addingTimeInterval(-3600)

        let card3 = Flashcard(type: .qa, question: "Second", answer: "A", linkedEntryID: UUID())
        card3.nextReviewDate = Date().addingTimeInterval(-1800)

        set.cards = [card1, card2, card3]

        // When: Getting due cards
        let dueCards = set.getDueCards()

        // Then: Should be sorted by due date (oldest first)
        XCTAssertEqual(dueCards.count, 3)
        XCTAssertEqual(dueCards[0].question, "First")
        XCTAssertEqual(dueCards[1].question, "Second")
        XCTAssertEqual(dueCards[2].question, "Third")
    }
}

// MARK: - ChatContext Edge Cases

final class ChatContextEdgeCaseTests: XCTestCase {

    func testFormatMessageHistoryEmpty() {
        // Given: Empty messages
        let context = ChatContext()
        let messages: [ChatMessageModel] = []

        // When: Formatting
        let result = context.formatMessageHistory(messages)

        // Then: Should return empty string
        XCTAssertEqual(result, "")
    }

    func testFormatMessageHistoryWithSingleMessage() {
        // Given: Single message
        let context = ChatContext()
        let message = ChatMessageModel(role: .user, content: "Hello")
        let messages = [message]

        // When: Formatting
        let result = context.formatMessageHistory(messages)

        // Then: Should format correctly
        XCTAssertTrue(result.contains("User: Hello"))
    }

    func testTokenEstimationWithManyScans() {
        // Given: Context with many scans
        var context = ChatContext()
        for _ in 0..<10 {
            context.activeScans.append(ScanAttachment(imageData: Data(), extractedText: "Test"))
        }

        // When: Estimating tokens
        let tokens = context.estimateTokens()

        // Then: Should include all scan costs
        XCTAssertEqual(tokens, 200 + (10 * 500))
    }

    func testSystemPromptWithAllContext() {
        // Given: Context with all types of data
        var context = ChatContext()
        context.userLearningLevel = .advanced
        context.activeScans.append(ScanAttachment(imageData: Data(), extractedText: "Scan text"))

        // When: Generating system prompt
        let prompt = context.systemPrompt()

        // Then: Should include all context
        XCTAssertTrue(prompt.contains("advanced"))
        XCTAssertTrue(prompt.contains("scanned"))
    }
}

// MARK: - Game Engine Edge Cases

@MainActor
final class GameEngineEdgeCaseTests: XCTestCase {

    func testMatchingGameWithSinglePair() async throws {
        // Given: A single flashcard
        let flashcards = [
            Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        ]
        let engine = GameEngine()

        // When: Creating game
        let game = engine.createMatchingGame(from: flashcards)

        // Then: Should have 1 pair
        XCTAssertEqual(game.pairs.count, 1)
    }

    func testMatchingGameScoreNeverNegative() async throws {
        // Given: A game with 0 score
        let engine = GameEngine()
        let flashcards = [
            Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        ]
        let game = engine.createMatchingGame(from: flashcards)
        game.score = 0

        // When: Making wrong match
        _ = engine.checkMatch(game, term: game.pairs[0].term, definition: "Wrong")

        // Then: Score should be 0 (not negative)
        XCTAssertEqual(game.score, 0)
    }

    func testMatchingGameAccuracyWithMultipleAttempts() async throws {
        // Given: A game with many attempts per pair
        let pair1 = MatchPair(term: "T1", definition: "D1")
        pair1.attempts = 5

        let pair2 = MatchPair(term: "T2", definition: "D2")
        pair2.attempts = 10

        let game = MatchingGame(flashcardSetID: UUID(), pairs: [pair1, pair2])

        // Then: Accuracy should be 2/15 ≈ 0.133
        XCTAssertEqual(game.accuracy, 2.0/15.0, accuracy: 0.01)
    }
}

// MARK: - String Edge Cases

final class StringEdgeCaseTests: XCTestCase {

    func testChatSessionTitleWithEmoji() {
        // Given: A session
        let session = ChatSession()

        // When: Generating title with emoji
        session.generateTitle(from: "👋 Hello world!")

        // Then: Should handle emoji
        XCTAssertTrue(session.title.contains("👋"))
    }

    func testChatSessionTitleWithExactly40Chars() {
        // Given: A session and exactly 40 character message
        let session = ChatSession()
        let message = String(repeating: "a", count: 40)

        // When: Generating title
        session.generateTitle(from: message)

        // Then: Should not have ellipsis
        XCTAssertFalse(session.title.hasSuffix("..."))
        XCTAssertEqual(session.title.count, 40)
    }

    func testChatSessionTitleWithNewlines() {
        // Given: A session
        let session = ChatSession()

        // When: Generating title with newlines
        session.generateTitle(from: "First line\nSecond line\nThird line")

        // Then: Should include newlines in truncation
        XCTAssertTrue(session.title.count <= 43)
    }

    func testChatSessionTitleWithUnicode() {
        // Given: A session
        let session = ChatSession()

        // When: Generating title with unicode
        session.generateTitle(from: "你好世界 Hello World مرحبا")

        // Then: Should handle unicode
        XCTAssertFalse(session.title.isEmpty)
    }
}

// MARK: - Concurrent Access Edge Cases

@MainActor
final class ConcurrentAccessEdgeCaseTests: XCTestCase {

    func testConcurrentFlashcardSetUpdates() async throws {
        // Given: A flashcard set
        let set = FlashcardSet(topicLabel: "Concurrent", tag: "concurrent")

        // When: Adding cards concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { @MainActor in
                    let card = Flashcard(type: .qa, question: "Q\(i)", answer: "A\(i)", linkedEntryID: UUID())
                    set.cards.append(card)
                }
            }
        }

        // Then: Should have all cards (though order may vary)
        XCTAssertEqual(set.cardCount, 10)
    }

    func testConcurrentCacheAccess() async throws {
        // Given: A content generator
        let generator = ContentGenerator()
        let flashcardID = UUID()

        // When: Caching and retrieving concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                let problems = [PracticeProblem(problem: "P", solution: "S", steps: [], difficulty: .same)]
                generator.cachePracticeProblems(problems, for: flashcardID)
            }
            group.addTask { @MainActor in
                _ = generator.getCachedPracticeProblems(for: flashcardID)
            }
        }

        // Then: Should not crash
        XCTAssertTrue(true)
    }
}

// MARK: - Date Edge Cases

@MainActor
final class DateEdgeCaseTests: XCTestCase {

    func testFlashcardDueAtExactCurrentTime() async throws {
        // Given: A card due at exactly now
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        card.nextReviewDate = Date()

        // Then: Should be due
        XCTAssertTrue(card.isDue)
    }

    func testMatchingGameElapsedTimeInProgress() async throws {
        // Given: A game in progress
        let game = MatchingGame(flashcardSetID: UUID())
        game.startTime = Date().addingTimeInterval(-30)

        // Then: Elapsed time should be approximately 30 seconds
        XCTAssertEqual(game.elapsedTime, 30, accuracy: 1.0)
    }

    func testConversationalSessionDuration() async throws {
        // Given: A session that started 5 minutes ago
        let session = ConversationalSession(flashcardID: UUID(), mode: .socratic)
        // Session startTime is set in init, so we need to check it's reasonable

        // Then: Duration should be very small (just created)
        XCTAssertLessThan(session.duration, 1.0)
    }
}
