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
enum Glass {
    /// Material for navigation bars and toolbars
    /// - Provides the signature Liquid Glass translucency
    /// - Automatically adapts to light/dark mode
    /// - Refracts and blurs content underneath
    static var bar: Material {
        .ultraThinMaterial
    }

    /// Material for floating panels, sheets, and cards
    /// - Slightly more opaque than bar material
    /// - Good for content containers
    /// - Maintains readability while showing depth
    static var panel: Material {
        .thinMaterial
    }

    /// Material for subtle overlays and backgrounds
    /// - Most translucent option
    /// - Use sparingly for non-critical UI
    /// - Best for temporary overlays
    static var overlay: Material {
        .ultraThinMaterial
    }

    /// Material for grouped content areas
    /// - More substantial than panel
    /// - Good for content that needs more separation
    /// - Better contrast for text
    static var contentBackground: Material {
        .regularMaterial
    }

    /// Opaque fallback when Reduce Transparency is enabled
    /// - Respects user accessibility preferences
    /// - Maintains visual hierarchy without translucency
    /// - Provides full contrast
    static var solid: Color {
        Color(.secondarySystemBackground)
    }

    /// Subtle tint for surfaces
    static var surfaceTint: Color {
        Color(.systemBackground).opacity(0.8)
    }
}

// MARK: - View Modifiers

/// Applies Liquid Glass panel styling with accessibility fallback
struct GlassPanel: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            // Solid background for users who need reduced transparency
            content
                .background(Glass.solid)
        } else {
            // Translucent Liquid Glass effect
            content
                .background(Glass.panel)
        }
    }
}

/// Applies Liquid Glass content background with accessibility fallback
struct GlassContentBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color(.tertiarySystemBackground))
        } else {
            content
                .background(Glass.contentBackground)
        }
    }
}

/// Adds a subtle Liquid Glass overlay effect
struct GlassOverlay: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Glass.solid)
                .cornerRadius(cornerRadius)
        } else {
            content
                .background(Glass.overlay)
                .cornerRadius(cornerRadius)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply Liquid Glass panel material
    /// Automatically falls back to solid for accessibility
    func glassPanel() -> some View {
        modifier(GlassPanel())
    }

    /// Apply Liquid Glass content background
    func glassContentBackground() -> some View {
        modifier(GlassContentBackground())
    }

    /// Apply Liquid Glass overlay with rounded corners
    func glassOverlay(cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassOverlay(cornerRadius: cornerRadius))
    }

    /// Apply a floating card style with Liquid Glass
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .padding()
            .glassPanel()
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
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

    /// AI feature accent color (sparkles, magic)
    static var aiAccent: Color {
        Color.blue
    }

    /// Success/positive color
    static var success: Color {
        Color.green
    }

    /// Warning color
    static var warning: Color {
        Color.orange
    }

    /// Error/destructive color
    static var destructive: Color {
        Color.red
    }
}

// MARK: - Typography

extension Font {
    /// Large title for main headers
    static var journalTitle: Font {
        .system(size: 34, weight: .bold, design: .default)
    }

    /// Entry title or first line
    static var entryTitle: Font {
        .system(size: 20, weight: .semibold, design: .default)
    }

    /// Body text for journal entries
    static var journalBody: Font {
        .system(size: 17, weight: .regular, design: .default)
    }

    /// Preview/summary text
    static var preview: Font {
        .system(size: 15, weight: .regular, design: .default)
    }

    /// Small metadata (dates, tags)
    static var metadata: Font {
        .system(size: 13, weight: .regular, design: .default)
    }

    /// Button labels
    static var button: Font {
        .system(size: 17, weight: .semibold, design: .default)
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
