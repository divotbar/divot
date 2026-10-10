import SwiftUI

/// The app's shared confirmation dialog.
///
/// Every Divot control that needs a yes/no confirmation presents through this
/// one component, so wording, the destructive role, and the cancel affordance
/// stay consistent and no call site reaches for a native `alert()`. It is a
/// thin, reusable wrapper over SwiftUI's `confirmationDialog`, which is keyboard
/// accessible and — unlike a new window or `NSAlert` — presents in place.
public extension View {
    /// Present the shared confirmation dialog while `isPresented` is true.
    func divotConfirmation(isPresented: Binding<Bool>,
                           title: String,
                           message: String,
                           confirmTitle: String,
                           onConfirm: @escaping () -> Void) -> some View {
        confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
            Button(confirmTitle, role: .destructive, action: onConfirm)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}
