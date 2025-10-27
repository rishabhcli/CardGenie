//
//  ScanAnalytics.swift
//  CardGenie
//
//  Analytics tracking for photo scanning quality and performance.
//  Helps measure impact of improvements to OCR pipeline.
//

import Foundation
import OSLog
import Combine

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
