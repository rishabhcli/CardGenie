# Repository Guidelines

## Project Structure & Module Organization
Primary source files live under `CardGenie/`. `App/` hosts `CardGenieApp.swift` and high-level configuration, `Features/` contains SwiftUI screens, `Data/` stores SwiftData models and persistence, `Intelligence/` wraps Apple Intelligence integrations, and `Design/` defines theming components. Shared assets stay in `Assets.xcassets`. Unit targets sit in `CardGenieTests/`, while UI flows belong to `CardGenieUITests/`.

## Build, Test, and Development Commands
Use Xcode 17+ and the iOS 26 SDK. Open the project with `open CardGenie.xcodeproj`. For command-line builds, run `xcodebuild -scheme CardGenie -destination 'generic/platform=iOS' build`. Execute unit tests with `xcodebuild test -scheme CardGenie -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5'`. When iterating on SwiftUI previews, prefer Xcode's preview canvas to confirm Liquid Glass visuals.

## Coding Style & Naming Conventions
Follow Swift API Design Guidelines: camelCase for functions and properties, UpperCamelCase for types, and capitalized enums. Use 4-space indentation and group related extensions with `// MARK:` comments. Keep SwiftUI view files focused (one primary view per file) and favor small, composable view structs in `Design/Components`. When touching placeholder Apple Intelligence code, clearly flag TODOs with `// TODO(iOS26):`.

## Testing Guidelines
Write SwiftData and AI integration tests in `CardGenieTests/`, mirroring filenames with a `Tests` suffix (e.g., `StoreTests.swift`). UI flows belong in `CardGenieUITests/` with scenario-focused methods such as `testJournalEntryCreation()`. Run the full suite via `xcodebuild test` before submitting changes and target coverage for new logic, especially around persistence and FMClient behavior.

## Commit & Pull Request Guidelines
Use short, imperative commit messages (`Add onboarding glass effect`). Reference related docs or ticket IDs in the body when helpful. Pull requests should summarize the change, note impacted screens or services, link to tracking issues, and include simulator screenshots or short screen recordings when UI shifts. Call out any placeholder Apple Intelligence behavior so reviewers can validate gating logic.

## Apple Intelligence & Privacy Notes
Never log raw journal content or AI prompts. Validate that new features respect the offline-first contract and degrade gracefully when Apple Intelligence is unavailable. Update `Intelligence/FMClient.swift` docs if API expectations shift, and confirm settings screens clearly communicate privacy posture.
