//
//  ARMemoryPalaceView.swift
//  CardGenie
//
//  AR view for placing flashcards in physical space.
//

import SwiftUI
import ARKit
import RealityKit
import SwiftData

// MARK: - AR Memory Palace View

struct ARMemoryPalaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let flashcardSet: FlashcardSet

    @State private var arManager = ARMemoryPalaceManager()
    @State private var selectedCard: Flashcard?
    @State private var placementMode = false
    @State private var locationLabel = ""
    @State private var showLocationPrompt = false

    var body: some View {
        ZStack {
            // AR View
            ARViewContainer(arManager: arManager)
                .ignoresSafeArea()

            VStack {
                // Top Status Bar
                HStack {
                    Button("Done") {
                        arManager.stopSession()
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    if let trackingState = arManager.trackingState {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(trackingState.isGood ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(trackingState.description)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                    }
                }
                .padding()

                Spacer()

                // Nearby Cards Display
                if !arManager.nearbyCards.isEmpty {
                    VStack(spacing: 12) {
                        Text("Nearby Cards")
                            .font(.headline)

                        ForEach(arManager.nearbyCards, id: \.id) { card in
                            CardPreviewView(card: card)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding()
                }

                // Bottom Controls
                VStack(spacing: 16) {
                    if placementMode {
                        PlacementControls(
                            selectedCard: selectedCard,
                            onPlace: { label in
                                placeCard(label: label)
                            },
                            onCancel: {
                                placementMode = false
                                selectedCard = nil
                            }
                        )
                    } else {
                        CardSelectionControls(
                            flashcardSet: flashcardSet,
                            onSelectCard: { card in
                                selectedCard = card
                                placementMode = true
                            }
                        )
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            arManager.startSession(for: flashcardSet, context: modelContext)
        }
        .onDisappear {
            arManager.stopSession()
        }
    }

    private func placeCard(label: String) {
        guard let card = selectedCard,
              let transform = arManager.getPlacementTransform() else { return }

        arManager.placeCard(card, at: transform, locationLabel: label)

        placementMode = false
        selectedCard = nil
    }
}

// MARK: - AR View Container

struct ARViewContainer: UIViewRepresentable {
    let arManager: ARMemoryPalaceManager

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR view
        arView.session = arManager.arSession

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Update if needed
    }

    typealias UIViewType = ARView

    class ARView: UIView {
        var session: ARSession?
    }
}

// MARK: - Card Preview

struct CardPreviewView: View {
    let card: Flashcard

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.question)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)

            Text(card.answer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Placement Controls

struct PlacementControls: View {
    let selectedCard: Flashcard?
    let onPlace: (String) -> Void
    let onCancel: () -> Void

    @State private var locationLabel = ""

    var body: some View {
        VStack(spacing: 12) {
            if let card = selectedCard {
                Text("Place: \(card.question.prefix(50))")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }

            TextField("Location (e.g., Desk, Door, Bed)", text: $locationLabel)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .tint(.gray)

                Button("Place Here") {
                    onPlace(locationLabel.isEmpty ? "Location" : locationLabel)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCard == nil)
            }
        }
        .padding()
    }
}

// MARK: - Card Selection Controls

struct CardSelectionControls: View {
    let flashcardSet: FlashcardSet
    let onSelectCard: (Flashcard) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Select a card to place in AR")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(flashcardSet.cards.prefix(10), id: \.id) { card in
                        Button {
                            onSelectCard(card)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.question)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                Text(card.masteryLevel.emoji)
                                    .font(.title3)
                            }
                            .frame(width: 140, height: 80, alignment: .leading)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FlashcardSet.self, configurations: config)
    let set = FlashcardSet(topicLabel: "Biology", tag: "biology")

    return ARMemoryPalaceView(flashcardSet: set)
        .modelContainer(container)
}
