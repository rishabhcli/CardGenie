//
//  ChatEngine.swift
//  CardGenie
//
//  AI Chat engine with Foundation Models streaming support.
//  Manages chat sessions, message history, and conversational AI responses.
//

import Foundation
import SwiftUI
import Combine
import OSLog
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class ChatEngine: ObservableObject {
    // MARK: - Published State

    /// All messages in current session
    @Published var messages: [ChatMessageModel] = []

    /// Streaming response text (updates in real-time)
    @Published var streamingResponse: String = ""

    /// Whether AI is processing a response
    @Published var isProcessing: Bool = false

    /// Current chat session
    @Published var currentSession: ChatSession?

    /// Error message to display
    @Published var errorMessage: String?

    // MARK: - Private State

    private var context: ChatContext = ChatContext()
    private let fmClient = FMClient()
    private let log = Logger(subsystem: "com.cardgenie.app", category: "ChatEngine")

    /// Streaming task for cancellation
    private var streamingTask: Task<Void, Never>?

    /// Context budget (iOS 26 limit: ~12K tokens input, keep under 10K)
    private let maxContextTokens = 10_000

    // MARK: - Initialization

    init() {
        log.info("💬 ChatEngine initialized")
    }

    // MARK: - Session Management

    /// Start a new chat session
    func startSession() async throws {
        log.info("Starting new chat session")

        // Check AI availability
        let capability = fmClient.capability()
        guard capability == .available else {
            throw ChatEngineError.aiNotAvailable(capability)
        }

        // Create new session
        let session = ChatSession(title: "New Chat")
        session.isActive = true
        currentSession = session

        // Reset state
        messages.removeAll()
        context = ChatContext()
        streamingResponse = ""
        errorMessage = nil

        log.info("✅ Chat session started: \(session.id)")
    }

    /// End current chat session
    func endSession() {
        guard let session = currentSession else { return }

        log.info("Ending chat session: \(session.id)")

        session.isActive = false
        session.updatedAt = Date()

        // Save to SwiftData (handled by modelContext in view)
        currentSession = nil
        messages.removeAll()
        context = ChatContext()
        streamingResponse = ""

        log.info("✅ Chat session ended")
    }

    // MARK: - Message Sending

    /// Send a user message and get streaming AI response
    func sendMessage(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let session = currentSession else {
            log.error("❌ No active session")
            errorMessage = "No active chat session. Please start a new chat."
            return
        }

        log.info("📤 User message: \(text.prefix(50))...")

        // Add user message
        let userMessage = ChatMessageModel(role: .user, content: text)
        messages.append(userMessage)
        session.messages.append(userMessage)
        session.messageCount += 1
        session.updatedAt = Date()

        // Auto-generate session title from first message
        if session.messageCount == 1 {
            session.generateTitle(from: text)
        }

        // Clear previous streaming response
        streamingResponse = ""
        isProcessing = true

        // Build prompt with context
        let prompt = buildContextualPrompt(for: text)

        // Stream AI response
        await streamAIResponse(to: prompt)
    }

    // MARK: - AI Response Streaming

    private func buildContextualPrompt(for userMessage: String) -> String {
        // Check context budget and prune if needed
        pruneContextIfNeeded()

        let prompt = """
        Previous conversation:
        \(context.formatMessageHistory(messages, limit: 8))

        User's latest message: \(userMessage)

        Respond conversationally and naturally. Keep responses concise (2-4 sentences) unless explaining complex topics.
        """

        return prompt
    }

    private func streamAIResponse(to prompt: String) async {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            await handleFallbackResponse()
            return
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            log.error("❌ AI model not available")
            errorMessage = "AI is not available right now"
            isProcessing = false
            return
        }

        do {
            // Create session with system prompt
            let session = LanguageModelSession {
                context.systemPrompt()
            }

            log.info("🧠 Starting streaming chat response...")

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.7 // Conversational warmth
            )

            // Stream the response
            let stream = session.streamResponse(to: prompt, options: options)

            // Create assistant message for streaming
            let assistantMessage = ChatMessageModel(role: .assistant, content: "")
            assistantMessage.isStreaming = true
            messages.append(assistantMessage)
            currentSession?.messages.append(assistantMessage)

            var fullResponse = ""

            for try await partial in stream {
                // Update UI immediately
                streamingResponse = partial.content
                fullResponse = partial.content
            }

            // Finalize message
            assistantMessage.content = fullResponse
            assistantMessage.isStreaming = false

            log.info("✅ Streaming complete: \(fullResponse.count) chars")

            isProcessing = false
            currentSession?.updatedAt = Date()

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            log.error("❌ Guardrail violation")
            await handleGuardrailError()
        } catch LanguageModelSession.GenerationError.refusal {
            log.error("❌ Model refused request")
            await handleRefusalError()
        } catch {
            log.error("❌ Streaming failed: \(error.localizedDescription)")
            errorMessage = "Something went wrong. Try asking again."
            isProcessing = false
        }

        #else
        await handleFallbackResponse()
        #endif
    }

    // MARK: - Error Handling

    private func handleFallbackResponse() async {
        let fallback = FMClient().availabilityPresentation(for: .chat).message
        streamingResponse = fallback

        let message = ChatMessageModel(role: .assistant, content: fallback)
        messages.append(message)
        currentSession?.messages.append(message)

        isProcessing = false
    }

    private func handleGuardrailError() async {
        let error = FMClient().safetyPresentation(for: SafetyError.guardrailViolation(
            SafetyEvent(type: .guardrailViolation, userMessage: "I can't help with that. Let's focus on your studies!")
        ), feature: .chat).message
        streamingResponse = error

        let message = ChatMessageModel(role: .assistant, content: error)
        messages.append(message)
        currentSession?.messages.append(message)

        isProcessing = false
    }

    private func handleRefusalError() async {
        let error = "The on-device model declined that request. Try asking something else about your study materials."
        streamingResponse = error

        let message = ChatMessageModel(role: .assistant, content: error)
        messages.append(message)
        currentSession?.messages.append(message)

        isProcessing = false
    }

    // MARK: - Context Management

    private func pruneContextIfNeeded() {
        let currentTokens = context.estimateTokens() + estimateMessageHistoryTokens()

        guard currentTokens > self.maxContextTokens else {
            log.info("Context budget OK: \(currentTokens)/\(self.maxContextTokens) tokens")
            return
        }

        log.warning("⚠️ Context budget exceeded: \(currentTokens)/\(self.maxContextTokens) tokens. Pruning...")

        // Strategy: Remove oldest messages first, but keep system context
        let messagesToKeep = 10
        if messages.count > messagesToKeep {
            let removed = messages.count - messagesToKeep
            messages.removeFirst(removed)
            log.info("Removed \(removed) old messages")
        }

        // Remove oldest scans if still over budget
        if context.activeScans.count > 3 {
            let removed = context.activeScans.count - 3
            context.activeScans.removeFirst(removed)
            log.info("Removed \(removed) old scans")
        }
    }

    private func estimateMessageHistoryTokens() -> Int {
        // Rough estimate: 1 token ≈ 4 characters
        let totalChars = messages.reduce(0) { $0 + $1.content.count }
        return totalChars / 4
    }

    // MARK: - Conversation Management

    /// Clear current conversation (keep session)
    func clearConversation() {
        messages.removeAll()
        currentSession?.messages.removeAll()
        streamingResponse = ""
        log.info("🗑️ Conversation cleared")
    }

    /// Interrupt streaming response
    func interrupt() {
        log.info("🛑 Interrupting response...")

        streamingTask?.cancel()
        streamingTask = nil

        isProcessing = false
        streamingResponse = ""

        log.info("✅ Response interrupted")
    }
}

// MARK: - Error Types

enum ChatEngineError: LocalizedError {
    case aiNotAvailable(FMCapabilityState)
    case noActiveSession

    var errorDescription: String? {
        switch self {
        case .aiNotAvailable:
            return "Chat is unavailable because the required on-device AI model is not ready on this device."
        case .noActiveSession:
            return "No active chat session. Please start a new chat."
        }
    }
}
