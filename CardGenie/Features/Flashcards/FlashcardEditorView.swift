//
//  FlashcardEditorView.swift
//  CardGenie
//
//  Editor view for manually creating and editing flashcards.
//  Supports all card types with preview and validation.
//

import SwiftUI
import SwiftData

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
        // TODO: Show alert to get new deck name
        // For now, create a default one
        let newSet = FlashcardSet(topicLabel: "New Deck", tag: "new")
        modelContext.insert(newSet)
        selectedSet = newSet
        showingSetPicker = false
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
    let container = try! ModelContainer(
        for: FlashcardSet.self, Flashcard.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

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
