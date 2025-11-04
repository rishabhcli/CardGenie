//
//  GameModeModels.swift
//  CardGenie
//
//  Game mode models for matching, true/false, multiple choice, teach-back,
//  and Feynman technique. All with scoring and feedback.
//

import Foundation
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Game Mode Types

enum StudyGameMode: String, Codable {
    case matching           // Match terms to definitions
    case trueFalse         // True/False with justification
    case multipleChoice    // MCQ with distractor analysis
    case teachBack         // Record explanation, get AI feedback
    case feynman           // Explain like you're 5
}

// MARK: - Matching Game

@Model
final class MatchingGame {
    var id: UUID
    var flashcardSetID: UUID
    var pairs: [MatchPair]
    var timeLimit: Int // seconds
    var startTime: Date?
    var endTime: Date?
    var score: Int
    var mistakes: Int

    init(flashcardSetID: UUID, pairs: [MatchPair], timeLimit: Int = 120) {
        self.id = UUID()
        self.flashcardSetID = flashcardSetID
        self.pairs = pairs
        self.timeLimit = timeLimit
        self.startTime = nil
        self.endTime = nil
        self.score = 0
        self.mistakes = 0
    }

    var isComplete: Bool {
        pairs.allSatisfy { $0.isMatched }
    }

    var elapsedTime: TimeInterval {
        guard let start = startTime else { return 0 }
        let end = endTime ?? Date()
        return end.timeIntervalSince(start)
    }

    var accuracy: Double {
        let totalAttempts = pairs.reduce(0) { $0 + $1.attempts }
        guard totalAttempts > 0 else { return 0 }
        return Double(pairs.count) / Double(totalAttempts)
    }
}

@Model
final class MatchPair {
    var id: UUID
    var term: String
    var definition: String
    var isMatched: Bool
    var attempts: Int
    var matchedAt: Date?

    init(term: String, definition: String) {
        self.id = UUID()
        self.term = term
        self.definition = definition
        self.isMatched = false
        self.attempts = 0
        self.matchedAt = nil
    }
}

// MARK: - True/False Game

#if canImport(FoundationModels)
@Generable
struct TrueFalseStatement: Equatable {
    @Guide(description: "A statement that is either true or false based on the flashcard content")
    let statement: String

    @Guide(description: "Whether the statement is true or false")
    let isTrue: Bool

    @Guide(description: "Clear explanation of why the statement is true or false")
    let justification: String
}

@Generable
struct TrueFalseBatch: Equatable {
    @Guide(description: "5-10 true/false statements with justifications")
    @Guide(.count(5...10))
    let statements: [TrueFalseStatement]
}
#else
struct TrueFalseStatement: Equatable {
    let statement: String
    let isTrue: Bool
    let justification: String
}

struct TrueFalseBatch: Equatable {
    let statements: [TrueFalseStatement]
}
#endif

@Model
final class TrueFalseGame {
    var id: UUID
    var flashcardSetID: UUID
    var currentIndex: Int
    var correctCount: Int
    var incorrectCount: Int
    var startTime: Date
    var endTime: Date?

    init(flashcardSetID: UUID) {
        self.id = UUID()
        self.flashcardSetID = flashcardSetID
        self.currentIndex = 0
        self.correctCount = 0
        self.incorrectCount = 0
        self.startTime = Date()
        self.endTime = nil
    }

    var accuracy: Double {
        let total = correctCount + incorrectCount
        guard total > 0 else { return 0 }
        return Double(correctCount) / Double(total)
    }
}

// MARK: - Multiple Choice with Analysis

#if canImport(FoundationModels)
@Generable
struct MultipleChoiceQuestion: Equatable {
    @Guide(description: "The question based on flashcard content")
    let question: String

    @Guide(description: "The correct answer")
    let correctAnswer: String

    @Guide(description: "3 plausible but incorrect distractors")
    @Guide(.count(3...3))
    let distractors: [String]

    @Guide(description: "Explanation of why each distractor is wrong, in same order as distractors")
    @Guide(.count(3...3))
    let distractorAnalysis: [String]

    @Guide(description: "Explanation of why the correct answer is right")
    let correctExplanation: String
}

@Generable
struct MCQBatch: Equatable {
    @Guide(description: "3-5 multiple choice questions with distractor analysis")
    @Guide(.count(3...5))
    let questions: [MultipleChoiceQuestion]
}
#else
struct MultipleChoiceQuestion: Equatable {
    let question: String
    let correctAnswer: String
    let distractors: [String]
    let distractorAnalysis: [String]
    let correctExplanation: String
}

struct MCQBatch: Equatable {
    let questions: [MultipleChoiceQuestion]
}
#endif

@Model
final class MultipleChoiceGame {
    var id: UUID
    var flashcardSetID: UUID
    var currentIndex: Int
    var correctCount: Int
    var incorrectCount: Int
    var startTime: Date
    var endTime: Date?

    init(flashcardSetID: UUID) {
        self.id = UUID()
        self.flashcardSetID = flashcardSetID
        self.currentIndex = 0
        self.correctCount = 0
        self.incorrectCount = 0
        self.startTime = Date()
        self.endTime = nil
    }

    var accuracy: Double {
        let total = correctCount + incorrectCount
        guard total > 0 else { return 0 }
        return Double(correctCount) / Double(total)
    }
}

// MARK: - Teach-Back Mode

@Model
final class TeachBackSession {
    var id: UUID
    var flashcardID: UUID
    var recordingURL: URL?
    var transcription: String?
    var feedback: Data? // Encoded TeachBackFeedback
    var createdAt: Date
    var duration: TimeInterval

    init(flashcardID: UUID) {
        self.id = UUID()
        self.flashcardID = flashcardID
        self.recordingURL = nil
        self.transcription = nil
        self.feedback = nil
        self.createdAt = Date()
        self.duration = 0
    }
}

#if canImport(FoundationModels)
@Generable
struct TeachBackFeedback: Codable, Equatable {
    @Guide(description: "Accuracy of explanation from 1 (incorrect) to 5 (perfectly accurate)")
    @Guide(.range(1...5))
    let accuracy: Int

    @Guide(description: "Clarity of explanation from 1 (confusing) to 5 (crystal clear)")
    @Guide(.range(1...5))
    let clarity: Int

    @Guide(description: "Key points the user explained correctly")
    @Guide(.count(1...5))
    let strengthAreas: [String]

    @Guide(description: "Important details missed or explained incorrectly")
    @Guide(.count(0...5))
    let improvementAreas: [String]

    @Guide(description: "Encouraging, constructive feedback to help the user improve")
    let feedback: String
}
#else
struct TeachBackFeedback: Codable, Equatable {
    let accuracy: Int
    let clarity: Int
    let strengthAreas: [String]
    let improvementAreas: [String]
    let feedback: String
}
#endif

// MARK: - Feynman Technique

#if canImport(FoundationModels)
@Generable
struct FeynmanEvaluation: Codable, Equatable {
    @Guide(description: "Is the explanation simple enough for a 10-year-old to understand?")
    let isSimpleEnough: Bool

    @Guide(description: "Technical jargon or complex terms used that need simplification")
    @Guide(.count(0...5))
    let jargonUsed: [String]

    @Guide(description: "Suggested analogies or everyday examples that would help explain the concept")
    @Guide(.count(2...4))
    let suggestedAnalogies: [String]

    @Guide(description: "A simplified version of the user's explanation using everyday language")
    let simplifiedVersion: String
}
#else
struct FeynmanEvaluation: Codable, Equatable {
    let isSimpleEnough: Bool
    let jargonUsed: [String]
    let suggestedAnalogies: [String]
    let simplifiedVersion: String
}
#endif

@Model
final class FeynmanSession {
    var id: UUID
    var flashcardID: UUID
    var userExplanation: String
    var evaluationData: Data? // Encoded FeynmanEvaluation
    var createdAt: Date

    init(flashcardID: UUID, userExplanation: String) {
        self.id = UUID()
        self.flashcardID = flashcardID
        self.userExplanation = userExplanation
        self.evaluationData = nil
        self.createdAt = Date()
    }
}

// MARK: - Game Statistics

@Model
final class GameStatistics {
    var id: UUID
    var mode: StudyGameMode
    var totalGamesPlayed: Int
    var averageScore: Double
    var averageAccuracy: Double
    var totalTimeSpent: TimeInterval
    var lastPlayedDate: Date?

    init(mode: StudyGameMode) {
        self.id = UUID()
        self.mode = mode
        self.totalGamesPlayed = 0
        self.averageScore = 0
        self.averageAccuracy = 0
        self.totalTimeSpent = 0
        self.lastPlayedDate = nil
    }

    func updateStatistics(score: Int, accuracy: Double, duration: TimeInterval) {
        totalGamesPlayed += 1
        averageScore = ((averageScore * Double(totalGamesPlayed - 1)) + Double(score)) / Double(totalGamesPlayed)
        averageAccuracy = ((averageAccuracy * Double(totalGamesPlayed - 1)) + accuracy) / Double(totalGamesPlayed)
        totalTimeSpent += duration
        lastPlayedDate = Date()
    }
}

// MARK: - Display Helpers

extension StudyGameMode {
    var displayName: String {
        switch self {
        case .matching: return "Matching Game"
        case .trueFalse: return "True or False"
        case .multipleChoice: return "Multiple Choice"
        case .teachBack: return "Teach Back"
        case .feynman: return "Feynman Technique"
        }
    }

    var icon: String {
        switch self {
        case .matching: return "arrow.left.arrow.right"
        case .trueFalse: return "checkmark.seal"
        case .multipleChoice: return "list.bullet.circle"
        case .teachBack: return "mic.circle"
        case .feynman: return "lightbulb"
        }
    }

    var description: String {
        switch self {
        case .matching:
            return "Match terms to definitions against the clock"
        case .trueFalse:
            return "Determine if statements are true or false and explain why"
        case .multipleChoice:
            return "Choose the right answer and learn why others are wrong"
        case .teachBack:
            return "Record yourself explaining the concept, get AI feedback"
        case .feynman:
            return "Explain the concept like you're teaching a 10-year-old"
        }
    }

    var color: String {
        switch self {
        case .matching: return "blue"
        case .trueFalse: return "green"
        case .multipleChoice: return "purple"
        case .teachBack: return "orange"
        case .feynman: return "pink"
        }
    }
}

extension MultipleChoiceQuestion {
    var allOptions: [String] {
        var options = [correctAnswer] + distractors
        return options.shuffled()
    }

    func isCorrect(_ answer: String) -> Bool {
        answer == correctAnswer
    }

    func getAnalysis(for answer: String) -> String {
        if answer == correctAnswer {
            return correctExplanation
        } else if let index = distractors.firstIndex(of: answer) {
            return distractorAnalysis[index]
        }
        return "Please select an answer."
    }
}
