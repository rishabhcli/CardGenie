//
//  ContentDetailView.swift
//  CardGenie
//
//  Detail view for creating and editing study content.
//  Integrates Apple Intelligence for on-device AI features:
//  - Writing Tools (proofread, rewrite) via text selection
//  - Custom AI actions (summarize, generate tags, insights)
//  - Flashcard generation
//

import SwiftUI
import SwiftData

/// Detail view for study content with AI-powered features
struct ContentDetailView: View {
    // Data
    @Environment(\.modelContext) private var modelContext
    @Bindable var content: StudyContent

    // AI
    @StateObject private var fmClient = FMClient()
    @StateObject private var categorizer = AutoCategorizer()

    // UI State
    @State private var isSummarizing = false
    @State private var isCategorizing = false
    @State private var isGeneratingTags = false
    @State private var isGeneratingInsights = false
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
                // Source indicator
                HStack {
                    Image(systemName: content.sourceIcon)
                        .foregroundStyle(Color.mysticBlue)

                    Text("Source: \(content.sourceLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.horizontal)

                // Text Editor with Writing Tools enabled
                WritingTextEditor(
                    text: Binding(
                        get: { content.rawContent },
                        set: { newValue in
                            content.rawContent = newValue
                            try? modelContext.save()
                        }
                    ),
                    onTextChange: { _ in
                        try? modelContext.save()
                    }
                )
                .frame(minHeight: 300)
                .padding()
                .glassContentBackground()
                .cornerRadius(CornerRadius.lg)
                .padding(.horizontal)

                // Character count
                Text("\(content.displayText.count) characters")
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
        .navigationTitle(content.createdAt.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    aiActionsMenu
                    Divider()
                    otherActionsMenu
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .foregroundStyle(Color.cosmicPurple)
                }
            }
        }
        .alert("Apple Intelligence Unavailable", isPresented: $showAIUnavailable) {
            Button("OK", role: .cancel) {}
            Button("Settings", action: openSettings)
        } message: {
            Text(aiUnavailableMessage)
        }
        .confirmationDialog("Delete Content", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: deleteContent)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this content? This action cannot be undone.")
        }
        .alert("Flashcards Generated ✨", isPresented: $showFlashcardSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Successfully generated \(generatedFlashcardCount) flashcard\(generatedFlashcardCount == 1 ? "" : "s")! View them in the Flashcards tab.")
        }
        .errorAlert($error)
    }

    // MARK: - AI Generated Content

    @ViewBuilder
    private var aiGeneratedContent: some View {
        VStack(spacing: Spacing.md) {
            // Summary
            if let summary = content.summary, !summary.isEmpty {
                AISummaryCard(summary: summary) {
                    withAnimation(reduceMotion ? .none : .glassQuick) {
                        content.summary = nil
                        try? modelContext.save()
                    }
                }
                .padding(.horizontal)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }

            // Tags
            if !content.tags.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Label("Tags", systemImage: "tag.fill")
                        .font(.headline)
                        .foregroundStyle(Color.cosmicPurple)

                    TagFlowLayout(spacing: Spacing.xs) {
                        ForEach(content.tags, id: \.self) { tag in
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

            // AI Insights
            if let insights = content.aiInsights, !insights.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Label("AI Insights", systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundStyle(Color.magicGold)

                    Text(insights)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(Color.magicGold.opacity(0.1))
                )
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
            Label("Summarize ✨", systemImage: "sparkles")
        }
        .disabled(isSummarizing || content.displayText.isEmpty)

        Button {
            Task { await generateTags() }
        } label: {
            Label("Generate Tags", systemImage: "tag.fill")
        }
        .disabled(isGeneratingTags || content.displayText.isEmpty)

        Button {
            Task { await categorize() }
        } label: {
            Label(isCategorizing ? "Categorizing..." : "Auto-Categorize", systemImage: "folder.fill")
        }
        .disabled(isCategorizing || content.displayText.isEmpty)

        Button {
            Task { await generateInsights() }
        } label: {
            Label("Get AI Insights", systemImage: "lightbulb.fill")
        }
        .disabled(isGeneratingInsights || content.displayText.isEmpty)

        Divider()

        Button {
            Task { await generateFlashcards() }
        } label: {
            Label(isGeneratingFlashcards ? "Generating..." : "Generate Flashcards 🪄", systemImage: "rectangle.on.rectangle.angled")
        }
        .disabled(isGeneratingFlashcards || content.displayText.isEmpty)
    }

    // MARK: - Other Actions Menu

    @ViewBuilder
    private var otherActionsMenu: some View {
        Button {
            shareContent()
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

    /// Summarize the content using Foundation Models
    private func summarize() async {
        let capability = fmClient.capability()
        guard capability == .available else {
            showAIUnavailable = true
            return
        }

        guard !content.displayText.isEmpty else { return }

        isSummarizing = true
        defer { isSummarizing = false }

        do {
            let summary = try await fmClient.summarize(content.displayText)

            withAnimation(reduceMotion ? .none : .glass) {
                content.summary = summary
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

        guard !content.displayText.isEmpty else { return }

        isGeneratingTags = true
        defer { isGeneratingTags = false }

        do {
            let tags = try await fmClient.tags(for: content.displayText)

            withAnimation(reduceMotion ? .none : .glass) {
                content.tags = tags
                if let firstTag = tags.first {
                    content.topic = firstTag
                }
                try? modelContext.save()
            }
        } catch {
            self.error = error
        }
    }

    /// Auto-categorize content
    private func categorize() async {
        let capability = fmClient.capability()
        guard capability == .available else {
            showAIUnavailable = true
            return
        }

        guard !content.displayText.isEmpty else { return }

        isCategorizing = true
        defer { isCategorizing = false }

        do {
            let category = try await categorizer.categorize(content)

            withAnimation(reduceMotion ? .none : .glass) {
                content.topic = category
                try? modelContext.save()
            }
        } catch {
            self.error = error
        }
    }

    /// Generate AI insights using Foundation Models
    private func generateInsights() async {
        let capability = fmClient.capability()
        guard capability == .available else {
            showAIUnavailable = true
            return
        }

        guard !content.displayText.isEmpty else { return }

        isGeneratingInsights = true
        defer { isGeneratingInsights = false }

        do {
            let insights = try await fmClient.reflection(for: content.displayText)

            withAnimation(reduceMotion ? .none : .glass) {
                content.aiInsights = insights
                try? modelContext.save()
            }
        } catch {
            self.error = error
        }
    }

    /// Generate flashcards from the content
    private func generateFlashcards() async {
        let capability = fmClient.capability()
        guard capability == .available else {
            showAIUnavailable = true
            return
        }

        guard !content.displayText.isEmpty else { return }

        isGeneratingFlashcards = true
        defer { isGeneratingFlashcards = false }

        do {
            // Generate flashcards using all three formats
            let result = try await fmClient.generateFlashcards(
                from: content,
                formats: [.cloze, .qa, .definition],
                maxPerFormat: 3
            )

            // Find or create flashcard set for this topic
            let flashcardSet = findOrCreateSet(for: result.topicTag)

            // Add flashcards to the set and link to content
            for flashcard in result.flashcards {
                flashcardSet.addCard(flashcard)
                modelContext.insert(flashcard)
            }

            // Link flashcards to content
            content.flashcards.append(contentsOf: result.flashcards)
            flashcardSet.entryCount += 1

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
        modelContext.findOrCreateFlashcardSet(topicLabel: topic)
    }

    // MARK: - Other Actions

    /// Share the content as plain text
    private func shareContent() {
        let text = """
        Study Content
        \(content.createdAt.formatted(date: .long, time: .shortened))
        Source: \(content.sourceLabel)

        \(content.displayText)

        ---
        Created with CardGenie ✨
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

    /// Delete the content and go back
    private func deleteContent() {
        modelContext.delete(content)
        try? modelContext.save()
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

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: StudyContent.self, configurations: config)
    let context = ModelContext(container)

    let content = StudyContent(
        source: .text,
        rawContent: "Today was an incredible day. I woke up early and went for a run in the park. The morning was beautiful – crisp air, golden sunlight filtering through the trees. It reminded me how important it is to start the day with intention.\n\nLater, I had a great conversation with a friend about our goals for the year. We talked about the importance of staying curious and open to new experiences. I'm feeling inspired and ready to take on new challenges.\n\nGrateful for days like this."
    )
    content.summary = "Had a wonderful morning run and an inspiring conversation with a friend about goals and staying curious."
    content.tags = ["gratitude", "goals", "friendship"]
    content.topic = "Personal Growth"
    content.aiInsights = "It's beautiful how simple moments can bring such clarity and inspiration."

    context.insert(content)

    return NavigationStack {
        ContentDetailView(content: content)
    }
    .modelContainer(container)
}
