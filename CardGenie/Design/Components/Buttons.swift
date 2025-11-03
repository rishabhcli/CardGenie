//
//  Buttons.swift
//  CardGenie
//
//  Button components with Liquid Glass styling.
//

import SwiftUI

// MARK: - Glass Button

/// A button with Liquid Glass styling
struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isLoading: Bool = false
    var style: ButtonStyleType = .primary

    enum ButtonStyleType {
        case primary, secondary, destructive
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if let icon = icon {
                    Image(systemName: icon)
                }

                Text(title)
                    .font(.button)
            }
            .foregroundStyle(textColor)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .glassPanel()
            .cornerRadius(CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }

    private var textColor: Color {
        switch style {
        case .primary:
            return .aiAccent
        case .secondary:
            return .primaryText
        case .destructive:
            return .destructive
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:
            return .aiAccent.opacity(0.3)
        case .secondary:
            return .clear
        case .destructive:
            return .destructive.opacity(0.3)
        }
    }
}

// MARK: - Previews

#Preview("Glass Buttons") {
    VStack(spacing: Spacing.md) {
        GlassButton(title: "Summarize", icon: "sparkles", action: {}, style: .primary)

        GlassButton(title: "Loading...", icon: nil, action: {}, isLoading: true, style: .primary)

        GlassButton(title: "Cancel", icon: "xmark", action: {}, style: .secondary)

        GlassButton(title: "Delete", icon: "trash", action: {}, style: .destructive)
    }
    .padding()
}
