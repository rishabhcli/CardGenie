# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records for CardGenie - documents that capture important architectural decisions made during the project's development.

## What is an ADR?

An Architecture Decision Record (ADR) is a document that captures an important architectural decision made along with its context and consequences. ADRs help teams:
- Understand why decisions were made
- Onboard new team members
- Review past decisions when context is forgotten
- Avoid revisiting settled debates

## Format

Each ADR follows this structure:
- **Status**: Accepted, Proposed, Deprecated, Superseded
- **Date**: When the decision was made
- **Context**: The problem and constraints
- **Decision**: What was decided
- **Consequences**: Positive and negative outcomes
- **Alternatives Considered**: Other options evaluated

## Index of Decisions

### Core Architecture

- [ADR 0001: MVVM Architecture Pattern](0001-mvvm-architecture.md)
  - **Decision**: Use MVVM as primary architectural pattern
  - **Rationale**: Natural fit for SwiftUI, clear separation of concerns, excellent testability
  - **Date**: 2025-11-14

- [ADR 0002: SwiftData over Core Data](0002-swiftdata-over-core-data.md)
  - **Decision**: Use SwiftData for local persistence
  - **Rationale**: Modern Swift-first API, zero boilerplate, automatic migrations
  - **Date**: 2025-11-14

### Domain-Specific Decisions

- [ADR 0003: SM-2 Spaced Repetition Algorithm](0003-sm2-spaced-repetition.md)
  - **Decision**: Implement SM-2 algorithm for flashcard scheduling
  - **Rationale**: Proven effectiveness, simple implementation, 30+ years of validation
  - **Date**: 2025-11-14

### Design Philosophy

- [ADR 0004: Offline-First Design Philosophy](0004-offline-first-design.md)
  - **Decision**: 100% offline operation with zero network calls
  - **Rationale**: Absolute privacy, reliability, leverages Apple Intelligence on-device
  - **Date**: 2025-11-14

- [ADR 0005: iOS 26+ Minimum Version Requirement](0005-ios-26-minimum-version.md)
  - **Decision**: Require iOS 26.0 as minimum deployment target
  - **Rationale**: Essential for Apple Intelligence, Liquid Glass UI, modern APIs
  - **Date**: 2025-11-14

## Decision Timeline

```
2025-11-14: Initial ADRs created (0001-0005)
├── MVVM Architecture
├── SwiftData over Core Data
├── SM-2 Spaced Repetition
├── Offline-First Design
└── iOS 26+ Minimum Version
```

## Cross-References

### Related Documentation
- [CLAUDE.md](../../../CLAUDE.md) - Comprehensive development guide
- [TODO_ANALYSIS.md](../../TODO_ANALYSIS.md) - Project roadmap and task tracking
- [Session Summaries](../../) - Development session documentation

### Implementation Files
- **MVVM**: `Features/`, `Intelligence/`, `Data/`
- **SwiftData**: `Data/Models.swift`, `Data/Store.swift`
- **SM-2**: `Data/SpacedRepetitionManager.swift`, tests at 95% coverage
- **Offline-First**: `Intelligence/FMClient.swift`, no cloud dependencies
- **iOS 26+**: `CardGenie.xcodeproj` deployment target

## Contributing

When making significant architectural decisions:

1. **Create a new ADR** in this directory using the next number (e.g., `0006-decision-name.md`)
2. **Follow the standard format** (see existing ADRs for examples)
3. **Update this README** to include the new ADR in the index
4. **Cross-reference** related ADRs and documentation
5. **Commit with clear message**: `docs: Add ADR 0006 - [Decision Name]`

### ADR Template

```markdown
# ADR 00XX: [Decision Title]

**Status:** [Proposed|Accepted|Deprecated|Superseded]

**Date:** YYYY-MM-DD

**Deciders:** [Who made this decision]

---

## Context

[What is the issue we're trying to solve? What constraints exist?]

## Decision

[What is the change we're proposing/have made?]

## Consequences

### Positive
[Good outcomes from this decision]

### Negative
[Trade-offs and limitations]

## Alternatives Considered

[What other options were evaluated and why were they rejected?]

## Related Decisions

[Links to other ADRs that relate to this decision]

## References

[External documentation, research papers, etc.]
```

## Status Definitions

- **Proposed**: Decision is under consideration
- **Accepted**: Decision has been made and implemented
- **Deprecated**: Decision is no longer relevant but kept for historical context
- **Superseded**: Replaced by a newer decision (reference the new ADR)

---

**Last Updated**: 2025-11-14
**Total ADRs**: 5
**Status**: All Accepted ✅
