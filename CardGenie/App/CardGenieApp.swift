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
    @StateObject private var runtimeState: AppRuntimeState
    private let modelContainer: ModelContainer

    init() {
        let bootstrap = AppBootstrapper.bootstrap()
        self.modelContainer = bootstrap.modelContainer
            ?? AppBootstrapper.makeDisplayContainer()
            ?? {
                let schema = CardGenieSchemaProvider.schema
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try! ModelContainer(for: schema, configurations: [configuration])
            }()
        self._runtimeState = StateObject(wrappedValue: bootstrap.runtimeState)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if runtimeState.bootstrapState == .unavailable {
                    AppBootstrapUnavailableView()
                } else {
                    MainTabView()
                }
            }
            .environmentObject(runtimeState)
            .environment(\.font, .system(.body, design: .rounded))
            .environment(\.persistenceMode, runtimeState.persistenceMode)
            .environment(\.appBootstrapState, runtimeState.bootstrapState)
            .tint(.cosmicPurple)
            .task {
                await NotificationManager.shared.setupNotificationsIfNeeded()
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .preferredColorScheme(appColorScheme)
        }
        .modelContainer(modelContainer)
    }

    private var appColorScheme: ColorScheme? {
        switch UserDefaults.standard.string(forKey: "preferredTheme") {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "cardgenie" else { return }

        switch (url.host, url.path) {
        case ("flashcards", "/due"), ("study", "/start"):
            NotificationCenter.default.post(name: .startStudySession, object: nil)
        default:
            break
        }
    }
}

extension Notification.Name {
    static let startStudySession = Notification.Name("StartStudySession")
    static let openAIChat = Notification.Name("OpenAIChat")
    static let openAIChatWithQuestion = Notification.Name("OpenAIChatWithQuestion")
    static let generateFlashcardsFromText = Notification.Name("GenerateFlashcardsFromText")
    static let switchToStudyTab = Notification.Name("SwitchToStudyTab")
    static let switchToRecordTab = Notification.Name("SwitchToRecordTab")
    static let switchToScanTab = Notification.Name("SwitchToScanTab")
}

private enum AppTab: Int {
    case study
    case flashcards
    case ai
    case record
    case scan
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var runtimeState: AppRuntimeState
    @Query private var flashcardSets: [FlashcardSet]
    @SceneStorage("selectedTab") private var selectedTabRawValue = AppTab.study.rawValue
    @State private var showingSettings = false
    @State private var pendingGenerationText: String?
    @State private var showingPersistenceRecovery = false
    @StateObject private var scanQueue = ScanQueue.shared
    @StateObject private var fmClient = FMClient()

    private var selectedTab: Binding<Int> {
        Binding(
            get: { selectedTabRawValue },
            set: { selectedTabRawValue = $0 }
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            tabView

            VStack(spacing: 8) {
                if runtimeState.persistenceMode == .inMemoryTemporary {
                    AppStatusBanner(
                        systemImage: "externaldrive.badge.exclamationmark",
                        title: runtimeState.persistenceMode.bannerTitle,
                        message: runtimeState.bootstrapMessage ?? runtimeState.persistenceMode.bannerMessage,
                        tint: .orange
                    )
                }

                if !scanQueue.pendingScans.isEmpty {
                    AppStatusBanner(
                        systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                        title: "\(scanQueue.pendingScans.count) Scan Job\(scanQueue.pendingScans.count == 1 ? "" : "s") Queued",
                        message: "Pending scans will retry automatically when on-device AI is ready.",
                        tint: .mysticBlue
                    )
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 12)
        }
        .onReceive(NotificationCenter.default.publisher(for: .startStudySession)) { _ in
            selectedTabRawValue = AppTab.flashcards.rawValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAIChat)) { _ in
            selectedTabRawValue = AppTab.ai.rawValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAIChatWithQuestion)) { _ in
            selectedTabRawValue = AppTab.ai.rawValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .generateFlashcardsFromText)) { notification in
            selectedTabRawValue = AppTab.study.rawValue
            pendingGenerationText = notification.userInfo?["text"] as? String
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToStudyTab)) { _ in
            selectedTabRawValue = AppTab.study.rawValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToRecordTab)) { _ in
            selectedTabRawValue = AppTab.record.rawValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToScanTab)) { _ in
            selectedTabRawValue = AppTab.scan.rawValue
        }
        .task {
            refreshPendingScans()
            await processPendingScansIfPossible()
            if runtimeState.persistenceMode == .inMemoryTemporary,
               !runtimeState.hasPresentedPersistenceNotice {
                showingPersistenceRecovery = true
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }

            refreshPendingScans()
            Task {
                await processPendingScansIfPossible()
            }
        }
        .sheet(isPresented: $showingPersistenceRecovery, onDismiss: {
            runtimeState.markPersistenceNoticePresented()
        }) {
            PersistenceRecoverySheet()
        }
    }

    @ViewBuilder
    private var tabView: some View {
        TabView(selection: selectedTab) {
            Tab("Study", systemImage: "book.fill", value: AppTab.study.rawValue) {
                ContentListView(pendingGenerationText: $pendingGenerationText)
            }

            if let badge = flashcardBadge {
                Tab("Cards", systemImage: "rectangle.on.rectangle", value: AppTab.flashcards.rawValue) {
                    FlashcardListView()
                }
                .badge(badge)
            } else {
                Tab("Cards", systemImage: "rectangle.on.rectangle", value: AppTab.flashcards.rawValue) {
                    FlashcardListView()
                }
            }

            Tab("AI", systemImage: "sparkles", value: AppTab.ai.rawValue) {
                AIChatView()
            }

            Tab("Record", systemImage: "mic.circle.fill", value: AppTab.record.rawValue) {
                VoiceRecordView()
            }

            Tab("Scan", systemImage: "doc.viewfinder", value: AppTab.scan.rawValue) {
                PhotoScanView()
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

    private var totalDueCount: Int {
        flashcardSets.reduce(0) { $0 + $1.dueCount }
    }

    private var flashcardBadge: Int? {
        let count = totalDueCount
        return count > 0 ? count : nil
    }

    private func refreshPendingScans() {
        scanQueue.refresh(modelContext: modelContext)
    }

    private func processPendingScansIfPossible() async {
        guard runtimeState.persistenceMode != .unavailable else { return }
        _ = await scanQueue.processQueue(modelContext: modelContext, fmClient: fmClient)
    }
}

private struct AppStatusBanner: View {
    let systemImage: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct PersistenceRecoverySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var runtimeState: AppRuntimeState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(runtimeState.bootstrapMessage ?? runtimeState.persistenceMode.bannerMessage)
                        .font(.body)
                        .foregroundStyle(.primary)
                } header: {
                    Text("Current Mode")
                }

                Section {
                    Label("New notes, flashcards, and scan jobs will only live in memory.", systemImage: "externaldrive.badge.exclamationmark")
                    Label("If the app closes, temporary changes are lost.", systemImage: "trash.slash")
                    Label("Restart the app after storage becomes available again to resume normal local saving.", systemImage: "arrow.clockwise")
                } header: {
                    Text("Recovery")
                }
            }
            .navigationTitle("Temporary Storage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct AppBootstrapUnavailableView: View {
    @EnvironmentObject private var runtimeState: AppRuntimeState

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "CardGenie Couldn’t Open Local Storage",
                systemImage: "externaldrive.badge.xmark",
                description: Text(
                    runtimeState.bootstrapMessage ??
                    "Restart the app after local storage becomes available again."
                )
            )
            .navigationTitle("CardGenie")
        }
    }
}
