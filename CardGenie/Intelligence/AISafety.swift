//
//  AISafety.swift
//  CardGenie
//
//  Safety infrastructure for Apple Intelligence integration.
//  Implements content filtering, guardrail handling, and privacy protection.
//

import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Safety Error Types

enum SafetyError: LocalizedError {
    case guardrailViolation(SafetyEvent)
    case contextLimitExceeded
    case unsafeContent(reason: String)
    case privacyViolation

    var errorDescription: String? {
        switch self {
        case .guardrailViolation(let event):
            return event.userMessage
        case .contextLimitExceeded:
            return "Content is too long to process. Please try with shorter text."
        case .unsafeContent(let reason):
            return "Content filter triggered: \(reason)"
        case .privacyViolation:
            return "This request cannot be processed due to privacy restrictions."
        }
    }
}

// MARK: - Safety Event

struct SafetyEvent {
    let type: SafetyEventType
    let originalPrompt: String? // Stored for logging, never sent to model
    let userMessage: String
    let safeAlternative: String?
    let timestamp: Date

    init(
        type: SafetyEventType,
        originalPrompt: String? = nil,
        userMessage: String,
        safeAlternative: String? = nil
    ) {
        self.type = type
        self.originalPrompt = originalPrompt
        self.userMessage = userMessage
        self.safeAlternative = safeAlternative
        self.timestamp = Date()
    }
}

enum SafetyEventType {
    case guardrailViolation
    case refusal
    case denyListMatch
    case privacyFilter
}

// MARK: - Content Safety Filter

/// Filters unsafe content before sending to the model
@MainActor
final class ContentSafetyFilter {
    private let log = Logger(subsystem: "com.cardgenie.app", category: "Safety")

    // MARK: - Deny List

    /// Topics inappropriate for a school/education app
    private let denyList: Set<String> = [
        // Violence & harmful content
        "violence", "weapon", "bomb", "explosive", "terrorism",
        "suicide", "self-harm", "self harm",

        // Adult content
        "sexual", "explicit", "pornography", "adult content",

        // Illegal activities
        "illegal drug", "narcotic", "trafficking",
        "hack", "exploit", "malware", "virus",
        "cheat", "plagiarize", "academic dishonesty",

        // Harmful instructions
        "how to hurt", "how to harm", "dangerous experiment",

        // Privacy violations
        "social security", "credit card", "password", "private key",
        "ssn", "driver license"
    ]

    /// Check if content contains unsafe topics
    func isSafe(_ text: String) -> Result<Void, SafetyError> {
        let lowercased = text.lowercased()

        // Check deny list
        for deniedTerm in denyList {
            if lowercased.contains(deniedTerm) {
                log.warning("Deny list match: \(deniedTerm)")

                return .failure(.unsafeContent(
                    reason: "Content contains topics not appropriate for an educational app."
                ))
            }
        }

        // Check for potential PII (simplified)
        if containsPotentialPII(text) {
            log.warning("Potential PII detected")

            return .failure(.privacyViolation)
        }

        return .success(())
    }

    /// Sanitize content by removing potential sensitive information
    func sanitize(_ text: String) -> String {
        var sanitized = text

        // Remove email addresses
        let emailRegex = try? NSRegularExpression(
            pattern: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        )
        if let regex = emailRegex {
            let range = NSRange(text.startIndex..., in: text)
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                range: range,
                withTemplate: "[EMAIL]"
            )
        }

        // Remove phone numbers (US format)
        let phoneRegex = try? NSRegularExpression(
            pattern: #"\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#
        )
        if let regex = phoneRegex {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                range: range,
                withTemplate: "[PHONE]"
            )
        }

        return sanitized
    }

    private func containsPotentialPII(_ text: String) -> Bool {
        // Check for SSN pattern (simplified)
        let ssnPattern = #"\d{3}-?\d{2}-?\d{4}"#
        if text.range(of: ssnPattern, options: .regularExpression) != nil {
            return true
        }

        // Check for credit card patterns (simplified)
        let ccPattern = #"\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}"#
        if text.range(of: ccPattern, options: .regularExpression) != nil {
            return true
        }

        return false
    }
}

// MARK: - Guardrail Handler

/// Handles guardrail violations and model refusals with user-friendly messaging
@MainActor
final class GuardrailHandler {
    private let log = Logger(subsystem: "com.cardgenie.app", category: "Guardrails")

    /// Process a guardrail violation and provide safe alternatives
    func handleGuardrailViolation(
        prompt: String,
        context: String = "study assistance"
    ) -> SafetyEvent {
        log.warning("Guardrail violation for context: \(context)")

        // Never log the actual prompt content per privacy policy

        let event = SafetyEvent(
            type: .guardrailViolation,
            originalPrompt: nil, // Don't store actual content
            userMessage: """
            I can't process that request due to content safety guidelines. \
            Let's focus on educational topics that are appropriate for studying.
            """,
            safeAlternative: generateSafeAlternative(for: context)
        )

        return event
    }

    /// Process a model refusal
    func handleRefusal(
        prompt: String,
        context: String = "study assistance"
    ) -> SafetyEvent {
        log.warning("Model refusal for context: \(context)")

        let event = SafetyEvent(
            type: .refusal,
            originalPrompt: nil,
            userMessage: """
            I'm not able to help with that particular request. \
            Try rephrasing your question or asking about a different topic.
            """,
            safeAlternative: generateSafeAlternative(for: context)
        )

        return event
    }

    private func generateSafeAlternative(for context: String) -> String {
        switch context {
        case "flashcard_generation":
            return "Try creating flashcards from your lecture notes or textbook content."

        case "study_plan":
            return "I can help you create a study schedule based on your upcoming deadlines."

        case "quiz":
            return "Let me generate practice questions from your study materials."

        case "clarification":
            return "Ask me to explain a specific concept from your notes."

        default:
            return "I can help you summarize notes, create flashcards, or explain study concepts."
        }
    }
}

// MARK: - Privacy Logger

/// Ensures no sensitive student data is logged
@MainActor
final class PrivacyLogger {
    private let log = Logger(subsystem: "com.cardgenie.app", category: "Privacy")

    /// Log AI operations without exposing user content
    func logOperation(
        _ operation: String,
        contentLength: Int,
        success: Bool,
        errorType: String? = nil
    ) {
        if success {
            log.info("""
            AI operation completed: \(operation) | \
            content_length: \(contentLength) | \
            success: true
            """)
        } else {
            log.error("""
            AI operation failed: \(operation) | \
            content_length: \(contentLength) | \
            error_type: \(errorType ?? "unknown")
            """)
        }

        // NEVER log:
        // - Raw student notes
        // - Prompts containing user content
        // - Generated flashcard content
        // - Study material text
        // - User questions or answers
    }

    /// Log safety events
    func logSafetyEvent(_ event: SafetyEvent) {
        log.warning("""
        Safety event: \(event.type) | \
        timestamp: \(event.timestamp) | \
        has_alternative: \(event.safeAlternative != nil)
        """)

        // Note: originalPrompt is intentionally not logged
    }
}

// MARK: - Context Budget Manager

/// Manages context window limits per TN3193
@MainActor
final class ContextBudgetManager {
    private let log = Logger(subsystem: "com.cardgenie.app", category: "ContextBudget")

    // Approximate token limits (conservative estimates)
    private let maxInputTokens = 8000  // Leave headroom for system instructions
    private let maxOutputTokens = 2000

    /// Estimate token count (rough approximation: 1 token ≈ 4 chars)
    func estimateTokens(_ text: String) -> Int {
        return text.count / 4
    }

    /// Check if content fits within context window
    func canFitInContext(_ text: String, instructions: String = "") -> Bool {
        let totalTokens = estimateTokens(text) + estimateTokens(instructions)
        return totalTokens < maxInputTokens
    }

    /// Chunk text to fit within context limits
    func chunkText(_ text: String, maxChunkTokens: Int = 6000) -> [String] {
        let maxChars = maxChunkTokens * 4

        guard text.count > maxChars else {
            return [text]
        }

        log.info("Chunking text: \(text.count) chars into chunks of ~\(maxChars)")

        var chunks: [String] = []
        var currentIndex = text.startIndex

        while currentIndex < text.endIndex {
            let endIndex = text.index(
                currentIndex,
                offsetBy: maxChars,
                limitedBy: text.endIndex
            ) ?? text.endIndex

            // Try to break at sentence boundary
            var chunkEndIndex = endIndex
            if endIndex != text.endIndex {
                let searchRange = text.index(endIndex, offsetBy: -200, limitedBy: currentIndex) ?? currentIndex
                if let breakPoint = text[searchRange..<endIndex].lastIndex(where: { ".!?\n".contains($0) }) {
                    chunkEndIndex = text.index(after: breakPoint)
                }
            }

            let chunk = String(text[currentIndex..<chunkEndIndex])
            chunks.append(chunk)

            currentIndex = chunkEndIndex
        }

        log.info("Created \(chunks.count) chunks")
        return chunks
    }

    /// Process long text by chunking and combining results
    func processInChunks(
        _ text: String,
        processor: (String) async throws -> String
    ) async throws -> String {
        let chunks = chunkText(text)

        if chunks.count == 1 {
            return try await processor(text)
        }

        log.info("Processing \(chunks.count) chunks sequentially")

        var results: [String] = []

        for (index, chunk) in chunks.enumerated() {
            log.info("Processing chunk \(index + 1)/\(chunks.count)")

            do {
                let result = try await processor(chunk)
                results.append(result)
            } catch {
                log.error("Chunk \(index + 1) failed: \(error.localizedDescription)")
                throw error
            }
        }

        return results.joined(separator: "\n\n")
    }
}

// MARK: - Locale Support

/// Handles locale-aware prompts per Apple guidelines
@MainActor
final class LocaleManager {
    private let log = Logger(subsystem: "com.cardgenie.app", category: "Locale")

    private let currentLocale = Locale.current

    /// Get locale-specific instructions for the model
    func getLocaleInstructions() -> String {
        let languageCode = currentLocale.language.languageCode?.identifier ?? "en"
        let regionCode = currentLocale.region?.identifier ?? "US"

        log.info("Locale: \(languageCode)_\(regionCode)")

        if languageCode == "en" && regionCode == "US" {
            return "You MUST respond in U.S. English."
        } else {
            // Use Apple's recommended phrasing for non-US locales
            return """
            The person's locale is \(currentLocale.identifier). \
            Respond in the appropriate language for this locale.
            """
        }
    }

    /// Check if locale is supported by Apple Intelligence
    func isLocaleSupported() -> Bool {
        // As of iOS 26, Apple Intelligence supports:
        // - English (US, UK, Australia, Canada, India, Ireland, New Zealand, Singapore, South Africa)
        // - Chinese (Simplified, Traditional)
        // - French, German, Italian, Japanese, Korean, Portuguese, Spanish
        // This list may expand - always check latest docs

        let supportedLanguages: Set<String> = [
            "en", "zh", "fr", "de", "it", "ja", "ko", "pt", "es"
        ]

        guard let langCode = currentLocale.language.languageCode?.identifier else {
            return false
        }

        return supportedLanguages.contains(langCode)
    }

    /// Present fallback message for unsupported locales
    func getUnsupportedLocaleMessage() -> String {
        return """
        Apple Intelligence is not yet available in your language. \
        CardGenie's AI features require Apple Intelligence to be enabled \
        in a supported language. You can still use manual flashcard creation \
        and study features.
        """
    }
}
