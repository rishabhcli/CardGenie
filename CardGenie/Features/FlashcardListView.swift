//
//  FlashcardListView.swift
//  CardGenie
//
//  Main view for browsing and managing flashcard sets.
//  Displays all sets grouped by topic with statistics and navigation to study mode.
//

import SwiftUI
import SwiftData

struct FlashcardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FlashcardSet.createdDate, order: .reverse) private var flashcardSets: [FlashcardSet]

    @State private var activeSession: FlashcardStudySession?
    @State private var searchText = ""
    @State private var showingSettings = false
    @State private var showingStatistics = false
    @State private var cachedDueCount: Int = 0
    @State private var lastCacheUpdate = Date.distantPast

    private let spacedRepetitionManager = SpacedRepetitionManager()
    private let cache = CacheManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .ignoresSafeArea()

                if flashcardSets.isEmpty {
                    FlashcardsEmptyState()
                } else {
                    mainContent
                }
            }
            .navigationTitle("Flashcards")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.cosmicPurple)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if !flashcardSets.isEmpty {
                            Button {
                                showingStatistics = true
                            } label: {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundStyle(Color.aiAccent)
                            }
                        }

                        if !flashcardSets.isEmpty {
                            Menu {
                                Button {
                                    studyAllDueCards()
                                } label: {
                                    Label("Study All Due", systemImage: "book.fill")
                                }
                                .disabled(totalDueCount == 0)

                                Button {
                                    updateAllNotifications()
                                } label: {
                                    Label("Update Reminders", systemImage: "bell.fill")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(Color.primaryText)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search flashcard sets")
            .sheet(item: $activeSession) { session in
                FlashcardStudyView(
                    flashcardSet: session.set,
                    sessionTitle: session.title,
                    cards: session.cards
                )
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingStatistics) {
                StatisticsView()
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Daily Review Section
                if totalDueCount > 0 {
                    dailyReviewSection
                }

                // Statistics Summary
                statisticsSection

                // Flashcard Sets List
                flashcardSetsSection
            }
            .padding()
        }
    }

    // MARK: - Daily Review Section

    private var dailyReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(Color.aiAccent)
                    .font(.title3)

                Text("Daily Review")
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)

                Spacer()

                Badge(count: totalDueCount, color: .red)
            }

            Text(dailyReviewMessage)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)

            Button {
                studyAllDueCards()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Review")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.aiAccent)
                .cornerRadius(12)
            }
        }
        .padding()
        .glassPanel()
        .cornerRadius(16)
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "rectangle.on.rectangle.angled",
                label: "Total Sets",
                value: "\(flashcardSets.count)",
                color: .blue
            )

            StatCard(
                icon: "square.stack.3d.up.fill",
                label: "Total Cards",
                value: "\(totalCardCount)",
                color: .green
            )

            StatCard(
                icon: "chart.line.uptrend.xyaxis",
                label: "Success Rate",
                value: successRateText,
                color: .purple
            )
        }
    }

    // MARK: - Flashcard Sets Section

    private var flashcardSetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All Sets")
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)

                Spacer()

                Text("\(filteredSets.count) set\(filteredSets.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }

            if filteredSets.isEmpty {
                Text("No flashcard sets found")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(filteredSets) { set in
                    FlashcardSetRow(set: set)
                        .onTapGesture {
                            startStudySession(for: set)
                        }
                        .contextMenu {
                            Button {
                                startStudySession(for: set)
                            } label: {
                                Label("Study", systemImage: "play.fill")
                            }

                            Button(role: .destructive) {
                                deleteSet(set)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        // MARK: - Accessibility
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(set.topicLabel) flashcard set")
                        .accessibilityValue("\(set.cardCount) total cards. \(set.dueCount) due for review. \(set.newCount) new cards.")
                        .accessibilityHint("Double tap to start studying this set")
                        .accessibilityAction(named: "Delete Set") {
                            deleteSet(set)
                        }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredSets: [FlashcardSet] {
        if searchText.isEmpty {
            return flashcardSets
        }
        return flashcardSets.filter { set in
            set.topicLabel.localizedCaseInsensitiveContains(searchText) ||
            set.tag.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var totalDueCount: Int {
        let now = Date()

        // Cache for 30 seconds to avoid recalculating on every view update
        if now.timeIntervalSince(lastCacheUpdate) > 30 {
            let setIDs = flashcardSets.map { $0.id }
            cachedDueCount = cache.get(
                key: CacheManager.dueCountKey(setIDs: setIDs),
                maxAge: 30
            ) {
                flashcardSets.reduce(0) { $0 + $1.dueCount }
            }
            lastCacheUpdate = now
        }

        return cachedDueCount
    }

    private var totalCardCount: Int {
        flashcardSets.reduce(0) { $0 + $1.cardCount }
    }

    private var dailyReviewQueue: [Flashcard] {
        cache.get(
            key: CacheManager.dailyQueueKey(date: Date()),
            maxAge: 300 // 5 minutes
        ) {
            spacedRepetitionManager.getDailyReviewQueue(from: flashcardSets)
        }
    }

    private var successRateText: String {
        let totalReviews = flashcardSets.reduce(0) { $0 + $1.totalReviews }
        guard totalReviews > 0 else { return "N/A" }

        let avgSuccessRate = flashcardSets.reduce(0.0) { $0 + $1.successRate } / Double(flashcardSets.count)
        return "\(Int(avgSuccessRate * 100))%"
    }

    private var dailyReviewMessage: String {
        let messages = [
            "Time to flex that brain! \(totalDueCount) card\(totalDueCount == 1 ? "" : "s") waiting",
            "\(totalDueCount) card\(totalDueCount == 1 ? "" : "s") ready to boost your knowledge!",
            "Level up time! \(totalDueCount) card\(totalDueCount == 1 ? " is" : "s are") calling your name",
            "Your brain wants to party! \(totalDueCount) card\(totalDueCount == 1 ? "" : "s") ready to go"
        ]
        return messages.randomElement() ?? "You have \(totalDueCount) card\(totalDueCount == 1 ? "" : "s") ready"
    }

    // MARK: - Actions

    private func studyAllDueCards() {
        guard totalDueCount > 0 else { return }

        let queue = dailyReviewQueue
        let cards = queue.isEmpty ? spacedRepetitionManager.getDailyReviewQueue(from: flashcardSets) : queue

        guard
            !cards.isEmpty,
            let contextSet = flashcardSets.first(where: { $0.dueCount > 0 }) ?? flashcardSets.first
        else { return }

        activeSession = FlashcardStudySession(
            set: contextSet,
            title: "Daily Review",
            cards: cards
        )
    }

    private func startStudySession(for set: FlashcardSet) {
        let cards = getStudyCards(for: set)
        activeSession = FlashcardStudySession(set: set, title: nil, cards: cards)
    }

    private func getStudyCards(for set: FlashcardSet) -> [Flashcard] {
        let studySession = spacedRepetitionManager.getStudySession(
            from: set,
            maxNew: 5,
            maxReview: 20
        )

        // If no cards in study session, return ALL cards from the set
        // This ensures tapping a set always shows something
        if studySession.isEmpty && !set.cards.isEmpty {
            return Array(set.cards.shuffled())
        }

        return studySession
    }

    private func deleteSet(_ set: FlashcardSet) {
        withAnimation {
            modelContext.delete(set)
            do {
                try modelContext.save()
            } catch {
                print("Error deleting flashcard set: \(error)")
            }
        }
    }

    private func updateAllNotifications() {
        Task {
            await NotificationManager.shared.setupNotificationsIfNeeded(dueCount: totalDueCount)
            NotificationManager.shared.updateBadgeCount(totalDueCount)
        }
    }
}

// MARK: - Stat Card Component

private struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
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

// MARK: - Preview

#Preview {
    FlashcardListView()
        .modelContainer(for: [FlashcardSet.self, Flashcard.self], inMemory: true)
}

// MARK: - Study Session Model

private struct FlashcardStudySession: Identifiable {
    let id = UUID()
    let set: FlashcardSet
    let title: String?
    let cards: [Flashcard]
}
