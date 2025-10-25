//
//  FlashcardExporter.swift
//  CardGenie
//
//  Handles exporting and importing flashcard data.
//

import Foundation
import SwiftData

// MARK: - Export Models

struct FlashcardSetExport: Codable {
    let topicLabel: String
    let tag: String
    let createdDate: Date
    let cards: [FlashcardExport]
}

struct FlashcardExport: Codable {
    let type: String
    let question: String
    let answer: String
    let tags: [String]
    let createdAt: Date
    let reviewCount: Int
    let easeFactor: Double
    let interval: Int
}

// MARK: - Exporter

enum ExportError: LocalizedError {
    case noDataToExport
    case encodingFailed(String)
    case fileWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .noDataToExport:
            return "No flashcards to export"
        case .encodingFailed(let reason):
            return "Failed to encode data: \(reason)"
        case .fileWriteFailed(let reason):
            return "Failed to write file: \(reason)"
        }
    }
}

final class FlashcardExporter {

    // MARK: - Export to JSON

    /// Export all flashcard sets to JSON data
    static func exportToJSON(sets: [FlashcardSet]) throws -> Data {
        guard !sets.isEmpty else {
            throw ExportError.noDataToExport
        }

        let exportData = sets.map { set in
            FlashcardSetExport(
                topicLabel: set.topicLabel,
                tag: set.tag,
                createdDate: set.createdDate,
                cards: set.cards.map { card in
                    FlashcardExport(
                        type: card.type.rawValue,
                        question: card.question,
                        answer: card.answer,
                        tags: card.tags,
                        createdAt: card.createdAt,
                        reviewCount: card.reviewCount,
                        easeFactor: card.easeFactor,
                        interval: card.interval
                    )
                }
            )
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            return try encoder.encode(exportData)
        } catch {
            throw ExportError.encodingFailed(error.localizedDescription)
        }
    }

    /// Export to CSV format (simplified, progress only)
    static func exportToCSV(sets: [FlashcardSet]) throws -> String {
        guard !sets.isEmpty else {
            throw ExportError.noDataToExport
        }

        var csv = "Topic,Question,Answer,Review Count,Ease Factor,Interval (days),Mastery Level\n"

        for set in sets {
            for card in set.cards {
                let question = escapeCSV(card.question)
                let answer = escapeCSV(card.answer)
                let mastery = card.masteryLevel.rawValue

                csv += "\(escapeCSV(set.topicLabel)),\(question),\(answer),\(card.reviewCount),\(card.easeFactor),\(card.interval),\(mastery)\n"
            }
        }

        return csv
    }

    // MARK: - Import from JSON

    /// Import flashcard sets from JSON data
    static func importFromJSON(_ data: Data, into context: ModelContext) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let imported: [FlashcardSetExport]
        do {
            imported = try decoder.decode([FlashcardSetExport].self, from: data)
        } catch {
            throw ExportError.encodingFailed("Invalid JSON format: \(error.localizedDescription)")
        }

        var importedCount = 0

        for setData in imported {
            // Find or create set
            let flashcardSet = context.findOrCreateFlashcardSet(topicLabel: setData.topicLabel)

            for cardData in setData.cards {
                guard let cardType = FlashcardType(rawValue: cardData.type) else { continue }

                let flashcard = Flashcard(
                    type: cardType,
                    question: cardData.question,
                    answer: cardData.answer,
                    linkedEntryID: UUID(), // New ID for imports
                    tags: cardData.tags
                )

                // Restore progress if importing backup
                flashcard.reviewCount = cardData.reviewCount
                flashcard.easeFactor = cardData.easeFactor
                flashcard.interval = cardData.interval

                flashcardSet.addCard(flashcard)
                context.insert(flashcard)
                importedCount += 1
            }
        }

        try context.save()
        return importedCount
    }

    // MARK: - File Operations

    /// Create a shareable file URL for export
    static func createExportFile(data: Data, filename: String) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            throw ExportError.fileWriteFailed(error.localizedDescription)
        }
    }

    /// Generate filename with timestamp
    static func generateFilename(prefix: String = "CardGenie", extension ext: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        return "\(prefix)_\(timestamp).\(ext)"
    }

    // MARK: - Helper Methods

    private static func escapeCSV(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}
