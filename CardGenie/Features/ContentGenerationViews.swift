//
//  ContentGenerationViews.swift
//  CardGenie
//
//  Content generation UI: Practice problems, scenarios, connection challenges.
//  All generation on-device using Foundation Models.
//

import SwiftUI
import SwiftData

// MARK: - Content Generation Hub

struct ContentGenerationView: View {
    let flashcardSet: FlashcardSet

    var body: some View {
        List {
            Section {
                NavigationLink {
                    PracticeProblemsView(flashcardSet: flashcardSet)
                } label: {
                    ContentGenRow(
                        title: "Practice Problems",
                        icon: "function",
                        description: "Generate new variations of problems"
                    )
                }

                NavigationLink {
                    ScenariosView(flashcardSet: flashcardSet)
                } label: {
                    ContentGenRow(
                        title: "Real-World Scenarios",
                        icon: "briefcase",
                        description: "Apply concepts to practical situations"
                    )
                }

                NavigationLink {
                    ConnectionsView(flashcardSets: [flashcardSet])
                } label: {
                    ContentGenRow(
                        title: "Connection Challenges",
                        icon: "link",
                        description: "Connect concepts across decks"
                    )
                }
            } header: {
                Text("Generate Practice Content")
            } footer: {
                Text("AI-generated practice materials based on your flashcards.")
            }
        }
        .navigationTitle("Practice Generator")
    }
}

struct ContentGenRow: View {
    let title: String
    let icon: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Color.cosmicPurple)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Practice Problems View

struct PracticeProblemsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var generator = ContentGenerator()

    let flashcardSet: FlashcardSet

    @State private var selectedCard: Flashcard?
    @State private var problems: [PracticeProblem] = []
    @State private var currentIndex = 0
    @State private var showingSolution = false
    @State private var isGenerating = false

    var body: some View {
        VStack(spacing: 0) {
            if selectedCard != nil {
                if isGenerating {
                    ProgressView("Generating practice problems...")
                        .frame(maxHeight: .infinity)
                } else if !problems.isEmpty {
                    practiceProblemsInterface
                } else {
                    GenerationEmptyView(
                        icon: "exclamationmark.triangle",
                        message: "No problems generated"
                    )
                }
            } else {
                cardSelectionList
            }
        }
        .navigationTitle("Practice Problems")
        .navigationBarTitleDisplayMode(.inline)
    }

    var practiceProblemsInterface: some View {
        VStack(spacing: 0) {
            // Progress indicator
            ProgressView(value: Double(currentIndex + 1), total: Double(problems.count))
                .tint(.cosmicPurple)
                .padding()

            ScrollView {
                VStack(spacing: 20) {
                    let problem = problems[currentIndex]

                    // Problem
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Problem \(currentIndex + 1) of \(problems.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            DifficultyBadge(difficulty: problem.difficulty)
                        }

                        Text(problem.problem)
                            .font(.title3)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Solution (toggle)
                    if showingSolution {
                        SolutionCard(problem: problem)
                    }

                    // Actions
                    HStack(spacing: 12) {
                        Button {
                            showingSolution.toggle()
                        } label: {
                            Label(showingSolution ? "Hide Solution" : "Show Solution", systemImage: "eye")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        if currentIndex < problems.count - 1 {
                            Button {
                                currentIndex += 1
                                showingSolution = false
                            } label: {
                                Label("Next", systemImage: "arrow.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding()
            }
        }
    }

    var cardSelectionList: some View {
        List {
            ForEach(flashcardSet.cards.filter { $0.supportsPracticeProblems }, id: \.id) { card in
                Button {
                    generateProblems(for: card)
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

            if flashcardSet.cards.filter({ $0.supportsPracticeProblems }).isEmpty {
                GenerationEmptyView(
                    icon: "function",
                    message: "No cards suitable for practice problems. Try math or calculation-based flashcards."
                )
            }
        }
    }

    func generateProblems(for card: Flashcard) {
        selectedCard = card
        isGenerating = true

        Task {
            do {
                problems = try await generator.generatePracticeProblems(from: card, count: 5)
                currentIndex = 0
                showingSolution = false
            } catch {
                problems = []
                // Error will be shown by empty state view
            }
            isGenerating = false
        }
    }
}

struct DifficultyBadge: View {
    let difficulty: DifficultyLevel

    var body: some View {
        Label(difficulty.displayName, systemImage: difficulty.icon)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(difficulty.color))
            .clipShape(Capsule())
    }
}

struct SolutionCard: View {
    let problem: PracticeProblem

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Solution", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Text(problem.solution)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if !problem.steps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Steps:")
                        .font(.caption.bold())

                    ForEach(problem.steps.indices, id: \.self) { index in
                        HStack(alignment: .top) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(problem.steps[index])
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Scenarios View

struct ScenariosView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var generator = ContentGenerator()

    let flashcardSet: FlashcardSet

    @State private var selectedCard: Flashcard?
    @State private var scenarios: [ScenarioQuestion] = []
    @State private var currentIndex = 0
    @State private var showingAnswer = false
    @State private var isGenerating = false

    var body: some View {
        VStack(spacing: 0) {
            if selectedCard != nil {
                if isGenerating {
                    ProgressView("Generating scenarios...")
                        .frame(maxHeight: .infinity)
                } else if !scenarios.isEmpty {
                    scenariosInterface
                } else {
                    GenerationEmptyView(icon: "exclamationmark.triangle", message: "No scenarios generated")
                }
            } else {
                cardSelectionList
            }
        }
        .navigationTitle("Real-World Scenarios")
        .navigationBarTitleDisplayMode(.inline)
    }

    var scenariosInterface: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(currentIndex + 1), total: Double(scenarios.count))
                .tint(.cosmicPurple)
                .padding()

            ScrollView {
                VStack(spacing: 20) {
                    let scenario = scenarios[currentIndex]

                    // Scenario
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Scenario \(currentIndex + 1) of \(scenarios.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Situation", systemImage: "briefcase")
                                .font(.caption.bold())

                            Text(scenario.scenario)
                                .font(.body)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Question", systemImage: "questionmark.circle")
                                .font(.caption.bold())

                            Text(scenario.question)
                                .font(.body.bold())
                        }
                        .padding()
                        .background(Color.cosmicPurple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        if showingAnswer {
                            ScenarioAnswerCard(scenario: scenario)
                        }
                    }

                    // Actions
                    HStack(spacing: 12) {
                        Button {
                            showingAnswer.toggle()
                        } label: {
                            Label(showingAnswer ? "Hide Answer" : "Show Answer", systemImage: "eye")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        if currentIndex < scenarios.count - 1 {
                            Button {
                                currentIndex += 1
                                showingAnswer = false
                            } label: {
                                Label("Next", systemImage: "arrow.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding()
            }
        }
    }

    var cardSelectionList: some View {
        List(flashcardSet.cards, id: \.id) { card in
            Button {
                generateScenarios(for: card)
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

    func generateScenarios(for card: Flashcard) {
        selectedCard = card
        isGenerating = true

        Task {
            do {
                scenarios = try await generator.generateScenarios(from: card)
                currentIndex = 0
                showingAnswer = false
            } catch {
                scenarios = []
                // Error will be shown by empty state view
            }
            isGenerating = false
        }
    }
}

struct ScenarioAnswerCard: View {
    let scenario: ScenarioQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Ideal Answer", systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.green)

                Text(scenario.idealAnswer)
                    .font(.body)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                Label("Reasoning", systemImage: "brain")
                    .font(.caption.bold())

                Text(scenario.reasoning)
                    .font(.caption)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Connections View

struct ConnectionsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var generator = ContentGenerator()
    @Query private var allSets: [FlashcardSet]

    let flashcardSets: [FlashcardSet]

    @State private var selectedSet1: FlashcardSet?
    @State private var selectedSet2: FlashcardSet?
    @State private var challenges: [ConnectionChallenge] = []
    @State private var currentIndex = 0
    @State private var showingAnswer = false
    @State private var isGenerating = false

    var body: some View {
        VStack {
            if challenges.isEmpty {
                deckSelectionInterface
            } else {
                challengesInterface
            }
        }
        .navigationTitle("Connection Challenges")
        .navigationBarTitleDisplayMode(.inline)
    }

    var deckSelectionInterface: some View {
        List {
            Section("Select First Deck") {
                ForEach(allSets, id: \.id) { set in
                    Button {
                        selectedSet1 = set
                    } label: {
                        HStack {
                            Text(set.topicLabel)
                            Spacer()
                            if selectedSet1?.id == set.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.cosmicPurple)
                            }
                        }
                    }
                }
            }

            Section("Select Second Deck") {
                ForEach(allSets.filter { $0.id != selectedSet1?.id }, id: \.id) { set in
                    Button {
                        selectedSet2 = set
                    } label: {
                        HStack {
                            Text(set.topicLabel)
                            Spacer()
                            if selectedSet2?.id == set.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.cosmicPurple)
                            }
                        }
                    }
                }
            }

            if selectedSet1 != nil && selectedSet2 != nil {
                Section {
                    Button("Generate Connections") {
                        generateConnections()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(isGenerating)
                }
            }
        }
    }

    var challengesInterface: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(currentIndex + 1), total: Double(challenges.count))
                .tint(.cosmicPurple)
                .padding()

            ScrollView {
                VStack(spacing: 20) {
                    let challenge = challenges[currentIndex]

                    ConnectionChallengeCard(challenge: challenge, showingAnswer: $showingAnswer)

                    HStack(spacing: 12) {
                        Button {
                            showingAnswer.toggle()
                        } label: {
                            Label(showingAnswer ? "Hide Answer" : "Show Answer", systemImage: "eye")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        if currentIndex < challenges.count - 1 {
                            Button {
                                currentIndex += 1
                                showingAnswer = false
                            } label: {
                                Label("Next", systemImage: "arrow.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding()
            }
        }
    }

    func generateConnections() {
        guard let set1 = selectedSet1, let set2 = selectedSet2 else { return }
        guard let card1 = set1.cards.first, let card2 = set2.cards.first else { return }

        isGenerating = true

        Task {
            do {
                challenges = try await generator.generateConnectionChallenges(
                    flashcard1: card1,
                    flashcard2: card2,
                    deck1Name: set1.topicLabel,
                    deck2Name: set2.topicLabel
                )
                currentIndex = 0
                showingAnswer = false
            } catch {
                challenges = []
                // Error will be shown by empty state view
            }
            isGenerating = false
        }
    }
}

struct ConnectionChallengeCard: View {
    let challenge: ConnectionChallenge
    @Binding var showingAnswer: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Connection: \(challenge.relatedDeck)", systemImage: "link")
                .font(.headline)

            Text(challenge.connection)
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                Label("Challenge", systemImage: "questionmark.diamond")
                    .font(.caption.bold())
                Text(challenge.synthesisQuestion)
                    .font(.body.bold())
            }
            .padding()
            .background(Color.cosmicPurple.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if showingAnswer {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Integrated Answer", systemImage: "lightbulb.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    Text(challenge.integratedAnswer)
                        .font(.body)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Empty State

struct GenerationEmptyView: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
}
