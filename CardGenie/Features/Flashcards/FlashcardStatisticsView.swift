//
//  FlashcardStatisticsView.swift
//  CardGenie
//
//  Comprehensive statistics and insights dashboard for flashcard study.
//  Shows streaks, forecasts, topic proficiency, and milestones.
//

import SwiftUI
import SwiftData
import Charts

struct FlashcardStatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var flashcardSets: [FlashcardSet]
    @Query private var allCards: [Flashcard]

    private let spacedRepetitionManager = SpacedRepetitionManager()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Streak
                    currentStreakSection

                    // Key Metrics
                    keyMetricsSection

                    // Due Forecast
                    dueForecastSection

                    // Topic Proficiency
                    topicProficiencySection

                    // Mastery Distribution
                    masteryDistributionSection

                    // Milestones
                    milestonesSection
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Current Streak Section

    private var currentStreakSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange.gradient)
                    .symbolEffect(.pulse)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(currentStreak)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primaryText)

                    Text("Day Streak")
                        .font(.headline)
                        .foregroundStyle(Color.secondaryText)
                }
            }

            if currentStreak > 0 {
                VStack(spacing: 8) {
                    HStack {
                        Text("Current Streak")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryText)

                        Spacer()

                        Text("\(currentStreak) day\(currentStreak == 1 ? "" : "s")")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.aiAccent)
                    }

                    HStack {
                        Text("Longest Streak")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryText)

                        Spacer()

                        Text("\(longestStreak) days")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.aiAccent)
                    }
                }

                Text(streakMotivation)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .glassPanel()
        .cornerRadius(16)
    }

    // MARK: - Key Metrics Section

    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricCard(
                    icon: "rectangle.stack.fill",
                    label: "Total Cards",
                    value: "\(totalCards)",
                    color: .blue
                )

                MetricCard(
                    icon: "checkmark.circle.fill",
                    label: "Mastered",
                    value: "\(masteredCards)",
                    color: .success
                )

                MetricCard(
                    icon: "clock.arrow.circlepath",
                    label: "Avg Success",
                    value: "\(avgSuccessRate)%",
                    color: .aiAccent
                )

                MetricCard(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Total Reviews",
                    value: "\(totalReviews)",
                    color: .purple
                )
            }
        }
    }

    // MARK: - Due Forecast Section

    private var dueForecastSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Due Forecast (Next 7 Days)")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(dueForecast, id: \.day) { data in
                        BarMark(
                            x: .value("Day", data.dayLabel),
                            y: .value("Cards Due", data.count)
                        )
                        .foregroundStyle(data.isToday ? Color.aiAccent.gradient : Color.blue.gradient)
                        .cornerRadius(4)
                    }
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            } else {
                // Fallback for iOS < 16
                VStack(spacing: 8) {
                    ForEach(dueForecast, id: \.day) { data in
                        HStack {
                            Text(data.dayLabel)
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                                .frame(width: 40, alignment: .leading)

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.tertiaryText.opacity(0.2))

                                    Rectangle()
                                        .fill(data.isToday ? Color.aiAccent : Color.blue)
                                        .frame(width: geometry.size.width * (CGFloat(data.count) / CGFloat(maxDueInForecast)))
                                }
                            }
                            .frame(height: 24)
                            .cornerRadius(4)

                            Text("\(data.count)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.primaryText)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
            }

            Text("Total due in next 7 days: \(totalDueInForecast) cards")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
        }
        .padding()
        .glassPanel()
        .cornerRadius(16)
    }

    // MARK: - Topic Proficiency Section

    private var topicProficiencySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Topic Proficiency")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            if flashcardSets.isEmpty {
                Text("No topics yet")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(topicProficiencies, id: \.topic) { proficiency in
                        TopicProficiencyRow(proficiency: proficiency)
                    }
                }
            }
        }
        .padding()
        .glassPanel()
        .cornerRadius(16)
    }

    // MARK: - Mastery Distribution Section

    private var masteryDistributionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mastery Levels")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(masteryDistribution, id: \.level) { data in
                        SectorMark(
                            angle: .value("Count", data.count),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .foregroundStyle(data.color)
                        .annotation(position: .overlay) {
                            if data.count > 0 {
                                VStack {
                                    Text(data.emoji)
                                        .font(.title3)
                                    Text("\(data.count)")
                                        .font(.caption2)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                }
                .frame(height: 200)
            } else {
                // Fallback for iOS < 16
                VStack(spacing: 8) {
                    ForEach(masteryDistribution, id: \.level) { data in
                        HStack {
                            Text(data.emoji)
                            Text(data.level.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(Color.primaryText)

                            Spacer()

                            Text("\(data.count) cards")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // Legend
            HStack(spacing: 16) {
                ForEach(masteryDistribution, id: \.level) { data in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(data.color)
                            .frame(width: 12, height: 12)
                        Text(data.level.rawValue)
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .glassPanel()
        .cornerRadius(16)
    }

    // MARK: - Milestones Section

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Milestones")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            VStack(spacing: 12) {
                ForEach(milestones, id: \.title) { milestone in
                    MilestoneRow(milestone: milestone)
                }
            }
        }
        .padding()
        .glassPanel()
        .cornerRadius(16)
    }

    // MARK: - Computed Properties

    private var currentStreak: Int {
        StudyStreakManager.shared.currentStreak()
    }

    private var longestStreak: Int {
        StudyStreakManager.shared.longestStreak()
    }

    private var streakMotivation: String {
        switch currentStreak {
        case 0:
            return "Start a study session today to begin your streak!"
        case 1...6:
            return "Keep it up! You're building a habit."
        case 7...29:
            return "Great progress! You're on your way to mastery."
        case 30...99:
            return "Incredible dedication! You're a study champion."
        default:
            return "Legendary! Your consistency is truly remarkable."
        }
    }

    private var totalCards: Int {
        allCards.count
    }

    private var masteredCards: Int {
        allCards.filter { $0.masteryLevel == .mastered }.count
    }

    private var avgSuccessRate: Int {
        guard !allCards.isEmpty else { return 0 }
        let rates = allCards.map { $0.successRate }
        let avg = rates.reduce(0, +) / Double(allCards.count)
        return Int(avg * 100)
    }

    private var totalReviews: Int {
        allCards.reduce(0) { $0 + $1.reviewCount }
    }

    private var dueForecast: [DueForecastData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: today)!
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: date)!

            let count = allCards.filter { card in
                card.nextReviewDate >= date && card.nextReviewDate < endOfDay
            }.count

            let formatter = DateFormatter()
            formatter.dateFormat = dayOffset == 0 ? "'Today'" : "EEE"

            return DueForecastData(
                day: dayOffset,
                dayLabel: formatter.string(from: date),
                count: count,
                isToday: dayOffset == 0
            )
        }
    }

    private var maxDueInForecast: Int {
        dueForecast.map { $0.count }.max() ?? 1
    }

    private var totalDueInForecast: Int {
        dueForecast.reduce(0) { $0 + $1.count }
    }

    private var topicProficiencies: [TopicProficiency] {
        flashcardSets.map { set in
            let stats = spacedRepetitionManager.getSetStatistics(for: set)
            let avgRate = stats["averageSuccessRate"] as? Double ?? 0

            return TopicProficiency(
                topic: set.topicLabel,
                proficiency: avgRate,
                cardCount: set.cardCount,
                masteredCount: set.cards.filter { $0.masteryLevel == .mastered }.count
            )
        }
        .sorted { $0.proficiency > $1.proficiency }
    }

    private var masteryDistribution: [MasteryData] {
        let levels: [Flashcard.MasteryLevel] = [.learning, .developing, .proficient, .mastered]

        return levels.map { level in
            let count = allCards.filter { $0.masteryLevel == level }.count
            return MasteryData(
                level: level,
                count: count,
                emoji: level.emoji,
                color: colorForMastery(level)
            )
        }
    }

    private var milestones: [Milestone] {
        [
            Milestone(
                icon: "star.fill",
                title: "First Review",
                description: "Complete your first review session",
                isAchieved: totalReviews > 0,
                color: .yellow
            ),
            Milestone(
                icon: "flame.fill",
                title: "Week Streak",
                description: "Study for 7 days in a row",
                isAchieved: currentStreak >= 7,
                color: .orange
            ),
            Milestone(
                icon: "sparkles",
                title: "100 Cards",
                description: "Create or generate 100 flashcards",
                isAchieved: totalCards >= 100,
                color: .aiAccent
            ),
            Milestone(
                icon: "trophy.fill",
                title: "Master 50",
                description: "Achieve mastery on 50 cards",
                isAchieved: masteredCards >= 50,
                color: Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
            ),
            Milestone(
                icon: "chart.line.uptrend.xyaxis",
                title: "1000 Reviews",
                description: "Complete 1000 card reviews",
                isAchieved: totalReviews >= 1000,
                color: .purple
            ),
            Milestone(
                icon: "crown.fill",
                title: "Month Streak",
                description: "Study for 30 days in a row",
                isAchieved: currentStreak >= 30,
                color: Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
            )
        ]
    }

    // MARK: - Helper Functions

    private func colorForMastery(_ level: Flashcard.MasteryLevel) -> Color {
        switch level {
        case .learning: return .orange
        case .developing: return .blue
        case .proficient: return .purple
        case .mastered: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        }
    }
}

// MARK: - Supporting Views

private struct MetricCard: View {
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
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassPanel()
        .cornerRadius(12)
    }
}

private struct TopicProficiencyRow: View {
    let proficiency: TopicProficiency

    private var proficiencyPercent: Int {
        Int(proficiency.proficiency * 100)
    }

    private var proficiencyColor: Color {
        switch proficiencyPercent {
        case 90...100: return .success
        case 75..<90: return .aiAccent
        case 60..<75: return .warning
        default: return .destructive
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(proficiency.topic)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primaryText)

                Spacer()

                Text("\(proficiencyPercent)%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(proficiencyColor)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.tertiaryText.opacity(0.2))

                    Rectangle()
                        .fill(proficiencyColor.gradient)
                        .frame(width: geometry.size.width * proficiency.proficiency)
                }
            }
            .frame(height: 8)
            .cornerRadius(4)

            HStack {
                Text("\(proficiency.cardCount) cards")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)

                Text("•")
                    .foregroundStyle(Color.tertiaryText)

                Text("\(proficiency.masteredCount) mastered")
                    .font(.caption)
                    .foregroundStyle(Color.success)
            }
        }
        .padding()
        .background(Color.primaryText.opacity(0.03))
        .cornerRadius(8)
    }
}

private struct MilestoneRow: View {
    let milestone: Milestone

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(milestone.isAchieved ? milestone.color.opacity(0.2) : Color.tertiaryText.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: milestone.icon)
                    .font(.title3)
                    .foregroundStyle(milestone.isAchieved ? milestone.color : Color.tertiaryText)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primaryText)

                Text(milestone.description)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }

            Spacer()

            // Checkmark
            if milestone.isAchieved {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(milestone.color)
                    .font(.title3)
            }
        }
        .padding()
        .background(milestone.isAchieved ? milestone.color.opacity(0.05) : Color.clear)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(milestone.isAchieved ? milestone.color.opacity(0.3) : Color.tertiaryText.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Data Models

private struct DueForecastData {
    let day: Int
    let dayLabel: String
    let count: Int
    let isToday: Bool
}

private struct TopicProficiency {
    let topic: String
    let proficiency: Double // 0.0 to 1.0
    let cardCount: Int
    let masteredCount: Int
}

private struct MasteryData {
    let level: Flashcard.MasteryLevel
    let count: Int
    let emoji: String
    let color: Color
}

private struct Milestone {
    let icon: String
    let title: String
    let description: String
    let isAchieved: Bool
    let color: Color
}

// MARK: - Preview

#Preview {
    FlashcardStatisticsView()
        .modelContainer(for: [FlashcardSet.self, Flashcard.self], inMemory: true)
}
