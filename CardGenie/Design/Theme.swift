//
//  Theme.swift
//  CardGenie
//
//  Liquid Glass design system for iOS 26.
//  Provides translucent materials, colors, and modifiers that adapt to accessibility settings.
//

import SwiftUI

// MARK: - Liquid Glass Materials

/// Liquid Glass materials for the iOS 26 design language.
/// These provide translucent, fluid backgrounds that dynamically blur and refract content.
/// Uses native iOS 26 .glassEffect() APIs for optimal performance and visual quality.
///
/// Note: The actual glass effect styling is applied via SwiftUI's .glassEffect() modifier.
/// These values represent corner radius preferences for different UI element types.
@available(iOS 26.0, *)
enum Glass {
    /// Corner radius for navigation bars and toolbars
    static let barCornerRadius: CGFloat = 0

    /// Corner radius for floating panels, sheets, and cards
    static let panelCornerRadius: CGFloat = 16

    /// Corner radius for subtle overlays
    static let overlayCornerRadius: CGFloat = 12

    /// Corner radius for content areas
    static let contentBackgroundCornerRadius: CGFloat = 12
}

/// Legacy fallback for iOS 25 and earlier
enum LegacyGlass {
    /// Material for navigation bars and toolbars (iOS 25 fallback)
    static var bar: Material {
        .ultraThinMaterial
    }

    /// Material for floating panels, sheets, and cards (iOS 25 fallback)
    static var panel: Material {
        .thinMaterial
    }

    /// Material for subtle overlays and backgrounds (iOS 25 fallback)
    static var overlay: Material {
        .ultraThinMaterial
    }

    /// Material for grouped content areas (iOS 25 fallback)
    static var contentBackground: Material {
        .regularMaterial
    }

    /// Opaque fallback when Reduce Transparency is enabled
    static var solid: Color {
        Color(.secondarySystemBackground)
    }
}

// MARK: - View Modifiers (iOS 26+)

/// Applies native Liquid Glass panel effect with automatic accessibility fallback
@available(iOS 26.0, *)
struct GlassPanel: ViewModifier {
    func body(content: Content) -> some View {
        // iOS 26 .glassEffect() automatically handles reduce transparency
        content.glassEffect(in: .rect(cornerRadius: Glass.panelCornerRadius))
    }
}

/// Applies native Liquid Glass content background
@available(iOS 26.0, *)
struct GlassContentBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.glassEffect(in: .rect(cornerRadius: Glass.contentBackgroundCornerRadius))
    }
}

/// Adds a subtle Liquid Glass overlay effect
@available(iOS 26.0, *)
struct GlassOverlay: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .glassEffect(in: .rect(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}

// MARK: - Legacy View Modifiers (iOS 25 fallback)

/// Legacy Liquid Glass panel styling for iOS 25 (Material-based)
struct LegacyGlassPanel: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(LegacyGlass.solid)
        } else {
            content.background(LegacyGlass.panel)
        }
    }
}

/// Legacy Liquid Glass content background for iOS 25
struct LegacyGlassContentBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(.tertiarySystemBackground))
        } else {
            content.background(LegacyGlass.contentBackground)
        }
    }
}

/// Legacy Liquid Glass overlay for iOS 25
struct LegacyGlassOverlay: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(LegacyGlass.solid)
                .cornerRadius(cornerRadius)
        } else {
            content
                .background(LegacyGlass.overlay)
                .cornerRadius(cornerRadius)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply Liquid Glass panel material
    /// Uses native iOS 26 API with automatic accessibility fallback
    @ViewBuilder
    func glassPanel() -> some View {
        if #available(iOS 26.0, *) {
            modifier(GlassPanel())
        } else {
            modifier(LegacyGlassPanel())
        }
    }

    /// Apply Liquid Glass content background
    @ViewBuilder
    func glassContentBackground() -> some View {
        if #available(iOS 26.0, *) {
            modifier(GlassContentBackground())
        } else {
            modifier(LegacyGlassContentBackground())
        }
    }

    /// Apply Liquid Glass overlay with rounded corners
    @ViewBuilder
    func glassOverlay(cornerRadius: CGFloat = 12) -> some View {
        if #available(iOS 26.0, *) {
            modifier(GlassOverlay(cornerRadius: cornerRadius))
        } else {
            modifier(LegacyGlassOverlay(cornerRadius: cornerRadius))
        }
    }

    /// Apply a floating card style with Liquid Glass
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            self
                .padding()
                .glassEffect(in: .rect(cornerRadius: cornerRadius))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        } else {
            self
                .padding()
                .modifier(LegacyGlassPanel())
                .cornerRadius(cornerRadius)
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        }
    }

    /// Apply glass effect to interactive buttons (iOS 26+)
    @available(iOS 26.0, *)
    func glassButton() -> some View {
        self.glassEffect(in: .capsule)
    }

    /// Apply glass effect with custom corner radius (iOS 26+)
    @available(iOS 26.0, *)
    func glassEffectWithRadius(_ cornerRadius: CGFloat = 16) -> some View {
        self.glassEffect(in: .rect(cornerRadius: cornerRadius))
    }
}

// MARK: - Colors

extension Color {
    /// Primary text color (adaptive)
    static var primaryText: Color {
        Color(.label)
    }

    /// Secondary text color (adaptive)
    static var secondaryText: Color {
        Color(.secondaryLabel)
    }

    /// Tertiary text color (adaptive)
    static var tertiaryText: Color {
        Color(.tertiaryLabel)
    }

    // MARK: - Genie Theme Colors ✨

    /// Cosmic Purple - Primary brand color
    static var cosmicPurple: Color {
        Color(hex: "6B46C1")
    }

    /// Magic Gold - Accents and achievements
    static var magicGold: Color {
        Color(hex: "F59E0B")
    }

    /// Mystic Blue - Information and progress
    static var mysticBlue: Color {
        Color(hex: "3B82F6")
    }

    /// Genie Green - Success states
    static var genieGreen: Color {
        Color(hex: "10B981")
    }

    /// Enchanted Pink - Special highlights
    static var enchantedPink: Color {
        Color(hex: "EC4899")
    }

    /// Dark Magic - Dark mode background
    static var darkMagic: Color {
        Color(hex: "0F172A")
    }

    /// Light Magic - Light mode background
    static var lightMagic: Color {
        Color(hex: "F8FAFC")
    }

    // MARK: - Gradients

    /// Main magic gradient (Purple → Blue)
    static var magicGradient: LinearGradient {
        LinearGradient(
            colors: [.cosmicPurple, .mysticBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Gold shimmer gradient
    static var goldShimmer: LinearGradient {
        LinearGradient(
            colors: [.magicGold, .yellow.opacity(0.8), .magicGold],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Success gradient (Green → Blue)
    static var successGradient: LinearGradient {
        LinearGradient(
            colors: [.genieGreen, .mysticBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Celebration gradient (Pink → Gold)
    static var celebrationGradient: LinearGradient {
        LinearGradient(
            colors: [.enchantedPink, .magicGold],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Semantic Colors

    /// AI feature accent color (sparkles, magic)
    static var aiAccent: Color {
        cosmicPurple
    }

    /// Success/positive color
    static var success: Color {
        genieGreen
    }

    /// Warning color
    static var warning: Color {
        magicGold
    }

    /// Error/destructive color
    static var destructive: Color {
        Color.red
    }

    // MARK: - Hex Color Helper

    /// Initialize a Color from a hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: // RGB (24-bit)
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // RGBA (32-bit)
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography (Dynamic Type Support)

extension Font {
    /// Large title for main headers (supports Dynamic Type)
    static var journalTitle: Font {
        .system(.largeTitle, design: .default, weight: .bold)
    }

    /// Entry title or first line (supports Dynamic Type)
    static var entryTitle: Font {
        .system(.title2, design: .default, weight: .semibold)
    }

    /// Body text for journal entries (supports Dynamic Type)
    static var journalBody: Font {
        .system(.body, design: .default)
    }

    /// Preview/summary text (supports Dynamic Type)
    static var preview: Font {
        .system(.callout, design: .default)
    }

    /// Small metadata (dates, tags) (supports Dynamic Type)
    static var metadata: Font {
        .system(.caption, design: .default)
    }

    /// Button labels (supports Dynamic Type)
    static var button: Font {
        .system(.body, design: .default, weight: .semibold)
    }

    /// Headline text (supports Dynamic Type)
    static var headline: Font {
        .system(.headline, design: .default)
    }

    /// Subheadline text (supports Dynamic Type)
    static var subheadline: Font {
        .system(.subheadline, design: .default)
    }

    /// Small caption text (supports Dynamic Type)
    static var smallCaption: Font {
        .system(.caption2, design: .default)
    }
}

// MARK: - Spacing

enum Spacing {
    /// Extra small spacing (4pt)
    static let xs: CGFloat = 4

    /// Small spacing (8pt)
    static let sm: CGFloat = 8

    /// Medium spacing (16pt)
    static let md: CGFloat = 16

    /// Large spacing (24pt)
    static let lg: CGFloat = 24

    /// Extra large spacing (32pt)
    static let xl: CGFloat = 32

    /// Extra extra large spacing (48pt)
    static let xxl: CGFloat = 48
}

// MARK: - Accessibility

enum Accessibility {
    /// Minimum hit target size (44pt per Apple HIG)
    static let minHitTarget: CGFloat = 44

    /// Recommended hit target size for comfortable interaction (48pt)
    static let recommendedHitTarget: CGFloat = 48

    /// Scale range for complex layouts with Dynamic Type
    static let scaleRange: ClosedRange<CGFloat> = 0.8...2.0

    /// Minimum contrast ratio for WCAG AA compliance
    static let minContrast: Double = 4.5

    /// Minimum contrast ratio for WCAG AAA compliance
    static let minContrastAAA: Double = 7.0
}

// MARK: - Accessible Colors (WCAG AA Compliant)

extension Color {
    /// Text color with guaranteed contrast on glass backgrounds
    static var accessiblePrimary: Color {
        Color(.label) // System adaptive, always accessible
    }

    /// Secondary text with minimum 4.5:1 contrast
    static var accessibleSecondary: Color {
        Color(.secondaryLabel) // System adaptive
    }

    /// Accessible accent blue (WCAG AA compliant)
    static var accessibleBlue: Color {
        Color(hex: "0A84FF") // iOS system blue
    }

    /// Accessible green for success states
    static var accessibleGreen: Color {
        Color(hex: "32D74B") // iOS system green
    }

    /// Accessible red for error states
    static var accessibleRed: Color {
        Color(hex: "FF453A") // iOS system red
    }

    /// Accessible orange for warnings
    static var accessibleOrange: Color {
        Color(hex: "FF9F0A") // iOS system orange
    }

    /// Glass background with proper opacity for light mode
    static var glassBackgroundLight: Color {
        Color(white: 1.0, opacity: 0.15)
    }

    /// Glass background with proper opacity for dark mode
    static var glassBackgroundDark: Color {
        Color(white: 0.0, opacity: 0.25)
    }
}

// MARK: - @ScaledMetric Support

/// Wrapper for creating scaled metrics that respect Dynamic Type
struct ScaledSpacing {
    @ScaledMetric private var value: CGFloat

    init(_ baseValue: CGFloat, relativeTo textStyle: Font.TextStyle = .body) {
        _value = ScaledMetric(wrappedValue: baseValue, relativeTo: textStyle)
    }

    var wrappedValue: CGFloat {
        value
    }
}

// MARK: - Corner Radius

enum CornerRadius {
    /// Small corners (8pt)
    static let sm: CGFloat = 8

    /// Medium corners (12pt)
    static let md: CGFloat = 12

    /// Large corners (16pt)
    static let lg: CGFloat = 16

    /// Extra large corners (20pt)
    static let xl: CGFloat = 20

    /// Circular (999pt)
    static let circular: CGFloat = 999
}

// MARK: - Animation

extension Animation {
    /// Fluid spring animation for Liquid Glass interactions
    static var glass: Animation {
        .spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0.5)
    }

    /// Quick spring for subtle transitions
    static var glassQuick: Animation {
        .spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.3)
    }

    /// Smooth ease for content morphing
    static var morph: Animation {
        .easeInOut(duration: 0.4)
    }
}

// MARK: - Accessibility View Modifiers

extension View {
    /// Ensures minimum hit target size for accessibility
    func minHitTarget() -> some View {
        self.frame(minWidth: Accessibility.minHitTarget, minHeight: Accessibility.minHitTarget)
    }

    /// Applies recommended hit target size
    func recommendedHitTarget() -> some View {
        self.frame(minWidth: Accessibility.recommendedHitTarget, minHeight: Accessibility.recommendedHitTarget)
    }

    /// Makes the view accessible with proper label and hint
    func accessible(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }

    /// Respects Reduce Motion preference
    func respectReduceMotion<T: Equatable>(value: T, animation: Animation) -> some View {
        self.modifier(ReduceMotionModifier(value: value, animation: animation))
    }
}

/// Modifier that respects Reduce Motion accessibility setting
struct ReduceMotionModifier<T: Equatable>: ViewModifier {
    let value: T
    let animation: Animation

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .animation(animation, value: value)
        }
    }
}

// MARK: - Accessibility Helpers

/// Check if a color has sufficient contrast against a background
func hasAccessibleContrast(foreground: UIColor, background: UIColor) -> Bool {
    let fgLuminance = luminance(of: foreground)
    let bgLuminance = luminance(of: background)

    let lighter = max(fgLuminance, bgLuminance)
    let darker = min(fgLuminance, bgLuminance)

    let contrast = (lighter + 0.05) / (darker + 0.05)
    return contrast >= Accessibility.minContrast
}

/// Calculate relative luminance of a color
private func luminance(of color: UIColor) -> CGFloat {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0

    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

    func adjust(_ component: CGFloat) -> CGFloat {
        if component <= 0.03928 {
            return component / 12.92
        } else {
            return pow((component + 0.055) / 1.055, 2.4)
        }
    }

    let r = adjust(red)
    let g = adjust(green)
    let b = adjust(blue)

    return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

// MARK: - Preview
#Preview("Liquid Glass Materials") {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            Text("Liquid Glass Design System")
                .font(.journalTitle)
                .padding()

            // Panel example
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Panel Material", systemImage: "rectangle.fill")
                    .font(.entryTitle)
                Text("This is a Liquid Glass panel with translucent blur.")
                    .font(.preview)
                    .foregroundStyle(Color.secondaryText)
            }
            .glassCard()
            .padding(.horizontal)

            // Content background example
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Content Background", systemImage: "doc.text.fill")
                    .font(.entryTitle)
                Text("Suitable for text content areas with better contrast.")
                    .font(.preview)
                    .foregroundStyle(Color.secondaryText)
            }
            .padding()
            .glassContentBackground()
            .cornerRadius(CornerRadius.lg)
            .padding(.horizontal)

            // Overlay example
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)

                VStack {
                    Text("Overlay Material")
                        .font(.entryTitle)
                    Text("Floats over colorful backgrounds")
                        .font(.preview)
                }
                .padding()
                .glassOverlay(cornerRadius: CornerRadius.lg)
            }
            .cornerRadius(CornerRadius.lg)
            .padding(.horizontal)

            // Color palette
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Color Palette")
                    .font(.entryTitle)

                HStack(spacing: Spacing.sm) {
                    ColorSwatch(color: .aiAccent, name: "AI")
                    ColorSwatch(color: .success, name: "Success")
                    ColorSwatch(color: .warning, name: "Warning")
                    ColorSwatch(color: .destructive, name: "Error")
                }
            }
            .glassCard()
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    .background(
        LinearGradient(
            colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}

private struct ColorSwatch: View {
    let color: Color
    let name: String

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 50, height: 50)
            Text(name)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
        }
    }
}

// MARK: - Design Guidelines
/*
 Liquid Glass Design Principles (iOS 26):

 1. **Translucency with Purpose**
    - Use glass materials for chrome (nav bars, toolbars)
    - Apply to floating panels and overlays
    - Keep dense text areas on solid backgrounds
    - Always provide accessibility fallbacks

 2. **Content First**
    - UI should recede when user is focused
    - Expand controls contextually when needed
    - Minimize chrome while reading/writing
    - Use fluid animations to morph UI states

 3. **Depth and Layering**
    - Create visual hierarchy with material weights
    - Use shadows sparingly (already have translucency)
    - Layer translucent surfaces for depth
    - Maintain clear relationships between elements

 4. **Readability**
    - Ensure sufficient contrast for all text
    - Test with Reduce Transparency enabled
    - Use Dynamic Type for accessibility
    - Balance aesthetics with legibility

 5. **Fluid Motion**
    - Animate transitions smoothly
    - Use spring animations for natural feel
    - Morph UI elements contextually
    - Respond to user gestures with life

 6. **Accessibility First**
    - Always provide solid fallbacks
    - Support Reduce Motion
    - Support Reduce Transparency
    - Test with VoiceOver
    - Ensure high contrast modes work

 Resources:
 - Apple HIG: Liquid Glass Design Language
 - WWDC 2025: "Design with Liquid Glass"
 - iOS 26 Design Resources: https://developer.apple.com/design/
 */
