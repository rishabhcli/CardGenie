//
//  ProcessorUtilities.swift
//  CardGenie
//
//  Utility processors: CSV import and smart scheduling.
//

import Foundation
import SwiftData

// MARK: - CSVImporter

// MARK: - CSV Importer

final class CSVImporter {
    private let llm: LLMEngine

    init(llm: LLMEngine = AIEngineFactory.createLLMEngine()) {
        self.llm = llm
    }

    // MARK: - Import CSV

    /// Import CSV file as flashcards
    /// Supports formats: "Question,Answer" or "Front,Back,Tags"
    func importCSV(from url: URL, context: ModelContext) async throws -> FlashcardSet {
        let content = try String(contentsOf: url, encoding: .utf8)
        let rows = parseCSV(content)

        guard !rows.isEmpty else {
            throw CSVError.emptyFile
        }

        // Detect format
        let header = rows.first ?? []
        let hasHeader = detectHeader(header)

        let dataRows = hasHeader ? Array(rows.dropFirst()) : rows

        // Create deck
        let fileName = url.deletingPathExtension().lastPathComponent
        let deck = FlashcardSet(topicLabel: fileName, tag: "imported")
        context.insert(deck)

        // Process each row
        for row in dataRows {
            guard row.count >= 2 else { continue }

            let question = row[0].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let answer = row[1].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            guard !question.isEmpty && !answer.isEmpty else { continue }

            // Extract tags if present
            var tags: [String] = []
            if row.count >= 3 {
                let tagString = row[2].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                tags = tagString.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
                    .filter { !$0.isEmpty }
            }

            // Create flashcard
            let card = Flashcard(
                type: .qa,
                question: question,
                answer: answer,
                linkedEntryID: UUID(),
                tags: tags
            )

            deck.addCard(card)
            context.insert(card)
        }

        return deck
    }

    // MARK: - CSV Parsing

    private func parseCSV(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        for char in content {
            switch char {
            case "\"":
                if inQuotes && currentField.last == "\"" {
                    // Escaped quote
                    currentField.removeLast()
                    currentField.append("\"")
                } else {
                    inQuotes.toggle()
                }

            case ",":
                if inQuotes {
                    currentField.append(char)
                } else {
                    currentRow.append(currentField)
                    currentField = ""
                }

            case "\n", "\r":
                if inQuotes {
                    currentField.append(char)
                } else {
                    if !currentField.isEmpty || !currentRow.isEmpty {
                        currentRow.append(currentField)
                        rows.append(currentRow)
                        currentRow = []
                        currentField = ""
                    }
                }

            default:
                currentField.append(char)
            }
        }

        // Add final field/row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows.filter { !$0.isEmpty }
    }

    private func detectHeader(_ row: [String]) -> Bool {
        guard !row.isEmpty else { return false }

        let firstCell = row[0].lowercased()

        // Common header patterns
        let headerKeywords = [
            "question", "front", "term", "prompt",
            "answer", "back", "definition", "response"
        ]

        return headerKeywords.contains { firstCell.contains($0) }
    }

    // MARK: - Batch Card Generation from CSV

    /// Import CSV data (notes/facts) and generate flashcards using AI
    func importAndGenerate(from url: URL, context: ModelContext) async throws -> FlashcardSet {
        let content = try String(contentsOf: url, encoding: .utf8)
        let rows = parseCSV(content)

        guard !rows.isEmpty else {
            throw CSVError.emptyFile
        }

        let fileName = url.deletingPathExtension().lastPathComponent
        let deck = FlashcardSet(topicLabel: fileName, tag: "csv-generated")
        context.insert(deck)

        // Skip header if present
        let hasHeader = detectHeader(rows.first ?? [])
        let dataRows = hasHeader ? Array(rows.dropFirst()) : rows

        // Generate cards from each row
        for row in dataRows {
            let text = row.joined(separator: " - ")
            guard !text.isEmpty else { continue }

            // Generate Q&A card from text
            if let cards = try? await generateCardsFromText(text) {
                for card in cards {
                    deck.addCard(card)
                    context.insert(card)
                }
            }
        }

        return deck
    }

    private func generateCardsFromText(_ text: String) async throws -> [Flashcard] {
        let prompt = """
        Create 1 question-answer flashcard from this fact/note.

        TEXT: \(text)

        FORMAT:
        Q: [question]
        A: [answer]

        CARD:
        """

        let response = try await llm.complete(prompt)

        // Parse response
        var question: String?
        var answer: String?

        for line in response.components(separatedBy: CharacterSet.newlines) {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)

            if trimmed.hasPrefix("Q:") {
                question = trimmed.replacingOccurrences(of: "Q:", with: "")
                    .trimmingCharacters(in: CharacterSet.whitespaces)
            } else if trimmed.hasPrefix("A:"), let q = question {
                answer = trimmed.replacingOccurrences(of: "A:", with: "")
                    .trimmingCharacters(in: CharacterSet.whitespaces)

                let card = Flashcard(
                    type: .qa,
                    question: q,
                    answer: answer!,
                    linkedEntryID: UUID()
                )
                return [card]
            }
        }

        return []
    }
}

// MARK: - Errors

enum CSVError: LocalizedError {
    case emptyFile
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .emptyFile: return "CSV file is empty"
        case .invalidFormat: return "Invalid CSV format"
        }
    }
}

// MARK: - SmartScheduler


// MARK: - Smart Scheduler

final class SmartScheduler {
    private let llm: LLMEngine
    private let modelContext: ModelContext

    init(llm: LLMEngine = AIEngineFactory.createLLMEngine(), modelContext: ModelContext) {
        self.llm = llm
        self.modelContext = modelContext
    }

    // MARK: - Generate Study Plan

    /// Generate a comprehensive study plan for an upcoming exam
    func generateStudyPlan(
        title: String,
        examDate: Date,
        flashcardSetIDs: [UUID],
        targetMastery: Double = 85.0,
        preferredTimes: [StudyTimePreference] = []
    ) async throws -> StudyPlan {
        // Fetch flashcard sets
        let sets = try fetchFlashcardSets(ids: flashcardSetIDs)

        // Calculate current mastery
        let currentMastery = calculateMastery(for: sets)

        // Calculate available days
        let daysUntilExam = Calendar.current.dateComponents(
            [.day],
            from: Date(),
            to: examDate
        ).day ?? 1

        // Analyze card distribution
        let analytics = analyzeCards(sets)

        // Generate optimal sessions using AI
        let sessions = try await generateSessions(
            sets: sets,
            daysAvailable: daysUntilExam,
            currentMastery: currentMastery,
            targetMastery: targetMastery,
            analytics: analytics,
            preferredTimes: preferredTimes
        )

        // Create study plan
        let plan = StudyPlan(
            title: title,
            targetDate: examDate,
            flashcardSetIDs: flashcardSetIDs
        )
        plan.currentMastery = currentMastery
        plan.targetMastery = targetMastery
        plan.sessions = sessions

        // Link sessions to plan
        for session in sessions {
            session.studyPlan = plan
        }

        modelContext.insert(plan)
        try modelContext.save()

        return plan
    }

    // MARK: - Adaptive Recalculation

    /// Recalculate plan based on actual progress
    func recalculatePlan(_ plan: StudyPlan) async throws {
        // Fetch current flashcard sets
        let sets = try fetchFlashcardSets(ids: plan.flashcardSetIDs)

        // Recalculate current mastery
        plan.currentMastery = calculateMastery(for: sets)

        // Get remaining sessions
        let remainingSessions = plan.sessions.filter { !$0.isCompleted }

        // Calculate days until exam
        let daysUntilExam = Calendar.current.dateComponents(
            [.day],
            from: Date(),
            to: plan.targetDate
        ).day ?? 1

        // If mastery is on track, keep plan
        if plan.currentMastery >= plan.targetMastery * 0.9 {
            // Just redistribute remaining sessions
            redistributeSessions(remainingSessions, daysAvailable: daysUntilExam)
        } else {
            // Need to intensify - generate new sessions
            let analytics = analyzeCards(sets)
            let newSessions = try await generateIntensiveSessions(
                sets: sets,
                daysAvailable: daysUntilExam,
                currentMastery: plan.currentMastery,
                targetMastery: plan.targetMastery,
                analytics: analytics
            )

            // Remove old incomplete sessions
            for session in remainingSessions {
                modelContext.delete(session)
            }

            // Add new sessions
            plan.sessions.append(contentsOf: newSessions)
            for session in newSessions {
                session.studyPlan = plan
            }
        }

        plan.lastRecalculated = Date()
        try modelContext.save()
    }

    // MARK: - Session Generation

    private func generateSessions(
        sets: [FlashcardSet],
        daysAvailable: Int,
        currentMastery: Double,
        targetMastery: Double,
        analytics: CardAnalytics,
        preferredTimes: [StudyTimePreference]
    ) async throws -> [StudySession] {
        var sessions: [StudySession] = []

        // Calculate total study time needed
        let totalCards = analytics.totalCards
        let newCards = analytics.newCount
        let weakCards = analytics.weakCount

        // Estimate: 5 min per new card, 2 min per review
        let estimatedMinutes = (newCards * 5) + ((totalCards - newCards) * 2)
        let sessionsNeeded = max(daysAvailable, estimatedMinutes / 30) // 30 min sessions

        // Generate sessions with AI
        let prompt = """
        Create a study schedule for an exam in \(daysAvailable) days.

        CURRENT STATUS:
        - Total cards: \(totalCards)
        - New cards (not studied): \(newCards)
        - Weak cards (success rate < 60%): \(weakCards)
        - Current mastery: \(Int(currentMastery))%
        - Target mastery: \(Int(targetMastery))%

        AVAILABLE TIME:
        - \(daysAvailable) days until exam
        - Estimate \(estimatedMinutes) minutes total needed

        Generate \(min(sessionsNeeded, daysAvailable * 2)) study sessions.
        For each session specify:
        1. Day offset (0 = today, 1 = tomorrow, etc.)
        2. Time (morning/afternoon/evening)
        3. Duration (15-60 minutes)
        4. Focus (new/review/weak/mixed)

        FORMAT (one per line):
        Day X | Morning/Afternoon/Evening | 30 min | New Cards
        """

        let response = try await llm.complete(prompt)

        // Parse AI response
        let lines = response.components(separatedBy: CharacterSet.newlines)
        var currentDay = 0

        for line in lines {
            guard !line.isEmpty,
                  line.contains("|") else { continue }

            let parts = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
            guard parts.count >= 4 else { continue }

            // Parse day offset
            if let dayMatch = parts[0].firstMatch(of: /\d+/),
               let day = Int(dayMatch.output) {
                currentDay = day
            }

            // Parse time
            let timeOfDay = parts[1].lowercased()
            var hour = 14 // Default afternoon
            if timeOfDay.contains("morning") {
                hour = 9
            } else if timeOfDay.contains("evening") {
                hour = 19
            }

            // Parse duration
            var duration = 30
            if let durationMatch = parts[2].firstMatch(of: /\d+/),
               let mins = Int(durationMatch.output) {
                duration = mins
            }

            // Parse type
            let focusText = parts[3].lowercased()
            let sessionType: StudySession.SessionType
            if focusText.contains("new") {
                sessionType = .newCards
            } else if focusText.contains("weak") {
                sessionType = .weakCards
            } else if focusText.contains("review") {
                sessionType = .review
            } else {
                sessionType = .mixed
            }

            // Calculate scheduled time
            let scheduledTime = Calendar.current.date(
                byAdding: .day,
                value: currentDay,
                to: Calendar.current.date(
                    bySettingHour: hour,
                    minute: 0,
                    second: 0,
                    of: Date()
                )!
            )!

            // Create session
            let session = StudySession(
                scheduledTime: scheduledTime,
                duration: duration,
                topic: sets.map { $0.topicLabel }.joined(separator: ", "),
                flashcardSetIDs: sets.map { $0.id },
                type: sessionType
            )

            sessions.append(session)
        }

        // If AI parsing failed, generate default schedule
        if sessions.isEmpty {
            sessions = generateDefaultSchedule(
                sets: sets,
                daysAvailable: daysAvailable,
                analytics: analytics
            )
        }

        return sessions
    }

    private func generateIntensiveSessions(
        sets: [FlashcardSet],
        daysAvailable: Int,
        currentMastery: Double,
        targetMastery: Double,
        analytics: CardAnalytics
    ) async throws -> [StudySession] {
        // Generate more frequent, shorter sessions for cramming
        var sessions: [StudySession] = []

        let sessionsPerDay = min(3, max(1, daysAvailable / 2))

        for day in 0..<daysAvailable {
            for sessionIndex in 0..<sessionsPerDay {
                let hour = 9 + (sessionIndex * 4) // 9am, 1pm, 5pm
                let scheduledTime = Calendar.current.date(
                    byAdding: .day,
                    value: day,
                    to: Calendar.current.date(
                        bySettingHour: hour,
                        minute: 0,
                        second: 0,
                        of: Date()
                    )!
                )!

                let type: StudySession.SessionType = day < daysAvailable / 2 ? .newCards : .cramming

                let session = StudySession(
                    scheduledTime: scheduledTime,
                    duration: 20, // Shorter intensive sessions
                    topic: sets.map { $0.topicLabel }.joined(separator: ", "),
                    flashcardSetIDs: sets.map { $0.id },
                    type: type
                )

                sessions.append(session)
            }
        }

        return sessions
    }

    private func generateDefaultSchedule(
        sets: [FlashcardSet],
        daysAvailable: Int,
        analytics: CardAnalytics
    ) -> [StudySession] {
        var sessions: [StudySession] = []

        // Simple default: one session per day
        for day in 0..<daysAvailable {
            let scheduledTime = Calendar.current.date(
                byAdding: .day,
                value: day,
                to: Calendar.current.date(
                    bySettingHour: 14,
                    minute: 0,
                    second: 0,
                    of: Date()
                )!
            )!

            let type: StudySession.SessionType
            if day == 0 {
                type = .newCards
            } else if day < daysAvailable - 2 {
                type = .mixed
            } else {
                type = .review
            }

            let session = StudySession(
                scheduledTime: scheduledTime,
                duration: 30,
                topic: sets.map { $0.topicLabel }.joined(separator: ", "),
                flashcardSetIDs: sets.map { $0.id },
                type: type
            )

            sessions.append(session)
        }

        return sessions
    }

    private func redistributeSessions(_ sessions: [StudySession], daysAvailable: Int) {
        // Evenly space remaining sessions
        let sessionCount = sessions.count
        guard sessionCount > 0, daysAvailable > 0 else { return }

        let interval = max(1, daysAvailable / sessionCount)

        for (index, session) in sessions.enumerated() {
            let dayOffset = index * interval
            if let newTime = Calendar.current.date(
                byAdding: .day,
                value: dayOffset,
                to: Date()
            ) {
                session.scheduledTime = newTime
            }
        }
    }

    // MARK: - Analytics

    private func calculateMastery(for sets: [FlashcardSet]) -> Double {
        guard !sets.isEmpty else { return 0 }

        var totalCards = 0
        var masteredCards = 0

        for set in sets {
            for card in set.cards {
                totalCards += 1
                // Card is "mastered" if reviewed 5+ times with good ease
                if card.reviewCount >= 5 && card.easeFactor >= 2.5 {
                    masteredCards += 1
                }
            }
        }

        guard totalCards > 0 else { return 0 }
        return (Double(masteredCards) / Double(totalCards)) * 100.0
    }

    private func analyzeCards(_ sets: [FlashcardSet]) -> CardAnalytics {
        var totalCards = 0
        var newCount = 0
        var weakCount = 0
        var dueCount = 0

        for set in sets {
            totalCards += set.cards.count

            for card in set.cards {
                if card.isNew {
                    newCount += 1
                }
                if card.isDue {
                    dueCount += 1
                }
                if card.successRate < 0.6 && !card.isNew {
                    weakCount += 1
                }
            }
        }

        return CardAnalytics(
            totalCards: totalCards,
            newCount: newCount,
            dueCount: dueCount,
            weakCount: weakCount
        )
    }

    // MARK: - Helpers

    private func fetchFlashcardSets(ids: [UUID]) throws -> [FlashcardSet] {
        let descriptor = FetchDescriptor<FlashcardSet>(
            predicate: #Predicate { set in
                ids.contains(set.id)
            }
        )
        return try modelContext.fetch(descriptor)
    }
}

// MARK: - Supporting Types

struct CardAnalytics {
    let totalCards: Int
    let newCount: Int
    let dueCount: Int
    let weakCount: Int
}

struct StudyTimePreference {
    let timeOfDay: TimeOfDay
    let daysOfWeek: [Int] // 1 = Sunday, 7 = Saturday

    enum TimeOfDay {
        case morning // 6-12
        case afternoon // 12-18
        case evening // 18-24
    }
}
