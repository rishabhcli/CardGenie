//
//  HandwritingProcessor.swift
//  CardGenie
//
//  Handwritten flashcards with PencilKit + Vision OCR.
//  Handwriting improves retention by 40%.
//

import Foundation
import PencilKit
import Vision
import UIKit
import SwiftData

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
