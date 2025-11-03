//
//  FlashcardEditorViews.swift
//  CardGenie
//
//  Flashcard editing, statistics, and handwriting editor.
//

import SwiftUI
import SwiftData
import PencilKit
import Charts

// MARK: - FlashcardEditorView


struct FlashcardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Mode: create new or edit existing
    enum Mode {
        case create
        case edit(Flashcard)
    }

    let mode: Mode
    let targetSet: FlashcardSet?

    // Form state
    @State private var cardType: FlashcardType = .qa
    @State private var question: String = ""
    @State private var answer: String = ""
    @State private var tags: [String] = []
    @State private var tagInput: String = ""
    @State private var selectedSet: FlashcardSet?

    // UI state
    @State private var showingPreview = false
    @State private var showingSetPicker = false
    @State private var showingValidationError = false
    @State private var validationMessage = ""
    @State private var showingNewSetAlert = false
    @State private var newSetName = ""

    @Query private var allSets: [FlashcardSet]
    @Query private var allCards: [Flashcard]

    // Existing tags for suggestions
    private var existingTags: [String] {
        let allTags = allCards.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }

    // Filtered tag suggestions based on input
    private var tagSuggestions: [String] {
        guard !tagInput.isEmpty else { return [] }
        return existingTags.filter {
            $0.localizedCaseInsensitiveContains(tagInput) && !tags.contains($0)
        }
    }

    init(mode: Mode = .create, targetSet: FlashcardSet? = nil) {
        self.mode = mode
        self.targetSet = targetSet
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Card Type Picker
                    cardTypePicker

                    // Question Field
                    questionField

                    // Answer Field
                    answerField

                    // Tags Section
                    tagsSection

                    // Set Selector
                    setSelector

                    // Preview Button
                    previewButton
                }
                .padding()
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCard()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingPreview) {
                previewSheet
            }
            .sheet(isPresented: $showingSetPicker) {
                setPickerSheet
            }
            .alert("Invalid Card", isPresented: $showingValidationError) {
                Button("OK") {}
            } message: {
                Text(validationMessage)
            }
            .alert("New Deck", isPresented: $showingNewSetAlert) {
                TextField("Deck Name", text: $newSetName)
                    .autocapitalization(.words)
                Button("Cancel", role: .cancel) {
                    newSetName = ""
                }
                Button("Create") {
                    confirmNewSet()
                }
                .disabled(newSetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Enter a name for your new flashcard deck")
            }
            .onAppear {
                loadInitialData()
            }
        }
    }

    // MARK: - Card Type Picker

    private var cardTypePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card Type")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            Picker("Card Type", selection: $cardType) {
                ForEach([FlashcardType.qa, .cloze, .definition], id: \.self) { type in
                    HStack {
                        Image(systemName: iconForType(type))
                        Text(displayName(for: type))
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .glassPanel()
        .cornerRadius(12)
    }

    // MARK: - Question Field

    private var questionField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(questionLabel)
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            Text(questionHint)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)

            TextField(questionPlaceholder, text: $question, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(Color.primaryText)
                .padding()
                .background(Color.primaryText.opacity(0.05))
                .cornerRadius(8)
                .lineLimit(5...10)
        }
        .padding()
        .glassPanel()
        .cornerRadius(12)
    }

    // MARK: - Answer Field

    private var answerField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(answerLabel)
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            Text(answerHint)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)

            TextField(answerPlaceholder, text: $answer, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(Color.primaryText)
                .padding()
                .background(Color.primaryText.opacity(0.05))
                .cornerRadius(8)
                .lineLimit(3...8)
        }
        .padding()
        .glassPanel()
        .cornerRadius(12)
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            // Current tags
            if !tags.isEmpty {
                TagFlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(text: tag)
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    removeTag(tag)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.tertiaryText)
                                }
                                .offset(x: 6, y: -6)
                            }
                    }
                }
            }

            // Tag input
            HStack {
                TextField("Add tag...", text: $tagInput)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(Color.primaryText)
                    .padding()
                    .background(Color.primaryText.opacity(0.05))
                    .cornerRadius(8)
                    .onSubmit {
                        addTag()
                    }

                Button {
                    addTag()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.aiAccent)
                        .font(.title3)
                }
                .disabled(tagInput.isEmpty)
            }

            // Tag suggestions
            if !tagSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggestions")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)

                    TagFlowLayout(spacing: 8) {
                        ForEach(tagSuggestions.prefix(5), id: \.self) { suggestion in
                            Button {
                                selectTag(suggestion)
                            } label: {
                                TagChip(text: suggestion)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .glassPanel()
        .cornerRadius(12)
    }

    // MARK: - Set Selector

    private var setSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deck")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            Button {
                showingSetPicker = true
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color.aiAccent)

                    Text(selectedSet?.topicLabel ?? "Select a deck...")
                        .foregroundStyle(selectedSet != nil ? Color.primaryText : Color.secondaryText)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .foregroundStyle(Color.tertiaryText)
                        .font(.caption)
                }
                .padding()
                .background(Color.primaryText.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding()
        .glassPanel()
        .cornerRadius(12)
    }

    // MARK: - Preview Button

    private var previewButton: some View {
        Button {
            showingPreview = true
        } label: {
            HStack {
                Image(systemName: "eye.fill")
                Text("Preview Card")
            }
            .font(.headline)
            .foregroundStyle(Color.aiAccent)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.aiAccent.opacity(0.1))
            .cornerRadius(12)
        }
        .disabled(!isValid)
    }

    // MARK: - Preview Sheet

    private var previewSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                FlashcardCardView(
                    flashcard: previewCard,
                    showAnswer: .constant(true)
                )

                Spacer()

                Text("This is how your card will appear during study")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingPreview = false
                    }
                }
            }
        }
    }

    // MARK: - Set Picker Sheet

    private var setPickerSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(allSets) { set in
                        Button {
                            selectedSet = set
                            showingSetPicker = false
                        } label: {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(Color.aiAccent)

                                VStack(alignment: .leading) {
                                    Text(set.topicLabel)
                                        .foregroundStyle(Color.primaryText)

                                    Text("\(set.cardCount) cards")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                }

                                Spacer()

                                if selectedSet?.id == set.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.aiAccent)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        createNewSet()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.aiAccent)
                            Text("Create New Deck")
                                .foregroundStyle(Color.aiAccent)
                        }
                    }
                }
            }
            .navigationTitle("Select Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingSetPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var navigationTitle: String {
        switch mode {
        case .create:
            return "New Flashcard"
        case .edit:
            return "Edit Flashcard"
        }
    }

    private var questionLabel: String {
        switch cardType {
        case .qa: return "Question"
        case .cloze: return "Sentence"
        case .definition: return "Term"
        }
    }

    private var questionHint: String {
        switch cardType {
        case .qa: return "Enter the question you want to ask"
        case .cloze: return "Use [...] to mark the part you want to hide"
        case .definition: return "Enter the term to define"
        }
    }

    private var questionPlaceholder: String {
        switch cardType {
        case .qa: return "What is the capital of France?"
        case .cloze: return "[...] is the capital of France"
        case .definition: return "Photosynthesis"
        }
    }

    private var answerLabel: String {
        switch cardType {
        case .qa: return "Answer"
        case .cloze: return "Hidden Word/Phrase"
        case .definition: return "Definition"
        }
    }

    private var answerHint: String {
        switch cardType {
        case .qa: return "Enter the correct answer"
        case .cloze: return "The word or phrase that fills the blank"
        case .definition: return "Explain what the term means"
        }
    }

    private var answerPlaceholder: String {
        switch cardType {
        case .qa: return "Paris"
        case .cloze: return "Paris"
        case .definition: return "The process by which plants convert light into energy"
        }
    }

    private var isValid: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedSet != nil
    }

    private var previewCard: Flashcard {
        Flashcard(
            type: cardType,
            question: question.isEmpty ? questionPlaceholder : question,
            answer: answer.isEmpty ? answerPlaceholder : answer,
            linkedEntryID: UUID(),
            tags: tags
        )
    }

    // MARK: - Actions

    private func loadInitialData() {
        switch mode {
        case .create:
            selectedSet = targetSet ?? allSets.first
        case .edit(let card):
            cardType = card.type
            question = card.question
            answer = card.answer
            tags = card.tags
            selectedSet = card.set
        }
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }

        tags.append(trimmed)
        tagInput = ""
    }

    private func selectTag(_ tag: String) {
        guard !tags.contains(tag) else { return }
        tags.append(tag)
        tagInput = ""
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    private func createNewSet() {
        showingNewSetAlert = true
    }

    private func confirmNewSet() {
        guard !newSetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let trimmedName = newSetName.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = trimmedName.lowercased().replacingOccurrences(of: " ", with: "-")
        let newSet = FlashcardSet(topicLabel: trimmedName, tag: tag)
        modelContext.insert(newSet)
        selectedSet = newSet
        showingSetPicker = false
        newSetName = ""
    }

    private func validateCard() -> Bool {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedQuestion.isEmpty {
            validationMessage = "Please enter a question"
            return false
        }

        if trimmedAnswer.isEmpty {
            validationMessage = "Please enter an answer"
            return false
        }

        if selectedSet == nil {
            validationMessage = "Please select a deck"
            return false
        }

        if cardType == .cloze && !question.contains("[...]") {
            validationMessage = "Cloze cards must contain [...] to mark the hidden part"
            return false
        }

        return true
    }

    private func saveCard() {
        guard validateCard() else {
            showingValidationError = true
            return
        }

        switch mode {
        case .create:
            createCard()
        case .edit(let card):
            updateCard(card)
        }

        dismiss()
    }

    private func createCard() {
        guard let set = selectedSet else { return }

        let card = Flashcard(
            type: cardType,
            question: question.trimmingCharacters(in: .whitespacesAndNewlines),
            answer: answer.trimmingCharacters(in: .whitespacesAndNewlines),
            linkedEntryID: UUID(), // No source entry for manual cards
            tags: tags
        )

        modelContext.insert(card)
        set.addCard(card)

        do {
            try modelContext.save()
        } catch {
            print("Error saving card: \(error)")
        }
    }

    private func updateCard(_ card: Flashcard) {
        // Preserve spaced repetition metadata
        card.type = cardType
        card.question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        card.answer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        card.tags = tags

        // Update set if changed
        if let newSet = selectedSet, card.set?.id != newSet.id {
            card.set?.cards.removeAll { $0.id == card.id }
            newSet.addCard(card)
        }

        do {
            try modelContext.save()
        } catch {
            print("Error updating card: \(error)")
        }
    }

    // MARK: - Helper Functions

    private func iconForType(_ type: FlashcardType) -> String {
        switch type {
        case .qa: return "questionmark.bubble"
        case .cloze: return "text.badge.star"
        case .definition: return "book"
        }
    }

    private func displayName(for type: FlashcardType) -> String {
        switch type {
        case .qa: return "Q&A"
        case .cloze: return "Cloze"
        case .definition: return "Definition"
        }
    }
}

// MARK: - Preview

#Preview("Create Mode") {
    FlashcardEditorView(mode: .create)
        .modelContainer(for: [FlashcardSet.self, Flashcard.self], inMemory: true)
}

#Preview("Edit Mode") {
    let container = (try? ModelContainer(
        for: FlashcardSet.self, Flashcard.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )) ?? {
        try! ModelContainer(for: FlashcardSet.self, Flashcard.self)
    }()

    let set = FlashcardSet(topicLabel: "Travel", tag: "travel")
    let card = Flashcard(
        type: .qa,
        question: "What is the capital of France?",
        answer: "Paris",
        linkedEntryID: UUID(),
        tags: ["geography", "europe"]
    )
    set.addCard(card)
    container.mainContext.insert(set)

    return FlashcardEditorView(mode: .edit(card))
        .modelContainer(container)
}

// MARK: - FlashcardStatisticsView


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

// MARK: - HandwritingEditorView


// MARK: - Handwriting Editor View

struct HandwritingEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let flashcard: Flashcard

    @State private var questionCanvas = PKCanvasView()
    @State private var answerCanvas = PKCanvasView()
    @State private var currentSide: CardSide = .question
    @State private var isProcessing = false
    @State private var showOCRText = false
    @State private var ocrText = ""

    enum CardSide {
        case question, answer
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Side Selector
                Picker("Side", selection: $currentSide) {
                    Text("Question").tag(CardSide.question)
                    Text("Answer").tag(CardSide.answer)
                }
                .pickerStyle(.segmented)
                .padding()

                // Canvas
                ZStack {
                    if currentSide == .question {
                        CanvasView(canvasView: $questionCanvas)
                    } else {
                        CanvasView(canvasView: $answerCanvas)
                    }

                    // Placeholder text
                    if currentCanvas.drawing.bounds.isEmpty {
                        VStack {
                            Image(systemName: "pencil.tip")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)

                            Text("Start writing with Apple Pencil")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Text(currentSide == .question ? "Write your question" : "Write your answer")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                        .allowsHitTesting(false)
                    }
                }

                Divider()

                // Toolbar
                HStack(spacing: 16) {
                    // Clear button
                    Button {
                        currentCanvas.drawing = PKDrawing()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    // OCR button
                    Button {
                        extractText()
                    } label: {
                        Label("Extract Text", systemImage: "text.viewfinder")
                    }
                    .buttonStyle(.bordered)
                    .disabled(currentCanvas.drawing.bounds.isEmpty)

                    // Save button
                    Button("Save") {
                        saveHandwriting()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(questionCanvas.drawing.bounds.isEmpty && answerCanvas.drawing.bounds.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Handwritten Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isProcessing {
                    ProgressView("Saving...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
            .sheet(isPresented: $showOCRText) {
                OCRResultView(text: ocrText, side: currentSide) {
                    if currentSide == .question {
                        flashcard.question = ocrText
                    } else {
                        flashcard.answer = ocrText
                    }
                    try? modelContext.save()
                    showOCRText = false
                }
            }
        }
        .onAppear {
            loadExistingDrawings()
        }
    }

    private var currentCanvas: PKCanvasView {
        currentSide == .question ? questionCanvas : answerCanvas
    }

    private func loadExistingDrawings() {
        guard let handwriting = flashcard.handwritingData else { return }

        if let qDrawing = try? handwriting.getQuestionDrawing() {
            questionCanvas.drawing = qDrawing
        }

        if let aDrawing = try? handwriting.getAnswerDrawing() {
            answerCanvas.drawing = aDrawing
        }
    }

    private func saveHandwriting() {
        isProcessing = true

        Task {
            let processor = HandwritingProcessor(modelContext: modelContext)

            let qDrawing = questionCanvas.drawing.bounds.isEmpty ? nil : questionCanvas.drawing
            let aDrawing = answerCanvas.drawing.bounds.isEmpty ? nil : answerCanvas.drawing

            do {
                try await processor.saveHandwriting(
                    for: flashcard,
                    questionDrawing: qDrawing,
                    answerDrawing: aDrawing
                )

                await MainActor.run {
                    isProcessing = false
                    dismiss()
                }
            } catch {
                print("Failed to save handwriting: \(error)")
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }

    private func extractText() {
        isProcessing = true

        Task {
            let drawing = currentCanvas.drawing
            _ = drawing.image(from: drawing.bounds, scale: 2.0)

            _ = HandwritingProcessor(modelContext: modelContext)

            // For now, just show placeholder
            ocrText = "OCR text will appear here"

            await MainActor.run {
                isProcessing = false
                showOCRText = true
            }
        }
    }
}

// MARK: - Canvas View Wrapper

struct CanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 3)
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .systemBackground
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Update if needed
    }
}

// MARK: - OCR Result View

struct OCRResultView: View {
    let text: String
    let side: HandwritingEditorView.CardSide
    let onAccept: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Extracted Text")
                    .font(.headline)

                ScrollView {
                    Text(text)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }

                Text("Use this text for the \(side == .question ? "question" : "answer")?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button("Use Text") {
                        onAccept()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = (try? ModelContainer(for: Flashcard.self, configurations: config)) ?? {
        try! ModelContainer(for: Flashcard.self)
    }()

    let card = Flashcard(
        type: .qa,
        question: "Test Question",
        answer: "Test Answer",
        linkedEntryID: UUID()
    )

    return HandwritingEditorView(flashcard: card)
        .modelContainer(container)
}
