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

/// Photo scanning interface with text extraction and flashcard generation
struct PhotoScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var extractor = VisionTextExtractor()
    @StateObject private var fmClient = FMClient()

    @State private var selectedImage: UIImage?
    @State private var extractedText = ""
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var isGeneratingCards = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        if let image = selectedImage {
                            // Show captured/selected image
                            imagePreviewSection(image: image)

                            if extractor.isProcessing {
                                // Text extraction in progress
                                loadingSection
                            } else if !extractedText.isEmpty {
                                // Show extracted text
                                extractedTextSection
                            }
                        } else {
                            // Initial state - show scanning options
                            emptyStateSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Scan Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedImage != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Reset") {
                            resetScan()
                        }
                        .foregroundColor(.cosmicPurple)
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView(image: $selectedImage)
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedPhoto,
                matching: .images
            )
            .onChange(of: selectedPhoto) { oldValue, newValue in
                Task {
                    await loadSelectedPhoto()
                }
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                if let image = newValue {
                    Task {
                        await extractTextFromImage(image)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
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
        do {
            extractedText = try await extractor.extractText(from: image)
            HapticFeedback.success()
        } catch let error as VisionError {
            await MainActor.run {
                errorMessage = error.errorDescription
                showError = true
                HapticFeedback.error()
            }
        } catch {
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
                content.photoData = selectedImage?.jpegData(compressionQuality: 0.8)

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
        extractedText = ""
        selectedPhoto = nil
        errorMessage = nil
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
