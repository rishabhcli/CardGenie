//
//  ScanningViews.swift
//  CardGenie
//
//  Photo and document scanning interfaces.
//

import SwiftUI
import SwiftData
import AVFoundation
import VisionKit
import PhotosUI

// MARK: - PhotoScanView


/// Photo scanning interface with text extraction and flashcard generation
struct PhotoScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var extractor = VisionTextExtractor()
    @StateObject private var fmClient = FMClient()
    @StateObject private var analytics = ScanAnalytics.shared

    @State private var selectedImage: UIImage?
    @State private var selectedImages: [UIImage] = []
    @State private var extractedText = ""
    @State private var showCamera = false
    @State private var showDocumentScanner = false
    @State private var showPhotoPicker = false
    @State private var isGeneratingCards = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var documentScanResult: DocumentScanResult?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isMultiPage = false
    @State private var extractionResult: TextExtractionResult?
    @State private var showLowConfidenceWarning = false

    var body: some View {
        NavigationStack {
            navigationContent
        }
    }

    private var navigationContent: some View {
        let navigationConfigured = mainView
            .navigationTitle("Scan Notes")
            .navigationBarTitleDisplayMode(.inline)

        let tooledView = navigationConfigured.toolbar {
            if selectedImage != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset") {
                        resetScan()
                    }
                    .foregroundColor(.cosmicPurple)
                }
            }
        }

        let cameraSheetView = tooledView.sheet(isPresented: $showCamera) {
            CameraView(image: $selectedImage)
        }

        let documentSheetView = cameraSheetView.sheet(isPresented: $showDocumentScanner) {
            DocumentScannerView(result: $documentScanResult)
                .ignoresSafeArea()
        }

        let photoPickerView = documentSheetView.photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhoto,
            matching: .images
        )

        let photoChangeView = photoPickerView.onChange(of: selectedPhoto) { _, newValue in
            handleSelectedPhotoChange(newValue)
        }

        let imageChangeView = photoChangeView.onChange(of: selectedImage) { _, newValue in
            handleSelectedImageChange(newValue)
        }

        let documentChangeView = imageChangeView.onChange(of: documentScanResult?.id) { _, _ in
            handleDocumentScanChange(documentScanResult)
        }

        let errorAlertView = documentChangeView.alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }

        let confidenceAlertView = errorAlertView.alert(
            "Low OCR Confidence",
            isPresented: $showLowConfidenceWarning
        ) {
            Button("Continue Anyway", role: .none) {}
            Button("Re-Scan", role: .cancel) {
                resetScan()
            }
        } message: {
            Text(lowConfidenceMessage)
        }

        return AnyView(confidenceAlertView)
    }

    // MARK: - View Sections

    private var emptyStateSection: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            // Icon
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(Color.magicGradient)
                .floating(distance: 8, duration: 3.0)

            // Title
            Text("Scan Your Notes")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundColor(.primaryText)

            // Description
            Text("Take a photo of your textbook, notes, or any written content to instantly create flashcards")
                .font(.system(.body, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondaryText)
                .padding(.horizontal)

            Spacer()

            // Action buttons
            VStack(spacing: Spacing.md) {
                // Document scanner (if available)
                if DocumentScanningCapability.isAvailable {
                    HapticButton(hapticStyle: .medium) {
                        showDocumentScanner = true
                    } label: {
                        Label("Scan Document", systemImage: "doc.text.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MagicButtonStyle())
                }

                HapticButton(hapticStyle: .medium) {
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MagicButtonStyle())

                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(.cosmicPurple)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 24)
                        .background(Color.cosmicPurple.opacity(0.1))
                        .cornerRadius(CornerRadius.lg)
                }
            }
            .padding(.horizontal)
        }
    }

    private var scanContent: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                if !selectedImages.isEmpty || selectedImage != nil {
                    if !selectedImages.isEmpty {
                        multiPagePreviewSection
                    } else if let image = selectedImage {
                        imagePreviewSection(image: image)
                    }

                    if extractor.isProcessing {
                        loadingSection
                    } else if !extractedText.isEmpty {
                        extractedTextSection
                    }
                } else {
                    emptyStateSection
                }
            }
            .padding()
        }
    }

    private var mainView: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()

            scanContent
        }
    }

    private var lowConfidenceMessage: String {
        """
        The text extraction quality is lower than optimal. For best results, try:

        • Better lighting
        • Holding camera steady
        • Ensuring text is in focus

        Would you like to re-scan?
        """
    }

    private func handleSelectedPhotoChange(_ newValue: PhotosPickerItem?) {
        guard newValue != nil else { return }
        Task { await loadSelectedPhoto() }
    }

    private func handleSelectedImageChange(_ newValue: UIImage?) {
        guard let image = newValue else { return }
        isMultiPage = false
        Task { await extractTextFromImage(image) }
    }

    private func handleDocumentScanChange(_ newValue: DocumentScanResult?) {
        guard let result = newValue else { return }
        selectedImages = result.images
        isMultiPage = true
        Task { await extractTextFromMultipleImages(result.images) }
    }

    private func imagePreviewSection(image: UIImage) -> some View {
        VStack(spacing: Spacing.md) {
            Text("Scanned Image")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondaryText)
                .textCase(.uppercase)

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .cornerRadius(CornerRadius.lg)
                .shadow(color: .cosmicPurple.opacity(0.2), radius: 10, y: 5)
        }
    }

    private var multiPagePreviewSection: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("Scanned Document")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondaryText)
                    .textCase(.uppercase)

                Spacer()

                Text("\(selectedImages.count) pages")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(.cosmicPurple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cosmicPurple.opacity(0.1))
                    .cornerRadius(CornerRadius.md)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                        VStack(spacing: Spacing.xs) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(CornerRadius.md)
                                .shadow(color: .cosmicPurple.opacity(0.2), radius: 5, y: 3)

                            Text("Page \(index + 1)")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var loadingSection: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .tint(.cosmicPurple)
                .scaleEffect(1.2)

            Text("Reading text from image...")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.cosmicPurple.opacity(0.05))
        )
        .shimmer()
    }

    private var extractedTextSection: some View {
        VStack(spacing: Spacing.lg) {
            // Extracted text display
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.genieGreen)
                    Text("Text Extracted")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondaryText)
                        .textCase(.uppercase)
                    Spacer()

                    // Confidence badge
                    if let result = extractionResult {
                        HStack(spacing: 4) {
                            Image(systemName: confidenceIcon(for: result.confidenceLevel))
                                .font(.system(size: 10))
                            Text("\(Int(result.confidence * 100))%")
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                        }
                        .foregroundColor(confidenceColor(for: result.confidenceLevel))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(confidenceColor(for: result.confidenceLevel).opacity(0.15))
                        .cornerRadius(CornerRadius.sm)
                    }

                    Text("\(extractedText.count) characters")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondaryText)
                }

                ScrollView {
                    Text(extractedText)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxHeight: 200)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.cosmicPurple.opacity(0.05))
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color.cosmicPurple.opacity(0.1))
            )

            // Generate flashcards button
            HapticButton(hapticStyle: .heavy) {
                generateFlashcards()
            } label: {
                HStack {
                    if isGeneratingCards {
                        ProgressView()
                            .tint(.white)
                        Text("Generating...")
                    } else {
                        Image(systemName: "sparkles")
                        Text("Generate Flashcards")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(MagicButtonStyle())
            .disabled(isGeneratingCards)
        }
    }

    // MARK: - Actions

    private func loadSelectedPhoto() async {
        guard let selectedPhoto else { return }

        do {
            if let data = try await selectedPhoto.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    self.selectedImage = image
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load photo. Please try again."
                showError = true
            }
        }
    }

    private func extractTextFromImage(_ image: UIImage) async {
        analytics.trackScanAttempt()

        do {
            let result = try await extractor.extractTextWithMetadata(from: image)
            extractedText = result.text
            extractionResult = result
            analytics.trackScanSuccess(characterCount: result.characterCount, confidence: result.confidence)

            // Check for low confidence
            if result.confidenceLevel == .low || result.confidenceLevel == .veryLow {
                showLowConfidenceWarning = true
                analytics.trackLowConfidenceWarning()
            }

            HapticFeedback.success()
        } catch let error as VisionError {
            analytics.trackScanFailure(reason: error.localizedDescription)
            await MainActor.run {
                errorMessage = error.errorDescription
                showError = true
                HapticFeedback.error()
            }
        } catch {
            analytics.trackScanFailure(reason: error.localizedDescription)
            await MainActor.run {
                errorMessage = "Text extraction failed. Please try again."
                showError = true
                HapticFeedback.error()
            }
        }
    }

    private func extractTextFromMultipleImages(_ images: [UIImage]) async {
        analytics.trackScanAttempt()
        analytics.trackMultiPageScan(pageCount: images.count)

        do {
            var allText: [String] = []
            var totalConfidence: Double = 0
            var hasLowConfidence = false

            for (index, image) in images.enumerated() {
                let result = try await extractor.extractTextWithMetadata(from: image)
                allText.append("--- Page \(index + 1) ---\n\n\(result.text)")
                totalConfidence += result.confidence

                if result.confidenceLevel == .low || result.confidenceLevel == .veryLow {
                    hasLowConfidence = true
                }
            }

            extractedText = allText.joined(separator: "\n\n")
            let avgConfidence = totalConfidence / Double(images.count)

            // Create combined result
            extractionResult = TextExtractionResult(
                text: extractedText,
                confidence: avgConfidence,
                detectedLanguages: [],
                blockCount: images.count,
                characterCount: extractedText.count,
                preprocessingApplied: true
            )

            analytics.trackScanSuccess(characterCount: extractedText.count, confidence: avgConfidence)

            if hasLowConfidence {
                showLowConfidenceWarning = true
                analytics.trackLowConfidenceWarning()
            }

            HapticFeedback.success()
        } catch let error as VisionError {
            analytics.trackScanFailure(reason: error.localizedDescription)
            await MainActor.run {
                errorMessage = error.errorDescription
                showError = true
                HapticFeedback.error()
            }
        } catch {
            analytics.trackScanFailure(reason: error.localizedDescription)
            await MainActor.run {
                errorMessage = "Text extraction failed. Please try again."
                showError = true
                HapticFeedback.error()
            }
        }
    }

    private func generateFlashcards() {
        guard !extractedText.isEmpty else { return }

        isGeneratingCards = true
        HapticFeedback.heavy()

        Task {
            do {
                // Create StudyContent from photo
                let content = StudyContent(
                    source: .photo,
                    rawContent: extractedText
                )

                // Store images based on scan type
                if isMultiPage && !selectedImages.isEmpty {
                    content.photoPages = selectedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
                    content.pageCount = selectedImages.count
                } else if let image = selectedImage {
                    content.photoData = image.jpegData(compressionQuality: 0.8)
                    content.pageCount = 1
                }

                // Save the content first
                modelContext.insert(content)

                // Generate flashcards using AI
                let flashcardFormats: Set<FlashcardType> = [.cloze, .qa, .definition]
                let result = try await fmClient.generateFlashcards(
                    from: content,
                    formats: flashcardFormats,
                    maxPerFormat: 3
                )

                // Find or create flashcard set for this topic
                let flashcardSet = modelContext.findOrCreateFlashcardSet(topicLabel: result.topicTag)

                // Link flashcards to content and set
                content.flashcards.append(contentsOf: result.flashcards)
                for flashcard in result.flashcards {
                    flashcardSet.addCard(flashcard)
                    modelContext.insert(flashcard)
                }
                flashcardSet.entryCount += 1

                // Save everything
                try modelContext.save()

                await MainActor.run {
                    isGeneratingCards = false
                    HapticFeedback.success()
                    dismiss()
                }

            } catch {
                await MainActor.run {
                    isGeneratingCards = false
                    errorMessage = "Failed to generate flashcards. Please try again."
                    showError = true
                    HapticFeedback.error()
                }
            }
        }
    }

    private func resetScan() {
        selectedImage = nil
        selectedImages = []
        extractedText = ""
        selectedPhoto = nil
        documentScanResult = nil
        errorMessage = nil
        isMultiPage = false
        extractionResult = nil
        showLowConfidenceWarning = false
    }

    // MARK: - Helper Functions

    private func confidenceColor(for level: ConfidenceLevel) -> Color {
        switch level {
        case .high: return .genieGreen
        case .medium: return .yellow
        case .low: return .orange
        case .veryLow: return .red
        }
    }

    private func confidenceIcon(for level: ConfidenceLevel) -> String {
        switch level {
        case .high: return "checkmark.circle.fill"
        case .medium: return "checkmark.circle"
        case .low: return "exclamationmark.triangle"
        case .veryLow: return "xmark.circle"
        }
    }
}

// MARK: - Camera View

/// Camera interface using UIImagePickerController
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

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = (try? ModelContainer(
        for: StudyContent.self, Flashcard.self, FlashcardSet.self,
        configurations: config
    )) ?? {
        try! ModelContainer(for: StudyContent.self, Flashcard.self, FlashcardSet.self)
    }()

    PhotoScanView()
        .modelContainer(container)
}

// MARK: - ScanReviewView


/// A section of extracted text with metadata
struct TextSection: Identifiable, Codable {
    let id: UUID
    var text: String
    var type: SectionType
    var isSelected: Bool

    init(id: UUID = UUID(), text: String, type: SectionType = .paragraph, isSelected: Bool = true) {
        self.id = id
        self.text = text
        self.type = type
        self.isSelected = isSelected
    }
}

enum SectionType: String, Codable, CaseIterable {
    case heading
    case paragraph
    case list
    case definition
    case equation

    var icon: String {
        switch self {
        case .heading: return "text.alignleft"
        case .paragraph: return "text.justify"
        case .list: return "list.bullet"
        case .definition: return "book.closed"
        case .equation: return "function"
        }
    }

    var color: Color {
        switch self {
        case .heading: return .purple
        case .paragraph: return .blue
        case .list: return .green
        case .definition: return .orange
        case .equation: return .red
        }
    }
}

/// Review and organize scanned text before generating flashcards
struct ScanReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let extractedText: String
    let images: [UIImage]
    let isMultiPage: Bool
    let extractionResult: TextExtractionResult?

    @State private var sections: [TextSection] = []
    @State private var selectedTopic: String = ""
    @State private var selectedDeck: String = ""
    @State private var editingSection: TextSection?
    @State private var showTopicPicker = false
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showVoiceAssistant = false

    @StateObject private var fmClient = FMClient()

    // Common topics for quick selection
    private let suggestedTopics = [
        "Biology", "Chemistry", "Physics", "Mathematics",
        "History", "Geography", "Literature", "Computer Science",
        "Medicine", "Psychology", "Economics", "Engineering"
    ]

    init(extractedText: String, images: [UIImage] = [], isMultiPage: Bool = false, extractionResult: TextExtractionResult? = nil) {
        self.extractedText = extractedText
        self.images = images
        self.isMultiPage = isMultiPage
        self.extractionResult = extractionResult
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Scan info header
                    scanInfoHeader

                    // Topic and deck selection
                    topicSelectionSection

                    // Sections list
                    sectionsListView

                    // Talk about this button
                    talkAboutThisButton

                    // Generate button
                    generateButton
                }
                .padding()
            }
            .navigationTitle("Review & Organize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $editingSection) { section in
                SectionEditorView(section: Binding(
                    get: { section },
                    set: { updated in
                        if let index = sections.firstIndex(where: { $0.id == section.id }) {
                            sections[index] = updated
                        }
                    }
                ))
            }
            .sheet(isPresented: $showVoiceAssistant) {
                // Create temporary StudyContent for context
                let tempContent = StudyContent(source: .photo, rawContent: extractedText)
                tempContent.topic = selectedTopic.isEmpty ? "Scanned Content" : selectedTopic
                tempContent.extractedText = extractedText

                let context = ConversationContext(studyContent: tempContent)
                return VoiceAssistantView(context: context)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
        .onAppear {
            analyzeSections()
        }
    }

    // MARK: - View Components

    private var scanInfoHeader: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Image(systemName: isMultiPage ? "doc.text" : "doc.plaintext")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.magicGradient)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isMultiPage ? "\(images.count) Pages Scanned" : "Single Page Scan")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.primaryText)

                    Text("\(extractedText.count) characters • \(sections.count) sections")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondaryText)

                    if let result = extractionResult {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                            Text("\(result.confidenceLevel.rawValue) Confidence")
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                        }
                        .foregroundColor(confidenceColor(for: result.confidenceLevel))
                    }
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color.cosmicPurple.opacity(0.1))
            )
        }
    }

    private var topicSelectionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Organization")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundColor(.primaryText)
                .textCase(.uppercase)

            // Topic field
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Topic")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondaryText)

                TextField("e.g., Cell Biology, World War II", text: $selectedTopic)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .rounded))
            }

            // Suggested topics
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(suggestedTopics, id: \.self) { topic in
                        Button(topic) {
                            selectedTopic = topic
                            HapticFeedback.light()
                        }
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(selectedTopic == topic ? Color.cosmicPurple : Color.cosmicPurple.opacity(0.1))
                        )
                        .foregroundColor(selectedTopic == topic ? .white : .cosmicPurple)
                    }
                }
            }

            // Deck field (optional)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Deck (Optional)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondaryText)

                TextField("Add to specific deck", text: $selectedDeck)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .rounded))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.cosmicPurple.opacity(0.05))
        )
    }

    private var sectionsListView: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Text Sections")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primaryText)
                    .textCase(.uppercase)

                Spacer()

                Text("\(sections.filter(\.isSelected).count)/\(sections.count) selected")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondaryText)
            }

            ForEach($sections) { $section in
                SectionRowView(
                    section: $section,
                    onEdit: {
                        editingSection = section
                    },
                    onDelete: {
                        withAnimation {
                            sections.removeAll { $0.id == section.id }
                        }
                    }
                )
            }

            // Add section button
            Button {
                let newSection = TextSection(text: "", type: .paragraph, isSelected: true)
                sections.append(newSection)
                editingSection = newSection
            } label: {
                Label("Add Section", systemImage: "plus.circle")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.cosmicPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .strokeBorder(Color.cosmicPurple, lineWidth: 1.5, antialiased: true)
                    )
            }
        }
    }

    private var talkAboutThisButton: some View {
        Button {
            showVoiceAssistant = true
        } label: {
            HStack {
                Image(systemName: "waveform.circle.fill")
                Text("Talk About This")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.gradient)
            .foregroundStyle(.white)
            .cornerRadius(CornerRadius.md)
            .font(.system(.body, design: .rounded, weight: .semibold))
        }
    }

    private var generateButton: some View {
        HapticButton(hapticStyle: .heavy) {
            generateFlashcards()
        } label: {
            HStack {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                    Text("Generating...")
                } else {
                    Image(systemName: "sparkles")
                    Text("Generate Flashcards")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(MagicButtonStyle())
        .disabled(isGenerating || sections.filter(\.isSelected).isEmpty || selectedTopic.isEmpty)
    }

    // MARK: - Helper Functions

    private func analyzeSections() {
        // Parse extracted text into logical sections
        let lines = extractedText.components(separatedBy: "\n")
        var currentSection = ""
        var detectedSections: [TextSection] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                // Empty line - end current section
                if !currentSection.isEmpty {
                    detectedSections.append(
                        TextSection(
                            text: currentSection.trimmingCharacters(in: .whitespacesAndNewlines),
                            type: detectSectionType(currentSection)
                        )
                    )
                    currentSection = ""
                }
            } else {
                currentSection += line + "\n"
            }
        }

        // Add final section if any
        if !currentSection.isEmpty {
            detectedSections.append(
                TextSection(
                    text: currentSection.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: detectSectionType(currentSection)
                )
            )
        }

        sections = detectedSections.isEmpty ? [TextSection(text: extractedText, type: .paragraph)] : detectedSections
    }

    private func detectSectionType(_ text: String) -> SectionType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: "\n")

        // Check for heading (short, all caps, or ends with colon)
        if lines.count == 1 {
            if trimmed.count < 60 && (trimmed == trimmed.uppercased() || trimmed.hasSuffix(":")) {
                return .heading
            }
        }

        // Check for list (multiple lines starting with bullets or numbers)
        let bulletPatterns = ["•", "-", "*", "◦"]
        let listLines = lines.filter { line in
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            return bulletPatterns.contains(where: { trimmedLine.hasPrefix($0) }) ||
                   trimmedLine.range(of: "^\\d+\\.", options: .regularExpression) != nil
        }
        if listLines.count >= 2 {
            return .list
        }

        // Check for definition (contains "is", "are", "means", "refers to")
        if trimmed.contains(":") || trimmed.range(of: "\\b(is|are|means|refers to|defined as)\\b", options: .regularExpression) != nil {
            return .definition
        }

        // Check for equation (contains mathematical symbols)
        if trimmed.range(of: "[=+\\-×÷∫∑√]", options: .regularExpression) != nil {
            return .equation
        }

        return .paragraph
    }

    private func confidenceColor(for level: ConfidenceLevel) -> Color {
        switch level {
        case .high: return .genieGreen
        case .medium: return .yellow
        case .low: return .orange
        case .veryLow: return .red
        }
    }

    private func generateFlashcards() {
        guard !sections.filter(\.isSelected).isEmpty else { return }

        isGenerating = true
        HapticFeedback.heavy()

        Task {
            do {
                // Combine selected sections
                let selectedText = sections
                    .filter(\.isSelected)
                    .map(\.text)
                    .joined(separator: "\n\n")

                // Create StudyContent
                let content = StudyContent(
                    source: .photo,
                    rawContent: selectedText
                )
                content.topic = selectedTopic.isEmpty ? nil : selectedTopic
                content.extractedText = extractedText

                // Store images
                if isMultiPage {
                    content.photoPages = images.compactMap { $0.jpegData(compressionQuality: 0.8) }
                    content.pageCount = images.count
                } else if let image = images.first {
                    content.photoData = image.jpegData(compressionQuality: 0.8)
                    content.pageCount = 1
                }

                modelContext.insert(content)

                // Generate flashcards
                let flashcardFormats: Set<FlashcardType> = recommendFlashcardFormats()
                let result = try await fmClient.generateFlashcards(
                    from: content,
                    formats: flashcardFormats,
                    maxPerFormat: 3
                )

                // Find or create flashcard set
                let deckName = selectedDeck.isEmpty ? (selectedTopic.isEmpty ? result.topicTag : selectedTopic) : selectedDeck
                let flashcardSet = modelContext.findOrCreateFlashcardSet(topicLabel: deckName)

                // Link flashcards
                content.flashcards.append(contentsOf: result.flashcards)
                for flashcard in result.flashcards {
                    flashcardSet.addCard(flashcard)
                    modelContext.insert(flashcard)
                }
                flashcardSet.entryCount += 1

                try modelContext.save()

                await MainActor.run {
                    isGenerating = false
                    HapticFeedback.success()
                    dismiss()
                }

            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = "Failed to generate flashcards. Please try again."
                    showError = true
                    HapticFeedback.error()
                }
            }
        }
    }

    private func recommendFlashcardFormats() -> Set<FlashcardType> {
        var formats: Set<FlashcardType> = [.qa]

        // Analyze section types to recommend formats
        let sectionTypes = sections.filter(\.isSelected).map(\.type)

        if sectionTypes.contains(.definition) {
            formats.insert(.definition)
        }

        if sectionTypes.contains(.list) {
            formats.insert(.cloze)
        }

        if sectionTypes.contains(.equation) {
            formats.insert(.cloze)
        }

        return formats
    }
}

// MARK: - Section Row View

struct SectionRowView: View {
    @Binding var section: TextSection
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Selection toggle
            Button {
                section.isSelected.toggle()
                HapticFeedback.light()
            } label: {
                Image(systemName: section.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(section.isSelected ? .cosmicPurple : .gray)
            }

            // Section content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Image(systemName: section.type.icon)
                        .font(.system(size: 12))
                        .foregroundColor(section.type.color)

                    Text(section.type.rawValue.capitalized)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundColor(section.type.color)
                        .textCase(.uppercase)

                    Spacer()

                    Text("\(section.text.count) chars")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondaryText)
                }

                Text(section.text)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.primaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            // Actions
            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(.secondaryText)
                    .padding(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(section.isSelected ? Color.cosmicPurple.opacity(0.1) : Color.gray.opacity(0.05))
        )
    }
}

// MARK: - Section Editor View

struct SectionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var section: TextSection

    @State private var editedText: String
    @State private var editedType: SectionType

    init(section: Binding<TextSection>) {
        self._section = section
        self._editedText = State(initialValue: section.wrappedValue.text)
        self._editedType = State(initialValue: section.wrappedValue.type)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Section Type") {
                    Picker("Type", selection: $editedType) {
                        ForEach(SectionType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue.capitalized)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Content") {
                    TextEditor(text: $editedText)
                        .frame(minHeight: 200)
                        .font(.system(.body, design: .rounded))
                }

                Section {
                    Text("\(editedText.count) characters")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondaryText)
                }
            }
            .navigationTitle("Edit Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        section.text = editedText
                        section.type = editedType
                        dismiss()
                    }
                    .disabled(editedText.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleText = """
    Cell Biology Introduction

    Cells are the basic building blocks of all living things. The human body is composed of trillions of cells.

    Key Components:
    • Nucleus - contains genetic material
    • Mitochondria - produces energy
    • Cell membrane - controls what enters and exits

    Photosynthesis Process

    Photosynthesis is the process by which plants convert light energy into chemical energy. The equation is:
    6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂
    """

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = (try? ModelContainer(
        for: StudyContent.self, Flashcard.self, FlashcardSet.self,
        configurations: config
    )) ?? {
        try! ModelContainer(for: StudyContent.self, Flashcard.self, FlashcardSet.self)
    }()

    return ScanReviewView(
        extractedText: sampleText,
        images: [],
        isMultiPage: false
    )
    .modelContainer(container)
}

// MARK: - DocumentScannerView


/// Result of a document scan operation
struct DocumentScanResult: Identifiable, Equatable {
    let id: UUID
    let images: [UIImage]
    let pageCount: Int

    init(images: [UIImage]) {
        self.id = UUID()
        self.images = images
        self.pageCount = images.count
    }

    static func == (lhs: DocumentScanResult, rhs: DocumentScanResult) -> Bool {
        lhs.id == rhs.id
    }
}

/// SwiftUI wrapper for VNDocumentCameraViewController
struct DocumentScannerView: UIViewControllerRepresentable {
    @Binding var result: DocumentScanResult?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView

        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var images: [UIImage] = []

            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                images.append(image)
            }

            parent.result = DocumentScanResult(images: images)
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            print("Document scanning failed: \(error.localizedDescription)")
            parent.dismiss()
        }
    }
}

/// Check if document scanning is available on the current device
struct DocumentScanningCapability {
    static var isAvailable: Bool {
        VNDocumentCameraViewController.isSupported
    }

    static var requiresiOS13: Bool {
        if #available(iOS 13.0, *) {
            return true
        }
        return false
    }
}
