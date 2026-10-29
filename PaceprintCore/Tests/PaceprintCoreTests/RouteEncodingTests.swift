import Foundation
import Testing
import PaceprintCore

private let points = [
    RoutePoint(
        timestamp: Date(timeIntervalSinceReferenceDate: 800_000_000.25),
        latitude: 40.7800001, longitude: -73.9660002, altitude: 31.5,
        horizontalAccuracy: 4.7, cumulativeDistance: 0, isPaused: false
    ),
    RoutePoint(
        timestamp: Date(timeIntervalSinceReferenceDate: 800_000_004.5),
        latitude: 40.7801003, longitude: -73.9660004, altitude: -2,
        horizontalAccuracy: 12, cumulativeDistance: 11.1195, isPaused: true
    ),
]

@Suite("Route encoding")
struct RouteEncodingTests {
    @Test("A Route survives encoding and decoding unchanged")
    func roundTrip() throws {
        let data = RouteEncoding.encode(points)

        #expect(try RouteEncoding.decode(data) == points)
    }

    @Test("An empty Route round-trips")
    func empty() throws {
        #expect(try RouteEncoding.decode(RouteEncoding.encode([])) == [])
    }

    @Test("The blob starts with format version 1")
    func versionByte() {
        #expect(RouteEncoding.encode(points).first == 1)
    }

    @Test("An unknown format version is refused")
    func unknownVersion() {
        var data = RouteEncoding.encode(points)
        data[data.startIndex] = 99

        #expect(throws: RouteEncoding.DecodingError.unsupportedVersion(99)) {
            try RouteEncoding.decode(data)
        }
    }

    @Test("A truncated blob is refused")
    func truncated() {
        let data = RouteEncoding.encode(points).dropLast(3)

        #expect(throws: RouteEncoding.DecodingError.truncated) {
            try RouteEncoding.decode(Data(data))
        }
    }
}
