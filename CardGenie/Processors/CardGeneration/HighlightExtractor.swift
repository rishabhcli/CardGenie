//
//  HighlightExtractor.swift
//  CardGenie
//
//  Lightweight heuristics for surfacing lecture highlights in real-time.
//

import Foundation

struct HighlightCandidate: Identifiable, Hashable {
    let id: UUID
    let startTime: Double
    let endTime: Double
    let excerpt: String
    let summary: String
    let confidence: Double
    let kind: Kind

    enum Kind {
        case automatic
        case manual
        case collaborative
    }
}

@MainActor
final class HighlightExtractor {
    private let keywordSignals: [String]
    private let emphasisSignals: CharacterSet

    init(keywordSignals: [String] = ["important", "key", "remember", "exam", "definition", "therefore"],
         emphasisSignals: CharacterSet = CharacterSet(charactersIn: "!?")) {
        self.keywordSignals = keywordSignals
        self.emphasisSignals = emphasisSignals
    }

    func evaluate(chunk: TranscriptChunk) -> HighlightCandidate? {
        let text = chunk.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 40 else { return nil }

        var confidence: Double = 0.4

        let lowercased = text.lowercased()
        let keywordHits = keywordSignals.filter { lowercased.contains($0) }
        confidence += Double(keywordHits.count) * 0.15

        if text.count > 180 {
            confidence += 0.1
        }

        if text.rangeOfCharacter(from: emphasisSignals) != nil {
            confidence += 0.15
        }

        confidence = min(confidence, 0.95)

        guard confidence >= 0.55 else {
            return nil
        }

        return HighlightCandidate(
            id: UUID(),
            startTime: chunk.timestampRange.start,
            endTime: chunk.timestampRange.end,
            excerpt: text,
            summary: summarize(text),
            confidence: confidence,
            kind: .automatic
        )
    }

    func manualHighlight(transcript: String, timestamp: Double) -> HighlightCandidate {
        let excerpt = transcript.isEmpty ? "Highlight at \(formatted(timestamp: timestamp))" : transcript

        return HighlightCandidate(
            id: UUID(),
            startTime: timestamp,
            endTime: timestamp + 8,
            excerpt: excerpt,
            summary: summarize(excerpt),
            confidence: 0.9,
            kind: .manual
        )
    }

    func collaborativeHighlight(_ excerpt: String, start: Double, end: Double, author: String?) -> HighlightCandidate {
        HighlightCandidate(
            id: UUID(),
            startTime: start,
            endTime: end,
            excerpt: excerpt,
            summary: summarize(excerpt, author: author),
            confidence: 0.8,
            kind: .collaborative
        )
    }

    private func summarize(_ text: String, author: String? = nil) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "New highlight" }

        let firstSentence = trimmed
            .split(whereSeparator: { ".!?".contains($0) })
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces)
            ?? trimmed.prefix(140).trimmingCharacters(in: .whitespaces)

        if let author {
            return "\(author): \(firstSentence)"
        }

        return firstSentence
    }

    private func formatted(timestamp: Double) -> String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
