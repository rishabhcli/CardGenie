//
//  ScanAnalysisModels.swift
//  CardGenie
//
//  @Generable models for structured AI output from Foundation Models.
//  Used for scan analysis and action suggestions.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Academic Subject Category

@Generable
enum AcademicSubject: String {
    case math = "Math"
    case science = "Science"
    case history = "History"
    case language = "Language"
    case literature = "Literature"
    case computerScience = "Computer Science"
    case business = "Business"
    case medicine = "Medicine"
    case engineering = "Engineering"
    case other = "Other"
}

// MARK: - Material Difficulty Level

@Generable
enum MaterialDifficulty: String {
    case elementary = "Elementary"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

// MARK: - Scan Analysis

/// AI analysis result for scanned study material
@Generable
struct ScanAnalysis {
    @Guide(description: "Brief summary of the scanned content in 1-2 sentences")
    var summary: String

    @Guide(description: "Main topics or subjects detected (1-5 topics)", .count(1...5))
    var topics: [String]

    @Guide(description: "Academic subject category - choose the most relevant")
    var subject: AcademicSubject

    @Guide(description: "Suggested number of flashcards to generate based on content density (0-20)", .range(0...20))
    var suggestedFlashcardCount: Int

    @Guide(description: "Key concepts or terms that should be studied (0-10 terms)", .count(0...10))
    var keyTerms: [String]

    @Guide(description: "Difficulty level of the material based on complexity and prerequisites")
    var difficultyLevel: MaterialDifficulty

    @Guide(description: "Suggested next actions for the student (1-3 actions)", .count(1...3))
    var suggestedActions: [String]
}

// MARK: - Chat Response with Actions

/// Conversational response with embedded action suggestions
@Generable
struct ChatResponseWithActions {
    @Guide(description: "The conversational response to the student's message (keep natural and concise)")
    var response: String

    @Guide(description: "Suggested quick actions the student can take (0-3 actions)", .count(0...3))
    var suggestedActions: [ActionSuggestion]
}

// MARK: - Action Type Enum

@Generable
enum ActionType: String {
    case generateFlashcards = "generate_flashcards"
    case summarize = "summarize"
    case explainConcept = "explain_concept"
    case quizMe = "quiz_me"
    case createNotes = "create_notes"
    case compareScans = "compare_scans"
    case extractKeyPoints = "extract_key_points"
}

/// A single action suggestion
@Generable
struct ActionSuggestion {
    @Guide(description: "Type of action to perform")
    var type: ActionType

    @Guide(description: "Short title for the action button (max 3 words)")
    var title: String

    @Guide(description: "Brief description of what this action will do (one sentence)")
    var description: String
}

#endif

// MARK: - Fallback Types (when Foundation Models unavailable)

/// Fallback scan analysis for when AI is not available
struct FallbackScanAnalysis {
    var summary: String
    var topics: [String]
    var subject: AcademicSubject
    var suggestedFlashcardCount: Int
    var keyTerms: [String]
    var difficultyLevel: MaterialDifficulty
    var suggestedActions: [String]

    /// Create a basic analysis without AI
    static func fromText(_ text: String) -> FallbackScanAnalysis {
        // Simple keyword extraction
        let words = text.components(separatedBy: .whitespaces)
        let wordCount = words.count

        // Estimate flashcard count based on length
        let suggestedCount = min(max(wordCount / 50, 3), 15)

        return FallbackScanAnalysis(
            summary: "Scanned content extracted successfully. (\(wordCount) words)",
            topics: ["General"],
            subject: .other,
            suggestedFlashcardCount: suggestedCount,
            keyTerms: [],
            difficultyLevel: .intermediate,
            suggestedActions: ["Generate flashcards", "Summarize content", "Quiz yourself"]
        )
    }
}
