//
//  InputProcessors.swift
//  CardGenie
//
//  Input processing for PDFs, images, handwriting, and videos.
//

import Foundation
import PDFKit
import Vision
import UIKit
import AVFoundation
import SwiftData
import PencilKit
import Speech
import OSLog

// MARK: - PDFProcessor

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

// MARK: - ImageProcessor

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

// MARK: - HandwritingProcessor


// MARK: - Handwriting Processor

final class HandwritingProcessor {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Create Handwritten Card

    /// Create or update handwriting data for a flashcard
    func saveHandwriting(
        for flashcard: Flashcard,
        questionDrawing: PKDrawing?,
        answerDrawing: PKDrawing?
    ) async throws {
        // Get or create handwriting data
        let handwritingData: HandwritingData

        if let existing = flashcard.handwritingData {
            handwritingData = existing
        } else {
            handwritingData = HandwritingData()
            modelContext.insert(handwritingData)
        }

        // Save question drawing
        if let qDrawing = questionDrawing {
            try handwritingData.setQuestionDrawing(qDrawing)

            // Extract OCR text
            let qImage = qDrawing.image(
                from: qDrawing.bounds,
                scale: 2.0
            )
            handwritingData.questionOCRText = try await extractText(from: qImage)
        }

        // Save answer drawing
        if let aDrawing = answerDrawing {
            try handwritingData.setAnswerDrawing(aDrawing)

            // Extract OCR text
            let aImage = aDrawing.image(
                from: aDrawing.bounds,
                scale: 2.0
            )
            handwritingData.answerOCRText = try await extractText(from: aImage)
        }

        // Mark as handwritten if either drawing exists
        handwritingData.isPrimaryHandwritten =
            (questionDrawing != nil && !questionDrawing!.bounds.isEmpty) ||
            (answerDrawing != nil && !answerDrawing!.bounds.isEmpty)

        try modelContext.save()
    }

    // MARK: - Vision OCR

    /// Extract text from handwriting using Vision
    private func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw HandwritingError.invalidImage
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
                }.joined(separator: " ")

                continuation.resume(returning: text)
            }

            // Configure for handwriting recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            // Add common academic terms
            request.customWords = [
                "mitochondria", "photosynthesis", "derivative", "integral",
                "theorem", "hypothesis", "coefficient", "polynomial",
                "algorithm", "binary", "syntax", "variable", "molecule",
                "electron", "neutron", "proton", "chromosome", "DNA", "RNA"
            ]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Handwriting Practice

    /// Compare student's handwritten answer with reference
    func gradeHandwriting(
        studentDrawing: PKDrawing,
        referenceText: String
    ) async throws -> HandwritingGrade {
        // Extract text from student's handwriting
        let image = studentDrawing.image(
            from: studentDrawing.bounds,
            scale: 2.0
        )
        let studentText = try await extractText(from: image)

        // Simple text comparison (can be enhanced with fuzzy matching)
        let similarity = calculateSimilarity(studentText, referenceText)

        // Determine grade
        let isCorrect = similarity > 0.85
        let feedback: String

        if similarity > 0.95 {
            feedback = "Perfect! Your answer is correct."
        } else if similarity > 0.85 {
            feedback = "Good! Minor differences: \"\(studentText)\" vs \"\(referenceText)\""
        } else if similarity > 0.6 {
            feedback = "Partially correct. You wrote: \"\(studentText)\""
        } else {
            feedback = "Try again. Expected: \"\(referenceText)\""
        }

        return HandwritingGrade(
            isCorrect: isCorrect,
            similarity: similarity,
            extractedText: studentText,
            feedback: feedback
        )
    }

    // MARK: - Helpers

    /// Simple string similarity (Levenshtein-based)
    private func calculateSimilarity(_ text1: String, _ text2: String) -> Double {
        let normalized1 = text1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized2 = text2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized1 == normalized2 {
            return 1.0
        }

        let distance = levenshteinDistance(normalized1, normalized2)
        let maxLength = max(normalized1.count, normalized2.count)

        guard maxLength > 0 else { return 0 }

        return 1.0 - (Double(distance) / Double(maxLength))
    }

    /// Levenshtein distance algorithm
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1 = Array(s1)
        let s2 = Array(s2)

        var dist = [[Int]](
            repeating: [Int](repeating: 0, count: s2.count + 1),
            count: s1.count + 1
        )

        for i in 0...s1.count {
            dist[i][0] = i
        }

        for j in 0...s2.count {
            dist[0][j] = j
        }

        for i in 1...s1.count {
            for j in 1...s2.count {
                let cost = s1[i - 1] == s2[j - 1] ? 0 : 1
                dist[i][j] = min(
                    dist[i - 1][j] + 1,      // deletion
                    dist[i][j - 1] + 1,      // insertion
                    dist[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return dist[s1.count][s2.count]
    }

    /// Convert handwritten card to typed (preserve OCR text)
    func convertToTyped(flashcard: Flashcard) throws {
        guard let handwriting = flashcard.handwritingData else {
            throw HandwritingError.noHandwritingData
        }

        // Use OCR text if available
        if let qText = handwriting.questionOCRText, !qText.isEmpty {
            flashcard.question = qText
        }

        if let aText = handwriting.answerOCRText, !aText.isEmpty {
            flashcard.answer = aText
        }

        // Keep handwriting data but mark as not primary
        handwriting.isPrimaryHandwritten = false

        try modelContext.save()
    }

    /// Convert typed card to handwritten mode
    func enableHandwriting(for flashcard: Flashcard) throws {
        let handwriting = HandwritingData()
        handwriting.isPrimaryHandwritten = true

        modelContext.insert(handwriting)
        try modelContext.save()
    }
}

// MARK: - Handwriting Grade Result

struct HandwritingGrade {
    let isCorrect: Bool
    let similarity: Double
    let extractedText: String
    let feedback: String
}

// MARK: - Errors

enum HandwritingError: LocalizedError {
    case invalidImage
    case ocrFailed
    case noHandwritingData

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Invalid image format"
        case .ocrFailed: return "Handwriting recognition failed"
        case .noHandwritingData: return "No handwriting data found"
        }
    }
}

// MARK: - PKDrawing Extension

extension PKDrawing {
    /// Check if drawing is empty
    var isEmpty: Bool {
        bounds.isEmpty || strokes.isEmpty
    }
}

// MARK: - VideoProcessor

private struct ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession
}

// MARK: - Progress Delegate

protocol VideoProcessorDelegate: AnyObject {
    func videoProcessor(_ processor: VideoProcessor, didUpdateProgress progress: VideoProcessingProgress)
    func videoProcessor(_ processor: VideoProcessor, didFailWithError error: Error)
}

// MARK: - Processing Progress

struct VideoProcessingProgress {
    enum Phase {
        case extractingAudio
        case transcribing
        case generatingChunks
        case creatingEmbeddings
        case summarizing
        case completed
    }

    let phase: Phase
    let percentComplete: Double // 0.0 - 1.0
    let message: String
}

// MARK: - Video Processor

final class VideoProcessor {
    private let llm: LLMEngine
    private let embedding: EmbeddingEngine
    private let log = Logger(subsystem: "com.cardgenie.app", category: "VideoProcessor")

    // SFSpeechRecognizer can be nil for a given locale; handle safely.
    private let speechRecognizer: SFSpeechRecognizer?
    // Retain the task to avoid it being deallocated prematurely and to support cancellation.
    private var recognitionTask: SFSpeechRecognitionTask?

    weak var delegate: VideoProcessorDelegate?
    private var isCancelled = false

    init(llm: LLMEngine = AIEngineFactory.createLLMEngine(),
         embedding: EmbeddingEngine = AIEngineFactory.createEmbeddingEngine(),
         locale: Locale = Locale(identifier: "en-US")) {
        self.llm = llm
        self.embedding = embedding
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)

        if speechRecognizer != nil {
            log.info("✅ Speech recognizer initialized for locale: \(locale.identifier)")
        } else {
            log.warning("⚠️ Speech recognizer not available for locale: \(locale.identifier)")
        }
    }

    // MARK: - Cancellation

    func cancel() {
        log.info("🛑 Cancelling video processing")
        isCancelled = true
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    private func reportProgress(_ phase: VideoProcessingProgress.Phase, percent: Double, message: String) {
        let progress = VideoProcessingProgress(phase: phase, percentComplete: percent, message: message)
        delegate?.videoProcessor(self, didUpdateProgress: progress)
        log.info("📊 Progress: \(message) (\(Int(percent * 100))%)")
    }

    // MARK: - Main Processing

    /// Process video and extract audio → transcript → chunks
    func process(videoURL: URL) async throws -> SourceDocument {
        log.info("🎬 Starting video processing: \(videoURL.lastPathComponent)")
        isCancelled = false

        do {
            // Ensure speech authorization before starting any work that depends on it.
            try await ensureSpeechAuthorization()
            reportProgress(.extractingAudio, percent: 0.0, message: "Preparing video...")

            let fileName = videoURL.lastPathComponent
            let fileSize = try getFileSize(videoURL)

            let sourceDoc = SourceDocument(
                kind: .video,
                fileName: fileName,
                fileURL: videoURL,
                fileSize: fileSize
            )

            // Get video duration
            let asset = AVURLAsset(url: videoURL)
            let duration = try await asset.load(.duration).seconds
            sourceDoc.duration = duration
            log.info("📹 Video duration: \(Int(duration))s")

            // Extract audio track
            reportProgress(.extractingAudio, percent: 0.1, message: "Extracting audio...")
            let audioURL = try await extractAudio(from: videoURL)
            // Clean up the temporary audio file after we're done with it.
            defer { try? FileManager.default.removeItem(at: audioURL) }

            if isCancelled { throw CancellationError() }
            log.info("🔊 Audio extracted successfully")

            // Transcribe audio offline
            reportProgress(.transcribing, percent: 0.3, message: "Transcribing audio (on-device)...")
            let transcript = try await transcribe(audioURL: audioURL, duration: duration)
            log.info("📝 Transcription complete: \(transcript.count) segments")

            if isCancelled { throw CancellationError() }

            // Chunk by timestamps
            reportProgress(.generatingChunks, percent: 0.6, message: "Organizing transcript...")
            let chunks = chunkTranscript(transcript)
            log.info("📦 Created \(chunks.count) chunks")

            // Generate embeddings
            reportProgress(.creatingEmbeddings, percent: 0.7, message: "Creating embeddings (on-device)...")
            let chunkTexts = chunks.map { $0.text }
            let embeddings = try await embedding.embed(chunkTexts)
            log.info("🧠 Generated \(embeddings.count) embeddings")

            if isCancelled { throw CancellationError() }

            // Create NoteChunks
            reportProgress(.summarizing, percent: 0.8, message: "Summarizing content...")
            for (index, chunk) in chunks.enumerated() {
                if isCancelled { throw CancellationError() }

                let noteChunk = NoteChunk(
                    text: chunk.text,
                    chunkIndex: index
                )
                noteChunk.setTimeRange(chunk.timeRange)

                if index < embeddings.count {
                    noteChunk.setEmbedding(embeddings[index])
                }

                // Summarize chunk
                noteChunk.summary = try? await summarizeChunk(chunk.text)

                sourceDoc.chunks.append(noteChunk)

                // Update progress for each chunk
                let chunkProgress = 0.8 + (0.15 * Double(index + 1) / Double(chunks.count))
                reportProgress(.summarizing, percent: chunkProgress, message: "Summarizing chunk \(index + 1)/\(chunks.count)...")
            }

            if isCancelled { throw CancellationError() }

            sourceDoc.processedAt = Date()
            reportProgress(.completed, percent: 1.0, message: "Processing complete!")
            log.info("✅ Video processing complete!")

            return sourceDoc

        } catch {
            log.error("❌ Video processing failed: \(error.localizedDescription)")
            delegate?.videoProcessor(self, didFailWithError: error)
            throw error
        }
    }

    // MARK: - Audio Extraction

    private func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)

        // Ensure there is at least one audio track to export.
        guard let _ = try await asset.loadTracks(withMediaType: .audio).first else {
            throw VideoProcessingError.noAudioTrack
        }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw VideoProcessingError.exportFailed
        }

        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("\(UUID().uuidString).m4a")

        if #available(iOS 18.0, *) {
            try await exportSession.export(to: audioURL, as: .m4a)
            return audioURL
        } else {
            exportSession.outputURL = audioURL
            exportSession.outputFileType = .m4a

            // Use the legacy async export API bridged via continuation.
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let sessionBox = ExportSessionBox(session: exportSession)
                sessionBox.session.exportAsynchronously {
                    switch sessionBox.session.status {
                    case .completed:
                        continuation.resume()
                    case .failed, .cancelled:
                        continuation.resume(throwing: VideoProcessingError.exportFailed)
                    default:
                        // Should not happen, but treat as failure
                        continuation.resume(throwing: VideoProcessingError.exportFailed)
                    }
                }
            }

            return audioURL
        }
    }

    // MARK: - Transcription

    private func transcribe(audioURL: URL, duration: Double) async throws -> [TimestampedSegment] {
        if Task.isCancelled { throw CancellationError() }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw VideoProcessingError.speechRecognizerUnavailable
        }

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = true // OFFLINE ONLY

            var segments: [TimestampedSegment] = []

            self?.recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                if let error = error {
                    self?.recognitionTask = nil
                    continuation.resume(throwing: error)
                    return
                }

                guard let result = result else { return }

                // Extract segments with timestamps
                let transcription = result.bestTranscription

                if result.isFinal {
                    // Group by time intervals (30-second chunks)
                    var currentChunk = ""
                    var chunkStart: TimeInterval = 0
                    var currentTime: TimeInterval = 0

                    for segment in transcription.segments {
                        let segmentTime = segment.timestamp

                        // If we've passed 30 seconds, create new chunk
                        if segmentTime - chunkStart >= 30 {
                            if !currentChunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                segments.append(TimestampedSegment(
                                    text: currentChunk.trimmingCharacters(in: .whitespacesAndNewlines),
                                    timeRange: TimestampRange(start: chunkStart, end: min(currentTime, duration))
                                ))
                            }
                            currentChunk = segment.substring
                            chunkStart = segmentTime
                        } else {
                            if currentChunk.isEmpty {
                                currentChunk = segment.substring
                            } else {
                                currentChunk += " " + segment.substring
                            }
                        }

                        currentTime = segmentTime + segment.duration
                    }

                    // Add final chunk
                    if !currentChunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        segments.append(TimestampedSegment(
                            text: currentChunk.trimmingCharacters(in: .whitespacesAndNewlines),
                            timeRange: TimestampRange(start: chunkStart, end: min(currentTime, duration))
                        ))
                    }

                    self?.recognitionTask = nil

                    if segments.isEmpty {
                        continuation.resume(throwing: VideoProcessingError.transcriptionFailed)
                    } else {
                        continuation.resume(returning: segments)
                    }
                }
            }
        }
    }

    // MARK: - Chunking

    private func chunkTranscript(_ segments: [TimestampedSegment]) -> [TranscriptChunkData] {
        // Already chunked by time, just convert
        return segments.enumerated().map { index, segment in
            TranscriptChunkData(
                text: segment.text,
                timeRange: segment.timeRange,
                chunkIndex: index
            )
        }
    }

    // MARK: - Summarization

    private func summarizeChunk(_ text: String) async throws -> String {
        let prompt = """
        Summarize this video transcript segment in 2-3 bullet points.

        TRANSCRIPT:
        \(text.prefix(1000))

        SUMMARY (bullets):
        """

        let summary = try await llm.complete(prompt, maxTokens: 200)
        return summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private func getFileSize(_ url: URL) throws -> Int64 {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return attrs[.size] as? Int64 ?? 0
    }

    private func ensureSpeechAuthorization() async throws {
        // Fast-path if already authorized
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return
        case .denied, .restricted:
            throw VideoProcessingError.speechRecognizerUnavailable
        case .notDetermined:
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { newStatus in
                    continuation.resume(returning: newStatus)
                }
            }
            guard status == .authorized else { throw VideoProcessingError.speechRecognizerUnavailable }
        @unknown default:
            throw VideoProcessingError.speechRecognizerUnavailable
        }
    }
}

// MARK: - Supporting Types

private struct TimestampedSegment {
    let text: String
    let timeRange: TimestampRange
}

private struct TranscriptChunkData {
    let text: String
    let timeRange: TimestampRange
    let chunkIndex: Int
}

// MARK: - Errors

enum VideoProcessingError: LocalizedError {
    case noAudioTrack
    case exportFailed
    case speechRecognizerUnavailable
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .noAudioTrack: return "Video has no audio track"
        case .exportFailed: return "Failed to export audio"
        case .speechRecognizerUnavailable: return "Speech recognition not available"
        case .transcriptionFailed: return "Transcription failed"
        }
    }
}
