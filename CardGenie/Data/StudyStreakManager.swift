//
//  StudyStreakManager.swift
//  CardGenie
//
//  Tracks study streaks using UserDefaults so daily sessions update streak counts.
//

import Foundation

/// Manages daily study streaks for flashcard sessions.
final class StudyStreakManager {
    static let shared = StudyStreakManager()

    private let defaults: UserDefaults
    private let streakKey = "flashcard.streak.count"
    private let lastStudyDateKey = "flashcard.streak.lastDate"
    private let longestStreakKey = "flashcard.streak.longest"
    private let calendar = Calendar.current

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns the current streak without mutating stored values.
    func currentStreak() -> Int {
        defaults.integer(forKey: streakKey)
    }

    /// Record that the user completed a study session today.
    /// - Returns: Updated streak value.
    func recordSessionCompletion(on date: Date = Date()) -> Int {
        let today = calendar.startOfDay(for: date)

        let lastDate = defaults.object(forKey: lastStudyDateKey) as? Date
        var newStreak = max(1, defaults.integer(forKey: streakKey))

        if let lastDate {
            if calendar.isDate(today, inSameDayAs: lastDate) {
                // Already recorded today; keep existing streak.
                newStreak = defaults.integer(forKey: streakKey)
            } else if let days = calendar.dateComponents([.day], from: lastDate, to: today).day, days == 1 {
                // Consecutive day.
                newStreak = defaults.integer(forKey: streakKey) + 1
            } else {
                // Break in streak.
                newStreak = 1
            }
        } else {
            newStreak = 1
        }

        defaults.set(newStreak, forKey: streakKey)
        defaults.set(today, forKey: lastStudyDateKey)

        // Update longest streak if needed
        let currentLongest = defaults.integer(forKey: longestStreakKey)
        if newStreak > currentLongest {
            defaults.set(newStreak, forKey: longestStreakKey)
        }

        return newStreak
    }

    /// Returns the longest streak ever recorded.
    func longestStreak() -> Int {
        defaults.integer(forKey: longestStreakKey)
    }

    /// Reset streak values. Useful for tests.
    func reset() {
        defaults.removeObject(forKey: streakKey)
        defaults.removeObject(forKey: lastStudyDateKey)
        defaults.removeObject(forKey: longestStreakKey)
    }
}

