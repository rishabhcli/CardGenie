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
        // Create schema with all models including conversation history and chat
        let schema = Schema([
            StudyContent.self,
            Flashcard.self,
            FlashcardSet.self,
            ConversationSession.self,  // Voice assistant
            ConversationMessage.self,  // Voice assistant
            ChatSession.self,          // AI Chat
            ChatMessage.self,          // AI Chat
            ScanAttachment.self        // AI Chat scans
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            print("✅ ModelContainer created successfully with core models")
            return container
        } catch {
            print("⚠️ Failed to create persistent ModelContainer: \(error)")
            print("⚠️ Error details: \(error.localizedDescription)")
            print("⚠️ Falling back to in-memory storage.")

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
                fatalError("Could not create even in-memory ModelContainer: \(error)")
            }
        }
    }()

    @StateObject private var onboardingCoordinator = OnboardingCoordinator()

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                    .environment(\.font, .system(.body, design: .rounded)) // Rounded font for genie theme
                    .tint(.cosmicPurple) // Genie theme accent color
                    .onAppear {
                        // Setup notifications on first launch
                        Task {
                            await NotificationManager.shared.setupNotificationsIfNeeded()
                        }
                    }
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }

                // Onboarding overlay
                if !onboardingCoordinator.isCompleted {
                    OnboardingView(coordinator: onboardingCoordinator)
                        .transition(.opacity)
                }
            }
        }
        .modelContainer(modelContainer) // Inject SwiftData container
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "cardgenie" else { return }

        switch url.host {
        case "flashcards":
            if url.path == "/due" {
                // Navigate to Flashcards tab and start study session with due cards
                NotificationCenter.default.post(name: NSNotification.Name("StartStudySession"), object: nil)
            }
        case "study":
            if url.path == "/start" {
                // Navigate to Flashcards tab and start study session
                NotificationCenter.default.post(name: NSNotification.Name("StartStudySession"), object: nil)
            }
        default:
            break
        }
    }
}

// MARK: - Main Tab View

/// Main navigation with Study Materials, Flashcards, and Scan tabs
/// iOS 26+ uses 3 tabs + floating AI assistant button
/// iOS 25 uses legacy 5-tab layout for compatibility
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var flashcardSets: [FlashcardSet]
    @State private var selectedTab: Int = 0
    @State private var showingSettings = false

    // App Intent handling
    @State private var shouldStartStudySession = false
    @State private var aiChatQuestion: String?
    @State private var pendingGenerationText: String?

    var body: some View {
        if #available(iOS 26.0, *) {
            // iOS 26+ with 3 tabs + floating AI assistant
            modernTabView
                .onAppear {
                    setupIntentObservers()
                }
        } else {
            // Fallback for iOS 25 (5 tabs)
            legacyTabView
                .onAppear {
                    setupIntentObservers()
                }
        }
    }

    // MARK: - App Intent Handling

    private func setupIntentObservers() {
        // Start study session intent
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("StartStudySession"),
            object: nil,
            queue: .main
        ) { _ in
            selectedTab = 1 // Switch to Flashcards tab
            shouldStartStudySession = true
        }

        // Open AI chat intent
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenAIChat"),
            object: nil,
            queue: .main
        ) { _ in
            selectedTab = 2 // Switch to AI tab (iOS 26+) or tab 2 (iOS 25)
        }

        // Open AI chat with question
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenAIChatWithQuestion"),
            object: nil,
            queue: .main
        ) { notification in
            if let question = notification.userInfo?["question"] as? String {
                selectedTab = 2 // Switch to AI tab
                aiChatQuestion = question
            }
        }

        // Generate flashcards from text
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("GenerateFlashcardsFromText"),
            object: nil,
            queue: .main
        ) { notification in
            if let text = notification.userInfo?["text"] as? String {
                selectedTab = 0 // Switch to Study tab
                pendingGenerationText = text
            }
        }
    }

    // MARK: - iOS 26+ Modern Tab View

    @available(iOS 26.0, *)
    @ViewBuilder
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Study", systemImage: "book.fill", value: 0) {
                NavigationStack {
                    ContentListView(pendingGenerationText: $pendingGenerationText)
                        .navigationTitle("Study")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showingSettings = true
                                } label: {
                                    Image(systemName: "gearshape")
                                }
                                .accessible(label: "Settings")
                            }
                        }
                }
            }

            if let badge = flashcardBadge {
                Tab("Cards", systemImage: "rectangle.on.rectangle", value: 1) {
                    NavigationStack {
                        FlashcardListView()
                            .navigationTitle("Flashcards")
                            .navigationBarTitleDisplayMode(.large)
                    }
                }
                .badge(badge)
            } else {
                Tab("Cards", systemImage: "rectangle.on.rectangle", value: 1) {
                    NavigationStack {
                        FlashcardListView()
                            .navigationTitle("Flashcards")
                            .navigationBarTitleDisplayMode(.large)
                    }
                }
            }

            Tab("Chat", systemImage: "message.fill", value: 2) {
                ChatView()
            }

            Tab("Record", systemImage: "mic.circle.fill", value: 3) {
                NavigationStack {
                    VoiceRecordView()
                        .navigationTitle("Record")
                        .navigationBarTitleDisplayMode(.large)
                }
            }

            Tab("Scan", systemImage: "doc.viewfinder", value: 4) {
                NavigationStack {
                    PhotoScanView()
                        .navigationTitle("Scan")
                        .navigationBarTitleDisplayMode(.large)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(.cosmicPurple)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }

    // MARK: - Legacy Tab View (iOS 25)

    @ViewBuilder
    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            ContentListView(pendingGenerationText: $pendingGenerationText)
                .tabItem {
                    Label("Study", systemImage: "sparkles")
                }
                .tag(0)

            flashcardsTabLegacy

            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
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

    // MARK: - Helper Properties

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

 4. Tab Bar Layout:
    iOS 26+ Modern Layout (5 tabs):
    - Study: View and manage study content
    - Cards: Flashcard sets and spaced repetition
    - AI: AI chat assistant powered by Foundation Models
    - Record: Voice recording for lecture capture
    - Scan: Document and photo scanning
    
    iOS 25 Legacy Layout (5 tabs):
    - Study, Cards, AI Chat, Record, Scan (same functionality)

 5. Capabilities:
    - No special entitlements needed for offline features
    - Apple Intelligence features work automatically on supported devices
    - Writing Tools are enabled at the text view level

 6. Info.plist Keys (if adding media later):
    - NSCameraUsageDescription (for photos)
    - NSMicrophoneUsageDescription (for voice notes)

 7. Privacy:
    - All data stays on device
    - No network calls
    - No analytics
    - AI processing is entirely on-device
 */
