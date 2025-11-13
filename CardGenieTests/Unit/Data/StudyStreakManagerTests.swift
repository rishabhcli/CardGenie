//
//  StudyStreakManagerTests.swift
//  CardGenie
//
//  Comprehensive unit tests for StudyStreakManager.
//  Tests daily streak tracking, consecutive day logic, and edge cases.
//

import XCTest
@testable import CardGenie

final class StudyStreakManagerTests: XCTestCase {
    var manager: StudyStreakManager!
    var testDefaults: UserDefaults!
    let testSuiteName = "com.cardgenie.tests.streaks"

    override func setUp() async throws {
        // Create isolated UserDefaults for testing
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removePersistentDomain(forName: testSuiteName)

        // Create manager with test defaults via reflection
        // Note: Since init is private, we'll use the shared instance and reset it
        manager = StudyStreakManager.shared
        manager.reset()
    }

    override func tearDown() async throws {
        manager.reset()
        testDefaults.removePersistentDomain(forName: testSuiteName)
        testDefaults = nil
        manager = nil
    }

    // MARK: - Initial State Tests

    func testInitialState_NoData() throws {
        // Given: Fresh manager with no prior data
        // When: Querying initial values
        let currentStreak = manager.currentStreak()
        let longestStreak = manager.longestStreak()

        // Then: Should return zero for all values
        XCTAssertEqual(currentStreak, 0, "Initial current streak should be 0")
        XCTAssertEqual(longestStreak, 0, "Initial longest streak should be 0")
    }

    // MARK: - First Session Tests

    func testFirstSession_CreatesStreakOfOne() throws {
        // Given: No prior study history
        XCTAssertEqual(manager.currentStreak(), 0)

        // When: Recording first session
        let streak = manager.recordSessionCompletion(on: Date())

        // Then: Should create streak of 1
        XCTAssertEqual(streak, 1, "First session should create streak of 1")
        XCTAssertEqual(manager.currentStreak(), 1)
        XCTAssertEqual(manager.longestStreak(), 1)
    }

    func testFirstSession_SetsLongestStreak() throws {
        // Given: No prior data
        // When: Recording first session
        _ = manager.recordSessionCompletion(on: Date())

        // Then: Longest streak should be set to 1
        XCTAssertEqual(manager.longestStreak(), 1)
    }

    // MARK: - Same Day Tests

    func testMultipleSessions_SameDay_DoesNotIncrement() throws {
        // Given: One session already recorded today
        let today = Date()
        let firstStreak = manager.recordSessionCompletion(on: today)
        XCTAssertEqual(firstStreak, 1)

        // When: Recording another session on the same day
        let secondStreak = manager.recordSessionCompletion(on: today)

        // Then: Streak should not increment
        XCTAssertEqual(secondStreak, 1, "Same-day sessions should not increment streak")
        XCTAssertEqual(manager.currentStreak(), 1)
    }

    func testMultipleSessions_SameDay_WithinHours() throws {
        // Given: Session in the morning
        let calendar = Calendar.current
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        _ = manager.recordSessionCompletion(on: morning)

        // When: Session in the evening of same day
        let evening = calendar.date(bySettingHour: 21, minute: 30, second: 0, of: Date())!
        let streak = manager.recordSessionCompletion(on: evening)

        // Then: Should still be streak of 1
        XCTAssertEqual(streak, 1, "Sessions within same calendar day should not increment")
    }

    // MARK: - Consecutive Day Tests

    func testConsecutiveDays_IncrementsStreak() throws {
        // Given: Session on day 1
        let day1 = Date()
        _ = manager.recordSessionCompletion(on: day1)

        // When: Session on day 2 (exactly 1 day later)
        let day2 = Calendar.current.date(byAdding: .day, value: 1, to: day1)!
        let streak = manager.recordSessionCompletion(on: day2)

        // Then: Streak should increment to 2
        XCTAssertEqual(streak, 2, "Consecutive day should increment streak")
        XCTAssertEqual(manager.currentStreak(), 2)
    }

    func testConsecutiveDays_SevenDayStreak() throws {
        // Given: Sessions on 7 consecutive days
        var currentDate = Date()

        for expectedStreak in 1...7 {
            // When: Recording session on each day
            let streak = manager.recordSessionCompletion(on: currentDate)

            // Then: Streak should match expected value
            XCTAssertEqual(streak, expectedStreak, "Day \(expectedStreak) should have streak \(expectedStreak)")

            // Move to next day
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }

        XCTAssertEqual(manager.currentStreak(), 7)
        XCTAssertEqual(manager.longestStreak(), 7)
    }

    func testConsecutiveDays_UpdatesLongestStreak() throws {
        // Given: Building a streak
        var currentDate = Date()

        // When: Recording 5 consecutive days
        for _ in 1...5 {
            _ = manager.recordSessionCompletion(on: currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }

        // Then: Longest streak should be 5
        XCTAssertEqual(manager.longestStreak(), 5, "Longest streak should track highest value")
    }

    // MARK: - Streak Breaking Tests

    func testStreakBreak_TwoDayGap_ResetsToOne() throws {
        // Given: 3-day streak
        var currentDate = Date()
        for _ in 1...3 {
            _ = manager.recordSessionCompletion(on: currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
        XCTAssertEqual(manager.currentStreak(), 3)

        // When: Missing a day (2-day gap)
        let afterGap = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)! // Skip one day
        let newStreak = manager.recordSessionCompletion(on: afterGap)

        // Then: Streak should reset to 1
        XCTAssertEqual(newStreak, 1, "Gap in consecutive days should reset streak to 1")
        XCTAssertEqual(manager.currentStreak(), 1)
    }

    func testStreakBreak_LongestStreakPersists() throws {
        // Given: Build a 5-day streak
        var currentDate = Date()
        for _ in 1...5 {
            _ = manager.recordSessionCompletion(on: currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
        XCTAssertEqual(manager.longestStreak(), 5)

        // When: Break streak with a gap
        let afterGap = Calendar.current.date(byAdding: .day, value: 2, to: currentDate)! // 2-day gap
        _ = manager.recordSessionCompletion(on: afterGap)

        // Then: Current streak resets but longest persists
        XCTAssertEqual(manager.currentStreak(), 1, "Current streak should reset")
        XCTAssertEqual(manager.longestStreak(), 5, "Longest streak should persist after break")
    }

    func testStreakBreak_WeekGap_ResetsToOne() throws {
        // Given: 2-day streak
        var currentDate = Date()
        _ = manager.recordSessionCompletion(on: currentDate)
        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        _ = manager.recordSessionCompletion(on: currentDate)

        // When: 7-day gap
        let afterWeek = Calendar.current.date(byAdding: .day, value: 8, to: currentDate)!
        let streak = manager.recordSessionCompletion(on: afterWeek)

        // Then: Streak resets to 1
        XCTAssertEqual(streak, 1)
    }

    // MARK: - Longest Streak Tests

    func testLongestStreak_UpdatesWhenExceeded() throws {
        // Given: Build 3-day streak
        var currentDate = Date()
        for _ in 1...3 {
            _ = manager.recordSessionCompletion(on: currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
        XCTAssertEqual(manager.longestStreak(), 3)

        // When: Break and build 5-day streak
        currentDate = Calendar.current.date(byAdding: .day, value: 2, to: currentDate)! // Break
        for _ in 1...5 {
            _ = manager.recordSessionCompletion(on: currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }

        // Then: Longest should update to 5
        XCTAssertEqual(manager.longestStreak(), 5, "Longest streak should update when exceeded")
    }

    func testLongestStreak_DoesNotDecreaseOnBreak() throws {
        // Given: 10-day streak
        var currentDate = Date()
        for _ in 1...10 {
            _ = manager.recordSessionCompletion(on: currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }

        // When: Break streak and start new one
        currentDate = Calendar.current.date(byAdding: .day, value: 2, to: currentDate)!
        _ = manager.recordSessionCompletion(on: currentDate)

        // Then: Longest should remain 10
        XCTAssertEqual(manager.longestStreak(), 10)
        XCTAssertEqual(manager.currentStreak(), 1)
    }

    // MARK: - Reset Tests

    func testReset_ClearsAllData() throws {
        // Given: Active streak with data
        var currentDate = Date()
        for _ in 1...5 {
            _ = manager.recordSessionCompletion(on: currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
        XCTAssertEqual(manager.currentStreak(), 5)
        XCTAssertEqual(manager.longestStreak(), 5)

        // When: Resetting
        manager.reset()

        // Then: All values should be zero
        XCTAssertEqual(manager.currentStreak(), 0, "Current streak should be 0 after reset")
        XCTAssertEqual(manager.longestStreak(), 0, "Longest streak should be 0 after reset")
    }

    func testReset_AllowsNewStreak() throws {
        // Given: Reset manager
        manager.reset()

        // When: Starting new streak after reset
        let streak = manager.recordSessionCompletion(on: Date())

        // Then: Should start fresh at 1
        XCTAssertEqual(streak, 1)
        XCTAssertEqual(manager.currentStreak(), 1)
    }

    // MARK: - Edge Cases

    func testEdgeCase_MidnightBoundary() throws {
        // Given: Session just before midnight
        let calendar = Calendar.current
        let day1End = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: Date())!
        _ = manager.recordSessionCompletion(on: day1End)

        // When: Session just after midnight (same calendar day for startOfDay comparison)
        let day2Start = calendar.date(byAdding: .day, value: 1, to: day1End)!
        let day2StartOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 1, of: day2Start)!
        let streak = manager.recordSessionCompletion(on: day2StartOfDay)

        // Then: Should increment streak (consecutive days)
        XCTAssertEqual(streak, 2, "Midnight boundary should be handled as consecutive days")
    }

    func testEdgeCase_LongStreak_100Days() throws {
        // Given: Simulating 100 consecutive days
        var currentDate = Date()

        // When: Recording 100 sessions
        for expectedStreak in 1...100 {
            let streak = manager.recordSessionCompletion(on: currentDate)
            XCTAssertEqual(streak, expectedStreak, "Day \(expectedStreak) should have correct streak")
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }

        // Then: Should reach 100-day streak
        XCTAssertEqual(manager.currentStreak(), 100, "Should handle long streaks correctly")
        XCTAssertEqual(manager.longestStreak(), 100)
    }

    func testEdgeCase_BackwardsDate_DoesNotCrash() throws {
        // Given: Session on a date
        let today = Date()
        _ = manager.recordSessionCompletion(on: today)

        // When: Recording session on a past date (edge case/time travel)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let streak = manager.recordSessionCompletion(on: yesterday)

        // Then: Should handle gracefully (resets streak since not consecutive forward)
        XCTAssertEqual(streak, 1, "Backward date should reset streak")
    }

    func testEdgeCase_FarFutureDate_ResetsStreak() throws {
        // Given: Session today
        let today = Date()
        _ = manager.recordSessionCompletion(on: today)

        // When: Session 1 year in the future
        let farFuture = Calendar.current.date(byAdding: .year, value: 1, to: today)!
        let streak = manager.recordSessionCompletion(on: farFuture)

        // Then: Should reset streak (large gap)
        XCTAssertEqual(streak, 1, "Large time gap should reset streak")
    }

    // MARK: - Date Component Tests

    func testDateComponents_ExactlyOneDayApart() throws {
        // Given: Two dates exactly 24 hours apart
        let date1 = Date()
        let date2 = Calendar.current.date(byAdding: .hour, value: 24, to: date1)!

        // When: Recording both
        _ = manager.recordSessionCompletion(on: date1)
        let streak = manager.recordSessionCompletion(on: date2)

        // Then: Should be consecutive (based on startOfDay)
        XCTAssertEqual(streak, 2, "Dates 24 hours apart should be consecutive")
    }

    func testDateComponents_StartOfDayNormalization() throws {
        // Given: Different times on consecutive days
        let calendar = Calendar.current
        let day1Morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let day2Evening = calendar.date(byAdding: .day, value: 1, to: day1Morning)!
        let day2EveningLate = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day2Evening)!

        // When: Recording both
        _ = manager.recordSessionCompletion(on: day1Morning)
        let streak = manager.recordSessionCompletion(on: day2EveningLate)

        // Then: Should be consecutive regardless of time
        XCTAssertEqual(streak, 2, "Time of day should not affect consecutive day detection")
    }

    // MARK: - Boundary Value Tests

    func testBoundaryValue_ZeroToOne() throws {
        // Given: Zero streak
        XCTAssertEqual(manager.currentStreak(), 0)

        // When: First session
        let streak = manager.recordSessionCompletion(on: Date())

        // Then: Should transition to 1
        XCTAssertEqual(streak, 1)
    }

    func testBoundaryValue_BreakFromHighStreak() throws {
        // Given: High streak (50 days)
        var currentDate = Date()
        for _ in 1...50 {
            _ = manager.recordSessionCompletion(on: currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }

        // When: Breaking streak
        let afterGap = Calendar.current.date(byAdding: .day, value: 2, to: currentDate)!
        let newStreak = manager.recordSessionCompletion(on: afterGap)

        // Then: Should reset to 1 (not crash with large numbers)
        XCTAssertEqual(newStreak, 1)
        XCTAssertEqual(manager.longestStreak(), 50)
    }

    // MARK: - Multiple Reset Tests

    func testMultipleResets_DoNotCorruptState() throws {
        // Given/When: Multiple resets
        for i in 1...5 {
            // Build small streak
            _ = manager.recordSessionCompletion(on: Date())

            // Reset
            manager.reset()

            // Then: Should be back to zero
            XCTAssertEqual(manager.currentStreak(), 0, "Reset \(i) should clear current streak")
            XCTAssertEqual(manager.longestStreak(), 0, "Reset \(i) should clear longest streak")
        }
    }

    // MARK: - Query Without Mutation Tests

    func testCurrentStreak_DoesNotMutate() throws {
        // Given: Active streak
        _ = manager.recordSessionCompletion(on: Date())
        let streakBefore = manager.currentStreak()

        // When: Calling currentStreak multiple times
        let streak1 = manager.currentStreak()
        let streak2 = manager.currentStreak()
        let streak3 = manager.currentStreak()

        // Then: Should return same value without mutation
        XCTAssertEqual(streak1, streakBefore)
        XCTAssertEqual(streak2, streakBefore)
        XCTAssertEqual(streak3, streakBefore)
    }

    func testLongestStreak_DoesNotMutate() throws {
        // Given: Active streak
        var currentDate = Date()
        for _ in 1...5 {
            _ = manager.recordSessionCompletion(on: currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
        let longestBefore = manager.longestStreak()

        // When: Calling longestStreak multiple times
        let longest1 = manager.longestStreak()
        let longest2 = manager.longestStreak()

        // Then: Should return same value
        XCTAssertEqual(longest1, longestBefore)
        XCTAssertEqual(longest2, longestBefore)
    }
}
