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
}
