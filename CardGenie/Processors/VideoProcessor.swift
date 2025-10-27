//
//  VideoProcessor.swift
//  CardGenie
//
//  Offline video transcription using AVFoundation + Speech.
//

import Foundation
import AVFoundation
import Speech
import OSLog

// AVAssetExportSession callbacks stay on the exporting queue; mark as @unchecked Sendable for continuations.
extension AVAssetExportSession: @unchecked Sendable {}

// MARK: - Progress Delegate

protocol VideoProcessorDelegate: AnyObject {
    func videoProcessor(_ processor: VideoProcessor, didUpdateProgress progress: VideoProcessingProgress)
    func videoProcessor(_ processor: VideoProcessor, didFailWithError error: Error)
}

// MARK: - Processing Progress

struct VideoProcessingProgress {
    enum Phase {
        case extractingAudio
        case transcribing
        case generatingChunks
        case creatingEmbeddings
        case summarizing
        case completed
    }

    let phase: Phase
    let percentComplete: Double // 0.0 - 1.0
    let message: String
}

// MARK: - Video Processor

final class VideoProcessor {
    private let llm: LLMEngine
    private let embedding: EmbeddingEngine
    private let log = Logger(subsystem: "com.cardgenie.app", category: "VideoProcessor")

    // SFSpeechRecognizer can be nil for a given locale; handle safely.
    private let speechRecognizer: SFSpeechRecognizer?
    // Retain the task to avoid it being deallocated prematurely and to support cancellation.
    private var recognitionTask: SFSpeechRecognitionTask?

    weak var delegate: VideoProcessorDelegate?
    private var isCancelled = false

    init(llm: LLMEngine = AIEngineFactory.createLLMEngine(),
         embedding: EmbeddingEngine = AIEngineFactory.createEmbeddingEngine(),
         locale: Locale = Locale(identifier: "en-US")) {
        self.llm = llm
        self.embedding = embedding
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)

        if speechRecognizer != nil {
            log.info("✅ Speech recognizer initialized for locale: \(locale.identifier)")
        } else {
            log.warning("⚠️ Speech recognizer not available for locale: \(locale.identifier)")
        }
    }

    // MARK: - Cancellation

    func cancel() {
        log.info("🛑 Cancelling video processing")
        isCancelled = true
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    private func reportProgress(_ phase: VideoProcessingProgress.Phase, percent: Double, message: String) {
        let progress = VideoProcessingProgress(phase: phase, percentComplete: percent, message: message)
        delegate?.videoProcessor(self, didUpdateProgress: progress)
        log.info("📊 Progress: \(message) (\(Int(percent * 100))%)")
    }

    // MARK: - Main Processing

    /// Process video and extract audio → transcript → chunks
    func process(videoURL: URL) async throws -> SourceDocument {
        log.info("🎬 Starting video processing: \(videoURL.lastPathComponent)")
        isCancelled = false

        do {
            // Ensure speech authorization before starting any work that depends on it.
            try await ensureSpeechAuthorization()
            reportProgress(.extractingAudio, percent: 0.0, message: "Preparing video...")

            let fileName = videoURL.lastPathComponent
            let fileSize = try getFileSize(videoURL)

            let sourceDoc = SourceDocument(
                kind: .video,
                fileName: fileName,
                fileURL: videoURL,
                fileSize: fileSize
            )

            // Get video duration
            let asset = AVURLAsset(url: videoURL)
            let duration = try await asset.load(.duration).seconds
            sourceDoc.duration = duration
            log.info("📹 Video duration: \(Int(duration))s")

            // Extract audio track
            reportProgress(.extractingAudio, percent: 0.1, message: "Extracting audio...")
            let audioURL = try await extractAudio(from: videoURL)
            // Clean up the temporary audio file after we're done with it.
            defer { try? FileManager.default.removeItem(at: audioURL) }

            if isCancelled { throw CancellationError() }
            log.info("🔊 Audio extracted successfully")

            // Transcribe audio offline
            reportProgress(.transcribing, percent: 0.3, message: "Transcribing audio (on-device)...")
            let transcript = try await transcribe(audioURL: audioURL, duration: duration)
            log.info("📝 Transcription complete: \(transcript.count) segments")

            if isCancelled { throw CancellationError() }

            // Chunk by timestamps
            reportProgress(.generatingChunks, percent: 0.6, message: "Organizing transcript...")
            let chunks = chunkTranscript(transcript)
            log.info("📦 Created \(chunks.count) chunks")

            // Generate embeddings
            reportProgress(.creatingEmbeddings, percent: 0.7, message: "Creating embeddings (on-device)...")
            let chunkTexts = chunks.map { $0.text }
            let embeddings = try await embedding.embed(chunkTexts)
            log.info("🧠 Generated \(embeddings.count) embeddings")

            if isCancelled { throw CancellationError() }

            // Create NoteChunks
            reportProgress(.summarizing, percent: 0.8, message: "Summarizing content...")
            for (index, chunk) in chunks.enumerated() {
                if isCancelled { throw CancellationError() }

                let noteChunk = NoteChunk(
                    text: chunk.text,
                    chunkIndex: index
                )
                noteChunk.setTimeRange(chunk.timeRange)

                if index < embeddings.count {
                    noteChunk.setEmbedding(embeddings[index])
                }

                // Summarize chunk
                noteChunk.summary = try? await summarizeChunk(chunk.text)

                sourceDoc.chunks.append(noteChunk)

                // Update progress for each chunk
                let chunkProgress = 0.8 + (0.15 * Double(index + 1) / Double(chunks.count))
                reportProgress(.summarizing, percent: chunkProgress, message: "Summarizing chunk \(index + 1)/\(chunks.count)...")
            }

            if isCancelled { throw CancellationError() }

            sourceDoc.processedAt = Date()
            reportProgress(.completed, percent: 1.0, message: "Processing complete!")
            log.info("✅ Video processing complete!")

            return sourceDoc

        } catch {
            log.error("❌ Video processing failed: \(error.localizedDescription)")
            delegate?.videoProcessor(self, didFailWithError: error)
            throw error
        }
    }

    // MARK: - Audio Extraction

    private func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)

        // Ensure there is at least one audio track to export.
        guard let _ = try await asset.loadTracks(withMediaType: .audio).first else {
            throw VideoProcessingError.noAudioTrack
        }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw VideoProcessingError.exportFailed
        }

        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("\(UUID().uuidString).m4a")

        if #available(iOS 18.0, *) {
            try await exportSession.export(to: audioURL, as: .m4a)
            return audioURL
        } else {
            exportSession.outputURL = audioURL
            exportSession.outputFileType = .m4a

            // Use the legacy async export API bridged via continuation.
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                // Capture export session for legacy API (pre-iOS 18)
                nonisolated(unsafe) let session = exportSession
                session.exportAsynchronously {
                    switch session.status {
                    case .completed:
                        continuation.resume()
                    case .failed, .cancelled:
                        continuation.resume(throwing: VideoProcessingError.exportFailed)
                    default:
                        // Should not happen, but treat as failure
                        continuation.resume(throwing: VideoProcessingError.exportFailed)
                    }
                }
            }

            return audioURL
        }
    }

    // MARK: - Transcription

    private func transcribe(audioURL: URL, duration: Double) async throws -> [TimestampedSegment] {
        if Task.isCancelled { throw CancellationError() }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw VideoProcessingError.speechRecognizerUnavailable
        }

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = true // OFFLINE ONLY

            var segments: [TimestampedSegment] = []

            self?.recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                if let error = error {
                    self?.recognitionTask = nil
                    continuation.resume(throwing: error)
                    return
                }

                guard let result = result else { return }

                // Extract segments with timestamps
                let transcription = result.bestTranscription

                if result.isFinal {
                    // Group by time intervals (30-second chunks)
                    var currentChunk = ""
                    var chunkStart: TimeInterval = 0
                    var currentTime: TimeInterval = 0

                    for segment in transcription.segments {
                        let segmentTime = segment.timestamp

                        // If we've passed 30 seconds, create new chunk
                        if segmentTime - chunkStart >= 30 {
                            if !currentChunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                segments.append(TimestampedSegment(
                                    text: currentChunk.trimmingCharacters(in: .whitespacesAndNewlines),
                                    timeRange: TimestampRange(start: chunkStart, end: min(currentTime, duration))
                                ))
                            }
                            currentChunk = segment.substring
                            chunkStart = segmentTime
                        } else {
                            if currentChunk.isEmpty {
                                currentChunk = segment.substring
                            } else {
                                currentChunk += " " + segment.substring
                            }
                        }

                        currentTime = segmentTime + segment.duration
                    }

                    // Add final chunk
                    if !currentChunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        segments.append(TimestampedSegment(
                            text: currentChunk.trimmingCharacters(in: .whitespacesAndNewlines),
                            timeRange: TimestampRange(start: chunkStart, end: min(currentTime, duration))
                        ))
                    }

                    self?.recognitionTask = nil

                    if segments.isEmpty {
                        continuation.resume(throwing: VideoProcessingError.transcriptionFailed)
                    } else {
                        continuation.resume(returning: segments)
                    }
                }
            }
        }
    }

    // MARK: - Chunking

    private func chunkTranscript(_ segments: [TimestampedSegment]) -> [TranscriptChunkData] {
        // Already chunked by time, just convert
        return segments.enumerated().map { index, segment in
            TranscriptChunkData(
                text: segment.text,
                timeRange: segment.timeRange,
                chunkIndex: index
            )
        }
    }

    // MARK: - Summarization

    private func summarizeChunk(_ text: String) async throws -> String {
        let prompt = """
        Summarize this video transcript segment in 2-3 bullet points.

        TRANSCRIPT:
        \(text.prefix(1000))

        SUMMARY (bullets):
        """

        let summary = try await llm.complete(prompt, maxTokens: 200)
        return summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private func getFileSize(_ url: URL) throws -> Int64 {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return attrs[.size] as? Int64 ?? 0
    }

    private func ensureSpeechAuthorization() async throws {
        // Fast-path if already authorized
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return
        case .denied, .restricted:
            throw VideoProcessingError.speechRecognizerUnavailable
        case .notDetermined:
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { newStatus in
                    continuation.resume(returning: newStatus)
                }
            }
            guard status == .authorized else { throw VideoProcessingError.speechRecognizerUnavailable }
        @unknown default:
            throw VideoProcessingError.speechRecognizerUnavailable
        }
    }
}

// MARK: - Supporting Types

private struct TimestampedSegment {
    let text: String
    let timeRange: TimestampRange
}

private struct TranscriptChunkData {
    let text: String
    let timeRange: TimestampRange
    let chunkIndex: Int
}

// MARK: - Errors

enum VideoProcessingError: LocalizedError {
    case noAudioTrack
    case exportFailed
    case speechRecognizerUnavailable
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .noAudioTrack: return "Video has no audio track"
        case .exportFailed: return "Failed to export audio"
        case .speechRecognizerUnavailable: return "Speech recognition not available"
        case .transcriptionFailed: return "Transcription failed"
        }
    }
}
