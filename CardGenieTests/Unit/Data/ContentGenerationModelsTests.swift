//
//  ContentGenerationModelsTests.swift
//  CardGenie
//
//  Unit tests for ContentGeneration models - practice problems, scenarios, connections.
//

import XCTest
@testable import CardGenie

// MARK: - PracticeProblemBatch Tests

final class PracticeProblemBatchTests: XCTestCase {

    func testPracticeProblemBatchCreation() {
        // Given/When: Creating a batch of problems
        let problems = [
            PracticeProblem(problem: "Problem 1", solution: "Solution 1", steps: ["Step 1"], difficulty: .easier),
            PracticeProblem(problem: "Problem 2", solution: "Solution 2", steps: ["Step 1", "Step 2"], difficulty: .same),
            PracticeProblem(problem: "Problem 3", solution: "Solution 3", steps: ["Step 1"], difficulty: .harder)
        ]
        let batch = PracticeProblemBatch(problems: problems)

        // Then: Should contain all problems
        XCTAssertEqual(batch.problems.count, 3)
    }

    func testPracticeProblemBatchEquality() {
        // Given: Two identical batches
        let problems = [
            PracticeProblem(problem: "P1", solution: "S1", steps: [], difficulty: .same)
        ]
        let batch1 = PracticeProblemBatch(problems: problems)
        let batch2 = PracticeProblemBatch(problems: problems)

        // Then: Should be equal
        XCTAssertEqual(batch1, batch2)
    }
}

// MARK: - ScenarioBatch Tests

final class ScenarioBatchTests: XCTestCase {

    func testScenarioBatchCreation() {
        // Given/When: Creating a batch of scenarios
        let scenarios = [
            ScenarioQuestion(scenario: "S1", question: "Q1", idealAnswer: "A1", reasoning: "R1"),
            ScenarioQuestion(scenario: "S2", question: "Q2", idealAnswer: "A2", reasoning: "R2")
        ]
        let batch = ScenarioBatch(scenarios: scenarios)

        // Then: Should contain all scenarios
        XCTAssertEqual(batch.scenarios.count, 2)
    }

    func testScenarioBatchEquality() {
        // Given: Two identical batches
        let scenarios = [
            ScenarioQuestion(scenario: "S", question: "Q", idealAnswer: "A", reasoning: "R")
        ]
        let batch1 = ScenarioBatch(scenarios: scenarios)
        let batch2 = ScenarioBatch(scenarios: scenarios)

        // Then: Should be equal
        XCTAssertEqual(batch1, batch2)
    }
}

// MARK: - ConnectionBatch Tests

final class ConnectionBatchTests: XCTestCase {

    func testConnectionBatchCreation() {
        // Given/When: Creating a batch of challenges
        let challenges = [
            ConnectionChallenge(relatedDeck: "D1", connection: "C1", synthesisQuestion: "Q1", integratedAnswer: "A1"),
            ConnectionChallenge(relatedDeck: "D2", connection: "C2", synthesisQuestion: "Q2", integratedAnswer: "A2")
        ]
        let batch = ConnectionBatch(challenges: challenges)

        // Then: Should contain all challenges
        XCTAssertEqual(batch.challenges.count, 2)
    }

    func testConnectionBatchEquality() {
        // Given: Two identical batches
        let challenges = [
            ConnectionChallenge(relatedDeck: "D", connection: "C", synthesisQuestion: "Q", integratedAnswer: "A")
        ]
        let batch1 = ConnectionBatch(challenges: challenges)
        let batch2 = ConnectionBatch(challenges: challenges)

        // Then: Should be equal
        XCTAssertEqual(batch1, batch2)
    }
}

// MARK: - GeneratedPracticeSet Tests

@MainActor
final class GeneratedPracticeSetTests: XCTestCase {

    func testGeneratedPracticeSetInitialization() async throws {
        // Given: Source data
        let sourceID = UUID()
        let problemsData = try JSONEncoder().encode([
            PracticeProblem(problem: "P", solution: "S", steps: [], difficulty: .same)
        ])

        // When: Creating a practice set
        let practiceSet = GeneratedPracticeSet(sourceFlashcardID: sourceID, problemsData: problemsData)

        // Then: Should have correct state
        XCTAssertNotNil(practiceSet.id)
        XCTAssertEqual(practiceSet.sourceFlashcardID, sourceID)
        XCTAssertFalse(practiceSet.problemsData.isEmpty)
        XCTAssertNotNil(practiceSet.createdAt)
        XCTAssertEqual(practiceSet.completedCount, 0)
    }
}

// MARK: - GeneratedScenarioSet Tests

@MainActor
final class GeneratedScenarioSetTests: XCTestCase {

    func testGeneratedScenarioSetInitialization() async throws {
        // Given: Source data
        let sourceID = UUID()
        let scenariosData = try JSONEncoder().encode([
            ScenarioQuestion(scenario: "S", question: "Q", idealAnswer: "A", reasoning: "R")
        ])

        // When: Creating a scenario set
        let scenarioSet = GeneratedScenarioSet(sourceFlashcardID: sourceID, scenariosData: scenariosData)

        // Then: Should have correct state
        XCTAssertNotNil(scenarioSet.id)
        XCTAssertEqual(scenarioSet.sourceFlashcardID, sourceID)
        XCTAssertFalse(scenarioSet.scenariosData.isEmpty)
        XCTAssertNotNil(scenarioSet.createdAt)
        XCTAssertEqual(scenarioSet.completedCount, 0)
    }
}

// MARK: - GeneratedConnectionSet Tests

@MainActor
final class GeneratedConnectionSetTests: XCTestCase {

    func testGeneratedConnectionSetInitialization() async throws {
        // Given: Source data
        let flashcard1ID = UUID()
        let flashcard2ID = UUID()
        let challengesData = try JSONEncoder().encode([
            ConnectionChallenge(relatedDeck: "D", connection: "C", synthesisQuestion: "Q", integratedAnswer: "A")
        ])

        // When: Creating a connection set
        let connectionSet = GeneratedConnectionSet(
            flashcard1ID: flashcard1ID,
            flashcard2ID: flashcard2ID,
            challengesData: challengesData
        )

        // Then: Should have correct state
        XCTAssertNotNil(connectionSet.id)
        XCTAssertEqual(connectionSet.flashcard1ID, flashcard1ID)
        XCTAssertEqual(connectionSet.flashcard2ID, flashcard2ID)
        XCTAssertFalse(connectionSet.challengesData.isEmpty)
        XCTAssertNotNil(connectionSet.createdAt)
        XCTAssertEqual(connectionSet.completedCount, 0)
    }
}
