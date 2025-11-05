//
//  PermissionManager.swift
//  CardGenie
//
//  Created by Claude Code on 2025-11-04.
//  Permission management with explainer-first pattern
//

import SwiftUI
import UserNotifications
import AVFoundation
import Photos
import Combine

// MARK: - Permission Manager

@MainActor
final class PermissionManager: ObservableObject {
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var microphoneStatus: AVAuthorizationStatus = .notDetermined
    @Published var cameraStatus: AVAuthorizationStatus = .notDetermined
    @Published var photoLibraryStatus: PHAuthorizationStatus = .notDetermined

    @Published var showingExplainer: PermissionType?
    @Published var isRequestingPermission = false

    static let shared = PermissionManager()

    init() {
        Task {
            await refreshAllStatuses()
        }
    }

    // MARK: - Status Refresh

    func refreshAllStatuses() async {
        await refreshNotificationStatus()
        await refreshMicrophoneStatus()
        await refreshCameraStatus()
        await refreshPhotoLibraryStatus()
    }

    func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    func refreshMicrophoneStatus() async {
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    func refreshCameraStatus() async {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    func refreshPhotoLibraryStatus() async {
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus()
    }

    // MARK: - Permission Requests

    func requestNotifications() async -> Bool {
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            await refreshNotificationStatus()
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    func requestMicrophone() async -> Bool {
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        await refreshMicrophoneStatus()
        return granted
    }

    func requestCamera() async -> Bool {
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await refreshCameraStatus()
        return granted
    }

    func requestPhotoLibrary() async -> Bool {
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                Task { @MainActor in
                    self.photoLibraryStatus = status
                    continuation.resume(returning: status == .authorized || status == .limited)
                }
            }
        }
    }

    // MARK: - Explainer Flow

    func showExplainer(for permissionType: PermissionType) {
        showingExplainer = permissionType
    }

    func requestPermissionWithExplainer(_ permissionType: PermissionType) async -> Bool {
        switch permissionType {
        case .notifications:
            return await requestNotifications()
        case .microphone:
            return await requestMicrophone()
        case .camera:
            return await requestCamera()
        case .photoLibrary:
            return await requestPhotoLibrary()
        }
    }

    // MARK: - Helper Methods

    func shouldShowExplainer(for permissionType: PermissionType) -> Bool {
        let status = currentStatus(for: permissionType)
        return status == .notDetermined
    }

    func shouldShowSettings(for permissionType: PermissionType) -> Bool {
        let status = currentStatus(for: permissionType)
        return status == .denied
    }

    func isGranted(_ permissionType: PermissionType) -> Bool {
        let status = currentStatus(for: permissionType)
        return status == .authorized
    }

    private func currentStatus(for permissionType: PermissionType) -> PermissionStatus {
        switch permissionType {
        case .notifications:
            return PermissionStatus(from: notificationStatus)
        case .microphone:
            return PermissionStatus(from: microphoneStatus)
        case .camera:
            return PermissionStatus(from: cameraStatus)
        case .photoLibrary:
            return PermissionStatus(from: photoLibraryStatus)
        }
    }
}

// MARK: - Permission Types

enum PermissionType: String, Identifiable {
    case notifications
    case microphone
    case camera
    case photoLibrary

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notifications: return "Notifications"
        case .microphone: return "Microphone"
        case .camera: return "Camera"
        case .photoLibrary: return "Photo Library"
        }
    }

    var icon: String {
        switch self {
        case .notifications: return "bell.fill"
        case .microphone: return "mic.fill"
        case .camera: return "camera.fill"
        case .photoLibrary: return "photo.fill"
        }
    }

    var title: String {
        switch self {
        case .notifications: return "Never Miss a Review"
        case .microphone: return "Voice-Powered Learning"
        case .camera: return "Instant Note Capture"
        case .photoLibrary: return "Import Study Materials"
        }
    }

    var explanation: String {
        switch self {
        case .notifications:
            return "Get timely reminders for spaced repetition reviews to maximize retention and build study streaks."
        case .microphone:
            return "Record lectures with live transcription, ask questions using voice, and get AI-powered answers hands-free."
        case .camera:
            return "Scan notes, textbooks, whiteboards, and documents instantly. AI extracts text and creates flashcards automatically."
        case .photoLibrary:
            return "Import photos of notes, diagrams, and study materials from your library to create powerful study content."
        }
    }

    var benefits: [PermissionBenefit] {
        switch self {
        case .notifications:
            return [
                PermissionBenefit(icon: "brain.head.profile", text: "Optimal review timing"),
                PermissionBenefit(icon: "flame.fill", text: "Build study streaks"),
                PermissionBenefit(icon: "chart.line.uptrend.xyaxis", text: "Track progress"),
                PermissionBenefit(icon: "bell.badge.fill", text: "Custom review schedules")
            ]
        case .microphone:
            return [
                PermissionBenefit(icon: "waveform", text: "Record lectures live"),
                PermissionBenefit(icon: "text.quote", text: "Automatic transcription"),
                PermissionBenefit(icon: "mic.circle.fill", text: "Voice questions"),
                PermissionBenefit(icon: "sparkles", text: "AI-powered answers")
            ]
        case .camera:
            return [
                PermissionBenefit(icon: "doc.text.viewfinder", text: "OCR text extraction"),
                PermissionBenefit(icon: "hand.draw.fill", text: "Handwriting recognition"),
                PermissionBenefit(icon: "rectangle.on.rectangle", text: "Auto flashcard creation"),
                PermissionBenefit(icon: "bolt.fill", text: "Instant capture")
            ]
        case .photoLibrary:
            return [
                PermissionBenefit(icon: "photo.on.rectangle.angled", text: "Import existing notes"),
                PermissionBenefit(icon: "square.stack.3d.up.fill", text: "Batch processing"),
                PermissionBenefit(icon: "text.viewfinder", text: "Text extraction"),
                PermissionBenefit(icon: "photo.badge.plus", text: "Multi-photo support")
            ]
        }
    }

    var iconColor: Color {
        switch self {
        case .notifications: return .orange
        case .microphone: return .red
        case .camera: return .blue
        case .photoLibrary: return .purple
        }
    }
}

// MARK: - Permission Benefit

struct PermissionBenefit: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}

// MARK: - Permission Status

enum PermissionStatus {
    case notDetermined
    case authorized
    case denied
    case restricted

    init(from unStatus: UNAuthorizationStatus) {
        switch unStatus {
        case .notDetermined: self = .notDetermined
        case .authorized, .provisional, .ephemeral: self = .authorized
        case .denied: self = .denied
        @unknown default: self = .notDetermined
        }
    }

    init(from avStatus: AVAuthorizationStatus) {
        switch avStatus {
        case .notDetermined: self = .notDetermined
        case .authorized: self = .authorized
        case .denied: self = .denied
        case .restricted: self = .restricted
        @unknown default: self = .notDetermined
        }
    }

    init(from phStatus: PHAuthorizationStatus) {
        switch phStatus {
        case .notDetermined: self = .notDetermined
        case .authorized, .limited: self = .authorized
        case .denied: self = .denied
        case .restricted: self = .restricted
        @unknown default: self = .notDetermined
        }
    }
}

// MARK: - Permission Explainer View

struct PermissionExplainerView: View {
    let permissionType: PermissionType
    @ObservedObject var manager: PermissionManager
    @Environment(\.dismiss) private var dismiss

    @State private var isRequesting = false
    @State private var requestResult: Bool?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 20)

                    // Icon
                    Image(systemName: permissionType.icon)
                        .font(.system(size: 80))
                        .foregroundStyle(permissionType.iconColor)
                        .symbolEffect(.bounce)

                    // Title
                    Text(permissionType.title)
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)

                    // Explanation
                    Text(permissionType.explanation)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Benefits
                    VStack(spacing: 16) {
                        ForEach(permissionType.benefits) { benefit in
                            BenefitRow(benefit: benefit)
                        }
                    }
                    .padding(.horizontal)

                    // Privacy notice
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(.blue)
                            Text("Privacy First")
                                .font(.headline)
                        }
                        Text("All processing happens on your device. Your data never leaves your iPhone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button {
                        requestPermission()
                    } label: {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Enable \(permissionType.displayName)")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(permissionType.iconColor)
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                    }
                    .disabled(isRequesting)

                    if manager.shouldShowSettings(for: permissionType) {
                        Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                            Text("Open Settings")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.primary.opacity(0.1))
                                .foregroundStyle(.primary)
                                .cornerRadius(16)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }

    func requestPermission() {
        isRequesting = true

        Task {
            let granted = await manager.requestPermissionWithExplainer(permissionType)
            requestResult = granted
            isRequesting = false

            // Auto-dismiss on success
            if granted {
                try? await Task.sleep(for: .milliseconds(500))
                dismiss()
            }
        }
    }
}

// MARK: - Benefit Row

struct BenefitRow: View {
    let benefit: PermissionBenefit

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: benefit.icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            Text(benefit.text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Permission Status Badge

struct PermissionStatusBadge: View {
    let permissionType: PermissionType
    @ObservedObject var manager: PermissionManager

    var isGranted: Bool {
        manager.isGranted(permissionType)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(isGranted ? "Enabled" : "Disabled")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(isGranted ? .green : .secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isGranted ? Color.green.opacity(0.1) : Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Permission Request Button

struct PermissionRequestButton: View {
    let permissionType: PermissionType
    @ObservedObject var manager: PermissionManager

    var body: some View {
        Button {
            if manager.shouldShowExplainer(for: permissionType) {
                manager.showExplainer(for: permissionType)
            } else if manager.shouldShowSettings(for: permissionType) {
                openSettings()
            }
        } label: {
            HStack {
                Image(systemName: permissionType.icon)
                Text(permissionType.displayName)

                Spacer()

                PermissionStatusBadge(permissionType: permissionType, manager: manager)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
        .sheet(item: $manager.showingExplainer) { permissionType in
            PermissionExplainerView(permissionType: permissionType, manager: manager)
        }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview("Explainer") {
    PermissionExplainerView(
        permissionType: .notifications,
        manager: PermissionManager.shared
    )
}

#Preview("Request Button") {
    VStack {
        PermissionRequestButton(
            permissionType: .notifications,
            manager: PermissionManager.shared
        )
        PermissionRequestButton(
            permissionType: .camera,
            manager: PermissionManager.shared
        )
    }
    .padding()
}
