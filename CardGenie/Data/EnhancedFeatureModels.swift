//
//  EnhancedFeatureModels.swift
//  CardGenie
//
//  Data models for AR Memory Palace, Handwritten Cards,
//  Smart Scheduler, and Concept Maps.
//

import Foundation
import SwiftData
import PencilKit
import ARKit

// MARK: - AR Memory Palace

/// Stores AR world map and anchor data for a flashcard set
@Model
final class ARMemoryPalace {
    @Attribute(.unique) var id: UUID

    /// The flashcard set this memory palace belongs to
    @Relationship(inverse: \FlashcardSet.arMemoryPalace)
    var flashcardSet: FlashcardSet?

    /// Serialized ARWorldMap data
    var worldMapData: Data?

    /// Card anchor configurations
    @Relationship(deleteRule: .cascade)
    var cardAnchors: [CardAnchor]

    /// When the memory palace was created
    var createdAt: Date

    /// Last time the world map was updated
    var lastUpdated: Date

    init() {
        self.id = UUID()
        self.cardAnchors = []
        self.createdAt = Date()
        self.lastUpdated = Date()
    }
}

/// Represents a flashcard anchored in AR space
@Model
final class CardAnchor {
    @Attribute(.unique) var id: UUID

    /// Reference to the flashcard
    var flashcardID: UUID

    /// Anchor name (unique identifier for ARKit)
    var anchorName: String

    /// Position in world space (serialized)
    var positionX: Float
    var positionY: Float
    var positionZ: Float

    /// Rotation (quaternion)
    var rotationX: Float
    var rotationY: Float
    var rotationZ: Float
    var rotationW: Float

    /// Custom label for this location (e.g., "Desk", "Bed", "Door")
    var locationLabel: String

    /// Proximity radius in meters (when user is within this, card activates)
    var proximityRadius: Float

    /// Parent memory palace
    @Relationship(inverse: \ARMemoryPalace.cardAnchors)
    var memoryPalace: ARMemoryPalace?

    init(flashcardID: UUID, anchorName: String, locationLabel: String) {
        self.id = UUID()
        self.flashcardID = flashcardID
        self.anchorName = anchorName
        self.locationLabel = locationLabel
        self.positionX = 0
        self.positionY = 0
        self.positionZ = 0
        self.rotationX = 0
        self.rotationY = 0
        self.rotationZ = 0
        self.rotationW = 1
        self.proximityRadius = 0.5 // Default 0.5 meters
    }

    /// Set position from simd_float3
    func setPosition(_ position: simd_float3) {
        self.positionX = position.x
        self.positionY = position.y
        self.positionZ = position.z
    }

    /// Set rotation from simd_quatf
    func setRotation(_ rotation: simd_quatf) {
        self.rotationX = rotation.vector.x
        self.rotationY = rotation.vector.y
        self.rotationZ = rotation.vector.z
        self.rotationW = rotation.vector.w
    }

    /// Get position as simd_float3
    func getPosition() -> simd_float3 {
        simd_float3(positionX, positionY, positionZ)
    }

    /// Get rotation as simd_quatf
    func getRotation() -> simd_quatf {
        simd_quatf(ix: rotationX, iy: rotationY, iz: rotationZ, r: rotationW)
    }
}

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
// Note: Relationships are managed via inverse relationships in ARMemoryPalace and HandwritingData models
