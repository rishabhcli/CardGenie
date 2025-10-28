//
//  ContentListView.swift
//  CardGenie
//
//  Main list view displaying all study content.
//  Features: search, create, delete, and navigate to content from various sources.
//

import SwiftUI
import SwiftData

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
    let container = try! ModelContainer(for: StudyContent.self, configurations: config)

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
    let container = try! ModelContainer(for: StudyContent.self, configurations: config)

    return ContentListView()
        .modelContainer(container)
}
