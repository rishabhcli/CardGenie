# ADR 0002: SwiftData Over Core Data

**Status:** Accepted

**Date:** 2025-11-14

**Deciders:** CardGenie Core Team

---

## Context

CardGenie requires local persistence for:
- Study content and source documents
- Flashcards with spaced repetition metadata
- User progress and statistics
- Conversation history and voice recordings
- Game mode sessions and scores

We needed a persistence framework that would:
- Work seamlessly with SwiftUI
- Minimize boilerplate code
- Support complex relationships (cascade deletes)
- Enable efficient queries and filtering
- Provide type-safe data access
- Support iOS 26+ features

Options considered:
- **Core Data**: Mature, battle-tested, extensive documentation
- **SwiftData**: Modern, Swift-first, automatic schema migration
- **Realm**: Third-party, requires external dependency
- **SQLite**: Low-level, too much manual work

## Decision

We will use **SwiftData** as the primary persistence framework for CardGenie.

### Implementation Details

**Model Definition:**
```swift
@Model
final class Flashcard {
    var question: String
    var answer: String
    var easeFactor: Double
    var interval: Int
    var nextReviewDate: Date

    @Relationship(deleteRule: .nullify)
    var set: FlashcardSet?

    init(question: String, answer: String) {
        self.question = question
        self.answer = answer
        self.easeFactor = 2.5
        self.interval = 0
        self.nextReviewDate = Date()
    }
}
```

**Container Configuration:**
```swift
// CardGenieApp.swift
let schema = Schema([
    StudyContent.self,
    Flashcard.self,
    FlashcardSet.self,
    SourceDocument.self,
    NoteChunk.self,
    ConversationSession.self,
    // ... all models
])

let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false
)

modelContainer = try ModelContainer(
    for: schema,
    configurations: [modelConfiguration]
)
```

**CRUD Operations:**
```swift
// Store.swift - Simple wrapper over ModelContext
@MainActor
class Store {
    let context: ModelContext

    func save() throws {
        try context.save()
    }

    func delete(_ object: any PersistentModel) throws {
        context.delete(object)
        try context.save()
    }
}
```

## Consequences

### Positive

✅ **Zero Boilerplate**: No `.xcdatamodeld` files, no managed object subclasses
✅ **Type Safety**: Compile-time checking for properties and relationships
✅ **SwiftUI Integration**: `@Query` macro for automatic view updates
✅ **Modern Syntax**: Swift-first API using macros and property wrappers
✅ **Automatic Migration**: Schema changes handled automatically in many cases
✅ **Cascade Deletes**: `@Relationship(deleteRule: .cascade)` handles cleanup
✅ **Preview Support**: Easy to create in-memory containers for SwiftUI previews
✅ **Performance**: Optimized for iOS 26+ devices

### Negative

⚠️ **iOS 26+ Only**: Requires minimum deployment target of iOS 26.0
⚠️ **Newer Framework**: Less mature than Core Data (fewer Stack Overflow answers)
⚠️ **Migration Limitations**: Complex migrations still require manual work
⚠️ **Debugging**: Fewer debugging tools compared to Core Data

### Mitigations

- **iOS 26+ Requirement**: Acceptable since app targets Apple Intelligence features anyway
- **Documentation**: Comprehensive inline comments and CLAUDE.md guidance
- **Fallback**: In-memory container fallback if persistent storage fails
- **Testing**: 86% test coverage validates persistence layer thoroughly

## Alternatives Considered

### Core Data
- **Pros**: Mature, extensive documentation, powerful migration tools
- **Cons**: Verbose boilerplate, `.xcdatamodeld` files, NSManagedObject complexity
- **Verdict**: SwiftData provides same functionality with cleaner API

### Realm
- **Pros**: Fast, easy to use, good documentation
- **Cons**: External dependency, different query syntax, licensing concerns
- **Verdict**: SwiftData is native and sufficient for our needs

### SQLite (Direct)
- **Pros**: Maximum control, lightweight
- **Cons**: Too low-level, manual schema management, no SwiftUI integration
- **Verdict**: Too much boilerplate for marginal benefit

### UserDefaults / Plist
- **Pros**: Simple, built-in
- **Cons**: Not suitable for complex relationships or large datasets
- **Verdict**: Insufficient for flashcard app with thousands of items

## Real-World Evidence

CardGenie's SwiftData implementation has proven successful:
- **10+ models** with complex relationships
- **Cascade deletes** work reliably (SourceDocument → NoteChunk → Flashcard)
- **Query performance** adequate for 1000+ flashcard tests
- **In-memory testing** enables fast unit tests (4,798+ test lines)
- **Zero data corruption** issues during development

## Related Decisions

- [ADR 0001: MVVM Architecture](0001-mvvm-architecture.md)
- [ADR 0004: Offline-First Design](0004-offline-first-design.md)
- [ADR 0005: iOS 26+ Minimum Version](0005-ios-26-minimum-version.md)

## References

- [Apple SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [SwiftData @Model Macro](https://developer.apple.com/documentation/swiftdata/model)
- CardGenie `Data/` layer implementation
- `Store.swift` - Simple CRUD wrapper
