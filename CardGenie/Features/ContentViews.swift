//
//  ContentViews.swift
//  CardGenie
//
//  Study content management views and AI availability status.
//

import SwiftUI
import SwiftData
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - ContentListView


/// Main view displaying the list of study content
struct ContentListView: View {
    // SwiftData
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudyContent.createdAt, order: .reverse) private var allContent: [StudyContent]

    // Search & Filtering
    @State private var searchText: String = ""
    @State private var selectedFilters: Set<ContentFilter> = []
    @State private var sortOrder: SortOrder = .dateDescending
    @State private var showingFilters = false

    // Navigation
    @State private var selectedContent: StudyContent?
    @State private var showingSettings = false

    // App Intent integration
    @Binding var pendingGenerationText: String?
    @State private var showingGenerationSheet = false

    // Animation
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    init(pendingGenerationText: Binding<String?> = .constant(nil)) {
        self._pendingGenerationText = pendingGenerationText
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    GlassSearchBar(text: $searchText, placeholder: "Search your study materials...")
                }
                .listSectionSeparator(.hidden)
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: Spacing.md, leading: Spacing.md, bottom: Spacing.sm, trailing: Spacing.md))
                .listRowBackground(Color.clear)

                // Active filter chips
                if !selectedFilters.isEmpty {
                    Section {
                        FilterChipsRow(filters: $selectedFilters) {
                            selectedFilters.removeAll()
                        }
                    }
                    .listSectionSeparator(.hidden)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: Spacing.sm, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                if filteredContent.isEmpty {
                    Section {
                        if searchText.isEmpty {
                            contextualEmptyState
                                .frame(maxWidth: .infinity, maxHeight: 400)
                                .padding(.vertical, Spacing.xl)
                        } else {
                            Text("No results for \"\(searchText)\"")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, Spacing.lg)
                        }
                    }
                    .listSectionSeparator(.hidden)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: Spacing.lg, leading: Spacing.md, bottom: Spacing.xl, trailing: Spacing.md))
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredContent) { content in
                        NavigationLink(value: content) {
                            ContentRow(content: content)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: deleteContent)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .background(Color.clear)
            .navigationTitle("Study Materials")
            .navigationDestination(for: StudyContent.self) { content in
                ContentDetailView(content: content)
            }
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
                    Menu {
                        // Sort options
                        Picker("Sort By", selection: $sortOrder) {
                            ForEach(SortOrder.allCases) { order in
                                Label(order.rawValue, systemImage: order.icon)
                                    .tag(order)
                            }
                        }

                        Divider()

                        Button {
                            showingFilters = true
                        } label: {
                            Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                        }

                        if !selectedFilters.isEmpty {
                            Button(role: .destructive) {
                                selectedFilters.removeAll()
                            } label: {
                                Label("Clear Filters", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: selectedFilters.isEmpty ? "ellipsis.circle" : "ellipsis.circle.fill")
                            .foregroundStyle(Color.cosmicPurple)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        createNewContent(source: .text)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolEffect(.bounce, value: allContent.count) // iOS 26 SF Symbols animation
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.cosmicPurple, .mysticBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingFilters) {
                FilterSheet(selectedFilters: $selectedFilters)
            }
            .sheet(isPresented: $showingGenerationSheet) {
                if let text = pendingGenerationText {
                    FlashcardGenerationSheet(
                        sourceText: text,
                        onDismiss: {
                            pendingGenerationText = nil
                            showingGenerationSheet = false
                        }
                    )
                }
            }
            .onChange(of: pendingGenerationText) { _, newValue in
                if newValue != nil {
                    showingGenerationSheet = true
                }
            }
        }
    }

    // MARK: - Empty State

    private var contextualEmptyState: some View {
        EmptyStateView(
            icon: "wand.and.stars",
            title: "Welcome to CardGenie! 🧞‍♂️",
            description: "Let's get started with your first study material. Create content from text, scan documents, or record lectures.",
            primaryAction: .init(
                title: "Add Text",
                icon: "text.badge.plus",
                action: {
                    createNewContent(source: .text)
                }
            ),
            secondaryAction: .init(
                title: "Scan",
                icon: "doc.viewfinder",
                action: {
                    // User can navigate to scan tab manually
                    // Or we could post a notification to switch tabs
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToScanTab"), object: nil)
                }
            ),
            tertiaryAction: .init(
                title: "Record",
                icon: "mic.circle",
                action: {
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToRecordTab"), object: nil)
                }
            )
        )
    }

    // MARK: - Computed Properties

    /// Filtered and sorted content based on search, filters, and sort order
    private var filteredContent: [StudyContent] {
        var content = allContent

        // Apply search filter
        if !searchText.isEmpty {
            content = content.filter { item in
                item.displayText.localizedCaseInsensitiveContains(searchText) ||
                (item.summary ?? "").localizedCaseInsensitiveContains(searchText) ||
                item.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                (item.topic ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply content filters
        if !selectedFilters.isEmpty {
            content = content.filter { item in
                selectedFilters.contains { filter in
                    filter.matches(item)
                }
            }
        }

        // Apply sort order
        return content.sorted(by: sortOrder.comparator)
    }

    // MARK: - Actions

    /// Create new study content
    private func createNewContent(source: ContentSource) {
        withAnimation(reduceMotion ? .none : .glass) {
            let newContent = StudyContent(source: source, rawContent: "")
            modelContext.insert(newContent)

            do {
                try modelContext.save()
                selectedContent = newContent
            } catch {
                print("Failed to create content: \(error)")
            }
        }
    }

    /// Delete content at the specified offsets
    private func deleteContent(at offsets: IndexSet) {
        withAnimation(reduceMotion ? .none : .glassQuick) {
            for index in offsets {
                let content = filteredContent[index]
                modelContext.delete(content)
            }

            do {
                try modelContext.save()
            } catch {
                print("Failed to delete content: \(error)")
            }
        }
    }
}

// MARK: - Content Row

struct ContentRow: View {
    let content: StudyContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with source icon
            HStack {
                Image(systemName: content.sourceIcon)
                    .font(.caption)
                    .foregroundStyle(Color.mysticBlue)

                Text(content.sourceLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(content.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Content preview
            Text(content.firstLine)
                .font(.headline)
                .lineLimit(1)

            Text(content.preview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // Tags
            if !content.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(content.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.cosmicPurple.opacity(0.1))
                                .foregroundStyle(Color.cosmicPurple)
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    // Create a preview container with sample data
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = (try? ModelContainer(for: StudyContent.self, configurations: config)) ?? {
        // Fallback to default container if creation fails
        try! ModelContainer(for: StudyContent.self)
    }()

    // Add sample content
    let context = ModelContext(container)

    let content1 = StudyContent(
        source: .text,
        rawContent: "Today was an amazing day! I spent time with friends and learned so much about SwiftUI. The new Liquid Glass design system is incredible – the translucent materials make everything feel so modern and fluid."
    )
    content1.summary = "Had a great day with friends and explored the Liquid Glass design system."
    content1.tags = ["friends", "learning", "SwiftUI"]
    content1.topic = "Technology"

    let content2 = StudyContent(
        source: .photo,
        rawContent: "Newton's Laws of Motion: 1. An object at rest stays at rest. 2. Force equals mass times acceleration. 3. For every action, there is an equal and opposite reaction."
    )
    content2.tags = ["physics", "Newton"]
    content2.topic = "Science"

    let content3 = StudyContent(
        source: .voice,
        rawContent: "Remember to follow up on the project deadline tomorrow. Need to finalize the designs and prepare the presentation."
    )
    content3.tags = ["work", "reminder"]

    context.insert(content1)
    context.insert(content2)
    context.insert(content3)

    return ContentListView()
        .modelContainer(container)
}

#Preview("Empty State") {
    // Empty container for empty state preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = (try? ModelContainer(for: StudyContent.self, configurations: config)) ?? {
        try! ModelContainer(for: StudyContent.self)
    }()

    return ContentListView()
        .modelContainer(container)
}

// MARK: - ContentDetailView
//  - Custom AI actions (summarize, generate tags, insights)
//  - Flashcard generation
//


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
        .alert("AI Unavailable", isPresented: $showAIUnavailable) {
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
            return "AI features are disabled. Enable them in Settings to use AI features."
        case .notSupported:
            return "This device doesn't support AI features. An iPhone 15 Pro or newer is required."
        case .modelNotReady:
            return "AI is loading. Please try again in a moment."
        case .unknown:
            return "Unable to determine AI availability."
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = (try? ModelContainer(for: StudyContent.self, configurations: config)) ?? {
        // Fallback to default container if creation fails
        try! ModelContainer(for: StudyContent.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }()
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

// MARK: - AIAvailabilityViews


#if canImport(FoundationModels)
#endif

// MARK: - Availability Gate Wrapper

/// Wraps AI-powered features with availability checking
struct AIFeatureGate<Content: View>: View {
    let feature: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            AIAvailabilityWrapper(feature: feature, content: content)
        } else {
            DeviceNotSupportedView()
        }
        #else
        DeviceNotSupportedView()
        #endif
    }
}

// MARK: - iOS 26+ Availability Wrapper

@available(iOS 26.0, *)
private struct AIAvailabilityWrapper<Content: View>: View {
    let feature: String
    @ViewBuilder let content: () -> Content

    private let model = SystemLanguageModel.default

    var body: some View {
        switch model.availability {
        case .available:
            content()

        case .unavailable(.deviceNotEligible):
            DeviceNotSupportedView()

        case .unavailable(.appleIntelligenceNotEnabled):
            EnableAIView()

        case .unavailable(.modelNotReady):
            ModelDownloadingView()

        default:
            GenericUnavailableView()
        }
    }
}

// MARK: - Device Not Supported View

struct DeviceNotSupportedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Text("AI Features Unavailable")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("AI features require an iPhone 15 Pro or later")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Text("You can still use:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "square.and.pencil", text: "Manual flashcard creation")
                    FeatureRow(icon: "book.fill", text: "Browse and organize notes")
                    FeatureRow(icon: "chart.bar.fill", text: "Track study progress")
                    FeatureRow(icon: "calendar", text: "Spaced repetition reminders")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
}

// MARK: - Enable AI View

struct EnableAIView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.fill")
                .font(.system(size: 60))
                .foregroundStyle(.purple)

            VStack(spacing: 12) {
                Text("Enable AI Features")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("AI-powered features need to be enabled in Settings")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Text("To enable:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 12) {
                    InstructionRow(number: 1, text: "Open Settings")
                    InstructionRow(number: 2, text: "Enable AI features")
                    InstructionRow(number: 3, text: "Return to CardGenie")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: openSettings) {
                Label("Open Settings", systemImage: "gear")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Model Downloading View

struct ModelDownloadingView: View {
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            VStack(spacing: 12) {
                Text("Preparing AI Model")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("AI model is downloading or initializing. This may take a few minutes.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Text("What's happening:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 8) {
                    StatusRow(icon: "arrow.down.circle.fill", text: "Downloading model files")
                    StatusRow(icon: "gear.circle.fill", text: "Optimizing for your device")
                    StatusRow(icon: "checkmark.circle.fill", text: "Preparing Neural Engine")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: refresh) {
                Label(
                    isRefreshing ? "Checking..." : "Check Again",
                    systemImage: "arrow.clockwise"
                )
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isRefreshing)
        }
        .padding()
    }

    private func refresh() {
        isRefreshing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isRefreshing = false
        }
    }
}

// MARK: - Generic Unavailable View

struct GenericUnavailableView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            VStack(spacing: 12) {
                Text("AI Temporarily Unavailable")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("AI features are currently unavailable. Please try again later.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("Your notes and flashcards are safe. Manual study features remain fully functional.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Helper Components

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.green)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

private struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

private struct StatusRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

// MARK: - Preview Helpers

#Preview("Device Not Supported") {
    DeviceNotSupportedView()
}

#Preview("Enable AI") {
    EnableAIView()
}

// MARK: - Content Filtering & Sorting

/// Content filter options for study materials
enum ContentFilter: String, CaseIterable, Identifiable {
    case text = "Text Notes"
    case photo = "Photos"
    case voice = "Voice"
    case pdf = "PDFs"
    case aiGenerated = "AI Processed"
    case hasFlashcards = "Has Cards"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .photo: return "photo"
        case .voice: return "waveform"
        case .pdf: return "doc.fill"
        case .aiGenerated: return "sparkles"
        case .hasFlashcards: return "rectangle.on.rectangle"
        }
    }

    var color: Color {
        switch self {
        case .text: return .blue
        case .photo: return .purple
        case .voice: return .pink
        case .pdf: return .red
        case .aiGenerated: return .cosmicPurple
        case .hasFlashcards: return .green
        }
    }

    /// Check if study content matches this filter
    func matches(_ content: StudyContent) -> Bool {
        switch self {
        case .text:
            return content.source == .text
        case .photo:
            return content.source == .photo
        case .voice:
            return content.source == .voice
        case .pdf:
            return content.source == .pdf
        case .aiGenerated:
            return content.summary != nil || !content.tags.isEmpty
        case .hasFlashcards:
            // Content has flashcards if it has been processed
            // In the current architecture, flashcards are in FlashcardSet
            // We'll check if tags exist as a proxy
            return !content.tags.isEmpty
        }
    }
}

/// Sort order options for study content
enum SortOrder: String, CaseIterable, Identifiable {
    case dateDescending = "Newest First"
    case dateAscending = "Oldest First"
    case titleAscending = "Title A-Z"
    case modifiedDescending = "Recently Updated"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dateDescending: return "calendar.badge.clock"
        case .dateAscending: return "calendar"
        case .titleAscending: return "textformat"
        case .modifiedDescending: return "clock"
        }
    }

    /// Comparator function for sorting
    var comparator: (StudyContent, StudyContent) -> Bool {
        switch self {
        case .dateDescending:
            return { $0.createdAt > $1.createdAt }
        case .dateAscending:
            return { $0.createdAt < $1.createdAt }
        case .titleAscending:
            return { ($0.topic ?? "") < ($1.topic ?? "") }
        case .modifiedDescending:
            // Use createdAt as proxy for modification (SwiftData tracks this)
            return { $0.createdAt > $1.createdAt }
        }
    }
}

// MARK: - Filter Sheet

struct FilterSheet: View {
    @Binding var selectedFilters: Set<ContentFilter>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ContentFilter.allCases) { filter in
                        FilterRow(
                            filter: filter,
                            isSelected: selectedFilters.contains(filter)
                        ) {
                            toggleFilter(filter)
                        }
                    }
                } header: {
                    Text("Filter by Type")
                        .font(.headline)
                } footer: {
                    Text("Select multiple filters to show content matching any filter")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !selectedFilters.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear All") {
                            selectedFilters.removeAll()
                        }
                    }
                }
            }
        }
    }

    private func toggleFilter(_ filter: ContentFilter) {
        if selectedFilters.contains(filter) {
            selectedFilters.remove(filter)
        } else {
            selectedFilters.insert(filter)
        }
    }
}

// MARK: - Filter Row

struct FilterRow: View {
    let filter: ContentFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: filter.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? filter.color : .secondary)
                    .frame(width: 32)

                Text(filter.rawValue)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(filter.color)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Chips Row

struct FilterChipsRow: View {
    @Binding var filters: Set<ContentFilter>
    let onClear: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(filters)) { filter in
                    FilterChip(filter: filter) {
                        filters.remove(filter)
                    }
                }

                if !filters.isEmpty {
                    Button {
                        onClear()
                    } label: {
                        Text("Clear")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.red.opacity(0.15))
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let filter: ContentFilter
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: filter.icon)
                .font(.caption)
            Text(filter.rawValue)
                .font(.caption.weight(.medium))
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .foregroundStyle(filter.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(filter.color.opacity(0.15))
        .cornerRadius(16)
    }
}

// MARK: - Flashcard Generation Sheet

/// Sheet for generating flashcards from text provided via Shortcuts
struct FlashcardGenerationSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var flashcardSets: [FlashcardSet]

    let sourceText: String
    let onDismiss: () -> Void

    @State private var isGenerating = false
    @State private var selectedSet: FlashcardSet?
    @State private var showingSetPicker = false
    @State private var generatedCount = 0
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preview of source text
                VStack(alignment: .leading, spacing: 12) {
                    Text("Source Text")
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)

                    ScrollView {
                        Text(sourceText)
                            .font(.body)
                            .foregroundStyle(Color.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 150)
                    .padding()
                    .background(Color.primaryText.opacity(0.05))
                    .cornerRadius(12)
                }
                .padding()
                .glassPanel()
                .cornerRadius(16)

                // Deck selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Target Deck")
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
                        .cornerRadius(12)
                    }
                }
                .padding()
                .glassPanel()
                .cornerRadius(16)

                Spacer()

                // Generate button
                Button {
                    generateFlashcards()
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isGenerating ? "Generating..." : "Generate Flashcards")
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
                .disabled(isGenerating || selectedSet == nil)
            }
            .padding()
            .navigationTitle("Generate Flashcards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSetPicker) {
                SetPickerView(selectedSet: $selectedSet, flashcardSets: flashcardSets)
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button("OK") {
                    onDismiss()
                    dismiss()
                }
            } message: {
                Text("Generated \(generatedCount) flashcards successfully!")
            }
            .onAppear {
                selectedSet = flashcardSets.first
            }
        }
    }

    private func generateFlashcards() {
        isGenerating = true

        Task {
            guard let targetSet = selectedSet else { return }

            // Create a source document
            let sourceDoc = SourceDocument(
                kind: .text,
                fileName: "Shortcut Import"
            )
            modelContext.insert(sourceDoc)

            // Create a note chunk
            let chunk = NoteChunk(
                text: sourceText,
                chunkIndex: 0
            )
            chunk.sourceDocument = sourceDoc
            modelContext.insert(chunk)

            // Generate flashcards using the flashcard generator
            let generator = FlashcardGenerator()
            do {
                let flashcards = try await generator.generateCards(
                    from: [chunk],
                    deck: targetSet
                )

                await MainActor.run {
                    generatedCount = flashcards.count
                    isGenerating = false
                    showSuccess = true
                }
            } catch {
                print("Error generating flashcards: \(error)")
                await MainActor.run {
                    isGenerating = false
                    // Show error to user
                }
            }
        }
    }
}

// MARK: - Set Picker View

private struct SetPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSet: FlashcardSet?
    let flashcardSets: [FlashcardSet]

    var body: some View {
        NavigationStack {
            List {
                ForEach(flashcardSets) { set in
                    Button {
                        selectedSet = set
                        dismiss()
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
            .navigationTitle("Select Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("Model Downloading") {
    ModelDownloadingView()
}

#Preview("Generic Unavailable") {
    GenericUnavailableView()
}
