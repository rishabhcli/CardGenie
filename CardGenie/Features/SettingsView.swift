//
//  SettingsView.swift
//  CardGenie
//
//  Settings and information view.
//  Shows privacy policy, AI availability, and app information.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Settings view with privacy info and AI status
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var fmClient = FMClient()

    @Query private var allContent: [StudyContent]
    @Query private var flashcardSets: [FlashcardSet]

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
                        Text("Apple Intelligence")
                        Spacer()
                        AvailabilityBadge(state: fmClient.capability())
                    }

                    if fmClient.capability() != .available {
                        Button("Open System Settings") {
                            openSystemSettings()
                        }
                    }
                } header: {
                    Text("AI")
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
                        Text("Flashcard Sets")
                        Spacer()
                        Text("\(flashcardSets.count)")
                            .foregroundStyle(Color.secondaryText)
                    }

                    HStack {
                        Text("Total Flashcards")
                        Spacer()
                        Text("\(totalFlashcardCount)")
                            .foregroundStyle(Color.secondaryText)
                    }

                    HStack {
                        Text("Characters Written")
                        Spacer()
                        Text("\(totalCharacterCount.formatted())")
                            .foregroundStyle(Color.secondaryText)
                    }
                } header: {
                    Text("Your Progress")
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
                        Label("Clear All Data", systemImage: "trash")
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Export your flashcards to backup or share. Imports will merge with existing cards.")
                }

                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(Color.secondaryText)
                    }

                    HStack {
                        Text("iOS Requirement")
                        Spacer()
                        Text("26.0+")
                            .foregroundStyle(Color.secondaryText)
                    }
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
