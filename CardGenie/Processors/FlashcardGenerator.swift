//
//  FlashcardGenerator.swift
//  CardGenie
//
//  Enhanced flashcard generation from note chunks.
//

import Foundation
import SwiftData

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

        let response = try await llm.complete(prompt, maxTokens: 400)
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

        let response = try await llm.complete(prompt, maxTokens: 200)
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
