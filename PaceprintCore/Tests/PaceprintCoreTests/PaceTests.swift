import Testing
import PaceprintCore

@Suite("Pace")
struct PaceTests {
    @Test("Average pace is Moving time over distance, from 0.1 km", arguments: [
        (movingTime: 1_800.0, distance: 5_000.0, secondsPerKilometre: 360.0 as Double?),
        (movingTime: 36.0, distance: 100.0, secondsPerKilometre: 360.0),
        (movingTime: 30.0, distance: 99.0, secondsPerKilometre: nil),
    ])
    func average(movingTime: Double, distance: Double, secondsPerKilometre: Double?) {
        #expect(Pace.average(movingTime: movingTime, distance: distance)?.seconds(per: .kilometers) == secondsPerKilometre)
    }
}
