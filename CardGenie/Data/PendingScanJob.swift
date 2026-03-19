//
//  PendingScanJob.swift
//  CardGenie
//
//  Persistent scan-to-flashcard jobs for offline retry.
//

import Foundation
import SwiftData

enum PendingScanJobStatus: String, Codable {
    case queued
    case processing
    case failed
    case completed
}

@Model
final class PendingScanJob {
    @Attribute(.unique) var id: UUID
    var text: String
    var topic: String?
    var deck: String?
    var imageDataArray: [Data]
    var pageCount: Int
    var createdAt: Date
    var updatedAt: Date
    var retryCount: Int
    var lastErrorMessage: String?
    var formats: [String]
    var sourceLabel: String
    var textFingerprint: String
    var statusRawValue: String

    init(
        id: UUID = UUID(),
        text: String,
        topic: String? = nil,
        deck: String? = nil,
        imageDataArray: [Data] = [],
        pageCount: Int = 1,
        formats: Set<FlashcardType> = [.qa, .cloze, .definition],
        sourceLabel: String = "scan"
    ) {
        self.id = id
        self.text = text
        self.topic = topic
        self.deck = deck
        self.imageDataArray = imageDataArray
        self.pageCount = pageCount
        self.createdAt = Date()
        self.updatedAt = Date()
        self.retryCount = 0
        self.lastErrorMessage = nil
        self.formats = formats.map(\.rawValue).sorted()
        self.sourceLabel = sourceLabel
        self.textFingerprint = Self.makeFingerprint(text: text, topic: topic, deck: deck)
        self.statusRawValue = PendingScanJobStatus.queued.rawValue
    }

    var status: PendingScanJobStatus {
        get { PendingScanJobStatus(rawValue: statusRawValue) ?? .queued }
        set {
            statusRawValue = newValue.rawValue
            updatedAt = Date()
        }
    }

    var flashcardFormats: Set<FlashcardType> {
        Set(formats.compactMap(FlashcardType.init(rawValue:)))
    }

    func markQueued() {
        status = .queued
        lastErrorMessage = nil
    }

    func markProcessing() {
        status = .processing
        lastErrorMessage = nil
    }

    func markFailure(_ message: String) {
        retryCount += 1
        lastErrorMessage = message
        status = .failed
    }

    func markCompleted() {
        lastErrorMessage = nil
        status = .completed
    }

    static func makeFingerprint(text: String, topic: String?, deck: String?) -> String {
        let normalizedText = text
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return [normalizedText, topic?.lowercased() ?? "", deck?.lowercased() ?? ""]
            .joined(separator: "|")
    }
}
