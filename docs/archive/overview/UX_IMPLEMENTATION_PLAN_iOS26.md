# UX Implementation Plan - iOS 26

**Generated:** 2025-11-04
**Target:** iOS 26.0+ Minimum Deployment
**Status:** Draft for Review

## Executive Summary

This document provides a comprehensive implementation plan addressing 39 UX issues identified in the CardGenie iOS app. The plan is organized into 4 priority phases spanning 12-16 weeks, focusing on critical user experience improvements while leveraging iOS 26's native capabilities.

---

## Issue Categorization

### 🔴 Critical (P0) - Foundation & Core Flows
Issues that block or severely degrade core user journeys:
- **#1** - First-run onboarding & capability scaffolding
- **#3** - Notification permission UX
- **#4** - Content filtering & search scalability
- **#7** - AI action visibility & progress feedback
- **#12** - Study session interactions & controls
- **#30** - Accessibility compliance (VoiceOver, Dynamic Type)
- **#33** - Error handling & recovery

### 🟡 High (P1) - Experience Enhancement
Issues impacting usability and user satisfaction:
- **#2** - Navigation consistency & information architecture
- **#5** - Multi-source content creation
- **#8** - AI output management & editing
- **#9** - Flashcard home organization
- **#11** - Session configuration & presets
- **#13** - Study session feedback & coaching
- **#23** - Live Activities visibility
- **#31** - Visual hierarchy & contrast
- **#32** - AI task management & performance
- **#34** - Feature capability gating

### 🟢 Medium (P2) - Polish & Delight
Issues that improve polish and advanced workflows:
- **#6** - Rich text editing & versioning
- **#10** - Deck detail enhancements
- **#14** - Flashcard editor streamlining
- **#15** - Statistics insights & interactivity
- **#16** - Practice mode persistence
- **#17** - Connection Challenges UX
- **#18** - Conversational mode improvements
- **#19** - Game mode onboarding
- **#20** - AI Chat mode clarity
- **#21** - Voice Assistant UX
- **#22** - Voice Recording telemetry
- **#24** - Scanning pipeline improvements
- **#25** - OCR validation
- **#28** - Settings organization
- **#29** - Import/export workflows

### 🔵 Low (P3) - Future Enhancements
Issues for future iterations:
- **#26** - Concept Map editing
- **#27** - Study Plan adaptive scheduling
- **#35** - Privacy dashboard
- **#36** - Badge management
- **#37** - Storage management
- **#38** - In-app support
- **#39** - iPad/Pencil optimization

---

## Phase 1: Foundation (Weeks 1-4)
**Goal:** Establish critical onboarding, accessibility, and core interaction patterns

### Sprint 1.1: Onboarding & First-Run (Week 1-2)
**Issues Addressed:** #1, #3, #34

#### 1.1.1 Onboarding Tour System
**Files:** `Features/OnboardingViews.swift` (new)

**Implementation:**
```swift
// Use Instructions library pattern for coach marks
import Instructions

@MainActor
final class OnboardingCoordinator: ObservableObject {
    private let coachMarksController = CoachMarksController()
    @AppStorage("hasCompletedOnboarding") private var hasCompleted = false

    func startTour(in viewController: UIViewController) {
        guard !hasCompleted else { return }

        coachMarksController.dataSource = self
        coachMarksController.delegate = self
        coachMarksController.start(in: .window(over: viewController))
    }
}

// 5-step tour sequence:
// 1. Welcome + Apple Intelligence explainer
// 2. Study tab - Content creation
// 3. Flashcards tab - Spaced repetition intro
// 4. Scan tab - Multi-modal input
// 5. Floating AI button - Voice features
```

**Key Features:**
- Contextual tooltips with "Try it" interactions
- Optional demo data seeding (3 sample notes, 1 deck)
- Device capability detection (shows/hides AI features based on availability)
- Skip button with confirmation
- Progress dots (1/5, 2/5, etc.)

**Context7 Integration:**
- Use SwiftUI accessibility APIs for VoiceOver labels
- Implement coach marks using Instructions library patterns
- Follow iOS HIG for onboarding best practices

#### 1.1.2 Permission Request Flow
**Files:** `App/PermissionManager.swift` (new), `Features/OnboardingViews.swift`

**Implementation:**
```swift
@MainActor
final class PermissionManager: ObservableObject {
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var microphoneStatus: AVAuthorizationStatus = .notDetermined
    @Published var cameraStatus: AVAuthorizationStatus = .notDetermined

    func requestNotifications(with explanation: String) async -> Bool {
        // Show explainer sheet first
        // Then request permission
        // Return result
    }
}

struct PermissionExplainerView: View {
    let permissionType: PermissionType

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: permissionType.icon)
                .font(.system(size: 60))

            Text(permissionType.title)
                .font(.title2.bold())

            Text(permissionType.explanation)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            // Benefits list
            ForEach(permissionType.benefits) { benefit in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text(benefit)
                }
            }

            Button("Enable \(permissionType.rawValue)") {
                // Request permission
            }
            .buttonStyle(.borderedProminent)

            Button("Not Now") {
                // Dismiss
            }
            .buttonStyle(.bordered)
        }
        .padding(32)
        .glassPanel()
    }
}
```

**Permission Types:**
- Notifications: "Never miss a review session"
- Microphone: "Record lectures and ask questions"
- Camera: "Scan notes and documents instantly"
- Photos: "Import study materials"

#### 1.1.3 Capability Gating UI
**Files:** `Intelligence/AICore.swift`, `Features/ContentViews.swift`

**Implementation:**
```swift
struct AIFeatureGate: View {
    @ObservedObject var fmClient: FMClient

    var body: some View {
        switch fmClient.capability() {
        case .available:
            content
        case .notEnabled:
            AINotEnabledView()
        case .notSupported:
            AINotSupportedView()
        case .modelNotReady:
            AIDownloadingView()
        case .unknown:
            content // Graceful fallback
        }
    }
}

struct AINotEnabledView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Apple Intelligence Disabled", systemImage: "brain")
        } description: {
            Text("Enable Apple Intelligence in Settings to unlock AI-powered features.")
        } actions: {
            Link("Open Settings",
                 destination: URL(string: UIApplication.openSettingsURLString)!)
                .buttonStyle(.borderedProminent)

            Button("Use Basic Features") {
                // Show fallback mode
            }
            .buttonStyle(.bordered)
        }
    }
}
```

---

### Sprint 1.2: Accessibility Foundation (Week 2-3)
**Issues Addressed:** #30, #31

#### 1.2.1 VoiceOver Audit & Remediation
**Files:** All `Features/` files

**Tasks:**
1. **Audit all interactive elements**
   - Add `.accessibilityLabel()` to custom controls
   - Add `.accessibilityHint()` for complex actions
   - Add `.accessibilityValue()` for dynamic content

2. **Fix navigation order**
   - Use `.accessibilitySortPriority()` for logical flow
   - Group related elements with `.accessibilityElement(children: .combine)`

3. **Add custom actions**
```swift
// Example: Flashcard card with multiple actions
FlashcardCardView(card: card)
    .accessibilityLabel("Flashcard: \(card.front)")
    .accessibilityValue(card.isRevealed ? card.back : "Hidden")
    .accessibilityActions {
        Button("Reveal Answer") { /* reveal */ }
        Button("Mark Easy") { /* rate easy */ }
        Button("Mark Good") { /* rate good */ }
        Button("Mark Again") { /* rate again */ }
        Button("Edit") { /* edit */ }
    }
```

**VoiceOver Labels Inventory:**
- Study list: "X items, last updated Y"
- Flashcard sets: "X cards, Y due today"
- AI buttons: "Generate summary using on-device AI"
- Progress: "67% mastered, 12 cards remaining"

#### 1.2.2 Dynamic Type Support
**Files:** `Design/Theme.swift`, `Design/Components.swift`

**Implementation:**
```swift
// Update Theme.swift with scalable text styles
extension Theme {
    static let dynamicTitle = Font.system(.title).weight(.bold)
    static let dynamicHeadline = Font.system(.headline)
    static let dynamicBody = Font.system(.body)
    static let dynamicCaption = Font.system(.caption)

    // Minimum scale for complex layouts
    static let scaleRange: ClosedRange<CGFloat> = 0.8...2.0
}

// Update Components with @ScaledMetric
struct GlassCard: View {
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var padding: CGFloat = 16

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
    }
}

// Audit problem areas:
// - Tag chips (horizontal scrolling)
// - Search bars
// - Statistics charts
// - Flashcard content (may need font size limiter)
```

**Testing Matrix:**
- Test at xSmall, Medium, xLarge, xxxLarge
- Ensure no text truncation
- Verify button hit targets remain ≥44pt
- Check multi-line layout wrapping

#### 1.2.3 Contrast & Visual Hierarchy
**Files:** `Design/Theme.swift`

**Implementation:**
```swift
extension Theme {
    // WCAG AA compliant colors
    static let glassBackgroundLight = Color(white: 1.0, opacity: 0.15)
    static let glassBackgroundDark = Color(white: 0.0, opacity: 0.25)

    // Text colors with minimum 4.5:1 contrast on glass
    static let primaryText = Color.primary // System adaptive
    static let secondaryText = Color.secondary.opacity(0.85)

    // Accent colors
    static let accentBlue = Color(hex: "#0A84FF") // iOS system blue
    static let accentGreen = Color(hex: "#32D74B") // Success
    static let accentRed = Color(hex: "#FF453A") // Error

    // Dark mode overrides
    @Environment(\.colorScheme) var colorScheme

    var adaptiveGlassBackground: Color {
        colorScheme == .dark ? glassBackgroundDark : glassBackgroundLight
    }
}

// Add shadow for depth on glass-on-glass
.shadow(color: .black.opacity(0.1), radius: 8, y: 4)

// Badge colors with solid backgrounds
.badge(count: dueCount)
    .badgeColor(.red)
    .badgeTextColor(.white) // Ensure readable contrast
```

---

### Sprint 1.3: Core Interaction Patterns (Week 3-4)
**Issues Addressed:** #7, #12, #32

#### 1.3.1 AI Action Redesign
**Files:** `Features/ContentViews.swift`, `Intelligence/AICore.swift`

**Current State:**
```swift
// Hidden in menu, no progress, generic errors
Menu {
    Button("Summarize") { /* ... */ }
    Button("Extract Tags") { /* ... */ }
    Button("Generate Insights") { /* ... */ }
} label: {
    Image(systemName: "ellipsis.circle")
}
```

**New Design:**
```swift
struct AIActionsPanel: View {
    @ObservedObject var content: StudyContent
    @StateObject private var aiCoordinator = AIActionCoordinator()

    var body: some View {
        VStack(spacing: 12) {
            ForEach(AIAction.allCases) { action in
                AIActionButton(
                    action: action,
                    content: content,
                    coordinator: aiCoordinator
                )
            }
        }
        .padding()
        .glassPanel()
    }
}

struct AIActionButton: View {
    let action: AIAction
    let content: StudyContent
    @ObservedObject var coordinator: AIActionCoordinator

    var body: some View {
        Button {
            coordinator.perform(action, on: content)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(.headline)
                    Text(action.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if coordinator.isRunning(action) {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else if coordinator.hasResult(action) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: action.icon)
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(Color.primary.opacity(0.05))
            .cornerRadius(12)
        }
        .disabled(coordinator.isRunning(action) || !action.isAvailable(for: content))
    }
}

@MainActor
final class AIActionCoordinator: ObservableObject {
    @Published var runningTasks: [AIAction: Task<Void, Never>] = [:]
    @Published var results: [AIAction: AIResult] = [:]
    @Published var errors: [AIAction: AIError] = [:]

    func perform(_ action: AIAction, on content: StudyContent) {
        let task = Task {
            do {
                results[action] = nil
                errors[action] = nil

                let result = try await action.execute(on: content)
                results[action] = result

            } catch let error as AIError {
                errors[action] = error
                showErrorAlert(error)
            }
            runningTasks[action] = nil
        }
        runningTasks[action] = task
    }

    func cancel(_ action: AIAction) {
        runningTasks[action]?.cancel()
        runningTasks[action] = nil
    }
}

enum AIAction: CaseIterable, Identifiable {
    case summarize
    case extractTags
    case generateInsights
    case createFlashcards

    var id: String { title }

    var title: String {
        switch self {
        case .summarize: return "Summarize"
        case .extractTags: return "Extract Tags"
        case .generateInsights: return "Generate Insights"
        case .createFlashcards: return "Create Flashcards"
        }
    }

    var subtitle: String {
        switch self {
        case .summarize: return "Get a concise summary"
        case .extractTags: return "Identify key topics"
        case .generateInsights: return "Discover connections"
        case .createFlashcards: return "Generate study cards"
        }
    }

    var icon: String {
        switch self {
        case .summarize: return "doc.text"
        case .extractTags: return "tag"
        case .generateInsights: return "lightbulb"
        case .createFlashcards: return "rectangle.on.rectangle"
        }
    }
}
```

**Progress Feedback:**
- Immediate visual feedback (spinner appears)
- Estimated duration for long operations
- Streaming results where applicable
- Cancel button for all operations

**Error Handling:**
```swift
enum AIError: LocalizedError {
    case modelNotReady(downloadProgress: Double?)
    case guardrailViolation(reason: String)
    case insufficientContent
    case timeout
    case networkRequired // Shouldn't happen, but safety check

    var errorDescription: String? {
        switch self {
        case .modelNotReady(let progress):
            if let progress = progress {
                return "Apple Intelligence model downloading: \(Int(progress * 100))%"
            }
            return "Apple Intelligence model not ready"
        case .guardrailViolation(let reason):
            return "Content safety check: \(reason)"
        case .insufficientContent:
            return "Add more content (minimum 100 characters) to use this feature"
        case .timeout:
            return "Operation took too long. Try again with less content."
        case .networkRequired:
            return "This device requires a network connection for AI features"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .modelNotReady:
            return "Wait for download to complete, then try again"
        case .guardrailViolation:
            return "Review content and remove any inappropriate material"
        case .insufficientContent:
            return "Add more text to your note"
        case .timeout:
            return "Break content into smaller chunks"
        case .networkRequired:
            return "Connect to Wi-Fi or upgrade device for on-device AI"
        }
    }
}
```

#### 1.3.2 Study Session Controls
**Files:** `Features/FlashcardStudyViews.swift`

**Enhancements:**
```swift
struct EnhancedStudyView: View {
    @StateObject private var session: StudySession
    @State private var currentCard: Flashcard?
    @State private var isRevealed = false
    @State private var showClarification = false

    var body: some View {
        ZStack {
            // Card stack
            FlashcardStack(
                cards: session.remainingCards,
                currentIndex: session.currentIndex
            )

            // Swipe gesture overlay
            Color.clear
                .contentShape(Rectangle())
                .gesture(swipeGesture)

            // Bottom controls
            VStack {
                Spacer()

                if isRevealed {
                    RatingButtons(
                        onAgain: { rate(.again) },
                        onGood: { rate(.good) },
                        onEasy: { rate(.easy) }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                ControlBar(
                    canGoBack: session.canGoBack,
                    onBack: { session.goBack() },
                    onSkip: { session.skip() },
                    onClarify: { showClarification = true }
                )
            }
        }
        .onChange(of: isRevealed) { _, newValue in
            if newValue, settings.hapticsEnabled {
                HapticManager.shared.cardFlip()
            }
        }
        .sheet(isPresented: $showClarification) {
            ClarificationSheet(
                card: currentCard,
                onCancel: { showClarification = false }
            )
        }
    }

    // Swipe gestures
    var swipeGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                let threshold: CGFloat = 100

                if value.translation.width > threshold {
                    // Swipe right = Easy
                    rate(.easy)
                } else if value.translation.width < -threshold {
                    // Swipe left = Again
                    rate(.again)
                } else if value.translation.height < -threshold {
                    // Swipe up = Good
                    rate(.good)
                }
            }
    }

    func rate(_ rating: ReviewRating) {
        guard isRevealed else { return }

        if settings.audioEnabled {
            AudioManager.shared.play(.cardAdvance)
        }

        session.rate(currentCard, as: rating)
        isRevealed = false

        // Move to next card
        withAnimation(.spring()) {
            session.advance()
        }
    }
}

struct ClarificationSheet: View {
    let card: Flashcard?
    @StateObject private var clarificationManager = ClarificationManager()
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Ask for Clarification")
                .font(.title2.bold())

            if clarificationManager.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Thinking...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else if let response = clarificationManager.response {
                ScrollView {
                    Text(response)
                        .padding()
                }
            } else {
                Text("Need help understanding this card?")
                    .foregroundStyle(.secondary)

                Button("Explain Concept") {
                    clarificationManager.explain(card)
                }
                .buttonStyle(.borderedProminent)

                Button("Show Example") {
                    clarificationManager.showExample(card)
                }
                .buttonStyle(.bordered)

                Button("Simplify") {
                    clarificationManager.simplify(card)
                }
                .buttonStyle(.bordered)
            }

            Button("Cancel") {
                clarificationManager.cancel()
                onCancel()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .presentationDetents([.medium])
    }
}
```

**New Features:**
- ✅ Swipe gestures (right = easy, left = again, up = good)
- ✅ Skip/back navigation
- ✅ Inline clarification with AI
- ✅ Audio cues (when enabled)
- ✅ Haptic feedback (when enabled)
- ✅ Cancel button for AI operations

---

## Phase 2: Navigation & Content (Weeks 5-8)
**Goal:** Improve information architecture, content creation, and filtering

### Sprint 2.1: Navigation Redesign (Week 5-6)
**Issues Addressed:** #2, #4, #9

#### 2.1.1 Consistent Tab Structure
**Files:** `App/CardGenieApp.swift`

**Current Issues:**
- iOS 25 vs 26 tab differences
- Hidden settings
- Equal visual weight for utilities

**New Structure:**
```swift
@available(iOS 26.0, *)
struct ModernTabView: View {
    @State private var selectedTab: AppTab = .study

    var body: some View {
        TabView(selection: $selectedTab) {
            StudyTab()
                .tabItem {
                    Label("Study", systemImage: "book")
                }
                .tag(AppTab.study)

            FlashcardsTab()
                .tabItem {
                    Label("Cards", systemImage: "rectangle.on.rectangle")
                }
                .tag(AppTab.flashcards)

            ScanTab()
                .tabItem {
                    Label("Scan", systemImage: "doc.viewfinder")
                }
                .tag(AppTab.scan)
        }
        .tabViewBottomAccessory {
            // Floating AI Assistant (iOS 26+)
            FloatingAIButton()
                .padding(.trailing, 16)
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }
}

struct FloatingAIButton: View {
    @State private var showingMenu = false

    var body: some View {
        Button {
            showingMenu = true
        } label: {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .confirmationDialog("AI Assistant", isPresented: $showingMenu) {
            Button("Ask Question") {
                // Open Voice Assistant
            }
            Button("Record Lecture") {
                // Open Voice Record
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
```

#### 2.1.2 Advanced Filtering & Search
**Files:** `Features/ContentViews.swift`, `Data/Store.swift`

**Implementation:**
```swift
struct ContentListView: View {
    @State private var searchText = ""
    @State private var selectedFilters: Set<ContentFilter> = []
    @State private var sortOrder: SortOrder = .dateDescending
    @State private var showingFilters = false

    var filteredContent: [StudyContent] {
        store.fetchAllContent()
            .filter { content in
                // Search filter
                if !searchText.isEmpty {
                    let matchesText = content.title.localizedCaseInsensitiveContains(searchText) ||
                                     content.rawText.localizedCaseInsensitiveContains(searchText)
                    guard matchesText else { return false }
                }

                // Source filter
                if !selectedFilters.isEmpty {
                    let matchesFilter = selectedFilters.contains { filter in
                        switch filter {
                        case .text: return content.source == .text
                        case .photo: return content.source == .photo
                        case .voice: return content.source == .voice
                        case .pdf: return content.source == .pdf
                        case .aiGenerated: return content.summary != nil
                        case .hasFlashcards: return !content.flashcards.isEmpty
                        }
                    }
                    guard matchesFilter else { return false }
                }

                return true
            }
            .sorted(by: sortOrder.comparator)
    }

    var body: some View {
        NavigationStack {
            List {
                // Search bar
                GlassSearchBar(
                    text: $searchText,
                    placeholder: "Search notes and tags"
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                // Active filters chip row
                if !selectedFilters.isEmpty {
                    FilterChipsRow(
                        filters: $selectedFilters,
                        onClear: { selectedFilters.removeAll() }
                    )
                    .listRowSeparator(.hidden)
                }

                // Content
                ForEach(filteredContent) { content in
                    ContentRow(content: content)
                }
            }
            .navigationTitle("Study")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // Sort options
                        Picker("Sort By", selection: $sortOrder) {
                            Text("Newest First").tag(SortOrder.dateDescending)
                            Text("Oldest First").tag(SortOrder.dateAscending)
                            Text("Title A-Z").tag(SortOrder.titleAscending)
                            Text("Recently Updated").tag(SortOrder.modifiedDescending)
                        }

                        Divider()

                        Button {
                            showingFilters = true
                        } label: {
                            Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterSheet(selectedFilters: $selectedFilters)
            }
        }
    }
}

enum ContentFilter: String, CaseIterable, Identifiable {
    case text = "Text Notes"
    case photo = "Photos"
    case voice = "Voice"
    case pdf = "PDFs"
    case aiGenerated = "AI Processed"
    case hasFlashcards = "Has Cards"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .photo: return "photo"
        case .voice: return "waveform"
        case .pdf: return "doc.fill"
        case .aiGenerated: return "sparkles"
        case .hasFlashcards: return "rectangle.on.rectangle"
        }
    }
}

enum SortOrder {
    case dateDescending, dateAscending
    case titleAscending, titleDescending
    case modifiedDescending

    var comparator: (StudyContent, StudyContent) -> Bool {
        switch self {
        case .dateDescending:
            return { $0.createdAt > $1.createdAt }
        case .dateAscending:
            return { $0.createdAt < $1.createdAt }
        case .titleAscending:
            return { $0.title < $1.title }
        case .titleDescending:
            return { $0.title > $1.title }
        case .modifiedDescending:
            return { $0.lastModified > $1.lastModified }
        }
    }
}

struct FilterSheet: View {
    @Binding var selectedFilters: Set<ContentFilter>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Filter by Source") {
                    ForEach(ContentFilter.allCases.prefix(4)) { filter in
                        FilterRow(
                            filter: filter,
                            isSelected: selectedFilters.contains(filter),
                            onToggle: { toggleFilter(filter) }
                        )
                    }
                }

                Section("Filter by Status") {
                    ForEach(ContentFilter.allCases.suffix(2)) { filter in
                        FilterRow(
                            filter: filter,
                            isSelected: selectedFilters.contains(filter),
                            onToggle: { toggleFilter(filter) }
                        )
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear All") {
                        selectedFilters.removeAll()
                    }
                }
            }
        }
    }

    func toggleFilter(_ filter: ContentFilter) {
        if selectedFilters.contains(filter) {
            selectedFilters.remove(filter)
        } else {
            selectedFilters.insert(filter)
        }
    }
}
```

---

### Sprint 2.2: Multi-Source Content Creation (Week 6-7)
**Issues Addressed:** #5, #6, #8

#### 2.2.1 Source Picker & Templates
**Files:** `Features/ContentViews.swift`

**Implementation:**
```swift
struct ContentCreationMenu: View {
    @State private var showingSourcePicker = false
    @State private var selectedSource: ContentCreationSource?

    var body: some View {
        Menu {
            Section("Quick Capture") {
                Button {
                    selectedSource = .text
                } label: {
                    Label("Text Note", systemImage: "text.alignleft")
                }

                Button {
                    selectedSource = .photo
                } label: {
                    Label("Scan Photo", systemImage: "camera")
                }

                Button {
                    selectedSource = .voice
                } label: {
                    Label("Voice Note", systemImage: "waveform")
                }
            }

            Section("From Files") {
                Button {
                    selectedSource = .pdf
                } label: {
                    Label("Import PDF", systemImage: "doc.fill")
                }

                Button {
                    selectedSource = .photos
                } label: {
                    Label("From Photos", systemImage: "photo.on.rectangle")
                }
            }

            Section("Templates") {
                ForEach(ContentTemplate.allCases) { template in
                    Button {
                        selectedSource = .template(template)
                    } label: {
                        Label(template.name, systemImage: template.icon)
                    }
                }
            }
        } label: {
            Label("Add", systemImage: "plus")
        }
        .sheet(item: $selectedSource) { source in
            ContentCreationView(source: source)
        }
    }
}

enum ContentTemplate: String, CaseIterable, Identifiable {
    case lectureNotes = "Lecture Notes"
    case vocabulary = "Vocabulary List"
    case formulas = "Formulas & Equations"
    case timeline = "Historical Timeline"
    case concepts = "Key Concepts"

    var id: String { rawValue }

    var name: String { rawValue }

    var icon: String {
        switch self {
        case .lectureNotes: return "note.text"
        case .vocabulary: return "textformat.abc"
        case .formulas: return "function"
        case .timeline: return "clock"
        case .concepts: return "lightbulb"
        }
    }

    var placeholderText: String {
        switch self {
        case .lectureNotes:
            return """
            # Lecture: [Topic]

            ## Main Concepts
            -

            ## Key Points
            -

            ## Questions
            -
            """
        case .vocabulary:
            return """
            # Vocabulary: [Subject]

            **Term**: Definition

            **Term**: Definition
            """
        case .formulas:
            return """
            # Formulas: [Subject]

            ## [Formula Name]
            Formula:
            When to use:
            Example:
            """
        case .timeline:
            return """
            # Timeline: [Event]

            **Year**: Event description

            **Year**: Event description
            """
        case .concepts:
            return """
            # Key Concepts: [Topic]

            ## Concept 1
            Definition:
            Significance:

            ## Concept 2
            Definition:
            Significance:
            """
        }
    }
}
```

#### 2.2.2 Enhanced Text Editor
**Files:** `Intelligence/WritingTextEditor.swift`, `Features/ContentViews.swift`

**Implementation:**
```swift
struct EnhancedTextEditorView: View {
    @Binding var text: String
    @State private var showingHistory = false
    @State private var showingFormatting = false
    @State private var characterCount: Int = 0
    @FocusState private var isFocused: Bool

    // Version history
    @StateObject private var versionManager = VersionManager()

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Formatting tools
                Button {
                    showingFormatting.toggle()
                } label: {
                    Image(systemName: "textformat")
                }

                // Version history
                Button {
                    showingHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }

                Spacer()

                // Character count
                Text("\(characterCount) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Save indicator
                if versionManager.isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            // Editor
            WritingTextEditor(text: $text, isFocused: $isFocused)
                .onChange(of: text) { oldValue, newValue in
                    characterCount = newValue.count
                    versionManager.scheduleAutoSave(newValue)
                }

            // Formatting panel
            if showingFormatting {
                FormattingPanel(
                    onInsert: { markdown in
                        insertText(markdown)
                    }
                )
                .transition(.move(edge: .bottom))
            }
        }
        .sheet(isPresented: $showingHistory) {
            VersionHistoryView(manager: versionManager)
        }
    }

    func insertText(_ markdown: String) {
        // Insert at cursor position
        text.append(markdown)
    }
}

@MainActor
final class VersionManager: ObservableObject {
    @Published var versions: [TextVersion] = []
    @Published var isSaving = false

    private var saveTask: Task<Void, Never>?

    func scheduleAutoSave(_ text: String) {
        saveTask?.cancel()

        saveTask = Task {
            isSaving = true
            try? await Task.sleep(for: .seconds(2))

            if !Task.isCancelled {
                saveVersion(text)
                isSaving = false
            }
        }
    }

    func saveVersion(_ text: String) {
        let version = TextVersion(
            text: text,
            timestamp: Date(),
            characterCount: text.count
        )
        versions.append(version)

        // Keep last 20 versions
        if versions.count > 20 {
            versions.removeFirst()
        }
    }

    func restore(_ version: TextVersion) -> String {
        version.text
    }
}

struct TextVersion: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date
    let characterCount: Int
}

struct FormattingPanel: View {
    let onInsert: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FormatButton(title: "H1", insert: "# ", onInsert: onInsert)
                FormatButton(title: "H2", insert: "## ", onInsert: onInsert)
                FormatButton(title: "Bold", insert: "**text**", onInsert: onInsert)
                FormatButton(title: "Italic", insert: "_text_", onInsert: onInsert)
                FormatButton(title: "List", insert: "- ", onInsert: onInsert)
                FormatButton(title: "Link", insert: "[text](url)", onInsert: onInsert)
                FormatButton(title: "Code", insert: "`code`", onInsert: onInsert)
            }
            .padding()
        }
        .frame(height: 60)
        .background(.ultraThinMaterial)
    }
}

struct FormatButton: View {
    let title: String
    let insert: String
    let onInsert: (String) -> Void

    var body: some View {
        Button(title) {
            onInsert(insert)
        }
        .buttonStyle(.bordered)
    }
}
```

#### 2.2.3 AI Output Management
**Files:** `Features/ContentViews.swift`

**Implementation:**
```swift
struct AIOutputSection: View {
    @Binding var content: StudyContent
    @State private var editMode: EditMode = .inactive

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Summary
            if let summary = content.summary {
                AIOutputCard(
                    title: "Summary",
                    icon: "doc.text",
                    content: summary,
                    onEdit: { editSummary() },
                    onDelete: { content.summary = nil },
                    onRegenerate: { regenerateSummary() }
                )
            }

            // Tags
            if !content.tags.isEmpty {
                AITagsCard(
                    tags: $content.tags,
                    onAdd: { addTag() },
                    onEdit: { tag in editTag(tag) },
                    onDelete: { tag in deleteTag(tag) }
                )
            }

            // Insights
            if let insights = content.insights {
                AIOutputCard(
                    title: "Insights",
                    icon: "lightbulb",
                    content: insights,
                    onEdit: { editInsights() },
                    onDelete: { content.insights = nil },
                    onRegenerate: { regenerateInsights() }
                )
            }

            // Linked flashcards
            if !content.flashcards.isEmpty {
                LinkedFlashcardsCard(
                    flashcards: content.flashcards,
                    onNavigate: { card in navigateToCard(card) }
                )
            }
        }
    }
}

struct AIOutputCard: View {
    let title: String
    let icon: String
    let content: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onRegenerate: () -> Void

    @State private var isEditing = false
    @State private var editedContent: String

    init(title: String, icon: String, content: String,
         onEdit: @escaping () -> Void,
         onDelete: @escaping () -> Void,
         onRegenerate: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.content = content
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onRegenerate = onRegenerate
        self._editedContent = State(initialValue: content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)

                Spacer()

                Menu {
                    Button {
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button {
                        onRegenerate()
                    } label: {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                    }

                    Divider()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            if isEditing {
                TextEditor(text: $editedContent)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)

                HStack {
                    Button("Cancel") {
                        editedContent = content
                        isEditing = false
                    }
                    .buttonStyle(.bordered)

                    Button("Save") {
                        // Save edited content
                        isEditing = false
                        onEdit()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text(content)
                    .font(.body)
            }
        }
        .padding()
        .glassPanel()
    }
}
```

---

## Phase 3: Study Experience (Weeks 9-12)
**Goal:** Enhance flashcard management, study sessions, and feedback loops

### Sprint 3.1: Flashcard Organization (Week 9-10)
**Issues Addressed:** #9, #10, #11, #14

### Sprint 3.2: Study Feedback & Analytics (Week 10-11)
**Issues Addressed:** #13, #15

### Sprint 3.3: Voice & Live Activities (Week 11-12)
**Issues Addressed:** #21, #22, #23

---

## Phase 4: Polish & Platform (Weeks 13-16)
**Goal:** Scanning improvements, settings, and platform-specific enhancements

### Sprint 4.1: Scanning & OCR (Week 13)
**Issues Addressed:** #24, #25

### Sprint 4.2: Settings & Data Management (Week 14)
**Issues Addressed:** #28, #29, #35, #37

### Sprint 4.3: Platform Adaptation (Week 15-16)
**Issues Addressed:** #39

---

## Implementation Guidelines

### Code Organization Principles

1. **Feature-First Structure**
   - Keep related functionality together
   - Use MARK comments for navigation
   - Extract reusable components to `Design/Components.swift`

2. **SwiftUI Best Practices**
   - Prefer composition over inheritance
   - Use `@StateObject` for owned objects, `@ObservedObject` for passed objects
   - Extract subviews when body > 100 lines
   - Use `@ViewBuilder` for conditional layouts

3. **Accessibility by Default**
   - Add `.accessibilityLabel()` to all custom controls
   - Test with VoiceOver enabled
   - Support Dynamic Type
   - Minimum 44pt hit targets

4. **Performance Considerations**
   - Lazy-load images and heavy views
   - Use `@State` sparingly
   - Debounce expensive operations (search, AI calls)
   - Cache AI results

### Testing Strategy

**Unit Tests Priority:**
- AI capability detection
- Spaced repetition logic
- Permission state management
- Filter/search logic
- Version history

**UI Tests Priority:**
- Onboarding flow
- Content creation flows
- Study session interactions
- Accessibility navigation

**Manual Testing Checklist:**
- [ ] VoiceOver navigation
- [ ] Dynamic Type at all sizes
- [ ] Dark mode
- [ ] Landscape orientation
- [ ] iPad split view
- [ ] iOS 25 fallback behavior

---

## Success Metrics

### Phase 1 (Foundation)
- [ ] Onboarding completion rate > 70%
- [ ] Permission acceptance rate > 60%
- [ ] Zero accessibility violations
- [ ] All AI actions show progress feedback

### Phase 2 (Navigation & Content)
- [ ] Average time to create content < 30s
- [ ] Filter usage > 40% of sessions
- [ ] Template usage > 25% of new content

### Phase 3 (Study Experience)
- [ ] Study session completion rate > 80%
- [ ] Average cards per session increases 20%
- [ ] Clarification usage > 15% of difficult cards

### Phase 4 (Polish & Platform)
- [ ] OCR accuracy > 90% for printed text
- [ ] Settings discoverability > 60%
- [ ] iPad user retention +15%

---

## Risk Mitigation

### Technical Risks

1. **iOS 26 SDK Availability**
   - **Risk:** Official SDK differs from WWDC docs
   - **Mitigation:** Maintain abstraction layer (FMClient), update when SDK ships

2. **Foundation Models Performance**
   - **Risk:** On-device AI slower than expected
   - **Mitigation:** Add cancellation, show ETA, batch operations

3. **SwiftData Migration**
   - **Risk:** Schema changes break existing data
   - **Mitigation:** Version all models, test migration path

### UX Risks

1. **Onboarding Fatigue**
   - **Risk:** Users skip 5-step tour
   - **Mitigation:** Allow skip, contextual tips, progressive disclosure

2. **Feature Overload**
   - **Risk:** Too many options overwhelm users
   - **Mitigation:** Smart defaults, templates, guided flows

3. **Accessibility Compliance**
   - **Risk:** Complex layouts break VoiceOver
   - **Mitigation:** Test early and often, user testing

---

## Next Steps

1. **Review & Approval**
   - Review this plan with stakeholders
   - Adjust priorities based on feedback
   - Finalize sprint dates

2. **Sprint Planning**
   - Break down Phase 1 into detailed tasks
   - Assign effort estimates
   - Create GitHub issues

3. **Design Assets**
   - Create high-fidelity mockups for:
     - Onboarding screens
     - AI action panels
     - Filter UI
     - Permission explainers

4. **Technical Spikes**
   - Prototype Instructions integration
   - Test Live Activities implementation
   - Validate accessibility approach

---

## Appendix A: Issue Reference

| Issue | Category | Phase | Sprint | Priority |
|-------|----------|-------|--------|----------|
| #1 | Onboarding | 1 | 1.1 | P0 |
| #2 | Navigation | 2 | 2.1 | P1 |
| #3 | Permissions | 1 | 1.1 | P0 |
| #4 | Search/Filter | 2 | 2.1 | P0 |
| #5 | Content Creation | 2 | 2.2 | P1 |
| #6 | Text Editing | 2 | 2.2 | P2 |
| #7 | AI UX | 1 | 1.3 | P0 |
| #8 | AI Output | 2 | 2.2 | P1 |
| #9 | Flashcard Home | 3 | 3.1 | P1 |
| #10 | Deck Detail | 3 | 3.1 | P2 |
| #11 | Session Config | 3 | 3.1 | P1 |
| #12 | Study Controls | 1 | 1.3 | P0 |
| #13 | Study Feedback | 3 | 3.2 | P1 |
| #14 | Card Editor | 3 | 3.1 | P2 |
| #15 | Statistics | 3 | 3.2 | P2 |
| #16 | Practice Modes | 3 | 3.1 | P2 |
| #17 | Connection Challenges | 3 | 3.1 | P2 |
| #18 | Conversational | 3 | 3.2 | P2 |
| #19 | Game Modes | 3 | 3.2 | P2 |
| #20 | AI Chat | 3 | 3.2 | P2 |
| #21 | Voice Assistant | 3 | 3.3 | P1 |
| #22 | Voice Recording | 3 | 3.3 | P1 |
| #23 | Live Activities | 3 | 3.3 | P1 |
| #24 | Scanning | 4 | 4.1 | P2 |
| #25 | OCR Validation | 4 | 4.1 | P2 |
| #26 | Concept Maps | - | - | P3 |
| #27 | Study Plans | - | - | P3 |
| #28 | Settings | 4 | 4.2 | P2 |
| #29 | Import/Export | 4 | 4.2 | P2 |
| #30 | Accessibility | 1 | 1.2 | P0 |
| #31 | Visual Hierarchy | 1 | 1.2 | P1 |
| #32 | Performance | 1 | 1.3 | P1 |
| #33 | Error Handling | 1 | 1.3 | P0 |
| #34 | Capability Gating | 1 | 1.1 | P1 |
| #35 | Privacy Dashboard | - | - | P3 |
| #36 | Badge Management | - | - | P3 |
| #37 | Storage Management | 4 | 4.2 | P2 |
| #38 | Support | - | - | P3 |
| #39 | Platform Adaptation | 4 | 4.3 | P2 |

---

## Appendix B: Context7 Resources Used

- **SwiftUI Accessibility:** `/websites/developer_apple_swiftui` - VoiceOver, Dynamic Type, accessibility modifiers
- **Live Activities:** `/software-mansion-labs/expo-live-activity` - Implementation patterns (adapted for native Swift)
- **Onboarding:** `/ephread/instructions` - Coach marks and onboarding flows

---

**Document Version:** 1.0
**Last Updated:** 2025-11-04
**Author:** Claude Code
**Status:** Ready for Review
