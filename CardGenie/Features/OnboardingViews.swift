//
//  OnboardingViews.swift
//  CardGenie
//
//  Created by Claude Code on 2025-11-04.
//  iOS 26.0+ Onboarding System
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Onboarding Coordinator

final class OnboardingCoordinator: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var isCompleted: Bool
    @Published var showDemoDataOption = true

    private let currentVersion = 1

    init() {
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let version = UserDefaults.standard.integer(forKey: "onboardingVersion")
        self.isCompleted = hasCompleted && version >= currentVersion
    }

    @MainActor
    func startOnboarding() {
        currentStep = .welcome
        isCompleted = false
    }

    @MainActor
    func nextStep() {
        guard let nextStep = currentStep.next else {
            completeOnboarding()
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentStep = nextStep
        }
    }

    @MainActor
    func previousStep() {
        guard let previousStep = currentStep.previous else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentStep = previousStep
        }
    }

    @MainActor
    func skip() {
        completeOnboarding()
    }

    @MainActor
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(currentVersion, forKey: "onboardingVersion")
        isCompleted = true
    }

    @MainActor
    func seedDemoData(in context: ModelContext) {
        // Create 3 sample notes
        let sampleNote1 = StudyContent(
            source: .text,
            rawContent: """
            Photosynthesis Basics

            Photosynthesis is the process by which plants convert light energy into chemical energy.

            Key components:
            - Chlorophyll (green pigment)
            - Light (usually sunlight)
            - Water (H2O)
            - Carbon dioxide (CO2)

            Output: Glucose (C6H12O6) + Oxygen (O2)
            """
        )
        sampleNote1.tags = ["Biology", "Science", "Plants"]
        sampleNote1.summary = "Plants convert light energy to chemical energy using chlorophyll, water, and CO2 to produce glucose and oxygen."

        let sampleNote2 = StudyContent(
            source: .text,
            rawContent: """
            World War II Timeline

            Major events of World War II:

            1939: Germany invades Poland, war begins
            1941: Pearl Harbor attack, US enters war
            1944: D-Day invasion of Normandy
            1945: Germany surrenders (May), Japan surrenders (August)

            Estimated casualties: 70-85 million people
            """
        )
        sampleNote2.tags = ["History", "World War II"]

        let sampleNote3 = StudyContent(
            source: .text,
            rawContent: """
            Pythagorean Theorem

            The Pythagorean Theorem states that in a right triangle:

            a² + b² = c²

            Where:
            - a and b are the lengths of the legs
            - c is the length of the hypotenuse (longest side)

            Example: If a = 3 and b = 4, then c = 5
            (3² + 4² = 9 + 16 = 25 = 5²)
            """
        )
        sampleNote3.tags = ["Math", "Geometry"]

        context.insert(sampleNote1)
        context.insert(sampleNote2)
        context.insert(sampleNote3)

        // Create a sample flashcard set
        let sampleSet = FlashcardSet(topicLabel: "Science Basics", tag: "science")
        context.insert(sampleSet)

        let card1 = Flashcard(
            type: .cloze,
            question: "What is photosynthesis?",
            answer: "The process by which plants convert light energy into chemical energy (glucose) using chlorophyll, water, and carbon dioxide.",
            linkedEntryID: sampleNote1.id,
            tags: ["Biology", "Science"]
        )
        sampleSet.addCard(card1)

        let card2 = Flashcard(
            type: .cloze,
            question: "What are the main components needed for photosynthesis?",
            answer: "Chlorophyll, light, water (H2O), and carbon dioxide (CO2)",
            linkedEntryID: sampleNote1.id,
            tags: ["Biology", "Science"]
        )
        sampleSet.addCard(card2)

        let card3 = Flashcard(
            type: .cloze,
            question: "What does photosynthesis produce?",
            answer: "Glucose (C6H12O6) and Oxygen (O2)",
            linkedEntryID: sampleNote1.id,
            tags: ["Biology", "Science"]
        )
        sampleSet.addCard(card3)

        context.insert(card1)
        context.insert(card2)
        context.insert(card3)

        try? context.save()
    }
}

// MARK: - Onboarding Steps

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case appleIntelligence
    case studyTab
    case flashcardsTab
    case scanTab
    case aiAssistant
    case complete

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        guard rawValue > 0 else { return nil }
        return OnboardingStep(rawValue: rawValue - 1)
    }

    var title: String {
        switch self {
        case .welcome: return "Welcome to CardGenie"
        case .appleIntelligence: return "Powered by Apple Intelligence"
        case .studyTab: return "Create Study Materials"
        case .flashcardsTab: return "Master with Flashcards"
        case .scanTab: return "Scan Anything"
        case .aiAssistant: return "Your AI Study Buddy"
        case .complete: return "You're All Set!"
        }
    }

    var description: String {
        switch self {
        case .welcome:
            return "Turn your notes into powerful study materials with AI-powered flashcards, all processed privately on your device."
        case .appleIntelligence:
            return "CardGenie uses Apple Intelligence for on-device AI processing. Your data never leaves your device and no network connection is required."
        case .studyTab:
            return "Add content from text, photos, PDFs, or voice recordings. AI automatically generates summaries, tags, and insights."
        case .flashcardsTab:
            return "Spaced repetition helps you remember what you study. Review cards at optimal intervals to maximize retention."
        case .scanTab:
            return "Snap photos of notes, textbooks, or whiteboards. AI extracts text and creates flashcards instantly."
        case .aiAssistant:
            return "Ask questions about your study materials or record lectures with live transcription and automatic note-taking."
        case .complete:
            return "Start creating your first study material or explore with demo content."
        }
    }

    var icon: String {
        switch self {
        case .welcome: return "sparkles"
        case .appleIntelligence: return "brain"
        case .studyTab: return "book.fill"
        case .flashcardsTab: return "rectangle.on.rectangle"
        case .scanTab: return "doc.viewfinder.fill"
        case .aiAssistant: return "waveform"
        case .complete: return "checkmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .welcome: return .purple
        case .appleIntelligence: return .blue
        case .studyTab: return .green
        case .flashcardsTab: return .orange
        case .scanTab: return .cyan
        case .aiAssistant: return .pink
        case .complete: return .green
        }
    }
}

// MARK: - Main Onboarding View

struct OnboardingView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @Environment(\.modelContext) private var modelContext
    @State private var showDemoDataConfirmation = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    coordinator.currentStep.iconColor.opacity(0.3),
                    coordinator.currentStep.iconColor.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                ProgressIndicator(
                    currentStep: coordinator.currentStep.rawValue,
                    totalSteps: OnboardingStep.allCases.count - 1 // Exclude complete
                )
                .padding(.top, 40)
                .padding(.horizontal)

                Spacer()

                // Content
                OnboardingStepView(step: coordinator.currentStep)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(coordinator.currentStep)

                Spacer()

                // Actions
                VStack(spacing: 16) {
                    if coordinator.currentStep == .complete {
                        // Demo data option
                        Button {
                            showDemoDataConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "tray.and.arrow.down.fill")
                                Text("Load Demo Content")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .cornerRadius(16)
                        }

                        Button {
                            coordinator.completeOnboarding()
                        } label: {
                            Text("Start Fresh")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(16)
                        }
                    } else {
                        // Next button
                        Button {
                            coordinator.nextStep()
                        } label: {
                            HStack {
                                Text("Continue")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(coordinator.currentStep.iconColor)
                            .foregroundStyle(.white)
                            .cornerRadius(16)
                        }

                        // Skip button
                        Button {
                            coordinator.skip()
                        } label: {
                            Text("Skip Tutorial")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .confirmationDialog("Load Demo Content?", isPresented: $showDemoDataConfirmation) {
            Button("Load Demo Content") {
                coordinator.seedDemoData(in: modelContext)
                coordinator.completeOnboarding()
            }
            Button("Start Fresh") {
                coordinator.completeOnboarding()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll create 3 sample notes and a flashcard set to help you explore CardGenie's features.")
        }
    }
}

// MARK: - Progress Indicator

struct ProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.primary : Color.primary.opacity(0.2))
                    .frame(height: 4)
                    .frame(maxWidth: step == currentStep ? 40 : .infinity)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Step Content View

struct OnboardingStepView: View {
    let step: OnboardingStep
    @ObservedObject var fmClient = FMClient()

    var body: some View {
        VStack(spacing: 32) {
            // Icon
            Image(systemName: step.icon)
                .font(.system(size: 80))
                .foregroundStyle(step.iconColor)
                .symbolEffect(.bounce, value: step)

            // Title
            Text(step.title)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)

            // Description
            Text(step.description)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Special content for Apple Intelligence step
            if step == .appleIntelligence {
                AICapabilityStatusCard()
                    .padding(.horizontal, 32)
            }

            // Feature highlights
            if let highlights = stepHighlights(for: step) {
                VStack(spacing: 16) {
                    ForEach(highlights) { highlight in
                        FeatureHighlightRow(highlight: highlight)
                    }
                }
                .padding(.horizontal, 32)
            }
        }
        .padding(.vertical, 40)
    }

    func stepHighlights(for step: OnboardingStep) -> [FeatureHighlight]? {
        switch step {
        case .studyTab:
            return [
                FeatureHighlight(icon: "text.alignleft", title: "Type or paste notes", color: .blue),
                FeatureHighlight(icon: "photo", title: "Add photos", color: .purple),
                FeatureHighlight(icon: "doc.fill", title: "Import PDFs", color: .red),
                FeatureHighlight(icon: "mic.fill", title: "Voice recordings", color: .orange)
            ]
        case .flashcardsTab:
            return [
                FeatureHighlight(icon: "brain", title: "Spaced repetition", color: .blue),
                FeatureHighlight(icon: "chart.line.uptrend.xyaxis", title: "Track progress", color: .green),
                FeatureHighlight(icon: "gamecontroller.fill", title: "Study games", color: .purple)
            ]
        case .scanTab:
            return [
                FeatureHighlight(icon: "text.viewfinder", title: "OCR text extraction", color: .blue),
                FeatureHighlight(icon: "hand.draw.fill", title: "Handwriting recognition", color: .purple),
                FeatureHighlight(icon: "sparkles", title: "Auto flashcard creation", color: .orange)
            ]
        default:
            return nil
        }
    }
}

// MARK: - Feature Highlight

struct FeatureHighlight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let color: Color
}

struct FeatureHighlightRow: View {
    let highlight: FeatureHighlight

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: highlight.icon)
                .font(.title2)
                .foregroundStyle(highlight.color)
                .frame(width: 40)

            Text(highlight.title)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - AI Capability Status Card

struct AICapabilityStatusCard: View {
    @ObservedObject var fmClient = FMClient()

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                statusIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.headline)
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(statusColor.opacity(0.1))
            .cornerRadius(12)

            if fmClient.capability() == .notEnabled {
                Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
    }

    var statusIcon: some View {
        Group {
            switch fmClient.capability() {
            case .available:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .notEnabled:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
            case .notSupported:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            case .modelNotReady:
                ProgressView()
            case .unknown:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.gray)
            }
        }
        .font(.title2)
    }

    var statusTitle: String {
        switch fmClient.capability() {
        case .available:
            return "Apple Intelligence Ready"
        case .notEnabled:
            return "Apple Intelligence Disabled"
        case .notSupported:
            return "Device Not Supported"
        case .modelNotReady:
            return "Downloading Models..."
        case .unknown:
            return "Checking Status..."
        }
    }

    var statusMessage: String {
        switch fmClient.capability() {
        case .available:
            return "All AI features are available"
        case .notEnabled:
            return "Enable in Settings > Apple Intelligence"
        case .notSupported:
            return "Basic features available without AI"
        case .modelNotReady:
            return "AI features available when complete"
        case .unknown:
            return "Please wait..."
        }
    }

    var statusColor: Color {
        switch fmClient.capability() {
        case .available:
            return .green
        case .notEnabled:
            return .orange
        case .notSupported:
            return .red
        case .modelNotReady:
            return .blue
        case .unknown:
            return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(coordinator: OnboardingCoordinator())
        .modelContainer(for: [StudyContent.self, Flashcard.self, FlashcardSet.self])
}
