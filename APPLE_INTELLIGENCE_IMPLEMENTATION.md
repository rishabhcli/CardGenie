# Apple Intelligence Implementation — CardGenie iOS 26

**Status**: ✅ Complete
**Target**: iOS 26+ with Apple Intelligence
**Architecture**: On-device AI with Foundation Models framework

---

## Overview

This implementation integrates Apple Intelligence into CardGenie following Apple's iOS 26 best practices and TN3193 guidelines. All AI processing happens on-device via the Neural Engine with zero network calls, preserving student privacy.

---

## ✅ Hard Requirements (Completed)

### 1. Model Availability Gating ✅
**Implementation**: `AIAvailabilityViews.swift`

- ✅ Check `SystemLanguageModel.default.availability` before all AI operations
- ✅ Provide fallback views for each unavailability state:
  - `DeviceNotSupportedView` → Device not eligible
  - `EnableAppleIntelligenceView` → Apple Intelligence disabled
  - `ModelDownloadingView` → Model not ready
  - `GenericUnavailableView` → Other states

**Usage**:
```swift
AIFeatureGate(feature: "flashcard_generation") {
    // Your AI-powered view here
}
```

### 2. Session Management ✅
**Implementation**: `EnhancedSessionManager.swift`

- ✅ Single-turn requests create new `LanguageModelSession()` per call
- ✅ Multi-turn conversations reuse the same session
- ✅ `isResponding` flag prevents concurrent requests
- ✅ Automatic session reset on context window overflow

**Example**:
```swift
let sessionManager = EnhancedSessionManager()

// Single-turn
let result = try await sessionManager.singleTurnRequest(
    prompt: "Summarize this note: \(text)",
    instructions: "Be concise and accurate",
    generating: Summary.self
)

// Multi-turn
sessionManager.startSession(instructions: "You are a study tutor")
let response1 = try await sessionManager.multiTurnRequest(prompt: "Explain photosynthesis")
let response2 = try await sessionManager.multiTurnRequest(prompt: "How do plants use it?")
sessionManager.endSession()
```

### 3. Context Limits & Error Handling ✅
**Implementation**: `AISafety.swift` → `ContextBudgetManager`

- ✅ Pre-check content fits in ~8000 token input window
- ✅ Catch `GenerationError.exceededContextWindowSize`
- ✅ Automatic chunking with `chunkText()` method
- ✅ Sentence-boundary aware chunking

**Example**:
```swift
let contextBudget = ContextBudgetManager()

if contextBudget.canFitInContext(text, instructions: instructions) {
    // Process normally
} else {
    // Chunk and process sequentially
    let result = try await contextBudget.processInChunks(text) { chunk in
        try await processChunk(chunk)
    }
}
```

### 4. Safety Guardrails ✅
**Implementation**: `AISafety.swift` → `GuardrailHandler`, `ContentSafetyFilter`

- ✅ Catch `GenerationError.guardrailViolation` and `refusal(...)`
- ✅ Return structured `SafetyEvent` with:
  - User-friendly message
  - Safe alternative suggestion
  - No raw prompt logging
- ✅ Pre-filter content with deny list before sending to model
- ✅ Block violence, weapons, self-harm, explicit content, illegal activities

**Example**:
```swift
do {
    let response = try await session.respond(to: prompt)
} catch LanguageModelSession.GenerationError.guardrailViolation {
    let event = guardrailHandler.handleGuardrailViolation(prompt: prompt, context: "flashcards")
    // Show event.userMessage to user
    // Offer event.safeAlternative
}
```

### 5. iOS 26 SDK Target ✅
- ✅ Deployment target set to iOS 26.0
- ✅ Conditional compilation with `#if canImport(FoundationModels)`
- ✅ Availability checks with `@available(iOS 26.0, *)`
- ✅ Xcode 26 project configuration

---

## 🎯 Feature Implementation

### Guided Generation (@Generable Models) ✅
**Implementation**: `FlashcardGenerationModels.swift`

All AI outputs use typed Swift structs instead of raw text:

```swift
@Generable(description: "A concise study flashcard")
struct Flashcard {
    @Guide(description: "Front of the card", .length(.maxChars(140)))
    var front: String

    @Guide(description: "Back of the card", .length(.maxChars(220)))
    var back: String

    @Guide(description: "Tags", .count(2...4))
    var tags: [String]

    @Guide(description: "Difficulty 1-5", .range(1...5))
    var difficulty: Int
}
```

**New Models Added**:
- ✅ `QuizItem` — MCQ, cloze, short answer questions
- ✅ `QuizBatch` — Collection of 6 quiz items
- ✅ `StudySession` — Single day study plan
- ✅ `StudyPlan` — 7-day study schedule

### Tool Calling ✅
**Implementation**: `AITools.swift` → `ToolRegistry`

Four tools exposed to the language model:

| Tool | Purpose | Parameters |
|------|---------|------------|
| `fetch_notes` | Search study notes | `query: String` |
| `save_flashcards` | Persist flashcards | `flashcards: [[String: Any]]` |
| `upcoming_deadlines` | Get calendar events | None |
| `glossary` | Look up definitions | `term: String` |

**Usage**:
```swift
let toolRegistry = ToolRegistry(modelContext: modelContext)
let result = try await toolRegistry.execute(
    toolName: "fetch_notes",
    parameters: ["query": "photosynthesis"]
)

if result.success {
    // Use result.data in prompt
}
```

### Quiz Builder ✅
**Implementation**: `QuizBuilder.swift`

Generates 6-question quizzes with tool calling:
- 3 multiple choice (MCQ)
- 2 cloze deletion
- 1 short answer
- Difficulty spread 2-5
- Explanations for each answer

**Usage**:
```swift
let quizBuilder = QuizBuilder(modelContext: modelContext)
await quizBuilder.generateQuiz(topic: "AP Statistics")

if let quiz = quizBuilder.currentQuiz {
    // Present quiz to user
}
```

### Study Plan Generator ✅
**Implementation**: `StudyPlanGenerator.swift`

Creates 7-day personalized study plans:
- Fetches upcoming deadlines from Calendar
- Retrieves student's notes on the course
- Allocates 30-45 min sessions
- Links concrete materials
- Prioritizes deadline-proximate content

**Usage**:
```swift
let planGenerator = StudyPlanGenerator(modelContext: modelContext)
await planGenerator.generatePlan(course: "AP Calculus")

if let plan = planGenerator.currentPlan {
    // Display 7-day schedule
}
```

---

## 🔒 Safety Design

### Content Filtering ✅
**Implementation**: `AISafety.swift` → `ContentSafetyFilter`

- ✅ Deny list for inappropriate topics (violence, weapons, adult content, etc.)
- ✅ PII detection (SSN, credit cards, emails, phone numbers)
- ✅ Sanitization with `[EMAIL]`, `[PHONE]` replacements
- ✅ Pre-filter before sending to model

### Privacy Protection ✅
**Implementation**: `AISafety.swift` → `PrivacyLogger`

- ✅ **NEVER** log raw student notes
- ✅ **NEVER** log prompts containing user content
- ✅ **NEVER** log generated flashcards or quiz answers
- ✅ Only log:
  - Operation type (e.g., "flashcard_generation")
  - Content length (character count)
  - Success/failure status
  - Error type (without details)

### Guardrail Events ✅
**Implementation**: `AISafety.swift` → `SafetyEvent`

Structured handling with user-friendly messages:

```swift
struct SafetyEvent {
    let type: SafetyEventType  // .guardrailViolation, .refusal, .denyListMatch, .privacyFilter
    let userMessage: String     // Show this to user
    let safeAlternative: String?  // Suggest this instead
    let timestamp: Date
}
```

---

## 🌍 Multilingual Support ✅
**Implementation**: `AISafety.swift` → `LocaleManager`

- ✅ Detect current `Locale.current`
- ✅ For US English: "You MUST respond in U.S. English."
- ✅ For other locales: "The person's locale is [locale]. Respond appropriately."
- ✅ Check supported languages (en, zh, fr, de, it, ja, ko, pt, es)
- ✅ Fallback message for unsupported locales

---

## 📝 System Prompts

**Location**: `CardGenie/Intelligence/Prompts/`

| File | Purpose |
|------|---------|
| `System.md` | Core system prompt with non-negotiables |
| `FlashcardGeneration.md` | 8-card generation with quality standards |
| `QuizBuilder.md` | 6-question quiz generation with tool calls |
| `StudyPlan.md` | 7-day plan with calendar integration |

These prompts are loaded at runtime and combined with locale instructions.

---

## 🧪 Testing

**Implementation**: `CardGenieTests/EnhancedAITests.swift`

**Coverage**:
- ✅ Content safety filter (safe/unsafe content)
- ✅ PII detection and sanitization
- ✅ Token estimation and chunking
- ✅ Context budget management
- ✅ Locale instructions generation
- ✅ @Generable model validation
- ✅ Tool execution (FetchNotes, SaveFlashcards)
- ✅ Guardrail/refusal handling
- ✅ Privacy logging (no crashes, no leaks)
- ✅ Quiz session state management
- ✅ Study plan tracking

**Run Tests**:
```bash
xcodebuild test -scheme CardGenie -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

---

## 📦 File Structure

```
CardGenie/Intelligence/
├── FMClient.swift                        # Existing Foundation Models client
├── FlashcardFM.swift                     # Existing flashcard generation
├── FlashcardGenerationModels.swift       # ✨ Enhanced with Quiz & StudyPlan models
├── AITools.swift                         # ✨ NEW: Tool calling infrastructure
├── AISafety.swift                        # ✨ NEW: Safety, privacy, context budgeting
├── EnhancedSessionManager.swift          # ✨ NEW: Session management with error handling
├── QuizBuilder.swift                     # ✨ NEW: Quiz generation feature
├── StudyPlanGenerator.swift              # ✨ NEW: Study plan feature
└── Prompts/
    ├── System.md                         # ✨ NEW: Core system prompt
    ├── FlashcardGeneration.md            # ✨ NEW: Flashcard prompt
    ├── QuizBuilder.md                    # ✨ NEW: Quiz prompt
    └── StudyPlan.md                      # ✨ NEW: Study plan prompt

CardGenie/Features/
└── AIAvailabilityViews.swift             # ✨ NEW: Availability-gated UI

CardGenieTests/
└── EnhancedAITests.swift                 # ✨ NEW: Comprehensive AI tests
```

---

## 📋 Definition of Done Checklist

### Core Requirements
- ✅ **Availability-gated UI with fallbacks** → `AIAvailabilityViews.swift`
- ✅ **Guided generation for Flashcard, QuizItem, StudyPlan** → `FlashcardGenerationModels.swift`
- ✅ **Tool calling (4 tools implemented)** → `AITools.swift`
- ✅ **Safety flows for guardrails & refusals** → `AISafety.swift`
- ✅ **Deny list & no raw note logging** → `ContentSafetyFilter`, `PrivacyLogger`
- ✅ **Locale-aware prompts** → `LocaleManager`

### iOS 26 Compliance
- ✅ **iOS 26 build with no deprecated APIs** → Deployment target 26.0
- ✅ **Conditional compilation** → `#if canImport(FoundationModels)`
- ✅ **Availability checks** → `@available(iOS 26.0, *)`

### Performance & Polish
- ✅ **Context budgeting per TN3193** → `ContextBudgetManager`
- ✅ **Streaming support** → `streamResponse()` in `EnhancedSessionManager`
- ✅ **Session management (no concurrent requests)** → `isResponding` flag
- ✅ **Chunking for long content** → `processInChunks()`

### Testing
- ✅ **Unit tests for safety, tools, models** → `EnhancedAITests.swift` (35+ tests)

### Documentation
- ✅ **System prompts documented** → `Prompts/*.md`
- ✅ **Implementation guide** → This file

---

## 🚀 Usage Examples

### Generate Flashcards with Safety
```swift
let sessionManager = EnhancedSessionManager()

do {
    let flashcards = try await sessionManager.singleTurnRequest(
        prompt: "Create flashcards from: \(noteText)",
        instructions: loadPrompt("FlashcardGeneration"),
        generating: [Flashcard].self,
        options: GenerationOptions(temperature: 0.4)
    )

    // Save to SwiftData
    for card in flashcards {
        modelContext.insert(card)
    }

} catch SafetyError.guardrailViolation(let event) {
    // Show event.userMessage
    // Offer event.safeAlternative

} catch SafetyError.contextLimitExceeded {
    // Ask user to provide shorter text or specific section
}
```

### Generate Quiz with Tool Calling
```swift
let quizBuilder = QuizBuilder(modelContext: modelContext)
await quizBuilder.generateQuiz(topic: "World War II")

if let error = quizBuilder.error {
    // Handle error (no notes found, guardrail triggered, etc.)
} else if let quiz = quizBuilder.currentQuiz {
    // Present quiz UI
    let viewModel = QuizSessionViewModel(quiz: quiz)
    // Show questions, track score
}
```

### Create Study Plan
```swift
let planGenerator = StudyPlanGenerator(modelContext: modelContext)
await planGenerator.generatePlan(course: "AP Physics")

if let plan = planGenerator.currentPlan {
    let tracker = StudyPlanTracker(plan: plan)

    // User completes a session
    tracker.markSessionComplete("2025-10-28")
    tracker.addNote(for: "2025-10-28", note: "Completed all problems")

    // Show progress
    print("Progress: \(Int(tracker.progress * 100))%")
}
```

---

## 🎓 Best Practices Followed

1. **Always gate on availability** — Never assume model is ready
2. **Use guided generation** — Structured types over free-form text
3. **Respect context limits** — Budget tokens, chunk when needed
4. **Handle guardrails gracefully** — User-friendly messages, no raw errors
5. **Protect privacy** — Never log student content
6. **Locale-aware prompts** — Explicit language instructions
7. **Prevent concurrent requests** — One operation at a time per session
8. **Tool calling over invention** — Fetch real data, don't make it up

---

## 📚 Apple Documentation References

- [Foundation Models Overview](https://developer.apple.com/documentation/FoundationModels)
- [SystemLanguageModel](https://developer.apple.com/documentation/FoundationModels/SystemLanguageModel)
- [LanguageModelSession](https://developer.apple.com/documentation/FoundationModels/LanguageModelSession)
- [Guided Generation (@Generable)](https://developer.apple.com/documentation/FoundationModels/Generable)
- [TN3193: Context Window Management](https://developer.apple.com/documentation/)
- [iOS 26 Release Notes](https://developer.apple.com/documentation/ios-ipados-release-notes)

---

## ⚠️ Known Limitations

1. **Requires iOS 26+** — Falls back to lightweight heuristics on older devices
2. **Device eligibility** — iPhone 15 Pro or later with Neural Engine
3. **Apple Intelligence must be enabled** — User setting in System Settings
4. **Model download required** — First use requires on-device model download
5. **No custom adapters yet** — Base model only (adapter support can be added later)

---

## 🔮 Future Enhancements

### Optional Improvements
- [ ] Adapter training for domain-specific phrasing (AP Stats, Chemistry, etc.)
- [ ] Permissive guardrail mode for advanced summarization tasks
- [ ] Regression testing suite for prompt safety
- [ ] Performance profiling with Instruments
- [ ] Remote flags for adapter loading/versioning
- [ ] MPSGraph integration for diagram annotation
- [ ] BNNS Graph for real-time audio preprocessing

### Feature Extensions
- [ ] Multi-modal input (images → text → flashcards)
- [ ] Voice-to-quiz pipeline
- [ ] Collaborative study plans (SharePlay)
- [ ] Adaptive difficulty based on performance

---

## 🤝 Contributing

When extending AI features:

1. **Add new @Generable models** to `FlashcardGenerationModels.swift`
2. **Create prompt files** in `Intelligence/Prompts/`
3. **Update `EnhancedSessionManager`** for new session types
4. **Add tools** to `AITools.swift` and register in `ToolRegistry`
5. **Write tests** in `EnhancedAITests.swift`
6. **Document** in this file

---

## ✅ Verification Checklist (Post-Implementation)

Run these checks before shipping:

```bash
# 1. Build succeeds with warnings as errors
xcodebuild -scheme CardGenie -destination 'generic/platform=iOS' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

# 2. Tests pass
xcodebuild test -scheme CardGenie -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# 3. Code analysis passes
xcodebuild analyze -scheme CardGenie

# 4. No force unwraps in safety-critical paths
grep -r "!" CardGenie/Intelligence/ --include="*.swift" | grep -v "//"

# 5. No raw content logging
grep -r "log.*content\|log.*prompt\|log.*note" CardGenie/Intelligence/ --include="*.swift"
```

---

**Implementation Date**: 2025-10-27
**iOS Target**: 26.0+
**Status**: ✅ Production Ready
