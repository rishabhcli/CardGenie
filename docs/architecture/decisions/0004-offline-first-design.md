# ADR 0004: Offline-First Design Philosophy

**Status:** Accepted

**Date:** 2025-11-14

**Deciders:** CardGenie Core Team

---

## Context

CardGenie is a study app that leverages AI features for flashcard generation, voice assistance, and content analysis. We needed to decide how to architect the AI and data layers:

**Cloud-First Approach:**
- Send data to cloud APIs (OpenAI, Anthropic, Google)
- More powerful models, unlimited compute
- Requires internet connection
- User data leaves device

**Offline-First Approach:**
- All processing on-device using iOS 26 Apple Intelligence
- Limited to device Neural Engine capabilities
- Works without internet (airplane mode, poor connectivity)
- 100% private, data never leaves device

**Considerations:**
- **Privacy**: Students often study sensitive material (medical, legal, personal)
- **Reliability**: Need consistent experience regardless of network
- **Cost**: Cloud API costs scale with users
- **Speed**: Network latency vs. on-device processing
- **Apple Intelligence**: iOS 26+ provides sophisticated on-device AI

## Decision

CardGenie will be **100% offline-first** with **zero network calls** for core functionality.

### Core Principles

1. **No Cloud APIs**: All AI processing uses iOS 26 Foundation Models (on-device)
2. **No Analytics**: No tracking, telemetry, or usage data sent anywhere
3. **No Cloud Sync**: All data stored locally using SwiftData
4. **No Network Checks**: App functions identically in Airplane Mode
5. **Graceful Degradation**: Features work even without Apple Intelligence

### Implementation Strategy

**AI Processing:**
```swift
// FMClient.swift - 100% on-device AI
@MainActor
final class FMClient: ObservableObject {
    func summarize(_ text: String) async throws -> String {
        #if os(iOS) && compiler(>=6.0)
        // iOS 26+ with Apple Intelligence
        if capability() == .available {
            let session = LanguageModelSession { /* system prompt */ }
            return try await session.complete(prompt)
        }
        #endif

        // Fallback: Local heuristics (no network call)
        return extractFirstSentences(text, count: 2)
    }
}
```

**All Features Have Local Fallbacks:**
- **Summarization**: Extract first 2 sentences
- **Tag Generation**: Frequency-based keyword extraction
- **Encouragement**: Pattern-based responses from templates
- **Flashcard Generation**: Rule-based extraction (questions, definitions)

**Data Storage:**
```swift
// SwiftData with local-only persistence
let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false  // Local SQLite file
)
```

**No Network Dependencies:**
```xml
<!-- Info.plist - NO network permissions requested -->
<!-- No NSAppTransportSecurity exceptions -->
<!-- No cloud entitlements -->
```

## Consequences

### Positive

✅ **Absolute Privacy**: Zero data exfiltration, perfect for sensitive studies
✅ **Reliable**: Works in subway, airplane, rural areas with no connectivity
✅ **Fast**: No network latency (on-device inference ~500ms - 2s)
✅ **Free**: No API costs regardless of user growth
✅ **Trustworthy**: Users can verify offline operation in Airplane Mode
✅ **Compliant**: GDPR, HIPAA, FERPA compliant by design (data never shared)
✅ **Simple**: No auth, no server infrastructure, no backend maintenance
✅ **Apple Intelligence**: Leverages iOS 26's sophisticated on-device models

### Negative

⚠️ **Device Requirements**: Requires iPhone 15 Pro+ for best AI experience
⚠️ **Model Limitations**: On-device models less capable than GPT-4/Claude
⚠️ **No Collaboration**: Can't share flashcard sets with other users
⚠️ **No Backup**: Users must handle their own backups (iCloud Drive, export)
⚠️ **Limited Platforms**: iOS-only (can't sync to web or Android)

### Mitigations

- **Fallback Logic**: App fully functional without Apple Intelligence
- **Export Features**: JSON/CSV export for data portability (FlashcardExporter)
- **Documentation**: Clear communication about offline-only nature
- **Future**: Could add *optional* iCloud sync for same-user multi-device
- **User Control**: Export/import allows manual "sync" via file sharing

## Privacy Model

CardGenie's privacy guarantees:

```
┌──────────────────────────────────────────────────────────┐
│                    User's iPhone                         │
│                                                          │
│  ┌────────────┐      ┌──────────────┐                  │
│  │ SwiftData  │ ←──→ │ CardGenie    │                  │
│  │ (local DB) │      │ App          │                  │
│  └────────────┘      └──────┬───────┘                  │
│                             │                           │
│                             ↓                           │
│                      ┌──────────────┐                  │
│                      │ Apple        │                  │
│                      │ Intelligence │                  │
│                      │ (on-device)  │                  │
│                      └──────────────┘                  │
│                                                          │
│  ❌ NO network calls                                    │
│  ❌ NO cloud storage                                    │
│  ❌ NO analytics                                        │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

**Verifiable Claims:**
1. Run app in Airplane Mode → All features work
2. Network monitoring shows zero outbound traffic
3. No cloud entitlements in app signature
4. Source code inspection confirms no URLSession usage

## Alternatives Considered

### Hybrid Approach (On-Device + Cloud Fallback)
- **Pros**: Better AI quality when online, offline fallback
- **Cons**: Privacy compromised, users don't know what's sent
- **Verdict**: Privacy concerns outweigh marginal AI improvements

### Cloud-Only Approach
- **Pros**: Best AI quality, unlimited compute, multi-platform sync
- **Cons**: Privacy risk, costs scale, requires internet, data custody issues
- **Verdict**: Conflicts with core privacy value proposition

### Optional Cloud Features
- **Pros**: User choice, power users get better AI
- **Cons**: Complex codebase, privacy confusion, splits feature set
- **Verdict**: Could revisit for v2.0, but v1.0 stays offline-only

## Real-World Evidence

Development and testing confirms offline-only feasibility:

- ✅ **All 302 tests** run without network access
- ✅ **Manual testing** in Airplane Mode shows full functionality
- ✅ **AI Quality**: Foundation Models sufficient for flashcard generation
- ✅ **Performance**: On-device inference fast enough (< 2s for most tasks)
- ✅ **User Feedback**: Privacy-first approach is major selling point

## Marketing Implications

Offline-first is a **unique competitive advantage**:

**Competitors:**
- Anki: Desktop app, manual sync, no AI
- Quizlet: Cloud-only, ads, data mining
- RemNote: Cloud-only, subscription required
- Notion: Cloud-only, privacy concerns

**CardGenie:**
- 100% offline, 100% private
- No subscription (no cloud costs)
- AI-powered (iOS 26 Apple Intelligence)
- Works anywhere (subway, airplane, library)

## Related Decisions

- [ADR 0002: SwiftData over Core Data](0002-swiftdata-over-core-data.md) - Local persistence
- [ADR 0005: iOS 26+ Minimum Version](0005-ios-26-minimum-version.md) - Apple Intelligence requirement

## Future Considerations

**Possible Future Additions (Still Privacy-Preserving):**
1. **iCloud Sync**: Same-user multi-device sync via CloudKit (Apple-encrypted)
2. **Local Network Sharing**: AirDrop-style flashcard set sharing (no cloud)
3. **Export/Import**: Enhanced data portability formats (Anki, Quizlet export)
4. **Offline Voice**: Download additional language models for Speech/TTS

**Never:**
- Third-party analytics or tracking
- Cloud API processing of user content
- Ads or data monetization
- Account system or user profiles

## References

- [Apple Privacy Principles](https://www.apple.com/privacy/)
- [Apple Intelligence Privacy](https://www.apple.com/privacy/docs/Apple_Intelligence_Privacy_Overview.pdf)
- iOS 26 Foundation Models API (100% on-device)
- CardGenie Privacy Model documentation

---

**Summary:** CardGenie's offline-first design is a core architectural principle that provides absolute privacy, reliability, and simplicity while leveraging iOS 26's powerful on-device AI capabilities.
