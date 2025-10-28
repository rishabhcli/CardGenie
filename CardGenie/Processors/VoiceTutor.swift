//
//  VoiceTutor.swift
//  CardGenie
//
//  Voice tutoring with offline TTS + STT.
//  Turn-taking conversation with interruptible speech.
//

import Foundation
import AVFoundation
import Speech
import Observation

// MARK: - Voice Tutor

@Observable
final class VoiceTutor: NSObject, AVSpeechSynthesizerDelegate {
    private let llm: LLMEngine
    nonisolated(unsafe) private let speechSynthesizer = AVSpeechSynthesizer()
    nonisolated(unsafe) private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    nonisolated(unsafe) private let audioEngine = AVAudioEngine()

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // State
    private(set) var isListening = false
    private(set) var isSpeaking = false
    private(set) var conversation: [ConversationTurn] = []
    private(set) var currentTranscript = ""

    // Context for tutoring
    private var topic: String = ""
    private var contextChunks: [NoteChunk] = []

    init(llm: LLMEngine = AIEngineFactory.createLLMEngine()) {
        self.llm = llm
        super.init()
        speechSynthesizer.delegate = self
    }

    // MARK: - Start Session

    func startSession(topic: String, context: [NoteChunk] = []) async throws {
        self.topic = topic
        self.contextChunks = context
        self.conversation = []

        // Initial greeting
        let greeting = "Hi! I'm your AI tutor. What would you like to learn about \(topic)?"
        await speak(greeting)

        conversation.append(ConversationTurn(
            role: .tutor,
            text: greeting,
            timestamp: Date()
        ))
    }

    // MARK: - Listening

    func startListening() throws {
        guard !isListening else { return }

        // Stop speaking if currently speaking (interrupt)
        if isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceTutorError.setupFailed
        }

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
                self.currentTranscript = result.bestTranscription.formattedString

                if result.isFinal {
                    Task {
                        await self.handleUserInput(self.currentTranscript)
                    }
                }
            }

            if error != nil {
                self.stopListening()
            }
        }

        isListening = true
    }

    func stopListening() {
        guard isListening else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        isListening = false
    }

    // MARK: - Handle User Input

    private func handleUserInput(_ text: String) async {
        guard !text.isEmpty else { return }

        stopListening()

        // Add to conversation
        conversation.append(ConversationTurn(
            role: .student,
            text: text,
            timestamp: Date()
        ))

        // Generate tutor response
        do {
            let response = try await generateTutorResponse(userQuestion: text)

            conversation.append(ConversationTurn(
                role: .tutor,
                text: response,
                timestamp: Date()
            ))

            // Speak response
            await speak(response)

            // Automatically start listening again after speaking
            try? startListening()

        } catch {
            let errorMsg = "I'm sorry, I had trouble understanding that. Could you rephrase?"
            await speak(errorMsg)
            try? startListening()
        }
    }

    // MARK: - Generate Response

    private func generateTutorResponse(userQuestion: String) async throws -> String {
        // Build context from conversation history
        let conversationHistory = conversation.suffix(6)
            .map { turn -> String in
                let speaker: String
                switch turn.role {
                case .student:
                    speaker = "Student"
                case .tutor:
                    speaker = "Tutor"
                }
                return "\(speaker): \(turn.text)"
            }
            .joined(separator: "\n")

        // Add context from notes if available
        let notesContext = contextChunks.prefix(3)
            .map { $0.text }
            .joined(separator: "\n\n")

        let prompt = """
        You are a friendly, encouraging tutor helping a student learn about \(topic).

        CONVERSATION HISTORY:
        \(conversationHistory)

        REFERENCE NOTES:
        \(notesContext.isEmpty ? "No notes available" : notesContext)

        STUDENT'S QUESTION: \(userQuestion)

        Respond as a tutor would:
        - Be encouraging and supportive
        - Explain concepts clearly
        - Ask follow-up questions to check understanding
        - Keep responses under 3 sentences for voice conversation
        - Use simple language

        TUTOR RESPONSE:
        """

        let response = try await llm.complete(prompt, maxTokens: 200)
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Speech

    private func speak(_ text: String) async {
        await MainActor.run {
            let utterance = AVSpeechUtterance(string: text)

            // Use enhanced voice (offline neural TTS)
            if let voice = AVSpeechSynthesisVoice(language: "en-US") {
                utterance.voice = voice
            }

            utterance.rate = 0.5 // Slightly slower for clarity
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0

            isSpeaking = true
            speechSynthesizer.speak(utterance)
        }

        // Wait for speech to finish
        while isSpeaking {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
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

    // MARK: - Helpers

    func interrupt() {
        if isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        }
    }

    func endSession() {
        stopListening()
        interrupt()
        conversation.append(ConversationTurn(
            role: .tutor,
            text: "Great session! Keep up the good work!",
            timestamp: Date()
        ))
    }
}

// MARK: - Models

struct ConversationTurn: Sendable {
    enum Role: Sendable {
        case student
        case tutor
    }

    let role: Role
    let text: String
    let timestamp: Date
}

// MARK: - Errors

enum VoiceTutorError: LocalizedError {
    case setupFailed
    case recognitionFailed
    case synthesisFailure

    var errorDescription: String? {
        switch self {
        case .setupFailed: return "Failed to setup voice tutor"
        case .recognitionFailed: return "Speech recognition failed"
        case .synthesisFailure: return "Text-to-speech failed"
        }
    }
}
