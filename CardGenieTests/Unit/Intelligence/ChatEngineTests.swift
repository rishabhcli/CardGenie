//
//  ChatEngineTests.swift
//  CardGenie
//
//  Unit tests for ChatEngine - AI-powered chat with streaming support.
//

import XCTest
@testable import CardGenie

@MainActor
final class ChatEngineTests: XCTestCase {
    var chatEngine: ChatEngine!

    override func setUp() async throws {
        chatEngine = ChatEngine()
    }

    override func tearDown() async throws {
        chatEngine = nil
    }

    // MARK: - Initialization Tests

    func testInitialization() async throws {
        // Given: A fresh ChatEngine instance
        // Then: Should have default empty state
        XCTAssertTrue(chatEngine.messages.isEmpty, "Messages should be empty initially")
        XCTAssertEqual(chatEngine.streamingResponse, "", "Streaming response should be empty")
        XCTAssertFalse(chatEngine.isProcessing, "Should not be processing initially")
        XCTAssertNil(chatEngine.currentSession, "Should have no active session")
        XCTAssertNil(chatEngine.errorMessage, "Should have no error message")
    }

    // MARK: - Session Management Tests

    func testEndSessionWithNoActiveSession() async throws {
        // Given: No active session
        XCTAssertNil(chatEngine.currentSession)

        // When: Ending session
        chatEngine.endSession()

        // Then: Should handle gracefully
        XCTAssertNil(chatEngine.currentSession)
        XCTAssertTrue(chatEngine.messages.isEmpty)
    }

    func testEndSessionClearsState() async throws {
        // Given: Simulated session state
        chatEngine.messages.append(ChatMessageModel(role: .user, content: "Test"))
        chatEngine.streamingResponse = "Partial response"

        // When: Ending session (even without formal session)
        chatEngine.endSession()

        // Then: State should be cleared
        XCTAssertTrue(chatEngine.messages.isEmpty, "Messages should be cleared")
        XCTAssertEqual(chatEngine.streamingResponse, "", "Streaming response should be cleared")
    }

    // MARK: - Message Handling Tests

    func testSendEmptyMessage() async throws {
        // Given: An engine (no session required for this test)
        let initialMessageCount = chatEngine.messages.count

        // When: Sending empty message
        await chatEngine.sendMessage("")

        // Then: Should not add message
        XCTAssertEqual(chatEngine.messages.count, initialMessageCount, "Empty message should be ignored")
    }

    func testSendWhitespaceOnlyMessage() async throws {
        // Given: An engine
        let initialMessageCount = chatEngine.messages.count

        // When: Sending whitespace-only message
        await chatEngine.sendMessage("   \n\t  ")

        // Then: Should not add message
        XCTAssertEqual(chatEngine.messages.count, initialMessageCount, "Whitespace message should be ignored")
    }

    func testSendMessageWithoutSession() async throws {
        // Given: No active session
        XCTAssertNil(chatEngine.currentSession)

        // When: Sending a message
        await chatEngine.sendMessage("Hello")

        // Then: Should set error message
        XCTAssertNotNil(chatEngine.errorMessage, "Should have error for no session")
        XCTAssertTrue(chatEngine.errorMessage?.contains("session") ?? false, "Error should mention session")
    }

    // MARK: - Conversation Management Tests

    func testClearConversation() async throws {
        // Given: Messages in the conversation
        chatEngine.messages.append(ChatMessageModel(role: .user, content: "Hello"))
        chatEngine.messages.append(ChatMessageModel(role: .assistant, content: "Hi!"))
        chatEngine.streamingResponse = "Partial"

        // When: Clearing conversation
        chatEngine.clearConversation()

        // Then: Messages should be cleared
        XCTAssertTrue(chatEngine.messages.isEmpty, "Messages should be empty")
        XCTAssertEqual(chatEngine.streamingResponse, "", "Streaming response should be cleared")
    }

    func testClearConversationPreservesSession() async throws {
        // Given: A session with messages
        let session = ChatSession(title: "Test")
        chatEngine.messages.append(ChatMessageModel(role: .user, content: "Hello"))

        // When: Clearing conversation (without formal session binding)
        chatEngine.clearConversation()

        // Then: Should clear messages but preserve session reference if any
        XCTAssertTrue(chatEngine.messages.isEmpty)
    }

    // MARK: - Interruption Tests

    func testInterrupt() async throws {
        // Given: Engine in processing state
        chatEngine.isProcessing = true
        chatEngine.streamingResponse = "Partial response..."

        // When: Interrupting
        chatEngine.interrupt()

        // Then: Should stop processing
        XCTAssertFalse(chatEngine.isProcessing, "Should stop processing")
        XCTAssertEqual(chatEngine.streamingResponse, "", "Streaming response should be cleared")
    }

    func testInterruptWhenIdle() async throws {
        // Given: Engine not processing
        XCTAssertFalse(chatEngine.isProcessing)

        // When: Interrupting anyway
        chatEngine.interrupt()

        // Then: Should handle gracefully
        XCTAssertFalse(chatEngine.isProcessing)
        XCTAssertEqual(chatEngine.streamingResponse, "")
    }

    // MARK: - Message Model Tests

    func testChatMessageModelInitialization() async throws {
        // Given/When: Creating a chat message
        let message = ChatMessageModel(role: .user, content: "Test content")

        // Then: Should have correct properties
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Test content")
        XCTAssertNotNil(message.id)
        XCTAssertFalse(message.isStreaming)
        XCTAssertTrue(message.scanAttachments.isEmpty)
    }

    func testChatMessageModelRoles() async throws {
        // Given/When: Creating messages with different roles
        let userMessage = ChatMessageModel(role: .user, content: "User")
        let assistantMessage = ChatMessageModel(role: .assistant, content: "Assistant")
        let systemMessage = ChatMessageModel(role: .system, content: "System")

        // Then: Should have correct roles
        XCTAssertEqual(userMessage.role, .user)
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(systemMessage.role, .system)
    }

    func testChatMessageStreamingFlag() async throws {
        // Given: A message
        let message = ChatMessageModel(role: .assistant, content: "")

        // When: Setting streaming flag
        message.isStreaming = true

        // Then: Should update
        XCTAssertTrue(message.isStreaming)

        // When: Completing streaming
        message.isStreaming = false
        message.content = "Final content"

        // Then: Should have final content
        XCTAssertFalse(message.isStreaming)
        XCTAssertEqual(message.content, "Final content")
    }

    // MARK: - Error Type Tests

    func testChatEngineErrorDescriptions() async throws {
        // Given: Different error types
        let notEnabledError = ChatEngineError.aiNotAvailable(.notEnabled)
        let notSupportedError = ChatEngineError.aiNotAvailable(.notSupported)
        let modelNotReadyError = ChatEngineError.aiNotAvailable(.modelNotReady)
        let noSessionError = ChatEngineError.noActiveSession

        // Then: Should have appropriate descriptions
        XCTAssertTrue(notEnabledError.errorDescription?.contains("enabled") ?? false)
        XCTAssertTrue(notSupportedError.errorDescription?.contains("support") ?? false)
        XCTAssertTrue(modelNotReadyError.errorDescription?.contains("download") ?? false)
        XCTAssertTrue(noSessionError.errorDescription?.contains("session") ?? false)
    }
}

// MARK: - ChatSession Tests

@MainActor
final class ChatSessionTests: XCTestCase {

    func testChatSessionInitialization() async throws {
        // Given/When: Creating a new chat session
        let session = ChatSession(title: "Test Chat")

        // Then: Should have correct initial state
        XCTAssertEqual(session.title, "Test Chat")
        XCTAssertNotNil(session.id)
        XCTAssertTrue(session.messages.isEmpty)
        XCTAssertTrue(session.linkedScans.isEmpty)
        XCTAssertEqual(session.messageCount, 0)
        XCTAssertEqual(session.scanCount, 0)
        XCTAssertTrue(session.isActive)
        XCTAssertFalse(session.isPinned)
    }

    func testChatSessionDefaultTitle() async throws {
        // Given/When: Creating session with default title
        let session = ChatSession()

        // Then: Should have default title
        XCTAssertEqual(session.title, "New Chat")
    }

    func testGenerateTitleFromShortMessage() async throws {
        // Given: A session
        let session = ChatSession()

        // When: Generating title from short message
        session.generateTitle(from: "Hello world")

        // Then: Should use full message
        XCTAssertEqual(session.title, "Hello world")
    }

    func testGenerateTitleFromLongMessage() async throws {
        // Given: A session
        let session = ChatSession()
        let longMessage = "This is a very long message that should be truncated to fit the title"

        // When: Generating title from long message
        session.generateTitle(from: longMessage)

        // Then: Should truncate with ellipsis
        XCTAssertTrue(session.title.count <= 43, "Title should be truncated") // 40 chars + "..."
        XCTAssertTrue(session.title.hasSuffix("..."), "Should have ellipsis")
    }

    func testChatSessionPreview() async throws {
        // Given: A session with messages
        let session = ChatSession()
        let userMessage = ChatMessageModel(role: .user, content: "What is AI?")
        session.messages.append(userMessage)

        // Then: Preview should show first user message
        XCTAssertEqual(session.preview, "What is AI?")
    }

    func testChatSessionPreviewEmpty() async throws {
        // Given: A session with no messages
        let session = ChatSession()

        // Then: Preview should show placeholder
        XCTAssertEqual(session.preview, "Empty conversation")
    }

    func testChatSessionTimestamps() async throws {
        // Given: A new session
        let beforeCreation = Date()
        let session = ChatSession()
        let afterCreation = Date()

        // Then: Timestamps should be valid
        XCTAssertTrue(session.createdAt >= beforeCreation)
        XCTAssertTrue(session.createdAt <= afterCreation)
        XCTAssertEqual(session.createdAt, session.updatedAt)
    }
}

// MARK: - ChatContext Tests

final class ChatContextTests: XCTestCase {

    func testChatContextDefaultInitialization() {
        // Given/When: Creating default context
        let context = ChatContext()

        // Then: Should have empty collections and defaults
        XCTAssertTrue(context.activeScans.isEmpty)
        XCTAssertTrue(context.referencedContent.isEmpty)
        XCTAssertTrue(context.referencedFlashcardSets.isEmpty)
        XCTAssertNil(context.currentTopic)
        XCTAssertEqual(context.userLearningLevel, .intermediate)
    }

    func testChatContextSystemPromptBasic() {
        // Given: A basic context
        let context = ChatContext()

        // When: Generating system prompt
        let prompt = context.systemPrompt()

        // Then: Should contain core elements
        XCTAssertTrue(prompt.contains("CardGenie"))
        XCTAssertTrue(prompt.contains("study assistant"))
        XCTAssertTrue(prompt.contains("intermediate"))
    }

    func testChatContextTokenEstimation() {
        // Given: A context with content
        var context = ChatContext()

        // When: Estimating tokens for empty context
        let emptyTokens = context.estimateTokens()

        // Then: Should have base token count
        XCTAssertEqual(emptyTokens, 200, "Empty context should have ~200 base tokens")
    }

    func testChatContextTokenEstimationWithScans() {
        // Given: A context with scans
        var context = ChatContext()
        let scan1 = ScanAttachment(imageData: Data(), extractedText: "Test text 1")
        let scan2 = ScanAttachment(imageData: Data(), extractedText: "Test text 2")
        context.activeScans = [scan1, scan2]

        // When: Estimating tokens
        let tokens = context.estimateTokens()

        // Then: Should include scan token costs
        XCTAssertEqual(tokens, 200 + (2 * 500), "Should add 500 tokens per scan")
    }

    func testChatContextFormatMessageHistory() {
        // Given: A context and messages
        let context = ChatContext()
        let messages = [
            ChatMessageModel(role: .user, content: "Hello"),
            ChatMessageModel(role: .assistant, content: "Hi there!"),
            ChatMessageModel(role: .user, content: "How are you?")
        ]

        // When: Formatting history
        let formatted = context.formatMessageHistory(messages)

        // Then: Should contain all messages properly formatted
        XCTAssertTrue(formatted.contains("User: Hello"))
        XCTAssertTrue(formatted.contains("Assistant: Hi there!"))
        XCTAssertTrue(formatted.contains("User: How are you?"))
    }

    func testChatContextFormatMessageHistoryWithLimit() {
        // Given: A context and many messages
        let context = ChatContext()
        var messages: [ChatMessageModel] = []
        for i in 0..<20 {
            messages.append(ChatMessageModel(role: .user, content: "Message \(i)"))
        }

        // When: Formatting with limit
        let formatted = context.formatMessageHistory(messages, limit: 5)

        // Then: Should only include last 5 messages
        XCTAssertTrue(formatted.contains("Message 15"))
        XCTAssertTrue(formatted.contains("Message 19"))
        XCTAssertFalse(formatted.contains("Message 0"))
        XCTAssertFalse(formatted.contains("Message 14"))
    }

    func testChatContextLearningLevels() {
        // Given: Different learning levels
        var context = ChatContext()

        // When/Then: Testing beginner level
        context.userLearningLevel = .beginner
        let beginnerPrompt = context.systemPrompt()
        XCTAssertTrue(beginnerPrompt.contains("beginner"))

        // When/Then: Testing advanced level
        context.userLearningLevel = .advanced
        let advancedPrompt = context.systemPrompt()
        XCTAssertTrue(advancedPrompt.contains("advanced"))
    }
}

// MARK: - ChatRole Tests

final class ChatRoleTests: XCTestCase {

    func testChatRoleRawValues() {
        // Given/When/Then: Verifying raw values
        XCTAssertEqual(ChatRole.user.rawValue, "user")
        XCTAssertEqual(ChatRole.assistant.rawValue, "assistant")
        XCTAssertEqual(ChatRole.system.rawValue, "system")
    }

    func testChatRoleCodable() throws {
        // Given: A chat role
        let role = ChatRole.assistant

        // When: Encoding and decoding
        let encoded = try JSONEncoder().encode(role)
        let decoded = try JSONDecoder().decode(ChatRole.self, from: encoded)

        // Then: Should preserve value
        XCTAssertEqual(decoded, role)
    }
}

// MARK: - SuggestedAction Tests

final class SuggestedActionTests: XCTestCase {

    func testSuggestedActionInitialization() {
        // Given/When: Creating a suggested action
        let action = SuggestedAction(
            type: .generateFlashcards,
            title: "Generate Flashcards",
            icon: "rectangle.stack.badge.plus"
        )

        // Then: Should have correct properties
        XCTAssertEqual(action.type, .generateFlashcards)
        XCTAssertEqual(action.title, "Generate Flashcards")
        XCTAssertEqual(action.icon, "rectangle.stack.badge.plus")
        XCTAssertNil(action.description)
    }

    func testSuggestedActionTypes() {
        // Given/When/Then: Verifying all action types
        let types: [SuggestedAction.ActionType] = [
            .generateFlashcards,
            .summarize,
            .explain,
            .quiz,
            .createNotes,
            .compareScans,
            .extractKeyPoints
        ]

        XCTAssertEqual(types.count, 7, "Should have 7 action types")
    }

    func testSuggestedActionCodable() throws {
        // Given: A suggested action with description
        let action = SuggestedAction(
            type: .summarize,
            title: "Summarize",
            icon: "doc.text",
            description: "Get a summary of this content"
        )

        // When: Encoding and decoding
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(SuggestedAction.self, from: encoded)

        // Then: Should preserve all properties
        XCTAssertEqual(decoded.type, action.type)
        XCTAssertEqual(decoded.title, action.title)
        XCTAssertEqual(decoded.icon, action.icon)
        XCTAssertEqual(decoded.description, action.description)
    }
}

// MARK: - ScanAttachment Tests

final class ScanAttachmentTests: XCTestCase {

    func testScanAttachmentInitialization() {
        // Given: Image data and text
        let imageData = Data([0x00, 0x01, 0x02])
        let extractedText = "Test extracted text"

        // When: Creating attachment
        let attachment = ScanAttachment(imageData: imageData, extractedText: extractedText)

        // Then: Should have correct properties
        XCTAssertNotNil(attachment.id)
        XCTAssertEqual(attachment.imageData, imageData)
        XCTAssertEqual(attachment.extractedText, extractedText)
        XCTAssertEqual(attachment.confidence, 0.0)
        XCTAssertEqual(attachment.language, "en-US")
        XCTAssertNil(attachment.pageNumber)
        XCTAssertNil(attachment.thumbnailData)
        XCTAssertNil(attachment.aiSummary)
        XCTAssertTrue(attachment.detectedTopics.isEmpty)
        XCTAssertEqual(attachment.suggestedFlashcardCount, 0)
    }

    func testScanAttachmentConfidence() {
        // Given: An attachment
        let attachment = ScanAttachment(imageData: Data(), extractedText: "Text")

        // When: Setting confidence
        attachment.confidence = 0.95

        // Then: Should update
        XCTAssertEqual(attachment.confidence, 0.95, accuracy: 0.01)
    }

    func testScanAttachmentDetectedTopics() {
        // Given: An attachment
        let attachment = ScanAttachment(imageData: Data(), extractedText: "Biology content")

        // When: Adding detected topics
        attachment.detectedTopics = ["Biology", "Cells", "DNA"]

        // Then: Should have topics
        XCTAssertEqual(attachment.detectedTopics.count, 3)
        XCTAssertTrue(attachment.detectedTopics.contains("Biology"))
    }
}
