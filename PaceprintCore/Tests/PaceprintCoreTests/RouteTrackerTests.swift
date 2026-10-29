import Foundation
import Testing
import PaceprintCore

/// One step of 0.0001° of latitude along a meridian is 11.1195 m on the mean-radius Earth.
private let stepMetres = 11.1195

private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

/// A fix `step` steps north of the origin, `seconds` after `start`.
private func fix(step: Int, seconds: Double, accuracy: Double = 5) -> LocationFix {
    LocationFix(
        timestamp: start.addingTimeInterval(seconds),
        latitude: 40.7800 + Double(step) * 0.0001,
        longitude: -73.9660,
        altitude: 30,
        horizontalAccuracy: accuracy
    )
}

@Suite("Route tracker")
struct RouteTrackerTests {
    @Test("The first good fix starts the Route at 0 m")
    func firstFix() {
        var tracker = RouteTracker(runStart: start)

        let point = tracker.add(fix(step: 0, seconds: 1))

        #expect(point?.cumulativeDistance == 0)
        #expect(point?.latitude == 40.7800)
        #expect(point?.horizontalAccuracy == 5)
        #expect(point?.isPaused == false)
    }

    @Test("Distance is the sum of great-circle distances between kept points")
    func distanceAccumulates() {
        var tracker = RouteTracker(runStart: start)

        for step in 0...10 {
            _ = tracker.add(fix(step: step, seconds: Double(step) * 4))
        }

        // 10 steps north: 111.195 m.
        #expect(abs(tracker.distance - 10 * stepMetres) < 0.01)
        #expect(abs(tracker.points[5].cumulativeDistance - 5 * stepMetres) < 0.01)
    }

    @Test("Distance east-west shrinks with latitude")
    func distanceAtLatitude() {
        // 0.001° of longitude at 60°N is half its length at the equator: 55.597 m.
        let a = LocationFix(timestamp: start.addingTimeInterval(1), latitude: 60, longitude: 10, altitude: 0, horizontalAccuracy: 5)
        let b = LocationFix(timestamp: start.addingTimeInterval(20), latitude: 60, longitude: 10.001, altitude: 0, horizontalAccuracy: 5)
        var tracker = RouteTracker(runStart: start)

        _ = tracker.add(a)
        _ = tracker.add(b)

        #expect(abs(tracker.distance - 55.597) < 0.01)
    }

    enum Noise: String, CaseIterable, CustomTestStringConvertible {
        case invalidAccuracy, poorAccuracy, outOfOrder, duplicateTimestamp, teleport, beforeRunStart

        var testDescription: String { rawValue }

        /// A noisy fix arriving after a good fix at step 1, 4 s into the Run.
        var fix: LocationFix {
            switch self {
            case .invalidAccuracy: PaceprintCoreTests.fix(step: 2, seconds: 8, accuracy: -1)
            case .poorAccuracy: PaceprintCoreTests.fix(step: 2, seconds: 8, accuracy: 26)
            case .outOfOrder: PaceprintCoreTests.fix(step: 2, seconds: 3)
            case .duplicateTimestamp: PaceprintCoreTests.fix(step: 2, seconds: 4)
            // 10 steps (111 m) in 4 s is 27.8 m/s, far beyond any runner.
            case .teleport: PaceprintCoreTests.fix(step: 11, seconds: 8)
            case .beforeRunStart: PaceprintCoreTests.fix(step: 2, seconds: -5)
            }
        }
    }

    @Test("Noisy fixes are dropped and add no distance", arguments: Noise.allCases)
    func dropsNoise(_ noise: Noise) {
        var tracker = RouteTracker(runStart: start)
        _ = tracker.add(fix(step: 0, seconds: 0))
        _ = tracker.add(fix(step: 1, seconds: 4))

        #expect(tracker.add(noise.fix) == nil)
        #expect(tracker.points.count == 2)
        #expect(abs(tracker.distance - stepMetres) < 0.01)
    }

    @Test("The first fix is dropped too when it's noisy")
    func dropsNoisyFirstFix() {
        var tracker = RouteTracker(runStart: start)

        #expect(tracker.add(fix(step: 0, seconds: -30)) == nil)
        #expect(tracker.add(fix(step: 0, seconds: 1, accuracy: 65)) == nil)
        #expect(tracker.points.isEmpty)
    }

    @Test("Fixes near the limits are kept: 25 m accuracy, just under 12 m/s")
    func keepsLimits() {
        var tracker = RouteTracker(runStart: start)
        _ = tracker.add(fix(step: 0, seconds: 0))

        #expect(tracker.add(fix(step: 1, seconds: 4, accuracy: 25)) != nil)
        // 12 steps (133.4 m) in 11.2 s is 11.9 m/s.
        #expect(tracker.add(fix(step: 13, seconds: 15.2)) != nil)
    }

    @Test("After a dropped fix, distance continues from the last kept point")
    func continuesAfterNoise() {
        var tracker = RouteTracker(runStart: start)
        _ = tracker.add(fix(step: 0, seconds: 0))
        _ = tracker.add(fix(step: 40, seconds: 4)) // teleport
        _ = tracker.add(fix(step: 1, seconds: 8))

        #expect(abs(tracker.distance - stepMetres) < 0.01)
    }
}
