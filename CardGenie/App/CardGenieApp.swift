//
//  CardGenieApp.swift
//  CardGenie
//
//  Main app entry point for CardGenie.
//  Configures SwiftData container for local, offline storage.
//

import SwiftUI
import SwiftData

@main
struct CardGenieApp: App {
    /// SwiftData container configured for local storage only
    /// All study content and flashcards are stored in the app's private sandbox
    /// with no iCloud sync or external file access.
    var modelContainer: ModelContainer = {
        let schema = Schema([
            StudyContent.self,
            Flashcard.self,
            FlashcardSet.self,
            SourceDocument.self,
            NoteChunk.self,
            LectureSession.self,
            HighlightMarker.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            // Data is stored locally in app sandbox, not exposed to Files app
            allowsSave: true
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.font, .system(.body, design: .rounded)) // Rounded font for genie theme
                .tint(.cosmicPurple) // Genie theme accent color
                .onAppear {
                    // Setup notifications on first launch
                    Task {
                        await NotificationManager.shared.setupNotificationsIfNeeded()
                    }
                }
        }
        .modelContainer(modelContainer) // Inject SwiftData container
    }
}

// MARK: - Main Tab View

/// Main navigation with Study Materials, Flashcards, and Settings tabs
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var flashcardSets: [FlashcardSet]

    var body: some View {
        TabView {
            ContentListView()
                .tabItem {
                    Label("Study", systemImage: "sparkles")
                }
                .tag(0)

            flashcardsTab

            VoiceAssistantView()
                .tabItem {
                    Label("Ask", systemImage: "waveform.circle.fill")
                }
                .tag(2)

            VoiceRecordView()
                .tabItem {
                    Label("Record", systemImage: "mic.circle.fill")
                }
                .tag(3)

            PhotoScanView()
                .tabItem {
                    Label("Scan", systemImage: "camera.fill")
                }
                .tag(4)
        }
        .accentColor(.cosmicPurple)
    }

    @ViewBuilder
    private var flashcardsTab: some View {
        if let badge = flashcardBadge {
            FlashcardListView()
                .tabItem {
                    Label("Flashcards", systemImage: "rectangle.on.rectangle.angled")
                }
                .badge(badge)
                .tag(1)
        } else {
            FlashcardListView()
                .tabItem {
                    Label("Flashcards", systemImage: "rectangle.on.rectangle.angled")
                }
                .tag(1)
        }
    }

    /// Total due flashcards across all sets
    private var totalDueCount: Int {
        flashcardSets.reduce(0) { $0 + $1.dueCount }
    }

    /// Badge value for flashcards tab (nil when 0)
    private var flashcardBadge: Int? {
        let count = totalDueCount
        return count > 0 ? count : nil
    }
}

// MARK: - App Configuration Notes
/*
 iOS 26 Configuration Requirements:

 1. Deployment Target: Set to iOS 26.0 in Xcode project settings
 2. Minimum Device: iPhone 15 Pro or newer (for Apple Intelligence)
 3. Required Frameworks:
    - SwiftUI (for UI)
    - SwiftData (for local persistence)
    - FoundationModels (for on-device AI - iOS 26+)
    - UIKit (for Writing Tools bridge)

 4. Capabilities:
    - No special entitlements needed for offline features
    - Apple Intelligence features work automatically on supported devices
    - Writing Tools are enabled at the text view level

 5. Info.plist Keys (if adding media later):
    - NSCameraUsageDescription (for photos)
    - NSMicrophoneUsageDescription (for voice notes)

 6. Privacy:
    - All data stays on device
    - No network calls
    - No analytics
    - AI processing is entirely on-device
 */
