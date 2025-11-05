# Voice-Enabled AI Chat Implementation Plan

## Overview

This document outlines the implementation plan for integrating full offline voice assistant capabilities into the existing **AI Chat** tab, following the architecture described in the iOS 26 documentation.

## Architecture

### Complete Offline Voice Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Interface                          │
│  - Microphone button (tap/hold modes)                          │
│  - Real-time transcript preview                                │
│  - Visual status indicators (Listening/Speaking/Thinking)      │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────────────┐
│                   Speech-to-Text (STT)                          │
│  Framework: Speech.framework                                    │
│  • SFSpeechRecognizer with requiresOnDeviceRecognition = true │
│  • Real-time partial results streaming                         │
│  • Automatic sentence completion detection                      │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────────────┐
│              Natural Language Understanding (NLU)               │
│  Framework: FoundationModels (iOS 26+)                         │
│  • SystemLanguageModel.default                                 │
│  • LanguageModelSession with conversation context             │
│  • Streaming response generation                               │
│  • Tool calling (future: deck creation, card search)           │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────────────┐
│                   Text-to-Speech (TTS)                          │
│  Framework: AVFoundation                                        │
│  • AVSpeechSynthesizer for offline synthesis                   │
│  • Sentence-by-sentence streaming                              │
│  • Interruption handling (stop when user talks)                │
└─────────────────────────────────────────────────────────────────┘
```

### Key Features

#### 1. **100% Offline Operation**
- All processing stays on-device (Neural Engine + CPU)
- No network calls, even for fallbacks
- Works in airplane mode
- Privacy-preserving (no data leaves device)

#### 2. **Multi-Modal Input**
- **Text input**: Type messages (existing functionality)
- **Voice input (tap-to-toggle)**: Tap mic to start, tap again to stop
- **Voice input (hold-to-talk)**: Hold mic while speaking, release to send

#### 3. **Conversational AI**
- Multi-turn conversations with context
- Different modes: General Q&A, Study Help, Flashcard Quiz, Explain Concept
- Streaming responses (text appears word-by-word)
- Optional TTS for AI responses

#### 4. **Rich Visual Feedback**
- Status indicator: "Listening..." / "Thinking..." / "Speaking..."
- Real-time transcript preview while listening
- Speaking animation on AI message bubbles
- Waveform animation on microphone button

## Implementation Phases

### Phase 1: Add TTS Support to AIChatEngine

**File**: `CardGenie/Features/VoiceViews.swift` (AIChatEngine class, line 2227)

**Changes**:
1. Add AVSpeechSynthesizer property and delegate conformance:
```swift
@MainActor
class AIChatEngine: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false
    @Published var autoSpeakEnabled = true

    private let speechSynthesizer = AVSpeechSynthesizer()
    // ... existing properties

    override init() {
        super.init()
        speechSynthesizer.delegate = self
        // ... existing init
    }
}
```

2. Add speak method:
```swift
func speak(_ text: String) async {
    guard !text.isEmpty else { return }

    let utterance = AVSpeechUtterance(string: text)

    // Use high-quality on-device voice
    if let voice = AVSpeechSynthesisVoice(language: "en-US") {
        utterance.voice = voice
    }

    utterance.rate = 0.52 // Slightly faster for natural flow
    utterance.pitchMultiplier = 1.0
    utterance.volume = 1.0

    isSpeaking = true
    speechSynthesizer.speak(utterance)

    // Wait for speech to finish
    while isSpeaking {
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
}

// AVSpeechSynthesizerDelegate methods
nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    Task { @MainActor in
        isSpeaking = false
    }
}

nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    Task { @MainActor in
        isSpeaking = false
    }
}
```

3. Modify `sendMessage` to optionally speak responses:
```swift
func sendMessage(_ text: String) async -> Bool {
    // ... existing code to generate response

    // After response is generated:
    if autoSpeakEnabled && !fullResponse.isEmpty {
        await speak(fullResponse)
    }

    return true
}
```

### Phase 2: Enhance Speech Recognition

**File**: `CardGenie/Features/VoiceViews.swift` (AIChatEngine class)

**Changes**:
1. Add real-time transcript state:
```swift
@Published var currentTranscript = ""
@Published var voiceInputMode: VoiceInputMode = .tapToToggle

enum VoiceInputMode {
    case tapToToggle  // Tap to start, tap to stop
    case holdToTalk   // Hold to record, release to send
}
```

2. Enforce offline-only recognition:
```swift
private func startListening() async {
    // ... existing permission checks

    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard let recognitionRequest else { return }

    recognitionRequest.shouldReportPartialResults = true
    recognitionRequest.requiresOnDeviceRecognition = true // ⚡ CRITICAL: Offline only

    // Verify on-device support
    guard speechRecognizer?.supportsOnDeviceRecognition == true else {
        availabilityMessage = "On-device speech recognition not available"
        return
    }

    // ... rest of implementation
}
```

3. Add real-time transcript updates:
```swift
recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
    guard let self else { return }

    if let result {
        Task { @MainActor in
            // Update real-time transcript preview
            self.currentTranscript = result.bestTranscription.formattedString

            if result.isFinal {
                // Send when complete
                await self.sendMessage(self.currentTranscript)
                self.currentTranscript = ""
                self.stopListening()
            }
        }
    }

    if error != nil {
        self.stopListening()
    }
}
```

4. Add interruption handling:
```swift
func startListening() async {
    // Stop speaking if AI is currently talking
    if isSpeaking {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // ... rest of STT setup
}
```

### Phase 3: Enhance AIChatView UI

**File**: `CardGenie/Features/VoiceViews.swift` (AIChatView, line 1832)

**Changes**:

1. Add status indicator at top:
```swift
var body: some View {
    NavigationStack {
        ZStack {
            // ... existing background

            VStack(spacing: 0) {
                // NEW: Voice status banner
                if chatEngine.isListening || chatEngine.isSpeaking || chatEngine.isGenerating {
                    voiceStatusBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Existing mode selector
                modeSelectorBanner

                // ... rest of UI
            }
        }
    }
}

private var voiceStatusBanner: some View {
    HStack(spacing: 12) {
        // Status icon with animation
        Image(systemName: statusIcon)
            .font(.title3)
            .foregroundStyle(statusColor)
            .symbolEffect(.pulse, isActive: true)

        // Status text
        Text(statusText)
            .font(.subheadline.bold())
            .foregroundStyle(statusColor)

        Spacer()

        // Current transcript preview (while listening)
        if chatEngine.isListening && !chatEngine.currentTranscript.isEmpty {
            Text(chatEngine.currentTranscript)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 200)
        }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(.ultraThinMaterial)
}

private var statusIcon: String {
    if chatEngine.isListening {
        return "waveform"
    } else if chatEngine.isSpeaking {
        return "speaker.wave.3.fill"
    } else if chatEngine.isGenerating {
        return "brain"
    } else {
        return "checkmark.circle.fill"
    }
}

private var statusText: String {
    if chatEngine.isListening {
        return "Listening..."
    } else if chatEngine.isSpeaking {
        return "Speaking..."
    } else if chatEngine.isGenerating {
        return "Thinking..."
    } else {
        return "Ready"
    }
}

private var statusColor: Color {
    if chatEngine.isListening {
        return .blue
    } else if chatEngine.isSpeaking {
        return .green
    } else if chatEngine.isGenerating {
        return .orange
    } else {
        return .cosmicPurple
    }
}
```

2. Update microphone button with better states:
```swift
private var inputBar: some View {
    HStack(spacing: 12) {
        // Enhanced voice button
        Button {
            chatEngine.toggleVoiceInput()
        } label: {
            ZStack {
                // Background circle
                Circle()
                    .fill(micButtonBackground)
                    .frame(width: 44, height: 44)

                // Icon
                Image(systemName: micButtonIcon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(micButtonForeground)
                    .symbolEffect(.pulse, isActive: chatEngine.isListening)
            }
        }
        .buttonStyle(.plain)
        .disabled(chatEngine.isGenerating || chatEngine.isSpeaking)

        // ... rest of input bar
    }
}

private var micButtonBackground: Color {
    if chatEngine.isListening {
        return .red.opacity(0.2)
    } else if chatEngine.isSpeaking {
        return .green.opacity(0.2)
    } else {
        return .clear
    }
}

private var micButtonIcon: String {
    if chatEngine.isListening {
        return "stop.circle.fill"
    } else if chatEngine.isSpeaking {
        return "speaker.wave.2.fill"
    } else {
        return "mic.fill"
    }
}

private var micButtonForeground: Color {
    if chatEngine.isListening {
        return .red
    } else if chatEngine.isSpeaking {
        return .green
    } else {
        return .cosmicPurple
    }
}
```

3. Add speaking animation to AI message bubbles:
```swift
@available(iOS 26.0, *)
struct AIChatMessageBubble: View {
    let message: AIChatMessage
    @EnvironmentObject var chatEngine: AIChatEngine

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // ... existing code

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        // ... existing background
                    )
                    .overlay(
                        // NEW: Speaking indicator
                        Group {
                            if !message.isUser && chatEngine.isSpeaking {
                                HStack(spacing: 3) {
                                    ForEach(0..<3) { index in
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 4, height: 4)
                                            .scaleEffect(chatEngine.isSpeaking ? 1.2 : 0.8)
                                            .animation(
                                                .easeInOut(duration: 0.4)
                                                    .repeatForever()
                                                    .delay(Double(index) * 0.15),
                                                value: chatEngine.isSpeaking
                                            )
                                    }
                                }
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .offset(x: 0, y: -10)
                            }
                        },
                        alignment: .topTrailing
                    )

                // ... rest of bubble
            }
        }
    }
}
```

4. Add voice settings sheet:
```swift
struct VoiceSettingsSheet: View {
    @Binding var autoSpeakEnabled: Bool
    @Binding var voiceInputMode: VoiceInputMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Auto-speak AI responses", isOn: $autoSpeakEnabled)
                } header: {
                    Text("Text-to-Speech")
                } footer: {
                    Text("Automatically speak AI responses out loud")
                }

                Section {
                    Picker("Voice input mode", selection: $voiceInputMode) {
                        Text("Tap to toggle").tag(VoiceInputMode.tapToToggle)
                        Text("Hold to talk").tag(VoiceInputMode.holdToTalk)
                    }
                } header: {
                    Text("Microphone")
                } footer: {
                    Text("Choose how you want to activate voice input")
                }
            }
            .navigationTitle("Voice Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
```

### Phase 4: Streaming Response with TTS

**Enhancement**: Instead of waiting for the full response, speak sentence-by-sentence as they're generated.

```swift
func sendMessage(_ text: String) async -> Bool {
    // ... existing setup

    var fullResponse = ""
    var speakableBuffer = ""

    // Stream response
    for try await chunk in fmClient.streamChat(fullPrompt) {
        fullResponse = chunk

        // Update UI
        messages[assistantIndex] = AIChatMessage(
            text: fullResponse,
            isUser: false,
            isStreaming: true
        )

        // Sentence-by-sentence TTS
        if autoSpeakEnabled {
            speakableBuffer = fullResponse

            // Check if we have a complete sentence
            if let lastSentenceEnd = speakableBuffer.lastIndex(where: { $0 == "." || $0 == "!" || $0 == "?" }) {
                let sentenceEnd = speakableBuffer.index(after: lastSentenceEnd)
                let completeSentence = String(speakableBuffer[..<sentenceEnd])

                // Speak this sentence
                await speak(completeSentence)

                // Remove spoken part from buffer
                speakableBuffer.removeSubrange(..<sentenceEnd)
            }
        }
    }

    // Speak any remaining text
    if autoSpeakEnabled && !speakableBuffer.isEmpty {
        await speak(speakableBuffer)
    }

    // Finalize
    messages[assistantIndex] = AIChatMessage(
        text: fullResponse,
        isUser: false,
        isStreaming: false
    )

    return true
}
```

### Phase 5: Polish & Testing

#### Required Info.plist Keys

**File**: `CardGenie/Info.plist`

```xml
<key>NSMicrophoneUsageDescription</key>
<string>CardGenie uses the microphone to transcribe your voice questions and lecture recordings, all processed on-device for privacy.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>CardGenie uses speech recognition to convert your voice to text for AI conversations and study sessions, all processed offline on your device.</string>
```

#### Testing Checklist

1. **Offline Mode Test**
   - Enable airplane mode
   - Try voice input → should work (on-device STT)
   - Try AI conversation → should work (on-device LLM)
   - Try TTS → should work (on-device synthesis)
   - ✅ **Expected**: Everything works offline

2. **Permission Flows**
   - Test first-time microphone permission request
   - Test first-time speech recognition permission request
   - Test denial scenarios (graceful fallback to text input)
   - Test re-requesting permissions from Settings

3. **Multi-Turn Conversations**
   - Test 5+ turn voice conversation
   - Verify context is maintained
   - Test interruptions (start talking while AI is speaking)
   - Test rapid back-and-forth (quick follow-ups)

4. **Audio Interruptions**
   - Test phone call interruption
   - Test alarm interruption
   - Test another app playing audio
   - ✅ **Expected**: Audio session gracefully pauses and resumes

5. **Voice Modes**
   - Test tap-to-toggle mode
   - Test hold-to-talk mode (future)
   - Test switching between modes
   - Test voice input cancellation

6. **TTS Settings**
   - Test auto-speak toggle
   - Test manual speak button on messages
   - Test speaking interruption (stop when user starts talking)
   - Test voice selection (if implementing custom voices)

## Benefits of This Approach

### 1. **Privacy-First**
- Zero network calls
- All processing on Neural Engine
- No data leaves device
- Apple Intelligence guardrails built-in

### 2. **Fast & Responsive**
- On-device LLM is instant (no API latency)
- Real-time STT streaming
- Sentence-by-sentence TTS for natural flow

### 3. **Unified Experience**
- Single "AI Chat" tab for all AI interactions
- Seamless switching between text and voice
- Conversation history preserved across modes

### 4. **Native iOS 26 Integration**
- Uses latest Apple Intelligence APIs
- Leverages Neural Engine for efficiency
- Battery-efficient on-device processing

## Future Enhancements

### Tool Calling (iOS 26 LanguageModelSession feature)
```swift
struct FlashcardSearchTool: LanguageModelTool {
    let name = "search_flashcards"
    let description = "Search for flashcards by topic or keyword"

    struct Input: Codable {
        let query: String
    }

    struct Output: Codable {
        let cards: [String]
        let count: Int
    }

    func perform(with input: Input) async throws -> Output {
        // Search user's flashcard database
        let results = await searchCards(query: input.query)
        return Output(cards: results.map(\.question), count: results.count)
    }
}
```

This enables the AI to:
- Search your flashcard database ("Show me all biology cards")
- Create new flashcard sets ("Create a deck about photosynthesis")
- Quiz you on specific topics ("Quiz me on US history")
- Track study progress ("How many cards are due today?")

### Context-Aware Conversations
```swift
struct PromptContext {
    let flashcardSets: [FlashcardSet]
    let studyStreak: Int
    let dueCards: Int
    let recentTopics: [String]

    var systemPrompt: String {
        """
        You are a personal study assistant in CardGenie, an iOS flashcard app.

        USER CONTEXT:
        - Current study streak: \(studyStreak) days
        - Cards due today: \(dueCards)
        - Recent topics: \(recentTopics.joined(separator: ", "))
        - Available flashcard sets: \(flashcardSets.map(\.name).joined(separator: ", "))

        You can help the user:
        1. Study their flashcards
        2. Create new flashcard sets
        3. Get explanations about topics they're learning
        4. Track their progress and motivation

        Be encouraging, concise, and educational.
        """
    }
}
```

## Implementation Timeline

| Phase | Tasks | Estimated Time | Priority |
|-------|-------|----------------|----------|
| Phase 1 | Add TTS support | 2-3 hours | High |
| Phase 2 | Enhance STT | 2-3 hours | High |
| Phase 3 | UI enhancements | 3-4 hours | High |
| Phase 4 | Streaming TTS | 2-3 hours | Medium |
| Phase 5 | Testing & polish | 2-3 hours | High |
| **Total** | | **11-16 hours** | |

## Success Metrics

1. ✅ Voice input works completely offline (airplane mode test)
2. ✅ Real-time transcript preview during listening
3. ✅ Natural TTS responses (sentence-by-sentence streaming)
4. ✅ Conversation context maintained across voice/text modes
5. ✅ Graceful interruption handling (stop speaking when user talks)
6. ✅ All permissions properly requested with clear explanations
7. ✅ Battery usage equivalent to other voice assistants (< 5% per 10 min)

## References

- [Apple Intelligence Documentation](https://developer.apple.com/documentation/FoundationModels/)
- [Speech Framework Guide](https://developer.apple.com/documentation/speech)
- [AVSpeechSynthesizer Guide](https://developer.apple.com/documentation/avfoundation/avspeechsynthesizer)
- [CardGenie Architecture Documentation](../../CLAUDE.md)
