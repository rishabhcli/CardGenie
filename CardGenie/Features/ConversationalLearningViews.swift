//
//  ConversationalLearningViews.swift
//  CardGenie
//
//  Conversational learning UI: Socratic tutor, Explain-to-AI, Debate mode.
//  All processing on-device using Foundation Models.
//

import SwiftUI
import SwiftData

// MARK: - Conversational Mode Selection

struct ConversationalLearningView: View {
    @Environment(\.modelContext) private var modelContext
    let flashcardSet: FlashcardSet

    var body: some View {
        List {
            Section {
                NavigationLink {
                    SocraticTutorView(flashcardSet: flashcardSet)
                } label: {
                    ConversationalModeRow(mode: .socratic)
                }

                NavigationLink {
                    ExplainToMeView(flashcardSet: flashcardSet)
                } label: {
                    ConversationalModeRow(mode: .explainToMe)
                }

                NavigationLink {
                    DebateModeView(flashcardSet: flashcardSet)
                } label: {
                    ConversationalModeRow(mode: .debate)
                }
            } header: {
                Text("Choose Learning Mode")
            } footer: {
                Text("Interactive AI tutoring powered by on-device intelligence.")
            }
        }
        .navigationTitle("Conversational Learning")
    }
}

struct ConversationalModeRow: View {
    let mode: ConversationalMode

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: mode.icon)
                .font(.system(size: 24))
                .foregroundStyle(Color.cosmicPurple)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(mode.displayName)
                    .font(.headline)

                Text(mode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Socratic Tutor View

struct SocraticTutorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = ConversationalEngine()

    let flashcardSet: FlashcardSet

    @State private var selectedCard: Flashcard?
    @State private var session: ConversationalSession?
    @State private var currentAnswer = ""
    @State private var currentQuestion: SocraticQuestion?
    @State private var isGenerating = false
    @State private var showingHint = false
    @State private var currentHintIndex = 0
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if let card = selectedCard, let session = session {
                // Chat interface
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            // Display messages
                            ForEach(session.messages, id: \.id) { message in
                                MessageBubble(message: message)
                            }

                            // Current AI question
                            if let question = currentQuestion {
                                QuestionCard(question: question, onHint: {
                                    showingHint = true
                                })
                            }

                            // Error display
                            if let error = errorMessage {
                                ErrorBanner(message: error, onDismiss: {
                                    errorMessage = nil
                                })
                            }
                        }
                        .padding()
                    }
                }

                // Input area
                VStack(spacing: 12) {
                    TextField("Your answer...", text: $currentAnswer, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)

                    Button {
                        submitAnswer()
                    } label: {
                        if isGenerating {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Submit")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentAnswer.isEmpty || isGenerating)
                }
                .padding()
                .background(Color(.systemGray6))
            } else {
                // Card selection
                List(flashcardSet.cards, id: \.id) { card in
                    Button {
                        startSession(with: card)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.question)
                                .font(.headline)
                            Text(card.answer)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .navigationTitle("Socratic Tutor")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Hint", isPresented: $showingHint) {
            Button("OK") {}
        } message: {
            if let question = currentQuestion, currentHintIndex < question.hints.count {
                Text(question.hints[currentHintIndex])
            }
        }
    }

    func startSession(with card: Flashcard) {
        selectedCard = card
        let newSession = engine.createSession(flashcardID: card.id, mode: .socratic)
        session = newSession
        modelContext.insert(newSession)

        Task {
            await generateInitialQuestion(card: card)
        }
    }

    func generateInitialQuestion(card: Flashcard) async {
        isGenerating = true
        do {
            let question = try await engine.generateSocraticQuestion(
                for: card,
                userAnswer: "",
                conversationHistory: []
            )
            currentQuestion = question
            session?.addMessage(role: .ai, content: question.question)
        } catch {
            errorMessage = "Failed to generate question: \(error.localizedDescription)"
        }
        isGenerating = false
    }

    func submitAnswer() {
        guard let card = selectedCard, !currentAnswer.isEmpty else { return }

        session?.addMessage(role: .user, content: currentAnswer)

        Task {
            isGenerating = true
            do {
                let history = session?.messages.map { $0.content } ?? []
                let question = try await engine.generateSocraticQuestion(
                    for: card,
                    userAnswer: currentAnswer,
                    conversationHistory: history
                )
                currentQuestion = question
                session?.addMessage(role: .ai, content: question.question)
                currentAnswer = ""
            } catch {
                errorMessage = "Failed to process answer: \(error.localizedDescription)"
            }
            isGenerating = false
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            Text(message.content)
                .padding()
                .background(message.role == .ai ? Color(.systemGray5) : Color.cosmicPurple)
                .foregroundStyle(message.role == .ai ? .primary : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if message.role == .ai { Spacer() }
        }
    }
}

struct QuestionCard: View {
    let question: SocraticQuestion
    let onHint: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(question.category.displayName, systemImage: question.category.icon)
                    .font(.caption.bold())
                    .foregroundStyle(Color.cosmicPurple)

                Spacer()

                Button {
                    onHint()
                } label: {
                    Label("Hint", systemImage: "lightbulb")
                        .font(.caption)
                }
            }

            Text(question.question)
                .font(.body)
        }
        .padding()
        .background(Color.cosmicPurple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Explain-to-Me View

struct ExplainToMeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var engine = ConversationalEngine()

    let flashcardSet: FlashcardSet

    @State private var selectedCard: Flashcard?
    @State private var explanation = ""
    @State private var evaluation: ExplanationEvaluation?
    @State private var isEvaluating = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let card = selectedCard {
                    VStack(spacing: 16) {
                        Text("Explain this concept")
                            .font(.title2.bold())

                        Text(card.question)
                            .font(.title3)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        TextEditor(text: $explanation)
                            .frame(minHeight: 200)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        if let error = errorMessage {
                            ErrorBanner(message: error, onDismiss: {
                                errorMessage = nil
                            })
                        }

                        if let eval = evaluation {
                            ExplanationEvaluationCard(evaluation: eval)
                        } else {
                            Button("Get Feedback") {
                                evaluateExplanation()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(explanation.isEmpty || isEvaluating)
                        }
                    }
                } else {
                    List(flashcardSet.cards, id: \.id) { card in
                        Button {
                            selectedCard = card
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.question)
                                    .font(.headline)
                                Text(card.answer)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Explain to AI")
        .navigationBarTitleDisplayMode(.inline)
    }

    func evaluateExplanation() {
        guard let card = selectedCard else { return }
        isEvaluating = true

        Task {
            do {
                evaluation = try await engine.evaluateExplanation(flashcard: card, userExplanation: explanation)
            } catch {
                errorMessage = "Failed to evaluate explanation: \(error.localizedDescription)"
            }
            isEvaluating = false
        }
    }
}

struct ExplanationEvaluationCard: View {
    let evaluation: ExplanationEvaluation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ScoreIndicator(label: "Complete", score: evaluation.completeness, total: 5)
                Spacer()
                ScoreIndicator(label: "Clear", score: evaluation.clarity, total: 5)
            }

            Divider()

            if !evaluation.missingAreas.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Topics to Add", systemImage: "plus.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.headline)

                    ForEach(evaluation.missingAreas, id: \.self) { area in
                        Text("• \(area)")
                            .font(.caption)
                    }
                }
            }

            if !evaluation.clarifyingQuestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Think About", systemImage: "questionmark.circle.fill")
                        .foregroundStyle(Color.cosmicPurple)
                        .font(.headline)

                    ForEach(evaluation.clarifyingQuestions, id: \.self) { question in
                        Text("• \(question)")
                            .font(.caption)
                    }
                }
            }

            Text(evaluation.encouragement)
                .font(.body)
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ScoreIndicator: View {
    let label: String
    let score: Int
    let total: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { index in
                    Circle()
                        .fill(index < score ? Color.cosmicPurple : Color(.systemGray4))
                        .frame(width: 8, height: 8)
                }
            }

            Text("\(score)/\(total)")
                .font(.caption2.bold())
        }
    }
}

// MARK: - Debate Mode View

struct DebateModeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var engine = ConversationalEngine()

    let flashcardSet: FlashcardSet

    @State private var selectedCard: Flashcard?
    @State private var userPosition = ""
    @State private var aiArgument: DebateArgument?
    @State private var isGenerating = false
    @State private var responses: [(String, DebateArgument)] = []
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let card = selectedCard {
                    VStack(spacing: 16) {
                        Text("Debate: \(card.question)")
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)

                        // Conversation history
                        ForEach(responses.indices, id: \.self) { index in
                            let (position, argument) = responses[index]

                            VStack(alignment: .leading, spacing: 12) {
                                // User position
                                HStack {
                                    Spacer()
                                    Text(position)
                                        .padding()
                                        .background(Color.cosmicPurple)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                // AI counterargument
                                DebateArgumentCard(argument: argument)
                            }
                        }

                        // Error display
                        if let error = errorMessage {
                            ErrorBanner(message: error, onDismiss: {
                                errorMessage = nil
                            })
                        }

                        // Current input
                        if aiArgument == nil {
                            VStack(spacing: 12) {
                                TextEditor(text: $userPosition)
                                    .frame(minHeight: 100)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                Button("Present Position") {
                                    presentPosition()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(userPosition.isEmpty || isGenerating)
                            }
                        } else if let argument = aiArgument {
                            VStack(spacing: 12) {
                                DebateArgumentCard(argument: argument)

                                Button("Respond to Challenge") {
                                    aiArgument = nil
                                    userPosition = ""
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                } else {
                    List(flashcardSet.cards, id: \.id) { card in
                        Button {
                            selectedCard = card
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.question)
                                    .font(.headline)
                                Text(card.answer)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Debate Mode")
        .navigationBarTitleDisplayMode(.inline)
    }

    func presentPosition() {
        guard let card = selectedCard, !userPosition.isEmpty else { return }
        isGenerating = true

        Task {
            do {
                let argument = try await engine.generateDebateArgument(
                    topic: card.question,
                    userPosition: userPosition
                )
                responses.append((userPosition, argument))
                aiArgument = argument
            } catch {
                errorMessage = "Failed to generate counterargument: \(error.localizedDescription)"
            }
            isGenerating = false
        }
    }
}

struct DebateArgumentCard: View {
    let argument: DebateArgument

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI Counterargument", systemImage: "person.2.badge.gearshape")
                .font(.caption.bold())
                .foregroundStyle(.orange)

            Text(argument.counterpoint)
                .font(.body)

            VStack(alignment: .leading, spacing: 8) {
                Text("Reasoning:")
                    .font(.caption.bold())
                Text(argument.reasoning)
                    .font(.caption)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                Text("Challenge:")
                    .font(.caption.bold())
                Text(argument.challenge)
                    .font(.caption)
                    .italic()
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
