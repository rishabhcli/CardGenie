//
//  PromptManager.swift
//  CardGenie
//
//  Manages AI chat prompts with template variable substitution.
//  Loads prompts from markdown files in Prompts/ directory.
//

import Foundation
import SwiftData

// MARK: - Chat Mode

/// Available AI chat modes with different personalities and purposes
enum ChatMode: String, CaseIterable, Identifiable {
    case general = "general_assistant"
    case tutor = "study_tutor"
    case quiz = "quiz_master"
    case explainer = "concept_explainer"
    case memory = "memory_coach"
    case planner = "study_planner"
    case exam = "exam_simulator"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: return "General Assistant"
        case .tutor: return "Study Tutor"
        case .quiz: return "Quiz Master"
        case .explainer: return "Concept Explainer"
        case .memory: return "Memory Coach"
        case .planner: return "Study Planner"
        case .exam: return "Exam Simulator"
        }
    }

    var icon: String {
        switch self {
        case .general: return "sparkles"
        case .tutor: return "person.fill.questionmark"
        case .quiz: return "gamecontroller.fill"
        case .explainer: return "lightbulb.fill"
        case .memory: return "brain.head.profile"
        case .planner: return "calendar.badge.checkmark"
        case .exam: return "doc.text.fill"
        }
    }

    var description: String {
        switch self {
        case .general:
            return "Friendly study companion for general questions and support"
        case .tutor:
            return "Socratic method - learn through guided questioning"
        case .quiz:
            return "Interactive quizzes with instant feedback"
        case .explainer:
            return "Deep explanations from simple to expert level"
        case .memory:
            return "Mnemonics and memory techniques"
        case .planner:
            return "Strategic study planning and scheduling"
        case .exam:
            return "Realistic exam simulation and test prep"
        }
    }

    var color: String {
        switch self {
        case .general: return "purple"
        case .tutor: return "blue"
        case .quiz: return "green"
        case .explainer: return "orange"
        case .memory: return "pink"
        case .planner: return "indigo"
        case .exam: return "red"
        }
    }
}

// MARK: - Prompt Context

/// Context data for template variable substitution
struct PromptContext {
    var flashcardContext: String = ""
    var studyTopics: String = ""
    var dueCount: Int = 0
    var studyStreak: Int = 0
    var performanceLevel: String = "intermediate"
    var flashcardSets: String = ""
    var difficultyArea: String = ""
    var timeRemaining: String = ""
    var topic: String = ""
    var depthLevel: String = "medium"
    var background: String = ""
    var score: Int = 0
    var total: Int = 0
    var difficulty: String = "medium"
    var availableModes: String = ""

    /// Create context from SwiftData
    static func from(
        flashcardSets: [FlashcardSet],
        studyStreak: Int = 0
    ) -> PromptContext {
        var context = PromptContext()

        // Build flashcard context (recent cards)
        let allCards = flashcardSets.flatMap { $0.cards }
        let recentCards = allCards.prefix(10)
        context.flashcardContext = recentCards.map { card in
            "- \(card.question): \(card.answer)"
        }.joined(separator: "\n")

        // Study topics
        let topics = Set(flashcardSets.compactMap { $0.topicLabel })
        context.studyTopics = topics.joined(separator: ", ")

        // Due count
        context.dueCount = allCards.filter { $0.isDue }.count

        // Study streak
        context.studyStreak = studyStreak

        // Performance level
        let avgSuccessRate = flashcardSets.map { $0.successRate }.reduce(0, +) / max(Double(flashcardSets.count), 1)
        if avgSuccessRate >= 0.8 {
            context.performanceLevel = "advanced"
        } else if avgSuccessRate >= 0.5 {
            context.performanceLevel = "intermediate"
        } else {
            context.performanceLevel = "beginner"
        }

        // Flashcard sets summary
        context.flashcardSets = flashcardSets.map { set in
            "\(set.topicLabel) (\(set.cardCount) cards)"
        }.joined(separator: ", ")

        // Available modes
        context.availableModes = ChatMode.allCases.map { $0.displayName }.joined(separator: ", ")

        return context
    }

    /// Convert to dictionary for template substitution
    func toDictionary() -> [String: String] {
        return [
            "flashcard_context": flashcardContext,
            "study_topics": studyTopics,
            "due_count": "\(dueCount)",
            "study_streak": "\(studyStreak)",
            "performance_level": performanceLevel,
            "flashcard_sets": flashcardSets,
            "difficulty_area": difficultyArea,
            "time_remaining": timeRemaining,
            "topic": topic,
            "depth_level": depthLevel,
            "background": background,
            "score": "\(score)",
            "total": "\(total)",
            "difficulty": difficulty,
            "available_modes": availableModes,
            "performance_stats": "\(Int(performanceLevel == "advanced" ? 80 : performanceLevel == "intermediate" ? 60 : 40))%"
        ]
    }
}

// MARK: - Prompt Manager

/// Manages loading and rendering of AI prompts with template substitution
@MainActor
class PromptManager {
    static let shared = PromptManager()

    private var promptCache: [ChatMode: String] = [:]

    private init() {
        // Pre-load all prompts
        loadAllPrompts()
    }

    /// Load all prompts from bundle
    private func loadAllPrompts() {
        for mode in ChatMode.allCases {
            if let prompt = loadPromptFromBundle(mode: mode) {
                promptCache[mode] = prompt
            }
        }
    }

    /// Load prompt from app bundle
    private func loadPromptFromBundle(mode: ChatMode) -> String? {
        guard let url = Bundle.main.url(forResource: mode.rawValue, withExtension: "md", subdirectory: "Intelligence/Prompts") else {
            print("⚠️ Prompt file not found: \(mode.rawValue).md")
            return nil
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            return content
        } catch {
            print("⚠️ Failed to load prompt \(mode.rawValue): \(error)")
            return nil
        }
    }

    /// Get rendered prompt with context substitution
    func getPrompt(
        mode: ChatMode,
        context: PromptContext? = nil
    ) -> String {
        let finalContext = context ?? PromptContext()

        // Get base prompt
        guard let basePrompt = promptCache[mode] else {
            return getFallbackPrompt(mode: mode)
        }

        // Substitute template variables
        return substituteVariables(in: basePrompt, context: finalContext)
    }

    /// Substitute {{variable}} placeholders with actual values
    private func substituteVariables(
        in template: String,
        context: PromptContext
    ) -> String {
        var result = template
        let contextDict = context.toDictionary()

        // Replace all {{variable}} patterns
        for (key, value) in contextDict {
            let pattern = "{{\(key)}}"
            result = result.replacingOccurrences(of: pattern, with: value)
        }

        // Clean up any remaining unreplaced variables (optional)
        result = result.replacingOccurrences(
            of: #"\{\{[^}]+\}\}"#,
            with: "[context not available]",
            options: .regularExpression
        )

        return result
    }

    /// Fallback prompts if file loading fails
    private func getFallbackPrompt(mode: ChatMode) -> String {
        switch mode {
        case .general:
            return """
            You are a helpful study assistant. Help students understand concepts, answer questions, and provide study support. Be encouraging and concise.
            """
        case .tutor:
            return """
            You are a Socratic tutor. Ask guiding questions instead of giving direct answers. Help students discover insights themselves through thoughtful questioning.
            """
        case .quiz:
            return """
            You are a quiz master. Create engaging questions to test understanding. Provide instant feedback and adapt difficulty based on performance.
            """
        case .explainer:
            return """
            You are a concept explainer. Explain topics clearly at any level from simple to expert. Use analogies and examples to make complex ideas accessible.
            """
        case .memory:
            return """
            You are a memory coach. Teach evidence-based memory techniques like mnemonics, method of loci, and chunking. Help students create memorable associations.
            """
        case .planner:
            return """
            You are a study planner. Create personalized, realistic study schedules using evidence-based techniques like spaced repetition and interleaving.
            """
        case .exam:
            return """
            You are an exam simulator. Create realistic practice tests with time pressure. Teach test-taking strategies and provide detailed performance analytics.
            """
        }
    }

    /// Build conversation context from recent messages
    func buildConversationContext(
        messages: [AIChatMessage],
        maxMessages: Int = 10
    ) -> String {
        let recentMessages = messages.suffix(maxMessages)

        return recentMessages.map { message in
            let role = message.isUser ? "User" : "Assistant"
            return "\(role): \(message.text)"
        }.joined(separator: "\n\n")
    }

    /// Format final prompt for LLM
    func formatForLLM(
        systemPrompt: String,
        conversationHistory: String,
        userMessage: String
    ) -> String {
        var prompt = systemPrompt

        if !conversationHistory.isEmpty {
            prompt += "\n\n## Conversation History\n\n\(conversationHistory)"
        }

        prompt += "\n\n## Current User Message\n\nUser: \(userMessage)"
        prompt += "\n\nAssistant:"

        return prompt
    }
}

// MARK: - Chat Message Model (moved from VoiceViews for better organization)

struct AIChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isUser: Bool
    var isStreaming: Bool
    var scanAttachments: [ScanAttachment]

    init(text: String, isUser: Bool, isStreaming: Bool = false, scanAttachments: [ScanAttachment] = []) {
        self.id = UUID()
        self.text = text
        self.isUser = isUser
        self.isStreaming = isStreaming
        self.scanAttachments = scanAttachments
    }
}
