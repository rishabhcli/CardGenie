//
//  ConceptMapGenerator.swift
//  CardGenie
//
//  Auto-generate concept maps from notes using NaturalLanguage.
//  Extract entities and relationships, visualize knowledge graph.
//

import Foundation
import NaturalLanguage
import SwiftData

// MARK: - Concept Map Generator

final class ConceptMapGenerator {
    private let llm: LLMEngine
    private let modelContext: ModelContext

    init(llm: LLMEngine = AIEngineFactory.createLLMEngine(), modelContext: ModelContext) {
        self.llm = llm
        self.modelContext = modelContext
    }

    // MARK: - Generate Concept Map

    /// Generate a concept map from source documents
    func generateConceptMap(
        title: String,
        sourceDocuments: [SourceDocument]
    ) async throws -> ConceptMap {
        // Create concept map
        let conceptMap = ConceptMap(
            title: title,
            sourceDocumentIDs: sourceDocuments.map { $0.id }
        )

        // Extract all text from documents
        var allText = ""

        for doc in sourceDocuments {
            for chunk in doc.chunks {
                allText += chunk.text + "\n\n"
            }
        }

        // Extract entities using NaturalLanguage
        let entities = extractEntities(from: allText)

        // Create concept nodes
        var nodeMap: [String: ConceptNode] = [:]

        for entity in entities {
            let node = try await createConceptNode(
                entity: entity,
                documents: sourceDocuments
            )
            conceptMap.nodes.append(node)
            nodeMap[entity.name] = node
        }

        // Extract relationships
        let relationships = try await extractRelationships(
            entities: entities,
            text: allText
        )

        // Create edges
        for relationship in relationships {
            guard let sourceNode = nodeMap[relationship.source],
                  let targetNode = nodeMap[relationship.target] else { continue }

            let edge = ConceptEdge(
                sourceNodeID: sourceNode.id,
                targetNodeID: targetNode.id,
                relationshipType: relationship.type,
                strength: relationship.strength
            )
            conceptMap.edges.append(edge)
            edge.conceptMap = conceptMap
        }

        // Calculate importance scores
        calculateImportance(for: conceptMap)

        // Generate force-directed layout
        generateLayout(for: conceptMap)

        modelContext.insert(conceptMap)
        try modelContext.save()

        return conceptMap
    }

    // MARK: - Entity Extraction

    private func extractEntities(from text: String) -> [Entity] {
        var entities: [Entity] = []
        var entityCounts: [String: Int] = [:]

        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text

        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        let tags: [NLTag] = [.personalName, .placeName, .organizationName]

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: options
        ) { tag, tokenRange in
            if let tag = tag, tags.contains(tag) {
                let entity = String(text[tokenRange])
                entityCounts[entity, default: 0] += 1
            }
            return true
        }

        // Also extract nouns as potential concepts
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: options
        ) { tag, tokenRange in
            if tag == .noun {
                let noun = String(text[tokenRange])
                // Only include multi-character nouns
                if noun.count > 3 {
                    entityCounts[noun, default: 0] += 1
                }
            }
            return true
        }

        // Filter to top entities (mentioned at least twice)
        for (name, count) in entityCounts where count >= 2 {
            entities.append(Entity(
                name: name,
                type: determineEntityType(name, in: text),
                frequency: count
            ))
        }

        // Sort by frequency and take top 30
        return Array(entities.sorted { $0.frequency > $1.frequency }.prefix(30))
    }

    private func determineEntityType(_ entity: String, in text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        // Find entity in text
        if let range = text.range(of: entity) {
            let tag = tagger.tag(
                at: range.lowerBound,
                unit: .word,
                scheme: .nameType
            ).0

            if tag == .personalName { return "Person" }
            if tag == .placeName { return "Place" }
            if tag == .organizationName { return "Organization" }
        }

        // Use heuristics
        let lower = entity.lowercased()
        if lower.hasSuffix("tion") || lower.hasSuffix("sis") || lower.hasSuffix("ment") {
            return "Process"
        }
        if lower.hasSuffix("ology") || lower.hasSuffix("graphy") {
            return "Field"
        }

        return "Concept"
    }

    // MARK: - Concept Node Creation

    private func createConceptNode(
        entity: Entity,
        documents: [SourceDocument]
    ) async throws -> ConceptNode {
        // Find related chunks
        var relatedChunks: [NoteChunk] = []
        var relatedFlashcards: [Flashcard] = []

        for doc in documents {
            for chunk in doc.chunks where chunk.text.localizedCaseInsensitiveContains(entity.name) {
                relatedChunks.append(chunk)
            }

            for card in doc.generatedCards where
                card.question.localizedCaseInsensitiveContains(entity.name) ||
                card.answer.localizedCaseInsensitiveContains(entity.name) {
                relatedFlashcards.append(card)
            }
        }

        // Generate definition using LLM
        let contextText = relatedChunks.prefix(3).map { $0.text }.joined(separator: "\n\n")

        let definition: String
        if !contextText.isEmpty {
            let prompt = """
            Define the concept '\(entity.name)' based on this context.
            Give a clear, concise definition in 1-2 sentences.

            CONTEXT:
            \(contextText.prefix(800))

            DEFINITION:
            """

            definition = try await llm.complete(prompt, maxTokens: 100)
        } else {
            definition = entity.name
        }

        // Create node
        let node = ConceptNode(
            name: entity.name,
            entityType: entity.type,
            definition: definition.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        node.relatedFlashcardIDs = relatedFlashcards.map { $0.id }
        node.relatedChunkIDs = relatedChunks.map { $0.id }

        return node
    }

    // MARK: - Relationship Extraction

    private func extractRelationships(
        entities: [Entity],
        text: String
    ) async throws -> [Relationship] {
        var relationships: [Relationship] = []

        // Use LLM to extract relationships
        let entityNames = entities.map { $0.name }.joined(separator: ", ")

        let prompt = """
        Extract relationships between these concepts:
        \(entityNames)

        From this text:
        \(text.prefix(2000))

        For each relationship, specify:
        SOURCE | RELATIONSHIP | TARGET | STRENGTH (0.0-1.0)

        Example:
        Mitochondria | produces | ATP | 0.9
        Cell | contains | Nucleus | 0.8

        List relationships (one per line):
        """

        let response = try await llm.complete(prompt, maxTokens: 400)

        // Parse response
        let lines = response.components(separatedBy: .newlines)

        for line in lines {
            guard !line.isEmpty, line.contains("|") else { continue }

            let parts = line.components(separatedBy: "|").map {
                $0.trimmingCharacters(in: .whitespaces)
            }

            guard parts.count >= 4 else { continue }

            let source = parts[0]
            let relationType = parts[1]
            let target = parts[2]
            let strengthText = parts[3]

            // Validate entities exist
            guard entities.contains(where: { $0.name.localizedCaseInsensitiveCompare(source) == .orderedSame }),
                  entities.contains(where: { $0.name.localizedCaseInsensitiveCompare(target) == .orderedSame })
            else { continue }

            // Parse strength
            let strength = Double(strengthText) ?? 0.5

            relationships.append(Relationship(
                source: source,
                target: target,
                type: relationType,
                strength: strength
            ))
        }

        return relationships
    }

    // MARK: - Importance Calculation

    private func calculateImportance(for conceptMap: ConceptMap) {
        // Importance based on:
        // 1. Number of connections
        // 2. Number of related flashcards/chunks

        for node in conceptMap.nodes {
            let connectionCount = conceptMap.edges.filter {
                $0.sourceNodeID == node.id || $0.targetNodeID == node.id
            }.count

            let relatedCount = node.relatedFlashcardIDs.count + node.relatedChunkIDs.count

            // Normalize to 0-1
            let connectionScore = min(1.0, Double(connectionCount) / 5.0)
            let relatedScore = min(1.0, Double(relatedCount) / 10.0)

            node.importance = (connectionScore + relatedScore) / 2.0
        }
    }

    // MARK: - Layout Generation

    private func generateLayout(for conceptMap: ConceptMap) {
        let nodes = conceptMap.nodes
        let edges = conceptMap.edges

        guard !nodes.isEmpty else { return }

        // Simple force-directed layout (Fruchterman-Reingold)
        let width = 1000.0
        let height = 1000.0
        let iterations = 50

        // Initialize random positions
        for node in nodes {
            node.layoutX = Double.random(in: 100...width-100)
            node.layoutY = Double.random(in: 100...height-100)
        }

        // Force-directed iterations
        for _ in 0..<iterations {
            var forces: [UUID: (x: Double, y: Double)] = [:]

            // Initialize forces
            for node in nodes {
                forces[node.id] = (0, 0)
            }

            // Repulsive forces (all nodes)
            for i in 0..<nodes.count {
                for j in (i+1)..<nodes.count {
                    let node1 = nodes[i]
                    let node2 = nodes[j]

                    let dx = node2.layoutX - node1.layoutX
                    let dy = node2.layoutY - node1.layoutY
                    let distance = sqrt(dx * dx + dy * dy)

                    guard distance > 0 else { continue }

                    let repulsion = 10000.0 / (distance * distance)
                    let fx = (dx / distance) * repulsion
                    let fy = (dy / distance) * repulsion

                    forces[node1.id]!.x -= fx
                    forces[node1.id]!.y -= fy
                    forces[node2.id]!.x += fx
                    forces[node2.id]!.y += fy
                }
            }

            // Attractive forces (connected nodes)
            for edge in edges {
                guard let source = nodes.first(where: { $0.id == edge.sourceNodeID }),
                      let target = nodes.first(where: { $0.id == edge.targetNodeID }) else { continue }

                let dx = target.layoutX - source.layoutX
                let dy = target.layoutY - source.layoutY
                let distance = sqrt(dx * dx + dy * dy)

                guard distance > 0 else { continue }

                let attraction = distance / 100.0 * edge.strength
                let fx = (dx / distance) * attraction
                let fy = (dy / distance) * attraction

                forces[source.id]!.x += fx
                forces[source.id]!.y += fy
                forces[target.id]!.x -= fx
                forces[target.id]!.y -= fy
            }

            // Apply forces
            for node in nodes {
                let force = forces[node.id]!
                node.layoutX += force.x * 0.1
                node.layoutY += force.y * 0.1

                // Keep in bounds
                node.layoutX = max(50, min(width - 50, node.layoutX))
                node.layoutY = max(50, min(height - 50, node.layoutY))
            }
        }
    }
}

// MARK: - Supporting Types

private struct Entity {
    let name: String
    let type: String
    let frequency: Int
}

private struct Relationship {
    let source: String
    let target: String
    let type: String
    let strength: Double
}
