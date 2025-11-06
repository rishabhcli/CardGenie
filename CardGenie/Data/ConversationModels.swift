//
//  ConversationModels.swift
//  CardGenie
//
//  SwiftData models for conversational voice assistant with persistent session history.
//

import Foundation
import SwiftData

// MARK: - Conversation Session

/// A conversational session with the AI tutor, persisted across app launches
@Model
final class ConversationSession {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Auto-generated title from first message
    var title: String

    /// When the conversation started
    var createdAt: Date

    /// Last update timestamp
    var updatedAt: Date

    /// All messages in this conversation
    @Relationship(deleteRule: .cascade, inverse: \VoiceConversationMessage.session)
    var messages: [VoiceConversationMessage]

    // MARK: - Context Linking

    /// StudyContent this conversation is about (optional)
    var linkedContentID: UUID?

    /// FlashcardSet being discussed (optional)
    var linkedFlashcardSetID: UUID?

    // MARK: - Session Metadata

    /// Total duration of conversation
    var totalDuration: TimeInterval

    /// Number of messages exchanged
    var messageCount: Int

    /// Whether this session is currently active
    var isActive: Bool

    // MARK: - Initialization

    init(
        title: String = "New Conversation",
        linkedContentID: UUID? = nil,
        linkedFlashcardSetID: UUID? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messages = []
        self.linkedContentID = linkedContentID
        self.linkedFlashcardSetID = linkedFlashcardSetID
        self.totalDuration = 0
        self.messageCount = 0
        self.isActive = false
    }

    // MARK: - Computed Properties

    /// Preview of the conversation (first user message)
    var preview: String {
        messages.first(where: { $0.role == .user })?.content ?? "Empty conversation"
    }
}

// MARK: - Message Role (Voice Assistant)

/// Role of a voice assistant conversation message
enum VoiceMessageRole: String, Codable {
    case user        // User's spoken or typed input
    case assistant   // AI assistant's response
    case system      // System-injected context
}

// MARK: - Voice Conversation Message

/// A single message in a voice conversation (user, assistant, or system)
@Model
final class VoiceConversationMessage {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Message role (user, assistant, system)
    var role: VoiceMessageRole

    /// Message content text
    var content: String

    /// When this message was created
    var timestamp: Date

    // MARK: - Audio Metadata

    /// Whether this message has associated audio
    var hasAudio: Bool

    /// Duration of audio (if any)
    var audioDuration: TimeInterval

    // MARK: - Streaming Metadata

    /// Whether this message is currently streaming
    var isStreaming: Bool

    /// Streaming chunks for debugging (not displayed in UI)
    var streamingChunks: [String]

    // MARK: - Relationship

    /// Parent conversation session
    var session: ConversationSession?

    // MARK: - Initialization

    init(role: VoiceMessageRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.hasAudio = false
        self.audioDuration = 0
        self.isStreaming = false
        self.streamingChunks = []
    }
}

// MARK: - Conversation Context

/// Runtime context for a conversation (not persisted, used during active session)
struct ConversationContext {
    /// Study content being discussed (optional)
    var studyContent: StudyContent?

    /// Flashcard set being worked on (optional)
    var flashcardSet: FlashcardSet?

    /// Recent flashcards for reference (optional)
    var recentFlashcards: [Flashcard]

    /// Current topic of discussion (optional)
    var currentTopic: String?

    // MARK: - Initialization

    init(
        studyContent: StudyContent? = nil,
        flashcardSet: FlashcardSet? = nil,
        recentFlashcards: [Flashcard] = [],
        currentTopic: String? = nil
    ) {
        self.studyContent = studyContent
        self.flashcardSet = flashcardSet
        self.recentFlashcards = recentFlashcards
        self.currentTopic = currentTopic
    }

    // MARK: - System Prompt Generation

    /// Generate system prompt with context awareness
    func systemPrompt() -> String {
        var prompt = """
        You are CardGenie, an AI study tutor having a natural conversation with a student.

        Guidelines:
        - Keep responses concise (2-3 sentences) to enable back-and-forth dialogue
        - Ask follow-up questions to check understanding
        - Be encouraging and supportive
        - If the student seems confused, break concepts into smaller parts
        - Remember previous questions in this conversation
        - Use the Socratic method: guide learning through questions
        """

        // Add study content context
        if let content = studyContent {
            let contentPreview = content.displayText.prefix(300)
            prompt += """


            The student is studying this content:
            Topic: \(content.topic ?? "General")
            Summary: \(content.summary ?? String(contentPreview))
            """
        }

        // Add flashcard set context
        if let set = flashcardSet {
            prompt += """


            The student is working with the "\(set.topicLabel)" flashcard set.
            Total cards: \(set.cardCount)
            Due cards: \(set.dueCount)
            """
        }

        // Add recent flashcards context
        if !recentFlashcards.isEmpty {
            let cardSummary = recentFlashcards.prefix(3).map { card in
                "Q: \(card.question.prefix(50))..."
            }.joined(separator: "\n")

            prompt += """


            Recent flashcards the student reviewed:
            \(cardSummary)
            """
        }

        return prompt
    }

    /// Format recent messages for context window (limits token usage)
    func formatRecentMessages(_ messages: [VoiceConversationMessage], limit: Int = 5) -> String {
        messages
            .suffix(limit)
            .map { "\($0.role.rawValue.capitalized): \($0.content)" }
            .joined(separator: "\n\n")
    }
}
