//
//  EnhancedModels.swift
//  CardGenie
//
//  Enhanced data models for multi-source content support.
//

import Foundation
import SwiftData

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
    var id: UUID
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
    var id: UUID
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
        self.embedding = Data(bytes: vector, count: vector.count * MemoryLayout<Float>.size)
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
    var id: UUID
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
            // Store as JSON in a string property
            // This is a simplified approach
            return nil
        }
        set {
            // Store metadata
        }
    }
}

// MARK: - Highlight Marker

@Model
final class HighlightMarker {
    var id: UUID
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
