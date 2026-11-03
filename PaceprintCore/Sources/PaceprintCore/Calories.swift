import Foundation

/// CAL (EST): the active calories a Run burned, estimated with the ACSM equations from its Route and
/// the runner's body weight. No heart rate, and grade ignored.
public enum Calories {
    /// ACSM's net oxygen cost, in mL of O₂ per kg per metre covered: running, and walking below 8 km/h.
    static let runningOxygenPerMetre = 0.2
    static let walkingOxygenPerMetre = 0.1
    /// 8 km/h, in metres per second: slower stretches use the walking term.
    static let walkingBelow = 8_000.0 / 3_600
    /// Energy per litre of O₂ burned.
    static let kilocaloriesPerLitre = 5.0
    /// CAL (EST) is rounded to this many kcal.
    static let roundedTo = 5.0

    /// Active (net) kcal burned covering `route` with a body mass of `bodyMass` kg, rounded to the
    /// nearest 5: about 1 kcal per kg per km running, half that walking. Nothing counts across a Pause.
    public static func activeKilocalories(route: [RoutePoint], pauses: [Pause], bodyMass: Double) -> Double {
        var oxygenPerKilogram = 0.0  // mL of O₂ per kg of body mass
        for stretch in PaceColoring.stretches(of: route, pauses: pauses) {
            for (a, b) in zip(stretch, stretch.dropFirst()) {
                let metres = b.cumulativeDistance - a.cumulativeDistance
                let seconds = b.timestamp.timeIntervalSince(a.timestamp)
                guard metres > 0, seconds > 0 else { continue }
                let perMetre = metres / seconds < walkingBelow ? walkingOxygenPerMetre : runningOxygenPerMetre
                oxygenPerKilogram += perMetre * metres
            }
        }
        let kilocalories = oxygenPerKilogram / 1_000 * kilocaloriesPerLitre * bodyMass
        return (kilocalories / roundedTo).rounded(.toNearestOrAwayFromZero) * roundedTo
    }
}
