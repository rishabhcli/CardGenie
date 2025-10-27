# CardGenie Flashcard System - Implementation Tracking Tickets

## Overview
This document tracks the implementation of the comprehensive flashcard system across 6 phases. Each ticket includes acceptance criteria, implementation notes, and dependencies.

---

## Phase 1: Solidify Baseline Flow

### Ticket F1.1: Wire up Flashcard Generation Pipeline
**Priority:** HIGH
**Status:** IN PROGRESS
**Estimate:** 2 hours

**Description:**
Complete integration between StudyContent → NoteChunk → FlashcardGenerator → FlashcardSet. Ensure users can generate flashcards from any study material and immediately access them in FlashcardListView.

**Acceptance Criteria:**
- [ ] Flashcard generation button visible in ContentDetailView or equivalent
- [ ] Generated flashcards appear in FlashcardListView grouped by topic
- [ ] Cards include proper source linking (linkedEntryID) back to original content
- [ ] Success/error feedback shown to user during generation
- [ ] Generated cards persist across app restarts

**Implementation Notes:**
- Location: `CardGenie/Features/FlashcardListView.swift:14`
- Location: `CardGenie/Processors/FlashcardGenerator.swift:14`
- Add generation trigger to content detail views
- Ensure ModelContext properly saves after generation

**Dependencies:** None

---

### Ticket F1.2: Add Due-Count Badges to Tab Bar
**Priority:** MEDIUM
**Status:** NOT STARTED
**Estimate:** 1 hour

**Description:**
Display due flashcard count as a badge on the Flashcards tab in MainTabView. Badge should update dynamically and be visible at all times.

**Acceptance Criteria:**
- [ ] Due count badge appears on Flashcards tab when count > 0
- [ ] Badge disappears when count = 0
- [ ] Badge updates automatically when cards are reviewed
- [ ] Badge count matches totalDueCount calculation
- [ ] Badge is accessible to VoiceOver users

**Implementation Notes:**
- Location: `CardGenie/App/CardGenieApp.swift:95-111` (already partially implemented!)
- Enhancement needed: Ensure badge updates in real-time without app restart
- Consider using @Query to auto-update

**Dependencies:** None

---

### Ticket F1.3: Integrate NotificationManager for Daily Reminders
**Priority:** MEDIUM
**Status:** NOT STARTED
**Estimate:** 2 hours

**Description:**
Wire NotificationManager into flashcard workflow. Schedule notifications based on due cards, allow users to configure notification times, handle notification taps to open study view.

**Acceptance Criteria:**
- [ ] Notifications requested on first flashcard creation
- [ ] Daily notification scheduled at user-preferred time (default 9 AM)
- [ ] Notification body includes accurate due count
- [ ] Tapping notification opens FlashcardStudyView with due cards
- [ ] Badge count updates on app icon
- [ ] Settings screen allows configuring notification time
- [ ] "Remind Me Later" action works correctly

**Implementation Notes:**
- Location: `CardGenie/Intelligence/NotificationManager.swift:14`
- Location: `CardGenie/Features/FlashcardListView.swift:355-360` (already has updateAllNotifications!)
- Add settings UI for notification preferences
- Implement UNUserNotificationCenterDelegate in App

**Dependencies:** F1.1 (need flashcards first)

---

### Ticket F1.4: Add Smoke Tests for Core Functionality
**Priority:** HIGH
**Status:** NOT STARTED
**Estimate:** 3 hours

**Description:**
Create integration and unit tests covering SM-2 scheduling, deck creation, and notification scheduling. Build on existing SpacedRepetitionTests.

**Acceptance Criteria:**
- [ ] Test: Flashcard generation creates valid cards
- [ ] Test: Deck creation and card association
- [ ] Test: Notification scheduling with accurate due counts
- [ ] Test: SM-2 algorithm edge cases (existing tests at `CardGenieTests/SpacedRepetitionTests.swift:14` are comprehensive)
- [ ] Test: Badge count calculation accuracy
- [ ] All tests pass on CI

**Implementation Notes:**
- Location: Create `CardGenieTests/FlashcardGenerationTests.swift`
- Location: Create `CardGenieTests/NotificationTests.swift`
- Use existing SpacedRepetitionTests as template
- Mock NotificationManager for testing

**Dependencies:** F1.1, F1.3

---

### Ticket F1.5: Add Quick Actions to FlashcardListView
**Priority:** LOW
**Status:** NOT STARTED
**Estimate:** 1 hour

**Description:**
Enhance FlashcardListView with quick action buttons for common tasks (study all due, update reminders, view stats).

**Acceptance Criteria:**
- [ ] "Study All Due" button prominently displayed when due count > 0
- [ ] Quick access to statistics view
- [ ] Menu with secondary actions (update reminders, settings)
- [ ] Actions disabled appropriately (e.g., study disabled when no due cards)
- [ ] Haptic feedback on button taps

**Implementation Notes:**
- Location: `CardGenie/Features/FlashcardListView.swift:60-78` (already implemented!)
- Enhancement: Add haptic feedback
- Enhancement: Add more quick actions based on user feedback

**Dependencies:** None

---

## Phase 2: Make Decks Manageable

### Ticket F2.1: Create FlashcardEditorView for Manual Card Creation
**Priority:** HIGH
**Status:** NOT STARTED
**Estimate:** 4 hours

**Description:**
Build dedicated editor view allowing users to manually create and edit flashcards. Support all card types (Q&A, Cloze, Definition).

**Acceptance Criteria:**
- [ ] Form with fields for question, answer, type, tags
- [ ] Type picker (Q&A / Cloze / Definition)
- [ ] Tag input with suggestions based on existing tags
- [ ] Set/deck selector
- [ ] Preview of card before saving
- [ ] Validation (non-empty question/answer)
- [ ] Accessible with VoiceOver
- [ ] Keyboard shortcuts for save (Cmd+S)

**Implementation Notes:**
- Create: `CardGenie/Features/Flashcards/FlashcardEditorView.swift`
- Use existing Components.swift design patterns
- Apply glassPanel styling for consistency
- Consider reusable CardFormView component

**Dependencies:** None

---

### Ticket F2.2: Add Edit Capability to Existing Cards
**Priority:** MEDIUM
**Status:** NOT STARTED
**Estimate:** 2 hours

**Description:**
Allow editing existing flashcards from study view and list view. Preserve spaced repetition metadata during edits.

**Acceptance Criteria:**
- [ ] Edit button on FlashcardCardView
- [ ] Edits preserve reviewCount, easeFactor, interval
- [ ] Edits update lastModified timestamp
- [ ] Cancel/Save confirmation
- [ ] Changes sync immediately to list view

**Implementation Notes:**
- Location: Modify `CardGenie/Features/FlashcardStudyView.swift:12`
- Location: Modify `CardGenie/Design/Components.swift:514` (FlashcardCardView)
- Add navigation to FlashcardEditorView in edit mode
- Pass existing card data to form

**Dependencies:** F2.1

---

### Ticket F2.3: Implement Tagging, Sorting, and Filtering
**Priority:** MEDIUM
**Status:** NOT STARTED
**Estimate:** 3 hours

**Description:**
Add comprehensive tagging system with filtering and sorting options in FlashcardListView.

**Acceptance Criteria:**
- [ ] Tag chips displayed on FlashcardSetRow
- [ ] Filter by tag (multi-select)
- [ ] Sort options: Name, Date Created, Due Count, Success Rate
- [ ] Search filters by tag and topic label
- [ ] Filter/sort state persists across sessions
- [ ] Tag autocomplete in editor

**Implementation Notes:**
- Location: `CardGenie/Features/FlashcardListView.swift:244-252` (already has basic search!)
- Enhancement: Add tag filter chips above list
- Enhancement: Add sort menu in toolbar
- Use @AppStorage for persistence

**Dependencies:** None

---

### Ticket F2.4: Implement Bulk Actions with Undo
**Priority:** MEDIUM
**Status:** NOT STARTED
**Estimate:** 3 hours

**Description:**
Add bulk selection mode for flashcard sets. Support archive, delete, tag modification, and deck merging with undo capability.

**Acceptance Criteria:**
- [ ] Multi-select mode toggle in toolbar
- [ ] Select/deselect individual sets
- [ ] Select all / deselect all
- [ ] Bulk actions: Archive, Delete, Change Tags, Merge Sets
- [ ] Undo toast appears after action
- [ ] Undo restores exact previous state using ModelContext
- [ ] Confirmation dialog for destructive actions

**Implementation Notes:**
- Location: Modify `CardGenie/Features/FlashcardListView.swift:12`
- Use ModelContext transactions for atomic operations
- Implement UndoManager wrapper for FlashcardSet changes
- Store pre-action state for undo

**Dependencies:** F2.3 (tagging)

---

## Phase 3: Upgrade Study Experience

### Ticket F3.1: Build Session Builder for Study Modes
**Priority:** HIGH
**Status:** NOT STARTED
**Estimate:** 4 hours

**Description:**
Create session configuration screen allowing users to customize study sessions (new only, due only, mixed, custom counts).

**Acceptance Criteria:**
- [ ] Session builder modal before starting study
- [ ] Mode selection: New Only, Due Only, Mixed, Custom
- [ ] Card count sliders (max new, max review)
- [ ] Estimated time display
- [ ] Quick start defaults (skip builder, use smart defaults)
- [ ] Settings remembered for next session

**Implementation Notes:**
- Create: `CardGenie/Features/Flashcards/SessionBuilderView.swift`
- Modify: `CardGenie/Features/FlashcardListView.swift:305-326` (study session start)
- Use SpacedRepetitionManager.getStudySession with configurable params
- Apply glassPanel design

**Dependencies:** None

---

### Ticket F3.2: Enhance Review UI with Advanced Controls
**Priority:** MEDIUM
**Status:** NOT STARTED
**Estimate:** 4 hours

**Description:**
Add flip/peek controls, confidence meter, keyboard shortcuts, and haptic feedback to FlashcardStudyView.

**Acceptance Criteria:**
- [ ] Flip animation on tap (already exists!)
- [ ] Peek mode (partially reveal answer without full flip)
- [ ] Confidence slider (0-100%) in addition to Again/Good/Easy
- [ ] Keyboard shortcuts: Space (flip), 1/2/3 (rate), Esc (exit)
- [ ] Haptic feedback on flip and rating
- [ ] Show estimated next review date for each rating
- [ ] Progress bar with percentage (already exists at `FlashcardStudyView.swift:65-71`)

**Implementation Notes:**
- Location: `CardGenie/Features/FlashcardStudyView.swift:12`
- Location: `CardGenie/Design/Components.swift:648` (ReviewButton)
- Add .onKeyPress modifiers for shortcuts
- Use UIImpactFeedbackGenerator for haptics
- Show preview of next review dates using SpacedRepetitionManager.estimateNextReview

**Dependencies:** None

---

### Ticket F3.3: Add Rich Session Summaries
**Priority:** MEDIUM
**Status:** NOT STARTED
**Estimate:** 2 hours

**Description:**
Enhance session summary with detailed statistics, streaks, accuracy, time metrics, and retry failed cards option.

**Acceptance Criteria:**
- [ ] Summary shows: total cards, accuracy %, time spent, streak
- [ ] Breakdown by rating (Again/Good/Easy)
- [ ] List of failed cards with retry option (already exists at `FlashcardStudyView.swift:372-383`)
- [ ] Encouraging messages based on performance
- [ ] Share summary as image (optional)
- [ ] Chart showing performance over last 7 days

**Implementation Notes:**
- Location: `CardGenie/Features/FlashcardStudyView.swift:186-197` (summaryView)
- Create: `CardGenie/Features/Flashcards/StudyResultsView.swift` (if not exists)
- Use StudyStreakManager (already integrated at `FlashcardStudyView.swift:29`)
- Add Charts framework for visualizations

**Dependencies:** None

---

## Phase 4: Intelligence Enhancements

### Ticket F4.1: Create AI Refinement Loop for Cards
**Priority:** HIGH
**Status:** NOT STARTED
**Estimate:** 5 hours

**Description:**
Allow users to request AI rewrites/clarifications for flashcards. Support both on-device FM and fallback modes.

**Acceptance Criteria:**
- [ ] "Rewrite Card" button on card view
- [ ] Options: Simplify, Add Detail, Change Style
- [ ] Preview before accepting rewrite
- [ ] Clarification feature (already exists at `FlashcardStudyView.swift:385-408`)
- [ ] On-device processing via FMClient
- [ ] Fallback message when FM unavailable
- [ ] Preserve original card version (undo)

**Implementation Notes:**
- Location: Modify `CardGenie/Features/FlashcardStudyView.swift:385-408` (requestClarification)
- Location: Use `CardGenie/Intelligence/FlashcardFM.swift` for FM interactions
- Add version history to Flashcard model
- Gate Apple Intelligence with // TODO(iOS26) comments

**Dependencies:** F2.2 (edit capability)

---

### Ticket F4.2: Persist AI Generation Metadata
**Priority:** MEDIUM
**Status:** NOT STARTED
**Estimate:** 2 hours

**Description:**
Store metadata about AI-generated cards to prevent duplicates and enable future tuning.

**Acceptance Criteria:**
- [ ] Store: prompt hash, FM version, generation timestamp
- [ ] Dedupe cards based on question similarity
- [ ] Track: auto-generated vs manually created
- [ ] Metadata viewable in card details
- [ ] Export includes metadata for debugging

**Implementation Notes:**
- Location: Modify `CardGenie/Data/FlashcardModels.swift:26` (Flashcard model)
- Add generationMetadata property (Dictionary or JSON)
- Update FlashcardGenerator to store metadata
- Consider using vector embeddings for similarity detection

**Dependencies:** None

---

### Ticket F4.3: Add Contextual Hints During Study
**Priority:** LOW
**Status:** NOT STARTED
**Estimate:** 2 hours

**Description:**
Show contextual information during study without compromising privacy (show source passage, timestamp, related cards).

**Acceptance Criteria:**
- [ ] "Show Context" button reveals source passage
- [ ] For video/audio: show timestamp and allow jump to source
- [ ] Related cards suggestions (same topic/tag)
- [ ] All data remains on-device
- [ ] Context collapsible/expandable

**Implementation Notes:**
- Location: Modify `CardGenie/Features/FlashcardStudyView.swift:236-314` (clarificationSheet)
- Use linkedEntryID to fetch source StudyContent
- For NoteChunk sources, show timestampRange
- Apply privacy-preserving design patterns

**Dependencies:** None

---

## Phase 5: Insights & Motivation

### Ticket F5.1: Build Statistics Dashboard
**Priority:** HIGH
**Status:** NOT STARTED
**Estimate:** 5 hours

**Description:**
Create comprehensive statistics view showing streaks, forecasts, topic proficiency, review history.

**Acceptance Criteria:**
- [ ] Current study streak display
- [ ] Due forecast: next 7 days
- [ ] Topic-level proficiency bars
- [ ] Review history chart (last 30 days)
- [ ] Mastery level distribution
- [ ] Average success rate per topic
- [ ] Total cards learned milestone badges

**Implementation Notes:**
- Create: `CardGenie/Features/Flashcards/StatisticsView.swift`
- Use SpacedRepetitionManager.getSetStatistics
- Use StudyStreakManager.currentStreak
- Add Charts framework for visualizations
- Cache expensive calculations

**Dependencies:** None

---

### Ticket F5.2: Add Daily/Weekly Goals with Notifications
**Priority:** MEDIUM
**Status:** NOT STARTED
**Estimate:** 3 hours

**Description:**
Allow users to set study goals (cards per day, days per week) with progress tracking and gentle reminders.

**Acceptance Criteria:**
- [ ] Goal setting UI in settings
- [ ] Progress ring showing today's goal
- [ ] Weekly goal tracking
- [ ] Celebration when goal met
- [ ] Gentle reminder notification if goal not met by evening
- [ ] Goal history (last 30 days)

**Implementation Notes:**
- Create: `CardGenie/Data/GoalManager.swift`
- Store goals in @AppStorage or SwiftData
- Integrate with NotificationManager for reminders
- Add progress rings using CircularProgressView

**Dependencies:** F1.3 (notifications), F5.1 (stats)

---

### Ticket F5.3: Implement Widgets (Optional)
**Priority:** LOW
**Status:** NOT STARTED
**Estimate:** 6 hours

**Description:**
Create home screen widgets showing due count, streak, and daily progress.

**Acceptance Criteria:**
- [ ] Small widget: due count only
- [ ] Medium widget: due count + streak
- [ ] Large widget: due count + streak + today's progress
- [ ] Widgets update automatically
- [ ] Tap widget opens to FlashcardListView
- [ ] Support for Lock Screen widgets (iOS 16+)

**Implementation Notes:**
- Create: `CardGenieWidgets/` extension target
- Use WidgetKit and App Intents
- Share SwiftData container with widget
- Use TimelineProvider for updates

**Dependencies:** F5.1 (stats), F5.2 (goals)

---

## Phase 6: Quality, Accessibility, Documentation

### Ticket F6.1: Expand Test Coverage
**Priority:** HIGH
**Status:** NOT STARTED
**Estimate:** 6 hours

**Description:**
Achieve >80% test coverage for flashcard features. Add unit tests, integration tests, and UI tests.

**Acceptance Criteria:**
- [ ] Unit tests for all managers (SpacedRepetition, Notification, Goal)
- [ ] Integration tests for flashcard generation pipeline
- [ ] UI tests for study flow (create set → study → review)
- [ ] Test AI fallback paths
- [ ] Test manual editor validation
- [ ] All tests pass in CI

**Implementation Notes:**
- Location: `CardGenieTests/` directory
- Use existing SpacedRepetitionTests as template
- Add UI tests in `CardGenieUITests/`
- Mock FMClient for deterministic AI tests
- Use XCTest framework

**Dependencies:** All previous tickets

---

### Ticket F6.2: Setup CI with xcodebuild
**Priority:** HIGH
**Status:** NOT STARTED
**Estimate:** 2 hours

**Description:**
Configure GitHub Actions or similar CI to run tests and builds before merge.

**Acceptance Criteria:**
- [ ] CI runs on every PR
- [ ] Builds for iOS simulator
- [ ] Runs all unit and integration tests
- [ ] Fails PR if tests fail
- [ ] Caches dependencies for speed

**Implementation Notes:**
- Create: `.github/workflows/ci.yml`
- Use xcodebuild commands: `xcodebuild build test`
- Target iOS 18.0+ simulator
- Consider fastlane for complex workflows

**Dependencies:** F6.1

---

### Ticket F6.3: Snapshot Tests for Key Views (Optional)
**Priority:** LOW
**Status:** NOT STARTED
**Estimate:** 4 hours

**Description:**
Add snapshot tests to catch UI regressions in critical views.

**Acceptance Criteria:**
- [ ] Snapshots for: FlashcardListView, FlashcardStudyView, StatisticsView
- [ ] Tests for light and dark mode
- [ ] Tests for different text sizes (accessibility)
- [ ] Snapshots stored in git
- [ ] CI fails if snapshots differ

**Implementation Notes:**
- Use swift-snapshot-testing library
- Create: `CardGenieSnapshotTests/`
- Generate reference images on first run
- Consider recording mode for updates

**Dependencies:** F6.1

---

### Ticket F6.4: Update Documentation
**Priority:** HIGH
**Status:** NOT STARTED
**Estimate:** 3 hours

**Description:**
Update project documentation to reflect all new flashcard features and architecture.

**Acceptance Criteria:**
- [ ] FLASHCARD_IMPLEMENTATION.md updated with all Phase 1-5 features
- [ ] PROJECT_SUMMARY.md reflects new capabilities
- [ ] Add ARCHITECTURE.md explaining SwiftData models and managers
- [ ] In-app help screens updated
- [ ] Privacy documentation emphasizes on-device processing
- [ ] README includes setup instructions for developers

**Implementation Notes:**
- Update: `FLASHCARD_IMPLEMENTATION.md`
- Update: `PROJECT_SUMMARY.md`
- Create: `ARCHITECTURE.md`
- Create: `CardGenie/Resources/Help/` for in-app content
- Use Markdown for consistency

**Dependencies:** All feature tickets

---

### Ticket F6.5: Accessibility Audit
**Priority:** HIGH
**Status:** NOT STARTED
**Estimate:** 4 hours

**Description:**
Comprehensive accessibility audit and fixes for flashcard features.

**Acceptance Criteria:**
- [ ] All interactive elements have labels and hints
- [ ] VoiceOver announces card content correctly
- [ ] Keyboard navigation works throughout app
- [ ] Dynamic Type supported (all text scales)
- [ ] High contrast mode supported
- [ ] Reduce motion respected in animations
- [ ] Color contrast meets WCAG AA standards
- [ ] Passes Xcode Accessibility Inspector

**Implementation Notes:**
- Location: All flashcard views need audit
- Existing accessibility already partially implemented (see FlashcardCardView.swift:594-627)
- Test with VoiceOver, Switch Control, Full Keyboard Access
- Use Accessibility Inspector in Xcode

**Dependencies:** All UI tickets

---

## Summary Statistics

### Phase 1: Solidify Baseline Flow
- Tickets: 5
- Total Estimate: 9 hours
- Priority: HIGH (3), MEDIUM (2)

### Phase 2: Make Decks Manageable
- Tickets: 4
- Total Estimate: 12 hours
- Priority: HIGH (1), MEDIUM (3)

### Phase 3: Upgrade Study Experience
- Tickets: 3
- Total Estimate: 10 hours
- Priority: HIGH (1), MEDIUM (2)

### Phase 4: Intelligence Enhancements
- Tickets: 3
- Total Estimate: 9 hours
- Priority: HIGH (1), MEDIUM (1), LOW (1)

### Phase 5: Insights & Motivation
- Tickets: 3
- Total Estimate: 14 hours
- Priority: HIGH (1), MEDIUM (1), LOW (1)

### Phase 6: Quality, Accessibility, Documentation
- Tickets: 5
- Total Estimate: 19 hours
- Priority: HIGH (3), LOW (2)

### Grand Total
- **Total Tickets:** 23
- **Total Estimate:** 73 hours (~9 working days)
- **High Priority:** 10 tickets (43 hours)
- **Medium Priority:** 8 tickets (23 hours)
- **Low Priority:** 5 tickets (7 hours)

---

## Next Steps

1. **Immediate (Sprint 1):** Complete Phase 1 tickets (9 hours)
2. **Near-term (Sprint 2-3):** Phase 2 + Phase 3 high-priority items (16 hours)
3. **Mid-term (Sprint 4-5):** Phase 4 + Phase 5 (23 hours)
4. **Final (Sprint 6):** Phase 6 quality and documentation (19 hours)

**Note:** Some features are already partially implemented (noted in each ticket). This significantly reduces actual implementation time.
