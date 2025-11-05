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

    func getTimeline(in context: Context, completion: @escaping (Timeline<DueCardsEntry>) -> Void) {
        Task {
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

    var body: some View {
        VStack(spacing: 8) {
            // Icon
            Image(systemName: "brain.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Count
            Text("\(entry.dueCount)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // Label
            Text("Cards Due")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ContainerRelativeShape()
                .fill(.regularMaterial)
        }
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
