//
//  StudyStreakWidget.swift
//  CardGenieWidgets
//
//  Widget showing current study streak
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Configuration Intent

struct StudyStreakConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Study Streak Configuration"
    static var description = IntentDescription("Configure your study streak widget")
}

// MARK: - Timeline Entry

struct StudyStreakEntry: TimelineEntry {
    let date: Date
    let currentStreak: Int
    let lastStudyDate: Date?
}

// MARK: - App Intent Timeline Provider

struct StudyStreakProvider: AppIntentTimelineProvider {
    typealias Entry = StudyStreakEntry
    typealias Intent = StudyStreakConfiguration

    func placeholder(in context: Context) -> StudyStreakEntry {
        StudyStreakEntry(date: Date(), currentStreak: 7, lastStudyDate: Date())
    }

    func snapshot(for configuration: Intent, in context: Context) async -> StudyStreakEntry {
        let (streak, lastDate) = await WidgetDataProvider.shared.getStudyStreak()
        return StudyStreakEntry(date: Date(), currentStreak: streak, lastStudyDate: lastDate)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<StudyStreakEntry> {
        let (streak, lastDate) = await WidgetDataProvider.shared.getStudyStreak()
        let entry = StudyStreakEntry(date: Date(), currentStreak: streak, lastStudyDate: lastDate)

        // Refresh every 6 hours
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 6, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// MARK: - Widget View

struct StudyStreakWidgetView: View {
    var entry: StudyStreakEntry

    @Environment(\.widgetFamily) var family

    private var isStreakActive: Bool {
        guard let lastDate = entry.lastStudyDate else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastStudy = calendar.startOfDay(for: lastDate)
        let daysDiff = calendar.dateComponents([.day], from: lastStudy, to: today).day ?? 0
        return daysDiff <= 1 // Today or yesterday
    }

    private var streakTitle: String {
        if entry.currentStreak == 0 {
            return "No Streak"
        } else if entry.currentStreak == 1 {
            return "Day One"
        } else {
            return "\(entry.currentStreak) Days"
        }
    }

    private var streakMessage: String {
        if entry.currentStreak == 0 {
            return "Study to start"
        } else if entry.currentStreak < 3 {
            return "Keep going!"
        } else if entry.currentStreak < 7 {
            return "On fire!"
        } else if entry.currentStreak < 30 {
            return "Incredible!"
        } else {
            return "Legendary!"
        }
    }

    private var flameColors: [Color] {
        if !isStreakActive || entry.currentStreak == 0 {
            return [.gray.opacity(0.6), .gray.opacity(0.3)]
        } else if entry.currentStreak < 3 {
            return [.orange, .yellow]
        } else if entry.currentStreak < 7 {
            return [.orange, .red]
        } else {
            return [.red, .pink, .orange]
        }
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: isStreakActive && entry.currentStreak > 0 ? [
                    Color.orange.opacity(0.12),
                    Color.red.opacity(0.06)
                ] : [
                    Color.gray.opacity(0.05),
                    Color.gray.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 6) {
                // Flame icon with glow
                Image(systemName: isStreakActive && entry.currentStreak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: flameColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        color: isStreakActive && entry.currentStreak > 0 ? .orange.opacity(0.5) : .clear,
                        radius: 12,
                        x: 0,
                        y: 2
                    )
                    .symbolEffect(.pulse, options: .repeating, isActive: isStreakActive && entry.currentStreak > 0)

                Spacer().frame(height: 2)

                // Streak count
                Text(streakTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        isStreakActive && entry.currentStreak > 0 ?
                        AnyShapeStyle(LinearGradient(
                            colors: flameColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )) : AnyShapeStyle(.secondary)
                    )
                    .contentTransition(.numericText())

                // Label
                Text("Study Streak")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                // Motivational message
                Text(streakMessage)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(isStreakActive && entry.currentStreak > 0 ? Color.orange : Color.gray.opacity(0.6))
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(URL(string: "cardgenie://study/start"))
    }
}

// MARK: - Widget Configuration

struct StudyStreakWidget: Widget {
    let kind: String = "StudyStreakWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: StudyStreakConfiguration.self,
            provider: StudyStreakProvider()
        ) { entry in
            StudyStreakWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Study Streak")
        .description("Track your daily study streak")
        .supportedFamilies([.systemSmall, .systemMedium])
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
