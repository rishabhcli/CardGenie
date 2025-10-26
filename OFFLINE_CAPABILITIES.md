# CardGenie Offline Capabilities

## 🔒 100% Offline, Privacy-First AI

CardGenie is designed to work **completely offline** with zero network calls. All AI processing happens locally on your device's Neural Engine, ensuring your study materials never leave your device.

## Verified Offline Components

### ✅ Voice AI Assistant

**Technology Stack:**
- **Speech Recognition**: Apple's `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`
  - Enforces on-device-only transcription
  - Location: `VoiceAssistantView.swift:446`

- **Text-to-Speech**: `AVSpeechSynthesizer` (always offline)
  - Native iOS speech synthesis
  - No network required

- **LLM (Language Model)**: Apple's Foundation Models (iOS 26+)
  - Runs on Neural Engine
  - Uses `SystemLanguageModel.default`
  - All processing happens locally
  - Location: `FMClient.swift`

**Features:**
- Real-time voice Q&A
- Conversational AI assistant
- Automatic follow-up questions
- Progress reporting with structured logging
- Cancellation support
- Comprehensive error handling

### ✅ Video/Lecture Processing

**Technology Stack:**
- **Audio Extraction**: `AVAssetExportSession`
  - Offline media processing
  - Location: `VideoProcessor.swift:180`

- **Speech Recognition**: On-device transcription with timestamps
  - 30-second chunking for optimal memory usage
  - Location: `VideoProcessor.swift:136`

- **Embeddings**: Apple's `NLEmbedding` framework
  - Semantic sentence embeddings
  - Word-based fallback for robustness
  - Location: `AIEngine.swift:120`

**Features:**
- Progress reporting (extraction → transcription → chunking → embeddings → summarization)
- Delegate pattern for UI updates
- Full cancellation support
- Structured logging with emoji indicators
- Automatic cleanup of temporary files

### ✅ Text Embeddings

**Technology Stack:**
- **Primary**: `NLEmbedding.sentenceEmbedding(for: .english)`
  - Native semantic vectors
  - High-quality embeddings

- **Fallback**: Word-based embedding averaging
  - Tokenizes text and averages word vectors
  - Handles edge cases gracefully
  - Location: `AIEngine.swift:143`

**Features:**
- 384-dimension vectors
- Vector normalization
- Zero-padding for consistency
- Multi-language ready (locale parameter)

### ✅ Flashcard Generation

**Technology Stack:**
- **AI Generation**: Foundation Models
  - Structured generation with `@Generable` protocol
  - Guardrail protection
  - Location: `FMClient.swift`

**Features:**
- Auto-tagging (max 3 tags)
- Summarization (2-3 sentences)
- Study encouragement messages
- Pattern analysis

## Privacy Keys (Info.plist)

Required permissions are already configured in Xcode project settings:

```xml
INFOPLIST_KEY_NSSpeechRecognitionUsageDescription
INFOPLIST_KEY_NSMicrophoneUsageDescription
INFOPLIST_KEY_NSCameraUsageDescription
```

## Logging & Debugging

All components use `OSLog` for structured logging:

### Log Categories:
- **VoiceAssistant**: Voice recognition, LLM processing, TTS
- **VideoProcessor**: Video transcription pipeline
- **FMClient**: Foundation Models operations

### Log Emoji Indicators:
- 🎙️ Voice recognition events
- 🧠 AI processing
- ✅ Success operations
- ❌ Errors
- ⚠️ Warnings
- 📊 Progress updates
- 🛑 Cancellations

**View logs in Console.app**:
```bash
Subsystem: com.cardgenie.app
Category: VoiceAssistant | VideoProcessor | FMClient
```

## Network Isolation Verification

### Enforced Offline Modes:

1. **Speech Recognition**:
   ```swift
   request.requiresOnDeviceRecognition = true
   // Will FAIL if device cannot perform on-device recognition
   ```

2. **Foundation Models**:
   ```swift
   SystemLanguageModel.default
   // Always runs on Neural Engine
   // No API key or network configuration exists
   ```

3. **Embeddings**:
   ```swift
   NLEmbedding.sentenceEmbedding(for: .english)
   // Part of iOS NaturalLanguage framework
   // Completely offline
   ```

## Testing Offline Mode

### 1. Enable Airplane Mode
```
Settings → Airplane Mode → ON
```

### 2. Disable Apple Intelligence Network (if desired)
```
Settings → Apple Intelligence → Disable network features
```

### 3. Test Features:
- ✅ Voice Q&A still works
- ✅ Video transcription still works
- ✅ Flashcard generation still works
- ✅ Embeddings still generated
- ✅ All AI features functional

## Performance Characteristics

### On-Device Processing Times (Estimated):

| Operation | Time | Notes |
|-----------|------|-------|
| Speech recognition (30s audio) | ~2-5s | Depends on Neural Engine |
| Sentence embedding | ~50ms | Per sentence |
| LLM completion (50 tokens) | ~1-3s | Depends on device model |
| Video transcription (1min) | ~10-15s | Full pipeline |

### Supported Devices:

- **Apple Intelligence**: iPhone 15 Pro+ (A17 Pro), M1+ iPads/Macs
- **Speech Recognition**: All iOS 10+ devices
- **NLEmbedding**: All iOS 14+ devices

## Error Handling

All components gracefully degrade:

1. **No Apple Intelligence**: Falls back to simpler algorithms
2. **Speech recognition unavailable**: Shows permission prompt
3. **Embedding model not loaded**: Returns error with clear message
4. **Cancellation**: All operations support mid-stream cancellation

## Progress Reporting

### VideoProcessor Phases:
```swift
enum Phase {
    case extractingAudio      // 0-10%
    case transcribing          // 10-60%
    case generatingChunks      // 60-70%
    case creatingEmbeddings    // 70-80%
    case summarizing           // 80-95%
    case completed             // 100%
}
```

### Delegate Protocol:
```swift
protocol VideoProcessorDelegate {
    func videoProcessor(_ processor, didUpdateProgress progress)
    func videoProcessor(_ processor, didFailWithError error)
}
```

## Cancellation Support

All long-running operations support cancellation:

```swift
// Voice Assistant
voiceAssistant.cancelListening()

// Video Processor
videoProcessor.cancel()

// Also respects Task.isCancelled for async operations
```

## Architecture Summary

```
┌─────────────────────────────────────────────┐
│         User Interface (SwiftUI)            │
└─────────────────┬───────────────────────────┘
                  │
        ┌─────────┼─────────┐
        │         │         │
┌───────▼─────┐ ┌▼─────────▼───┐ ┌─────────────┐
│Voice AI     │ │Video         │ │Flashcard    │
│Assistant    │ │Processor     │ │Generator    │
└───────┬─────┘ └┬─────────────┘ └┬────────────┘
        │        │                 │
        └────────┼─────────────────┘
                 │
        ┌────────▼─────────┐
        │  AI Engine       │
        │  - FMClient      │
        │  - NLEmbedding   │
        └────────┬─────────┘
                 │
        ┌────────▼──────────┐
        │ Neural Engine     │
        │ (On-Device Only)  │
        └───────────────────┘
```

## Code References

### Key Files:

- **Voice AI**: `Features/VoiceAssistantView.swift`
- **Video Processing**: `Processors/VideoProcessor.swift`
- **AI Client**: `Intelligence/FMClient.swift`
- **AI Engine**: `Intelligence/AIEngine.swift`
- **Embeddings**: `AIEngine.swift:120-191`

### Critical Offline Flags:

1. `VoiceAssistantView.swift:446`:
   ```swift
   recognitionRequest.requiresOnDeviceRecognition = true
   ```

2. `VideoProcessor.swift:146`:
   ```swift
   request.requiresOnDeviceRecognition = true
   ```

3. `FMClient.swift:91`:
   ```swift
   let model = SystemLanguageModel.default
   guard case .available = model.availability
   ```

---

**Last Updated**: October 25, 2025
**Version**: 1.0.0
**Build**: Verified Offline ✅
