//
//  AdvancedProcessors.swift
//  CardGenie
//
//  Advanced features: math solving, concept maps, and voice tutoring.
//

import Foundation
import SwiftUI
import SwiftData
import Speech
import AVFoundation
import Vision
import NaturalLanguage
import OSLog
import Combine

// MARK: - MathSolver


// MARK: - Math Solver

final class MathSolver {
    private let llm: LLMEngine

    init(llm: LLMEngine = AIEngineFactory.createLLMEngine()) {
        self.llm = llm
    }

    // MARK: - Solve from Image

    /// Capture math problem from image and solve
    func solve(image: UIImage) async throws -> MathSolution {
        // 1. OCR the math
        let mathText = try await extractMath(from: image)

        // 2. Parse to normalized form
        let expression = try parseExpression(mathText)

        // 3. Solve symbolically
        let steps = try solveSymbolic(expression)

        // 4. Generate explanations with LLM
        let explanations = try await generateExplanations(steps: steps)

        return MathSolution(
            originalText: mathText,
            expression: expression,
            steps: steps,
            explanations: explanations
        )
    }

    // MARK: - Compare Student Answer

    /// "Why you're wrong" - compare student work with solution
    func compareAnswer(
        problem: String,
        studentAnswer: String,
        correctSolution: MathSolution
    ) async throws -> ComparisonResult {
        // Parse student's work
        let studentSteps = extractSteps(from: studentAnswer)

        // Find first divergence
        var divergenceIndex: Int?
        for (index, correctStep) in correctSolution.steps.enumerated() {
            if index < studentSteps.count {
                if !isEquivalent(studentSteps[index], correctStep.result) {
                    divergenceIndex = index
                    break
                }
            }
        }

        // Generate feedback
        let feedback: String
        let correction: String

        if let divIndex = divergenceIndex {
            let wrongStep = studentSteps[divIndex]
            let correctStep = correctSolution.steps[divIndex]

            let prompt = """
            A student made an error in their math work.

            PROBLEM: \(problem)

            STUDENT'S STEP \(divIndex + 1): \(wrongStep)
            CORRECT STEP \(divIndex + 1): \(correctStep.result)

            Explain in 2-3 sentences:
            1. What mistake the student made
            2. Why it's wrong
            3. What the correct next step should be

            Be encouraging and educational.

            EXPLANATION:
            """

            feedback = try await llm.complete(prompt)
            correction = correctStep.result
        } else {
            feedback = "Your work looks correct!"
            correction = ""
        }

        return ComparisonResult(
            isCorrect: divergenceIndex == nil,
            divergencePoint: divergenceIndex,
            feedback: feedback,
            correction: correction
        )
    }

    // MARK: - OCR Math

    private func extractMath(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw MathError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.customWords = [
                "x", "y", "dx", "dy", "sin", "cos", "tan",
                "lim", "log", "ln", "sqrt", "integral"
            ]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Expression Parsing

    private func parseExpression(_ text: String) throws -> MathExpression {
        // Normalize: remove spaces, convert symbols
        var normalized = text.replacingOccurrences(of: " ", with: "")
        normalized = normalized.replacingOccurrences(of: "×", with: "*")
        normalized = normalized.replacingOccurrences(of: "÷", with: "/")
        normalized = normalized.replacingOccurrences(of: "−", with: "-")

        // Detect type
        if normalized.contains("=") {
            // Equation
            let parts = normalized.components(separatedBy: "=")
            guard parts.count == 2 else {
                throw MathError.invalidExpression
            }
            return MathExpression(type: .equation, text: normalized)
        } else if normalized.contains("d/dx") || normalized.contains("∫") {
            // Calculus
            return MathExpression(type: .calculus, text: normalized)
        } else {
            // Simplification
            return MathExpression(type: .simplify, text: normalized)
        }
    }

    // MARK: - Symbolic Solver

    private func solveSymbolic(_ expr: MathExpression) throws -> [SolutionStep] {
        switch expr.type {
        case .equation:
            return solveEquation(expr.text)
        case .simplify:
            return simplifyExpression(expr.text)
        case .calculus:
            return solveCalculus(expr.text)
        }
    }

    private func solveEquation(_ equation: String) -> [SolutionStep] {
        var steps: [SolutionStep] = []

        // Simple linear equation solver (ax + b = c)
        // This is a simplified version - production would use a full CAS

        steps.append(SolutionStep(
            operation: "Given equation",
            result: equation,
            rule: "Starting point"
        ))

        // Pattern: ax + b = c
        if equation.range(of: #"^(\d*)x([+-]\d+)=(\d+)$"#, options: .regularExpression) != nil {

            // Extract coefficients (simplified)
            // Production version would use proper parsing

            steps.append(SolutionStep(
                operation: "Isolate variable term",
                result: "ax = c - b",
                rule: "Subtract b from both sides"
            ))

            steps.append(SolutionStep(
                operation: "Solve for x",
                result: "x = (c - b) / a",
                rule: "Divide both sides by a"
            ))
        }

        return steps
    }

    private func simplifyExpression(_ expr: String) -> [SolutionStep] {
        var steps: [SolutionStep] = []

        steps.append(SolutionStep(
            operation: "Original expression",
            result: expr,
            rule: "Given"
        ))

        // Simple algebraic simplifications
        // Production would use full symbolic algebra

        // Example: 2x + 3x → 5x
        let simplified = expr

        // Combine like terms (very simplified)
        if simplified.contains("+") {
            steps.append(SolutionStep(
                operation: "Combine like terms",
                result: simplified,
                rule: "Add coefficients of same variables"
            ))
        }

        return steps
    }

    private func solveCalculus(_ expr: String) -> [SolutionStep] {
        var steps: [SolutionStep] = []

        steps.append(SolutionStep(
            operation: "Given",
            result: expr,
            rule: "Calculus problem"
        ))

        // Simple derivatives
        if expr.contains("d/dx") {
            // Power rule, etc.
            steps.append(SolutionStep(
                operation: "Apply power rule",
                result: "d/dx(x^n) = nx^(n-1)",
                rule: "Power rule of differentiation"
            ))
        }

        return steps
    }

    // MARK: - LLM Explanations

    private func generateExplanations(steps: [SolutionStep]) async throws -> [String] {
        var explanations: [String] = []

        for step in steps {
            let prompt = """
            Explain this math step in simple terms for a student.

            STEP: \(step.operation)
            RESULT: \(step.result)
            RULE: \(step.rule)

            Write 1-2 sentences explaining why we do this step.

            EXPLANATION:
            """

            let explanation = try await llm.complete(prompt)
            explanations.append(explanation.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
        }

        return explanations
    }

    // MARK: - Helpers

    private func extractSteps(from work: String) -> [String] {
        // Extract steps from student's work
        // Look for line breaks or step markers
        return work.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func isEquivalent(_ expr1: String, _ expr2: String) -> Bool {
        // Simplified equivalence check
        // Production would use symbolic comparison
        let normalized1 = expr1.replacingOccurrences(of: " ", with: "")
        let normalized2 = expr2.replacingOccurrences(of: " ", with: "")
        return normalized1 == normalized2
    }
}

// MARK: - Models

struct MathExpression {
    enum ExpressionType {
        case equation
        case simplify
        case calculus
    }

    let type: ExpressionType
    let text: String
}

struct SolutionStep {
    let operation: String
    let result: String
    let rule: String
}

struct MathSolution {
    let originalText: String
    let expression: MathExpression
    let steps: [SolutionStep]
    let explanations: [String]
}

struct ComparisonResult {
    let isCorrect: Bool
    let divergencePoint: Int?
    let feedback: String
    let correction: String
}

// MARK: - Errors

enum MathError: LocalizedError {
    case invalidImage
    case invalidExpression
    case unsupportedOperation

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Invalid image format"
        case .invalidExpression: return "Could not parse math expression"
        case .unsupportedOperation: return "Math operation not yet supported"
        }
    }
}

// MARK: - ConceptMapGenerator


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

            definition = try await llm.complete(prompt)
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

        let response = try await llm.complete(prompt)

        // Parse response
        let lines = response.components(separatedBy: CharacterSet.newlines)

        for line in lines {
            guard !line.isEmpty, line.contains("|") else { continue }

            let parts = line.components(separatedBy: "|").map {
                $0.trimmingCharacters(in: CharacterSet.whitespaces)
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

// MARK: - VoiceTutor


// MARK: - Voice Tutor

@Observable
final class VoiceTutor: NSObject, AVSpeechSynthesizerDelegate {
    private let llm: LLMEngine
    nonisolated(unsafe) private let speechSynthesizer = AVSpeechSynthesizer()
    nonisolated(unsafe) private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    nonisolated(unsafe) private let audioEngine = AVAudioEngine()

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // State
    private(set) var isListening = false
    private(set) var isSpeaking = false
    private(set) var conversation: [ConversationTurn] = []
    private(set) var currentTranscript = ""

    // Context for tutoring
    private var topic: String = ""
    private var contextChunks: [NoteChunk] = []

    init(llm: LLMEngine = AIEngineFactory.createLLMEngine()) {
        self.llm = llm
        super.init()
        speechSynthesizer.delegate = self
    }

    // MARK: - Start Session

    func startSession(topic: String, context: [NoteChunk] = []) async throws {
        self.topic = topic
        self.contextChunks = context
        self.conversation = []

        // Initial greeting
        let greeting = "Hi! I'm your AI tutor. What would you like to learn about \(topic)?"
        await speak(greeting)

        conversation.append(ConversationTurn(
            role: .tutor,
            text: greeting,
            timestamp: Date()
        ))
    }

    // MARK: - Listening

    func startListening() throws {
        guard !isListening else { return }

        // Stop speaking if currently speaking (interrupt)
        if isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceTutorError.setupFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                self.currentTranscript = result.bestTranscription.formattedString

                if result.isFinal {
                    Task {
                        await self.handleUserInput(self.currentTranscript)
                    }
                }
            }

            if error != nil {
                self.stopListening()
            }
        }

        isListening = true
    }

    func stopListening() {
        guard isListening else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        isListening = false
    }

    // MARK: - Handle User Input

    private func handleUserInput(_ text: String) async {
        guard !text.isEmpty else { return }

        stopListening()

        // Add to conversation
        conversation.append(ConversationTurn(
            role: .student,
            text: text,
            timestamp: Date()
        ))

        // Generate tutor response
        do {
            let response = try await generateTutorResponse(userQuestion: text)

            conversation.append(ConversationTurn(
                role: .tutor,
                text: response,
                timestamp: Date()
            ))

            // Speak response
            await speak(response)

            // Automatically start listening again after speaking
            try? startListening()

        } catch {
            let errorMsg = "I'm sorry, I had trouble understanding that. Could you rephrase?"
            await speak(errorMsg)
            try? startListening()
        }
    }

    // MARK: - Generate Response

    private func generateTutorResponse(userQuestion: String) async throws -> String {
        // Build context from conversation history
        let conversationHistory = conversation.suffix(6)
            .map { turn -> String in
                let speaker: String
                switch turn.role {
                case .student:
                    speaker = "Student"
                case .tutor:
                    speaker = "Tutor"
                }
                return "\(speaker): \(turn.text)"
            }
            .joined(separator: "\n")

        // Add context from notes if available
        let notesContext = contextChunks.prefix(3)
            .map { $0.text }
            .joined(separator: "\n\n")

        let prompt = """
        You are a friendly, encouraging tutor helping a student learn about \(topic).

        CONVERSATION HISTORY:
        \(conversationHistory)

        REFERENCE NOTES:
        \(notesContext.isEmpty ? "No notes available" : notesContext)

        STUDENT'S QUESTION: \(userQuestion)

        Respond as a tutor would:
        - Be encouraging and supportive
        - Explain concepts clearly
        - Ask follow-up questions to check understanding
        - Keep responses under 3 sentences for voice conversation
        - Use simple language

        TUTOR RESPONSE:
        """

        let response = try await llm.complete(prompt)
        return response.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    // MARK: - Speech

    private func speak(_ text: String) async {
        await MainActor.run {
            let utterance = AVSpeechUtterance(string: text)

            // Use enhanced voice (offline neural TTS)
            if let voice = AVSpeechSynthesisVoice(language: "en-US") {
                utterance.voice = voice
            }

            utterance.rate = 0.5 // Slightly slower for clarity
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0

            isSpeaking = true
            speechSynthesizer.speak(utterance)
        }

        // Wait for speech to finish
        while isSpeaking {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
        }
    }

    // MARK: - Helpers

    func interrupt() {
        if isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        }
    }

    func endSession() {
        stopListening()
        interrupt()
        conversation.append(ConversationTurn(
            role: .tutor,
            text: "Great session! Keep up the good work!",
            timestamp: Date()
        ))
    }
}

// MARK: - Models

struct ConversationTurn: Sendable {
    enum Role: Sendable {
        case student
        case tutor
    }

    let role: Role
    let text: String
    let timestamp: Date
}

// MARK: - Errors

enum VoiceTutorError: LocalizedError {
    case setupFailed
    case recognitionFailed
    case synthesisFailure

    var errorDescription: String? {
        switch self {
        case .setupFailed: return "Failed to setup voice tutor"
        case .recognitionFailed: return "Speech recognition failed"
        case .synthesisFailure: return "Text-to-speech failed"
        }
    }
}
