//
//  SpacedRepetitionTests.swift
//  CardGenieTests
//
//  Comprehensive unit tests for SpacedRepetitionManager.
//  Tests SM-2 algorithm implementation for correctness.
//

import XCTest
import SwiftData
@testable import CardGenie

@MainActor
final class SpacedRepetitionTests: XCTestCase {
    var manager: SpacedRepetitionManager!
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        manager = SpacedRepetitionManager()

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Flashcard.self, FlashcardSet.self,
            configurations: configuration
        )
        context = ModelContext(container)
    }

    override func tearDown() async throws {
        manager = nil
        container = nil
        context = nil
    }

    // MARK: - Again Response Tests

    func testAgainResponseResetsInterval() {
        let card = createTestCard()
        card.interval = 10

        manager.scheduleNextReview(for: card, response: .again)

        XCTAssertEqual(card.interval, 0, "Again response should reset interval to 0")
    }

    func testAgainResponseDecreasesEaseFactor() {
        let card = createTestCard()
        let initialEase = card.easeFactor

        manager.scheduleNextReview(for: card, response: .again)

        XCTAssertLessThan(card.easeFactor, initialEase, "Again response should decrease ease factor")
        XCTAssertEqual(card.easeFactor, initialEase - 0.2, accuracy: 0.01)
    }

    func testAgainResponseNeverGoesbelowMinimumEase() {
        let card = createTestCard()

        // Spam "again" 100 times
        for _ in 0..<100 {
            manager.scheduleNextReview(for: card, response: .again)
        }

        XCTAssertGreaterThanOrEqual(card.easeFactor, 1.3, "Ease factor should never go below 1.3")
    }

    func testAgainResponseIncrementsAgainCount() {
        let card = createTestCard()

        manager.scheduleNextReview(for: card, response: .again)

        XCTAssertEqual(card.againCount, 1)
    }

    func testAgainResponseSchedules10Minutes() {
        let card = createTestCard()
        let beforeDate = Date()

        manager.scheduleNextReview(for: card, response: .again)

        let expectedDate = beforeDate.addingTimeInterval(10 * 60)
        let tolerance: TimeInterval = 5 // 5 seconds tolerance

        XCTAssertEqual(
            card.nextReviewDate.timeIntervalSince1970,
            expectedDate.timeIntervalSince1970,
            accuracy: tolerance,
            "Again response should schedule review in ~10 minutes"
        )
    }

    // MARK: - Good Response Tests

    func testGoodResponseFirstReview() {
        let card = createTestCard()
        XCTAssertEqual(card.interval, 0, "New card starts with 0 interval")

        manager.scheduleNextReview(for: card, response: .good)

        XCTAssertEqual(card.interval, 1, "First good review should set interval to 1 day")
    }

    func testGoodResponseSecondReview() {
        let card = createTestCard()
        card.interval = 1

        manager.scheduleNextReview(for: card, response: .good)

        XCTAssertEqual(card.interval, 6, "Second good review should set interval to 6 days")
    }

    func testGoodResponseSubsequentReviews() {
        let card = createTestCard()
        card.interval = 6
        card.easeFactor = 2.5

        manager.scheduleNextReview(for: card, response: .good)

        let expectedInterval = Int(ceil(6.0 * 2.5))
        XCTAssertEqual(card.interval, expectedInterval, "Good response should multiply interval by ease factor")
    }

    func testGoodResponseMaintainsEaseFactor() {
        let card = createTestCard()
        let initialEase = card.easeFactor

        manager.scheduleNextReview(for: card, response: .good)

        XCTAssertEqual(card.easeFactor, initialEase, "Good response should not change ease factor")
    }

    func testGoodResponseIncrementsGoodCount() {
        let card = createTestCard()

        manager.scheduleNextReview(for: card, response: .good)

        XCTAssertEqual(card.goodCount, 1)
    }

    // MARK: - Easy Response Tests

    func testEasyResponseFirstReview() {
        let card = createTestCard()

        manager.scheduleNextReview(for: card, response: .easy)

        XCTAssertEqual(card.interval, 4, "First easy review should set interval to 4 days")
    }

    func testEasyResponseSubsequentReviews() {
        let card = createTestCard()
        card.interval = 6
        card.easeFactor = 2.5

        manager.scheduleNextReview(for: card, response: .easy)

        let expectedInterval = Int(ceil(6.0 * 2.5 * 1.3))
        XCTAssertEqual(card.interval, expectedInterval, "Easy response should apply easy bonus (1.3x)")
    }

    func testEasyResponseIncreasesEaseFactor() {
        let card = createTestCard()
        let initialEase = card.easeFactor

        manager.scheduleNextReview(for: card, response: .easy)

        XCTAssertGreaterThan(card.easeFactor, initialEase, "Easy response should increase ease factor")
        XCTAssertEqual(card.easeFactor, initialEase + 0.15, accuracy: 0.01)
    }

    func testEasyResponseCapsEaseFactorAt3() {
        let card = createTestCard()
        card.easeFactor = 2.9

        // Multiple easy responses
        for _ in 0..<10 {
            manager.scheduleNextReview(for: card, response: .easy)
        }

        XCTAssertLessThanOrEqual(card.easeFactor, 3.0, "Ease factor should be capped at 3.0")
    }

    func testEasyResponseIncrementsEasyCount() {
        let card = createTestCard()

        manager.scheduleNextReview(for: card, response: .easy)

        XCTAssertEqual(card.easyCount, 1)
    }

    // MARK: - General Metadata Tests

    func testAllResponsesIncrementReviewCount() {
        let card1 = createTestCard()
        let card2 = createTestCard()
        let card3 = createTestCard()

        manager.scheduleNextReview(for: card1, response: .again)
        manager.scheduleNextReview(for: card2, response: .good)
        manager.scheduleNextReview(for: card3, response: .easy)

        XCTAssertEqual(card1.reviewCount, 1)
        XCTAssertEqual(card2.reviewCount, 1)
        XCTAssertEqual(card3.reviewCount, 1)
    }

    func testAllResponsesUpdateLastReviewed() {
        let card = createTestCard()
        let beforeDate = Date()

        manager.scheduleNextReview(for: card, response: .good)

        XCTAssertNotNil(card.lastReviewed)
        XCTAssertGreaterThanOrEqual(card.lastReviewed!, beforeDate)
    }

    // MARK: - Queue Management Tests

    func testGetDailyReviewQueue() {
        let set1 = createTestSet(named: "Set 1")
        let set2 = createTestSet(named: "Set 2")

        // Add due cards
        let dueCard1 = createTestCard()
        dueCard1.nextReviewDate = Date().addingTimeInterval(-3600) // 1 hour ago
        set1.addCard(dueCard1)

        let dueCard2 = createTestCard()
        dueCard2.nextReviewDate = Date().addingTimeInterval(-7200) // 2 hours ago
        set2.addCard(dueCard2)

        // Add future card (not due)
        let futureCard = createTestCard()
        futureCard.nextReviewDate = Date().addingTimeInterval(86400) // tomorrow
        set1.addCard(futureCard)

        let queue = manager.getDailyReviewQueue(from: [set1, set2])

        XCTAssertEqual(queue.count, 2, "Should return only due cards")
        XCTAssertEqual(queue.first?.id, dueCard2.id, "Should sort by due date (oldest first)")
    }

    func testGetStudySession() {
        let set = createTestSet(named: "Test Set")

        // Add 10 new cards
        for _ in 0..<10 {
            let newCard = createTestCard()
            newCard.nextReviewDate = Date()
            set.addCard(newCard)
        }

        // Add 30 due cards
        for _ in 0..<30 {
            let dueCard = createTestCard()
            dueCard.reviewCount = 5
            dueCard.nextReviewDate = Date().addingTimeInterval(-3600)
            set.addCard(dueCard)
        }

        let session = manager.getStudySession(from: set, maxNew: 5, maxReview: 20)

        XCTAssertLessThanOrEqual(session.count, 25, "Should not exceed maxNew + maxReview")

        let newCardsInSession = session.filter { $0.reviewCount == 0 }.count
        XCTAssertLessThanOrEqual(newCardsInSession, 5, "Should not exceed maxNew")

        let reviewCardsInSession = session.filter { $0.reviewCount > 0 }.count
        XCTAssertLessThanOrEqual(reviewCardsInSession, 20, "Should not exceed maxReview")
    }

    func testGetStudySessionShuffles() {
        let set = createTestSet(named: "Test Set")

        // Create predictable pattern
        for i in 0..<20 {
            let card = createTestCard()
            card.question = "Card \(i)"
            card.reviewCount = i % 2 // Alternating new and review
            set.addCard(card)
        }

        let session1 = manager.getStudySession(from: set)
        let session2 = manager.getStudySession(from: set)

        // Sessions should be different orders (very unlikely to be same if shuffled)
        let sameOrder = session1.enumerated().allSatisfy { index, card in
            session2[index].id == card.id
        }

        XCTAssertFalse(sameOrder, "Study sessions should be shuffled")
    }

    // MARK: - Statistics Tests

    func testEstimateDailyStudyTime() {
        let set1 = createTestSet(named: "Set 1")
        let set2 = createTestSet(named: "Set 2")

        // Add 10 due cards total
        for i in 0..<10 {
            let card = createTestCard()
            card.nextReviewDate = Date().addingTimeInterval(-3600)
            if i < 5 {
                set1.addCard(card)
            } else {
                set2.addCard(card)
            }
        }

        let estimatedMinutes = manager.estimateDailyStudyTime(for: [set1, set2])

        // 10 cards * 30 seconds = 300 seconds = 5 minutes
        XCTAssertEqual(estimatedMinutes, 5)
    }

    func testGetSetStatistics() {
        let set = createTestSet(named: "Test Set")

        // Add 5 new cards
        for _ in 0..<5 {
            let newCard = createTestCard()
            set.addCard(newCard)
        }

        // Add 3 due cards
        for _ in 0..<3 {
            let dueCard = createTestCard()
            dueCard.reviewCount = 5
            dueCard.nextReviewDate = Date().addingTimeInterval(-3600)
            set.addCard(dueCard)
        }

        // Add 2 not-due cards
        for _ in 0..<2 {
            let futureCard = createTestCard()
            futureCard.reviewCount = 3
            futureCard.nextReviewDate = Date().addingTimeInterval(86400)
            set.addCard(futureCard)
        }

        let stats = manager.getSetStatistics(for: set)

        XCTAssertEqual(stats["totalCards"] as? Int, 10)
        XCTAssertEqual(stats["dueCards"] as? Int, 8) // 5 new + 3 due
        XCTAssertEqual(stats["newCards"] as? Int, 5)
        XCTAssertEqual(stats["totalReviews"] as? Int, 16) // 3*5 + 2*3
    }

    // MARK: - Edge Cases

    func testMultipleResponsesProgression() {
        let card = createTestCard()

        // Simulate learning progression
        manager.scheduleNextReview(for: card, response: .good) // Day 1
        XCTAssertEqual(card.interval, 1)

        manager.scheduleNextReview(for: card, response: .good) // Day 6
        XCTAssertEqual(card.interval, 6)

        manager.scheduleNextReview(for: card, response: .good) // ~Day 21
        XCTAssertEqual(card.interval, 15)

        manager.scheduleNextReview(for: card, response: .easy) // ~Day 57
        let expectedInterval = Int(ceil(15.0 * card.easeFactor * 1.3))
        XCTAssertEqual(card.interval, expectedInterval)
    }

    func testResetProgressWithAgain() {
        let card = createTestCard()

        // Build up progress
        for _ in 0..<5 {
            manager.scheduleNextReview(for: card, response: .easy)
        }

        let highInterval = card.interval
        let highEase = card.easeFactor
        XCTAssertGreaterThan(highInterval, 10)

        // Reset with again
        manager.scheduleNextReview(for: card, response: .again)

        XCTAssertEqual(card.interval, 0)
        XCTAssertLessThan(card.easeFactor, highEase)
    }

    // MARK: - Performance Tests

    func testSchedulingPerformance() {
        let cards = (0..<1000).map { _ in createTestCard() }

        measure {
            for card in cards {
                manager.scheduleNextReview(for: card, response: .good)
            }
        }
    }

    func testQueueGenerationPerformance() {
        let set = createTestSet(named: "Large Set")

        for _ in 0..<500 {
            let card = createTestCard()
            card.nextReviewDate = Date().addingTimeInterval(.random(in: -86400...86400))
            set.addCard(card)
        }

        measure {
            _ = manager.getStudySession(from: set)
        }
    }

    // MARK: - Helper Methods

    private func createTestCard() -> Flashcard {
        let card = Flashcard(
            type: .qa,
            question: "Test Question",
            answer: "Test Answer",
            linkedEntryID: UUID(),
            tags: ["test"]
        )
        context.insert(card)
        return card
    }

    private func createTestSet(named name: String) -> FlashcardSet {
        let set = FlashcardSet(topicLabel: name, tag: name.lowercased())
        context.insert(set)
        return set
    }
}
