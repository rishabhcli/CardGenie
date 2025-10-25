//
//  SpeechToTextConverter.swift
//  CardGenie
//
//  Speech-to-text conversion using Apple's Speech framework (iOS 13+).
//  Supports real-time transcription and audio recording.
//

import Speech
import AVFoundation
import OSLog
import Combine

/// Speech recognition and audio recording engine
@MainActor
final class SpeechToTextConverter: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "com.cardgenie.app", category: "Speech")

    // Published state
    @Published var transcribedText = ""
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var error: SpeechError?
    @Published var recordingDuration: TimeInterval = 0

    // Speech recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // Audio recording
    private let audioEngine = AVAudioEngine()
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingTimerTask: Task<Void, Never>?

    // MARK: - Authorization

    /// Check and request speech recognition authorization
    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                let authorized = status == .authorized
                if !authorized {
                    self.logger.warning("Speech recognition not authorized: \(String(describing: status))")
                }
                continuation.resume(returning: authorized)
            }
        }
    }

    /// Check current authorization status
    func authorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        return SFSpeechRecognizer.authorizationStatus()
    }

    /// Check if speech recognition is available
    func isAvailable() -> Bool {
        guard let recognizer = speechRecognizer else {
            logger.warning("Speech recognizer is nil")
            return false
        }
        return recognizer.isAvailable
    }

    // MARK: - Recording

    /// Start recording audio and transcribing in real-time
    func startRecording() async throws {
        // Check authorization
        guard authorizationStatus() == .authorized else {
            logger.error("Speech recognition not authorized")
            throw SpeechError.notAuthorized
        }

        if #available(iOS 13.0, *), let recognizer = speechRecognizer, !recognizer.supportsOnDeviceRecognition {
            logger.error("On-device recognition not supported on this device")
            throw SpeechError.onDeviceNotSupported
        }

        guard isAvailable() else {
            logger.error("Speech recognizer not available")
            throw SpeechError.recognizerUnavailable
        }

        // Cancel any ongoing tasks
        if recognitionTask != nil {
            stopRecording()
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Setup recording URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("recording-\(UUID().uuidString).m4a")

        // Setup audio recorder for saving
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        if let url = recordingURL {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.unableToCreateRequest
        }

        if #available(iOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        recognitionRequest.shouldReportPartialResults = true

        // Get audio input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on audio input
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Prepare and start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                Task { @MainActor in
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }

            if error != nil || result?.isFinal == true {
                Task { @MainActor in
                    self.stopRecording()
                }
            }
        }

        // Update state
        isRecording = true
        recordingDuration = 0

        // Start duration timer
        recordingTimerTask?.cancel()
        recordingTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 100_000_000)
                } catch {
                    return
                }
                await MainActor.run {
                    guard let self else { return }
                    self.recordingDuration += 0.1
                }
            }
        }

        logger.info("Recording started")
    }

    /// Stop recording and finalize transcription
    func stopRecording() {
        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Stop audio recorder
        audioRecorder?.stop()

        // Cancel recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        // Stop timer
        recordingTimerTask?.cancel()
        recordingTimerTask = nil

        // Update state
        isRecording = false

        logger.info("Recording stopped. Duration: \(self.recordingDuration)s")
    }

    /// Get the URL of the saved audio recording
    func getSavedRecordingURL() -> URL? {
        return recordingURL
    }

    /// Delete the saved recording
    func deleteSavedRecording() {
        guard let url = recordingURL else { return }

        do {
            try FileManager.default.removeItem(at: url)
            logger.info("Deleted recording at \(url)")
        } catch {
            logger.error("Failed to delete recording: \(error.localizedDescription)")
        }

        recordingURL = nil
    }

    // MARK: - Offline Transcription

    /// Transcribe a pre-recorded audio file
    func transcribeAudioFile(_ url: URL) async throws -> String {
        guard authorizationStatus() == .authorized else {
            throw SpeechError.notAuthorized
        }

        guard isAvailable() else {
            throw SpeechError.recognizerUnavailable
        }

        isProcessing = true
        defer { isProcessing = false }

        logger.info("Starting transcription of audio file")

        return try await withCheckedThrowingContinuation { continuation in
        let request = SFSpeechURLRecognitionRequest(url: url)
        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = true
        }
        request.shouldReportPartialResults = false

            speechRecognizer?.recognitionTask(with: request) { result, error in
                if let error = error {
                    self.logger.error("Transcription failed: \(error.localizedDescription)")
                    continuation.resume(throwing: SpeechError.transcriptionFailed(error.localizedDescription))
                    return
                }

                if let result = result, result.isFinal {
                    let text = result.bestTranscription.formattedString
                    self.logger.info("Transcription completed: \(text.count) characters")
                    continuation.resume(returning: text)
                }
            }
        }
    }
}

// MARK: - Speech Error Types

enum SpeechError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case unableToCreateRequest
    case transcriptionFailed(String)
    case audioEngineError
    case onDeviceNotSupported

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Microphone access is required to record lectures. Please enable it in Settings."
        case .recognizerUnavailable:
            return "Speech recognition is not available on this device or for this language."
        case .unableToCreateRequest:
            return "Unable to start speech recognition. Please try again."
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .audioEngineError:
            return "Audio recording error. Please check your microphone."
        case .onDeviceNotSupported:
            return "This device doesn’t support on-device speech recognition required for offline transcription."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAuthorized:
            return "Go to Settings > Privacy & Security > Microphone and enable access for CardGenie."
        case .recognizerUnavailable:
            return "Make sure you have an internet connection for the first transcription, then it will work offline."
        case .unableToCreateRequest:
            return "Restart the app and try again."
        case .transcriptionFailed:
            return "Make sure you're speaking clearly in a quiet environment."
        case .audioEngineError:
            return "Check that your microphone is working and not being used by another app."
        case .onDeviceNotSupported:
            return "Use a device that supports on-device speech recognition or connect to a newer Apple Intelligence-compatible device."
        }
    }
}
