//
//  Models.swift
//  CardGenie
//
//  Core data models: study content, sources, documents, and feature-specific models.
//

import Foundation
import SwiftData
import PencilKit

// MARK: - Core Models (StudyContent, ContentSource)


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

    /// Photo data if source is photo (single page)
    var photoData: Data?

    /// Multiple page images for multi-page scans (encoded as array of Data)
    var photoPages: [Data]?

    /// Number of pages in multi-page scan
    var pageCount: Int?

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
        self.photoPages = nil
        self.pageCount = nil
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

// MARK: - Source Models (SourceDocument, NoteChunk)

// MARK: - Source Document Types

enum SourceKind: String, Codable {
    case pdf
    case video
    case image
    case audio
    case csv
    case text
    case lecture // Live recording
}

// MARK: - Source Document

@Model
final class SourceDocument {
    @Attribute(.unique) var id: UUID
    var kind: SourceKind
    var fileName: String
    var fileURL: URL?
    var createdAt: Date
    var processedAt: Date?
    var totalPages: Int?
    var duration: TimeInterval? // For video/audio
    var fileSize: Int64

    // Relationships
    @Relationship(deleteRule: .cascade) var chunks: [NoteChunk] = []
    @Relationship(deleteRule: .cascade) var generatedCards: [Flashcard] = []

    init(
        kind: SourceKind,
        fileName: String,
        fileURL: URL? = nil,
        fileSize: Int64 = 0
    ) {
        self.id = UUID()
        self.kind = kind
        self.fileName = fileName
        self.fileURL = fileURL
        self.createdAt = Date()
        self.fileSize = fileSize
    }
}

// MARK: - Note Chunk

@Model
final class NoteChunk {
    @Attribute(.unique) var id: UUID
    var text: String
    var summary: String?
    var chunkIndex: Int

    // Source tracking
    var pageNumber: Int?
    var timestampRange: String? // JSON encoded Range<Double>
    var slideNumber: Int?

    // Embedding for RAG
    var embedding: Data? // Encoded [Float]
    var embeddingVersion: Int // Track embedding model version

    // Relationships
    var sourceDocument: SourceDocument?
    @Relationship(deleteRule: .cascade) var generatedCards: [Flashcard] = []

    init(
        text: String,
        chunkIndex: Int,
        pageNumber: Int? = nil,
        timestampRange: String? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.chunkIndex = chunkIndex
        self.pageNumber = pageNumber
        self.timestampRange = timestampRange
        self.embeddingVersion = 1
    }

    // MARK: - Embedding Helpers

    func setEmbedding(_ vector: [Float]) {
        // Encode Float array to Data
        self.embedding = vector.withUnsafeBytes { Data($0) }
    }

    func getEmbedding() -> [Float]? {
        guard let data = embedding else { return nil }
        let count = data.count / MemoryLayout<Float>.size
        return data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self).prefix(count))
        }
    }
}

// MARK: - Lecture Session

@Model
final class LectureSession {
    @Attribute(.unique) var id: UUID
    var title: String
    var recordedAt: Date
    var duration: TimeInterval
    var audioFileURL: URL?
    var transcriptComplete: Bool
    var collaborationGroupID: UUID?
    private(set) var sharePlayStateRaw: String

    @Relationship(deleteRule: .cascade)
    var liveHighlights: [HighlightMarker] = []

    // Real-time summary
    var liveNotes: String = ""

    // Relationships
    @Relationship(deleteRule: .cascade) var chunks: [NoteChunk] = []
    var sourceDocument: SourceDocument?

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.recordedAt = Date()
        self.duration = 0
        self.transcriptComplete = false
        self.sharePlayStateRaw = LectureCollaborationState.inactive.rawValue
    }

    var sharePlayState: LectureCollaborationState {
        get { LectureCollaborationState(rawValue: sharePlayStateRaw) ?? .inactive }
        set { sharePlayStateRaw = newValue.rawValue }
    }
}

// MARK: - Collaboration State

enum LectureCollaborationState: String, Codable {
    case inactive
    case waiting
    case active
    case ended
}

// MARK: - Timestamp Range Helper

struct TimestampRange: Codable, Sendable {
    let start: Double
    let end: Double

    var formatted: String {
        let startMin = Int(start) / 60
        let startSec = Int(start) % 60
        let endMin = Int(end) / 60
        let endSec = Int(end) % 60
        return String(format: "%02d:%02d - %02d:%02d", startMin, startSec, endMin, endSec)
    }
}

@MainActor
extension NoteChunk {
    var timeRange: TimestampRange? {
        guard let json = timestampRange,
              let data = json.data(using: .utf8),
              let range = try? JSONDecoder().decode(TimestampRange.self, from: data) else {
            return nil
        }
        return range
    }

    func setTimeRange(_ range: TimestampRange) {
        if let data = try? JSONEncoder().encode(range),
           let json = String(data: data, encoding: .utf8) {
            self.timestampRange = json
        }
    }
}

// MARK: - Card Kind Extension

enum CardKind: String, Codable {
    case qa         // Question & Answer
    case cloze      // Fill in the blank
    case multipleChoice // Multiple choice
    case matching   // Matching pairs
    case trueOrFalse // True/False
}

extension Flashcard {
    // Add additional properties for new card types
    var choices: [String]? {
        get {
            guard let json = metadata?["choices"] as? String,
                  let data = json.data(using: .utf8),
                  let array = try? JSONDecoder().decode([String].self, from: data) else {
                return nil
            }
            return array
        }
        set {
            if metadata == nil {
                metadata = [:]
            }
            if let array = newValue,
               let data = try? JSONEncoder().encode(array),
               let json = String(data: data, encoding: .utf8) {
                metadata?["choices"] = json
            }
        }
    }

    var correctChoiceIndex: Int? {
        get { metadata?["correctIndex"] as? Int }
        set {
            if metadata == nil {
                metadata = [:]
            }
            metadata?["correctIndex"] = newValue
        }
    }

    var metadata: [String: Any]? {
        get {
            guard let json = metadataJSON,
                  let data = json.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return nil }
            return dict
        }
        set {
            guard let dict = newValue,
                  let data = try? JSONSerialization.data(withJSONObject: dict),
                  let json = String(data: data, encoding: .utf8)
            else {
                metadataJSON = nil
                return
            }
            metadataJSON = json
        }
    }
}

// MARK: - Highlight Marker

@Model
final class HighlightMarker {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var startTime: Double
    var endTime: Double
    var transcriptSnippet: String
    var summary: String?
    var authorName: String?
    var authorID: UUID?
    var confidence: Double
    var isPinned: Bool
    var isCardCandidate: Bool

    @Relationship
    var session: LectureSession?

    @Relationship
    var linkedFlashcard: Flashcard?

    init(
        startTime: Double,
        endTime: Double,
        transcriptSnippet: String,
        summary: String?,
        authorName: String?,
        authorID: UUID?,
        confidence: Double,
        isPinned: Bool = false,
        isCardCandidate: Bool = false
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.startTime = startTime
        self.endTime = endTime
        self.transcriptSnippet = transcriptSnippet
        self.summary = summary
        self.authorName = authorName
        self.authorID = authorID
        self.confidence = confidence
        self.isPinned = isPinned
        self.isCardCandidate = isCardCandidate
    }
}

extension HighlightMarker {
    var timeRange: TimestampRange {
        TimestampRange(start: startTime, end: endTime)
    }
}

// MARK: - Feature Models

// MARK: - Handwritten Flashcards

/// Stores handwriting data for a flashcard
@Model
final class HandwritingData {
    @Attribute(.unique) var id: UUID

    /// Serialized PKDrawing for question side
    var questionDrawingData: Data?

    /// Serialized PKDrawing for answer side
    var answerDrawingData: Data?

    /// OCR-extracted text from question drawing
    var questionOCRText: String?

    /// OCR-extracted text from answer drawing
    var answerOCRText: String?

    /// Whether this card is primarily handwritten (vs typed)
    var isPrimaryHandwritten: Bool

    /// When the handwriting was created
    var createdAt: Date

    /// Last time handwriting was modified
    var lastModified: Date

    init() {
        self.id = UUID()
        self.isPrimaryHandwritten = false
        self.createdAt = Date()
        self.lastModified = Date()
    }

    /// Save a PKDrawing for the question
    func setQuestionDrawing(_ drawing: PKDrawing) throws {
        self.questionDrawingData = drawing.dataRepresentation()
        self.lastModified = Date()
    }

    /// Save a PKDrawing for the answer
    func setAnswerDrawing(_ drawing: PKDrawing) throws {
        self.answerDrawingData = drawing.dataRepresentation()
        self.lastModified = Date()
    }

    /// Load the question PKDrawing
    func getQuestionDrawing() throws -> PKDrawing? {
        guard let data = questionDrawingData else { return nil }
        return try PKDrawing(data: data)
    }

    /// Load the answer PKDrawing
    func getAnswerDrawing() throws -> PKDrawing? {
        guard let data = answerDrawingData else { return nil }
        return try PKDrawing(data: data)
    }
}

// MARK: - Smart Study Scheduler

/// A generated study plan with scheduled sessions
@Model
final class StudyPlan {
    @Attribute(.unique) var id: UUID

    /// Plan title (e.g., "Physics Exam Prep")
    var title: String

    /// Target exam/deadline date
    var targetDate: Date

    /// When this plan was generated
    var generatedAt: Date

    /// Flashcard sets included in this plan
    var flashcardSetIDs: [UUID]

    /// Scheduled study sessions
    @Relationship(deleteRule: .cascade)
    var sessions: [StudySession]

    /// Current mastery percentage (0-100)
    var currentMastery: Double

    /// Target mastery percentage (0-100)
    var targetMastery: Double

    /// Whether plan is active
    var isActive: Bool

    /// Last time plan was recalculated
    var lastRecalculated: Date?

    init(title: String, targetDate: Date, flashcardSetIDs: [UUID]) {
        self.id = UUID()
        self.title = title
        self.targetDate = targetDate
        self.flashcardSetIDs = flashcardSetIDs
        self.sessions = []
        self.currentMastery = 0
        self.targetMastery = 85
        self.isActive = true
        self.generatedAt = Date()
    }
}

/// A scheduled study session
@Model
final class StudySession {
    @Attribute(.unique) var id: UUID

    /// Scheduled start time
    var scheduledTime: Date

    /// Duration in minutes
    var durationMinutes: Int

    /// Topic/focus for this session
    var topic: String

    /// Specific flashcard set IDs to study
    var flashcardSetIDs: [UUID]

    /// Session type
    var sessionType: SessionType

    /// Whether session is completed
    var isCompleted: Bool

    /// Actual completion time (if completed)
    var completedAt: Date?

    /// Cards reviewed count (if completed)
    var cardsReviewed: Int

    /// Parent study plan
    @Relationship(inverse: \StudyPlan.sessions)
    var studyPlan: StudyPlan?

    enum SessionType: String, Codable {
        case newCards = "Learn New Cards"
        case review = "Review"
        case weakCards = "Practice Weak Areas"
        case mixed = "Mixed Practice"
        case cramming = "Intensive Review"
    }

    init(scheduledTime: Date, duration: Int, topic: String, flashcardSetIDs: [UUID], type: SessionType) {
        self.id = UUID()
        self.scheduledTime = scheduledTime
        self.durationMinutes = duration
        self.topic = topic
        self.flashcardSetIDs = flashcardSetIDs
        self.sessionType = type
        self.isCompleted = false
        self.cardsReviewed = 0
    }
}

// MARK: - Concept Maps

/// A concept map generated from notes
@Model
final class ConceptMap {
    @Attribute(.unique) var id: UUID

    /// Title of the concept map
    var title: String

    /// Source document IDs used to generate this map
    var sourceDocumentIDs: [UUID]

    /// When the map was generated
    var createdAt: Date

    /// Last time map was updated
    var lastUpdated: Date

    /// Concept nodes
    @Relationship(deleteRule: .cascade)
    var nodes: [ConceptNode]

    /// Relationships between concepts
    @Relationship(deleteRule: .cascade)
    var edges: [ConceptEdge]

    init(title: String, sourceDocumentIDs: [UUID]) {
        self.id = UUID()
        self.title = title
        self.sourceDocumentIDs = sourceDocumentIDs
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.nodes = []
        self.edges = []
    }
}

/// A node in the concept map (represents a concept/entity)
@Model
final class ConceptNode {
    @Attribute(.unique) var id: UUID

    /// The concept name (e.g., "Photosynthesis", "Mitochondria")
    var name: String

    /// Type of entity (person, process, structure, etc.)
    var entityType: String

    /// Definition or description
    var definition: String

    /// Related flashcard IDs
    var relatedFlashcardIDs: [UUID]

    /// Related note chunk IDs
    var relatedChunkIDs: [UUID]

    /// Importance score (0-1, for sizing in visualization)
    var importance: Double

    /// Position in graph (for layout persistence)
    var layoutX: Double
    var layoutY: Double

    /// Parent concept map
    @Relationship(inverse: \ConceptMap.nodes)
    var conceptMap: ConceptMap?

    init(name: String, entityType: String, definition: String) {
        self.id = UUID()
        self.name = name
        self.entityType = entityType
        self.definition = definition
        self.relatedFlashcardIDs = []
        self.relatedChunkIDs = []
        self.importance = 0.5
        self.layoutX = 0
        self.layoutY = 0
    }
}

/// An edge connecting two concepts (represents a relationship)
@Model
final class ConceptEdge {
    @Attribute(.unique) var id: UUID

    /// Source concept ID
    var sourceNodeID: UUID

    /// Target concept ID
    var targetNodeID: UUID

    /// Relationship type (e.g., "is part of", "produces", "requires")
    var relationshipType: String

    /// Relationship strength (0-1, for visual weight)
    var strength: Double

    /// Parent concept map
    @Relationship(inverse: \ConceptMap.edges)
    var conceptMap: ConceptMap?

    init(sourceNodeID: UUID, targetNodeID: UUID, relationshipType: String, strength: Double = 0.5) {
        self.id = UUID()
        self.sourceNodeID = sourceNodeID
        self.targetNodeID = targetNodeID
        self.relationshipType = relationshipType
        self.strength = strength
    }
}

// MARK: - Helper Extensions
// Note: Relationships are managed via inverse relationships in HandwritingData model
