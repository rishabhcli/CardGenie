//
//  ARMemoryPalaceManager.swift
//  CardGenie
//
//  AR Memory Palace - anchor flashcards to real-world locations.
//  Spatial memory is 3x more effective than traditional study.
//

import Foundation
import ARKit
import RealityKit
import SwiftData
import Combine

// MARK: - AR Memory Palace Manager

@Observable
final class ARMemoryPalaceManager: NSObject, ARSessionDelegate {
    let arSession = ARSession()
    private var modelContext: ModelContext?

    // State
    private(set) var isSessionRunning = false
    private(set) var trackingState: ARCamera.TrackingState?
    private(set) var worldMapStatus: ARFrame.WorldMappingStatus = .notAvailable

    // Current memory palace
    private(set) var currentMemoryPalace: ARMemoryPalace?
    private(set) var currentFlashcardSet: FlashcardSet?

    // Anchors
    private var anchorMap: [String: CardAnchor] = [:]
    private var activeAnchors: [ARAnchor] = []

    // Proximity detection
    private(set) var nearbyCards: [Flashcard] = []
    private var proximityCheckTimer: Timer?

    override init() {
        super.init()
        arSession.delegate = self
    }

    // MARK: - Session Management

    /// Start AR session for creating or exploring a memory palace
    func startSession(for flashcardSet: FlashcardSet, context: ModelContext) {
        self.modelContext = context
        self.currentFlashcardSet = flashcardSet

        // Load or create memory palace
        if let existing = loadMemoryPalace(for: flashcardSet) {
            currentMemoryPalace = existing
            loadWorldMap()
        } else {
            currentMemoryPalace = createMemoryPalace(for: flashcardSet)
        }

        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic

        // Enable world map persistence
        if #available(iOS 12.0, *) {
            configuration.initialWorldMap = nil // Will be set if loading existing
        }

        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true

        // Start proximity detection
        startProximityDetection()
    }

    /// Stop AR session
    func stopSession() {
        arSession.pause()
        isSessionRunning = false
        proximityCheckTimer?.invalidate()
        proximityCheckTimer = nil

        // Save world map before stopping
        saveWorldMap()
    }

    /// Pause session (e.g., app backgrounded)
    func pauseSession() {
        arSession.pause()
        proximityCheckTimer?.invalidate()
    }

    /// Resume session
    func resumeSession() {
        guard let currentFrame = arSession.currentFrame else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arSession.run(configuration, options: [])
        startProximityDetection()
    }

    // MARK: - Anchor Placement

    /// Place a flashcard at a real-world location
    func placeCard(
        _ flashcard: Flashcard,
        at transform: simd_float4x4,
        locationLabel: String
    ) {
        guard let memoryPalace = currentMemoryPalace else { return }

        // Create anchor in AR session
        let anchorName = "card_\(flashcard.id.uuidString)"
        let arAnchor = ARAnchor(name: anchorName, transform: transform)
        arSession.add(anchor: arAnchor)

        // Create CardAnchor model
        let cardAnchor = CardAnchor(
            flashcardID: flashcard.id,
            anchorName: anchorName,
            locationLabel: locationLabel
        )

        // Extract position and rotation
        let position = simd_make_float3(transform.columns.3)
        cardAnchor.setPosition(position)

        // Extract rotation (simplified - just orientation)
        let rotation = simd_quaternion(transform)
        cardAnchor.setRotation(rotation)

        // Add to memory palace
        memoryPalace.cardAnchors.append(cardAnchor)
        anchorMap[anchorName] = cardAnchor
        activeAnchors.append(arAnchor)

        // Save
        try? modelContext?.save()
    }

    /// Remove a card anchor
    func removeCardAnchor(_ cardAnchor: CardAnchor) {
        guard let memoryPalace = currentMemoryPalace else { return }

        // Remove from AR session
        if let arAnchor = activeAnchors.first(where: { $0.name == cardAnchor.anchorName }) {
            arSession.remove(anchor: arAnchor)
            activeAnchors.removeAll { $0.name == cardAnchor.anchorName }
        }

        // Remove from model
        memoryPalace.cardAnchors.removeAll { $0.id == cardAnchor.id }
        anchorMap.removeValue(forKey: cardAnchor.anchorName)

        // Delete from context
        modelContext?.delete(cardAnchor)
        try? modelContext?.save()
    }

    // MARK: - World Map Persistence

    private func saveWorldMap() {
        guard let memoryPalace = currentMemoryPalace else { return }

        arSession.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap, error == nil else { return }

            do {
                let data = try NSKeyedArchiver.archivedData(
                    withRootObject: map,
                    requiringSecureCoding: true
                )
                memoryPalace.worldMapData = data
                memoryPalace.lastUpdated = Date()
                try? self.modelContext?.save()
            } catch {
                print("Failed to save world map: \(error)")
            }
        }
    }

    private func loadWorldMap() {
        guard let memoryPalace = currentMemoryPalace,
              let data = memoryPalace.worldMapData else { return }

        do {
            guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: ARWorldMap.self,
                from: data
            ) else { return }

            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            configuration.initialWorldMap = worldMap

            arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])

            // Restore anchors
            restoreAnchors()
        } catch {
            print("Failed to load world map: \(error)")
        }
    }

    private func restoreAnchors() {
        guard let memoryPalace = currentMemoryPalace else { return }

        for cardAnchor in memoryPalace.cardAnchors {
            var transform = matrix_identity_float4x4

            // Restore position
            let position = cardAnchor.getPosition()
            transform.columns.3 = simd_float4(position.x, position.y, position.z, 1.0)

            // Restore rotation
            let rotation = cardAnchor.getRotation()
            let rotationMatrix = simd_float4x4(rotation)
            transform = simd_mul(transform, rotationMatrix)

            // Add anchor
            let arAnchor = ARAnchor(name: cardAnchor.anchorName, transform: transform)
            arSession.add(anchor: arAnchor)

            anchorMap[cardAnchor.anchorName] = cardAnchor
            activeAnchors.append(arAnchor)
        }
    }

    // MARK: - Proximity Detection

    private func startProximityDetection() {
        proximityCheckTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            self?.checkProximity()
        }
    }

    private func checkProximity() {
        guard let frame = arSession.currentFrame,
              let memoryPalace = currentMemoryPalace,
              let flashcardSet = currentFlashcardSet else {
            nearbyCards = []
            return
        }

        let cameraPosition = simd_make_float3(frame.camera.transform.columns.3)
        var nearby: [Flashcard] = []

        for cardAnchor in memoryPalace.cardAnchors {
            let anchorPosition = cardAnchor.getPosition()
            let distance = simd_distance(cameraPosition, anchorPosition)

            if distance <= cardAnchor.proximityRadius {
                // Find the flashcard
                if let card = flashcardSet.cards.first(where: { $0.id == cardAnchor.flashcardID }) {
                    nearby.append(card)
                }
            }
        }

        nearbyCards = nearby
    }

    // MARK: - Helper Methods

    private func loadMemoryPalace(for flashcardSet: FlashcardSet) -> ARMemoryPalace? {
        guard let context = modelContext else { return nil }

        // Fetch all memory palaces and filter manually due to Predicate limitations with optional relationships
        let descriptor = FetchDescriptor<ARMemoryPalace>()

        guard let allPalaces = try? context.fetch(descriptor) else { return nil }

        return allPalaces.first { palace in
            palace.flashcardSet?.id == flashcardSet.id
        }
    }

    private func createMemoryPalace(for flashcardSet: FlashcardSet) -> ARMemoryPalace {
        let palace = ARMemoryPalace()
        palace.flashcardSet = flashcardSet
        modelContext?.insert(palace)
        try? modelContext?.save()
        return palace
    }

    /// Get current camera transform for placing objects
    func getCameraTransform() -> simd_float4x4? {
        arSession.currentFrame?.camera.transform
    }

    /// Get transform at a distance in front of camera
    func getPlacementTransform(distanceMeters: Float = 1.0) -> simd_float4x4? {
        guard let cameraTransform = getCameraTransform() else { return nil }

        // Place object in front of camera
        var transform = cameraTransform
        let forward = simd_make_float3(transform.columns.2)
        let position = simd_make_float3(transform.columns.3)
        let placementPosition = position - (forward * distanceMeters)

        transform.columns.3 = simd_float4(placementPosition.x, placementPosition.y, placementPosition.z, 1.0)

        return transform
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        trackingState = frame.camera.trackingState
        worldMapStatus = frame.worldMappingStatus
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Handle added anchors
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Handle updated anchors
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        // Handle removed anchors
    }
}

// MARK: - AR Tracking State Extension

extension ARCamera.TrackingState {
    var description: String {
        switch self {
        case .normal:
            return "Tracking"
        case .notAvailable:
            return "Not Available"
        case .limited(.initializing):
            return "Initializing..."
        case .limited(.excessiveMotion):
            return "Too much motion"
        case .limited(.insufficientFeatures):
            return "Need more detail"
        case .limited(.relocalizing):
            return "Relocalizing..."
        default:
            return "Unknown"
        }
    }

    var isGood: Bool {
        if case .normal = self {
            return true
        }
        return false
    }
}
