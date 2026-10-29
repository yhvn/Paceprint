import Foundation

/// Builds a Run's Route as fixes arrive: drops noisy fixes and keeps a running distance.
public struct RouteTracker: Sendable {
    public let runStart: Date
    public private(set) var points: [RoutePoint] = []

    /// Metres covered so far.
    public var distance: Double { points.last?.cumulativeDistance ?? 0 }

    public init(runStart: Date) {
        self.runStart = runStart
    }

    /// Adds `fix` to the Route if it passes the noise filter, returning the new point, else nil.
    public mutating func add(_ fix: LocationFix) -> RoutePoint? {
        let last = points.last
        guard NoiseFilter.accepts(fix, runStart: runStart, after: last) else { return nil }

        var cumulativeDistance = 0.0
        if let last {
            cumulativeDistance = last.cumulativeDistance + Distance.between(
                latitude: last.latitude, longitude: last.longitude,
                andLatitude: fix.latitude, longitude: fix.longitude
            )
        }
        let point = RoutePoint(
            timestamp: fix.timestamp,
            latitude: fix.latitude,
            longitude: fix.longitude,
            altitude: fix.altitude,
            horizontalAccuracy: fix.horizontalAccuracy,
            cumulativeDistance: cumulativeDistance,
            isPaused: false
        )
        points.append(point)
        return point
    }
}
