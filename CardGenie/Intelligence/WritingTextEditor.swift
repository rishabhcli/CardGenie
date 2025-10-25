//
//  WritingTextEditor.swift
//  CardGenie
//
//  SwiftUI wrapper for UITextView with Apple Intelligence Writing Tools enabled.
//  Provides on-device proofreading, rewriting, and summarization via context menu.
//

import SwiftUI
import UIKit

/// A text editor that bridges UIKit's UITextView to SwiftUI and enables
/// Apple Intelligence Writing Tools for on-device text assistance.
///
/// On iOS 26+ devices with Apple Intelligence:
/// - Users can select text and see "Proofread", "Rewrite", "Summarize" options
/// - All processing happens on-device via the Neural Engine
/// - No network connection required
struct WritingTextEditor: UIViewRepresentable {
    /// Binding to the text content
    @Binding var text: String

    /// Optional callback when text changes
    var onTextChange: ((String) -> Void)?

    /// Whether the text view is editable
    var isEditable: Bool = true

    /// Font for the text (defaults to system body font)
    var font: UIFont = .preferredFont(forTextStyle: .body)

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        // Basic configuration
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        // Accessibility & Dynamic Type
        textView.adjustsFontForContentSizeCategory = true
        textView.font = font

        // Keyboard
        textView.keyboardDismissMode = .interactive
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .yes

        // Enable Apple Intelligence Writing Tools (iOS 26+)
        if #available(iOS 26.0, *) {
            // Enable Apple Intelligence Writing Tools using KVC so the project still compiles on pre-iOS 26 SDKs.
            if textView.responds(to: Selector(("setWritingToolsEnabled:"))) {
                textView.setValue(true, forKey: "writingToolsEnabled")
            }
        }

        // Set initial text
        textView.text = text

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Update text if it changed externally
        if textView.text != text {
            textView.text = text
        }

        // Update editability
        textView.isEditable = isEditable

        // Update font
        textView.font = font
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: WritingTextEditor

        init(_ parent: WritingTextEditor) {
            self.parent = parent
        }

        /// Called whenever the text changes
        func textViewDidChange(_ textView: UITextView) {
            // Update the binding
            parent.text = textView.text

            // Call the optional callback
            parent.onTextChange?(textView.text)
        }

        /// Called when Writing Tools makes changes
        /// (This delegate method is available on iOS 26+)
        // TODO: Uncomment when building with iOS 26 SDK
        // @available(iOS 26.0, *)
        // func textView(_ textView: UITextView, writingToolsDidFinish result: UITextView.WritingToolsResult) {
        //     // Writing Tools completed an operation (e.g., rewrite, proofread)
        //     // The text has already been updated, so we just sync it
        //     parent.text = textView.text
        //     parent.onTextChange?(textView.text)
        //
        //     // Optional: Track analytics or show a toast
        //     print("Writing Tools completed: \(result.action)")
        // }
    }
}

// MARK: - SwiftUI Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var text = "This is a sample journal entry. It contains some text that can be edited and enhanced using Apple Intelligence Writing Tools. Try selecting text to see the available options."

        var body: some View {
            VStack {
                Text("Journal Editor with Writing Tools")
                    .font(.headline)
                    .padding()

                WritingTextEditor(
                    text: $text,
                    onTextChange: { newText in
                        print("Text changed: \(newText.count) characters")
                    }
                )
                .frame(height: 400)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding()

                Text("\(text.count) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    return PreviewWrapper()
}

// MARK: - Implementation Notes
/*
 Apple Intelligence Writing Tools (iOS 26+)

 When enabled on a UITextView, Writing Tools provide:

 1. **Proofread**: Checks grammar, spelling, and punctuation
    - Shows inline suggestions
    - Can accept/reject changes
    - Runs entirely on-device

 2. **Rewrite**: Offers alternative phrasings
    - Different tones (professional, friendly, concise)
    - Preserves meaning while improving clarity
    - Multiple suggestions to choose from

 3. **Summarize**: Condenses selected text
    - Extracts key points
    - Maintains first-person perspective
    - Useful for long entries

 4. **Transform**: Advanced text transformations
    - Change tone or style
    - Expand or condense
    - Adjust formality level

 How it works:
 - Set `textView.isWritingToolsEnabled = true`
 - User selects text
 - Context menu shows AI options
 - User taps an option (e.g., "Rewrite")
 - System shows suggestions in real-time
 - User accepts or dismisses
 - Text is updated automatically

 Requirements:
 - iOS 26 or later
 - Apple Intelligence-capable device (iPhone 15 Pro+)
 - Apple Intelligence enabled in Settings

 Privacy:
 - All processing happens on-device
 - No data sent to servers
 - Works completely offline
 - User's text never leaves the device

 Customization:
 You can customize the behavior with `writingToolsBehavior`:

 ```swift
 textView.writingToolsBehavior = .automatic  // Full features (default)
 textView.writingToolsBehavior = .limited    // Only basic corrections
 textView.writingToolsBehavior = .none       // Disable all AI features
 ```

 Testing:
 - Run on a physical device with iOS 26 and Apple Intelligence
 - Select text in the editor
 - Long-press or tap the context menu
 - Verify "Proofread", "Rewrite", etc. appear
 - Confirm changes are applied correctly

 For more information:
 - WWDC 2025: "Integrate Writing Tools in your app"
 - Documentation: https://developer.apple.com/documentation/uikit/uitextview/writing-tools
 - Human Interface Guidelines: Writing Tools design patterns
 */
