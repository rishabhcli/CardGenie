//
//  Components.swift
//  CardGenie
//
//  Reusable UI components with Liquid Glass styling.
//

import SwiftUI
import PencilKit

// MARK: - Buttons

// MARK: - Glass Button

/// A button with Liquid Glass styling
struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isLoading: Bool = false
    var style: ButtonStyleType = .primary

    enum ButtonStyleType {
        case primary, secondary, destructive
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if let icon = icon {
                    Image(systemName: icon)
                }

                Text(title)
                    .font(.button)
            }
            .foregroundStyle(textColor)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .glassPanel()
            .cornerRadius(CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }

    private var textColor: Color {
        switch style {
        case .primary:
            return .aiAccent
        case .secondary:
            return .primaryText
        case .destructive:
            return .destructive
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:
            return .aiAccent.opacity(0.3)
        case .secondary:
            return .clear
        case .destructive:
            return .destructive.opacity(0.3)
        }
    }
}

// MARK: - Previews

#Preview("Glass Buttons") {
    VStack(spacing: Spacing.md) {
        GlassButton(title: "Summarize", icon: "sparkles", action: {}, style: .primary)

        GlassButton(title: "Loading...", icon: nil, action: {}, isLoading: true, style: .primary)

        GlassButton(title: "Cancel", icon: "xmark", action: {}, style: .secondary)

        GlassButton(title: "Delete", icon: "trash", action: {}, style: .destructive)
    }
    .padding()
}

// MARK: - Cards

// MARK: - AI Summary Card

/// A card displaying an AI-generated summary
struct AISummaryCard: View {
    let summary: String
    var onDismiss: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack {
                Label("AI Summary", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Color.aiAccent)

                Spacer()

                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Summary text
            Text(summary)
                .font(.preview)
                .foregroundStyle(Color.primaryText)
        }
        .padding()
        .glassCard()
        .transition(
            reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                )
        )
    }
}

// MARK: - AI Reflection Card

/// A card displaying an AI-generated reflection
struct AIReflectionCard: View {
    let reflection: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "quote.bubble.fill")
                .font(.title2)
                .foregroundStyle(Color.aiAccent)

            Text(reflection)
                .font(.preview)
                .foregroundStyle(Color.secondaryText)
                .italic()
        }
        .padding()
        .glassPanel()
        .cornerRadius(CornerRadius.lg)
    }
}

// MARK: - Flashcard Set Row

/// Row displaying a flashcard set with statistics
struct FlashcardSetRow: View {
    let set: FlashcardSet

    private var topicIcon: String {
        // Map topics to SF Symbols
        switch set.topicLabel.lowercased() {
        case "work": return "briefcase.fill"
        case "travel": return "airplane"
        case "health": return "heart.fill"
        case "personal": return "person.fill"
        case "learning": return "book.fill"
        case "family": return "house.fill"
        case "food": return "fork.knife"
        default: return "folder.fill"
        }
    }

    private var successPercent: String {
        let percent = Int(set.successRate * 100)
        return "\(percent)%"
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Topic icon with glow effect
            ZStack {
                Circle()
                    .fill(Color.aiAccent.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .blur(radius: 8)

                Image(systemName: topicIcon)
                    .font(.title2)
                    .foregroundStyle(Color.aiAccent)
                    .frame(width: 44, height: 44)
                    .background(Color.aiAccent.opacity(0.15))
                    .cornerRadius(CornerRadius.md)
            }

            // Content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Topic name with due badge
                HStack {
                    Text(set.topicLabel)
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)

                    if set.dueCount > 0 {
                        Badge(count: set.dueCount, color: .red)
                    }
                }

                // Statistics
                HStack(spacing: Spacing.xs) {
                    Text("\(set.cardCount) cards")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)

                    if set.newCount > 0 {
                        Text("•")
                        Text("\(set.newCount) new")
                            .font(.caption)
                            .foregroundStyle(Color.aiAccent)
                    }

                    if set.totalReviews > 0 {
                        Text("•")
                        Text(successPercent)
                            .font(.caption)
                            .foregroundStyle(Color.success)
                    }
                }
            }

            Spacer()

            // More obvious "tap here" indicator
            VStack(spacing: 4) {
                Text("VIEW")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.cosmicPurple)

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.cosmicPurple)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color(.systemBackground))
                .glassEffect(.regular, in: .rect(cornerRadius: CornerRadius.lg))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(Color.cosmicPurple.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Flashcard set: \(set.topicLabel). \(set.cardCount) cards, \(set.dueCount) due")
        .accessibilityHint("Double tap to view set details and learning modes")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Flashcard Card View

/// Flashcard view with front/back flip
struct FlashcardCardView: View {
    let flashcard: Flashcard
    @Binding var showAnswer: Bool

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Type indicator and mastery level
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: typeIcon)
                        .font(.caption)
                    Text(flashcard.typeDisplayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(Color.tertiaryText)

                Spacer()

                // Mastery badge
                HStack(spacing: 4) {
                    Text(flashcard.masteryLevel.emoji)
                        .font(.caption)
                    Text(flashcard.masteryLevel.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(masteryColor.opacity(0.15))
                .foregroundStyle(masteryColor)
                .cornerRadius(8)
            }

            Spacer()

            // Question
            Text(flashcard.question)
                .font(.title2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.primaryText)
                .padding(.horizontal)

            if showAnswer {
                // Divider
                Rectangle()
                    .fill(Color.tertiaryText.opacity(0.3))
                    .frame(height: 1)
                    .frame(maxWidth: 100)
                    .padding(.vertical, Spacing.sm)

                // Answer
                Text(flashcard.answer)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.aiAccent)
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // Tap hint
                Text("Tap to reveal answer")
                    .font(.caption)
                    .foregroundStyle(Color.tertiaryText)
                    .padding(.top, Spacing.md)
            }

            Spacer()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .frame(height: 400)
        .glassPanel()
        .cornerRadius(CornerRadius.xl)
        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        .onTapGesture {
            withAnimation(.spring()) {
                showAnswer.toggle()
            }
        }
        // MARK: - Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(showAnswer ? [] : .isButton)
        .accessibilityAction(named: "Reveal Answer") {
            withAnimation(.spring()) {
                showAnswer = true
            }
        }
    }

    // MARK: - Accessibility Helpers

    private var accessibilityLabel: String {
        "Flashcard: \(flashcard.typeDisplayName). Mastery level: \(flashcard.masteryLevel.rawValue)"
    }

    private var accessibilityValue: String {
        if showAnswer {
            return "Question: \(flashcard.question). Answer: \(flashcard.answer)"
        } else {
            return "Question: \(flashcard.question). Answer hidden."
        }
    }

    private var accessibilityHint: String {
        if showAnswer {
            return "Swipe right to rate your recall"
        } else {
            return "Double tap to reveal answer"
        }
    }

    private var typeIcon: String {
        switch flashcard.type {
        case .cloze: return "text.badge.star"
        case .qa: return "questionmark.bubble"
        case .definition: return "book"
        }
    }

    private var masteryColor: Color {
        switch flashcard.masteryLevel {
        case .learning: return .orange
        case .developing: return .blue
        case .proficient: return .purple
        case .mastered: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        }
    }
}

// MARK: - Previews

#Preview("AI Summary Card") {
    VStack {
        AISummaryCard(
            summary: "You had a productive day learning about SwiftUI and the Liquid Glass design system. The new translucent materials impressed you.",
            onDismiss: { print("Dismissed") }
        )
        .padding()

        Spacer()
    }
}

#Preview("AI Reflection Card") {
    VStack {
        AIReflectionCard(reflection: "It's wonderful that you're taking time to reflect on your learning journey.")
            .padding()

        Spacer()
    }
}

#Preview("Flashcard Set Row") {
    let set = FlashcardSet(topicLabel: "Travel", tag: "travel")
    set.entryCount = 3
    set.totalReviews = 25

    // Add mock cards
    for i in 1...10 {
        let card = Flashcard(
            type: .cloze,
            question: "Test question \(i)",
            answer: "Test answer",
            linkedEntryID: UUID()
        )
        if i <= 3 {
            card.nextReviewDate = Date() // Make them due
        }
        set.addCard(card)
    }

    return VStack {
        FlashcardSetRow(set: set)
            .padding()
        Spacer()
    }
}

// MARK: - Text Components

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

// MARK: - Containers

// MARK: - Loading View

/// Loading indicator with message
struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .controlSize(.large)

            Text(message)
                .font(.preview)
                .foregroundStyle(Color.secondaryText)
        }
        .padding()
        .glassPanel()
        .cornerRadius(CornerRadius.lg)
    }
}

// MARK: - Session Summary View

/// Session completion summary
struct SessionSummaryView: View {
    let totalCards: Int
    let againCount: Int
    let goodCount: Int
    let easyCount: Int

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Completion icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.success)

            // Title
            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)

            // Stats
            VStack(spacing: Spacing.sm) {
                HStack {
                    Text("Cards reviewed:")
                    Spacer()
                    Text("\(totalCards)")
                        .fontWeight(.semibold)
                }

                if againCount > 0 {
                    HStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)
                        Text("Again:")
                        Spacer()
                        Text("\(againCount)")
                    }
                }

                if goodCount > 0 {
                    HStack {
                        Circle()
                            .fill(.blue)
                            .frame(width: 12, height: 12)
                        Text("Good:")
                        Spacer()
                        Text("\(goodCount)")
                    }
                }

                if easyCount > 0 {
                    HStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 12, height: 12)
                        Text("Easy:")
                        Spacer()
                        Text("\(easyCount)")
                    }
                }
            }
            .padding()
            .glassPanel()
            .cornerRadius(CornerRadius.lg)
        }
        .padding()
    }
}

// MARK: - Previews

#Preview("Session Summary") {
    SessionSummaryView(
        totalCards: 10,
        againCount: 2,
        goodCount: 5,
        easyCount: 3
    )
}

// MARK: - Modifiers

// MARK: - Error Alert

/// Alert for displaying errors
struct ErrorAlert: ViewModifier {
    @Binding var error: Error?

    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: .constant(error != nil), presenting: error) { _ in
                Button("OK") {
                    error = nil
                }
            } message: { error in
                Text(error.localizedDescription)
            }
    }
}

extension View {
    func errorAlert(_ error: Binding<Error?>) -> some View {
        modifier(ErrorAlert(error: error))
    }
}

// MARK: - Study Controls

// MARK: - Review Button

/// Review button for spaced repetition ratings with iOS 26 glass effects and haptic feedback
struct ReviewButton: View {
    let response: SpacedRepetitionManager.ReviewResponse
    let action: () -> Void
    let isEnabled: Bool

    init(response: SpacedRepetitionManager.ReviewResponse, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.response = response
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button {
            // Haptic feedback based on response type
            let impact = UIImpactFeedbackGenerator(style: hapticStyle)
            impact.impactOccurred()

            action()
        } label: {
            VStack(spacing: Spacing.xs) {
                Text(response.displayName)
                    .font(.headline)

                Text(shortDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(backgroundColor)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(backgroundColor)
                }
            }
            .foregroundStyle(isEnabled ? foregroundColor : .gray)
        }
        .disabled(!isEnabled)
        // MARK: - Accessibility
        .accessibilityLabel("\(response.displayName) recall")
        .accessibilityValue("\(shortDescription) accuracy")
        .accessibilityHint("Double tap to rate this flashcard as \(response.displayName.lowercased())")
    }

    private var backgroundColor: Color {
        guard isEnabled else { return .gray.opacity(0.1) }
        return buttonColor.opacity(0.15)
    }

    private var foregroundColor: Color {
        buttonColor
    }

    private var buttonColor: Color {
        switch response {
        case .again: return .red
        case .good: return .blue
        case .easy: return .green
        }
    }

    private var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch response {
        case .again: return .medium
        case .good: return .medium
        case .easy: return .light
        }
    }

    private var shortDescription: String {
        switch response {
        case .again: return "< 60%"
        case .good: return "60-90%"
        case .easy: return "> 90%"
        }
    }
}

// MARK: - Study Progress Bar

/// Progress indicator for study sessions
struct StudyProgressBar: View {
    let current: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("Card \(current) of \(total)")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.aiAccent)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.tertiaryText.opacity(0.2))

                    // Progress
                    Rectangle()
                        .fill(Color.aiAccent)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 4)
            .cornerRadius(2)
        }
    }
}

// MARK: - Previews

#Preview("Review Buttons") {
    VStack(spacing: Spacing.md) {
        ReviewButton(response: .again, action: {})
        ReviewButton(response: .good, action: {})
        ReviewButton(response: .easy, action: {})
    }
    .padding()
}

#Preview("Study Progress") {
    VStack(spacing: Spacing.lg) {
        StudyProgressBar(current: 1, total: 10)
        StudyProgressBar(current: 5, total: 10)
        StudyProgressBar(current: 10, total: 10)
    }
    .padding()
}

// MARK: - Glass Search Bar


struct GlassSearchBar: View {
    @Binding var text: String
    var placeholder: String
    var onSubmit: (() -> Void)? = nil

    // Optional customization
    var showCancelButton: Bool = false
    var onCancel: (() -> Void)? = nil

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            searchField

            if showCancelButton && (isFocused || !text.isEmpty) {
                cancelButton
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: text.isEmpty)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }

    // MARK: - Subviews

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.secondaryText)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.none)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .foregroundStyle(Color.primaryText)
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }
                // Keyboard toolbar for better UX
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()

                        if !text.isEmpty {
                            Button("Clear") {
                                withAnimation {
                                    text = ""
                                }
                            }
                            .tint(.cosmicPurple)
                        }

                        Button("Done") {
                            isFocused = false
                            onSubmit?()
                        }
                        .tint(.cosmicPurple)
                        .fontWeight(.semibold)
                    }
                }

            if !text.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        text = ""
                    }
                    isFocused = true // Keep focus after clearing
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.secondaryText.opacity(0.8))
                        .accessibilityLabel("Clear search")
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, Spacing.sm + 2) // Slightly taller for better touch target
        .padding(.horizontal, Spacing.md)
        .glassSearchBar()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text.isEmpty ? "Search" : "Search, \(text)")
        .accessibilityHint("Double tap to start typing")
        .accessibilityAddTraits(.isSearchField)
    }

    private var cancelButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                text = ""
                isFocused = false
            }
            onCancel?()
        } label: {
            Text("Cancel")
                .foregroundStyle(Color.cosmicPurple)
                .fontWeight(.medium)
        }
        .buttonStyle(.plain)
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .accessibilityLabel("Cancel search")
    }
}

// MARK: - Liquid Glass Search Bar Modifier

extension View {
    /// Apply iOS 26 Liquid Glass search bar styling with capsule shape and interactive mode
    @ViewBuilder
    func glassSearchBar() -> some View {
        if #available(iOS 26.0, *) {
            modifier(GlassSearchBarModifier())
        } else {
            modifier(LegacyGlassSearchBarModifier())
        }
    }
}

/// iOS 26+ Liquid Glass search bar with interactive capsule effect
@available(iOS 26.0, *)
struct GlassSearchBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.interactive(), in: .capsule)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

/// Legacy fallback for iOS 25 and earlier
struct LegacyGlassSearchBarModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        }
    }
}

#Preview("Glass Search Bar - Empty") {
    ZStack {
        // Background gradient to showcase glass blur effect
        LinearGradient(
            colors: [.cosmicPurple.opacity(0.6), .mysticBlue.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 24) {
            // Some content behind the glass to show blur
            Text("iOS 26 Liquid Glass")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            GlassSearchBar(
                text: .constant(""),
                placeholder: "Search study materials..."
            )
            .padding(.horizontal)

            Text("Tap to see interactive shimmer effect")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Glass Search Bar - Filled") {
    ZStack {
        LinearGradient(
            colors: [.cosmicPurple.opacity(0.6), .mysticBlue.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 24) {
            Text("iOS 26 Liquid Glass")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            GlassSearchBar(
                text: .constant("Flashcards"),
                placeholder: "Search study materials..."
            )
            .padding(.horizontal)

            Text("Clear button appears when text is present")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Glass Search Bar - Interactive") {
    struct InteractivePreview: View {
        @State private var searchText = ""

        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [.cosmicPurple.opacity(0.6), .mysticBlue.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("iOS 26 Liquid Glass")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    // Basic search bar
                    GlassSearchBar(
                        text: $searchText,
                        placeholder: "Search study materials...",
                        onSubmit: {
                            print("Searching for: \(searchText)")
                        }
                    )
                    .padding(.horizontal)

                    // Search bar with cancel button
                    GlassSearchBar(
                        text: $searchText,
                        placeholder: "Search with cancel button...",
                        showCancelButton: true,
                        onCancel: {
                            print("Search cancelled")
                        }
                    )
                    .padding(.horizontal)

                    if !searchText.isEmpty {
                        Text("Searching for: \"\(searchText)\"")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.top, 40)
            }
            .preferredColorScheme(.dark)
        }
    }

    return InteractivePreview()
}

// MARK: - Tag Flow Layout

struct TagFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude

        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestLine: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            let requiredWidth = lineWidth == 0 ? subviewSize.width : lineWidth + spacing + subviewSize.width

            if requiredWidth > maxWidth, lineWidth > 0 {
                widestLine = max(widestLine, lineWidth)
                totalHeight += lineHeight + spacing
                lineWidth = subviewSize.width
                lineHeight = subviewSize.height
            } else {
                if lineWidth > 0 {
                    lineWidth += spacing
                }
                lineWidth += subviewSize.width
                lineHeight = max(lineHeight, subviewSize.height)
            }
        }

        if lineWidth > 0 {
            widestLine = max(widestLine, lineWidth)
            totalHeight += lineHeight
        }

        let finalWidth = maxWidth.isFinite ? min(widestLine, maxWidth) : widestLine
        return CGSize(width: finalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let availableWidth = bounds.width > 0 ? bounds.width : (proposal.width ?? .greatestFiniteMagnitude)

        var x = bounds.minX
        var y = bounds.minY
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let requiredWidth = lineWidth == 0 ? size.width : lineWidth + spacing + size.width

            if requiredWidth > availableWidth, lineWidth > 0 {
                x = bounds.minX
                y += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }

            if lineWidth > 0 {
                x += spacing
                lineWidth += spacing
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))

            x += size.width
            lineWidth += size.width
            lineHeight = max(lineHeight, size.height)
        }
    }
}
