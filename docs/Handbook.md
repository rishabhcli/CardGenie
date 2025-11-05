# CardGenie Handbook

A condensed, practical guide for setup, implementation, and daily workflows. Full detail remains in `docs/archive/handbook` and `docs/archive/overview`.

## 1) Getting Started

- Requirements: Xcode 17+, iOS 26 SDK, iPhone 15 Pro+ (for Apple Intelligence).
- Open project: `CardGenie.xcodeproj` and set deployment to iOS 26.0.
- Build & run on device; AI features work with placeholders until iOS 26 SDK.

## 2) Implementation Summary

- Architecture: MVVM, SwiftUI + SwiftData, offline-first design.
- Intelligence: On-device Foundation Models for summarization, tags, reflections.
- Flashcards: SM-2 spaced repetition; Q&A, Cloze, Definition types.
- Liquid Glass UI: Translucent materials with accessibility fallbacks.

Reference: `docs/archive/overview/IMPLEMENTATION_SUMMARY.md`

## 3) UX Plan (iOS 26)

- Voice-first interactions, Liquid Glass patterns, accessibility-first.
- Tabs: Journal and Flashcards with AI generation flows.

Reference: `docs/archive/overview/UX_IMPLEMENTATION_PLAN_iOS26.md`

## 4) Guides

- Implementation Guide: `docs/archive/handbook/IMPLEMENTATION_GUIDE.md`
- Camera Permissions: `docs/archive/handbook/CAMERA_PERMISSIONS_SETUP.md`
- Microphone Permissions: `docs/archive/handbook/MICROPHONE_PERMISSIONS_SETUP.md`

## 5) Daily Use Checklist

- Journal: create → write → summarize → tags → reflect.
- Flashcards: generate from entries → review daily (Again/Good/Easy).
- Accessibility: test Reduce Motion/Transparency and Dynamic Type.

## 6) Build & Test

- Build: `xcodebuild -scheme CardGenie -destination 'generic/platform=iOS' build`
- Unit tests: `xcodebuild test -scheme CardGenie -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5'`

## 7) Apple Intelligence Integration (when SDK available)

- Replace placeholders in `FMClient.swift` with real `FoundationModels` API.
- Verify Writing Tools API names/flags on iOS 26.

Details: `docs/archive/reference/architecture/APPLE_INTELLIGENCE_IMPLEMENTATION.md`

## 8) Privacy & Offline

- 100% offline; no analytics, no network calls, local SwiftData.
- Ensure graceful degradation when Intelligence unavailable.

