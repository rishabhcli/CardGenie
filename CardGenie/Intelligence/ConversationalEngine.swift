//
//  ConversationalEngine.swift
//  CardGenie
//
//  AI-powered conversational learning engine for Socratic tutoring,
//  misconception detection, debate mode, and explain-to-me evaluation.
//  All processing happens on-device using Foundation Models.
//

import Foundation
import Combine
import OSLog
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class ConversationalEngine: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private let log = Logger(subsystem: "com.cardgenie.app", category: "ConversationalEngine")

    init() {}

    // MARK: - Socratic Tutoring

    /// Generate a Socratic question to guide the user's thinking
    /// - Parameters:
    ///   - flashcard: The flashcard being studied
    ///   - userAnswer: The user's current answer or response
    ///   - conversationHistory: Previous exchanges (for context)
    /// - Returns: A probing question with hints
    func generateSocraticQuestion(
        for flashcard: Flashcard,
        userAnswer: String,
        conversationHistory: [String] = []
    ) async throws -> SocraticQuestion {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        log.info("Generating Socratic question...")

        let session = LanguageModelSession {
            """
            You are a Socratic tutor. Ask probing questions that help students discover answers themselves.
            Use these question types:
            - Clarification: "What do you mean by...?"
            - Assumption: "What are we assuming here?"
            - Evidence: "What evidence supports this?"
            - Perspective: "How would someone else view this?"
            - Implication: "What are the consequences of this?"

            Never give direct answers. Guide thinking through questions.
            Provide hints that scaffold without revealing the answer.
            """
        }

        let historyContext = conversationHistory.isEmpty ? "" : """
            Previous conversation:
            \(conversationHistory.joined(separator: "\n"))

            """

        let prompt = """
            \(historyContext)
            Flashcard Question: \(flashcard.question)
            Correct Answer: \(flashcard.answer)
            Student's Answer: \(userAnswer)

            Generate a Socratic question that helps the student think deeper about this topic.
            Choose the most appropriate question category based on what the student needs.
            """

        let options = GenerationOptions(sampling: .greedy, temperature: 0.7)
        let response = try await session.respond(
            to: prompt,
            generating: SocraticQuestion.self,
            options: options
        )

        log.info("Socratic question generated: \(response.content.category.rawValue)")
        return response.content

        #else
        // Fallback: Simple follow-up questions
        log.info("Using fallback Socratic question")
        return SocraticQuestion(
            question: "Can you explain why you think that?",
            category: .clarification,
            hints: [
                "Think about the key concepts in the question",
                "Consider what you already know about this topic"
            ]
        )
        #endif
    }

    // MARK: - Misconception Detection

    /// Detect if the user's answer reveals a misconception
    /// - Parameters:
    ///   - flashcard: The flashcard being studied
    ///   - userAnswer: The user's answer
    /// - Returns: Analysis of any misconception found
    func detectMisconception(
        flashcard: Flashcard,
        userAnswer: String
    ) async throws -> MisconceptionAnalysis {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        log.info("Detecting misconceptions...")

        let session = LanguageModelSession {
            """
            You are an expert tutor who identifies misconceptions in student answers.
            Be gentle and constructive. Focus on the misunderstanding, not the mistake.
            Explain what the student seems to be thinking and why it's incorrect.
            Then guide them toward the correct understanding.
            """
        }

        let prompt = """
            Question: \(flashcard.question)
            Correct Answer: \(flashcard.answer)
            Student's Answer: \(userAnswer)

            Analyze if the student's answer reveals any misconception.
            If the answer is correct or close, set hasMisconception to false.
            If there is a misconception, explain it gently and constructively.
            """

        let options = GenerationOptions(sampling: .greedy, temperature: 0.4)
        let response = try await session.respond(
            to: prompt,
            generating: MisconceptionAnalysis.self,
            options: options
        )

        log.info("Misconception analysis complete: hasMisconception=\(response.content.hasMisconception)")
        return response.content

        #else
        // Fallback: Simple comparison
        log.info("Using fallback misconception detection")
        let isCorrect = userAnswer.lowercased().contains(flashcard.answer.lowercased())
        return MisconceptionAnalysis(
            hasMisconception: !isCorrect,
            misconception: isCorrect ? "" : "Your answer doesn't match the expected answer",
            correctConcept: flashcard.answer,
            explanation: isCorrect ? "Good job!" : "Review the concept and try again"
        )
        #endif
    }

    // MARK: - Debate Partner

    /// Generate a counterargument from the opposite perspective
    /// - Parameters:
    ///   - topic: The topic being debated (from flashcard)
    ///   - userPosition: The user's current position or argument
    /// - Returns: Counterargument with reasoning and challenge
    func generateDebateArgument(
        topic: String,
        userPosition: String
    ) async throws -> DebateArgument {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        log.info("Generating debate argument...")

        let session = LanguageModelSession {
            """
            You are a debate partner who argues the opposite viewpoint.
            Present strong counterarguments to test understanding.
            Be intellectually rigorous but respectful.
            Support your position with reasoning and challenge the user's assumptions.
            """
        }

        let prompt = """
            Topic: \(topic)
            User's Position: \(userPosition)

            Argue the opposite position with evidence and reasoning.
            Challenge the user's thinking with a thoughtful question.
            """

        let options = GenerationOptions(sampling: .greedy, temperature: 0.8)
        let response = try await session.respond(
            to: prompt,
            generating: DebateArgument.self,
            options: options
        )

        log.info("Debate argument generated")
        return response.content

        #else
        // Fallback: Simple counterpoint
        log.info("Using fallback debate argument")
        return DebateArgument(
            counterpoint: "However, there's another way to look at this...",
            reasoning: "Consider the alternative perspective on this topic.",
            challenge: "What evidence supports your position over this alternative view?"
        )
        #endif
    }

    // MARK: - Explain-to-Me Mode

    /// Evaluate the user's explanation of a concept
    /// - Parameters:
    ///   - flashcard: The flashcard being explained
    ///   - userExplanation: The user's explanation
    /// - Returns: Evaluation with feedback and clarifying questions
    func evaluateExplanation(
        flashcard: Flashcard,
        userExplanation: String
    ) async throws -> ExplanationEvaluation {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        log.info("Evaluating explanation...")

        let session = LanguageModelSession {
            """
            You are evaluating a student's explanation of a concept.
            Assess completeness (how much they covered) and clarity (how well they explained it).
            Identify missing areas and ask questions to help them elaborate.
            Be encouraging and constructive. Celebrate what they did well.
            """
        }

        let prompt = """
            Concept: \(flashcard.question)
            Expected Understanding: \(flashcard.answer)
            Student's Explanation: \(userExplanation)

            Evaluate their explanation:
            1. How complete is it? (1-5)
            2. How clear is it? (1-5)
            3. What key areas are missing?
            4. What questions can help them elaborate?
            5. What did they explain well?
            """

        let options = GenerationOptions(sampling: .greedy, temperature: 0.5)
        let response = try await session.respond(
            to: prompt,
            generating: ExplanationEvaluation.self,
            options: options
        )

        log.info("Explanation evaluated: completeness=\(response.content.completeness), clarity=\(response.content.clarity)")
        return response.content

        #else
        // Fallback: Simple evaluation
        log.info("Using fallback explanation evaluation")
        let wordCount = userExplanation.split(separator: " ").count
        let score = min(5, max(1, wordCount / 10))
        return ExplanationEvaluation(
            completeness: score,
            clarity: score,
            missingAreas: ["More detail needed"],
            clarifyingQuestions: [
                "Can you explain that in more detail?",
                "What else is important about this concept?"
            ],
            encouragement: "Good start! Keep explaining."
        )
        #endif
    }

    // MARK: - Session Management

    /// Create a new conversational session
    func createSession(flashcardID: UUID, mode: ConversationalMode) -> ConversationalSession {
        ConversationalSession(flashcardID: flashcardID, mode: mode)
    }

    /// End a conversational session
    func endSession(_ session: ConversationalSession) {
        session.endTime = Date()
        log.info("Conversational session ended: \(session.mode.rawValue), turns: \(session.turnCount)")
    }
}

// MARK: - Error Types

enum ConversationalEngineError: Error, LocalizedError {
    case sessionNotFound
    case invalidInput
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .sessionNotFound: return "Conversational session not found"
        case .invalidInput: return "Invalid input provided"
        case .generationFailed: return "Failed to generate response"
        }
    }
}
