//
//  ConversationalModels.swift
//  CardGenie
//
//  Conversational learning models for Socratic tutoring, misconception detection,
//  debate mode, and explain-to-me evaluation. All AI-powered with @Generable.
//

import Foundation
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Socratic Tutor Models

#if canImport(FoundationModels)
@Generable
struct SocraticQuestion: Equatable {
    @Guide(description: "A probing question that helps the user think deeper about the concept")
    let question: String

    @Guide(description: "The reasoning category: clarification, assumption, evidence, perspective, or implication")
    let category: QuestionCategory

    @Guide(description: "2-3 progressive hints if the user gets stuck")
    @Guide(.count(2...3))
    let hints: [String]
}

@Generable
enum QuestionCategory: String {
    case clarification  // "What do you mean by...?"
    case assumption     // "What are we assuming here?"
    case evidence       // "What evidence supports this?"
    case perspective    // "How would someone else view this?"
    case implication    // "What are the consequences?"
}
#else
struct SocraticQuestion: Equatable {
    let question: String
    let category: QuestionCategory
    let hints: [String]
}

enum QuestionCategory: String, Equatable {
    case clarification
    case assumption
    case evidence
    case perspective
    case implication
}
#endif

// MARK: - Misconception Detection

#if canImport(FoundationModels)
@Generable
struct MisconceptionAnalysis: Equatable {
    @Guide(description: "Did the user's answer reveal a misconception?")
    let hasMisconception: Bool

    @Guide(description: "The specific misconception detected (empty string if none)")
    let misconception: String

    @Guide(description: "The correct understanding of the concept")
    let correctConcept: String

    @Guide(description: "Gentle, constructive explanation to correct the misunderstanding")
    let explanation: String
}
#else
struct MisconceptionAnalysis: Equatable {
    let hasMisconception: Bool
    let misconception: String
    let correctConcept: String
    let explanation: String
}
#endif

// MARK: - Debate Partner

#if canImport(FoundationModels)
@Generable
struct DebateArgument: Equatable {
    @Guide(description: "Counterargument from the opposite perspective")
    let counterpoint: String

    @Guide(description: "Evidence or reasoning supporting the counterpoint")
    let reasoning: String

    @Guide(description: "Challenge question to test the user's position")
    let challenge: String
}
#else
struct DebateArgument: Equatable {
    let counterpoint: String
    let reasoning: String
    let challenge: String
}
#endif

// MARK: - Explain-to-Me Evaluation

#if canImport(FoundationModels)
@Generable
struct ExplanationEvaluation: Equatable {
    @Guide(description: "Completeness score from 1 (incomplete) to 5 (comprehensive)")
    @Guide(.range(1...5))
    let completeness: Int

    @Guide(description: "Clarity score from 1 (confusing) to 5 (crystal clear)")
    @Guide(.range(1...5))
    let clarity: Int

    @Guide(description: "1-3 areas or topics that need more explanation")
    @Guide(.count(1...3))
    let missingAreas: [String]

    @Guide(description: "2-4 clarifying questions to help the user elaborate on missing areas")
    @Guide(.count(2...4))
    let clarifyingQuestions: [String]

    @Guide(description: "Encouraging feedback about what the user explained well")
    let encouragement: String
}
#else
struct ExplanationEvaluation: Equatable {
    let completeness: Int
    let clarity: Int
    let missingAreas: [String]
    let clarifyingQuestions: [String]
    let encouragement: String
}
#endif

// MARK: - Conversational Session Tracking

@Model
final class ConversationalSession {
    @Attribute(.unique) var id: UUID
    var flashcardID: UUID
    var mode: ConversationalMode
    var startTime: Date
    var endTime: Date?
    var turnCount: Int
    
    @Relationship(deleteRule: .cascade)
    var messages: [ChatMessage] = []

    init(flashcardID: UUID, mode: ConversationalMode) {
        self.id = UUID()
        self.flashcardID = flashcardID
        self.mode = mode
        self.startTime = Date()
        self.endTime = nil
        self.turnCount = 0
        self.messages = []
    }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    func addMessage(role: MessageRole, content: String) {
        let message = ChatMessage(role: role, content: content)
        messages.append(message)
        turnCount += 1
    }
}

enum ConversationalMode: String, Codable {
    case socratic = "socratic"
    case explainToMe = "explainToMe"
    case debate = "debate"
}

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date

    init(role: MessageRole = .user, content: String = "") {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

enum MessageRole: String, Codable, Hashable {
    case user = "user"
    case ai = "ai"
    case system = "system"
}

// MARK: - Display Helpers

extension QuestionCategory {
    var displayName: String {
        switch self {
        case .clarification: return "Clarification"
        case .assumption: return "Assumption Check"
        case .evidence: return "Evidence Seeking"
        case .perspective: return "Perspective Taking"
        case .implication: return "Implication Analysis"
        }
    }

    var icon: String {
        switch self {
        case .clarification: return "questionmark.circle"
        case .assumption: return "exclamationmark.triangle"
        case .evidence: return "doc.text.magnifyingglass"
        case .perspective: return "person.2"
        case .implication: return "arrow.triangle.branch"
        }
    }
}

extension ConversationalMode {
    var displayName: String {
        switch self {
        case .socratic: return "Socratic Tutor"
        case .explainToMe: return "Explain to AI"
        case .debate: return "Debate Mode"
        }
    }

    var icon: String {
        switch self {
        case .socratic: return "brain.head.profile"
        case .explainToMe: return "person.wave.2"
        case .debate: return "person.2.badge.gearshape"
        }
    }

    var description: String {
        switch self {
        case .socratic:
            return "AI asks probing questions to guide your thinking"
        case .explainToMe:
            return "You teach the AI, it asks clarifying questions"
        case .debate:
            return "AI argues the opposite position to test your understanding"
        }
    }
}
