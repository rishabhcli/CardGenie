//
//  GlassSearchBar.swift
//  CardGenie
//
//  Reusable Liquid Glass-styled search field.
//

import SwiftUI

struct GlassSearchBar: View {
    @Binding var text: String
    var placeholder: String
    var onSubmit: (() -> Void)? = nil

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.secondaryText)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.none)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .foregroundStyle(Color.primaryText)
                .onSubmit {
                    onSubmit?()
                }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.secondaryText.opacity(0.8))
                        .accessibilityLabel("Clear search")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .glassPanel()
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .stroke(Color.white.opacity(reduceTransparency ? 0.05 : 0.25), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(reduceTransparency ? 0.05 : 0.18),
            radius: reduceTransparency ? 6 : 18,
            y: reduceTransparency ? 2 : 10
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("Use the field to search your content")
    }
}

#Preview("Glass Search Bar") {
    ZStack {
        LinearGradient(
            colors: [.cosmicPurple.opacity(0.6), .mysticBlue.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        GlassSearchBar(
            text: .constant("Study tips"),
            placeholder: "Search study materials..."
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
