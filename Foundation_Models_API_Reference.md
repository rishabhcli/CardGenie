# Foundation Models API Reference - iOS 26

**Based on official Apple documentation and WWDC 2025 sessions**

## Overview

The Foundation Models framework provides direct access to Apple's on-device language models. All processing happens locally on the Neural Engine with zero network calls.

## System Requirements

- **Development**: Xcode 26+, macOS Tahoe
- **Deployment**: iOS 26+, iPadOS 26+, macOS 26+
- **Hardware**: Apple Silicon (iPhone 15 Pro+, M1+ Macs)

## Core API Components

### 1. SystemLanguageModel - Capability Detection

```swift
import FoundationModels

let model = SystemLanguageModel.default

// Check availability
switch model.availability {
case .available:
    // Foundation Models ready to use
case .unavailable(.appleIntelligenceNotEnabled):
    // Show "Enable Apple Intelligence in Settings"
case .unavailable(.modelNotReady):
    // Show "Model is loading..."
case .unavailable(.deviceNotEligible):
    // Show "Requires iPhone 15 Pro or newer"
}

// Convenience property
if model.isAvailable {
    // Quick boolean check
}
```

### 2. LanguageModelSession - Main Interface

```swift
// Basic initialization with trailing closure
let session = LanguageModelSession {
    """
    You are a helpful assistant.
    Provide concise, accurate responses.
    """
}

// With tools for function calling
let session = LanguageModelSession(tools: [myTool]) {
    "System instructions here..."
}
```

### 3. Basic Text Generation

```swift
// Simple text response
let response = try await session.respond(to: "Summarize this text: ...")
print(response.content) // String

// With generation options
let options = GenerationOptions(
    sampling: .greedy,      // Deterministic
    temperature: 0.3        // 0.0-1.0, lower = focused
)

let response = try await session.respond(
    to: prompt,
    options: options
)
```

### 4. Structured Output with @Generable

```swift
@Generable
struct Summary {
    @Guide(description: "A brief summary in 2-3 sentences")
    let summary: String

    @Guide(description: "Key topics mentioned", .range(1...5))
    let topics: [String]

    @Guide(description: "Sentiment: positive, neutral, or negative")
    let sentiment: Sentiment
}

@Generable
enum Sentiment: String, Codable {
    case positive, neutral, negative
}

// Generate structured output
let response = try await session.respond(
    to: "Analyze this journal entry: \(text)",
    generating: Summary.self,
    options: options
)

print(response.content.summary)
print(response.content.topics)
print(response.content.sentiment)
```

### 5. Streaming Responses

```swift
// Stream plain text
let stream = session.streamResponse(to: "Write a story...") {
    "You are a creative writer."
}

for try await partialResponse in stream {
    updateUI(with: partialResponse.content)
}

// Stream structured output
let stream = session.streamResponse(
    to: "Generate flashcards...",
    generating: FlashcardSet.self
)

for try await partial in stream {
    // partial is FlashcardSet.PartiallyGenerated
    if let cards = partial.cards {
        updateUI(with: cards)
    }
}
```

### 6. Custom Tools (Function Calling)

```swift
struct SearchTool: Tool {
    let database: ContentDatabase

    var name = "searchContent"
    var description = "Search user's notes and study materials"

    @Generable
    struct Arguments {
        @Guide(description: "Keywords to search for")
        let keywords: [String]

        @Guide(description: "Limit results", .range(1...20))
        let limit: Int
    }

    nonisolated func call(arguments: Arguments) async throws -> ToolOutput {
        let results = try await database.search(
            keywords: arguments.keywords,
            limit: arguments.limit
        )
        return ToolOutput(results.formatted())
    }
}

// Register tool with session
let session = LanguageModelSession(tools: [SearchTool(database: db)]) {
    "When user asks about their notes, use searchContent tool."
}
```

### 7. Error Handling

```swift
do {
    let response = try await session.respond(to: prompt)
    // Process response

} catch LanguageModelSession.GenerationError.guardrailViolation {
    // Content violated safety policies
    showAlert("Request blocked by safety guardrails")

} catch LanguageModelSession.GenerationError.refusal {
    // Model declined to respond
    showAlert("Unable to process this request")

} catch {
    // Other errors (system, timeout, etc.)
    showAlert("Generation failed: \(error.localizedDescription)")
}
```

### 8. Performance Optimization

```swift
// Prewarm model for faster first response
await session.prewarm()

// Call when you know user will likely use AI features
// Example: When entering editor view
.onAppear {
    Task {
        await aiSession.prewarm()
    }
}
```

## @Guide Macro Options

```swift
@Generable
struct Example {
    // Basic description
    @Guide(description: "User's name")
    let name: String

    // Range constraint for numbers
    @Guide(description: "Age in years", .range(1...120))
    let age: Int

    // Array length constraint
    @Guide(description: "Favorite colors", .range(1...5))
    let colors: [String]

    // Enum for constrained options
    @Guide(description: "Preferred contact method")
    let contactMethod: ContactMethod
}

@Generable
enum ContactMethod: String, Codable {
    case email, phone, sms
}
```

## Temperature Guidelines

```swift
// 0.0 - 0.3: Factual, deterministic
// Best for: Summaries, tags, classifications, data extraction
GenerationOptions(sampling: .greedy, temperature: 0.2)

// 0.4 - 0.7: Balanced
// Best for: Q&A, reflections, general assistance
GenerationOptions(sampling: .greedy, temperature: 0.6)

// 0.8 - 1.0: Creative, diverse
// Best for: Stories, brainstorming, open-ended generation
GenerationOptions(sampling: .greedy, temperature: 0.9)
```

## Token Limits

- **Combined input + output**: 4096 tokens maximum
- **1 token ≈ 4 characters** (rough estimate)
- **Truncate long inputs** to leave room for output

## Best Practices

### Prompt Engineering

```swift
// ✅ Good: Clear, specific, with constraints
"""
Summarize this journal entry in exactly 3 sentences.
Maintain first-person perspective.
Focus on key events and emotions.
"""

// ❌ Bad: Vague, open-ended
"""
Tell me about this text.
"""
```

### System Instructions

```swift
// ✅ Good: Define role, style, and constraints
"""
You are CardGenie, a supportive study coach.
Generate encouraging feedback in 1-2 sentences.
Use a warm, positive tone.
Celebrate effort and progress.
"""

// ❌ Bad: Minimal context
"""
Be helpful.
"""
```

### Property Ordering in @Generable

```swift
@Generable
struct FlashcardSet {
    // Independent properties first
    let topic: String
    let difficulty: Difficulty

    // Dependent properties last
    // (cards depend on topic and difficulty)
    let cards: [Flashcard]
}
```

### Error Recovery

```swift
func generateSummaryWithFallback(_ text: String) async -> String {
    do {
        return try await fmClient.summarize(text)
    } catch LanguageModelSession.GenerationError.guardrailViolation {
        // Sensitive content detected
        return "Unable to summarize this content."
    } catch {
        // Use local fallback
        return extractFirstTwoSentences(text)
    }
}
```

## SwiftUI Integration Pattern

```swift
struct ContentDetailView: View {
    @State private var summary: String = ""
    @State private var isGenerating = false

    let fmClient = FMClient()
    let content: StudyContent

    var body: some View {
        VStack {
            Text(content.displayText)

            if isGenerating {
                ProgressView("Generating summary...")
            } else if !summary.isEmpty {
                Text(summary)
                    .foregroundColor(.secondary)
            }

            Button("Generate Summary") {
                Task {
                    await generateSummary()
                }
            }
            .disabled(isGenerating)
        }
    }

    func generateSummary() async {
        guard fmClient.capability() == .available else {
            // Show alert: "Apple Intelligence not available"
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        do {
            summary = try await fmClient.summarize(content.displayText)
        } catch {
            // Show error alert
            print("Summary generation failed: \(error)")
        }
    }
}
```

## Migration Guide for CardGenie's FMClient.swift

### Changes Required

1. **Update session initialization** - Use trailing closure syntax
2. **Add @Generable structs** - For structured output (tags, etc.)
3. **Add .refusal error case** - Handle model refusals
4. **Consider prewarm()** - Add to improve first-response latency

### Example: Updated tags() Method

```swift
@Generable
private struct JournalTags {
    @Guide(description: "1-3 short topic tags (1-2 words each)")
    let tags: [String]
}

func tags(for text: String) async throws -> [String] {
    #if canImport(FoundationModels)
    guard #available(iOS 26.0, *) else {
        throw FMError.unsupportedOS
    }

    let model = SystemLanguageModel.default
    guard case .available = model.availability else {
        throw FMError.modelUnavailable
    }

    do {
        let session = LanguageModelSession {
            """
            Extract up to 3 short topic tags from text.
            Each tag should be 1-2 words.
            Examples: work, planning, travel, health
            """
        }

        let options = GenerationOptions(
            sampling: .greedy,
            temperature: 0.2
        )

        let response = try await session.respond(
            to: "Extract tags from:\n\n\(text)",
            generating: JournalTags.self,
            options: options
        )

        return response.content.tags

    } catch LanguageModelSession.GenerationError.guardrailViolation {
        throw FMError.processingFailed
    } catch LanguageModelSession.GenerationError.refusal {
        throw FMError.processingFailed
    } catch {
        throw FMError.processingFailed
    }
    #else
    return fallbackTags(for: text)
    #endif
}
```

## References

- Apple Developer Documentation: https://developer.apple.com/documentation/FoundationModels
- WWDC 2025 Session 286: "Meet the Foundation Models framework"
- WWDC 2025 Session 301: "Deep dive into the Foundation Models framework"
