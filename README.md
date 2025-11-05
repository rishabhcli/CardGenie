# CardGenie - iOS 26 Smart Notecard App

A modern, privacy-first journaling app for iOS 26+ that leverages Apple Intelligence for on-device AI features and showcases the new Liquid Glass design language.

## 🎯 Overview

CardGenie is a native iPhone app built for iOS 26 that combines beautiful design with intelligent features - all while keeping your data completely private and offline.

## 📚 Full Documentation

For a consolidated, easy-to-browse index of all documents, see `docs/README.md`.

### Key Features

- 📝 **Rich Text Journaling** - Write and organize your thoughts with ease
- 🤖 **On-Device AI** - Summarize entries, generate tags, and get reflections using Apple Intelligence
- ✍️ **Writing Tools** - Built-in proofreading, rewriting, and text transformation
- 🔒 **100% Offline** - All data and AI processing stay on your device
- 💎 **Liquid Glass UI** - Modern, translucent interface with fluid animations
- 🔍 **Smart Search** - Find entries by content, tags, or summaries
- ♿️ **Accessibility First** - Full support for Dynamic Type, Reduce Motion, and Reduce Transparency

## 🏗️ Architecture

### Project Structure

```
CardGenie/
├── App/
│   └── CardGenieApp.swift          # Main app entry point
├── Data/
│   ├── Models.swift                   # SwiftData models
│   └── Store.swift                    # Persistence layer
├── Intelligence/
│   ├── FMClient.swift                 # Foundation Models wrapper
│   └── WritingTextEditor.swift        # Writing Tools integration
├── Features/
│   ├── JournalListView.swift          # Entry list screen
│   ├── JournalDetailView.swift        # Editor with AI actions
│   └── SettingsView.swift             # Settings & info
├── Design/
│   ├── Theme.swift                    # Liquid Glass materials
│   └── Components.swift               # Reusable UI components
└── Tests/
    ├── FMClientTests.swift            # AI client tests
    └── StoreTests.swift               # Data layer tests
```

### Design Patterns

- **MVVM Architecture** - Separation of concerns between UI and logic
- **SwiftUI + SwiftData** - Modern declarative UI with reactive data
- **Offline-First** - All features work without internet
- **Privacy by Design** - No data collection, tracking, or cloud sync

## 🚀 Getting Started

### Requirements

- **Xcode 17+** with iOS 26 SDK
- **iOS 26.0+** deployment target
- **iPhone 15 Pro or newer** for Apple Intelligence features
- **Apple Intelligence enabled** in Settings

### Installation

1. Clone the repository
2. Open `CardGenie.xcodeproj` in Xcode
3. Set the deployment target to iOS 26.0
4. Build and run on a device with iOS 26+

### First Run Setup

The app works out of the box with placeholder AI responses for testing. To enable full Apple Intelligence features:

1. Ensure your device supports Apple Intelligence (iPhone 15 Pro+)
2. Go to **Settings > Apple Intelligence & Siri**
3. Enable **Apple Intelligence**
4. Wait for the on-device model to download (first time only)
5. Launch CardGenie and test AI features

## 🤖 Apple Intelligence Integration

### Foundation Models API

CardGenie uses Apple's on-device Foundation Models for custom AI features:

```swift
// Example: Summarizing an entry
let client = FMClient()
let summary = try await client.summarize(entryText)
```

**Features powered by Foundation Models:**
- **Summarization** - Condense entries into 2-3 sentences
- **Tag Generation** - Extract key topics and themes
- **Reflections** - Generate encouraging insights

**Implementation Notes:**
- The `FMClient.swift` file contains placeholder implementations for testing
- When building with the actual iOS 26 SDK, replace placeholders with real API calls
- See inline comments in `FMClient.swift` for exact API patterns

### Writing Tools

Built-in text editing assistance via UIKit's Writing Tools:

```swift
// Enable Writing Tools on text view
textView.isWritingToolsEnabled = true
```

**Available to users:**
- **Proofread** - Grammar and spelling checks
- **Rewrite** - Alternative phrasings and tones
- **Summarize** - Quick summaries of selected text
- **Transform** - Change style and formality

Writing Tools appear automatically when users select text in the editor.

## 🎨 Liquid Glass Design

### Materials

CardGenie uses iOS 26's Liquid Glass materials for a modern, translucent UI:

```swift
// Apply Liquid Glass panel
view.glassPanel()

// Apply content background
view.glassContentBackground()

// Custom glass overlay
view.glassOverlay(cornerRadius: 16)
```

### Design Principles

1. **Translucency with Purpose** - Glass materials for chrome and panels
2. **Content First** - UI recedes when focusing, expands when needed
3. **Fluid Motion** - Spring animations and smooth transitions
4. **Accessibility** - Automatic fallbacks for Reduce Transparency

### Accessibility Support

All Liquid Glass effects include solid fallbacks:

```swift
@Environment(\.accessibilityReduceTransparency) var reduceTransparency

if reduceTransparency {
    content.background(Glass.solid)  // Opaque
} else {
    content.background(Glass.panel)  // Translucent
}
```

## 📊 Data Storage

### SwiftData Models

```swift
@Model
final class JournalEntry {
    var id: UUID
    var createdAt: Date
    var text: String
    var summary: String?
    var tags: [String]
    var reflection: String?
}
```

### Local Storage

- All data stored in app sandbox via SwiftData
- No iCloud sync or external file access
- Private and secure by default
- Survives app updates and restarts

### CRUD Operations

```swift
// Create
let entry = store.newEntry()

// Read
let entries = store.fetchAllEntries()

// Update
entry.text = "Updated content"
store.save()

// Delete
store.delete(entry)

// Search
let results = store.search("keyword")
```

## 🧪 Testing

### Unit Tests

Run tests via Xcode Test Navigator (⌘U):

```swift
// Test AI client
FMClientTests.swift - 15+ tests covering all AI operations

// Test data layer
StoreTests.swift - 25+ tests covering CRUD, search, persistence
```

### Manual Testing Checklist

- [ ] Create new entry and save text
- [ ] Search for entries by keyword
- [ ] Generate AI summary (requires Apple Intelligence)
- [ ] Select text and use Writing Tools (Proofread/Rewrite)
- [ ] Generate tags and reflections
- [ ] Delete entries with confirmation
- [ ] Share entry via system share sheet
- [ ] Test in dark mode
- [ ] Test with Reduce Transparency enabled
- [ ] Test with Reduce Motion enabled
- [ ] Test with various Dynamic Type sizes
- [ ] Turn on Airplane Mode and verify all features work offline

### Performance Testing

```bash
# Recommended test scenarios:
# - Create 100+ entries
# - Search through large datasets
# - Summarize very long entries (1000+ words)
# - Monitor memory during AI operations
# - Check battery impact of AI features
```

## 🔒 Privacy & Security

### Privacy Features

- ✅ **100% Offline** - No network calls
- ✅ **On-Device AI** - All processing via Neural Engine
- ✅ **Local Storage** - Data never leaves device
- ✅ **No Analytics** - Zero tracking or telemetry
- ✅ **No Third Parties** - No external dependencies

### Data Handling

- Journal entries stored in app sandbox
- SwiftData encrypts data when device is locked
- No iCloud sync (optional future feature)
- No backup to external locations
- User can clear all data via Settings

## 🎯 Roadmap

### Current Version (1.0)
- [x] Core journaling features
- [x] Apple Intelligence integration
- [x] Liquid Glass UI
- [x] Offline functionality
- [x] Search and organization

### Future Enhancements
- [ ] Photo attachments
- [ ] Voice notes
- [ ] Mood tracking
- [ ] Export to PDF
- [ ] Optional iCloud sync
- [ ] Siri Shortcuts integration
- [ ] Widgets for quick entry
- [ ] Apple Watch companion app

## 🛠️ Building for Production

### Xcode Project Setup

1. **Set Deployment Target**
   - Project Settings > General > Deployment Info
   - Set to **iOS 26.0**

2. **Configure Signing**
   - Automatic signing recommended
   - Team: Your Apple Developer account

3. **Add Frameworks**
   - SwiftUI (auto-included)
   - SwiftData (auto-included)
   - Foundation Models (iOS 26+)
   - UIKit (for Writing Tools bridge)

4. **Update Info.plist** (if adding media later)
   - `NSCameraUsageDescription` - "To add photos to journal entries"
   - `NSMicrophoneUsageDescription` - "To record voice notes"

### Release Checklist

- [ ] Update version number in project settings
- [ ] Test on physical device with Apple Intelligence
- [ ] Verify all AI features work correctly
- [ ] Test accessibility features
- [ ] Review and update privacy policy
- [ ] Prepare App Store screenshots
- [ ] Write App Store description highlighting privacy
- [ ] Submit for App Review

### App Store Requirements

- Must be built with **Xcode 17+ and iOS 26 SDK** (as of April 2026)
- App Privacy form: "No data collected"
- Age rating: 4+ (journal app, no objectionable content)
- Categories: Productivity, Lifestyle
- Keywords: journal, diary, AI, privacy, offline

## 📖 API Reference

### FMClient

```swift
@MainActor
final class FMClient: ObservableObject {
    func capability() -> FMCapabilityState
    func summarize(_ text: String) async throws -> String
    func tags(for text: String) async throws -> [String]
    func reflection(for text: String) async throws -> String
}
```

### Store

```swift
@MainActor
final class Store: ObservableObject {
    func newEntry() -> JournalEntry
    func delete(_ entry: JournalEntry)
    func save()
    func fetchAllEntries() -> [JournalEntry]
    func search(_ searchText: String) -> [JournalEntry]
}
```

### Theme Modifiers

```swift
extension View {
    func glassPanel() -> some View
    func glassContentBackground() -> some View
    func glassOverlay(cornerRadius: CGFloat = 12) -> some View
    func glassCard(cornerRadius: CGFloat = 16) -> some View
}
```

## 🔗 Resources

### Apple Documentation
- [Foundation Models Framework](https://developer.apple.com/documentation/FoundationModels/)
- [Writing Tools Integration](https://developer.apple.com/documentation/uikit/uitextview/writing-tools)
- [Liquid Glass Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/liquid-glass)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)

### WWDC Sessions (2025)
- "What's New in iOS 26"
- "Generating Content with Foundation Models"
- "Integrate Writing Tools in Your App"
- "Design with Liquid Glass"
- "Privacy and Machine Learning"

## 🤝 Contributing

This is a reference implementation for iOS 26 features. Contributions welcome!

### Development Guidelines
- Follow Swift API design guidelines
- Maintain offline-first approach
- Preserve privacy principles
- Include tests for new features
- Update documentation

## 📄 License

MIT License - See LICENSE file for details

## ⚠️ Important Notes

### iOS 26 SDK Placeholder APIs

**The Foundation Models API used in this project is based on the iOS 26 specification.** When Apple releases the actual iOS 26 SDK, you'll need to:

1. **Update `FMClient.swift`** with real API calls:
   - Replace placeholder implementations in `generateTextWithFoundationModels()`
   - Import the actual `FoundationModels` framework
   - Use real `SystemLanguageModel` and `LanguageModelSession` APIs
   - Handle all availability states properly

2. **Update `WritingTextEditor.swift`** if needed:
   - Verify `isWritingToolsEnabled` is the correct property name
   - Check for any additional configuration options
   - Test on actual iOS 26 devices

3. **Test thoroughly** on real devices:
   - iPhone 15 Pro or newer
   - iOS 26.0+ installed
   - Apple Intelligence enabled
   - Verify all AI features work as expected

### Current Behavior

- **AI features use placeholder implementations** for testing
- **Writing Tools integration uses documented APIs** but needs verification
- **Liquid Glass effects use current SwiftUI materials** as a baseline
- **All code is production-ready** except for the AI integration placeholders

---

Built with ❤️ for iOS 26 • Privacy First • 100% Offline • Apple Intelligence Powered
