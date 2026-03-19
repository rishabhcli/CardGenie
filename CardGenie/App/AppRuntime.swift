//
//  AppRuntime.swift
//  CardGenie
//
//  App bootstrap, persistence state, and shared SwiftData schema.
//

import Foundation
import Combine
import SwiftUI
import SwiftData

enum AppBootstrapState: String {
    case ready
    case degradedInMemory
    case unavailable
}

enum PersistenceMode: String {
    case persistent
    case inMemoryTemporary
    case unavailable

    var writesAreDurable: Bool {
        self == .persistent
    }

    var bannerTitle: String {
        switch self {
        case .persistent:
            return "Storage Ready"
        case .inMemoryTemporary:
            return "Temporary Storage Mode"
        case .unavailable:
            return "Storage Unavailable"
        }
    }

    var bannerMessage: String {
        switch self {
        case .persistent:
            return "All study data is stored locally on this device."
        case .inMemoryTemporary:
            return "CardGenie is running locally, but new changes will be lost if the app closes."
        case .unavailable:
            return "CardGenie could not open local storage."
        }
    }
}

@MainActor
final class AppRuntimeState: ObservableObject {
    @Published private(set) var bootstrapState: AppBootstrapState
    @Published private(set) var persistenceMode: PersistenceMode
    @Published private(set) var bootstrapMessage: String?
    @Published var hasPresentedPersistenceNotice = false

    init(
        bootstrapState: AppBootstrapState,
        persistenceMode: PersistenceMode,
        bootstrapMessage: String? = nil
    ) {
        self.bootstrapState = bootstrapState
        self.persistenceMode = persistenceMode
        self.bootstrapMessage = bootstrapMessage
    }

    func markPersistenceNoticePresented() {
        hasPresentedPersistenceNotice = true
    }
}

private struct PersistenceModeKey: EnvironmentKey {
    static let defaultValue = PersistenceMode.persistent
}

private struct AppBootstrapStateKey: EnvironmentKey {
    static let defaultValue = AppBootstrapState.ready
}

extension EnvironmentValues {
    var persistenceMode: PersistenceMode {
        get { self[PersistenceModeKey.self] }
        set { self[PersistenceModeKey.self] = newValue }
    }

    var appBootstrapState: AppBootstrapState {
        get { self[AppBootstrapStateKey.self] }
        set { self[AppBootstrapStateKey.self] = newValue }
    }
}

enum CardGenieSchemaProvider {
    nonisolated static var schema: Schema {
        Schema([
            StudyContent.self,
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
            Flashcard.self,
            FlashcardSet.self,
            ConversationSession.self,
            VoiceConversationMessage.self,
            ChatSession.self,
            ChatMessageModel.self,
            ScanAttachment.self,
            ConversationalSession.self,
            ConversationalMessage.self,
            MatchingGame.self,
            MatchPair.self,
            TrueFalseGame.self,
            MultipleChoiceGame.self,
            TeachBackSession.self,
            FeynmanSession.self,
            GameStatistics.self,
            GeneratedPracticeSet.self,
            GeneratedScenarioSet.self,
            GeneratedConnectionSet.self,
            PendingScanJob.self
        ])
    }
}

struct AppBootstrapResult {
    let modelContainer: ModelContainer?
    let runtimeState: AppRuntimeState
}

enum AppBootstrapper {
    static func bootstrap() -> AppBootstrapResult {
        let environment = ProcessInfo.processInfo.environment
        let schema = CardGenieSchemaProvider.schema

        if environment["CARDGENIE_FORCE_BOOTSTRAP_UNAVAILABLE"] == "1" {
            return AppBootstrapResult(
                modelContainer: nil,
                runtimeState: AppRuntimeState(
                    bootstrapState: .unavailable,
                    persistenceMode: .unavailable,
                    bootstrapMessage: "CardGenie was forced into an unavailable storage state for validation."
                )
            )
        }

        if environment["CARDGENIE_FORCE_IN_MEMORY_BOOTSTRAP"] == "1" {
            do {
                let container = try makeContainer(schema: schema, inMemoryOnly: true)
                return AppBootstrapResult(
                    modelContainer: container,
                    runtimeState: AppRuntimeState(
                        bootstrapState: .degradedInMemory,
                        persistenceMode: .inMemoryTemporary,
                        bootstrapMessage: "Running in temporary in-memory mode for validation."
                    )
                )
            } catch {
                return AppBootstrapResult(
                    modelContainer: nil,
                    runtimeState: AppRuntimeState(
                        bootstrapState: .unavailable,
                        persistenceMode: .unavailable,
                        bootstrapMessage: error.localizedDescription
                    )
                )
            }
        }

        do {
            let container = try makeContainer(schema: schema, inMemoryOnly: false)
            return AppBootstrapResult(
                modelContainer: container,
                runtimeState: AppRuntimeState(
                    bootstrapState: .ready,
                    persistenceMode: .persistent
                )
            )
        } catch {
            do {
                let fallbackContainer = try makeContainer(schema: schema, inMemoryOnly: true)
                return AppBootstrapResult(
                    modelContainer: fallbackContainer,
                    runtimeState: AppRuntimeState(
                        bootstrapState: .degradedInMemory,
                        persistenceMode: .inMemoryTemporary,
                        bootstrapMessage: "Local storage could not be opened. CardGenie is using temporary in-memory storage instead."
                    )
                )
            } catch {
                return AppBootstrapResult(
                    modelContainer: nil,
                    runtimeState: AppRuntimeState(
                        bootstrapState: .unavailable,
                        persistenceMode: .unavailable,
                        bootstrapMessage: "CardGenie could not open local storage or its in-memory fallback."
                    )
                )
            }
        }
    }

    private static func makeContainer(schema: Schema, inMemoryOnly: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemoryOnly,
            allowsSave: true
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeDisplayContainer() -> ModelContainer? {
        try? makeContainer(schema: CardGenieSchemaProvider.schema, inMemoryOnly: true)
    }
}
