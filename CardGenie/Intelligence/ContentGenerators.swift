//
//  ContentGenerators.swift
//  CardGenie
//
//  Content generation: quizzes, study plans, and auto-categorization.
//

import Foundation
import SwiftData
import Combine
import OSLog
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - QuizBuilder

// MARK: - Quiz Builder

@available(iOS 26.0, *)
@MainActor
final class QuizBuilder: ObservableObject {
    private let log = Logger(subsystem: "com.cardgenie.app", category: "QuizBuilder")

    @Published private(set) var isGenerating = false
    @Published private(set) var currentQuiz: QuizBatch?
    @Published private(set) var errorMessage: String?

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
        errorMessage = nil
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
                errorMessage = "No notes found for topic '\(topic)'. Please add study materials first."
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
            if quiz.items.count != 6 {
                log.warning("Generated quiz has \(quiz.items.count) items instead of 6")
            }

            currentQuiz = quiz
            log.info("Quiz generated successfully with \(quiz.items.count) questions")

        } catch let safetyError as SafetyError {
            self.errorMessage = safetyError.errorDescription
            log.error("Quiz generation failed: \(safetyError.localizedDescription)")

        } catch {
            self.errorMessage = "Failed to generate quiz: \(error.localizedDescription)"
            log.error("Quiz generation error: \(error.localizedDescription)")
        }
    }

    /// Clear current quiz
    func clearQuiz() {
        currentQuiz = nil
        errorMessage = nil
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

// MARK: - StudyPlanGenerator

#if canImport(FoundationModels)
#endif

// MARK: - Study Plan Generator

@available(iOS 26.0, *)
@MainActor
final class StudyPlanGenerator: ObservableObject {
    private let log = Logger(subsystem: "com.cardgenie.app", category: "StudyPlanGenerator")

    @Published private(set) var isGenerating = false
    @Published private(set) var currentPlan: GeneratedStudyPlan?
    @Published private(set) var error: String?

    private let sessionManager = EnhancedSessionManager()
    private let toolRegistry: ToolRegistry
    private let modelContext: ModelContext

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.toolRegistry = ToolRegistry(modelContext: modelContext)
    }

    // MARK: - Plan Generation

    /// Generate a 7-day study plan for a course
    func generatePlan(course: String) async {
        guard !isGenerating else {
            log.warning("Study plan generation already in progress")
            return
        }

        isGenerating = true
        error = nil
        defer { isGenerating = false }

        log.info("Starting study plan generation for course: \(course)")

        // Load system prompt
        let systemPrompt = loadPrompt(named: "StudyPlan") ?? """
        Propose a 7-day study plan incorporating upcoming deadlines and student materials.
        Use tools to gather deadlines and fetch study content.
        Allocate 30-45 minutes per daily session with clear goals.
        """

        let instructions = """
        \(systemPrompt)

        Available tools:
        - upcoming_deadlines(): Get calendar events and due dates
        - fetch_notes(query: String): Retrieve study materials for the course

        IMPORTANT: Generate exactly 7 daily sessions with realistic time estimates.
        """

        do {
            // Step 1: Fetch upcoming deadlines
            let deadlinesResult = try await toolRegistry.execute(
                toolName: "upcoming_deadlines",
                parameters: [:]
            )

            let deadlinesInfo = deadlinesResult.success ? deadlinesResult.data : "No upcoming deadlines found."
            log.info("Deadlines: \(deadlinesInfo.prefix(100))...")

            // Step 2: Fetch course notes
            let notesResult = try await toolRegistry.execute(
                toolName: "fetch_notes",
                parameters: ["query": course]
            )

            let notesInfo = notesResult.success ? notesResult.data : "No notes found for this course."
            log.info("Notes: \(notesInfo.prefix(100))...")

            // Step 3: Generate study plan
            let today = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let startDate = formatter.string(from: today)

            let prompt = """
            Course: \(course)
            Today's Date: \(startDate)

            Upcoming Deadlines:
            \(deadlinesInfo)

            Available Study Materials:
            \(notesInfo)

            Generate a 7-day study plan starting from \(startDate). Each session should:
            - Have a clear, specific learning goal
            - Reference 2-4 concrete materials from the available content
            - Estimate realistic time (30-45 minutes recommended)
            - Progress logically from foundational to advanced topics
            - Prioritize material with approaching deadlines

            Use ISO 8601 date format (YYYY-MM-DD) for all dates.
            """

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.5 // Balanced for planning
            )

            let plan = try await sessionManager.singleTurnRequest(
                prompt: prompt,
                instructions: instructions,
                generating: GeneratedStudyPlan.self,
                options: options
            )

            // Validate plan structure
            if plan.sessions.count != 7 {
                log.warning("Generated plan has \(plan.sessions.count) sessions instead of 7")
            }

            // Validate date progression
            for (index, session) in plan.sessions.enumerated() {
                if let sessionDate = parseDate(session.date) {
                    let expectedDate = Calendar.current.date(
                        byAdding: .day,
                        value: index,
                        to: today
                    )
                    if let expected = expectedDate,
                       !Calendar.current.isDate(sessionDate, inSameDayAs: expected) {
                        log.warning("Session \(index) date mismatch: \(session.date)")
                    }
                } else {
                    log.error("Invalid date format in session \(index): \(session.date)")
                }
            }

            currentPlan = plan
            log.info("Study plan generated successfully with \(plan.sessions.count) sessions")

        } catch let safetyError as SafetyError {
            self.error = safetyError.errorDescription
            log.error("Study plan generation failed: \(safetyError.localizedDescription)")

        } catch {
            self.error = "Failed to generate study plan: \(error.localizedDescription)"
            log.error("Study plan generation error: \(error.localizedDescription)")
        }
    }

    /// Clear current plan
    func clearPlan() {
        currentPlan = nil
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

    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}

// MARK: - Study Plan Tracking

@MainActor
final class StudyPlanTracker: ObservableObject {
    @Published var completedSessions: Set<String> = []
    @Published var sessionNotes: [String: String] = [:]

    private let plan: GeneratedStudyPlan

    init(plan: GeneratedStudyPlan) {
        self.plan = plan
    }

    func markSessionComplete(_ date: String) {
        completedSessions.insert(date)
    }

    func isSessionComplete(_ date: String) -> Bool {
        completedSessions.contains(date)
    }

    func addNote(for date: String, note: String) {
        sessionNotes[date] = note
    }

    var progress: Double {
        Double(completedSessions.count) / Double(plan.sessions.count)
    }

    var completedCount: Int {
        completedSessions.count
    }

    var totalSessions: Int {
        plan.sessions.count
    }
}

// MARK: - Session Reminder

struct StudySessionReminder {
    let session: GeneratedStudySession
    let course: String

    var title: String {
        "Study Session: \(course)"
    }

    var body: String {
        """
        Goal: \(session.goal)
        Time: \(session.estimatedMinutes) minutes
        Materials: \(session.materials.joined(separator: ", "))
        """
    }

    var identifier: String {
        "study_session_\(session.date)"
    }
}

// MARK: - AutoCategorizer

/// Automatic content categorization using AI
final class AutoCategorizer: ObservableObject {
    private let fmClient = FMClient()

    // MARK: - Predefined Categories

    static let commonCategories = [
        "Science", "Math", "History", "Language", "Literature",
        "Computer Science", "Business", "Medicine", "Engineering",
        "Art", "Music", "Philosophy", "Psychology", "General"
    ]

    // MARK: - Auto-Categorize

    /// Automatically categorize content based on its text
    func categorize(_ content: StudyContent) async throws -> String {
        // Check AI availability
        guard fmClient.capability() == .available else {
            return fallbackCategory(for: content)
        }

        // Use existing tags as hint if available
        let hint = content.tags.isEmpty ? "" : "Existing tags: \(content.tags.joined(separator: ", "))"

        let prompt = """
        Analyze the following study content and categorize it into ONE of these categories:
        \(Self.commonCategories.joined(separator: ", "))

        Content:
        \(content.displayText.prefix(500))

        \(hint)

        Respond with ONLY the category name, nothing else.
        """

        do {
            let category = try await fmClient.customPrompt(prompt)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Validate against common categories
            if Self.commonCategories.contains(where: { $0.localizedCaseInsensitiveCompare(category) == .orderedSame }) {
                return category
            }

            return fallbackCategory(for: content)

        } catch {
            return fallbackCategory(for: content)
        }
    }

    /// Batch categorize multiple content items
    func categorizeBatch(_ contents: [StudyContent]) async -> [UUID: String] {
        var results: [UUID: String] = [:]

        for content in contents {
            if let category = try? await categorize(content) {
                results[content.id] = category
            }
        }

        return results
    }

    // MARK: - Smart Suggestions

    /// Suggest category based on tags and existing patterns
    func suggestCategory(for content: StudyContent, basedOn allContent: [StudyContent]) -> String? {
        // If content has tags, find similar content
        guard !content.tags.isEmpty else { return nil }

        let contentTagSet = Set(content.tags)

        // Find content with similar tags
        let similar = allContent.filter { other in
            !other.tags.isEmpty &&
            !contentTagSet.intersection(other.tags).isEmpty &&
            other.topic != nil
        }

        // Get most common category among similar content
        let categories = similar.compactMap { $0.topic }
        let grouped = Dictionary(grouping: categories, by: { $0 })
        let mostCommon = grouped.max(by: { $0.value.count < $1.value.count })

        return mostCommon?.key
    }

    // MARK: - Fallback

    /// Simple keyword-based fallback categorization
    private func fallbackCategory(for content: StudyContent) -> String {
        let text = content.displayText.lowercased()

        // Keyword patterns for common categories
        let patterns: [(String, [String])] = [
            ("Science", ["science", "biology", "chemistry", "physics", "experiment", "theory", "hypothesis"]),
            ("Math", ["math", "equation", "calculate", "algebra", "geometry", "theorem", "proof"]),
            ("History", ["history", "war", "century", "ancient", "civilization", "revolution", "empire"]),
            ("Language", ["language", "grammar", "vocabulary", "verb", "noun", "sentence", "pronunciation"]),
            ("Literature", ["literature", "novel", "poem", "author", "character", "plot", "story"]),
            ("Computer Science", ["code", "programming", "algorithm", "computer", "software", "function", "data"]),
            ("Business", ["business", "marketing", "finance", "management", "strategy", "customer", "revenue"]),
            ("Medicine", ["medical", "health", "disease", "treatment", "patient", "diagnosis", "symptom"]),
            ("Engineering", ["engineering", "design", "circuit", "mechanical", "structure", "system", "build"]),
            ("Art", ["art", "painting", "sculpture", "artist", "canvas", "museum", "exhibition"]),
            ("Music", ["music", "song", "instrument", "melody", "rhythm", "composer", "harmony"]),
            ("Philosophy", ["philosophy", "ethics", "logic", "existence", "knowledge", "moral", "truth"]),
            ("Psychology", ["psychology", "behavior", "mind", "emotion", "cognitive", "therapy", "mental"])
        ]

        // Check tags first
        if !content.tags.isEmpty {
            for (category, keywords) in patterns {
                if content.tags.contains(where: { tag in
                    keywords.contains(where: { tag.localizedCaseInsensitiveContains($0) })
                }) {
                    return category
                }
            }
        }

        // Check content text
        for (category, keywords) in patterns {
            let matches = keywords.filter { text.contains($0) }.count
            if matches >= 2 {
                return category
            }
        }

        return "General"
    }
}

// MARK: - FMClient Extension

extension FMClient {
    /// Custom prompt execution
    func customPrompt(_ prompt: String) async throws -> String {
        // Use the reflection method as a proxy for custom prompts
        return try await reflection(for: prompt)
    }
}
