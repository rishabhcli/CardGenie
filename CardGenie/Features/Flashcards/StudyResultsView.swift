//
//  StudyResultsView.swift
//  CardGenie
//
//  Session completion view with detailed statistics and encouragement.
//  Shows accuracy, streaks, time metrics, and retry failed cards option.
//

import SwiftUI

struct StudyResultsView: View {
    let correct: Int
    let total: Int
    let streak: Int
    let missedCount: Int
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void

    // Computed properties
    private var accuracy: Double {
        guard total > 0 else { return 0 }
        return Double(correct) / Double(total)
    }

    private var accuracyPercent: Int {
        Int(accuracy * 100)
    }

    private var failed: Int {
        total - correct
    }

    private var performanceLevel: PerformanceLevel {
        switch accuracyPercent {
        case 90...100: return .excellent
        case 75..<90: return .great
        case 60..<75: return .good
        default: return .needsWork
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Celebration Icon
                celebrationIcon

                // Performance Message
                performanceMessage

                // Statistics Cards
                statisticsCards

                // Accuracy Ring
                accuracyRing

                // Streak Display
                if streak > 1 {
                    streakDisplay
                }

                // Failed Cards Section
                if missedCount > 0, onRetry != nil {
                    retrySection
                }

                // Action Buttons
                actionButtons
            }
            .padding()
        }
        .background(Color.clear.ignoresSafeArea())
    }

    // MARK: - Celebration Icon

    private var celebrationIcon: some View {
        Image(systemName: performanceLevel.icon)
            .font(.system(size: 80))
            .foregroundStyle(performanceLevel.color.gradient)
            .symbolEffect(.bounce)
    }

    // MARK: - Performance Message

    private var performanceMessage: some View {
        VStack(spacing: 8) {
            Text(performanceLevel.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.primaryText)

            Text(performanceLevel.message)
                .font(.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Statistics Cards

    private var statisticsCards: some View {
        HStack(spacing: 12) {
            StatisticCard(
                icon: "checkmark.circle.fill",
                label: "Correct",
                value: "\(correct)",
                color: .success
            )

            StatisticCard(
                icon: "xmark.circle.fill",
                label: "Incorrect",
                value: "\(failed)",
                color: .destructive
            )

            StatisticCard(
                icon: "square.stack.3d.up.fill",
                label: "Total",
                value: "\(total)",
                color: .aiAccent
            )
        }
    }

    // MARK: - Accuracy Ring

    private var accuracyRing: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.tertiaryText.opacity(0.2), lineWidth: 20)
                    .frame(width: 180, height: 180)

                // Progress circle
                Circle()
                    .trim(from: 0, to: accuracy)
                    .stroke(
                        performanceLevel.color.gradient,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.5, dampingFraction: 0.8), value: accuracy)

                // Percentage text
                VStack(spacing: 4) {
                    Text("\(accuracyPercent)%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primaryText)

                    Text("Accuracy")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
            }

            Text(performanceLevel.accuracyFeedback)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .glassPanel()
        .cornerRadius(20)
    }

    // MARK: - Streak Display

    private var streakDisplay: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.orange.gradient)
                    .symbolEffect(.pulse)

                Text("Study Streak")
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)
            }

            Text("\(streak) day\(streak == 1 ? "" : "s") in a row!")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.aiAccent)

            Text("Keep it up! Consistency is key to mastery.")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .glassPanel()
        .cornerRadius(16)
    }

    // MARK: - Retry Section

    private var retrySection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundStyle(Color.warning)

                Text("Cards to Review")
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)
            }

            Text("You missed \(missedCount) card\(missedCount == 1 ? "" : "s"). Review them again to strengthen your memory.")
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                onRetry?()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Review Missed Cards")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.warning)
                .cornerRadius(12)
            }
        }
        .padding()
        .glassPanel()
        .cornerRadius(16)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.aiAccent)
                    .cornerRadius(12)
            }
        }
    }
}

// MARK: - Statistic Card Component

private struct StatisticCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.primaryText)

            Text(label)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassPanel()
        .cornerRadius(12)
    }
}

// MARK: - Performance Level

private enum PerformanceLevel {
    case excellent
    case great
    case good
    case needsWork

    var title: String {
        switch self {
        case .excellent: return "Outstanding!"
        case .great: return "Great Work!"
        case .good: return "Good Job!"
        case .needsWork: return "Keep Practicing"
        }
    }

    var message: String {
        switch self {
        case .excellent:
            return "You've mastered this material! Your hard work is paying off."
        case .great:
            return "You're doing really well! A few more reviews and you'll have it down."
        case .good:
            return "You're making progress! Keep reviewing to improve your recall."
        case .needsWork:
            return "Don't give up! Regular practice will help you improve quickly."
        }
    }

    var accuracyFeedback: String {
        switch self {
        case .excellent:
            return "Nearly perfect recall! You're ready for the next challenge."
        case .great:
            return "Strong performance! A few more reps will cement your knowledge."
        case .good:
            return "Solid foundation! Review the tricky cards to boost your score."
        case .needsWork:
            return "Keep at it! Everyone starts somewhere, and practice makes perfect."
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "star.circle.fill"
        case .great: return "hand.thumbsup.circle.fill"
        case .good: return "checkmark.circle.fill"
        case .needsWork: return "arrow.up.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .excellent: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        case .great: return .success
        case .good: return .aiAccent
        case .needsWork: return .warning
        }
    }
}

// MARK: - Preview

#Preview("Excellent Performance") {
    StudyResultsView(
        correct: 18,
        total: 20,
        streak: 7,
        missedCount: 2,
        onRetry: { print("Retry tapped") },
        onDismiss: { print("Done tapped") }
    )
}

#Preview("Good Performance") {
    StudyResultsView(
        correct: 14,
        total: 20,
        streak: 3,
        missedCount: 6,
        onRetry: { print("Retry tapped") },
        onDismiss: { print("Done tapped") }
    )
}

#Preview("Needs Work") {
    StudyResultsView(
        correct: 8,
        total: 20,
        streak: 1,
        missedCount: 12,
        onRetry: { print("Retry tapped") },
        onDismiss: { print("Done tapped") }
    )
}

#Preview("Perfect Score") {
    StudyResultsView(
        correct: 20,
        total: 20,
        streak: 14,
        missedCount: 0,
        onRetry: nil,
        onDismiss: { print("Done tapped") }
    )
}
