//
//  Modifiers.swift
//  CardGenie
//
//  View modifiers for common UI patterns.
//

import SwiftUI

// MARK: - Error Alert

/// Alert for displaying errors
struct ErrorAlert: ViewModifier {
    @Binding var error: Error?

    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: .constant(error != nil), presenting: error) { _ in
                Button("OK") {
                    error = nil
                }
            } message: { error in
                Text(error.localizedDescription)
            }
    }
}

extension View {
    func errorAlert(_ error: Binding<Error?>) -> some View {
        modifier(ErrorAlert(error: error))
    }
}
