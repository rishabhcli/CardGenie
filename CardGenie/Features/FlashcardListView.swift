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

    @State private var selectedSet: FlashcardSet?
    @State private var showingStudyView = false
    @State private var studyingDailyReview = false
    @State private var searchText = ""

    private let spacedRepetitionManager = SpacedRepetitionManager()

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
                ToolbarItem(placement: .topBarTrailing) {
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
            .searchable(text: $searchText, prompt: "Search flashcard sets")
            .sheet(isPresented: $showingStudyView) {
                if let set = selectedSet {
                    FlashcardStudyView(
                        flashcardSet: set,
                        cards: studyingDailyReview ? dailyReviewQueue : getStudyCards(for: set)
                    )
                }
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

            Text("You have \(totalDueCount) card\(totalDueCount == 1 ? "" : "s") ready for review")
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
                            selectedSet = set
                            studyingDailyReview = false
                            showingStudyView = true
                        }
                        .contextMenu {
                            Button {
                                selectedSet = set
                                studyingDailyReview = false
                                showingStudyView = true
                            } label: {
                                Label("Study", systemImage: "play.fill")
                            }

                            Button(role: .destructive) {
                                deleteSet(set)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(set.topicLabel) flashcard set")
                        .accessibilityHint("\(set.cardCount) cards, \(set.dueCount) due. Double tap to study.")
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
        flashcardSets.reduce(0) { $0 + $1.dueCount }
    }

    private var totalCardCount: Int {
        flashcardSets.reduce(0) { $0 + $1.cardCount }
    }

    private var dailyReviewQueue: [Flashcard] {
        spacedRepetitionManager.getDailyReviewQueue(from: flashcardSets)
    }

    private var successRateText: String {
        let totalReviews = flashcardSets.reduce(0) { $0 + $1.totalReviews }
        guard totalReviews > 0 else { return "N/A" }

        let avgSuccessRate = flashcardSets.reduce(0.0) { $0 + $1.successRate } / Double(flashcardSets.count)
        return "\(Int(avgSuccessRate * 100))%"
    }

    // MARK: - Actions

    private func studyAllDueCards() {
        guard totalDueCount > 0 else { return }

        // Create a temporary "Daily Review" set for study view
        selectedSet = flashcardSets.first
        studyingDailyReview = true
        showingStudyView = true
    }

    private func getStudyCards(for set: FlashcardSet) -> [Flashcard] {
        spacedRepetitionManager.getStudySession(
            from: set,
            maxNew: 5,
            maxReview: 20
        )
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
            await NotificationManager.shared.updateBadgeCount(totalDueCount)
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
