# CardGenie: Detailed Implementation Plan

## 🎯 Phase 1: Core "Wow" Features (Week 1-2)

### Task 1.1: Rebrand from Journal to Study Content
**Priority:** CRITICAL
**Time:** 2-3 hours

#### Changes Needed:

1. **Rename Models**
```swift
// OLD: JournalEntry
// NEW: StudyContent

@Model
final class StudyContent {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var source: ContentSource  // .text, .photo, .voice
    var rawContent: String
    var extractedText: String?
    var photoData: Data?

    // AI metadata
    var summary: String?
    var tags: [String]
    var topic: String?

    // Relationships
    @Relationship(deleteRule: .cascade)
    var flashcards: [Flashcard]
}

enum ContentSource: String, Codable {
    case text
    case photo
    case voice
    case pdf
}
```

2. **Update All References**
- [ ] `Data/Models.swift` → Rename class
- [ ] `Data/Store.swift` → Update queries
- [ ] `Features/JournalListView.swift` → Rename to `ContentListView.swift`
- [ ] `Features/JournalDetailView.swift` → Rename to `ContentDetailView.swift`
- [ ] All view models and references

3. **Update UI Copy**
- [ ] "Journal Entries" → "Study Materials"
- [ ] "New Entry" → "Add Content"
- [ ] "Entry Details" → "Content Details"
- [ ] Navigation titles throughout app

---

### Task 1.2: Implement Genie Theming
**Priority:** HIGH
**Time:** 4-6 hours

#### Create New Design System

1. **Update Theme.swift**
```swift
//
//  Theme.swift
//  CardGenie
//

import SwiftUI

extension Color {
    // Genie Theme Colors
    static let cosmicPurple = Color(hex: "6B46C1")
    static let magicGold = Color(hex: "F59E0B")
    static let mysticBlue = Color(hex: "3B82F6")
    static let genieGreen = Color(hex: "10B981")

    // Backgrounds
    static let darkMagic = Color(hex: "0F172A")
    static let lightMagic = Color(hex: "F8FAFC")

    // Gradients
    static let magicGradient = LinearGradient(
        colors: [.cosmicPurple, .mysticBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let goldShimmer = LinearGradient(
        colors: [.magicGold, .yellow, .magicGold],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// Helper for hex colors
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
```

2. **Create Magic Effects**
```swift
//
//  MagicEffects.swift
//  CardGenie
//

import SwiftUI

// Sparkle particle effect
struct SparkleEffect: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    ForEach(0..<20) { i in
                        Circle()
                            .fill(Color.magicGold.opacity(0.6))
                            .frame(width: 4, height: 4)
                            .position(
                                x: CGFloat.random(in: 0...geometry.size.width),
                                y: isAnimating ? -20 : geometry.size.height + 20
                            )
                            .animation(
                                .linear(duration: Double.random(in: 1...3))
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.1),
                                value: isAnimating
                            )
                    }
                }
            )
            .onAppear { isAnimating = true }
    }
}

extension View {
    func sparkles() -> some View {
        modifier(SparkleEffect())
    }
}

// Shimmer loading effect
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.6),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// Magic button style
struct MagicButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.magicGradient)
            .foregroundColor(.white)
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}
```

3. **Update App Icon**
- Design genie lamp icon
- Create icon set in Assets.xcassets
- Purple/gold color scheme

---

### Task 1.3: AI Study Coach
**Priority:** HIGH
**Time:** 6-8 hours

#### Implementation

1. **Create StudyCoach.swift**
```swift
//
//  StudyCoach.swift
//  CardGenie
//

import Foundation
import FoundationModels
import OSLog

extension FMClient {
    private var coachLog: Logger {
        Logger(subsystem: "com.cardgenie.app", category: "StudyCoach")
    }

    /// Generate encouraging message based on study performance
    func generateEncouragement(
        correctCount: Int,
        totalCount: Int,
        streak: Int
    ) async throws -> String {
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        coachLog.info("Generating study encouragement...")

        let accuracy = totalCount > 0 ? Double(correctCount) / Double(totalCount) : 0.0

        do {
            let instructions = """
                You are a supportive, enthusiastic AI study coach named CardGenie.
                Encourage students with warmth and positivity.
                Keep messages brief (1-2 sentences).
                Use encouraging emojis sparingly.
                Celebrate progress and effort, not just perfection.
                """

            let session = LanguageModelSession(instructions: instructions)

            let prompt = """
                Generate an encouraging message for a student who just completed a study session.

                Performance:
                - Correct: \(correctCount) out of \(totalCount)
                - Accuracy: \(Int(accuracy * 100))%
                - Study streak: \(streak) days

                The message should be personal, warm, and motivating.
                """

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.8
            )

            let response = try await session.respond(to: prompt, options: options)
            let message = response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            coachLog.info("Encouragement generated")
            return message

        } catch {
            coachLog.error("Encouragement generation failed: \(error.localizedDescription)")

            // Fallback messages
            if accuracy >= 0.9 {
                return "Outstanding work! You're mastering this material! ⭐️"
            } else if accuracy >= 0.7 {
                return "Great progress! Keep up the excellent work! 💪"
            } else if accuracy >= 0.5 {
                return "You're learning! Every review makes you stronger! 🌟"
            } else {
                return "Don't give up! Learning takes time and you're doing great! 💫"
            }
        }
    }

    /// Generate insight about study patterns
    func generateStudyInsight(
        totalReviews: Int,
        averageAccuracy: Double,
        longestStreak: Int
    ) async throws -> String {
        guard #available(iOS 26.0, *) else {
            throw FMError.unsupportedOS
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw FMError.modelUnavailable
        }

        do {
            let instructions = """
                You are CardGenie, an AI study coach.
                Provide brief, actionable insights about study patterns.
                Be encouraging and specific.
                One sentence maximum.
                """

            let session = LanguageModelSession(instructions: instructions)

            let prompt = """
                Generate a study insight for a student with these statistics:
                - Total reviews: \(totalReviews)
                - Average accuracy: \(Int(averageAccuracy * 100))%
                - Longest streak: \(longestStreak) days

                What's one positive observation or tip?
                """

            let options = GenerationOptions(
                sampling: .greedy,
                temperature: 0.7
            )

            let response = try await session.respond(to: prompt, options: options)
            return response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        } catch {
            return "You've reviewed \(totalReviews) cards - that's dedication! 🎯"
        }
    }
}
```

2. **Update Study Session UI**
```swift
// In FlashcardStudyView.swift
// Add encouragement after session completes

.sheet(isPresented: $showResults) {
    StudyResultsView(
        correct: correctCount,
        total: cards.count,
        streak: currentStreak,
        onDismiss: {
            showResults = false
        }
    )
}
```

3. **Create StudyResultsView.swift**
```swift
//
//  StudyResultsView.swift
//  CardGenie
//

import SwiftUI

struct StudyResultsView: View {
    let correct: Int
    let total: Int
    let streak: Int
    let onDismiss: () -> Void

    @State private var encouragement = ""
    @State private var isLoading = true
    @StateObject private var fmClient = FMClient()

    var accuracy: Double {
        total > 0 ? Double(correct) / Double(total) : 0
    }

    var body: some View {
        VStack(spacing: 24) {
            // Celebration animation
            if accuracy >= 0.8 {
                LottieView(animation: "celebration")
                    .frame(height: 200)
            }

            Text("Session Complete!")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))

            // Stats
            HStack(spacing: 40) {
                StatItem(
                    value: "\(correct)/\(total)",
                    label: "Correct",
                    color: .genieGreen
                )

                StatItem(
                    value: "\(Int(accuracy * 100))%",
                    label: "Accuracy",
                    color: .mysticBlue
                )

                StatItem(
                    value: "\(streak)",
                    label: "Day Streak",
                    color: .magicGold
                )
            }

            // AI Encouragement
            if isLoading {
                ProgressView()
                    .shimmer()
            } else {
                Text(encouragement)
                    .font(.system(.title3, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.cosmicPurple)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.cosmicPurple.opacity(0.1))
                    )
            }

            Button("Continue") {
                onDismiss()
            }
            .buttonStyle(MagicButtonStyle())
        }
        .padding()
        .task {
            await loadEncouragement()
        }
    }

    private func loadEncouragement() async {
        do {
            encouragement = try await fmClient.generateEncouragement(
                correctCount: correct,
                totalCount: total,
                streak: streak
            )
            isLoading = false
        } catch {
            encouragement = "Great work! Keep studying! ✨"
            isLoading = false
        }
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack {
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

---

### Task 1.4: Photo Scanning Feature
**Priority:** CRITICAL (Signature SSC feature)
**Time:** 10-12 hours

#### Implementation Steps

1. **Add VisionKit Framework**
```swift
// In CardGenie.swift
import VisionKit
import Vision
```

2. **Create VisionTextExtractor.swift**
```swift
//
//  VisionTextExtractor.swift
//  CardGenie
//

import Vision
import VisionKit
import UIKit
import OSLog

@MainActor
final class VisionTextExtractor: ObservableObject {
    private let logger = Logger(subsystem: "com.cardgenie.app", category: "Vision")

    @Published var extractedText = ""
    @Published var isProcessing = false
    @Published var error: Error?

    /// Extract text from an image using Vision framework
    func extractText(from image: UIImage) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }

        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        logger.info("Starting text recognition...")

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: VisionError.noTextFound)
                    return
                }

                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                self.logger.info("Extracted \(recognizedText.count) characters")
                continuation.resume(returning: recognizedText)
            }

            // Configure for accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum VisionError: LocalizedError {
    case invalidImage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The image could not be processed"
        case .noTextFound:
            return "No text was found in the image"
        }
    }
}
```

3. **Create PhotoScanView.swift**
```swift
//
//  PhotoScanView.swift
//  CardGenie
//

import SwiftUI
import PhotosUI

struct PhotoScanView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var extractor = VisionTextExtractor()
    @StateObject private var fmClient = FMClient()

    @State private var selectedImage: UIImage?
    @State private var extractedText = ""
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var isGeneratingCards = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let image = selectedImage {
                    // Show captured image
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)

                    if extractor.isProcessing {
                        VStack {
                            ProgressView()
                            Text("Reading text...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .shimmer()
                    } else if !extractedText.isEmpty {
                        // Show extracted text
                        ScrollView {
                            Text(extractedText)
                                .font(.body)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.cosmicPurple.opacity(0.1))
                                )
                        }

                        Button("Generate Flashcards ✨") {
                            generateFlashcards()
                        }
                        .buttonStyle(MagicButtonStyle())
                        .disabled(isGeneratingCards)
                    }
                } else {
                    // Initial state - show options
                    VStack(spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.magicGradient)

                        Text("Scan Your Notes")
                            .font(.system(.title, design: .rounded, weight: .bold))

                        Text("Take a photo of your textbook, notes, or any written content")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                        VStack(spacing: 12) {
                            Button {
                                showCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(MagicButtonStyle())

                            Button {
                                showPhotoPicker = true
                            } label: {
                                Label("Choose from Library", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Scan Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView(image: $selectedImage)
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto)
            .onChange(of: selectedImage) { oldValue, newValue in
                if let image = newValue {
                    Task {
                        await extractTextFromImage(image)
                    }
                }
            }
        }
    }

    @State private var selectedPhoto: PhotosPickerItem?

    private func extractTextFromImage(_ image: UIImage) async {
        do {
            extractedText = try await extractor.extractText(from: image)
        } catch {
            // Handle error
            print("Text extraction failed: \(error)")
        }
    }

    private func generateFlashcards() {
        isGeneratingCards = true

        Task {
            do {
                // Create StudyContent from photo
                let content = StudyContent(
                    source: .photo,
                    rawContent: extractedText
                )
                content.photoData = selectedImage?.jpegData(compressionQuality: 0.8)

                // Generate flashcards using AI
                let result = try await fmClient.generateFlashcards(
                    from: content,
                    formats: [.cloze, .qa, .definition],
                    maxPerFormat: 3
                )

                // Save to database
                // Navigate to flashcard list

                dismiss()
            } catch {
                print("Flashcard generation failed: \(error)")
            }

            isGeneratingCards = false
        }
    }
}

// Camera view using UIImagePickerController
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
```

4. **Add to Main Navigation**
```swift
// In ContentListView.swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Menu {
            Button {
                showPhotoScan = true
            } label: {
                Label("Scan Notes", systemImage: "camera")
            }

            Button {
                // Future: Voice recording
            } label: {
                Label("Record Lecture", systemImage: "mic")
            }

            Button {
                // Existing: Add text
            } label: {
                Label("Add Text", systemImage: "text.quote")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.magicGradient)
        }
    }
}
.sheet(isPresented: $showPhotoScan) {
    PhotoScanView()
}
```

---

## Week 3-4: Voice Recording & Polish

### Task 2.1: Voice Recording Feature
**Priority:** HIGH
**Time:** 8-10 hours

Similar structure to photo scanning but using Speech framework.

### Task 2.2: Onboarding Flow
**Priority:** HIGH
**Time:** 6-8 hours

### Task 2.3: Study Streaks & Achievements
**Priority:** MEDIUM
**Time:** 8-10 hours

---

## Testing Checklist

- [ ] All features work on iOS 26+
- [ ] Graceful degradation on older iOS
- [ ] VoiceOver support
- [ ] Dynamic Type support
- [ ] Dark mode support
- [ ] Edge cases handled (no camera, no mic, etc.)
- [ ] Performance optimized (60fps)
- [ ] Memory usage reasonable
- [ ] Battery usage acceptable
- [ ] No crashes or force unwraps

---

## Files to Create (Summary)

### New Files
1. `SSC_VISION_AND_PLAN.md` ✅
2. `IMPLEMENTATION_PLAN.md` ✅ (this file)
3. `Design/MagicEffects.swift`
4. `Intelligence/StudyCoach.swift`
5. `Intelligence/VisionTextExtractor.swift`
6. `Intelligence/SpeechToText.swift`
7. `Features/PhotoScanView.swift`
8. `Features/VoiceRecordView.swift`
9. `Features/StudyResultsView.swift`
10. `Features/OnboardingFlow.swift`
11. `Data/StudyStats.swift`
12. `Data/Achievement.swift`
13. `Data/StreakManager.swift`

### Files to Modify
1. `Data/Models.swift` - Rename JournalEntry
2. `Design/Theme.swift` - Add genie colors
3. `Features/JournalListView.swift` - Rename & update
4. `App/CardGenieApp.swift` - Add frameworks
5. `Intelligence/FMClient.swift` - Add coach methods

---

**Ready to start implementation?** I recommend beginning with Task 1.1 (rebrand) and Task 1.2 (theming) first!
