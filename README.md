# CardGenie

CardGenie is an iOS 26-only flashcard and study app built around local-first storage and on-device AI. Notes, scans, flashcards, study history, and AI-assisted flows stay on the device. The app does not rely on network services, analytics, or cloud sync.

## Product Focus

- Generate flashcards from text, scans, PDFs, handwriting, and lecture notes.
- Study with spaced repetition, game modes, chat, voice tutoring, and conversational learning.
- Use Apple’s on-device models when the current device and language support them.
- Fall back honestly when on-device AI is unavailable instead of implying a cloud dependency.

## Reliability Model

Recent hardening work focuses on making the offline contract explicit and recoverable:

- The app is treated as iOS 26-only throughout the UI and runtime.
- App bootstrap now uses explicit runtime states: `ready`, `degradedInMemory`, and `unavailable`.
- Persistence failures no longer crash the app; temporary in-memory mode is surfaced in the UI.
- Pending scan jobs are stored in SwiftData and resume across relaunches.
- AI capability messaging is shared across chat, voice, content generation, and study assistance.
- Retrieval uses embedding freshness metadata and bounded candidate selection instead of naive fetch-all ranking.
- The flashcard flow now surfaces a due-now summary and can resume the last unfinished study session.

## Requirements

- Xcode 17 or later
- iOS 26 SDK
- Deployment target: iOS 26.0
- A device or language configuration supported by Apple’s on-device models for AI-heavy features

CardGenie remains usable without the on-device model. Manual study flows, scanning, browsing, editing, and spaced-repetition review remain local.

## Build

```bash
# Generic simulator build
xcodebuild -project CardGenie.xcodeproj -scheme CardGenie -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build

# Discover a concrete iOS 26.x simulator when you want to run locally
xcrun simctl list devices available | rg 'iOS 26'
```

The current hardening pass was validated with:

```bash
xcodebuild -project CardGenie.xcodeproj -scheme CardGenie -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' build
```

## Architecture

- `CardGenie/App`: app bootstrap, runtime state, permissions, intents
- `CardGenie/Data`: SwiftData models, vector storage, spaced repetition, exporters
- `CardGenie/Processors`: scan, OCR, PDF, lecture, and flashcard generation pipelines
- `CardGenie/Intelligence`: Foundation Models integration, safety handling, retrieval, prompts, session management
- `CardGenie/Features`: SwiftUI screens for study, flashcards, scanning, voice, chat, content generation, and settings
- `CardGenie/Design`: Liquid Glass styling, reusable components, motion helpers

## Privacy

- No network API is required at runtime
- No analytics or telemetry
- No cloud sync
- No server-side AI fallback
- All user data stays in local app storage

## Notes for Contributors

- Treat the app as iOS 26-only.
- Keep unavailable AI states explicit and local.
- Prefer resilient degradation over crashes.
- Do not reintroduce checked-in docs trees or build logs.
