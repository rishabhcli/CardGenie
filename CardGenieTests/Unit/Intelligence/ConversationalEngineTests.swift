//
//  ConversationalEngineTests.swift
//  CardGenie
//
//  Unit tests for ConversationalEngine - Socratic tutoring and learning modes.
//

import XCTest
@testable import CardGenie

@MainActor
final class ConversationalEngineTests: XCTestCase {
    var engine: ConversationalEngine!

    override func setUp() async throws {
        engine = ConversationalEngine()
    }

    override func tearDown() async throws {
        engine = nil
    }

    // MARK: - Initialization Tests

    func testInitialization() async throws {
        // Given/When: A fresh ConversationalEngine instance
        // Then: Should initialize successfully
        XCTAssertNotNil(engine, "ConversationalEngine should initialize")
    }

    // MARK: - Socratic Question Tests (Fallback)

    func testGenerateSocraticQuestionFallback() async throws {
        // Given: A flashcard and user answer
        let flashcard = createTestFlashcard(
            question: "What is the Pythagorean theorem?",
            answer: "a² + b² = c²"
        )
        let userAnswer = "Something about triangles"

        // When: Generating a Socratic question
        do {
            let question = try await engine.generateSocraticQuestion(
                for: flashcard,
                userAnswer: userAnswer
            )

            // Then: Should return a guiding question
            XCTAssertFalse(question.question.isEmpty, "Should have a question")
            XCTAssertNotNil(question.category, "Should have a category")
            XCTAssertFalse(question.hints.isEmpty, "Should have hints")
        } catch {
            // Expected in environments without AI
            XCTAssertTrue(error is FMError, "Should throw FMError")
        }
    }

    func testGenerateSocraticQuestionWithHistory() async throws {
        // Given: A flashcard, answer, and conversation history
        let flashcard = createTestFlashcard(
            question: "What causes the seasons?",
            answer: "Earth's axial tilt as it orbits the sun"
        )
        let userAnswer = "Because of the sun"
        let history = [
            "Teacher: What do you know about Earth's orbit?",
            "Student: The Earth goes around the sun."
        ]

        // When: Generating with history
        do {
            let question = try await engine.generateSocraticQuestion(
                for: flashcard,
                userAnswer: userAnswer,
                conversationHistory: history
            )

            // Then: Should consider history in response
            XCTAssertNotNil(question)
        } catch {
            XCTAssertTrue(error is FMError)
        }
    }

    // MARK: - Misconception Detection Tests (Fallback)

    func testDetectMisconceptionCorrectAnswer() async throws {
        // Given: A flashcard and correct answer
        let flashcard = createTestFlashcard(
            question: "What is H2O?",
            answer: "Water"
        )
        let userAnswer = "Water is H2O"

        // When: Detecting misconceptions
        do {
            let analysis = try await engine.detectMisconception(
                flashcard: flashcard,
                userAnswer: userAnswer
            )

            // Then: Should not detect misconception for correct answer
            XCTAssertFalse(analysis.hasMisconception, "Correct answer should have no misconception")
        } catch {
            XCTAssertTrue(error is FMError)
        }
    }

    func testDetectMisconceptionIncorrectAnswer() async throws {
        // Given: A flashcard and incorrect answer
        let flashcard = createTestFlashcard(
            question: "What is the chemical symbol for gold?",
            answer: "Au"
        )
        let userAnswer = "Go"

        // When: Detecting misconceptions
        do {
            let analysis = try await engine.detectMisconception(
                flashcard: flashcard,
                userAnswer: userAnswer
            )

            // Then: Should detect misconception
            XCTAssertTrue(analysis.hasMisconception, "Incorrect answer should have misconception")
            XCTAssertFalse(analysis.explanation.isEmpty, "Should have explanation")
        } catch {
            XCTAssertTrue(error is FMError)
        }
    }

    // MARK: - Debate Argument Tests (Fallback)

    func testGenerateDebateArgument() async throws {
        // Given: A topic and user position
        let topic = "Is homework beneficial for students?"
        let userPosition = "Homework helps students practice and retain knowledge."

        // When: Generating counterargument
        do {
            let argument = try await engine.generateDebateArgument(
                topic: topic,
                userPosition: userPosition
            )

            // Then: Should provide counterpoint
            XCTAssertFalse(argument.counterpoint.isEmpty, "Should have counterpoint")
            XCTAssertFalse(argument.reasoning.isEmpty, "Should have reasoning")
            XCTAssertFalse(argument.challenge.isEmpty, "Should have challenge question")
        } catch {
            XCTAssertTrue(error is FMError)
        }
    }

    // MARK: - Explanation Evaluation Tests (Fallback)

    func testEvaluateExplanation() async throws {
        // Given: A flashcard and user explanation
        let flashcard = createTestFlashcard(
            question: "Explain photosynthesis",
            answer: "Process by which plants convert sunlight, water, and CO2 into glucose and oxygen"
        )
        let explanation = "Plants use sunlight to make food. They take in carbon dioxide and water, then produce sugar and release oxygen."

        // When: Evaluating explanation
        do {
            let evaluation = try await engine.evaluateExplanation(
                flashcard: flashcard,
                userExplanation: explanation
            )

            // Then: Should provide comprehensive evaluation
            XCTAssertGreaterThanOrEqual(evaluation.completeness, 1)
            XCTAssertLessThanOrEqual(evaluation.completeness, 5)
            XCTAssertGreaterThanOrEqual(evaluation.clarity, 1)
            XCTAssertLessThanOrEqual(evaluation.clarity, 5)
            XCTAssertFalse(evaluation.encouragement.isEmpty, "Should have encouragement")
        } catch {
            XCTAssertTrue(error is FMError)
        }
    }

    func testEvaluateExplanationShortAnswer() async throws {
        // Given: A short explanation
        let flashcard = createTestFlashcard(question: "What is gravity?", answer: "Force of attraction")
        let shortExplanation = "Force."

        // When: Evaluating short explanation
        do {
            let evaluation = try await engine.evaluateExplanation(
                flashcard: flashcard,
                userExplanation: shortExplanation
            )

            // Then: Fallback should give lower scores for short answers
            XCTAssertLessThanOrEqual(evaluation.completeness, 3, "Short answer should have low completeness")
        } catch {
            XCTAssertTrue(error is FMError)
        }
    }

    // MARK: - Session Management Tests

    func testCreateSession() async throws {
        // Given: A flashcard ID and mode
        let flashcardID = UUID()
        let mode = ConversationalMode.socratic

        // When: Creating a session
        let session = engine.createSession(flashcardID: flashcardID, mode: mode)

        // Then: Should create session with correct properties
        XCTAssertEqual(session.flashcardID, flashcardID)
        XCTAssertEqual(session.mode, mode)
        XCTAssertNotNil(session.startTime)
        XCTAssertNil(session.endTime)
        XCTAssertEqual(session.turnCount, 0)
    }

    func testEndSession() async throws {
        // Given: An active session
        let session = engine.createSession(flashcardID: UUID(), mode: .debate)

        // When: Ending the session
        engine.endSession(session)

        // Then: Should set end time
        XCTAssertNotNil(session.endTime, "Should have end time")
    }

    func testSessionModes() async throws {
        // Given: All available modes
        let modes: [ConversationalMode] = [.socratic, .debate, .explainToMe]

        // When/Then: Creating sessions for each mode
        for mode in modes {
            let session = engine.createSession(flashcardID: UUID(), mode: mode)
            XCTAssertEqual(session.mode, mode)
        }
    }

    // MARK: - Error Type Tests

    func testConversationalEngineErrorDescriptions() async throws {
        // Given: Different error types
        let sessionNotFound = ConversationalEngineError.sessionNotFound
        let invalidInput = ConversationalEngineError.invalidInput
        let generationFailed = ConversationalEngineError.generationFailed

        // Then: Should have appropriate descriptions
        XCTAssertNotNil(sessionNotFound.errorDescription)
        XCTAssertNotNil(invalidInput.errorDescription)
        XCTAssertNotNil(generationFailed.errorDescription)
    }

    // MARK: - Helper Methods

    private func createTestFlashcard(question: String, answer: String) -> Flashcard {
        Flashcard(
            type: .qa,
            question: question,
            answer: answer,
            linkedEntryID: UUID()
        )
    }
}

// MARK: - SocraticQuestion Tests

final class SocraticQuestionTests: XCTestCase {

    func testSocraticQuestionCreation() {
        // Given/When: Creating a Socratic question
        let question = SocraticQuestion(
            question: "What evidence supports that conclusion?",
            category: .evidence,
            hints: ["Consider the data", "Look at the examples"]
        )

        // Then: Should have correct values
        XCTAssertEqual(question.question, "What evidence supports that conclusion?")
        XCTAssertEqual(question.category, .evidence)
        XCTAssertEqual(question.hints.count, 2)
    }

    func testSocraticQuestionCategories() {
        // Given: All question categories
        let categories: [SocraticQuestionCategory] = [
            .clarification,
            .assumption,
            .evidence,
            .perspective,
            .implication
        ]

        // Then: Should have 5 categories
        XCTAssertEqual(categories.count, 5)
    }
}

// MARK: - MisconceptionAnalysis Tests

final class MisconceptionAnalysisTests: XCTestCase {

    func testMisconceptionAnalysisWithMisconception() {
        // Given/When: Creating analysis with misconception
        let analysis = MisconceptionAnalysis(
            hasMisconception: true,
            misconception: "Student thinks heavier objects fall faster",
            correctConcept: "All objects fall at the same rate in a vacuum",
            explanation: "This is a common misconception dating back to Aristotle..."
        )

        // Then: Should have correct values
        XCTAssertTrue(analysis.hasMisconception)
        XCTAssertFalse(analysis.misconception.isEmpty)
        XCTAssertFalse(analysis.correctConcept.isEmpty)
        XCTAssertFalse(analysis.explanation.isEmpty)
    }

    func testMisconceptionAnalysisWithoutMisconception() {
        // Given/When: Creating analysis without misconception
        let analysis = MisconceptionAnalysis(
            hasMisconception: false,
            misconception: "",
            correctConcept: "Objects fall at the same rate",
            explanation: "Correct! Good understanding."
        )

        // Then: Should indicate no misconception
        XCTAssertFalse(analysis.hasMisconception)
        XCTAssertTrue(analysis.misconception.isEmpty)
    }
}

// MARK: - DebateArgument Tests

final class DebateArgumentTests: XCTestCase {

    func testDebateArgumentCreation() {
        // Given/When: Creating a debate argument
        let argument = DebateArgument(
            counterpoint: "While homework can reinforce learning, it may also cause stress...",
            reasoning: "Research shows that excessive homework can lead to burnout...",
            challenge: "How do you account for students who learn better through hands-on practice?"
        )

        // Then: Should have all components
        XCTAssertFalse(argument.counterpoint.isEmpty)
        XCTAssertFalse(argument.reasoning.isEmpty)
        XCTAssertFalse(argument.challenge.isEmpty)
    }
}

// MARK: - ExplanationEvaluation Tests

final class ExplanationEvaluationTests: XCTestCase {

    func testExplanationEvaluationCreation() {
        // Given/When: Creating an evaluation
        let evaluation = ExplanationEvaluation(
            completeness: 4,
            clarity: 5,
            missingAreas: ["Could mention specific examples"],
            clarifyingQuestions: ["What are some real-world applications?"],
            encouragement: "Great job explaining the main concepts!"
        )

        // Then: Should have correct values
        XCTAssertEqual(evaluation.completeness, 4)
        XCTAssertEqual(evaluation.clarity, 5)
        XCTAssertEqual(evaluation.missingAreas.count, 1)
        XCTAssertEqual(evaluation.clarifyingQuestions.count, 1)
        XCTAssertFalse(evaluation.encouragement.isEmpty)
    }

    func testExplanationEvaluationScoreBounds() {
        // Given: Evaluations with boundary scores
        let lowEval = ExplanationEvaluation(
            completeness: 1,
            clarity: 1,
            missingAreas: [],
            clarifyingQuestions: [],
            encouragement: ""
        )
        let highEval = ExplanationEvaluation(
            completeness: 5,
            clarity: 5,
            missingAreas: [],
            clarifyingQuestions: [],
            encouragement: ""
        )

        // Then: Should have correct bounds
        XCTAssertEqual(lowEval.completeness, 1)
        XCTAssertEqual(highEval.completeness, 5)
    }
}

// MARK: - ConversationalSession Tests

@MainActor
final class ConversationalSessionTests: XCTestCase {

    func testConversationalSessionInitialization() async throws {
        // Given/When: Creating a session
        let flashcardID = UUID()
        let session = ConversationalSession(flashcardID: flashcardID, mode: .socratic)

        // Then: Should have correct initial state
        XCTAssertNotNil(session.id)
        XCTAssertEqual(session.flashcardID, flashcardID)
        XCTAssertEqual(session.mode, .socratic)
        XCTAssertNotNil(session.startTime)
        XCTAssertNil(session.endTime)
        XCTAssertEqual(session.turnCount, 0)
    }

    func testConversationalModeDisplayNames() async throws {
        // Given: All conversational modes
        // Then: Should have display names
        XCTAssertEqual(ConversationalMode.socratic.rawValue, "socratic")
        XCTAssertEqual(ConversationalMode.debate.rawValue, "debate")
        XCTAssertEqual(ConversationalMode.explainToMe.rawValue, "explainToMe")
    }
}

// MARK: - SocraticQuestionCategory Tests

final class SocraticQuestionCategoryTests: XCTestCase {

    func testClarificationCategory() {
        let category = SocraticQuestionCategory.clarification
        XCTAssertEqual(category.rawValue, "clarification")
    }

    func testAssumptionCategory() {
        let category = SocraticQuestionCategory.assumption
        XCTAssertEqual(category.rawValue, "assumption")
    }

    func testEvidenceCategory() {
        let category = SocraticQuestionCategory.evidence
        XCTAssertEqual(category.rawValue, "evidence")
    }

    func testPerspectiveCategory() {
        let category = SocraticQuestionCategory.perspective
        XCTAssertEqual(category.rawValue, "perspective")
    }

    func testImplicationCategory() {
        let category = SocraticQuestionCategory.implication
        XCTAssertEqual(category.rawValue, "implication")
    }
}
