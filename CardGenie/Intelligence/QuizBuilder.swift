//
//  QuizBuilder.swift
//  CardGenie
//
//  AI-powered quiz generation using Apple Intelligence and tool calling.
//

import Foundation
import SwiftData
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Quiz Builder

@available(iOS 26.0, *)
@MainActor
final class QuizBuilder: ObservableObject {
    private let log = Logger(subsystem: "com.cardgenie.app", category: "QuizBuilder")

    @Published private(set) var isGenerating = false
    @Published private(set) var currentQuiz: QuizBatch?
    @Published private(set) var error: String?

    private let sessionManager = EnhancedSessionManager()
    private let toolRegistry: ToolRegistry
    private let modelContext: ModelContext

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.toolRegistry = ToolRegistry(modelContext: modelContext)
    }

    // MARK: - Quiz Generation

    /// Generate a mixed quiz from notes on a specific topic
    func generateQuiz(topic: String) async {
        guard !isGenerating else {
            log.warning("Quiz generation already in progress")
            return
        }

        isGenerating = true
        error = nil
        defer { isGenerating = false }

        log.info("Starting quiz generation for topic: \(topic)")

        // Load system prompt
        let systemPrompt = loadPrompt(named: "QuizBuilder") ?? """
        Build a 6-question mixed quiz (3 MCQ, 2 cloze, 1 short answer) from study materials.
        Use tools to fetch notes and ensure questions test understanding, not just recall.
        """

        // Prepare instructions with tool information
        let instructions = """
        \(systemPrompt)

        Available tools:
        - fetch_notes(query: String): Search study notes by topic
        - save_flashcards(flashcards: Array): Save review cards for tricky concepts

        IMPORTANT: Generate exactly 6 questions with the specified distribution.
        """

        do {
            // Step 1: Fetch notes using tool
            let fetchResult = try await toolRegistry.execute(
                toolName: "fetch_notes",
                parameters: ["query": topic]
            )

            guard fetchResult.success, !fetchResult.data.isEmpty else {
                error = "No notes found for topic '\(topic)'. Please add study materials first."
                log.error("No notes found for topic: \(topic)")
                return
            }

            log.info("Fetched notes for quiz: \(fetchResult.data.prefix(100))...")

            // Step 2: Generate quiz using guided generation
            let prompt = """
            Topic: \(topic)

            Available study materials:
            \(fetchResult.data)

            Generate a 6-question quiz following these requirements:
            - 3 multiple choice questions (MCQ) with 1 correct answer and 3 distractors
            - 2 cloze deletion questions (fill in the blank)
            - 1 short answer question requiring explanation

            Ensure difficulty spread from 2-5 and include explanations for each answer.
            """

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.4 // Focused for quiz accuracy
            )

            let quiz = try await sessionManager.singleTurnRequest(
                prompt: prompt,
                instructions: instructions,
                generating: QuizBatch.self,
                options: options
            )

            // Validate quiz structure
            guard quiz.items.count == 6 else {
                log.warning("Generated quiz has \(quiz.items.count) items instead of 6")
            }

            currentQuiz = quiz
            log.info("Quiz generated successfully with \(quiz.items.count) questions")

        } catch let safetyError as SafetyError {
            error = safetyError.errorDescription
            log.error("Quiz generation failed: \(safetyError.localizedDescription)")

        } catch {
            error = "Failed to generate quiz: \(error.localizedDescription)"
            log.error("Quiz generation error: \(error.localizedDescription)")
        }
    }

    /// Clear current quiz
    func clearQuiz() {
        currentQuiz = nil
        error = nil
    }

    // MARK: - Helper Methods

    private func loadPrompt(named name: String) -> String? {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "md",
            subdirectory: "Intelligence/Prompts"
        ) else {
            log.warning("Prompt file not found: \(name).md")
            return nil
        }

        return try? String(contentsOf: url, encoding: .utf8)
    }
}

// MARK: - Quiz Taking View Model

@MainActor
final class QuizSessionViewModel: ObservableObject {
    @Published var currentQuestionIndex = 0
    @Published var userAnswers: [String] = []
    @Published var showingExplanation = false
    @Published var isComplete = false
    @Published var score = 0

    private let quiz: QuizBatch

    init(quiz: QuizBatch) {
        self.quiz = quiz
        self.userAnswers = Array(repeating: "", count: quiz.items.count)
    }

    var currentQuestion: QuizItem {
        quiz.items[currentQuestionIndex]
    }

    var progress: Double {
        Double(currentQuestionIndex + 1) / Double(quiz.items.count)
    }

    func submitAnswer(_ answer: String) {
        userAnswers[currentQuestionIndex] = answer

        // Check if correct
        if answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ==
            currentQuestion.correctAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
            score += 1
        }

        showingExplanation = true
    }

    func nextQuestion() {
        showingExplanation = false

        if currentQuestionIndex < quiz.items.count - 1 {
            currentQuestionIndex += 1
        } else {
            isComplete = true
        }
    }

    var accuracyPercentage: Int {
        quiz.items.isEmpty ? 0 : Int((Double(score) / Double(quiz.items.count)) * 100)
    }
}
