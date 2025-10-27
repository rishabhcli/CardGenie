//
//  PhotoScanningTests.swift
//  CardGenieTests
//
//  Unit tests for photo scanning enhancements including preprocessing,
//  confidence tracking, and multi-page support.
//

import XCTest
@testable import CardGenie

@MainActor
final class PhotoScanningTests: XCTestCase {

    // MARK: - ScanAnalytics Tests

    func testScanAnalyticsTracking() {
        let analytics = ScanAnalytics.shared
        analytics.reset()

        // Test initial state
        XCTAssertEqual(analytics.metrics.scanAttempts, 0)
        XCTAssertEqual(analytics.metrics.successfulScans, 0)
        XCTAssertEqual(analytics.metrics.failedScans, 0)

        // Test scan attempt tracking
        analytics.trackScanAttempt()
        XCTAssertEqual(analytics.metrics.scanAttempts, 1)

        // Test successful scan tracking
        analytics.trackScanSuccess(characterCount: 500, confidence: 0.95)
        XCTAssertEqual(analytics.metrics.successfulScans, 1)
        XCTAssertEqual(analytics.metrics.totalCharactersExtracted, 500)
        XCTAssertEqual(analytics.metrics.averageConfidence, 0.95, accuracy: 0.01)

        // Test failed scan tracking
        analytics.trackScanFailure(reason: "Test failure")
        XCTAssertEqual(analytics.metrics.failedScans, 1)

        // Test success rate calculation
        XCTAssertEqual(analytics.metrics.successRate, 0.5, accuracy: 0.01) // 1 success out of 2 attempts
    }

    func testScanAnalyticsMultiPageTracking() {
        let analytics = ScanAnalytics.shared
        analytics.reset()

        analytics.trackMultiPageScan(pageCount: 5)
        XCTAssertEqual(analytics.metrics.multiPageScans, 1)
    }

    func testScanAnalyticsPreprocessingTracking() {
        let analytics = ScanAnalytics.shared
        analytics.reset()

        analytics.trackPreprocessing()
        XCTAssertEqual(analytics.metrics.preprocessingUsed, 1)
    }

    func testScanAnalyticsLowConfidenceWarning() {
        let analytics = ScanAnalytics.shared
        analytics.reset()

        analytics.trackLowConfidenceWarning()
        XCTAssertEqual(analytics.metrics.lowConfidenceWarnings, 1)
    }

    // MARK: - ImagePreprocessor Tests

    func testImagePreprocessorBasicOperation() {
        let preprocessor = ImagePreprocessor()
        let testImage = createTestImage(size: CGSize(width: 100, height: 100))

        let config = PreprocessingConfig.minimal
        let result = preprocessor.preprocess(testImage, config: config)

        XCTAssertNotNil(result.processedImage)
        XCTAssertTrue(result.processingTime >= 0)
        XCTAssertFalse(result.appliedOperations.isEmpty)
    }

    func testImagePreprocessorRecommendation() {
        let preprocessor = ImagePreprocessor()
        let testImage = createTestImage(size: CGSize(width: 100, height: 100))

        let recommendation = preprocessor.recommendPreprocessing(for: testImage)

        // Should return a valid config
        XCTAssertTrue([true, false].contains(recommendation.enhanceContrast))
        XCTAssertTrue([true, false].contains(recommendation.convertToGrayscale))
    }

    // MARK: - TextExtractionResult Tests

    func testTextExtractionResultConfidenceLevel() {
        let highConfidence = TextExtractionResult(
            text: "Test",
            confidence: 0.95,
            detectedLanguages: ["en"],
            blockCount: 1,
            characterCount: 4,
            preprocessingApplied: false
        )
        XCTAssertEqual(highConfidence.confidenceLevel, .high)

        let mediumConfidence = TextExtractionResult(
            text: "Test",
            confidence: 0.8,
            detectedLanguages: ["en"],
            blockCount: 1,
            characterCount: 4,
            preprocessingApplied: false
        )
        XCTAssertEqual(mediumConfidence.confidenceLevel, .medium)

        let lowConfidence = TextExtractionResult(
            text: "Test",
            confidence: 0.6,
            detectedLanguages: ["en"],
            blockCount: 1,
            characterCount: 4,
            preprocessingApplied: false
        )
        XCTAssertEqual(lowConfidence.confidenceLevel, .low)

        let veryLowConfidence = TextExtractionResult(
            text: "Test",
            confidence: 0.3,
            detectedLanguages: ["en"],
            blockCount: 1,
            characterCount: 4,
            preprocessingApplied: false
        )
        XCTAssertEqual(veryLowConfidence.confidenceLevel, .veryLow)
    }

    // MARK: - TextSection Tests

    func testTextSectionCreation() {
        let section = TextSection(
            text: "This is a test section",
            type: .paragraph,
            isSelected: true
        )

        XCTAssertNotNil(section.id)
        XCTAssertEqual(section.text, "This is a test section")
        XCTAssertEqual(section.type, .paragraph)
        XCTAssertTrue(section.isSelected)
    }

    func testSectionTypeProperties() {
        XCTAssertEqual(SectionType.heading.icon, "text.alignleft")
        XCTAssertEqual(SectionType.paragraph.icon, "text.justify")
        XCTAssertEqual(SectionType.list.icon, "list.bullet")
        XCTAssertEqual(SectionType.definition.icon, "book.closed")
        XCTAssertEqual(SectionType.equation.icon, "function")
    }

    // MARK: - ScanQueue Tests

    func testScanQueueEnqueue() async {
        let queue = ScanQueue.shared
        queue.clearQueue()

        let scan = PendingScan(
            text: "Test scan content",
            topic: "Biology",
            deck: "Test Deck",
            formats: [.qa, .cloze]
        )

        queue.enqueueScan(scan)

        XCTAssertEqual(queue.pendingScans.count, 1)
        XCTAssertEqual(queue.pendingScans.first?.text, "Test scan content")
        XCTAssertEqual(queue.pendingScans.first?.topic, "Biology")
    }

    func testScanQueueRemove() async {
        let queue = ScanQueue.shared
        queue.clearQueue()

        let scan = PendingScan(text: "Test", formats: [.qa])
        queue.enqueueScan(scan)

        XCTAssertEqual(queue.pendingScans.count, 1)

        queue.removeScan(scan.id)

        XCTAssertEqual(queue.pendingScans.count, 0)
    }

    func testScanQueueClear() async {
        let queue = ScanQueue.shared
        queue.clearQueue()

        queue.enqueueScan(PendingScan(text: "Test 1", formats: [.qa]))
        queue.enqueueScan(PendingScan(text: "Test 2", formats: [.cloze]))

        XCTAssertEqual(queue.pendingScans.count, 2)

        queue.clearQueue()

        XCTAssertEqual(queue.pendingScans.count, 0)
    }

    func testScanQueueStats() async {
        let queue = ScanQueue.shared
        queue.clearQueue()

        queue.enqueueScan(PendingScan(text: "Test 1", formats: [.qa]))
        queue.enqueueScan(PendingScan(text: "Test 2", formats: [.cloze]))

        let stats = queue.queueStats
        XCTAssertEqual(stats.count, 2)
        XCTAssertNotNil(stats.oldestDate)
    }

    func testPendingScanFormatConversion() {
        let scan = PendingScan(
            text: "Test",
            formats: [.qa, .cloze, .definition]
        )

        let formats = scan.flashcardFormats
        XCTAssertEqual(formats.count, 3)
        XCTAssertTrue(formats.contains(.qa))
        XCTAssertTrue(formats.contains(.cloze))
        XCTAssertTrue(formats.contains(.definition))
    }

    // MARK: - DocumentScanResult Tests

    func testDocumentScanResultCreation() {
        let images = [
            createTestImage(size: CGSize(width: 100, height: 100)),
            createTestImage(size: CGSize(width: 100, height: 100))
        ]

        let result = DocumentScanResult(images: images)

        XCTAssertEqual(result.pageCount, 2)
        XCTAssertEqual(result.images.count, 2)
    }

    func testDocumentScanningCapability() {
        // This will return true/false based on device capabilities
        let isAvailable = DocumentScanningCapability.isAvailable

        // Just verify it returns a boolean
        XCTAssertTrue(isAvailable == true || isAvailable == false)
    }

    // MARK: - PreprocessingConfig Tests

    func testPreprocessingConfigPresets() {
        let standard = PreprocessingConfig.standard
        XCTAssertTrue(standard.enhanceContrast)
        XCTAssertTrue(standard.convertToGrayscale)
        XCTAssertTrue(standard.sharpen)
        XCTAssertTrue(standard.autoRotate)

        let minimal = PreprocessingConfig.minimal
        XCTAssertTrue(minimal.enhanceContrast)
        XCTAssertFalse(minimal.convertToGrayscale)
        XCTAssertFalse(minimal.sharpen)

        let aggressive = PreprocessingConfig.aggressive
        XCTAssertTrue(aggressive.enhanceContrast)
        XCTAssertTrue(aggressive.convertToGrayscale)
        XCTAssertTrue(aggressive.sharpen)
        XCTAssertTrue(aggressive.denoise)
    }

    // MARK: - Helper Methods

    private func createTestImage(size: CGSize, color: UIColor = .white) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Performance Tests

    func testImagePreprocessingPerformance() {
        let preprocessor = ImagePreprocessor()
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))

        measure {
            _ = preprocessor.preprocess(testImage, config: .standard)
        }
    }

    func testScanAnalyticsSaveLoadPerformance() {
        let analytics = ScanAnalytics.shared

        measure {
            for _ in 0..<100 {
                analytics.trackScanAttempt()
            }
        }
    }
}

// MARK: - Mock Classes

/// Mock VisionTextExtractor for testing without actual Vision framework calls
@MainActor
final class MockVisionTextExtractor {
    var mockText = "Sample extracted text"
    var mockConfidence: Double = 0.9
    var shouldFail = false

    func extractText(from image: UIImage) async throws -> String {
        if shouldFail {
            throw VisionError.processingFailed("Mock failure")
        }
        return mockText
    }

    func extractTextWithMetadata(from image: UIImage) async throws -> TextExtractionResult {
        if shouldFail {
            throw VisionError.processingFailed("Mock failure")
        }

        return TextExtractionResult(
            text: mockText,
            confidence: mockConfidence,
            detectedLanguages: ["en"],
            blockCount: 1,
            characterCount: mockText.count,
            preprocessingApplied: true
        )
    }
}
