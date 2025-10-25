//
//  VideoProcessor.swift
//  CardGenie
//
//  Offline video transcription using AVFoundation + Speech.
//

import Foundation
import AVFoundation
import Speech

// MARK: - Video Processor

final class VideoProcessor {
    private let llm: LLMEngine
    private let embedding: EmbeddingEngine
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!

    init(llm: LLMEngine = AIEngineFactory.createLLMEngine(),
         embedding: EmbeddingEngine = AIEngineFactory.createEmbeddingEngine()) {
        self.llm = llm
        self.embedding = embedding
    }

    // MARK: - Main Processing

    /// Process video and extract audio → transcript → chunks
    func process(videoURL: URL) async throws -> SourceDocument {
        let fileName = videoURL.lastPathComponent
        let fileSize = try getFileSize(videoURL)

        let sourceDoc = SourceDocument(
            kind: .video,
            fileName: fileName,
            fileURL: videoURL,
            fileSize: fileSize
        )

        // Get video duration
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds
        sourceDoc.duration = duration

        // Extract audio track
        let audioURL = try await extractAudio(from: videoURL)

        // Transcribe audio offline
        let transcript = try await transcribe(audioURL: audioURL, duration: duration)

        // Chunk by timestamps
        let chunks = chunkTranscript(transcript)

        // Generate embeddings
        let chunkTexts = chunks.map { $0.text }
        let embeddings = try await embedding.embed(chunkTexts)

        // Create NoteChunks
        for (index, chunk) in chunks.enumerated() {
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
        }

        sourceDoc.processedAt = Date()
        return sourceDoc
    }

    // MARK: - Audio Extraction

    private func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVAsset(url: videoURL)

        // Get audio track
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw VideoProcessingError.noAudioTrack
        }

        // Setup export
        let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        )

        guard let exportSession = exportSession else {
            throw VideoProcessingError.exportFailed
        }

        // Output URL
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("\(UUID().uuidString).m4a")

        exportSession.outputURL = audioURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        if exportSession.status == .completed {
            return audioURL
        } else {
            throw VideoProcessingError.exportFailed
        }
    }

    // MARK: - Transcription

    private func transcribe(audioURL: URL, duration: Double) async throws -> [TimestampedSegment] {
        guard speechRecognizer.isAvailable else {
            throw VideoProcessingError.speechRecognizerUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = true // OFFLINE ONLY

            var segments: [TimestampedSegment] = []

            speechRecognizer.recognitionTask(with: request) { result, error in
                if let error = error {
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
                            if !currentChunk.isEmpty {
                                segments.append(TimestampedSegment(
                                    text: currentChunk,
                                    timeRange: TimestampRange(start: chunkStart, end: currentTime)
                                ))
                            }
                            currentChunk = segment.substring
                            chunkStart = segmentTime
                        } else {
                            currentChunk += " " + segment.substring
                        }

                        currentTime = segmentTime + segment.duration
                    }

                    // Add final chunk
                    if !currentChunk.isEmpty {
                        segments.append(TimestampedSegment(
                            text: currentChunk,
                            timeRange: TimestampRange(start: chunkStart, end: currentTime)
                        ))
                    }

                    continuation.resume(returning: segments)
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
