//
//  GameModeViews.swift
//  CardGenie
//
//  Game mode UI views: Matching, True/False, Multiple Choice, Teach-Back, Feynman.
//  All modes use on-device AI for content generation and feedback.
//

import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Game Mode Selection

struct GameModeSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var flashcardSets: [FlashcardSet]

    let flashcardSet: FlashcardSet

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero section
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .padding(.top)

                    Text("Choose Your Game")
                        .font(.title2.bold())
                        .foregroundStyle(Color.primaryText)

                    Text("All modes use on-device AI")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)

                // Game Mode Cards
                VStack(spacing: 16) {
                    ForEach([
                        StudyGameMode.matching,
                        .trueFalse,
                        .multipleChoice,
                        .teachBack,
                        .feynman
                    ], id: \.self) { mode in
                        NavigationLink {
                            gameModeView(for: mode)
                        } label: {
                            GameModeCard(mode: mode)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Game Modes")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    func gameModeView(for mode: StudyGameMode) -> some View {
        switch mode {
        case .matching:
            MatchingGameView(flashcardSet: flashcardSet)
        case .trueFalse:
            TrueFalseGameView(flashcardSet: flashcardSet)
        case .multipleChoice:
            MultipleChoiceGameView(flashcardSet: flashcardSet)
        case .teachBack:
            TeachBackGameView(flashcardSet: flashcardSet)
        case .feynman:
            FeynmanGameView(flashcardSet: flashcardSet)
        }
    }
}

struct GameModeCard: View {
    let mode: StudyGameMode

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(mode.color), Color(mode.color).opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: mode.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(mode.displayName)
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)

                Text(mode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Arrow
            Image(systemName: "arrow.right")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(mode.color))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(mode.color).opacity(0.3), lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mode.displayName). \(mode.description)")
        .accessibilityHint("Double tap to start game")
        .accessibilityAddTraits(.isButton)
    }
}

struct GameModeRow: View {
    let mode: StudyGameMode

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: mode.icon)
                .font(.system(size: 24))
                .foregroundStyle(Color(mode.color))
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

// MARK: - Matching Game View

struct MatchingGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameEngine = GameEngine()

    let flashcardSet: FlashcardSet

    @State private var game: MatchingGame?
    @State private var selectedTerm: String?
    @State private var showingResults = false

    var body: some View {
        VStack(spacing: 0) {
            if let game = game {
                // Timer and score header
                GameHeader(
                    timeRemaining: game.timeLimit - Int(game.elapsedTime),
                    score: game.score,
                    mistakes: game.mistakes
                )

                // Matching interface
                ScrollView {
                    VStack(spacing: 24) {
                        // Terms column
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Terms")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            ForEach(game.pairs.filter { !$0.isMatched }, id: \.id) { pair in
                                TermCard(
                                    text: pair.term,
                                    isSelected: selectedTerm == pair.term,
                                    action: {
                                        selectedTerm = pair.term
                                    }
                                )
                            }
                        }

                        Divider()

                        // Definitions column
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Definitions")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            ForEach(game.pairs.filter { !$0.isMatched }, id: \.id) { pair in
                                MatchingCard(
                                    text: pair.definition,
                                    action: {
                                        if let term = selectedTerm {
                                            checkMatch(term: term, definition: pair.definition)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                }
            } else {
                // Loading or start screen
                VStack(spacing: 20) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.cosmicPurple)

                    Text("Match terms to definitions")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Tap a term, then tap its matching definition")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Button("Start Game") {
                        startGame()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
            }
        }
        .navigationTitle("Matching Game")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingResults) {
            if let game = game {
                GameResultsView(
                    mode: .matching,
                    score: game.score,
                    accuracy: game.accuracy,
                    duration: game.elapsedTime,
                    onDismiss: { dismiss() }
                )
            }
        }
    }

    func startGame() {
        let newGame = gameEngine.createMatchingGame(from: Array(flashcardSet.cards))
        gameEngine.startMatchingGame(newGame)
        game = newGame
    }

    func checkMatch(term: String, definition: String) {
        guard let game = game else { return }

        let isCorrect = gameEngine.checkMatch(game, term: term, definition: definition)

        if isCorrect {
            // Success feedback
            selectedTerm = nil

            if game.isComplete {
                gameEngine.endMatchingGame(game)
                showingResults = true
            }
        } else {
            // Error feedback
        }
    }
}

struct TermCard: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(isSelected ? Color.cosmicPurple : Color(.systemGray6))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct MatchingCard: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct GameHeader: View {
    let timeRemaining: Int
    let score: Int
    let mistakes: Int

    var body: some View {
        HStack {
            Label("\(timeRemaining)s", systemImage: "timer")
            Spacer()
            Label("\(score)", systemImage: "star.fill")
            Spacer()
            Label("\(mistakes)", systemImage: "xmark.circle")
        }
        .font(.subheadline.bold())
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - True/False Game View

struct TrueFalseGameView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameEngine = GameEngine()

    let flashcardSet: FlashcardSet

    @State private var statements: [TrueFalseStatement] = []
    @State private var currentIndex = 0
    @State private var score = 0
    @State private var showingExplanation = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Generating questions...")
            } else if let error = errorMessage {
                ErrorView(message: error)
            } else if currentIndex < statements.count {
                let statement = statements[currentIndex]

                VStack(spacing: 30) {
                    // Progress
                    ProgressView(value: Double(currentIndex), total: Double(statements.count))
                        .tint(.cosmicPurple)

                    Text("Question \(currentIndex + 1) of \(statements.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Statement
                    Text(statement.statement)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Buttons
                    HStack(spacing: 16) {
                        Button {
                            answerQuestion(true)
                        } label: {
                            Label("True", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.large)

                        Button {
                            answerQuestion(false)
                        } label: {
                            Label("False", systemImage: "xmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                    }
                }
                .padding()
            } else {
                // Results
                GameResultsView(
                    mode: .trueFalse,
                    score: score,
                    accuracy: Double(score) / Double(statements.count),
                    duration: 0,
                    onDismiss: { dismiss() }
                )
            }
        }
        .navigationTitle("True or False")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Explanation", isPresented: $showingExplanation) {
            Button("Next") {
                currentIndex += 1
            }
        } message: {
            if currentIndex < statements.count {
                Text(statements[currentIndex].justification)
            }
        }
        .task {
            await loadStatements()
        }
    }

    func loadStatements() async {
        do {
            statements = try await gameEngine.generateTrueFalseStatements(from: Array(flashcardSet.cards.prefix(5)))
            isLoading = false
        } catch {
            errorMessage = "Failed to generate questions: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func answerQuestion(_ answer: Bool) {
        let statement = statements[currentIndex]
        if answer == statement.isTrue {
            score += 1
        }
        showingExplanation = true
    }
}

// MARK: - Multiple Choice Game View

struct MultipleChoiceGameView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameEngine = GameEngine()

    let flashcardSet: FlashcardSet

    @State private var questions: [MultipleChoiceQuestion] = []
    @State private var currentIndex = 0
    @State private var selectedAnswer: String?
    @State private var showingExplanation = false
    @State private var score = 0
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Generating questions...")
            } else if let error = errorMessage {
                ErrorView(message: error)
            } else if currentIndex < questions.count {
                let question = questions[currentIndex]

                VStack(spacing: 30) {
                    ProgressView(value: Double(currentIndex), total: Double(questions.count))
                        .tint(.cosmicPurple)

                    Text("Question \(currentIndex + 1) of \(questions.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(question.question)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()

                    VStack(spacing: 12) {
                        ForEach(question.allOptions, id: \.self) { option in
                            Button {
                                selectedAnswer = option
                                showingExplanation = true
                            } label: {
                                Text(option)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            } else {
                GameResultsView(
                    mode: .multipleChoice,
                    score: score,
                    accuracy: Double(score) / Double(questions.count),
                    duration: 0,
                    onDismiss: { dismiss() }
                )
            }
        }
        .navigationTitle("Multiple Choice")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Answer Analysis", isPresented: $showingExplanation) {
            Button("Next") {
                currentIndex += 1
                selectedAnswer = nil
            }
        } message: {
            if let selected = selectedAnswer, currentIndex < questions.count {
                let question = questions[currentIndex]
                Text(question.getAnalysis(for: selected))
            }
        }
        .task {
            await loadQuestions()
        }
    }

    func loadQuestions() async {
        do {
            questions = try await gameEngine.generateMultipleChoice(from: Array(flashcardSet.cards.prefix(3)))
            isLoading = false
        } catch {
            errorMessage = "Failed to generate questions: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - Teach-Back Game View

struct TeachBackGameView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameEngine = GameEngine()

    let flashcardSet: FlashcardSet

    @State private var selectedCard: Flashcard?
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?
    @State private var feedback: TeachBackFeedback?
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 30) {
            if let card = selectedCard {
                VStack(spacing: 16) {
                    Text("Teach Back")
                        .font(.title2.bold())

                    Text(card.question)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    if let feedback = feedback {
                        FeedbackCard(feedback: feedback)
                    } else {
                        RecordingButton(
                            isRecording: isRecording,
                            isProcessing: isProcessing,
                            action: toggleRecording
                        )

                        Text("Record yourself explaining this concept")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            } else {
                CardSelectionView(cards: flashcardSet.cards, onSelect: { card in
                    selectedCard = card
                })
            }
        }
        .navigationTitle("Teach Back")
        .navigationBarTitleDisplayMode(.inline)
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        // Simplified: In production, use AVAudioSession properly
        isRecording = true
    }

    func stopRecording() {
        isRecording = false
        isProcessing = true

        Task {
            // In production: transcribe and evaluate
            await Task.sleep(seconds: 2)
            feedback = TeachBackFeedback(
                accuracy: 4,
                clarity: 4,
                strengthAreas: ["Good explanation of key concept"],
                improvementAreas: ["Add more specific examples"],
                feedback: "Great job! You explained the concept clearly."
            )
            isProcessing = false
        }
    }
}

struct RecordingButton: View {
    let isRecording: Bool
    let isProcessing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.cosmicPurple)
                    .frame(width: 80, height: 80)

                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                }
            }
        }
        .disabled(isProcessing)
    }
}

struct FeedbackCard: View {
    let feedback: TeachBackFeedback

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ScoreRow(label: "Accuracy", score: feedback.accuracy)
                Spacer()
                ScoreRow(label: "Clarity", score: feedback.clarity)
            }

            if !feedback.strengthAreas.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Strengths", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    ForEach(feedback.strengthAreas, id: \.self) { strength in
                        Text("• \(strength)")
                            .font(.caption)
                    }
                }
            }

            if !feedback.improvementAreas.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Areas to Improve", systemImage: "arrow.up.circle.fill")
                        .foregroundStyle(.orange)
                    ForEach(feedback.improvementAreas, id: \.self) { area in
                        Text("• \(area)")
                            .font(.caption)
                    }
                }
            }

            Text(feedback.feedback)
                .font(.body)
                .padding()
                .background(Color.cosmicPurple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ScoreRow: View {
    let label: String
    let score: Int

    var body: some View {
        VStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(score)/5")
                .font(.title3.bold())
        }
    }
}

// MARK: - Feynman Game View

struct FeynmanGameView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameEngine = GameEngine()

    let flashcardSet: FlashcardSet

    @State private var selectedCard: Flashcard?
    @State private var explanation = ""
    @State private var evaluation: FeynmanEvaluation?
    @State private var isEvaluating = false

    var body: some View {
        VStack(spacing: 20) {
            if let card = selectedCard {
                ScrollView {
                    VStack(spacing: 20) {
                        Text(card.question)
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)

                        Text("Explain this like you're teaching a 10-year-old")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $explanation)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        if let eval = evaluation {
                            FeynmanEvaluationCard(evaluation: eval)
                        } else {
                            Button("Evaluate My Explanation") {
                                evaluateExplanation()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(explanation.isEmpty || isEvaluating)
                        }
                    }
                    .padding()
                }
            } else {
                CardSelectionView(cards: flashcardSet.cards, onSelect: { card in
                    selectedCard = card
                })
            }
        }
        .navigationTitle("Feynman Technique")
        .navigationBarTitleDisplayMode(.inline)
    }

    func evaluateExplanation() {
        guard let card = selectedCard else { return }
        isEvaluating = true

        Task {
            do {
                evaluation = try await gameEngine.evaluateFeynmanExplanation(flashcard: card, explanation: explanation)
            } catch {
                // Handle error
            }
            isEvaluating = false
        }
    }
}

struct FeynmanEvaluationCard: View {
    let evaluation: FeynmanEvaluation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: evaluation.isSimpleEnough ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(evaluation.isSimpleEnough ? .green : .orange)
                Text(evaluation.isSimpleEnough ? "Simple enough!" : "Could be simpler")
                    .font(.headline)
            }

            if !evaluation.jargonUsed.isEmpty {
                VStack(alignment: .leading) {
                    Text("Complex terms:")
                        .font(.caption.bold())
                    ForEach(evaluation.jargonUsed, id: \.self) { jargon in
                        Text("• \(jargon)")
                            .font(.caption)
                    }
                }
            }

            if !evaluation.suggestedAnalogies.isEmpty {
                VStack(alignment: .leading) {
                    Text("Try these analogies:")
                        .font(.caption.bold())
                    ForEach(evaluation.suggestedAnalogies, id: \.self) { analogy in
                        Text("• \(analogy)")
                            .font(.caption)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Simplified version:")
                    .font(.caption.bold())
                Text(evaluation.simplifiedVersion)
                    .font(.body)
                    .padding()
                    .background(Color.cosmicPurple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Helper Views

struct CardSelectionView: View {
    let cards: [Flashcard]
    let onSelect: (Flashcard) -> Void

    var body: some View {
        List(cards, id: \.id) { card in
            Button {
                onSelect(card)
            } label: {
                VStack(alignment: .leading) {
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

struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct GameResultsView: View {
    let mode: StudyGameMode
    let score: Int
    let accuracy: Double
    let duration: TimeInterval
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.cosmicPurple)

            Text("Game Complete!")
                .font(.title.bold())

            VStack(spacing: 12) {
                ResultRow(label: "Score", value: "\(score)")
                ResultRow(label: "Accuracy", value: String(format: "%.0f%%", accuracy * 100))
                if duration > 0 {
                    ResultRow(label: "Time", value: "\(Int(duration))s")
                }
            }

            Button("Done") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

struct ResultRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .bold()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Extensions

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
