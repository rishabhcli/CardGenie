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
    /// Falls back to in-memory storage if persistent storage fails.
    var modelContainer: ModelContainer = {
        let schema = Schema([
            StudyContent.self,
            Flashcard.self,
            FlashcardSet.self,
            SourceDocument.self,
            NoteChunk.self,
            LectureSession.self,
            HighlightMarker.self,
            HandwritingData.self,
            StudyPlan.self,
            StudySession.self,
            ConceptMap.self,
            ConceptNode.self,
            ConceptEdge.self,
            // Conversational Learning Models
            ConversationalSession.self,
            ChatMessage.self,
            // Game Mode Models
            MatchingGame.self,
            MatchPair.self,
            TrueFalseGame.self,
            MultipleChoiceGame.self,
            TeachBackSession.self,
            FeynmanSession.self,
            GameStatistics.self,
            // Content Generation Models
            GeneratedPracticeSet.self,
            GeneratedScenarioSet.self,
            GeneratedConnectionSet.self
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
            // If persistent storage fails, fall back to in-memory storage
            // This prevents app crashes while allowing the app to function
            print("⚠️ Failed to create persistent ModelContainer: \(error)")
            print("⚠️ Falling back to in-memory storage. Data will not persist between launches.")

            let memoryConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )

            do {
                return try ModelContainer(
                    for: schema,
                    configurations: [memoryConfig]
                )
            } catch {
                // This should never happen, but if it does, we have no choice but to crash
                // At least we tried to recover gracefully
                fatalError("Could not create even in-memory ModelContainer: \(error)")
            }
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
/// Uses iOS 26+ Tab API for modern Liquid Glass tab bar with sidebar adaptability
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var flashcardSets: [FlashcardSet]
    @State private var selectedTab: Int = 0

    var body: some View {
        if #available(iOS 26.0, *) {
            // iOS 26+ with AI Chat tab
            modernTabView
        } else {
            // Fallback for iOS 25
            legacyTabView
        }
    }

    // MARK: - iOS 26+ Modern Tab View

    @available(iOS 26.0, *)
    @ViewBuilder
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Study", systemImage: "sparkles", value: 0) {
                ContentListView()
            }

            if let badge = flashcardBadge {
                Tab("Flashcards", systemImage: "rectangle.on.rectangle.angled", value: 1) {
                    FlashcardListView()
                }
                .badge(badge)
            } else {
                Tab("Flashcards", systemImage: "rectangle.on.rectangle.angled", value: 1) {
                    FlashcardListView()
                }
            }

            Tab("AI Chat", systemImage: "message.fill", value: 2) {
                AIChatView()
            }

            Tab("Record", systemImage: "mic.circle.fill", value: 3) {
                VoiceRecordView()
            }

            Tab("Scan", systemImage: "camera.fill", value: 4) {
                PhotoScanView()
            }
        }
        .tabViewStyle(.sidebarAdaptable) // Sidebar on iPad, tabs on iPhone
        .tint(.cosmicPurple)
    }

    // MARK: - Legacy Tab View (iOS 25)

    @ViewBuilder
    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            ContentListView()
                .tabItem {
                    Label("Study", systemImage: "sparkles")
                }
                .tag(0)

            flashcardsTabLegacy

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
    private var flashcardsTabLegacy: some View {
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
