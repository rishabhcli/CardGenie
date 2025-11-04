//
//  GameEngine.swift
//  CardGenie
//
//  AI-powered game engine for matching, true/false, multiple choice,
//  teach-back, and Feynman technique modes. All processing on-device.
//

import Foundation
import Combine
import AVFoundation
import Speech
import OSLog
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class GameEngine: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private let log = Logger(subsystem: "com.cardgenie.app", category: "GameEngine")

    init() {}

    // MARK: - Matching Game

    /// Create a matching game from a set of flashcards
    /// - Parameters:
    ///   - flashcards: Source flashcards (max 10 for playability)
    ///   - timeLimit: Time limit in seconds (default 120)
    /// - Returns: A new matching game
    func createMatchingGame(
        from flashcards: [Flashcard],
        timeLimit: Int = 120
    ) -> MatchingGame {
        let limitedCards = Array(flashcards.prefix(10))
        let pairs = limitedCards.map { card in
            MatchPair(term: card.question, definition: card.answer)
        }

        return MatchingGame(
            flashcardSetID: flashcards.first?.set?.id ?? UUID(),
            pairs: pairs.shuffled(),
            timeLimit: timeLimit
        )
    }

    /// Start a matching game
    func startMatchingGame(_ game: MatchingGame) {
        game.startTime = Date()
        log.info("Matching game started with \(game.pairs.count) pairs")
    }

    /// End a matching game
    func endMatchingGame(_ game: MatchingGame) {
        game.endTime = Date()
        log.info("Matching game ended: score=\(game.score), accuracy=\(game.accuracy)")
    }

    /// Check if a match is correct
    func checkMatch(_ game: MatchingGame, term: String, definition: String) -> Bool {
        guard let pair = game.pairs.first(where: { $0.term == term }) else {
            return false
        }

        pair.attempts += 1

        if pair.definition == definition {
            pair.isMatched = true
            pair.matchedAt = Date()
            game.score += 100
            log.info("Correct match: \(term)")
            return true
        } else {
            game.mistakes += 1
            game.score = max(0, game.score - 10)
            log.info("Incorrect match attempt: \(term)")
            return false
        }
    }

    // MARK: - True/False Generation

    /// Generate true/false statements from flashcards
    /// - Parameter flashcards: Source flashcards (uses up to 5)
    /// - Returns: Array of true/false statements
    func generateTrueFalseStatements(
        from flashcards: [Flashcard]
    ) async throws -> [TrueFalseStatement] {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        log.info("Generating true/false statements...")

        let session = LanguageModelSession {
            """
            Create true/false statements based on flashcard content.
            Make false statements plausible but clearly wrong to someone who knows the material.
            Provide clear justifications explaining why each statement is true or false.
            Mix approximately 50% true and 50% false statements.
            """
        }

        let limitedCards = Array(flashcards.prefix(5))
        let cardInfo = limitedCards.map { "Q: \($0.question) A: \($0.answer)" }.joined(separator: "\n")

        let prompt = """
            Flashcards:
            \(cardInfo)

            Generate 5-10 true/false statements with justifications.
            Make statements specific and clear.
            """

        let options = GenerationOptions(sampling: .greedy, temperature: 0.6)
        let response = try await session.respond(
            to: prompt,
            generating: TrueFalseBatch.self,
            options: options
        )

        log.info("Generated \(response.content.statements.count) true/false statements")
        return response.content.statements

        #else
        // Fallback: Simple true statements from flashcards
        log.info("Using fallback true/false generation")
        return flashcards.prefix(5).map { card in
            TrueFalseStatement(
                statement: "\(card.question) → \(card.answer)",
                isTrue: true,
                justification: "This is correct according to the flashcard."
            )
        }
        #endif
    }

    // MARK: - Multiple Choice Generation

    /// Generate multiple choice questions from flashcards
    /// - Parameter flashcards: Source flashcards (uses up to 3)
    /// - Returns: Array of multiple choice questions
    func generateMultipleChoice(
        from flashcards: [Flashcard]
    ) async throws -> [MultipleChoiceQuestion] {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        log.info("Generating multiple choice questions...")

        let session = LanguageModelSession {
            """
            Create multiple choice questions with plausible distractors.
            Each distractor should represent a common mistake or misconception.
            Explain why each distractor is wrong - this teaches students to avoid common errors.
            Make the correct answer clearly best when you understand the concept.
            """
        }

        let limitedCards = Array(flashcards.prefix(3))
        let cardInfo = limitedCards.map { "Q: \($0.question) A: \($0.answer)" }.joined(separator: "\n")

        let prompt = """
            Flashcards:
            \(cardInfo)

            Generate 3-5 multiple choice questions:
            - Each with 1 correct answer and 3 plausible distractors
            - Explain why each distractor is wrong
            - Explain why the correct answer is right
            """

        let options = GenerationOptions(sampling: .greedy, temperature: 0.7)
        let response = try await session.respond(
            to: prompt,
            generating: MCQBatch.self,
            options: options
        )

        log.info("Generated \(response.content.questions.count) multiple choice questions")
        return response.content.questions

        #else
        // Fallback: Simple questions from flashcards
        log.info("Using fallback multiple choice generation")
        return flashcards.prefix(3).map { card in
            MultipleChoiceQuestion(
                question: card.question,
                correctAnswer: card.answer,
                distractors: ["Option A", "Option B", "Option C"],
                distractorAnalysis: [
                    "This is incorrect because...",
                    "This is not the right answer because...",
                    "This doesn't match because..."
                ],
                correctExplanation: "This is correct according to the flashcard."
            )
        }
        #endif
    }

    // MARK: - Teach-Back Evaluation

    /// Evaluate a teach-back recording
    /// - Parameters:
    ///   - flashcard: The flashcard being taught
    ///   - transcription: Transcribed speech from the recording
    /// - Returns: Feedback on the explanation
    func evaluateTeachBack(
        flashcard: Flashcard,
        transcription: String
    ) async throws -> TeachBackFeedback {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        log.info("Evaluating teach-back explanation...")

        let session = LanguageModelSession {
            """
            You are evaluating a student's verbal explanation of a concept.
            Assess accuracy (correctness) and clarity (how well explained).
            Be encouraging and constructive. Highlight what they did well.
            Identify areas for improvement without being harsh.
            """
        }

        let prompt = """
            Concept: \(flashcard.question)
            Expected Answer: \(flashcard.answer)
            Student's Verbal Explanation: \(transcription)

            Evaluate their explanation:
            - Accuracy score (1-5)
            - Clarity score (1-5)
            - What did they explain correctly?
            - What important details did they miss or get wrong?
            - Encouraging feedback to help them improve
            """

        let options = GenerationOptions(sampling: .greedy, temperature: 0.5)
        let response = try await session.respond(
            to: prompt,
            generating: TeachBackFeedback.self,
            options: options
        )

        log.info("Teach-back evaluated: accuracy=\(response.content.accuracy), clarity=\(response.content.clarity)")
        return response.content

        #else
        // Fallback: Simple evaluation
        log.info("Using fallback teach-back evaluation")
        let wordCount = transcription.split(separator: " ").count
        let score = min(5, max(1, wordCount / 20))
        return TeachBackFeedback(
            accuracy: score,
            clarity: score,
            strengthAreas: ["You covered the main concept"],
            improvementAreas: ["Add more specific details"],
            feedback: "Good explanation! Keep practicing to add more depth."
        )
        #endif
    }

    // MARK: - Feynman Technique Evaluation

    /// Evaluate if an explanation is simple enough (Feynman technique)
    /// - Parameters:
    ///   - flashcard: The flashcard being explained
    ///   - explanation: User's simplified explanation
    /// - Returns: Evaluation with suggestions
    func evaluateFeynmanExplanation(
        flashcard: Flashcard,
        explanation: String
    ) async throws -> FeynmanEvaluation {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        log.info("Evaluating Feynman explanation...")

        let session = LanguageModelSession {
            """
            You are evaluating if an explanation is simple enough for a 10-year-old to understand.
            Identify technical jargon, complex terms, and abstract concepts.
            Suggest analogies and everyday examples that would help.
            Provide a simplified version using only everyday language.
            """
        }

        let prompt = """
            Concept: \(flashcard.question)
            Student's Explanation: \(explanation)

            Evaluate:
            - Is this simple enough for a 10-year-old?
            - What jargon or complex terms are used?
            - What analogies would help?
            - Provide a simplified version
            """

        let options = GenerationOptions(sampling: .greedy, temperature: 0.6)
        let response = try await session.respond(
            to: prompt,
            generating: FeynmanEvaluation.self,
            options: options
        )

        log.info("Feynman evaluation complete: isSimpleEnough=\(response.content.isSimpleEnough)")
        return response.content

        #else
        // Fallback: Simple check
        log.info("Using fallback Feynman evaluation")
        let complexWords = explanation.split(separator: " ").filter { $0.count > 12 }
        return FeynmanEvaluation(
            isSimpleEnough: complexWords.isEmpty,
            jargonUsed: complexWords.map(String.init),
            suggestedAnalogies: [
                "Think of it like...",
                "It's similar to..."
            ],
            simplifiedVersion: "Try explaining this using simpler words and everyday examples."
        )
        #endif
    }

    // MARK: - Speech Recognition for Teach-Back

    /// Transcribe audio recording for teach-back mode
    /// - Parameter audioURL: URL of the recorded audio
    /// - Returns: Transcribed text
    func transcribeAudio(_ audioURL: URL) async throws -> String {
        let recognizer = SFSpeechRecognizer()
        guard recognizer?.isAvailable == true else {
            throw GameEngineError.speechRecognitionUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            recognizer?.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}

// MARK: - Error Types

enum GameEngineError: Error, LocalizedError {
    case invalidGame
    case speechRecognitionUnavailable
    case audioRecordingFailed
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .invalidGame: return "Invalid game state"
        case .speechRecognitionUnavailable: return "Speech recognition is not available"
        case .audioRecordingFailed: return "Failed to record audio"
        case .generationFailed: return "Failed to generate game content"
        }
    }
}
