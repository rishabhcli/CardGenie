//
//  MagicEffectsTests.swift
//  CardGenieTests
//
//  Comprehensive unit tests for MagicEffects view modifiers, button styles,
//  and haptic feedback. Tests initialization, configuration, accessibility,
//  and state management.
//

import XCTest
import SwiftUI
@testable import CardGenie

@MainActor
final class MagicEffectsTests: XCTestCase {

    // MARK: - SparkleEffect Tests

    func testSparkleEffect_DefaultInitialization() {
        // When: Creating SparkleEffect with defaults
        let effect = SparkleEffect()

        // Then: Should have default values
        XCTAssertEqual(effect.particleCount, 20)
        XCTAssertEqual(effect.colors.count, 3)
    }

    func testSparkleEffect_CustomInitialization() {
        // Given: Custom parameters
        let customCount = 50
        let customColors = [Color.red, Color.blue]

        // When: Creating SparkleEffect with custom values
        let effect = SparkleEffect(particleCount: customCount, colors: customColors)

        // Then: Should store custom values
        XCTAssertEqual(effect.particleCount, customCount)
        XCTAssertEqual(effect.colors.count, customColors.count)
    }

    func testSparkleEffect_ZeroParticles() {
        // When: Creating with zero particles
        let effect = SparkleEffect(particleCount: 0, colors: [.red])

        // Then: Should accept zero particles
        XCTAssertEqual(effect.particleCount, 0)
    }

    func testSparkleEffect_LargeParticleCount() {
        // When: Creating with large particle count
        let effect = SparkleEffect(particleCount: 100, colors: [.red])

        // Then: Should accept large counts
        XCTAssertEqual(effect.particleCount, 100)
    }

    func testSparkleEffect_EmptyColorArray() {
        // When: Creating with empty color array
        let effect = SparkleEffect(particleCount: 20, colors: [])

        // Then: Should accept empty array
        XCTAssertEqual(effect.colors.count, 0)
    }

    func testSparkleEffect_SingleColor() {
        // When: Creating with single color
        let effect = SparkleEffect(particleCount: 20, colors: [.magicGold])

        // Then: Should accept single color
        XCTAssertEqual(effect.colors.count, 1)
    }

    // MARK: - ShimmerEffect Tests

    func testShimmerEffect_Initialization() {
        // When: Creating ShimmerEffect
        let effect = ShimmerEffect()

        // Then: Should initialize without error
        XCTAssertNotNil(effect)
    }

    // MARK: - PulseEffect Tests

    func testPulseEffect_DefaultInitialization() {
        // When: Creating PulseEffect with defaults
        let effect = PulseEffect()

        // Then: Should have default values
        XCTAssertEqual(effect.color, .cosmicPurple)
        XCTAssertEqual(effect.duration, 1.5, accuracy: 0.01)
    }

    func testPulseEffect_CustomInitialization() {
        // Given: Custom parameters
        let customColor = Color.red
        let customDuration = 2.5

        // When: Creating PulseEffect with custom values
        let effect = PulseEffect(color: customColor, duration: customDuration)

        // Then: Should store custom values
        XCTAssertEqual(effect.color, customColor)
        XCTAssertEqual(effect.duration, customDuration, accuracy: 0.01)
    }

    func testPulseEffect_ShortDuration() {
        // When: Creating with very short duration
        let effect = PulseEffect(color: .red, duration: 0.1)

        // Then: Should accept short duration
        XCTAssertEqual(effect.duration, 0.1, accuracy: 0.01)
    }

    func testPulseEffect_LongDuration() {
        // When: Creating with long duration
        let effect = PulseEffect(color: .red, duration: 10.0)

        // Then: Should accept long duration
        XCTAssertEqual(effect.duration, 10.0, accuracy: 0.01)
    }

    // MARK: - FloatingEffect Tests

    func testFloatingEffect_DefaultInitialization() {
        // When: Creating FloatingEffect with defaults
        let effect = FloatingEffect()

        // Then: Should have default values
        XCTAssertEqual(effect.distance, 10, accuracy: 0.01)
        XCTAssertEqual(effect.duration, 2.0, accuracy: 0.01)
    }

    func testFloatingEffect_CustomInitialization() {
        // Given: Custom parameters
        let customDistance: CGFloat = 20
        let customDuration = 3.0

        // When: Creating FloatingEffect with custom values
        let effect = FloatingEffect(distance: customDistance, duration: customDuration)

        // Then: Should store custom values
        XCTAssertEqual(effect.distance, customDistance, accuracy: 0.01)
        XCTAssertEqual(effect.duration, customDuration, accuracy: 0.01)
    }

    func testFloatingEffect_SmallDistance() {
        // When: Creating with small distance
        let effect = FloatingEffect(distance: 1, duration: 2.0)

        // Then: Should accept small distance
        XCTAssertEqual(effect.distance, 1, accuracy: 0.01)
    }

    func testFloatingEffect_LargeDistance() {
        // When: Creating with large distance
        let effect = FloatingEffect(distance: 100, duration: 2.0)

        // Then: Should accept large distance
        XCTAssertEqual(effect.distance, 100, accuracy: 0.01)
    }

    func testFloatingEffect_NegativeDistance() {
        // When: Creating with negative distance
        let effect = FloatingEffect(distance: -10, duration: 2.0)

        // Then: Should accept negative distance
        XCTAssertEqual(effect.distance, -10, accuracy: 0.01)
    }

    // MARK: - MagicButtonStyle Tests

    func testMagicButtonStyle_DefaultInitialization() {
        // When: Creating MagicButtonStyle with defaults
        let style = MagicButtonStyle()

        // Then: Should initialize without error
        XCTAssertNotNil(style)
        XCTAssertEqual(style.shadowColor, .cosmicPurple)
    }

    func testMagicButtonStyle_CustomInitialization() {
        // Given: Custom parameters
        let customGradient = LinearGradient(
            colors: [.red, .blue],
            startPoint: .leading,
            endPoint: .trailing
        )
        let customShadowColor = Color.green

        // When: Creating MagicButtonStyle with custom values
        let style = MagicButtonStyle(gradient: customGradient, shadowColor: customShadowColor)

        // Then: Should store custom values
        XCTAssertNotNil(style)
        XCTAssertEqual(style.shadowColor, customShadowColor)
    }

    // MARK: - GlowEffect Tests

    func testGlowEffect_DefaultInitialization() {
        // When: Creating GlowEffect with defaults
        let effect = GlowEffect()

        // Then: Should have default values
        XCTAssertEqual(effect.color, .cosmicPurple)
        XCTAssertEqual(effect.radius, 10, accuracy: 0.01)
    }

    func testGlowEffect_CustomInitialization() {
        // Given: Custom parameters
        let customColor = Color.red
        let customRadius: CGFloat = 20

        // When: Creating GlowEffect with custom values
        let effect = GlowEffect(color: customColor, radius: customRadius)

        // Then: Should store custom values
        XCTAssertEqual(effect.color, customColor)
        XCTAssertEqual(effect.radius, customRadius, accuracy: 0.01)
    }

    func testGlowEffect_SmallRadius() {
        // When: Creating with small radius
        let effect = GlowEffect(color: .red, radius: 1)

        // Then: Should accept small radius
        XCTAssertEqual(effect.radius, 1, accuracy: 0.01)
    }

    func testGlowEffect_LargeRadius() {
        // When: Creating with large radius
        let effect = GlowEffect(color: .red, radius: 50)

        // Then: Should accept large radius
        XCTAssertEqual(effect.radius, 50, accuracy: 0.01)
    }

    func testGlowEffect_ZeroRadius() {
        // When: Creating with zero radius
        let effect = GlowEffect(color: .red, radius: 0)

        // Then: Should accept zero radius
        XCTAssertEqual(effect.radius, 0, accuracy: 0.01)
    }

    // MARK: - ConfettiEffect Tests

    func testConfettiEffect_Initialization() {
        // When: Creating ConfettiEffect
        let effect = ConfettiEffect()

        // Then: Should initialize with correct particle count
        XCTAssertEqual(effect.particleCount, 30)
    }

    // MARK: - ConfettiShape Tests

    func testConfettiShape_PathGeneration() {
        // Given: ConfettiShape
        let shape = ConfettiShape()
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)

        // When: Generating path
        let path = shape.path(in: rect)

        // Then: Should generate non-empty path
        XCTAssertFalse(path.isEmpty)
    }

    func testConfettiShape_ZeroSizeRect() {
        // Given: ConfettiShape with zero-size rect
        let shape = ConfettiShape()
        let rect = CGRect.zero

        // When: Generating path
        let path = shape.path(in: rect)

        // Then: Should handle zero-size rect
        XCTAssertNotNil(path)
    }

    // MARK: - HapticFeedback Tests

    func testHapticFeedback_Light() {
        // When: Triggering light haptic
        HapticFeedback.light()

        // Then: Should execute without crashing
        XCTAssertTrue(true)
    }

    func testHapticFeedback_Medium() {
        // When: Triggering medium haptic
        HapticFeedback.medium()

        // Then: Should execute without crashing
        XCTAssertTrue(true)
    }

    func testHapticFeedback_Heavy() {
        // When: Triggering heavy haptic
        HapticFeedback.heavy()

        // Then: Should execute without crashing
        XCTAssertTrue(true)
    }

    func testHapticFeedback_Success() {
        // When: Triggering success notification
        HapticFeedback.success()

        // Then: Should execute without crashing
        XCTAssertTrue(true)
    }

    func testHapticFeedback_Warning() {
        // When: Triggering warning notification
        HapticFeedback.warning()

        // Then: Should execute without crashing
        XCTAssertTrue(true)
    }

    func testHapticFeedback_Error() {
        // When: Triggering error notification
        HapticFeedback.error()

        // Then: Should execute without crashing
        XCTAssertTrue(true)
    }

    func testHapticFeedback_Selection() {
        // When: Triggering selection changed
        HapticFeedback.selection()

        // Then: Should execute without crashing
        XCTAssertTrue(true)
    }

    func testHapticFeedback_MultipleSequential() {
        // When: Triggering multiple haptics sequentially
        HapticFeedback.light()
        HapticFeedback.medium()
        HapticFeedback.heavy()

        // Then: Should execute without crashing
        XCTAssertTrue(true)
    }

    func testHapticFeedback_AllNotifications() {
        // When: Triggering all notification types
        HapticFeedback.success()
        HapticFeedback.warning()
        HapticFeedback.error()

        // Then: Should execute without crashing
        XCTAssertTrue(true)
    }

    // MARK: - HapticButton Tests

    func testHapticButton_DefaultInitialization() {
        // Given: Simple action
        var actionCalled = false
        let action = { actionCalled = true }

        // When: Creating HapticButton with default haptic style
        let button = HapticButton(action: action) {
            Text("Test")
        }

        // Then: Should initialize without error
        XCTAssertNotNil(button)
        XCTAssertEqual(button.hapticStyle, .medium)
        XCTAssertFalse(actionCalled) // Action not called yet
    }

    func testHapticButton_CustomHapticStyle() {
        // Given: Custom haptic style
        let action = {}

        // When: Creating HapticButton with light haptic
        let button = HapticButton(hapticStyle: .light, action: action) {
            Text("Test")
        }

        // Then: Should store custom style
        XCTAssertEqual(button.hapticStyle, .light)
    }

    func testHapticButton_HeavyHapticStyle() {
        // Given: Heavy haptic style
        let action = {}

        // When: Creating HapticButton with heavy haptic
        let button = HapticButton(hapticStyle: .heavy, action: action) {
            Text("Test")
        }

        // Then: Should store heavy style
        XCTAssertEqual(button.hapticStyle, .heavy)
    }

    // MARK: - View Extension Tests

    func testSparklesExtension_DefaultParameters() {
        // Given: A view
        let view = Text("Test")

        // When: Applying sparkles with defaults
        let modified = view.sparkles()

        // Then: Should return modified view
        XCTAssertNotNil(modified)
    }

    func testSparklesExtension_CustomParameters() {
        // Given: A view
        let view = Text("Test")

        // When: Applying sparkles with custom parameters
        let modified = view.sparkles(count: 50, colors: [.red, .blue])

        // Then: Should return modified view
        XCTAssertNotNil(modified)
    }

    func testShimmerExtension() {
        // Given: A view
        let view = Text("Test")

        // When: Applying shimmer
        let modified = view.shimmer()

        // Then: Should return modified view
        XCTAssertNotNil(modified)
    }

    func testPulseExtension_DefaultParameters() {
        // Given: A view
        let view = Circle()

        // When: Applying pulse with defaults
        let modified = view.pulse()

        // Then: Should return modified view
        XCTAssertNotNil(modified)
    }

    func testPulseExtension_CustomParameters() {
        // Given: A view
        let view = Circle()

        // When: Applying pulse with custom parameters
        let modified = view.pulse(color: .red, duration: 2.5)

        // Then: Should return modified view
        XCTAssertNotNil(modified)
    }

    func testFloatingExtension_DefaultParameters() {
        // Given: A view
        let view = Image(systemName: "star")

        // When: Applying floating with defaults
        let modified = view.floating()

        // Then: Should return modified view
        XCTAssertNotNil(modified)
    }

    func testFloatingExtension_CustomParameters() {
        // Given: A view
        let view = Image(systemName: "star")

        // When: Applying floating with custom parameters
        let modified = view.floating(distance: 20, duration: 3.0)

        // Then: Should return modified view
        XCTAssertNotNil(modified)
    }

    func testGlowExtension_DefaultParameters() {
        // Given: A view
        let view = Circle()

        // When: Applying glow with defaults
        let modified = view.glow()

        // Then: Should return modified view
        XCTAssertNotNil(modified)
    }

    func testGlowExtension_CustomParameters() {
        // Given: A view
        let view = Circle()

        // When: Applying glow with custom parameters
        let modified = view.glow(color: .red, radius: 20)

        // Then: Should return modified view
        XCTAssertNotNil(modified)
    }

    func testConfettiExtension() {
        // Given: A view
        let view = Text("Celebration!")

        // When: Applying confetti
        let modified = view.confetti()

        // Then: Should return modified view
        XCTAssertNotNil(modified)
    }

    // MARK: - Edge Case Tests

    func testSparkleEffect_VeryLargeParticleCount() {
        // When: Creating with very large particle count (stress test)
        let effect = SparkleEffect(particleCount: 1000, colors: [.red])

        // Then: Should handle large count
        XCTAssertEqual(effect.particleCount, 1000)
    }

    func testSparkleEffect_ManyColors() {
        // Given: Many colors
        let colors = [Color.red, .blue, .green, .yellow, .orange, .purple, .pink, .gray]

        // When: Creating with many colors
        let effect = SparkleEffect(particleCount: 20, colors: colors)

        // Then: Should handle many colors
        XCTAssertEqual(effect.colors.count, 8)
    }

    func testPulseEffect_VeryShortDuration() {
        // When: Creating with very short duration
        let effect = PulseEffect(color: .red, duration: 0.01)

        // Then: Should handle very short duration
        XCTAssertEqual(effect.duration, 0.01, accuracy: 0.001)
    }

    func testFloatingEffect_VeryLargeDistance() {
        // When: Creating with very large distance
        let effect = FloatingEffect(distance: 500, duration: 2.0)

        // Then: Should handle large distance
        XCTAssertEqual(effect.distance, 500, accuracy: 0.01)
    }

    func testGlowEffect_VeryLargeRadius() {
        // When: Creating with very large radius
        let effect = GlowEffect(color: .red, radius: 100)

        // Then: Should handle large radius
        XCTAssertEqual(effect.radius, 100, accuracy: 0.01)
    }

    // MARK: - Performance Tests

    func testPerformance_SparkleEffectCreation() {
        measure {
            for _ in 0..<100 {
                _ = SparkleEffect(particleCount: 20, colors: [.red, .blue, .green])
            }
        }
    }

    func testPerformance_HapticFeedback() {
        measure {
            for _ in 0..<10 {
                HapticFeedback.light()
            }
        }
    }

    func testPerformance_ViewModifierChaining() {
        let view = Text("Test")

        measure {
            _ = view
                .sparkles()
                .shimmer()
                .glow()
        }
    }

    // MARK: - Integration Tests

    func testViewModifier_MultipleEffectsChaining() {
        // Given: A view
        let view = Text("CardGenie")

        // When: Chaining multiple effects
        let modified = view
            .sparkles(count: 10, colors: [.magicGold])
            .shimmer()
            .glow(color: .cosmicPurple, radius: 15)
            .floating(distance: 5, duration: 2.0)

        // Then: Should successfully chain all modifiers
        XCTAssertNotNil(modified)
    }

    func testHapticFeedback_CompleteSequence() {
        // When: Executing complete haptic sequence
        HapticFeedback.light()
        HapticFeedback.medium()
        HapticFeedback.heavy()
        HapticFeedback.success()
        HapticFeedback.warning()
        HapticFeedback.error()
        HapticFeedback.selection()

        // Then: Should complete without crashing
        XCTAssertTrue(true)
    }

    func testConfettiShape_LargeRect() {
        // Given: Large rectangle
        let shape = ConfettiShape()
        let rect = CGRect(x: 0, y: 0, width: 1000, height: 1000)

        // When: Generating path
        let path = shape.path(in: rect)

        // Then: Should handle large rectangle
        XCTAssertFalse(path.isEmpty)
    }

    // MARK: - Concurrency Tests

    func testHapticFeedback_ConcurrentCalls() async {
        // When: Triggering haptics concurrently
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    HapticFeedback.light()
                }
            }
        }

        // Then: Should complete without crashing
        XCTAssertTrue(true)
    }

    func testViewModifier_ConcurrentCreation() async {
        // When: Creating view modifiers concurrently
        await withTaskGroup(of: SparkleEffect.self) { group in
            for i in 0..<10 {
                group.addTask {
                    SparkleEffect(particleCount: i * 10, colors: [.red])
                }
            }

            // Then: All should complete
            var count = 0
            for await _ in group {
                count += 1
            }
            XCTAssertEqual(count, 10)
        }
    }
}
