//
//  ContentGenerationModels.swift
//  CardGenie
//
//  Models for practice problem synthesis, scenario-based questions,
//  and connection challenges across decks.
//

import Foundation
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Practice Problem Synthesis

#if canImport(FoundationModels)
@Generable
struct PracticeProblemBatch: Equatable, Codable {
    @Guide(description: "3-5 practice problems based on the original concept with variations")
    @Guide(.count(3...5))
    let problems: [PracticeProblem]
}

@Generable
struct PracticeProblem: Equatable, Codable {
    @Guide(description: "The problem statement with different numbers, context, or scenario")
    let problem: String

    @Guide(description: "The correct solution or answer")
    let solution: String

    @Guide(description: "Step-by-step approach to solving the problem")
    @Guide(.count(2...5))
    let steps: [String]

    @Guide(description: "Difficulty compared to original: easier, same, or harder")
    let difficulty: RelativeDifficulty
}

@Generable
enum RelativeDifficulty: String, Codable {
    case easier
    case same
    case harder
}
#else
struct PracticeProblemBatch: Equatable, Codable {
    let problems: [PracticeProblem]
}

struct PracticeProblem: Equatable, Codable {
    let problem: String
    let solution: String
    let steps: [String]
    let difficulty: RelativeDifficulty
}

enum RelativeDifficulty: String, Equatable, Codable {
    case easier
    case same
    case harder
}
#endif

// MARK: - Scenario-Based Questions

#if canImport(FoundationModels)
@Generable
struct ScenarioQuestion: Equatable, Codable {
    @Guide(description: "Real-world scenario that applies the concept")
    let scenario: String

    @Guide(description: "Question about how to apply the concept in this scenario")
    let question: String

    @Guide(description: "Best answer or approach for the scenario")
    let idealAnswer: String

    @Guide(description: "Reasoning explaining why this answer is best")
    let reasoning: String
}

@Generable
struct ScenarioBatch: Equatable, Codable {
    @Guide(description: "2-4 scenario-based application questions")
    @Guide(.count(2...4))
    let scenarios: [ScenarioQuestion]
}
#else
struct ScenarioQuestion: Equatable, Codable {
    let scenario: String
    let question: String
    let idealAnswer: String
    let reasoning: String
}

struct ScenarioBatch: Equatable, Codable {
    let scenarios: [ScenarioQuestion]
}
#endif

// MARK: - Connection Challenges

#if canImport(FoundationModels)
@Generable
struct ConnectionChallenge: Equatable, Codable {
    @Guide(description: "Name or topic of the related flashcard deck")
    let relatedDeck: String

    @Guide(description: "How the concepts from both decks connect or relate")
    let connection: String

    @Guide(description: "Question that requires understanding both concepts together")
    let synthesisQuestion: String

    @Guide(description: "Answer demonstrating integrated understanding of both concepts")
    let integratedAnswer: String
}

@Generable
struct ConnectionBatch: Equatable, Codable {
    @Guide(description: "2-3 connection challenges between different decks")
    @Guide(.count(2...3))
    let challenges: [ConnectionChallenge]
}
#else
struct ConnectionChallenge: Equatable, Codable {
    let relatedDeck: String
    let connection: String
    let synthesisQuestion: String
    let integratedAnswer: String
}

struct ConnectionBatch: Equatable, Codable {
    let challenges: [ConnectionChallenge]
}
#endif

// MARK: - Generated Content Storage

@Model
final class GeneratedPracticeSet {
    @Attribute(.unique) var id: UUID
    var sourceFlashcardID: UUID
    var problemsData: Data // Encoded [PracticeProblem]
    var createdAt: Date
    var completedCount: Int

    init(sourceFlashcardID: UUID, problemsData: Data) {
        self.id = UUID()
        self.sourceFlashcardID = sourceFlashcardID
        self.problemsData = problemsData
        self.createdAt = Date()
        self.completedCount = 0
    }
}

@Model
final class GeneratedScenarioSet {
    @Attribute(.unique) var id: UUID
    var sourceFlashcardID: UUID
    var scenariosData: Data // Encoded [ScenarioQuestion]
    var createdAt: Date
    var completedCount: Int

    init(sourceFlashcardID: UUID, scenariosData: Data) {
        self.id = UUID()
        self.sourceFlashcardID = sourceFlashcardID
        self.scenariosData = scenariosData
        self.createdAt = Date()
        self.completedCount = 0
    }
}

@Model
final class GeneratedConnectionSet {
    @Attribute(.unique) var id: UUID
    var flashcard1ID: UUID
    var flashcard2ID: UUID
    var challengesData: Data // Encoded [ConnectionChallenge]
    var createdAt: Date
    var completedCount: Int

    init(flashcard1ID: UUID, flashcard2ID: UUID, challengesData: Data) {
        self.id = UUID()
        self.flashcard1ID = flashcard1ID
        self.flashcard2ID = flashcard2ID
        self.challengesData = challengesData
        self.createdAt = Date()
        self.completedCount = 0
    }
}

// MARK: - Display Helpers

extension RelativeDifficulty {
    var displayName: String {
        switch self {
        case .easier: return "Easier"
        case .same: return "Same Difficulty"
        case .harder: return "Harder"
        }
    }

    var icon: String {
        switch self {
        case .easier: return "arrow.down.circle"
        case .same: return "equal.circle"
        case .harder: return "arrow.up.circle"
        }
    }

    var color: String {
        switch self {
        case .easier: return "green"
        case .same: return "blue"
        case .harder: return "red"
        }
    }
}

extension PracticeProblem {
    var stepsFormatted: String {
        steps.enumerated().map { (index, step) in
            "\(index + 1). \(step)"
        }.joined(separator: "\n")
    }
}

extension ScenarioQuestion {
    var fullQuestion: String {
        "\(scenario)\n\n\(question)"
    }
}

// MARK: - Coding Helpers

// These extensions are only for the fallback (non-Foundation Models) versions
#if !canImport(FoundationModels)
extension DifficultyLevel: Codable {}

extension Array where Element == PracticeProblem {
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decode(from data: Data) throws -> [PracticeProblem] {
        try JSONDecoder().decode([PracticeProblem].self, from: data)
    }
}

extension Array where Element == ScenarioQuestion {
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decode(from data: Data) throws -> [ScenarioQuestion] {
        try JSONDecoder().decode([ScenarioQuestion].self, from: data)
    }
}

extension Array where Element == ConnectionChallenge {
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decode(from data: Data) throws -> [ConnectionChallenge] {
        try JSONDecoder().decode([ConnectionChallenge].self, from: data)
    }
}
#endif
