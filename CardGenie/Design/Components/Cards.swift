//
//  Cards.swift
//  CardGenie
//
//  Card components with Liquid Glass styling.
//

import SwiftUI

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
            // Topic icon
            Image(systemName: topicIcon)
                .font(.title2)
                .foregroundStyle(Color.aiAccent)
                .frame(width: 44, height: 44)
                .background(Color.aiAccent.opacity(0.1))
                .cornerRadius(CornerRadius.md)

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

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.tertiaryText)
        }
        .padding()
        .glassPanel()
        .cornerRadius(CornerRadius.lg)
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
