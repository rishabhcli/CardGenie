//
//  StatisticsView.swift
//  CardGenie
//
//  Comprehensive statistics and analytics dashboard.
//

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query(sort: \FlashcardSet.createdDate, order: .reverse) private var flashcardSets: [FlashcardSet]

    private var analytics: StudyAnalytics {
        StudyAnalytics(sets: flashcardSets)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Overview Cards
                    overviewSection

                    // This Week Stats
                    weeklyStatsSection

                    // Study Trend Chart
                    if !analytics.dailyProgress.isEmpty {
                        studyTrendSection
                    }

                    // Mastery Distribution
                    masteryDistributionSection

                    // Top Performing Sets
                    topPerformingSection
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(spacing: 16) {
            Text("Overview")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatsCard(
                    title: "Study Streak",
                    value: "\(analytics.currentStreak)",
                    subtitle: "days",
                    icon: "flame.fill",
                    color: .orange
                )

                StatsCard(
                    title: "Total Reviews",
                    value: "\(analytics.totalReviews)",
                    subtitle: "cards",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                StatsCard(
                    title: "Avg Accuracy",
                    value: "\(Int(analytics.overallAccuracy * 100))%",
                    subtitle: "success rate",
                    icon: "target",
                    color: .blue
                )

                StatsCard(
                    title: "Cards Mastered",
                    value: "\(analytics.masteredCount)",
                    subtitle: "expert level",
                    icon: "trophy.fill",
                    color: Color(red: 1.0, green: 0.84, blue: 0.0)
                )
            }
        }
    }

    // MARK: - Weekly Stats

    private var weeklyStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)

            VStack(spacing: 8) {
                StatRow(
                    label: "Cards Studied",
                    value: "\(analytics.cardsStudiedThisWeek)",
                    icon: "rectangle.on.rectangle.angled"
                )

                StatRow(
                    label: "Study Time",
                    value: analytics.studyTimeThisWeek,
                    icon: "clock.fill"
                )

                StatRow(
                    label: "New Cards Added",
                    value: "\(analytics.newCardsThisWeek)",
                    icon: "plus.circle.fill"
                )

                StatRow(
                    label: "Weekly Accuracy",
                    value: "\(Int(analytics.weeklyAccuracy * 100))%",
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
            .padding()
            .glassPanel()
            .cornerRadius(12)
        }
    }

    // MARK: - Study Trend Chart

    private var studyTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Study Trend (Last 7 Days)")
                .font(.headline)

            Chart {
                ForEach(analytics.dailyProgress) { day in
                    LineMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Cards", day.cardsStudied)
                    )
                    .foregroundStyle(Color.aiAccent)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Cards", day.cardsStudied)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.aiAccent.opacity(0.3), Color.aiAccent.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.weekday(.narrow))
                                .font(.caption2)
                        }
                    }
                }
            }
            .padding()
            .glassPanel()
            .cornerRadius(12)
        }
    }

    // MARK: - Mastery Distribution

    private var masteryDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mastery Distribution")
                .font(.headline)

            VStack(spacing: 8) {
                MasteryBar(
                    level: "🏆 Mastered",
                    count: analytics.masteredCount,
                    total: analytics.totalCards,
                    color: Color(red: 1.0, green: 0.84, blue: 0.0)
                )

                MasteryBar(
                    level: "⭐️ Proficient",
                    count: analytics.proficientCount,
                    total: analytics.totalCards,
                    color: .purple
                )

                MasteryBar(
                    level: "📈 Developing",
                    count: analytics.developingCount,
                    total: analytics.totalCards,
                    color: .blue
                )

                MasteryBar(
                    level: "🌱 Learning",
                    count: analytics.learningCount,
                    total: analytics.totalCards,
                    color: .orange
                )
            }
            .padding()
            .glassPanel()
            .cornerRadius(12)
        }
    }

    // MARK: - Top Performing Sets

    private var topPerformingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Performing Sets")
                .font(.headline)

            if analytics.topSets.isEmpty {
                Text("No study sessions yet")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassPanel()
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(analytics.topSets.prefix(5), id: \.set.id) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.set.topicLabel)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("\(item.set.cardCount) cards • \(item.set.totalReviews) reviews")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondaryText)
                            }

                            Spacer()

                            Text("\(Int(item.accuracy * 100))%")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(accuracyColor(item.accuracy))
                        }
                        .padding(.vertical, 8)

                        if item.set.id != analytics.topSets.prefix(5).last?.set.id {
                            Divider()
                        }
                    }
                }
                .padding()
                .glassPanel()
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Helper Methods

    private func accuracyColor(_ accuracy: Double) -> Color {
        if accuracy >= 0.9 { return .green }
        if accuracy >= 0.7 { return .blue }
        if accuracy >= 0.5 { return .orange }
        return .red
    }
}

// MARK: - Stats Card Component

private struct StatsCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.primaryText)

            Text(title)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(Color.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassPanel()
        .cornerRadius(12)
    }
}

// MARK: - Stat Row Component

private struct StatRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.aiAccent)
                .frame(width: 24)

            Text(label)
                .foregroundStyle(Color.primaryText)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(Color.secondaryText)
        }
    }
}

// MARK: - Mastery Bar Component

private struct MasteryBar: View {
    let level: String
    let count: Int
    let total: Int
    let color: Color

    private var percentage: Double {
        total > 0 ? Double(count) / Double(total) : 0
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(level)
                    .font(.subheadline)
                Spacer()
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.tertiaryText.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * percentage)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Analytics Model

struct StudyAnalytics {
    let sets: [FlashcardSet]

    // Overall stats
    var totalReviews: Int {
        sets.reduce(0) { $0 + $1.totalReviews }
    }

    var totalCards: Int {
        sets.flatMap { $0.cards }.count
    }

    var overallAccuracy: Double {
        let allCards = sets.flatMap { $0.cards }
        guard !allCards.isEmpty else { return 0 }

        let rates = allCards.compactMap { card -> Double? in
            guard card.reviewCount > 0 else { return nil }
            return card.successRate
        }

        guard !rates.isEmpty else { return 0 }
        return rates.reduce(0, +) / Double(rates.count)
    }

    var currentStreak: Int {
        StudyStreakManager.shared.currentStreak()
    }

    // Mastery levels
    var masteredCount: Int {
        sets.flatMap { $0.cards }.filter { $0.masteryLevel == .mastered }.count
    }

    var proficientCount: Int {
        sets.flatMap { $0.cards }.filter { $0.masteryLevel == .proficient }.count
    }

    var developingCount: Int {
        sets.flatMap { $0.cards }.filter { $0.masteryLevel == .developing }.count
    }

    var learningCount: Int {
        sets.flatMap { $0.cards }.filter { $0.masteryLevel == .learning }.count
    }

    // Weekly stats
    var cardsStudiedThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return sets.flatMap { $0.cards }
            .filter { card in
                guard let lastReviewed = card.lastReviewed else { return false }
                return lastReviewed > weekAgo
            }
            .count
    }

    var studyTimeThisWeek: String {
        let minutes = cardsStudiedThisWeek * 30 / 60 // 30 seconds per card
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMin = minutes % 60
            return "\(hours)h \(remainingMin)m"
        }
    }

    var newCardsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return sets.flatMap { $0.cards }
            .filter { $0.createdAt > weekAgo }
            .count
    }

    var weeklyAccuracy: Double {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let recentCards = sets.flatMap { $0.cards }.filter { card in
            guard let lastReviewed = card.lastReviewed else { return false }
            return lastReviewed > weekAgo
        }

        guard !recentCards.isEmpty else { return 0 }
        let rates = recentCards.map { $0.successRate }
        return rates.reduce(0, +) / Double(rates.count)
    }

    // Daily progress
    struct DailyProgress: Identifiable {
        let id = UUID()
        let date: Date
        let cardsStudied: Int
    }

    var dailyProgress: [DailyProgress] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!

            let count = sets.flatMap { $0.cards }.filter { card in
                guard let lastReviewed = card.lastReviewed else { return false }
                return lastReviewed >= date && lastReviewed < nextDay
            }.count

            return DailyProgress(date: date, cardsStudied: count)
        }.reversed()
    }

    // Top performing sets
    struct TopSet {
        let set: FlashcardSet
        let accuracy: Double
    }

    var topSets: [TopSet] {
        sets.compactMap { set in
            guard set.totalReviews > 0 else { return nil }
            return TopSet(set: set, accuracy: set.successRate)
        }
        .sorted { $0.accuracy > $1.accuracy }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: FlashcardSet.self, Flashcard.self,
        configurations: config
    )
    let context = ModelContext(container)

    // Create sample data
    let set1 = FlashcardSet(topicLabel: "History", tag: "history")
    set1.totalReviews = 50
    for i in 0..<20 {
        let card = Flashcard(
            type: .qa,
            question: "Question \(i)",
            answer: "Answer \(i)",
            linkedEntryID: UUID()
        )
        card.reviewCount = Int.random(in: 0...10)
        card.easeFactor = Double.random(in: 1.5...3.0)
        set1.addCard(card)
    }
    context.insert(set1)

    return StatisticsView()
        .modelContainer(container)
}
