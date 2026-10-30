import SwiftUI

/// A round glass button over a map or photo, e.g. Close on Summary.
struct CircleButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 36, height: 36)
                .background(Theme.Colors.glass, in: Circle())
                .overlay(Circle().stroke(Theme.Colors.glassBorder))
        }
        .accessibilityLabel(label)
    }
}
