import Foundation
import Testing
import PaceprintCore

private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

/// 6:00 /km.
private let average = Pace(secondsPerMetre: 0.36)

/// One point every 10 m along `path` (metres east, metres north of the start), each 10 m taking
/// `secondsPerMetre(at: metres) * 10` seconds.
private func route(
    metres: Double,
    secondsPerMetre: (Double) -> Double = { _ in 0.36 },
    path: (Double) -> (east: Double, north: Double) = { (0, $0) }
) -> [RoutePoint] {
    var points: [RoutePoint] = []
    var time = start
    var distance = 0.0
    while distance <= metres {
        let (east, north) = path(distance)
        points.append(RoutePoint(
            timestamp: time,
            latitude: 40.78 + north / 111_195,
            longitude: -73.966 + east / (111_195 * cos(40.78 * .pi / 180)),
            altitude: 30,
            horizontalAccuracy: 5,
            cumulativeDistance: distance,
            isPaused: false
        ))
        time += secondsPerMetre(distance) * 10
        distance += 10
    }
    return points
}

/// A zigzag: 50 m legs alternating north-east and north-west.
private func zigzag(_ metres: Double) -> (east: Double, north: Double) {
    let leg = (metres / 50).rounded(.down)
    let along = metres - leg * 50
    let east = Int(leg).isMultiple(of: 2) ? along : 50 - along
    return (east * 0.7, metres * 0.7)
}

@Suite("Route thumbnail")
struct RouteThumbnailTests {
    @Test("A straight Route is kept as just its two ends")
    func straight() {
        let route = route(metres: 2_000)

        let thumbnail = RouteThumbnail(route: route, pauses: [], averagePace: average)

        #expect(thumbnail.lines.count == 1)
        #expect(thumbnail.lines.first?.points.count == 2)
        #expect(thumbnail.lines.first?.points.first == RouteThumbnail.Point(latitude: route[0].latitude, longitude: route[0].longitude))
        #expect(thumbnail.lines.first?.points.last == RouteThumbnail.Point(latitude: route[200].latitude, longitude: route[200].longitude))
    }

    @Test("A winding Route is cut down to at most 48 points, keeping its ends")
    func budget() throws {
        let route = route(metres: 10_000, path: zigzag)

        let thumbnail = RouteThumbnail(route: route, pauses: [], averagePace: average)

        let line = try #require(thumbnail.lines.first)
        #expect(thumbnail.pointCount <= RouteThumbnail.maximumPoints)
        #expect(thumbnail.pointCount > 2)
        #expect(line.points.first == RouteThumbnail.Point(latitude: route[0].latitude, longitude: route[0].longitude))
        #expect(line.points.last == RouteThumbnail.Point(latitude: route.last!.latitude, longitude: route.last!.longitude))
    }

    @Test("A short winding Route that fits the budget keeps every corner")
    func keepsCorners() throws {
        // Four 50 m legs: five corners including both ends.
        let route = route(metres: 200, path: zigzag)

        let thumbnail = RouteThumbnail(route: route, pauses: [], averagePace: average)

        #expect(thumbnail.lines.first?.points.count == 5)
    }

    @Test("The Route breaks at a Pause into one line per stretch")
    func breaksAtPauses() {
        var route = route(metres: 1_000)
        // A 60 s Pause between the 500 m and 510 m points.
        for index in 51..<route.count { route[index].timestamp += 60 }
        let pause = Pause(start: route[50].timestamp + 1, end: route[51].timestamp - 1)

        let thumbnail = RouteThumbnail(route: route, pauses: [pause], averagePace: average)

        #expect(thumbnail.lines.count == 2)
        #expect(thumbnail.lines.allSatisfy { $0.points.count == 2 })
    }

    @Test("Each segment keeps the Pace color of the stretch it stands for")
    func colors() throws {
        // A fast first kilometre (5:00 /km), then a slow one (7:00 /km), around a corner at 1 km
        // so the halves stay separate segments.
        let route = route(metres: 2_000, secondsPerMetre: { $0 < 1_000 ? 0.30 : 0.42 }, path: { $0 < 1_000 ? (0, $0) : ($0 - 1_000, 1_000) })

        let thumbnail = RouteThumbnail(route: route, pauses: [], averagePace: average)

        let line = try #require(thumbnail.lines.first)
        #expect(line.colors.count == line.points.count - 1)
        #expect(try #require(line.colors.first).position < 0.1)
        #expect(try #require(line.colors.last).position > 0.9)
    }

    @Test("Without an Average pace every segment is the middle color")
    func noAverage() throws {
        let thumbnail = RouteThumbnail(route: route(metres: 500, secondsPerMetre: { $0 < 250 ? 0.3 : 0.42 }), pauses: [], averagePace: nil)

        #expect(thumbnail.lines.flatMap(\.colors).allSatisfy { abs($0.position - 0.5) < 0.01 })
    }

    @Test("A Route with nothing to draw has no lines")
    func empty() {
        #expect(RouteThumbnail(route: [], pauses: [], averagePace: nil).lines.isEmpty)
        #expect(RouteThumbnail(route: route(metres: 0), pauses: [], averagePace: nil).lines.isEmpty)
    }

    @Test("A thumbnail survives encoding and decoding, colors to within one 255th")
    func roundTrip() throws {
        let thumbnail = RouteThumbnail(route: route(metres: 3_000, secondsPerMetre: { 0.3 + $0 / 25_000 }, path: zigzag), pauses: [], averagePace: average)

        let decoded = try RouteThumbnail(decoding: thumbnail.encoded())

        #expect(decoded.lines.map(\.points) == thumbnail.lines.map(\.points))
        for (decodedLine, line) in zip(decoded.lines, thumbnail.lines) {
            for (decodedColor, color) in zip(decodedLine.colors, line.colors) {
                #expect(abs(decodedColor.position - color.position) <= 0.5 / 255 + 1e-9)
            }
        }
    }

    @Test("An empty thumbnail round-trips")
    func emptyRoundTrip() throws {
        let empty = RouteThumbnail(route: [], pauses: [], averagePace: nil)

        #expect(try RouteThumbnail(decoding: empty.encoded()).lines.isEmpty)
    }

    @Test("Decoding refuses an unknown version")
    func unknownVersion() {
        var data = RouteThumbnail(route: route(metres: 100), pauses: [], averagePace: nil).encoded()
        data[data.startIndex] = 99

        #expect(throws: RouteThumbnail.DecodingError.unsupportedVersion(99)) {
            try RouteThumbnail(decoding: data)
        }
    }

    @Test("Decoding refuses cut-off data")
    func truncated() {
        let data = RouteThumbnail(route: route(metres: 100), pauses: [], averagePace: nil).encoded()

        #expect(throws: RouteThumbnail.DecodingError.truncated) {
            try RouteThumbnail(decoding: data.dropLast(3))
        }
        #expect(throws: RouteThumbnail.DecodingError.truncated) {
            try RouteThumbnail(decoding: Data())
        }
    }
}
