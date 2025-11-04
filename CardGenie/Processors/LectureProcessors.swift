//
//  LectureProcessors.swift
//  CardGenie
//
//  Lecture recording and on-device transcription.
//

import Foundation
import AVFoundation
import Speech

// MARK: - LectureRecorder

// MARK: - Lecture Recorder

protocol LectureRecorderDelegate: AnyObject {
    @MainActor
    func recorder(_ recorder: LectureRecorder, didUpdateTranscript transcript: String)

    @MainActor
    func recorder(_ recorder: LectureRecorder, didProduce chunk: TranscriptChunk)

    @MainActor
    func recorder(_ recorder: LectureRecorder, didEncounter error: Error)
}

@Observable
final class LectureRecorder: NSObject {
    private let audioEngine = AVAudioEngine()
    private let transcriber = OnDeviceTranscriber()
    weak var delegate: LectureRecorderDelegate?

    private var audioFile: AVAudioFile?
    private var audioFileURL: URL?

    private let llm: LLMEngine
    private let embedding: EmbeddingEngine

    // State
    private(set) var isRecording = false
    private(set) var transcript = ""
    private(set) var liveNotes = ""
    private(set) var duration: TimeInterval = 0
    private(set) var chunks: [TranscriptChunk] = []

    private var recordingStartTime: Date?
    private var lastChunkTime: Date?
    private var rollingBuffer = ""

    // Rolling summary timer
    private var summaryTimer: Timer?

    @MainActor
    func currentTimestamp() -> TimeInterval {
        if let start = recordingStartTime {
            return Date().timeIntervalSince(start)
        }
        return duration
    }

    init(llm: LLMEngine = AIEngineFactory.createLLMEngine(),
         embedding: EmbeddingEngine = AIEngineFactory.createEmbeddingEngine()) {
        self.llm = llm
        self.embedding = embedding
        super.init()
        transcriber.delegate = self
    }

    // MARK: - Permission

    func requestPermissions() async -> Bool {
        guard await transcriber.prepareAuthorization() else {
            return false
        }

        // Request microphone
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let micAuth = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            return micAuth
        } catch {
            return false
        }
    }

    // MARK: - Recording

    func startRecording(title: String) throws {
        guard !isRecording else { return }

        // Reset state
        transcript = ""
        liveNotes = ""
        chunks = []
        duration = 0
        rollingBuffer = ""
        recordingStartTime = Date()
        lastChunkTime = Date()

        // Setup audio file for saving
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        audioFileURL = documentsPath.appendingPathComponent("lecture_\(UUID().uuidString).m4a")

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        do {
            try transcriber.startStreaming()
        } catch {
            throw RecordingError.recognitionFailed
        }

        // Setup audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Setup audio file
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioFile = try AVAudioFile(forWriting: audioFileURL!, settings: settings)

        // Install tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.transcriber.append(buffer)

            // Write to file
            try? self?.audioFile?.write(from: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition
        isRecording = true

        // Start rolling summary timer (every 45 seconds)
        summaryTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
            Task {
                await self?.generateRollingSummary()
            }
        }
    }

    func stopRecording() async -> LectureSession? {
        guard isRecording else { return nil }

        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Stop recognition
        transcriber.stop()

        summaryTimer?.invalidate()
        summaryTimer = nil

        isRecording = false

        // Calculate duration
        if let start = recordingStartTime {
            duration = Date().timeIntervalSince(start)
        }

        // Create lecture session
        let session = LectureSession(title: "Lecture \(Date().formatted(date: .abbreviated, time: .shortened))")
        session.duration = duration
        session.audioFileURL = audioFileURL
        session.liveNotes = liveNotes
        session.transcriptComplete = true

        // Process final buffer
        if !rollingBuffer.isEmpty {
            await createChunkFromBuffer(session: session)
        }

        return session
    }

    // MARK: - Recognition Handling

    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult, isFinal: Bool) {
        let transcription = result.bestTranscription.formattedString
        transcript = transcription
        delegate?.recorder(self, didUpdateTranscript: transcription)

        // Update rolling buffer
        if isFinal {
            rollingBuffer += transcription + " "

            // Check if we should chunk (based on silence or length)
            if rollingBuffer.split(separator: " ").count > 100 {
                Task {
                    await createChunkFromBuffer(session: nil)
                }
            }
        }
    }

    // MARK: - Chunking

    private func createChunkFromBuffer(session: LectureSession?) async {
        guard !rollingBuffer.isEmpty else { return }

        let chunkText = rollingBuffer
        rollingBuffer = ""

        // Calculate timestamp
        let now = Date()
        let start = lastChunkTime?.timeIntervalSince(recordingStartTime ?? now) ?? 0
        let end = now.timeIntervalSince(recordingStartTime ?? now)

        let chunk = TranscriptChunk(
            text: chunkText,
            timestampRange: TimestampRange(start: start, end: end),
            chunkIndex: chunks.count
        )

        chunks.append(chunk)
        lastChunkTime = now

        // Generate embedding
        let embeddings = try? await embedding.embed([chunkText])
        if let embedding = embeddings?.first {
            chunk.embedding = embedding
        }

        await MainActor.run {
            self.delegate?.recorder(self, didProduce: chunk)
        }

        // Add to session if provided
        if let session = session {
            let noteChunk = NoteChunk(
                text: chunkText,
                chunkIndex: chunk.chunkIndex
            )
            noteChunk.setTimeRange(chunk.timestampRange)
            if let emb = chunk.embedding {
                noteChunk.setEmbedding(emb)
            }
            session.chunks.append(noteChunk)
        }
    }

    // MARK: - Rolling Summary

    private func generateRollingSummary() async {
        guard !chunks.isEmpty else { return }

        // Get last 3 chunks
        let recentChunks = chunks.suffix(3)
        let combinedText = recentChunks.map { $0.text }.joined(separator: "\n")

        let prompt = """
        Create concise bullet-point notes from this lecture segment.
        Focus on key concepts, definitions, and examples.

        TRANSCRIPT:
        \(combinedText.prefix(1500))

        NOTES (bullets):
        """

        if let summary = try? await llm.complete(prompt) {
            let timestamp = String(format: "[%02d:%02d]",
                                 Int(duration) / 60,
                                 Int(duration) % 60)

            liveNotes += "\n\(timestamp)\n\(summary)\n"
        }
    }
}

// MARK: - Transcript Chunk

final class TranscriptChunk {
    let text: String
    let timestampRange: TimestampRange
    let chunkIndex: Int
    var embedding: [Float]?

    init(text: String, timestampRange: TimestampRange, chunkIndex: Int) {
        self.text = text
        self.timestampRange = timestampRange
        self.chunkIndex = chunkIndex
    }
}

// MARK: - Errors

enum RecordingError: LocalizedError {
    case setupFailed
    case permissionDenied
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .setupFailed: return "Failed to setup audio recording"
        case .permissionDenied: return "Microphone or speech recognition permission denied"
        case .recognitionFailed: return "Speech recognition failed"
        }
    }
}

// MARK: - OnDeviceTranscriberDelegate

extension LectureRecorder: OnDeviceTranscriberDelegate {
    @MainActor
    func transcriber(_ transcriber: OnDeviceTranscriber, didReceive result: SFSpeechRecognitionResult, isFinal: Bool) {
        handleRecognitionResult(result, isFinal: isFinal)
    }

    @MainActor
    func transcriber(_ transcriber: OnDeviceTranscriber, didFail error: OnDeviceTranscriberError) {
        delegate?.recorder(self, didEncounter: error)
    }
}

// MARK: - OnDeviceTranscriber

protocol OnDeviceTranscriberDelegate: AnyObject {
    @MainActor
    func transcriber(_ transcriber: OnDeviceTranscriber, didReceive result: SFSpeechRecognitionResult, isFinal: Bool)

    @MainActor
    func transcriber(_ transcriber: OnDeviceTranscriber, didFail error: OnDeviceTranscriberError)
}

enum OnDeviceTranscriberError: LocalizedError {
    case unavailable
    case notAuthorized
    case unsupportedLocale
    case failed(Error)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Speech recognizer is unavailable."
        case .notAuthorized:
            return "Speech recognition is not authorized."
        case .unsupportedLocale:
            return "On-device recognition is not supported for this locale."
        case .failed(let error):
            return error.localizedDescription
        }
    }
}

final class OnDeviceTranscriber {
    weak var delegate: OnDeviceTranscriberDelegate?

    private let locale: Locale
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    init(locale: Locale = Locale(identifier: "en-US")) {
        self.locale = locale
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    func prepareAuthorization() async -> Bool {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        return status == .authorized
    }

    func startStreaming() throws {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw OnDeviceTranscriberError.notAuthorized
        }

        guard let speechRecognizer else {
            throw OnDeviceTranscriberError.unavailable
        }

        if #available(iOS 13.0, *), !speechRecognizer.supportsOnDeviceRecognition {
            throw OnDeviceTranscriberError.unsupportedLocale
        }

        cancelRecognition()

        let request = SFSpeechAudioBufferRecognitionRequest()
        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = true
        }
        request.shouldReportPartialResults = true

        recognitionRequest = request

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let error {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.delegate?.transcriber(self, didFail: .failed(error))
                }
                self.cancelRecognition()
                return
            }

            guard let result else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.delegate?.transcriber(self, didReceive: result, isFinal: result.isFinal)
            }

            if result.isFinal {
                self.cancelRecognition()
            }
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    func stop() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        cancelRecognition()
    }

    private func cancelRecognition() {
        recognitionRequest = nil
        recognitionTask = nil
    }
}
