/// Time taken per unit of distance; never expressed as speed.
public struct Pace: Equatable, Sendable {
    public var secondsPerMetre: Double

    public init(secondsPerMetre: Double) {
        self.secondsPerMetre = secondsPerMetre
    }

    /// Seconds per one `unit`, e.g. 315 for 5:15 /km.
    public func seconds(per unit: DistanceUnit) -> Double {
        secondsPerMetre * unit.metresPerUnit
    }
}
