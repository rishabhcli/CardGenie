//
//  LectureHighlightLiveActivity.swift
//  CardGenieWidgets
//
//  Live Activity for lecture recording with Dynamic Island support
//  Displays real-time highlights, timestamps, and collaboration status
//

import ActivityKit
import WidgetKit
import SwiftUI

#if canImport(ActivityKit)
@available(iOS 26.0, *)
struct LectureHighlightLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LectureHighlightActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            LectureHighlightLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded region
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 14))

                        Text(context.attributes.topic)
                            .font(.headline)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.timestampLabel)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Text("LIVE")
                            .font(.caption2.bold())
                            .foregroundStyle(.red)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    if !context.state.highlightTitle.isEmpty {
                        VStack(spacing: 4) {
                            Text("Latest Highlight")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text(context.state.highlightTitle)
                                .font(.caption)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 4)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        // Highlight count
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)

                            Text("\(context.state.highlightCount)")
                                .font(.caption.bold())

                            Text("highlights")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Collaborators
                        if !context.state.participants.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)

                                Text("\(context.state.participants.count)")
                                    .font(.caption.bold())

                                Text("collaborating")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                // Compact leading (left side of notch)
                HStack(spacing: 4) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 12))

                    if context.state.highlightCount > 0 {
                        Text("\(context.state.highlightCount)")
                            .font(.caption2.bold())
                    }
                }
            } compactTrailing: {
                // Compact trailing (right side of notch)
                Text(context.state.timestampLabel)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            } minimal: {
                // Minimal (when multiple activities are running)
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 26.0, *)
struct LectureHighlightLockScreenView: View {
    let context: ActivityViewContext<LectureHighlightActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // Left: Recording indicator and topic
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)

                    Text("RECORDING")
                        .font(.caption2.bold())
                        .foregroundStyle(.red)
                }

                Text(context.attributes.topic)
                    .font(.headline)
                    .lineLimit(1)

                if !context.state.highlightTitle.isEmpty {
                    Text(context.state.highlightTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Right: Stats
            VStack(alignment: .trailing, spacing: 4) {
                Text(context.state.timestampLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)

                    Text("\(context.state.highlightCount)")
                        .font(.caption.bold())
                }

                if !context.state.participants.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)

                        Text("\(context.state.participants.count)")
                            .font(.caption2)
                    }
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Live Activity - Lock Screen", as: .content, using: LectureHighlightActivityAttributes.preview) {
    LectureHighlightLiveActivity()
} contentStates: {
    LectureHighlightActivityAttributes.ContentState(
        highlightTitle: "The mitochondria is the powerhouse of the cell",
        timestampLabel: "12:34",
        highlightCount: 5,
        participants: ["Alice", "Bob"]
    )

    LectureHighlightActivityAttributes.ContentState(
        highlightTitle: "Photosynthesis converts light energy into chemical energy",
        timestampLabel: "45:21",
        highlightCount: 12,
        participants: []
    )
}

// MARK: - Preview Helpers

@available(iOS 17.0, *)
extension LectureHighlightActivityAttributes {
    static var preview: LectureHighlightActivityAttributes {
        LectureHighlightActivityAttributes(
            sessionID: UUID(),
            topic: "Biology 101 - Cell Structure"
        )
    }
}
#endif
