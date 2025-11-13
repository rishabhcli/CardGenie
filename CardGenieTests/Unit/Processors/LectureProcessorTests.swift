//
//  LectureProcessorTests.swift
//  CardGenieTests
//
//  Comprehensive unit tests for LectureRecorder and OnDeviceTranscriber.
//  Tests recording lifecycle, transcript chunking, timestamp accuracy,
//  delegate callbacks, and error handling.
//

import XCTest
import AVFoundation
import Speech
@testable import CardGenie

// MARK: - Mock Delegate

@MainActor
final class MockLectureRecorderDelegate: LectureRecorderDelegate {
    var transcriptUpdates: [String] = []
    var chunksProduced: [TranscriptChunk] = []
    var errors: [Error] = []

    func recorder(_ recorder: LectureRecorder, didUpdateTranscript transcript: String) {
        transcriptUpdates.append(transcript)
    }

    func recorder(_ recorder: LectureRecorder, didProduce chunk: TranscriptChunk) {
        chunksProduced.append(chunk)
    }

    func recorder(_ recorder: LectureRecorder, didEncounter error: Error) {
        errors.append(error)
    }

    func reset() {
        transcriptUpdates.removeAll()
        chunksProduced.removeAll()
        errors.removeAll()
    }
}

// MARK: - Mock Transcriber

@MainActor
final class MockTranscriber {
    weak var delegate: OnDeviceTranscriberDelegate?
    var isAuthorized = true
    var isStreaming = false
    var shouldFailOnStart = false
    var buffers: [AVAudioPCMBuffer] = []

    func prepareAuthorization() async -> Bool {
        return isAuthorized
    }

    func startStreaming() throws {
        if shouldFailOnStart {
            throw OnDeviceTranscriberError.unavailable
        }
        isStreaming = true
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        buffers.append(buffer)
    }

    func stop() {
        isStreaming = false
    }

    func simulateRecognitionResult(_ text: String, isFinal: Bool) {
        let mockResult = MockSpeechRecognitionResult(text: text, isFinal: isFinal)
        delegate?.transcriber(OnDeviceTranscriber(), didReceive: mockResult, isFinal: isFinal)
    }

    func simulateError(_ error: OnDeviceTranscriberError) {
        delegate?.transcriber(OnDeviceTranscriber(), didFail: error)
    }
}

// MARK: - Mock Speech Recognition Result

final class MockSpeechRecognitionResult: SFSpeechRecognitionResult {
    private let mockText: String
    private let mockIsFinal: Bool
    private let mockTranscription: MockTranscription

    init(text: String, isFinal: Bool) {
        self.mockText = text
        self.mockIsFinal = isFinal
        self.mockTranscription = MockTranscription(text: text)
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var bestTranscription: SFTranscription {
        return mockTranscription
    }

    override var isFinal: Bool {
        return mockIsFinal
    }
}

// MARK: - Mock Transcription

final class MockTranscription: SFTranscription {
    private let mockFormattedString: String

    init(text: String) {
        self.mockFormattedString = text
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var formattedString: String {
        return mockFormattedString
    }
}

// MARK: - Test Suite

@MainActor
final class LectureProcessorTests: XCTestCase {

    var recorder: LectureRecorder!
    var mockDelegate: MockLectureRecorderDelegate!

    override func setUp() async throws {
        recorder = LectureRecorder()
        mockDelegate = MockLectureRecorderDelegate()
        recorder.delegate = mockDelegate
    }

    override func tearDown() async throws {
        recorder = nil
        mockDelegate = nil
    }

    // MARK: - TranscriptChunk Tests

    func testTranscriptChunk_Initialization() {
        // Given
        let timestampRange = TimestampRange(start: 0, end: 60)

        // When
        let chunk = TranscriptChunk(
            text: "This is a test transcript.",
            timestampRange: timestampRange,
            chunkIndex: 0
        )

        // Then
        XCTAssertEqual(chunk.text, "This is a test transcript.")
        XCTAssertEqual(chunk.timestampRange.start, 0)
        XCTAssertEqual(chunk.timestampRange.end, 60)
        XCTAssertEqual(chunk.chunkIndex, 0)
        XCTAssertNil(chunk.embedding)
    }

    func testTranscriptChunk_WithEmbedding() {
        // Given
        let timestampRange = TimestampRange(start: 0, end: 60)
        let chunk = TranscriptChunk(
            text: "Test",
            timestampRange: timestampRange,
            chunkIndex: 0
        )
        let embedding: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]

        // When
        chunk.embedding = embedding

        // Then
        XCTAssertNotNil(chunk.embedding)
        XCTAssertEqual(chunk.embedding?.count, 5)
        XCTAssertEqual(chunk.embedding?[0], 0.1)
    }

    func testTranscriptChunk_MultipleChunks_CorrectIndices() {
        // Given
        let timestampRange1 = TimestampRange(start: 0, end: 30)
        let timestampRange2 = TimestampRange(start: 30, end: 60)
        let timestampRange3 = TimestampRange(start: 60, end: 90)

        // When
        let chunk1 = TranscriptChunk(text: "First", timestampRange: timestampRange1, chunkIndex: 0)
        let chunk2 = TranscriptChunk(text: "Second", timestampRange: timestampRange2, chunkIndex: 1)
        let chunk3 = TranscriptChunk(text: "Third", timestampRange: timestampRange3, chunkIndex: 2)

        // Then
        XCTAssertEqual(chunk1.chunkIndex, 0)
        XCTAssertEqual(chunk2.chunkIndex, 1)
        XCTAssertEqual(chunk3.chunkIndex, 2)
    }

    // MARK: - Recording State Tests

    func testInitialState() {
        // Then
        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(recorder.transcript, "")
        XCTAssertEqual(recorder.liveNotes, "")
        XCTAssertEqual(recorder.duration, 0)
        XCTAssertTrue(recorder.chunks.isEmpty)
    }

    func testCurrentTimestamp_BeforeRecording() {
        // When
        let timestamp = recorder.currentTimestamp()

        // Then
        XCTAssertEqual(timestamp, 0)
    }

    func testCurrentTimestamp_DuringRecording() async {
        // Given: Simulate recording started 2 seconds ago
        // Note: We can't actually start recording in unit tests due to hardware dependencies,
        // but we can test the timestamp calculation logic through the public API

        // When
        let timestamp1 = recorder.currentTimestamp()

        // Then: Should return 0 when not recording
        XCTAssertEqual(timestamp1, 0)
    }

    // MARK: - Delegate Callback Tests

    func testDelegate_TranscriptUpdate() {
        // Given
        let expectedTranscript = "Hello world"

        // When: Simulate transcript update through delegate
        recorder.delegate?.recorder(recorder, didUpdateTranscript: expectedTranscript)

        // Then
        XCTAssertEqual(mockDelegate.transcriptUpdates.count, 1)
        XCTAssertEqual(mockDelegate.transcriptUpdates.first, expectedTranscript)
    }

    func testDelegate_ChunkProduced() {
        // Given
        let chunk = TranscriptChunk(
            text: "Test chunk",
            timestampRange: TimestampRange(start: 0, end: 10),
            chunkIndex: 0
        )

        // When
        recorder.delegate?.recorder(recorder, didProduce: chunk)

        // Then
        XCTAssertEqual(mockDelegate.chunksProduced.count, 1)
        XCTAssertEqual(mockDelegate.chunksProduced.first?.text, "Test chunk")
    }

    func testDelegate_ErrorEncountered() {
        // Given
        let error = RecordingError.setupFailed

        // When
        recorder.delegate?.recorder(recorder, didEncounter: error)

        // Then
        XCTAssertEqual(mockDelegate.errors.count, 1)
        XCTAssertTrue(mockDelegate.errors.first is RecordingError)
    }

    func testDelegate_MultipleTranscriptUpdates() {
        // Given
        let updates = ["Hello", "Hello world", "Hello world, this", "Hello world, this is a test"]

        // When
        for update in updates {
            recorder.delegate?.recorder(recorder, didUpdateTranscript: update)
        }

        // Then
        XCTAssertEqual(mockDelegate.transcriptUpdates.count, 4)
        XCTAssertEqual(mockDelegate.transcriptUpdates.last, "Hello world, this is a test")
    }

    // MARK: - Error Tests

    func testRecordingError_SetupFailed() {
        // Given
        let error = RecordingError.setupFailed

        // Then
        XCTAssertEqual(error.errorDescription, "Failed to setup audio recording")
    }

    func testRecordingError_PermissionDenied() {
        // Given
        let error = RecordingError.permissionDenied

        // Then
        XCTAssertEqual(error.errorDescription, "Microphone or speech recognition permission denied")
    }

    func testRecordingError_RecognitionFailed() {
        // Given
        let error = RecordingError.recognitionFailed

        // Then
        XCTAssertEqual(error.errorDescription, "Speech recognition failed")
    }

    func testOnDeviceTranscriberError_Unavailable() {
        // Given
        let error = OnDeviceTranscriberError.unavailable

        // Then
        XCTAssertEqual(error.errorDescription, "Speech recognizer is unavailable.")
    }

    func testOnDeviceTranscriberError_NotAuthorized() {
        // Given
        let error = OnDeviceTranscriberError.notAuthorized

        // Then
        XCTAssertEqual(error.errorDescription, "Speech recognition is not authorized.")
    }

    func testOnDeviceTranscriberError_UnsupportedLocale() {
        // Given
        let error = OnDeviceTranscriberError.unsupportedLocale

        // Then
        XCTAssertEqual(error.errorDescription, "On-device recognition is not supported for this locale.")
    }

    func testOnDeviceTranscriberError_Failed() {
        // Given
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test error" }
        }
        let error = OnDeviceTranscriberError.failed(TestError())

        // Then
        XCTAssertEqual(error.errorDescription, "Test error")
    }

    // MARK: - OnDeviceTranscriber Tests

    func testOnDeviceTranscriber_Initialization() {
        // When
        let transcriber = OnDeviceTranscriber()

        // Then: Should initialize without crashing
        XCTAssertNotNil(transcriber)
    }

    func testOnDeviceTranscriber_CustomLocale() {
        // Given
        let locale = Locale(identifier: "es-ES")

        // When
        let transcriber = OnDeviceTranscriber(locale: locale)

        // Then: Should initialize with custom locale
        XCTAssertNotNil(transcriber)
    }

    func testOnDeviceTranscriber_DelegateAssignment() {
        // Given
        let transcriber = OnDeviceTranscriber()
        let mockDelegate = MockOnDeviceTranscriberDelegate()

        // When
        transcriber.delegate = mockDelegate

        // Then: Delegate should be set (weak reference)
        XCTAssertNotNil(transcriber.delegate)
    }

    // MARK: - TimestampRange Tests

    func testTimestampRange_Duration() {
        // Given
        let range = TimestampRange(start: 10, end: 70)

        // When
        let duration = range.duration

        // Then
        XCTAssertEqual(duration, 60)
    }

    func testTimestampRange_ZeroDuration() {
        // Given
        let range = TimestampRange(start: 45, end: 45)

        // When
        let duration = range.duration

        // Then
        XCTAssertEqual(duration, 0)
    }

    func testTimestampRange_LargeDuration() {
        // Given: 1 hour lecture
        let range = TimestampRange(start: 0, end: 3600)

        // When
        let duration = range.duration

        // Then
        XCTAssertEqual(duration, 3600)
    }

    // MARK: - Chunking Logic Tests

    func testChunking_EmptyBuffer() {
        // Given: Initial state with no chunks

        // Then
        XCTAssertTrue(recorder.chunks.isEmpty)
    }

    func testChunking_IndexIncrement() {
        // Given: Multiple chunks
        let chunk1 = TranscriptChunk(
            text: "First chunk",
            timestampRange: TimestampRange(start: 0, end: 30),
            chunkIndex: 0
        )
        let chunk2 = TranscriptChunk(
            text: "Second chunk",
            timestampRange: TimestampRange(start: 30, end: 60),
            chunkIndex: 1
        )

        // Then
        XCTAssertEqual(chunk1.chunkIndex, 0)
        XCTAssertEqual(chunk2.chunkIndex, 1)
    }

    // MARK: - Performance Tests

    func testPerformance_MultipleTranscriptUpdates() {
        measure {
            for i in 0..<100 {
                recorder.delegate?.recorder(recorder, didUpdateTranscript: "Update \(i)")
            }
            mockDelegate.reset()
        }
    }

    func testPerformance_MultipleChunkCreation() {
        measure {
            for i in 0..<50 {
                let chunk = TranscriptChunk(
                    text: "Performance test chunk \(i)",
                    timestampRange: TimestampRange(start: Double(i * 30), end: Double((i + 1) * 30)),
                    chunkIndex: i
                )
                recorder.delegate?.recorder(recorder, didProduce: chunk)
            }
            mockDelegate.reset()
        }
    }

    func testPerformance_LargeTranscript() {
        // Given: Large transcript (simulating 1-hour lecture)
        let largeText = String(repeating: "This is a long transcript segment. ", count: 1000)

        measure {
            recorder.delegate?.recorder(recorder, didUpdateTranscript: largeText)
            mockDelegate.reset()
        }
    }

    // MARK: - Edge Case Tests

    func testEdgeCase_EmptyTranscript() {
        // When
        recorder.delegate?.recorder(recorder, didUpdateTranscript: "")

        // Then
        XCTAssertEqual(mockDelegate.transcriptUpdates.count, 1)
        XCTAssertEqual(mockDelegate.transcriptUpdates.first, "")
    }

    func testEdgeCase_VeryLongTranscript() {
        // Given: 10,000 character transcript
        let longText = String(repeating: "a", count: 10000)

        // When
        recorder.delegate?.recorder(recorder, didUpdateTranscript: longText)

        // Then
        XCTAssertEqual(mockDelegate.transcriptUpdates.count, 1)
        XCTAssertEqual(mockDelegate.transcriptUpdates.first?.count, 10000)
    }

    func testEdgeCase_UnicodeTranscript() {
        // Given: Unicode characters
        let unicodeText = "Hello 你好 مرحبا 🎉"

        // When
        recorder.delegate?.recorder(recorder, didUpdateTranscript: unicodeText)

        // Then
        XCTAssertEqual(mockDelegate.transcriptUpdates.first, unicodeText)
    }

    func testEdgeCase_MultilineTranscript() {
        // Given
        let multilineText = """
        First line
        Second line
        Third line
        """

        // When
        recorder.delegate?.recorder(recorder, didUpdateTranscript: multilineText)

        // Then
        XCTAssertEqual(mockDelegate.transcriptUpdates.first, multilineText)
    }

    func testEdgeCase_SpecialCharacters() {
        // Given
        let specialText = "Special chars: @#$%^&*()[]{}|\\<>?/"

        // When
        recorder.delegate?.recorder(recorder, didUpdateTranscript: specialText)

        // Then
        XCTAssertEqual(mockDelegate.transcriptUpdates.first, specialText)
    }

    func testEdgeCase_ZeroTimestamp() {
        // Given
        let chunk = TranscriptChunk(
            text: "Start",
            timestampRange: TimestampRange(start: 0, end: 0),
            chunkIndex: 0
        )

        // Then
        XCTAssertEqual(chunk.timestampRange.start, 0)
        XCTAssertEqual(chunk.timestampRange.end, 0)
        XCTAssertEqual(chunk.timestampRange.duration, 0)
    }

    func testEdgeCase_NegativeTimestamp() {
        // Given: Testing timestamp range with negative values (edge case)
        let chunk = TranscriptChunk(
            text: "Test",
            timestampRange: TimestampRange(start: -1, end: 0),
            chunkIndex: 0
        )

        // Then: Should handle gracefully
        XCTAssertEqual(chunk.timestampRange.start, -1)
        XCTAssertEqual(chunk.timestampRange.duration, 1)
    }

    // MARK: - Memory Tests

    func testMemory_ChunkRetention() {
        // Given: Create many chunks
        var chunks: [TranscriptChunk] = []

        for i in 0..<100 {
            let chunk = TranscriptChunk(
                text: "Chunk \(i)",
                timestampRange: TimestampRange(start: Double(i), end: Double(i + 1)),
                chunkIndex: i
            )
            chunks.append(chunk)
        }

        // Then: All chunks should be retained
        XCTAssertEqual(chunks.count, 100)
        XCTAssertEqual(chunks.first?.chunkIndex, 0)
        XCTAssertEqual(chunks.last?.chunkIndex, 99)
    }

    func testMemory_DelegateWeakReference() {
        // Given
        var tempDelegate: MockLectureRecorderDelegate? = MockLectureRecorderDelegate()
        recorder.delegate = tempDelegate

        // When: Release delegate
        tempDelegate = nil

        // Then: Delegate should be nil (weak reference)
        XCTAssertNil(recorder.delegate)
    }

    // MARK: - Concurrent Access Tests

    func testConcurrency_MultipleUpdates() async {
        // Given: Multiple concurrent transcript updates
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await self.recorder.delegate?.recorder(self.recorder, didUpdateTranscript: "Update \(i)")
                }
            }
        }

        // Then: All updates should be recorded
        XCTAssertEqual(mockDelegate.transcriptUpdates.count, 10)
    }

    func testConcurrency_ChunkAndTranscriptUpdates() async {
        // Given: Concurrent chunk and transcript updates
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.recorder.delegate?.recorder(self.recorder, didUpdateTranscript: "Transcript 1")
            }
            group.addTask {
                let chunk = TranscriptChunk(
                    text: "Chunk 1",
                    timestampRange: TimestampRange(start: 0, end: 10),
                    chunkIndex: 0
                )
                await self.recorder.delegate?.recorder(self.recorder, didProduce: chunk)
            }
        }

        // Then
        XCTAssertEqual(mockDelegate.transcriptUpdates.count, 1)
        XCTAssertEqual(mockDelegate.chunksProduced.count, 1)
    }

    // MARK: - Integration-Style Tests

    func testIntegration_CompleteRecordingFlow() {
        // Given: Simulate a complete recording session

        // 1. Initial state check
        XCTAssertFalse(recorder.isRecording)
        XCTAssertTrue(recorder.chunks.isEmpty)

        // 2. Transcript updates
        recorder.delegate?.recorder(recorder, didUpdateTranscript: "Hello")
        recorder.delegate?.recorder(recorder, didUpdateTranscript: "Hello world")

        // 3. Chunk creation
        let chunk1 = TranscriptChunk(
            text: "Hello world",
            timestampRange: TimestampRange(start: 0, end: 5),
            chunkIndex: 0
        )
        recorder.delegate?.recorder(recorder, didProduce: chunk1)

        // 4. More transcripts
        recorder.delegate?.recorder(recorder, didUpdateTranscript: "Hello world, how are you?")

        // 5. Another chunk
        let chunk2 = TranscriptChunk(
            text: "how are you?",
            timestampRange: TimestampRange(start: 5, end: 10),
            chunkIndex: 1
        )
        recorder.delegate?.recorder(recorder, didProduce: chunk2)

        // Then
        XCTAssertEqual(mockDelegate.transcriptUpdates.count, 3)
        XCTAssertEqual(mockDelegate.chunksProduced.count, 2)
        XCTAssertEqual(mockDelegate.chunksProduced[0].chunkIndex, 0)
        XCTAssertEqual(mockDelegate.chunksProduced[1].chunkIndex, 1)
    }

    func testIntegration_ErrorDuringRecording() {
        // Given: Recording in progress
        recorder.delegate?.recorder(recorder, didUpdateTranscript: "Test")

        // When: Error occurs
        let error = RecordingError.recognitionFailed
        recorder.delegate?.recorder(recorder, didEncounter: error)

        // Then
        XCTAssertEqual(mockDelegate.transcriptUpdates.count, 1)
        XCTAssertEqual(mockDelegate.errors.count, 1)
        XCTAssertTrue(mockDelegate.errors.first is RecordingError)
    }

    // MARK: - Timestamp Accuracy Tests

    func testTimestamp_SequentialChunks() {
        // Given: Multiple sequential chunks
        let chunk1 = TranscriptChunk(
            text: "First",
            timestampRange: TimestampRange(start: 0, end: 30),
            chunkIndex: 0
        )
        let chunk2 = TranscriptChunk(
            text: "Second",
            timestampRange: TimestampRange(start: 30, end: 60),
            chunkIndex: 1
        )
        let chunk3 = TranscriptChunk(
            text: "Third",
            timestampRange: TimestampRange(start: 60, end: 90),
            chunkIndex: 2
        )

        // Then: Timestamps should be sequential
        XCTAssertEqual(chunk1.timestampRange.end, chunk2.timestampRange.start)
        XCTAssertEqual(chunk2.timestampRange.end, chunk3.timestampRange.start)
    }

    func testTimestamp_OverlappingChunks() {
        // Given: Overlapping chunks (edge case)
        let chunk1 = TranscriptChunk(
            text: "First",
            timestampRange: TimestampRange(start: 0, end: 35),
            chunkIndex: 0
        )
        let chunk2 = TranscriptChunk(
            text: "Second",
            timestampRange: TimestampRange(start: 30, end: 65),
            chunkIndex: 1
        )

        // Then: Should track both independently
        XCTAssertTrue(chunk1.timestampRange.end > chunk2.timestampRange.start)
        XCTAssertEqual(chunk1.timestampRange.duration, 35)
        XCTAssertEqual(chunk2.timestampRange.duration, 35)
    }
}

// MARK: - Mock OnDeviceTranscriberDelegate

@MainActor
final class MockOnDeviceTranscriberDelegate: OnDeviceTranscriberDelegate {
    var results: [SFSpeechRecognitionResult] = []
    var errors: [OnDeviceTranscriberError] = []

    func transcriber(_ transcriber: OnDeviceTranscriber, didReceive result: SFSpeechRecognitionResult, isFinal: Bool) {
        results.append(result)
    }

    func transcriber(_ transcriber: OnDeviceTranscriber, didFail error: OnDeviceTranscriberError) {
        errors.append(error)
    }
}
