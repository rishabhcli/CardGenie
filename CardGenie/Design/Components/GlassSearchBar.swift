//
//  GlassSearchBar.swift
//  CardGenie
//
//  Reusable Liquid Glass-styled search field for iOS 26+.
//  Uses native glassEffect with capsule shape and interactive mode.
//

import SwiftUI

struct GlassSearchBar: View {
    @Binding var text: String
    var placeholder: String
    var onSubmit: (() -> Void)? = nil

    // Optional customization
    var showCancelButton: Bool = false
    var onCancel: (() -> Void)? = nil

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            searchField

            if showCancelButton && (isFocused || !text.isEmpty) {
                cancelButton
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: text.isEmpty)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }

    // MARK: - Subviews

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.secondaryText)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.none)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .foregroundStyle(Color.primaryText)
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }
                // Keyboard toolbar for better UX
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()

                        if !text.isEmpty {
                            Button("Clear") {
                                withAnimation {
                                    text = ""
                                }
                            }
                            .tint(.cosmicPurple)
                        }

                        Button("Done") {
                            isFocused = false
                            onSubmit?()
                        }
                        .tint(.cosmicPurple)
                        .fontWeight(.semibold)
                    }
                }

            if !text.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        text = ""
                    }
                    isFocused = true // Keep focus after clearing
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.secondaryText.opacity(0.8))
                        .accessibilityLabel("Clear search")
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, Spacing.sm + 2) // Slightly taller for better touch target
        .padding(.horizontal, Spacing.md)
        .glassSearchBar()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text.isEmpty ? "Search" : "Search, \(text)")
        .accessibilityHint("Double tap to start typing")
        .accessibilityAddTraits(.isSearchField)
    }

    private var cancelButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                text = ""
                isFocused = false
            }
            onCancel?()
        } label: {
            Text("Cancel")
                .foregroundStyle(Color.cosmicPurple)
                .fontWeight(.medium)
        }
        .buttonStyle(.plain)
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .accessibilityLabel("Cancel search")
    }
}

// MARK: - Liquid Glass Search Bar Modifier

extension View {
    /// Apply iOS 26 Liquid Glass search bar styling with capsule shape and interactive mode
    @ViewBuilder
    func glassSearchBar() -> some View {
        if #available(iOS 26.0, *) {
            modifier(GlassSearchBarModifier())
        } else {
            modifier(LegacyGlassSearchBarModifier())
        }
    }
}

/// iOS 26+ Liquid Glass search bar with interactive capsule effect
@available(iOS 26.0, *)
struct GlassSearchBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.interactive(), in: .capsule)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

/// Legacy fallback for iOS 25 and earlier
struct LegacyGlassSearchBarModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        }
    }
}

#Preview("Glass Search Bar - Empty") {
    ZStack {
        // Background gradient to showcase glass blur effect
        LinearGradient(
            colors: [.cosmicPurple.opacity(0.6), .mysticBlue.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 24) {
            // Some content behind the glass to show blur
            Text("iOS 26 Liquid Glass")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            GlassSearchBar(
                text: .constant(""),
                placeholder: "Search study materials..."
            )
            .padding(.horizontal)

            Text("Tap to see interactive shimmer effect")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Glass Search Bar - Filled") {
    ZStack {
        LinearGradient(
            colors: [.cosmicPurple.opacity(0.6), .mysticBlue.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 24) {
            Text("iOS 26 Liquid Glass")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            GlassSearchBar(
                text: .constant("Flashcards"),
                placeholder: "Search study materials..."
            )
            .padding(.horizontal)

            Text("Clear button appears when text is present")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Glass Search Bar - Interactive") {
    struct InteractivePreview: View {
        @State private var searchText = ""

        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [.cosmicPurple.opacity(0.6), .mysticBlue.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("iOS 26 Liquid Glass")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    // Basic search bar
                    GlassSearchBar(
                        text: $searchText,
                        placeholder: "Search study materials...",
                        onSubmit: {
                            print("Searching for: \(searchText)")
                        }
                    )
                    .padding(.horizontal)

                    // Search bar with cancel button
                    GlassSearchBar(
                        text: $searchText,
                        placeholder: "Search with cancel button...",
                        showCancelButton: true,
                        onCancel: {
                            print("Search cancelled")
                        }
                    )
                    .padding(.horizontal)

                    if !searchText.isEmpty {
                        Text("Searching for: \"\(searchText)\"")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.top, 40)
            }
            .preferredColorScheme(.dark)
        }
    }

    return InteractivePreview()
}
