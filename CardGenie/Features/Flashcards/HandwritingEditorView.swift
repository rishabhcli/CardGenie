//
//  HandwritingEditorView.swift
//  CardGenie
//
//  PencilKit editor for handwritten flashcards.
//  Handwriting improves retention by 40%.
//

import SwiftUI
import PencilKit
import SwiftData

// MARK: - Handwriting Editor View

struct HandwritingEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let flashcard: Flashcard

    @State private var questionCanvas = PKCanvasView()
    @State private var answerCanvas = PKCanvasView()
    @State private var currentSide: CardSide = .question
    @State private var isProcessing = false
    @State private var showOCRText = false
    @State private var ocrText = ""

    enum CardSide {
        case question, answer
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Side Selector
                Picker("Side", selection: $currentSide) {
                    Text("Question").tag(CardSide.question)
                    Text("Answer").tag(CardSide.answer)
                }
                .pickerStyle(.segmented)
                .padding()

                // Canvas
                ZStack {
                    if currentSide == .question {
                        CanvasView(canvasView: $questionCanvas)
                    } else {
                        CanvasView(canvasView: $answerCanvas)
                    }

                    // Placeholder text
                    if currentCanvas.drawing.bounds.isEmpty {
                        VStack {
                            Image(systemName: "pencil.tip")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)

                            Text("Start writing with Apple Pencil")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Text(currentSide == .question ? "Write your question" : "Write your answer")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                        .allowsHitTesting(false)
                    }
                }

                Divider()

                // Toolbar
                HStack(spacing: 16) {
                    // Clear button
                    Button {
                        currentCanvas.drawing = PKDrawing()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    // OCR button
                    Button {
                        extractText()
                    } label: {
                        Label("Extract Text", systemImage: "text.viewfinder")
                    }
                    .buttonStyle(.bordered)
                    .disabled(currentCanvas.drawing.bounds.isEmpty)

                    // Save button
                    Button("Save") {
                        saveHandwriting()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(questionCanvas.drawing.bounds.isEmpty && answerCanvas.drawing.bounds.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Handwritten Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isProcessing {
                    ProgressView("Saving...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
            .sheet(isPresented: $showOCRText) {
                OCRResultView(text: ocrText, side: currentSide) {
                    if currentSide == .question {
                        flashcard.question = ocrText
                    } else {
                        flashcard.answer = ocrText
                    }
                    try? modelContext.save()
                    showOCRText = false
                }
            }
        }
        .onAppear {
            loadExistingDrawings()
        }
    }

    private var currentCanvas: PKCanvasView {
        currentSide == .question ? questionCanvas : answerCanvas
    }

    private func loadExistingDrawings() {
        guard let handwriting = flashcard.handwritingData else { return }

        if let qDrawing = try? handwriting.getQuestionDrawing() {
            questionCanvas.drawing = qDrawing
        }

        if let aDrawing = try? handwriting.getAnswerDrawing() {
            answerCanvas.drawing = aDrawing
        }
    }

    private func saveHandwriting() {
        isProcessing = true

        Task {
            let processor = HandwritingProcessor(modelContext: modelContext)

            let qDrawing = questionCanvas.drawing.bounds.isEmpty ? nil : questionCanvas.drawing
            let aDrawing = answerCanvas.drawing.bounds.isEmpty ? nil : answerCanvas.drawing

            do {
                try await processor.saveHandwriting(
                    for: flashcard,
                    questionDrawing: qDrawing,
                    answerDrawing: aDrawing
                )

                await MainActor.run {
                    isProcessing = false
                    dismiss()
                }
            } catch {
                print("Failed to save handwriting: \(error)")
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }

    private func extractText() {
        isProcessing = true

        Task {
            let drawing = currentCanvas.drawing
            _ = drawing.image(from: drawing.bounds, scale: 2.0)

            _ = HandwritingProcessor(modelContext: modelContext)

            // For now, just show placeholder
            ocrText = "OCR text will appear here"

            await MainActor.run {
                isProcessing = false
                showOCRText = true
            }
        }
    }
}

// MARK: - Canvas View Wrapper

struct CanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 3)
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .systemBackground
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Update if needed
    }
}

// MARK: - OCR Result View

struct OCRResultView: View {
    let text: String
    let side: HandwritingEditorView.CardSide
    let onAccept: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Extracted Text")
                    .font(.headline)

                ScrollView {
                    Text(text)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }

                Text("Use this text for the \(side == .question ? "question" : "answer")?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button("Use Text") {
                        onAccept()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = (try? ModelContainer(for: Flashcard.self, configurations: config)) ?? {
        try! ModelContainer(for: Flashcard.self)
    }()

    let card = Flashcard(
        type: .qa,
        question: "Test Question",
        answer: "Test Answer",
        linkedEntryID: UUID()
    )

    return HandwritingEditorView(flashcard: card)
        .modelContainer(container)
}
