//
//  NotificationManager.swift
//  CardGenie
//
//  Manages local notifications for daily flashcard review reminders.
//  All notifications are generated on-device with no server dependency.
//

import Foundation
import Combine
import UserNotifications
import OSLog

/// Manages local notifications for flashcard study reminders
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    private let log = Logger(subsystem: "com.cardgenie.app", category: "Notifications")

    // Notification identifiers
    private let dailyReviewIdentifier = "com.cardgenie.dailyreview"

    private init() {}

    // MARK: - Authorization

    /// Request notification permission from the user
    /// - Returns: Whether permission was granted
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])

            log.info("Notification permission: \(granted)")
            return granted
        } catch {
            log.error("Failed to request notification permission: \(error.localizedDescription)")
            return false
        }
    }

    /// Check if notifications are authorized
    /// - Returns: Current authorization status
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Daily Review Notifications

    /// Schedule a daily notification to remind user to review flashcards
    /// - Parameters:
    ///   - hour: Hour of day (0-23) to send notification
    ///   - minute: Minute of hour (0-59) to send notification
    ///   - dueCardCount: Number of cards due today (for notification message)
    func scheduleDailyReviewNotification(at hour: Int, minute: Int, dueCardCount: Int = 0) async {
        // Cancel existing daily notification
        cancelDailyNotification()

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Time to Review!"
        content.sound = .default
        content.badge = dueCardCount as NSNumber

        if dueCardCount > 0 {
            content.body = "You have \(dueCardCount) flashcard\(dueCardCount == 1 ? "" : "s") ready for review."
        } else {
            content.body = "Check your flashcards and keep your learning streak going!"
        }

        // Add action buttons
        let reviewAction = UNNotificationAction(
            identifier: "REVIEW_ACTION",
            title: "Review Now",
            options: .foreground
        )

        let remindAction = UNNotificationAction(
            identifier: "REMIND_ACTION",
            title: "Remind Me Later",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: "FLASHCARD_REVIEW",
            actions: [reviewAction, remindAction],
            intentIdentifiers: [],
            options: []
        )

        await UNUserNotificationCenter.current().setNotificationCategories([category])

        content.categoryIdentifier = "FLASHCARD_REVIEW"

        // Create trigger for daily at specified time
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        // Create request
        let request = UNNotificationRequest(
            identifier: dailyReviewIdentifier,
            content: content,
            trigger: trigger
        )

        // Schedule notification
        do {
            try await UNUserNotificationCenter.current().add(request)
            log.info("Scheduled daily notification for \(hour):\(minute)")
        } catch {
            log.error("Failed to schedule notification: \(error.localizedDescription)")
        }
    }

    /// Cancel the daily review notification
    func cancelDailyNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [dailyReviewIdentifier])

        log.info("Cancelled daily notification")
    }

    /// Update badge count (number shown on app icon)
    /// - Parameter count: Number of due flashcards
    func updateBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
        log.info("Updated badge count to \(count)")
    }

    /// Clear badge count
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    // MARK: - One-Time Notifications

    /// Send an immediate notification (for testing or special reminders)
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body
    func sendImmediateNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // nil trigger = immediate
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            log.info("Sent immediate notification")
        } catch {
            log.error("Failed to send immediate notification: \(error.localizedDescription)")
        }
    }

    /// Schedule a reminder after a delay
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - delay: Delay in seconds
    func scheduleReminder(title: String, body: String, after delay: TimeInterval) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: delay,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            log.info("Scheduled reminder for \(delay)s from now")
        } catch {
            log.error("Failed to schedule reminder: \(error.localizedDescription)")
        }
    }

    // MARK: - Notification Management

    /// Get all pending notifications
    /// - Returns: List of pending notification requests
    func getPendingNotifications() async -> [UNNotificationRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
    }

    /// Remove all pending notifications
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        log.info("Removed all pending notifications")
    }

    /// Remove all delivered notifications from notification center
    func removeAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        log.info("Removed all delivered notifications")
    }

    // MARK: - Default Settings

    /// Get recommended notification time (9 AM)
    static var defaultNotificationTime: (hour: Int, minute: Int) {
        (9, 0)
    }
}

// MARK: - Notification Handling

extension NotificationManager {
    /// Handle notification response (when user taps notification)
    /// - Parameter response: The notification response
    /// - Returns: Whether the app should open to review screen
    func handleNotificationResponse(_ response: UNNotificationResponse) -> Bool {
        log.info("Handling notification response: \(response.actionIdentifier)")

        switch response.actionIdentifier {
        case "REVIEW_ACTION":
            // User tapped "Review Now" - return true to open review screen
            return true

        case "REMIND_ACTION":
            // User tapped "Remind Me Later" - schedule a reminder in 1 hour
            Task {
                await scheduleReminder(
                    title: "Flashcard Reminder",
                    body: "Don't forget to review your flashcards!",
                    after: 3600 // 1 hour
                )
            }
            return false

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself (not an action button)
            return true

        default:
            return false
        }
    }
}

// MARK: - SwiftUI Integration

extension NotificationManager {
    /// Check and request authorization if needed, then schedule notifications
    /// - Parameter dueCount: Number of due cards
    func setupNotificationsIfNeeded(dueCount: Int = 0) async {
        let status = await checkAuthorizationStatus()

        switch status {
        case .notDetermined:
            // First time - request permission
            let granted = await requestAuthorization()
            if granted {
                let (hour, minute) = Self.defaultNotificationTime
                await scheduleDailyReviewNotification(
                    at: hour,
                    minute: minute,
                    dueCardCount: dueCount
                )
            }

        case .authorized, .provisional:
            // Already authorized - just schedule
            let (hour, minute) = Self.defaultNotificationTime
            await scheduleDailyReviewNotification(
                at: hour,
                minute: minute,
                dueCardCount: dueCount
            )

        case .denied, .ephemeral:
            // User denied - don't schedule
            log.warning("Notification permission denied")

        @unknown default:
            log.warning("Unknown notification authorization status")
        }
    }
}
