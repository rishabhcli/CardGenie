//
//  Store.swift
//  CardGenie
//
//  Manages persistence and database operations for study content.
//  All operations are local and offline.
//

import Foundation
import Combine
import SwiftData

/// Handles all data persistence operations for study content.
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

    /// Create new study content and persist it
    /// - Parameter source: The source type of content (defaults to text)
    /// - Returns: The newly created content
    func newContent(source: ContentSource = .text) -> StudyContent {
        let content = StudyContent(source: source, rawContent: "")
        modelContext.insert(content)
        try? modelContext.save()
        return content
    }

    /// Delete study content
    /// - Parameter content: The content to delete
    func delete(_ content: StudyContent) {
        modelContext.delete(content)
        try? modelContext.save()
    }

    /// Save any pending changes to the database
    func save() {
        try? modelContext.save()
    }

    /// Fetch all content sorted by creation date (newest first)
    /// - Returns: Array of all study content
    func fetchAllContent() -> [StudyContent] {
        let descriptor = FetchDescriptor<StudyContent>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Fetch content by source type
    /// - Parameter source: The content source to filter by
    /// - Returns: Array of matching content
    func fetchContent(bySource source: ContentSource) -> [StudyContent] {
        let allContent = fetchAllContent()
        return allContent.filter { $0.source == source }
    }

    /// Search content by text
    /// - Parameter searchText: The text to search for
    /// - Returns: Filtered array of matching content
    func search(_ searchText: String) -> [StudyContent] {
        guard !searchText.isEmpty else { return fetchAllContent() }

        let allContent = fetchAllContent()
        return allContent.filter { content in
            content.displayText.localizedCaseInsensitiveContains(searchText) ||
            (content.summary ?? "").localizedCaseInsensitiveContains(searchText) ||
            content.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
            (content.topic ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
}
