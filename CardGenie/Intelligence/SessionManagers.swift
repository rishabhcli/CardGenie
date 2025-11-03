//
//  SessionManagers.swift
//  CardGenie
//
//  Session management, notifications, scan queue, and analytics.
//

import Foundation
import SwiftData
import UserNotifications
import FoundationModels
import Combine
import OSLog
import UIKit

// MARK: - EnhancedSessionManager

// MARK: - Session Type

enum SessionType {
    case singleTurn    // Create new session per request
    case multiTurn     // Reuse session for conversation
}

// MARK: - Enhanced Session Manager

@available(iOS 26.0, *)
@MainActor
final class EnhancedSessionManager: ObservableObject {
    private let log = Logger(subsystem: "com.cardgenie.app", category: "SessionManager")

    // MARK: - Properties

    @Published private(set) var isResponding = false
    @Published private(set) var currentSession: LanguageModelSession?

    private let contextBudget = ContextBudgetManager()
    private let safetyFilter = ContentSafetyFilter()
    private let guardrailHandler = GuardrailHandler()
    private let privacyLogger = PrivacyLogger()
    private let localeManager = LocaleManager()

    private var sessionType: SessionType = .singleTurn

    // MARK: - Initialization

    init(sessionType: SessionType = .singleTurn) {
        self.sessionType = sessionType
    }

    // MARK: - Session Management

    /// Start a new session with instructions
    func startSession(instructions: String) {
        guard !isResponding else {
            log.warning("Cannot start new session while responding")
            return
        }

        let localeInstructions = localeManager.getLocaleInstructions()
        let fullInstructions = """
        \(instructions)

        \(localeInstructions)

        IMPORTANT CONSTRAINTS:
        - NEVER log or expose student notes or personal information
        - Keep outputs concise and age-appropriate
        - Refuse unsafe or inappropriate requests politely
        - Stay within academic/educational topics
        """

        currentSession = LanguageModelSession(instructions: fullInstructions)
        log.info("Started new session with type: \(String(describing: self.sessionType))")
    }

    /// End current session
    func endSession() {
        currentSession = nil
        isResponding = false
        log.info("Ended session")
    }

    // MARK: - Single-Turn Request

    /// Perform a single-turn request (creates new session each time)
    func singleTurnRequest<T>(
        prompt: String,
        instructions: String,
        generating type: T.Type,
        options: GenerationOptions = GenerationOptions()
    ) async throws -> T where T: Generable {
        // Ensure no concurrent requests
        guard !isResponding else {
            log.warning("Request blocked: already responding")
            throw SafetyError.guardrailViolation(
                SafetyEvent(
                    type: .privacyFilter,
                    userMessage: "Please wait for the current request to complete."
                )
            )
        }

        isResponding = true
        defer { isResponding = false }

        // Safety check
        switch safetyFilter.isSafe(prompt) {
        case .success:
            break
        case .failure(let error):
            log.error("Safety filter triggered")
            throw error
        }

        // Context limit check
        guard contextBudget.canFitInContext(prompt, instructions: instructions) else {
            log.warning("Content exceeds context window")
            throw SafetyError.contextLimitExceeded
        }

        // Create new session for single-turn
        let localeInstructions = localeManager.getLocaleInstructions()
        let fullInstructions = "\(instructions)\n\n\(localeInstructions)"

        let session = LanguageModelSession(instructions: fullInstructions)

        do {
            let response = try await session.respond(
                to: prompt,
                generating: type,
                options: options
            )

            privacyLogger.logOperation(
                "single_turn",
                contentLength: prompt.count,
                success: true
            )

            return response.content

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            let event = guardrailHandler.handleGuardrailViolation(prompt: prompt)
            privacyLogger.logSafetyEvent(event)
            throw SafetyError.guardrailViolation(event)

        } catch LanguageModelSession.GenerationError.refusal {
            let event = guardrailHandler.handleRefusal(prompt: prompt)
            privacyLogger.logSafetyEvent(event)
            throw SafetyError.guardrailViolation(event)

        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            log.error("Context window exceeded despite pre-check")
            throw SafetyError.contextLimitExceeded

        } catch {
            log.error("Request failed: \(error.localizedDescription)")
            privacyLogger.logOperation(
                "single_turn",
                contentLength: prompt.count,
                success: false,
                errorType: "\(error)"
            )
            throw error
        }
    }

    /// Perform a single-turn request returning String
    func singleTurnRequest(
        prompt: String,
        instructions: String,
        options: GenerationOptions = GenerationOptions()
    ) async throws -> String {
        // Ensure no concurrent requests
        guard !isResponding else {
            log.warning("Request blocked: already responding")
            throw SafetyError.guardrailViolation(
                SafetyEvent(
                    type: .privacyFilter,
                    userMessage: "Please wait for the current request to complete."
                )
            )
        }

        isResponding = true
        defer { isResponding = false }

        // Safety check
        switch safetyFilter.isSafe(prompt) {
        case .success:
            break
        case .failure(let error):
            log.error("Safety filter triggered")
            throw error
        }

        // Context limit check
        guard contextBudget.canFitInContext(prompt, instructions: instructions) else {
            log.warning("Content exceeds context window")
            throw SafetyError.contextLimitExceeded
        }

        // Create new session for single-turn
        let localeInstructions = localeManager.getLocaleInstructions()
        let fullInstructions = "\(instructions)\n\n\(localeInstructions)"

        let session = LanguageModelSession(instructions: fullInstructions)

        do {
            let response = try await session.respond(
                to: prompt,
                options: options
            )

            privacyLogger.logOperation(
                "single_turn",
                contentLength: prompt.count,
                success: true
            )

            return response.content

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            let event = guardrailHandler.handleGuardrailViolation(prompt: prompt)
            privacyLogger.logSafetyEvent(event)
            throw SafetyError.guardrailViolation(event)

        } catch LanguageModelSession.GenerationError.refusal {
            let event = guardrailHandler.handleRefusal(prompt: prompt)
            privacyLogger.logSafetyEvent(event)
            throw SafetyError.guardrailViolation(event)

        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            log.error("Context window exceeded despite pre-check")
            throw SafetyError.contextLimitExceeded

        } catch {
            log.error("Request failed: \(error.localizedDescription)")
            privacyLogger.logOperation(
                "single_turn",
                contentLength: prompt.count,
                success: false,
                errorType: "\(error)"
            )
            throw error
        }
    }

    // MARK: - Multi-Turn Request

    /// Perform a multi-turn request (reuses existing session)
    func multiTurnRequest(
        prompt: String,
        options: GenerationOptions = GenerationOptions()
    ) async throws -> String {
        guard let session = currentSession else {
            log.error("No active session for multi-turn request")
            throw SafetyError.guardrailViolation(
                SafetyEvent(
                    type: .privacyFilter,
                    userMessage: "Please start a conversation session first."
                )
            )
        }

        // Ensure no concurrent requests
        guard !isResponding else {
            log.warning("Request blocked: already responding")
            throw SafetyError.guardrailViolation(
                SafetyEvent(
                    type: .privacyFilter,
                    userMessage: "Please wait for the current response to complete."
                )
            )
        }

        isResponding = true
        defer { isResponding = false }

        // Safety check
        switch safetyFilter.isSafe(prompt) {
        case .success:
            break
        case .failure(let error):
            log.error("Safety filter triggered")
            throw error
        }

        do {
            let response = try await session.respond(
                to: prompt,
                options: options
            )

            privacyLogger.logOperation(
                "multi_turn",
                contentLength: prompt.count,
                success: true
            )

            return response.content

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            let event = guardrailHandler.handleGuardrailViolation(prompt: prompt)
            privacyLogger.logSafetyEvent(event)
            throw SafetyError.guardrailViolation(event)

        } catch LanguageModelSession.GenerationError.refusal {
            let event = guardrailHandler.handleRefusal(prompt: prompt)
            privacyLogger.logSafetyEvent(event)
            throw SafetyError.guardrailViolation(event)

        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            log.error("Context window exceeded - starting new session")

            // Context exceeded in multi-turn: start new session and retry
            endSession()
            startSession(instructions: "Continue the conversation from context.")

            guard let newSession = currentSession else {
                throw SafetyError.contextLimitExceeded
            }

            // Retry with new session
            let response = try await newSession.respond(
                to: prompt,
                options: options
            )

            return response.content

        } catch {
            log.error("Request failed: \(error.localizedDescription)")
            privacyLogger.logOperation(
                "multi_turn",
                contentLength: prompt.count,
                success: false,
                errorType: "\(error)"
            )
            throw error
        }
    }

    // MARK: - Streaming Support

    /// Stream a response with snapshots
    func streamResponse(
        prompt: String,
        instructions: String,
        options: GenerationOptions = GenerationOptions()
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                guard !isResponding else {
                    continuation.finish(throwing: SafetyError.guardrailViolation(
                        SafetyEvent(
                            type: .privacyFilter,
                            userMessage: "Please wait for the current request to complete."
                        )
                    ))
                    return
                }

                isResponding = true
                defer { isResponding = false }

                // Safety check
                switch safetyFilter.isSafe(prompt) {
                case .success:
                    break
                case .failure(let error):
                    continuation.finish(throwing: error)
                    return
                }

                // Create session
                let localeInstructions = localeManager.getLocaleInstructions()
                let fullInstructions = "\(instructions)\n\n\(localeInstructions)"
                let session = LanguageModelSession(instructions: fullInstructions)

                do {
                    let stream = session.streamResponse(options: options) {
                        prompt
                    }

                    for try await snapshot in stream {
                        continuation.yield(snapshot.content)
                    }

                    continuation.finish()

                } catch {
                    log.error("Streaming failed: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Chunked Processing

    /// Process long content by chunking
    func processLongContent(
        text: String,
        instructions: String,
        processor: @escaping (String) async throws -> String
    ) async throws -> String {
        guard !isResponding else {
            throw SafetyError.guardrailViolation(
                SafetyEvent(
                    type: .privacyFilter,
                    userMessage: "Please wait for the current request to complete."
                )
            )
        }

        if contextBudget.canFitInContext(text, instructions: instructions) {
            return try await processor(text)
        }

        log.info("Content too long, processing in chunks")

        return try await contextBudget.processInChunks(text) { chunk in
            try await processor(chunk)
        }
    }
}

// MARK: - NotificationManager


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

        UNUserNotificationCenter.current().setNotificationCategories([category])

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

// MARK: - ScanQueue


/// A pending scan waiting for flashcard generation
struct PendingScan: Identifiable, Codable {
    let id: UUID
    let text: String
    let topic: String?
    let deck: String?
    let imageDataArray: [Data]
    let pageCount: Int
    let createdAt: Date
    let formats: [String] // FlashcardType raw values

    init(
        id: UUID = UUID(),
        text: String,
        topic: String? = nil,
        deck: String? = nil,
        imageDataArray: [Data] = [],
        pageCount: Int = 1,
        formats: Set<FlashcardType> = [.qa, .cloze, .definition]
    ) {
        self.id = id
        self.text = text
        self.topic = topic
        self.deck = deck
        self.imageDataArray = imageDataArray
        self.pageCount = pageCount
        self.createdAt = Date()
        self.formats = formats.map(\.rawValue)
    }

    var flashcardFormats: Set<FlashcardType> {
        Set(formats.compactMap { FlashcardType(rawValue: $0) })
    }
}

/// Manages offline scan queue for background processing
@MainActor
final class ScanQueue: ObservableObject {
    static let shared = ScanQueue()

    private let logger = Logger(subsystem: "com.cardgenie.app", category: "ScanQueue")
    private let userDefaults = UserDefaults.standard
    private let queueKey = "com.cardgenie.scanQueue"

    @Published private(set) var pendingScans: [PendingScan] = []
    @Published private(set) var isProcessing = false

    private init() {
        loadQueue()
    }

    // MARK: - Queue Management

    /// Add a scan to the offline queue
    func enqueueScan(_ scan: PendingScan) {
        pendingScans.append(scan)
        saveQueue()
        logger.info("Enqueued scan: \(scan.id) - \(scan.text.prefix(50))...")
    }

    /// Add a scan from ScanReviewView data
    func enqueueScan(
        text: String,
        topic: String?,
        deck: String?,
        images: [UIImage],
        formats: Set<FlashcardType>
    ) {
        let imageData = images.compactMap { $0.jpegData(compressionQuality: 0.8) }
        let scan = PendingScan(
            text: text,
            topic: topic,
            deck: deck,
            imageDataArray: imageData,
            pageCount: images.count,
            formats: formats
        )
        enqueueScan(scan)
    }

    /// Remove a specific scan from queue
    func removeScan(_ scanID: UUID) {
        pendingScans.removeAll { $0.id == scanID }
        saveQueue()
        logger.info("Removed scan from queue: \(scanID)")
    }

    /// Clear all pending scans
    func clearQueue() {
        pendingScans.removeAll()
        saveQueue()
        logger.info("Cleared scan queue")
    }

    // MARK: - Processing

    /// Process all pending scans using Foundation Models
    /// - Parameter modelContext: SwiftData context for saving results
    /// - Returns: Number of successfully processed scans
    @discardableResult
    func processQueue(modelContext: ModelContext, fmClient: FMClient) async -> Int {
        guard !pendingScans.isEmpty else {
            logger.info("Queue is empty, nothing to process")
            return 0
        }

        guard !isProcessing else {
            logger.warning("Queue is already being processed")
            return 0
        }

        isProcessing = true
        defer { isProcessing = false }

        logger.info("Starting queue processing: \(self.pendingScans.count) scans")
        var successCount = 0

        for scan in self.pendingScans {
            do {
                try await processScan(scan, modelContext: modelContext, fmClient: fmClient)
                removeScan(scan.id)
                successCount += 1
                logger.info("Successfully processed scan: \(scan.id)")
            } catch {
                logger.error("Failed to process scan \(scan.id): \(error.localizedDescription)")
                // Keep failed scan in queue for retry
            }
        }

        logger.info("Queue processing complete: \(successCount)/\(self.pendingScans.count) successful")
        return successCount
    }

    /// Process a single pending scan
    private func processScan(
        _ scan: PendingScan,
        modelContext: ModelContext,
        fmClient: FMClient
    ) async throws {
        // Create StudyContent
        let content = StudyContent(
            source: .photo,
            rawContent: scan.text
        )
        content.topic = scan.topic
        content.extractedText = scan.text

        // Store images
        if scan.pageCount > 1 {
            content.photoPages = scan.imageDataArray
            content.pageCount = scan.pageCount
        } else if let imageData = scan.imageDataArray.first {
            content.photoData = imageData
            content.pageCount = 1
        }

        modelContext.insert(content)

        // Generate flashcards
        let result = try await fmClient.generateFlashcards(
            from: content,
            formats: scan.flashcardFormats,
            maxPerFormat: 3
        )

        // Find or create flashcard set
        let deckName = scan.deck ?? scan.topic ?? result.topicTag
        let flashcardSet = modelContext.findOrCreateFlashcardSet(topicLabel: deckName)

        // Link flashcards
        content.flashcards.append(contentsOf: result.flashcards)
        for flashcard in result.flashcards {
            flashcardSet.addCard(flashcard)
            modelContext.insert(flashcard)
        }
        flashcardSet.entryCount += 1

        try modelContext.save()
    }

    // MARK: - Persistence

    private func loadQueue() {
        guard let data = userDefaults.data(forKey: queueKey),
              let decoded = try? JSONDecoder().decode([PendingScan].self, from: data) else {
            logger.info("No existing queue found")
            return
        }

        pendingScans = decoded
        logger.info("Loaded queue: \(decoded.count) pending scans")
    }

    private func saveQueue() {
        guard let encoded = try? JSONEncoder().encode(pendingScans) else {
            logger.error("Failed to encode queue")
            return
        }

        userDefaults.set(encoded, forKey: queueKey)
    }

    // MARK: - Helper Methods

    /// Check if AI is available for processing
    func canProcessQueue(fmClient: FMClient) -> Bool {
        return fmClient.capability() == .available
    }

    /// Get queue statistics
    var queueStats: (count: Int, oldestDate: Date?) {
        let oldest = pendingScans.min(by: { $0.createdAt < $1.createdAt })?.createdAt
        return (pendingScans.count, oldest)
    }
}

// FlashcardType is already Codable in FlashcardModels.swift

// MARK: - ScanAnalytics


/// Metrics tracked during photo scanning and OCR
struct ScanMetrics: Codable {
    var scanAttempts: Int = 0
    var successfulScans: Int = 0
    var failedScans: Int = 0
    var totalCharactersExtracted: Int = 0
    var averageConfidence: Double = 0.0
    var lowConfidenceWarnings: Int = 0
    var multiPageScans: Int = 0
    var preprocessingUsed: Int = 0
    var lastUpdated: Date = Date()

    var successRate: Double {
        guard scanAttempts > 0 else { return 0.0 }
        return Double(successfulScans) / Double(scanAttempts)
    }

    var averageCharactersPerScan: Double {
        guard successfulScans > 0 else { return 0.0 }
        return Double(totalCharactersExtracted) / Double(successfulScans)
    }
}

/// Analytics manager for photo scanning operations
@MainActor
final class ScanAnalytics: ObservableObject {
    static let shared = ScanAnalytics()
    private let logger = Logger(subsystem: "com.cardgenie.app", category: "ScanAnalytics")

    @Published private(set) var metrics = ScanMetrics()

    private let userDefaults = UserDefaults.standard
    private let metricsKey = "com.cardgenie.scanMetrics"

    private init() {
        loadMetrics()
    }

    // MARK: - Event Tracking

    /// Track a scan attempt
    func trackScanAttempt() {
        metrics.scanAttempts += 1
        metrics.lastUpdated = Date()
        saveMetrics()
        logger.info("Scan attempt #\(self.metrics.scanAttempts)")
    }

    /// Track a successful scan
    func trackScanSuccess(characterCount: Int, confidence: Double = 0.0) {
        metrics.successfulScans += 1
        metrics.totalCharactersExtracted += characterCount

        // Update rolling average confidence
        if confidence > 0 {
            let totalScans = Double(metrics.successfulScans)
            metrics.averageConfidence = ((metrics.averageConfidence * (totalScans - 1)) + confidence) / totalScans
        }

        metrics.lastUpdated = Date()
        saveMetrics()
        logger.info("Scan success: \(characterCount) characters, confidence: \(confidence)")
    }

    /// Track a failed scan
    func trackScanFailure(reason: String? = nil) {
        metrics.failedScans += 1
        metrics.lastUpdated = Date()
        saveMetrics()

        if let reason = reason {
            logger.error("Scan failed: \(reason)")
        } else {
            logger.error("Scan failed")
        }
    }

    /// Track a low confidence warning shown to user
    func trackLowConfidenceWarning() {
        metrics.lowConfidenceWarnings += 1
        metrics.lastUpdated = Date()
        saveMetrics()
        logger.warning("Low confidence warning shown")
    }

    /// Track a multi-page scan
    func trackMultiPageScan(pageCount: Int) {
        metrics.multiPageScans += 1
        metrics.lastUpdated = Date()
        saveMetrics()
        logger.info("Multi-page scan completed: \(pageCount) pages")
    }

    /// Track preprocessing usage
    func trackPreprocessing() {
        metrics.preprocessingUsed += 1
        metrics.lastUpdated = Date()
        saveMetrics()
        logger.info("Image preprocessing applied")
    }

    // MARK: - Persistence

    private func loadMetrics() {
        guard let data = userDefaults.data(forKey: metricsKey),
              let decoded = try? JSONDecoder().decode(ScanMetrics.self, from: data) else {
            logger.info("No existing metrics found, starting fresh")
            return
        }

        metrics = decoded
        logger.info("Loaded metrics: \(self.metrics.scanAttempts) attempts, \(self.metrics.successfulScans) successful")
    }

    private func saveMetrics() {
        guard let encoded = try? JSONEncoder().encode(metrics) else {
            logger.error("Failed to encode metrics")
            return
        }

        userDefaults.set(encoded, forKey: metricsKey)
    }

    // MARK: - Reporting

    /// Get a summary report of scan metrics
    func getReport() -> String {
        """
        Scan Analytics Report
        =====================
        Total Attempts: \(metrics.scanAttempts)
        Successful Scans: \(metrics.successfulScans)
        Failed Scans: \(metrics.failedScans)
        Success Rate: \(String(format: "%.1f%%", metrics.successRate * 100))

        Text Extraction:
        - Total Characters: \(metrics.totalCharactersExtracted)
        - Avg per Scan: \(String(format: "%.0f", metrics.averageCharactersPerScan)) characters
        - Avg Confidence: \(String(format: "%.1f%%", metrics.averageConfidence * 100))

        Features:
        - Low Confidence Warnings: \(metrics.lowConfidenceWarnings)
        - Multi-page Scans: \(metrics.multiPageScans)
        - Preprocessing Used: \(metrics.preprocessingUsed)

        Last Updated: \(metrics.lastUpdated.formatted())
        """
    }

    /// Reset all metrics
    func reset() {
        metrics = ScanMetrics()
        saveMetrics()
        logger.info("Metrics reset")
    }
}
