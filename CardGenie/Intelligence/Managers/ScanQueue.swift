//
//  ScanQueue.swift
//  CardGenie
//
//  Offline queue manager for pending scan-to-flashcard operations.
//  Allows users to scan offline and process later when AI is available.
//

import Foundation
import SwiftData
import OSLog
import Combine
import UIKit

/// A pending scan waiting for flashcard generation
struct PendingScan: Identifiable, Codable {
    let id: UUID
    let text: String
    let topic: String?
    let deck: String?
    let imageDataArray: [Data]
    let pageCount: Int
    let createdAt: Date
    let formats: [String] // FlashcardType raw values

    init(
        id: UUID = UUID(),
        text: String,
        topic: String? = nil,
        deck: String? = nil,
        imageDataArray: [Data] = [],
        pageCount: Int = 1,
        formats: Set<FlashcardType> = [.qa, .cloze, .definition]
    ) {
        self.id = id
        self.text = text
        self.topic = topic
        self.deck = deck
        self.imageDataArray = imageDataArray
        self.pageCount = pageCount
        self.createdAt = Date()
        self.formats = formats.map(\.rawValue)
    }

    var flashcardFormats: Set<FlashcardType> {
        Set(formats.compactMap { FlashcardType(rawValue: $0) })
    }
}

/// Manages offline scan queue for background processing
@MainActor
final class ScanQueue: ObservableObject {
    static let shared = ScanQueue()

    private let logger = Logger(subsystem: "com.cardgenie.app", category: "ScanQueue")
    private let userDefaults = UserDefaults.standard
    private let queueKey = "com.cardgenie.scanQueue"

    @Published private(set) var pendingScans: [PendingScan] = []
    @Published private(set) var isProcessing = false

    private init() {
        loadQueue()
    }

    // MARK: - Queue Management

    /// Add a scan to the offline queue
    func enqueueScan(_ scan: PendingScan) {
        pendingScans.append(scan)
        saveQueue()
        logger.info("Enqueued scan: \(scan.id) - \(scan.text.prefix(50))...")
    }

    /// Add a scan from ScanReviewView data
    func enqueueScan(
        text: String,
        topic: String?,
        deck: String?,
        images: [UIImage],
        formats: Set<FlashcardType>
    ) {
        let imageData = images.compactMap { $0.jpegData(compressionQuality: 0.8) }
        let scan = PendingScan(
            text: text,
            topic: topic,
            deck: deck,
            imageDataArray: imageData,
            pageCount: images.count,
            formats: formats
        )
        enqueueScan(scan)
    }

    /// Remove a specific scan from queue
    func removeScan(_ scanID: UUID) {
        pendingScans.removeAll { $0.id == scanID }
        saveQueue()
        logger.info("Removed scan from queue: \(scanID)")
    }

    /// Clear all pending scans
    func clearQueue() {
        pendingScans.removeAll()
        saveQueue()
        logger.info("Cleared scan queue")
    }

    // MARK: - Processing

    /// Process all pending scans using Foundation Models
    /// - Parameter modelContext: SwiftData context for saving results
    /// - Returns: Number of successfully processed scans
    @discardableResult
    func processQueue(modelContext: ModelContext, fmClient: FMClient) async -> Int {
        guard !pendingScans.isEmpty else {
            logger.info("Queue is empty, nothing to process")
            return 0
        }

        guard !isProcessing else {
            logger.warning("Queue is already being processed")
            return 0
        }

        isProcessing = true
        defer { isProcessing = false }

        logger.info("Starting queue processing: \(self.pendingScans.count) scans")
        var successCount = 0

        for scan in self.pendingScans {
            do {
                try await processScan(scan, modelContext: modelContext, fmClient: fmClient)
                removeScan(scan.id)
                successCount += 1
                logger.info("Successfully processed scan: \(scan.id)")
            } catch {
                logger.error("Failed to process scan \(scan.id): \(error.localizedDescription)")
                // Keep failed scan in queue for retry
            }
        }

        logger.info("Queue processing complete: \(successCount)/\(self.pendingScans.count) successful")
        return successCount
    }

    /// Process a single pending scan
    private func processScan(
        _ scan: PendingScan,
        modelContext: ModelContext,
        fmClient: FMClient
    ) async throws {
        // Create StudyContent
        let content = StudyContent(
            source: .photo,
            rawContent: scan.text
        )
        content.topic = scan.topic
        content.extractedText = scan.text

        // Store images
        if scan.pageCount > 1 {
            content.photoPages = scan.imageDataArray
            content.pageCount = scan.pageCount
        } else if let imageData = scan.imageDataArray.first {
            content.photoData = imageData
            content.pageCount = 1
        }

        modelContext.insert(content)

        // Generate flashcards
        let result = try await fmClient.generateFlashcards(
            from: content,
            formats: scan.flashcardFormats,
            maxPerFormat: 3
        )

        // Find or create flashcard set
        let deckName = scan.deck ?? scan.topic ?? result.topicTag
        let flashcardSet = modelContext.findOrCreateFlashcardSet(topicLabel: deckName)

        // Link flashcards
        content.flashcards.append(contentsOf: result.flashcards)
        for flashcard in result.flashcards {
            flashcardSet.addCard(flashcard)
            modelContext.insert(flashcard)
        }
        flashcardSet.entryCount += 1

        try modelContext.save()
    }

    // MARK: - Persistence

    private func loadQueue() {
        guard let data = userDefaults.data(forKey: queueKey),
              let decoded = try? JSONDecoder().decode([PendingScan].self, from: data) else {
            logger.info("No existing queue found")
            return
        }

        pendingScans = decoded
        logger.info("Loaded queue: \(decoded.count) pending scans")
    }

    private func saveQueue() {
        guard let encoded = try? JSONEncoder().encode(pendingScans) else {
            logger.error("Failed to encode queue")
            return
        }

        userDefaults.set(encoded, forKey: queueKey)
    }

    // MARK: - Helper Methods

    /// Check if AI is available for processing
    func canProcessQueue(fmClient: FMClient) -> Bool {
        return fmClient.capability() == .available
    }

    /// Get queue statistics
    var queueStats: (count: Int, oldestDate: Date?) {
        let oldest = pendingScans.min(by: { $0.createdAt < $1.createdAt })?.createdAt
        return (pendingScans.count, oldest)
    }
}

// FlashcardType is already Codable in FlashcardModels.swift
