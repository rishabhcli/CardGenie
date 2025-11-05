# CardGenie Reference

Condensed technical reference for architecture, features, UI, API, and prompts. Full detail remains in `docs/archive/reference`.

## 1) Architecture

- Overview: Offline-first AI pipeline; modular processors (PDF/Image/Lecture); vector search + RAG.
- Data Models: SourceDocument, NoteChunk, LectureSession, Flashcard, FlashcardSet.
- AI Abstraction: `LLMEngine`, `EmbeddingEngine` with Apple on-device implementations.

Details:
- System Architecture: `docs/archive/reference/architecture/ARCHITECTURE.md`
- Offline Capabilities: `docs/archive/reference/architecture/OFFLINE_CAPABILITIES.md`
- Intelligence Implementation: `docs/archive/reference/architecture/APPLE_INTELLIGENCE_IMPLEMENTATION.md`
- SSC Vision/Plan: `docs/archive/reference/architecture/SSC_VISION_AND_PLAN.md`

## 2) Features

- Flashcards: SM-2 algorithm, three card types, daily review, stats.
- AI Chat & Assistant: On-device chat and floating assistant patterns.
- Media: Photo scanning (Vision OCR), planned audio/video processing.

Details: `docs/archive/reference/features/`

## 3) UI / Design

- Liquid Glass: Panels, overlays, content backgrounds; solid fallbacks per accessibility.
- Components: Search bar enhancements, cleanup summaries, critique notes.

Details: `docs/archive/reference/ui/`

## 4) API / References

- Foundation Models API (notes/specs): `docs/archive/reference/api/Foundation_Models_API_Reference.md`
- iOS 26 SDK notes: `docs/archive/reference/api/Apple iOS 26 SDK Documentation.md`

## 5) Intelligence Prompts

- Catalog: `docs/archive/reference/INTELLIGENCE_PROMPTS.md`
- Prompt files (in app bundle): `CardGenie/Intelligence/Prompts/`

