//
//  FlashcardFM.swift
//  CardGenie
//
//  AI-powered flashcard generation and clarification using Apple's Foundation Models.
//  All processing happens on-device via the Neural Engine.
//

import Foundation
import OSLog
import FoundationModels

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

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            flashcardLog.error("Model not available for entity extraction")
            throw FMError.modelUnavailable
        }

        flashcardLog.info("Extracting entities and topics...")

        do {
            let instructions = """
                Extract important entities (names, places, dates, key terms) from the text.
                Also identify the main topic category (e.g., Travel, Work, Health, History, Learning).
                Focus on terms that would be valuable for creating flashcards.
                """

            let session = LanguageModelSession(instructions: instructions)

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.2
            )

            let response = try await session.respond(
                to: "Extract entities and topic from this text:\n\n\(text)",
                generating: EntityExtractionResult.self,
                options: options
            )

            let entities = response.content.entities
            let topic = response.content.topicTag

            flashcardLog.info("Extracted \(entities.count) entities with topic: \(topic)")
            return (entities, topic)

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            flashcardLog.error("Guardrail violation during entity extraction")
            throw FMError.processingFailed
        } catch LanguageModelSession.GenerationError.refusal {
            flashcardLog.error("Model refused entity extraction request")
            throw FMError.processingFailed
        } catch {
            flashcardLog.error("Entity extraction failed: \(error.localizedDescription)")
            throw FMError.processingFailed
        }
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
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        flashcardLog.info("Generating cloze deletion cards...")

        do {
            let instructions = """
                Create cloze deletion flashcards from the text.
                A cloze card has a sentence with an important term replaced by ______.
                Choose sentences that contain key concepts, names, dates, or important details.
                Replace the most important term in each sentence with ______.
                """

            let session = LanguageModelSession(instructions: instructions)

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.3
            )

            let entityList = entities.joined(separator: ", ")
            let prompt = """
                Create \(maxCards) cloze deletion flashcards from this text.
                Focus on these key entities: \(entityList)

                Text:
                \(text)
                """

            let response = try await session.respond(
                to: prompt,
                generating: ClozeCardBatch.self,
                options: options
            )

            let flashcards = response.content.cards.map { clozeCard in
                clozeCard.toFlashcard(linkedEntryID: linkedEntryID, tags: [topicTag])
            }

            flashcardLog.info("Generated \(flashcards.count) cloze cards")
            return flashcards

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            flashcardLog.error("Guardrail violation during cloze generation")
            return []
        } catch LanguageModelSession.GenerationError.refusal {
            flashcardLog.warning("Model refused cloze generation request")
            return []
        } catch {
            flashcardLog.error("Cloze generation failed: \(error.localizedDescription)")
            return []
        }
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

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        flashcardLog.info("Generating Q&A cards...")

        do {
            let instructions = """
                Create question-and-answer flashcards from the text.
                Each Q&A should focus on a specific fact, detail, or concept.
                Questions should be clear and specific.
                Answers should be concise and factual.
                """

            let session = LanguageModelSession(instructions: instructions)

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.3
            )

            let prompt = """
                Create \(maxCards) question-and-answer flashcards from this text:

                \(text)
                """

            let response = try await session.respond(
                to: prompt,
                generating: QACardBatch.self,
                options: options
            )

            let flashcards = response.content.cards.map { qaCard in
                qaCard.toFlashcard(linkedEntryID: linkedEntryID, tags: [topicTag])
            }

            flashcardLog.info("Generated \(flashcards.count) Q&A cards")
            return flashcards

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            flashcardLog.error("Guardrail violation during Q&A generation")
            return []
        } catch LanguageModelSession.GenerationError.refusal {
            flashcardLog.warning("Model refused Q&A generation request")
            return []
        } catch {
            flashcardLog.error("Q&A generation failed: \(error.localizedDescription)")
            return []
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
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        flashcardLog.info("Generating definition cards...")

        do {
            let instructions = """
                Create term-definition flashcards from the text.
                Each card should define a key term, concept, or entity based on the context.
                Definitions should be concise (1-2 sentences) and based only on information in the text.
                """

            let session = LanguageModelSession(instructions: instructions)

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.3
            )

            let entityList = entities.joined(separator: ", ")
            let prompt = """
                Create \(maxCards) term-definition flashcards from this text.
                Focus on these key entities: \(entityList)

                Text:
                \(text)
                """

            let response = try await session.respond(
                to: prompt,
                generating: DefinitionCardBatch.self,
                options: options
            )

            let flashcards = response.content.cards.map { defCard in
                defCard.toFlashcard(linkedEntryID: linkedEntryID, tags: [topicTag])
            }

            flashcardLog.info("Generated \(flashcards.count) definition cards")
            return flashcards

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            flashcardLog.error("Guardrail violation during definition generation")
            return []
        } catch LanguageModelSession.GenerationError.refusal {
            flashcardLog.warning("Model refused definition generation request")
            return []
        } catch {
            flashcardLog.error("Definition generation failed: \(error.localizedDescription)")
            return []
        }
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

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            flashcardLog.error("Model not available for clarification")
            throw FMError.modelUnavailable
        }

        flashcardLog.info("Generating clarification for flashcard")

        do {
            let instructions = """
                You are a helpful tutor assistant.
                Explain flashcard answers clearly and concisely.
                Use simple terms and provide context when helpful.
                Keep explanations to 2-3 sentences.
                ALWAYS be respectful and supportive.
                """

            let session = LanguageModelSession(instructions: instructions)

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.7
            )

            let prompt = """
                Flashcard Question: \(flashcard.question)
                Flashcard Answer: \(flashcard.answer)

                User asks: \(userQuestion)

                Provide a clear explanation:
                """

            let response = try await session.respond(
                to: prompt,
                options: options
            )

            let explanation = response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            flashcardLog.info("Clarification generated")
            return explanation

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            flashcardLog.error("Guardrail violation during clarification")
            throw FMError.processingFailed
        } catch {
            flashcardLog.error("Clarification failed: \(error.localizedDescription)")
            throw FMError.processingFailed
        }
    }
}
