import Foundation

/// One location reading as the system reported it, before the noise filter.
public struct LocationFix: Equatable, Sendable {
    public var timestamp: Date
    public var latitude: Double
    public var longitude: Double
    /// Metres above sea level.
    public var altitude: Double
    /// Radius of uncertainty in metres; negative means the coordinate is invalid.
    public var horizontalAccuracy: Double

    public init(timestamp: Date, latitude: Double, longitude: Double, altitude: Double, horizontalAccuracy: Double) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
    }
}
