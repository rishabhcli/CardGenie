//
//  LiveHighlightActivityManager.swift
//  CardGenie
//
//  Manages the Live Activity timeline for lecture highlights.
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit
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
