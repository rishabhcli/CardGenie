//
//  FlashcardGenerationModels.swift
//  CardGenie
//
//  Guided generation models for Apple Intelligence flashcard creation.
//  Uses @Generable for structured, reliable output from Foundation Models.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Entity Extraction

#if canImport(FoundationModels)
@Generable
struct EntityExtractionResult: Equatable {
    @Guide(description: "Important entities like names, places, dates, and key terms from the text.")
    @Guide(.count(3...10))
    let entities: [String]

    @Guide(description: "The main topic category (e.g., Travel, Work, Health, History, Learning).")
    let topicTag: String
}

// MARK: - Flashcard Generation

@Generable
struct GeneratedFlashcards: Equatable {
    @Guide(description: "A list of flashcards generated from the journal entry.")
    @Guide(.count(1...5))
    let cards: [GeneratedFlashcard]
}

@Generable
struct GeneratedFlashcard: Equatable {
    @Guide(description: "The type of flashcard: cloze, qa, or definition.")
    let type: FlashcardTypeEnum

    @Guide(description: "The question or prompt. For cloze cards, use ______ as the blank.")
    let question: String

    @Guide(description: "The answer or missing term.")
    let answer: String
}

@Generable
enum FlashcardTypeEnum {
    case cloze
    case qa
    case definition
}

// MARK: - Cloze Card Generation

@Generable
struct ClozeCardBatch: Equatable {
    @Guide(description: "A list of cloze deletion flashcards.")
    @Guide(.count(1...3))
    let cards: [ClozeCard]
}

@Generable
struct ClozeCard: Equatable {
    @Guide(description: "A sentence from the text with an important term replaced by ______")
    let sentence: String

    @Guide(description: "The missing term that fills the blank.")
    let answer: String
}

// MARK: - Q&A Card Generation

@Generable
struct QACardBatch: Equatable {
    @Guide(description: "A list of question and answer flashcards.")
    @Guide(.count(1...3))
    let cards: [QACard]
}

@Generable
struct QACard: Equatable {
    @Guide(description: "A specific question about a fact or detail from the text.")
    let question: String

    @Guide(description: "The factual answer to the question.")
    let answer: String
}

// MARK: - Definition Card Generation

@Generable
struct DefinitionCardBatch: Equatable {
    @Guide(description: "A list of term-definition flashcards.")
    @Guide(.count(1...3))
    let cards: [DefinitionCard]
}

@Generable
struct DefinitionCard: Equatable {
    @Guide(description: "The term or concept to be defined.")
    let term: String

    @Guide(description: "A concise definition or explanation of the term based on the context.")
    let definition: String
}

// MARK: - Quiz Generation

@Generable
struct QuizBatch: Equatable {
    @Guide(description: "A list of quiz questions mixing multiple formats.")
    @Guide(.count(1...10))
    let items: [QuizItem]
}

@Generable
struct QuizItem: Equatable {
    @Guide(description: "Question format: mcq, cloze, or shortAnswer.")
    let type: QuizTypeEnum

    @Guide(description: "The quiz question prompt.")
    let question: String

    @Guide(description: "The correct answer or completion.")
    let correctAnswer: String

    @Guide(description: "Incorrect options for multiple choice questions.")
    @Guide(.count(0...3))
    let distractors: [String]

    @Guide(description: "Difficulty rating from 1 (easy) to 5 (hard).")
    let difficulty: Int

    @Guide(description: "Explanation reinforcing the correct answer.")
    let explanation: String
}

@Generable
enum QuizTypeEnum {
    case mcq
    case cloze
    case shortAnswer
}

// MARK: - Journal Entry Tagging

@Generable
struct JournalTags: Equatable {
    @Guide(description: "Up to three short topic tags (1-2 words each). Examples: work, planning, travel")
    @Guide(.count(1...3))
    let tags: [String]
}

#else
struct EntityExtractionResult: Equatable {
    let entities: [String]
    let topicTag: String
}

struct GeneratedFlashcards: Equatable {
    let cards: [GeneratedFlashcard]
}

struct GeneratedFlashcard: Equatable {
    let type: FlashcardTypeEnum
    let question: String
    let answer: String
}

enum FlashcardTypeEnum {
    case cloze
    case qa
    case definition
}

struct ClozeCardBatch: Equatable {
    let cards: [ClozeCard]
}

struct ClozeCard: Equatable {
    let sentence: String
    let answer: String
}

struct QACardBatch: Equatable {
    let cards: [QACard]
}

struct QACard: Equatable {
    let question: String
    let answer: String
}

struct DefinitionCardBatch: Equatable {
    let cards: [DefinitionCard]
}

struct DefinitionCard: Equatable {
    let term: String
    let definition: String
}

struct JournalTags: Equatable {
    let tags: [String]
}

// MARK: - Quiz Generation (Fallback)

struct QuizItem: Equatable {
    let type: QuizTypeEnum
    let question: String
    let correctAnswer: String
    let distractors: [String]
    let difficulty: Int
    let explanation: String
}

enum QuizTypeEnum: Equatable {
    case mcq
    case cloze
    case shortAnswer
}

struct QuizBatch: Equatable {
    let items: [QuizItem]
}
#endif

// MARK: - Study Plan Generation

#if canImport(FoundationModels)
@Generable
struct GeneratedStudySession: Equatable {
    @Guide(description: "ISO 8601 date (YYYY-MM-DD) for the session.")
    let date: String

    @Guide(description: "Specific learning outcome the student should accomplish.")
    let goal: String

    @Guide(description: "2-4 concrete materials or activities for the session.")
    @Guide(.count(2...4))
    let materials: [String]

    @Guide(description: "Estimated duration in minutes (typically 30-45).")
    let estimatedMinutes: Int
}

@Generable
struct GeneratedStudyPlan: Equatable {
    @Guide(description: "Course or subject the plan is for.")
    let course: String

    @Guide(description: "Overall learning goal across the seven sessions.")
    let overallGoal: String

    @Guide(description: "Exactly seven study sessions with goals, materials, and estimates.")
    @Guide(.count(7...7))
    let sessions: [GeneratedStudySession]
}
#else
struct GeneratedStudySession: Equatable {
    let date: String
    let goal: String
    let materials: [String]
    let estimatedMinutes: Int
}

struct GeneratedStudyPlan: Equatable {
    let course: String
    let overallGoal: String
    let sessions: [GeneratedStudySession]
}
#endif


// MARK: - Conversion Helpers

extension FlashcardTypeEnum {
    var toFlashcardType: FlashcardType {
        switch self {
        case .cloze: return .cloze
        case .qa: return .qa
        case .definition: return .definition
        }
    }
}

extension GeneratedFlashcard {
    func toFlashcard(linkedEntryID: UUID, tags: [String]) -> Flashcard {
        Flashcard(
            type: type.toFlashcardType,
            question: question,
            answer: answer,
            linkedEntryID: linkedEntryID,
            tags: tags
        )
    }
}

extension ClozeCard {
    func toFlashcard(linkedEntryID: UUID, tags: [String]) -> Flashcard {
        Flashcard(
            type: .cloze,
            question: sentence,
            answer: answer,
            linkedEntryID: linkedEntryID,
            tags: tags
        )
    }
}

extension QACard {
    func toFlashcard(linkedEntryID: UUID, tags: [String]) -> Flashcard {
        Flashcard(
            type: .qa,
            question: question,
            answer: answer,
            linkedEntryID: linkedEntryID,
            tags: tags
        )
    }
}

extension DefinitionCard {
    func toFlashcard(linkedEntryID: UUID, tags: [String]) -> Flashcard {
        Flashcard(
            type: .definition,
            question: "What is \(term)?",
            answer: definition,
            linkedEntryID: linkedEntryID,
            tags: tags
        )
    }
}
