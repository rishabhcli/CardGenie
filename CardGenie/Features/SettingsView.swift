//
//  SettingsView.swift
//  CardGenie
//
//  Settings and information view.
//  Shows privacy policy, AI availability, and app information.
//

import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// Settings view with privacy info and AI status
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var fmClient = FMClient()

    @Query private var allContent: [StudyContent]
    @Query private var flashcardSets: [FlashcardSet]

    @AppStorage("studyRemindersEnabled") private var studyRemindersEnabled = false
    @AppStorage("dailyStudyGoal") private var dailyStudyGoal = 20
    @AppStorage("preferredTheme") private var preferredTheme = "system"
    @AppStorage("autoPlayAudio") private var autoPlayAudio = true
    @AppStorage("showStreakNotifications") private var showStreakNotifications = true
    @AppStorage("cardAnimationSpeed") private var cardAnimationSpeed = 1.0
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
    @AppStorage("spacedRepetitionAlgorithm") private var spacedRepetitionAlgorithm = "SM-2"

    @State private var showClearDataConfirmation = false
    @State private var showExportOptions = false
    @State private var showImportPicker = false
    @State private var exportError: Error?
    @State private var importSuccess = false
    @State private var importedCount = 0

    var body: some View {
        NavigationStack {
            List {
                // AI Status Section
                Section {
                    HStack {
                        Label("AI Features", systemImage: "sparkles")
                            .foregroundStyle(Color.cosmicPurple)
                        Spacer()
                        AvailabilityBadge(state: fmClient.capability())
                    }

                    if fmClient.capability() != .available {
                        Button {
                            openSystemSettings()
                        } label: {
                            Label("Open System Settings", systemImage: "gear")
                        }
                    }
                } header: {
                    Text("AI Features")
                }

                // Study Settings
                Section {
                    Toggle(isOn: $studyRemindersEnabled) {
                        Label("Study Reminders", systemImage: "bell.fill")
                    }
                    .tint(Color.cosmicPurple)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Daily Study Goal", systemImage: "target")
                        Picker("Daily Goal", selection: $dailyStudyGoal) {
                            Text("10 cards").tag(10)
                            Text("20 cards").tag(20)
                            Text("30 cards").tag(30)
                            Text("50 cards").tag(50)
                            Text("100 cards").tag(100)
                        }
                        .pickerStyle(.segmented)
                    }

                    Toggle(isOn: $showStreakNotifications) {
                        Label("Streak Notifications", systemImage: "flame.fill")
                    }
                    .tint(Color.magicGold)

                    Picker(selection: $spacedRepetitionAlgorithm) {
                        Text("SM-2 (Classic)").tag("SM-2")
                        Text("SM-2+ (Enhanced)").tag("SM-2+")
                        Text("Leitner System").tag("Leitner")
                    } label: {
                        Label("Review Algorithm", systemImage: "brain.head.profile")
                    }
                } header: {
                    Text("Study Preferences")
                } footer: {
                    Text("SM-2 is optimal for long-term retention. Leitner is simpler for quick reviews.")
                }

                // Appearance
                Section {
                    Picker(selection: $preferredTheme) {
                        Label("System", systemImage: "circle.lefthalf.filled").tag("system")
                        Label("Light", systemImage: "sun.max.fill").tag("light")
                        Label("Dark", systemImage: "moon.fill").tag("dark")
                    } label: {
                        Label("Theme", systemImage: "paintbrush.fill")
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Animation Speed", systemImage: "speedometer")
                        Slider(value: $cardAnimationSpeed, in: 0.5...2.0, step: 0.1) {
                            Text("Speed")
                        } minimumValueLabel: {
                            Text("0.5×").font(.caption)
                        } maximumValueLabel: {
                            Text("2×").font(.caption)
                        }
                        .tint(Color.cosmicPurple)

                        Text("Current: \(String(format: "%.1f", cardAnimationSpeed))×")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Appearance")
                }

                // Features
                Section {
                    Toggle(isOn: $autoPlayAudio) {
                        Label("Auto-play Voice Answers", systemImage: "speaker.wave.2.fill")
                    }
                    .tint(Color.genieGreen)

                    Toggle(isOn: $enableHapticFeedback) {
                        Label("Haptic Feedback", systemImage: "hand.tap.fill")
                    }
                    .tint(Color.cosmicPurple)
                } header: {
                    Text("Features")
                }

                // Data Section
                Section {
                    NavigationLink {
                        ProgressDetailView(
                            contentCount: allContent.count,
                            setCount: flashcardSets.count,
                            cardCount: totalFlashcardCount,
                            charCount: totalCharacterCount
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Your Progress", systemImage: "chart.bar.fill")
                                .font(.headline)
                                .foregroundStyle(Color.cosmicPurple)

                            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                                GridRow {
                                    Text("Study Materials:")
                                        .foregroundStyle(.secondary)
                                    Text("\(allContent.count)")
                                        .fontWeight(.semibold)
                                }
                                GridRow {
                                    Text("Flashcard Sets:")
                                        .foregroundStyle(.secondary)
                                    Text("\(flashcardSets.count)")
                                        .fontWeight(.semibold)
                                }
                                GridRow {
                                    Text("Total Cards:")
                                        .foregroundStyle(.secondary)
                                    Text("\(totalFlashcardCount)")
                                        .fontWeight(.semibold)
                                }
                                GridRow {
                                    Text("Characters:")
                                        .foregroundStyle(.secondary)
                                    Text("\(totalCharacterCount.formatted())")
                                        .fontWeight(.semibold)
                                }
                            }
                            .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Statistics")
                }

                // Backup Section
                Section {
                    Button {
                        showExportOptions = true
                    } label: {
                        Label("Export Flashcards", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showImportPicker = true
                    } label: {
                        Label("Import Flashcards", systemImage: "square.and.arrow.down")
                    }

                    Button(role: .destructive) {
                        showClearDataConfirmation = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash.fill")
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Export your flashcards to backup or share. Imports will merge with existing cards.")
                }

                // About Section
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(Color.secondaryText)
                    }

                    HStack {
                        Label("iOS Requirement", systemImage: "iphone")
                        Spacer()
                        Text("26.0+")
                            .foregroundStyle(Color.secondaryText)
                    }

                    Link(destination: URL(string: "https://apple.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }

                    Link(destination: URL(string: "https://github.com")!) {
                        Label("Open Source Licenses", systemImage: "doc.text.fill")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
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
            .confirmationDialog(
                "Export Format",
                isPresented: $showExportOptions,
                titleVisibility: .visible
            ) {
                Button("JSON (Full Backup)") {
                    exportFlashcards(format: .json)
                }
                Button("CSV (Progress Only)") {
                    exportFlashcards(format: .csv)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose export format. JSON preserves all data, CSV is for spreadsheets.")
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert("Import Successful", isPresented: $importSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Imported \(importedCount) flashcards successfully!")
            }
            .errorAlert($exportError)
        }
    }

    // MARK: - Computed Properties

    private var totalCharacterCount: Int {
        allContent.reduce(0) { $0 + $1.displayText.count }
    }

    private var totalFlashcardCount: Int {
        flashcardSets.reduce(0) { $0 + $1.cardCount }
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

    // MARK: - Export/Import

    private enum ExportFormat {
        case json
        case csv
    }

    private func exportFlashcards(format: ExportFormat) {
        guard !flashcardSets.isEmpty else {
            exportError = ExportError.noDataToExport
            return
        }

        do {
            let data: Data
            let filename: String

            switch format {
            case .json:
                data = try FlashcardExporter.exportToJSON(sets: flashcardSets)
                filename = FlashcardExporter.generateFilename(extension: "json")
            case .csv:
                let csvString = try FlashcardExporter.exportToCSV(sets: flashcardSets)
                data = Data(csvString.utf8)
                filename = FlashcardExporter.generateFilename(extension: "csv")
            }

            let fileURL = try FlashcardExporter.createExportFile(data: data, filename: filename)
            shareFile(at: fileURL)

        } catch {
            exportError = error
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                exportError = ExportError.fileWriteFailed("Cannot access file")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            importedCount = try FlashcardExporter.importFromJSON(data, into: modelContext)
            importSuccess = true

        } catch {
            exportError = error
        }
    }

    private func shareFile(at url: URL) {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Progress Detail View

struct ProgressDetailView: View {
    let contentCount: Int
    let setCount: Int
    let cardCount: Int
    let charCount: Int

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    ProgressRow(
                        icon: "doc.text.fill",
                        label: "Study Materials",
                        value: "\(contentCount)",
                        color: .cosmicPurple
                    )

                    ProgressRow(
                        icon: "square.stack.3d.up.fill",
                        label: "Flashcard Sets",
                        value: "\(setCount)",
                        color: .mysticBlue
                    )

                    ProgressRow(
                        icon: "rectangle.portrait.on.rectangle.portrait.fill",
                        label: "Total Flashcards",
                        value: "\(cardCount)",
                        color: .genieGreen
                    )

                    ProgressRow(
                        icon: "character.cursor.ibeam",
                        label: "Characters Written",
                        value: charCount.formatted(),
                        color: .magicGold
                    )
                }
                .padding(.vertical, 8)
            } header: {
                Text("Your Statistics")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Keep it up!")
                        .font(.headline)

                    Text("You're making great progress with your studies. Consistency is key to long-term retention.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Motivation")
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct ProgressRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = (try? ModelContainer(for: StudyContent.self, configurations: config)) ?? {
        try! ModelContainer(for: StudyContent.self)
    }()
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
