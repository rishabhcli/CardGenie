//
//  AIEngine.swift
//  CardGenie
//
//  Core AI engine protocols for offline-first LLM and embeddings.
//

import Foundation

// MARK: - LLM Engine Protocol

/// Protocol for large language model inference
protocol LLMEngine {
    /// Generate text completion from prompt
    func complete(_ prompt: String, maxTokens: Int) async throws -> String

    /// Stream text completion (for chat/tutoring)
    func streamComplete(_ prompt: String, maxTokens: Int) -> AsyncThrowingStream<String, Error>

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

    func complete(_ prompt: String, maxTokens: Int) async throws -> String {
        guard isAvailable else {
            throw LLMError.notAvailable
        }

        // Use existing FMClient methods
        return try await fmClient.reflection(for: prompt)
    }

    func streamComplete(_ prompt: String, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await complete(prompt, maxTokens: maxTokens)
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
        // Simplified embedding using NaturalLanguage framework
        // In production, use actual embedding model
        let normalized = text.lowercased()
        let hash = abs(normalized.hashValue)

        // Simple hash-based embedding (placeholder)
        // TODO: Replace with actual NLEmbedding or Core ML model
        return (0..<dimension).map { i in
            Float(sin(Double(hash + i) * 0.1))
        }
    }
}

// MARK: - AI Engine Factory

/// Factory for creating appropriate AI engines
struct AIEngineFactory {
    static func createLLMEngine() -> LLMEngine {
        // Try Apple's on-device first
        let apple = AppleOnDeviceLLM()
        if apple.isAvailable {
            return apple
        }

        // Fallback to CoreML (to be implemented)
        // return CoreMLLLM()

        return apple // Return anyway, will fail gracefully
    }

    static func createEmbeddingEngine() -> EmbeddingEngine {
        return AppleEmbedding()
    }
}
