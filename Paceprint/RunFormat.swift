import Foundation
import PaceprintCore

/// How Run numbers read on screen. Kilometres until the units setting lands.
enum RunFormat {
    /// Metres in `unit` to 2 decimals, e.g. "0.37".
    static func distance(_ metres: Double, in unit: DistanceUnit) -> String {
        (metres / unit.metresPerUnit).formatted(.number.precision(.fractionLength(2)))
    }

    /// A Pace per `unit` as "m:ss", or "--:--" when there's none to show.
    static func pace(_ pace: Pace?, per unit: DistanceUnit) -> String {
        guard let pace else { return "--:--" }
        return Duration.seconds(pace.seconds(per: unit).rounded()).formatted(.time(pattern: .minuteSecond))
    }

    /// Metres as kilometres to 2 decimals, e.g. "5.24".
    static func kilometres(_ metres: Double) -> String {
        distance(metres, in: .kilometers)
    }

    /// Seconds as "m:ss", or "h:mm:ss" from an hour.
    static func time(_ seconds: TimeInterval) -> String {
        let duration = Duration.seconds(seconds.rounded(.down))
        return duration.formatted(.time(pattern: seconds >= 3_600 ? .hourMinuteSecond : .minuteSecond))
    }

    /// A Pace per kilometre as "m:ss", e.g. "5:15", or "--:--" when there's none to show.
    static func pace(_ pace: Pace?) -> String {
        self.pace(pace, per: .kilometers)
    }
}

extension DistanceUnit {
    /// As in labels: "KM" or "MI".
    var abbreviation: String {
        switch self {
        case .kilometers: "KM"
        case .miles: "MI"
        }
    }

    /// As VoiceOver reads it: "kilometre" or "mile".
    var spokenName: String {
        switch self {
        case .kilometers: "kilometre"
        case .miles: "mile"
        }
    }
}
