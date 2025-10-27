//
//  LiveLectureContext.swift
//  CardGenie
//
//  Coordinates live lecture recording, highlights, Live Activities, and SharePlay.
//

import Foundation
import Observation
import SwiftData

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

    init(
        recorder: LectureRecorder = LectureRecorder(),
        highlightExtractor: HighlightExtractor = HighlightExtractor(),
        activityManager: LiveHighlightActivityManager = LiveHighlightActivityManager(),
        collaboration: LectureCollaborationController = LectureCollaborationController()
    ) {
        self.recorder = recorder
        self.highlightExtractor = highlightExtractor
        self.activityManager = activityManager
        self.collaboration = collaboration
        recorder.delegate = self

        notificationToken = NotificationCenter.default.addObserver(
            forName: .collaborativeHighlightReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let highlight = notification.object as? CollaborativeHighlight
            else { return }
            self?.handleCollaborativeHighlight(highlight)
        }
    }

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
