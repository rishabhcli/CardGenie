//
//  GameEngineTests.swift
//  CardGenie
//
//  Unit tests for GameEngine - AI-powered game modes for flashcard study.
//

import XCTest
@testable import CardGenie

@MainActor
final class GameEngineTests: XCTestCase {
    var gameEngine: GameEngine!

    override func setUp() async throws {
        gameEngine = GameEngine()
    }

    override func tearDown() async throws {
        gameEngine = nil
    }

    // MARK: - Initialization Tests

    func testInitialization() async throws {
        // Given/When: A fresh GameEngine instance
        // Then: Should initialize successfully
        XCTAssertNotNil(gameEngine, "GameEngine should initialize")
    }

    // MARK: - Matching Game Creation Tests

    func testCreateMatchingGameWithFlashcards() async throws {
        // Given: A set of flashcards
        let flashcards = createTestFlashcards(count: 5)

        // When: Creating a matching game
        let game = gameEngine.createMatchingGame(from: flashcards)

        // Then: Should create game with correct pairs
        XCTAssertEqual(game.pairs.count, 5, "Should have 5 pairs")
        XCTAssertEqual(game.timeLimit, 120, "Should have default time limit")
        XCTAssertEqual(game.score, 0, "Should start with 0 score")
        XCTAssertEqual(game.mistakes, 0, "Should start with 0 mistakes")
        XCTAssertNil(game.startTime, "Should not have start time yet")
        XCTAssertNil(game.endTime, "Should not have end time yet")
    }

    func testCreateMatchingGameLimitsTo10Cards() async throws {
        // Given: More than 10 flashcards
        let flashcards = createTestFlashcards(count: 15)

        // When: Creating a matching game
        let game = gameEngine.createMatchingGame(from: flashcards)

        // Then: Should limit to 10 pairs for playability
        XCTAssertEqual(game.pairs.count, 10, "Should limit to 10 pairs")
    }

    func testCreateMatchingGameWithCustomTimeLimit() async throws {
        // Given: Flashcards and custom time limit
        let flashcards = createTestFlashcards(count: 5)

        // When: Creating a matching game with custom time
        let game = gameEngine.createMatchingGame(from: flashcards, timeLimit: 60)

        // Then: Should have custom time limit
        XCTAssertEqual(game.timeLimit, 60, "Should have custom time limit")
    }

    func testCreateMatchingGameWithEmptyFlashcards() async throws {
        // Given: No flashcards
        let flashcards: [Flashcard] = []

        // When: Creating a matching game
        let game = gameEngine.createMatchingGame(from: flashcards)

        // Then: Should create empty game
        XCTAssertTrue(game.pairs.isEmpty, "Should have no pairs")
    }

    // MARK: - Matching Game Lifecycle Tests

    func testStartMatchingGame() async throws {
        // Given: A matching game
        let flashcards = createTestFlashcards(count: 5)
        let game = gameEngine.createMatchingGame(from: flashcards)

        // When: Starting the game
        gameEngine.startMatchingGame(game)

        // Then: Should set start time
        XCTAssertNotNil(game.startTime, "Should have start time")
    }

    func testEndMatchingGame() async throws {
        // Given: A started matching game
        let flashcards = createTestFlashcards(count: 5)
        let game = gameEngine.createMatchingGame(from: flashcards)
        gameEngine.startMatchingGame(game)

        // When: Ending the game
        gameEngine.endMatchingGame(game)

        // Then: Should set end time
        XCTAssertNotNil(game.endTime, "Should have end time")
    }

    // MARK: - Match Checking Tests

    func testCheckMatchCorrect() async throws {
        // Given: A matching game with known pairs
        let flashcards = createTestFlashcards(count: 3)
        let game = gameEngine.createMatchingGame(from: flashcards)
        let pair = game.pairs[0]

        // When: Checking a correct match
        let result = gameEngine.checkMatch(game, term: pair.term, definition: pair.definition)

        // Then: Should return true and update score
        XCTAssertTrue(result, "Correct match should return true")
        XCTAssertEqual(game.score, 100, "Should add 100 points")
        XCTAssertTrue(pair.isMatched, "Pair should be marked as matched")
        XCTAssertNotNil(pair.matchedAt, "Should have match timestamp")
    }

    func testCheckMatchIncorrect() async throws {
        // Given: A matching game with known pairs
        let flashcards = createTestFlashcards(count: 3)
        let game = gameEngine.createMatchingGame(from: flashcards)
        let pair = game.pairs[0]

        // When: Checking an incorrect match
        let result = gameEngine.checkMatch(game, term: pair.term, definition: "Wrong answer")

        // Then: Should return false and track mistake
        XCTAssertFalse(result, "Incorrect match should return false")
        XCTAssertEqual(game.mistakes, 1, "Should track mistake")
        XCTAssertFalse(pair.isMatched, "Pair should not be matched")
    }

    func testCheckMatchScorePenalty() async throws {
        // Given: A game with some score
        let flashcards = createTestFlashcards(count: 3)
        let game = gameEngine.createMatchingGame(from: flashcards)
        game.score = 100

        let pair = game.pairs[0]

        // When: Making an incorrect match
        _ = gameEngine.checkMatch(game, term: pair.term, definition: "Wrong")

        // Then: Should deduct points but not go below 0
        XCTAssertEqual(game.score, 90, "Should deduct 10 points")
    }

    func testCheckMatchScoreDoesNotGoBelowZero() async throws {
        // Given: A game with 0 score
        let flashcards = createTestFlashcards(count: 3)
        let game = gameEngine.createMatchingGame(from: flashcards)
        game.score = 5

        let pair = game.pairs[0]

        // When: Making incorrect match
        _ = gameEngine.checkMatch(game, term: pair.term, definition: "Wrong")

        // Then: Should not go below 0
        XCTAssertEqual(game.score, 0, "Score should not go below 0")
    }

    func testCheckMatchWithInvalidTerm() async throws {
        // Given: A matching game
        let flashcards = createTestFlashcards(count: 3)
        let game = gameEngine.createMatchingGame(from: flashcards)

        // When: Checking with invalid term
        let result = gameEngine.checkMatch(game, term: "Nonexistent Term", definition: "Any")

        // Then: Should return false
        XCTAssertFalse(result, "Invalid term should return false")
    }

    func testCheckMatchTracksAttempts() async throws {
        // Given: A matching game
        let flashcards = createTestFlashcards(count: 3)
        let game = gameEngine.createMatchingGame(from: flashcards)
        let pair = game.pairs[0]

        // When: Making multiple attempts
        _ = gameEngine.checkMatch(game, term: pair.term, definition: "Wrong1")
        _ = gameEngine.checkMatch(game, term: pair.term, definition: "Wrong2")
        _ = gameEngine.checkMatch(game, term: pair.term, definition: pair.definition)

        // Then: Should track all attempts
        XCTAssertEqual(pair.attempts, 3, "Should track 3 attempts")
        XCTAssertTrue(pair.isMatched, "Should be matched after correct answer")
    }

    // MARK: - True/False Game Tests (Fallback)

    func testGenerateTrueFalseStatementsFallback() async throws {
        // Given: Flashcards (AI unavailable in test environment)
        let flashcards = createTestFlashcards(count: 3)

        // When: Generating true/false statements
        do {
            let statements = try await gameEngine.generateTrueFalseStatements(from: flashcards)

            // Then: Should return fallback statements
            XCTAssertFalse(statements.isEmpty, "Should have statements")
            // Fallback always returns true statements
            for statement in statements {
                XCTAssertTrue(statement.isTrue, "Fallback returns true statements")
            }
        } catch {
            // Expected in environments without AI - verify error type
            XCTAssertTrue(error is FMError, "Should throw FMError")
        }
    }

    // MARK: - Multiple Choice Game Tests (Fallback)

    func testGenerateMultipleChoiceFallback() async throws {
        // Given: Flashcards
        let flashcards = createTestFlashcards(count: 3)

        // When: Generating multiple choice questions
        do {
            let questions = try await gameEngine.generateMultipleChoice(from: flashcards)

            // Then: Should return fallback questions
            XCTAssertFalse(questions.isEmpty, "Should have questions")
            for question in questions {
                XCTAssertEqual(question.distractors.count, 3, "Should have 3 distractors")
            }
        } catch {
            // Expected in environments without AI
            XCTAssertTrue(error is FMError, "Should throw FMError")
        }
    }

    // MARK: - Teach-Back Evaluation Tests (Fallback)

    func testEvaluateTeachBackFallback() async throws {
        // Given: A flashcard and transcription
        let flashcard = createTestFlashcard(question: "What is photosynthesis?", answer: "Process by which plants convert sunlight to energy")
        let transcription = "Photosynthesis is the process where plants use sunlight to make food and energy."

        // When: Evaluating teach-back
        do {
            let feedback = try await gameEngine.evaluateTeachBack(flashcard: flashcard, transcription: transcription)

            // Then: Should return feedback with scores 1-5
            XCTAssertGreaterThanOrEqual(feedback.accuracy, 1)
            XCTAssertLessThanOrEqual(feedback.accuracy, 5)
            XCTAssertGreaterThanOrEqual(feedback.clarity, 1)
            XCTAssertLessThanOrEqual(feedback.clarity, 5)
            XCTAssertFalse(feedback.feedback.isEmpty, "Should have feedback text")
        } catch {
            // Expected in environments without AI
            XCTAssertTrue(error is FMError, "Should throw FMError")
        }
    }

    func testEvaluateTeachBackScoreBasedOnLength() async throws {
        // Given: Flashcard and short transcription
        let flashcard = createTestFlashcard(question: "Test", answer: "Answer")
        let shortTranscription = "Brief answer"

        // When: Evaluating with short answer
        do {
            let feedback = try await gameEngine.evaluateTeachBack(flashcard: flashcard, transcription: shortTranscription)

            // Then: Fallback calculates score based on word count
            XCTAssertGreaterThanOrEqual(feedback.accuracy, 1)
        } catch {
            XCTAssertTrue(error is FMError)
        }
    }

    // MARK: - Feynman Technique Tests (Fallback)

    func testEvaluateFeynmanExplanationFallback() async throws {
        // Given: A flashcard and simple explanation
        let flashcard = createTestFlashcard(question: "What is gravity?", answer: "Force that attracts objects toward each other")
        let explanation = "Gravity is like a invisible force that pulls things down to the ground."

        // When: Evaluating Feynman explanation
        do {
            let evaluation = try await gameEngine.evaluateFeynmanExplanation(flashcard: flashcard, explanation: explanation)

            // Then: Should return evaluation
            XCTAssertNotNil(evaluation.simplifiedVersion, "Should have simplified version")
            XCTAssertNotNil(evaluation.suggestedAnalogies, "Should have suggested analogies")
        } catch {
            // Expected in environments without AI
            XCTAssertTrue(error is FMError, "Should throw FMError")
        }
    }

    func testEvaluateFeynmanExplanationDetectsJargon() async throws {
        // Given: A flashcard and explanation with jargon
        let flashcard = createTestFlashcard(question: "Explain DNA", answer: "Genetic material")
        let jargonExplanation = "DNA involves deoxyribonucleic acid polymerization and transcription mechanisms."

        // When: Evaluating
        do {
            let evaluation = try await gameEngine.evaluateFeynmanExplanation(flashcard: flashcard, explanation: jargonExplanation)

            // Then: Fallback detects long words as jargon
            XCTAssertFalse(evaluation.jargonUsed.isEmpty, "Should detect jargon words")
        } catch {
            XCTAssertTrue(error is FMError)
        }
    }

    // MARK: - Error Type Tests

    func testGameEngineErrorDescriptions() async throws {
        // Given: Different error types
        let invalidGameError = GameEngineError.invalidGame
        let speechError = GameEngineError.speechRecognitionUnavailable
        let audioError = GameEngineError.audioRecordingFailed
        let generationError = GameEngineError.generationFailed

        // Then: Should have appropriate descriptions
        XCTAssertNotNil(invalidGameError.errorDescription)
        XCTAssertNotNil(speechError.errorDescription)
        XCTAssertNotNil(audioError.errorDescription)
        XCTAssertNotNil(generationError.errorDescription)
    }

    // MARK: - Helper Methods

    private func createTestFlashcards(count: Int) -> [Flashcard] {
        (0..<count).map { i in
            createTestFlashcard(
                question: "Question \(i)",
                answer: "Answer \(i)"
            )
        }
    }

    private func createTestFlashcard(question: String, answer: String) -> Flashcard {
        Flashcard(
            type: .qa,
            question: question,
            answer: answer,
            linkedEntryID: UUID()
        )
    }
}

// MARK: - MatchingGame Model Tests

@MainActor
final class MatchingGameTests: XCTestCase {

    func testMatchingGameInitialization() async throws {
        // Given/When: Creating a matching game
        let game = MatchingGame(flashcardSetID: UUID(), timeLimit: 120)

        // Then: Should have correct initial state
        XCTAssertNotNil(game.id)
        XCTAssertEqual(game.timeLimit, 120)
        XCTAssertTrue(game.pairs.isEmpty)
        XCTAssertEqual(game.score, 0)
        XCTAssertEqual(game.mistakes, 0)
        XCTAssertNil(game.startTime)
        XCTAssertNil(game.endTime)
    }

    func testMatchingGameIsComplete() async throws {
        // Given: A game with matched pairs
        let pair1 = MatchPair(term: "Term1", definition: "Def1")
        let pair2 = MatchPair(term: "Term2", definition: "Def2")
        pair1.isMatched = true
        pair2.isMatched = true

        let game = MatchingGame(flashcardSetID: UUID(), pairs: [pair1, pair2])

        // Then: Should be complete
        XCTAssertTrue(game.isComplete, "Game should be complete when all pairs matched")
    }

    func testMatchingGameIsNotComplete() async throws {
        // Given: A game with unmatched pairs
        let pair1 = MatchPair(term: "Term1", definition: "Def1")
        let pair2 = MatchPair(term: "Term2", definition: "Def2")
        pair1.isMatched = true
        pair2.isMatched = false

        let game = MatchingGame(flashcardSetID: UUID(), pairs: [pair1, pair2])

        // Then: Should not be complete
        XCTAssertFalse(game.isComplete, "Game should not be complete with unmatched pairs")
    }

    func testMatchingGameElapsedTime() async throws {
        // Given: A game with start and end times
        let game = MatchingGame(flashcardSetID: UUID())
        let startTime = Date()
        game.startTime = startTime
        game.endTime = startTime.addingTimeInterval(60)

        // Then: Should calculate elapsed time
        XCTAssertEqual(game.elapsedTime, 60, accuracy: 0.1)
    }

    func testMatchingGameElapsedTimeNoStart() async throws {
        // Given: A game without start time
        let game = MatchingGame(flashcardSetID: UUID())

        // Then: Elapsed time should be 0
        XCTAssertEqual(game.elapsedTime, 0)
    }

    func testMatchingGameAccuracy() async throws {
        // Given: A game with pairs that have attempts
        let pair1 = MatchPair(term: "Term1", definition: "Def1")
        let pair2 = MatchPair(term: "Term2", definition: "Def2")
        pair1.attempts = 1
        pair2.attempts = 3

        let game = MatchingGame(flashcardSetID: UUID(), pairs: [pair1, pair2])

        // Then: Accuracy = pairs / totalAttempts = 2 / 4 = 0.5
        XCTAssertEqual(game.accuracy, 0.5, accuracy: 0.01)
    }

    func testMatchingGameAccuracyNoAttempts() async throws {
        // Given: A game with no attempts
        let pair1 = MatchPair(term: "Term1", definition: "Def1")
        let game = MatchingGame(flashcardSetID: UUID(), pairs: [pair1])

        // Then: Accuracy should be 0
        XCTAssertEqual(game.accuracy, 0)
    }
}

// MARK: - MatchPair Model Tests

@MainActor
final class MatchPairTests: XCTestCase {

    func testMatchPairInitialization() async throws {
        // Given/When: Creating a match pair
        let pair = MatchPair(term: "Photosynthesis", definition: "Process of converting light to energy")

        // Then: Should have correct initial state
        XCTAssertNotNil(pair.id)
        XCTAssertEqual(pair.term, "Photosynthesis")
        XCTAssertEqual(pair.definition, "Process of converting light to energy")
        XCTAssertFalse(pair.isMatched)
        XCTAssertEqual(pair.attempts, 0)
        XCTAssertNil(pair.matchedAt)
    }

    func testMatchPairMatching() async throws {
        // Given: A match pair
        let pair = MatchPair(term: "Term", definition: "Definition")

        // When: Marking as matched
        pair.isMatched = true
        pair.matchedAt = Date()

        // Then: Should be updated
        XCTAssertTrue(pair.isMatched)
        XCTAssertNotNil(pair.matchedAt)
    }
}

// MARK: - TrueFalseStatement Tests

final class TrueFalseStatementTests: XCTestCase {

    func testTrueFalseStatementCreation() {
        // Given/When: Creating a true statement
        let statement = TrueFalseStatement(
            statement: "Water boils at 100°C at sea level",
            isTrue: true,
            justification: "This is the standard boiling point of water at standard atmospheric pressure."
        )

        // Then: Should have correct values
        XCTAssertEqual(statement.statement, "Water boils at 100°C at sea level")
        XCTAssertTrue(statement.isTrue)
        XCTAssertFalse(statement.justification.isEmpty)
    }

    func testTrueFalseStatementEquality() {
        // Given: Two identical statements
        let statement1 = TrueFalseStatement(statement: "Test", isTrue: true, justification: "Because")
        let statement2 = TrueFalseStatement(statement: "Test", isTrue: true, justification: "Because")

        // Then: Should be equal
        XCTAssertEqual(statement1, statement2)
    }

    func testTrueFalseStatementInequality() {
        // Given: Two different statements
        let statement1 = TrueFalseStatement(statement: "Test", isTrue: true, justification: "Because")
        let statement2 = TrueFalseStatement(statement: "Test", isTrue: false, justification: "Because")

        // Then: Should not be equal
        XCTAssertNotEqual(statement1, statement2)
    }
}

// MARK: - MultipleChoiceQuestion Tests

final class MultipleChoiceQuestionTests: XCTestCase {

    func testMultipleChoiceQuestionCreation() {
        // Given/When: Creating a question
        let question = MultipleChoiceQuestion(
            question: "What is the capital of France?",
            correctAnswer: "Paris",
            distractors: ["London", "Berlin", "Madrid"],
            distractorAnalysis: [
                "London is the capital of the UK",
                "Berlin is the capital of Germany",
                "Madrid is the capital of Spain"
            ],
            correctExplanation: "Paris has been the capital of France since the 10th century."
        )

        // Then: Should have correct values
        XCTAssertEqual(question.question, "What is the capital of France?")
        XCTAssertEqual(question.correctAnswer, "Paris")
        XCTAssertEqual(question.distractors.count, 3)
        XCTAssertEqual(question.distractorAnalysis.count, 3)
    }

    func testMultipleChoiceAllOptions() {
        // Given: A question
        let question = MultipleChoiceQuestion(
            question: "Test",
            correctAnswer: "A",
            distractors: ["B", "C", "D"],
            distractorAnalysis: ["", "", ""],
            correctExplanation: ""
        )

        // When: Getting all options
        let options = question.allOptions

        // Then: Should contain all 4 options (shuffled)
        XCTAssertEqual(options.count, 4)
        XCTAssertTrue(options.contains("A"))
        XCTAssertTrue(options.contains("B"))
        XCTAssertTrue(options.contains("C"))
        XCTAssertTrue(options.contains("D"))
    }

    func testMultipleChoiceIsCorrect() {
        // Given: A question
        let question = MultipleChoiceQuestion(
            question: "Test",
            correctAnswer: "Correct",
            distractors: ["Wrong1", "Wrong2", "Wrong3"],
            distractorAnalysis: ["", "", ""],
            correctExplanation: ""
        )

        // Then: Should identify correct and incorrect answers
        XCTAssertTrue(question.isCorrect("Correct"))
        XCTAssertFalse(question.isCorrect("Wrong1"))
        XCTAssertFalse(question.isCorrect("Random"))
    }

    func testMultipleChoiceGetAnalysis() {
        // Given: A question with analysis
        let question = MultipleChoiceQuestion(
            question: "Test",
            correctAnswer: "Correct",
            distractors: ["Wrong1", "Wrong2", "Wrong3"],
            distractorAnalysis: ["Analysis1", "Analysis2", "Analysis3"],
            correctExplanation: "This is why it's correct"
        )

        // Then: Should return appropriate analysis
        XCTAssertEqual(question.getAnalysis(for: "Correct"), "This is why it's correct")
        XCTAssertEqual(question.getAnalysis(for: "Wrong1"), "Analysis1")
        XCTAssertEqual(question.getAnalysis(for: "Wrong2"), "Analysis2")
        XCTAssertEqual(question.getAnalysis(for: "Unknown"), "Please select an answer.")
    }
}

// MARK: - TeachBackFeedback Tests

final class TeachBackFeedbackTests: XCTestCase {

    func testTeachBackFeedbackCreation() {
        // Given/When: Creating feedback
        let feedback = TeachBackFeedback(
            accuracy: 4,
            clarity: 5,
            strengthAreas: ["Good understanding", "Clear examples"],
            improvementAreas: ["More detail needed"],
            feedback: "Excellent explanation overall!"
        )

        // Then: Should have correct values
        XCTAssertEqual(feedback.accuracy, 4)
        XCTAssertEqual(feedback.clarity, 5)
        XCTAssertEqual(feedback.strengthAreas.count, 2)
        XCTAssertEqual(feedback.improvementAreas.count, 1)
        XCTAssertFalse(feedback.feedback.isEmpty)
    }

    func testTeachBackFeedbackEquality() {
        // Given: Two identical feedbacks
        let feedback1 = TeachBackFeedback(
            accuracy: 3,
            clarity: 3,
            strengthAreas: ["Good"],
            improvementAreas: ["More"],
            feedback: "Nice"
        )
        let feedback2 = TeachBackFeedback(
            accuracy: 3,
            clarity: 3,
            strengthAreas: ["Good"],
            improvementAreas: ["More"],
            feedback: "Nice"
        )

        // Then: Should be equal
        XCTAssertEqual(feedback1, feedback2)
    }
}

// MARK: - FeynmanEvaluation Tests

final class FeynmanEvaluationTests: XCTestCase {

    func testFeynmanEvaluationCreation() {
        // Given/When: Creating evaluation
        let evaluation = FeynmanEvaluation(
            isSimpleEnough: false,
            jargonUsed: ["mitochondria", "phospholipid"],
            suggestedAnalogies: ["Think of it like a battery", "It's similar to a factory"],
            simplifiedVersion: "Cells have tiny parts that make energy."
        )

        // Then: Should have correct values
        XCTAssertFalse(evaluation.isSimpleEnough)
        XCTAssertEqual(evaluation.jargonUsed.count, 2)
        XCTAssertEqual(evaluation.suggestedAnalogies.count, 2)
        XCTAssertFalse(evaluation.simplifiedVersion.isEmpty)
    }

    func testFeynmanEvaluationSimpleEnough() {
        // Given: A simple enough evaluation
        let evaluation = FeynmanEvaluation(
            isSimpleEnough: true,
            jargonUsed: [],
            suggestedAnalogies: ["Good analogy"],
            simplifiedVersion: "Great explanation!"
        )

        // Then: Should be simple enough
        XCTAssertTrue(evaluation.isSimpleEnough)
        XCTAssertTrue(evaluation.jargonUsed.isEmpty)
    }
}
