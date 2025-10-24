//
//  StoreTests.swift
//  CardGenie
//
//  Unit tests for data persistence layer.
//

import XCTest
import SwiftData
@testable import CardGenie

@MainActor
final class StoreTests: XCTestCase {
    var container: ModelContainer!
    var store: Store!

    override func setUp() async throws {
        // Create an in-memory container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: JournalEntry.self, configurations: config)
        store = Store(container: container)
    }

    override func tearDown() async throws {
        container = nil
        store = nil
    }

    // MARK: - Creation Tests

    func testCreateNewEntry() async throws {
        // When: Creating a new entry
        let entry = store.newEntry()

        // Then: Entry should exist with defaults
        XCTAssertNotNil(entry.id, "Entry should have an ID")
        XCTAssertTrue(entry.text.isEmpty, "New entry should have empty text")
        XCTAssertNil(entry.summary, "New entry should have no summary")
        XCTAssertTrue(entry.tags.isEmpty, "New entry should have no tags")
        XCTAssertNotNil(entry.createdAt, "Entry should have creation date")
    }

    func testMultipleEntryCreation() async throws {
        // Given: Creating multiple entries
        let entry1 = store.newEntry()
        let entry2 = store.newEntry()
        let entry3 = store.newEntry()

        // Then: Each should have unique ID
        XCTAssertNotEqual(entry1.id, entry2.id)
        XCTAssertNotEqual(entry2.id, entry3.id)
        XCTAssertNotEqual(entry1.id, entry3.id)
    }

    // MARK: - Fetch Tests

    func testFetchAllEntries() async throws {
        // Given: Multiple entries
        _ = store.newEntry()
        _ = store.newEntry()
        _ = store.newEntry()

        // When: Fetching all entries
        let entries = store.fetchAllEntries()

        // Then: Should return all entries
        XCTAssertEqual(entries.count, 3, "Should fetch all 3 entries")
    }

    func testFetchEntriesSortedByDate() async throws {
        // Given: Entries created at different times
        let entry1 = store.newEntry()
        entry1.text = "First"
        entry1.createdAt = Date().addingTimeInterval(-3600) // 1 hour ago

        let entry2 = store.newEntry()
        entry2.text = "Second"
        entry2.createdAt = Date().addingTimeInterval(-1800) // 30 min ago

        let entry3 = store.newEntry()
        entry3.text = "Third"
        entry3.createdAt = Date() // Now

        store.save()

        // When: Fetching entries
        let entries = store.fetchAllEntries()

        // Then: Should be sorted newest first
        XCTAssertEqual(entries[0].text, "Third")
        XCTAssertEqual(entries[1].text, "Second")
        XCTAssertEqual(entries[2].text, "First")
    }

    func testFetchFromEmptyStore() async throws {
        // Given: Empty store
        // When: Fetching entries
        let entries = store.fetchAllEntries()

        // Then: Should return empty array
        XCTAssertTrue(entries.isEmpty, "Empty store should return no entries")
    }

    // MARK: - Update Tests

    func testUpdateEntryText() async throws {
        // Given: An entry
        let entry = store.newEntry()
        let originalId = entry.id

        // When: Updating text
        entry.text = "Updated content"
        store.save()

        // Then: Changes should persist
        let entries = store.fetchAllEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].id, originalId)
        XCTAssertEqual(entries[0].text, "Updated content")
    }

    func testUpdateEntrySummary() async throws {
        // Given: An entry with text
        let entry = store.newEntry()
        entry.text = "This is a long journal entry with lots of content."

        // When: Adding a summary
        entry.summary = "A summary of the entry"
        store.save()

        // Then: Summary should persist
        let entries = store.fetchAllEntries()
        XCTAssertEqual(entries[0].summary, "A summary of the entry")
    }

    func testUpdateEntryTags() async throws {
        // Given: An entry
        let entry = store.newEntry()

        // When: Adding tags
        entry.tags = ["work", "planning", "goals"]
        store.save()

        // Then: Tags should persist
        let entries = store.fetchAllEntries()
        XCTAssertEqual(entries[0].tags.count, 3)
        XCTAssertTrue(entries[0].tags.contains("work"))
        XCTAssertTrue(entries[0].tags.contains("planning"))
    }

    // MARK: - Delete Tests

    func testDeleteEntry() async throws {
        // Given: Multiple entries
        let entry1 = store.newEntry()
        let entry2 = store.newEntry()
        let entry3 = store.newEntry()

        // When: Deleting one entry
        store.delete(entry2)

        // Then: Should have 2 entries left
        let entries = store.fetchAllEntries()
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.contains(where: { $0.id == entry1.id }))
        XCTAssertFalse(entries.contains(where: { $0.id == entry2.id }))
        XCTAssertTrue(entries.contains(where: { $0.id == entry3.id }))
    }

    func testDeleteAllEntries() async throws {
        // Given: Multiple entries
        _ = store.newEntry()
        _ = store.newEntry()
        _ = store.newEntry()

        var entries = store.fetchAllEntries()
        XCTAssertEqual(entries.count, 3)

        // When: Deleting all
        for entry in entries {
            store.delete(entry)
        }

        // Then: Store should be empty
        entries = store.fetchAllEntries()
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - Search Tests

    func testSearchByText() async throws {
        // Given: Entries with different content
        let entry1 = store.newEntry()
        entry1.text = "Today I went to the gym and had a great workout."

        let entry2 = store.newEntry()
        entry2.text = "Worked on the project all day. Made good progress."

        let entry3 = store.newEntry()
        entry3.text = "Relaxing evening with a good book."

        store.save()

        // When: Searching for "gym"
        let results = store.search("gym")

        // Then: Should find matching entry
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, entry1.id)
    }

    func testSearchBySummary() async throws {
        // Given: Entry with summary
        let entry = store.newEntry()
        entry.text = "A long journal entry about my day."
        entry.summary = "Summary mentions workout and friends"
        store.save()

        // When: Searching for "workout"
        let results = store.search("workout")

        // Then: Should find entry by summary
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, entry.id)
    }

    func testSearchByTags() async throws {
        // Given: Entry with tags
        let entry = store.newEntry()
        entry.text = "Project planning session."
        entry.tags = ["work", "planning", "meeting"]
        store.save()

        // When: Searching for a tag
        let results = store.search("meeting")

        // Then: Should find entry by tag
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, entry.id)
    }

    func testSearchCaseInsensitive() async throws {
        // Given: Entry with mixed case text
        let entry = store.newEntry()
        entry.text = "Meeting with the Team about Project Alpha"
        store.save()

        // When: Searching with different cases
        let results1 = store.search("team")
        let results2 = store.search("TEAM")
        let results3 = store.search("Team")

        // Then: All should find the entry
        XCTAssertEqual(results1.count, 1)
        XCTAssertEqual(results2.count, 1)
        XCTAssertEqual(results3.count, 1)
    }

    func testSearchWithEmptyQuery() async throws {
        // Given: Multiple entries
        _ = store.newEntry()
        _ = store.newEntry()

        // When: Searching with empty string
        let results = store.search("")

        // Then: Should return all entries
        XCTAssertEqual(results.count, 2)
    }

    func testSearchNoResults() async throws {
        // Given: Entries
        let entry = store.newEntry()
        entry.text = "This is about coding"
        store.save()

        // When: Searching for non-existent term
        let results = store.search("unicorn")

        // Then: Should return empty
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Model Property Tests

    func testEntryFirstLine() async throws {
        // Given: Entry with multi-line text
        let entry = store.newEntry()
        entry.text = "First line of the entry\nSecond line\nThird line"

        // Then: firstLine should return first line
        XCTAssertEqual(entry.firstLine, "First line of the entry")
    }

    func testEntryFirstLineEmpty() async throws {
        // Given: Entry with empty text
        let entry = store.newEntry()
        entry.text = ""

        // Then: Should return default
        XCTAssertEqual(entry.firstLine, "New entry")
    }

    func testEntryPreviewWithSummary() async throws {
        // Given: Entry with summary
        let entry = store.newEntry()
        entry.text = "Long text here..."
        entry.summary = "This is the summary"

        // Then: Preview should use summary
        XCTAssertEqual(entry.preview, "This is the summary")
    }

    func testEntryPreviewWithoutSummary() async throws {
        // Given: Entry without summary
        let entry = store.newEntry()
        entry.text = "Short text"

        // Then: Preview should use text
        XCTAssertEqual(entry.preview, "Short text")
    }

    func testEntryPreviewTruncation() async throws {
        // Given: Entry with long text
        let entry = store.newEntry()
        entry.text = String(repeating: "A", count: 200)

        // Then: Preview should be truncated
        let preview = entry.preview
        XCTAssertTrue(preview.hasSuffix("…"))
        XCTAssertLessThanOrEqual(preview.count, 125) // 120 chars + "…"
    }

    // MARK: - Persistence Tests

    func testDataPersistsAfterSave() async throws {
        // Given: An entry with data
        let entry = store.newEntry()
        entry.text = "Important journal entry"
        entry.summary = "Summary of the entry"
        entry.tags = ["important", "personal"]
        store.save()

        // When: Creating a new store instance
        let newStore = Store(container: container)

        // Then: Data should still exist
        let entries = newStore.fetchAllEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].text, "Important journal entry")
        XCTAssertEqual(entries[0].summary, "Summary of the entry")
        XCTAssertEqual(entries[0].tags.count, 2)
    }

    // MARK: - Performance Tests

    func testFetchPerformance() async throws {
        // Given: Many entries
        for i in 1...100 {
            let entry = store.newEntry()
            entry.text = "Entry number \(i)"
        }
        store.save()

        // When/Then: Measure fetch performance
        measure {
            _ = store.fetchAllEntries()
        }
    }

    func testSearchPerformance() async throws {
        // Given: Many entries with varied content
        for i in 1...100 {
            let entry = store.newEntry()
            entry.text = "Entry \(i) with content about \(i % 10 == 0 ? "work" : "personal") matters"
        }
        store.save()

        // When/Then: Measure search performance
        measure {
            _ = store.search("work")
        }
    }
}
