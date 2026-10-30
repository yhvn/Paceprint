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

@Suite("Run tracker")
struct RunTrackerTests {
    @Test("The first good fix starts the Route at 0 m")
    func firstFix() {
        var tracker = RunTracker(runStart: start)

        let point = tracker.add(fix(step: 0, seconds: 1))

        #expect(point?.cumulativeDistance == 0)
        #expect(point?.latitude == 40.7800)
        #expect(point?.horizontalAccuracy == 5)
        #expect(point?.isPaused == false)
    }

    @Test("Distance is the sum of great-circle distances between kept points")
    func distanceAccumulates() {
        var tracker = RunTracker(runStart: start)

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
        var tracker = RunTracker(runStart: start)

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
        var tracker = RunTracker(runStart: start)
        _ = tracker.add(fix(step: 0, seconds: 0))
        _ = tracker.add(fix(step: 1, seconds: 4))

        #expect(tracker.add(noise.fix) == nil)
        #expect(tracker.points.count == 2)
        #expect(abs(tracker.distance - stepMetres) < 0.01)
    }

    @Test("The first fix is dropped too when it's noisy")
    func dropsNoisyFirstFix() {
        var tracker = RunTracker(runStart: start)

        #expect(tracker.add(fix(step: 0, seconds: -30)) == nil)
        #expect(tracker.add(fix(step: 0, seconds: 1, accuracy: 65)) == nil)
        #expect(tracker.points.isEmpty)
    }

    @Test("Fixes near the limits are kept: 25 m accuracy, just under 12 m/s")
    func keepsLimits() {
        var tracker = RunTracker(runStart: start)
        _ = tracker.add(fix(step: 0, seconds: 0))

        #expect(tracker.add(fix(step: 1, seconds: 4, accuracy: 25)) != nil)
        // 12 steps (133.4 m) in 11.2 s is 11.9 m/s.
        #expect(tracker.add(fix(step: 13, seconds: 15.2)) != nil)
    }

    @Test("After a dropped fix, distance continues from the last kept point")
    func continuesAfterNoise() {
        var tracker = RunTracker(runStart: start)
        _ = tracker.add(fix(step: 0, seconds: 0))
        _ = tracker.add(fix(step: 40, seconds: 4)) // teleport
        _ = tracker.add(fix(step: 1, seconds: 8))

        #expect(abs(tracker.distance - stepMetres) < 0.01)
    }

    @Test("Fixes during a Pause are kept, flagged paused, and add no distance")
    func pausedFixes() {
        var tracker = RunTracker(runStart: start)
        _ = tracker.add(fix(step: 0, seconds: 0))
        _ = tracker.add(fix(step: 1, seconds: 4))
        tracker.pause(at: start.addingTimeInterval(6))

        let paused = tracker.add(fix(step: 2, seconds: 8))

        #expect(paused?.isPaused == true)
        #expect(paused?.cumulativeDistance == tracker.points[1].cumulativeDistance)
        #expect(abs(tracker.distance - stepMetres) < 0.01)
    }

    @Test("The Route breaks between Pause and Resume: the gap adds no distance")
    func routeBreaks() {
        var tracker = RunTracker(runStart: start)
        _ = tracker.add(fix(step: 0, seconds: 0))
        _ = tracker.add(fix(step: 1, seconds: 4))
        tracker.pause(at: start.addingTimeInterval(5))
        _ = tracker.add(fix(step: 2, seconds: 8))
        tracker.resume(at: start.addingTimeInterval(60))
        // The runner walked 20 steps while paused; none of it counts.
        _ = tracker.add(fix(step: 22, seconds: 64))
        _ = tracker.add(fix(step: 23, seconds: 68))

        #expect(tracker.points.map(\.isPaused) == [false, false, true, false, false])
        #expect(abs(tracker.distance - 2 * stepMetres) < 0.01)
    }

    @Test("Whether a fix is paused depends on its timestamp, not when it arrives")
    func pausedByTimestamp() {
        var tracker = RunTracker(runStart: start)
        _ = tracker.add(fix(step: 0, seconds: 0))
        tracker.pause(at: start.addingTimeInterval(10))
        tracker.resume(at: start.addingTimeInterval(20))

        // Arrives after the Pause was recorded but was taken before it.
        #expect(tracker.add(fix(step: 1, seconds: 4))?.isPaused == false)
        #expect(tracker.add(fix(step: 2, seconds: 12))?.isPaused == true)
        #expect(tracker.add(fix(step: 3, seconds: 20))?.isPaused == false)
    }

    @Test("Pauses are recorded as intervals; one still open has no end")
    func pauseIntervals() {
        var tracker = RunTracker(runStart: start)
        tracker.pause(at: start.addingTimeInterval(10))
        tracker.resume(at: start.addingTimeInterval(25))
        tracker.pause(at: start.addingTimeInterval(40))

        #expect(tracker.pauses == [
            Pause(start: start.addingTimeInterval(10), end: start.addingTimeInterval(25)),
            Pause(start: start.addingTimeInterval(40), end: nil),
        ])
        #expect(tracker.isPaused)
    }

    @Test("Pausing twice or resuming while running changes nothing")
    func redundantPauseAndResume() {
        var tracker = RunTracker(runStart: start)
        tracker.resume(at: start.addingTimeInterval(5))
        tracker.pause(at: start.addingTimeInterval(10))
        tracker.pause(at: start.addingTimeInterval(15))

        #expect(tracker.pauses == [Pause(start: start.addingTimeInterval(10), end: nil)])
    }

    @Test("Moving time is the time since Start with Pauses removed")
    func movingTime() {
        var tracker = RunTracker(runStart: start)
        tracker.pause(at: start.addingTimeInterval(100))
        tracker.resume(at: start.addingTimeInterval(160))

        #expect(tracker.movingTime(at: start.addingTimeInterval(50)) == 50)
        #expect(tracker.movingTime(at: start.addingTimeInterval(130)) == 100)
        #expect(tracker.movingTime(at: start.addingTimeInterval(400)) == 340)
    }

    @Test("Moving time stands still during a Pause that hasn't ended")
    func movingTimeWhilePaused() {
        var tracker = RunTracker(runStart: start)
        tracker.pause(at: start.addingTimeInterval(90))

        #expect(tracker.movingTime(at: start.addingTimeInterval(90)) == 90)
        #expect(tracker.movingTime(at: start.addingTimeInterval(500)) == 90)
    }

    @Test("Average pace is Moving time over distance")
    func averagePace() throws {
        var tracker = RunTracker(runStart: start)
        for step in 0...5 { _ = tracker.add(fix(step: step, seconds: Double(step) * 4)) }
        tracker.pause(at: start.addingTimeInterval(22))
        tracker.resume(at: start.addingTimeInterval(42))
        for step in 5...10 { _ = tracker.add(fix(step: step, seconds: 22 + Double(step) * 4)) }

        // 111.195 m in 42 s of Moving time (62 s elapsed): 6:17.7 /km, 10:07.9 /mi.
        let pace = try #require(tracker.averagePace(at: start.addingTimeInterval(62)))
        #expect(abs(pace.seconds(per: .kilometers) - 377.71) < 0.01)
        #expect(abs(pace.seconds(per: .miles) - 607.87) < 0.01)
    }

    @Test("Average pace isn't shown until 0.1 km")
    func averagePaceBelowMinimum() {
        var tracker = RunTracker(runStart: start)
        for step in 0...8 { _ = tracker.add(fix(step: step, seconds: Double(step) * 4)) }

        // 88.956 m.
        #expect(tracker.averagePace(at: start.addingTimeInterval(32)) == nil)
    }

    /// One step every 4 s: 11.1195 m / 4 s is 5:59.7 /km.
    private static let steadyPace = 359.73

    @Test("Current pace is the Pace over the last 30 s of Moving time")
    func currentPace() throws {
        var tracker = RunTracker(runStart: start)
        for step in 0...15 { _ = tracker.add(fix(step: step, seconds: Double(step) * 4)) }

        let pace = try #require(tracker.currentPace)
        #expect(abs(pace.seconds(per: .kilometers) - Self.steadyPace) < 0.01)
    }

    @Test("Current pace looks back over Moving time, skipping a Pause")
    func currentPaceAcrossPause() throws {
        var tracker = RunTracker(runStart: start)
        for step in 0...15 { _ = tracker.add(fix(step: step, seconds: Double(step) * 4)) }
        tracker.pause(at: start.addingTimeInterval(60))
        tracker.resume(at: start.addingTimeInterval(120))
        for step in 15...19 { _ = tracker.add(fix(step: step, seconds: 60 + Double(step) * 4)) }

        // 76 s of Moving time: the window is 46 s to 76 s of Moving time, 7.5 steps.
        // Counting the Pause would give 4 steps in 30 s: 11:14 /km.
        let pace = try #require(tracker.currentPace)
        #expect(abs(pace.seconds(per: .kilometers) - Self.steadyPace) < 0.01)
    }

    @Test("No Current pace for the first 30 s of Moving time")
    func currentPaceTooEarly() {
        var tracker = RunTracker(runStart: start)
        for step in 0...5 { _ = tracker.add(fix(step: step, seconds: Double(step) * 4)) }
        tracker.pause(at: start.addingTimeInterval(20))
        tracker.resume(at: start.addingTimeInterval(200))

        // 29 s of Moving time, 209 s elapsed.
        #expect(tracker.currentPace == nil)
    }

    @Test("No Current pace when slower than 20:00 /km")
    func currentPaceTooSlow() {
        var tracker = RunTracker(runStart: start)
        // One step every 14 s is 20:59 /km.
        for step in 0...5 { _ = tracker.add(fix(step: step, seconds: Double(step) * 14)) }

        #expect(tracker.currentPace == nil)
    }

    @Test("No Current pace when standing still")
    func currentPaceStandingStill() {
        var tracker = RunTracker(runStart: start)
        for second in stride(from: 0.0, through: 60, by: 4) { _ = tracker.add(fix(step: 0, seconds: second)) }

        #expect(tracker.currentPace == nil)
    }

    @Test("The Route breaks across a Pause even when no fix was kept during it")
    func routeBreaksWithoutPausedFix() {
        var tracker = RunTracker(runStart: start)
        _ = tracker.add(fix(step: 0, seconds: 0))
        _ = tracker.add(fix(step: 1, seconds: 4))
        tracker.pause(at: start.addingTimeInterval(5))
        tracker.resume(at: start.addingTimeInterval(60))
        _ = tracker.add(fix(step: 21, seconds: 64))
        _ = tracker.add(fix(step: 22, seconds: 68))

        #expect(abs(tracker.distance - 2 * stepMetres) < 0.01)
    }

    @Test("Moving far during a Pause isn't taken for a teleport after Resume")
    func farDuringPause() {
        var tracker = RunTracker(runStart: start)
        _ = tracker.add(fix(step: 0, seconds: 0))
        tracker.pause(at: start.addingTimeInterval(5))
        tracker.resume(at: start.addingTimeInterval(60))

        // 200 steps (2.2 km) in 64 s is 35 m/s, but it was covered while paused.
        #expect(tracker.add(fix(step: 200, seconds: 64)) != nil)
        #expect(tracker.distance == 0)
    }

    @Test("GPS is being found until the first point is kept")
    func findingGPS() {
        var tracker = RunTracker(runStart: start)
        #expect(tracker.gpsStatus(at: start.addingTimeInterval(20)) == .finding)

        // A fix too poor to keep doesn't count as found.
        _ = tracker.add(fix(step: 0, seconds: 21, accuracy: 60))
        #expect(tracker.gpsStatus(at: start.addingTimeInterval(22)) == .finding)

        _ = tracker.add(fix(step: 0, seconds: 23))
        #expect(tracker.gpsStatus(at: start.addingTimeInterval(24)) == .good)
    }

    @Test("GPS is weak once no point has been kept for 10 s")
    func weakGPS() {
        var tracker = RunTracker(runStart: start)
        _ = tracker.add(fix(step: 0, seconds: 0))
        _ = tracker.add(fix(step: 1, seconds: 4))

        #expect(tracker.gpsStatus(at: start.addingTimeInterval(13.9)) == .good)
        #expect(tracker.gpsStatus(at: start.addingTimeInterval(14)) == .weak)

        // Noisy fixes don't count as GPS coming back.
        _ = tracker.add(fix(step: 2, seconds: 15, accuracy: 80))
        #expect(tracker.gpsStatus(at: start.addingTimeInterval(16)) == .weak)

        _ = tracker.add(fix(step: 3, seconds: 17))
        #expect(tracker.gpsStatus(at: start.addingTimeInterval(18)) == .good)
    }

    @Test("When fixes return after a gap, it's bridged with a straight line")
    func gapBridged() {
        var tracker = RunTracker(runStart: start)
        _ = tracker.add(fix(step: 0, seconds: 0))
        // 60 s in a tunnel, 15 steps (167 m) further on: 2.8 m/s.
        _ = tracker.add(fix(step: 15, seconds: 60))

        #expect(abs(tracker.distance - 15 * stepMetres) < 0.01)
    }

    @Test("Standing still isn't weak GPS: the system stops sending fixes while it reports stationary")
    func stationaryIsNotWeak() {
        var tracker = RunTracker(runStart: start)
        _ = tracker.add(fix(step: 0, seconds: 0))
        tracker.markStationary()

        #expect(tracker.gpsStatus(at: start.addingTimeInterval(60)) == .good)

        // Moving again: the next kept fix ends it, and the usual 10 s rule applies.
        _ = tracker.add(fix(step: 1, seconds: 64))
        #expect(tracker.gpsStatus(at: start.addingTimeInterval(80)) == .weak)
    }

    @Test("Stationary before any point is kept is still finding GPS")
    func stationaryWhileFinding() {
        var tracker = RunTracker(runStart: start)
        tracker.markStationary()

        #expect(tracker.gpsStatus(at: start.addingTimeInterval(30)) == .finding)
    }

    @Test("A Run under 0.1 km or under 1 min of Moving time is too short to keep", arguments: [
        (steps: 8, seconds: 120.0, isTooShort: true),   // 89 m
        (steps: 9, seconds: 120.0, isTooShort: false),  // 100.08 m
        (steps: 20, seconds: 59.0, isTooShort: true),
        (steps: 20, seconds: 60.0, isTooShort: false),
    ])
    func tooShort(steps: Int, seconds: Double, isTooShort: Bool) {
        var tracker = RunTracker(runStart: start)
        for step in 0...steps {
            _ = tracker.add(fix(step: step, seconds: Double(step)))
        }

        #expect(tracker.isTooShort(at: start.addingTimeInterval(seconds)) == isTooShort)
    }

    @Test("Moving time spent in a Pause doesn't count toward the 1 min")
    func tooShortAcrossPause() {
        var tracker = RunTracker(runStart: start)
        for step in 0...20 {
            _ = tracker.add(fix(step: step, seconds: Double(step)))
        }
        tracker.pause(at: start.addingTimeInterval(30))

        #expect(tracker.isTooShort(at: start.addingTimeInterval(300)))
    }

    @Test("A tracker rebuilt from its Route and Pauses carries on where it left off")
    func restored() {
        var original = RunTracker(runStart: start)
        for step in 0...5 {
            _ = original.add(fix(step: step, seconds: Double(step) * 4))
        }
        original.pause(at: start.addingTimeInterval(22))

        var restored = RunTracker(runStart: start, points: original.points, pauses: original.pauses)
        restored.resume(at: start.addingTimeInterval(40))
        _ = restored.add(fix(step: 6, seconds: 44))
        _ = restored.add(fix(step: 7, seconds: 48))

        #expect(restored.points.count == 8)
        // 5 steps before the Pause, none across it, 1 after.
        #expect(abs(restored.distance - 6 * stepMetres) < 0.01)
        #expect(restored.movingTime(at: start.addingTimeInterval(48)) == 30)
    }
}
