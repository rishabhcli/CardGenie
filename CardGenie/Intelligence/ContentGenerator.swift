//
//  ContentGenerator.swift
//  CardGenie
//
//  AI-powered content generation for practice problems, scenario-based questions,
//  and connection challenges. All processing happens on-device using Foundation Models.
//

import Foundation
import Combine
import OSLog
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class ContentGenerator: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private let log = Logger(subsystem: "com.cardgenie.app", category: "ContentGenerator")

    init() {}

    // MARK: - Practice Problem Synthesis

    /// Generate practice problems based on an original flashcard
    /// - Parameters:
    ///   - flashcard: The source flashcard
    ///   - count: Number of problems to generate (default 3)
    /// - Returns: Array of practice problems with solutions
    func generatePracticeProblems(
        from flashcard: Flashcard,
        count: Int = 3
    ) async throws -> [PracticeProblem] {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        log.info("Generating \(count) practice problems...")

        let session = LanguageModelSession {
            """
            You are creating practice problems based on an original problem.
            Vary the numbers, context, and difficulty slightly while maintaining the same conceptual pattern.
            Provide step-by-step solutions to help students learn.
            Create a mix of easier, similar, and harder variations.
            """
        }

        let prompt = """
            Original Problem: \(flashcard.question)
            Original Solution: \(flashcard.answer)

            Generate \(count) similar practice problems with:
            - Different numbers or scenarios
            - Clear solutions
            - Step-by-step solving approaches
            - A mix of difficulties (easier, same, harder)
            """

        let options = GenerationOptions(sampling: .greedy, temperature: 0.9)
        let response = try await session.respond(
            to: prompt,
            generating: PracticeProblemBatch.self,
            options: options
        )

        log.info("Generated \(response.content.problems.count) practice problems")
        return response.content.problems

        #else
        // Fallback: Simple variations
        log.info("Using fallback practice problem generation")
        return [
            PracticeProblem(
                problem: "Practice problem based on: \(flashcard.question)",
                solution: "Similar to: \(flashcard.answer)",
                steps: ["Review the concept", "Apply the same approach"],
                difficulty: .same
            )
        ]
        #endif
    }

    // MARK: - Scenario-Based Questions

    /// Generate real-world scenarios that apply the concept
    /// - Parameter flashcard: The source flashcard
    /// - Returns: Array of scenario-based questions
    func generateScenarios(
        from flashcard: Flashcard
    ) async throws -> [ScenarioQuestion] {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        log.info("Generating scenario-based questions...")

        let session = LanguageModelSession {
            """
            You are creating real-world scenarios that apply abstract concepts.
            Make scenarios realistic, relatable, and thought-provoking.
            Show how the concept appears in everyday situations or professional contexts.
            Provide ideal answers with clear reasoning.
            """
        }

        let prompt = """
            Concept: \(flashcard.question)
            Answer: \(flashcard.answer)

            Create 2-4 real-world scenarios where this concept applies:
            - Everyday life situations
            - Professional or academic contexts
            - Practical decision-making scenarios
            Each with a question, ideal answer, and reasoning.
            """

        let options = GenerationOptions(sampling: .greedy, temperature: 0.8)
        let response = try await session.respond(
            to: prompt,
            generating: ScenarioBatch.self,
            options: options
        )

        log.info("Generated \(response.content.scenarios.count) scenarios")
        return response.content.scenarios

        #else
        // Fallback: Simple application question
        log.info("Using fallback scenario generation")
        return [
            ScenarioQuestion(
                scenario: "Consider a real-world situation related to: \(flashcard.question)",
                question: "How would you apply this concept?",
                idealAnswer: flashcard.answer,
                reasoning: "This concept is useful in practical situations."
            )
        ]
        #endif
    }

    // MARK: - Connection Challenges

    /// Generate questions that connect concepts across two flashcard decks
    /// - Parameters:
    ///   - flashcard1: First flashcard from deck 1
    ///   - flashcard2: Second flashcard from deck 2
    ///   - deck1Name: Name of the first deck
    ///   - deck2Name: Name of the second deck
    /// - Returns: Array of connection challenges
    func generateConnectionChallenges(
        flashcard1: Flashcard,
        flashcard2: Flashcard,
        deck1Name: String,
        deck2Name: String
    ) async throws -> [ConnectionChallenge] {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        log.info("Generating connection challenges between \(deck1Name) and \(deck2Name)...")

        let session = LanguageModelSession {
            """
            You help students connect concepts across different topics.
            Find non-obvious relationships and create synthesis questions.
            Show how seemingly unrelated concepts share underlying patterns or principles.
            Create questions that require understanding both concepts together.
            """
        }

        let prompt = """
            Deck 1 (\(deck1Name)):
            Question: \(flashcard1.question)
            Answer: \(flashcard1.answer)

            Deck 2 (\(deck2Name)):
            Question: \(flashcard2.question)
            Answer: \(flashcard2.answer)

            Generate 2-3 connection challenges:
            - Show how these concepts relate
            - Create questions requiring both concepts
            - Provide integrated answers demonstrating deep understanding
            """

        let options = GenerationOptions(sampling: .greedy, temperature: 0.7)
        let response = try await session.respond(
            to: prompt,
            generating: ConnectionBatch.self,
            options: options
        )

        log.info("Generated \(response.content.challenges.count) connection challenges")
        return response.content.challenges

        #else
        // Fallback: Simple connection
        log.info("Using fallback connection generation")
        return [
            ConnectionChallenge(
                relatedDeck: deck2Name,
                connection: "Both concepts involve similar principles.",
                synthesisQuestion: "How do the concepts from \(deck1Name) and \(deck2Name) relate?",
                integratedAnswer: "They share common underlying patterns."
            )
        ]
        #endif
    }

    // MARK: - Bulk Generation

    /// Generate multiple types of content for a flashcard at once
    /// - Parameter flashcard: The source flashcard
    /// - Returns: Tuple of problems, scenarios, and connection suggestions
    func generateAllContent(
        for flashcard: Flashcard
    ) async throws -> (problems: [PracticeProblem], scenarios: [ScenarioQuestion]) {
        async let problems = generatePracticeProblems(from: flashcard)
        async let scenarios = generateScenarios(from: flashcard)

        return try await (problems, scenarios)
    }

    // MARK: - Content Caching

    /// Cache generated content to avoid regeneration
    private var practiceCache: [UUID: [PracticeProblem]] = [:]
    private var scenarioCache: [UUID: [ScenarioQuestion]] = [:]

    func getCachedPracticeProblems(for flashcardID: UUID) -> [PracticeProblem]? {
        practiceCache[flashcardID]
    }

    func cachePracticeProblems(_ problems: [PracticeProblem], for flashcardID: UUID) {
        practiceCache[flashcardID] = problems
    }

    func getCachedScenarios(for flashcardID: UUID) -> [ScenarioQuestion]? {
        scenarioCache[flashcardID]
    }

    func cacheScenarios(_ scenarios: [ScenarioQuestion], for flashcardID: UUID) {
        scenarioCache[flashcardID] = scenarios
    }

    func clearCache() {
        practiceCache.removeAll()
        scenarioCache.removeAll()
        log.info("Content cache cleared")
    }
}

// MARK: - Error Types

enum ContentGeneratorError: Error, LocalizedError {
    case invalidFlashcard
    case generationFailed
    case insufficientContent

    var errorDescription: String? {
        switch self {
        case .invalidFlashcard: return "Flashcard is not suitable for content generation"
        case .generationFailed: return "Failed to generate content"
        case .insufficientContent: return "Not enough content to generate from"
        }
    }
}

// MARK: - Flashcard Extensions for Content Generation

extension Flashcard {
    /// Check if this flashcard is suitable for practice problem generation
    var supportsPracticeProblems: Bool {
        // Math, science, calculation problems work best
        let indicators = ["calculate", "solve", "compute", "find", "determine", "how many", "what is"]
        return indicators.contains { question.lowercased().contains($0) }
    }

    /// Check if this flashcard is suitable for scenario generation
    var supportsScenarios: Bool {
        // Conceptual content works best for scenarios
        !question.isEmpty && answer.count > 20
    }

    /// Check if this flashcard is suitable for connection challenges
    var supportsConnections: Bool {
        // Most flashcards can be connected to others
        !question.isEmpty && !answer.isEmpty
    }
}
