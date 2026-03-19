# Offline Reliability Hardening

## Summary

This change hardens CardGenie as an iOS 26-only, offline-only app. It removes the old speculative compatibility paths, makes persistence failures recoverable, persists pending scan work across relaunches, improves local retrieval quality, and aligns AI availability messaging across the product.

## Changes

- Added explicit app bootstrap and persistence modes with non-crashing degraded startup behavior.
- Added `PendingScanJob` and migrated the offline scan queue from `UserDefaults` to SwiftData-backed jobs.
- Standardized AI availability and safety messaging through `FMClient` so chat, voice, scanning, and content generation report unsupported states consistently.
- Added embedding freshness metadata and bounded vector retrieval candidate filtering.
- Added citation-aware grounding for chat and voice flows when local source material exists.
- Added duplicate filtering and retry queueing to the scan-to-flashcard flow.
- Added a launch summary and persisted “resume study session” path for the flashcard review loop.
- Removed the main iOS-25-era fallback branches from app chrome and core study UI.
- Updated `README.md`, `AGENTS.md`, and `CLAUDE.md` to match the iOS 26 offline-only implementation.

## Validation

- `xcodebuild -project CardGenie.xcodeproj -scheme CardGenie -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' build`

## Notes

- The build succeeds after the hardening changes.
- Some pre-existing warnings remain, but there are no blocking compile errors in this pass.
