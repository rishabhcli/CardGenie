//
//  DueCardsWidget.swift
//  CardGenieWidgets
//
//  Widget showing count of flashcards due for review
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct DueCardsEntry: TimelineEntry {
    let date: Date
    let dueCount: Int
}

// MARK: - Timeline Provider

struct DueCardsProvider: TimelineProvider {
    func placeholder(in context: Context) -> DueCardsEntry {
        DueCardsEntry(date: Date(), dueCount: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (DueCardsEntry) -> Void) {
        let entry = DueCardsEntry(date: Date(), dueCount: 12)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<DueCardsEntry>) -> Void) {
        Task { @Sendable in
            let dueCount = await WidgetDataProvider.shared.getDueCardsCount()
            let entry = DueCardsEntry(date: Date(), dueCount: dueCount)

            // Refresh every hour
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Widget View

struct DueCardsWidgetView: View {
    var entry: DueCardsEntry

    @Environment(\.widgetFamily) var family

    private var countColor: Color {
        entry.dueCount == 0 ? .green : entry.dueCount > 20 ? .red : .purple
    }

    private var motivationalMessage: String {
        if entry.dueCount == 0 {
            return "All done!"
        } else if entry.dueCount < 5 {
            return "Almost there"
        } else if entry.dueCount < 15 {
            return "Keep going"
        } else {
            return "Time to study"
        }
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.1),
                    Color.blue.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 6) {
                // Icon with subtle glow
                Image(systemName: "brain.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 2)

                Spacer().frame(height: 2)

                // Count with dynamic color
                Text("\(entry.dueCount)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(countColor)
                    .contentTransition(.numericText())

                // Label
                Text("Cards Due")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                // Motivational message
                Text(motivationalMessage)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(URL(string: "cardgenie://flashcards/due"))
    }
}

// MARK: - Widget Configuration

struct DueCardsWidget: Widget {
    let kind: String = "DueCardsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DueCardsProvider()) { entry in
            DueCardsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Due Cards")
        .description("See how many flashcards are due for review")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    DueCardsWidget()
} timeline: {
    DueCardsEntry(date: Date(), dueCount: 0)
    DueCardsEntry(date: Date(), dueCount: 12)
    DueCardsEntry(date: Date(), dueCount: 47)
    DueCardsEntry(date: Date(), dueCount: 156)
}
