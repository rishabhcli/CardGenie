//
//  ChatModels.swift
//  CardGenie
//
//  SwiftData models for AI Chat with integrated scanning capabilities.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Chat Session

/// A conversational chat session with the AI assistant
@Model
final class ChatSession {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Auto-generated title from first message
    var title: String

    /// When the session was created
    var createdAt: Date

    /// Last update timestamp
    var updatedAt: Date

    /// All messages in this session
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage]

    /// Scanned attachments linked to this session
    @Relationship(deleteRule: .cascade, inverse: \ScanAttachment.chatSession)
    var linkedScans: [ScanAttachment]

    // MARK: - Context Tracking

    /// StudyContent IDs referenced in this chat
    var linkedContentIDs: [UUID]

    /// FlashcardSet IDs referenced in this chat
    var linkedFlashcardSetIDs: [UUID]

    // MARK: - Session Metadata

    /// Number of messages exchanged
    var messageCount: Int

    /// Number of scans attached
    var scanCount: Int

    /// Number of flashcard sets generated from this chat
    var flashcardGenerationCount: Int

    /// Whether this session is currently active
    var isActive: Bool

    /// Whether this session is pinned to top
    var isPinned: Bool

    // MARK: - Initialization

    init(title: String = "New Chat") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messages = []
        self.linkedScans = []
        self.linkedContentIDs = []
        self.linkedFlashcardSetIDs = []
        self.messageCount = 0
        self.scanCount = 0
        self.flashcardGenerationCount = 0
        self.isActive = true
        self.isPinned = false
    }

    // MARK: - Computed Properties

    /// Auto-generate title from first user message
    func generateTitle(from firstMessage: String) {
        let truncated = firstMessage.prefix(40)
        self.title = String(truncated) + (firstMessage.count > 40 ? "..." : "")
    }

    /// Preview of the conversation (first user message)
    var preview: String {
        messages.first(where: { $0.role == .user })?.content ?? "Empty conversation"
    }
}

// MARK: - Chat Message

/// A single message in a chat conversation
@Model
final class ChatMessage {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Message role (user, assistant, system)
    var role: ChatRole

    /// Message content text
    var content: String

    /// When this message was created
    var timestamp: Date

    // MARK: - Attachments

    /// Scanned images attached to this message
    @Relationship(deleteRule: .cascade, inverse: \ScanAttachment.message)
    var scanAttachments: [ScanAttachment]

    /// Flashcard IDs generated from this message
    var generatedFlashcardIDs: [UUID]

    // MARK: - Streaming Metadata

    /// Whether this message is currently streaming
    var isStreaming: Bool

    /// Streaming chunks for debugging/replay
    var streamingChunks: [String]

    // MARK: - AI Suggestions

    /// Suggested actions encoded as JSON
    var suggestedActionsData: Data?

    // MARK: - Relationship

    /// Parent chat session
    var session: ChatSession?

    // MARK: - Initialization

    init(role: ChatRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.scanAttachments = []
        self.generatedFlashcardIDs = []
        self.isStreaming = false
        self.streamingChunks = []
        self.suggestedActionsData = nil
    }

    // MARK: - Computed Properties

    /// Decode suggested actions from data
    var suggestedActions: [SuggestedAction] {
        get {
            guard let data = suggestedActionsData else { return [] }
            return (try? JSONDecoder().decode([SuggestedAction].self, from: data)) ?? []
        }
        set {
            suggestedActionsData = try? JSONEncoder().encode(newValue)
        }
    }
}

// MARK: - Chat Role

/// Role of a chat message
enum ChatRole: String, Codable {
    case user        // User's text or voice input
    case assistant   // AI assistant's response
    case system      // System-injected context messages
}

// MARK: - Scan Attachment

/// A scanned image with OCR text and AI analysis
@Model
final class ScanAttachment {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Compressed image data (JPEG)
    var imageData: Data?

    /// Small thumbnail for previews
    var thumbnailData: Data?

    /// OCR-extracted text
    var extractedText: String

    /// When the image was scanned
    var scannedAt: Date

    // MARK: - OCR Metadata

    /// OCR confidence level (0.0-1.0)
    var confidence: Float

    /// Detected language code (e.g., "en-US")
    var language: String

    /// Page number for multi-page scans
    var pageNumber: Int?

    // MARK: - AI Analysis Results (Cached)

    /// AI-generated summary of the content
    var aiSummary: String?

    /// Detected topics/subjects
    var detectedTopics: [String]

    /// Suggested number of flashcards to generate
    var suggestedFlashcardCount: Int

    // MARK: - Relationships

    /// Message this scan is attached to
    var message: ChatMessage?

    /// Chat session this scan belongs to
    var chatSession: ChatSession?

    // MARK: - Initialization

    init(imageData: Data, extractedText: String) {
        self.id = UUID()
        self.imageData = imageData
        self.extractedText = extractedText
        self.scannedAt = Date()
        self.confidence = 0.0
        self.language = "en-US"
        self.pageNumber = nil
        self.thumbnailData = nil
        self.aiSummary = nil
        self.detectedTopics = []
        self.suggestedFlashcardCount = 0
    }
}

// MARK: - Suggested Action

/// A quick action button suggested by the AI
struct SuggestedAction: Codable, Identifiable {
    var id: UUID = UUID()
    var type: ActionType
    var title: String
    var icon: String
    var description: String?

    enum ActionType: String, Codable {
        case generateFlashcards
        case summarize
        case explain
        case quiz
        case createNotes
        case compareScans
        case extractKeyPoints
    }
}

// MARK: - Chat Context

/// Runtime context for a chat session (not persisted)
struct ChatContext {
    // MARK: - Current Session State

    /// Active scans in this conversation
    var activeScans: [ScanAttachment] = []

    /// Referenced study content
    var referencedContent: [StudyContent] = []

    /// Referenced flashcard sets
    var referencedFlashcardSets: [FlashcardSet] = []

    // MARK: - Conversation Metadata

    /// Current discussion topic
    var currentTopic: String?

    /// User's learning level
    var userLearningLevel: LearningLevel = .intermediate

    enum LearningLevel: String {
        case beginner
        case intermediate
        case advanced
    }

    // MARK: - System Prompt Generation

    /// Generate context-aware system prompt for AI
    func systemPrompt() -> String {
        var prompt = """
        You are CardGenie's AI study assistant, helping students learn through natural conversation.

        Guidelines:
        - Be conversational and encouraging
        - Keep responses concise (2-4 sentences unless explaining complex topics)
        - Use examples and analogies when helpful
        - Ask follow-up questions to check understanding
        - Reference scanned content when relevant
        - Suggest actionable next steps (create flashcards, take quiz, etc.)

        Student level: \(userLearningLevel.rawValue)
        """

        // Add scan context
        if !activeScans.isEmpty {
            prompt += """


            The student has scanned \(activeScans.count) image(s) in this conversation:
            """

            for (index, scan) in activeScans.prefix(3).enumerated() {
                let preview = scan.extractedText.prefix(200)
                prompt += """

            Scan \(index + 1): \(preview)...
            """

                if let topic = scan.detectedTopics.first {
                    prompt += " (Topic: \(topic))"
                }
            }
        }

        // Add content context
        if !referencedContent.isEmpty {
            prompt += """


            Referenced study materials:
            """

            for content in referencedContent.prefix(3) {
                prompt += """

            - \(content.topic ?? "Untitled"): \(content.summary ?? "No summary")
            """
            }
        }

        // Add flashcard context
        if !referencedFlashcardSets.isEmpty {
            prompt += """


            Referenced flashcard sets:
            """

            for set in referencedFlashcardSets.prefix(3) {
                prompt += """

            - \(set.topicLabel): \(set.cardCount) cards, \(set.dueCount) due
            """
            }
        }

        return prompt
    }

    // MARK: - Message History Formatting

    /// Format conversation history for context window
    func formatMessageHistory(_ messages: [ChatMessage], limit: Int = 10) -> String {
        let recentMessages = messages.suffix(limit)

        return recentMessages.map { message in
            var formatted = "\(message.role.rawValue.capitalized): \(message.content)"

            // Include scan references
            if !message.scanAttachments.isEmpty {
                formatted += " [Attached \(message.scanAttachments.count) scan(s)]"
            }

            return formatted
        }.joined(separator: "\n\n")
    }

    // MARK: - Token Estimation

    /// Estimate token count for context budget management
    func estimateTokens() -> Int {
        var tokens = 0

        // System prompt: ~200 tokens
        tokens += 200

        // Scans: ~500 tokens each (text preview)
        tokens += activeScans.count * 500

        // Content references: ~100 tokens each
        tokens += referencedContent.count * 100

        // Flashcard references: ~50 tokens each
        tokens += referencedFlashcardSets.count * 50

        return tokens
    }
}
