//
//  JournalListView.swift
//  CardGenie
//
//  Main list view displaying all journal entries.
//  Features: search, create, delete, and navigate to entries.
//

import SwiftUI
import SwiftData

/// Main view displaying the list of journal entries
struct JournalListView: View {
    // SwiftData
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    // Search
    @State private var searchText: String = ""

    // Navigation
    @State private var selectedEntry: JournalEntry?
    @State private var showingSettings = false

    // Animation
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                if entries.isEmpty && searchText.isEmpty {
                    // Empty state
                    EmptyStateView()
                } else {
                    // List of entries
                    List {
                        ForEach(filteredEntries) { entry in
                            NavigationLink(value: entry) {
                                EntryRow(entry: entry)
                            }
                        }
                        .onDelete(perform: deleteEntries)
                    }
                    .listStyle(.plain)
                    .searchable(
                        text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search entries..."
                    )
                }
            }
            .navigationTitle("Journal")
            .navigationDestination(for: JournalEntry.self) { entry in
                JournalDetailView(entry: entry)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        createNewEntry()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Computed Properties

    /// Filtered entries based on search text
    private var filteredEntries: [JournalEntry] {
        guard !searchText.isEmpty else { return entries }

        return entries.filter { entry in
            entry.text.localizedCaseInsensitiveContains(searchText) ||
            (entry.summary ?? "").localizedCaseInsensitiveContains(searchText) ||
            entry.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    // MARK: - Actions

    /// Create a new journal entry
    private func createNewEntry() {
        withAnimation(reduceMotion ? .none : .glass) {
            let newEntry = JournalEntry(text: "")
            modelContext.insert(newEntry)

            do {
                try modelContext.save()
                selectedEntry = newEntry
            } catch {
                print("Failed to create entry: \(error)")
            }
        }
    }

    /// Delete entries at the specified offsets
    private func deleteEntries(at offsets: IndexSet) {
        withAnimation(reduceMotion ? .none : .glassQuick) {
            for index in offsets {
                let entry = filteredEntries[index]
                modelContext.delete(entry)
            }

            do {
                try modelContext.save()
            } catch {
                print("Failed to delete entries: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    // Create a preview container with sample data
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: JournalEntry.self, configurations: config)

    // Add sample entries
    let context = ModelContext(container)

    let entry1 = JournalEntry(text: "Today was an amazing day! I spent time with friends and learned so much about SwiftUI. The new Liquid Glass design system is incredible – the translucent materials make everything feel so modern and fluid.")
    entry1.summary = "Had a great day with friends and explored the Liquid Glass design system."
    entry1.tags = ["friends", "learning", "SwiftUI"]

    let entry2 = JournalEntry(text: "Quick note: Remember to follow up on the project deadline tomorrow. Need to finalize the designs and prepare the presentation.")
    entry2.tags = ["work", "reminder"]

    let entry3 = JournalEntry(text: "Feeling grateful today. Sometimes it's important to pause and appreciate the small things – a good cup of coffee, a sunny morning, and the joy of creating something meaningful.")
    entry3.summary = "Reflecting on gratitude and the small joys in life."
    entry3.tags = ["gratitude", "reflection"]

    context.insert(entry1)
    context.insert(entry2)
    context.insert(entry3)

    return JournalListView()
        .modelContainer(container)
}

#Preview("Empty State") {
    // Empty container for empty state preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: JournalEntry.self, configurations: config)

    return JournalListView()
        .modelContainer(container)
}
