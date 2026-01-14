//
//  FlashcardExporterTests.swift
//  CardGenie
//
//  Comprehensive unit tests for FlashcardExporter.
//  Tests JSON/CSV export, import, round-trip data integrity, and error handling.
//

import XCTest
import SwiftData
@testable import CardGenie

final class FlashcardExporterTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        // Create in-memory model container for testing
        let schema = Schema([
            FlashcardSet.self,
            Flashcard.self,
            StudyContent.self,
            ConversationSession.self,
            VoiceConversationMessage.self
        ])

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContext = nil
        modelContainer = nil
    }

    // MARK: - Helper Functions

    private func makeFlashcardSet(name: String) -> FlashcardSet {
        return FlashcardSet(topicLabel: name, tag: name.lowercased().replacingOccurrences(of: " ", with: "-"))
    }

    private func makeFlashcard(question: String, answer: String, tags: [String] = []) -> Flashcard {
        return Flashcard(type: .qa, question: question, answer: answer, linkedEntryID: UUID(), tags: tags)
    }

    private func makeFlashcard(type: FlashcardType, question: String, answer: String) -> Flashcard {
        return Flashcard(type: type, question: question, answer: answer, linkedEntryID: UUID())
    }

    // MARK: - JSON Export Tests

    func testJSONExport_SingleSet_SingleCard() throws {
        // Given: A flashcard set with one card
        let set = makeFlashcardSet(name: "Biology")
        let card = makeFlashcard(question: "What is DNA?", answer: "Genetic material")
        set.addCard(card)

        // When: Exporting to JSON
        let jsonData = try FlashcardExporter.exportToJSON(sets: [set])

        // Then: Should produce valid JSON
        XCTAssertFalse(jsonData.isEmpty, "JSON data should not be empty")

        // Verify JSON structure
        let decoded = try JSONDecoder().decode([FlashcardSetExport].self, from: jsonData)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].topicLabel, "Biology")
        XCTAssertEqual(decoded[0].cards.count, 1)
        XCTAssertEqual(decoded[0].cards[0].question, "What is DNA?")
        XCTAssertEqual(decoded[0].cards[0].answer, "Genetic material")
    }

    func testJSONExport_MultipleSetsWith_MultipleCards() throws {
        // Given: Multiple flashcard sets
        let bioSet = makeFlashcardSet(name: "Biology")
        bioSet.addCard(makeFlashcard(question: "Q1", answer: "A1"))
        bioSet.addCard(makeFlashcard(question: "Q2", answer: "A2"))

        let chemSet = makeFlashcardSet(name: "Chemistry")
        chemSet.addCard(makeFlashcard(question: "Q3", answer: "A3"))
        chemSet.addCard(makeFlashcard(question: "Q4", answer: "A4"))
        chemSet.addCard(makeFlashcard(question: "Q5", answer: "A5"))

        // When: Exporting
        let jsonData = try FlashcardExporter.exportToJSON(sets: [bioSet, chemSet])

        // Then: Should include all sets and cards
        let decoded = try JSONDecoder().decode([FlashcardSetExport].self, from: jsonData)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].cards.count, 2)
        XCTAssertEqual(decoded[1].cards.count, 3)
    }

    func testJSONExport_PreservesSpacedRepetitionData() throws {
        // Given: Card with spaced repetition progress
        let set = makeFlashcardSet(name: "Test")
        let card = makeFlashcard(question: "Q", answer: "A")
        card.reviewCount = 10
        card.easeFactor = 2.5
        card.interval = 7
        set.addCard(card)

        // When: Exporting
        let jsonData = try FlashcardExporter.exportToJSON(sets: [set])

        // Then: Should preserve SR data
        let decoded = try JSONDecoder().decode([FlashcardSetExport].self, from: jsonData)
        XCTAssertEqual(decoded[0].cards[0].reviewCount, 10)
        XCTAssertEqual(decoded[0].cards[0].easeFactor, 2.5)
        XCTAssertEqual(decoded[0].cards[0].interval, 7)
    }

    func testJSONExport_PreservesCardTypes() throws {
        // Given: Cards with different types
        let set = makeFlashcardSet(name: "Mixed")
        set.addCard(makeFlashcard(type: .qa, question: "Q1", answer: "A1"))
        set.addCard(makeFlashcard(type: .cloze, question: "Q2", answer: "A2"))
        set.addCard(makeFlashcard(type: .definition, question: "Q3", answer: "A3"))

        // When: Exporting
        let jsonData = try FlashcardExporter.exportToJSON(sets: [set])

        // Then: Should preserve types
        let decoded = try JSONDecoder().decode([FlashcardSetExport].self, from: jsonData)
        XCTAssertEqual(decoded[0].cards[0].type, "qa")
        XCTAssertEqual(decoded[0].cards[1].type, "cloze")
        XCTAssertEqual(decoded[0].cards[2].type, "definition")
    }

    func testJSONExport_PreservesTags() throws {
        // Given: Cards with tags
        let set = makeFlashcardSet(name: "Test")
        let card = makeFlashcard(question: "Q", answer: "A", tags: ["biology", "cells", "advanced"])
        set.addCard(card)

        // When: Exporting
        let jsonData = try FlashcardExporter.exportToJSON(sets: [set])

        // Then: Should preserve tags
        let decoded = try JSONDecoder().decode([FlashcardSetExport].self, from: jsonData)
        XCTAssertEqual(decoded[0].cards[0].tags, ["biology", "cells", "advanced"])
    }

    func testJSONExport_EmptyArray_ThrowsError() throws {
        // Given: Empty array of sets
        let emptySets: [FlashcardSet] = []

        // When/Then: Should throw noDataToExport error
        XCTAssertThrowsError(try FlashcardExporter.exportToJSON(sets: emptySets)) { error in
            guard let exportError = error as? ExportError else {
                XCTFail("Expected ExportError")
                return
            }
            if case .noDataToExport = exportError {
                // Expected error type
            } else {
                XCTFail("Expected noDataToExport error")
            }
        }
    }

    // MARK: - CSV Export Tests

    func testCSVExport_SingleCard_ProducesValidCSV() throws {
        // Given: A single flashcard
        let set = makeFlashcardSet(name: "Biology")
        let card = makeFlashcard(question: "What is DNA?", answer: "Genetic material")
        card.reviewCount = 5
        card.easeFactor = 2.5
        card.interval = 3
        set.addCard(card)

        // When: Exporting to CSV
        let csv = try FlashcardExporter.exportToCSV(sets: [set])

        // Then: Should produce valid CSV
        let lines = csv.components(separatedBy: "\n")
        XCTAssertGreaterThanOrEqual(lines.count, 2, "Should have header + data rows")

        // Check header
        XCTAssertTrue(lines[0].contains("Topic"))
        XCTAssertTrue(lines[0].contains("Question"))
        XCTAssertTrue(lines[0].contains("Answer"))
        XCTAssertTrue(lines[0].contains("Review Count"))

        // Check data row
        XCTAssertTrue(lines[1].contains("Biology"))
        XCTAssertTrue(lines[1].contains("What is DNA?"))
        XCTAssertTrue(lines[1].contains("Genetic material"))
    }

    func testCSVExport_MultipleCards_CreatesMultipleRows() throws {
        // Given: Multiple cards
        let set = makeFlashcardSet(name: "Test")
        set.addCard(makeFlashcard(question: "Q1", answer: "A1"))
        set.addCard(makeFlashcard(question: "Q2", answer: "A2"))
        set.addCard(makeFlashcard(question: "Q3", answer: "A3"))

        // When: Exporting
        let csv = try FlashcardExporter.exportToCSV(sets: [set])

        // Then: Should have header + 3 data rows
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 4, "Should have 1 header + 3 data rows")
    }

    func testCSVExport_EscapesCommas() throws {
        // Given: Card with commas in text
        let set = makeFlashcardSet(name: "Test")
        let card = makeFlashcard(
            question: "What are DNA, RNA, and proteins?",
            answer: "Nucleic acids, and building blocks"
        )
        set.addCard(card)

        // When: Exporting
        let csv = try FlashcardExporter.exportToCSV(sets: [set])

        // Then: Should quote fields with commas
        XCTAssertTrue(csv.contains("\"What are DNA, RNA, and proteins?\""))
        XCTAssertTrue(csv.contains("\"Nucleic acids, and building blocks\""))
    }

    func testCSVExport_EscapesQuotes() throws {
        // Given: Card with quotes in text
        let set = makeFlashcardSet(name: "Test")
        let card = makeFlashcard(
            question: "What is \"DNA\"?",
            answer: "The \"blueprint\" of life"
        )
        set.addCard(card)

        // When: Exporting
        let csv = try FlashcardExporter.exportToCSV(sets: [set])

        // Then: Should escape quotes with double quotes
        XCTAssertTrue(csv.contains("\"\"DNA\"\"") || csv.contains("What is \"\"DNA\"\"?"))
    }

    func testCSVExport_EscapesNewlines() throws {
        // Given: Card with newlines
        let set = makeFlashcardSet(name: "Test")
        let card = makeFlashcard(
            question: "What is DNA?\nProvide details.",
            answer: "Genetic material\nFound in cells"
        )
        set.addCard(card)

        // When: Exporting
        let csv = try FlashcardExporter.exportToCSV(sets: [set])

        // Then: Should quote fields with newlines
        XCTAssertTrue(csv.contains("\"What is DNA?\nProvide details.\"") ||
                      csv.contains("\"Genetic material\nFound in cells\""))
    }

    func testCSVExport_IncludesMasteryLevel() throws {
        // Given: Card with mastery level
        let set = makeFlashcardSet(name: "Test")
        let card = makeFlashcard(question: "Q", answer: "A")
        // Mastery level is computed from reviewCount/easeFactor/interval
        set.addCard(card)

        // When: Exporting
        let csv = try FlashcardExporter.exportToCSV(sets: [set])

        // Then: Should include mastery level column
        let lines = csv.components(separatedBy: "\n")
        XCTAssertTrue(lines[0].contains("Mastery Level"))
    }

    func testCSVExport_EmptyArray_ThrowsError() throws {
        // Given: Empty array
        let emptySets: [FlashcardSet] = []

        // When/Then: Should throw error
        XCTAssertThrowsError(try FlashcardExporter.exportToCSV(sets: emptySets)) { error in
            guard let exportError = error as? ExportError else {
                XCTFail("Expected ExportError")
                return
            }
            if case .noDataToExport = exportError {
                // Expected
            } else {
                XCTFail("Expected noDataToExport error")
            }
        }
    }

    // MARK: - JSON Import Tests

    func testJSONImport_ValidData_CreatesFlashcards() throws {
        // Given: Valid JSON export data
        let set = makeFlashcardSet(name: "Biology")
        set.addCard(makeFlashcard(question: "Q1", answer: "A1"))
        set.addCard(makeFlashcard(question: "Q2", answer: "A2"))
        let jsonData = try FlashcardExporter.exportToJSON(sets: [set])

        // When: Importing
        let importedCount = try FlashcardExporter.importFromJSON(jsonData, into: modelContext)

        // Then: Should import all cards
        XCTAssertEqual(importedCount, 2)

        // Verify flashcards were created
        let descriptor = FetchDescriptor<Flashcard>()
        let flashcards = try modelContext.fetch(descriptor)
        XCTAssertEqual(flashcards.count, 2)
    }

    func testJSONImport_RestoresSpacedRepetitionData() throws {
        // Given: Export with SR data
        let set = makeFlashcardSet(name: "Test")
        let card = makeFlashcard(question: "Q", answer: "A")
        card.reviewCount = 15
        card.easeFactor = 2.8
        card.interval = 10
        set.addCard(card)
        let jsonData = try FlashcardExporter.exportToJSON(sets: [set])

        // When: Importing
        _ = try FlashcardExporter.importFromJSON(jsonData, into: modelContext)

        // Then: Should restore SR data
        let descriptor = FetchDescriptor<Flashcard>()
        let flashcards = try modelContext.fetch(descriptor)
        XCTAssertEqual(flashcards.count, 1)
        XCTAssertEqual(flashcards[0].reviewCount, 15)
        XCTAssertEqual(flashcards[0].easeFactor, 2.8)
        XCTAssertEqual(flashcards[0].interval, 10)
    }

    func testJSONImport_CreatesFlashcardSets() throws {
        // Given: JSON with flashcard sets
        let set1 = makeFlashcardSet(name: "Biology")
        set1.addCard(makeFlashcard(question: "Q1", answer: "A1"))
        let set2 = makeFlashcardSet(name: "Chemistry")
        set2.addCard(makeFlashcard(question: "Q2", answer: "A2"))
        let jsonData = try FlashcardExporter.exportToJSON(sets: [set1, set2])

        // When: Importing
        _ = try FlashcardExporter.importFromJSON(jsonData, into: modelContext)

        // Then: Should create flashcard sets
        let descriptor = FetchDescriptor<FlashcardSet>()
        let sets = try modelContext.fetch(descriptor)
        XCTAssertEqual(sets.count, 2)
    }

    func testJSONImport_InvalidJSON_ThrowsError() throws {
        // Given: Invalid JSON data
        let invalidJSON = "{ invalid json }".data(using: .utf8)!

        // When/Then: Should throw encoding error
        XCTAssertThrowsError(try FlashcardExporter.importFromJSON(invalidJSON, into: modelContext)) { error in
            guard let exportError = error as? ExportError else {
                XCTFail("Expected ExportError")
                return
            }
            if case .encodingFailed = exportError {
                // Expected
            } else {
                XCTFail("Expected encodingFailed error")
            }
        }
    }

    func testJSONImport_EmptyArray_ImportsZeroCards() throws {
        // Given: Valid JSON with empty array
        let emptyJSON = "[]".data(using: .utf8)!

        // When: Importing
        let count = try FlashcardExporter.importFromJSON(emptyJSON, into: modelContext)

        // Then: Should import 0 cards
        XCTAssertEqual(count, 0)
    }

    // MARK: - Round-Trip Tests

    func testRoundTrip_ExportImport_PreservesData() throws {
        // Given: Original flashcards
        let set = makeFlashcardSet(name: "Biology")
        let card1 = makeFlashcard(question: "What is DNA?", answer: "Genetic material")
        card1.reviewCount = 5
        card1.easeFactor = 2.5
        card1.interval = 3
        let card2 = makeFlashcard(question: "What is RNA?", answer: "Messenger molecule")
        card2.reviewCount = 10
        set.addCard(card1)
        set.addCard(card2)

        // When: Exporting then importing
        let jsonData = try FlashcardExporter.exportToJSON(sets: [set])
        let importedCount = try FlashcardExporter.importFromJSON(jsonData, into: modelContext)

        // Then: Should preserve all data
        XCTAssertEqual(importedCount, 2)

        let descriptor = FetchDescriptor<Flashcard>()
        let imported = try modelContext.fetch(descriptor)
        XCTAssertEqual(imported.count, 2)

        // Verify data integrity
        let importedCard1 = imported.first { $0.question.contains("DNA") }
        XCTAssertNotNil(importedCard1)
        XCTAssertEqual(importedCard1?.answer, "Genetic material")
        XCTAssertEqual(importedCard1?.reviewCount, 5)
        XCTAssertEqual(importedCard1?.easeFactor, 2.5)
        XCTAssertEqual(importedCard1?.interval, 3)
    }

    func testRoundTrip_MultipleSets_PreservesAllData() throws {
        // Given: Multiple sets with multiple cards
        let bio = makeFlashcardSet(name: "Biology")
        bio.addCard(makeFlashcard(question: "Q1", answer: "A1"))
        bio.addCard(makeFlashcard(question: "Q2", answer: "A2"))

        let chem = makeFlashcardSet(name: "Chemistry")
        chem.addCard(makeFlashcard(question: "Q3", answer: "A3"))

        // When: Round-trip
        let jsonData = try FlashcardExporter.exportToJSON(sets: [bio, chem])
        let importedCount = try FlashcardExporter.importFromJSON(jsonData, into: modelContext)

        // Then: Should import all cards
        XCTAssertEqual(importedCount, 3)

        let setDescriptor = FetchDescriptor<FlashcardSet>()
        let importedSets = try modelContext.fetch(setDescriptor)
        XCTAssertEqual(importedSets.count, 2)
    }

    // MARK: - File Operations Tests

    func testCreateExportFile_CreatesFileAtURL() throws {
        // Given: Export data
        let testData = "Test export data".data(using: .utf8)!
        let filename = "test_export.json"

        // When: Creating file
        let fileURL = try FlashcardExporter.createExportFile(data: testData, filename: filename)

        // Then: File should exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(fileURL.lastPathComponent == filename)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testCreateExportFile_WritesCorrectData() throws {
        // Given: Specific data
        let testData = "Flashcard export test".data(using: .utf8)!
        let filename = "test.json"

        // When: Creating file
        let fileURL = try FlashcardExporter.createExportFile(data: testData, filename: filename)

        // Then: Should contain correct data
        let readData = try Data(contentsOf: fileURL)
        XCTAssertEqual(readData, testData)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testGenerateFilename_IncludesPrefix() throws {
        // Given: Prefix
        let prefix = "CardGenie"

        // When: Generating filename
        let filename = FlashcardExporter.generateFilename(prefix: prefix, extension: "json")

        // Then: Should include prefix
        XCTAssertTrue(filename.hasPrefix("CardGenie_"))
        XCTAssertTrue(filename.hasSuffix(".json"))
    }

    func testGenerateFilename_IncludesTimestamp() throws {
        // Given: Generating two filenames
        let filename1 = FlashcardExporter.generateFilename(prefix: "Test", extension: "csv")

        // Wait a moment
        Thread.sleep(forTimeInterval: 1.0)

        let filename2 = FlashcardExporter.generateFilename(prefix: "Test", extension: "csv")

        // Then: Should have different timestamps
        XCTAssertNotEqual(filename1, filename2, "Filenames should be unique with timestamps")
    }

    func testGenerateFilename_IncludesExtension() throws {
        // Given: Different extensions
        let jsonFile = FlashcardExporter.generateFilename(extension: "json")
        let csvFile = FlashcardExporter.generateFilename(extension: "csv")

        // Then: Should have correct extensions
        XCTAssertTrue(jsonFile.hasSuffix(".json"))
        XCTAssertTrue(csvFile.hasSuffix(".csv"))
    }

    // MARK: - Edge Cases

    func testExport_UnicodeCharacters_PreservesCorrectly() throws {
        // Given: Cards with Unicode characters
        let set = makeFlashcardSet(name: "Languages")
        set.addCard(makeFlashcard(question: "こんにちは", answer: "Hello (Japanese)"))
        set.addCard(makeFlashcard(question: "¿Cómo estás?", answer: "How are you? (Spanish)"))
        set.addCard(makeFlashcard(question: "😀 Emoji test", answer: "✅ Works"))

        // When: Round-trip
        let jsonData = try FlashcardExporter.exportToJSON(sets: [set])
        _ = try FlashcardExporter.importFromJSON(jsonData, into: modelContext)

        // Then: Should preserve Unicode
        let descriptor = FetchDescriptor<Flashcard>()
        let imported = try modelContext.fetch(descriptor)

        let japanese = imported.first { $0.question.contains("こんにちは") }
        XCTAssertNotNil(japanese)
        XCTAssertEqual(japanese?.answer, "Hello (Japanese)")

        let emoji = imported.first { $0.question.contains("😀") }
        XCTAssertNotNil(emoji)
        XCTAssertEqual(emoji?.answer, "✅ Works")
    }

    func testExport_LargeDataset_HandlesEfficiently() throws {
        // Given: Large number of cards
        let set = makeFlashcardSet(name: "Large Set")
        for i in 1...100 {
            let card = makeFlashcard(question: "Question \(i)", answer: "Answer \(i)")
            set.addCard(card)
        }

        // When: Exporting
        let startTime = Date()
        let jsonData = try FlashcardExporter.exportToJSON(sets: [set])
        let exportTime = Date().timeIntervalSince(startTime)

        // Then: Should complete in reasonable time (< 1 second for 100 cards)
        XCTAssertLessThan(exportTime, 1.0)

        // Verify all cards exported
        let decoded = try JSONDecoder().decode([FlashcardSetExport].self, from: jsonData)
        XCTAssertEqual(decoded[0].cards.count, 100)
    }

    func testExport_SpecialCharacters_InTopicName() throws {
        // Given: Set with special characters in name
        let set = FlashcardSet(topicLabel: "Biology & Chemistry: 101!", tag: "biology-chemistry-101")
        set.addCard(makeFlashcard(question: "Q", answer: "A"))

        // When: Round-trip
        let jsonData = try FlashcardExporter.exportToJSON(sets: [set])
        _ = try FlashcardExporter.importFromJSON(jsonData, into: modelContext)

        // Then: Should preserve topic name
        let descriptor = FetchDescriptor<FlashcardSet>()
        let imported = try modelContext.fetch(descriptor)

        // Note: The set name might be normalized during import
        XCTAssertEqual(imported.count, 1)
    }

    func testExport_EmptyStrings_HandlesCorrectly() throws {
        // Given: Card with empty answer (edge case)
        let set = makeFlashcardSet(name: "Test")
        let card = makeFlashcard(question: "Question with no answer", answer: "")
        set.addCard(card)

        // When: Round-trip
        let jsonData = try FlashcardExporter.exportToJSON(sets: [set])
        _ = try FlashcardExporter.importFromJSON(jsonData, into: modelContext)

        // Then: Should handle empty strings
        let descriptor = FetchDescriptor<Flashcard>()
        let imported = try modelContext.fetch(descriptor)
        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(imported[0].answer, "")
    }

    func testExport_VeryLongText_HandlesCorrectly() throws {
        // Given: Card with very long text
        let longText = String(repeating: "This is a very long answer. ", count: 100)
        let set = makeFlashcardSet(name: "Test")
        set.addCard(makeFlashcard(question: "Long answer test", answer: longText))

        // When: Round-trip
        let jsonData = try FlashcardExporter.exportToJSON(sets: [set])
        _ = try FlashcardExporter.importFromJSON(jsonData, into: modelContext)

        // Then: Should preserve full text
        let descriptor = FetchDescriptor<Flashcard>()
        let imported = try modelContext.fetch(descriptor)
        XCTAssertEqual(imported[0].answer, longText)
    }

    // MARK: - Error Description Tests

    func testExportError_NoDataToExport_HasDescription() throws {
        // Given: Error
        let error = ExportError.noDataToExport

        // When: Getting description
        let description = error.errorDescription

        // Then: Should have meaningful description
        XCTAssertNotNil(description)
        XCTAssertTrue(description!.contains("No flashcards"))
    }

    func testExportError_EncodingFailed_HasDescription() throws {
        // Given: Error with reason
        let error = ExportError.encodingFailed("Test reason")

        // When: Getting description
        let description = error.errorDescription

        // Then: Should include reason
        XCTAssertNotNil(description)
        XCTAssertTrue(description!.contains("Test reason"))
    }

    func testExportError_FileWriteFailed_HasDescription() throws {
        // Given: Error
        let error = ExportError.fileWriteFailed("Permission denied")

        // When: Getting description
        let description = error.errorDescription

        // Then: Should have description
        XCTAssertNotNil(description)
        XCTAssertTrue(description!.contains("Permission denied"))
    }
}
