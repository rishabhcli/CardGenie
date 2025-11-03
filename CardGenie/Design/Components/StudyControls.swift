//
//  StudyControls.swift
//  CardGenie
//
//  Study and flashcard-specific controls.
//

import SwiftUI

// MARK: - Review Button

/// Review button for spaced repetition ratings
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
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Text(response.displayName)
                    .font(.headline)

                Text(shortDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .foregroundStyle(isEnabled ? foregroundColor : .gray)
            .cornerRadius(CornerRadius.md)
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
