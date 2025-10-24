//
//  VoiceRecordView.swift
//  CardGenie
//
//  Voice recording view for lecture transcription and flashcard generation.
//  Uses Speech framework for real-time voice-to-text conversion.
//

import SwiftUI
import SwiftData

/// Voice recording interface with real-time transcription
struct VoiceRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var speechConverter = SpeechToTextConverter()
    @StateObject private var fmClient = FMClient()

    @State private var transcribedText = ""
    @State private var isGeneratingCards = false
    @State private var showPermissionAlert = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var hasRequestedPermission = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        if !hasRequestedPermission {
                            // Permission request state
                            permissionRequestSection
                        } else if !speechConverter.isRecording && transcribedText.isEmpty {
                            // Ready to record state
                            readyToRecordSection
                        } else {
                            // Recording or completed state
                            VStack(spacing: Spacing.xl) {
                                if speechConverter.isRecording {
                                    recordingVisualization
                                }

                                if !speechConverter.transcribedText.isEmpty || !transcribedText.isEmpty {
                                    transcriptionSection
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Record Lecture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if speechConverter.isRecording {
                            stopRecording()
                        }
                        dismiss()
                    }
                }

                if speechConverter.isRecording || !transcribedText.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button(speechConverter.isRecording ? "Stop" : "Reset") {
                            if speechConverter.isRecording {
                                stopRecording()
                            } else {
                                resetRecording()
                            }
                        }
                        .foregroundColor(speechConverter.isRecording ? .red : .cosmicPurple)
                    }
                }
            }
            .alert("Microphone Permission Required", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    openSettings()
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("CardGenie needs microphone access to record lectures. Please enable it in Settings.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
            .task {
                await requestPermissionIfNeeded()
            }
            .onChange(of: speechConverter.transcribedText) { oldValue, newValue in
                transcribedText = newValue
            }
        }
    }

    // MARK: - View Sections

    private var permissionRequestSection: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.magicGradient)
                .floating(distance: 8, duration: 3.0)

            Text("Microphone Access")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundColor(.primaryText)

            Text("CardGenie needs microphone access to transcribe your lectures into flashcards")
                .font(.system(.body, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondaryText)
                .padding(.horizontal)

            Spacer()

            HapticButton(hapticStyle: .medium) {
                Task {
                    await requestPermissionIfNeeded()
                }
            } label: {
                Text("Allow Microphone Access")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MagicButtonStyle())
            .padding(.horizontal)
        }
    }

    private var readyToRecordSection: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            // Microphone icon
            ZStack {
                Circle()
                    .fill(Color.cosmicPurple.opacity(0.2))
                    .frame(width: 150, height: 150)

                Circle()
                    .fill(Color.cosmicPurple.opacity(0.3))
                    .frame(width: 120, height: 120)

                Image(systemName: "mic.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.cosmicPurple)
            }
            .floating(distance: 8, duration: 3.0)

            Text("Ready to Record")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundColor(.primaryText)

            Text("Tap the button below to start recording your lecture or study notes")
                .font(.system(.body, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondaryText)
                .padding(.horizontal)

            Spacer()

            // Start recording button
            HapticButton(hapticStyle: .heavy) {
                startRecording()
            } label: {
                HStack {
                    Image(systemName: "mic.circle.fill")
                    Text("Start Recording")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(MagicButtonStyle())
            .padding(.horizontal)
        }
    }

    private var recordingVisualization: some View {
        VStack(spacing: Spacing.lg) {
            // Animated recording indicator
            ZStack {
                // Pulsing circles
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 150, height: 150)
                    .pulse(color: .red, duration: 1.0)

                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 100, height: 100)

                // Microphone icon
                Image(systemName: "waveform")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                    .floating(distance: 5, duration: 1.0)
            }

            // Recording status
            VStack(spacing: Spacing.xs) {
                Text("Recording...")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundColor(.red)

                Text(formatDuration(speechConverter.recordingDuration))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.primaryText)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, Spacing.xl)
    }

    private var transcriptionSection: some View {
        VStack(spacing: Spacing.lg) {
            // Transcription header
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: speechConverter.isRecording ? "waveform" : "checkmark.circle.fill")
                        .foregroundColor(speechConverter.isRecording ? .mysticBlue : .genieGreen)
                    Text(speechConverter.isRecording ? "Live Transcription" : "Transcription Complete")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondaryText)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(transcribedText.count) characters")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondaryText)
                }

                // Scrollable transcription
                ScrollView {
                    Text(transcribedText)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxHeight: 300)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.cosmicPurple.opacity(0.05))
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color.cosmicPurple.opacity(0.1))
            )

            // Generate flashcards button (only when not recording)
            if !speechConverter.isRecording && !transcribedText.isEmpty {
                HapticButton(hapticStyle: .heavy) {
                    generateFlashcards()
                } label: {
                    HStack {
                        if isGeneratingCards {
                            ProgressView()
                                .tint(.white)
                            Text("Generating...")
                        } else {
                            Image(systemName: "sparkles")
                            Text("Generate Flashcards")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(MagicButtonStyle())
                .disabled(isGeneratingCards)
            }
        }
    }

    // MARK: - Actions

    private func requestPermissionIfNeeded() async {
        let authorized = await speechConverter.requestAuthorization()
        await MainActor.run {
            hasRequestedPermission = true
            if !authorized {
                showPermissionAlert = true
            }
        }
    }

    private func startRecording() {
        Task {
            do {
                try await speechConverter.startRecording()
                HapticFeedback.heavy()
            } catch let error as SpeechError {
                await MainActor.run {
                    errorMessage = error.errorDescription
                    showError = true
                    HapticFeedback.error()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to start recording. Please try again."
                    showError = true
                    HapticFeedback.error()
                }
            }
        }
    }

    private func stopRecording() {
        speechConverter.stopRecording()
        HapticFeedback.medium()
    }

    private func resetRecording() {
        transcribedText = ""
        speechConverter.transcribedText = ""
        speechConverter.deleteSavedRecording()
        HapticFeedback.light()
    }

    private func generateFlashcards() {
        guard !transcribedText.isEmpty else { return }

        isGeneratingCards = true
        HapticFeedback.heavy()

        Task {
            do {
                // Create StudyContent from voice recording
                let content = StudyContent(
                    source: .voice,
                    rawContent: transcribedText
                )

                // Store audio URL if available
                if let audioURL = speechConverter.getSavedRecordingURL() {
                    content.audioURL = audioURL.path
                }

                // Save the content first
                modelContext.insert(content)

                // Generate flashcards using AI
                let flashcardFormats: Set<FlashcardType> = [.cloze, .qa, .definition]
                let result = try await fmClient.generateFlashcards(
                    from: content,
                    formats: flashcardFormats,
                    maxPerFormat: 3
                )

                // Create flashcard set
                let flashcardSet = FlashcardSet(
                    topicLabel: result.topicTag,
                    tag: result.topicTag.lowercased()
                )

                // Link flashcards to content and set
                content.flashcards = result.flashcards
                flashcardSet.cards = result.flashcards

                // Insert all entities
                modelContext.insert(flashcardSet)
                for flashcard in result.flashcards {
                    modelContext.insert(flashcard)
                }

                // Save everything
                try modelContext.save()

                await MainActor.run {
                    isGeneratingCards = false
                    HapticFeedback.success()
                    dismiss()
                }

            } catch {
                await MainActor.run {
                    isGeneratingCards = false
                    errorMessage = "Failed to generate flashcards. Please try again."
                    showError = true
                    HapticFeedback.error()
                }
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: StudyContent.self, Flashcard.self, FlashcardSet.self,
        configurations: config
    )

    VoiceRecordView()
        .modelContainer(container)
}
