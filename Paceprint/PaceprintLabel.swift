import SwiftUI

extension EnvironmentValues {
    /// Inside the Story card, which keeps the design's look whatever the accessibility settings.
    @Entry var isStoryCard = false
}

/// The small uppercase labels: TIME, AVG PACE, dates, the Place context. At least 11 pt and 70% white,
/// scaling with Dynamic Type; 100% white with Increase Contrast (#15). On the Story card, the design's look.
private struct PaceprintLabel: ViewModifier {
    let tracking: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isStoryCard) private var isStoryCard

    func body(content: Content) -> some View {
        content
            .font(Theme.Typography.label)
            .tracking(tracking)
            .foregroundStyle(color)
    }

    private var color: Color {
        if isStoryCard { return Theme.Colors.storyCardLabel }
        return contrast == .increased ? Theme.Colors.textPrimary : Theme.Colors.textSecondary
    }
}

extension View {
    /// Styles this as one of the app's small uppercase labels.
    func paceprintLabel(tracking: CGFloat = Theme.Typography.labelTracking) -> some View {
        modifier(PaceprintLabel(tracking: tracking))
    }
}
