//
//  StudyResultsView.swift
//  CardGenie
//
//  Study session results with AI-powered encouragement.
//  Shows performance stats and celebration effects.
//

import SwiftUI

/// Study session results view with AI encouragement
struct StudyResultsView: View {
    let correct: Int
    let total: Int
    let streak: Int
    let onDismiss: () -> Void

    @State private var encouragement = ""
    @State private var isLoading = true
    @StateObject private var fmClient = FMClient()
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var accuracy: Double {
        total > 0 ? Double(correct) / Double(total) : 0
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Celebration effect for high accuracy
            if accuracy >= 0.8 && !reduceMotion {
                Circle()
                    .fill(Color.magicGold)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "star.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    )
                    .glow(color: .magicGold, radius: 20)
                    .confetti()
            } else {
                Circle()
                    .fill(Color.cosmicPurple)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    )
                    .glow(color: .cosmicPurple, radius: 15)
            }

            Text("Session Complete!")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundColor(.primaryText)

            // Stats
            HStack(spacing: 40) {
                StatItem(
                    value: "\(correct)/\(total)",
                    label: "Correct",
                    color: .genieGreen
                )

                StatItem(
                    value: "\(Int(accuracy * 100))%",
                    label: "Accuracy",
                    color: .mysticBlue
                )

                StatItem(
                    value: "\(streak)",
                    label: "Day Streak",
                    color: .magicGold
                )
            }
            .padding(.vertical, Spacing.lg)

            // AI Encouragement
            VStack(spacing: Spacing.md) {
                if isLoading {
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                            .tint(.cosmicPurple)
                        Text("CardGenie is thinking...")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .fill(Color.cosmicPurple.opacity(0.1))
                    )
                    .shimmer()
                } else {
                    Text(encouragement)
                        .font(.system(.title3, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.cosmicPurple)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                .fill(Color.cosmicPurple.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal)

            Spacer()

            // Continue button
            HapticButton(hapticStyle: .medium) {
                onDismiss()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MagicButtonStyle())
            .padding(.horizontal)
        }
        .padding()
        .task {
            await loadEncouragement()
        }
    }

    private func loadEncouragement() async {
        do {
            encouragement = try await fmClient.generateEncouragement(
                correctCount: correct,
                totalCount: total,
                streak: streak
            )
            isLoading = false
        } catch {
            // Fallback encouragement
            if accuracy >= 0.9 {
                encouragement = "Outstanding work! You're mastering this material! ⭐️"
            } else if accuracy >= 0.7 {
                encouragement = "Great progress! Keep up the excellent work! 💪"
            } else if accuracy >= 0.5 {
                encouragement = "You're learning! Every review makes you stronger! 🌟"
            } else {
                encouragement = "Don't give up! Learning takes time and you're doing great! 💫"
            }
            isLoading = false
        }
    }
}

/// Stat item display component
struct StatItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondaryText)
        }
    }
}

// MARK: - Preview

#Preview("High Score") {
    StudyResultsView(
        correct: 9,
        total: 10,
        streak: 5,
        onDismiss: {}
    )
}

#Preview("Medium Score") {
    StudyResultsView(
        correct: 6,
        total: 10,
        streak: 2,
        onDismiss: {}
    )
}

#Preview("Low Score") {
    StudyResultsView(
        correct: 3,
        total: 10,
        streak: 1,
        onDismiss: {}
    )
}
