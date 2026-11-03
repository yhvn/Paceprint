import Foundation
import Testing
import PaceprintCore

private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

/// A point every 10 m to `metres`, each 10 m taking `secondsPer10m`, `from` metres in and `at` seconds after start.
private func route(from: Double = 0, to metres: Double, secondsPer10m: Double, at seconds: Double = 0) -> [RoutePoint] {
    stride(from: from, through: metres, by: 10).map {
        RoutePoint(
            timestamp: start + seconds + ($0 - from) / 10 * secondsPer10m,
            latitude: 40.78 + $0 / 111_195,
            longitude: -73.966,
            altitude: 30,
            horizontalAccuracy: 5,
            cumulativeDistance: $0,
            isPaused: false
        )
    }
}

@Suite("Calories")
struct CaloriesTests {
    @Test("Running burns about 1 active kcal per kg per km, whatever the Pace (ACSM, net)")
    func running() {
        // 5 km at 5:15 /km for 70 kg: the decision's worked example, 350 kcal.
        let calories = Calories.activeKilocalories(route: route(to: 5_000, secondsPer10m: 3.15), pauses: [], bodyMass: 70)

        #expect(calories == 350)
    }

    @Test("Below 8 km/h ACSM's walking term applies: half as much per km")
    func walking() {
        // 2 km at 6 km/h (6 s per 10 m) for 80 kg: 0.5 × 80 × 2 = 80 kcal.
        let calories = Calories.activeKilocalories(route: route(to: 2_000, secondsPer10m: 6), pauses: [], bodyMass: 80)

        #expect(calories == 80)
    }

    @Test("Walking or running is judged over about 100 m, not each GPS step, so jitter doesn't halve a run")
    func judgedOverStretches() {
        // 2 km at 9 km/h on average, each 10 m step alternating 5 s and 3 s: half the steps alone look like walking.
        let points = stride(from: 0.0, through: 2_000, by: 10).map { metres -> RoutePoint in
            let steps = Int(metres / 10)
            let seconds = Double(steps / 2) * 8 + (steps % 2 == 1 ? 5 : 0)
            return RoutePoint(timestamp: start + seconds, latitude: 40.78 + metres / 111_195, longitude: -73.966, altitude: 30, horizontalAccuracy: 5, cumulativeDistance: metres, isPaused: false)
        }

        #expect(Calories.activeKilocalories(route: points, pauses: [], bodyMass: 70) == 140)
    }

    @Test("Nothing is burned across a Pause, however far the gap")
    func pause() {
        // 1 km, a 10-minute Pause during which the runner is driven 3 km, then 1 km more.
        let before = route(to: 1_000, secondsPer10m: 3)
        let after = route(from: 4_000, to: 5_000, secondsPer10m: 3, at: 900)
        let pause = Pause(start: start + 310, end: start + 900)

        let calories = Calories.activeKilocalories(route: before + after, pauses: [pause], bodyMass: 70)

        #expect(calories == 140)
    }

    @Test("Calories are rounded to the nearest 5 kcal", arguments: [
        (metres: 1_000.0, kg: 72.4, kcal: 70.0),
        (metres: 1_000.0, kg: 72.6, kcal: 75.0),
    ])
    func rounding(metres: Double, kg: Double, kcal: Double) {
        #expect(Calories.activeKilocalories(route: route(to: metres, secondsPer10m: 3), pauses: [], bodyMass: kg) == kcal)
    }

    @Test("A Route that covers no distance burns nothing")
    func noDistance() {
        #expect(Calories.activeKilocalories(route: [], pauses: [], bodyMass: 70) == 0)
    }
}
