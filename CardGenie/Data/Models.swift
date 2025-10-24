//
//  Models.swift
//  CardGenie
//
//  Data models for the journal app using SwiftData.
//  All data is stored locally in the app sandbox (offline only).
//

import Foundation
import SwiftData

/// A journal entry with text content, AI-generated metadata, and timestamps.
/// SwiftData automatically persists this to a local SQLite database.
@Model
final class JournalEntry {
    /// Unique identifier for the entry
    @Attribute(.unique) var id: UUID

    /// When the entry was created
    var createdAt: Date

    /// The main text content of the journal entry
    var text: String

    /// AI-generated summary (optional, created via Foundation Models)
    var summary: String?

    /// AI-extracted tags/keywords for the entry
    var tags: [String]

    /// Optional AI-generated reflection or insight
    var reflection: String?

    /// Initialize a new journal entry
    /// - Parameter text: Initial text content (can be empty for new entries)
    init(text: String) {
        self.id = UUID()
        self.createdAt = .now
        self.text = text
        self.summary = nil
        self.tags = []
        self.reflection = nil
    }

    /// Computed property to get the first line as a title
    var firstLine: String {
        text.split(separator: "\n").first.map(String.init) ?? "New entry"
    }

    /// Computed property to get a preview snippet
    var preview: String {
        if let summary = summary, !summary.isEmpty {
            return summary
        }
        let truncated = text.prefix(120)
        return truncated.isEmpty ? "Empty entry" : String(truncated) + (text.count > 120 ? "…" : "")
    }
}
