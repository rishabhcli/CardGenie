//
//  AICore.swift
//  CardGenie
//
//  Core AI functionality including Foundation Models client, AI engines, safety, and tools.
//

import Foundation
import SwiftUI
import OSLog
import Combine
import SwiftData
import NaturalLanguage
import EventKit
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - FMClient

// MARK: - Capability States

/// Represents the availability state of Apple Intelligence on the device
enum FMCapabilityState {
    case available                  // Model is ready and can be used
    case notEnabled                 // Apple Intelligence is disabled in Settings
    case notSupported               // Device doesn't support Apple Intelligence
    case modelNotReady              // Model is downloading/initializing
    case unknown                    // Unable to determine state
}

// MARK: - Foundation Models Client

/// Client for interacting with Apple's on-device Foundation Models.
/// All AI operations run locally on the Neural Engine, preserving privacy.
@MainActor
final class FMClient: ObservableObject {
    private let log = Logger(subsystem: "com.smartjournal.app", category: "FMClient")

    // MARK: - Capability Checking

    /// Check if Apple Intelligence is available on this device
    /// - Returns: Current capability state
    nonisolated func capability() -> FMCapabilityState {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                log.info("Apple Intelligence is available")
                return .available
            case .unavailable(.appleIntelligenceNotEnabled):
                log.warning("Apple Intelligence is not enabled in Settings")
                return .notEnabled
            case .unavailable(.deviceNotEligible):
                log.warning("Device does not support Apple Intelligence")
                return .notSupported
            case .unavailable(.modelNotReady):
                log.info("Model is downloading or initializing")
                return .modelNotReady
            case .unavailable(let other):
                log.error("Apple Intelligence unavailable: \(String(describing: other))")
                return .unknown
            }
        } else {
            log.warning("iOS 26+ required for Foundation Models")
            return .notSupported
        }
        #else
        log.info("FoundationModels framework not available; using fallback mode")
        return .modelNotReady
        #endif
    }

    // MARK: - AI Operations

    /// Summarize a journal entry into 2-3 concise sentences
    /// - Parameter text: The journal entry text to summarize
    /// - Returns: A brief summary of the content
    /// - Throws: Error if the model is unavailable or processing fails
    func summarize(_ text: String) async throws -> String {
        // Validate input
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 20 else {
            log.info("Text too short to summarize")
            return ""
        }

        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            log.error("iOS 26+ required")
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            log.error("Model not available")
            throw FMError.modelUnavailable
        }

        log.info("Starting summarization...")

        do {
            let session = LanguageModelSession {
                """
                You are a helpful journaling assistant.
                Summarize journal entries concisely in 2-3 sentences.
                Write in first person and maintain the original tone.
                Do not add facts not present in the entry.
                """
            }

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.3 // Lower for more focused summaries
            )

            let response = try await session.respond(
                to: "Summarize this journal entry:\n\n\(trimmed)",
                generating: ContentSummary.self,
                options: options
            )

            let summary = response.content.summary
            log.info("Summary generated: \(summary.count) chars")
            return summary

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            log.error("Guardrail violation during summarization")
            throw FMError.processingFailed
        } catch LanguageModelSession.GenerationError.refusal {
            log.error("Model refused summarization request")
            throw FMError.processingFailed
        } catch {
            log.error("Summarization failed: \(error.localizedDescription)")
            throw FMError.processingFailed
        }
        #else
        log.info("Using fallback summarization implementation")
        return fallbackSummary(for: trimmed)
        #endif
    }

    /// Extract up to 3 relevant tags/keywords from the entry
    /// - Parameter text: The journal entry text to analyze
    /// - Returns: Array of extracted tags (max 3)
    /// - Throws: Error if the model is unavailable or processing fails
    func tags(for text: String) async throws -> [String] {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            log.error("Model not available")
            throw FMError.modelUnavailable
        }

        log.info("Extracting tags...")

        do {
            let session = LanguageModelSession {
                """
                Extract up to three short topic tags from the text.
                Each tag should be 1-2 words maximum.
                Examples: work, planning, travel, health, learning
                """
            }

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.2 // Very focused output
            )

            let response = try await session.respond(
                to: "Extract relevant topic tags from this text:\n\n\(text)",
                generating: JournalTags.self,
                options: options
            )

            let tags = response.content.tags
            log.info("Extracted tags: \(tags)")
            return tags

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            log.error("Guardrail violation during tag extraction")
            throw FMError.processingFailed
        } catch LanguageModelSession.GenerationError.refusal {
            log.error("Model refused tag extraction request")
            throw FMError.processingFailed
        } catch {
            log.error("Tag extraction failed: \(error.localizedDescription)")
            throw FMError.processingFailed
        }
        #else
        log.info("Using fallback tag extraction implementation")
        return fallbackTags(for: text)
        #endif
    }

    /// Generate a kind, encouraging reflection based on the entry
    /// - Parameter text: The journal entry text
    /// - Returns: One sentence of encouragement or reflection
    /// - Throws: Error if the model is unavailable or processing fails
    func reflection(for text: String) async throws -> String {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            log.error("Model not available")
            throw FMError.modelUnavailable
        }

        log.info("Generating reflection...")

        do {
            let session = LanguageModelSession {
                """
                You are a supportive journaling companion.
                Read the user's entry and respond with ONE kind, uplifting sentence.
                Be empathetic but concise.
                If they express difficulty, acknowledge it gently.
                If they express joy, celebrate with them.
                ALWAYS respond respectfully and supportively.
                """
            }

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.7 // More creative/warm responses
            )

            let response = try await session.respond(
                to: "Provide a supportive reflection for this journal entry:\n\n\(text)",
                generating: ContentReflection.self,
                options: options
            )

            let reflection = response.content.reflection
            log.info("Reflection generated")
            return reflection

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            log.error("Guardrail violation during reflection generation")
            throw FMError.processingFailed
        } catch LanguageModelSession.GenerationError.refusal {
            log.error("Model refused reflection request")
            throw FMError.processingFailed
        } catch {
            log.error("Reflection generation failed: \(error.localizedDescription)")
            throw FMError.processingFailed
        }
        #else
        log.info("Using fallback reflection implementation")
        return fallbackReflection(for: text)
        #endif
    }

    // MARK: - General Completion

    /// General-purpose text completion for RAG, chat, and other uses
    /// - Parameters:
    ///   - prompt: The prompt/instruction for the model
    /// - Returns: Generated text response
    /// - Throws: Error if the model is unavailable or processing fails
    func complete(_ prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            log.error("Model not available")
            throw FMError.modelUnavailable
        }

        log.info("Generating completion...")

        do {
            let session = LanguageModelSession {
                """
                You are a helpful AI assistant for studying and learning.
                Provide accurate, concise, and well-structured responses.
                When answering questions about lecture notes or study materials, cite sources if provided.
                """
            }

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.5 // Balanced between creativity and accuracy
            )

            let response = try await session.respond(to: prompt, options: options)
            let completion = response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            log.info("Completion generated")
            return completion

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            log.error("Guardrail violation during completion")
            throw FMError.processingFailed
        } catch {
            log.error("Completion failed: \(error.localizedDescription)")
            throw FMError.processingFailed
        }
        #else
        log.info("Using fallback completion implementation")
        // Fallback: return a generic response
        return "I'm unable to process this request without Apple Intelligence enabled."
        #endif
    }

    // MARK: - Study Coach

    /// Generate encouraging message based on study performance
    /// - Parameters:
    ///   - correctCount: Number of correct answers
    ///   - totalCount: Total number of questions
    ///   - streak: Current study streak in days
    /// - Returns: Encouraging message for the student
    /// - Throws: Error if the model is unavailable or processing fails
    func generateEncouragement(
        correctCount: Int,
        totalCount: Int,
        streak: Int
    ) async throws -> String {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            // Provide fallback encouragement based on accuracy
            let accuracy = totalCount > 0 ? Double(correctCount) / Double(totalCount) : 0.0
            return fallbackEncouragement(accuracy: accuracy)
        }

        log.info("Generating study encouragement...")

        let accuracy = totalCount > 0 ? Double(correctCount) / Double(totalCount) : 0.0

        do {
            let session = LanguageModelSession {
                """
                You are CardGenie, a supportive and enthusiastic AI study coach.
                Encourage students with warmth and positivity.
                Keep messages brief (1-2 sentences maximum).
                Use encouraging emojis sparingly (0-1 per message).
                Celebrate progress and effort, not just perfection.
                Be specific about their performance when possible.
                """
            }

            let prompt = """
                Generate an encouraging message for a student who just completed a study session.

                Performance:
                - Correct: \(correctCount) out of \(totalCount)
                - Accuracy: \(Int(accuracy * 100))%
                - Study streak: \(streak) days

                The message should be personal, warm, and motivating. One or two sentences maximum.
                """

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.8 // More creative/warm responses
            )

            let response = try await session.respond(to: prompt, options: options)
            let message = response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            log.info("Encouragement generated")
            return message

        } catch {
            log.error("Encouragement generation failed: \(error.localizedDescription)")
            return fallbackEncouragement(accuracy: accuracy)
        }
        #else
        log.info("Using fallback encouragement implementation")
        let accuracy = totalCount > 0 ? Double(correctCount) / Double(totalCount) : 0.0
        return fallbackEncouragement(accuracy: accuracy)
        #endif
    }

    /// Generate insight about study patterns
    /// - Parameters:
    ///   - totalReviews: Total number of card reviews
    ///   - averageAccuracy: Average accuracy across all sessions
    ///   - longestStreak: Longest study streak achieved
    /// - Returns: Actionable study insight
    /// - Throws: Error if the model is unavailable or processing fails
    func generateStudyInsight(
        totalReviews: Int,
        averageAccuracy: Double,
        longestStreak: Int
    ) async throws -> String {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            return "You've reviewed \(totalReviews) cards - that's dedication! 🎯"
        }

        log.info("Generating study insight...")

        do {
            let session = LanguageModelSession {
                """
                You are CardGenie, an AI study coach.
                Provide brief, actionable insights about study patterns.
                Be encouraging and specific.
                One sentence maximum.
                Focus on positive observations or helpful tips.
                """
            }

            let prompt = """
                Generate a study insight for a student with these statistics:
                - Total reviews: \(totalReviews)
                - Average accuracy: \(Int(averageAccuracy * 100))%
                - Longest streak: \(longestStreak) days

                What's one positive observation or actionable tip? One sentence only.
                """

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.7
            )

            let response = try await session.respond(to: prompt, options: options)
            let insight = response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            log.info("Study insight generated")
            return insight

        } catch {
            log.error("Insight generation failed: \(error.localizedDescription)")
            return "You've reviewed \(totalReviews) cards - that's dedication! 🎯"
        }
        #else
        log.info("Using fallback study insight implementation")
        if totalReviews == 0 {
            return "Start a quick review session to build momentum! 🚀"
        }
        return "You've reviewed \(totalReviews) cards with \(Int(averageAccuracy * 100))% accuracy—keep the streak alive!"
        #endif
    }

    /// Fallback encouragement when AI is unavailable
    private func fallbackEncouragement(accuracy: Double) -> String {
        if accuracy >= 0.9 {
            return "Outstanding work! You're mastering this material! ⭐️"
        } else if accuracy >= 0.7 {
            return "Great progress! Keep up the excellent work! 💪"
        } else if accuracy >= 0.5 {
            return "You're learning! Every review makes you stronger! 🌟"
        } else {
            return "Don't give up! Learning takes time and you're doing great! 💫"
        }
    }

    // MARK: - Fallback Helpers

    private func fallbackSummary(for text: String) -> String {
        let sentences = text
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let summary = sentences.prefix(2).joined(separator: ". ")
        if summary.isEmpty {
            let truncated = text.prefix(160)
            return truncated.isEmpty ? "" : "\(truncated)…"
        }
        return sentences.count > 2 ? "\(summary)." : summary
    }

    private func fallbackTags(for text: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        let words = text
            .lowercased()
            .components(separatedBy: separators)
            .filter { $0.count > 3 }

        let stopWords: Set<String> = [
            "this", "that", "with", "have", "from", "about", "there", "their",
            "would", "could", "should", "really", "today", "yesterday", "tomorrow"
        ]

        var frequency: [String: Int] = [:]
        for word in words where !stopWords.contains(word) {
            frequency[word, default: 0] += 1
        }

        let sorted = frequency.sorted { $0.value > $1.value }.map { $0.key.capitalized }
        return Array(sorted.prefix(3))
    }

    private func fallbackReflection(for text: String) -> String {
        if text.lowercased().contains("stress") || text.lowercased().contains("tired") {
            return "It sounds like you handled a lot today—remember to take a breather when you can."
        }
        if text.lowercased().contains("happy") || text.lowercased().contains("grateful") {
            return "Love how you’re appreciating the good moments—keep leaning into that energy!"
        }
        return "Thanks for reflecting—acknowledging your day is a powerful step forward."
    }

    // MARK: - Streaming (Advanced)

    /// Stream a response token-by-token for real-time UI updates
    /// - Parameters:
    ///   - text: Input text
    ///   - onPartialContent: Callback for each partial content update
    /// - Throws: Error if streaming fails
    func streamSummary(_ text: String, onPartialContent: @escaping (String) -> Void) async throws {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            log.error("Model not available")
            throw FMError.modelUnavailable
        }

        log.info("Starting streaming summarization...")

        do {
            let session = LanguageModelSession {
                """
                You are a helpful journaling assistant.
                Summarize journal entries concisely in 2-3 sentences.
                Write in first person and maintain the original tone.
                """
            }

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.3
            )

            let stream = session.streamResponse(
                to: "Summarize this journal entry using three sentences:\n\n\(text)",
                options: options
            )

            for try await partialResponse in stream {
                onPartialContent(partialResponse.content)
            }

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            log.error("Guardrail violation during streaming")
            throw FMError.processingFailed
        } catch {
            log.error("Streaming failed: \(error.localizedDescription)")
            throw FMError.processingFailed
        }
        #else
        log.info("Using fallback streaming implementation")
        onPartialContent(fallbackSummary(for: text))
        #endif
    }

    /// Stream a conversational chat response for real-time UI updates
    /// - Parameter prompt: The chat message or conversation context
    /// - Returns: AsyncStream of partial responses as they're generated
    /// - Throws: Error if streaming fails
    @available(iOS 26.0, *)
    func streamChat(_ prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                #if canImport(FoundationModels)
                let model = SystemLanguageModel.default
                guard case .available = model.availability else {
                    continuation.finish(throwing: FMError.modelUnavailable)
                    return
                }

                log.info("Starting chat streaming...")

                do {
                    let session = LanguageModelSession {
                        """
                        You are a helpful, friendly AI assistant.
                        Provide clear, concise, and accurate responses.
                        Be conversational but professional.
                        Keep responses focused and relevant.
                        """
                    }

                    let options = GenerationOptions(
                        sampling: .greedy,
                        temperature: 0.7
                    )

                    let stream = session.streamResponse(to: prompt, options: options)

                    for try await partialResponse in stream {
                        continuation.yield(partialResponse.content)
                    }

                    continuation.finish()

                } catch LanguageModelSession.GenerationError.guardrailViolation {
                    log.error("Guardrail violation during chat streaming")
                    continuation.finish(throwing: FMError.processingFailed)
                } catch LanguageModelSession.GenerationError.refusal {
                    log.error("Model refused to respond")
                    continuation.finish(throwing: FMError.processingFailed)
                } catch {
                    log.error("Chat streaming failed: \(error.localizedDescription)")
                    continuation.finish(throwing: FMError.processingFailed)
                }
                #else
                log.info("Using fallback chat implementation")
                continuation.yield("I'm currently unavailable. Apple Intelligence is not enabled on this device.")
                continuation.finish()
                #endif
            }
        }
    }
}

// MARK: - Error Types

enum FMError: LocalizedError {
    case unsupportedOS
    case modelUnavailable
    case processingFailed
    case textTooShort

    var errorDescription: String? {
        switch self {
        case .unsupportedOS:
            return "iOS 26 or later is required for Apple Intelligence features."
        case .modelUnavailable:
            return "Apple Intelligence is not available. Please enable it in Settings."
        case .processingFailed:
            return "Failed to process your request. Please try again."
        case .textTooShort:
            return "Please write more text before using AI features."
        }
    }
}

// MARK: - AIEngine

// MARK: - LLM Engine Protocol

/// Protocol for large language model inference
protocol LLMEngine {
    /// Generate text completion from prompt
    func complete(_ prompt: String) async throws -> String

    /// Stream text completion (for chat/tutoring)
    func streamComplete(_ prompt: String) -> AsyncThrowingStream<String, Error>

    /// Check if engine is available
    var isAvailable: Bool { get }
}

// MARK: - Embedding Engine Protocol

/// Protocol for text embedding generation
protocol EmbeddingEngine {
    /// Generate embeddings for multiple texts
    func embed(_ texts: [String]) async throws -> [[Float]]

    /// Get embedding dimension
    var dimension: Int { get }

    /// Check if engine is available
    var isAvailable: Bool { get }
}

// MARK: - LLM Errors

enum LLMError: LocalizedError {
    case notAvailable
    case promptTooLong
    case generationFailed(String)
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "AI model not available on this device"
        case .promptTooLong:
            return "Input text is too long"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        case .modelNotLoaded:
            return "AI model not loaded"
        }
    }
}

// MARK: - Apple On-Device Provider

/// Apple Intelligence / Foundation Models provider (iOS 18.1+)
final class AppleOnDeviceLLM: LLMEngine {
    private let fmClient = FMClient()

    var isAvailable: Bool {
        fmClient.capability() == .available
    }

    func complete(_ prompt: String) async throws -> String {
        guard isAvailable else {
            throw LLMError.notAvailable
        }

        // Use general-purpose completion method for RAG and chat
        return try await fmClient.complete(prompt)
    }

    func streamComplete(_ prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await complete(prompt)
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

/// Apple's on-device embedding provider
final class AppleEmbedding: EmbeddingEngine {
    var dimension: Int { 384 } // Standard embedding size

    var isAvailable: Bool {
        // Check if NLEmbedding is available
        return true
    }

    func embed(_ texts: [String]) async throws -> [[Float]] {
        guard isAvailable else {
            throw LLMError.notAvailable
        }

        // Use NLEmbedding for on-device text embeddings
        var embeddings: [[Float]] = []

        for text in texts {
            let embedding = try await generateEmbedding(for: text)
            embeddings.append(embedding)
        }

        return embeddings
    }

    private func generateEmbedding(for text: String) async throws -> [Float] {
        // Use NaturalLanguage framework's NLEmbedding for semantic vectors
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
            // Fallback to word embedding if sentence embedding not available
            guard let wordEmbedding = NLEmbedding.wordEmbedding(for: .english) else {
                throw LLMError.modelNotLoaded
            }
            return await generateWordBasedEmbedding(for: text, using: wordEmbedding)
        }

        // Get sentence embedding vector
        if let vector = embedding.vector(for: text) {
            // NLEmbedding returns vectors of varying sizes, normalize to our dimension
            let floatVector = Array(vector).map { Float($0) }
            return normalizeVector(floatVector, targetDimension: dimension)
        }

        // If sentence embedding fails, fall back to word-based approach
        guard let wordEmbedding = NLEmbedding.wordEmbedding(for: .english) else {
            throw LLMError.modelNotLoaded
        }
        return await generateWordBasedEmbedding(for: text, using: wordEmbedding)
    }

    private func generateWordBasedEmbedding(for text: String, using embedding: NLEmbedding) async -> [Float] {
        // Tokenize text and average word embeddings
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var wordVectors: [[Double]] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let word = String(text[tokenRange])
            if let vector = embedding.vector(for: word) {
                wordVectors.append(Array(vector))
            }
            return true
        }

        // Average all word vectors
        guard !wordVectors.isEmpty else {
            // Return zero vector if no words found
            return Array(repeating: 0.0, count: dimension)
        }

        let vectorSize = wordVectors[0].count
        var averagedVector = Array(repeating: 0.0, count: vectorSize)

        for vector in wordVectors {
            for (i, value) in vector.enumerated() {
                averagedVector[i] += value
            }
        }

        for i in 0..<vectorSize {
            averagedVector[i] /= Double(wordVectors.count)
        }

        return normalizeVector(averagedVector.map { Float($0) }, targetDimension: dimension)
    }

    private func normalizeVector(_ vector: [Float], targetDimension: Int) -> [Float] {
        let currentSize = vector.count

        if currentSize == targetDimension {
            return vector
        } else if currentSize > targetDimension {
            // Truncate to target dimension
            return Array(vector.prefix(targetDimension))
        } else {
            // Pad with zeros to reach target dimension
            return vector + Array(repeating: 0.0, count: targetDimension - currentSize)
        }
    }
}

// MARK: - AI Engine Factory

/// Factory for creating appropriate AI engines
struct AIEngineFactory {
    nonisolated static func createLLMEngine() -> LLMEngine {
        // Return the Apple on-device implementation
        // It will check availability at runtime
        return AppleOnDeviceLLM()
    }

    nonisolated static func createEmbeddingEngine() -> EmbeddingEngine {
        return AppleEmbedding()
    }
}

// MARK: - AISafety


#if canImport(FoundationModels)
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

enum SafetyEventType: CustomStringConvertible {
    case guardrailViolation
    case refusal
    case denyListMatch
    case privacyFilter

    var description: String {
        switch self {
        case .guardrailViolation:
            return "guardrail_violation"
        case .refusal:
            return "refusal"
        case .denyListMatch:
            return "deny_list_match"
        case .privacyFilter:
            return "privacy_filter"
        }
    }
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

// MARK: - AITools



// MARK: - Tool Protocols

/// Protocol for tools that can be called by the language model
protocol AITool {
    var name: String { get }
    var description: String { get }
    func execute(parameters: [String: Any]) async throws -> ToolResult
}

struct ToolResult {
    let success: Bool
    let data: String
    let error: String?
}

// MARK: - FetchNotes Tool

/// Fetches study content from SwiftData based on query
@available(iOS 26.0, *)
final class FetchNotesTool: AITool {
    let name = "fetch_notes"
    let description = "Search and retrieve study notes by topic, tags, or keywords"

    private let modelContext: ModelContext
    private let log = Logger(subsystem: "com.cardgenie.app", category: "AITools")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func execute(parameters: [String: Any]) async throws -> ToolResult {
        guard let query = parameters["query"] as? String else {
            return ToolResult(
                success: false,
                data: "",
                error: "Missing required parameter: query"
            )
        }

        log.info("Fetching notes with query: \(query)")

        do {
            var descriptor = FetchDescriptor<StudyContent>(
                sortBy: [SortDescriptor<StudyContent>(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 200

            let candidates = try modelContext.fetch(descriptor)

            let results = candidates.filter { content in
                matches(query, in: content.rawContent) ||
                matches(query, in: content.summary) ||
                matches(query, in: content.topic) ||
                content.tags.contains { containsCaseInsensitive($0, query) }
            }

            // Limit to top 5 most recent matches to stay within context window
            let limited = Array(results.prefix(5))

            if limited.isEmpty {
                return ToolResult(
                    success: true,
                    data: "No notes found matching '\(query)'",
                    error: nil
                )
            }

            let summaries = limited.map { content in
                let summaryText = content.summary ?? String(content.displayText.prefix(200))
                return """
                ID: \(content.id)
                Topic: \(content.topic ?? "Untitled")
                Tags: \(content.tags.joined(separator: ", "))
                Summary: \(summaryText)
                """
            }.joined(separator: "\n\n")

            log.info("Found \(limited.count) matching notes")

            return ToolResult(
                success: true,
                data: "Found \(limited.count) notes:\n\n\(summaries)",
                error: nil
            )

        } catch {
            log.error("Failed to fetch notes: \(error.localizedDescription)")
            return ToolResult(
                success: false,
                data: "",
                error: "Failed to search notes: \(error.localizedDescription)"
            )
    }
}

    private func matches(_ query: String, in text: String?) -> Bool {
        guard let text else { return false }
        return text.range(
            of: query,
            options: String.CompareOptions(arrayLiteral: .caseInsensitive, .diacriticInsensitive)
        ) != nil
    }

    private func containsCaseInsensitive(_ text: String, _ query: String) -> Bool {
        text.range(
            of: query,
            options: String.CompareOptions(arrayLiteral: .caseInsensitive, .diacriticInsensitive)
        ) != nil
    }
}

// MARK: - SaveFlashcards Tool

/// Saves generated flashcards to SwiftData
@available(iOS 26.0, *)
final class SaveFlashcardsTool: AITool {
    let name = "save_flashcards"
    let description = "Save flashcards to the database for later study"

    private let modelContext: ModelContext
    private let log = Logger(subsystem: "com.cardgenie.app", category: "AITools")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func execute(parameters: [String: Any]) async throws -> ToolResult {
        guard let flashcardsData = parameters["flashcards"] as? [[String: Any]] else {
            return ToolResult(
                success: false,
                data: "",
                error: "Missing required parameter: flashcards"
            )
        }

        log.info("Saving \(flashcardsData.count) flashcards")

        do {
            var savedCount = 0

            for cardData in flashcardsData {
                guard let question = cardData["question"] as? String,
                      let answer = cardData["answer"] as? String,
                      let typeStr = cardData["type"] as? String else {
                    continue
                }

                let type: FlashcardType
                switch typeStr.lowercased() {
                case "cloze": type = .cloze
                case "definition": type = .definition
                default: type = .qa
                }

                let tags = (cardData["tags"] as? [String]) ?? []
                let linkedID = (cardData["linkedEntryID"] as? String)
                    .flatMap { UUID(uuidString: $0) } ?? UUID()

                let flashcard = Flashcard(
                    type: type,
                    question: question,
                    answer: answer,
                    linkedEntryID: linkedID,
                    tags: tags
                )

                modelContext.insert(flashcard)
                savedCount += 1
            }

            try modelContext.save()

            log.info("Successfully saved \(savedCount) flashcards")

            return ToolResult(
                success: true,
                data: "Saved \(savedCount) flashcards successfully",
                error: nil
            )

        } catch {
            log.error("Failed to save flashcards: \(error.localizedDescription)")
            return ToolResult(
                success: false,
                data: "",
                error: "Failed to save flashcards: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - UpcomingDeadlines Tool

/// Fetches upcoming calendar events for study planning
@available(iOS 26.0, *)
final class UpcomingDeadlinesTool: AITool {
    let name = "upcoming_deadlines"
    let description = "Get upcoming calendar events and deadlines for study planning"

    private let eventStore = EKEventStore()
    private let log = Logger(subsystem: "com.cardgenie.app", category: "AITools")

    func execute(parameters: [String: Any]) async throws -> ToolResult {
        log.info("Fetching upcoming deadlines")

        // Request calendar access
        let granted = try await eventStore.requestFullAccessToEvents()

        guard granted else {
            return ToolResult(
                success: false,
                data: "",
                error: "Calendar access not granted. Please enable in Settings."
            )
        }

        // Fetch events for next 14 days
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 14, to: startDate) ?? startDate

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)

        if events.isEmpty {
            return ToolResult(
                success: true,
                data: "No upcoming events found in the next 14 days",
                error: nil
            )
        }

        // Format events for LLM
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let eventSummaries = events.prefix(10).map { event in
            let dateStr = formatter.string(from: event.startDate)
            return "• \(event.title ?? "Untitled"): \(dateStr)"
        }.joined(separator: "\n")

        log.info("Found \(events.count) upcoming events")

        return ToolResult(
            success: true,
            data: "Upcoming events (next 14 days):\n\n\(eventSummaries)",
            error: nil
        )
    }
}

// MARK: - Glossary Tool

/// Looks up terms in a local definitions database
@available(iOS 26.0, *)
final class GlossaryTool: AITool {
    let name = "glossary"
    let description = "Look up academic terms and definitions from study materials"

    private let modelContext: ModelContext
    private let log = Logger(subsystem: "com.cardgenie.app", category: "AITools")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func execute(parameters: [String: Any]) async throws -> ToolResult {
        guard let term = parameters["term"] as? String else {
            return ToolResult(
                success: false,
                data: "",
                error: "Missing required parameter: term"
            )
        }

        log.info("Looking up glossary term: \(term)")

        do {
            // Search for definition-type flashcards matching the term
            var descriptor = FetchDescriptor<Flashcard>(
                sortBy: [SortDescriptor<Flashcard>(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 50

            let flashcards = try modelContext.fetch(descriptor)
            if let match = flashcards.first(where: {
                $0.type == .definition && $0.question.localizedStandardContains(term)
            }) {
                return ToolResult(
                    success: true,
                    data: "\(match.question)\n\n\(match.answer)",
                    error: nil
                )
            }

            // Fallback: search in study content
            var contentDescriptor = FetchDescriptor<StudyContent>(
                sortBy: [SortDescriptor<StudyContent>(\.createdAt, order: .reverse)]
            )
            contentDescriptor.fetchLimit = 200

            let contentResults = try modelContext.fetch(contentDescriptor)

            if let match = contentResults.first(where: { matchesTerm(term, in: $0.displayText) }) {
                let excerpt = extractRelevantExcerpt(from: match.displayText, term: term)
                return ToolResult(
                    success: true,
                    data: "Found in notes: \(excerpt)",
                    error: nil
                )
            }

            return ToolResult(
                success: true,
                data: "Term '\(term)' not found in glossary or notes",
                error: nil
            )

        } catch {
            log.error("Failed to look up term: \(error.localizedDescription)")
            return ToolResult(
                success: false,
                data: "",
                error: "Failed to look up term: \(error.localizedDescription)"
            )
        }
    }

    private func extractRelevantExcerpt(from text: String, term: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))

        for sentence in sentences {
            if sentence.localizedStandardContains(term) {
                return sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Fallback: return first 200 chars
        return String(text.prefix(200))
    }

    private func matches(_ query: String, in text: String?) -> Bool {
        guard let text else { return false }
        return containsCaseInsensitive(text, query)
    }

    private func matchesTerm(_ term: String, in text: String) -> Bool {
        containsCaseInsensitive(text, term)
    }

    private func containsCaseInsensitive(_ text: String, _ query: String) -> Bool {
        text.range(
            of: query,
            options: String.CompareOptions(arrayLiteral: .caseInsensitive, .diacriticInsensitive)
        ) != nil
    }
}

// MARK: - Tool Registry

/// Manages available tools for the language model
@available(iOS 26.0, *)
@MainActor
final class ToolRegistry {
    private var tools: [String: AITool] = [:]
    private let log = Logger(subsystem: "com.cardgenie.app", category: "ToolRegistry")

    init(modelContext: ModelContext) {
        // Register all available tools
        register(FetchNotesTool(modelContext: modelContext))
        register(SaveFlashcardsTool(modelContext: modelContext))
        register(UpcomingDeadlinesTool())
        register(GlossaryTool(modelContext: modelContext))
    }

    private func register(_ tool: AITool) {
        tools[tool.name] = tool
        log.info("Registered tool: \(tool.name)")
    }

    func getTool(named name: String) -> AITool? {
        return tools[name]
    }

    func allTools() -> [AITool] {
        return Array(tools.values)
    }

    /// Execute a tool call from the language model
    func execute(toolName: String, parameters: [String: Any]) async throws -> ToolResult {
        guard let tool = getTool(named: toolName) else {
            log.error("Tool not found: \(toolName)")
            return ToolResult(
                success: false,
                data: "",
                error: "Tool '\(toolName)' not found"
            )
        }

        log.info("Executing tool: \(toolName)")
        return try await tool.execute(parameters: parameters)
    }
}

// MARK: - FlashcardFM

// MARK: - Flashcard Generation Result

struct FlashcardGenerationResult {
    let flashcards: [Flashcard]
    let topicTag: String
    let entities: [String]
}

#if !canImport(FoundationModels)
extension FMClient {
    /// Generate flashcards using lightweight heuristics when FoundationModels is unavailable.
    func generateFlashcards(
        from content: StudyContent,
        formats: Set<FlashcardType>,
        maxPerFormat: Int = 3
    ) async throws -> FlashcardGenerationResult {
        flashcardLog.info("Using fallback flashcard generation for content: \(content.id)")

        let baseText = content.displayText
        let tags = fallbackTags(for: baseText)
        let topic = tags.first ?? content.topic ?? "General"

        var generated: [Flashcard] = []
        let sentences = baseText
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if formats.contains(.qa), let sentence = sentences.first {
            generated.append(
                Flashcard(
                    type: .qa,
                    question: "What is the key idea from this note?",
                    answer: sentence,
                    linkedEntryID: content.id,
                    tags: tags
                )
            )
        }

        if formats.contains(.cloze), let sentence = sentences.dropFirst().first {
            let words = sentence.split(separator: " ")
            if let keyword = words.first(where: { $0.count > 4 }) {
                let answer = String(keyword)
                let clozeSentence = sentence.replacingOccurrences(of: answer, with: "_____", options: .caseInsensitive, range: nil)
                generated.append(
                    Flashcard(
                        type: .cloze,
                        question: clozeSentence,
                        answer: answer,
                        linkedEntryID: content.id,
                        tags: tags
                    )
                )
            }
        }

        if formats.contains(.definition) {
            let term = topic
            let definition = sentences.first ?? "A concept related to \(topic)."
            generated.append(
                Flashcard(
                    type: .definition,
                    question: "What is \(term)?",
                    answer: definition,
                    linkedEntryID: content.id,
                    tags: tags
                )
            )
        }

        let unique = deduplicateFlashcards(generated)
        return FlashcardGenerationResult(flashcards: unique, topicTag: topic, entities: tags)
    }

    /// Provide a simple clarification message about a flashcard.
    func clarifyFlashcard(_ flashcard: Flashcard, userQuestion: String) async throws -> String {
        flashcardLog.info("Using fallback clarification for flashcard \(flashcard.id)")
        return """
        The answer, "\(flashcard.answer)", comes directly from the material linked to this card. Focus on how it connects to the question "\(flashcard.question)" and review the surrounding context in your notes for reinforcement.
        """
    }
}
#endif

// MARK: - FMClient Extension for Flashcards

extension FMClient {
    fileprivate var flashcardLog: Logger {
        Logger(subsystem: "com.cardgenie.app", category: "FlashcardGeneration")
    }

    // MARK: - Main Generation Method

    /// Generate flashcards from study content using on-device AI
    /// - Parameters:
    ///   - content: The study content to generate flashcards from
    ///   - formats: Flashcard formats to generate (cloze, Q&A, definition)
    ///   - maxPerFormat: Maximum flashcards per format (default: 3)
    /// - Returns: Array of generated flashcards with topic information
    func generateFlashcards(
        from content: StudyContent,
        formats: Set<FlashcardType>,
        maxPerFormat: Int = 3
    ) async throws -> FlashcardGenerationResult {
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        flashcardLog.info("Starting flashcard generation for content: \(content.id)")

        // Step 1: Extract entities and topics using content tagging
        let (entities, topicTag) = try await extractEntitiesAndTopics(from: content.displayText)

        flashcardLog.info("Extracted \(entities.count) entities and topic: \(topicTag)")

        // Step 2: Generate flashcards for each requested format
        var allFlashcards: [Flashcard] = []

        for format in formats {
            let cards = try await generateFlashcardsForFormat(
                format,
                text: content.displayText,
                entities: entities,
                linkedEntryID: content.id,
                topicTag: topicTag,
                maxCards: maxPerFormat
            )
            allFlashcards.append(contentsOf: cards)
        }

        // Step 3: Deduplicate and filter
        let uniqueFlashcards = deduplicateFlashcards(allFlashcards)

        flashcardLog.info("Generated \(uniqueFlashcards.count) unique flashcards")

        return FlashcardGenerationResult(
            flashcards: uniqueFlashcards,
            topicTag: topicTag,
            entities: entities
        )
    }

    // MARK: - Entity Extraction

    /// Extract key entities and assign a topic tag using content tagging model
    private func extractEntitiesAndTopics(from text: String) async throws -> ([String], String) {
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            flashcardLog.error("Model not available for entity extraction")
            throw FMError.modelUnavailable
        }

        flashcardLog.info("Extracting entities and topics...")

        do {
            let session = LanguageModelSession {
                """
                Extract important entities (names, places, dates, key terms) from the text.
                Also identify the main topic category (e.g., Travel, Work, Health, History, Learning).
                Focus on terms that would be valuable for creating flashcards.
                """
            }

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.2
            )

            let response = try await session.respond(
                to: "Extract entities and topic from this text:\n\n\(text)",
                generating: EntityExtractionResult.self,
                options: options
            )

            let entities = response.content.entities
            let topic = response.content.topicTag

            flashcardLog.info("Extracted \(entities.count) entities with topic: \(topic)")
            return (entities, topic)

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            flashcardLog.error("Guardrail violation during entity extraction")
            throw FMError.processingFailed
        } catch LanguageModelSession.GenerationError.refusal {
            flashcardLog.error("Model refused entity extraction request")
            throw FMError.processingFailed
        } catch {
            flashcardLog.error("Entity extraction failed: \(error.localizedDescription)")
            throw FMError.processingFailed
        }
    }

    // MARK: - Format-Specific Generation

    private func generateFlashcardsForFormat(
        _ format: FlashcardType,
        text: String,
        entities: [String],
        linkedEntryID: UUID,
        topicTag: String,
        maxCards: Int
    ) async throws -> [Flashcard] {
        switch format {
        case .cloze:
            return try await generateClozeCards(
                text: text,
                entities: entities,
                linkedEntryID: linkedEntryID,
                topicTag: topicTag,
                maxCards: maxCards
            )
        case .qa:
            return try await generateQACards(
                text: text,
                linkedEntryID: linkedEntryID,
                topicTag: topicTag,
                maxCards: maxCards
            )
        case .definition:
            return try await generateDefinitionCards(
                text: text,
                entities: entities,
                linkedEntryID: linkedEntryID,
                topicTag: topicTag,
                maxCards: maxCards
            )
        }
    }

    // MARK: - Cloze Deletion Cards

    private func generateClozeCards(
        text: String,
        entities: [String],
        linkedEntryID: UUID,
        topicTag: String,
        maxCards: Int
    ) async throws -> [Flashcard] {
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        flashcardLog.info("Generating cloze deletion cards...")

        do {
            let session = LanguageModelSession {
                """
                Create cloze deletion flashcards from the text.
                A cloze card has a sentence with an important term replaced by ______.
                Choose sentences that contain key concepts, names, dates, or important details.
                Replace the most important term in each sentence with ______.
                """
            }

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.3
            )

            let entityList = entities.joined(separator: ", ")
            let prompt = """
                Create \(maxCards) cloze deletion flashcards from this text.
                Focus on these key entities: \(entityList)

                Text:
                \(text)
                """

            let response = try await session.respond(
                to: prompt,
                generating: ClozeCardBatch.self,
                options: options
            )

            let flashcards = response.content.cards.map { clozeCard in
                clozeCard.toFlashcard(linkedEntryID: linkedEntryID, tags: [topicTag])
            }

            flashcardLog.info("Generated \(flashcards.count) cloze cards")
            return flashcards

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            flashcardLog.error("Guardrail violation during cloze generation")
            return []
        } catch LanguageModelSession.GenerationError.refusal {
            flashcardLog.warning("Model refused cloze generation request")
            return []
        } catch {
            flashcardLog.error("Cloze generation failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Q&A Cards

    private func generateQACards(
        text: String,
        linkedEntryID: UUID,
        topicTag: String,
        maxCards: Int
    ) async throws -> [Flashcard] {
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        flashcardLog.info("Generating Q&A cards...")

        do {
            let session = LanguageModelSession {
                """
                Create question-and-answer flashcards from the text.
                Each Q&A should focus on a specific fact, detail, or concept.
                Questions should be clear and specific.
                Answers should be concise and factual.
                """
            }

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.3
            )

            let prompt = """
                Create \(maxCards) question-and-answer flashcards from this text:

                \(text)
                """

            let response = try await session.respond(
                to: prompt,
                generating: QACardBatch.self,
                options: options
            )

            let flashcards = response.content.cards.map { qaCard in
                qaCard.toFlashcard(linkedEntryID: linkedEntryID, tags: [topicTag])
            }

            flashcardLog.info("Generated \(flashcards.count) Q&A cards")
            return flashcards

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            flashcardLog.error("Guardrail violation during Q&A generation")
            return []
        } catch LanguageModelSession.GenerationError.refusal {
            flashcardLog.warning("Model refused Q&A generation request")
            return []
        } catch {
            flashcardLog.error("Q&A generation failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Definition Cards

    private func generateDefinitionCards(
        text: String,
        entities: [String],
        linkedEntryID: UUID,
        topicTag: String,
        maxCards: Int
    ) async throws -> [Flashcard] {
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        flashcardLog.info("Generating definition cards...")

        do {
            let session = LanguageModelSession {
                """
                Create term-definition flashcards from the text.
                Each card should define a key term, concept, or entity based on the context.
                Definitions should be concise (1-2 sentences) and based only on information in the text.
                """
            }

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.3
            )

            let entityList = entities.joined(separator: ", ")
            let prompt = """
                Create \(maxCards) term-definition flashcards from this text.
                Focus on these key entities: \(entityList)

                Text:
                \(text)
                """

            let response = try await session.respond(
                to: prompt,
                generating: DefinitionCardBatch.self,
                options: options
            )

            let flashcards = response.content.cards.map { defCard in
                defCard.toFlashcard(linkedEntryID: linkedEntryID, tags: [topicTag])
            }

            flashcardLog.info("Generated \(flashcards.count) definition cards")
            return flashcards

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            flashcardLog.error("Guardrail violation during definition generation")
            return []
        } catch LanguageModelSession.GenerationError.refusal {
            flashcardLog.warning("Model refused definition generation request")
            return []
        } catch {
            flashcardLog.error("Definition generation failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Deduplication

    fileprivate func deduplicateFlashcards(_ flashcards: [Flashcard]) -> [Flashcard] {
        var seen = Set<String>()
        var unique: [Flashcard] = []

        for card in flashcards {
            let key = "\(card.question.lowercased())|\(card.answer.lowercased())"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(card)
            }
        }

        return unique
    }

    // MARK: - Interactive Clarification

    /// Generate a clarification/explanation for a flashcard using on-device AI
    /// - Parameters:
    ///   - flashcard: The flashcard to clarify
    ///   - userQuestion: The user's specific question
    /// - Returns: AI-generated explanation
    func clarifyFlashcard(_ flashcard: Flashcard, userQuestion: String) async throws -> String {
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            flashcardLog.error("Model not available for clarification")
            throw FMError.modelUnavailable
        }

        flashcardLog.info("Generating clarification for flashcard")

        do {
            let session = LanguageModelSession {
                """
                You are a helpful tutor assistant.
                Explain flashcard answers clearly and concisely.
                Use simple terms and provide context when helpful.
                Keep explanations to 2-3 sentences.
                ALWAYS be respectful and supportive.
                """
            }

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.7
            )

            let prompt = """
                Flashcard Question: \(flashcard.question)
                Flashcard Answer: \(flashcard.answer)

                User asks: \(userQuestion)

                Provide a clear explanation:
                """

            let response = try await session.respond(
                to: prompt,
                options: options
            )

            let explanation = response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            flashcardLog.info("Clarification generated")
            return explanation

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            flashcardLog.error("Guardrail violation during clarification")
            throw FMError.processingFailed
        } catch {
            flashcardLog.error("Clarification failed: \(error.localizedDescription)")
            throw FMError.processingFailed
        }
}
}

/// Inline AI capability badge
struct AICapabilityBadge: View {
    @StateObject private var fmClient = FMClient()

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(statusText)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(6)
    }

    var icon: String {
        switch fmClient.capability() {
        case .available: return "checkmark.circle.fill"
        case .notEnabled: return "exclamationmark.triangle.fill"
        case .notSupported: return "xmark.circle.fill"
        case .modelNotReady: return "arrow.down.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    var statusText: String {
        switch fmClient.capability() {
        case .available: return "AI Ready"
        case .notEnabled: return "AI Disabled"
        case .notSupported: return "AI Unavailable"
        case .modelNotReady: return "Downloading"
        case .unknown: return "Checking"
        }
    }

    var color: Color {
        switch fmClient.capability() {
        case .available: return .green
        case .notEnabled: return .orange
        case .notSupported: return .red
        case .modelNotReady: return .blue
        case .unknown: return .gray
        }
    }
}

// MARK: - AI Button with Capability Check

/// Button that handles AI capability states automatically
struct AIActionButton: View {
    let title: String
    let icon: String
    let action: () async throws -> Void

    @StateObject private var fmClient = FMClient()
    @State private var isLoading = false
    @State private var showError: Error?

    var body: some View {
        Button {
            Task {
                await performAction()
            }
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
            }
        }
        .disabled(isLoading || !isAvailable)
        .alert("AI Unavailable", isPresented: .constant(showError != nil)) {
            Button("OK") {
                showError = nil
            }
        } message: {
            if let error = showError {
                Text(error.localizedDescription)
            }
        }
    }

    var isAvailable: Bool {
        fmClient.capability() == .available
    }

    func performAction() async {
        guard isAvailable else {
            showError = FMError.modelUnavailable
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await action()
        } catch {
            showError = error
        }
    }
}

// MARK: - Preview

#Preview("AI Badge") {
    VStack {
        AICapabilityBadge()
        AICapabilityBadge()
        AICapabilityBadge()
    }
}
