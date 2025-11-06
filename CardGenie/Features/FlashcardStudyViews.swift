//
//  FlashcardStudyViews.swift
//  CardGenie
//
//  Flashcard study sessions, list, session builder, and results.
//

import SwiftUI
import SwiftData

// MARK: - FlashcardListView


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
                    VStack(spacing: Spacing.lg) {
                        GlassSearchBar(text: $searchText, placeholder: "Search flashcard sets")
                            .padding(.horizontal)

                        flashcardsEmptyState
                    }
                    .padding(.top, Spacing.xl)
                } else if totalDueCount == 0 && hasFlashcards {
                    // All caught up state
                    allCaughtUpState
                } else {
                    mainContent
                }
            }
            .navigationTitle("Flashcards")
            .toolbar {
                // iOS 26: Settings button on leading edge
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.cosmicPurple)
                    }
                }

                // iOS 26: Grouped trailing buttons - automatic glass grouping for image buttons
                if !flashcardSets.isEmpty {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            showingStatistics = true
                        } label: {
                            Image(systemName: "chart.bar.fill")
                                .foregroundStyle(Color.aiAccent)
                        }

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
                FlashcardStatisticsView()
            }
        }
    }

    // MARK: - Empty States

    private var hasFlashcards: Bool {
        flashcardSets.contains { $0.cardCount > 0 }
    }

    private var flashcardsEmptyState: some View {
        EmptyStateView(
            icon: "rectangle.stack.badge.plus",
            title: "No Flashcards Yet",
            description: "Create your first flashcards by generating them from your study materials or creating them manually.",
            primaryAction: .init(
                title: "Generate from Content",
                icon: "sparkles",
                action: {
                    // Navigate to Study tab
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToStudyTab"), object: nil)
                }
            ),
            secondaryAction: .init(
                title: "Create Manually",
                icon: "plus.circle",
                action: {
                    // Create a default set and open editor
                    createDefaultSetAndCard()
                }
            )
        )
    }

    private var allCaughtUpState: some View {
        EmptyStateView(
            icon: "checkmark.seal.fill",
            title: "All Caught Up! 🎉",
            description: "You've reviewed all your due cards. Great job keeping up with your studies! Your next review will be ready soon.",
            primaryAction: .init(
                title: "Review All Cards",
                icon: "arrow.triangle.2.circlepath",
                action: {
                    studyAllDueCards()
                }
            ),
            secondaryAction: .init(
                title: "View Statistics",
                icon: "chart.bar",
                action: {
                    showingStatistics = true
                }
            )
        )
    }

    private func createDefaultSetAndCard() {
        // Create a default flashcard set if needed
        let defaultSet = FlashcardSet(topicLabel: "My Flashcards", tag: "default")
        modelContext.insert(defaultSet)

        // Create an empty flashcard
        let newCard = Flashcard(
            type: .qa,
            question: "",
            answer: "",
            linkedEntryID: UUID(),
            tags: []
        )
        modelContext.insert(newCard)
        defaultSet.addCard(newCard)

        do {
            try modelContext.save()
        } catch {
            print("Error creating default set: \(error)")
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if #available(iOS 26.0, *) {
            ScrollView {
                // Wrap all glass elements in GlassEffectContainer to prevent glass-on-glass sampling
                GlassEffectContainer {
                    VStack(spacing: 24) {
                        GlassSearchBar(text: $searchText, placeholder: "Search flashcard sets")

                        // Study Suggestion Banner - shows when 5+ cards due
                        if totalDueCount >= 5 {
                            studySuggestionBanner
                        }

                        // Quick Play Section - NEW!
                        if !flashcardSets.isEmpty {
                            quickPlaySection
                        }

                        // Daily Review Section
                        if totalDueCount > 0 {
                            dailyReviewSection
                        }

                        // Statistics Summary
                        statisticsSection

                        // Flashcard Sets List
                        flashcardSetsSection
                    }
                    .padding(.horizontal)
                    .padding(.vertical, Spacing.lg)
                }
            }
        } else {
            // Legacy fallback for iOS 25
            ScrollView {
                VStack(spacing: 24) {
                    GlassSearchBar(text: $searchText, placeholder: "Search flashcard sets")

                    // Study Suggestion Banner - shows when 5+ cards due
                    if totalDueCount >= 5 {
                        studySuggestionBanner
                    }

                    // Quick Play Section - NEW!
                    if !flashcardSets.isEmpty {
                        quickPlaySection
                    }

                    // Daily Review Section
                    if totalDueCount > 0 {
                        dailyReviewSection
                    }

                    // Statistics Summary
                    statisticsSection

                    // Flashcard Sets List
                    flashcardSetsSection
                }
                .padding(.horizontal)
                .padding(.vertical, Spacing.lg)
            }
        }
    }

    // MARK: - Study Suggestion Banner

    private var studySuggestionBanner: some View {
        HStack(spacing: 16) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.cosmicPurple.opacity(0.2), Color.mysticBlue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: "lightbulb.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cosmicPurple, .mysticBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse, options: .repeating)
            }

            // Message
            VStack(alignment: .leading, spacing: 4) {
                Text("Ready to study?")
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)

                Text("You have \(totalDueCount) cards due - Start studying to keep your knowledge fresh!")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            // Quick action button
            Button {
                studyAllDueCards()
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.cosmicPurple)
            }
        }
        .padding()
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.cosmicPurple.opacity(0.08), Color.mysticBlue.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.cosmicPurple.opacity(0.08), Color.mysticBlue.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.cosmicPurple.opacity(0.3), Color.mysticBlue.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
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
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent) // Prominent button style
            .tint(.aiAccent)
            .controlSize(.large)
        }
        .padding()
        .glassPanel()
        .cornerRadius(16)
    }

    // MARK: - Quick Play Section

    private var quickPlaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                    )
                    .font(.title2)

                Text("Quick Play")
                    .font(.title3.bold())
                    .foregroundStyle(Color.primaryText)

                Spacer()

                Text("\(flashcardSets.count) sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Jump straight into games with any flashcard set")
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)

            // Game mode buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    QuickGameButton(
                        mode: .matching,
                        flashcardSets: flashcardSets,
                        onTap: { set in
                            quickStartGame(.matching, for: set)
                        }
                    )

                    QuickGameButton(
                        mode: .trueFalse,
                        flashcardSets: flashcardSets,
                        onTap: { set in
                            quickStartGame(.trueFalse, for: set)
                        }
                    )

                    QuickGameButton(
                        mode: .multipleChoice,
                        flashcardSets: flashcardSets,
                        onTap: { set in
                            quickStartGame(.multipleChoice, for: set)
                        }
                    )

                    QuickGameButton(
                        mode: .teachBack,
                        flashcardSets: flashcardSets,
                        onTap: { set in
                            quickStartGame(.teachBack, for: set)
                        }
                    )

                    QuickGameButton(
                        mode: .feynman,
                        flashcardSets: flashcardSets,
                        onTap: { set in
                            quickStartGame(.feynman, for: set)
                        }
                    )
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.08), Color.cyan.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(colors: [.blue.opacity(0.3), .cyan.opacity(0.2)], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 2
                )
        )
        .cornerRadius(20)
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
                VStack(spacing: Spacing.sm) {
                    Text(searchText.isEmpty ? "No flashcard sets found" : "No results for “\(searchText)”")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)

                    if searchText.isEmpty {
                        Text("Create a set to get started with your study queue.")
                            .font(.caption)
                            .foregroundStyle(Color.tertiaryText)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .glassPanel()
                .cornerRadius(16)
            } else {
                ForEach(filteredSets) { set in
                    NavigationLink {
                        FlashcardSetDetailView(flashcardSet: set)
                    } label: {
                        FlashcardSetRow(set: set)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            startStudySession(for: set)
                        } label: {
                            Label("Study Now", systemImage: "play.fill")
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

    private func quickStartGame(_ mode: StudyGameMode, for set: FlashcardSet) {
        // Store the selected game mode and flashcard set for navigation
        // This will be handled by the QuickGameButton's NavigationLink
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

// MARK: - Quick Game Button Component

private struct QuickGameButton: View {
    let mode: StudyGameMode
    let flashcardSets: [FlashcardSet]
    let onTap: (FlashcardSet) -> Void

    @State private var showingSetPicker = false
    @State private var selectedSet: FlashcardSet?

    var body: some View {
        Button {
            if flashcardSets.count == 1 {
                // Auto-select if only one set
                if let set = flashcardSets.first {
                    selectedSet = set
                }
            } else {
                showingSetPicker = true
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(mode.color).opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: mode.icon)
                        .font(.title2)
                        .foregroundStyle(Color(mode.color))
                }

                Text(mode.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 90)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(mode.color).opacity(0.3), lineWidth: 2)
            )
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .confirmationDialog("Choose a flashcard set", isPresented: $showingSetPicker) {
            ForEach(flashcardSets) { set in
                Button(set.topicLabel) {
                    selectedSet = set
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .navigationDestination(item: $selectedSet) { set in
            gameModeView(for: mode, with: set)
        }
    }

    @ViewBuilder
    func gameModeView(for mode: StudyGameMode, with set: FlashcardSet) -> some View {
        switch mode {
        case .matching:
            MatchingGameView(flashcardSet: set)
        case .trueFalse:
            TrueFalseGameView(flashcardSet: set)
        case .multipleChoice:
            MultipleChoiceGameView(flashcardSet: set)
        case .teachBack:
            TeachBackGameView(flashcardSet: set)
        case .feynman:
            FeynmanGameView(flashcardSet: set)
        }
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

// MARK: - FlashcardStudyView


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
            // Heavy haptic feedback for reveal action
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()

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
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.aiAccent)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.aiAccent)
                }
            }
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

// MARK: - SessionBuilderView


struct SessionBuilderView: View {
    @Environment(\.dismiss) private var dismiss

    let flashcardSet: FlashcardSet
    let onStart: (SessionConfiguration) -> Void

    // Session configuration
    @State private var mode: SessionMode = .mixed
    @State private var maxNew: Int = 5
    @State private var maxReview: Int = 20
    @State private var includeNew: Bool = true
    @State private var includeReview: Bool = true

    @AppStorage("defaultSessionMode") private var defaultMode: String = "mixed"
    @AppStorage("defaultMaxNew") private var defaultMaxNew: Int = 5
    @AppStorage("defaultMaxReview") private var defaultMaxReview: Int = 20

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Set Info
                    setInfoSection

                    // Mode Selector
                    modeSelector

                    // Custom Settings (only for Custom mode)
                    if mode == .custom {
                        customSettings
                    }

                    // Estimated Time
                    estimatedTimeSection

                    // Quick Start Note
                    quickStartNote
                }
                .padding()
            }
            .navigationTitle("Session Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        startSession()
                    }
                    .fontWeight(.semibold)
                    .disabled(cardCount == 0)
                }
            }
            .onAppear {
                loadDefaults()
            }
        }
    }

    // MARK: - Set Info Section

    private var setInfoSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .font(.title)
                    .foregroundStyle(Color.aiAccent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(flashcardSet.topicLabel)
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)

                    HStack(spacing: 12) {
                        Label("\(flashcardSet.newCount) new", systemImage: "sparkles")
                            .font(.caption)
                            .foregroundStyle(Color.aiAccent)

                        Label("\(flashcardSet.dueCount - flashcardSet.newCount) review", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(Color.warning)
                    }
                }

                Spacer()
            }
            .padding()
            .glassPanel()
            .cornerRadius(16)
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Mode")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            VStack(spacing: 12) {
                ModeOption(
                    mode: .newOnly,
                    selectedMode: $mode,
                    icon: "sparkles",
                    title: "New Cards Only",
                    description: "Focus on learning new material",
                    count: flashcardSet.newCount
                )

                ModeOption(
                    mode: .reviewOnly,
                    selectedMode: $mode,
                    icon: "arrow.clockwise",
                    title: "Review Only",
                    description: "Practice cards you've already seen",
                    count: flashcardSet.dueCount - flashcardSet.newCount
                )

                ModeOption(
                    mode: .mixed,
                    selectedMode: $mode,
                    icon: "shuffle",
                    title: "Mixed (Recommended)",
                    description: "Balance of new cards and reviews",
                    count: min(maxNew, flashcardSet.newCount) + min(maxReview, flashcardSet.dueCount - flashcardSet.newCount)
                )

                ModeOption(
                    mode: .custom,
                    selectedMode: $mode,
                    icon: "slider.horizontal.3",
                    title: "Custom",
                    description: "Configure your own limits",
                    count: cardCount
                )
            }
        }
    }

    // MARK: - Custom Settings

    private var customSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Custom Settings")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            VStack(spacing: 24) {
                // New cards toggle and slider
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $includeNew) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.aiAccent)
                            Text("Include New Cards")
                                .foregroundStyle(Color.primaryText)
                        }
                    }
                    .tint(Color.aiAccent)

                    if includeNew {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Max New Cards")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondaryText)

                                Spacer()

                                Text("\(maxNew)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.aiAccent)
                            }

                            Slider(value: Binding(
                                get: { Double(maxNew) },
                                set: { maxNew = Int($0) }
                            ), in: 1...Double(max(flashcardSet.newCount, 1)), step: 1)
                                .tint(Color.aiAccent)
                        }
                    }
                }
                .padding()
                .glassPanel()
                .cornerRadius(12)

                // Review cards toggle and slider
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $includeReview) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(Color.warning)
                            Text("Include Review Cards")
                                .foregroundStyle(Color.primaryText)
                        }
                    }
                    .tint(Color.aiAccent)

                    if includeReview {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Max Review Cards")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondaryText)

                                Spacer()

                                Text("\(maxReview)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.warning)
                            }

                            Slider(value: Binding(
                                get: { Double(maxReview) },
                                set: { maxReview = Int($0) }
                            ), in: 1...Double(max(flashcardSet.dueCount - flashcardSet.newCount, 1)), step: 1)
                                .tint(Color.warning)
                        }
                    }
                }
                .padding()
                .glassPanel()
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Estimated Time Section

    private var estimatedTimeSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(Color.aiAccent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Time")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)

                    Text(estimatedTime)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.primaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Cards")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)

                    Text("\(cardCount)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.aiAccent)
                }
            }
            .padding()
            .glassPanel()
            .cornerRadius(16)
        }
    }

    // MARK: - Quick Start Note

    private var quickStartNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.aiAccent)

            Text("Your preferences will be saved for future sessions")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)

            Spacer()
        }
        .padding()
        .background(Color.aiAccent.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    private var cardCount: Int {
        switch mode {
        case .newOnly:
            return min(flashcardSet.newCount, 20)
        case .reviewOnly:
            return min(flashcardSet.dueCount - flashcardSet.newCount, 25)
        case .mixed:
            let newCount = min(maxNew, flashcardSet.newCount)
            let reviewCount = min(maxReview, flashcardSet.dueCount - flashcardSet.newCount)
            return newCount + reviewCount
        case .custom:
            var count = 0
            if includeNew {
                count += min(maxNew, flashcardSet.newCount)
            }
            if includeReview {
                count += min(maxReview, flashcardSet.dueCount - flashcardSet.newCount)
            }
            return count
        }
    }

    private var estimatedTime: String {
        let minutes = (cardCount * 30) / 60 // 30 seconds per card
        if minutes < 1 {
            return "< 1 min"
        } else if minutes == 1 {
            return "1 min"
        } else {
            return "\(minutes) mins"
        }
    }

    // MARK: - Actions

    private func loadDefaults() {
        if let savedMode = SessionMode(rawValue: defaultMode) {
            mode = savedMode
        }
        maxNew = defaultMaxNew
        maxReview = defaultMaxReview
    }

    private func saveDefaults() {
        defaultMode = mode.rawValue
        defaultMaxNew = maxNew
        defaultMaxReview = maxReview
    }

    private func startSession() {
        saveDefaults()

        let config = SessionConfiguration(
            mode: mode,
            maxNew: mode == .custom ? (includeNew ? maxNew : 0) : maxNew,
            maxReview: mode == .custom ? (includeReview ? maxReview : 0) : maxReview
        )

        onStart(config)
        dismiss()
    }
}

// MARK: - Mode Option Component

private struct ModeOption: View {
    let mode: SessionMode
    @Binding var selectedMode: SessionMode
    let icon: String
    let title: String
    let description: String
    let count: Int

    private var isSelected: Bool {
        selectedMode == mode
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedMode = mode
            }
        } label: {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.aiAccent : Color.secondaryText)
                    .frame(width: 40)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }

                Spacer()

                // Card count
                VStack(spacing: 2) {
                    Text("\(count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(isSelected ? Color.aiAccent : Color.primaryText)

                    Text("cards")
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryText)
                }

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.aiAccent)
                        .font(.title3)
                }
            }
            .padding()
            .background(isSelected ? Color.aiAccent.opacity(0.1) : Color.clear)
            .glassPanel()
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.aiAccent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Mode

enum SessionMode: String, Codable, CaseIterable {
    case newOnly = "new"
    case reviewOnly = "review"
    case mixed = "mixed"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .newOnly: return "New Only"
        case .reviewOnly: return "Review Only"
        case .mixed: return "Mixed"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Session Configuration

struct SessionConfiguration {
    let mode: SessionMode
    let maxNew: Int
    let maxReview: Int

    func getCards(from set: FlashcardSet, manager: SpacedRepetitionManager) -> [Flashcard] {
        switch mode {
        case .newOnly:
            return Array(set.getNewCards().prefix(20))
        case .reviewOnly:
            let dueCards = set.getDueCards().filter { !$0.isNew }
            return Array(dueCards.prefix(25))
        case .mixed, .custom:
            return manager.getStudySession(from: set, maxNew: maxNew, maxReview: maxReview)
        }
    }
}

// MARK: - Preview

#Preview {
    let set = FlashcardSet(topicLabel: "Spanish Vocabulary", tag: "spanish")

    // Add mock cards
    for i in 1...15 {
        let card = Flashcard(
            type: .qa,
            question: "Question \(i)",
            answer: "Answer \(i)",
            linkedEntryID: UUID()
        )
        if i <= 5 {
            card.nextReviewDate = Date() // Due
        } else {
            card.reviewCount = 1 // Not new
            card.nextReviewDate = Date().addingTimeInterval(86400) // Not due
        }
        set.addCard(card)
    }

    return SessionBuilderView(flashcardSet: set) { config in
        print("Starting session with config: \(config)")
    }
}

// MARK: - StudyResultsView


struct StudyResultsView: View {
    let correct: Int
    let total: Int
    let streak: Int
    let missedCount: Int
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void

    // Animation state
    @State private var animatedProgress: Double = 0
    @State private var animatedPercent: Int = 0
    @State private var isAppearing = false

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
                // Celebration Icon with milestone celebrations
                celebrationIconWithMilestones

                // Performance Message
                performanceMessage

                // Milestone Achievements Banner
                if hasMilestone {
                    milestoneAchievementsBanner
                }

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

    // MARK: - Milestone Detection

    private var hasMilestone: Bool {
        isPerfectSession || isLargeSession || isWeekStreak
    }

    private var isPerfectSession: Bool {
        accuracyPercent == 100 && total >= 5
    }

    private var isLargeSession: Bool {
        total >= 10
    }

    private var isWeekStreak: Bool {
        streak >= 7
    }

    // MARK: - Celebration Icon

    private var celebrationIcon: some View {
        Image(systemName: performanceLevel.icon)
            .font(.system(size: 80))
            .foregroundStyle(performanceLevel.color.gradient)
            .symbolEffect(.bounce)
    }

    private var celebrationIconWithMilestones: some View {
        ZStack {
            celebrationIcon
        }
        .modifier(MilestoneCelebrationModifier(showConfetti: hasMilestone))
    }

    // MARK: - Milestone Achievements Banner

    private var milestoneAchievementsBanner: some View {
        VStack(spacing: 12) {
            // Banner header
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color.magicGold)
                Text("Milestone Achieved!")
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)
                Image(systemName: "star.fill")
                    .foregroundStyle(Color.magicGold)
            }

            // Milestone badges
            VStack(spacing: 8) {
                if isPerfectSession {
                    MilestoneBadge(
                        icon: "checkmark.seal.fill",
                        title: "Perfect Session",
                        description: "100% accuracy!",
                        color: .success
                    )
                }

                if isLargeSession {
                    MilestoneBadge(
                        icon: "bolt.fill",
                        title: "Study Champion",
                        description: "Completed \(total) cards in one session!",
                        color: .cosmicPurple
                    )
                }

                if isWeekStreak {
                    MilestoneBadge(
                        icon: "flame.fill",
                        title: "Week Warrior",
                        description: "\(streak) day study streak!",
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.magicGold.opacity(0.1), Color.cosmicPurple.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.magicGold.opacity(0.1), Color.cosmicPurple.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.magicGold.opacity(0.3), lineWidth: 2)
        )
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

                // Progress circle with animated progress
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        performanceLevel.color.gradient,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))

                // Percentage text with count-up animation
                VStack(spacing: 4) {
                    Text("\(animatedPercent)%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primaryText)
                        .contentTransition(.numericText())

                    Text("Accuracy")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .scaleEffect(isAppearing ? 1.0 : 0.8)
            .opacity(isAppearing ? 1.0 : 0.0)

            Text(performanceLevel.accuracyFeedback)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .glassPanel()
        .cornerRadius(20)
        .onAppear {
            // Trigger animations on appearance
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                isAppearing = true
            }

            withAnimation(.spring(response: 1.8, dampingFraction: 0.75).delay(0.3)) {
                animatedProgress = accuracy
            }

            withAnimation(.spring(response: 1.5, dampingFraction: 0.8).delay(0.3)) {
                animatedPercent = accuracyPercent
            }
        }
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

    @State private var animatedValue: Int = 0
    @State private var isAppearing = false

    private var numericValue: Int? {
        Int(value)
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .scaleEffect(isAppearing ? 1.0 : 0.5)
                .opacity(isAppearing ? 1.0 : 0.0)

            if numericValue != nil {
                Text("\(animatedValue)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primaryText)
                    .contentTransition(.numericText())
            } else {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primaryText)
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassPanel()
        .cornerRadius(12)
        .scaleEffect(isAppearing ? 1.0 : 0.8)
        .opacity(isAppearing ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isAppearing = true
            }

            if let targetValue = numericValue {
                withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2)) {
                    animatedValue = targetValue
                }
            }
        }
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

// MARK: - Flashcard Set Detail View

struct FlashcardSetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let flashcardSet: FlashcardSet

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero Statistics Card
                statsHeroCard

                // Feature Cards
                VStack(spacing: 16) {
                    Text("Choose Your Learning Mode")
                        .font(.title3.bold())
                        .foregroundStyle(Color.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Study Mode Card
                    FeatureCard(
                        title: "Study Session",
                        subtitle: "Traditional Review",
                        description: "Spaced repetition flashcard study",
                        icon: "play.circle.fill",
                        gradient: [Color.cosmicPurple, Color.cosmicPurple.opacity(0.7)]
                    ) {
                        SessionBuilderView(flashcardSet: flashcardSet) { _ in }
                    }

                    // Game Modes Card - HIGHLIGHTED
                    FeatureCard(
                        title: "🎮 Game Modes",
                        subtitle: "5 Fun Ways to Learn",
                        description: "Matching, Quiz, Teach-Back & More",
                        icon: "gamecontroller.fill",
                        gradient: [Color.blue, Color.cyan],
                        destination: {
                            GameModeSelectionView(flashcardSet: flashcardSet)
                        },
                        isHighlighted: true
                    )

                    // AI Tutoring Card
                    FeatureCard(
                        title: "🧠 AI Tutoring",
                        subtitle: "Conversational Learning",
                        description: "Socratic Tutor, Debate, Explain-to-AI",
                        icon: "brain.head.profile",
                        gradient: [Color.orange, Color.red]
                    ) {
                        ConversationalLearningView(flashcardSet: flashcardSet)
                    }

                    // Voice Tutor Card
                    FeatureCard(
                        title: "🎙️ Voice Tutor",
                        subtitle: "Streaming Voice Chat",
                        description: "Real-time conversations with AI tutor",
                        icon: "waveform.circle.fill",
                        gradient: [Color.green, Color.cyan]
                    ) {
                        let context = ConversationContext(
                            flashcardSet: flashcardSet,
                            recentFlashcards: Array(flashcardSet.cards.prefix(10))
                        )
                        VoiceAssistantView(context: context)
                    }

                    // Practice Generator Card
                    FeatureCard(
                        title: "⚡ Practice Generator",
                        subtitle: "AI-Powered Content",
                        description: "Problems, Scenarios, Connections",
                        icon: "wand.and.stars",
                        gradient: [Color.green, Color.green.opacity(0.8)]
                    ) {
                        ContentGenerationView(flashcardSet: flashcardSet)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(flashcardSet.topicLabel)
        .navigationBarTitleDisplayMode(.large)
    }

    private var statsHeroCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                StatPill(label: "Total", value: "\(flashcardSet.cardCount)", color: .blue)
                StatPill(label: "Due", value: "\(flashcardSet.dueCount)", color: .red)
                StatPill(label: "New", value: "\(flashcardSet.newCount)", color: .purple)
            }

            HStack {
                Text("Success Rate")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", flashcardSet.successRate * 100))
                    .font(.title2.bold())
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        )
    }
}

struct FeatureCard<Destination: View>: View {
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let gradient: [Color]
    @ViewBuilder let destination: () -> Destination
    var isHighlighted: Bool = false

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .cornerRadius(12)

                    Spacer()

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(20)
            .background(
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(20)
            .shadow(color: gradient[0].opacity(0.3), radius: 12, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isHighlighted ? Color.white.opacity(0.5) : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isHighlighted ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle). \(description)")
        .accessibilityHint("Double tap to open")
        .accessibilityAddTraits(.isButton)
    }
}

struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ModeRow: View {
    let title: String
    let icon: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Milestone Celebration Modifier

struct MilestoneCelebrationModifier: ViewModifier {
    let showConfetti: Bool

    func body(content: Content) -> some View {
        if showConfetti {
            content
                .confetti()
        } else {
            content
        }
    }
}

// MARK: - Milestone Badge

struct MilestoneBadge: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primaryText)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }

            Spacer()

            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(color)
                .font(.title3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.05))
        .cornerRadius(12)
    }
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
