import Foundation
import PaceprintCore

/// How Run numbers read on screen. Kilometres until the units setting lands.
enum RunFormat {
    /// Metres as kilometres to 2 decimals, e.g. "5.24".
    static func kilometres(_ metres: Double) -> String {
        (metres / DistanceUnit.kilometers.metresPerUnit).formatted(.number.precision(.fractionLength(2)))
    }

    /// Seconds as "m:ss", or "h:mm:ss" from an hour.
    static func time(_ seconds: TimeInterval) -> String {
        let duration = Duration.seconds(seconds.rounded(.down))
        return duration.formatted(.time(pattern: seconds >= 3_600 ? .hourMinuteSecond : .minuteSecond))
    }

    /// A Pace per kilometre as "m:ss", e.g. "5:15", or "--:--" when there's none to show.
    static func pace(_ pace: Pace?) -> String {
        guard let pace else { return "--:--" }
        let seconds = pace.seconds(per: .kilometers).rounded()
        return Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }
}
