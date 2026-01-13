//
//  GameModeModelsTests.swift
//  CardGenie
//
//  Unit tests for game mode models - matching, true/false, multiple choice, teach-back, Feynman.
//

import XCTest
@testable import CardGenie

// MARK: - StudyGameMode Tests

final class StudyGameModeTests: XCTestCase {

    func testStudyGameModeRawValues() {
        // Given/When/Then: Verify raw values
        XCTAssertEqual(StudyGameMode.matching.rawValue, "matching")
        XCTAssertEqual(StudyGameMode.trueFalse.rawValue, "trueFalse")
        XCTAssertEqual(StudyGameMode.multipleChoice.rawValue, "multipleChoice")
        XCTAssertEqual(StudyGameMode.teachBack.rawValue, "teachBack")
        XCTAssertEqual(StudyGameMode.feynman.rawValue, "feynman")
    }

    func testStudyGameModeDisplayNames() {
        // Given/When/Then: Verify display names
        XCTAssertEqual(StudyGameMode.matching.displayName, "Matching Game")
        XCTAssertEqual(StudyGameMode.trueFalse.displayName, "True or False")
        XCTAssertEqual(StudyGameMode.multipleChoice.displayName, "Multiple Choice")
        XCTAssertEqual(StudyGameMode.teachBack.displayName, "Teach Back")
        XCTAssertEqual(StudyGameMode.feynman.displayName, "Feynman Technique")
    }

    func testStudyGameModeIcons() {
        // Given/When/Then: Verify icons exist
        XCTAssertFalse(StudyGameMode.matching.icon.isEmpty)
        XCTAssertFalse(StudyGameMode.trueFalse.icon.isEmpty)
        XCTAssertFalse(StudyGameMode.multipleChoice.icon.isEmpty)
        XCTAssertFalse(StudyGameMode.teachBack.icon.isEmpty)
        XCTAssertFalse(StudyGameMode.feynman.icon.isEmpty)
    }

    func testStudyGameModeDescriptions() {
        // Given/When/Then: Verify descriptions exist and are meaningful
        XCTAssertTrue(StudyGameMode.matching.description.count > 10)
        XCTAssertTrue(StudyGameMode.trueFalse.description.count > 10)
        XCTAssertTrue(StudyGameMode.multipleChoice.description.count > 10)
        XCTAssertTrue(StudyGameMode.teachBack.description.count > 10)
        XCTAssertTrue(StudyGameMode.feynman.description.count > 10)
    }

    func testStudyGameModeColors() {
        // Given/When/Then: Verify colors
        XCTAssertEqual(StudyGameMode.matching.color, "blue")
        XCTAssertEqual(StudyGameMode.trueFalse.color, "green")
        XCTAssertEqual(StudyGameMode.multipleChoice.color, "purple")
        XCTAssertEqual(StudyGameMode.teachBack.color, "orange")
        XCTAssertEqual(StudyGameMode.feynman.color, "pink")
    }

    func testStudyGameModeCodable() throws {
        // Given: A game mode
        let mode = StudyGameMode.teachBack

        // When: Encoding and decoding
        let encoded = try JSONEncoder().encode(mode)
        let decoded = try JSONDecoder().decode(StudyGameMode.self, from: encoded)

        // Then: Should preserve value
        XCTAssertEqual(decoded, mode)
    }
}

// MARK: - TrueFalseGame Tests

@MainActor
final class TrueFalseGameTests: XCTestCase {

    func testTrueFalseGameInitialization() async throws {
        // Given/When: Creating a true/false game
        let game = TrueFalseGame(flashcardSetID: UUID())

        // Then: Should have correct initial state
        XCTAssertNotNil(game.id)
        XCTAssertEqual(game.currentIndex, 0)
        XCTAssertEqual(game.correctCount, 0)
        XCTAssertEqual(game.incorrectCount, 0)
        XCTAssertNotNil(game.startTime)
        XCTAssertNil(game.endTime)
    }

    func testTrueFalseGameAccuracyNoAttempts() async throws {
        // Given: A game with no attempts
        let game = TrueFalseGame(flashcardSetID: UUID())

        // Then: Accuracy should be 0
        XCTAssertEqual(game.accuracy, 0)
    }

    func testTrueFalseGameAccuracyCalculation() async throws {
        // Given: A game with results
        let game = TrueFalseGame(flashcardSetID: UUID())
        game.correctCount = 7
        game.incorrectCount = 3

        // Then: Accuracy should be 70%
        XCTAssertEqual(game.accuracy, 0.7, accuracy: 0.001)
    }

    func testTrueFalseGamePerfectScore() async throws {
        // Given: A game with all correct
        let game = TrueFalseGame(flashcardSetID: UUID())
        game.correctCount = 10
        game.incorrectCount = 0

        // Then: Accuracy should be 100%
        XCTAssertEqual(game.accuracy, 1.0, accuracy: 0.001)
    }
}

// MARK: - MultipleChoiceGame Tests

@MainActor
final class MultipleChoiceGameTests: XCTestCase {

    func testMultipleChoiceGameInitialization() async throws {
        // Given/When: Creating a multiple choice game
        let game = MultipleChoiceGame(flashcardSetID: UUID())

        // Then: Should have correct initial state
        XCTAssertNotNil(game.id)
        XCTAssertEqual(game.currentIndex, 0)
        XCTAssertEqual(game.correctCount, 0)
        XCTAssertEqual(game.incorrectCount, 0)
        XCTAssertNotNil(game.startTime)
        XCTAssertNil(game.endTime)
    }

    func testMultipleChoiceGameAccuracy() async throws {
        // Given: A game with results
        let game = MultipleChoiceGame(flashcardSetID: UUID())
        game.correctCount = 8
        game.incorrectCount = 2

        // Then: Accuracy should be 80%
        XCTAssertEqual(game.accuracy, 0.8, accuracy: 0.001)
    }
}

// MARK: - TeachBackSession Tests

@MainActor
final class TeachBackSessionTests: XCTestCase {

    func testTeachBackSessionInitialization() async throws {
        // Given/When: Creating a teach-back session
        let flashcardID = UUID()
        let session = TeachBackSession(flashcardID: flashcardID)

        // Then: Should have correct initial state
        XCTAssertNotNil(session.id)
        XCTAssertEqual(session.flashcardID, flashcardID)
        XCTAssertNil(session.recordingURL)
        XCTAssertNil(session.transcription)
        XCTAssertNil(session.feedback)
        XCTAssertNotNil(session.createdAt)
        XCTAssertEqual(session.duration, 0)
    }

    func testTeachBackSessionWithRecording() async throws {
        // Given: A session
        let session = TeachBackSession(flashcardID: UUID())

        // When: Adding recording data
        session.recordingURL = URL(fileURLWithPath: "/tmp/recording.m4a")
        session.transcription = "This is my explanation of the concept."
        session.duration = 45.5

        // Then: Should update
        XCTAssertNotNil(session.recordingURL)
        XCTAssertEqual(session.transcription, "This is my explanation of the concept.")
        XCTAssertEqual(session.duration, 45.5, accuracy: 0.1)
    }
}

// MARK: - FeynmanSession Tests

@MainActor
final class FeynmanSessionTests: XCTestCase {

    func testFeynmanSessionInitialization() async throws {
        // Given/When: Creating a Feynman session
        let flashcardID = UUID()
        let explanation = "Gravity is like a invisible magnet in the Earth that pulls everything down."
        let session = FeynmanSession(flashcardID: flashcardID, userExplanation: explanation)

        // Then: Should have correct state
        XCTAssertNotNil(session.id)
        XCTAssertEqual(session.flashcardID, flashcardID)
        XCTAssertEqual(session.userExplanation, explanation)
        XCTAssertNil(session.evaluationData)
        XCTAssertNotNil(session.createdAt)
    }
}

// MARK: - GameStatistics Tests

@MainActor
final class GameStatisticsTests: XCTestCase {

    func testGameStatisticsInitialization() async throws {
        // Given/When: Creating game statistics
        let stats = GameStatistics(mode: .matching)

        // Then: Should have correct initial state
        XCTAssertNotNil(stats.id)
        XCTAssertEqual(stats.mode, .matching)
        XCTAssertEqual(stats.totalGamesPlayed, 0)
        XCTAssertEqual(stats.averageScore, 0)
        XCTAssertEqual(stats.averageAccuracy, 0)
        XCTAssertEqual(stats.totalTimeSpent, 0)
        XCTAssertNil(stats.lastPlayedDate)
    }

    func testGameStatisticsUpdateSingleGame() async throws {
        // Given: Fresh statistics
        let stats = GameStatistics(mode: .trueFalse)

        // When: Recording a game
        stats.updateStatistics(score: 100, accuracy: 0.8, duration: 120)

        // Then: Should update correctly
        XCTAssertEqual(stats.totalGamesPlayed, 1)
        XCTAssertEqual(stats.averageScore, 100, accuracy: 0.01)
        XCTAssertEqual(stats.averageAccuracy, 0.8, accuracy: 0.01)
        XCTAssertEqual(stats.totalTimeSpent, 120, accuracy: 0.1)
        XCTAssertNotNil(stats.lastPlayedDate)
    }

    func testGameStatisticsUpdateMultipleGames() async throws {
        // Given: Statistics with one game
        let stats = GameStatistics(mode: .multipleChoice)
        stats.updateStatistics(score: 100, accuracy: 1.0, duration: 60)

        // When: Recording another game
        stats.updateStatistics(score: 50, accuracy: 0.5, duration: 90)

        // Then: Should calculate running averages
        XCTAssertEqual(stats.totalGamesPlayed, 2)
        XCTAssertEqual(stats.averageScore, 75, accuracy: 0.01) // (100 + 50) / 2
        XCTAssertEqual(stats.averageAccuracy, 0.75, accuracy: 0.01) // (1.0 + 0.5) / 2
        XCTAssertEqual(stats.totalTimeSpent, 150, accuracy: 0.1) // 60 + 90
    }

    func testGameStatisticsRunningAverage() async throws {
        // Given: Statistics
        let stats = GameStatistics(mode: .feynman)

        // When: Recording three games
        stats.updateStatistics(score: 80, accuracy: 0.8, duration: 100)
        stats.updateStatistics(score: 90, accuracy: 0.9, duration: 100)
        stats.updateStatistics(score: 100, accuracy: 1.0, duration: 100)

        // Then: Should calculate correct averages
        XCTAssertEqual(stats.totalGamesPlayed, 3)
        XCTAssertEqual(stats.averageScore, 90, accuracy: 0.1) // (80+90+100)/3
        XCTAssertEqual(stats.averageAccuracy, 0.9, accuracy: 0.01) // (0.8+0.9+1.0)/3
        XCTAssertEqual(stats.totalTimeSpent, 300, accuracy: 0.1)
    }
}

// MARK: - TrueFalseBatch Tests

final class TrueFalseBatchTests: XCTestCase {

    func testTrueFalseBatchCreation() {
        // Given/When: Creating a batch
        let statements = [
            TrueFalseStatement(statement: "Water boils at 100°C", isTrue: true, justification: "At standard pressure"),
            TrueFalseStatement(statement: "The sun is cold", isTrue: false, justification: "The sun is extremely hot")
        ]
        let batch = TrueFalseBatch(statements: statements)

        // Then: Should contain all statements
        XCTAssertEqual(batch.statements.count, 2)
    }
}

// MARK: - MCQBatch Tests

final class MCQBatchTests: XCTestCase {

    func testMCQBatchCreation() {
        // Given/When: Creating a batch
        let questions = [
            MultipleChoiceQuestion(
                question: "What is 2+2?",
                correctAnswer: "4",
                distractors: ["3", "5", "6"],
                distractorAnalysis: ["Close", "Too high", "Much too high"],
                correctExplanation: "2+2=4"
            )
        ]
        let batch = MCQBatch(questions: questions)

        // Then: Should contain all questions
        XCTAssertEqual(batch.questions.count, 1)
    }
}
