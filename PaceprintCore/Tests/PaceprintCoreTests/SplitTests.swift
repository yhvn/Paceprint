import Foundation
import Testing
import PaceprintCore

private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

/// A point `distance` metres along the Route, `seconds` after `start`.
private func point(_ distance: Double, _ seconds: Double, isPaused: Bool = false) -> RoutePoint {
    RoutePoint(
        timestamp: start + seconds,
        latitude: 40.78 + distance / 111_195,
        longitude: -73.966,
        altitude: 30,
        horizontalAccuracy: 5,
        cumulativeDistance: distance,
        isPaused: isPaused
    )
}

/// A point every 10 m from `from` to `to` metres at 6:00 /km, the first `seconds` after `start`.
private func steady(from: Double = 0, to: Double, at seconds: Double = 0) -> [RoutePoint] {
    stride(from: from, through: to, by: 10).map { point($0, seconds + ($0 - from) * 0.36) }
}

@Suite("Splits")
struct SplitTests {
    @Test("A Route is cut into whole kilometres, then a Partial split with its real distance")
    func kilometres() {
        let tracker = RunTracker(runStart: start, points: steady(to: 2_500), pauses: [])

        let splits = tracker.splits(per: .kilometers, until: tracker.points.last!.timestamp)

        #expect(splits.map(\.number) == [1, 2, 3])
        #expect(splits.map(\.isPartial) == [false, false, true])
        #expect(splits.map(\.distance) == [1_000, 1_000, 500])
        #expect(splits.map { $0.movingTime.rounded() } == [360, 360, 180])
        #expect(splits.map { $0.cumulativeMovingTime.rounded() } == [360, 720, 900])
        #expect(splits.allSatisfy { abs($0.pace.seconds(per: .kilometers) - 360) < 0.001 })
    }

    @Test("Switching to miles re-cuts the same Route")
    func miles() {
        let tracker = RunTracker(runStart: start, points: steady(to: 2_000), pauses: [])

        let splits = tracker.splits(per: .miles, until: tracker.points.last!.timestamp)

        #expect(splits.count == 2)
        #expect(splits[0].distance == 1_609.344)
        #expect(abs(splits[0].movingTime - 579.364) < 0.001)
        #expect(splits[1].isPartial)
        #expect(abs(splits[1].distance - 390.656) < 0.001)
    }

    @Test("A Pause inside a Split doesn't count toward its Moving time")
    func pauseInsideSplit() {
        // 6:00 /km to 500 m, a 60 s Pause with a paused point in it, then 6:00 /km to 1,200 m.
        let before = steady(to: 500)
        let paused = point(500, 200, isPaused: true)
        let after = steady(from: 500, to: 1_200, at: 240)
        let pause = Pause(start: start + 180, end: start + 240)
        let tracker = RunTracker(runStart: start, points: before + [paused] + after, pauses: [pause])

        let splits = tracker.splits(per: .kilometers, until: tracker.points.last!.timestamp)

        #expect(splits.map { $0.movingTime.rounded() } == [360, 72])
        #expect(splits.map { $0.cumulativeMovingTime.rounded() } == [360, 432])
    }

    @Test("Time before the first point counts toward the first Split, as it does toward TIME")
    func beforeFirstPoint() {
        let tracker = RunTracker(runStart: start, points: steady(to: 1_000, at: 10), pauses: [])

        let splits = tracker.splits(per: .kilometers, until: tracker.points.last!.timestamp)

        #expect(splits.map { $0.movingTime.rounded() } == [370])
    }

    @Test("A Run shorter than one unit is all Partial split")
    func onlyPartial() {
        let tracker = RunTracker(runStart: start, points: steady(to: 400), pauses: [])

        let splits = tracker.splits(per: .kilometers, until: tracker.points.last!.timestamp)

        #expect(splits.count == 1)
        #expect(splits.first?.isPartial == true)
        #expect(splits.first?.distance == 400)
    }

    @Test("A Route ending on a whole unit has no Partial split")
    func noPartial() {
        let tracker = RunTracker(runStart: start, points: steady(to: 2_000), pauses: [])

        #expect(tracker.splits(per: .kilometers, until: tracker.points.last!.timestamp).map(\.isPartial) == [false, false])
    }

    @Test("The last Split runs to Stop, so its cumulative Moving time is the Run's TIME")
    func lastSplitRunsToStop() {
        let tracker = RunTracker(runStart: start, points: steady(to: 1_500), pauses: [])

        let splits = tracker.splits(per: .kilometers, until: start + 545)

        #expect(splits.map { $0.movingTime.rounded() } == [360, 185])
        #expect(splits.last?.cumulativeMovingTime == 545)
    }

    @Test("A leftover under 10 m isn't a Partial split")
    func tinyLeftover() {
        let tracker = RunTracker(runStart: start, points: steady(to: 1_000) + [point(1_008, 363)], pauses: [])

        let splits = tracker.splits(per: .kilometers, until: start + 363)

        #expect(splits.map(\.isPartial) == [false])
        #expect(splits.last?.cumulativeMovingTime == 363)
    }

    @Test("A Route ending exactly on a whole unit cuts cleanly, whatever the floating point", arguments: DistanceUnit.allCases, 1...5)
    func exactMultiple(unit: DistanceUnit, units: Int) {
        let total = Double(units) * unit.metresPerUnit
        let points = stride(from: 0.0, to: total, by: 10).map { point($0, $0 * 0.36) } + [point(total, total * 0.36)]
        let tracker = RunTracker(runStart: start, points: points, pauses: [])

        let splits = tracker.splits(per: unit, until: points.last!.timestamp)

        #expect(splits.count == units)
        #expect(splits.allSatisfy { !$0.isPartial && $0.movingTime > 0 })
    }

    @Test("A Route covering no distance has no Splits")
    func noDistance() {
        let tracker = RunTracker(runStart: start, points: [point(0, 5), point(0, 30)], pauses: [])

        #expect(tracker.splits(per: .kilometers, until: tracker.points.last!.timestamp).isEmpty)
    }
}
