//
//  ScanReviewView.swift
//  CardGenie
//
//  Review and organize scanned text before flashcard generation.
//  Allows editing, section management, and topic tagging.
//

import SwiftUI
import SwiftData

/// A section of extracted text with metadata
struct TextSection: Identifiable, Codable {
    let id: UUID
    var text: String
    var type: SectionType
    var isSelected: Bool

    init(id: UUID = UUID(), text: String, type: SectionType = .paragraph, isSelected: Bool = true) {
        self.id = id
        self.text = text
        self.type = type
        self.isSelected = isSelected
    }
}

enum SectionType: String, Codable, CaseIterable {
    case heading
    case paragraph
    case list
    case definition
    case equation

    var icon: String {
        switch self {
        case .heading: return "text.alignleft"
        case .paragraph: return "text.justify"
        case .list: return "list.bullet"
        case .definition: return "book.closed"
        case .equation: return "function"
        }
    }

    var color: Color {
        switch self {
        case .heading: return .purple
        case .paragraph: return .blue
        case .list: return .green
        case .definition: return .orange
        case .equation: return .red
        }
    }
}

/// Review and organize scanned text before generating flashcards
struct ScanReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let extractedText: String
    let images: [UIImage]
    let isMultiPage: Bool
    let extractionResult: TextExtractionResult?

    @State private var sections: [TextSection] = []
    @State private var selectedTopic: String = ""
    @State private var selectedDeck: String = ""
    @State private var editingSection: TextSection?
    @State private var showTopicPicker = false
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showError = false

    @StateObject private var fmClient = FMClient()

    // Common topics for quick selection
    private let suggestedTopics = [
        "Biology", "Chemistry", "Physics", "Mathematics",
        "History", "Geography", "Literature", "Computer Science",
        "Medicine", "Psychology", "Economics", "Engineering"
    ]

    init(extractedText: String, images: [UIImage] = [], isMultiPage: Bool = false, extractionResult: TextExtractionResult? = nil) {
        self.extractedText = extractedText
        self.images = images
        self.isMultiPage = isMultiPage
        self.extractionResult = extractionResult
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Scan info header
                    scanInfoHeader

                    // Topic and deck selection
                    topicSelectionSection

                    // Sections list
                    sectionsListView

                    // Generate button
                    generateButton
                }
                .padding()
            }
            .navigationTitle("Review & Organize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $editingSection) { section in
                SectionEditorView(section: Binding(
                    get: { section },
                    set: { updated in
                        if let index = sections.firstIndex(where: { $0.id == section.id }) {
                            sections[index] = updated
                        }
                    }
                ))
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
        .onAppear {
            analyzeSections()
        }
    }

    // MARK: - View Components

    private var scanInfoHeader: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Image(systemName: isMultiPage ? "doc.text" : "doc.plaintext")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.magicGradient)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isMultiPage ? "\(images.count) Pages Scanned" : "Single Page Scan")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.primaryText)

                    Text("\(extractedText.count) characters • \(sections.count) sections")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondaryText)

                    if let result = extractionResult {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                            Text("\(result.confidenceLevel.rawValue) Confidence")
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                        }
                        .foregroundColor(confidenceColor(for: result.confidenceLevel))
                    }
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color.cosmicPurple.opacity(0.1))
            )
        }
    }

    private var topicSelectionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Organization")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundColor(.primaryText)
                .textCase(.uppercase)

            // Topic field
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Topic")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondaryText)

                TextField("e.g., Cell Biology, World War II", text: $selectedTopic)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .rounded))
            }

            // Suggested topics
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(suggestedTopics, id: \.self) { topic in
                        Button(topic) {
                            selectedTopic = topic
                            HapticFeedback.light()
                        }
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(selectedTopic == topic ? Color.cosmicPurple : Color.cosmicPurple.opacity(0.1))
                        )
                        .foregroundColor(selectedTopic == topic ? .white : .cosmicPurple)
                    }
                }
            }

            // Deck field (optional)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Deck (Optional)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondaryText)

                TextField("Add to specific deck", text: $selectedDeck)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .rounded))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.cosmicPurple.opacity(0.05))
        )
    }

    private var sectionsListView: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Text Sections")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primaryText)
                    .textCase(.uppercase)

                Spacer()

                Text("\(sections.filter(\.isSelected).count)/\(sections.count) selected")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondaryText)
            }

            ForEach($sections) { $section in
                SectionRowView(
                    section: $section,
                    onEdit: {
                        editingSection = section
                    },
                    onDelete: {
                        withAnimation {
                            sections.removeAll { $0.id == section.id }
                        }
                    }
                )
            }

            // Add section button
            Button {
                let newSection = TextSection(text: "", type: .paragraph, isSelected: true)
                sections.append(newSection)
                editingSection = newSection
            } label: {
                Label("Add Section", systemImage: "plus.circle")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.cosmicPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .strokeBorder(Color.cosmicPurple, lineWidth: 1.5, antialiased: true)
                    )
            }
        }
    }

    private var generateButton: some View {
        HapticButton(hapticStyle: .heavy) {
            generateFlashcards()
        } label: {
            HStack {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                    Text("Generating...")
                } else {
                    Image(systemName: "sparkles")
                    Text("Generate Flashcards")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(MagicButtonStyle())
        .disabled(isGenerating || sections.filter(\.isSelected).isEmpty || selectedTopic.isEmpty)
    }

    // MARK: - Helper Functions

    private func analyzeSections() {
        // Parse extracted text into logical sections
        let lines = extractedText.components(separatedBy: "\n")
        var currentSection = ""
        var detectedSections: [TextSection] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                // Empty line - end current section
                if !currentSection.isEmpty {
                    detectedSections.append(
                        TextSection(
                            text: currentSection.trimmingCharacters(in: .whitespacesAndNewlines),
                            type: detectSectionType(currentSection)
                        )
                    )
                    currentSection = ""
                }
            } else {
                currentSection += line + "\n"
            }
        }

        // Add final section if any
        if !currentSection.isEmpty {
            detectedSections.append(
                TextSection(
                    text: currentSection.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: detectSectionType(currentSection)
                )
            )
        }

        sections = detectedSections.isEmpty ? [TextSection(text: extractedText, type: .paragraph)] : detectedSections
    }

    private func detectSectionType(_ text: String) -> SectionType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: "\n")

        // Check for heading (short, all caps, or ends with colon)
        if lines.count == 1 {
            if trimmed.count < 60 && (trimmed == trimmed.uppercased() || trimmed.hasSuffix(":")) {
                return .heading
            }
        }

        // Check for list (multiple lines starting with bullets or numbers)
        let bulletPatterns = ["•", "-", "*", "◦"]
        let listLines = lines.filter { line in
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            return bulletPatterns.contains(where: { trimmedLine.hasPrefix($0) }) ||
                   trimmedLine.range(of: "^\\d+\\.", options: .regularExpression) != nil
        }
        if listLines.count >= 2 {
            return .list
        }

        // Check for definition (contains "is", "are", "means", "refers to")
        if trimmed.contains(":") || trimmed.range(of: "\\b(is|are|means|refers to|defined as)\\b", options: .regularExpression) != nil {
            return .definition
        }

        // Check for equation (contains mathematical symbols)
        if trimmed.range(of: "[=+\\-×÷∫∑√]", options: .regularExpression) != nil {
            return .equation
        }

        return .paragraph
    }

    private func confidenceColor(for level: ConfidenceLevel) -> Color {
        switch level {
        case .high: return .genieGreen
        case .medium: return .yellow
        case .low: return .orange
        case .veryLow: return .red
        }
    }

    private func generateFlashcards() {
        guard !sections.filter(\.isSelected).isEmpty else { return }

        isGenerating = true
        HapticFeedback.heavy()

        Task {
            do {
                // Combine selected sections
                let selectedText = sections
                    .filter(\.isSelected)
                    .map(\.text)
                    .joined(separator: "\n\n")

                // Create StudyContent
                let content = StudyContent(
                    source: .photo,
                    rawContent: selectedText
                )
                content.topic = selectedTopic.isEmpty ? nil : selectedTopic
                content.extractedText = extractedText

                // Store images
                if isMultiPage {
                    content.photoPages = images.compactMap { $0.jpegData(compressionQuality: 0.8) }
                    content.pageCount = images.count
                } else if let image = images.first {
                    content.photoData = image.jpegData(compressionQuality: 0.8)
                    content.pageCount = 1
                }

                modelContext.insert(content)

                // Generate flashcards
                let flashcardFormats: Set<FlashcardType> = recommendFlashcardFormats()
                let result = try await fmClient.generateFlashcards(
                    from: content,
                    formats: flashcardFormats,
                    maxPerFormat: 3
                )

                // Find or create flashcard set
                let deckName = selectedDeck.isEmpty ? (selectedTopic.isEmpty ? result.topicTag : selectedTopic) : selectedDeck
                let flashcardSet = modelContext.findOrCreateFlashcardSet(topicLabel: deckName)

                // Link flashcards
                content.flashcards.append(contentsOf: result.flashcards)
                for flashcard in result.flashcards {
                    flashcardSet.addCard(flashcard)
                    modelContext.insert(flashcard)
                }
                flashcardSet.entryCount += 1

                try modelContext.save()

                await MainActor.run {
                    isGenerating = false
                    HapticFeedback.success()
                    dismiss()
                }

            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = "Failed to generate flashcards. Please try again."
                    showError = true
                    HapticFeedback.error()
                }
            }
        }
    }

    private func recommendFlashcardFormats() -> Set<FlashcardType> {
        var formats: Set<FlashcardType> = [.qa]

        // Analyze section types to recommend formats
        let sectionTypes = sections.filter(\.isSelected).map(\.type)

        if sectionTypes.contains(.definition) {
            formats.insert(.definition)
        }

        if sectionTypes.contains(.list) {
            formats.insert(.cloze)
        }

        if sectionTypes.contains(.equation) {
            formats.insert(.cloze)
        }

        return formats
    }
}

// MARK: - Section Row View

struct SectionRowView: View {
    @Binding var section: TextSection
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Selection toggle
            Button {
                section.isSelected.toggle()
                HapticFeedback.light()
            } label: {
                Image(systemName: section.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(section.isSelected ? .cosmicPurple : .gray)
            }

            // Section content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Image(systemName: section.type.icon)
                        .font(.system(size: 12))
                        .foregroundColor(section.type.color)

                    Text(section.type.rawValue.capitalized)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundColor(section.type.color)
                        .textCase(.uppercase)

                    Spacer()

                    Text("\(section.text.count) chars")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondaryText)
                }

                Text(section.text)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.primaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            // Actions
            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(.secondaryText)
                    .padding(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(section.isSelected ? Color.cosmicPurple.opacity(0.1) : Color.gray.opacity(0.05))
        )
    }
}

// MARK: - Section Editor View

struct SectionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var section: TextSection

    @State private var editedText: String
    @State private var editedType: SectionType

    init(section: Binding<TextSection>) {
        self._section = section
        self._editedText = State(initialValue: section.wrappedValue.text)
        self._editedType = State(initialValue: section.wrappedValue.type)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Section Type") {
                    Picker("Type", selection: $editedType) {
                        ForEach(SectionType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue.capitalized)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Content") {
                    TextEditor(text: $editedText)
                        .frame(minHeight: 200)
                        .font(.system(.body, design: .rounded))
                }

                Section {
                    Text("\(editedText.count) characters")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondaryText)
                }
            }
            .navigationTitle("Edit Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        section.text = editedText
                        section.type = editedType
                        dismiss()
                    }
                    .disabled(editedText.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleText = """
    Cell Biology Introduction

    Cells are the basic building blocks of all living things. The human body is composed of trillions of cells.

    Key Components:
    • Nucleus - contains genetic material
    • Mitochondria - produces energy
    • Cell membrane - controls what enters and exits

    Photosynthesis Process

    Photosynthesis is the process by which plants convert light energy into chemical energy. The equation is:
    6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂
    """

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = (try? ModelContainer(
        for: StudyContent.self, Flashcard.self, FlashcardSet.self,
        configurations: config
    )) ?? {
        try! ModelContainer(for: StudyContent.self, Flashcard.self, FlashcardSet.self)
    }()

    return ScanReviewView(
        extractedText: sampleText,
        images: [],
        isMultiPage: false
    )
    .modelContainer(container)
}
