import PaceprintCore
import SwiftUI

/// NONE · CHROMA · NOIR · DUSK · FILM along the bottom of Summary; the chosen one is a white pill.
struct FilterStrip: View {
    @Binding var selection: PhotoFilter

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PhotoFilter.allCases, id: \.self) { filter in
                pill(filter)
            }
        }
    }

    private func pill(_ filter: PhotoFilter) -> some View {
        let isSelected = filter == selection
        return Button {
            selection = filter
        } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(colors: filter.swatch, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 22, height: 22)
                Text(filter.label)
                    .font(Theme.Typography.label)
                    .tracking(Theme.Typography.labelTracking * 0.9)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(isSelected ? Theme.Colors.textOnLight : Color.white.opacity(0.85))
            }
            .padding(.top, 8)
            .padding(.bottom, 6)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.white.opacity(0.95) : Theme.Colors.glass, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.white.opacity(0.95) : Color.white.opacity(0.15), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filter == .none ? "No filter" : "\(filter.label.capitalized) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension PhotoFilter {
    var label: String {
        rawValue.uppercased()
    }

    /// The design's little square for each filter.
    var swatch: [Color] {
        switch self {
        case .none: [Color(hex: 0xF5B97D), Color(hex: 0x6B3D6B)]
        case .chroma: [Color(hex: 0xFF8A3D), Color(hex: 0xE0345B)]
        case .noir: [Color(hex: 0x888888), Color(hex: 0x222222)]
        case .dusk: [Color(hex: 0xD56B6B), Color(hex: 0x2A2547)]
        case .film: [Color(hex: 0xC9B890), Color(hex: 0x5A4030)]
        }
    }
}
