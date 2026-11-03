import Foundation

/// CAL (EST): the active calories a Run burned, estimated with the ACSM equations from its Route and
/// the runner's body weight. No heart rate, and grade ignored.
public enum Calories {
    /// ACSM's net oxygen cost, in mL of O₂ per kg per metre covered: running, and walking below 8 km/h.
    static let runningOxygenPerMetre = 0.2
    static let walkingOxygenPerMetre = 0.1
    /// 8 km/h, in metres per second: stretches covered slower than this use the walking term.
    static let walkingSpeedLimit = 8_000.0 / 3_600
    /// Walking or running is judged over about this many metres, so GPS jitter between single fixes
    /// doesn't flip it from step to step.
    static let judgedOver = 100.0
    /// Energy per litre of O₂ burned.
    static let kilocaloriesPerLitre = 5.0
    /// CAL (EST) is rounded to this many kcal.
    static let roundedTo = 5.0

    /// Active (net) kcal burned covering `route` with a body mass of `bodyMass` kg, rounded to the
    /// nearest 5: about 1 kcal per kg per km running, half that walking. Nothing counts across a Pause.
    public static func activeKilocalories(route: [RoutePoint], pauses: [Pause], bodyMass: Double) -> Double {
        var oxygenPerKilogram = 0.0  // mL of O₂ per kg of body mass
        for stretch in PaceColoring.stretches(of: route, pauses: pauses) {
            // Cut each stretch into pieces of at least 100 m (the last may be shorter), each judged whole.
            var pieceStart = stretch[0]
            for (index, point) in stretch.enumerated().dropFirst() {
                let metres = point.cumulativeDistance - pieceStart.cumulativeDistance
                guard metres >= judgedOver || index == stretch.count - 1 else { continue }
                let seconds = point.timestamp.timeIntervalSince(pieceStart.timestamp)
                if metres > 0, seconds > 0 {
                    let perMetre = metres / seconds < walkingSpeedLimit ? walkingOxygenPerMetre : runningOxygenPerMetre
                    oxygenPerKilogram += perMetre * metres
                }
                pieceStart = point
            }
        }
        let kilocalories = oxygenPerKilogram / 1_000 * kilocaloriesPerLitre * bodyMass
        return (kilocalories / roundedTo).rounded(.toNearestOrAwayFromZero) * roundedTo
    }
}
