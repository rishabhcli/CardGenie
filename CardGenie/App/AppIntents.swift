//
//  AppIntents.swift
//  CardGenie
//
//  App Intents for Siri Shortcuts integration
//

import AppIntents
import SwiftUI
import SwiftData

// MARK: - App Shortcut Provider

struct CardGenieShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartStudySessionIntent(),
            phrases: [
                "Start studying with \(.applicationName)",
                "Begin flashcard review in \(.applicationName)",
                "Study flashcards in \(.applicationName)"
            ],
            shortTitle: "Start Study Session",
            systemImageName: "brain.fill"
        )
        
        AppShortcut(
            intent: AskStudyQuestionIntent(),
            phrases: [
                "Ask \(.applicationName) a question",
                "Get study help from \(.applicationName)",
                "Ask a study question in \(.applicationName)"
            ],
            shortTitle: "Ask Study Question",
            systemImageName: "bubble.left.and.text.bubble.right.fill"
        )
    }
}

// MARK: - Start Study Session Intent

struct StartStudySessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Study Session"
    static var description = IntentDescription("Opens CardGenie and starts a flashcard study session with due cards")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Post notification to trigger study session
        NotificationCenter.default.post(
            name: NSNotification.Name("StartStudySession"),
            object: nil
        )

        return .result(dialog: "Starting your study session with due flashcards")
    }
}

// MARK: - Ask Study Question Intent

struct AskStudyQuestionIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Study Question"
    static var description = IntentDescription("Opens CardGenie's AI chat to ask a study-related question")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Question", description: "The question you want to ask")
    var question: String?

    @MainActor
    func perform() async throws -> some IntentResult {
        if let question = question {
            // Post notification with question
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenAIChatWithQuestion"),
                object: nil,
                userInfo: ["question": question]
            )
            return .result(dialog: "Opening AI chat with your question")
        } else {
            // Just open AI chat
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenAIChat"),
                object: nil
            )
            return .result(dialog: "Opening AI chat")
        }
    }
}

// MARK: - Get Due Cards Count Intent

struct GetDueCardsCountIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Due Cards Count"
    static var description = IntentDescription("Returns the number of flashcards due for review")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let count = await getDueCardsCount()

        let message = if count == 0 {
            "You have no flashcards due for review"
        } else if count == 1 {
            "You have 1 flashcard due for review"
        } else {
            "You have \(count) flashcards due for review"
        }

        return .result(value: count, dialog: IntentDialog(stringLiteral: message))
    }

    private func getDueCardsCount() async -> Int {
        do {
            let container = try await getModelContainer()
            let context = ModelContext(container)
            
            let now = Date.now

            let descriptor = FetchDescriptor<Flashcard>(
                predicate: #Predicate { flashcard in
                    flashcard.nextReviewDate <= now
                }
            )

            let results = try context.fetch(descriptor)
            return results.count
        } catch {
            print("Failed to fetch due cards: \(error)")
            return 0
        }
    }

    private func getModelContainer() async throws -> ModelContainer {
        let schema = Schema([
            StudyContent.self,
            Flashcard.self,
            FlashcardSet.self,
            SourceDocument.self,
            NoteChunk.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
}

// MARK: - Generate Flashcards Intent

struct GenerateFlashcardsIntent: AppIntent {
    static var title: LocalizedStringResource = "Generate Flashcards"
    static var description = IntentDescription("Generate flashcards from text using AI")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Text", description: "The text to generate flashcards from")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult {
        // Post notification with text
        NotificationCenter.default.post(
            name: NSNotification.Name("GenerateFlashcardsFromText"),
            object: nil,
            userInfo: ["text": text]
        )

        return .result(dialog: "Generating flashcards from your text")
    }
}

// MARK: - Quick Add Flashcard Intent

struct QuickAddFlashcardIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Flashcard"
    static var description = IntentDescription("Quickly add a new flashcard")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Front", description: "The question or prompt")
    var front: String

    @Parameter(title: "Back", description: "The answer")
    var back: String

    @MainActor
    func perform() async throws -> some IntentResult {
        do {
            let container = try await getModelContainer()
            let context = ModelContext(container)

            // Create minimal StudyContent to back-link this quick add
            let content = StudyContent(text: front + "\n" + back)
            context.insert(content)

            // Create a simple Q&A flashcard matching the model initializer
            let flashcard = Flashcard(
                type: .qa,
                question: front,
                answer: back,
                linkedEntryID: content.id,
                tags: []
            )

            context.insert(flashcard)
            try context.save()

            return .result(dialog: "Flashcard added successfully")
        } catch {
            throw AppIntentError.failedToAddFlashcard
        }
    }

    private func getModelContainer() async throws -> ModelContainer {
        let schema = Schema([
            StudyContent.self,
            Flashcard.self,
            FlashcardSet.self,
            SourceDocument.self,
            NoteChunk.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
}

// MARK: - Custom Errors

enum AppIntentError: Error, CustomLocalizedStringResourceConvertible {
    case failedToAddFlashcard
    case failedToGenerateFlashcards
    case noDataAvailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .failedToAddFlashcard:
            return "Failed to add flashcard"
        case .failedToGenerateFlashcards:
            return "Failed to generate flashcards"
        case .noDataAvailable:
            return "No data available"
        }
    }
}
