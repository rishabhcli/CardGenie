# ADR 0005: iOS 26+ Minimum Version Requirement

**Status:** Accepted

**Date:** 2025-11-14

**Deciders:** CardGenie Core Team

---

## Context

CardGenie is being developed during the iOS 26 era, when Apple introduced major new capabilities around Apple Intelligence, on-device AI, and enhanced UI frameworks. We needed to choose a minimum deployment target that would:

- Enable core differentiating features
- Balance market reach vs. technical capabilities
- Set reasonable development complexity
- Future-proof the architecture

**iOS Version Landscape (2025):**
- **iOS 26**: Apple Intelligence, Foundation Models API, Liquid Glass, enhanced SwiftData
- **iOS 25**: Modern baseline, SwiftUI 5, but no Apple Intelligence
- **iOS 24**: Previous year, broader device support
- **iOS 23+**: Much broader reach, but older APIs

**Device Compatibility:**
- **iOS 26**: iPhone 15 Pro+, iPhone 16 series (Neural Engine 5+)
- **iOS 25**: iPhone 13+, iPad Air 5+, iPad Pro 3rd gen+
- **iOS 24**: iPhone 11+, iPad 8th gen+

## Decision

CardGenie will require **iOS 26.0** as the minimum deployment target.

### Xcode Configuration

```swift
// CardGenie.xcodeproj settings
IPHONEOS_DEPLOYMENT_TARGET = 26.0

// CardGenieApp.swift
@main
struct CardGenieApp: App {
    // Requires iOS 26+ for:
    // - Foundation Models API
    // - SwiftData enhancements
    // - Liquid Glass effects
    // - Enhanced Speech framework
}
```

### Critical iOS 26+ Features Used

1. **Foundation Models API** (Core Value Proposition)
```swift
#if os(iOS) && compiler(>=6.0)
import FoundationModels

let session = LanguageModelSession { "system prompt" }
let response = try await session.complete(prompt)
#endif
```

2. **Liquid Glass UI** (Modern Design Language)
```swift
.glassEffect(.regular, in: .rect(cornerRadius: 16))
.glassEffect(.regular.interactive(), in: .capsule)  // iOS 26+
```

3. **Enhanced SwiftData** (Improved Performance)
- Better relationship handling
- Improved query optimization
- Automatic lightweight migrations

4. **Advanced Speech Recognition** (Voice Features)
- Improved on-device recognition accuracy
- Better punctuation handling
- Enhanced multilingual support

## Consequences

### Positive

✅ **Apple Intelligence**: Access to on-device Foundation Models (core feature)
✅ **Modern UI**: Liquid Glass, interactive glass effects, latest SwiftUI
✅ **Performance**: Neural Engine 5+ for fast AI inference
✅ **Clean Code**: No legacy workarounds or version checks
✅ **Future-Proof**: Starting with latest APIs ensures longevity
✅ **Smaller Binary**: No compatibility shims or fallback UI code
✅ **Development Speed**: Focus on one target, no cross-version testing

### Negative

⚠️ **Limited Reach**: Only iPhone 15 Pro+ and iPhone 16 series (initially)
⚠️ **Early Adoption**: Requires users on latest iOS version
⚠️ **Market Size**: Smaller addressable market than iOS 24-25 support
⚠️ **Testing**: Fewer test devices available during development
⚠️ **App Store**: May see lower download numbers initially

### Mitigations

- **Clear Messaging**: App Store listing explicitly states iOS 26+ requirement
- **Value Proposition**: Apple Intelligence features justify requirement
- **Fallback Features**: All features have local fallbacks (work without AI)
- **Growth Strategy**: Market grows as iOS 26 adoption increases
- **Premium Positioning**: Target early adopters with latest devices

## Market Analysis

### iOS Adoption Rates (Historical)
- After 6 months: ~60% of active iPhones on latest major version
- After 12 months: ~80-85% adoption
- After 18 months: ~90%+ adoption

### Target Audience
CardGenie targets:
- **Students**: Often have newer devices (education discounts)
- **Professionals**: Continuing education, typically newer hardware
- **Early Adopters**: Excited about Apple Intelligence features
- **Privacy-Conscious**: Willing to upgrade for on-device AI

### Competitive Landscape
- **Anki**: Desktop-first, older UI, no AI → We differentiate with modern mobile-first + AI
- **Quizlet**: Cloud-only, privacy concerns → We differentiate with offline privacy
- **RemNote**: Requires iOS 16+ → We target more sophisticated users

## Technical Justification

### Apple Intelligence is Non-Negotiable

The entire value proposition depends on on-device AI:
- Flashcard generation from text/PDFs/photos
- Voice assistant and conversational learning
- Content summarization and tagging
- AI-powered game modes and feedback

**Without Foundation Models:**
- Flashcard quality drops significantly (rule-based vs. AI)
- Voice assistant becomes basic Q&A (no Socratic dialogue)
- App loses key differentiator vs. competitors

### Fallback Strategy is Insufficient

While we have local fallbacks, they provide degraded experience:
```swift
// Fallback summarization (extracting first sentences)
// vs. AI summarization (key concepts extraction)

// Fallback tag generation (word frequency)
// vs. AI tags (semantic understanding)
```

Users would not get the "smart flashcard app" experience we promise.

### Alternative: Dual-Target Strategy

We considered maintaining two builds:
- **CardGenie Pro**: iOS 26+, full AI features
- **CardGenie Lite**: iOS 24+, basic features only

**Rejected because:**
- Doubles testing surface
- Fragments user base
- Confusing App Store presence
- Significant maintenance burden
- Dilutes premium positioning

## Alternatives Considered

### iOS 25 Minimum
- **Pros**: Broader device support (iPhone 13+)
- **Cons**: No Apple Intelligence → App loses core value
- **Verdict**: Not viable, Foundation Models are essential

### iOS 24 Minimum
- **Pros**: Very broad support (iPhone 11+)
- **Cons**: No Apple Intelligence, old SwiftUI, legacy UI
- **Verdict**: Would require complete redesign without AI

### Progressive Enhancement (iOS 24+ with iOS 26 features)
- **Pros**: Broader reach, AI for those who can use it
- **Cons**: Complex codebase, two-tier user experience, fragmented feature set
- **Verdict**: Too much complexity, dilutes vision

## Real-World Validation

Development on iOS 26 has confirmed the decision:
- ✅ Foundation Models essential for quality flashcard generation
- ✅ Liquid Glass UI significantly enhances aesthetics
- ✅ SwiftData improvements enable smooth 1000+ card performance
- ✅ Voice features rely heavily on iOS 26 Speech enhancements
- ✅ Clean codebase without version conditionals

## Migration Path

If market demands broader support in the future:

**Option 1: Wait for iOS 26 Adoption**
- After 12-18 months, 80%+ adoption makes requirement reasonable
- Preferred approach: stick to vision, let market catch up

**Option 2: Cloud AI Fallback**
- iOS 24+ users get cloud-based AI (compromise privacy)
- Conflicts with offline-first principle (see ADR 0004)
- Not recommended

**Option 3: CardGenie Lite**
- Separate "basic" version for older iOS
- Only if market demands it (based on App Store data)
- Would be positioned as different product

## App Store Strategy

**App Store Listing:**
```
Requirements: iOS 26.0 or later
Compatible Devices: iPhone 15 Pro, iPhone 15 Pro Max, iPhone 16 series

Why iOS 26?
CardGenie leverages Apple Intelligence for powerful on-device AI features:
- Smart flashcard generation
- AI-powered study assistance
- 100% private, offline learning
- Requires iPhone with Neural Engine 5+
```

**Phased Rollout:**
1. **Phase 1 (Months 1-6)**: Target early adopters, gather feedback
2. **Phase 2 (Months 6-12)**: Expand as iOS 26 adoption grows
3. **Phase 3 (12+ months)**: Re-evaluate based on adoption data

## Related Decisions

- [ADR 0004: Offline-First Design](0004-offline-first-design.md) - Requires Apple Intelligence
- [ADR 0002: SwiftData over Core Data](0002-swiftdata-over-core-data.md) - Uses iOS 26 enhancements

## References

- [Apple Intelligence Device Requirements](https://www.apple.com/apple-intelligence/)
- [Foundation Models API Documentation](https://developer.apple.com/documentation/FoundationModels/)
- [iOS Version Distribution Statistics](https://developer.apple.com/support/app-store/)

---

**Summary:** iOS 26+ is essential for CardGenie's Apple Intelligence features and represents a strategic bet on early adopters and privacy-conscious users who value on-device AI capabilities.
