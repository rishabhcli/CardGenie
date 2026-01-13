//
//  PermissionManagerTests.swift
//  CardGenie
//
//  Unit tests for PermissionManager - camera, microphone, photos, notifications.
//

import XCTest
import AVFoundation
import Photos
import UserNotifications
@testable import CardGenie

// MARK: - PermissionType Tests

final class PermissionTypeTests: XCTestCase {

    func testPermissionTypeRawValues() {
        // Given/When/Then: Verify raw values
        XCTAssertEqual(PermissionType.notifications.rawValue, "notifications")
        XCTAssertEqual(PermissionType.microphone.rawValue, "microphone")
        XCTAssertEqual(PermissionType.camera.rawValue, "camera")
        XCTAssertEqual(PermissionType.photoLibrary.rawValue, "photoLibrary")
    }

    func testPermissionTypeIdentifiable() {
        // Given: Permission types
        // Then: ID should match raw value
        XCTAssertEqual(PermissionType.notifications.id, "notifications")
        XCTAssertEqual(PermissionType.microphone.id, "microphone")
        XCTAssertEqual(PermissionType.camera.id, "camera")
        XCTAssertEqual(PermissionType.photoLibrary.id, "photoLibrary")
    }

    func testPermissionTypeDisplayNames() {
        // Given/When/Then: Verify display names
        XCTAssertEqual(PermissionType.notifications.displayName, "Notifications")
        XCTAssertEqual(PermissionType.microphone.displayName, "Microphone")
        XCTAssertEqual(PermissionType.camera.displayName, "Camera")
        XCTAssertEqual(PermissionType.photoLibrary.displayName, "Photo Library")
    }

    func testPermissionTypeIcons() {
        // Given/When/Then: Verify icons exist
        XCTAssertEqual(PermissionType.notifications.icon, "bell.fill")
        XCTAssertEqual(PermissionType.microphone.icon, "mic.fill")
        XCTAssertEqual(PermissionType.camera.icon, "camera.fill")
        XCTAssertEqual(PermissionType.photoLibrary.icon, "photo.fill")
    }

    func testPermissionTypeTitles() {
        // Given/When/Then: Verify titles are descriptive
        XCTAssertEqual(PermissionType.notifications.title, "Never Miss a Review")
        XCTAssertEqual(PermissionType.microphone.title, "Voice-Powered Learning")
        XCTAssertEqual(PermissionType.camera.title, "Instant Note Capture")
        XCTAssertEqual(PermissionType.photoLibrary.title, "Import Study Materials")
    }

    func testPermissionTypeExplanations() {
        // Given: All permission types
        // Then: Explanations should be meaningful (>50 chars)
        XCTAssertTrue(PermissionType.notifications.explanation.count > 50)
        XCTAssertTrue(PermissionType.microphone.explanation.count > 50)
        XCTAssertTrue(PermissionType.camera.explanation.count > 50)
        XCTAssertTrue(PermissionType.photoLibrary.explanation.count > 50)
    }

    func testPermissionTypeBenefits() {
        // Given: All permission types
        // Then: Should have benefits
        XCTAssertEqual(PermissionType.notifications.benefits.count, 4)
        XCTAssertEqual(PermissionType.microphone.benefits.count, 4)
        XCTAssertEqual(PermissionType.camera.benefits.count, 4)
        XCTAssertEqual(PermissionType.photoLibrary.benefits.count, 4)
    }

    func testPermissionTypeIconColors() {
        // Given/When/Then: Verify icon colors
        XCTAssertNotNil(PermissionType.notifications.iconColor)
        XCTAssertNotNil(PermissionType.microphone.iconColor)
        XCTAssertNotNil(PermissionType.camera.iconColor)
        XCTAssertNotNil(PermissionType.photoLibrary.iconColor)
    }
}

// MARK: - PermissionBenefit Tests

final class PermissionBenefitTests: XCTestCase {

    func testPermissionBenefitCreation() {
        // Given/When: Creating a benefit
        let benefit = PermissionBenefit(icon: "checkmark.circle", text: "Test benefit")

        // Then: Should have correct properties
        XCTAssertNotNil(benefit.id)
        XCTAssertEqual(benefit.icon, "checkmark.circle")
        XCTAssertEqual(benefit.text, "Test benefit")
    }

    func testPermissionBenefitUniqueIDs() {
        // Given: Two benefits
        let benefit1 = PermissionBenefit(icon: "star", text: "First")
        let benefit2 = PermissionBenefit(icon: "star", text: "Second")

        // Then: Should have different IDs
        XCTAssertNotEqual(benefit1.id, benefit2.id)
    }
}

// MARK: - PermissionStatus Tests

final class PermissionStatusTests: XCTestCase {

    // MARK: - UN Authorization Status Conversion

    func testPermissionStatusFromUNNotDetermined() {
        // Given/When: Converting notDetermined
        let status = PermissionStatus(from: UNAuthorizationStatus.notDetermined)

        // Then: Should be notDetermined
        XCTAssertEqual(status, .notDetermined)
    }

    func testPermissionStatusFromUNAuthorized() {
        // Given/When: Converting authorized
        let status = PermissionStatus(from: UNAuthorizationStatus.authorized)

        // Then: Should be authorized
        XCTAssertEqual(status, .authorized)
    }

    func testPermissionStatusFromUNDenied() {
        // Given/When: Converting denied
        let status = PermissionStatus(from: UNAuthorizationStatus.denied)

        // Then: Should be denied
        XCTAssertEqual(status, .denied)
    }

    func testPermissionStatusFromUNProvisional() {
        // Given/When: Converting provisional
        let status = PermissionStatus(from: UNAuthorizationStatus.provisional)

        // Then: Should be authorized
        XCTAssertEqual(status, .authorized)
    }

    func testPermissionStatusFromUNEphemeral() {
        // Given/When: Converting ephemeral
        let status = PermissionStatus(from: UNAuthorizationStatus.ephemeral)

        // Then: Should be authorized
        XCTAssertEqual(status, .authorized)
    }

    // MARK: - AV Authorization Status Conversion

    func testPermissionStatusFromAVNotDetermined() {
        // Given/When: Converting notDetermined
        let status = PermissionStatus(from: AVAuthorizationStatus.notDetermined)

        // Then: Should be notDetermined
        XCTAssertEqual(status, .notDetermined)
    }

    func testPermissionStatusFromAVAuthorized() {
        // Given/When: Converting authorized
        let status = PermissionStatus(from: AVAuthorizationStatus.authorized)

        // Then: Should be authorized
        XCTAssertEqual(status, .authorized)
    }

    func testPermissionStatusFromAVDenied() {
        // Given/When: Converting denied
        let status = PermissionStatus(from: AVAuthorizationStatus.denied)

        // Then: Should be denied
        XCTAssertEqual(status, .denied)
    }

    func testPermissionStatusFromAVRestricted() {
        // Given/When: Converting restricted
        let status = PermissionStatus(from: AVAuthorizationStatus.restricted)

        // Then: Should be restricted
        XCTAssertEqual(status, .restricted)
    }

    // MARK: - PH Authorization Status Conversion

    func testPermissionStatusFromPHNotDetermined() {
        // Given/When: Converting notDetermined
        let status = PermissionStatus(from: PHAuthorizationStatus.notDetermined)

        // Then: Should be notDetermined
        XCTAssertEqual(status, .notDetermined)
    }

    func testPermissionStatusFromPHAuthorized() {
        // Given/When: Converting authorized
        let status = PermissionStatus(from: PHAuthorizationStatus.authorized)

        // Then: Should be authorized
        XCTAssertEqual(status, .authorized)
    }

    func testPermissionStatusFromPHLimited() {
        // Given/When: Converting limited
        let status = PermissionStatus(from: PHAuthorizationStatus.limited)

        // Then: Should be authorized (limited access is still authorized)
        XCTAssertEqual(status, .authorized)
    }

    func testPermissionStatusFromPHDenied() {
        // Given/When: Converting denied
        let status = PermissionStatus(from: PHAuthorizationStatus.denied)

        // Then: Should be denied
        XCTAssertEqual(status, .denied)
    }

    func testPermissionStatusFromPHRestricted() {
        // Given/When: Converting restricted
        let status = PermissionStatus(from: PHAuthorizationStatus.restricted)

        // Then: Should be restricted
        XCTAssertEqual(status, .restricted)
    }
}

// MARK: - PermissionManager Tests

@MainActor
final class PermissionManagerTests: XCTestCase {

    func testPermissionManagerSharedInstance() async throws {
        // Given/When: Accessing shared instance
        let manager1 = PermissionManager.shared
        let manager2 = PermissionManager.shared

        // Then: Should be the same instance
        XCTAssertTrue(manager1 === manager2)
    }

    func testPermissionManagerInitialState() async throws {
        // Given: A new permission manager
        let manager = PermissionManager()

        // Then: Should have default states
        XCTAssertFalse(manager.isRequestingPermission)
        XCTAssertNil(manager.showingExplainer)
    }

    func testShowExplainer() async throws {
        // Given: A permission manager
        let manager = PermissionManager()

        // When: Showing explainer
        manager.showExplainer(for: .camera)

        // Then: Should set showing explainer
        XCTAssertEqual(manager.showingExplainer, .camera)
    }

    func testShouldShowExplainerForNotDetermined() async throws {
        // Given: A permission manager (notifications typically start as notDetermined in tests)
        let manager = PermissionManager()
        manager.notificationStatus = .notDetermined

        // When/Then: Should show explainer for not determined
        XCTAssertTrue(manager.shouldShowExplainer(for: .notifications))
    }

    func testShouldShowSettingsForDenied() async throws {
        // Given: A permission manager with denied status
        let manager = PermissionManager()

        // Simulate denied status
        let deniedStatus = AVAuthorizationStatus.denied

        // When: Checking if should show settings
        // For camera with denied status
        manager.cameraStatus = deniedStatus

        // Then: Should show settings
        XCTAssertTrue(manager.shouldShowSettings(for: .camera))
    }

    func testIsGrantedForAuthorized() async throws {
        // Given: A permission manager with authorized status
        let manager = PermissionManager()
        manager.cameraStatus = .authorized

        // When/Then: Should be granted
        XCTAssertTrue(manager.isGranted(.camera))
    }

    func testIsGrantedForNotAuthorized() async throws {
        // Given: A permission manager with notDetermined status
        let manager = PermissionManager()
        manager.microphoneStatus = .notDetermined

        // When/Then: Should not be granted
        XCTAssertFalse(manager.isGranted(.microphone))
    }
}
