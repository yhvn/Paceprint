//
//  Theme.swift
//  Paceprint
//
//  Color and type tokens from the design's palette spec (docs/design/Paceline.html).
//  Paceprint is dark-only.
//

import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Theme {
    enum Colors {
        // Primary
        static let liveRed = Color(hex: 0xFF4D4D)
        static let actionWhite = Color.white
        static let pauseAmber = Color(hex: 0xFFD66B)

        // Background
        static let inkBlack = Color(hex: 0x08090C)
        static let mapNight = Color(hex: 0x0A0E14)
        static let mapIndigo = Color(hex: 0x11151C)
        static let photoTop = Color.black.opacity(0.55)
        static let photoMid = Color.black.opacity(0.10)
        static let photoBottom = Color(hex: 0x080A10, opacity: 0.96)

        // Text
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.65)
        static let textTertiary = Color.white.opacity(0.45)
        static let textDisabled = Color.white.opacity(0.25)
        static let textOnLight = Color(hex: 0x111111)

        // Route (default "pace" palette)
        static let paceFast = Color(hex: 0x4AE27A)
        static let paceMid = Color(hex: 0xFFE055)
        static let paceSlow = liveRed
        static let routeHalo = Color.white.opacity(0.18)

        // Surface
        static let glass = Color.black.opacity(0.45)
        static let glassBorder = Color.white.opacity(0.18)
        static let glassShadow = Color.black.opacity(0.25)
        static let sheetDark = Color(hex: 0x1A1830)
        static let sheetMid = Color(hex: 0x2A2540)
        static let divider = Color.white.opacity(0.15)

        // Semantic
        static let success = paceFast
        static let warning = pauseAmber
        static let error = liveRed
        static let info = Color(hex: 0x7DC4FF)
    }

    enum Typography {
        /// Hero numbers: heavy, tabular digits, tight tracking.
        enum MetricSize: CGFloat {
            case hero = 86
            case xl = 56
            case lg = 44
            case md = 30
            case sm = 22
        }

        static func metric(_ size: MetricSize) -> Font {
            .system(size: size.rawValue, weight: .heavy).monospacedDigit()
        }

        static func metricTracking(_ size: MetricSize) -> CGFloat {
            size.rawValue * -0.02
        }

        /// Uppercase eyebrow labels (TIME, AVG PACE, dates). 11 pt is the floor
        /// set in "Accessibility of text over photos and live metrics".
        static let labelSize: CGFloat = 11
        static let label = Font.system(size: labelSize, weight: .semibold)
        static let labelTracking: CGFloat = labelSize * 0.2
        /// The spaced-out PACEPRINT wordmark.
        static let wordmarkTracking: CGFloat = labelSize * 0.4

        /// Place name headline on Summary.
        static let placeName = Font.system(size: 44, weight: .heavy)
    }
}
