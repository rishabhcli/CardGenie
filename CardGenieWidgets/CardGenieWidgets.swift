//
//  CardGenieWidgets.swift
//  CardGenieWidgets
//
//  Widget bundle and widget implementations for CardGenie
//

import WidgetKit
import SwiftUI
import SwiftData
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Widget Bundle

@main
struct CardGenieWidgets: WidgetBundle {
    var body: some Widget {
        DueCardsWidget()
        StudyStreakWidget()
    }
}

// MARK: - Live Activity (iOS 16.2+)

#if canImport(ActivityKit)
import AppIntents

@available(iOS 16.2, *)
struct LectureHighlightAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentTimestamp: TimeInterval
        var latestHighlight: String?
        var highlightCount: Int
        var isRecording: Bool
    }
    
    var lectureTitle: String
    var startTime: Date
}

@available(iOS 16.2, *)
struct LectureHighlightLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LectureHighlightAttributes.self) { context in
            // Lock screen/banner UI
            LectureHighlightLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.lectureTitle, systemImage: "waveform")
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatDuration(context.state.currentTimestamp))
                        .font(.caption.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let highlight = context.state.latestHighlight {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text("Latest Highlight")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(highlight)
                                .font(.caption)
                                .lineLimit(2)
                        }
                        .padding(.top, 4)
                    } else {
                        Text("No highlights yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isRecording ? "record.circle.fill" : "record.circle")
                    .foregroundStyle(.red)
            } compactTrailing: {
                Text(formatDuration(context.state.currentTimestamp))
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "waveform")
                    .foregroundStyle(.red)
            }
        }
    }
}

@available(iOS 16.2, *)
struct LectureHighlightLockScreenView: View {
    let context: ActivityViewContext<LectureHighlightAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: context.state.isRecording ? "record.circle.fill" : "record.circle")
                    .foregroundStyle(.red)
                
                Text(context.attributes.lectureTitle)
                    .font(.headline)
                
                Spacer()
                
                Text(formatDuration(context.state.currentTimestamp))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            
            if let highlight = context.state.latestHighlight {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Latest Highlight (\(context.state.highlightCount))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Text(highlight)
                            .font(.caption)
                            .lineLimit(2)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "star")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    
                    Text("No highlights yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.3))
    }
}

private func formatDuration(_ seconds: TimeInterval) -> String {
    let hours = Int(seconds) / 3600
    let minutes = Int(seconds) / 60 % 60
    let secs = Int(seconds) % 60
    
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    } else {
        return String(format: "%d:%02d", minutes, secs)
    }
}
#endif

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

            let now = Date.now

            let descriptor = FetchDescriptor<Flashcard>(
                predicate: #Predicate { flashcard in
                    flashcard.nextReviewDate <= now
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
                .compactMap { $0.lastReviewed }
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
            allowsSave: true
        )

        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
}
