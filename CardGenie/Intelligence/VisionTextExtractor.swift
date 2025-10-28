//
//  VisionTextExtractor.swift
//  CardGenie
//
//  Text extraction from images using Vision framework (iOS 16+).
//  Supports high-accuracy OCR for scanned notes, textbooks, and handwriting.
//

import Vision
import VisionKit
import UIKit
import OSLog
import Combine

/// Result of text extraction with metadata
struct TextExtractionResult {
    let text: String
    let confidence: Double
    let detectedLanguages: [String]
    let blockCount: Int
    let characterCount: Int
    let preprocessingApplied: Bool

    var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case 0.9...1.0: return .high
        case 0.7..<0.9: return .medium
        case 0.5..<0.7: return .low
        default: return .veryLow
        }
    }
}

enum ConfidenceLevel: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case veryLow = "Very Low"

    var color: String {
        switch self {
        case .high: return "green"
        case .medium: return "yellow"
        case .low: return "orange"
        case .veryLow: return "red"
        }
    }
}

/// Text extraction from images using Apple's Vision framework
@MainActor
final class VisionTextExtractor: ObservableObject {
    private let logger = Logger(subsystem: "com.cardgenie.app", category: "Vision")
    private let preprocessor = ImagePreprocessor()

    @Published var extractedText = ""
    @Published var isProcessing = false
    @Published var error: VisionError?
    @Published var lastExtractionResult: TextExtractionResult?

    /// Extract text from an image using Vision framework with preprocessing
    /// - Parameters:
    ///   - image: The UIImage to extract text from
    ///   - enablePreprocessing: Whether to apply image preprocessing
    /// - Returns: Extracted text as a single string
    /// - Throws: VisionError if extraction fails
    func extractText(from image: UIImage, enablePreprocessing: Bool = true) async throws -> String {
        let result = try await extractTextWithMetadata(from: image, enablePreprocessing: enablePreprocessing)
        return result.text
    }

    /// Extract text from an image with full metadata
    /// - Parameters:
    ///   - image: The UIImage to extract text from
    ///   - enablePreprocessing: Whether to apply image preprocessing
    /// - Returns: TextExtractionResult with confidence and language info
    /// - Throws: VisionError if extraction fails
    func extractTextWithMetadata(from image: UIImage, enablePreprocessing: Bool = true) async throws -> TextExtractionResult {
        isProcessing = true
        error = nil
        defer { isProcessing = false }

        // Preprocess image if enabled
        var processedImage = image
        var preprocessingApplied = false

        if enablePreprocessing {
            let config = preprocessor.recommendPreprocessing(for: image)
            let preprocessResult = preprocessor.preprocess(image, config: config)
            processedImage = preprocessResult.processedImage
            preprocessingApplied = !preprocessResult.appliedOperations.isEmpty

            if preprocessingApplied {
                logger.info("Applied preprocessing: \(preprocessResult.appliedOperations.joined(separator: ", "))")
                ScanAnalytics.shared.trackPreprocessing()
            }
        }

        guard let cgImage = processedImage.cgImage else {
            logger.error("Invalid image - no CGImage representation")
            let visionError = VisionError.invalidImage
            error = visionError
            throw visionError
        }

        logger.info("Starting text recognition...")

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    self.logger.error("Vision request failed: \(error.localizedDescription)")
                    let visionError = VisionError.processingFailed(error.localizedDescription)
                    self.error = visionError
                    continuation.resume(throwing: visionError)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    self.logger.warning("No text observations found")
                    let visionError = VisionError.noTextFound
                    self.error = visionError
                    continuation.resume(throwing: visionError)
                    return
                }

                if observations.isEmpty {
                    self.logger.warning("Text observations array is empty")
                    let visionError = VisionError.noTextFound
                    self.error = visionError
                    continuation.resume(throwing: visionError)
                    return
                }

                // Extract text and confidence from observations
                var allText: [String] = []
                var totalConfidence: Float = 0
                let detectedLanguages = Set<String>()

                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    allText.append(candidate.string)
                    totalConfidence += candidate.confidence

                    // Track detected languages if available
                    // Note: Language detection would require additional processing
                }

                let recognizedText = allText.joined(separator: "\n")

                if recognizedText.isEmpty {
                    self.logger.warning("Recognized text is empty")
                    let visionError = VisionError.noTextFound
                    self.error = visionError
                    continuation.resume(throwing: visionError)
                    return
                }

                let averageConfidence = Double(totalConfidence) / Double(observations.count)
                let result = TextExtractionResult(
                    text: recognizedText,
                    confidence: averageConfidence,
                    detectedLanguages: Array(detectedLanguages),
                    blockCount: observations.count,
                    characterCount: recognizedText.count,
                    preprocessingApplied: preprocessingApplied
                )

                self.logger.info("Extracted \(recognizedText.count) characters with confidence \(String(format: "%.2f", averageConfidence))")
                self.extractedText = recognizedText
                self.lastExtractionResult = result
                continuation.resume(returning: result)
            }

            // Configure for maximum accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            // Support multiple languages if needed
            request.recognitionLanguages = ["en-US"]

            // Automatic language detection
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                self.logger.error("Failed to perform Vision request: \(error.localizedDescription)")
                let visionError = VisionError.processingFailed(error.localizedDescription)
                self.error = visionError
                continuation.resume(throwing: visionError)
            }
        }
    }

    /// Check if VisionKit document scanning is available
    func isDocumentScanningAvailable() -> Bool {
        return VNDocumentCameraViewController.isSupported
    }
}

// MARK: - Vision Error Types

enum VisionError: LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed(String)
    case notSupported

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The image could not be processed. Please try a different image."
        case .noTextFound:
            return "No text was found in the image. Make sure the image contains readable text."
        case .processingFailed(let reason):
            return "Text extraction failed: \(reason)"
        case .notSupported:
            return "Document scanning is not supported on this device."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidImage:
            return "Try taking a new photo or choosing a different image."
        case .noTextFound:
            return "Ensure the image is clear, well-lit, and contains visible text."
        case .processingFailed:
            return "Please try again. If the problem persists, restart the app."
        case .notSupported:
            return "Photo scanning requires iOS 16 or later."
        }
    }
}
