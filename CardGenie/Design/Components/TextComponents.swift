//
//  TextComponents.swift
//  CardGenie
//
//  Text-based UI components (badges, tags, empty states).
//

import SwiftUI

// MARK: - Entry Row (Deprecated - use ContentRow)

/// A row displaying a journal entry in a list
/// Note: This component is deprecated. Use ContentRow for new code.
struct EntryRow: View {
    let entry: StudyContent

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Title (first line of text)
            Text(entry.firstLine)
                .font(.entryTitle)
                .foregroundStyle(Color.primaryText)
                .lineLimit(1)

            // Preview or summary
            Text(entry.preview)
                .font(.preview)
                .foregroundStyle(Color.secondaryText)
                .lineLimit(2)

            // Metadata: date and tags
            HStack {
                // Date
                Label(entry.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    .font(.metadata)
                    .foregroundStyle(Color.tertiaryText)

                Spacer()

                // Tags
                if !entry.tags.isEmpty {
                    HStack(spacing: Spacing.xs) {
                        ForEach(entry.tags.prefix(3), id: \.self) { tag in
                            TagChip(text: tag)
                        }
                    }
                }
            }
        }
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Tag Chip

/// A small chip displaying a tag
struct TagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Color.aiAccent.opacity(0.15))
            .foregroundStyle(Color.aiAccent)
            .cornerRadius(CornerRadius.sm)
    }
}

// MARK: - Badge

/// Badge showing a count with colored background
struct Badge: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("\(count)")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs / 2)
            .background(color)
            .cornerRadius(CornerRadius.sm)
    }
}

// MARK: - Empty State

/// Empty state view for when there are no journal entries
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.tertiaryText)

            VStack(spacing: Spacing.sm) {
                Text("No Entries Yet")
                    .font(.entryTitle)
                    .foregroundStyle(Color.primaryText)

                Text("Tap the + button to create your first journal entry")
                    .font(.preview)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

// MARK: - Flashcards Empty State

/// Empty state for no flashcards
struct FlashcardsEmptyState: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 64))
                .foregroundStyle(Color.aiAccent)
                .symbolEffect(.pulse)

            VStack(spacing: Spacing.sm) {
                Text("Ready to Level Up? 🚀")
                    .font(.entryTitle)
                    .foregroundStyle(Color.primaryText)

                Text("Create some study materials, then let CardGenie work its magic to generate flashcards!")
                    .font(.preview)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}

// MARK: - Availability Badge

/// Badge showing Apple Intelligence availability status
struct AvailabilityBadge: View {
    let state: FMCapabilityState

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)

            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(backgroundColor)
        .foregroundStyle(foregroundColor)
        .cornerRadius(CornerRadius.sm)
    }

    private var icon: String {
        switch state {
        case .available:
            return "checkmark.circle.fill"
        case .notEnabled, .notSupported:
            return "exclamationmark.triangle.fill"
        case .modelNotReady:
            return "hourglass"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    private var text: String {
        switch state {
        case .available:
            return "AI Ready"
        case .notEnabled:
            return "AI Disabled"
        case .notSupported:
            return "AI Unavailable"
        case .modelNotReady:
            return "AI Loading..."
        case .unknown:
            return "Unknown"
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .available:
            return .success.opacity(0.15)
        case .notEnabled, .notSupported:
            return .warning.opacity(0.15)
        case .modelNotReady:
            return .blue.opacity(0.15)
        case .unknown:
            return .gray.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch state {
        case .available:
            return .success
        case .notEnabled, .notSupported:
            return .warning
        case .modelNotReady:
            return .blue
        case .unknown:
            return .gray
        }
    }
}

// MARK: - Previews

#Preview("Entry Row") {
    List {
        EntryRow(entry: StudyContent(
            source: .text,
            rawContent: "Today was a great day! I learned so much about SwiftUI and had a wonderful time exploring the new Liquid Glass design system. The translucent materials really make the interface come alive."
        ))

        EntryRow(entry: StudyContent(
            source: .text,
            rawContent: "Quick note about the meeting"
        ))
    }
}

#Preview("Empty State") {
    EmptyStateView()
}

#Preview("Availability Badges") {
    VStack(spacing: Spacing.sm) {
        AvailabilityBadge(state: .available)
        AvailabilityBadge(state: .notEnabled)
        AvailabilityBadge(state: .notSupported)
        AvailabilityBadge(state: .modelNotReady)
        AvailabilityBadge(state: .unknown)
    }
    .padding()
}
