//
//  Store.swift
//  CardGenie
//
//  Manages persistence and database operations for journal entries.
//  All operations are local and offline.
//

import Foundation
import Combine
import SwiftData

/// Handles all data persistence operations for the journal.
/// Uses SwiftData for local, offline storage in the app sandbox.
@MainActor
final class Store: ObservableObject {
    /// The SwiftData model context for database operations
    let modelContext: ModelContext

    /// Initialize the store with a model container
    /// - Parameter container: The SwiftData model container
    init(container: ModelContainer) {
        self.modelContext = ModelContext(container)
    }

    /// Create a new journal entry and persist it
    /// - Returns: The newly created entry
    func newEntry() -> JournalEntry {
        let entry = JournalEntry(text: "")
        modelContext.insert(entry)
        try? modelContext.save()
        return entry
    }

    /// Delete a journal entry
    /// - Parameter entry: The entry to delete
    func delete(_ entry: JournalEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }

    /// Save any pending changes to the database
    func save() {
        try? modelContext.save()
    }

    /// Fetch all entries sorted by creation date (newest first)
    /// - Returns: Array of all journal entries
    func fetchAllEntries() -> [JournalEntry] {
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Search entries by text content
    /// - Parameter searchText: The text to search for
    /// - Returns: Filtered array of matching entries
    func search(_ searchText: String) -> [JournalEntry] {
        guard !searchText.isEmpty else { return fetchAllEntries() }

        let allEntries = fetchAllEntries()
        return allEntries.filter { entry in
            entry.text.localizedCaseInsensitiveContains(searchText) ||
            (entry.summary ?? "").localizedCaseInsensitiveContains(searchText) ||
            entry.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
}
