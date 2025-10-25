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
    let missedCount: Int
    let onRetry: (() -> Void)?
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

            if missedCount > 0, let onRetry {
                VStack(spacing: Spacing.sm) {
                    Text("Missed \(missedCount) card\(missedCount == 1 ? "" : "s")")
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondaryText)

                    HapticButton(hapticStyle: .medium) {
                        onRetry()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Retry Missed Cards")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MagicButtonStyle())
                }
                .padding(.horizontal)
            }

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
            // Fallback encouragement with more personality
            let messages: [String]

            if accuracy >= 0.95 {
                messages = [
                    "🎯 PERFECT! You're a CardGenie master!",
                    "✨ Flawless! Your brain is on fire!",
                    "🌟 Legendary performance! Keep this energy!",
                    "🚀 Mind-blowing! You're unstoppable!"
                ]
            } else if accuracy >= 0.8 {
                messages = [
                    "🔥 Crushing it! You're in the zone!",
                    "💪 Impressive! Your hard work is paying off!",
                    "⭐️ Stellar session! You're leveling up fast!",
                    "✨ Fantastic! Keep that momentum going!"
                ]
            } else if accuracy >= 0.6 {
                messages = [
                    "📈 Making progress! You're getting stronger!",
                    "🌱 Growing every day! Keep practicing!",
                    "💡 You're learning! Every card counts!",
                    "🎯 Solid effort! You're on the right track!"
                ]
            } else {
                messages = [
                    "🌟 Every expert was once a beginner! Keep going!",
                    "💫 Practice makes perfect! You've got this!",
                    "🦸 Heroes train every day! You're doing great!",
                    "✨ Learning is a journey! You're making moves!"
                ]
            }

            // Add streak bonus message
            if streak >= 7 {
                encouragement = messages.randomElement()! + "\n🔥 \(streak)-day streak! You're on fire!"
            } else if streak >= 3 {
                encouragement = messages.randomElement()! + "\n⚡️ \(streak)-day streak! Keep it alive!"
            } else {
                encouragement = messages.randomElement()!
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
        missedCount: 0,
        onRetry: nil,
        onDismiss: {}
    )
}

#Preview("Medium Score") {
    StudyResultsView(
        correct: 6,
        total: 10,
        streak: 2,
        missedCount: 2,
        onRetry: {},
        onDismiss: {}
    )
}

#Preview("Low Score") {
    StudyResultsView(
        correct: 3,
        total: 10,
        streak: 1,
        missedCount: 1,
        onRetry: {},
        onDismiss: {}
    )
}
