import PaceprintCore
import SwiftUI

/// The colors a Route's Pace colors are drawn in: a fast, a middle (the Average pace) and a slow
/// color, blended in between. The runner picks one of the four in Settings.
enum RoutePalette: String, CaseIterable {
    case pace, electric, ember, mono

    /// The palette chosen in Settings, else the pace palette.
    static var selected: RoutePalette {
        UserDefaults.standard.string(forKey: SettingsKey.routePalette).flatMap(RoutePalette.init) ?? .pace
    }

    private var colors: (fast: UInt32, middle: UInt32, slow: UInt32) {
        switch self {
        case .pace: (0x4AE27A, 0xFFE055, 0xFF4D4D)
        case .electric: (0x00F0FF, 0xA78BFA, 0xFF3DA5)
        case .ember: (0xFFD66B, 0xFF8A3D, 0xE0345B)
        case .mono: (0xFFFFFF, 0xB8B8B8, 0x5A5A5A)
        }
    }

    /// As Settings lists it, e.g. "Electric".
    var name: String {
        rawValue.capitalized
    }

    /// Fast, middle and slow, for a swatch.
    var swatch: [Color] {
        [PaceColor(position: 0), .average, PaceColor(position: 1)].map(color)
    }

    /// `paceColor` in this palette: fast to middle over its first half, middle to slow over its second.
    func color(for paceColor: PaceColor) -> Color {
        let position = paceColor.position
        return position < 0.5
            ? Self.blend(colors.fast, colors.middle, by: position * 2)
            : Self.blend(colors.middle, colors.slow, by: (position - 0.5) * 2)
    }

    /// Blends two sRGB colors channel by channel, as the design does.
    private static func blend(_ from: UInt32, _ to: UInt32, by fraction: Double) -> Color {
        func channel(_ hex: UInt32, _ shift: UInt32) -> Double { Double((hex >> shift) & 0xFF) / 255 }
        func mix(_ shift: UInt32) -> Double { channel(from, shift) + (channel(to, shift) - channel(from, shift)) * fraction }
        return Color(.sRGB, red: mix(16), green: mix(8), blue: mix(0))
    }
}
