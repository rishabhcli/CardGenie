//
//  HighlightCardBuilder.swift
//  CardGenie
//
//  Converts confirmed highlights into flashcard decks.
//

import Foundation
import SwiftData

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

        let response = try await llm.complete(prompt, maxTokens: 180)
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
