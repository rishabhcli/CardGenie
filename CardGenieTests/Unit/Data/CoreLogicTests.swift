//
//  CoreLogicTests.swift
//  CardGenieTests
//

import XCTest
@testable import CardGenie

final class SpacedRepetitionManagerTests: XCTestCase {
    let manager = SpacedRepetitionManager()

    func testAgainResponseResetsInterval() {
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        card.interval = 5
        card.easeFactor = 2.5

        manager.scheduleNextReview(for: card, response: .again)

        XCTAssertEqual(card.interval, 0)
        XCTAssertLessThanOrEqual(card.easeFactor, 2.3)
        XCTAssertTrue(card.nextReviewDate <= Date().addingTimeInterval(10 * 60 + 1))
    }

    func testGoodResponseProgressesIntervals() {
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())

        manager.scheduleNextReview(for: card, response: .good) // interval becomes 1
        XCTAssertEqual(card.interval, 1)

        manager.scheduleNextReview(for: card, response: .good) // interval becomes 6
        XCTAssertEqual(card.interval, 6)
    }

    func testDailyReviewQueueSortedByDueDate() {
        let set = FlashcardSet(topicLabel: "Test", tag: "test")

        let soon = Flashcard(type: .qa, question: "Soon", answer: "A", linkedEntryID: UUID())
        soon.nextReviewDate = Date().addingTimeInterval(-60)

        let later = Flashcard(type: .qa, question: "Later", answer: "A", linkedEntryID: UUID())
        later.nextReviewDate = Date().addingTimeInterval(60)

        set.addCard(soon)
        set.addCard(later)

        let queue = manager.getDailyReviewQueue(from: [set])
        XCTAssertEqual(queue.first?.question, "Soon")
    }

    func testStudySessionMixesNewAndDueCards() {
        let set = FlashcardSet(topicLabel: "Mix", tag: "mix")

        for _ in 0..<10 {
            let card = Flashcard(type: .qa, question: "New", answer: "A", linkedEntryID: UUID())
            set.addCard(card)
        }

        for idx in 0..<10 {
            let card = Flashcard(type: .qa, question: "Due \(idx)", answer: "A", linkedEntryID: UUID())
            card.reviewCount = 3
            card.nextReviewDate = Date().addingTimeInterval(-3600)
            set.addCard(card)
        }

        let session = manager.getStudySession(from: set, maxNew: 5, maxReview: 7)
        XCTAssertLessThanOrEqual(session.filter { $0.isNew }.count, 5)
        XCTAssertLessThanOrEqual(session.filter { $0.isDue }.count, 7)
        XCTAssertFalse(session.isEmpty)
    }
}
