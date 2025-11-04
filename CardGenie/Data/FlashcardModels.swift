//
//  FlashcardModels.swift
//  CardGenie
//
//  Data models for flashcard features using SwiftData.
//  Supports intelligent flashcard generation and spaced repetition.
//

import Foundation
import SwiftData

// MARK: - Flashcard Type

/// The format/type of a flashcard
enum FlashcardType: String, Codable {
    case cloze = "cloze"              // Cloze deletion (fill in the blank)
    case qa = "qa"                    // Question & Answer pairs
    case definition = "definition"     // Term-Definition cards
}

// MARK: - Flashcard Model

/// An individual flashcard generated from journal content
/// All data is stored locally and never leaves the device
@Model
final class Flashcard {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Type of flashcard (cloze, Q&A, definition)
    var type: FlashcardType

    /// The question or prompt text
    /// For cloze cards: sentence with blank (e.g., "_____ designed the Eiffel Tower")
    /// For Q&A: the question
    /// For definition: the term to define
    var question: String

    /// The answer or missing term
    /// For cloze: the hidden word
    /// For Q&A: the factual answer
    /// For definition: the explanation
    var answer: String

    /// Reference to the source journal entry
    /// Allows tracing flashcards back to their origin
    var linkedEntryID: UUID

    /// Topic tags for organization and search
    var tags: [String]

    /// When the flashcard was created
    var createdAt: Date

    // MARK: - Spaced Repetition Properties

    /// Next scheduled review date
    var nextReviewDate: Date

    /// Ease factor for spaced repetition (SM-2 algorithm)
    /// Higher = easier, schedule further apart
    var easeFactor: Double

    /// Current interval in days between reviews
    var interval: Int

    /// Number of times reviewed
    var reviewCount: Int

    /// Number of times marked "Again" (failed recall)
    var againCount: Int

    /// Number of times marked "Good"
    var goodCount: Int

    /// Number of times marked "Easy"
    var easyCount: Int

    /// Last review date
    var lastReviewed: Date?

    /// JSON-encoded metadata for advanced card types (multiple choice, etc.)
    var metadataJSON: String?

    // MARK: - Relationship

    /// The flashcard set this card belongs to
    @Relationship(inverse: \FlashcardSet.cards)
    var set: FlashcardSet?

    /// Handwriting data for this card (optional)
    @Relationship(deleteRule: .cascade)
    var handwritingData: HandwritingData?

    // MARK: - Initialization

    init(
        type: FlashcardType,
        question: String,
        answer: String,
        linkedEntryID: UUID,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.type = type
        self.question = question
        self.answer = answer
        self.linkedEntryID = linkedEntryID
        self.tags = tags
        self.createdAt = Date()

        // Initialize spaced repetition properties
        self.nextReviewDate = Date() // Due immediately for new cards
        self.easeFactor = 2.5 // Default ease factor (SM-2)
        self.interval = 0 // New card
        self.reviewCount = 0
        self.againCount = 0
        self.goodCount = 0
        self.easyCount = 0
        self.lastReviewed = nil
        self.metadataJSON = nil
    }

    // MARK: - Computed Properties

    /// Whether this card is due for review
    var isDue: Bool {
        nextReviewDate <= Date()
    }

    /// Whether this is a new card (never reviewed)
    var isNew: Bool {
        reviewCount == 0
    }

    /// Success rate (percentage of Good + Easy ratings)
    var successRate: Double {
        guard reviewCount > 0 else { return 0 }
        let successCount = goodCount + easyCount
        return Double(successCount) / Double(reviewCount)
    }

    /// Display string for card type
    var typeDisplayName: String {
        switch type {
        case .cloze: return "Cloze Deletion"
        case .qa: return "Q&A"
        case .definition: return "Definition"
        }
    }

    // MARK: - Mastery Level

    /// Mastery level based on ease factor and review count
    enum MasteryLevel: String {
        case learning = "Learning" // Just started
        case developing = "Developing" // Getting better
        case proficient = "Proficient" // Solid knowledge
        case mastered = "Mastered" // Expert level

        var emoji: String {
            switch self {
            case .learning: return "🌱"
            case .developing: return "📈"
            case .proficient: return "⭐️"
            case .mastered: return "🏆"
            }
        }

        var color: String {
            switch self {
            case .learning: return "orange"
            case .developing: return "blue"
            case .proficient: return "purple"
            case .mastered: return "gold"
            }
        }
    }

    /// Calculate current mastery level
    var masteryLevel: MasteryLevel {
        if reviewCount == 0 {
            return .learning
        } else if reviewCount < 5 || easeFactor < 2.2 {
            return .developing
        } else if reviewCount < 10 || easeFactor < 2.7 {
            return .proficient
        } else {
            return .mastered
        }
    }

    /// Progress towards next mastery level (0.0 to 1.0)
    var masteryProgress: Double {
        let level = masteryLevel
        switch level {
        case .learning:
            return reviewCount > 0 ? Double(reviewCount) / 2.0 : 0.0
        case .developing:
            let reviewProgress = min(Double(reviewCount) / 5.0, 1.0) * 0.5
            let easeProgress = min((easeFactor - 2.0) / 0.2, 1.0) * 0.5
            return reviewProgress + easeProgress
        case .proficient:
            let reviewProgress = min(Double(reviewCount - 5) / 5.0, 1.0) * 0.5
            let easeProgress = min((easeFactor - 2.2) / 0.5, 1.0) * 0.5
            return reviewProgress + easeProgress
        case .mastered:
            return 1.0
        }
    }
}

// MARK: - FlashcardSet Model

/// A collection of flashcards grouped by topic
/// Organizes cards for efficient study sessions
@Model
final class FlashcardSet {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Human-readable topic name (e.g., "History", "Work", "Travel")
    var topicLabel: String

    /// Primary tag for categorization
    var tag: String

    /// When the set was created
    var createdDate: Date

    /// Number of source journal entries that contributed to this set
    var entryCount: Int

    // MARK: - Performance Tracking

    /// Total number of reviews across all cards in this set
    var totalReviews: Int

    /// Average ease factor across cards
    var averageEase: Double

    /// Last time any card in this set was reviewed
    var lastReviewDate: Date?

    // MARK: - Relationship

    /// All flashcards in this set
    @Relationship(deleteRule: .cascade)
    var cards: [Flashcard]

    // MARK: - Initialization

    init(topicLabel: String, tag: String) {
        self.id = UUID()
        self.topicLabel = topicLabel
        self.tag = tag
        self.createdDate = Date()
        self.entryCount = 0
        self.totalReviews = 0
        self.averageEase = 2.5
        self.lastReviewDate = nil
        self.cards = []
    }

    // MARK: - Computed Properties

    /// Total number of cards in this set
    var cardCount: Int {
        cards.count
    }

    /// Number of cards due for review today
    var dueCount: Int {
        cards.filter { $0.isDue }.count
    }

    /// Number of new cards (never reviewed)
    var newCount: Int {
        cards.filter { $0.isNew }.count
    }

    /// Overall success rate for this set
    var successRate: Double {
        guard !cards.isEmpty else { return 0 }
        let rates = cards.map { $0.successRate }
        return rates.reduce(0, +) / Double(cards.count)
    }

    // MARK: - Methods

    /// Add a flashcard to this set
    func addCard(_ card: Flashcard) {
        cards.append(card)
        card.set = self
    }

    /// Update performance metadata after a review
    func updatePerformanceMetrics() {
        totalReviews = cards.reduce(0) { $0 + $1.reviewCount }

        if !cards.isEmpty {
            let easeSum = cards.reduce(0.0) { $0 + $1.easeFactor }
            averageEase = easeSum / Double(cards.count)
        }

        lastReviewDate = cards.compactMap { $0.lastReviewed }.max()
    }
}

// MARK: - Helper Extensions

extension Flashcard {
    /// Format question for display (handles cloze blanks)
    var formattedQuestion: String {
        question
    }

    /// Format answer for display
    var formattedAnswer: String {
        answer
    }
}

extension FlashcardSet {
    /// Get cards due for review, sorted by due date
    func getDueCards() -> [Flashcard] {
        cards
            .filter { $0.isDue }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
    }

    /// Get new cards (never reviewed)
    func getNewCards() -> [Flashcard] {
        cards
            .filter { $0.isNew }
            .sorted { $0.createdAt < $1.createdAt }
    }
}

// MARK: - ModelContext Helpers

extension ModelContext {
    /// Find an existing flashcard set for a topic or create a new one if needed.
    /// Ensures topic tags are normalized to avoid duplicate sets.
    func findOrCreateFlashcardSet(topicLabel: String) -> FlashcardSet {
        let trimmedLabel = topicLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLabel = trimmedLabel.isEmpty ? "General" : trimmedLabel
        let normalizedTag = normalizedLabel.lowercased()

        let descriptor = FetchDescriptor<FlashcardSet>(
            predicate: #Predicate { $0.tag == normalizedTag }
        )

        if let existing = try? fetch(descriptor).first {
            return existing
        }

        let newSet = FlashcardSet(topicLabel: normalizedLabel, tag: normalizedTag)
        insert(newSet)
        return newSet
    }
}
