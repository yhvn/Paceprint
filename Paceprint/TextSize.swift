import SwiftUI

extension View {
    /// On photo screens (Home, Active run, Summary, the top of Run detail), text scales up to XXXL and no
    /// further, so it stays clear of what's behind it (#15). Plain screens take every size.
    func photoScreenTextSize() -> some View {
        dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

extension AnyLayout {
    /// Side by side, or stacked at accessibility text sizes, where side by side wouldn't fit.
    static func across(_ size: DynamicTypeSize, spacing: CGFloat, alignment: VerticalAlignment = .center, stackedAlignment: HorizontalAlignment = .leading, stackedSpacing: CGFloat? = nil) -> AnyLayout {
        size.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: stackedAlignment, spacing: stackedSpacing ?? spacing))
            : AnyLayout(HStackLayout(alignment: alignment, spacing: spacing))
    }
}
