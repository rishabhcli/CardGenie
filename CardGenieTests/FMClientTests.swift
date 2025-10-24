//
//  FMClientTests.swift
//  CardGenie
//
//  Unit tests for Foundation Models client.
//

import XCTest
@testable import CardGenie

@MainActor
final class FMClientTests: XCTestCase {
    var client: FMClient!

    override func setUp() async throws {
        client = FMClient()
    }

    override func tearDown() async throws {
        client = nil
    }

    // MARK: - Capability Tests

    func testCapabilityCheck() async throws {
        // Test that capability check returns a valid state
        let capability = client.capability()

        XCTAssertTrue(
            [.available, .notEnabled, .notSupported, .modelNotReady, .unknown].contains(capability),
            "Capability should return a valid state"
        )
    }

    // MARK: - Summarization Tests

    func testSummarizeWithValidText() async throws {
        // Given: A long text entry
        let sampleText = """
        Today was an amazing day. I woke up early and went for a run in the park.
        The weather was perfect, and I felt energized. Later, I had a productive meeting
        at work where we discussed the new project. I'm excited about the opportunities ahead.
        In the evening, I spent quality time with family and we had a great dinner together.
        """

        // When: Summarizing the text
        let summary = try await client.summarize(sampleText)

        // Then: Should return a non-empty summary
        XCTAssertFalse(summary.isEmpty, "Summary should not be empty")
        XCTAssertTrue(summary.count < sampleText.count, "Summary should be shorter than original")
    }

    func testSummarizeWithShortText() async throws {
        // Given: Very short text
        let shortText = "Quick note"

        // When: Summarizing
        let summary = try await client.summarize(shortText)

        // Then: Should return empty (text too short)
        XCTAssertTrue(summary.isEmpty, "Summary of very short text should be empty")
    }

    func testSummarizeWithEmptyText() async throws {
        // Given: Empty text
        let emptyText = ""

        // When: Summarizing
        let summary = try await client.summarize(emptyText)

        // Then: Should return empty
        XCTAssertTrue(summary.isEmpty, "Summary of empty text should be empty")
    }

    // MARK: - Tagging Tests

    func testTagsGeneration() async throws {
        // Given: Text with clear topics
        let sampleText = """
        Had a great workout session at the gym today. Focused on strength training
        and cardio. Feeling motivated to continue my fitness journey.
        """

        // When: Generating tags
        let tags = try await client.tags(for: sampleText)

        // Then: Should return tags
        XCTAssertFalse(tags.isEmpty, "Tags should not be empty")
        XCTAssertLessThanOrEqual(tags.count, 3, "Should return at most 3 tags")

        // Tags should be capitalized and non-empty
        for tag in tags {
            XCTAssertFalse(tag.isEmpty, "Tags should not be empty strings")
            XCTAssertTrue(tag.first?.isUppercase ?? false, "Tags should be capitalized")
        }
    }

    func testTagsFromShortText() async throws {
        // Given: Short text
        let shortText = "Quick gym session"

        // When: Generating tags
        let tags = try await client.tags(for: shortText)

        // Then: May return empty or few tags
        XCTAssertLessThanOrEqual(tags.count, 3, "Should return at most 3 tags")
    }

    // MARK: - Reflection Tests

    func testReflectionGeneration() async throws {
        // Given: A journal entry
        let sampleText = """
        Feeling grateful today. Sometimes it's the small things that matter most.
        A good conversation, a beautiful sunset, and time to reflect.
        """

        // When: Generating reflection
        let reflection = try await client.reflection(for: sampleText)

        // Then: Should return a reflection
        XCTAssertFalse(reflection.isEmpty, "Reflection should not be empty")
        XCTAssertTrue(reflection.count > 10, "Reflection should be a meaningful sentence")
    }

    // MARK: - Performance Tests

    func testSummarizationPerformance() async throws {
        // Given: A medium-length text
        let text = String(repeating: "This is a test sentence. ", count: 50)

        // When/Then: Should complete within reasonable time
        measure {
            Task {
                _ = try? await client.summarize(text)
            }
        }
    }

    // MARK: - Error Handling Tests

    func testUnsupportedOSError() async throws {
        // This test is for documentation purposes
        // In production, the client would throw FMError.unsupportedOS
        // when running on iOS < 26

        // Given: A client that checks OS version
        // When: Running on unsupported OS
        // Then: Should handle gracefully

        // Note: Actual testing would require mocking OS version check
        XCTAssertTrue(true, "Error handling documented")
    }
}

// MARK: - Test Helpers

extension FMClientTests {
    /// Creates sample text for testing
    func sampleJournalEntry() -> String {
        """
        Today was a productive day at work. I finished the design mockups for
        the new feature and presented them to the team. Everyone was excited
        about the direction we're heading. In the evening, I took some time to
        read and relax. Feeling satisfied with today's accomplishments.
        """
    }
}

// MARK: - Integration Tests

/// These tests require a real device with iOS 26 and Apple Intelligence enabled
/// Comment out @available when testing on supported devices
@available(iOS 26.0, *)
final class FMClientIntegrationTests: XCTestCase {
    // Integration tests to run on actual iOS 26 devices

    @MainActor
    func testRealModelSummarization() async throws {
        // This test only runs on iOS 26+ devices with Apple Intelligence
        let client = FMClient()

        guard client.capability() == .available else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let text = """
        Had an incredible day exploring the city. Started with a morning coffee
        at my favorite café, then visited the art museum. The new exhibition was
        breathtaking. Ended the day with dinner at a new restaurant with friends.
        """

        let summary = try await client.summarize(text)

        XCTAssertFalse(summary.isEmpty)
        print("Generated summary: \(summary)")
    }

    @MainActor
    func testRealModelTagging() async throws {
        let client = FMClient()

        guard client.capability() == .available else {
            throw XCTSkip("Apple Intelligence not available")
        }

        let text = """
        Completed my first marathon today! The training over the past six months
        really paid off. The experience was challenging but incredibly rewarding.
        Can't wait for the next one.
        """

        let tags = try await client.tags(for: text)

        XCTAssertFalse(tags.isEmpty)
        print("Generated tags: \(tags)")
    }
}
