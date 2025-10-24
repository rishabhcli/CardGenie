//
//  JournalDetailView.swift
//  CardGenie
//
//  Detail view for creating and editing journal entries.
//  Integrates Apple Intelligence for on-device AI features:
//  - Writing Tools (proofread, rewrite) via text selection
//  - Custom AI actions (summarize, generate tags, reflection)
//

import SwiftUI
import SwiftData

/// Detail view for a journal entry with AI-powered features
struct JournalDetailView: View {
    // Data
    @Environment(\.modelContext) private var modelContext
    @Bindable var entry: JournalEntry

    // AI
    @StateObject private var fmClient = FMClient()

    // UI State
    @State private var isSummarizing = false
    @State private var isGeneratingTags = false
    @State private var isGeneratingReflection = false
    @State private var isGeneratingFlashcards = false
    @State private var showAIUnavailable = false
    @State private var error: Error?
    @State private var showDeleteConfirmation = false
    @State private var showFlashcardSuccess = false
    @State private var generatedFlashcardCount = 0

    // Accessibility
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                // Text Editor with Writing Tools enabled
                WritingTextEditor(
                    text: $entry.text,
                    onTextChange: { _ in
                        // Auto-save on text change
                        try? modelContext.save()
                    }
                )
                .frame(minHeight: 300)
                .padding()
                .glassContentBackground()
                .cornerRadius(CornerRadius.lg)
                .padding(.horizontal)

                // Character count
                Text("\(entry.text.count) characters")
                    .font(.metadata)
                    .foregroundStyle(Color.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal)

                // AI-generated content
                aiGeneratedContent

                Spacer(minLength: Spacing.xxl)
            }
            .padding(.vertical)
        }
        .navigationTitle(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    aiActionsMenu
                    Divider()
                    otherActionsMenu
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Apple Intelligence Unavailable", isPresented: $showAIUnavailable) {
            Button("OK", role: .cancel) {}
            Button("Settings", action: openSettings)
        } message: {
            Text(aiUnavailableMessage)
        }
        .confirmationDialog("Delete Entry", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: deleteEntry)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this entry? This action cannot be undone.")
        }
        .alert("Flashcards Generated", isPresented: $showFlashcardSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Successfully generated \(generatedFlashcardCount) flashcard\(generatedFlashcardCount == 1 ? "" : "s"). View them in the Flashcards tab.")
        }
        .errorAlert($error)
    }

    // MARK: - AI Generated Content

    @ViewBuilder
    private var aiGeneratedContent: some View {
        VStack(spacing: Spacing.md) {
            // Summary
            if let summary = entry.summary, !summary.isEmpty {
                AISummaryCard(summary: summary) {
                    withAnimation(reduceMotion ? .none : .glassQuick) {
                        entry.summary = nil
                        try? modelContext.save()
                    }
                }
                .padding(.horizontal)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }

            // Tags
            if !entry.tags.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Label("Tags", systemImage: "tag.fill")
                        .font(.headline)
                        .foregroundStyle(Color.secondaryText)

                    FlowLayout(spacing: Spacing.xs) {
                        ForEach(entry.tags, id: \.self) { tag in
                            TagChip(text: tag)
                        }
                    }
                }
                .padding()
                .glassPanel()
                .cornerRadius(CornerRadius.lg)
                .padding(.horizontal)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }

            // Reflection
            if let reflection = entry.reflection, !reflection.isEmpty {
                AIReflectionCard(reflection: reflection)
                    .padding(.horizontal)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - AI Actions Menu

    @ViewBuilder
    private var aiActionsMenu: some View {
        Button {
            Task { await summarize() }
        } label: {
            Label("Summarize", systemImage: "sparkles")
        }
        .disabled(isSummarizing || entry.text.isEmpty)

        Button {
            Task { await generateTags() }
        } label: {
            Label("Generate Tags", systemImage: "tag")
        }
        .disabled(isGeneratingTags || entry.text.isEmpty)

        Button {
            Task { await generateReflection() }
        } label: {
            Label("Get Reflection", systemImage: "quote.bubble")
        }
        .disabled(isGeneratingReflection || entry.text.isEmpty)

        Divider()

        Button {
            Task { await generateFlashcards() }
        } label: {
            Label(isGeneratingFlashcards ? "Generating..." : "Generate Flashcards", systemImage: "rectangle.on.rectangle.angled")
        }
        .disabled(isGeneratingFlashcards || entry.text.isEmpty)
    }

    // MARK: - Other Actions Menu

    @ViewBuilder
    private var otherActionsMenu: some View {
        Button {
            shareEntry()
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }

        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - AI Actions

    /// Summarize the entry using Foundation Models
    private func summarize() async {
        // Check capability
        let capability = fmClient.capability()
        guard capability == .available else {
            showAIUnavailable = true
            return
        }

        guard !entry.text.isEmpty else { return }

        isSummarizing = true
        defer { isSummarizing = false }

        do {
            let summary = try await fmClient.summarize(entry.text)

            withAnimation(reduceMotion ? .none : .glass) {
                entry.summary = summary
                try? modelContext.save()
            }
        } catch {
            self.error = error
        }
    }

    /// Generate tags using Foundation Models
    private func generateTags() async {
        let capability = fmClient.capability()
        guard capability == .available else {
            showAIUnavailable = true
            return
        }

        guard !entry.text.isEmpty else { return }

        isGeneratingTags = true
        defer { isGeneratingTags = false }

        do {
            let tags = try await fmClient.tags(for: entry.text)

            withAnimation(reduceMotion ? .none : .glass) {
                entry.tags = tags
                try? modelContext.save()
            }
        } catch {
            self.error = error
        }
    }

    /// Generate a reflection using Foundation Models
    private func generateReflection() async {
        let capability = fmClient.capability()
        guard capability == .available else {
            showAIUnavailable = true
            return
        }

        guard !entry.text.isEmpty else { return }

        isGeneratingReflection = true
        defer { isGeneratingReflection = false }

        do {
            let reflection = try await fmClient.reflection(for: entry.text)

            withAnimation(reduceMotion ? .none : .glass) {
                entry.reflection = reflection
                try? modelContext.save()
            }
        } catch {
            self.error = error
        }
    }

    /// Generate flashcards from the journal entry
    private func generateFlashcards() async {
        let capability = fmClient.capability()
        guard capability == .available else {
            showAIUnavailable = true
            return
        }

        guard !entry.text.isEmpty else { return }

        isGeneratingFlashcards = true
        defer { isGeneratingFlashcards = false }

        do {
            // Generate flashcards using all three formats
            let result = try await fmClient.generateFlashcards(
                from: entry,
                formats: [.cloze, .qa, .definition],
                maxPerFormat: 3
            )

            // Find or create flashcard set for this topic
            let flashcardSet = findOrCreateSet(for: result.topicTag)

            // Add flashcards to the set
            for flashcard in result.flashcards {
                flashcard.set = flashcardSet
                modelContext.insert(flashcard)
            }

            // Save changes
            try modelContext.save()

            // Show success message
            generatedFlashcardCount = result.flashcards.count
            showFlashcardSuccess = true

        } catch {
            self.error = error
        }
    }

    /// Find existing flashcard set by topic or create a new one
    private func findOrCreateSet(for topic: String) -> FlashcardSet {
        // Try to find existing set with this topic
        let descriptor = FetchDescriptor<FlashcardSet>(
            predicate: #Predicate { $0.tag == topic }
        )

        if let existingSet = try? modelContext.fetch(descriptor).first {
            return existingSet
        }

        // Create new set
        let newSet = FlashcardSet(topicLabel: topic, tag: topic)
        modelContext.insert(newSet)
        return newSet
    }

    // MARK: - Other Actions

    /// Share the entry as plain text
    private func shareEntry() {
        let text = """
        Journal Entry
        \(entry.createdAt.formatted(date: .long, time: .shortened))

        \(entry.text)

        ---
        Written with CardGenie
        """

        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    /// Delete the entry and go back
    private func deleteEntry() {
        modelContext.delete(entry)
        try? modelContext.save()
        // Navigation will automatically pop back
    }

    /// Open Settings app
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }

    // MARK: - Computed Properties

    private var aiUnavailableMessage: String {
        switch fmClient.capability() {
        case .available:
            return ""
        case .notEnabled:
            return "Apple Intelligence is disabled. Enable it in Settings > Apple Intelligence & Siri to use AI features."
        case .notSupported:
            return "This device doesn't support Apple Intelligence. An iPhone 15 Pro or newer is required."
        case .modelNotReady:
            return "Apple Intelligence is loading. Please try again in a moment."
        case .unknown:
            return "Unable to determine Apple Intelligence availability."
        }
    }
}

// MARK: - Flow Layout

/// A simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for size in sizes {
            if lineWidth + size.width > proposal.width ?? 0 {
                totalHeight += lineHeight + spacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            totalWidth = max(totalWidth, lineWidth)
        }

        totalHeight += lineHeight

        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var lineX = bounds.minX
        var lineY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if lineX + size.width > bounds.maxX {
                lineX = bounds.minX
                lineY += lineHeight + spacing
                lineHeight = 0
            }

            subview.place(
                at: CGPoint(x: lineX, y: lineY),
                proposal: ProposedViewSize(size)
            )

            lineX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: JournalEntry.self, configurations: config)
    let context = ModelContext(container)

    let entry = JournalEntry(text: "Today was an incredible day. I woke up early and went for a run in the park. The morning was beautiful – crisp air, golden sunlight filtering through the trees. It reminded me how important it is to start the day with intention.\n\nLater, I had a great conversation with a friend about our goals for the year. We talked about the importance of staying curious and open to new experiences. I'm feeling inspired and ready to take on new challenges.\n\nGrateful for days like this.")
    entry.summary = "Had a wonderful morning run and an inspiring conversation with a friend about goals and staying curious."
    entry.tags = ["gratitude", "goals", "friendship"]
    entry.reflection = "It's beautiful how simple moments can bring such clarity and inspiration."

    context.insert(entry)

    return NavigationStack {
        JournalDetailView(entry: entry)
    }
    .modelContainer(container)
}
