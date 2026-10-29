import Foundation

/// One point of a Route: a fix that passed the noise filter, with the distance covered up to it.
public struct RoutePoint: Equatable, Sendable {
    public var timestamp: Date
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double
    public var horizontalAccuracy: Double
    /// Metres from the Run's first point to this one.
    public var cumulativeDistance: Double
    /// True for points that arrived during a Pause; they count for nothing.
    public var isPaused: Bool

    public init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        altitude: Double,
        horizontalAccuracy: Double,
        cumulativeDistance: Double,
        isPaused: Bool
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.cumulativeDistance = cumulativeDistance
        self.isPaused = isPaused
    }
}
