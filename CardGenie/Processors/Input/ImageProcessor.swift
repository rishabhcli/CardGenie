//
//  ImageProcessor.swift
//  CardGenie
//
//  Offline image/slide OCR with Vision framework.
//

import Foundation
import Vision
import UIKit

// MARK: - Image Processor

final class ImageProcessor {
    private let llm: LLMEngine
    private let embedding: EmbeddingEngine

    init(llm: LLMEngine = AIEngineFactory.createLLMEngine(),
         embedding: EmbeddingEngine = AIEngineFactory.createEmbeddingEngine()) {
        self.llm = llm
        self.embedding = embedding
    }

    // MARK: - Main Processing

    /// Process image (slide/whiteboard photo) and create source document with chunks
    func process(images: [UIImage], title: String = "Slides") async throws -> SourceDocument {
        let sourceDoc = SourceDocument(
            kind: .image,
            fileName: title,
            fileSize: 0
        )
        sourceDoc.totalPages = images.count

        var allText: [SlideText] = []

        for (index, image) in images.enumerated() {
            let text = try await extractText(from: image)

            if !text.isEmpty {
                allText.append(SlideText(slideNumber: index + 1, text: text))
            }
        }

        // Chunk the text
        let chunks = chunkSlides(allText)

        // Generate embeddings
        let chunkTexts = chunks.map { $0.text }
        let embeddings = try await embedding.embed(chunkTexts)

        // Create NoteChunks
        for (index, chunk) in chunks.enumerated() {
            let noteChunk = NoteChunk(
                text: chunk.text,
                chunkIndex: index
            )
            noteChunk.slideNumber = chunk.slideNumber

            // Store embedding
            if index < embeddings.count {
                noteChunk.setEmbedding(embeddings[index])
            }

            // Generate summary
            noteChunk.summary = try? await summarizeChunk(chunk.text)

            sourceDoc.chunks.append(noteChunk)
        }

        sourceDoc.processedAt = Date()
        return sourceDoc
    }

    // MARK: - Vision OCR

    private func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw ImageProcessingError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []

                // Sort by vertical position (top to bottom)
                let sorted = observations.sorted { obs1, obs2 in
                    obs1.boundingBox.minY > obs2.boundingBox.minY
                }

                let text = sorted.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            // Configure for accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            // Add common academic terms
            request.customWords = [
                "mitochondria", "photosynthesis", "derivative", "integral",
                "theorem", "hypothesis", "coefficient", "polynomial",
                "algorithm", "binary", "syntax", "variable"
            ]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Chunking

    private func chunkSlides(_ slides: [SlideText]) -> [SlideChunk] {
        var chunks: [SlideChunk] = []

        for slide in slides {
            // Each slide is typically one chunk
            // But if slide has a lot of text, split it
            let text = slide.text

            if text.split(separator: " ").count > 300 {
                // Split long slides by sections
                let sections = splitByHeadings(text)
                for section in sections {
                    chunks.append(SlideChunk(
                        text: section,
                        slideNumber: slide.slideNumber
                    ))
                }
            } else {
                chunks.append(SlideChunk(
                    text: text,
                    slideNumber: slide.slideNumber
                ))
            }
        }

        return chunks
    }

    private func splitByHeadings(_ text: String) -> [String] {
        var sections: [String] = []
        var current = ""

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect headings (all caps, short lines)
            if trimmed == trimmed.uppercased() &&
               trimmed.count > 2 &&
               trimmed.count < 50 &&
               !current.isEmpty {
                sections.append(current)
                current = trimmed + "\n"
            } else {
                current += line + "\n"
            }
        }

        if !current.isEmpty {
            sections.append(current)
        }

        return sections
    }

    // MARK: - Summarization

    private func summarizeChunk(_ text: String) async throws -> String {
        let prompt = """
        Summarize this slide content in 2-3 concise bullet points. Focus on key concepts.

        SLIDE TEXT:
        \(text.prefix(1000))

        SUMMARY (bullets):
        """

        let summary = try await llm.complete(prompt, maxTokens: 150)
        return summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Supporting Types

private struct SlideText {
    let slideNumber: Int
    let text: String
}

private struct SlideChunk {
    let text: String
    let slideNumber: Int
}

enum ImageProcessingError: LocalizedError {
    case invalidImage
    case ocrFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Invalid image format"
        case .ocrFailed: return "Text recognition failed"
        }
    }
}
