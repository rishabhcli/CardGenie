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

**Search Bar (Design/Components.swift - GlassSearchBar section)**
- Uses iOS 26 `.glassEffect(.regular.interactive(), in: .capsule)` for native Liquid Glass
- Interactive mode provides shimmer effect on user input
- Capsule shape is optimal for search bars (vs. rect)
 - See `docs/archive/reference/ui/iOS26_Liquid_Glass_Search_Bar.md` for implementation details and best practices

**Floating AI Assistant (App/CardGenieApp.swift)**
- iOS 26+ uses `.tabViewBottomAccessory` for bottom-right floating button
- Consolidates "Ask" and "Record" voice features into single menu-driven button
- Reduces tab count from 5 → 3 (Study, Flashcards, Scan)
- Native Liquid Glass effect (automatic)
- Menu shows "Ask Question" and "Record Lecture" options
- Opens VoiceAssistantView or VoiceRecordView in sheet presentation
- iOS 25 fallback maintains legacy 5-tab layout
 - See `docs/archive/reference/features/FLOATING_AI_ASSISTANT.md` for complete implementation details

## Working with Apple Intelligence

### Foundation Models Integration

 **IMPORTANT:** The current `FMClient.swift` implementation is based on official Apple documentation from WWDC 2025. See `docs/archive/reference/api/Foundation_Models_API_Reference.md` for complete API documentation including:
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

## Conversational Voice Assistant

### Overview

CardGenie includes a **fully offline, streaming conversational voice assistant** that transforms the app into an interactive AI tutor. The assistant leverages iOS 26's Foundation Models streaming API, Speech framework, and AVFoundation for a natural, real-time conversational experience.

**Key Features:**
- **Streaming AI responses**: Text appears word-by-word, no loading spinners
- **Incremental text-to-speech**: AI speaks sentences as they're generated
- **Multi-turn conversations**: Maintains context across the entire session
- **Natural interruptions**: Stop AI mid-response with interrupt button
- **Context awareness**: Integrates with study content and flashcard sets
- **100% offline**: All speech recognition, AI, and TTS happen on-device

### Architecture

**Core Components:**

1. **VoiceAssistant** (`Features/VoiceViews.swift:375-850`)
   - Enhanced with Foundation Models streaming support
   - Manages conversation state, speech recognition, and TTS
   - Implements interruption handling
   - Supports conversation context injection

2. **ConversationModels** (`Data/ConversationModels.swift`)
   - `ConversationSession`: SwiftData model for persistent chat history
   - `ConversationMessage`: Individual messages with role (user/assistant/system)
   - `ConversationContext`: Runtime context with study content/flashcard references

3. **VoiceAssistantView** (`Features/VoiceViews.swift:23-405`)
   - Real-time streaming response display
   - Interrupt button (appears when AI is speaking)
   - Context-aware initialization

### Key Implementation Details

**Streaming AI Responses** (`VoiceViews.swift:590-680`)

```swift
private func streamAIResponse(to question: String) async {
    let session = LanguageModelSession {
        context.systemPrompt() // Context-aware system prompt
    }

    let stream = session.streamResponse(to: prompt, options: options)

    for try await partial in stream {
        streamingResponse = partial.content // Updates UI immediately

        // Speak new sentences as they arrive
        let newText = extractNewText(from: partial.content, after: lastSpokenText)
        if !newText.isEmpty {
            speakTextIncremental(newText)
            lastSpokenText = partial.content
        }
    }
}
```

**Incremental Text-to-Speech** (`VoiceViews.swift:754-803`)

Sentences are extracted and spoken as they complete during streaming, creating a natural conversational flow without waiting for the full response.

**Interruption Handling** (`VoiceViews.swift:443-462`)

```swift
func interrupt() {
    streamingTask?.cancel() // Cancel AI streaming
    speechSynthesizer.stopSpeaking(at: .immediate) // Stop TTS immediately
    isSpeaking = false
    isProcessing = false
    streamingResponse = ""
}
```

**Context Injection**

The assistant can be launched with context from:
- Scanned content (`ScanningViews.swift:775-783`)
- Flashcard sets (`FlashcardStudyViews.swift:2426-2439`)

Example:
```swift
let context = ConversationContext(
    studyContent: scannedContent,
    flashcardSet: currentSet,
    recentFlashcards: Array(currentSet.cards.prefix(10))
)
VoiceAssistantView(context: context)
```

The context injects study material into the system prompt, allowing the AI to reference specific content during conversations.

### Usage

**Basic Conversation:**
1. Launch VoiceAssistantView
2. Tap mic button to start listening
3. Speak your question
4. AI responds with streaming text and speech
5. Continue the conversation naturally

**Context-Aware Conversations:**

**From Scanned Content:**
1. Scan notes via PhotoScanView
2. Tap "Talk About This" in ScanReviewView
3. AI has full context of scanned material

**From Flashcard Sets:**
1. Open any FlashcardSet detail view
2. Tap "Voice Tutor" feature card
3. AI references your flashcards in responses

**Interruption:**
1. While AI is speaking, tap the orange interrupt button
2. AI stops immediately
3. Start a new question or clarification

### Technical Notes

**Speech Recognition:**
- Uses `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`
- Continuous recognition with partial results
- Automatic silence detection (2 seconds of silence triggers message send)

**Foundation Models Integration:**
- Streaming with `session.streamResponse(to:options:)`
- Temperature: 0.7 for conversational warmth
- Error handling for `guardrailViolation` and `refusal`
- Fallback to local heuristics when AI unavailable

**Text-to-Speech:**
- `AVSpeechSynthesizer` with sentence-by-sentence queuing
- Rate: 0.52 (slightly faster than default for natural flow)
- Incremental speaking during streaming (no wait for full response)

**Conversation History:**
- SwiftData persistence via ConversationSession
- Last 5 messages included in context window (token optimization)
- Registered in ModelContainer (`CardGenieApp.swift:24-25`)

### Testing

**Manual Testing Checklist:**
- [ ] Start conversation and ask question via voice
- [ ] Verify streaming response updates in real-time
- [ ] Verify TTS starts before full response completes
- [ ] Test interruption mid-response
- [ ] Ask follow-up question, verify context is maintained
- [ ] Launch from scan review with content context
- [ ] Launch from flashcard set, verify AI references cards
- [ ] Test in Airplane Mode (must work 100% offline)

**Unit Tests:**
See `CardGenieTests/Unit/Intelligence/VoiceAssistantEngineTests.swift` (TODO: create)

**Performance Targets:**
- First response: < 2 seconds
- Streaming latency: < 500ms per token
- TTS start: < 1 second from first sentence
- Memory usage: < 100MB

### Future Enhancements

- Conversation export (share transcripts as study notes)
- Multi-language support (when Apple Intelligence expands)
- Voice profile customization (select different AI voices)
- Conversation templates (Socratic method, Feynman technique)

## Common Development Workflows

### Adding a New Content Source

1. Add enum case to `ContentSource` in `Data/Models.swift`
2. Create a processor in `Processors/InputProcessors.swift` (add new MARK section for your processor)
3. Add source icon/label in `StudyContent.sourceIcon` and `StudyContent.sourceLabel`
4. Add UI view to `Features/ContentViews.swift` or create new feature file if it's a major feature
5. Wire up to `MainTabView` if needed

### Adding a New AI Feature

1. Add method to `Intelligence/AICore.swift` in the FMClient section with proper capability checking
2. Implement placeholder logic in `#else` block for fallback
3. Add corresponding UI in appropriate Features file
4. Write unit tests in `CardGenieTests/Unit/Intelligence/`

### Modifying Flashcard Types

1. Add enum case to `FlashcardType` in `Data/FlashcardModels.swift`
2. Update `Processors/FlashcardProcessors.swift` generation logic (FlashcardGenerator section)
3. Update UI rendering in `Features/FlashcardStudyViews.swift` or `Features/FlashcardEditorViews.swift`
4. Add mastery level logic if needed in `Flashcard.masteryLevel`

### Adding Spaced Repetition Features

- Core SR logic lives in `Data/SpacedRepetitionManager.swift`
- Review scheduling uses SM-2: modify `scheduleNext()` for algorithm changes
- Statistics are computed in `FlashcardSet.updatePerformanceMetrics()`
- Study session state managed in `Intelligence/SessionManagers.swift` (EnhancedSessionManager section)

## File Organization

### Data/ - Core data models and persistence (9 files)
- `Models.swift`: All core data models (StudyContent, ContentSource, SourceDocument, NoteChunk, feature models)
- `FlashcardModels.swift`: Flashcard and deck models with SR properties
- `FlashcardGenerationModels.swift`: @Generable models for AI flashcard generation
- `SpacedRepetitionManager.swift`: SM-2 algorithm implementation
- `StudyStreakManager.swift`: Track study streaks and consistency
- `Store.swift`: Simple CRUD wrapper over ModelContext
- `FlashcardExporter.swift`: Export to CSV, PDF, Anki
- `CacheManager.swift`: Image/asset caching
- `VectorStore.swift`: Embeddings for RAG (experimental)

### Intelligence/ - AI and ML features (5 files)
- `AICore.swift`: Core AI infrastructure (FMClient, AIEngine, AISafety, AITools, FlashcardFM)
- `ContentExtractors.swift`: Text, vision, and audio extraction (VisionTextExtractor, SpeechToTextConverter, ImagePreprocessor)
- `SessionManagers.swift`: Session and state management (EnhancedSessionManager, NotificationManager, ScanQueue, ScanAnalytics)
- `ContentGenerators.swift`: Content generation (QuizBuilder, StudyPlanGenerator, AutoCategorizer)
- `WritingTextEditor.swift`: UIKit bridge for Writing Tools integration
- `Prompts/`: Markdown prompt templates for AI interactions (directory)

### Processors/ - Content processing pipeline (5 files)
- `InputProcessors.swift`: Source material processing (PDFProcessor, ImageProcessor, HandwritingProcessor, VideoProcessor)
- `FlashcardProcessors.swift`: Flashcard creation (FlashcardGenerator, HighlightExtractor, HighlightCardBuilder)
- `LectureProcessors.swift`: Lecture recording and transcription (LectureRecorder, OnDeviceTranscriber)
- `AdvancedProcessors.swift`: Advanced features (MathSolver, ConceptMapGenerator, VoiceTutor)
- `ProcessorUtilities.swift`: Helper processors (CSVImporter, SmartScheduler)

### Features/ - UI views and screens (8 files)
- `ContentViews.swift`: Content management and AI availability (ContentListView, ContentDetailView, AIAvailabilityViews)
- `FlashcardStudyViews.swift`: Study sessions (FlashcardListView, FlashcardStudyView, SessionBuilderView, StudyResultsView)
- `FlashcardEditorViews.swift`: Flashcard editing (FlashcardEditorView, FlashcardStatisticsView, HandwritingEditorView)
- `ScanningViews.swift`: Document scanning (PhotoScanView, ScanReviewView, DocumentScannerView)
- `VoiceViews.swift`: Voice features (VoiceAssistantView, VoiceRecordView, LectureCollaborationController, LiveHighlightActivityManager, LiveLectureContext)
- `StatisticsView.swift`: Study analytics and progress tracking
- `SettingsView.swift`: App settings and preferences
- `AdvancedViews.swift`: Experimental features (ConceptMapView, StudyPlanView)

### Design/ - UI design system (3 files)
- `Theme.swift`: Liquid Glass materials, colors, spacing, and view modifiers
- `MagicEffects.swift`: Particle effects and animations
- `Components.swift`: Reusable UI components (Buttons, Cards, Text Components, Containers, Modifiers, Study Controls, GlassSearchBar, TagFlowLayout)

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
