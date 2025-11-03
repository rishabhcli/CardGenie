//
//  ConceptMapView.swift
//  CardGenie
//
//  Interactive concept map visualization.
//  Visual knowledge graph for better understanding.
//

import SwiftUI
import SwiftData

// MARK: - Concept Map List View

struct ConceptMapListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var conceptMaps: [ConceptMap]

    @State private var showCreateMap = false

    var body: some View {
        NavigationStack {
            Group {
                if conceptMaps.isEmpty {
                    EmptyMapsView {
                        showCreateMap = true
                    }
                } else {
                    List {
                        ForEach(conceptMaps, id: \.id) { map in
                            NavigationLink(destination: ConceptMapDetailView(conceptMap: map)) {
                                ConceptMapRowView(conceptMap: map)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Concept Maps")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateMap = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showCreateMap) {
                CreateConceptMapView()
            }
        }
    }
}

// MARK: - Empty State

struct EmptyMapsView: View {
    let onCreate: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Concept Maps", systemImage: "diagram.fill")
        } description: {
            Text("Generate visual knowledge graphs from your notes")
        } actions: {
            Button("Create Map") {
                onCreate()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Concept Map Row

struct ConceptMapRowView: View {
    let conceptMap: ConceptMap

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(conceptMap.title)
                .font(.headline)

            HStack(spacing: 16) {
                Label("\(conceptMap.nodes.count)", systemImage: "circle")
                Label("\(conceptMap.edges.count)", systemImage: "arrow.right")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(conceptMap.createdAt, format: .dateTime.month().day().year())
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Concept Map Detail View

struct ConceptMapDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let conceptMap: ConceptMap

    @State private var selectedNode: ConceptNode?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        ZStack {
            // Graph visualization
            GeometryReader { geometry in
                ZStack {
                    // Edges (connections)
                    ForEach(conceptMap.edges, id: \.id) { edge in
                        if let source = conceptMap.nodes.first(where: { $0.id == edge.sourceNodeID }),
                           let target = conceptMap.nodes.first(where: { $0.id == edge.targetNodeID }) {
                            EdgeView(
                                source: CGPoint(x: source.layoutX, y: source.layoutY),
                                target: CGPoint(x: target.layoutX, y: target.layoutY),
                                strength: edge.strength
                            )
                        }
                    }

                    // Nodes (concepts)
                    ForEach(conceptMap.nodes, id: \.id) { node in
                        NodeView(
                            node: node,
                            isSelected: selectedNode?.id == node.id,
                            onTap: {
                                selectedNode = node
                            }
                        )
                        .position(x: node.layoutX, y: node.layoutY)
                    }
                }
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = value
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = value.translation
                        }
                )
            }
            .background(Color(uiColor: .systemBackground))

            // Selected node detail
            if let node = selectedNode {
                VStack {
                    Spacer()

                    NodeDetailCard(node: node, onClose: {
                        selectedNode = nil
                    })
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .navigationTitle(conceptMap.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    resetView()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }

    private func resetView() {
        withAnimation {
            scale = 1.0
            offset = .zero
        }
    }
}

// MARK: - Edge View

struct EdgeView: View {
    let source: CGPoint
    let target: CGPoint
    let strength: Double

    var body: some View {
        Path { path in
            path.move(to: source)
            path.addLine(to: target)
        }
        .stroke(
            Color.blue.opacity(strength * 0.5),
            lineWidth: strength * 3
        )
    }
}

// MARK: - Node View

struct NodeView: View {
    let node: ConceptNode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(isSelected ? Color.blue : Color.purple)
                    .frame(width: nodeSize, height: nodeSize)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                    }

                Text(node.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? .blue : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
            }
        }
        .buttonStyle(.plain)
    }

    private var nodeSize: CGFloat {
        let baseSize: CGFloat = 40
        let importanceMultiplier = 1.0 + (node.importance * 0.5)
        return baseSize * importanceMultiplier
    }
}

// MARK: - Node Detail Card

struct NodeDetailCard: View {
    let node: ConceptNode
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.name)
                        .font(.title2.weight(.bold))

                    Text(node.entityType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(node.definition)
                .font(.body)

            if !node.relatedFlashcardIDs.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.stack")
                    Text("\(node.relatedFlashcardIDs.count) related cards")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding()
    }
}

// MARK: - Create Concept Map View

struct CreateConceptMapView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var sourceDocuments: [SourceDocument]

    @State private var title = ""
    @State private var selectedDocuments: Set<UUID> = []
    @State private var isGenerating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Map Details") {
                    TextField("Title (e.g., Biology Overview)", text: $title)
                }

                Section("Source Documents") {
                    ForEach(sourceDocuments, id: \.id) { doc in
                        Toggle(isOn: Binding(
                            get: { selectedDocuments.contains(doc.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedDocuments.insert(doc.id)
                                } else {
                                    selectedDocuments.remove(doc.id)
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.fileName)
                                    .font(.subheadline)
                                Text("\(doc.chunks.count) chunks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create Concept Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        generateMap()
                    }
                    .disabled(title.isEmpty || selectedDocuments.isEmpty || isGenerating)
                }
            }
            .overlay {
                if isGenerating {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Extracting concepts...")
                        Text("This may take a moment")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
            }
        }
    }

    private func generateMap() {
        isGenerating = true

        Task {
            let generator = ConceptMapGenerator(modelContext: modelContext)

            do {
                let docs = sourceDocuments.filter { selectedDocuments.contains($0.id) }

                _ = try await generator.generateConceptMap(
                    title: title,
                    sourceDocuments: docs
                )

                await MainActor.run {
                    isGenerating = false
                    dismiss()
                }
            } catch {
                print("Failed to generate concept map: \(error)")
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ConceptMapListView()
        .modelContainer(for: [ConceptMap.self, ConceptNode.self, ConceptEdge.self])
}
