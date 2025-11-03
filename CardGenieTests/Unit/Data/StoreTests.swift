//
//  StoreTests.swift
//  CardGenieTests
//
//  Updated unit tests for the StudyContent store.
//

import XCTest
import SwiftData
@testable import CardGenie

@MainActor
final class StoreTests: XCTestCase {
    var container: ModelContainer!
    var store: Store!

    override func setUp() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: StudyContent.self, configurations: configuration)
        store = Store(container: container)
    }

    override func tearDown() async throws {
        container = nil
        store = nil
    }

    func testNewContentDefaults() async throws {
        let content = store.newContent()

        XCTAssertFalse(content.rawContent.contains(where: { !$0.isWhitespace }))
        XCTAssertTrue(content.tags.isEmpty)
        XCTAssertNil(content.summary)
        XCTAssertEqual(content.source, .text)
        XCTAssertNotNil(content.createdAt)
    }

    func testFetchAllContentSortedByDate() async throws {
        let first = store.newContent()
        first.rawContent = "First item"
        first.createdAt = Date().addingTimeInterval(-3600)

        let second = store.newContent()
        second.rawContent = "Second item"
        second.createdAt = Date()

        store.save()

        let results = store.fetchAllContent()
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first?.rawContent, "Second item")
        XCTAssertEqual(results.last?.rawContent, "First item")
    }

    func testDeleteContentRemovesFromStore() async throws {
        let content = store.newContent()
        content.rawContent = "Keep me safe"
        store.save()

        var results = store.fetchAllContent()
        XCTAssertEqual(results.count, 1)

        store.delete(content)
        results = store.fetchAllContent()
        XCTAssertTrue(results.isEmpty)
    }

    func testFetchContentBySource() async throws {
        let text = store.newContent(source: .text)
        text.rawContent = "Notebook entry"

        let photo = store.newContent(source: .photo)
        photo.rawContent = "Photo capture"

        store.save()

        let textItems = store.fetchContent(bySource: .text)
        XCTAssertEqual(textItems.count, 1)
        XCTAssertEqual(textItems.first?.id, text.id)

        let photoItems = store.fetchContent(bySource: .photo)
        XCTAssertEqual(photoItems.count, 1)
        XCTAssertEqual(photoItems.first?.id, photo.id)
    }

    func testSearchMatchesSummaryTagsAndTopic() async throws {
        let content = store.newContent()
        content.rawContent = "The mitochondria is the powerhouse of the cell."
        content.summary = "Biology overview"
        content.tags = ["science", "biology"]
        content.topic = "Cellular Biology"
        store.save()

        XCTAssertEqual(store.search("biology").count, 1)      // matches summary + tag + topic
        XCTAssertEqual(store.search("SCIENCE").count, 1)      // case-insensitive tag match
        XCTAssertEqual(store.search("powerhouse").count, 1)   // raw content match
        XCTAssertTrue(store.search("astronomy").isEmpty)
    }

    func testPreviewPrefersSummary() async throws {
        let content = store.newContent()
        content.rawContent = "Long-form content that should not be shown when a summary exists."
        content.summary = "Concise summary"
        store.save()

        let fetched = store.fetchAllContent().first
        XCTAssertEqual(fetched?.preview, "Concise summary")
    }

    func testPreviewFallsBackToRawContent() async throws {
        let content = store.newContent()
        content.rawContent = "This is the first sentence.\nHere is some additional detail."
        store.save()

        let fetched = store.fetchAllContent().first
        XCTAssertEqual(fetched?.firstLine, "This is the first sentence.")
        XCTAssertTrue(fetched?.preview.hasPrefix("This is the first sentence.") ?? false)
    }

    func testSearchWithEmptyQueryReturnsAll() async throws {
        store.newContent().rawContent = "One"
        store.newContent().rawContent = "Two"
        store.save()

        XCTAssertEqual(store.search("").count, 2)
    }

    func testFetchPerformance() async throws {
        for index in 0..<200 {
            let content = store.newContent()
            content.rawContent = "Item \(index)"
        }
        store.save()

        measure {
            _ = store.fetchAllContent()
        }
    }

    func testSearchPerformance() async throws {
        for index in 0..<200 {
            let content = store.newContent()
            content.rawContent = "Physics concept \(index)"
            content.tags = index.isMultiple(of: 2) ? ["physics"] : ["chemistry"]
        }
        store.save()

        measure {
            _ = store.search("physics")
        }
    }
}
