# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CardGenie is a native iOS 26+ smart flashcard and study app leveraging Apple Intelligence for on-device AI features. The app uses Apple's Foundation Models API for AI-powered flashcard generation, summarization, and study assistance - all completely offline with zero network calls.

**Key Technologies:**
- SwiftUI + SwiftData (declarative UI and local persistence)
- Foundation Models (iOS 26+ on-device AI via Neural Engine)
- Liquid Glass design language (iOS 26+ translucent UI)
- Vision framework (OCR from photos/handwriting)
- Speech framework (voice transcription)

**Privacy Model:** 100% offline, no analytics, no cloud sync, all data and AI processing stays on device.

## Using Context7 for Documentation

**IMPORTANT:** Always use Context7 MCP when you need:
- **Code generation** using external libraries or frameworks
- **Setup/configuration steps** for dependencies or tools
- **Library/API documentation** for Swift frameworks, iOS SDKs, or third-party packages

Context7 provides up-to-date documentation and examples directly from official sources. When you need to work with a library or API:

1. Automatically resolve the library ID (e.g., "SwiftUI", "Vision", "FoundationModels")
2. Use Context7 to fetch the latest documentation
3. Generate code based on the official API documentation, not assumptions

**Example scenarios where Context7 is essential:**
- Implementing new Vision framework features → fetch Vision docs
- Working with SwiftData relationships → fetch SwiftData docs
- Adding Speech recognition → fetch Speech framework docs
- Setting up new dependencies → fetch setup/config docs

Do not guess API signatures or configuration steps when Context7 can provide authoritative information.

## Building and Testing

### Build Commands

```bash
# Build the app (Debug)
xcodebuild -project CardGenie.xcodeproj -scheme CardGenie -configuration Debug build

# Build for device/simulator
xcodebuild -project CardGenie.xcodeproj -scheme CardGenie -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Clean build folder
xcodebuild clean -project CardGenie.xcodeproj -scheme CardGenie
```

### Testing

```bash
# Run all tests
xcodebuild test -project CardGenie.xcodeproj -scheme CardGenie -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run specific test class
xcodebuild test -project CardGenie.xcodeproj -scheme CardGenie -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -only-testing:CardGenieTests/FMClientTests

# Run specific test method
xcodebuild test -project CardGenie.xcodeproj -scheme CardGenie -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -only-testing:CardGenieTests/FMClientTests/testSummarizeWithValidText

# Available test targets:
# - CardGenieTests (unit tests)
# - CardGenieUITests (UI tests)
```

### Development in Xcode

- Open `CardGenie.xcodeproj` in Xcode 17+
- Deployment target: iOS 26.0
- Recommended simulator: iPhone 15 Pro (supports Apple Intelligence)
- Press ⌘B to build, ⌘U to run tests, ⌘R to run

## Architecture

### High-Level Structure

CardGenie follows an **MVVM architecture** with clear separation between data (SwiftData models), business logic (processors/intelligence), and UI (SwiftUI views).

```
┌─────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                        │
│              (Features/, Design/Components/)                │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────────┐
│                   Business Logic Layer                      │
│  • Processors/ (content processing, flashcard generation)  │
│  • Intelligence/ (AI engines, FMClient, speech, vision)    │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────────┐
│                     Data Layer (SwiftData)                  │
│  • CoreModels.swift (StudyContent, ContentSource)          │
│  • FlashcardModels.swift (Flashcard, FlashcardSet)        │
│  • SourceModels.swift (SourceDocument, NoteChunk)         │
│  • Store.swift (CRUD operations)                           │
└─────────────────────────────────────────────────────────────┘
```

### Key Architectural Patterns

**1. Multi-Source Content Pipeline**

The app supports multiple input sources (text, photos, voice, PDFs, lectures) that follow a common processing pipeline:

```
Input Source → Processor → SourceDocument → NoteChunks → Flashcards
```

- `SourceDocument`: Represents the raw input (PDF, image, recording, etc.)
- `NoteChunk`: Extracted text segments with metadata (page numbers, timestamps)
- `Flashcard`: Generated study cards linked back to source chunks

**2. AI Processing Flow**

All AI features use the `FMClient` (Foundation Models Client) as a unified interface:

```swift
// Intelligence/FMClient.swift
@MainActor
final class FMClient: ObservableObject {
    func capability() -> FMCapabilityState
    func summarize(_ text: String) async throws -> String
    func tags(for text: String) async throws -> [String]
    func reflection(for text: String) async throws -> String
    func generateEncouragement(...) async throws -> String
}
```

The client automatically detects Apple Intelligence availability and falls back to local heuristics when unavailable. This ensures the app works on all devices, not just those with Neural Engine support.

**3. Flashcard Generation Architecture**

Flashcard generation is handled by specialized processors in `Processors/`:

- `FlashcardGenerator.swift`: Core AI-powered flashcard creation from text chunks
- `HighlightExtractor.swift`: Extracts highlighted text from documents
- `HighlightCardBuilder.swift`: Converts highlights to flashcards
- `HandwritingProcessor.swift`: OCR for handwritten notes
- `ImageProcessor.swift`: Photo analysis and text extraction
- `PDFProcessor.swift`: PDF parsing and text extraction

Each processor outputs `NoteChunk` objects that feed into the flashcard generation pipeline.

**4. Spaced Repetition System**

Flashcards use the **SM-2 algorithm** for spaced repetition:

- `SpacedRepetitionManager.swift`: Core SR logic and scheduling
- Each `Flashcard` tracks: `easeFactor`, `interval`, `nextReviewDate`, `reviewCount`
- Review ratings: Again (forgot), Good (remembered), Easy (trivial)
- Mastery levels: Learning → Developing → Proficient → Mastered

**5. Data Models and Relationships**

SwiftData models with cascading relationships:

```
StudyContent (1) ←→ (many) Flashcard
                ↓
         FlashcardSet (groups flashcards by topic)

SourceDocument (1) ←→ (many) NoteChunk (1) ←→ (many) Flashcard
```

All models use `@Model` macro and persist automatically. The `ModelContainer` is configured in `CardGenieApp.swift` with fallback to in-memory storage on failure.

### Critical Components

**FMClient (Intelligence/FMClient.swift)**
- Wrapper around iOS 26's Foundation Models API
- Currently uses **placeholder implementations** until real iOS 26 SDK is available
- When iOS 26 ships, replace placeholder code with actual `SystemLanguageModel` API calls
- Handles capability detection, graceful fallbacks, and error handling

**Store (Data/Store.swift)**
- Simple persistence layer over SwiftData's ModelContext
- Provides CRUD operations: `newContent()`, `delete()`, `save()`, `fetchAllContent()`, `search()`
- All operations are synchronous and local (no async database calls)

**Processors Pipeline**
- Each processor is independent and can be used standalone
- Processors output `SourceDocument` + `NoteChunk[]` for downstream use
- AI-powered processors use `FMClient` or dedicated engines (e.g., `AIEngine.swift`)

**Theme System (Design/Theme.swift)**
- iOS 26+ uses native `.glassEffect()` modifier for Liquid Glass
- iOS 25 fallback uses Material-based effects
- Automatic accessibility support (Reduce Transparency, Reduce Motion)
- View modifiers: `.glassPanel()`, `.glassContentBackground()`, `.glassOverlay()`, `.glassSearchBar()`

**Search Bar (Design/Components/GlassSearchBar.swift)**
- Uses iOS 26 `.glassEffect(.regular.interactive(), in: .capsule)` for native Liquid Glass
- Interactive mode provides shimmer effect on user input
- Capsule shape is optimal for search bars (vs. rect)
- See `docs/ui/iOS26_Liquid_Glass_Search_Bar.md` for implementation details and best practices

**Floating AI Assistant (App/CardGenieApp.swift)**
- iOS 26+ uses `.tabViewBottomAccessory` for bottom-right floating button
- Consolidates "Ask" and "Record" voice features into single menu-driven button
- Reduces tab count from 5 → 3 (Study, Flashcards, Scan)
- Native Liquid Glass effect (automatic)
- Menu shows "Ask Question" and "Record Lecture" options
- Opens VoiceAssistantView or VoiceRecordView in sheet presentation
- iOS 25 fallback maintains legacy 5-tab layout
- See `docs/features/FLOATING_AI_ASSISTANT.md` for complete implementation details

## Working with Apple Intelligence

### Foundation Models Integration

**IMPORTANT:** The current `FMClient.swift` implementation is based on official Apple documentation from WWDC 2025. See `docs/api/Foundation_Models_API_Reference.md` for complete API documentation including:
- `SystemLanguageModel` and availability checking
- `LanguageModelSession` with trailing closure syntax
- `@Generable` macro for structured output
- Error handling patterns (`guardrailViolation`, `refusal`)
- `GenerationOptions` with temperature control
- Streaming responses and custom tools

When updating `FMClient.swift` for the real iOS 26 SDK:

1. Change session initialization to use trailing closure: `LanguageModelSession { "instructions" }`
2. Add `@Generable` structs for structured output (tags, summaries, etc.)
3. Add `.refusal` error case in catch blocks
4. Consider adding `prewarm()` for improved first-response latency
5. Test thoroughly on iPhone 15 Pro+ with Apple Intelligence enabled

**Current Status**: The implementation is ~90% accurate based on WWDC docs, with minor syntax differences that need updating when the SDK ships.

### Capability Detection

Always check availability before using AI features:

```swift
let client = FMClient()
let state = client.capability()

switch state {
case .available:
    // Safe to use AI features
case .notEnabled:
    // Prompt user to enable Apple Intelligence in Settings
case .notSupported:
    // Device doesn't support (< iPhone 15 Pro)
case .modelNotReady:
    // Model is downloading, show loading UI
case .unknown:
    // Unknown state, use fallback
}
```

### Fallback Behavior

All AI functions have local fallbacks that work without Apple Intelligence:
- `summarize()`: Extracts first 2 sentences
- `tags()`: Frequency-based keyword extraction
- `reflection()`: Pattern-based encouraging messages
- `generateEncouragement()`: Accuracy-based pre-written responses

This ensures the app is **fully functional on all iOS 26+ devices**, even those without Neural Engine.

## Common Development Workflows

### Adding a New Content Source

1. Add enum case to `ContentSource` in `Data/CoreModels.swift` or `SourceKind` in `Data/SourceModels.swift`
2. Create a processor in `Processors/Input/` or relevant subdirectory (e.g., `WebArticleProcessor.swift`)
3. Add source icon/label in `StudyContent.sourceIcon` and `StudyContent.sourceLabel`
4. Create a UI view in `Features/Content/` or relevant subdirectory for the import flow
5. Wire up to `MainTabView` if needed

### Adding a New AI Feature

1. Add method to `Intelligence/Core/FMClient.swift` with proper capability checking
2. Implement placeholder logic in `#else` block for fallback
3. Add corresponding UI in appropriate `Features/` subdirectory
4. Write unit tests in `CardGenieTests/Unit/Intelligence/FMClientTests.swift`

### Modifying Flashcard Types

1. Add enum case to `FlashcardType` in `Data/FlashcardModels.swift`
2. Update `Processors/CardGeneration/FlashcardGenerator.swift` generation logic
3. Update UI rendering in `Features/Flashcards/FlashcardStudyView.swift` or related views
4. Add mastery level logic if needed in `Flashcard.masteryLevel`

### Adding Spaced Repetition Features

- Core SR logic lives in `Data/SpacedRepetitionManager.swift`
- Review scheduling uses SM-2: modify `scheduleNext()` for algorithm changes
- Statistics are computed in `FlashcardSet.updatePerformanceMetrics()`
- Study session state managed in `Intelligence/Managers/EnhancedSessionManager.swift`

## File Organization

### Data/ - Core data models and persistence
- `CoreModels.swift`: Primary content model (`StudyContent`, `ContentSource`)
- `FlashcardModels.swift`: Flashcard and deck models with SR properties
- `SourceModels.swift`: Multi-source support (`SourceDocument`, `NoteChunk`)
- `FeatureModels.swift`: Feature-specific models
- `FlashcardGenerationModels.swift`: @Generable models for AI flashcard generation
- `Store.swift`: Simple CRUD wrapper over ModelContext
- `SpacedRepetitionManager.swift`: SM-2 algorithm implementation
- `StudyStreakManager.swift`: Track study streaks and consistency
- `FlashcardExporter.swift`: Export to CSV, PDF, Anki
- `CacheManager.swift`: Image/asset caching
- `VectorStore.swift`: Embeddings for RAG (experimental)

### Intelligence/ - AI and ML features (organized into subdirectories)

**Core/** - Core AI engines and clients
- `FMClient.swift`: Foundation Models API wrapper (primary AI client)
- `AIEngine.swift`: Generic LLM engine interface
- `AISafety.swift`: Safety and content filtering
- `AITools.swift`: Tool calling for structured generation
- `FlashcardFM.swift`: Flashcard-specific AI generation using Apple Intelligence

**Extractors/** - Text, vision, and audio extraction
- `VisionTextExtractor.swift`: OCR using Vision framework
- `SpeechToTextConverter.swift`: Voice transcription
- `ImagePreprocessor.swift`: Image enhancement before OCR

**Managers/** - Session and state management
- `EnhancedSessionManager.swift`: Manages study sessions and state
- `NotificationManager.swift`: Study reminders and notifications
- `ScanQueue.swift`: Queue for processing scanned documents
- `ScanAnalytics.swift`: Track scanning performance and usage

**Generators/** - Content generation beyond flashcards
- `QuizBuilder.swift`: Generate practice quizzes
- `StudyPlanGenerator.swift`: Create personalized study schedules
- `AutoCategorizer.swift`: Auto-categorize content by topic

**Root Level:**
- `WritingTextEditor.swift`: UIKit bridge for Writing Tools integration
- `Prompts/`: Markdown prompt templates for AI interactions

### Processors/ - Content processing pipeline (organized into subdirectories)

**Input/** - Source material processors
- `PDFProcessor.swift`: PDF parsing and text extraction
- `ImageProcessor.swift`: Photo analysis and OCR
- `HandwritingProcessor.swift`: Handwriting OCR
- `VideoProcessor.swift`: Video transcript extraction

**CardGeneration/** - Flashcard creation
- `FlashcardGenerator.swift`: AI-powered flashcard creation from NoteChunks
- `HighlightExtractor.swift`: Extract highlights from documents
- `HighlightCardBuilder.swift`: Convert highlights to flashcards

**Lecture/** - Lecture recording and transcription
- `LectureRecorder.swift`: Live lecture recording + real-time transcription
- `OnDeviceTranscriber.swift`: Local speech-to-text for lectures

**Advanced/** - Advanced processing features
- `MathSolver.swift`: Solve math problems in notes
- `ConceptMapGenerator.swift`: Generate concept maps from content
- `VoiceTutor.swift`: Interactive voice tutoring

**Utilities/** - Helper processors
- `CSVImporter.swift`: Import flashcards from CSV
- `SmartScheduler.swift`: Intelligent scheduling algorithms

### Features/ - UI views and screens (organized by feature area)

**Content/** - Content management
- `ContentListView.swift`: Main study materials list
- `ContentDetailView.swift`: Edit/view study content

**Flashcards/** - Flashcard study interface
- `FlashcardListView.swift`: Browse flashcard decks
- `FlashcardStudyView.swift`: Active study session UI
- `FlashcardEditorView.swift`: Create/edit flashcards manually
- `FlashcardStatisticsView.swift`: Detailed flashcard performance stats
- `HandwritingEditorView.swift`: Draw and annotate flashcards
- `SessionBuilderView.swift`: Configure custom study sessions
- `StudyResultsView.swift`: Review session results

**Scanning/** - Document and photo scanning
- `PhotoScanView.swift`: Camera interface for scanning notes
- `ScanReviewView.swift`: Review and edit scanned content
- `DocumentScannerView.swift`: Document scanning interface

**Voice/** - Voice features
- `VoiceAssistantView.swift`: Voice Q&A interface
- `VoiceRecordView.swift`: Record lectures/notes
- `LectureCollaborationController.swift`: Collaborative lecture features
- `LiveHighlightActivityManager.swift`: Live Activities for lecture recording
- `LiveLectureContext.swift`: Context management for live lectures

**Analytics/** - Study analytics
- `StatisticsView.swift`: Study analytics and progress tracking

**Settings/** - App configuration
- `SettingsView.swift`: App settings and preferences

**Advanced/** - Experimental features
- `ConceptMapView.swift`: Concept map visualization
- `StudyPlanView.swift`: Study plan interface

**Root Level:**
- `AIAvailabilityViews.swift`: Apple Intelligence availability status views

### Design/ - UI design system
- `Theme.swift`: Liquid Glass materials, colors, spacing, and view modifiers
- `MagicEffects.swift`: Particle effects and animations
- **Components/** - Reusable UI components (organized by type)
  - `Buttons.swift`: Button components (GlassButton, etc.)
  - `Cards.swift`: Card components (AISummaryCard, FlashcardCardView, etc.)
  - `TextComponents.swift`: Text elements (Badge, TagChip, EmptyStateView, etc.)
  - `Containers.swift`: Container views (LoadingView, SessionSummaryView)
  - `Modifiers.swift`: View modifiers (ErrorAlert, etc.)
  - `StudyControls.swift`: Study-specific controls (ReviewButton, StudyProgressBar)
  - `GlassSearchBar.swift`: Native Liquid Glass search bar
  - `TagFlowLayout.swift`: Tag cloud layout

### App/ - App entry point
- `CardGenieApp.swift`: Main app struct with ModelContainer configuration

## Testing Strategy

### Unit Tests (CardGenieTests/)

**Unit/Data/** - Data layer tests
- `CoreLogicTests.swift`: Business logic tests
- `StoreTests.swift`: Data persistence tests
- `SpacedRepetitionTests.swift`: SR algorithm correctness

**Unit/Intelligence/** - AI functionality tests
- `FMClientTests.swift`: AI client functionality
- `EnhancedAITests.swift`: Enhanced AI features
- `FlashcardGenerationTests.swift`: Card generation quality

**Unit/Processors/** - Processing pipeline tests
- `PhotoScanningTests.swift`: OCR accuracy

**Integration/** - Integration tests
- `NotificationTests.swift`: Study reminders and notification integration

### UI Tests (CardGenieUITests/)
- `CardGenieUITests.swift`: Core UI flows
- `CardGenieUITestsLaunchTests.swift`: Launch performance tests
- `PhotoScanningUITests.swift`: Camera and scanning flow

## Important Notes for AI Development

1. **Apple Intelligence is iOS 26+ only**: All AI features must have fallbacks for older devices and when Apple Intelligence is disabled.

2. **Placeholder APIs**: The Foundation Models API is not yet released. Current implementations in `FMClient.swift` are based on WWDC documentation and must be replaced with real APIs when available.

3. **Privacy First**: Never add network calls, analytics, or cloud features. All processing must remain 100% on-device.

4. **Accessibility**: All Liquid Glass effects must have solid fallbacks for Reduce Transparency. Test with accessibility settings enabled.

5. **SwiftData Relationships**: Use `@Relationship(deleteRule: .cascade)` for parent-child relationships to ensure proper cleanup.

6. **ModelContext Operations**: SwiftData operations should be wrapped in try-catch and handle failures gracefully with fallback to in-memory storage if needed.

7. **Background AI Processing**: Long-running AI operations should use `Task { }` with proper cancellation support.

## References

- Apple Intelligence: https://developer.apple.com/documentation/FoundationModels/
- SwiftData: https://developer.apple.com/documentation/swiftdata
- Liquid Glass Design: https://developer.apple.com/design/human-interface-guidelines/liquid-glass
- Writing Tools: https://developer.apple.com/documentation/uikit/uitextview/writing-tools
- Vision OCR: https://developer.apple.com/documentation/vision
