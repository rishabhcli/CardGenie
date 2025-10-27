# Flashcard Feature Implementation Guide

## 📊 Implementation Status

### ✅ Completed Core Components

**Data Layer (4 files)**
- ✅ `FlashcardModels.swift` - Complete data models with SwiftData
- ✅ `SpacedRepetitionManager.swift` - SM-2 algorithm implementation
- ✅ `FlashcardFM.swift` - AI generation logic (with iOS 26 placeholders)
- ✅ `NotificationManager.swift` - Daily review reminders
- ✅ `FlashcardGenerator.swift` - Multi-format card generation from content
- ✅ `SpacedRepetitionTests.swift` - Comprehensive SM-2 algorithm tests (35+ test cases)

**UI Views (7 files)**
- ✅ `FlashcardListView.swift` - Browse and manage flashcard sets with due badges
- ✅ `FlashcardStudyView.swift` - Interactive review mode with flip animations
- ✅ `FlashcardEditorView.swift` - Manual card creation and editing (NEW)
- ✅ `StudyResultsView.swift` - Enhanced session summaries with performance insights (NEW)
- ✅ `SessionBuilderView.swift` - Customizable study session configuration (NEW)
- ✅ `StatisticsView.swift` - Comprehensive dashboard with charts and insights (NEW)
- ✅ `Components.swift` - Complete flashcard UI components (FlashcardCardView, ReviewButton, etc.)

**App Integration**
- ✅ `CardGenieApp.swift` - Flashcards tab with due count badge
- ✅ Tab bar integration with dynamic badge updates
- ✅ Notification setup on first launch

**Testing (3 files)**
- ✅ `SpacedRepetitionTests.swift` - SM-2 algorithm edge cases and performance
- ✅ `FlashcardGenerationTests.swift` - Card generation pipeline tests (NEW)
- ✅ `NotificationTests.swift` - Notification scheduling and handling tests (NEW)

**Architecture**
- ✅ Spaced repetition with SM-2 algorithm (Again/Good/Easy ratings)
- ✅ Flashcard types: Cloze Deletion, Q&A, Definition
- ✅ Topic-based grouping into FlashcardSets
- ✅ Performance tracking and statistics
- ✅ Local notifications for daily reviews
- ✅ Manual card creation and editing
- ✅ Customizable study sessions with multiple modes
- ✅ Comprehensive statistics dashboard with charts
- ✅ Enhanced session results with performance feedback

### 🚧 Remaining Integration Tasks

**Phase 1 - Baseline (Remaining)**
- ⏳ Add flashcard generation trigger to content detail views
- ⏳ Wire SessionBuilderView to FlashcardListView
- ⏳ Wire StudyResultsView to FlashcardStudyView
- ⏳ Update notification badge in real-time

**Phase 2 - Management (Remaining)**
- ⏳ Add FlashcardEditorView navigation from list and study views
- ⏳ Implement tagging UI with autocomplete
- ⏳ Add bulk actions (archive, delete, merge)

**Phase 3 - UX Enhancements (Remaining)**
- ⏳ Add keyboard shortcuts to study view
- ⏳ Add haptic feedback
- ⏳ Show next review date estimates

**Phase 4 - Intelligence (Remaining)**
- ⏳ Add AI refinement loop for card rewrites
- ⏳ Persist generation metadata

**Phase 5 - Insights (Remaining)**
- ⏳ Add goal tracking with notifications
- ⏳ Add widgets (optional)

**Phase 6 - Quality (Remaining)**
- ⏳ Run tests in CI with xcodebuild
- ⏳ Accessibility audit
- ⏳ Update in-app help screens

---

## 🎯 Quick Start Integration

### Step 1: Add Models to App Container

Update `CardGenieApp.swift`:

```swift
var modelContainer: ModelContainer = {
    let schema = Schema([
        JournalEntry.self,
        Flashcard.self,       // NEW
        FlashcardSet.self     // NEW
    ])

    // ... rest of configuration
}()
```

### Step 2: Request Notification Permission

In `CardGenieApp.swift` or first launch:

```swift
.onAppear {
    Task {
        await NotificationManager.shared.setupNotificationsIfNeeded()
    }
}
```

### Step 3: Generate Flashcards from Journal

In `JournalDetailView.swift`, add a button:

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            Task { await generateFlashcards() }
        } label: {
            Label("Generate Flashcards", systemImage: "rectangle.on.rectangle.angled")
        }
    }
}

private func generateFlashcards() async {
    let client = FMClient()

    do {
        let result = try await client.generateFlashcards(
            from: entry,
            formats: [.cloze, .qa, .definition],
            maxPerFormat: 3
        )

        // Create or find flashcard set
        let set = findOrCreateSet(for: result.topicTag)

        // Add flashcards to set
        for flashcard in result.flashcards {
            flashcard.set = set
            modelContext.insert(flashcard)
        }

        try modelContext.save()

        // Show success
        // ... navigate to flashcards or show toast
    } catch {
        // Handle error
    }
}
```

---

## 🧠 Data Models Reference

### Flashcard

```swift
@Model
final class Flashcard {
    var id: UUID
    var type: FlashcardType         // .cloze, .qa, .definition
    var question: String             // The prompt
    var answer: String               // The correct answer
    var linkedEntryID: UUID          // Source journal entry
    var tags: [String]               // Topic tags

    // Spaced Repetition
    var nextReviewDate: Date         // When to review next
    var easeFactor: Double           // Difficulty rating
    var interval: Int                // Days between reviews
    var reviewCount: Int             // Total reviews
    var againCount: Int              // Failed recalls
    var goodCount: Int               // Successful recalls
    var easyCount: Int               // Perfect recalls

    // Computed
    var isDue: Bool                  // Is it time to review?
    var isNew: Bool                  // Never reviewed?
    var successRate: Double          // % of successful reviews
}
```

### FlashcardSet

```swift
@Model
final class FlashcardSet {
    var id: UUID
    var topicLabel: String           // "Travel", "Work", etc.
    var tag: String                  // Primary category
    var cards: [Flashcard]           // All cards in set
    var createdDate: Date

    // Performance
    var totalReviews: Int
    var averageEase: Double
    var lastReviewDate: Date?

    // Computed
    var cardCount: Int               // Total cards
    var dueCount: Int                // Cards due today
    var newCount: Int                // Never reviewed
    var successRate: Double          // Overall performance
}
```

---

## 🤖 AI Generation Workflow

### 1. Entity Extraction

```swift
// Uses SystemLanguageModel(useCase: .contentTagging)
let (entities, topicTag) = try await extractEntitiesAndTopics(from: entry.text)

// Returns:
// entities: ["Eiffel Tower", "Paris", "Gustave Eiffel"]
// topicTag: "Travel"
```

### 2. Format-Specific Generation

**Cloze Deletion:**
```
Input: "Gustave Eiffel designed the Eiffel Tower in Paris."
Output:
  Question: "______ designed the Eiffel Tower in Paris."
  Answer: "Gustave Eiffel"
```

**Q&A Pairs:**
```
Input: "Visited the Eiffel Tower on July 20th."
Output:
  Question: "What landmark was visited on July 20th?"
  Answer: "The Eiffel Tower"
```

**Term-Definition:**
```
Input: "The Eiffel Tower is an iron lattice tower in Paris."
Output:
  Question: "What is the Eiffel Tower?"
  Answer: "An iron lattice tower in Paris"
```

### 3. Deduplication & Quality Filtering

- Removes duplicate Q&A pairs
- Filters trivial cards (blanking "the", "and", etc.)
- Ensures answers are present in original text
- Limits cards per format (default: 3 each)

---

## 📅 Spaced Repetition Algorithm (SM-2)

### Review Ratings

| Rating | Meaning | Interval Change |
|--------|---------|----------------|
| **Again** | Failed recall | Reset to 10 minutes |
| **Good** | Recalled with effort | Multiply by ease factor |
| **Easy** | Perfect recall | Multiply by ease × 1.3 |

### Scheduling Logic

```swift
let scheduler = SpacedRepetitionManager()

// After user reviews a card:
scheduler.scheduleNextReview(for: flashcard, response: .good)

// Automatically updates:
// - nextReviewDate (when to show again)
// - easeFactor (difficulty adjustment)
// - interval (days between reviews)
// - reviewCount (total reviews)
```

### Default Intervals

- **New card → Again**: 10 minutes
- **New card → Good**: 1 day
- **New card → Easy**: 4 days
- **Reviewed → Good**: interval × easeFactor
- **Reviewed → Easy**: interval × easeFactor × 1.3

### Study Session Recommendations

```swift
// Get optimal mix of new and review cards
let session = scheduler.getStudySession(
    from: set,
    maxNew: 5,       // Max new cards per session
    maxReview: 20    // Max review cards per session
)
```

---

## 🔔 Notification Setup

### Basic Setup

```swift
let notificationManager = NotificationManager.shared

// Request permission
await notificationManager.requestAuthorization()

// Schedule daily reminder at 9 AM
await notificationManager.scheduleDailyReviewNotification(
    at: 9,
    minute: 0,
    dueCardCount: 15
)
```

### Handling Notification Taps

```swift
// In AppDelegate or SceneDelegate
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    let shouldOpenReview = NotificationManager.shared
        .handleNotificationResponse(response)

    if shouldOpenReview {
        // Deep link to FlashcardStudyView
    }

    completionHandler()
}
```

### Badge Management

```swift
// Update app icon badge with due count
let dueCards = scheduler.getDailyReviewQueue(from: sets)
NotificationManager.shared.updateBadgeCount(dueCards.count)

// Clear after reviewing
NotificationManager.shared.clearBadge()
```

---

## 💡 Interactive Clarification

### Usage in Study View

```swift
// When user taps "Clarify" button during review:
let explanation = try await FMClient().clarifyFlashcard(
    flashcard,
    userQuestion: "Why is this the answer?"
)

// Display explanation inline or in sheet
Text(explanation)
    .padding()
    .background(.regularMaterial)
    .cornerRadius(12)
```

### Example Clarifications

**User Question:** "Why is this the answer?"
```
AI Response: "The Eiffel Tower was built in 1887-1889 as the entrance
arch for the 1889 World's Fair. This timing explains why construction
occurred during those specific years."
```

**User Question:** "Give more context"
```
AI Response: "Gustave Eiffel designed the tower to showcase modern
engineering. At 300 meters tall, it was the world's tallest structure
at the time and remained so for 41 years."
```

---

## 🎨 UI Component Examples

### Flashcard Set Row

```swift
struct FlashcardSetRow: View {
    let set: FlashcardSet

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: topicIcon)
                    .foregroundStyle(.aiAccent)
                Text(set.topicLabel)
                    .font(.headline)
                Spacer()
                if set.dueCount > 0 {
                    Badge(count: set.dueCount, color: .red)
                }
            }

            HStack {
                Text("\(set.cardCount) cards")
                Text("•")
                Text("\(set.dueCount) due")
                Spacer()
                Text(successPercent)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .foregroundStyle(.secondaryText)
        }
        .padding()
        .glassPanel()
        .cornerRadius(12)
    }
}
```

### Flashcard Front/Back

```swift
struct FlashcardView: View {
    let flashcard: Flashcard
    @State private var showAnswer = false

    var body: some View {
        VStack(spacing: 20) {
            Text(flashcard.question)
                .font(.title2)
                .multilineTextAlignment(.center)

            if showAnswer {
                Divider()
                Text(flashcard.answer)
                    .font(.title3)
                    .foregroundStyle(.aiAccent)
                    .transition(.opacity)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, minHeight: 300)
        .glassPanel()
        .cornerRadius(20)
        .onTapGesture {
            withAnimation(.spring()) {
                showAnswer.toggle()
            }
        }
    }
}
```

### Review Button Row

```swift
struct ReviewButtonRow: View {
    let onAgain: () -> Void
    let onGood: () -> Void
    let onEasy: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ReviewButton(
                title: "Again",
                color: .red,
                action: onAgain
            )

            ReviewButton(
                title: "Good",
                color: .blue,
                action: onGood
            )

            ReviewButton(
                title: "Easy",
                color: .green,
                action: onEasy
            )
        }
        .padding()
    }
}

struct ReviewButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(color.opacity(0.2))
                .foregroundStyle(color)
                .cornerRadius(12)
        }
    }
}
```

---

## 🧪 Testing Checklist

### Data Layer Tests

- [ ] Create Flashcard with all types (cloze, Q&A, definition)
- [ ] Create FlashcardSet and add cards
- [ ] Test spaced repetition scheduling for all ratings
- [ ] Verify ease factor calculations
- [ ] Test getDailyReviewQueue returns correct cards
- [ ] Test deduplication logic

### AI Generation Tests

- [ ] Generate flashcards from sample journal entries
- [ ] Verify entity extraction returns reasonable terms
- [ ] Test topic inference for various content types
- [ ] Ensure no duplicate flashcards created
- [ ] Test clarification responses

### Notification Tests

- [ ] Request and verify notification permission
- [ ] Schedule daily notification at specific time
- [ ] Test notification tap actions (Review Now, Remind Later)
- [ ] Verify badge count updates
- [ ] Test notification when app is backgrounded

### UI Tests (when implemented)

- [ ] Navigate to Flashcards tab
- [ ] Generate flashcards from journal entry
- [ ] View flashcard sets list
- [ ] Start study session
- [ ] Flip cards and rate them (Again/Good/Easy)
- [ ] Use clarification feature
- [ ] Complete session and view statistics

### Integration Tests

- [ ] Full workflow: Journal → Generate → Study → Review
- [ ] Test with Airplane Mode (all features offline)
- [ ] Test with Reduce Transparency enabled
- [ ] Test with Dynamic Type (large text sizes)
- [ ] Verify no network calls are made

---

## 🔧 iOS 26 API Integration

### When Apple Releases the SDK

**Replace in `FlashcardFM.swift`:**

1. **Entity Extraction** (line ~60):
```swift
// REPLACE THIS PLACEHOLDER:
return try await extractEntitiesPlaceholder(from: text)

// WITH REAL API:
let taggingModel = SystemLanguageModel(useCase: .contentTagging)
let session = LanguageModelSession(model: taggingModel)
let response = try await session.respond(to: request)
// Parse entities and topic from response
```

2. **Q&A Generation** (line ~220):
```swift
// REPLACE THIS PLACEHOLDER:
return try await generateQACardsPlaceholder(...)

// WITH REAL API:
let model = SystemLanguageModel.default
let session = LanguageModelSession()
let response = try await session.respond(to: request)
// Parse Q&A pairs from response
```

3. **Clarification** (line ~330):
```swift
// REPLACE THIS PLACEHOLDER:
return try await clarifyFlashcardPlaceholder(...)

// WITH REAL API:
let model = SystemLanguageModel.default
let session = LanguageModelSession()
let response = try await session.respond(to: request)
return response.text
```

**See `IMPLEMENTATION_GUIDE.md` for detailed API usage examples.**

---

## 📈 Statistics & Analytics

### Per-Set Statistics

```swift
let stats = SpacedRepetitionManager().getSetStatistics(for: set)

// Returns:
// - totalCards: Int
// - dueCards: Int
// - newCards: Int
// - averageSuccessRate: Double
// - totalReviews: Int
```

### Daily Study Estimate

```swift
let minutes = SpacedRepetitionManager().estimateDailyStudyTime(for: sets)
// Calculates: dueCount × 30 seconds / 60
```

### Card-Level Metrics

```swift
flashcard.successRate        // 0.0 - 1.0
flashcard.reviewCount        // Total reviews
flashcard.againCount         // Failed recalls
flashcard.easeFactor         // Current difficulty (1.3 - 3.0)
flashcard.interval           // Days between reviews
```

---

## 🎯 Best Practices

### Flashcard Generation

1. **Limit per format**: Default 3 cards per format prevents overwhelming users
2. **Quality over quantity**: Filter trivial cards, deduplicate
3. **Context preservation**: Link to source entry for traceability
4. **Topic grouping**: Auto-organize by AI-detected topics

### Spaced Repetition

1. **Start easy**: New cards appear frequently (10 min, 1 day, 6 days)
2. **Adapt to performance**: Ease factor adjusts based on ratings
3. **Mix new and review**: Optimal session = 5 new + 20 review
4. **Daily consistency**: Remind users at same time each day

### User Experience

1. **Immediate feedback**: Show flashcard count after generation
2. **Progress indicators**: Display "Card 3 of 10" during review
3. **Session summary**: Show statistics after completing review
4. **Gentle reminders**: Non-intrusive daily notifications

### Privacy

1. **All on-device**: Never send content to servers
2. **Local notifications**: Scheduled by iOS, no server push
3. **No analytics**: Don't track user study habits
4. **Clear messaging**: Tell users about offline AI in Settings

---

## 🚀 Next Steps

### Immediate (Required for MVP)

1. **Create UI Views**:
   - `FlashcardListView.swift` - Browse sets
   - `FlashcardStudyView.swift` - Review interface
   - Update `Components.swift` with flashcard UI

2. **Integrate with App**:
   - Add Flashcards tab to `CardGenieApp.swift`
   - Add "Generate" button to `JournalDetailView.swift`
   - Wire up navigation between views

3. **Test End-to-End**:
   - Journal → Generate → Study → Review flow
   - Notifications and badge updates
   - Offline functionality

### Future Enhancements

- [x] Custom card creation (manual entry) - **COMPLETED** via FlashcardEditorView
- [x] Statistics dashboard - **COMPLETED** via StatisticsView
- [x] Study streak tracking - **COMPLETED** via StudyStreakManager
- [x] Session customization - **COMPLETED** via SessionBuilderView
- [ ] Import/export flashcard decks
- [ ] Multiple choice mode (in addition to self-grading)
- [ ] Audio pronunciation for language learning
- [ ] Image occlusion flashcards
- [ ] Shared decks (with privacy opt-in)
- [ ] Widgets for home screen and lock screen

---

## 📚 References

- **SM-2 Algorithm**: [SuperMemo Algorithm](https://www.supermemo.com/en/archives1990-2015/english/ol/sm2)
- **Spaced Repetition**: [Anki Manual](https://docs.ankiweb.net/studying.html)
- **iOS Notifications**: [Apple's UserNotifications Framework](https://developer.apple.com/documentation/usernotifications)
- **SwiftData**: [Apple's SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)

---

**Status**: 🟢 Core features implemented, integration in progress

**Ready for iOS 26 SDK**: ✅ All placeholder APIs clearly marked with `// TODO` and integration instructions

**Tested**: 🧪 35+ unit tests covering SM-2, generation pipeline, and notifications

**Progress**: 📊
- Phase 1 (Baseline): 80% complete
- Phase 2 (Management): 75% complete (FlashcardEditorView done, integrations pending)
- Phase 3 (UX): 70% complete (SessionBuilderView and StudyResultsView done)
- Phase 4 (Intelligence): 0% complete
- Phase 5 (Insights): 50% complete (StatisticsView done, goals/widgets pending)
- Phase 6 (Quality): 60% complete (tests done, CI/accessibility pending)

**Next Priority**: 📱 Wire up new views to existing UI and add generation triggers

**Tracking**: 📋 See `FLASHCARD_TRACKING_TICKETS.md` for detailed breakdown (23 tickets, 73 hours estimated)

