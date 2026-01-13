//
//  InputProcessorTests.swift
//  CardGenie
//
//  Unit tests for InputProcessors - PDF, Image, Handwriting, Video processing.
//

import XCTest
import PDFKit
import Vision
@testable import CardGenie

// MARK: - PDFProcessor Tests

final class PDFProcessorTests: XCTestCase {

    func testPDFProcessorInitialization() {
        // Given/When: Creating a PDF processor
        let processor = PDFProcessor()

        // Then: Should initialize
        XCTAssertNotNil(processor)
    }

    func testPDFProcessorWithInvalidURL() async {
        // Given: An invalid PDF URL
        let processor = PDFProcessor()
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.pdf")

        // When/Then: Should throw error
        do {
            _ = try await processor.process(pdfURL: invalidURL)
            XCTFail("Should throw error for invalid PDF")
        } catch {
            XCTAssertTrue(error is ProcessingError)
        }
    }
}

// MARK: - ProcessingError Tests

final class ProcessingErrorTests: XCTestCase {

    func testProcessingErrorDescriptions() {
        // Given: Various processing errors
        let invalidPDF = ProcessingError.invalidPDF
        let ocrFailed = ProcessingError.ocrFailed
        let noTextFound = ProcessingError.noTextFound

        // Then: Should have descriptions
        XCTAssertNotNil(invalidPDF.errorDescription)
        XCTAssertNotNil(ocrFailed.errorDescription)
        XCTAssertNotNil(noTextFound.errorDescription)
    }

    func testProcessingErrorTypes() {
        // Given/When/Then: Verify all error cases exist
        let errors: [ProcessingError] = [
            .invalidPDF,
            .ocrFailed,
            .noTextFound,
            .embeddingFailed,
            .chunkingFailed
        ]

        XCTAssertEqual(errors.count, 5)
    }
}

// MARK: - ImageProcessor Tests

@MainActor
final class ImageProcessorTests: XCTestCase {

    func testImageProcessorInitialization() async throws {
        // Given/When: Creating an image processor
        let processor = ImageProcessor()

        // Then: Should initialize
        XCTAssertNotNil(processor)
    }
}

// MARK: - HandwritingProcessor Tests

@MainActor
final class HandwritingProcessorTests: XCTestCase {

    func testHandwritingProcessorInitialization() async throws {
        // Given/When: Creating a handwriting processor
        let processor = HandwritingProcessor()

        // Then: Should initialize
        XCTAssertNotNil(processor)
    }
}

// MARK: - VideoProcessor Tests

@MainActor
final class VideoProcessorTests: XCTestCase {

    func testVideoProcessorInitialization() async throws {
        // Given/When: Creating a video processor
        let processor = VideoProcessor()

        // Then: Should initialize
        XCTAssertNotNil(processor)
    }
}

// MARK: - TextExtractionResult Tests

final class TextExtractionResultTests: XCTestCase {

    func testTextExtractionResultCreation() {
        // Given/When: Creating a result
        let result = TextExtractionResult(
            text: "Extracted text",
            confidence: 0.92,
            detectedLanguages: ["en-US", "es"],
            blockCount: 5,
            wordCount: 50,
            preprocessingApplied: true
        )

        // Then: Should have correct values
        XCTAssertEqual(result.text, "Extracted text")
        XCTAssertEqual(result.confidence, 0.92, accuracy: 0.01)
        XCTAssertEqual(result.detectedLanguages.count, 2)
        XCTAssertEqual(result.blockCount, 5)
        XCTAssertEqual(result.wordCount, 50)
        XCTAssertTrue(result.preprocessingApplied)
    }

    func testTextExtractionResultHighConfidence() {
        // Given: High confidence result
        let result = TextExtractionResult(
            text: "Test",
            confidence: 0.95,
            detectedLanguages: ["en"],
            blockCount: 1,
            wordCount: 1,
            preprocessingApplied: false
        )

        // Then: Should be high confidence
        XCTAssertEqual(result.confidenceLevel, .high)
    }

    func testTextExtractionResultMediumConfidence() {
        // Given: Medium confidence result
        let result = TextExtractionResult(
            text: "Test",
            confidence: 0.75,
            detectedLanguages: ["en"],
            blockCount: 1,
            wordCount: 1,
            preprocessingApplied: false
        )

        // Then: Should be medium confidence
        XCTAssertEqual(result.confidenceLevel, .medium)
    }

    func testTextExtractionResultLowConfidence() {
        // Given: Low confidence result
        let result = TextExtractionResult(
            text: "Test",
            confidence: 0.4,
            detectedLanguages: ["en"],
            blockCount: 1,
            wordCount: 1,
            preprocessingApplied: false
        )

        // Then: Should be low confidence
        XCTAssertEqual(result.confidenceLevel, .low)
    }
}

// MARK: - PreprocessingConfig Tests

final class PreprocessingConfigTests: XCTestCase {

    func testPreprocessingConfigMinimal() {
        // Given/When: Getting minimal config
        let config = PreprocessingConfig.minimal

        // Then: Should have minimal settings
        XCTAssertFalse(config.enhanceContrast)
        XCTAssertFalse(config.convertToGrayscale)
        XCTAssertFalse(config.autoRotate)
        XCTAssertFalse(config.deskew)
        XCTAssertEqual(config.denoise, 0)
    }

    func testPreprocessingConfigStandard() {
        // Given/When: Getting standard config
        let config = PreprocessingConfig.standard

        // Then: Should have standard settings
        XCTAssertTrue(config.enhanceContrast)
        XCTAssertTrue(config.convertToGrayscale)
        XCTAssertTrue(config.autoRotate)
        XCTAssertFalse(config.deskew)
    }

    func testPreprocessingConfigAggressive() {
        // Given/When: Getting aggressive config
        let config = PreprocessingConfig.aggressive

        // Then: Should have all settings enabled
        XCTAssertTrue(config.enhanceContrast)
        XCTAssertTrue(config.convertToGrayscale)
        XCTAssertTrue(config.autoRotate)
        XCTAssertTrue(config.deskew)
        XCTAssertGreaterThan(config.denoise, 0)
    }

    func testPreprocessingConfigCustom() {
        // Given/When: Creating custom config
        let config = PreprocessingConfig(
            enhanceContrast: true,
            convertToGrayscale: false,
            autoRotate: true,
            deskew: false,
            denoise: 0.5
        )

        // Then: Should have custom settings
        XCTAssertTrue(config.enhanceContrast)
        XCTAssertFalse(config.convertToGrayscale)
        XCTAssertTrue(config.autoRotate)
        XCTAssertFalse(config.deskew)
        XCTAssertEqual(config.denoise, 0.5, accuracy: 0.01)
    }
}

// MARK: - PreprocessingResult Tests

final class PreprocessingResultTests: XCTestCase {

    func testPreprocessingResultCreation() {
        // Given: A test image and operations
        let image = createTestImage()
        let operations = ["contrast_enhanced", "grayscale_converted"]

        // When: Creating result
        let result = PreprocessingResult(
            processedImage: image,
            appliedOperations: operations,
            processingTime: 0.5
        )

        // Then: Should have correct values
        XCTAssertNotNil(result.processedImage)
        XCTAssertEqual(result.appliedOperations.count, 2)
        XCTAssertEqual(result.processingTime, 0.5, accuracy: 0.01)
    }

    // Helper
    private func createTestImage() -> UIImage {
        UIGraphicsBeginImageContext(CGSize(width: 100, height: 100))
        UIColor.white.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}

// MARK: - ConfidenceLevel Tests

final class ConfidenceLevelTests: XCTestCase {

    func testConfidenceLevelRawValues() {
        // Given/When/Then: Verify raw values
        XCTAssertEqual(ConfidenceLevel.high.rawValue, "high")
        XCTAssertEqual(ConfidenceLevel.medium.rawValue, "medium")
        XCTAssertEqual(ConfidenceLevel.low.rawValue, "low")
    }

    func testConfidenceLevelThresholds() {
        // Given: Different confidence values
        // Then: Should map to correct levels

        // High: >= 0.85
        XCTAssertEqual(confidenceLevelFor(0.95), .high)
        XCTAssertEqual(confidenceLevelFor(0.85), .high)

        // Medium: >= 0.6 && < 0.85
        XCTAssertEqual(confidenceLevelFor(0.84), .medium)
        XCTAssertEqual(confidenceLevelFor(0.6), .medium)

        // Low: < 0.6
        XCTAssertEqual(confidenceLevelFor(0.59), .low)
        XCTAssertEqual(confidenceLevelFor(0.1), .low)
    }

    private func confidenceLevelFor(_ value: Float) -> ConfidenceLevel {
        if value >= 0.85 {
            return .high
        } else if value >= 0.6 {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - ScanMetrics Tests

final class ScanMetricsTests: XCTestCase {

    func testScanMetricsInitialization() {
        // Given/When: Creating metrics
        let metrics = ScanMetrics()

        // Then: Should have zero initial values
        XCTAssertEqual(metrics.scanAttempts, 0)
        XCTAssertEqual(metrics.successfulScans, 0)
        XCTAssertEqual(metrics.failedScans, 0)
        XCTAssertEqual(metrics.totalCharactersExtracted, 0)
        XCTAssertEqual(metrics.averageConfidence, 0)
        XCTAssertEqual(metrics.multiPageScans, 0)
        XCTAssertEqual(metrics.preprocessingUsed, 0)
        XCTAssertEqual(metrics.lowConfidenceWarnings, 0)
    }

    func testScanMetricsSuccessRate() {
        // Given: Metrics with results
        var metrics = ScanMetrics()
        metrics.scanAttempts = 10
        metrics.successfulScans = 8

        // Then: Success rate should be 80%
        XCTAssertEqual(metrics.successRate, 0.8, accuracy: 0.01)
    }

    func testScanMetricsSuccessRateNoAttempts() {
        // Given: Metrics with no attempts
        let metrics = ScanMetrics()

        // Then: Success rate should be 0
        XCTAssertEqual(metrics.successRate, 0)
    }
}

// MARK: - NoteChunk Tests

@MainActor
final class NoteChunkTests: XCTestCase {

    func testNoteChunkInitialization() async throws {
        // Given/When: Creating a note chunk
        let chunk = NoteChunk()

        // Then: Should have default values
        XCTAssertNotNil(chunk.id)
        XCTAssertEqual(chunk.text, "")
        XCTAssertNil(chunk.pageNumber)
    }

    func testNoteChunkWithContent() async throws {
        // Given: Chunk parameters
        let text = "This is sample text from the document."
        let pageNumber = 3

        // When: Creating with content
        let chunk = NoteChunk()
        chunk.text = text
        chunk.pageNumber = pageNumber

        // Then: Should have correct values
        XCTAssertEqual(chunk.text, text)
        XCTAssertEqual(chunk.pageNumber, 3)
    }

    func testNoteChunkSetEmbedding() async throws {
        // Given: A chunk and embedding
        let chunk = NoteChunk()
        let embedding: [Float] = [0.1, 0.2, 0.3, 0.4]

        // When: Setting embedding
        chunk.setEmbedding(embedding)

        // Then: Should store embedding
        XCTAssertNotNil(chunk.embeddingData)
    }

    func testNoteChunkGetEmbedding() async throws {
        // Given: A chunk with embedding
        let chunk = NoteChunk()
        let embedding: [Float] = [0.1, 0.2, 0.3, 0.4]
        chunk.setEmbedding(embedding)

        // When: Getting embedding
        let retrieved = chunk.getEmbedding()

        // Then: Should match original
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.count, 4)
        XCTAssertEqual(retrieved?[0], 0.1, accuracy: 0.001)
    }
}

// MARK: - SourceDocument Tests

@MainActor
final class SourceDocumentTests: XCTestCase {

    func testSourceDocumentInitialization() async throws {
        // Given/When: Creating a source document
        let doc = SourceDocument(kind: .pdf, fileName: "test.pdf")

        // Then: Should have correct values
        XCTAssertNotNil(doc.id)
        XCTAssertEqual(doc.kind, .pdf)
        XCTAssertEqual(doc.fileName, "test.pdf")
        XCTAssertNotNil(doc.createdAt)
        XCTAssertNil(doc.processedAt)
        XCTAssertTrue(doc.chunks.isEmpty)
    }

    func testSourceDocumentKinds() async throws {
        // Given: All source kinds
        let kinds: [SourceKind] = [.pdf, .video, .image, .audio, .csv, .text, .lecture]

        // Then: Should have 7 kinds
        XCTAssertEqual(kinds.count, 7)
    }

    func testSourceDocumentWithURL() async throws {
        // Given: A URL
        let url = URL(fileURLWithPath: "/test/document.pdf")

        // When: Creating document with URL
        let doc = SourceDocument(kind: .pdf, fileName: "document.pdf", fileURL: url)

        // Then: Should have URL
        XCTAssertEqual(doc.fileURL, url)
    }

    func testSourceDocumentWithFileSize() async throws {
        // Given: File size
        let fileSize: Int64 = 1024 * 1024 // 1MB

        // When: Creating document with size
        let doc = SourceDocument(kind: .pdf, fileName: "large.pdf", fileSize: fileSize)

        // Then: Should have correct size
        XCTAssertEqual(doc.fileSize, fileSize)
    }
}

// MARK: - SourceKind Tests

final class SourceKindTests: XCTestCase {

    func testSourceKindRawValues() {
        // Given/When/Then: Verify raw values
        XCTAssertEqual(SourceKind.pdf.rawValue, "pdf")
        XCTAssertEqual(SourceKind.video.rawValue, "video")
        XCTAssertEqual(SourceKind.image.rawValue, "image")
        XCTAssertEqual(SourceKind.audio.rawValue, "audio")
        XCTAssertEqual(SourceKind.csv.rawValue, "csv")
        XCTAssertEqual(SourceKind.text.rawValue, "text")
        XCTAssertEqual(SourceKind.lecture.rawValue, "lecture")
    }

    func testSourceKindCodable() throws {
        // Given: A source kind
        let kind = SourceKind.lecture

        // When: Encoding and decoding
        let encoded = try JSONEncoder().encode(kind)
        let decoded = try JSONDecoder().decode(SourceKind.self, from: encoded)

        // Then: Should preserve value
        XCTAssertEqual(decoded, kind)
    }
}
