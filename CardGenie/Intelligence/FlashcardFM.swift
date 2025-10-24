//
//  FlashcardFM.swift
//  CardGenie
//
//  AI-powered flashcard generation and clarification using Apple's Foundation Models.
//  All processing happens on-device via the Neural Engine.
//

import Foundation
import OSLog

// MARK: - Flashcard Generation Result

struct FlashcardGenerationResult {
    let flashcards: [Flashcard]
    let topicTag: String
    let entities: [String]
}

// MARK: - FMClient Extension for Flashcards

extension FMClient {
    private var flashcardLog: Logger {
        Logger(subsystem: "com.cardgenie.app", category: "FlashcardGeneration")
    }

    // MARK: - Main Generation Method

    /// Generate flashcards from a journal entry using on-device AI
    /// - Parameters:
    ///   - entry: The journal entry to generate flashcards from
    ///   - formats: Flashcard formats to generate (cloze, Q&A, definition)
    ///   - maxPerFormat: Maximum flashcards per format (default: 3)
    /// - Returns: Array of generated flashcards with topic information
    func generateFlashcards(
        from entry: JournalEntry,
        formats: Set<FlashcardType>,
        maxPerFormat: Int = 3
    ) async throws -> FlashcardGenerationResult {
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        flashcardLog.info("Starting flashcard generation for entry: \(entry.id)")

        // Step 1: Extract entities and topics using content tagging
        let (entities, topicTag) = try await extractEntitiesAndTopics(from: entry.text)

        flashcardLog.info("Extracted \(entities.count) entities and topic: \(topicTag)")

        // Step 2: Generate flashcards for each requested format
        var allFlashcards: [Flashcard] = []

        for format in formats {
            let cards = try await generateFlashcardsForFormat(
                format,
                text: entry.text,
                entities: entities,
                linkedEntryID: entry.id,
                topicTag: topicTag,
                maxCards: maxPerFormat
            )
            allFlashcards.append(contentsOf: cards)
        }

        // Step 3: Deduplicate and filter
        let uniqueFlashcards = deduplicateFlashcards(allFlashcards)

        flashcardLog.info("Generated \(uniqueFlashcards.count) unique flashcards")

        return FlashcardGenerationResult(
            flashcards: uniqueFlashcards,
            topicTag: topicTag,
            entities: entities
        )
    }

    // MARK: - Entity Extraction

    /// Extract key entities and assign a topic tag using content tagging model
    private func extractEntitiesAndTopics(from text: String) async throws -> ([String], String) {
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        // TODO: Replace with actual Foundation Models content tagging API when iOS 26 SDK is available
        // Example from Apple's docs:
        //
        // let taggingModel = SystemLanguageModel(useCase: .contentTagging)
        // guard taggingModel.isAvailable else {
        //     throw FMError.modelUnavailable
        // }
        //
        // let session = LanguageModelSession(model: taggingModel)
        //
        // let request = LanguageModelRequest(
        //     systemPrompt: """
        //         Extract important entities (names, places, dates, key terms) from the text.
        //         Also identify the main topic category (e.g., Travel, Work, Health, History).
        //         Format: Entities: term1, term2, term3 | Topic: category
        //         """,
        //     userPrompt: text
        // )
        //
        // let response = try await session.respond(to: request)
        //
        // // Parse response to extract entities and topic
        // let components = response.text.components(separatedBy: "|")
        // let entitiesStr = components.first?.replacingOccurrences(of: "Entities:", with: "").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // let topicStr = components.last?.replacingOccurrences(of: "Topic:", with: "").trimmingCharacters(in: .whitespacesAndNewlines) ?? "General"
        //
        // let entities = entitiesStr.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        //
        // return (entities, topicStr)

        // Placeholder implementation for testing
        return try await extractEntitiesPlaceholder(from: text)
    }

    private func extractEntitiesPlaceholder(from text: String) async throws -> ([String], String) {
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Simple keyword extraction (placeholder until real API is available)
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 4 }
            .filter { !commonWords.contains($0.lowercased()) }

        let uniqueWords = Array(Set(words)).prefix(5)

        // Simple topic inference
        let topic = inferTopic(from: text)

        return (Array(uniqueWords), topic)
    }

    private func inferTopic(from text: String) -> String {
        let lowercased = text.lowercased()

        let topicKeywords: [(String, [String])] = [
            ("Work", ["work", "meeting", "project", "deadline", "client", "office"]),
            ("Travel", ["travel", "trip", "vacation", "visit", "explore", "city", "country"]),
            ("Health", ["health", "exercise", "workout", "fitness", "doctor", "medical"]),
            ("Personal", ["feeling", "thought", "reflection", "mood", "emotion"]),
            ("Learning", ["learn", "study", "course", "book", "reading", "education"]),
            ("Family", ["family", "parent", "child", "sibling", "relative"]),
            ("Food", ["food", "restaurant", "cooking", "meal", "dinner", "lunch"])
        ]

        for (topic, keywords) in topicKeywords {
            if keywords.contains(where: { lowercased.contains($0) }) {
                return topic
            }
        }

        return "General"
    }

    // MARK: - Format-Specific Generation

    private func generateFlashcardsForFormat(
        _ format: FlashcardType,
        text: String,
        entities: [String],
        linkedEntryID: UUID,
        topicTag: String,
        maxCards: Int
    ) async throws -> [Flashcard] {
        switch format {
        case .cloze:
            return try await generateClozeCards(
                text: text,
                entities: entities,
                linkedEntryID: linkedEntryID,
                topicTag: topicTag,
                maxCards: maxCards
            )
        case .qa:
            return try await generateQACards(
                text: text,
                linkedEntryID: linkedEntryID,
                topicTag: topicTag,
                maxCards: maxCards
            )
        case .definition:
            return try await generateDefinitionCards(
                text: text,
                entities: entities,
                linkedEntryID: linkedEntryID,
                topicTag: topicTag,
                maxCards: maxCards
            )
        }
    }

    // MARK: - Cloze Deletion Cards

    private func generateClozeCards(
        text: String,
        entities: [String],
        linkedEntryID: UUID,
        topicTag: String,
        maxCards: Int
    ) async throws -> [Flashcard] {
        var cards: [Flashcard] = []

        // For each entity, find a sentence containing it and create a cloze deletion
        for entity in entities.prefix(maxCards) {
            if let clozeCard = createClozeCard(
                forEntity: entity,
                inText: text,
                linkedEntryID: linkedEntryID,
                topicTag: topicTag
            ) {
                cards.append(clozeCard)
            }
        }

        return cards
    }

    private func createClozeCard(
        forEntity entity: String,
        inText text: String,
        linkedEntryID: UUID,
        topicTag: String
    ) -> Flashcard? {
        // Find sentence containing the entity
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let sentence = sentences.first(where: { $0.localizedCaseInsensitiveContains(entity) }) else {
            return nil
        }

        // Create cloze deletion by replacing entity with blank
        let clozeQuestion = sentence.replacingOccurrences(
            of: entity,
            with: "______",
            options: .caseInsensitive
        )

        return Flashcard(
            type: .cloze,
            question: clozeQuestion,
            answer: entity,
            linkedEntryID: linkedEntryID,
            tags: [topicTag]
        )
    }

    // MARK: - Q&A Cards

    private func generateQACards(
        text: String,
        linkedEntryID: UUID,
        topicTag: String,
        maxCards: Int
    ) async throws -> [Flashcard] {
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        // TODO: Replace with actual Foundation Models API
        // Example prompt:
        //
        // let model = SystemLanguageModel.default
        // guard model.isAvailable else { throw FMError.modelUnavailable }
        //
        // let session = LanguageModelSession()
        //
        // let systemPrompt = """
        //     You are a flashcard generation assistant.
        //     Generate question-and-answer pairs from journal text.
        //     Each Q&A should focus on a specific fact or detail.
        //     Format each as: Q: [question] | A: [answer]
        //     Generate \(maxCards) flashcards.
        //     """
        //
        // let request = LanguageModelRequest(
        //     systemPrompt: systemPrompt,
        //     userPrompt: "Text: \(text)",
        //     temperature: 0.3,
        //     maxTokens: 300
        // )
        //
        // let response = try await session.respond(to: request)
        //
        // // Parse Q&A pairs from response
        // return parseQAPairs(response.text, linkedEntryID: linkedEntryID, topicTag: topicTag)

        // Placeholder implementation
        return try await generateQACardsPlaceholder(
            text: text,
            linkedEntryID: linkedEntryID,
            topicTag: topicTag,
            maxCards: maxCards
        )
    }

    private func generateQACardsPlaceholder(
        text: String,
        linkedEntryID: UUID,
        topicTag: String,
        maxCards: Int
    ) async throws -> [Flashcard] {
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds

        // Generate simple Q&A from first sentences
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(maxCards)

        return sentences.enumerated().map { index, sentence in
            Flashcard(
                type: .qa,
                question: "What is mentioned in the entry about point \(index + 1)?",
                answer: sentence,
                linkedEntryID: linkedEntryID,
                tags: [topicTag]
            )
        }
    }

    // MARK: - Definition Cards

    private func generateDefinitionCards(
        text: String,
        entities: [String],
        linkedEntryID: UUID,
        topicTag: String,
        maxCards: Int
    ) async throws -> [Flashcard] {
        var cards: [Flashcard] = []

        for entity in entities.prefix(maxCards) {
            if let definition = try await generateDefinition(for: entity, inContext: text) {
                let card = Flashcard(
                    type: .definition,
                    question: "What is \(entity)?",
                    answer: definition,
                    linkedEntryID: linkedEntryID,
                    tags: [topicTag]
                )
                cards.append(card)
            }
        }

        return cards
    }

    private func generateDefinition(for term: String, inContext text: String) async throws -> String? {
        // Find sentence(s) containing the term as context
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.localizedCaseInsensitiveContains(term) }

        guard let context = sentences.first else {
            return nil
        }

        // For now, use the context sentence as the definition
        // TODO: Use Foundation Models to generate a concise definition
        return context
    }

    // MARK: - Deduplication

    private func deduplicateFlashcards(_ flashcards: [Flashcard]) -> [Flashcard] {
        var seen = Set<String>()
        var unique: [Flashcard] = []

        for card in flashcards {
            let key = "\(card.question.lowercased())|\(card.answer.lowercased())"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(card)
            }
        }

        return unique
    }

    // MARK: - Interactive Clarification

    /// Generate a clarification/explanation for a flashcard using on-device AI
    /// - Parameters:
    ///   - flashcard: The flashcard to clarify
    ///   - userQuestion: The user's specific question
    /// - Returns: AI-generated explanation
    func clarifyFlashcard(_ flashcard: Flashcard, userQuestion: String) async throws -> String {
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        flashcardLog.info("Generating clarification for flashcard")

        // TODO: Replace with actual Foundation Models API
        // Example:
        //
        // let model = SystemLanguageModel.default
        // guard model.isAvailable else { throw FMError.modelUnavailable }
        //
        // let session = LanguageModelSession()
        //
        // let systemPrompt = """
        //     You are a helpful tutor assistant.
        //     Explain flashcard answers clearly and concisely.
        //     Use simple terms and provide context when helpful.
        //     """
        //
        // let contextPrompt = """
        //     Flashcard Q: \(flashcard.question)
        //     Flashcard A: \(flashcard.answer)
        //
        //     User asks: \(userQuestion)
        //
        //     Provide a clear explanation:
        //     """
        //
        // let request = LanguageModelRequest(
        //     systemPrompt: systemPrompt,
        //     userPrompt: contextPrompt,
        //     temperature: 0.7,
        //     maxTokens: 150
        // )
        //
        // let response = try await session.respond(to: request)
        // return response.text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Placeholder implementation
        return try await clarifyFlashcardPlaceholder(flashcard, userQuestion: userQuestion)
    }

    private func clarifyFlashcardPlaceholder(_ flashcard: Flashcard, userQuestion: String) async throws -> String {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        let explanations = [
            "This flashcard helps you remember key information from your journal entry. The answer '\(flashcard.answer)' is important because it's a central detail you recorded.",
            "The question '\(flashcard.question)' is designed to test your recall of '\(flashcard.answer)', which was mentioned in your notes.",
            "Understanding '\(flashcard.answer)' in context with '\(flashcard.question)' helps reinforce the concepts you've been learning about."
        ]

        return explanations.randomElement() ?? explanations[0]
    }

    // MARK: - Helper Data

    private var commonWords: Set<String> {
        Set([
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "is", "was", "are", "were", "been", "be", "have", "has",
            "had", "do", "does", "did", "will", "would", "could", "should", "may",
            "might", "can", "i", "you", "we", "they", "my", "your", "our", "their",
            "this", "that", "these", "those", "it", "its", "from", "by", "about"
        ])
    }
}
