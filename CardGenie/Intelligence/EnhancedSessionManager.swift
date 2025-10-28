//
//  EnhancedSessionManager.swift
//  CardGenie
//
//  Enhanced session management for Apple Intelligence.
//  Handles context limits, concurrent request prevention, and error recovery.
//

import Foundation
import OSLog
import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Session Type

enum SessionType {
    case singleTurn    // Create new session per request
    case multiTurn     // Reuse session for conversation
}

// MARK: - Enhanced Session Manager

@available(iOS 26.0, *)
@MainActor
final class EnhancedSessionManager: ObservableObject {
    private let log = Logger(subsystem: "com.cardgenie.app", category: "SessionManager")

    // MARK: - Properties

    @Published private(set) var isResponding = false
    @Published private(set) var currentSession: LanguageModelSession?

    private let contextBudget = ContextBudgetManager()
    private let safetyFilter = ContentSafetyFilter()
    private let guardrailHandler = GuardrailHandler()
    private let privacyLogger = PrivacyLogger()
    private let localeManager = LocaleManager()

    private var sessionType: SessionType = .singleTurn

    // MARK: - Initialization

    init(sessionType: SessionType = .singleTurn) {
        self.sessionType = sessionType
    }

    // MARK: - Session Management

    /// Start a new session with instructions
    func startSession(instructions: String) {
        guard !isResponding else {
            log.warning("Cannot start new session while responding")
            return
        }

        let localeInstructions = localeManager.getLocaleInstructions()
        let fullInstructions = """
        \(instructions)

        \(localeInstructions)

        IMPORTANT CONSTRAINTS:
        - NEVER log or expose student notes or personal information
        - Keep outputs concise and age-appropriate
        - Refuse unsafe or inappropriate requests politely
        - Stay within academic/educational topics
        """

        currentSession = LanguageModelSession(instructions: fullInstructions)
        log.info("Started new session with type: \(String(describing: self.sessionType))")
    }

    /// End current session
    func endSession() {
        currentSession = nil
        isResponding = false
        log.info("Ended session")
    }

    // MARK: - Single-Turn Request

    /// Perform a single-turn request (creates new session each time)
    func singleTurnRequest<T>(
        prompt: String,
        instructions: String,
        generating type: T.Type,
        options: GenerationOptions = GenerationOptions()
    ) async throws -> T where T: Generable {
        // Ensure no concurrent requests
        guard !isResponding else {
            log.warning("Request blocked: already responding")
            throw SafetyError.guardrailViolation(
                SafetyEvent(
                    type: .privacyFilter,
                    userMessage: "Please wait for the current request to complete."
                )
            )
        }

        isResponding = true
        defer { isResponding = false }

        // Safety check
        switch safetyFilter.isSafe(prompt) {
        case .success:
            break
        case .failure(let error):
            log.error("Safety filter triggered")
            throw error
        }

        // Context limit check
        guard contextBudget.canFitInContext(prompt, instructions: instructions) else {
            log.warning("Content exceeds context window")
            throw SafetyError.contextLimitExceeded
        }

        // Create new session for single-turn
        let localeInstructions = localeManager.getLocaleInstructions()
        let fullInstructions = "\(instructions)\n\n\(localeInstructions)"

        let session = LanguageModelSession(instructions: fullInstructions)

        do {
            let response = try await session.respond(
                to: prompt,
                generating: type,
                options: options
            )

            privacyLogger.logOperation(
                "single_turn",
                contentLength: prompt.count,
                success: true
            )

            return response.content

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            let event = guardrailHandler.handleGuardrailViolation(prompt: prompt)
            privacyLogger.logSafetyEvent(event)
            throw SafetyError.guardrailViolation(event)

        } catch LanguageModelSession.GenerationError.refusal {
            let event = guardrailHandler.handleRefusal(prompt: prompt)
            privacyLogger.logSafetyEvent(event)
            throw SafetyError.guardrailViolation(event)

        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            log.error("Context window exceeded despite pre-check")
            throw SafetyError.contextLimitExceeded

        } catch {
            log.error("Request failed: \(error.localizedDescription)")
            privacyLogger.logOperation(
                "single_turn",
                contentLength: prompt.count,
                success: false,
                errorType: "\(error)"
            )
            throw error
        }
    }

    /// Perform a single-turn request returning String
    func singleTurnRequest(
        prompt: String,
        instructions: String,
        options: GenerationOptions = GenerationOptions()
    ) async throws -> String {
        // Ensure no concurrent requests
        guard !isResponding else {
            log.warning("Request blocked: already responding")
            throw SafetyError.guardrailViolation(
                SafetyEvent(
                    type: .privacyFilter,
                    userMessage: "Please wait for the current request to complete."
                )
            )
        }

        isResponding = true
        defer { isResponding = false }

        // Safety check
        switch safetyFilter.isSafe(prompt) {
        case .success:
            break
        case .failure(let error):
            log.error("Safety filter triggered")
            throw error
        }

        // Context limit check
        guard contextBudget.canFitInContext(prompt, instructions: instructions) else {
            log.warning("Content exceeds context window")
            throw SafetyError.contextLimitExceeded
        }

        // Create new session for single-turn
        let localeInstructions = localeManager.getLocaleInstructions()
        let fullInstructions = "\(instructions)\n\n\(localeInstructions)"

        let session = LanguageModelSession(instructions: fullInstructions)

        do {
            let response = try await session.respond(
                to: prompt,
                options: options
            )

            privacyLogger.logOperation(
                "single_turn",
                contentLength: prompt.count,
                success: true
            )

            return response.content

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            let event = guardrailHandler.handleGuardrailViolation(prompt: prompt)
            privacyLogger.logSafetyEvent(event)
            throw SafetyError.guardrailViolation(event)

        } catch LanguageModelSession.GenerationError.refusal {
            let event = guardrailHandler.handleRefusal(prompt: prompt)
            privacyLogger.logSafetyEvent(event)
            throw SafetyError.guardrailViolation(event)

        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            log.error("Context window exceeded despite pre-check")
            throw SafetyError.contextLimitExceeded

        } catch {
            log.error("Request failed: \(error.localizedDescription)")
            privacyLogger.logOperation(
                "single_turn",
                contentLength: prompt.count,
                success: false,
                errorType: "\(error)"
            )
            throw error
        }
    }

    // MARK: - Multi-Turn Request

    /// Perform a multi-turn request (reuses existing session)
    func multiTurnRequest(
        prompt: String,
        options: GenerationOptions = GenerationOptions()
    ) async throws -> String {
        guard let session = currentSession else {
            log.error("No active session for multi-turn request")
            throw SafetyError.guardrailViolation(
                SafetyEvent(
                    type: .privacyFilter,
                    userMessage: "Please start a conversation session first."
                )
            )
        }

        // Ensure no concurrent requests
        guard !isResponding else {
            log.warning("Request blocked: already responding")
            throw SafetyError.guardrailViolation(
                SafetyEvent(
                    type: .privacyFilter,
                    userMessage: "Please wait for the current response to complete."
                )
            )
        }

        isResponding = true
        defer { isResponding = false }

        // Safety check
        switch safetyFilter.isSafe(prompt) {
        case .success:
            break
        case .failure(let error):
            log.error("Safety filter triggered")
            throw error
        }

        do {
            let response = try await session.respond(
                to: prompt,
                options: options
            )

            privacyLogger.logOperation(
                "multi_turn",
                contentLength: prompt.count,
                success: true
            )

            return response.content

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            let event = guardrailHandler.handleGuardrailViolation(prompt: prompt)
            privacyLogger.logSafetyEvent(event)
            throw SafetyError.guardrailViolation(event)

        } catch LanguageModelSession.GenerationError.refusal {
            let event = guardrailHandler.handleRefusal(prompt: prompt)
            privacyLogger.logSafetyEvent(event)
            throw SafetyError.guardrailViolation(event)

        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            log.error("Context window exceeded - starting new session")

            // Context exceeded in multi-turn: start new session and retry
            endSession()
            startSession(instructions: "Continue the conversation from context.")

            guard let newSession = currentSession else {
                throw SafetyError.contextLimitExceeded
            }

            // Retry with new session
            let response = try await newSession.respond(
                to: prompt,
                options: options
            )

            return response.content

        } catch {
            log.error("Request failed: \(error.localizedDescription)")
            privacyLogger.logOperation(
                "multi_turn",
                contentLength: prompt.count,
                success: false,
                errorType: "\(error)"
            )
            throw error
        }
    }

    // MARK: - Streaming Support

    /// Stream a response with snapshots
    func streamResponse(
        prompt: String,
        instructions: String,
        options: GenerationOptions = GenerationOptions()
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                guard !isResponding else {
                    continuation.finish(throwing: SafetyError.guardrailViolation(
                        SafetyEvent(
                            type: .privacyFilter,
                            userMessage: "Please wait for the current request to complete."
                        )
                    ))
                    return
                }

                isResponding = true
                defer { isResponding = false }

                // Safety check
                switch safetyFilter.isSafe(prompt) {
                case .success:
                    break
                case .failure(let error):
                    continuation.finish(throwing: error)
                    return
                }

                // Create session
                let localeInstructions = localeManager.getLocaleInstructions()
                let fullInstructions = "\(instructions)\n\n\(localeInstructions)"
                let session = LanguageModelSession(instructions: fullInstructions)

                do {
                    let stream = session.streamResponse(options: options) {
                        prompt
                    }

                    for try await snapshot in stream {
                        continuation.yield(snapshot.content)
                    }

                    continuation.finish()

                } catch {
                    log.error("Streaming failed: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Chunked Processing

    /// Process long content by chunking
    func processLongContent(
        text: String,
        instructions: String,
        processor: @escaping (String) async throws -> String
    ) async throws -> String {
        guard !isResponding else {
            throw SafetyError.guardrailViolation(
                SafetyEvent(
                    type: .privacyFilter,
                    userMessage: "Please wait for the current request to complete."
                )
            )
        }

        if contextBudget.canFitInContext(text, instructions: instructions) {
            return try await processor(text)
        }

        log.info("Content too long, processing in chunks")

        return try await contextBudget.processInChunks(text) { chunk in
            try await processor(chunk)
        }
    }
}
