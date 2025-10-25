//
//  VoiceAssistantView.swift
//  CardGenie
//
//  Voice Q&A agent using Apple Intelligence.
//  Ask general knowledge questions and get instant answers.
//

import SwiftUI
import Speech
import AVFoundation
import Combine

// MARK: - Voice Assistant View

struct VoiceAssistantView: View {
    @StateObject private var assistant = VoiceAssistant()
    @State private var showPermissionAlert = false
    @State private var hasRequestedPermission = false
    @State private var scrollProxy: ScrollViewProxy? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [.cosmicPurple.opacity(0.1), .mysticBlue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    if !hasRequestedPermission {
                        permissionView
                    } else {
                        // Assistant Status
                        assistantStatusView
                            .padding(.top)

                        Spacer()

                        // Conversation History
                        if !assistant.conversation.isEmpty {
                            conversationView
                        } else {
                            emptyConversationView
                        }

                        Spacer()

                        // Mic Button
                        micButton
                            .padding(.bottom, 20)
                    }
                }
                .padding()
            }
            .navigationTitle("Voice Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !assistant.conversation.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            assistant.clearConversation()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .onAppear {
                if !hasRequestedPermission {
                    requestPermissions()
                }
            }
            .onDisappear {
                assistant.stopListening()
            }
            .alert("Microphone Permission Required", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable microphone access in Settings to use voice assistant.")
            }
        }
    }

    // MARK: - Permission View

    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cosmicPurple, .mysticBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Voice Assistant")
                .font(.title.bold())

            Text("Ask any general knowledge question and get instant answers using on-device AI.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Enable Voice") {
                requestPermissions()
            }
            .buttonStyle(.borderedProminent)
            .tint(.cosmicPurple)
        }
        .padding()
    }

    // MARK: - Empty Conversation

    private var emptyConversationView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("Hold the mic and ask a question")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Release when done speaking to get your answer")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Assistant Status

    private var assistantStatusView: some View {
        VStack(spacing: 12) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: statusIcon)
                    .font(.system(size: 50))
                    .foregroundStyle(statusColor)
                    .symbolEffect(.pulse, isActive: assistant.isListening || assistant.isSpeaking || assistant.isProcessing)
            }

            // Status Text
            Text(statusText)
                .font(.headline)
                .foregroundStyle(statusColor)

            // Current Transcript
            if assistant.isListening && !assistant.currentTranscript.isEmpty {
                Text(assistant.currentTranscript)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .transition(.scale.combined(with: .opacity))
            }

            // Processing Indicator
            if assistant.isProcessing {
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.cosmicPurple)
                            .frame(width: 8, height: 8)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                                value: assistant.isProcessing
                            )
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var statusIcon: String {
        if assistant.isListening {
            return "waveform"
        } else if assistant.isSpeaking {
            return "speaker.wave.3.fill"
        } else if assistant.isProcessing {
            return "brain"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var statusText: String {
        if assistant.isListening {
            return "Listening..."
        } else if assistant.isSpeaking {
            return "Speaking..."
        } else if assistant.isProcessing {
            return "Thinking..."
        } else {
            return "Ready"
        }
    }

    private var statusColor: Color {
        if assistant.isListening {
            return .blue
        } else if assistant.isSpeaking {
            return .green
        } else if assistant.isProcessing {
            return .orange
        } else {
            return .cosmicPurple
        }
    }

    // MARK: - Conversation View

    private var conversationView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(assistant.conversation) { message in
                        HStack(alignment: .top, spacing: 8) {
                            if message.isUser {
                                Spacer()
                            }

                            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                                Text(message.text)
                                    .font(.body)
                                    .padding(12)
                                    .background(message.isUser ? Color.cosmicPurple.opacity(0.2) : Color.gray.opacity(0.2))
                                    .cornerRadius(16)
                                    .contextMenu {
                                        Button {
                                            UIPasteboard.general.string = message.text
                                        } label: {
                                            Label("Copy", systemImage: "doc.on.doc")
                                        }
                                    }

                                Text(message.timestamp, format: .dateTime.hour().minute())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
                            .id(message.id)

                            if !message.isUser {
                                Spacer()
                            }
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: 350)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .onChange(of: assistant.conversation.count) { _, _ in
                if let lastMessage = assistant.conversation.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                scrollProxy = proxy
            }
        }
    }

    // MARK: - Mic Button

    private var micButton: some View {
        Button {
            if assistant.isListening {
                assistant.stopListening()
            } else if !assistant.isProcessing && !assistant.isSpeaking {
                do {
                    try assistant.startListening()
                } catch {
                    print("Failed to start listening: \(error)")
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: assistant.isListening ? [.red, .orange] : [.cosmicPurple, .mysticBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(
                        color: assistant.isListening ? .red.opacity(0.5) : .cosmicPurple.opacity(0.5),
                        radius: 20
                    )

                Image(systemName: assistant.isListening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 35))
                    .foregroundStyle(.white)
            }
        }
        .disabled(assistant.isSpeaking || assistant.isProcessing)
        .opacity(assistant.isSpeaking || assistant.isProcessing ? 0.5 : 1.0)
    }

    // MARK: - Permissions

    private func requestPermissions() {
        Task {
            // Request speech recognition
            let speechAuth = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }

            guard speechAuth == .authorized else {
                await MainActor.run {
                    showPermissionAlert = true
                }
                return
            }

            // Request microphone
            let micAuth = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }

            await MainActor.run {
                if micAuth {
                    hasRequestedPermission = true
                } else {
                    showPermissionAlert = true
                }
            }
        }
    }
}

// MARK: - Voice Assistant Engine

@MainActor
class VoiceAssistant: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var isProcessing = false
    @Published var currentTranscript = ""
    @Published var conversation: [ConversationMessage] = []

    private let llm: LLMEngine
    nonisolated(unsafe) private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    nonisolated(unsafe) private let audioEngine = AVAudioEngine()
    nonisolated(unsafe) private let speechSynthesizer = AVSpeechSynthesizer()

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    override init() {
        self.llm = AIEngineFactory.createLLMEngine()
        super.init()
        speechSynthesizer.delegate = self
    }

    func clearConversation() {
        conversation.removeAll()
    }

    // MARK: - Listening

    func startListening() throws {
        guard !isListening else { return }

        // Stop speaking if active
        if isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                Task { @MainActor in
                    self.currentTranscript = result.bestTranscription.formattedString

                    if result.isFinal {
                        await self.handleQuestion(self.currentTranscript)
                    }
                }
            }

            if error != nil {
                Task { @MainActor in
                    self.stopListening()
                }
            }
        }

        isListening = true
        currentTranscript = ""
    }

    func stopListening() {
        guard isListening else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        isListening = false
    }

    // MARK: - Question Handling

    private func handleQuestion(_ question: String) async {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        stopListening()

        // Add user message
        let userMessage = ConversationMessage(text: question, isUser: true)
        conversation.append(userMessage)
        currentTranscript = ""

        // Start processing
        isProcessing = true

        // Get answer
        do {
            let answer = try await generateAnswer(question: question)

            // Add assistant message
            let assistantMessage = ConversationMessage(text: answer, isUser: false)
            conversation.append(assistantMessage)

            isProcessing = false

            // Speak answer
            await speak(answer)

            // Auto-listen for follow-up (with small delay)
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            try? startListening()

        } catch {
            isProcessing = false

            let errorAnswer = "Sorry, I had trouble processing that. Could you rephrase your question?"
            let errorMessage = ConversationMessage(text: errorAnswer, isUser: false)
            conversation.append(errorMessage)

            await speak(errorAnswer)

            try? await Task.sleep(nanoseconds: 500_000_000)
            try? startListening()
        }
    }

    private func generateAnswer(question: String) async throws -> String {
        // Generate general knowledge answer using on-device LLM
        let prompt = """
        You are a helpful voice assistant. Answer this question clearly and concisely in 2-3 sentences maximum.
        This answer will be spoken aloud, so keep it conversational and easy to understand.

        QUESTION: \(question)

        Provide a clear, concise answer:
        """

        let answer = try await llm.complete(prompt, maxTokens: 200)
        return answer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Speaking

    private func speak(_ text: String) async {
        let utterance = AVSpeechUtterance(string: text)

        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }

        utterance.rate = 0.52 // Slightly faster for better flow
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isSpeaking = true
        speechSynthesizer.speak(utterance)

        // Wait for speech to finish
        while isSpeaking {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
        }
    }
}

// MARK: - Conversation Message

struct ConversationMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

// MARK: - Preview

#Preview {
    VoiceAssistantView()
}
