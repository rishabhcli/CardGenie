//
//  LectureCollaborationController.swift
//  CardGenie
//
//  SharePlay helper for collaborative highlight marking.
//

import Foundation
#if canImport(GroupActivities)
import GroupActivities
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
            state = GroupActivitiesAvailability.shared.isEligible ? .idle : .unavailable
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
        guard GroupActivitiesAvailability.shared.isEligible else {
            state = .unavailable
            return
        }

        do {
            let activity = LectureCollaborationActivity(title: title)
            state = .waiting

            switch await activity.prepareForActivation() {
            case .activationPreferred:
                try await activity.activate()
            case .activationDisabled:
                state = .unavailable
                return
            case .activationRejected:
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
        for await session in activity.sessions() {
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
                name: participant.displayName
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
                CollaborationParticipant(id: participant.id, name: participant.displayName)
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
        metadata.type = .studyTogether
        return metadata
    }
}
#endif

extension Notification.Name {
    static let collaborativeHighlightReceived = Notification.Name("LectureCollaborationHighlightReceived")
}
