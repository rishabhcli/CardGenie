//
//  VoiceRecordView.swift
//  CardGenie
//
//  Live lecture companion with transcription, highlights, Live Activity, and SharePlay.
//

import SwiftUI
import SwiftData
import UIKit

struct VoiceRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var contextManager = LiveLectureContext()

    @State private var hasRequestedPermission = false
    @State private var hasPermission = false
    @State private var topic = ""
    @State private var showSummarySheet = false
    @State private var isGeneratingDeck = false
    @State private var generationMessage: String?
    @State private var showError = false

    @FocusState private var topicFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        if !hasPermission {
                            permissionRequestSection
                        } else if !contextManager.isRecording && contextManager.transcript.isEmpty {
                            readyToRecordSection
                        } else {
                            recordingSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Record Lecture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if contextManager.isRecording {
                        Button("Stop") {
                            Task {
                                if await contextManager.stopRecording() != nil {
                                    showSummarySheet = true
                                }
                            }
                        }
                        .foregroundColor(.red)
                    } else if !contextManager.transcript.isEmpty {
                        Button("Reset") {
                            contextManager.cancelRecording()
                            topic = ""
                        }
                        .foregroundColor(.cosmicPurple)
                    }
                }
            }
            .task {
                hasPermission = await contextManager.requestPermissions()
                hasRequestedPermission = true
            }
            .onChange(of: contextManager.lastErrorMessage) { _, newValue in
                if newValue != nil {
                    showError = true
                }
            }
            .alert("Recording Error", isPresented: $showError, presenting: contextManager.lastErrorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .sheet(isPresented: $showSummarySheet) {
                LectureSummarySheet(
                    summary: contextManager.summary,
                    isGeneratingDeck: $isGeneratingDeck,
                    generationMessage: $generationMessage,
                    generateAction: generateDeck
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Sections

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

            Text("CardGenie needs microphone access to transcribe lectures and surface highlights in real time.")
                .font(.system(.body, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondaryText)
                .padding(.horizontal)

            Spacer()

            HapticButton(hapticStyle: .medium) {
                Task {
                    hasPermission = await contextManager.requestPermissions()
                    hasRequestedPermission = true
                    if !hasPermission {
                        await MainActor.run {
                            openSettings()
                        }
                    }
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

            Text("Give your session a short title and tap record to begin streaming highlights to your Live Activity.")
                .font(.system(.body, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondaryText)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Session Title")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.secondaryText)

                TextField("Biology lecture, study group…", text: $topic)
                    .textFieldStyle(.roundedBorder)
                    .focused($topicFieldFocused)
            }
            .padding(.horizontal)

            Spacer()

            HapticButton(hapticStyle: .heavy) {
                Task {
                    do {
                        try await contextManager.startRecording(topic: topic, context: modelContext)
                    } catch {
                        generationMessage = "Could not start recording. \(error.localizedDescription)"
                        showError = true
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "record.circle.fill")
                    Text("Start Recording")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(MagicButtonStyle())
            .padding(.horizontal)
        }
    }

    private var recordingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if contextManager.isLiveActivityRunning {
                liveActivityBanner
            }

            collaborationStatus

            liveTranscriptSection
            highlightsSection

            controlsSection
        }
    }

    private var liveActivityBanner: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "waveform.and.magnifyingglass")
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Live Activity Active")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Text("Highlights are streaming to your Lock Screen.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondaryText)
            }
        }
        .padding()
        .glassPanel()
        .cornerRadius(16)
    }

    private var collaborationStatus: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Label(
                    collaborationStateLabel,
                    systemImage: collaborationIcon
                )
                .font(.system(.body, design: .rounded, weight: .medium))

                Spacer()

                if collaborationStateActionAvailable {
                    Button("Invite classmates") {
                        Task {
                            await contextManager.startSharePlay()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            if !contextManager.collaboration.participants.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(contextManager.collaboration.participants) { participant in
                            Label(participant.name, systemImage: "person.crop.circle")
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .glassPanel()
                                .cornerRadius(12)
                        }
                    }
                }
            } else if collaborationStateHint != nil {
                Text(collaborationStateHint!)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondaryText)
            }
        }
        .padding()
        .glassPanel()
        .cornerRadius(16)
    }

    private var liveTranscriptSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Live Transcript")
                .font(.system(.headline, design: .rounded))

            if contextManager.transcript.isEmpty {
                Text("Start speaking to see real-time transcription.")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(contextManager.transcript)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .glassPanel()
        .cornerRadius(16)
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Highlights")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Text("\(contextManager.highlights.count)")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondaryText)
            }

            if contextManager.highlights.isEmpty {
                Text("Automatic highlight detection will show key moments here. Tap “Mark Highlight” to capture manually.")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondaryText)
            } else {
                VStack(spacing: Spacing.md) {
                    ForEach(contextManager.highlights) { highlight in
                        highlightRow(highlight)
                    }
                }
            }
        }
        .padding()
        .glassPanel()
        .cornerRadius(16)
    }

    private func highlightRow(_ highlight: LiveLectureContext.LiveHighlight) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(highlight.summary)
                    .font(.system(.body, design: .rounded, weight: highlight.isPinned ? .semibold : .regular))
                    .foregroundColor(.primaryText)
                Spacer()
                Text(highlight.timestampLabel)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondaryText)
            }

            Text(highlight.excerpt)
                .font(.system(.footnote, design: .rounded))
                .foregroundColor(.secondaryText)

            HStack(spacing: Spacing.md) {
                Toggle("Create flashcard", isOn: Binding(
                    get: { highlight.isCardCandidate },
                    set: { newValue in
                        contextManager.markAsCardCandidate(highlight.id, isCandidate: newValue)
                    }
                ))
                .font(.system(.footnote, design: .rounded))

                Button {
                    contextManager.togglePin(for: highlight.id)
                } label: {
                    Label(
                        highlight.isPinned ? "Pinned" : "Pin",
                        systemImage: highlight.isPinned ? "pin.fill" : "pin"
                    )
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .foregroundColor(highlight.isPinned ? .cosmicPurple : .secondaryText)
            }
        }
        .padding()
        .glassPanel()
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.05), radius: highlight.isPinned ? 6 : 2, x: 0, y: 2)
    }

    private var controlsSection: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                HapticButton(hapticStyle: .light) {
                    contextManager.addManualHighlight()
                } label: {
                    HStack {
                        Image(systemName: "highlighter")
                        Text("Mark Highlight")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(MagicButtonStyle())

                HapticButton(hapticStyle: .medium) {
                    Task {
                        await contextManager.startSharePlay()
                    }
                } label: {
                    HStack {
                        Image(systemName: "person.2.wave.2")
                        Text("SharePlay")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(MagicButtonStyle.sharePlay)
            }

            HStack {
                Button("End Session") {
                    Task {
                        if await contextManager.stopRecording() != nil {
                            showSummarySheet = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, Spacing.lg)
    }

    // MARK: - Helpers

    private var collaborationStateLabel: String {
        switch contextManager.collaboration.state {
        case .active:
            return "Collaborating"
        case .waiting:
            return "Waiting for friends"
        case .ended:
            return "Collaboration ended"
        case .idle:
            return "Solo session"
        case .unavailable:
            return "SharePlay unavailable"
        }
    }

    private var collaborationIcon: String {
        switch contextManager.collaboration.state {
        case .active:
            return "person.2.fill"
        case .waiting:
            return "hourglass"
        case .ended:
            return "person.crop.circle.badge.exclam"
        case .idle:
            return "person"
        case .unavailable:
            return "slash.circle"
        }
    }

    private var collaborationStateHint: String? {
        switch contextManager.collaboration.state {
        case .idle:
            return "Start a SharePlay session to invite classmates and mark highlights together."
        case .waiting:
            return "Waiting for classmates to join. Highlights will sync once they connect."
        case .ended:
            return "Collaboration ended. You can restart SharePlay at any time."
        case .unavailable:
            return "SharePlay is not available on this device or account."
        case .active:
            return nil
        }
    }

    private var collaborationStateActionAvailable: Bool {
        switch contextManager.collaboration.state {
        case .idle, .ended:
            return true
        default:
            return false
        }
    }

    private func generateDeck() async {
        guard !isGeneratingDeck else { return }
        isGeneratingDeck = true
        generationMessage = nil

        do {
            if let deck = try await contextManager.generateCards(context: modelContext) {
                generationMessage = "Generated \(deck.cardCount) cards in \(deck.topicLabel)."
            } else {
                generationMessage = "No highlights marked for flashcards yet."
            }
        } catch {
            generationMessage = "Could not generate cards: \(error.localizedDescription)"
        }

        isGeneratingDeck = false
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}

// MARK: - Summary Sheet

private struct LectureSummarySheet: View {
    let summary: LiveLectureContext.SessionSummary?
    @Binding var isGeneratingDeck: Bool
    @Binding var generationMessage: String?
    let generateAction: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if let summary {
                Text("Session Summary")
                    .font(.system(.title3, design: .rounded, weight: .bold))

                summaryHeader(summary)
                highlightOverview(summary)
                actions
            } else {
                ProgressView("Finalizing session…")
                    .progressViewStyle(.circular)
            }
        }
        .padding()
    }

    private func summaryHeader(_ summary: LiveLectureContext.SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(summary.session.title)
                .font(.system(.headline, design: .rounded))
            Text("\(summary.highlights.count) highlights · \(summary.participants.count) collaborators")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondaryText)
        }
    }

    private func highlightOverview(_ summary: LiveLectureContext.SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Highlights ready for cards")
                .font(.system(.subheadline, design: .rounded, weight: .medium))

            let cardCandidates = summary.highlights.filter { $0.isCardCandidate }
            if cardCandidates.isEmpty {
                Text("Toggle \"Create flashcard\" for a highlight to add it to your collaborative deck.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundColor(.secondaryText)
            } else {
                ForEach(cardCandidates.prefix(5), id: \.id) { marker in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(marker.summary ?? marker.transcriptSnippet)
                            .font(.system(.footnote, design: .rounded, weight: .medium))
                        Text(marker.transcriptSnippet)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondaryText)
                    }
                    .padding(.vertical, Spacing.xs)
                }
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Button {
                Task {
                    await generateAction()
                }
            } label: {
                if isGeneratingDeck {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Generate Flashcards")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(MagicButtonStyle())
            .disabled(isGeneratingDeck)

            if let generationMessage {
                Text(generationMessage)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundColor(.secondaryText)
            }
        }
    }
}

private extension MagicButtonStyle {
    static var sharePlay: MagicButtonStyle {
        MagicButtonStyle(
            gradient: LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}
