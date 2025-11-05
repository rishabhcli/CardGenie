//
//  CardGenieWidgets.swift
//  CardGenieWidgets
//
//  Widget bundle and widget implementations for CardGenie
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Widget Bundle

@main
struct CardGenieWidgets: WidgetBundle {
    var body: some Widget {
        DueCardsWidget()
        StudyStreakWidget()
    }
}

// MARK: - Shared Data Provider

/// Provides data for widgets from the SwiftData store
actor WidgetDataProvider {
    static let shared = WidgetDataProvider()

    private init() {}

    /// Get count of due flashcards
    func getDueCardsCount() async -> Int {
        do {
            let container = try await getModelContainer()
            let context = ModelContext(container)

            let descriptor = FetchDescriptor<Flashcard>(
                predicate: #Predicate { flashcard in
                    flashcard.nextReviewDate <= Date()
                }
            )

            let results = try context.fetch(descriptor)
            return results.count
        } catch {
            print("Widget: Failed to fetch due cards: \(error)")
            return 0
        }
    }

    /// Get study streak data
    func getStudyStreak() async -> (currentStreak: Int, lastStudyDate: Date?) {
        do {
            let container = try await getModelContainer()
            let context = ModelContext(container)

            // Fetch all flashcards to calculate streak
            let descriptor = FetchDescriptor<Flashcard>()
            let flashcards = try context.fetch(descriptor)

            // Calculate streak from last review dates
            let sortedDates = flashcards
                .compactMap { $0.lastReviewDate }
                .sorted(by: >)

            guard let mostRecent = sortedDates.first else {
                return (0, nil)
            }

            var streak = 1
            var currentDate = Calendar.current.startOfDay(for: mostRecent)

            for date in sortedDates.dropFirst() {
                let dayStart = Calendar.current.startOfDay(for: date)
                let daysBetween = Calendar.current.dateComponents([.day], from: dayStart, to: currentDate).day ?? 0

                if daysBetween == 1 {
                    streak += 1
                    currentDate = dayStart
                } else if daysBetween > 1 {
                    break
                }
            }

            return (streak, mostRecent)
        } catch {
            print("Widget: Failed to fetch study streak: \(error)")
            return (0, nil)
        }
    }

    /// Get the shared ModelContainer
    private func getModelContainer() async throws -> ModelContainer {
        let schema = Schema([
            StudyContent.self,
            Flashcard.self,
            FlashcardSet.self,
            SourceDocument.self,
            NoteChunk.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier("group.com.cardgenie.shared")
        )

        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
}
