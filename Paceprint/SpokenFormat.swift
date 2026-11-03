import Foundation
import PaceprintCore

/// What VoiceOver says for Run numbers: whole words, e.g. "5 minutes, 16 seconds per kilometre", in
/// English like the rest of the app.
enum SpokenFormat {
    /// Active run's metrics as one element, read when focused: distance, Moving time, Current pace.
    static func activeRun(distance metres: Double, movingTime: TimeInterval, pace: Pace?, units: DistanceUnit) -> String {
        let pace = pace.map { "Pace \(self.pace($0, per: units))." } ?? "No pace yet."
        return "Distance \(distance(metres, in: units)). Time \(duration(movingTime)). \(pace)"
    }

    /// Announced as each whole Split is completed, e.g. "Kilometre 3, 5 minutes, 12 seconds".
    static func splitCompleted(_ split: Split, units: DistanceUnit) -> String {
        "\(splitName(split.number, units: units)), \(duration(split.movingTime))"
    }

    /// A row of Run detail's Splits, e.g. "Kilometre 1, 5 minutes, 1 second per kilometre, total 5 minutes,
    /// 1 second"; the Partial split goes by its real distance.
    static func splitRow(_ split: Split, units: DistanceUnit) -> String {
        let name = split.isPartial ? "Last \(distance(split.distance, in: units))" : splitName(split.number, units: units)
        return "\(name), \(pace(split.pace, per: units)), total \(duration(split.cumulativeMovingTime))"
    }

    /// The Route on its map as one element, e.g. "Route map, 5.42 kilometres, starting in Central Park".
    static func routeMap(distance metres: Double, startingIn place: String?, units: DistanceUnit) -> String {
        "Route map, \(routeDetails(metres, place, units))"
    }

    /// The Route drawn over a photo, where there's no map: e.g. "Route, 5.42 kilometres, starting in …".
    static func route(distance metres: Double, startingIn place: String?, units: DistanceUnit) -> String {
        "Route, \(routeDetails(metres, place, units))"
    }

    /// A whole Split by its number, e.g. "Kilometre 3".
    static func splitName(_ number: Int, units: DistanceUnit) -> String {
        "\(units.spokenName.capitalized) \(number)"
    }

    private static func routeDetails(_ metres: Double, _ place: String?, _ units: DistanceUnit) -> String {
        distance(metres, in: units) + (place.map { ", starting in \($0)" } ?? "")
    }

    /// e.g. "3.42 kilometres", "1 mile".
    static func distance(_ metres: Double, in units: DistanceUnit) -> String {
        let value = metres / units.metresPerUnit
        let number = value.formatted(.number.precision(.fractionLength(0...2)).locale(RunFormat.english))
        return "\(number) \(units.spokenName)\(number == "1" ? "" : "s")"
    }

    /// e.g. "5 minutes, 16 seconds per kilometre".
    static func pace(_ pace: Pace, per units: DistanceUnit) -> String {
        "\(duration(pace.seconds(per: units).rounded())) per \(units.spokenName)"
    }

    /// e.g. "18 minutes, 4 seconds", "1 hour, 2 minutes".
    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds.rounded(.down)).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(RunFormat.english))
    }
}
