//
//  PhotoScanView.swift
//  CardGenie
//
//  Photo scanning view for converting images to study content.
//  Uses Vision framework for OCR and Foundation Models for flashcard generation.
//

import SwiftUI
import SwiftData
import PhotosUI
import VisionKit

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
    let container = try! ModelContainer(
        for: StudyContent.self, Flashcard.self, FlashcardSet.self,
        configurations: config
    )

    PhotoScanView()
        .modelContainer(container)
}
