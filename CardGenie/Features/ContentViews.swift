//
//  ContentViews.swift
//  CardGenie
//
//  Study content management views and AI availability status.
//

import SwiftUI
import SwiftData
import FoundationModels

// MARK: - ContentListView


/// Main view displaying the list of study content
struct ContentListView: View {
    // SwiftData
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudyContent.createdAt, order: .reverse) private var allContent: [StudyContent]

    // Search
    @State private var searchText: String = ""

    // Navigation
    @State private var selectedContent: StudyContent?
    @State private var showingSettings = false

    // Animation
    @Environment(\.accessibilityReduceMotion) var reduceMotion

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

                if filteredContent.isEmpty {
                    Section {
                        if searchText.isEmpty {
                            EmptyStateView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, Spacing.xl)
                        } else {
                            Text("No results for “\(searchText)”")
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
        }
    }

    // MARK: - Computed Properties

    /// Filtered content based on search text
    private var filteredContent: [StudyContent] {
        guard !searchText.isEmpty else { return allContent }

        return allContent.filter { content in
            content.displayText.localizedCaseInsensitiveContains(searchText) ||
            (content.summary ?? "").localizedCaseInsensitiveContains(searchText) ||
            content.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
            (content.topic ?? "").localizedCaseInsensitiveContains(searchText)
        }
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
            EnableAppleIntelligenceView()

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

                Text("Apple Intelligence requires an iPhone 15 Pro or later with iOS 26+")
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

// MARK: - Enable Apple Intelligence View

struct EnableAppleIntelligenceView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.fill")
                .font(.system(size: 60))
                .foregroundStyle(.purple)

            VStack(spacing: 12) {
                Text("Enable Apple Intelligence")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("AI-powered features require Apple Intelligence to be turned on")
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
                    InstructionRow(number: 2, text: "Tap 'Apple Intelligence & Siri'")
                    InstructionRow(number: 3, text: "Turn on 'Apple Intelligence'")
                    InstructionRow(number: 4, text: "Return to CardGenie")
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

                Text("Apple Intelligence is downloading or initializing. This may take a few minutes.")
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

                Text("Apple Intelligence features are currently unavailable. Please try again later.")
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

#Preview("Enable Apple Intelligence") {
    EnableAppleIntelligenceView()
}

#Preview("Model Downloading") {
    ModelDownloadingView()
}

#Preview("Generic Unavailable") {
    GenericUnavailableView()
}
