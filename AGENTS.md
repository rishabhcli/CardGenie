# Repository Guidelines

## Project Structure & Module Organization
- Primary code lives in `CardGenie/`. `App/` hosts `CardGenieApp.swift` and app-level setup, `Features/` contains SwiftUI screens, `Data/` holds SwiftData models and persistence, `Intelligence/` wraps Apple Intelligence integrations, and `Design/` delivers theming components. Assets remain in `Assets.xcassets`.
- Tests live in `CardGenieTests/` for unit coverage and `CardGenieUITests/` for UI flows. Keep shared fixtures alongside the tests that consume them.

## Build, Test, and Development Commands
- Build: `xcodebuild -scheme CardGenie -destination 'generic/platform=iOS' build` to confirm the project compiles with Xcode 17 + iOS 17.5 SDK.
- Unit tests: `xcodebuild test -scheme CardGenie -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5'`.
- Open in Xcode: `open CardGenie.xcodeproj` for SwiftUI previews and asset tuning.
- Prefer the preview canvas for iterating on Liquid Glass visuals; avoid adding throwaway preview data to production targets.

## Coding Style & Naming Conventions
- Follow Swift API Design Guidelines. Use UpperCamelCase for types, camelCase for functions/properties, and capitalize enums.
- Indent with 4 spaces, keep one primary SwiftUI view per file, and group extensions using `// MARK:` comments.
- Place shared view components in `Design/Components` and flag placeholder Apple Intelligence logic with `// TODO(iOS26):`.

## Testing Guidelines
- Mirror target files with `Tests` suffix counterparts (e.g., `StoreTests.swift`). Favor focused methods such as `testJournalEntryCreation()`.
- Cover SwiftData persistence and FMClient fallbacks, especially offline scenarios. No logging of journal content or prompts in tests.
- Run the full suite via the `xcodebuild test` command before submitting.

## Commit & Pull Request Guidelines
- Use short, imperative commit messages (e.g., `Add onboarding glass effect`). Reference tickets or docs in the body when useful.
- Pull requests should summarize the change, call out affected screens/services, link tracking issues, and attach simulator screenshots or brief recordings for UI shifts.
- Highlight any placeholder Apple Intelligence behavior so reviewers can verify gating and privacy handling.

## Apple Intelligence & Privacy
- Ensure features degrade gracefully when Apple Intelligence is unavailable and keep the app offline-first.
- Never log raw journal entries or prompt text. Update `Intelligence/FMClient.swift` docs if API usage shifts and confirm settings screens communicate privacy posture clearly.
