//
//  StudyPlanGenerator.swift
//  CardGenie
//
//  AI-powered study plan generation with calendar integration.
//

import Foundation
import SwiftData
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Study Plan Generator

@available(iOS 26.0, *)
@MainActor
final class StudyPlanGenerator: ObservableObject {
    private let log = Logger(subsystem: "com.cardgenie.app", category: "StudyPlanGenerator")

    @Published private(set) var isGenerating = false
    @Published private(set) var currentPlan: StudyPlan?
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
                generating: StudyPlan.self,
                options: options
            )

            // Validate plan structure
            guard plan.sessions.count == 7 else {
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
            error = safetyError.errorDescription
            log.error("Study plan generation failed: \(safetyError.localizedDescription)")

        } catch {
            error = "Failed to generate study plan: \(error.localizedDescription)"
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

    private let plan: StudyPlan

    init(plan: StudyPlan) {
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
    let session: StudySession
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
