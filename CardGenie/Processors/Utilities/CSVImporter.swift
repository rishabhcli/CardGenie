//
//  CSVImporter.swift
//  CardGenie
//
//  Import flashcards from CSV files.
//

import Foundation
import SwiftData

// MARK: - CSV Importer

final class CSVImporter {
    private let llm: LLMEngine

    init(llm: LLMEngine = AIEngineFactory.createLLMEngine()) {
        self.llm = llm
    }

    // MARK: - Import CSV

    /// Import CSV file as flashcards
    /// Supports formats: "Question,Answer" or "Front,Back,Tags"
    func importCSV(from url: URL, context: ModelContext) async throws -> FlashcardSet {
        let content = try String(contentsOf: url, encoding: .utf8)
        let rows = parseCSV(content)

        guard !rows.isEmpty else {
            throw CSVError.emptyFile
        }

        // Detect format
        let header = rows.first ?? []
        let hasHeader = detectHeader(header)

        let dataRows = hasHeader ? Array(rows.dropFirst()) : rows

        // Create deck
        let fileName = url.deletingPathExtension().lastPathComponent
        let deck = FlashcardSet(topicLabel: fileName, tag: "imported")
        context.insert(deck)

        // Process each row
        for row in dataRows {
            guard row.count >= 2 else { continue }

            let question = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let answer = row[1].trimmingCharacters(in: .whitespacesAndNewlines)

            guard !question.isEmpty && !answer.isEmpty else { continue }

            // Extract tags if present
            var tags: [String] = []
            if row.count >= 3 {
                let tagString = row[2].trimmingCharacters(in: .whitespacesAndNewlines)
                tags = tagString.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }

            // Create flashcard
            let card = Flashcard(
                type: .qa,
                question: question,
                answer: answer,
                linkedEntryID: UUID(),
                tags: tags
            )

            deck.addCard(card)
            context.insert(card)
        }

        return deck
    }

    // MARK: - CSV Parsing

    private func parseCSV(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        for char in content {
            switch char {
            case "\"":
                if inQuotes && currentField.last == "\"" {
                    // Escaped quote
                    currentField.removeLast()
                    currentField.append("\"")
                } else {
                    inQuotes.toggle()
                }

            case ",":
                if inQuotes {
                    currentField.append(char)
                } else {
                    currentRow.append(currentField)
                    currentField = ""
                }

            case "\n", "\r":
                if inQuotes {
                    currentField.append(char)
                } else {
                    if !currentField.isEmpty || !currentRow.isEmpty {
                        currentRow.append(currentField)
                        rows.append(currentRow)
                        currentRow = []
                        currentField = ""
                    }
                }

            default:
                currentField.append(char)
            }
        }

        // Add final field/row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows.filter { !$0.isEmpty }
    }

    private func detectHeader(_ row: [String]) -> Bool {
        guard !row.isEmpty else { return false }

        let firstCell = row[0].lowercased()

        // Common header patterns
        let headerKeywords = [
            "question", "front", "term", "prompt",
            "answer", "back", "definition", "response"
        ]

        return headerKeywords.contains { firstCell.contains($0) }
    }

    // MARK: - Batch Card Generation from CSV

    /// Import CSV data (notes/facts) and generate flashcards using AI
    func importAndGenerate(from url: URL, context: ModelContext) async throws -> FlashcardSet {
        let content = try String(contentsOf: url, encoding: .utf8)
        let rows = parseCSV(content)

        guard !rows.isEmpty else {
            throw CSVError.emptyFile
        }

        let fileName = url.deletingPathExtension().lastPathComponent
        let deck = FlashcardSet(topicLabel: fileName, tag: "csv-generated")
        context.insert(deck)

        // Skip header if present
        let hasHeader = detectHeader(rows.first ?? [])
        let dataRows = hasHeader ? Array(rows.dropFirst()) : rows

        // Generate cards from each row
        for row in dataRows {
            let text = row.joined(separator: " - ")
            guard !text.isEmpty else { continue }

            // Generate Q&A card from text
            if let cards = try? await generateCardsFromText(text) {
                for card in cards {
                    deck.addCard(card)
                    context.insert(card)
                }
            }
        }

        return deck
    }

    private func generateCardsFromText(_ text: String) async throws -> [Flashcard] {
        let prompt = """
        Create 1 question-answer flashcard from this fact/note.

        TEXT: \(text)

        FORMAT:
        Q: [question]
        A: [answer]

        CARD:
        """

        let response = try await llm.complete(prompt, maxTokens: 150)

        // Parse response
        var question: String?
        var answer: String?

        for line in response.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("Q:") {
                question = trimmed.replacingOccurrences(of: "Q:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("A:"), let q = question {
                answer = trimmed.replacingOccurrences(of: "A:", with: "")
                    .trimmingCharacters(in: .whitespaces)

                let card = Flashcard(
                    type: .qa,
                    question: q,
                    answer: answer!,
                    linkedEntryID: UUID()
                )
                return [card]
            }
        }

        return []
    }
}

// MARK: - Errors

enum CSVError: LocalizedError {
    case emptyFile
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .emptyFile: return "CSV file is empty"
        case .invalidFormat: return "Invalid CSV format"
        }
    }
}
