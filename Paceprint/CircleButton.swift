import SwiftUI

/// A round glass button over a map or photo, e.g. Close on Summary.
struct CircleButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleIcon(systemImage: systemImage)
        }
        .accessibilityLabel(label)
    }
}

/// The look of a CircleButton, for a NavigationLink to wear.
struct CircleIcon: View {
    let systemImage: String
    /// The circle's width; the icon scales with it.
    var diameter: CGFloat = 36
    var iconColor = Theme.Colors.textPrimary

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: diameter * 14 / 36, weight: .bold))
            .foregroundStyle(iconColor)
            .frame(width: diameter, height: diameter)
            .background(Theme.Colors.glass, in: Circle())
            .overlay(Circle().stroke(Theme.Colors.glassBorder))
    }
}
