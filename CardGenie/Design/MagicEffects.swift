//
//  MagicEffects.swift
//  CardGenie
//
//  Magical visual effects for the Genie theme.
//  Includes particle effects, shimmer animations, and haptic feedback.
//

import SwiftUI

// MARK: - Sparkle Particle Effect

struct SparkleEffect: ViewModifier {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let particleCount: Int
    let colors: [Color]

    init(particleCount: Int = 20, colors: [Color] = [.magicGold, .cosmicPurple, .mysticBlue]) {
        self.particleCount = particleCount
        self.colors = colors
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            // Skip animation for accessibility
            content
        } else {
            content
                .overlay(
                    GeometryReader { geometry in
                        ForEach(0..<particleCount, id: \.self) { i in
                            Circle()
                                .fill(colors.randomElement() ?? .magicGold)
                                .frame(width: CGFloat.random(in: 2...6), height: CGFloat.random(in: 2...6))
                                .opacity(isAnimating ? 0 : 0.8)
                                .position(
                                    x: CGFloat.random(in: 0...geometry.size.width),
                                    y: isAnimating ? -20 : geometry.size.height + 20
                                )
                                .animation(
                                    .linear(duration: Double.random(in: 1.5...3.0))
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.05),
                                    value: isAnimating
                                )
                        }
                    }
                )
                .onAppear {
                    isAnimating = true
                }
        }
    }
}

extension View {
    /// Add sparkle particle effect
    func sparkles(count: Int = 20, colors: [Color] = [.magicGold, .cosmicPurple, .mysticBlue]) -> some View {
        modifier(SparkleEffect(particleCount: count, colors: colors))
    }
}

// MARK: - Shimmer Loading Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
                .opacity(0.6)
        } else {
            content
                .overlay(
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.5),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
                    .mask(content)
                )
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 400
                    }
                }
        }
    }
}

extension View {
    /// Add shimmer loading effect
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Pulse Effect

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let color: Color
    let duration: Double

    init(color: Color = .cosmicPurple, duration: Double = 1.5) {
        self.color = color
        self.duration = duration
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.5), lineWidth: 2)
                        .scaleEffect(isPulsing ? 1.5 : 1.0)
                        .opacity(isPulsing ? 0 : 1)
                )
                .onAppear {
                    withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
                        isPulsing = true
                    }
                }
        }
    }
}

extension View {
    /// Add pulse effect
    func pulse(color: Color = .cosmicPurple, duration: Double = 1.5) -> some View {
        modifier(PulseEffect(color: color, duration: duration))
    }
}

// MARK: - Floating Animation

struct FloatingEffect: ViewModifier {
    @State private var isFloating = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let distance: CGFloat
    let duration: Double

    init(distance: CGFloat = 10, duration: Double = 2.0) {
        self.distance = distance
        self.duration = duration
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .offset(y: isFloating ? -distance : distance)
                .onAppear {
                    withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                        isFloating = true
                    }
                }
        }
    }
}

extension View {
    /// Add floating animation
    func floating(distance: CGFloat = 10, duration: Double = 2.0) -> some View {
        modifier(FloatingEffect(distance: distance, duration: duration))
    }
}

// MARK: - Magic Button Style

struct MagicButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let gradient: LinearGradient
    let shadowColor: Color

    init(gradient: LinearGradient = Color.magicGradient, shadowColor: Color = .cosmicPurple) {
        self.gradient = gradient
        self.shadowColor = shadowColor
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .fill(gradient)
                    .glassEffect(.regular, in: .rect(cornerRadius: CornerRadius.lg))
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Glow Effect

struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat

    init(color: Color = .cosmicPurple, radius: CGFloat = 10) {
        self.color = color
        self.radius = radius
    }

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.5), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: radius * 2, x: 0, y: 0)
    }
}

extension View {
    /// Add glow effect
    func glow(color: Color = .cosmicPurple, radius: CGFloat = 10) -> some View {
        modifier(GlowEffect(color: color, radius: radius))
    }
}

// MARK: - Confetti Effect

struct ConfettiShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addRect(rect)
        }
    }
}

struct ConfettiPiece: View {
    let color: Color
    @State private var isAnimating = false

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 8, height: 8)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

struct ConfettiEffect: ViewModifier {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let particleCount: Int = 30

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay(
                    GeometryReader { geometry in
                        ForEach(0..<particleCount, id: \.self) { i in
                            let colors: [Color] = [.magicGold, .cosmicPurple, .mysticBlue, .enchantedPink, .genieGreen]
                            ConfettiPiece(color: colors.randomElement() ?? .magicGold)
                                .opacity(isAnimating ? 0 : 1)
                                .position(
                                    x: CGFloat.random(in: 0...geometry.size.width),
                                    y: isAnimating ? geometry.size.height + 20 : -20
                                )
                                .animation(
                                    .easeIn(duration: Double.random(in: 1.0...2.0))
                                    .delay(Double(i) * 0.02),
                                    value: isAnimating
                                )
                        }
                    }
                )
                .onAppear {
                    isAnimating = true
                }
        }
    }
}

extension View {
    /// Add confetti celebration effect
    func confetti() -> some View {
        modifier(ConfettiEffect())
    }
}

// MARK: - Haptic Feedback

struct HapticFeedback {
    /// Light impact (button tap)
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium impact (toggle)
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Heavy impact (important action)
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Success notification
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Warning notification
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Error notification
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    /// Selection changed (picker)
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// MARK: - Button with Haptics

struct HapticButton<Label: View>: View {
    let action: () -> Void
    let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle
    @ViewBuilder let label: () -> Label

    init(
        hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.hapticStyle = hapticStyle
        self.action = action
        self.label = label
    }

    var body: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: hapticStyle)
            generator.impactOccurred()
            action()
        } label: {
            label()
        }
    }
}

// MARK: - Preview

#Preview("Magic Effects") {
    ScrollView {
        VStack(spacing: Spacing.xl) {
            Text("CardGenie Magic Effects ✨")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(Color.magicGradient)

            // Sparkles
            VStack {
                Text("Sparkle Effect")
                    .font(.headline)
                Rectangle()
                    .fill(Color.cosmicPurple.opacity(0.2))
                    .frame(height: 100)
                    .cornerRadius(CornerRadius.lg)
                    .sparkles()
            }
            .padding()

            // Shimmer
            VStack {
                Text("Shimmer Effect")
                    .font(.headline)
                Text("Loading...")
                    .shimmer()
            }
            .padding()

            // Glow
            VStack {
                Text("Glow Effect")
                    .font(.headline)
                Circle()
                    .fill(Color.cosmicPurple)
                    .frame(width: 60, height: 60)
                    .glow(color: .cosmicPurple, radius: 15)
            }
            .padding()

            // Pulse
            VStack {
                Text("Pulse Effect")
                    .font(.headline)
                Circle()
                    .fill(Color.mysticBlue)
                    .frame(width: 60, height: 60)
                    .pulse(color: .mysticBlue)
            }
            .padding()

            // Floating
            VStack {
                Text("Floating Effect")
                    .font(.headline)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.magicGold)
                    .floating()
            }
            .padding()

            // Magic Button
            VStack {
                Text("Magic Button")
                    .font(.headline)
                Button("Generate Flashcards ✨") {
                    HapticFeedback.success()
                }
                .buttonStyle(MagicButtonStyle())
            }
            .padding()
        }
        .padding()
    }
}
