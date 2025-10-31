//
//  FlashcardStudyView.swift
//  CardGenie
//
//  Interactive flashcard study mode with spaced repetition.
//  Users flip cards, rate their recall, and receive immediate feedback.
//

import SwiftUI
import SwiftData

struct FlashcardStudyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let flashcardSet: FlashcardSet
    let sessionTitle: String?

    @State private var currentCardIndex = 0
    @State private var showAnswer = false
    @State private var sessionStats = SessionStats()
    @State private var showingSummary = false
    @State private var showingClarification = false
    @State private var clarificationText = ""
    @State private var isLoadingClarification = false
    @State private var sessionCards: [Flashcard]
    @State private var failedCards: [Flashcard] = []
    @State private var sessionRecorded = false
    @State private var streakValue = StudyStreakManager.shared.currentStreak()

    private let spacedRepetitionManager = SpacedRepetitionManager()
    private let fmClient = FMClient()

    init(flashcardSet: FlashcardSet, sessionTitle: String? = nil, cards: [Flashcard]) {
        self.flashcardSet = flashcardSet
        self.sessionTitle = sessionTitle
        _sessionCards = State(initialValue: cards)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .ignoresSafeArea()

                if showingSummary {
                    summaryView
                } else if sessionCards.isEmpty {
                    emptyStateView
                } else {
                    studyContent
                }
            }
            .navigationTitle(sessionTitle ?? flashcardSet.topicLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(Color.primaryText)
                }

                ToolbarItem(placement: .principal) {
                    if !showingSummary && !sessionCards.isEmpty {
                        StudyProgressBar(
                            current: currentCardIndex + 1,
                            total: sessionCards.count
                        )
                    }
                }
            }
            .sheet(isPresented: $showingClarification) {
                clarificationSheet
            }
        }
    }

    // MARK: - Study Content

    private var studyContent: some View {
        VStack(spacing: 24) {
            Spacer()

            // Flashcard
            currentCardView
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            Spacer()

            // Control Buttons
            if showAnswer {
                answerButtons
            } else {
                revealButton
            }
        }
        .padding()
    }

    // MARK: - Current Card View

    private var currentCardView: some View {
        VStack(spacing: 0) {
            FlashcardCardView(
                flashcard: currentCard,
                showAnswer: $showAnswer
            )
            .onTapGesture {
                if !showAnswer {
                    withAnimation(.spring(response: 0.3)) {
                        showAnswer = true
                    }
                }
            }

            // Clarification Button (when answer is shown)
            if showAnswer {
                Button {
                    requestClarification()
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle")
                        Text("Ask for Clarification")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.aiAccent)
                    .padding(.vertical, 12)
                }
                .disabled(isLoadingClarification)
            }
        }
    }

    // MARK: - Reveal Button

    private var revealButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                showAnswer = true
            }
        } label: {
            HStack {
                Image(systemName: "eye.fill")
                Text("Show Answer")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.aiAccent)
            .cornerRadius(12)
        }
        .accessibilityLabel("Reveal answer")
    }

    // MARK: - Answer Buttons

    private var answerButtons: some View {
        VStack(spacing: 12) {
            Text("How well did you recall?")
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)

            HStack(spacing: 12) {
                ReviewButton(response: .again) {
                    handleReview(.again)
                }

                ReviewButton(response: .good) {
                    handleReview(.good)
                }

                ReviewButton(response: .easy) {
                    handleReview(.easy)
                }
            }
        }
    }

    // MARK: - Summary View

    private var summaryView: some View {
        StudyResultsView(
            correct: sessionStats.goodCount + sessionStats.easyCount,
            total: sessionStats.totalCards,
            streak: streakValue,
            missedCount: failedCards.count,
            onRetry: failedCards.isEmpty ? nil : { retryMissedCards() },
            onDismiss: {
                dismiss()
            }
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(Color.aiAccent)
                .symbolEffect(.pulse)

            Text("You're a Study Wizard! ✨")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.primaryText)

            Text("All caught up! Your brain is leveling up. Come back later for more magic.")
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                dismiss()
            } label: {
                Text("Awesome!")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.aiAccent)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }

    // MARK: - Clarification Sheet

    @ViewBuilder
    private var clarificationSheet: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .ignoresSafeArea()

                if #available(iOS 26.0, *) {
                    ScrollView {
                        // Wrap glass elements in GlassEffectContainer
                        GlassEffectContainer {
                            VStack(alignment: .leading, spacing: 20) {
                                // Original Flashcard
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Question")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                        .textCase(.uppercase)

                                    Text(currentCard.question)
                                        .font(.body)
                                        .foregroundStyle(Color.primaryText)

                                    Divider()
                                        .padding(.vertical, 4)

                                    Text("Answer")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                        .textCase(.uppercase)

                                    Text(currentCard.answer)
                                        .font(.body)
                                        .foregroundStyle(Color.aiAccent)
                                }
                                .padding()
                                .glassPanel()
                                .cornerRadius(12)

                                // AI Explanation
                                if isLoadingClarification {
                                    HStack {
                                        ProgressView()
                                        Text("Generating explanation...")
                                            .foregroundStyle(Color.secondaryText)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                } else if !clarificationText.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "sparkles")
                                                .foregroundStyle(Color.aiAccent)
                                            Text("AI Explanation")
                                                .font(.headline)
                                                .foregroundStyle(Color.primaryText)
                                        }

                                        Text(clarificationText)
                                            .font(.body)
                                            .foregroundStyle(Color.primaryText)
                                            .lineSpacing(4)
                                    }
                                    .padding()
                                    .glassPanel()
                                    .cornerRadius(12)
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    // Legacy fallback for iOS 25
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Original Flashcard
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Question")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondaryText)
                                    .textCase(.uppercase)

                                Text(currentCard.question)
                                    .font(.body)
                                    .foregroundStyle(Color.primaryText)

                                Divider()
                                    .padding(.vertical, 4)

                                Text("Answer")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondaryText)
                                    .textCase(.uppercase)

                                Text(currentCard.answer)
                                    .font(.body)
                                    .foregroundStyle(Color.aiAccent)
                            }
                            .padding()
                            .glassPanel()
                            .cornerRadius(12)

                            // AI Explanation
                            if isLoadingClarification {
                                HStack {
                                    ProgressView()
                                    Text("Generating explanation...")
                                        .foregroundStyle(Color.secondaryText)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            } else if !clarificationText.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .foregroundStyle(Color.aiAccent)
                                        Text("AI Explanation")
                                            .font(.headline)
                                            .foregroundStyle(Color.primaryText)
                                    }

                                    Text(clarificationText)
                                        .font(.body)
                                        .foregroundStyle(Color.primaryText)
                                        .lineSpacing(4)
                                }
                                .padding()
                                .glassPanel()
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Clarification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingClarification = false
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var currentCard: Flashcard {
        sessionCards[currentCardIndex]
    }

    // MARK: - Actions

    private func handleReview(_ response: SpacedRepetitionManager.ReviewResponse) {
        processResponse(response)
    }

    private func processResponse(_ response: SpacedRepetitionManager.ReviewResponse) {
        let card = currentCard

        spacedRepetitionManager.scheduleNextReview(for: card, response: response)

        sessionStats.totalCards += 1
        switch response {
        case .again:
            sessionStats.againCount += 1
            if !failedCards.contains(where: { $0.id == card.id }) {
                failedCards.append(card)
            }
        case .good:
            sessionStats.goodCount += 1
            failedCards.removeAll { $0.id == card.id }
        case .easy:
            sessionStats.easyCount += 1
            failedCards.removeAll { $0.id == card.id }
        }

        do {
            try modelContext.save()
        } catch {
            print("Error saving flashcard review: \(error)")
        }

        withAnimation(.spring(response: 0.4)) {
            if currentCardIndex < sessionCards.count - 1 {
                currentCardIndex += 1
                showAnswer = false
            } else {
                completeSession()
            }
        }
    }

    private func completeSession() {
        if !sessionRecorded {
            streakValue = StudyStreakManager.shared.recordSessionCompletion()
            sessionRecorded = true
        }
        showingSummary = true
    }

    private func retryMissedCards() {
        guard !failedCards.isEmpty else { return }

        withAnimation(.spring(response: 0.35)) {
            sessionCards = failedCards
            failedCards = []
            currentCardIndex = 0
            sessionStats = SessionStats()
            showAnswer = false
            showingSummary = false
        }
    }

    private func requestClarification() {
        isLoadingClarification = true
        showingClarification = true
        clarificationText = ""

        Task {
            do {
                let explanation = try await fmClient.clarifyFlashcard(
                    currentCard,
                    userQuestion: "Can you explain this answer in more detail?"
                )

                await MainActor.run {
                    clarificationText = explanation
                    isLoadingClarification = false
                }
            } catch {
                await MainActor.run {
                    clarificationText = "Unable to generate explanation. Please try again."
                    isLoadingClarification = false
                }
            }
        }
    }

}

// MARK: - Session Statistics

private struct SessionStats {
    var totalCards = 0
    var againCount = 0
    var goodCount = 0
    var easyCount = 0

    var successRate: Double {
        guard totalCards > 0 else { return 0 }
        return Double(goodCount + easyCount) / Double(totalCards)
    }
}

// MARK: - Preview

#Preview {
    let container = (try? ModelContainer(
        for: FlashcardSet.self, Flashcard.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )) ?? {
        try! ModelContainer(for: FlashcardSet.self, Flashcard.self)
    }()

    let set = FlashcardSet(topicLabel: "Travel", tag: "travel")

    let card1 = Flashcard(
        type: .cloze,
        question: "______ designed the Eiffel Tower.",
        answer: "Gustave Eiffel",
        linkedEntryID: UUID(),
        tags: ["travel"]
    )

    let card2 = Flashcard(
        type: .qa,
        question: "What is the capital of France?",
        answer: "Paris",
        linkedEntryID: UUID(),
        tags: ["travel"]
    )

    set.cards = [card1, card2]
    container.mainContext.insert(set)

    return FlashcardStudyView(flashcardSet: set, sessionTitle: nil, cards: [card1, card2])
        .modelContainer(container)
}
