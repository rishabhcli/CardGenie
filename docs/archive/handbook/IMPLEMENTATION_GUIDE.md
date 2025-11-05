# Implementation Guide for iOS 26 APIs

This guide helps you integrate the actual iOS 26 APIs when Apple releases the SDK.

## 🎯 Quick Reference

### Files Requiring Updates

| File | Status | Priority |
|------|--------|----------|
| `Intelligence/FMClient.swift` | ⚠️ Placeholder | **HIGH** |
| `Intelligence/WritingTextEditor.swift` | ⚠️ Needs Verification | **MEDIUM** |
| `Design/Theme.swift` | ✅ Ready | LOW |
| All other files | ✅ Production Ready | N/A |

---

## 📝 Step-by-Step Integration

### Step 1: Update FMClient.swift for Real Foundation Models

**Location:** `CardGenie/Intelligence/FMClient.swift`

#### 1.1 Import the Framework

```swift
// Add at the top of the file
import FoundationModels  // iOS 26+
```

#### 1.2 Update Capability Check

Replace the placeholder `capability()` method:

```swift
func capability() -> FMCapabilityState {
    if #available(iOS 26.0, *) {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            return .available
        case .appleIntelligenceNotEnabled:
            return .notEnabled
        case .deviceNotSupported:
            return .notSupported
        case .modelNotReady:
            return .modelNotReady
        default:
            return .unknown
        }
    } else {
        return .notSupported
    }
}
```

**Apple Documentation Reference:**
- Foundation Models → Checking Model Availability
- `SystemLanguageModel.default.availability`

#### 1.3 Implement Real Summarization

Replace the placeholder `generateTextWithFoundationModels()` method:

```swift
private func generateTextWithFoundationModels(system: String, user: String) async throws -> String {
    // Get the default system language model
    let model = SystemLanguageModel.default

    guard model.isAvailable else {
        throw FMError.modelUnavailable
    }

    // Create a session for this interaction
    let session = LanguageModelSession()

    // Configure the request
    let request = LanguageModelRequest(
        systemPrompt: system,
        userPrompt: user,
        temperature: 0.3,      // Lower = more focused
        maxTokens: 150,        // Limit response length
        topP: 0.9              // Nucleus sampling
    )

    // Generate response
    let response = try await session.respond(to: request)

    // Extract text from response
    let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)

    log.info("Generated \(text.count) characters")

    return text
}
```

**Key Apple APIs to Use:**
- `SystemLanguageModel.default` - Access the on-device model
- `LanguageModelSession()` - Create a generation session
- `LanguageModelRequest` - Configure the prompt
- `session.respond(to:)` - Get the AI response

#### 1.4 Implement Streaming (Optional)

For better UX with long responses:

```swift
func streamSummary(_ text: String, onToken: @escaping (String) -> Void) async throws {
    guard #available(iOS 26.0, *) else {
        throw FMError.unsupportedOS
    }

    let model = SystemLanguageModel.default
    guard model.isAvailable else {
        throw FMError.modelUnavailable
    }

    let session = LanguageModelSession()

    let request = LanguageModelRequest(
        systemPrompt: "Summarize concisely in 2 sentences.",
        userPrompt: text
    )

    // Stream tokens as they're generated
    for try await token in session.stream(request) {
        await MainActor.run {
            onToken(token.text)
        }
    }
}
```

#### 1.5 Use Specialized Models

For tag extraction, use the content tagging model:

```swift
func tags(for text: String) async throws -> [String] {
    guard #available(iOS 26.0, *) else {
        throw FMError.unsupportedOS
    }

    // Use specialized model for content tagging
    let model = SystemLanguageModel(useCase: .contentTagging)
    guard model.isAvailable else {
        throw FMError.modelUnavailable
    }

    let session = LanguageModelSession(model: model)

    let request = LanguageModelRequest(
        systemPrompt: """
        Extract up to three topic tags from the text.
        Output as comma-separated words (1-2 words each).
        Example: work, planning, goals
        """,
        userPrompt: text
    )

    let response = try await session.respond(to: request)

    // Parse tags
    let tags = response.text
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .prefix(3)
        .map(String.init)

    return tags
}
```

**Apple Documentation Reference:**
- Foundation Models → Specialized Use Cases
- `SystemLanguageModel(useCase:)` enumeration
- Available use cases: `.contentTagging`, `.contentClassification`, `.entityExtraction`

---

### Step 2: Verify Writing Tools Integration

**Location:** `CardGenie/Intelligence/WritingTextEditor.swift`

#### 2.1 Confirm Property Names

Verify that `isWritingToolsEnabled` is the correct property:

```swift
if #available(iOS 26.0, *) {
    textView.isWritingToolsEnabled = true  // ✓ Correct?
}
```

**Check Apple's Documentation:**
- UIKit → UITextView → Writing Tools
- Property name and availability
- Any additional configuration options

#### 2.2 Test Behavior Customization

Apple may provide additional customization:

```swift
if #available(iOS 26.0, *) {
    textView.isWritingToolsEnabled = true

    // If these exist in the API:
    textView.writingToolsBehavior = .automatic  // or .limited, .none
    textView.allowedWritingToolsActions = [.proofread, .rewrite, .summarize]
}
```

#### 2.3 Implement Delegate (if available)

Check if there's a delegate protocol for Writing Tools events:

```swift
@available(iOS 26.0, *)
extension Coordinator: UITextViewWritingToolsDelegate {
    func textView(_ textView: UITextView, writingToolsDidFinish result: WritingToolsResult) {
        // Track which tool was used
        print("Writing Tools action: \(result.action)")

        // Update parent
        parent.text = textView.text
        parent.onTextChange?(textView.text)
    }
}
```

---

### Step 3: Test Liquid Glass Materials

**Location:** `CardGenie/Design/Theme.swift`

#### 3.1 Verify Material Naming

Check if iOS 26 introduces new material styles:

```swift
// Current (iOS 15-18):
.ultraThinMaterial
.thinMaterial
.regularMaterial

// Possible iOS 26 additions:
.liquidGlassMaterial  // Check if this exists
.fluidMaterial        // Or similar
```

#### 3.2 Check for New Modifiers

Apple may provide SwiftUI modifiers specifically for Liquid Glass:

```swift
// Potential new modifiers to check for:
.liquidGlassEffect()
.fluidBackground()
.glassMorphing()
```

#### 3.3 Test Default Behavior

Standard UI components should adopt Liquid Glass automatically:

```swift
// Test that these automatically use Liquid Glass on iOS 26:
NavigationStack { }     // Nav bar should be translucent
TabView { }             // Tab bar should be translucent
.toolbar { }            // Toolbar should be translucent
.sheet { }              // Sheets should have glass background
```

---

## 🧪 Testing Checklist

### Device Requirements
- [ ] iPhone 15 Pro or newer
- [ ] iOS 26.0+ installed
- [ ] Apple Intelligence enabled in Settings
- [ ] Developer mode enabled

### Foundation Models Tests
- [ ] Check `capability()` returns `.available`
- [ ] Generate summary for 200-word entry (< 3 seconds)
- [ ] Generate tags for entry (returns 1-3 tags)
- [ ] Generate reflection (returns one sentence)
- [ ] Test with 1000+ word entry (verify doesn't timeout)
- [ ] Test with empty text (handles gracefully)
- [ ] Test with non-English text (if supported)
- [ ] Monitor memory usage during generation
- [ ] Test in Airplane Mode (should still work)

### Writing Tools Tests
- [ ] Select text in editor
- [ ] Context menu shows "Proofread" option
- [ ] Context menu shows "Rewrite" option
- [ ] Context menu shows "Summarize" option
- [ ] Proofread highlights errors correctly
- [ ] Rewrite provides alternative phrasings
- [ ] Summarize condenses text appropriately
- [ ] Changes apply correctly to the text view
- [ ] Works offline (Airplane Mode)

### Liquid Glass Tests
- [ ] Navigation bar is translucent
- [ ] Content behind nav bar is blurred
- [ ] Toolbar has glass effect
- [ ] Custom panels use glass material
- [ ] Glass adapts to light/dark mode
- [ ] Reduce Transparency shows solid backgrounds
- [ ] Text remains legible over glass
- [ ] Animations are smooth (60fps)

---

## 🐛 Troubleshooting

### Issue: Apple Intelligence Not Available

**Symptoms:**
- `capability()` returns `.notSupported` or `.notEnabled`
- AI features don't work

**Solutions:**
1. **Check Device:** iPhone 15 Pro or newer required
2. **Check OS:** iOS 26.0+ required
3. **Enable in Settings:**
   - Go to Settings > Apple Intelligence & Siri
   - Toggle on "Apple Intelligence"
4. **Wait for Model:** First time may require download
5. **Restart Device:** Sometimes needed after enabling

### Issue: Writing Tools Don't Appear

**Symptoms:**
- Context menu doesn't show AI options
- `isWritingToolsEnabled` has no effect

**Solutions:**
1. **Verify Property Name:** Check Apple's docs for correct API
2. **Check Text View Type:** Ensure using `UITextView`, not `UITextField`
3. **Apple Intelligence:** Must be enabled in Settings
4. **Delegate Setup:** Ensure delegate is set correctly
5. **Build Target:** Verify building for iOS 26.0+

### Issue: AI Responses Are Slow

**Symptoms:**
- Summarization takes > 5 seconds
- UI freezes during generation

**Solutions:**
1. **Limit Input Length:** Cap at ~500 words for summaries
2. **Use Streaming:** Implement streaming API for better UX
3. **Background Tasks:** Ensure using `async/await` correctly
4. **Temperature Settings:** Lower temperature for faster responses
5. **Check Device:** Older A-series chips may be slower

### Issue: Liquid Glass Looks Wrong

**Symptoms:**
- UI is fully opaque instead of translucent
- Materials don't blur background

**Solutions:**
1. **Check Reduce Transparency:** May be enabled
2. **Verify Material Names:** Ensure using correct materials
3. **Test on Device:** Simulator may not show effects accurately
4. **Update Xcode:** Ensure using latest with iOS 26 SDK
5. **Check Background:** Glass needs content behind it to show effect

---

## 📚 Apple Resources

### Official Documentation

1. **Foundation Models**
   - https://developer.apple.com/documentation/FoundationModels/
   - "Generating content and performing tasks with Foundation Models"
   - Sample code and best practices

2. **Writing Tools**
   - https://developer.apple.com/documentation/uikit/uitextview/writing-tools
   - "Integrate Writing Tools in your app"
   - Customization options

3. **Liquid Glass Design**
   - https://developer.apple.com/design/human-interface-guidelines/liquid-glass
   - Design principles and guidelines
   - Material usage recommendations

4. **Apple Intelligence**
   - https://developer.apple.com/apple-intelligence/
   - Overview and capabilities
   - Privacy and security

### WWDC 2025 Sessions (When Available)

- "What's New in iOS 26"
- "Meet Foundation Models"
- "Generating Content with Foundation Models"
- "Integrate Writing Tools in Your App"
- "Design with Liquid Glass"
- "Privacy and On-Device Machine Learning"

### Developer Forums

- Apple Developer Forums → iOS & iPadOS → Apple Intelligence
- Search for: Foundation Models, Writing Tools, Liquid Glass
- Look for sample code and solutions from Apple engineers

---

## 📋 Integration Checklist

Use this checklist when Apple releases the iOS 26 SDK:

### Pre-Integration
- [ ] Download Xcode 17+ with iOS 26 SDK
- [ ] Review Apple's Foundation Models documentation
- [ ] Watch relevant WWDC sessions
- [ ] Check for sample code from Apple

### Code Updates
- [ ] Update `FMClient.swift` with real API calls
- [ ] Verify `WritingTextEditor.swift` implementation
- [ ] Test `Theme.swift` materials on iOS 26
- [ ] Update tests with real device tests

### Testing
- [ ] Run all unit tests
- [ ] Complete manual testing checklist
- [ ] Test on multiple devices
- [ ] Verify offline functionality
- [ ] Check accessibility features

### Documentation
- [ ] Update README with real API details
- [ ] Document any API differences from spec
- [ ] Add screenshots of real Liquid Glass UI
- [ ] Update version numbers

### Deployment
- [ ] Build release version
- [ ] Test on TestFlight
- [ ] Submit to App Store
- [ ] Monitor crash reports

---

## 💡 Tips & Best Practices

### Foundation Models

1. **Keep Prompts Concise** - Shorter prompts = faster responses
2. **Use Appropriate Temperature** - Lower (0.2-0.5) for factual, higher (0.7-0.9) for creative
3. **Limit Token Output** - Set `maxTokens` to prevent overly long responses
4. **Handle Errors Gracefully** - Always have fallbacks
5. **Test Edge Cases** - Very long text, special characters, multiple languages

### Writing Tools

1. **Don't Override** - Let the system handle the UI
2. **Trust Apple's UX** - Their implementation is well-designed
3. **Test with Users** - See which tools they use most
4. **Provide Context** - Clear labels for what text does
5. **Monitor Feedback** - Track if users find tools helpful

### Liquid Glass

1. **Less is More** - Don't overuse translucency
2. **Test Legibility** - Ensure text is always readable
3. **Support Accessibility** - Always provide solid fallbacks
4. **Use System Materials** - Don't try to recreate them
5. **Consider Context** - Dense text needs solid backgrounds

---

## 🔄 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Current | Initial implementation with placeholders |
| 1.1.0 | TBD | Real Foundation Models integration |
| 1.2.0 | TBD | Verified Writing Tools implementation |
| 1.3.0 | TBD | Final Liquid Glass adjustments |

---

**Next Steps:**
1. Wait for Apple to release iOS 26 SDK
2. Follow this guide to integrate real APIs
3. Test thoroughly on actual devices
4. Submit to App Store

For questions or issues, refer to Apple's documentation or developer forums.
