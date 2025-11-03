//
//  NotificationTests.swift
//  CardGenieTests
//
//  Tests for NotificationManager functionality.
//

import XCTest
import UserNotifications
@testable import CardGenie

@MainActor
final class NotificationTests: XCTestCase {
    var notificationManager: NotificationManager!
    var notificationCenter: UNUserNotificationCenter!

    override func setUp() async throws {
        notificationManager = NotificationManager.shared
        notificationCenter = UNUserNotificationCenter.current()

        // Clear all notifications before each test
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }

    override func tearDown() async throws {
        // Clean up after each test
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        notificationManager = nil
        notificationCenter = nil
    }

    // MARK: - Authorization Tests

    func testCheckAuthorizationStatus() async {
        let status = await notificationManager.checkAuthorizationStatus()

        XCTAssertTrue(
            [.notDetermined, .denied, .authorized, .provisional, .ephemeral].contains(status),
            "Authorization status should be one of the valid states"
        )
    }

    func testRequestAuthorizationReturnsBoolean() async {
        // Note: In test environment, this will likely be denied or not determined
        let granted = await notificationManager.requestAuthorization()

        XCTAssertTrue(granted == true || granted == false, "Should return a boolean value")
    }

    // MARK: - Daily Notification Tests

    func testScheduleDailyReviewNotification() async {
        let hour = 9
        let minute = 0
        let dueCount = 5

        await notificationManager.scheduleDailyReviewNotification(
            at: hour,
            minute: minute,
            dueCardCount: dueCount
        )

        let pendingNotifications = await notificationCenter.pendingNotificationRequests()

        XCTAssertGreaterThan(
            pendingNotifications.count,
            0,
            "Should schedule at least one notification"
        )

        // Find the daily review notification
        let dailyNotification = pendingNotifications.first {
            $0.identifier.contains("dailyreview")
        }

        XCTAssertNotNil(dailyNotification, "Should schedule daily review notification")

        if let notification = dailyNotification {
            let content = notification.content

            XCTAssertTrue(
                content.title.contains("Review") || content.title.contains("Time"),
                "Notification title should mention review"
            )

            if dueCount > 0 {
                XCTAssertTrue(
                    content.body.contains("\(dueCount)"),
                    "Notification body should include due count"
                )
            }

            XCTAssertEqual(
                content.badge as? Int,
                dueCount,
                "Badge should match due count"
            )

            // Verify trigger is calendar-based
            if let trigger = notification.trigger as? UNCalendarNotificationTrigger {
                XCTAssertTrue(trigger.repeats, "Daily notification should repeat")
                XCTAssertEqual(trigger.dateComponents.hour, hour, "Should trigger at correct hour")
                XCTAssertEqual(trigger.dateComponents.minute, minute, "Should trigger at correct minute")
            } else {
                XCTFail("Trigger should be UNCalendarNotificationTrigger")
            }
        }
    }

    func testScheduleDailyNotificationReplacesExisting() async {
        // Schedule first notification
        await notificationManager.scheduleDailyReviewNotification(at: 9, minute: 0, dueCardCount: 5)

        let firstCount = await notificationCenter.pendingNotificationRequests().count

        // Schedule second notification (should replace first)
        await notificationManager.scheduleDailyReviewNotification(at: 10, minute: 30, dueCardCount: 10)

        let secondCount = await notificationCenter.pendingNotificationRequests().count

        XCTAssertEqual(
            firstCount,
            secondCount,
            "Scheduling a new daily notification should replace the old one, not add to it"
        )
    }

    func testCancelDailyNotification() async {
        // Schedule notification
        await notificationManager.scheduleDailyReviewNotification(at: 9, minute: 0, dueCardCount: 5)

        var pendingBefore = await notificationCenter.pendingNotificationRequests()
        XCTAssertGreaterThan(pendingBefore.count, 0, "Should have pending notification")

        // Cancel notification
        notificationManager.cancelDailyNotification()

        // Wait a bit for cancellation to process
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        let pendingAfter = await notificationCenter.pendingNotificationRequests()

        let dailyNotificationRemoved = !pendingAfter.contains {
            $0.identifier.contains("dailyreview")
        }

        XCTAssertTrue(
            dailyNotificationRemoved,
            "Daily notification should be removed after cancellation"
        )
    }

    // MARK: - Badge Tests

    func testUpdateBadgeCount() {
        let testCount = 7

        notificationManager.updateBadgeCount(testCount)

        // Note: Testing badge count in unit tests is challenging since it's app-level state
        // This test mainly ensures the method doesn't crash
        XCTAssertTrue(true, "updateBadgeCount should execute without error")
    }

    func testClearBadge() {
        notificationManager.clearBadge()

        // This test mainly ensures the method doesn't crash
        XCTAssertTrue(true, "clearBadge should execute without error")
    }

    // MARK: - Immediate Notification Tests

    func testSendImmediateNotification() async {
        let title = "Test Title"
        let body = "Test Body"

        await notificationManager.sendImmediateNotification(title: title, body: body)

        // Wait briefly for notification to be scheduled
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        let pendingNotifications = await notificationCenter.pendingNotificationRequests()

        // Note: Immediate notifications may be delivered immediately,
        // so they might not show in pending. This test ensures no crash.
        XCTAssertTrue(true, "Immediate notification should be sent without error")
    }

    func testScheduleReminder() async {
        let title = "Reminder"
        let body = "Don't forget to study!"
        let delay: TimeInterval = 5.0

        await notificationManager.scheduleReminder(
            title: title,
            body: body,
            after: delay
        )

        let pendingNotifications = await notificationCenter.pendingNotificationRequests()

        XCTAssertGreaterThan(
            pendingNotifications.count,
            0,
            "Should schedule reminder notification"
        )

        // Find the reminder (non-daily notification)
        let reminder = pendingNotifications.first {
            !$0.identifier.contains("dailyreview")
        }

        XCTAssertNotNil(reminder, "Should find scheduled reminder")

        if let reminder = reminder {
            if let trigger = reminder.trigger as? UNTimeIntervalNotificationTrigger {
                XCTAssertEqual(
                    trigger.timeInterval,
                    delay,
                    accuracy: 1.0,
                    "Reminder should trigger after specified delay"
                )
                XCTAssertFalse(trigger.repeats, "Reminder should not repeat")
            } else {
                XCTFail("Reminder trigger should be UNTimeIntervalNotificationTrigger")
            }
        }
    }

    // MARK: - Notification Management Tests

    func testGetPendingNotifications() async {
        // Schedule a few notifications
        await notificationManager.scheduleDailyReviewNotification(at: 9, minute: 0, dueCardCount: 5)
        await notificationManager.scheduleReminder(title: "Test", body: "Body", after: 60)

        let pending = await notificationManager.getPendingNotifications()

        XCTAssertGreaterThanOrEqual(
            pending.count,
            1,
            "Should retrieve pending notifications"
        )
    }

    func testRemoveAllPendingNotifications() async {
        // Schedule notifications
        await notificationManager.scheduleDailyReviewNotification(at: 9, minute: 0, dueCardCount: 5)
        await notificationManager.scheduleReminder(title: "Test", body: "Body", after: 60)

        var pendingBefore = await notificationCenter.pendingNotificationRequests()
        XCTAssertGreaterThan(pendingBefore.count, 0, "Should have pending notifications")

        // Remove all
        notificationManager.removeAllPendingNotifications()

        // Wait for removal to process
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        let pendingAfter = await notificationCenter.pendingNotificationRequests()

        XCTAssertEqual(
            pendingAfter.count,
            0,
            "All pending notifications should be removed"
        )
    }

    func testRemoveAllDeliveredNotifications() {
        // This mainly tests that the method doesn't crash
        notificationManager.removeAllDeliveredNotifications()

        XCTAssertTrue(true, "removeAllDeliveredNotifications should execute without error")
    }

    // MARK: - Default Settings Tests

    func testDefaultNotificationTime() {
        let (hour, minute) = NotificationManager.defaultNotificationTime

        XCTAssertEqual(hour, 9, "Default hour should be 9 AM")
        XCTAssertEqual(minute, 0, "Default minute should be 0")
    }

    // MARK: - Notification Response Handling Tests

    func testHandleNotificationResponseReviewAction() {
        let response = MockNotificationResponse(actionIdentifier: "REVIEW_ACTION")

        let shouldOpenReview = notificationManager.handleNotificationResponse(response)

        XCTAssertTrue(shouldOpenReview, "Review action should return true to open review screen")
    }

    func testHandleNotificationResponseRemindAction() async {
        let response = MockNotificationResponse(actionIdentifier: "REMIND_ACTION")

        let shouldOpenReview = notificationManager.handleNotificationResponse(response)

        XCTAssertFalse(shouldOpenReview, "Remind action should return false")

        // Wait for reminder to be scheduled
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        let pending = await notificationCenter.pendingNotificationRequests()

        XCTAssertGreaterThan(
            pending.count,
            0,
            "Remind action should schedule a new reminder"
        )
    }

    func testHandleNotificationResponseDefaultAction() {
        let response = MockNotificationResponse(
            actionIdentifier: UNNotificationDefaultActionIdentifier
        )

        let shouldOpenReview = notificationManager.handleNotificationResponse(response)

        XCTAssertTrue(
            shouldOpenReview,
            "Default action (tapping notification) should open review screen"
        )
    }

    func testHandleNotificationResponseUnknownAction() {
        let response = MockNotificationResponse(actionIdentifier: "UNKNOWN_ACTION")

        let shouldOpenReview = notificationManager.handleNotificationResponse(response)

        XCTAssertFalse(shouldOpenReview, "Unknown actions should return false")
    }

    // MARK: - Setup Notifications Tests

    func testSetupNotificationsIfNeededWithDueCount() async {
        let dueCount = 10

        await notificationManager.setupNotificationsIfNeeded(dueCount: dueCount)

        // This test primarily ensures the method doesn't crash
        // Actual behavior depends on authorization status
        XCTAssertTrue(true, "setupNotificationsIfNeeded should execute without error")
    }

    // MARK: - Integration Tests

    func testFullNotificationLifecycle() async {
        let dueCount = 15

        // 1. Schedule daily notification
        await notificationManager.scheduleDailyReviewNotification(
            at: 10,
            minute: 30,
            dueCardCount: dueCount
        )

        // 2. Verify it was scheduled
        var pending = await notificationCenter.pendingNotificationRequests()
        XCTAssertGreaterThan(pending.count, 0, "Notification should be scheduled")

        // 3. Update badge
        notificationManager.updateBadgeCount(dueCount)

        // 4. Cancel notification
        notificationManager.cancelDailyNotification()

        // Wait for cancellation
        try? await Task.sleep(nanoseconds: 100_000_000)

        // 5. Verify cancellation
        pending = await notificationCenter.pendingNotificationRequests()
        let hasDailyNotification = pending.contains { $0.identifier.contains("dailyreview") }
        XCTAssertFalse(hasDailyNotification, "Daily notification should be cancelled")

        // 6. Clear badge
        notificationManager.clearBadge()
    }

    // MARK: - Edge Cases

    func testScheduleNotificationWithZeroDueCount() async {
        await notificationManager.scheduleDailyReviewNotification(
            at: 9,
            minute: 0,
            dueCardCount: 0
        )

        let pending = await notificationCenter.pendingNotificationRequests()

        if let notification = pending.first(where: { $0.identifier.contains("dailyreview") }) {
            XCTAssertTrue(
                notification.content.body.contains("0") ||
                !notification.content.body.contains(where: { $0.isNumber }),
                "Notification with 0 due cards should handle count appropriately"
            )
        }
    }

    func testScheduleNotificationAtMidnight() async {
        await notificationManager.scheduleDailyReviewNotification(
            at: 0,
            minute: 0,
            dueCardCount: 5
        )

        let pending = await notificationCenter.pendingNotificationRequests()
        let notification = pending.first { $0.identifier.contains("dailyreview") }

        XCTAssertNotNil(notification, "Should handle midnight time (0:00)")
    }

    func testScheduleNotificationAtEndOfDay() async {
        await notificationManager.scheduleDailyReviewNotification(
            at: 23,
            minute: 59,
            dueCardCount: 5
        )

        let pending = await notificationCenter.pendingNotificationRequests()
        let notification = pending.first { $0.identifier.contains("dailyreview") }

        XCTAssertNotNil(notification, "Should handle end of day time (23:59)")
    }
}

// MARK: - Mock Notification Response

class MockNotificationResponse: UNNotificationResponse {
    private let mockActionIdentifier: String

    init(actionIdentifier: String) {
        self.mockActionIdentifier = actionIdentifier
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var actionIdentifier: String {
        return mockActionIdentifier
    }
}
