//
//  SessionBuilderView.swift
//  CardGenie
//
//  Session configuration view for customizing study sessions.
//  Allows users to choose modes and card limits.
//

import SwiftUI

struct SessionBuilderView: View {
    @Environment(\.dismiss) private var dismiss

    let flashcardSet: FlashcardSet
    let onStart: (SessionConfiguration) -> Void

    // Session configuration
    @State private var mode: SessionMode = .mixed
    @State private var maxNew: Int = 5
    @State private var maxReview: Int = 20
    @State private var includeNew: Bool = true
    @State private var includeReview: Bool = true

    @AppStorage("defaultSessionMode") private var defaultMode: String = "mixed"
    @AppStorage("defaultMaxNew") private var defaultMaxNew: Int = 5
    @AppStorage("defaultMaxReview") private var defaultMaxReview: Int = 20

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Set Info
                    setInfoSection

                    // Mode Selector
                    modeSelector

                    // Custom Settings (only for Custom mode)
                    if mode == .custom {
                        customSettings
                    }

                    // Estimated Time
                    estimatedTimeSection

                    // Quick Start Note
                    quickStartNote
                }
                .padding()
            }
            .navigationTitle("Session Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        startSession()
                    }
                    .fontWeight(.semibold)
                    .disabled(cardCount == 0)
                }
            }
            .onAppear {
                loadDefaults()
            }
        }
    }

    // MARK: - Set Info Section

    private var setInfoSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .font(.title)
                    .foregroundStyle(Color.aiAccent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(flashcardSet.topicLabel)
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)

                    HStack(spacing: 12) {
                        Label("\(flashcardSet.newCount) new", systemImage: "sparkles")
                            .font(.caption)
                            .foregroundStyle(Color.aiAccent)

                        Label("\(flashcardSet.dueCount - flashcardSet.newCount) review", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(Color.warning)
                    }
                }

                Spacer()
            }
            .padding()
            .glassPanel()
            .cornerRadius(16)
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Mode")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            VStack(spacing: 12) {
                ModeOption(
                    mode: .newOnly,
                    selectedMode: $mode,
                    icon: "sparkles",
                    title: "New Cards Only",
                    description: "Focus on learning new material",
                    count: flashcardSet.newCount
                )

                ModeOption(
                    mode: .reviewOnly,
                    selectedMode: $mode,
                    icon: "arrow.clockwise",
                    title: "Review Only",
                    description: "Practice cards you've already seen",
                    count: flashcardSet.dueCount - flashcardSet.newCount
                )

                ModeOption(
                    mode: .mixed,
                    selectedMode: $mode,
                    icon: "shuffle",
                    title: "Mixed (Recommended)",
                    description: "Balance of new cards and reviews",
                    count: min(maxNew, flashcardSet.newCount) + min(maxReview, flashcardSet.dueCount - flashcardSet.newCount)
                )

                ModeOption(
                    mode: .custom,
                    selectedMode: $mode,
                    icon: "slider.horizontal.3",
                    title: "Custom",
                    description: "Configure your own limits",
                    count: cardCount
                )
            }
        }
    }

    // MARK: - Custom Settings

    private var customSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Custom Settings")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            VStack(spacing: 24) {
                // New cards toggle and slider
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $includeNew) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.aiAccent)
                            Text("Include New Cards")
                                .foregroundStyle(Color.primaryText)
                        }
                    }
                    .tint(Color.aiAccent)

                    if includeNew {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Max New Cards")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondaryText)

                                Spacer()

                                Text("\(maxNew)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.aiAccent)
                            }

                            Slider(value: Binding(
                                get: { Double(maxNew) },
                                set: { maxNew = Int($0) }
                            ), in: 1...Double(max(flashcardSet.newCount, 1)), step: 1)
                                .tint(Color.aiAccent)
                        }
                    }
                }
                .padding()
                .glassPanel()
                .cornerRadius(12)

                // Review cards toggle and slider
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $includeReview) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(Color.warning)
                            Text("Include Review Cards")
                                .foregroundStyle(Color.primaryText)
                        }
                    }
                    .tint(Color.aiAccent)

                    if includeReview {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Max Review Cards")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondaryText)

                                Spacer()

                                Text("\(maxReview)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.warning)
                            }

                            Slider(value: Binding(
                                get: { Double(maxReview) },
                                set: { maxReview = Int($0) }
                            ), in: 1...Double(max(flashcardSet.dueCount - flashcardSet.newCount, 1)), step: 1)
                                .tint(Color.warning)
                        }
                    }
                }
                .padding()
                .glassPanel()
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Estimated Time Section

    private var estimatedTimeSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(Color.aiAccent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Time")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)

                    Text(estimatedTime)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.primaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Cards")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)

                    Text("\(cardCount)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.aiAccent)
                }
            }
            .padding()
            .glassPanel()
            .cornerRadius(16)
        }
    }

    // MARK: - Quick Start Note

    private var quickStartNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.aiAccent)

            Text("Your preferences will be saved for future sessions")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)

            Spacer()
        }
        .padding()
        .background(Color.aiAccent.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    private var cardCount: Int {
        switch mode {
        case .newOnly:
            return min(flashcardSet.newCount, 20)
        case .reviewOnly:
            return min(flashcardSet.dueCount - flashcardSet.newCount, 25)
        case .mixed:
            let newCount = min(maxNew, flashcardSet.newCount)
            let reviewCount = min(maxReview, flashcardSet.dueCount - flashcardSet.newCount)
            return newCount + reviewCount
        case .custom:
            var count = 0
            if includeNew {
                count += min(maxNew, flashcardSet.newCount)
            }
            if includeReview {
                count += min(maxReview, flashcardSet.dueCount - flashcardSet.newCount)
            }
            return count
        }
    }

    private var estimatedTime: String {
        let minutes = (cardCount * 30) / 60 // 30 seconds per card
        if minutes < 1 {
            return "< 1 min"
        } else if minutes == 1 {
            return "1 min"
        } else {
            return "\(minutes) mins"
        }
    }

    // MARK: - Actions

    private func loadDefaults() {
        if let savedMode = SessionMode(rawValue: defaultMode) {
            mode = savedMode
        }
        maxNew = defaultMaxNew
        maxReview = defaultMaxReview
    }

    private func saveDefaults() {
        defaultMode = mode.rawValue
        defaultMaxNew = maxNew
        defaultMaxReview = maxReview
    }

    private func startSession() {
        saveDefaults()

        let config = SessionConfiguration(
            mode: mode,
            maxNew: mode == .custom ? (includeNew ? maxNew : 0) : maxNew,
            maxReview: mode == .custom ? (includeReview ? maxReview : 0) : maxReview
        )

        onStart(config)
        dismiss()
    }
}

// MARK: - Mode Option Component

private struct ModeOption: View {
    let mode: SessionMode
    @Binding var selectedMode: SessionMode
    let icon: String
    let title: String
    let description: String
    let count: Int

    private var isSelected: Bool {
        selectedMode == mode
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedMode = mode
            }
        } label: {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.aiAccent : Color.secondaryText)
                    .frame(width: 40)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }

                Spacer()

                // Card count
                VStack(spacing: 2) {
                    Text("\(count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(isSelected ? Color.aiAccent : Color.primaryText)

                    Text("cards")
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryText)
                }

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.aiAccent)
                        .font(.title3)
                }
            }
            .padding()
            .background(isSelected ? Color.aiAccent.opacity(0.1) : Color.clear)
            .glassPanel()
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.aiAccent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Mode

enum SessionMode: String, Codable, CaseIterable {
    case newOnly = "new"
    case reviewOnly = "review"
    case mixed = "mixed"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .newOnly: return "New Only"
        case .reviewOnly: return "Review Only"
        case .mixed: return "Mixed"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Session Configuration

struct SessionConfiguration {
    let mode: SessionMode
    let maxNew: Int
    let maxReview: Int

    func getCards(from set: FlashcardSet, manager: SpacedRepetitionManager) -> [Flashcard] {
        switch mode {
        case .newOnly:
            return Array(set.getNewCards().prefix(20))
        case .reviewOnly:
            let dueCards = set.getDueCards().filter { !$0.isNew }
            return Array(dueCards.prefix(25))
        case .mixed, .custom:
            return manager.getStudySession(from: set, maxNew: maxNew, maxReview: maxReview)
        }
    }
}

// MARK: - Preview

#Preview {
    let set = FlashcardSet(topicLabel: "Spanish Vocabulary", tag: "spanish")

    // Add mock cards
    for i in 1...15 {
        let card = Flashcard(
            type: .qa,
            question: "Question \(i)",
            answer: "Answer \(i)",
            linkedEntryID: UUID()
        )
        if i <= 5 {
            card.nextReviewDate = Date() // Due
        } else {
            card.reviewCount = 1 // Not new
            card.nextReviewDate = Date().addingTimeInterval(86400) // Not due
        }
        set.addCard(card)
    }

    return SessionBuilderView(flashcardSet: set) { config in
        print("Starting session with config: \(config)")
    }
}
