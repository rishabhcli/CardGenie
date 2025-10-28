//
//  AIAvailabilityViews.swift
//  CardGenie
//
//  Availability-gated views for Apple Intelligence features.
//  Provides appropriate fallbacks for each unavailability state.
//

import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Availability Gate Wrapper

/// Wraps AI-powered features with availability checking
struct AIFeatureGate<Content: View>: View {
    let feature: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            AIAvailabilityWrapper(feature: feature, content: content)
        } else {
            DeviceNotSupportedView()
        }
        #else
        DeviceNotSupportedView()
        #endif
    }
}

// MARK: - iOS 26+ Availability Wrapper

@available(iOS 26.0, *)
private struct AIAvailabilityWrapper<Content: View>: View {
    let feature: String
    @ViewBuilder let content: () -> Content

    private let model = SystemLanguageModel.default

    var body: some View {
        switch model.availability {
        case .available:
            content()

        case .unavailable(.deviceNotEligible):
            DeviceNotSupportedView()

        case .unavailable(.appleIntelligenceNotEnabled):
            EnableAppleIntelligenceView()

        case .unavailable(.modelNotReady):
            ModelDownloadingView()

        default:
            GenericUnavailableView()
        }
    }
}

// MARK: - Device Not Supported View

struct DeviceNotSupportedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Text("AI Features Unavailable")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Apple Intelligence requires an iPhone 15 Pro or later with iOS 26+")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Text("You can still use:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "square.and.pencil", text: "Manual flashcard creation")
                    FeatureRow(icon: "book.fill", text: "Browse and organize notes")
                    FeatureRow(icon: "chart.bar.fill", text: "Track study progress")
                    FeatureRow(icon: "calendar", text: "Spaced repetition reminders")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
}

// MARK: - Enable Apple Intelligence View

struct EnableAppleIntelligenceView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.fill")
                .font(.system(size: 60))
                .foregroundStyle(.purple)

            VStack(spacing: 12) {
                Text("Enable Apple Intelligence")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("AI-powered features require Apple Intelligence to be turned on")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Text("To enable:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 12) {
                    InstructionRow(number: 1, text: "Open Settings")
                    InstructionRow(number: 2, text: "Tap 'Apple Intelligence & Siri'")
                    InstructionRow(number: 3, text: "Turn on 'Apple Intelligence'")
                    InstructionRow(number: 4, text: "Return to CardGenie")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: openSettings) {
                Label("Open Settings", systemImage: "gear")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Model Downloading View

struct ModelDownloadingView: View {
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            VStack(spacing: 12) {
                Text("Preparing AI Model")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Apple Intelligence is downloading or initializing. This may take a few minutes.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Text("What's happening:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 8) {
                    StatusRow(icon: "arrow.down.circle.fill", text: "Downloading model files")
                    StatusRow(icon: "gear.circle.fill", text: "Optimizing for your device")
                    StatusRow(icon: "checkmark.circle.fill", text: "Preparing Neural Engine")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: refresh) {
                Label(
                    isRefreshing ? "Checking..." : "Check Again",
                    systemImage: "arrow.clockwise"
                )
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isRefreshing)
        }
        .padding()
    }

    private func refresh() {
        isRefreshing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isRefreshing = false
        }
    }
}

// MARK: - Generic Unavailable View

struct GenericUnavailableView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            VStack(spacing: 12) {
                Text("AI Temporarily Unavailable")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Apple Intelligence features are currently unavailable. Please try again later.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("Your notes and flashcards are safe. Manual study features remain fully functional.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Helper Components

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.green)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

private struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

private struct StatusRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

// MARK: - Preview Helpers

#Preview("Device Not Supported") {
    DeviceNotSupportedView()
}

#Preview("Enable Apple Intelligence") {
    EnableAppleIntelligenceView()
}

#Preview("Model Downloading") {
    ModelDownloadingView()
}

#Preview("Generic Unavailable") {
    GenericUnavailableView()
}
