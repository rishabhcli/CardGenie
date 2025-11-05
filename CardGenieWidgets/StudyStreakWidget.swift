//
//  StudyStreakWidget.swift
//  CardGenieWidgets
//
//  Widget showing current study streak
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct StudyStreakEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let lastStudyDate: Date?
}

// MARK: - Timeline Provider

struct StudyStreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudyStreakEntry {
        StudyStreakEntry(date: Date(), currentStreak: 7, lastStudyDate: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (StudyStreakEntry) -> Void) {
        let entry = StudyStreakEntry(date: Date(), currentStreak: 7, lastStudyDate: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudyStreakEntry>) -> Void) {
        Task {
            let (streak, lastDate) = await WidgetDataProvider.shared.getStudyStreak()
            let entry = StudyStreakEntry(date: Date(), currentStreak: streak, lastStudyDate: lastDate)

            // Refresh every 6 hours
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 6, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Widget View

struct StudyStreakWidgetView: View {
    var entry: StudyStreakEntry

    private var streakMessage: String {
        if entry.currentStreak == 0 {
            return "Start your streak!"
        } else if entry.currentStreak == 1 {
            return "Keep it going!"
        } else {
            return "\(entry.currentStreak) day streak!"
        }
    }

    private var isStreakActive: Bool {
        guard let lastDate = entry.lastStudyDate else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastStudy = calendar.startOfDay(for: lastDate)
        let daysDiff = calendar.dateComponents([.day], from: lastStudy, to: today).day ?? 0
        return daysDiff <= 1 // Today or yesterday
    }

    var body: some View {
        VStack(spacing: 8) {
            // Flame icon
            Image(systemName: isStreakActive ? "flame.fill" : "flame")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: isStreakActive ? [.orange, .red] : [.gray, .gray.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .symbolEffect(.pulse, isActive: isStreakActive)

            // Streak count
            Text("\(entry.currentStreak)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: isStreakActive ? [.orange, .red] : [.gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // Message
            Text(streakMessage)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ContainerRelativeShape()
                .fill(.regularMaterial)
        }
    }
}

// MARK: - Widget Configuration

struct StudyStreakWidget: Widget {
    let kind: String = "StudyStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyStreakProvider()) { entry in
            StudyStreakWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Study Streak")
        .description("Track your daily study streak")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    StudyStreakWidget()
} timeline: {
    StudyStreakEntry(date: Date(), currentStreak: 0, lastStudyDate: nil)
    StudyStreakEntry(date: Date(), currentStreak: 1, lastStudyDate: Date())
    StudyStreakEntry(date: Date(), currentStreak: 7, lastStudyDate: Date())
    StudyStreakEntry(date: Date(), currentStreak: 30, lastStudyDate: Date().addingTimeInterval(-86400 * 2))
}
