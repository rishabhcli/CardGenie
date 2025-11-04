//
//  FlashcardProcessors.swift
//  CardGenie
//
//  Flashcard generation from note chunks, highlights, and documents.
//

import Foundation
import SwiftData

// MARK: - FlashcardGenerator
//


// MARK: - Flashcard Generator

final class FlashcardGenerator {
    private let llm: LLMEngine

    init(llm: LLMEngine = AIEngineFactory.createLLMEngine()) {
        self.llm = llm
    }

    // MARK: - Generate from Chunks

    /// Generate flashcards from note chunks
    func generateCards(from chunks: [NoteChunk], deck: FlashcardSet) async throws -> [Flashcard] {
        var allCards: [Flashcard] = []

        for chunk in chunks {
            // Generate different types of cards
            let cards = try await generateCardsFromChunk(chunk)

            for card in cards {
                deck.addCard(card)
                allCards.append(card)
            }
        }

        return allCards
    }

    // MARK: - Card Generation from Single Chunk

    private func generateCardsFromChunk(_ chunk: NoteChunk) async throws -> [Flashcard] {
        var cards: [Flashcard] = []

        // Generate Q&A cards
        if let qaCards = try? await generateQACards(chunk) {
            cards.append(contentsOf: qaCards)
        }

        // Generate cloze deletion cards
        if let clozeCards = try? await generateClozeCards(chunk) {
            cards.append(contentsOf: clozeCards)
        }

        return cards
    }

    // MARK: - Q&A Card Generation

    private func generateQACards(_ chunk: NoteChunk) async throws -> [Flashcard] {
        let prompt = """
        Create 2 question-answer flashcards from this text.
        Make questions clear and specific. Keep answers concise (1-3 sentences).

        TEXT:
        \(chunk.text.prefix(800))

        FORMAT:
        Q1: [question]
        A1: [answer]

        Q2: [question]
        A2: [answer]

        CARDS:
        """

        let response = try await llm.complete(prompt)
        return parseQACards(response, sourceChunk: chunk)
    }

    private func parseQACards(_ response: String, sourceChunk: NoteChunk) -> [Flashcard] {
        var cards: [Flashcard] = []

        // Simple parser for Q1/A1, Q2/A2 format
        let lines = response.components(separatedBy: .newlines)
        var currentQuestion: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("Q") && trimmed.contains(":") {
                // Extract question
                let parts = trimmed.components(separatedBy: ":")
                if parts.count >= 2 {
                    currentQuestion = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                }
            } else if trimmed.hasPrefix("A") && trimmed.contains(":"), let question = currentQuestion {
                // Extract answer
                let parts = trimmed.components(separatedBy: ":")
                if parts.count >= 2 {
                    let answer = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)

                    let card = Flashcard(
                        type: .qa,
                        question: question,
                        answer: answer,
                        linkedEntryID: sourceChunk.id
                    )

                    cards.append(card)
                    currentQuestion = nil
                }
            }
        }

        return cards
    }

    // MARK: - Cloze Deletion Card Generation

    private func generateClozeCards(_ chunk: NoteChunk) async throws -> [Flashcard] {
        let prompt = """
        Create 1 cloze deletion (fill-in-the-blank) flashcard from this text.
        Use [...] to mark the blanked word/phrase.

        TEXT:
        \(chunk.text.prefix(600))

        FORMAT:
        CLOZE: [sentence with [...] marking the blank]
        ANSWER: [the word/phrase that fills the blank]

        CARD:
        """

        let response = try await llm.complete(prompt)
        return parseClozeCards(response, sourceChunk: chunk)
    }

    private func parseClozeCards(_ response: String, sourceChunk: NoteChunk) -> [Flashcard] {
        var cards: [Flashcard] = []

        let lines = response.components(separatedBy: .newlines)
        var clozeText: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("CLOZE:") {
                clozeText = trimmed.replacingOccurrences(of: "CLOZE:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("ANSWER:"), let cloze = clozeText {
                let answer = trimmed.replacingOccurrences(of: "ANSWER:", with: "")
                    .trimmingCharacters(in: .whitespaces)

                let card = Flashcard(
                    type: .cloze,
                    question: cloze,
                    answer: answer,
                    linkedEntryID: sourceChunk.id
                )

                cards.append(card)
                clozeText = nil
            }
        }

        return cards
    }

    // MARK: - Batch Generation

    /// Generate flashcards from entire source document
    func generateFromSource(_ source: SourceDocument, context: ModelContext) async throws -> FlashcardSet {
        // Create or find deck
        let deckName = source.fileName.replacingOccurrences(of: ".pdf", with: "")
        let deck = FlashcardSet(topicLabel: deckName, tag: source.kind.rawValue)

        context.insert(deck)

        // Generate cards from each chunk
        let cards = try await generateCards(from: source.chunks, deck: deck)

        print("Generated \(cards.count) flashcards from \(source.fileName)")

        return deck
    }
}

// MARK: - HighlightExtractor

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

// MARK: - HighlightCardBuilder

final class HighlightCardBuilder {
    private let llm: LLMEngine

    init(llm: LLMEngine = AIEngineFactory.createLLMEngine()) {
        self.llm = llm
    }

    func buildDeck(
        from highlights: [HighlightMarker],
        session: LectureSession,
        preferredName: String,
        context: ModelContext
    ) async throws -> FlashcardSet {
        let tag = "lecture-\(session.id.uuidString.prefix(6))"
        let deck = FlashcardSet(topicLabel: preferredName, tag: String(tag))
        context.insert(deck)

        for marker in highlights where marker.isCardCandidate {
            let card = try await makeCard(from: marker, session: session)
            deck.addCard(card)
            marker.linkedFlashcard = card
        }

        try context.save()
        return deck
    }

    private func makeCard(from marker: HighlightMarker, session: LectureSession) async throws -> Flashcard {
        let prompt = """
        Create a study flashcard from the following lecture highlight.
        Keep the language concise and helpful for revision.

        SESSION TITLE: \(session.title)
        HIGHLIGHT: \(marker.summary ?? marker.transcriptSnippet)
        TRANSCRIPT SNIPPET: \(marker.transcriptSnippet)

        FORMAT:
        Q: [question]
        A: [answer]
        """

        let response = try await llm.complete(prompt)
        if let parsed = parseQA(response: response) {
            return Flashcard(
                type: .qa,
                question: parsed.question,
                answer: parsed.answer,
                linkedEntryID: marker.id
            )
        }

        // Fallback card if parsing fails
        let fallbackQuestion = "What key idea was covered at \(marker.timeRange.formatted)?"
        let fallbackAnswer = marker.summary ?? marker.transcriptSnippet

        return Flashcard(
            type: .qa,
            question: fallbackQuestion,
            answer: fallbackAnswer,
            linkedEntryID: marker.id
        )
    }

    private func parseQA(response: String) -> (question: String, answer: String)? {
        var question: String?
        var answer: String?

        response
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .forEach { line in
                if line.hasPrefix("Q:"), question == nil {
                    question = line.replacingOccurrences(of: "Q:", with: "").trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("A:"), answer == nil {
                    answer = line.replacingOccurrences(of: "A:", with: "").trimmingCharacters(in: .whitespaces)
                }
            }

        if let question, let answer, !question.isEmpty, !answer.isEmpty {
            return (question, answer)
        }
        return nil
    }
}
