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

/// Text extraction from images using Apple's Vision framework
@MainActor
final class VisionTextExtractor: ObservableObject {
    private let logger = Logger(subsystem: "com.cardgenie.app", category: "Vision")

    @Published var extractedText = ""
    @Published var isProcessing = false
    @Published var error: VisionError?

    /// Extract text from an image using Vision framework
    /// - Parameter image: The UIImage to extract text from
    /// - Returns: Extracted text as a single string
    /// - Throws: VisionError if extraction fails
    func extractText(from image: UIImage) async throws -> String {
        isProcessing = true
        error = nil
        defer { isProcessing = false }

        guard let cgImage = image.cgImage else {
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

                // Extract top candidate from each observation
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                if recognizedText.isEmpty {
                    self.logger.warning("Recognized text is empty")
                    let visionError = VisionError.noTextFound
                    self.error = visionError
                    continuation.resume(throwing: visionError)
                    return
                }

                self.logger.info("Extracted \(recognizedText.count) characters from image")
                self.extractedText = recognizedText
                continuation.resume(returning: recognizedText)
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
