//
//  PDFProcessor.swift
//  CardGenie
//
//  Offline PDF processing with Vision OCR fallback.
//

import Foundation
import PDFKit
import Vision
import UIKit

// MARK: - PDF Processor

final class PDFProcessor {
    private let llm: LLMEngine
    private let embedding: EmbeddingEngine

    init(llm: LLMEngine = AIEngineFactory.createLLMEngine(),
         embedding: EmbeddingEngine = AIEngineFactory.createEmbeddingEngine()) {
        self.llm = llm
        self.embedding = embedding
    }

    // MARK: - Main Processing

    /// Process PDF and create source document with chunks
    func process(pdfURL: URL) async throws -> SourceDocument {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw ProcessingError.invalidPDF
        }

        let fileName = pdfURL.lastPathComponent
        let fileSize: Int64 = {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: pdfURL.path),
               let size = attrs[.size] as? Int64 {
                return size
            }
            return 0
        }()

        let sourceDoc = SourceDocument(
            kind: .pdf,
            fileName: fileName,
            fileURL: pdfURL,
            fileSize: fileSize
        )
        sourceDoc.totalPages = pdfDocument.pageCount

        // Extract text from all pages
        var allText: [PageText] = []

        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            // Try PDFKit text extraction first
            var text = page.string ?? ""

            // If minimal text, use Vision OCR (scanned PDF)
            if text.trimmingCharacters(in: .whitespacesAndNewlines).count < 50 {
                text = try await extractTextWithVision(from: page)
            }

            if !text.isEmpty {
                allText.append(PageText(pageNumber: pageIndex + 1, text: text))
            }
        }

        // Chunk the text semantically
        let chunks = await chunkText(allText)

        // Generate embeddings for each chunk
        let chunkTexts = chunks.map { $0.text }
        let embeddings = try await embedding.embed(chunkTexts)

        // Create NoteChunks
        for (index, chunk) in chunks.enumerated() {
            let noteChunk = NoteChunk(
                text: chunk.text,
                chunkIndex: index,
                pageNumber: chunk.pageNumber
            )

            // Store embedding
            if index < embeddings.count {
                noteChunk.setEmbedding(embeddings[index])
            }

            // Generate summary for chunk
            noteChunk.summary = try? await summarizeChunk(chunk.text)

            sourceDoc.chunks.append(noteChunk)
        }

        sourceDoc.processedAt = Date()
        return sourceDoc
    }

    // MARK: - Vision OCR

    private func extractTextWithVision(from page: PDFPage) async throws -> String {
        // Render page to image
        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)

        let image = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)

            ctx.cgContext.translateBy(x: 0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)

            page.draw(with: .mediaBox, to: ctx.cgContext)
        }

        // OCR with Vision
        guard let cgImage = image.cgImage else {
            throw ProcessingError.ocrFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.customWords = ["mitochondria", "photosynthesis", "derivative", "integral"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Semantic Chunking

    private func chunkText(_ pages: [PageText]) async -> [TextChunk] {
        var chunks: [TextChunk] = []

        for page in pages {
            let text = page.text

            // Split by headings (lines in all caps or starting with #)
            let lines = text.components(separatedBy: .newlines)
            var currentChunk = ""
            var chunkStartPage = page.pageNumber

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Check if line is a heading
                if isHeading(trimmed) && !currentChunk.isEmpty {
                    // Save current chunk
                    chunks.append(TextChunk(
                        text: currentChunk,
                        pageNumber: chunkStartPage
                    ))
                    currentChunk = trimmed + "\n"
                    chunkStartPage = page.pageNumber
                } else {
                    currentChunk += line + "\n"
                }

                // If chunk gets too large (>500 words), split
                if currentChunk.split(separator: " ").count > 500 {
                    chunks.append(TextChunk(
                        text: currentChunk,
                        pageNumber: chunkStartPage
                    ))
                    currentChunk = ""
                    chunkStartPage = page.pageNumber
                }
            }

            // Add remaining chunk
            if !currentChunk.isEmpty {
                chunks.append(TextChunk(
                    text: currentChunk,
                    pageNumber: chunkStartPage
                ))
            }
        }

        return chunks
    }

    private func isHeading(_ line: String) -> Bool {
        // Heuristics for detecting headings
        if line.isEmpty { return false }

        // All caps (at least 3 words)
        if line == line.uppercased() && line.split(separator: " ").count >= 3 {
            return true
        }

        // Starts with # or numbers like "1.", "1.1"
        if line.hasPrefix("#") || line.range(of: #"^\d+\.(\d+\.)?\s+"#, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    // MARK: - Summarization

    private func summarizeChunk(_ text: String) async throws -> String {
        let prompt = """
        Summarize this academic text in 2-3 concise bullet points. Focus on key concepts.

        TEXT:
        \(text.prefix(1000))

        SUMMARY (bullets):
        """

        let summary = try await llm.complete(prompt, maxTokens: 200)
        return summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Supporting Types

private struct PageText {
    let pageNumber: Int
    let text: String
}

private struct TextChunk {
    let text: String
    let pageNumber: Int
}

enum ProcessingError: LocalizedError {
    case invalidPDF
    case ocrFailed
    case chunkingFailed

    var errorDescription: String? {
        switch self {
        case .invalidPDF: return "Could not load PDF file"
        case .ocrFailed: return "Text recognition failed"
        case .chunkingFailed: return "Failed to process text"
        }
    }
}
