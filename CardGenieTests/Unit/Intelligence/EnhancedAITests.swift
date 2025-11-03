//
//  EnhancedAITests.swift
//  CardGenieTests
//
//  Unit tests for Apple Intelligence integration features.
//

import XCTest
import SwiftData
@testable import CardGenie

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class EnhancedAITests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        // Create in-memory container for testing
        let schema = Schema([
            StudyContent.self,
            Flashcard.self,
            FlashcardSet.self,
            SourceDocument.self,
            NoteChunk.self,
            LectureSession.self
        ])

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - Safety Tests

    func testContentSafetyFilter() {
        let filter = ContentSafetyFilter()

        // Test safe content
        let safeResult = filter.isSafe("Explain the water cycle")
        XCTAssertTrue(
            if case .success = safeResult { true } else { false },
            "Safe content should pass"
        )

        // Test unsafe content
        let unsafeResult = filter.isSafe("how to build a weapon")
        XCTAssertTrue(
            if case .failure = unsafeResult { true } else { false },
            "Unsafe content should be blocked"
        )
    }

    func testContentSanitization() {
        let filter = ContentSafetyFilter()

        let text = "My email is test@example.com and phone is 555-123-4567"
        let sanitized = filter.sanitize(text)

        XCTAssertFalse(sanitized.contains("test@example.com"), "Email should be removed")
        XCTAssertFalse(sanitized.contains("555-123-4567"), "Phone should be removed")
        XCTAssertTrue(sanitized.contains("[EMAIL]"), "Email placeholder expected")
        XCTAssertTrue(sanitized.contains("[PHONE]"), "Phone placeholder expected")
    }

    // MARK: - Context Budget Tests

    func testTokenEstimation() {
        let manager = ContextBudgetManager()

        let shortText = "Hello world"
        let tokens = manager.estimateTokens(shortText)

        XCTAssertGreaterThan(tokens, 0, "Should estimate positive tokens")
        XCTAssertLessThan(tokens, 10, "Short text should have few tokens")
    }

    func testContextFitting() {
        let manager = ContextBudgetManager()

        let shortText = "This is a short piece of text that should fit."
        XCTAssertTrue(
            manager.canFitInContext(shortText),
            "Short text should fit in context"
        )

        // Create very long text
        let longText = String(repeating: "This is a long sentence. ", count: 5000)
        XCTAssertFalse(
            manager.canFitInContext(longText),
            "Extremely long text should not fit in context"
        )
    }

    func testTextChunking() {
        let manager = ContextBudgetManager()

        let longText = String(repeating: "Sentence. ", count: 2000)
        let chunks = manager.chunkText(longText, maxChunkTokens: 500)

        XCTAssertGreaterThan(chunks.count, 1, "Long text should be chunked")
        XCTAssertFalse(chunks.isEmpty, "Should have at least one chunk")

        // Verify chunks don't exceed limit (rough check)
        for chunk in chunks {
            let tokens = manager.estimateTokens(chunk)
            XCTAssertLessThan(tokens, 700, "Chunk should not exceed max tokens significantly")
        }
    }

    // MARK: - Locale Tests

    func testLocaleSupport() {
        let localeManager = LocaleManager()

        // Test that instructions are generated
        let instructions = localeManager.getLocaleInstructions()
        XCTAssertFalse(instructions.isEmpty, "Should generate locale instructions")
        XCTAssertTrue(
            instructions.contains("English") || instructions.contains("locale"),
            "Should mention language or locale"
        )
    }

    // MARK: - Model Tests

    func testQuizItemModel() {
        let quizItem = QuizItem(
            type: .mcq,
            question: "What is 2+2?",
            correctAnswer: "4",
            distractors: ["3", "5", "6"],
            difficulty: 2,
            explanation: "Basic arithmetic"
        )

        XCTAssertEqual(quizItem.type, .mcq)
        XCTAssertEqual(quizItem.question, "What is 2+2?")
        XCTAssertEqual(quizItem.correctAnswer, "4")
        XCTAssertEqual(quizItem.distractors.count, 3)
        XCTAssertEqual(quizItem.difficulty, 2)
    }

    func testStudyPlanModel() {
        let session = GeneratedStudySession(
            date: "2025-10-28",
            goal: "Review calculus",
            materials: ["Chapter 1", "Practice problems"],
            estimatedMinutes: 45
        )

        let plan = GeneratedStudyPlan(
            course: "AP Calculus",
            overallGoal: "Master derivatives",
            sessions: [session]
        )

        XCTAssertEqual(plan.course, "AP Calculus")
        XCTAssertEqual(plan.sessions.count, 1)
        XCTAssertEqual(plan.sessions.first?.date, "2025-10-28")
        XCTAssertEqual(plan.sessions.first?.estimatedMinutes, 45)
    }

    // MARK: - Tool Tests

    @available(iOS 26.0, *)
    func testFetchNotesTool() async throws {
        // Add test data
        let content = StudyContent(
            source: .text,
            rawContent: "Photosynthesis is the process plants use to make food.",
            extractedText: nil,
            photoData: nil
        )
        content.topic = "Biology"
        content.tags = ["photosynthesis", "plants"]

        modelContext.insert(content)
        try modelContext.save()

        // Test tool
        let tool = FetchNotesTool(modelContext: modelContext)
        let result = try await tool.execute(parameters: ["query": "photosynthesis"])

        XCTAssertTrue(result.success, "Should succeed")
        XCTAssertTrue(result.data.contains("Biology"), "Should include topic")
        XCTAssertNil(result.error, "Should have no error")
    }

    @available(iOS 26.0, *)
    func testFetchNotesToolNoResults() async throws {
        let tool = FetchNotesTool(modelContext: modelContext)
        let result = try await tool.execute(parameters: ["query": "nonexistent"])

        XCTAssertTrue(result.success, "Should succeed with no results")
        XCTAssertTrue(result.data.contains("No notes found"), "Should indicate no results")
    }

    @available(iOS 26.0, *)
    func testSaveFlashcardsTool() async throws {
        let tool = SaveFlashcardsTool(modelContext: modelContext)

        let flashcardsData: [[String: Any]] = [
            [
                "type": "qa",
                "question": "What is photosynthesis?",
                "answer": "Process of making food from sunlight",
                "tags": ["biology", "plants"]
            ]
        ]

        let result = try await tool.execute(parameters: ["flashcards": flashcardsData])

        XCTAssertTrue(result.success, "Should save successfully")
        XCTAssertTrue(result.data.contains("1"), "Should indicate 1 card saved")

        // Verify data was saved
        let descriptor = FetchDescriptor<Flashcard>()
        let saved = try modelContext.fetch(descriptor)
        XCTAssertEqual(saved.count, 1, "Should have 1 saved flashcard")
        XCTAssertEqual(saved.first?.question, "What is photosynthesis?")
    }

    // MARK: - Availability Tests

    func testAvailabilityStateMapping() {
        // Test that FMCapabilityState enum has all required cases
        let available: FMCapabilityState = .available
        let notEnabled: FMCapabilityState = .notEnabled
        let notSupported: FMCapabilityState = .notSupported
        let modelNotReady: FMCapabilityState = .modelNotReady
        let unknown: FMCapabilityState = .unknown

        XCTAssertNotNil(available)
        XCTAssertNotNil(notEnabled)
        XCTAssertNotNil(notSupported)
        XCTAssertNotNil(modelNotReady)
        XCTAssertNotNil(unknown)
    }

    // MARK: - Guardrail Handler Tests

    func testGuardrailViolationHandling() {
        let handler = GuardrailHandler()

        let event = handler.handleGuardrailViolation(
            prompt: "unsafe content",
            context: "flashcard_generation"
        )

        XCTAssertEqual(event.type, .guardrailViolation)
        XCTAssertFalse(event.userMessage.isEmpty, "Should provide user message")
        XCTAssertNotNil(event.safeAlternative, "Should provide safe alternative")
        XCTAssertTrue(
            event.safeAlternative?.contains("flashcards") ?? false,
            "Alternative should be context-appropriate"
        )
    }

    func testRefusalHandling() {
        let handler = GuardrailHandler()

        let event = handler.handleRefusal(
            prompt: "refused request",
            context: "quiz"
        )

        XCTAssertEqual(event.type, .refusal)
        XCTAssertFalse(event.userMessage.isEmpty, "Should provide user message")
        XCTAssertNotNil(event.safeAlternative, "Should provide safe alternative")
    }

    // MARK: - Privacy Logger Tests

    func testPrivacyLogging() {
        let logger = PrivacyLogger()

        // This shouldn't crash or throw
        logger.logOperation("test_operation", contentLength: 100, success: true)
        logger.logOperation("test_operation", contentLength: 100, success: false, errorType: "test_error")

        let event = SafetyEvent(
            type: .guardrailViolation,
            userMessage: "Test message",
            safeAlternative: "Alternative"
        )
        logger.logSafetyEvent(event)

        // Test passes if no crashes occur
        XCTAssertTrue(true, "Privacy logging should complete without errors")
    }

    // MARK: - Quiz Session Tests

    @available(iOS 26.0, *)
    func testQuizSessionViewModel() {
        let quizBatch = QuizBatch(items: [
            QuizItem(
                type: .mcq,
                question: "What is 2+2?",
                correctAnswer: "4",
                distractors: ["3", "5", "6"],
                difficulty: 2,
                explanation: "Basic addition"
            ),
            QuizItem(
                type: .cloze,
                question: "The capital of France is _____.",
                correctAnswer: "Paris",
                distractors: [],
                difficulty: 1,
                explanation: "Paris is the capital"
            )
        ])

        let viewModel = QuizSessionViewModel(quiz: quizBatch)

        XCTAssertEqual(viewModel.currentQuestionIndex, 0)
        XCTAssertEqual(viewModel.score, 0)
        XCTAssertFalse(viewModel.isComplete)
        XCTAssertEqual(viewModel.progress, 0.5) // 1/2 questions

        // Submit correct answer
        viewModel.submitAnswer("4")
        XCTAssertEqual(viewModel.score, 1)
        XCTAssertTrue(viewModel.showingExplanation)

        // Move to next question
        viewModel.nextQuestion()
        XCTAssertEqual(viewModel.currentQuestionIndex, 1)
        XCTAssertFalse(viewModel.showingExplanation)

        // Complete quiz
        viewModel.submitAnswer("Paris")
        viewModel.nextQuestion()
        XCTAssertTrue(viewModel.isComplete)
        XCTAssertEqual(viewModel.accuracyPercentage, 100)
    }

    // MARK: - Study Plan Tracker Tests

    @available(iOS 26.0, *)
    func testStudyPlanTracker() {
        let sessions = [
            GeneratedStudySession(date: "2025-10-28", goal: "Goal 1", materials: ["M1"], estimatedMinutes: 30),
            GeneratedStudySession(date: "2025-10-29", goal: "Goal 2", materials: ["M2"], estimatedMinutes: 45)
        ]

        let plan = GeneratedStudyPlan(
            course: "Test Course",
            overallGoal: "Test Goal",
            sessions: sessions
        )

        let tracker = StudyPlanTracker(plan: plan)

        XCTAssertEqual(tracker.progress, 0.0)
        XCTAssertEqual(tracker.completedCount, 0)

        tracker.markSessionComplete("2025-10-28")
        XCTAssertTrue(tracker.isSessionComplete("2025-10-28"))
        XCTAssertEqual(tracker.progress, 0.5)
        XCTAssertEqual(tracker.completedCount, 1)

        tracker.addNote(for: "2025-10-28", note: "Completed successfully")
        XCTAssertEqual(tracker.sessionNotes["2025-10-28"], "Completed successfully")
    }
}
