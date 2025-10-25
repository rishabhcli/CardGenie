//
//  CacheManager.swift
//  CardGenie
//
//  Caches expensive computations to improve performance.
//

import Foundation
import UIKit

/// Generic cache manager for expensive computations
@Observable
final class CacheManager {
    static let shared = CacheManager()

    private var cache: [String: CachedValue] = [:]
    private let cacheQueue = DispatchQueue(label: "com.cardgenie.cache", attributes: .concurrent)

    private init() {
        // Clear cache on memory warning
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Get cached value or compute if needed
    func get<T>(
        key: String,
        maxAge: TimeInterval = 60,
        compute: () -> T
    ) -> T {
        var result: T?

        cacheQueue.sync {
            if let cached = cache[key],
               !cached.isExpired(maxAge: maxAge),
               let value = cached.value as? T {
                result = value
            }
        }

        if let result = result {
            return result
        }

        // Compute new value
        let newValue = compute()

        cacheQueue.async(flags: .barrier) {
            self.cache[key] = CachedValue(value: newValue)
        }

        return newValue
    }

    /// Invalidate specific cache entry
    func invalidate(key: String) {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }

    /// Clear all cached values
    @objc func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

// MARK: - Cached Value

private struct CachedValue {
    let value: Any
    let timestamp: Date

    init(value: Any) {
        self.value = value
        self.timestamp = Date()
    }

    func isExpired(maxAge: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) > maxAge
    }
}

// MARK: - Flashcard Statistics Cache

extension CacheManager {
    /// Cache key for total due count
    static func dueCountKey(setIDs: [UUID]) -> String {
        "due_count_\(setIDs.sorted().map { $0.uuidString }.joined(separator: "_"))"
    }

    /// Cache key for set statistics
    static func setStatsKey(setID: UUID) -> String {
        "set_stats_\(setID.uuidString)"
    }

    /// Cache key for daily review queue
    static func dailyQueueKey(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "daily_queue_\(formatter.string(from: date))"
    }
}
