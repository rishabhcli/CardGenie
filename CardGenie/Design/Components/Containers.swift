//
//  Containers.swift
//  CardGenie
//
//  Container views and loading states.
//

import SwiftUI

// MARK: - Loading View

/// Loading indicator with message
struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .controlSize(.large)

            Text(message)
                .font(.preview)
                .foregroundStyle(Color.secondaryText)
        }
        .padding()
        .glassPanel()
        .cornerRadius(CornerRadius.lg)
    }
}

// MARK: - Session Summary View

/// Session completion summary
struct SessionSummaryView: View {
    let totalCards: Int
    let againCount: Int
    let goodCount: Int
    let easyCount: Int

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Completion icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.success)

            // Title
            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)

            // Stats
            VStack(spacing: Spacing.sm) {
                HStack {
                    Text("Cards reviewed:")
                    Spacer()
                    Text("\(totalCards)")
                        .fontWeight(.semibold)
                }

                if againCount > 0 {
                    HStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)
                        Text("Again:")
                        Spacer()
                        Text("\(againCount)")
                    }
                }

                if goodCount > 0 {
                    HStack {
                        Circle()
                            .fill(.blue)
                            .frame(width: 12, height: 12)
                        Text("Good:")
                        Spacer()
                        Text("\(goodCount)")
                    }
                }

                if easyCount > 0 {
                    HStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 12, height: 12)
                        Text("Easy:")
                        Spacer()
                        Text("\(easyCount)")
                    }
                }
            }
            .padding()
            .glassPanel()
            .cornerRadius(CornerRadius.lg)
        }
        .padding()
    }
}

// MARK: - Previews

#Preview("Session Summary") {
    SessionSummaryView(
        totalCards: 10,
        againCount: 2,
        goodCount: 5,
        easyCount: 3
    )
}
