# ADR 0001: MVVM Architecture Pattern

**Status:** Accepted

**Date:** 2025-11-14

**Deciders:** CardGenie Core Team

---

## Context

CardGenie is a native iOS 26+ study app built with SwiftUI. We needed to choose an architectural pattern that would:
- Work seamlessly with SwiftUI's declarative paradigm
- Support clear separation of concerns
- Enable comprehensive unit testing
- Scale well as features grow (AI, voice, scanning, etc.)
- Minimize boilerplate while maintaining clarity

Common iOS architecture patterns considered:
- **MVC (Model-View-Controller)**: Traditional iOS pattern, but tight coupling with UIKit
- **MVVM (Model-View-ViewModel)**: Natural fit for SwiftUI's state management
- **VIPER**: Over-engineered for a single-platform app
- **Redux/TCA**: Too opinionated, steep learning curve

## Decision

We will use **MVVM (Model-View-ViewModel)** as the primary architectural pattern for CardGenie.

### Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                        │
│              (Features/, Design/Components/)                │
│                  - Declarative UI                           │
│                  - State bindings via @Published            │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────────┐
│                   Business Logic Layer                      │
│  • Processors/ (content processing, flashcard generation)  │
│  • Intelligence/ (AI engines, FMClient, speech, vision)    │
│                  - Pure Swift classes                       │
│                  - @MainActor for UI updates                │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────────┐
│                     Data Layer (SwiftData)                  │
│  • Models with @Model macro                                │
│  • Store.swift (CRUD operations)                           │
│  • ModelContext for persistence                            │
└─────────────────────────────────────────────────────────────┘
```

### Key Characteristics

1. **Views** (`Features/`): SwiftUI views that observe state
2. **ViewModels/Processors**: Business logic in `Processors/` and `Intelligence/`
3. **Models**: SwiftData models with `@Model` macro
4. **Store**: Simple persistence layer over `ModelContext`

## Consequences

### Positive

✅ **Natural SwiftUI Integration**: `@Published`, `@ObservedObject`, `@StateObject` work seamlessly
✅ **Testability**: Business logic isolated from UI (86% test coverage achieved)
✅ **Clear Separation**: Data, logic, and presentation layers well-defined
✅ **Scalability**: 12 feature files, 11 intelligence modules organized cleanly
✅ **Maintainability**: New developers understand structure immediately
✅ **SwiftData Compatibility**: `@Model` macro integrates perfectly with MVVM

### Negative

⚠️ **Boilerplate**: Some repetition in state management across views
⚠️ **Learning Curve**: Junior developers need to understand reactive programming
⚠️ **State Synchronization**: Must be careful with multi-view state updates

### Mitigations

- Use `@Environment(\.modelContext)` for shared data access
- Centralize complex state in dedicated managers (`SpacedRepetitionManager`, `StudyStreakManager`)
- Document state flow clearly in CLAUDE.md
- Use `@MainActor` to ensure UI updates happen on main thread

## Alternatives Considered

### MVC (Model-View-Controller)
- **Rejected**: Designed for UIKit, not declarative SwiftUI
- Controllers would conflict with SwiftUI's state-driven views

### VIPER (View-Interactor-Presenter-Entity-Router)
- **Rejected**: Too much abstraction for a single-platform app
- Would create unnecessary files and indirection

### TCA (The Composable Architecture)
- **Rejected**: Steep learning curve, opinionated state management
- Redux-style actions/reducers add complexity without clear benefit

## Related Decisions

- [ADR 0002: SwiftData over Core Data](0002-swiftdata-over-core-data.md)
- [ADR 0004: Offline-First Design](0004-offline-first-design.md)

## References

- [Apple SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [MVVM Design Pattern](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93viewmodel)
- CardGenie Architecture Section in `CLAUDE.md`
