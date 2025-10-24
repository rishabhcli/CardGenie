//
//  SettingsView.swift
//  CardGenie
//
//  Settings and information view.
//  Shows privacy policy, AI availability, and app information.
//

import SwiftUI
import SwiftData

/// Settings view with privacy info and AI status
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var fmClient = FMClient()

    @Query private var allContent: [StudyContent]

    @State private var showClearDataConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // AI Status Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Apple Intelligence")
                                .font(.headline)

                            Text(aiStatusDescription)
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)
                        }

                        Spacer()

                        AvailabilityBadge(state: fmClient.capability())
                    }
                    .padding(.vertical, Spacing.xs)

                    if fmClient.capability() != .available {
                        Button("Open Settings") {
                            openSystemSettings()
                        }
                    }
                } header: {
                    Text("AI Features")
                } footer: {
                    Text("Apple Intelligence provides on-device summarization, writing assistance, and content tagging. All processing happens locally on your device.")
                }

                // Privacy Section
                Section {
                    InfoRow(
                        icon: "lock.shield.fill",
                        title: "100% Offline",
                        description: "All data stays on your device"
                    )

                    InfoRow(
                        icon: "cpu.fill",
                        title: "On-Device AI",
                        description: "Processing happens locally via Neural Engine"
                    )

                    InfoRow(
                        icon: "eye.slash.fill",
                        title: "No Tracking",
                        description: "We don't collect or share any data"
                    )

                    InfoRow(
                        icon: "icloud.slash.fill",
                        title: "No Cloud Sync",
                        description: "Your journal never leaves this device"
                    )
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("CardGenie is designed with privacy first. All your journal entries, AI processing, and data storage remain completely on your device.")
                }

                // Writing Tools Section
                Section {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Built-in Writing Tools")
                            .font(.headline)

                        Text("Select text in any entry to access:")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                            .padding(.bottom, Spacing.xs)

                        FeatureRow(icon: "checkmark.circle.fill", title: "Proofread")
                        FeatureRow(icon: "arrow.triangle.2.circlepath", title: "Rewrite")
                        FeatureRow(icon: "text.alignleft", title: "Summarize")
                        FeatureRow(icon: "wand.and.stars", title: "Transform")
                    }
                    .padding(.vertical, Spacing.xs)
                } header: {
                    Text("Features")
                } footer: {
                    Text("All Writing Tools features are powered by on-device Apple Intelligence and work completely offline.")
                }

                // Data Section
                Section {
                    HStack {
                        Text("Study Materials")
                        Spacer()
                        Text("\(allContent.count)")
                            .foregroundStyle(Color.secondaryText)
                    }

                    HStack {
                        Text("Total Characters")
                        Spacer()
                        Text("\(totalCharacterCount)")
                            .foregroundStyle(Color.secondaryText)
                    }

                    Button(role: .destructive) {
                        showClearDataConfirmation = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("All data is stored locally in the app's private storage.")
                }

                // About Section
                Section {
                    InfoRow(
                        icon: "app.badge.checkmark.fill",
                        title: "Version",
                        description: "1.0.0"
                    )

                    InfoRow(
                        icon: "iphone.gen3",
                        title: "Minimum OS",
                        description: "iOS 26.0"
                    )

                    InfoRow(
                        icon: "sparkles",
                        title: "Design",
                        description: "Liquid Glass UI"
                    )
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Clear All Data",
                isPresented: $showClearDataConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All Data", role: .destructive) {
                    clearAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all \(allContent.count) study materials. This action cannot be undone.")
            }
        }
    }

    // MARK: - Computed Properties

    private var aiStatusDescription: String {
        switch fmClient.capability() {
        case .available:
            return "Ready and available"
        case .notEnabled:
            return "Disabled in Settings"
        case .notSupported:
            return "Device not supported"
        case .modelNotReady:
            return "Loading model..."
        case .unknown:
            return "Status unknown"
        }
    }

    private var totalCharacterCount: Int {
        allContent.reduce(0) { $0 + $1.displayText.count }
    }

    // MARK: - Actions

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func clearAllData() {
        for content in allContent {
            modelContext.delete(content)
        }
        try? modelContext.save()
    }
}

// MARK: - Supporting Views

/// A row displaying information with an icon
private struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.aiAccent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.primaryText)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

/// A row displaying a feature with a checkmark
private struct FeatureRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(Color.aiAccent)
                .frame(width: 20)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.primaryText)
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: StudyContent.self, configurations: config)
    let context = ModelContext(container)

    // Add some sample content
    for i in 1...5 {
        let content = StudyContent(
            source: .text,
            rawContent: "Sample study content \(i) with some text for testing."
        )
        context.insert(content)
    }

    return SettingsView()
        .modelContainer(container)
}
