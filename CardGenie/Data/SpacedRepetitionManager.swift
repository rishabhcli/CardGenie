//
//  SpacedRepetitionManager.swift
//  CardGenie
//
//  Implements the SM-2 spaced repetition algorithm for optimal flashcard scheduling.
//  All scheduling happens on-device with no network connectivity required.
//

import Foundation

/// Spaced repetition scheduler based on the SM-2 algorithm
/// Used by Anki and other popular flashcard apps
final class SpacedRepetitionManager {
    // MARK: - SM-2 Constants

    private let minimumEaseFactor: Double = 1.3
    private let initialInterval: Int = 1 // 1 day for first successful review
    private let easyBonus: Double = 1.3 // Multiplier for "Easy" responses

    // MARK: - Review Response

    enum ReviewResponse {
        case again  // Failed to recall (< 60% accuracy)
        case good   // Recalled with effort (60-90% accuracy)
        case easy   // Perfect recall (> 90% accuracy)
    }

    // MARK: - Scheduling

    /// Update a flashcard's scheduling after review
    /// - Parameters:
    ///   - flashcard: The flashcard being reviewed
    ///   - response: User's self-assessment (Again/Good/Easy)
    func scheduleNextReview(for flashcard: Flashcard, response: ReviewResponse) {
        let now = Date()

        // Update review counters
        flashcard.reviewCount += 1
        flashcard.lastReviewed = now

        switch response {
        case .again:
            handleAgainResponse(for: flashcard)
        case .good:
            handleGoodResponse(for: flashcard)
        case .easy:
            handleEasyResponse(for: flashcard)
        }
    }

    // MARK: - Response Handlers

    private func handleAgainResponse(for flashcard: Flashcard) {
        // Failed recall - reset to beginning
        flashcard.againCount += 1

        // Reset interval to relearn
        flashcard.interval = 0

        // Reduce ease factor (but not below minimum)
        flashcard.easeFactor = max(
            minimumEaseFactor,
            flashcard.easeFactor - 0.2
        )

        // Schedule for 10 minutes from now (short relearn interval)
        flashcard.nextReviewDate = Date().addingTimeInterval(10 * 60)
    }

    private func handleGoodResponse(for flashcard: Flashcard) {
        // Successful recall with effort
        flashcard.goodCount += 1

        if flashcard.interval == 0 {
            // First successful review
            flashcard.interval = initialInterval
        } else if flashcard.interval == 1 {
            // Second review
            flashcard.interval = 6 // 6 days
        } else {
            // Subsequent reviews: multiply by ease factor
            flashcard.interval = Int(ceil(Double(flashcard.interval) * flashcard.easeFactor))
        }

        // Maintain ease factor (no change for "Good")
        // Just ensure it doesn't drop below minimum
        flashcard.easeFactor = max(minimumEaseFactor, flashcard.easeFactor)

        // Schedule next review
        flashcard.nextReviewDate = Calendar.current.date(
            byAdding: .day,
            value: flashcard.interval,
            to: Date()
        ) ?? Date()
    }

    private func handleEasyResponse(for flashcard: Flashcard) {
        // Perfect recall - increase ease and extend interval
        flashcard.easyCount += 1

        if flashcard.interval == 0 {
            // First review marked as easy - skip ahead
            flashcard.interval = 4 // 4 days
        } else {
            // Apply easy bonus to interval
            flashcard.interval = Int(ceil(
                Double(flashcard.interval) * flashcard.easeFactor * easyBonus
            ))
        }

        // Increase ease factor for easier future scheduling
        flashcard.easeFactor += 0.15
        flashcard.easeFactor = min(flashcard.easeFactor, 3.0) // Cap at 3.0

        // Schedule next review
        flashcard.nextReviewDate = Calendar.current.date(
            byAdding: .day,
            value: flashcard.interval,
            to: Date()
        ) ?? Date()
    }

    // MARK: - Queue Management

    /// Get all cards due for review today across all sets
    /// - Parameter sets: All flashcard sets
    /// - Returns: Cards due today, sorted by due date
    func getDailyReviewQueue(from sets: [FlashcardSet]) -> [Flashcard] {
        let allCards = sets.flatMap { $0.cards }
        return allCards
            .filter { $0.isDue }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
    }

    /// Get optimal study session (mix of new and due cards)
    /// - Parameters:
    ///   - set: The flashcard set to study
    ///   - maxNew: Maximum new cards to include (default: 5)
    ///   - maxReview: Maximum review cards to include (default: 20)
    /// - Returns: Cards to study in this session
    func getStudySession(
        from set: FlashcardSet,
        maxNew: Int = 5,
        maxReview: Int = 20
    ) -> [Flashcard] {
        var session: [Flashcard] = []

        // Add new cards (limit to maxNew)
        let newCards = set.getNewCards().prefix(maxNew)
        session.append(contentsOf: newCards)

        // Add due review cards (limit to maxReview)
        let dueCards = set.getDueCards().prefix(maxReview)
        session.append(contentsOf: dueCards)

        // Shuffle to mix new and review cards
        return session.shuffled()
    }

    /// Estimate when a card will be due next based on hypothetical response
    /// - Parameters:
    ///   - flashcard: The card to estimate for
    ///   - response: The hypothetical response
    /// - Returns: Estimated next review date
    func estimateNextReview(for flashcard: Flashcard, if response: ReviewResponse) -> Date {
        var interval = flashcard.interval

        switch response {
        case .again:
            return Date().addingTimeInterval(10 * 60) // 10 minutes

        case .good:
            if interval == 0 {
                interval = initialInterval
            } else if interval == 1 {
                interval = 6
            } else {
                interval = Int(ceil(Double(interval) * flashcard.easeFactor))
            }

        case .easy:
            if interval == 0 {
                interval = 4
            } else {
                interval = Int(ceil(
                    Double(interval) * flashcard.easeFactor * easyBonus
                ))
            }
        }

        return Calendar.current.date(
            byAdding: .day,
            value: interval,
            to: Date()
        ) ?? Date()
    }

    // MARK: - Statistics

    /// Calculate optimal study time based on current workload
    /// - Parameter sets: All flashcard sets
    /// - Returns: Estimated minutes needed for daily review
    func estimateDailyStudyTime(for sets: [FlashcardSet]) -> Int {
        let dueCount = getDailyReviewQueue(from: sets).count
        // Estimate 30 seconds per card on average
        return (dueCount * 30) / 60
    }

    /// Get statistics for a flashcard set
    /// - Parameter set: The set to analyze
    /// - Returns: Dictionary of statistics
    func getSetStatistics(for set: FlashcardSet) -> [String: Any] {
        let cards = set.cards

        guard !cards.isEmpty else {
            return [
                "totalCards": 0,
                "dueCards": 0,
                "newCards": 0,
                "averageSuccessRate": 0.0,
                "totalReviews": 0
            ]
        }

        let dueCards = cards.filter { $0.isDue }.count
        let newCards = cards.filter { $0.isNew }.count
        let totalReviews = cards.reduce(0) { $0 + $1.reviewCount }

        let avgSuccessRate = cards.map { $0.successRate }.reduce(0, +) / Double(cards.count)

        return [
            "totalCards": cards.count,
            "dueCards": dueCards,
            "newCards": newCards,
            "averageSuccessRate": avgSuccessRate,
            "totalReviews": totalReviews
        ]
    }
}

// MARK: - Extensions

extension SpacedRepetitionManager.ReviewResponse {
    /// User-friendly display name
    var displayName: String {
        switch self {
        case .again: return "Again"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }

    /// Description of what this rating means
    var description: String {
        switch self {
        case .again:
            return "I didn't recall this. Show it again soon."
        case .good:
            return "I recalled it with effort. Normal interval."
        case .easy:
            return "Perfect recall! Extend the interval."
        }
    }

    /// Color association for UI
    var color: String {
        switch self {
        case .again: return "red"
        case .good: return "blue"
        case .easy: return "green"
        }
    }
}
