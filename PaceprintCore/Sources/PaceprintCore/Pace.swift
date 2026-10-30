/// Time taken per unit of distance; never expressed as speed.
public struct Pace: Equatable, Sendable {
    public var secondsPerMetre: Double

    public init(secondsPerMetre: Double) {
        self.secondsPerMetre = secondsPerMetre
    }

    /// Distance below which Average pace is too unsteady to show.
    static let averageMinimumDistance = 100.0

    /// Average pace: `movingTime` over `distance` metres, or nil until 0.1 km.
    public static func average(movingTime: Double, distance: Double) -> Pace? {
        guard distance >= averageMinimumDistance else { return nil }
        return Pace(secondsPerMetre: movingTime / distance)
    }

    /// Seconds per one `unit`, e.g. 315 for 5:15 /km.
    public func seconds(per unit: DistanceUnit) -> Double {
        secondsPerMetre * unit.metresPerUnit
    }
}
