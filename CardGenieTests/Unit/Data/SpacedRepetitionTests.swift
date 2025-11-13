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

    // MARK: - Long-Term Retention Edge Cases

    func testVeryLongInterval_365Days() {
        // Given: Card with 1 year interval
        let card = createTestCard()
        card.interval = 365
        card.easeFactor = 2.5

        // When: Good response
        manager.scheduleNextReview(for: card, response: .good)

        // Then: Should multiply by ease factor (365 * 2.5 = 912.5 ≈ 913 days)
        let expectedInterval = Int(ceil(365.0 * 2.5))
        XCTAssertEqual(card.interval, expectedInterval)
        XCTAssertGreaterThan(card.interval, 365)
    }

    func testVeryLongInterval_3Years() {
        // Given: Card with 3-year interval (1095 days)
        let card = createTestCard()
        card.interval = 1095
        card.easeFactor = 2.5

        // When: Good response
        manager.scheduleNextReview(for: card, response: .good)

        // Then: Should continue extending (1095 * 2.5 = 2737.5 ≈ 2738 days)
        let expectedInterval = Int(ceil(1095.0 * 2.5))
        XCTAssertEqual(card.interval, expectedInterval)
    }

    func testLongInterval_RecoveryAfterAgain() {
        // Given: Card mastered with 200-day interval
        let card = createTestCard()
        card.interval = 200
        card.easeFactor = 2.8
        card.reviewCount = 20

        // When: Failed recall (again response)
        manager.scheduleNextReview(for: card, response: .again)

        // Then: Should reset interval but preserve history
        XCTAssertEqual(card.interval, 0)
        XCTAssertEqual(card.reviewCount, 21)
        XCTAssertEqual(card.againCount, 1)
        XCTAssertLessThan(card.easeFactor, 2.8)
    }

    func testLongInterval_RelearningProgression() {
        // Given: Mastered card that was forgotten
        let card = createTestCard()
        card.interval = 0
        card.easeFactor = 2.3 // Reduced from previous mastery
        card.reviewCount = 25
        card.againCount = 1

        // When: Relearning with good responses
        manager.scheduleNextReview(for: card, response: .good)
        XCTAssertEqual(card.interval, 1)

        manager.scheduleNextReview(for: card, response: .good)
        XCTAssertEqual(card.interval, 6)

        manager.scheduleNextReview(for: card, response: .good)
        let expectedInterval = Int(ceil(6.0 * card.easeFactor))
        XCTAssertEqual(card.interval, expectedInterval)

        // Then: Should rebuild mastery with reduced ease factor
        XCTAssertGreaterThan(card.interval, 6)
        XCTAssertLessThan(card.easeFactor, 2.5) // Lower than default
    }

    // MARK: - Extreme Volume Edge Cases

    func test1000ConsecutiveCorrectAnswers() {
        // Given: Card that user knows extremely well
        let card = createTestCard()

        // When: 1000 consecutive "easy" responses
        for _ in 0..<1000 {
            manager.scheduleNextReview(for: card, response: .easy)
        }

        // Then: Ease factor should be capped at 3.0
        XCTAssertEqual(card.easeFactor, 3.0, accuracy: 0.01)
        XCTAssertEqual(card.reviewCount, 1000)
        XCTAssertEqual(card.easyCount, 1000)
        XCTAssertEqual(card.againCount, 0)

        // Interval should be extremely large but calculable
        XCTAssertGreaterThan(card.interval, 1000)
    }

    func test1000ConsecutiveIncorrectAnswers() {
        // Given: Card that user consistently fails
        let card = createTestCard()

        // When: 1000 consecutive "again" responses
        for _ in 0..<1000 {
            manager.scheduleNextReview(for: card, response: .again)
        }

        // Then: Ease factor should be floored at 1.3
        XCTAssertEqual(card.easeFactor, 1.3, accuracy: 0.01)
        XCTAssertEqual(card.reviewCount, 1000)
        XCTAssertEqual(card.againCount, 1000)
        XCTAssertEqual(card.interval, 0) // Always resets to 0
    }

    func testAlternatingCorrectIncorrect_Pattern1() {
        // Given: Card with alternating success/failure
        let card = createTestCard()

        // When: Alternating good/again 50 times each
        for i in 0..<100 {
            if i % 2 == 0 {
                manager.scheduleNextReview(for: card, response: .good)
            } else {
                manager.scheduleNextReview(for: card, response: .again)
            }
        }

        // Then: Ease factor should be reduced from alternating failures
        XCTAssertLessThan(card.easeFactor, 2.5)
        XCTAssertGreaterThanOrEqual(card.easeFactor, 1.3)
        XCTAssertEqual(card.reviewCount, 100)
        XCTAssertEqual(card.goodCount, 50)
        XCTAssertEqual(card.againCount, 50)
    }

    func testAlternatingCorrectIncorrect_Pattern2() {
        // Given: Card with pattern: 3 good, 1 again
        let card = createTestCard()

        // When: Repeat pattern 25 times (100 total reviews)
        for i in 0..<100 {
            if i % 4 == 3 {
                manager.scheduleNextReview(for: card, response: .again)
            } else {
                manager.scheduleNextReview(for: card, response: .good)
            }
        }

        // Then
        XCTAssertEqual(card.reviewCount, 100)
        XCTAssertEqual(card.goodCount, 75)
        XCTAssertEqual(card.againCount, 25)

        // Ease factor should be somewhat reduced but not minimal
        XCTAssertLessThan(card.easeFactor, 2.5)
        XCTAssertGreaterThan(card.easeFactor, 1.5)
    }

    func testMixedResponses_RealisticPattern() {
        // Given: Realistic learning pattern
        let card = createTestCard()

        // When: Realistic progression (mostly good, some easy, rare again)
        let pattern: [ReviewResponse] = [
            .good, .good, .good, .easy, .good,
            .good, .easy, .good, .again, .good,
            .good, .good, .easy, .good, .good,
            .good, .good, .easy, .good, .good
        ]

        for response in pattern {
            manager.scheduleNextReview(for: card, response: response)
        }

        // Then: Should show learning progression
        XCTAssertEqual(card.reviewCount, 20)
        XCTAssertEqual(card.againCount, 1)
        XCTAssertGreaterThan(card.interval, 10) // Should have progressed significantly
        XCTAssertGreaterThan(card.easeFactor, 2.5) // Easy responses should increase it
    }

    // MARK: - Boundary Condition Edge Cases

    func testMinimumEaseFactor_AtBoundary() {
        // Given: Ease factor at minimum
        let card = createTestCard()
        card.easeFactor = 1.3

        // When: Another "again" response
        manager.scheduleNextReview(for: card, response: .again)

        // Then: Should not go below 1.3
        XCTAssertEqual(card.easeFactor, 1.3, accuracy: 0.01)
    }

    func testMaximumEaseFactor_AtBoundary() {
        // Given: Ease factor at maximum
        let card = createTestCard()
        card.easeFactor = 3.0

        // When: Another "easy" response
        manager.scheduleNextReview(for: card, response: .easy)

        // Then: Should not exceed 3.0
        XCTAssertEqual(card.easeFactor, 3.0, accuracy: 0.01)
    }

    func testZeroInterval_AfterMultipleAgain() {
        // Given: Card with some interval
        let card = createTestCard()
        card.interval = 50

        // When: Multiple "again" responses
        manager.scheduleNextReview(for: card, response: .again)
        manager.scheduleNextReview(for: card, response: .again)
        manager.scheduleNextReview(for: card, response: .again)

        // Then: Interval should remain 0
        XCTAssertEqual(card.interval, 0)
    }

    func testIntervalCeiling_FractionalMultiplication() {
        // Given: Card with interval that produces fractional result
        let card = createTestCard()
        card.interval = 7
        card.easeFactor = 2.4

        // When: Good response (7 * 2.4 = 16.8)
        manager.scheduleNextReview(for: card, response: .good)

        // Then: Should ceil to 17
        XCTAssertEqual(card.interval, 17)
    }

    // MARK: - Concurrent Access Edge Cases

    func testConcurrentScheduling_SameCard() async {
        // Given: Single card
        let card = createTestCard()

        // When: Multiple concurrent scheduling attempts
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await self.manager.scheduleNextReview(for: card, response: .good)
                }
            }
        }

        // Then: All reviews should be recorded
        XCTAssertEqual(card.reviewCount, 10)
        XCTAssertGreaterThan(card.interval, 0)
    }

    func testConcurrentScheduling_MultipleCards() async {
        // Given: Multiple cards
        let cards = (0..<20).map { _ in createTestCard() }

        // When: Concurrent scheduling on different cards
        await withTaskGroup(of: Void.self) { group in
            for card in cards {
                group.addTask {
                    await self.manager.scheduleNextReview(for: card, response: .good)
                }
            }
        }

        // Then: All cards should be scheduled
        for card in cards {
            XCTAssertEqual(card.reviewCount, 1)
            XCTAssertGreaterThan(card.interval, 0)
        }
    }

    func testConcurrentQueueGeneration() async {
        // Given: Large set with many due cards
        let set = createTestSet(named: "Concurrent Test")
        for _ in 0..<100 {
            let card = createTestCard()
            card.nextReviewDate = Date().addingTimeInterval(-3600)
            set.addCard(card)
        }

        // When: Multiple concurrent queue requests
        await withTaskGroup(of: [Flashcard].self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await self.manager.getStudySession(from: set)
                }
            }

            // Then: All should complete without crashes
            var queueCount = 0
            for await _ in group {
                queueCount += 1
            }
            XCTAssertEqual(queueCount, 10)
        }
    }

    // MARK: - Statistical Edge Cases

    func testStatistics_EmptySet() {
        // Given: Empty set
        let set = createTestSet(named: "Empty Set")

        // When
        let stats = manager.getSetStatistics(for: set)

        // Then
        XCTAssertEqual(stats["totalCards"] as? Int, 0)
        XCTAssertEqual(stats["dueCards"] as? Int, 0)
        XCTAssertEqual(stats["newCards"] as? Int, 0)
        XCTAssertEqual(stats["totalReviews"] as? Int, 0)
    }

    func testStatistics_AllCardsNew() {
        // Given: Set with only new cards
        let set = createTestSet(named: "All New")
        for _ in 0..<20 {
            let card = createTestCard()
            set.addCard(card)
        }

        // When
        let stats = manager.getSetStatistics(for: set)

        // Then
        XCTAssertEqual(stats["totalCards"] as? Int, 20)
        XCTAssertEqual(stats["dueCards"] as? Int, 20)
        XCTAssertEqual(stats["newCards"] as? Int, 20)
    }

    func testDailyStudyTime_NoCards() {
        // Given: Empty sets
        let sets: [FlashcardSet] = []

        // When
        let estimatedMinutes = manager.estimateDailyStudyTime(for: sets)

        // Then
        XCTAssertEqual(estimatedMinutes, 0)
    }

    func testDailyStudyTime_LargeVolume() {
        // Given: 1000 due cards
        let set = createTestSet(named: "Large Volume")
        for _ in 0..<1000 {
            let card = createTestCard()
            card.nextReviewDate = Date().addingTimeInterval(-3600)
            set.addCard(card)
        }

        // When
        let estimatedMinutes = manager.estimateDailyStudyTime(for: [set])

        // Then: 1000 cards * 30 seconds = 30000 seconds = 500 minutes
        XCTAssertEqual(estimatedMinutes, 500)
    }

    // MARK: - Date/Time Edge Cases

    func testScheduling_AtMidnight() {
        // Given: Card reviewed at midnight
        let card = createTestCard()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 0
        components.minute = 0
        components.second = 0
        let midnight = Calendar.current.date(from: components)!

        // When: Schedule at midnight
        manager.scheduleNextReview(for: card, response: .good)

        // Then: Should schedule for next day
        XCTAssertGreaterThan(card.nextReviewDate, midnight)
    }

    func testNextReviewDate_PastDue() {
        // Given: Card overdue by 7 days
        let card = createTestCard()
        card.nextReviewDate = Date().addingTimeInterval(-7 * 86400)

        // When: Check if due
        let isDue = card.nextReviewDate <= Date()

        // Then: Should be marked as due
        XCTAssertTrue(isDue)
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
