import CoreLocation
import PaceprintCore

/// Finds what's at a point on the map. The app's seam for reverse geocoding, faked in tests.
protocol PlaceLookup {
    /// What's at the point, nil if the lookup worked but found nothing; throws if it couldn't be
    /// done, e.g. offline, so it can be tried again later.
    func placemark(latitude: Double, longitude: Double) async throws -> Placemark?
}

/// Looks points up with Apple's reverse geocoder; names come in the device's language.
struct GeocoderPlaceLookup: PlaceLookup {
    func placemark(latitude: Double, longitude: Double) async throws -> Placemark? {
        let found: [CLPlacemark]
        do {
            found = try await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude))
        } catch CLError.geocodeFoundNoResult {
            return nil
        }
        guard let placemark = found.first else { return nil }
        return Placemark(
            areasOfInterest: placemark.areasOfInterest ?? [],
            // Not the county (subAdministrativeArea): "New York County" means little to a runner.
            neighbourhood: placemark.subLocality,
            city: placemark.locality,
            region: placemark.administrativeArea,
            country: placemark.country
        )
    }
}
