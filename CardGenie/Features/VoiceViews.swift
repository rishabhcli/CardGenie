//
//  VoiceViews.swift
//  CardGenie
//
//  Voice assistant, recording, and lecture collaboration features.
//

import SwiftUI
import SwiftData
import UIKit
import AVFoundation
import ActivityKit
import Speech
import OSLog
import GroupActivities
import Combine
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - VoiceAssistantView


// MARK: - Voice Assistant View

struct VoiceAssistantView: View {
    @StateObject private var assistant: VoiceAssistant
    @State private var showPermissionAlert = false
    @State private var hasRequestedPermission = false
    @State private var scrollProxy: ScrollViewProxy? = nil

    // MARK: - Initialization

    init(context: ConversationContext = ConversationContext()) {
        _assistant = StateObject(wrappedValue: VoiceAssistant(context: context))
    }

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

                        // Streaming response (shown in real-time)
                        if !assistant.streamingResponse.isEmpty {
                            streamingResponseView
                                .padding(.horizontal)
                                .transition(.scale.combined(with: .opacity))
                        }

                        Spacer()

                        // Control Buttons
                        controlButtons
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
                    .glassOverlay(cornerRadius: 12)
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
            .glassPanel()
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

    // MARK: - Streaming Response View

    private var streamingResponseView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)
                Text("AI Tutor (streaming...)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(assistant.streamingResponse)
                .font(.body)
                .padding(12)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(16)
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 20) {
            // Mic Button
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

            // Interrupt Button (only visible when AI is speaking)
            if assistant.isSpeaking || assistant.isProcessing {
                Button {
                    assistant.interrupt()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .shadow(color: .orange.opacity(0.5), radius: 15)

                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: assistant.isSpeaking)
        .animation(.spring(response: 0.3), value: assistant.isProcessing)
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

// MARK: - Voice Assistant Engine (Enhanced with Streaming)

@MainActor
class VoiceAssistant: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    // MARK: - Published State

    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var isProcessing = false
    @Published var currentTranscript = ""
    @Published var conversation: [VoiceMessage] = []
    @Published var lastError: String?

    /// Streaming response text (updates in real-time)
    @Published var streamingResponse = ""

    // MARK: - Private State

    private let fmClient = FMClient()
    private let speechRecognizer: SFSpeechRecognizer
    private let audioEngine = AVAudioEngine()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let log = Logger(subsystem: "com.cardgenie.app", category: "VoiceAssistant")

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    /// Current conversation session (if using SwiftData persistence)
    private var currentSession: ConversationSession?

    /// Conversation context (study content, flashcards, etc.)
    private var context: ConversationContext

    /// Streaming task for cancellation
    private var streamingTask: Task<Void, Never>?

    /// Sentence buffer for incremental TTS
    private var lastSpokenText = ""

    /// Silence detection timer
    private var silenceTimer: Timer?
    private var lastTranscriptUpdate = Date()

    // MARK: - Initialization

    init(context: ConversationContext = ConversationContext()) {
        self.context = context
        // Initialize speech recognizer with fallback
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) ?? SFSpeechRecognizer()!
        super.init()
        speechSynthesizer.delegate = self
        log.info("🎙️ Voice Assistant initialized (OFFLINE MODE)")
        log.info("✅ On-device speech recognition: ENABLED")
        log.info("✅ Apple Intelligence: \(self.fmClient.capability() == .available ? "AVAILABLE" : "UNAVAILABLE")")
    }

    func clearConversation() {
        conversation.removeAll()
        lastError = nil
        streamingResponse = ""
        log.info("🗑️ Conversation cleared")
    }

    // MARK: - Cancellation & Interruption

    func cancelListening() {
        log.info("🛑 Cancelling voice recognition")
        stopListening()
    }

    /// Interrupt AI response mid-speech
    func interrupt() {
        log.info("🛑 Interrupting AI response...")

        // Cancel streaming task
        streamingTask?.cancel()
        streamingTask = nil

        // Stop speech immediately
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        // Reset state
        isSpeaking = false
        isProcessing = false
        streamingResponse = ""
        lastSpokenText = ""

        log.info("✅ AI response interrupted")
    }

    // MARK: - Listening

    func startListening() throws {
        guard !isListening else {
            log.warning("⚠️ Already listening")
            return
        }

        log.info("🎙️ Starting voice recognition (on-device)")
        lastError = nil

        // Stop speaking if active
        if isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .voiceChat, options: [.duckOthers, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            log.error("❌ Failed to configure audio session: \(error.localizedDescription)")
            lastError = "Microphone access failed"
            throw error
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            log.error("❌ Failed to create recognition request")
            lastError = "Speech recognition setup failed"
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true // CRITICAL: OFFLINE ONLY
        log.info("✅ On-device recognition mode ENFORCED")

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            log.info("🔊 Audio engine started")
        } catch {
            log.error("❌ Failed to start audio engine: \(error.localizedDescription)")
            lastError = "Audio recording failed"
            throw error
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                Task { @MainActor in
                    self.currentTranscript = result.bestTranscription.formattedString

                    if result.isFinal {
                        self.log.info("✅ Transcription complete: '\(self.currentTranscript)'")
                        await self.handleQuestion(self.currentTranscript)
                    }
                }
            }

            if let error = error {
                Task { @MainActor in
                    self.log.error("❌ Recognition error: \(error.localizedDescription)")
                    self.lastError = "Voice recognition failed"
                    self.stopListening()
                }
            }
        }

        isListening = true
        currentTranscript = ""
    }

    func stopListening() {
        guard isListening else { return }

        log.info("🛑 Stopping voice recognition")
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        // Deactivate audio session to restore other audio playback
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            log.info("✅ Audio session deactivated")
        } catch {
            log.error("⚠️ Failed to deactivate audio session: \(error.localizedDescription)")
        }

        isListening = false
    }

    // MARK: - Question Handling (with Streaming)

    private func handleQuestion(_ question: String) async {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            log.warning("⚠️ Empty question received")
            return
        }

        log.info("❓ Processing question: '\(question)'")
        stopListening()

        // Add user message
        let userMessage = VoiceMessage(text: question, isUser: true)
        conversation.append(userMessage)
        currentTranscript = ""

        // Start processing
        isProcessing = true
        streamingResponse = ""
        lastSpokenText = ""

        // Stream AI response
        await streamAIResponse(to: question)

        // Auto-listen for follow-up (with small delay)
        if !streamingResponse.isEmpty {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            try? startListening()
        }
    }

    /// Stream AI response using Foundation Models
    private func streamAIResponse(to question: String) async {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            await handleFallbackResponse(to: question)
            return
        }

        // Check AI availability
        guard fmClient.capability() == .available else {
            log.error("❌ Apple Intelligence not available")
            lastError = "AI is not available right now"
            await handleFallbackResponse(to: question)
            return
        }

        log.info("🧠 Starting streaming response...")

        do {
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                // Create session with context-aware system prompt
                let session = LanguageModelSession {
                    context.systemPrompt()
                }

                // Build prompt with conversation history
                let conversationHistory = formatConversationHistory()
                let prompt = """
                Recent conversation:
                \(conversationHistory)

                Student's question: \(question)

                Respond naturally and concisely (2-3 sentences). Ask follow-up questions to encourage deeper understanding.
                """

                let options = GenerationOptions(
                    sampling: .greedy,
                    temperature: 0.7 // Conversational warmth
                )

                // Stream the response
                let stream = session.streamResponse(to: prompt, options: options)

                // Start speaking as soon as we have content
                isSpeaking = true

                var fullResponse = ""

                for try await partial in stream {
                    // Update UI immediately
                    streamingResponse = partial.content
                    fullResponse = partial.content

                    // Speak new sentences as they arrive
                    let newText = extractNewText(from: partial.content, after: lastSpokenText)
                    if !newText.isEmpty {
                        speakTextIncremental(newText)
                        lastSpokenText = partial.content
                    }
                }

                // Finalize message
                let assistantMessage = VoiceMessage(text: fullResponse, isUser: false)
                conversation.append(assistantMessage)

                log.info("✅ Streaming response complete: \(fullResponse.count) chars")

                isProcessing = false

                // Wait for speech to finish
                while isSpeaking {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            } else {
                // Fallback for older iOS versions
                await handleFallbackResponse(to: question)
            }
            #else
            // FoundationModels not available
            await handleFallbackResponse(to: question)
            #endif

        } catch {
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                if let genError = error as? LanguageModelSession.GenerationError {
                    switch genError {
                    case .guardrailViolation:
                        log.error("❌ Guardrail violation")
                        lastError = "I can't help with that. Let's focus on your studies!"
                    case .refusal:
                        log.error("❌ Model refused request")
                        lastError = "I'm not able to answer that question."
                    default:
                        log.error("❌ Streaming failed: \(error.localizedDescription)")
                        lastError = "Something went wrong. Try asking again."
                    }
                } else {
                    log.error("❌ Streaming failed: \(error.localizedDescription)")
                    lastError = "Something went wrong. Try asking again."
                }
            }
            #endif
            await handleErrorResponse()
        }

        #else
        await handleFallbackResponse(to: question)
        #endif
    }

    /// Extract only new text from current response
    private func extractNewText(from current: String, after previous: String) -> String {
        guard current.count > previous.count else { return "" }
        let startIndex = current.index(current.startIndex, offsetBy: previous.count)
        return String(current[startIndex...])
    }

    /// Format conversation history for context
    private func formatConversationHistory() -> String {
        let recentMessages = conversation.suffix(5) // Last 5 messages
        if recentMessages.isEmpty {
            return "This is the start of the conversation."
        }
        return recentMessages.map { message in
            let role = message.isUser ? "Student" : "Tutor"
            return "\(role): \(message.text)"
        }.joined(separator: "\n")
    }

    /// Fallback response when Apple Intelligence unavailable
    private func handleFallbackResponse(to question: String) async {
        let fallbackResponse = "I'm currently unavailable. Apple Intelligence must be enabled for voice conversations. You can enable it in Settings > Apple Intelligence."
        streamingResponse = fallbackResponse

        let message = VoiceMessage(text: fallbackResponse, isUser: false)
        conversation.append(message)

        isProcessing = false

        await speak(fallbackResponse)
    }

    /// Handle error response
    private func handleErrorResponse() async {
        let errorResponse = lastError ?? "Sorry, I had trouble with that. Could you rephrase?"
        streamingResponse = errorResponse

        let message = VoiceMessage(text: errorResponse, isUser: false)
        conversation.append(message)

        isProcessing = false

        await speak(errorResponse)
    }

    // MARK: - Speaking

    private func speak(_ text: String) async {
        guard !text.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: text)

        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }

        utterance.rate = 0.52 // Slightly faster for better flow
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isSpeaking = true
        speechSynthesizer.speak(utterance)

        log.info("🔊 Speaking: \(text.prefix(50))...")

        // Wait for speech to finish
        while isSpeaking {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    /// Speak text incrementally as it streams in (sentence-by-sentence)
    private func speakTextIncremental(_ text: String) {
        guard !text.isEmpty else { return }

        // Extract complete sentences from the new text
        let sentences = extractCompleteSentences(from: text)

        for sentence in sentences {
            let utterance = AVSpeechUtterance(string: sentence)

            if let voice = AVSpeechSynthesisVoice(language: "en-US") {
                utterance.voice = voice
            }

            utterance.rate = 0.52
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0

            speechSynthesizer.speak(utterance)
            log.info("🔊 Speaking sentence: \(sentence.prefix(30))...")
        }
    }

    /// Extract complete sentences from text
    private func extractCompleteSentences(from text: String) -> [String] {
        let sentenceEndings: Set<Character> = [".", "!", "?"]
        var sentences: [String] = []
        var currentSentence = ""

        for char in text {
            currentSentence.append(char)

            if sentenceEndings.contains(char) {
                let trimmed = currentSentence.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                currentSentence = ""
            }
        }

        // Add remaining text if it looks complete (ends with space or newline)
        if !currentSentence.isEmpty {
            let trimmed = currentSentence.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && (text.last?.isWhitespace == true || text.last?.isNewline == true) {
                sentences.append(trimmed)
            }
        }

        return sentences
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

// MARK: - Voice Message (Simple in-memory message for UI)

struct VoiceMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

// MARK: - Preview

#Preview {
    VoiceAssistantView()
}

// MARK: - VoiceRecordView

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

// MARK: - LectureCollaborationController
#if canImport(Combine)
#endif
#if canImport(GroupActivities)
#endif

struct CollaborationParticipant: Identifiable, Hashable {
    let id: UUID
    let name: String
}

struct CollaborativeHighlight: Codable, Hashable {
    let id: UUID
    let startTime: Double
    let endTime: Double
    let excerpt: String
    let authorName: String?
}

@MainActor
@Observable
final class LectureCollaborationController {
    enum State {
        case unavailable
        case idle
        case waiting
        case active
        case ended
    }

    private(set) var state: State = .unavailable
    private(set) var participants: [CollaborationParticipant] = []
    private(set) var lastError: Error?

    #if canImport(GroupActivities)
    @available(iOS 17.0, *)
    private var session: GroupSession<LectureCollaborationActivity>?
    @available(iOS 17.0, *)
    private var messenger: GroupSessionMessenger?
    #endif

    init() {
        #if canImport(GroupActivities)
        if #available(iOS 17.0, *) {
            state = .idle
        } else {
            state = .unavailable
        }
        #else
        state = .unavailable
        #endif
    }

    func startSharing(forTitle title: String) async {
        #if canImport(GroupActivities)
        guard #available(iOS 17.0, *) else { return }

        do {
            let activity = LectureCollaborationActivity(title: title)
            state = .waiting

            switch await activity.prepareForActivation() {
            case .activationPreferred:
                _ = try await activity.activate()
            case .activationDisabled:
                state = .unavailable
                return
            case .cancelled:
                state = .idle
                return
            @unknown default:
                state = .idle
                return
            }

            Task { [weak self] in
                await self?.listenForSessions(activity: activity)
            }
        } catch {
            lastError = error
            state = .idle
        }
        #endif
    }

    func endSharing() {
        #if canImport(GroupActivities)
        if #available(iOS 17.0, *) {
            session?.end()
            session = nil
            messenger = nil
        }
        #endif
        state = .ended
        participants.removeAll()
    }

    func broadcast(highlight: CollaborativeHighlight) async {
        #if canImport(GroupActivities)
        guard #available(iOS 17.0, *), let messenger else { return }
        do {
            try await messenger.send(highlight)
        } catch {
            lastError = error
        }
        #endif
    }

    #if canImport(GroupActivities)
    @available(iOS 17.0, *)
    private func listenForSessions(activity: LectureCollaborationActivity) async {
        for await session in LectureCollaborationActivity.sessions() {
            configure(session)
        }
    }

    @available(iOS 17.0, *)
    private func configure(_ session: GroupSession<LectureCollaborationActivity>) {
        self.session = session
        messenger = GroupSessionMessenger(session: session)
        participants = session.activeParticipants.map { participant in
            CollaborationParticipant(
                id: participant.id,
                name: participant.id.uuidString
            )
        }
        state = .active

        Task { [weak self] in
            await self?.listenForParticipantChanges(session: session)
        }

        Task { [weak self] in
            await self?.listenForHighlights(session: session)
        }
    }

    @available(iOS 17.0, *)
    private func listenForParticipantChanges(session: GroupSession<LectureCollaborationActivity>) async {
        for await change in session.$activeParticipants.values {
            participants = change.map { participant in
                CollaborationParticipant(id: participant.id, name: participant.id.uuidString)
            }
        }
    }

    @available(iOS 17.0, *)
    private func listenForHighlights(session: GroupSession<LectureCollaborationActivity>) async {
        guard let messenger else { return }
        for await message in messenger.messages(of: CollaborativeHighlight.self) {
            NotificationCenter.default.post(name: .collaborativeHighlightReceived, object: message)
        }
    }
    #endif
}

#if canImport(GroupActivities)
@available(iOS 17.0, *)
struct LectureCollaborationActivity: GroupActivity {
    let title: String

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "\(title) · CardGenie"
        metadata.fallbackURL = URL(string: "cardgenie://record")
        metadata.type = .generic
        return metadata
    }
}
#endif

extension Notification.Name {
    static let collaborativeHighlightReceived = Notification.Name("LectureCollaborationHighlightReceived")
}

// MARK: - LiveHighlightActivityManager
#if canImport(ActivityKit)
#endif

struct LiveHighlightSnapshot: Hashable {
    let highlightTitle: String
    let timestampLabel: String
    let highlightCount: Int
    let participants: [String]
}

#if canImport(ActivityKit)
@available(iOS 17.0, *)
struct LectureHighlightActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var highlightTitle: String
        var timestampLabel: String
        var highlightCount: Int
        var participants: [String]
    }

    var sessionID: UUID
    var topic: String
}
#endif

@MainActor
final class LiveHighlightActivityManager {
    private(set) var isActive = false
    private var sessionID: UUID?

    #if canImport(ActivityKit)
    @available(iOS 17.0, *)
    private var activity: Activity<LectureHighlightActivityAttributes>?
    #endif

    func start(topic: String, sessionID: UUID, snapshot: LiveHighlightSnapshot?) async {
        self.sessionID = sessionID

        #if canImport(ActivityKit)
        if #available(iOS 17.0, *) {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                isActive = false
                return
            }

            let attributes = LectureHighlightActivityAttributes(sessionID: sessionID, topic: topic)
            let state = LectureHighlightActivityAttributes.ContentState(
                highlightTitle: snapshot?.highlightTitle ?? "Starting...",
                timestampLabel: snapshot?.timestampLabel ?? "00:00",
                highlightCount: snapshot?.highlightCount ?? 0,
                participants: snapshot?.participants ?? []
            )

            activity = try? Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil)
            )
            isActive = activity != nil
        } else {
            isActive = false
        }
        #else
        isActive = false
        #endif
    }

    func update(snapshot: LiveHighlightSnapshot) async {
        #if canImport(ActivityKit)
        if #available(iOS 17.0, *), let activity {
            let state = LectureHighlightActivityAttributes.ContentState(
                highlightTitle: snapshot.highlightTitle,
                timestampLabel: snapshot.timestampLabel,
                highlightCount: snapshot.highlightCount,
                participants: snapshot.participants
            )
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        #endif
    }

    func end() async {
        #if canImport(ActivityKit)
        if #available(iOS 17.0, *), let activity {
            let finalState = LectureHighlightActivityAttributes.ContentState(
                highlightTitle: "",
                timestampLabel: "",
                highlightCount: 0,
                participants: []
            )
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            self.activity = nil
        }
        #endif
        isActive = false
        sessionID = nil
    }
}

// MARK: - LiveLectureContext

@MainActor
@Observable
final class LiveLectureContext: LectureRecorderDelegate {
    struct LiveHighlight: Identifiable, Hashable {
        let id: UUID
        let startTime: Double
        let endTime: Double
        let excerpt: String
        let summary: String
        let confidence: Double
        let kind: HighlightCandidate.Kind
        var authorName: String?
        var isPinned: Bool
        var isCardCandidate: Bool

        var timestampLabel: String {
            let minutes = Int(startTime) / 60
            let seconds = Int(startTime) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    struct SessionSummary {
        let session: LectureSession
        let highlights: [HighlightMarker]
        let participants: [CollaborationParticipant]
        let transcript: String
    }

    private(set) var transcript: String = ""
    private(set) var highlights: [LiveHighlight] = []
    private(set) var isRecording = false
    private(set) var isLiveActivityRunning = false
    private(set) var lastErrorMessage: String?
    private(set) var summary: SessionSummary?

    let collaboration: LectureCollaborationController

    private let recorder: LectureRecorder
    private let highlightExtractor: HighlightExtractor
    private let activityManager: LiveHighlightActivityManager

    private var activeRecordingID: UUID?
    private var activeTopic: String = ""
    private var modelContext: ModelContext?
    private var notificationToken: NSObjectProtocol?

    @MainActor
    init(
        recorder: LectureRecorder? = nil,
        highlightExtractor: HighlightExtractor? = nil,
        activityManager: LiveHighlightActivityManager? = nil,
        collaboration: LectureCollaborationController? = nil
    ) {
        let recorderInstance = recorder ?? LectureRecorder()
        let extractorInstance = highlightExtractor ?? HighlightExtractor()
        let activityManagerInstance = activityManager ?? LiveHighlightActivityManager()
        let collaborationController = collaboration ?? LectureCollaborationController()

        self.recorder = recorderInstance
        self.highlightExtractor = extractorInstance
        self.activityManager = activityManagerInstance
        self.collaboration = collaborationController
        recorderInstance.delegate = self

        let token = NotificationCenter.default.addObserver(
            forName: .collaborativeHighlightReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let highlight = notification.object as? CollaborativeHighlight
            else { return }

            Task { @MainActor [weak self] in
                self?.handleCollaborativeHighlight(highlight)
            }
        }
        notificationToken = token
    }

    @MainActor
    deinit {
        if let token = notificationToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Permissions

    func requestPermissions() async -> Bool {
        await recorder.requestPermissions()
    }

    // MARK: - Recording Lifecycle

    func startRecording(topic: String, context: ModelContext) async throws {
        guard !isRecording else { return }

        activeTopic = topic.isEmpty ? "Lecture" : topic
        modelContext = context
        activeRecordingID = UUID()
        highlights.removeAll()
        summary = nil
        lastErrorMessage = nil

        do {
            try recorder.startRecording(title: activeTopic)
            isRecording = true
            transcript = ""
            await activityManager.start(topic: activeTopic, sessionID: activeRecordingID ?? UUID(), snapshot: nil)
            isLiveActivityRunning = activityManager.isActive
        } catch {
            lastErrorMessage = error.localizedDescription
            isRecording = false
            throw error
        }
    }

    func stopRecording() async -> SessionSummary? {
        guard isRecording else { return summary }

        let session = await recorder.stopRecording()
        await activityManager.end()
        isLiveActivityRunning = false
        collaboration.endSharing()
        isRecording = false

        guard let session, let context = modelContext else {
            return nil
        }

        session.sharePlayState = mapCollaborationState(collaboration.state)
        session.collaborationGroupID = activeRecordingID

        let markers = highlights.map { highlight -> HighlightMarker in
            let marker = HighlightMarker(
                startTime: highlight.startTime,
                endTime: highlight.endTime,
                transcriptSnippet: highlight.excerpt,
                summary: highlight.summary,
                authorName: highlight.authorName,
                authorID: nil,
                confidence: highlight.confidence,
                isPinned: highlight.isPinned,
                isCardCandidate: highlight.isCardCandidate
            )
            marker.session = session
            return marker
        }

        markers.forEach { session.liveHighlights.append($0) }

        context.insert(session)

        do {
            try context.save()
        } catch {
            lastErrorMessage = "Failed to save lecture: \(error.localizedDescription)"
        }

        let summary = SessionSummary(
            session: session,
            highlights: markers,
            participants: collaboration.participants,
            transcript: transcript
        )
        self.summary = summary
        return summary
    }

    func cancelRecording() {
        isRecording = false
        transcript = ""
        highlights.removeAll()
        activeRecordingID = nil
        summary = nil
        lastErrorMessage = nil
        collaboration.endSharing()
        Task {
            await activityManager.end()
        }
    }

    // MARK: - Highlight Management

    func addManualHighlight() {
        let timestamp = recorder.currentTimestamp()
        let excerpt = recentTranscriptExcerpt()

        let candidate = highlightExtractor.manualHighlight(transcript: excerpt, timestamp: timestamp)
        appendHighlight(from: candidate, authorName: "You")
        Task {
            await collaboration.broadcast(
                highlight: CollaborativeHighlight(
                    id: candidate.id,
                    startTime: candidate.startTime,
                    endTime: candidate.endTime,
                    excerpt: candidate.excerpt,
                    authorName: "You"
                )
            )
        }
    }

    func togglePin(for highlightID: UUID) {
        guard let index = highlights.firstIndex(where: { $0.id == highlightID }) else { return }
        highlights[index].isPinned.toggle()
        highlights[index].isCardCandidate = highlights[index].isPinned || highlights[index].confidence >= 0.7
    }

    func markAsCardCandidate(_ highlightID: UUID, isCandidate: Bool) {
        guard let index = highlights.firstIndex(where: { $0.id == highlightID }) else { return }
        highlights[index].isCardCandidate = isCandidate
    }

    // MARK: - SharePlay

    func startSharePlay() async {
        await collaboration.startSharing(forTitle: activeTopic.isEmpty ? "Lecture" : activeTopic)
    }

    // MARK: - Flashcard Generation

    func generateCards(context: ModelContext, deckName: String? = nil) async throws -> FlashcardSet? {
        guard let summary else { return nil }
        let builder = HighlightCardBuilder()
        let set = try await builder.buildDeck(
            from: summary.highlights,
            session: summary.session,
            preferredName: deckName ?? summary.session.title,
            context: context
        )
        summary.highlights.forEach { marker in
            if marker.linkedFlashcard == nil,
               let card = set.cards.first(where: { $0.linkedEntryID == marker.id }) {
                marker.linkedFlashcard = card
            }
        }
        return set
    }

    // MARK: - LectureRecorderDelegate

    func recorder(_ recorder: LectureRecorder, didUpdateTranscript transcript: String) {
        self.transcript = transcript
    }

    func recorder(_ recorder: LectureRecorder, didProduce chunk: TranscriptChunk) {
        guard let candidate = highlightExtractor.evaluate(chunk: chunk) else { return }
        appendHighlight(from: candidate, authorName: nil)
        Task {
            await collaboration.broadcast(
                highlight: CollaborativeHighlight(
                    id: candidate.id,
                    startTime: candidate.startTime,
                    endTime: candidate.endTime,
                    excerpt: candidate.excerpt,
                    authorName: nil
                )
            )
        }
    }

    func recorder(_ recorder: LectureRecorder, didEncounter error: Error) {
        lastErrorMessage = error.localizedDescription
    }

    // MARK: - Helpers

    private func appendHighlight(from candidate: HighlightCandidate, authorName: String?) {
        let highlight = LiveHighlight(
            id: candidate.id,
            startTime: candidate.startTime,
            endTime: candidate.endTime,
            excerpt: candidate.excerpt,
            summary: candidate.summary,
            confidence: candidate.confidence,
            kind: candidate.kind,
            authorName: authorName,
            isPinned: candidate.kind != .automatic,
            isCardCandidate: candidate.confidence >= 0.7 || candidate.kind != .automatic
        )

        highlights.append(highlight)

        let snapshot = LiveHighlightSnapshot(
            highlightTitle: highlight.summary,
            timestampLabel: highlight.timestampLabel,
            highlightCount: highlights.count,
            participants: collaboration.participants.map(\.name)
        )

        Task {
            await activityManager.update(snapshot: snapshot)
        }
    }

    private func recentTranscriptExcerpt() -> String {
        let truncated = transcript.suffix(220)
        return String(truncated.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func handleCollaborativeHighlight(_ highlight: CollaborativeHighlight) {
        guard highlights.contains(where: { $0.id == highlight.id }) == false else { return }
        let candidate = highlightExtractor.collaborativeHighlight(
            highlight.excerpt,
            start: highlight.startTime,
            end: highlight.endTime,
            author: highlight.authorName
        )
        appendHighlight(from: candidate, authorName: highlight.authorName)
    }

    private func mapCollaborationState(_ state: LectureCollaborationController.State) -> LectureCollaborationState {
        switch state {
        case .unavailable, .idle:
            return .inactive
        case .waiting:
            return .waiting
        case .active:
            return .active
        case .ended:
            return .ended
        }
    }
}

// MARK: - AI Chat View

/// Conversational AI chat interface powered by Apple Intelligence Foundation Models
/// Provides streaming text responses with voice input support
@available(iOS 26.0, *)
struct AIChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var flashcardSets: [FlashcardSet]
    @StateObject private var chatEngine = AIChatEngine()
    @State private var messageText = ""
    @State private var showPermissionAlert = false
    @State private var currentMode: ChatMode = .general
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Voice status indicator
                if chatEngine.isListening || chatEngine.isSpeaking || chatEngine.isGenerating {
                    voiceStatusBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if chatEngine.messages.isEmpty {
                                emptyStateView
                                    .padding(.top, 40)
                            } else {
                                ForEach(chatEngine.messages) { message in
                                    AIChatMessageBubble(message: message, chatEngine: chatEngine)
                                        .id(message.id)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isInputFocused = false
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.immediately)
                    .onChange(of: chatEngine.messages.count) { _, _ in
                        if let lastMessage = chatEngine.messages.last {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: currentMode) { oldMode, newMode in
                        // Update engine mode and context
                        let context = PromptContext.from(flashcardSets: flashcardSets)
                        chatEngine.setMode(newMode, context: context)
                    }
                }

                // Input bar at bottom
                inputBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(currentMode.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleMenu {
                ForEach(ChatMode.allCases) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            currentMode = mode
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.displayName)
                                    .font(.headline)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: mode.icon)
                                .foregroundStyle(Color(mode.color))
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        chatEngine.clearConversation()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.cosmicPurple.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .glassEffect(.regular, in: .circle)

                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.cosmicPurple)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .alert("AI Not Available", isPresented: $showPermissionAlert) {
                Button("OK") {}
            } message: {
                Text(chatEngine.availabilityMessage)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon with glass effect
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cosmicPurple.opacity(0.2), .mysticBlue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .glassEffect(.regular, in: .circle)

                Image(systemName: "sparkles")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cosmicPurple, .mysticBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.variableColor.iterative.reversing)
            }

            VStack(spacing: 12) {
                Text("Ask me anything")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text("100% on-device, private, and secure")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Voice Status Banner

    private var voiceStatusBanner: some View {
        HStack(spacing: 12) {
            // Status icon with animation
            Image(systemName: voiceStatusIcon)
                .font(.title3)
                .foregroundStyle(voiceStatusColor)
                .symbolEffect(.pulse, isActive: true)

            // Status text
            Text(voiceStatusText)
                .font(.subheadline.bold())
                .foregroundStyle(voiceStatusColor)

            Spacer()

            // Real-time transcript preview (while listening)
            if chatEngine.isListening && !chatEngine.currentTranscript.isEmpty {
                Text(chatEngine.currentTranscript)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 200)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassPanel()
        .animation(.easeInOut(duration: 0.2), value: chatEngine.isListening)
        .animation(.easeInOut(duration: 0.2), value: chatEngine.isSpeaking)
        .animation(.easeInOut(duration: 0.2), value: chatEngine.isGenerating)
    }

    private var voiceStatusIcon: String {
        if chatEngine.isListening {
            return "waveform"
        } else if chatEngine.isSpeaking {
            return "speaker.wave.3.fill"
        } else if chatEngine.isGenerating {
            return "brain"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var voiceStatusText: String {
        if chatEngine.isListening {
            return "Listening..."
        } else if chatEngine.isSpeaking {
            return "Speaking..."
        } else if chatEngine.isGenerating {
            return "Thinking..."
        } else {
            return "Ready"
        }
    }

    private var voiceStatusColor: Color {
        if chatEngine.isListening {
            return .blue
        } else if chatEngine.isSpeaking {
            return .green
        } else if chatEngine.isGenerating {
            return .orange
        } else {
            return .cosmicPurple
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            // Enhanced voice input button with iOS 26 glass
            Button {
                chatEngine.toggleVoiceInput()
            } label: {
                ZStack {
                    // Glass background circle with state-based color
                    Circle()
                        .fill(micButtonBackground)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular, in: .circle)

                    // Icon with state-based appearance
                    Image(systemName: micButtonIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(micButtonForeground)
                        .symbolEffect(.pulse, isActive: chatEngine.isListening)
                }
            }
            .buttonStyle(.plain)
            .disabled(chatEngine.isGenerating || chatEngine.isSpeaking)
            .opacity(chatEngine.isGenerating || chatEngine.isSpeaking ? 0.5 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: chatEngine.isListening)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: chatEngine.isSpeaking)

            // Text input with iOS 26 glass styling
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                .submitLabel(.send)
                .onSubmit {
                    sendMessage()
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isInputFocused = false
                        }
                        .foregroundStyle(Color.cosmicPurple)
                    }
                }

            // Send button with iOS 26 glass
            Button {
                sendMessage()
            } label: {
                ZStack {
                    Circle()
                        .fill(messageText.isEmpty ? Color(.systemGray6) : Color.cosmicPurple)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular, in: .circle)

                    Image(systemName: "arrow.up")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: chatEngine.messages.count)
                }
            }
            .buttonStyle(.plain)
            .disabled(messageText.isEmpty || chatEngine.isGenerating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Divider()
                .opacity(0.3)
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messageText = ""
        isInputFocused = false

        Task {
            let success = await chatEngine.sendMessage(text)
            if !success {
                showPermissionAlert = true
            }
        }
    }

    // MARK: - Microphone Button States

    private var micButtonBackground: Color {
        if chatEngine.isListening {
            return .red.opacity(0.9)
        } else if chatEngine.isSpeaking {
            return .green.opacity(0.2)
        } else {
            return Color.cosmicPurple.opacity(0.15)
        }
    }

    private var micButtonIcon: String {
        if chatEngine.isListening {
            return "stop.circle.fill"
        } else if chatEngine.isSpeaking {
            return "speaker.wave.2.fill"
        } else {
            return "mic.fill"
        }
    }

    private var micButtonForeground: Color {
        if chatEngine.isListening {
            return .white
        } else if chatEngine.isSpeaking {
            return .green
        } else {
            return .cosmicPurple
        }
    }

    private var micButtonShadowColor: Color {
        if chatEngine.isListening {
            return .red.opacity(0.5)
        } else if chatEngine.isSpeaking {
            return .green.opacity(0.3)
        } else {
            return .cosmicPurple.opacity(0.2)
        }
    }
}

// MARK: - AI Chat Message Bubble

@available(iOS 26.0, *)
struct AIChatMessageBubble: View {
    let message: AIChatMessage
    @ObservedObject var chatEngine: AIChatEngine

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.isUser {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background {
                        if message.isUser {
                            // User messages with gradient and glass effect
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.cosmicPurple, .mysticBlue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(
                                    color: Color.cosmicPurple.opacity(0.3),
                                    radius: 8,
                                    x: 0,
                                    y: 2
                                )
                        } else {
                            // AI messages with iOS 26 Liquid Glass
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        // Speaking indicator for AI messages
                        if !message.isUser && chatEngine.isSpeaking && message.id == chatEngine.messages.last?.id {
                            HStack(spacing: 3) {
                                ForEach(0..<3) { index in
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 4, height: 4)
                                        .scaleEffect(chatEngine.isSpeaking ? 1.2 : 0.8)
                                        .animation(
                                            .easeInOut(duration: 0.4)
                                                .repeatForever()
                                                .delay(Double(index) * 0.15),
                                            value: chatEngine.isSpeaking
                                        )
                                }
                            }
                            .padding(8)
                            .glassOverlay(cornerRadius: 20)
                            .offset(x: -8, y: 8)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }

                if !message.isUser && message.isStreaming {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(.secondary)
                                .frame(width: 6, height: 6)
                                .scaleEffect(message.isStreaming ? 1.0 : 0.5)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: message.isStreaming
                                )
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }

            if !message.isUser {
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Mode Selector Sheet

@available(iOS 26.0, *)
struct ModeSelectorSheet: View {
    @Binding var selectedMode: ChatMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(ChatMode.allCases) { mode in
                    Button {
                        selectedMode = mode
                        dismiss()
                    } label: {
                        HStack(spacing: 16) {
                            // Icon
                            ZStack {
                                Circle()
                                    .fill(Color(mode.color).opacity(0.15))
                                    .frame(width: 50, height: 50)

                                Image(systemName: mode.icon)
                                    .font(.title3)
                                    .foregroundStyle(Color(mode.color))
                            }

                            // Info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            if selectedMode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(mode.color))
                                    .font(.title3)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Choose AI Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - AI Chat Engine

@MainActor
@available(iOS 26.0, *)
class AIChatEngine: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var messages: [AIChatMessage] = []
    @Published private(set) var isGenerating = false
    @Published private(set) var isListening = false
    @Published private(set) var isSpeaking = false
    @Published private(set) var availabilityMessage = ""
    @Published var currentTranscript = "" // Real-time transcript preview

    // Voice is always enabled - just like ChatGPT
    private let autoSpeakEnabled = true

    private let fmClient = FMClient()
    private let promptManager = PromptManager.shared
    private var currentMode: ChatMode = .general
    private var promptContext: PromptContext = PromptContext()

    // TTS support
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var speakingQueue: [String] = []
    private var isSpeakingQueued = false

    #if canImport(Speech)
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    #endif

    override init() {
        super.init()
        speechSynthesizer.delegate = self
        checkAvailability()
        #if canImport(Speech)
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        setupAudioInterruptionHandling()
        #endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func setMode(_ mode: ChatMode, context: PromptContext) {
        self.currentMode = mode
        self.promptContext = context
        // Optionally clear messages when switching modes
        messages.removeAll()
    }

    func sendMessage(_ text: String) async -> Bool {
        // Check availability
        guard fmClient.capability() == .available else {
            checkAvailability()
            return false
        }

        // Add user message
        let userMessage = AIChatMessage(text: text, isUser: true)
        messages.append(userMessage)

        // Create placeholder for assistant response
        let assistantMessage = AIChatMessage(text: "", isUser: false, isStreaming: true)
        messages.append(assistantMessage)
        let assistantIndex = messages.count - 1

        isGenerating = true
        defer { isGenerating = false }

        do {
            // Build prompt with context
            let systemPrompt = promptManager.getPrompt(mode: currentMode, context: promptContext)
            let conversationHistory = promptManager.buildConversationContext(messages: messages, maxMessages: 10)
            let fullPrompt = promptManager.formatForLLM(
                systemPrompt: systemPrompt,
                conversationHistory: conversationHistory,
                userMessage: text
            )

            // Stream response with sentence-by-sentence TTS
            var fullResponse = ""
            var lastSpokenPosition = 0 // Track what we've already spoken

            #if canImport(FoundationModels)
            // Use actual Foundation Models streaming with TTS
            for try await chunk in fmClient.streamChat(fullPrompt) {
                fullResponse = chunk
                messages[assistantIndex] = AIChatMessage(
                    text: fullResponse,
                    isUser: false,
                    isStreaming: true
                )

                // Speak complete sentences as they arrive (queued for sequential playback)
                if autoSpeakEnabled {
                    let newText = String(fullResponse.dropFirst(lastSpokenPosition))
                    if let sentenceEnd = findCompleteSentenceEnd(in: newText) {
                        let endIndex = fullResponse.index(fullResponse.startIndex, offsetBy: lastSpokenPosition + sentenceEnd)
                        let sentenceToSpeak = String(fullResponse[fullResponse.index(fullResponse.startIndex, offsetBy: lastSpokenPosition)...endIndex])

                        // Queue this sentence for speaking (will be spoken sequentially)
                        enqueueSpeech(sentenceToSpeak)

                        lastSpokenPosition = lastSpokenPosition + sentenceEnd + 1
                    }
                }
            }
            #else
            // Fallback: use complete method
            fullResponse = try await fmClient.complete(fullPrompt)
            #endif

            // Finalize message
            messages[assistantIndex] = AIChatMessage(
                text: fullResponse,
                isUser: false,
                isStreaming: false
            )

            // Queue any remaining text that wasn't spoken during streaming
            if autoSpeakEnabled && lastSpokenPosition < fullResponse.count {
                let remainingText = String(fullResponse.dropFirst(lastSpokenPosition))
                enqueueSpeech(remainingText)
            }

            return true

        } catch {
            // Remove failed message
            if assistantIndex < messages.count {
                messages.remove(at: assistantIndex)
            }

            // Add error message
            let errorMessage = "Sorry, I encountered an error. Please try again."
            messages.append(AIChatMessage(
                text: errorMessage,
                isUser: false
            ))

            // Speak error message if auto-speak is enabled
            if autoSpeakEnabled {
                await speak(errorMessage)
            }

            return false
        }
    }

    func toggleVoiceInput() {
        #if canImport(Speech)
        if isListening {
            stopListening()
        } else {
            Task {
                await startListening()
            }
        }
        #endif
    }

    #if canImport(Speech)
    private func startListening() async {
        // Stop speaking if AI is currently talking (interruption handling)
        if isSpeaking {
            stopSpeaking()
        }

        // Request permissions
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                continuation.resume(returning: authStatus)
            }
        }

        guard status == .authorized else {
            availabilityMessage = "Speech recognition not authorized"
            return
        }

        let micPermission = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        guard micPermission else {
            availabilityMessage = "Microphone access not authorized"
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .voiceChat, options: [.duckOthers, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else { return }

            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = true // ⚡ CRITICAL: Offline-only mode

            // Verify on-device support is available
            guard speechRecognizer?.supportsOnDeviceRecognition == true else {
                availabilityMessage = "On-device speech recognition not available for your language"
                return
            }

            let inputNode = audioEngine.inputNode
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self else { return }

                if let result {
                    Task { @MainActor in
                        // Update real-time transcript preview
                        self.currentTranscript = result.bestTranscription.formattedString

                        // Auto-send when speech is final
                        if result.isFinal {
                            let finalText = self.currentTranscript
                            self.currentTranscript = "" // Clear preview
                            _ = await self.sendMessage(finalText)
                            self.stopListening()
                        }
                    }
                }

                if let error = error {
                    Task { @MainActor in
                        self.availabilityMessage = "Speech recognition error: \(error.localizedDescription)"
                        self.stopListening()
                    }
                }
            }

            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isListening = true

        } catch {
            availabilityMessage = "Could not start speech recognition"
        }
    }

    private func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        currentTranscript = "" // Clear transcript preview when stopping

        // Deactivate audio session to restore other audio playback
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Log error but don't fail - this is cleanup code
            print("⚠️ Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Audio Session Interruption Handling

    private func setupAudioInterruptionHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        Task { @MainActor in
            switch type {
            case .began:
                // Interruption began (e.g., phone call, alarm)
                // Stop listening and speaking
                if isListening {
                    stopListening()
                }
                if isSpeaking {
                    stopSpeaking()
                }

            case .ended:
                // Interruption ended
                // Optionally resume listening if it was active
                // For now, we'll let the user manually restart
                guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                    return
                }
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Could automatically resume listening here if desired
                    // For now, we'll just clear the error message
                    availabilityMessage = ""
                }

            @unknown default:
                break
            }
        }
    }
    #endif

    func clearConversation() {
        messages.removeAll()
    }

    // MARK: - Text-to-Speech

    /// Speak text aloud using on-device TTS
    /// - Parameter text: The text to speak
    func speak(_ text: String) async {
        guard !text.isEmpty else { return }

        // Stop any current speech
        if isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)

        // Use high-quality on-device voice for English
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }

        utterance.rate = 0.52 // Slightly faster for natural flow
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isSpeaking = true
        speechSynthesizer.speak(utterance)

        // Wait for speech to finish
        while isSpeaking {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s polling
        }
    }

    /// Stop speaking immediately
    func stopSpeaking() {
        if isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        }
        // Also clear the queue
        speakingQueue.removeAll()
        isSpeakingQueued = false
    }

    /// Add text to the speaking queue and process it
    /// - Parameter text: The text to speak
    private func enqueueSpeech(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        speakingQueue.append(text)

        // Start processing queue if not already doing so
        if !isSpeakingQueued {
            Task {
                await processSpeakingQueue()
            }
        }
    }

    /// Process the speaking queue sequentially
    private func processSpeakingQueue() async {
        guard !isSpeakingQueued else { return }
        isSpeakingQueued = true

        while !speakingQueue.isEmpty {
            let textToSpeak = speakingQueue.removeFirst()
            await speak(textToSpeak)
        }

        isSpeakingQueued = false
    }

    /// Find the end position of the last complete sentence in text
    /// - Parameter text: The text to search for sentence boundaries
    /// - Returns: Index of the last sentence-ending character, or nil if no complete sentence found
    private func findCompleteSentenceEnd(in text: String) -> Int? {
        // Sentence endings: period, exclamation, question mark
        let sentenceEndings: Set<Character> = [".", "!", "?"]

        // Search backwards for the last sentence ending followed by space or end
        for (index, char) in text.enumerated().reversed() {
            if sentenceEndings.contains(char) {
                // Check if this is followed by a space or it's at the end
                let nextIndex = text.index(text.startIndex, offsetBy: index + 1)
                if nextIndex == text.endIndex || (nextIndex < text.endIndex && text[nextIndex].isWhitespace) {
                    return index
                }
            }
        }

        return nil
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

    // MARK: - Private Helpers

    private func checkAvailability() {
        let status = fmClient.capability()
        switch status {
        case .available:
            availabilityMessage = ""
        case .notEnabled:
            availabilityMessage = "Please enable AI features in Settings"
        case .notSupported:
            availabilityMessage = "AI features require iPhone 15 Pro or newer"
        case .modelNotReady:
            availabilityMessage = "AI model is downloading"
        case .unknown:
            availabilityMessage = "AI status unknown"
        }
    }
}
