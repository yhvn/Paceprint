import Foundation
import Testing
import PaceprintCore

private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

/// 6:00 /km.
private let average = Pace(secondsPerMetre: 0.36)

/// A Route of points every 10 m, each 10 m taking `secondsPerMetre(at: metres) * 10` seconds.
private func route(metres: Double, secondsPerMetre: (Double) -> Double) -> [RoutePoint] {
    var points: [RoutePoint] = []
    var time = start
    var distance = 0.0
    while distance <= metres {
        points.append(point(at: distance, time: time))
        time += secondsPerMetre(distance) * 10
        distance += 10
    }
    return points
}

private func point(at distance: Double, time: Date, isPaused: Bool = false) -> RoutePoint {
    RoutePoint(
        timestamp: time,
        latitude: 40.78 + distance / 111_195,
        longitude: -73.966,
        altitude: 30,
        horizontalAccuracy: 5,
        cumulativeDistance: distance,
        isPaused: isPaused
    )
}

@Suite("Pace coloring")
struct PaceColoringTests {
    @Test("A Route run at the Average pace is one piece in the middle color")
    func steady() throws {
        let route = route(metres: 1_000) { _ in 0.36 }

        let pieces = PaceColoring.pieces(of: route, pauses: [], averagePace: average)

        #expect(pieces.count == 1)
        #expect(pieces.first?.color == .average)
        #expect(pieces.first?.points == route)
    }

    @Test("Pace color runs from full fast at 30 s/km faster than average to full slow at 30 s/km slower", arguments: [
        (secondsPerKilometre: 330.0, position: 0.0),
        (secondsPerKilometre: 300.0, position: 0.0),
        (secondsPerKilometre: 345.0, position: 0.25),
        (secondsPerKilometre: 375.0, position: 0.75),
        (secondsPerKilometre: 390.0, position: 1.0),
        (secondsPerKilometre: 450.0, position: 1.0),
    ])
    func scale(secondsPerKilometre: Double, position: Double) {
        let route = route(metres: 500) { _ in secondsPerKilometre / 1000 }

        let pieces = PaceColoring.pieces(of: route, pauses: [], averagePace: average)

        #expect(pieces.map(\.color) == [PaceColor(position: position)])
    }

    @Test("Each point's Pace is averaged over the surrounding 100 m, so a change of Pace blends over 100 m")
    func smoothedOver100m() throws {
        // 500 m at 5:30 /km, then 500 m at 6:30 /km: an average of 6:00 /km.
        let route = route(metres: 1_000) { $0 < 500 ? 0.33 : 0.39 }

        let pieces = PaceColoring.pieces(of: route, pauses: [], averagePace: average)

        func color(at metres: Double) throws -> PaceColor {
            try #require(pieces.first { piece in piece.points.contains { $0.cumulativeDistance == metres } && piece.points.last?.cumulativeDistance != metres }?.color)
        }
        #expect(try color(at: 0) == PaceColor(position: 0))
        #expect(try color(at: 440) == PaceColor(position: 0))
        #expect(try color(at: 560) == PaceColor(position: 1))
        #expect(try color(at: 990) == PaceColor(position: 1))
        // Colors only get slower along the Route, in more than the two end colors.
        let positions = pieces.map(\.color.position)
        #expect(positions == positions.sorted())
        #expect(pieces.count > 2)
    }

    @Test("Neighbouring pieces never share a color: same-color stretches are merged")
    func merged() {
        let route = route(metres: 1_000) { $0 < 500 ? 0.33 : 0.39 }

        let pieces = PaceColoring.pieces(of: route, pauses: [], averagePace: average)

        #expect(zip(pieces, pieces.dropFirst()).allSatisfy { $0.color != $1.color })
        // Each piece starts where the last ended, so the line has no gaps.
        #expect(zip(pieces, pieces.dropFirst()).allSatisfy { $0.points.last == $1.points.first })
    }

    @Test("Without an Average pace yet, the whole Route is the middle color")
    func noAverage() {
        let route = route(metres: 50) { _ in 0.2 }

        let pieces = PaceColoring.pieces(of: route, pauses: [], averagePace: nil)

        #expect(pieces.map(\.color) == [.average])
    }

    @Test("The Route breaks across a Pause: paused points aren't drawn, and no piece or stretch spans it")
    func breaksAtPause() {
        // 0–200 m, a 60 s Pause with two paused points, then 200–400 m.
        let before = route(metres: 200) { _ in 0.36 }
        let pauseStart = before.last!.timestamp + 10
        let paused = [point(at: 200, time: pauseStart + 20, isPaused: true), point(at: 200, time: pauseStart + 40, isPaused: true)]
        let after = route(metres: 200) { _ in 0.36 }.map {
            point(at: 200 + $0.cumulativeDistance, time: $0.timestamp + pauseStart.timeIntervalSince(start) + 60)
        }
        let route = before + paused + after
        let pauses = [Pause(start: pauseStart, end: pauseStart + 60)]

        let stretches = PaceColoring.stretches(of: route, pauses: pauses)
        let pieces = PaceColoring.pieces(of: route, pauses: pauses, averagePace: average)

        #expect(stretches == [before, after])
        // The Pause doesn't count against the Pace either side of it.
        #expect(pieces.map(\.color) == [.average, .average])
        #expect(pieces.map(\.points) == [before, after])
    }

    @Test("A Route of one point has nothing to draw")
    func singlePoint() {
        let route = [point(at: 0, time: start)]

        #expect(PaceColoring.stretches(of: route, pauses: []).isEmpty)
        #expect(PaceColoring.pieces(of: route, pauses: [], averagePace: average).isEmpty)
    }
}
