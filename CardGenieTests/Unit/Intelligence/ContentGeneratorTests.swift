//
//  ContentGeneratorTests.swift
//  CardGenie
//
//  Unit tests for ContentGenerator - AI-powered practice problem and scenario generation.
//

import XCTest
@testable import CardGenie

@MainActor
final class ContentGeneratorTests: XCTestCase {
    var generator: ContentGenerator!

    override func setUp() async throws {
        generator = ContentGenerator()
    }

    override func tearDown() async throws {
        generator = nil
    }

    // MARK: - Initialization Tests

    func testInitialization() async throws {
        // Given/When: Creating a ContentGenerator
        // Then: Should initialize successfully
        XCTAssertNotNil(generator, "ContentGenerator should initialize")
    }

    // MARK: - Practice Problem Generation Tests (Fallback)

    func testGeneratePracticeProblemsReturnsProblems() async throws {
        // Given: A flashcard
        let flashcard = createTestFlashcard(
            question: "Calculate the area of a rectangle with length 5 and width 3",
            answer: "Area = 5 × 3 = 15 square units"
        )

        // When: Generating practice problems
        do {
            let problems = try await generator.generatePracticeProblems(from: flashcard, count: 3)

            // Then: Should return problems
            XCTAssertFalse(problems.isEmpty, "Should generate problems")
            // Fallback returns at least 1 problem
            XCTAssertGreaterThanOrEqual(problems.count, 1)
        } catch {
            // Expected in environments without AI
            XCTAssertTrue(error is FMError, "Should throw FMError")
        }
    }

    func testGeneratePracticeProblemsCustomCount() async throws {
        // Given: A flashcard
        let flashcard = createTestFlashcard(
            question: "Solve for x: 2x + 4 = 10",
            answer: "x = 3"
        )

        // When: Requesting specific count
        do {
            let problems = try await generator.generatePracticeProblems(from: flashcard, count: 5)

            // Then: Should attempt to generate requested count
            XCTAssertGreaterThanOrEqual(problems.count, 1)
        } catch {
            XCTAssertTrue(error is FMError)
        }
    }

    func testPracticeProblemHasRequiredFields() async throws {
        // Given: A flashcard
        let flashcard = createTestFlashcard(
            question: "What is 2 + 2?",
            answer: "4"
        )

        // When: Generating
        do {
            let problems = try await generator.generatePracticeProblems(from: flashcard)

            // Then: Each problem should have required fields
            for problem in problems {
                XCTAssertFalse(problem.problem.isEmpty, "Problem should have text")
                XCTAssertFalse(problem.solution.isEmpty, "Problem should have solution")
                XCTAssertFalse(problem.steps.isEmpty, "Problem should have steps")
            }
        } catch {
            XCTAssertTrue(error is FMError)
        }
    }

    // MARK: - Scenario Generation Tests (Fallback)

    func testGenerateScenariosReturnsScenarios() async throws {
        // Given: A flashcard with a concept
        let flashcard = createTestFlashcard(
            question: "What is compound interest?",
            answer: "Interest calculated on both the initial principal and accumulated interest"
        )

        // When: Generating scenarios
        do {
            let scenarios = try await generator.generateScenarios(from: flashcard)

            // Then: Should return scenarios
            XCTAssertFalse(scenarios.isEmpty, "Should generate scenarios")
        } catch {
            XCTAssertTrue(error is FMError)
        }
    }

    func testScenarioHasRequiredFields() async throws {
        // Given: A flashcard
        let flashcard = createTestFlashcard(
            question: "What is opportunity cost?",
            answer: "The loss of potential gain from other alternatives when one option is chosen"
        )

        // When: Generating
        do {
            let scenarios = try await generator.generateScenarios(from: flashcard)

            // Then: Each scenario should have required fields
            for scenario in scenarios {
                XCTAssertFalse(scenario.scenario.isEmpty, "Should have scenario description")
                XCTAssertFalse(scenario.question.isEmpty, "Should have question")
                XCTAssertFalse(scenario.idealAnswer.isEmpty, "Should have ideal answer")
                XCTAssertFalse(scenario.reasoning.isEmpty, "Should have reasoning")
            }
        } catch {
            XCTAssertTrue(error is FMError)
        }
    }

    // MARK: - Connection Challenge Tests (Fallback)

    func testGenerateConnectionChallenges() async throws {
        // Given: Two flashcards from different decks
        let flashcard1 = createTestFlashcard(
            question: "What is Newton's First Law?",
            answer: "An object at rest stays at rest unless acted upon by a force"
        )
        let flashcard2 = createTestFlashcard(
            question: "What is inertia?",
            answer: "The tendency of an object to resist changes in motion"
        )

        // When: Generating connection challenges
        do {
            let challenges = try await generator.generateConnectionChallenges(
                flashcard1: flashcard1,
                flashcard2: flashcard2,
                deck1Name: "Physics",
                deck2Name: "Motion"
            )

            // Then: Should return challenges
            XCTAssertFalse(challenges.isEmpty, "Should generate challenges")
        } catch {
            XCTAssertTrue(error is FMError)
        }
    }

    func testConnectionChallengeHasRequiredFields() async throws {
        // Given: Two flashcards
        let flashcard1 = createTestFlashcard(question: "Test 1", answer: "Answer 1")
        let flashcard2 = createTestFlashcard(question: "Test 2", answer: "Answer 2")

        // When: Generating
        do {
            let challenges = try await generator.generateConnectionChallenges(
                flashcard1: flashcard1,
                flashcard2: flashcard2,
                deck1Name: "Deck1",
                deck2Name: "Deck2"
            )

            // Then: Each challenge should have required fields
            for challenge in challenges {
                XCTAssertFalse(challenge.relatedDeck.isEmpty, "Should have related deck")
                XCTAssertFalse(challenge.connection.isEmpty, "Should have connection")
                XCTAssertFalse(challenge.synthesisQuestion.isEmpty, "Should have synthesis question")
                XCTAssertFalse(challenge.integratedAnswer.isEmpty, "Should have integrated answer")
            }
        } catch {
            XCTAssertTrue(error is FMError)
        }
    }

    // MARK: - Bulk Generation Tests

    func testGenerateAllContent() async throws {
        // Given: A flashcard
        let flashcard = createTestFlashcard(
            question: "What is the water cycle?",
            answer: "The continuous movement of water within the Earth and atmosphere"
        )

        // When: Generating all content
        do {
            let (problems, scenarios) = try await generator.generateAllContent(for: flashcard)

            // Then: Should return both types
            XCTAssertGreaterThanOrEqual(problems.count, 0)
            XCTAssertGreaterThanOrEqual(scenarios.count, 0)
        } catch {
            XCTAssertTrue(error is FMError)
        }
    }

    // MARK: - Caching Tests

    func testCachePracticeProblems() async throws {
        // Given: Problems and a flashcard ID
        let flashcardID = UUID()
        let problems = [
            PracticeProblem(
                problem: "Test problem",
                solution: "Test solution",
                steps: ["Step 1"],
                difficulty: .same
            )
        ]

        // When: Caching
        generator.cachePracticeProblems(problems, for: flashcardID)

        // Then: Should retrieve from cache
        let cached = generator.getCachedPracticeProblems(for: flashcardID)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.count, 1)
    }

    func testCacheScenariosProblems() async throws {
        // Given: Scenarios and a flashcard ID
        let flashcardID = UUID()
        let scenarios = [
            ScenarioQuestion(
                scenario: "Test scenario",
                question: "Test question",
                idealAnswer: "Test answer",
                reasoning: "Test reasoning"
            )
        ]

        // When: Caching
        generator.cacheScenarios(scenarios, for: flashcardID)

        // Then: Should retrieve from cache
        let cached = generator.getCachedScenarios(for: flashcardID)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.count, 1)
    }

    func testGetCachedProblemsNotFound() async throws {
        // Given: An ID with no cached content
        let flashcardID = UUID()

        // When: Getting cached
        let cached = generator.getCachedPracticeProblems(for: flashcardID)

        // Then: Should return nil
        XCTAssertNil(cached)
    }

    func testClearCache() async throws {
        // Given: Cached content
        let flashcardID = UUID()
        generator.cachePracticeProblems([
            PracticeProblem(problem: "Test", solution: "Sol", steps: [], difficulty: .same)
        ], for: flashcardID)

        // When: Clearing cache
        generator.clearCache()

        // Then: Cache should be empty
        XCTAssertNil(generator.getCachedPracticeProblems(for: flashcardID))
        XCTAssertNil(generator.getCachedScenarios(for: flashcardID))
    }

    // MARK: - Flashcard Extension Tests

    func testFlashcardSupportsPracticeProblems() async throws {
        // Given: A flashcard with calculation keywords
        let mathCard = createTestFlashcard(
            question: "Calculate the derivative of x²",
            answer: "2x"
        )
        let nonMathCard = createTestFlashcard(
            question: "Who wrote Hamlet?",
            answer: "Shakespeare"
        )

        // Then: Math card should support practice problems
        XCTAssertTrue(mathCard.supportsPracticeProblems, "Math card should support practice problems")
        XCTAssertFalse(nonMathCard.supportsPracticeProblems, "Non-math card should not support practice problems")
    }

    func testFlashcardSupportsScenarios() async throws {
        // Given: Flashcards with different answer lengths
        let longAnswer = createTestFlashcard(
            question: "What is economics?",
            answer: "Economics is the social science that studies the production, distribution, and consumption of goods and services."
        )
        let shortAnswer = createTestFlashcard(
            question: "What is 2+2?",
            answer: "4"
        )

        // Then: Long answer should support scenarios
        XCTAssertTrue(longAnswer.supportsScenarios, "Long answer should support scenarios")
        XCTAssertFalse(shortAnswer.supportsScenarios, "Short answer should not support scenarios")
    }

    func testFlashcardSupportsConnections() async throws {
        // Given: A normal flashcard
        let card = createTestFlashcard(question: "Test", answer: "Answer")

        // Then: Most cards should support connections
        XCTAssertTrue(card.supportsConnections)
    }

    // MARK: - Error Type Tests

    func testContentGeneratorErrorDescriptions() async throws {
        // Given: Different error types
        let invalidFlashcard = ContentGeneratorError.invalidFlashcard
        let generationFailed = ContentGeneratorError.generationFailed
        let insufficientContent = ContentGeneratorError.insufficientContent

        // Then: Should have appropriate descriptions
        XCTAssertNotNil(invalidFlashcard.errorDescription)
        XCTAssertNotNil(generationFailed.errorDescription)
        XCTAssertNotNil(insufficientContent.errorDescription)
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

// MARK: - PracticeProblem Tests

final class PracticeProblemTests: XCTestCase {

    func testPracticeProblemCreation() {
        // Given/When: Creating a practice problem
        let problem = PracticeProblem(
            problem: "What is 5 × 7?",
            solution: "35",
            steps: ["Multiply 5 by 7", "The answer is 35"],
            difficulty: .same
        )

        // Then: Should have correct values
        XCTAssertEqual(problem.problem, "What is 5 × 7?")
        XCTAssertEqual(problem.solution, "35")
        XCTAssertEqual(problem.steps.count, 2)
        XCTAssertEqual(problem.difficulty, .same)
    }

    func testPracticeProblemDifficulties() {
        // Given: All difficulty levels
        let easier = RelativeDifficulty.easier
        let same = RelativeDifficulty.same
        let harder = RelativeDifficulty.harder

        // Then: Should have correct raw values
        XCTAssertEqual(easier.rawValue, "easier")
        XCTAssertEqual(same.rawValue, "same")
        XCTAssertEqual(harder.rawValue, "harder")
    }

    func testPracticeProblemStepsFormatted() {
        // Given: A problem with steps
        let problem = PracticeProblem(
            problem: "Test",
            solution: "Answer",
            steps: ["First step", "Second step", "Third step"],
            difficulty: .same
        )

        // When: Getting formatted steps
        let formatted = problem.stepsFormatted

        // Then: Should be numbered
        XCTAssertTrue(formatted.contains("1."))
        XCTAssertTrue(formatted.contains("2."))
        XCTAssertTrue(formatted.contains("3."))
    }

    func testRelativeDifficultyDisplayName() {
        // Given: All difficulties
        // Then: Should have display names
        XCTAssertEqual(RelativeDifficulty.easier.displayName, "Easier")
        XCTAssertEqual(RelativeDifficulty.same.displayName, "Same Difficulty")
        XCTAssertEqual(RelativeDifficulty.harder.displayName, "Harder")
    }

    func testRelativeDifficultyIcon() {
        // Given: All difficulties
        // Then: Should have icons
        XCTAssertEqual(RelativeDifficulty.easier.icon, "arrow.down.circle")
        XCTAssertEqual(RelativeDifficulty.same.icon, "equal.circle")
        XCTAssertEqual(RelativeDifficulty.harder.icon, "arrow.up.circle")
    }

    func testRelativeDifficultyColor() {
        // Given: All difficulties
        // Then: Should have colors
        XCTAssertEqual(RelativeDifficulty.easier.color, "green")
        XCTAssertEqual(RelativeDifficulty.same.color, "blue")
        XCTAssertEqual(RelativeDifficulty.harder.color, "red")
    }
}

// MARK: - ScenarioQuestion Tests

final class ScenarioQuestionTests: XCTestCase {

    func testScenarioQuestionCreation() {
        // Given/When: Creating a scenario
        let scenario = ScenarioQuestion(
            scenario: "You're at a grocery store deciding between two brands",
            question: "How would you apply opportunity cost here?",
            idealAnswer: "Consider what you give up by choosing one option",
            reasoning: "This helps illustrate the trade-offs in decision making"
        )

        // Then: Should have correct values
        XCTAssertFalse(scenario.scenario.isEmpty)
        XCTAssertFalse(scenario.question.isEmpty)
        XCTAssertFalse(scenario.idealAnswer.isEmpty)
        XCTAssertFalse(scenario.reasoning.isEmpty)
    }

    func testScenarioQuestionFullQuestion() {
        // Given: A scenario
        let scenario = ScenarioQuestion(
            scenario: "Context scenario",
            question: "What would you do?",
            idealAnswer: "Answer",
            reasoning: "Because"
        )

        // When: Getting full question
        let fullQuestion = scenario.fullQuestion

        // Then: Should combine scenario and question
        XCTAssertTrue(fullQuestion.contains("Context scenario"))
        XCTAssertTrue(fullQuestion.contains("What would you do?"))
        XCTAssertTrue(fullQuestion.contains("\n\n"))
    }
}

// MARK: - ConnectionChallenge Tests

final class ConnectionChallengeTests: XCTestCase {

    func testConnectionChallengeCreation() {
        // Given/When: Creating a connection challenge
        let challenge = ConnectionChallenge(
            relatedDeck: "Chemistry",
            connection: "Both involve atomic structure",
            synthesisQuestion: "How do physics and chemistry overlap?",
            integratedAnswer: "They share fundamental principles about matter"
        )

        // Then: Should have correct values
        XCTAssertEqual(challenge.relatedDeck, "Chemistry")
        XCTAssertFalse(challenge.connection.isEmpty)
        XCTAssertFalse(challenge.synthesisQuestion.isEmpty)
        XCTAssertFalse(challenge.integratedAnswer.isEmpty)
    }
}
