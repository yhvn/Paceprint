import Foundation

enum Distance {
    /// IUGG mean Earth radius, in metres.
    static let earthRadius = 6_371_008.8

    /// Great-circle (haversine) distance in metres between two coordinates in degrees.
    static func between(latitude lat1: Double, longitude lon1: Double, andLatitude lat2: Double, longitude lon2: Double) -> Double {
        let φ1 = lat1 * .pi / 180
        let φ2 = lat2 * .pi / 180
        let Δφ = φ2 - φ1
        let Δλ = (lon2 - lon1) * .pi / 180
        let a = sin(Δφ / 2) * sin(Δφ / 2) + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
        return 2 * earthRadius * asin(min(1, sqrt(a)))
    }
}
