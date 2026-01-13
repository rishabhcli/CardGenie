//
//  PromptManagerTests.swift
//  CardGenie
//
//  Unit tests for PromptManager - AI prompt templates and context management.
//

import XCTest
@testable import CardGenie

// MARK: - ChatMode Tests

final class ChatModeTests: XCTestCase {

    func testChatModeRawValues() {
        // Given/When/Then: Verify raw values
        XCTAssertEqual(ChatMode.general.rawValue, "general_assistant")
        XCTAssertEqual(ChatMode.tutor.rawValue, "study_tutor")
        XCTAssertEqual(ChatMode.quiz.rawValue, "quiz_master")
        XCTAssertEqual(ChatMode.explainer.rawValue, "concept_explainer")
        XCTAssertEqual(ChatMode.memory.rawValue, "memory_coach")
        XCTAssertEqual(ChatMode.planner.rawValue, "study_planner")
        XCTAssertEqual(ChatMode.exam.rawValue, "exam_simulator")
    }

    func testChatModeAllCases() {
        // Given/When: Getting all cases
        let allCases = ChatMode.allCases

        // Then: Should have 7 modes
        XCTAssertEqual(allCases.count, 7)
    }

    func testChatModeDisplayNames() {
        // Given/When/Then: Verify display names
        XCTAssertEqual(ChatMode.general.displayName, "General Assistant")
        XCTAssertEqual(ChatMode.tutor.displayName, "Study Tutor")
        XCTAssertEqual(ChatMode.quiz.displayName, "Quiz Master")
        XCTAssertEqual(ChatMode.explainer.displayName, "Concept Explainer")
        XCTAssertEqual(ChatMode.memory.displayName, "Memory Coach")
        XCTAssertEqual(ChatMode.planner.displayName, "Study Planner")
        XCTAssertEqual(ChatMode.exam.displayName, "Exam Simulator")
    }

    func testChatModeIcons() {
        // Given/When/Then: Verify icons exist and are valid SF Symbols
        XCTAssertFalse(ChatMode.general.icon.isEmpty)
        XCTAssertFalse(ChatMode.tutor.icon.isEmpty)
        XCTAssertFalse(ChatMode.quiz.icon.isEmpty)
        XCTAssertFalse(ChatMode.explainer.icon.isEmpty)
        XCTAssertFalse(ChatMode.memory.icon.isEmpty)
        XCTAssertFalse(ChatMode.planner.icon.isEmpty)
        XCTAssertFalse(ChatMode.exam.icon.isEmpty)
    }

    func testChatModeDescriptions() {
        // Given: All chat modes
        // Then: Descriptions should be meaningful (>20 chars)
        for mode in ChatMode.allCases {
            XCTAssertTrue(mode.description.count > 20, "\(mode) should have meaningful description")
        }
    }

    func testChatModeColors() {
        // Given/When/Then: Verify colors
        XCTAssertEqual(ChatMode.general.color, "purple")
        XCTAssertEqual(ChatMode.tutor.color, "blue")
        XCTAssertEqual(ChatMode.quiz.color, "green")
        XCTAssertEqual(ChatMode.explainer.color, "orange")
        XCTAssertEqual(ChatMode.memory.color, "pink")
        XCTAssertEqual(ChatMode.planner.color, "indigo")
        XCTAssertEqual(ChatMode.exam.color, "red")
    }

    func testChatModeIdentifiable() {
        // Given: A chat mode
        let mode = ChatMode.tutor

        // Then: ID should match raw value
        XCTAssertEqual(mode.id, mode.rawValue)
    }
}

// MARK: - PromptContext Tests

final class PromptContextTests: XCTestCase {

    func testPromptContextDefaultValues() {
        // Given/When: Creating default context
        let context = PromptContext()

        // Then: Should have empty/default values
        XCTAssertEqual(context.flashcardContext, "")
        XCTAssertEqual(context.studyTopics, "")
        XCTAssertEqual(context.dueCount, 0)
        XCTAssertEqual(context.studyStreak, 0)
        XCTAssertEqual(context.performanceLevel, "intermediate")
        XCTAssertEqual(context.flashcardSets, "")
        XCTAssertEqual(context.difficultyArea, "")
        XCTAssertEqual(context.topic, "")
        XCTAssertEqual(context.depthLevel, "medium")
        XCTAssertEqual(context.difficulty, "medium")
    }

    func testPromptContextToDictionary() {
        // Given: A populated context
        var context = PromptContext()
        context.studyTopics = "Biology, Chemistry"
        context.dueCount = 15
        context.studyStreak = 7
        context.performanceLevel = "advanced"

        // When: Converting to dictionary
        let dict = context.toDictionary()

        // Then: Should contain expected keys and values
        XCTAssertEqual(dict["study_topics"], "Biology, Chemistry")
        XCTAssertEqual(dict["due_count"], "15")
        XCTAssertEqual(dict["study_streak"], "7")
        XCTAssertEqual(dict["performance_level"], "advanced")
    }

    func testPromptContextFromFlashcardSets() {
        // Given: Flashcard sets
        let set1 = FlashcardSet(topicLabel: "Biology", tag: "biology")
        let card1 = Flashcard(type: .qa, question: "What is DNA?", answer: "Genetic material", linkedEntryID: UUID())
        set1.cards.append(card1)

        let set2 = FlashcardSet(topicLabel: "Chemistry", tag: "chemistry")

        // When: Creating context from sets
        let context = PromptContext.from(flashcardSets: [set1, set2], studyStreak: 5)

        // Then: Should populate context
        XCTAssertTrue(context.studyTopics.contains("Biology"))
        XCTAssertTrue(context.studyTopics.contains("Chemistry"))
        XCTAssertEqual(context.studyStreak, 5)
        XCTAssertFalse(context.flashcardContext.isEmpty)
    }

    func testPromptContextPerformanceLevelBeginner() {
        // Given: Sets with low success rate
        let set = FlashcardSet(topicLabel: "Test", tag: "test")
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        card.reviewCount = 10
        card.againCount = 8
        card.goodCount = 2
        set.cards.append(card)

        // When: Creating context
        let context = PromptContext.from(flashcardSets: [set])

        // Then: Should be beginner level
        XCTAssertEqual(context.performanceLevel, "beginner")
    }

    func testPromptContextPerformanceLevelAdvanced() {
        // Given: Sets with high success rate
        let set = FlashcardSet(topicLabel: "Test", tag: "test")
        let card = Flashcard(type: .qa, question: "Q", answer: "A", linkedEntryID: UUID())
        card.reviewCount = 10
        card.goodCount = 6
        card.easyCount = 4
        set.cards.append(card)

        // When: Creating context
        let context = PromptContext.from(flashcardSets: [set])

        // Then: Should be advanced level
        XCTAssertEqual(context.performanceLevel, "advanced")
    }

    func testPromptContextAvailableModes() {
        // Given: A context from flashcard sets
        let context = PromptContext.from(flashcardSets: [])

        // Then: Should list available modes
        XCTAssertTrue(context.availableModes.contains("General Assistant"))
        XCTAssertTrue(context.availableModes.contains("Study Tutor"))
    }
}

// MARK: - PromptManager Tests

@MainActor
final class PromptManagerTests: XCTestCase {

    func testPromptManagerSharedInstance() async throws {
        // Given/When: Accessing shared instance
        let manager1 = PromptManager.shared
        let manager2 = PromptManager.shared

        // Then: Should be the same instance
        XCTAssertTrue(manager1 === manager2)
    }

    func testGetPromptReturnsContent() async throws {
        // Given: The prompt manager
        let manager = PromptManager.shared

        // When: Getting a prompt
        let prompt = manager.getPrompt(mode: .general)

        // Then: Should return non-empty prompt (either from file or fallback)
        XCTAssertFalse(prompt.isEmpty)
    }

    func testGetPromptWithContext() async throws {
        // Given: A context with values
        var context = PromptContext()
        context.studyStreak = 10
        context.performanceLevel = "advanced"

        // When: Getting prompt with context
        let manager = PromptManager.shared
        let prompt = manager.getPrompt(mode: .tutor, context: context)

        // Then: Should return non-empty prompt
        XCTAssertFalse(prompt.isEmpty)
    }

    func testGetPromptForAllModes() async throws {
        // Given: The prompt manager
        let manager = PromptManager.shared

        // When/Then: All modes should return prompts
        for mode in ChatMode.allCases {
            let prompt = manager.getPrompt(mode: mode)
            XCTAssertFalse(prompt.isEmpty, "Mode \(mode) should have a prompt")
        }
    }

    func testBuildConversationContext() async throws {
        // Given: Messages
        let messages = [
            AIChatMessage(text: "What is gravity?", isUser: true),
            AIChatMessage(text: "Gravity is a force that attracts objects.", isUser: false),
            AIChatMessage(text: "Can you explain more?", isUser: true)
        ]

        // When: Building context
        let manager = PromptManager.shared
        let context = manager.buildConversationContext(messages: messages)

        // Then: Should include all messages
        XCTAssertTrue(context.contains("User: What is gravity?"))
        XCTAssertTrue(context.contains("Assistant: Gravity is a force"))
        XCTAssertTrue(context.contains("User: Can you explain more?"))
    }

    func testBuildConversationContextWithLimit() async throws {
        // Given: Many messages
        var messages: [AIChatMessage] = []
        for i in 0..<20 {
            messages.append(AIChatMessage(text: "Message \(i)", isUser: i % 2 == 0))
        }

        // When: Building with limit
        let manager = PromptManager.shared
        let context = manager.buildConversationContext(messages: messages, maxMessages: 5)

        // Then: Should only include last 5 messages
        XCTAssertTrue(context.contains("Message 15"))
        XCTAssertTrue(context.contains("Message 19"))
        XCTAssertFalse(context.contains("Message 0"))
    }

    func testFormatForLLM() async throws {
        // Given: Components
        let systemPrompt = "You are a helpful tutor."
        let history = "User: Hello\nAssistant: Hi!"
        let userMessage = "What is 2+2?"

        // When: Formatting
        let manager = PromptManager.shared
        let formatted = manager.formatForLLM(
            systemPrompt: systemPrompt,
            conversationHistory: history,
            userMessage: userMessage
        )

        // Then: Should include all parts
        XCTAssertTrue(formatted.contains(systemPrompt))
        XCTAssertTrue(formatted.contains("Conversation History"))
        XCTAssertTrue(formatted.contains(history))
        XCTAssertTrue(formatted.contains("Current User Message"))
        XCTAssertTrue(formatted.contains(userMessage))
        XCTAssertTrue(formatted.contains("Assistant:"))
    }

    func testFormatForLLMWithEmptyHistory() async throws {
        // Given: Empty history
        let systemPrompt = "You are a tutor."
        let userMessage = "Question?"

        // When: Formatting
        let manager = PromptManager.shared
        let formatted = manager.formatForLLM(
            systemPrompt: systemPrompt,
            conversationHistory: "",
            userMessage: userMessage
        )

        // Then: Should not include conversation history section
        XCTAssertFalse(formatted.contains("Conversation History"))
        XCTAssertTrue(formatted.contains(systemPrompt))
        XCTAssertTrue(formatted.contains(userMessage))
    }
}

// MARK: - AIChatMessage Tests

final class AIChatMessageTests: XCTestCase {

    func testAIChatMessageUserInitialization() {
        // Given/When: Creating a user message
        let message = AIChatMessage(text: "Hello", isUser: true)

        // Then: Should have correct properties
        XCTAssertNotNil(message.id)
        XCTAssertEqual(message.text, "Hello")
        XCTAssertTrue(message.isUser)
        XCTAssertFalse(message.isStreaming)
        XCTAssertTrue(message.scanAttachments.isEmpty)
    }

    func testAIChatMessageAssistantInitialization() {
        // Given/When: Creating an assistant message
        let message = AIChatMessage(text: "Hi there!", isUser: false)

        // Then: Should have correct properties
        XCTAssertFalse(message.isUser)
    }

    func testAIChatMessageStreamingFlag() {
        // Given/When: Creating a streaming message
        let message = AIChatMessage(text: "", isUser: false, isStreaming: true)

        // Then: Should have streaming flag
        XCTAssertTrue(message.isStreaming)
    }

    func testAIChatMessageIdentifiable() {
        // Given: Two messages
        let message1 = AIChatMessage(text: "Test", isUser: true)
        let message2 = AIChatMessage(text: "Test", isUser: true)

        // Then: Should have unique IDs
        XCTAssertNotEqual(message1.id, message2.id)
    }
}
