//
//  FlashcardModelsTests.swift
//  CardGenie
//
//  Unit tests for Flashcard and FlashcardSet models.
//

import XCTest
@testable import CardGenie

// MARK: - FlashcardType Tests

final class FlashcardTypeTests: XCTestCase {

    func testFlashcardTypeRawValues() {
        // Given/When/Then: Verify raw values
        XCTAssertEqual(FlashcardType.cloze.rawValue, "cloze")
        XCTAssertEqual(FlashcardType.qa.rawValue, "qa")
        XCTAssertEqual(FlashcardType.definition.rawValue, "definition")
    }

    func testFlashcardTypeCodable() throws {
        // Given: A flashcard type
        let type = FlashcardType.cloze

        // When: Encoding and decoding
        let encoded = try JSONEncoder().encode(type)
        let decoded = try JSONDecoder().decode(FlashcardType.self, from: encoded)

        // Then: Should preserve value
        XCTAssertEqual(decoded, type)
    }
}

// MARK: - Flashcard Tests

@MainActor
final class FlashcardTests: XCTestCase {

    // MARK: - Initialization Tests

    func testFlashcardInitialization() async throws {
        // Given/When: Creating a flashcard
        let linkedEntryID = UUID()
        let card = Flashcard(
            type: .qa,
            question: "What is photosynthesis?",
            answer: "Process by which plants convert light to energy",
            linkedEntryID: linkedEntryID,
            tags: ["biology", "plants"]
        )

        // Then: Should have correct initial state
        XCTAssertNotNil(card.id)
        XCTAssertEqual(card.type, .qa)
        XCTAssertEqual(card.question, "What is photosynthesis?")
        XCTAssertEqual(card.answer, "Process by which plants convert light to energy")
        XCTAssertEqual(card.linkedEntryID, linkedEntryID)
        XCTAssertEqual(card.tags, ["biology", "plants"])
        XCTAssertNotNil(card.createdAt)
    }

    func testFlashcardSpacedRepetitionDefaults() async throws {
        // Given/When: Creating a new flashcard
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())

        // Then: Should have default SR properties
        XCTAssertEqual(card.easeFactor, 2.5, accuracy: 0.01)
        XCTAssertEqual(card.interval, 0)
        XCTAssertEqual(card.reviewCount, 0)
        XCTAssertEqual(card.againCount, 0)
        XCTAssertEqual(card.goodCount, 0)
        XCTAssertEqual(card.easyCount, 0)
        XCTAssertNil(card.lastReviewed)
    }

    // MARK: - Computed Property Tests

    func testFlashcardIsDue() async throws {
        // Given: A card with past due date
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        card.nextReviewDate = Date().addingTimeInterval(-3600) // 1 hour ago

        // Then: Should be due
        XCTAssertTrue(card.isDue)
    }

    func testFlashcardIsNotDue() async throws {
        // Given: A card with future due date
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        card.nextReviewDate = Date().addingTimeInterval(3600) // 1 hour from now

        // Then: Should not be due
        XCTAssertFalse(card.isDue)
    }

    func testFlashcardIsNew() async throws {
        // Given: A card that's never been reviewed
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())

        // Then: Should be new
        XCTAssertTrue(card.isNew)
    }

    func testFlashcardIsNotNew() async throws {
        // Given: A card that's been reviewed
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        card.reviewCount = 1

        // Then: Should not be new
        XCTAssertFalse(card.isNew)
    }

    func testFlashcardSuccessRateNoReviews() async throws {
        // Given: A card with no reviews
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())

        // Then: Success rate should be 0
        XCTAssertEqual(card.successRate, 0)
    }

    func testFlashcardSuccessRateCalculation() async throws {
        // Given: A card with reviews
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        card.reviewCount = 10
        card.goodCount = 6
        card.easyCount = 2
        card.againCount = 2

        // Then: Success rate should be 80% (6+2)/10
        XCTAssertEqual(card.successRate, 0.8, accuracy: 0.01)
    }

    func testFlashcardTypeDisplayName() async throws {
        // Given: Cards of different types
        let cloze = Flashcard(type: .cloze, question: "Q", answer: "A", linkedEntryID: UUID())
        let qa = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        let definition = Flashcard(type: .definition, question: "Q", answer: "A", linkedEntryID: UUID())

        // Then: Should have correct display names
        XCTAssertEqual(cloze.typeDisplayName, "Cloze Deletion")
        XCTAssertEqual(qa.typeDisplayName, "Q&A")
        XCTAssertEqual(definition.typeDisplayName, "Definition")
    }

    // MARK: - Mastery Level Tests

    func testMasteryLevelLearning() async throws {
        // Given: A new card
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())

        // Then: Should be learning
        XCTAssertEqual(card.masteryLevel, .learning)
    }

    func testMasteryLevelDeveloping() async throws {
        // Given: A card with some reviews but low ease
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        card.reviewCount = 3
        card.easeFactor = 2.0

        // Then: Should be developing
        XCTAssertEqual(card.masteryLevel, .developing)
    }

    func testMasteryLevelProficient() async throws {
        // Given: A card with decent reviews and ease
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        card.reviewCount = 7
        card.easeFactor = 2.4

        // Then: Should be proficient
        XCTAssertEqual(card.masteryLevel, .proficient)
    }

    func testMasteryLevelMastered() async throws {
        // Given: A well-reviewed card with high ease
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        card.reviewCount = 15
        card.easeFactor = 2.8

        // Then: Should be mastered
        XCTAssertEqual(card.masteryLevel, .mastered)
    }

    func testMasteryLevelEmoji() async throws {
        // Given: All mastery levels
        // Then: Should have emojis
        XCTAssertEqual(Flashcard.MasteryLevel.learning.emoji, "🌱")
        XCTAssertEqual(Flashcard.MasteryLevel.developing.emoji, "📈")
        XCTAssertEqual(Flashcard.MasteryLevel.proficient.emoji, "⭐️")
        XCTAssertEqual(Flashcard.MasteryLevel.mastered.emoji, "🏆")
    }

    func testMasteryProgress() async throws {
        // Given: A mastered card
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        card.reviewCount = 15
        card.easeFactor = 2.8

        // Then: Mastery progress should be 1.0
        XCTAssertEqual(card.masteryProgress, 1.0, accuracy: 0.01)
    }

    func testFormattedQuestion() async throws {
        // Given: A card
        let card = Flashcard(type: .qa, question: "Test question?", answer: "Answer", linkedEntryID: UUID())

        // Then: Formatted question should match
        XCTAssertEqual(card.formattedQuestion, "Test question?")
    }

    func testFormattedAnswer() async throws {
        // Given: A card
        let card = Flashcard(type: .qa, question: "Q", answer: "Test answer", linkedEntryID: UUID())

        // Then: Formatted answer should match
        XCTAssertEqual(card.formattedAnswer, "Test answer")
    }
}

// MARK: - FlashcardSet Tests

@MainActor
final class FlashcardSetTests: XCTestCase {

    func testFlashcardSetInitialization() async throws {
        // Given/When: Creating a flashcard set
        let set = FlashcardSet(topicLabel: "Biology", tag: "biology")

        // Then: Should have correct initial state
        XCTAssertNotNil(set.id)
        XCTAssertEqual(set.topicLabel, "Biology")
        XCTAssertEqual(set.tag, "biology")
        XCTAssertNotNil(set.createdDate)
        XCTAssertEqual(set.entryCount, 0)
        XCTAssertEqual(set.totalReviews, 0)
        XCTAssertEqual(set.averageEase, 2.5, accuracy: 0.01)
        XCTAssertNil(set.lastReviewDate)
        XCTAssertTrue(set.cards.isEmpty)
    }

    func testFlashcardSetCardCount() async throws {
        // Given: A set with cards
        let set = FlashcardSet(topicLabel: "Math", tag: "math")
        set.cards.append(Flashcard(type: .qa, question: "Q1", answer: "A1", linkedEntryID: UUID()))
        set.cards.append(Flashcard(type: .qa, question: "Q2", answer: "A2", linkedEntryID: UUID()))

        // Then: Card count should match
        XCTAssertEqual(set.cardCount, 2)
    }

    func testFlashcardSetDueCount() async throws {
        // Given: A set with some due cards
        let set = FlashcardSet(topicLabel: "Test", tag: "test")

        let dueCard = Flashcard(type: .qa, question: "Q1", answer: "A1", linkedEntryID: UUID())
        dueCard.nextReviewDate = Date().addingTimeInterval(-3600)

        let futureCard = Flashcard(type: .qa, question: "Q2", answer: "A2", linkedEntryID: UUID())
        futureCard.nextReviewDate = Date().addingTimeInterval(3600)

        set.cards = [dueCard, futureCard]

        // Then: Due count should be 1
        XCTAssertEqual(set.dueCount, 1)
    }

    func testFlashcardSetNewCount() async throws {
        // Given: A set with some new cards
        let set = FlashcardSet(topicLabel: "Test", tag: "test")

        let newCard = Flashcard(type: .qa, question: "Q1", answer: "A1", linkedEntryID: UUID())

        let reviewedCard = Flashcard(type: .qa, question: "Q2", answer: "A2", linkedEntryID: UUID())
        reviewedCard.reviewCount = 5

        set.cards = [newCard, reviewedCard]

        // Then: New count should be 1
        XCTAssertEqual(set.newCount, 1)
    }

    func testFlashcardSetSuccessRate() async throws {
        // Given: A set with cards having different success rates
        let set = FlashcardSet(topicLabel: "Test", tag: "test")

        let card1 = Flashcard(type: .qa, question: "Q1", answer: "A1", linkedEntryID: UUID())
        card1.reviewCount = 10
        card1.goodCount = 8
        card1.easyCount = 0

        let card2 = Flashcard(type: .qa, question: "Q2", answer: "A2", linkedEntryID: UUID())
        card2.reviewCount = 10
        card2.goodCount = 4
        card2.easyCount = 2

        set.cards = [card1, card2]

        // Then: Success rate should be average (0.8 + 0.6) / 2 = 0.7
        XCTAssertEqual(set.successRate, 0.7, accuracy: 0.01)
    }

    func testFlashcardSetAddCard() async throws {
        // Given: A set and a card
        let set = FlashcardSet(topicLabel: "Test", tag: "test")
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())

        // When: Adding the card
        set.addCard(card)

        // Then: Card should be in set and linked
        XCTAssertEqual(set.cards.count, 1)
        XCTAssertEqual(card.set?.id, set.id)
    }

    func testFlashcardSetUpdatePerformanceMetrics() async throws {
        // Given: A set with reviewed cards
        let set = FlashcardSet(topicLabel: "Test", tag: "test")

        let card1 = Flashcard(type: .qa, question: "Q1", answer: "A1", linkedEntryID: UUID())
        card1.reviewCount = 5
        card1.easeFactor = 2.2
        card1.lastReviewed = Date()

        let card2 = Flashcard(type: .qa, question: "Q2", answer: "A2", linkedEntryID: UUID())
        card2.reviewCount = 3
        card2.easeFactor = 2.8
        card2.lastReviewed = Date().addingTimeInterval(-3600)

        set.cards = [card1, card2]

        // When: Updating metrics
        set.updatePerformanceMetrics()

        // Then: Should calculate totals and averages
        XCTAssertEqual(set.totalReviews, 8)
        XCTAssertEqual(set.averageEase, 2.5, accuracy: 0.01) // (2.2 + 2.8) / 2
        XCTAssertNotNil(set.lastReviewDate)
    }

    func testFlashcardSetGetDueCards() async throws {
        // Given: A set with cards
        let set = FlashcardSet(topicLabel: "Test", tag: "test")

        let dueCard = Flashcard(type: .qa, question: "Due", answer: "A", linkedEntryID: UUID())
        dueCard.nextReviewDate = Date().addingTimeInterval(-3600)

        let futureCard = Flashcard(type: .qa, question: "Future", answer: "A", linkedEntryID: UUID())
        futureCard.nextReviewDate = Date().addingTimeInterval(3600)

        set.cards = [futureCard, dueCard]

        // When: Getting due cards
        let dueCards = set.getDueCards()

        // Then: Should return only due cards sorted by date
        XCTAssertEqual(dueCards.count, 1)
        XCTAssertEqual(dueCards.first?.question, "Due")
    }

    func testFlashcardSetGetNewCards() async throws {
        // Given: A set with cards
        let set = FlashcardSet(topicLabel: "Test", tag: "test")

        let newCard = Flashcard(type: .qa, question: "New", answer: "A", linkedEntryID: UUID())

        let reviewedCard = Flashcard(type: .qa, question: "Reviewed", answer: "A", linkedEntryID: UUID())
        reviewedCard.reviewCount = 3

        set.cards = [reviewedCard, newCard]

        // When: Getting new cards
        let newCards = set.getNewCards()

        // Then: Should return only new cards
        XCTAssertEqual(newCards.count, 1)
        XCTAssertEqual(newCards.first?.question, "New")
    }
}
