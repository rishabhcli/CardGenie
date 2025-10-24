//
//  Models.swift
//  CardGenie
//
//  Data models for CardGenie using SwiftData.
//  All data is stored locally in the app sandbox (offline only).
//

import Foundation
import SwiftData

// MARK: - Content Source

/// The source type of study content
enum ContentSource: String, Codable {
    case text = "text"           // Manually typed or pasted text
    case photo = "photo"         // Scanned from camera/photos
    case voice = "voice"         // Voice recording transcript
    case pdf = "pdf"             // PDF import
    case web = "web"             // Web article
}

// MARK: - Study Content Model

/// Study content with text, AI-generated metadata, and source information.
/// Can be created from text, photos, voice recordings, or other sources.
/// SwiftData automatically persists this to a local SQLite database.
@Model
final class StudyContent {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// When the content was created
    var createdAt: Date

    /// Source of the content (text, photo, voice, etc.)
    var source: ContentSource

    /// The raw content (original text or extracted text)
    var rawContent: String

    /// Extracted or processed text (may differ from raw for photos/voice)
    var extractedText: String?

    /// Photo data if source is photo
    var photoData: Data?

    /// Audio file URL if source is voice
    var audioURL: String?

    // MARK: - AI-Generated Metadata

    /// AI-generated summary (created via Foundation Models)
    var summary: String?

    /// AI-extracted tags/keywords
    var tags: [String]

    /// Main topic category
    var topic: String?

    /// AI-generated insights or reflection
    var aiInsights: String?

    // MARK: - Relationships

    /// Flashcards generated from this content
    @Relationship(deleteRule: .cascade)
    var flashcards: [Flashcard]

    // MARK: - Initialization

    /// Initialize new study content
    /// - Parameters:
    ///   - source: The source type of content
    ///   - rawContent: The raw text content
    init(source: ContentSource, rawContent: String) {
        self.id = UUID()
        self.createdAt = .now
        self.source = source
        self.rawContent = rawContent
        self.extractedText = nil
        self.photoData = nil
        self.audioURL = nil
        self.summary = nil
        self.tags = []
        self.topic = nil
        self.aiInsights = nil
        self.flashcards = []
    }

    /// Convenience initializer for text content (backward compatibility)
    convenience init(text: String) {
        self.init(source: .text, rawContent: text)
    }

    // MARK: - Computed Properties

    /// Get the display text (extracted text if available, otherwise raw content)
    var displayText: String {
        extractedText ?? rawContent
    }

    /// Get the first line as a title
    var firstLine: String {
        displayText.split(separator: "\n").first.map(String.init) ?? "New content"
    }

    /// Get a preview snippet
    var preview: String {
        if let summary = summary, !summary.isEmpty {
            return summary
        }
        let truncated = displayText.prefix(120)
        return truncated.isEmpty ? "Empty content" : String(truncated) + (displayText.count > 120 ? "…" : "")
    }

    /// Get source icon name
    var sourceIcon: String {
        switch source {
        case .text: return "text.quote"
        case .photo: return "camera.fill"
        case .voice: return "mic.fill"
        case .pdf: return "doc.fill"
        case .web: return "globe"
        }
    }

    /// Get source label
    var sourceLabel: String {
        switch source {
        case .text: return "Text"
        case .photo: return "Photo"
        case .voice: return "Voice"
        case .pdf: return "PDF"
        case .web: return "Web"
        }
    }
}
