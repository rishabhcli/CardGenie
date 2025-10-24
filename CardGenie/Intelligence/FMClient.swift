//
//  FMClient.swift
//  CardGenie
//
//  Client for Apple's Foundation Models framework (iOS 26+).
//  Provides on-device AI capabilities: summarization, tagging, and reflections.
//  All processing happens locally on the Neural Engine with zero network calls.
//

import Foundation
import Combine
import OSLog
import FoundationModels

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
    func capability() -> FMCapabilityState {
        // iOS 26+ required for Foundation Models
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
            let instructions = """
                You are a helpful journaling assistant.
                Summarize journal entries concisely in 2-3 sentences.
                Write in first person and maintain the original tone.
                Do not add facts not present in the entry.
                """

            let session = LanguageModelSession(instructions: instructions)

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.3 // Lower for more focused summaries
            )

            let response = try await session.respond(
                to: "Summarize this journal entry using three sentences:\n\n\(trimmed)",
                options: options
            )

            let summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            log.info("Summary generated: \(summary.count) chars")
            return summary

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            log.error("Guardrail violation during summarization")
            throw FMError.processingFailed
        } catch {
            log.error("Summarization failed: \(error.localizedDescription)")
            throw FMError.processingFailed
        }
    }

    /// Extract up to 3 relevant tags/keywords from the entry
    /// - Parameter text: The journal entry text to analyze
    /// - Returns: Array of extracted tags (max 3)
    /// - Throws: Error if the model is unavailable or processing fails
    func tags(for text: String) async throws -> [String] {
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
            let instructions = """
                Extract up to three short topic tags from the text.
                Each tag should be 1-2 words maximum.
                Examples: work, planning, travel, health, learning
                """

            let session = LanguageModelSession(instructions: instructions)

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
    }

    /// Generate a kind, encouraging reflection based on the entry
    /// - Parameter text: The journal entry text
    /// - Returns: One sentence of encouragement or reflection
    /// - Throws: Error if the model is unavailable or processing fails
    func reflection(for text: String) async throws -> String {
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
            let instructions = """
                You are a supportive journaling companion.
                Read the user's entry and respond with ONE kind, uplifting sentence.
                Be empathetic but concise.
                If they express difficulty, acknowledge it gently.
                If they express joy, celebrate with them.
                ALWAYS respond respectfully and supportively.
                """

            let session = LanguageModelSession(instructions: instructions)

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.7 // More creative/warm responses
            )

            let response = try await session.respond(
                to: "Provide a supportive reflection for this journal entry in one sentence:\n\n\(text)",
                options: options
            )

            let reflection = response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            log.info("Reflection generated")
            return reflection

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            log.error("Guardrail violation during reflection generation")
            throw FMError.processingFailed
        } catch {
            log.error("Reflection generation failed: \(error.localizedDescription)")
            throw FMError.processingFailed
        }
    }

    // MARK: - Streaming (Advanced)

    /// Stream a response token-by-token for real-time UI updates
    /// - Parameters:
    ///   - text: Input text
    ///   - onPartialContent: Callback for each partial content update
    /// - Throws: Error if streaming fails
    func streamSummary(_ text: String, onPartialContent: @escaping (String) -> Void) async throws {
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
            let instructions = """
                You are a helpful journaling assistant.
                Summarize journal entries concisely in 2-3 sentences.
                Write in first person and maintain the original tone.
                """

            let session = LanguageModelSession(instructions: instructions)

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.3
            )

            let stream = session.streamResponse(options: options) {
                "Summarize this journal entry using three sentences:\n\n\(text)"
            }

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
