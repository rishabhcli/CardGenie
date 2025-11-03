//
//  AITools.swift
//  CardGenie
//
//  Tool calling infrastructure for Apple Intelligence.
//  Provides safe, controlled access to app data and services.
//

import Foundation
import SwiftData
import EventKit
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Tool Protocols

/// Protocol for tools that can be called by the language model
protocol AITool {
    var name: String { get }
    var description: String { get }
    func execute(parameters: [String: Any]) async throws -> ToolResult
}

struct ToolResult {
    let success: Bool
    let data: String
    let error: String?
}

// MARK: - FetchNotes Tool

/// Fetches study content from SwiftData based on query
@available(iOS 26.0, *)
final class FetchNotesTool: AITool {
    let name = "fetch_notes"
    let description = "Search and retrieve study notes by topic, tags, or keywords"

    private let modelContext: ModelContext
    private let log = Logger(subsystem: "com.cardgenie.app", category: "AITools")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func execute(parameters: [String: Any]) async throws -> ToolResult {
        guard let query = parameters["query"] as? String else {
            return ToolResult(
                success: false,
                data: "",
                error: "Missing required parameter: query"
            )
        }

        log.info("Fetching notes with query: \(query)")

        do {
            var descriptor = FetchDescriptor<StudyContent>(
                sortBy: [SortDescriptor<StudyContent>(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 200

            let candidates = try modelContext.fetch(descriptor)

            let results = candidates.filter { content in
                matches(query, in: content.rawContent) ||
                matches(query, in: content.summary) ||
                matches(query, in: content.topic) ||
                content.tags.contains { containsCaseInsensitive($0, query) }
            }

            // Limit to top 5 most recent matches to stay within context window
            let limited = Array(results.prefix(5))

            if limited.isEmpty {
                return ToolResult(
                    success: true,
                    data: "No notes found matching '\(query)'",
                    error: nil
                )
            }

            let summaries = limited.map { content in
                let summaryText = content.summary ?? String(content.displayText.prefix(200))
                return """
                ID: \(content.id)
                Topic: \(content.topic ?? "Untitled")
                Tags: \(content.tags.joined(separator: ", "))
                Summary: \(summaryText)
                """
            }.joined(separator: "\n\n")

            log.info("Found \(limited.count) matching notes")

            return ToolResult(
                success: true,
                data: "Found \(limited.count) notes:\n\n\(summaries)",
                error: nil
            )

        } catch {
            log.error("Failed to fetch notes: \(error.localizedDescription)")
            return ToolResult(
                success: false,
                data: "",
                error: "Failed to search notes: \(error.localizedDescription)"
            )
    }
}

    private func matches(_ query: String, in text: String?) -> Bool {
        guard let text else { return false }
        return text.range(
            of: query,
            options: String.CompareOptions(arrayLiteral: .caseInsensitive, .diacriticInsensitive)
        ) != nil
    }

    private func containsCaseInsensitive(_ text: String, _ query: String) -> Bool {
        text.range(
            of: query,
            options: String.CompareOptions(arrayLiteral: .caseInsensitive, .diacriticInsensitive)
        ) != nil
    }
}

// MARK: - SaveFlashcards Tool

/// Saves generated flashcards to SwiftData
@available(iOS 26.0, *)
final class SaveFlashcardsTool: AITool {
    let name = "save_flashcards"
    let description = "Save flashcards to the database for later study"

    private let modelContext: ModelContext
    private let log = Logger(subsystem: "com.cardgenie.app", category: "AITools")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func execute(parameters: [String: Any]) async throws -> ToolResult {
        guard let flashcardsData = parameters["flashcards"] as? [[String: Any]] else {
            return ToolResult(
                success: false,
                data: "",
                error: "Missing required parameter: flashcards"
            )
        }

        log.info("Saving \(flashcardsData.count) flashcards")

        do {
            var savedCount = 0

            for cardData in flashcardsData {
                guard let question = cardData["question"] as? String,
                      let answer = cardData["answer"] as? String,
                      let typeStr = cardData["type"] as? String else {
                    continue
                }

                let type: FlashcardType
                switch typeStr.lowercased() {
                case "cloze": type = .cloze
                case "definition": type = .definition
                default: type = .qa
                }

                let tags = (cardData["tags"] as? [String]) ?? []
                let linkedID = (cardData["linkedEntryID"] as? String)
                    .flatMap { UUID(uuidString: $0) } ?? UUID()

                let flashcard = Flashcard(
                    type: type,
                    question: question,
                    answer: answer,
                    linkedEntryID: linkedID,
                    tags: tags
                )

                modelContext.insert(flashcard)
                savedCount += 1
            }

            try modelContext.save()

            log.info("Successfully saved \(savedCount) flashcards")

            return ToolResult(
                success: true,
                data: "Saved \(savedCount) flashcards successfully",
                error: nil
            )

        } catch {
            log.error("Failed to save flashcards: \(error.localizedDescription)")
            return ToolResult(
                success: false,
                data: "",
                error: "Failed to save flashcards: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - UpcomingDeadlines Tool

/// Fetches upcoming calendar events for study planning
@available(iOS 26.0, *)
final class UpcomingDeadlinesTool: AITool {
    let name = "upcoming_deadlines"
    let description = "Get upcoming calendar events and deadlines for study planning"

    private let eventStore = EKEventStore()
    private let log = Logger(subsystem: "com.cardgenie.app", category: "AITools")

    func execute(parameters: [String: Any]) async throws -> ToolResult {
        log.info("Fetching upcoming deadlines")

        // Request calendar access
        let granted = try await eventStore.requestFullAccessToEvents()

        guard granted else {
            return ToolResult(
                success: false,
                data: "",
                error: "Calendar access not granted. Please enable in Settings."
            )
        }

        // Fetch events for next 14 days
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 14, to: startDate) ?? startDate

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)

        if events.isEmpty {
            return ToolResult(
                success: true,
                data: "No upcoming events found in the next 14 days",
                error: nil
            )
        }

        // Format events for LLM
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let eventSummaries = events.prefix(10).map { event in
            let dateStr = formatter.string(from: event.startDate)
            return "• \(event.title ?? "Untitled"): \(dateStr)"
        }.joined(separator: "\n")

        log.info("Found \(events.count) upcoming events")

        return ToolResult(
            success: true,
            data: "Upcoming events (next 14 days):\n\n\(eventSummaries)",
            error: nil
        )
    }
}

// MARK: - Glossary Tool

/// Looks up terms in a local definitions database
@available(iOS 26.0, *)
final class GlossaryTool: AITool {
    let name = "glossary"
    let description = "Look up academic terms and definitions from study materials"

    private let modelContext: ModelContext
    private let log = Logger(subsystem: "com.cardgenie.app", category: "AITools")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func execute(parameters: [String: Any]) async throws -> ToolResult {
        guard let term = parameters["term"] as? String else {
            return ToolResult(
                success: false,
                data: "",
                error: "Missing required parameter: term"
            )
        }

        log.info("Looking up glossary term: \(term)")

        do {
            // Search for definition-type flashcards matching the term
            var descriptor = FetchDescriptor<Flashcard>(
                sortBy: [SortDescriptor<Flashcard>(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 50

            let flashcards = try modelContext.fetch(descriptor)
            if let match = flashcards.first(where: {
                $0.type == .definition && $0.question.localizedStandardContains(term)
            }) {
                return ToolResult(
                    success: true,
                    data: "\(match.question)\n\n\(match.answer)",
                    error: nil
                )
            }

            // Fallback: search in study content
            var contentDescriptor = FetchDescriptor<StudyContent>(
                sortBy: [SortDescriptor<StudyContent>(\.createdAt, order: .reverse)]
            )
            contentDescriptor.fetchLimit = 200

            let contentResults = try modelContext.fetch(contentDescriptor)

            if let match = contentResults.first(where: { matchesTerm(term, in: $0.displayText) }) {
                let excerpt = extractRelevantExcerpt(from: match.displayText, term: term)
                return ToolResult(
                    success: true,
                    data: "Found in notes: \(excerpt)",
                    error: nil
                )
            }

            return ToolResult(
                success: true,
                data: "Term '\(term)' not found in glossary or notes",
                error: nil
            )

        } catch {
            log.error("Failed to look up term: \(error.localizedDescription)")
            return ToolResult(
                success: false,
                data: "",
                error: "Failed to look up term: \(error.localizedDescription)"
            )
        }
    }

    private func extractRelevantExcerpt(from text: String, term: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))

        for sentence in sentences {
            if sentence.localizedStandardContains(term) {
                return sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Fallback: return first 200 chars
        return String(text.prefix(200))
    }

    private func matches(_ query: String, in text: String?) -> Bool {
        guard let text else { return false }
        return containsCaseInsensitive(text, query)
    }

    private func matchesTerm(_ term: String, in text: String) -> Bool {
        containsCaseInsensitive(text, term)
    }

    private func containsCaseInsensitive(_ text: String, _ query: String) -> Bool {
        text.range(
            of: query,
            options: String.CompareOptions(arrayLiteral: .caseInsensitive, .diacriticInsensitive)
        ) != nil
    }
}

// MARK: - Tool Registry

/// Manages available tools for the language model
@available(iOS 26.0, *)
@MainActor
final class ToolRegistry {
    private var tools: [String: AITool] = [:]
    private let log = Logger(subsystem: "com.cardgenie.app", category: "ToolRegistry")

    init(modelContext: ModelContext) {
        // Register all available tools
        register(FetchNotesTool(modelContext: modelContext))
        register(SaveFlashcardsTool(modelContext: modelContext))
        register(UpcomingDeadlinesTool())
        register(GlossaryTool(modelContext: modelContext))
    }

    private func register(_ tool: AITool) {
        tools[tool.name] = tool
        log.info("Registered tool: \(tool.name)")
    }

    func getTool(named name: String) -> AITool? {
        return tools[name]
    }

    func allTools() -> [AITool] {
        return Array(tools.values)
    }

    /// Execute a tool call from the language model
    func execute(toolName: String, parameters: [String: Any]) async throws -> ToolResult {
        guard let tool = getTool(named: toolName) else {
            log.error("Tool not found: \(toolName)")
            return ToolResult(
                success: false,
                data: "",
                error: "Tool '\(toolName)' not found"
            )
        }

        log.info("Executing tool: \(toolName)")
        return try await tool.execute(parameters: parameters)
    }
}
