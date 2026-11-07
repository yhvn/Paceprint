import Foundation
import MapKit
import Testing
@testable import Paceprint

/// Maps come from Mapbox, with its telemetry off unless the user turns it on (ADR 0005).
@Suite("Mapbox")
struct MapboxTests {
    /// A defaults store of its own, empty, so the tests never touch the app's.
    private func freshDefaults() throws -> (UserDefaults, String) {
        let domain = "MapboxTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        return (defaults, domain)
    }

    @Test("Telemetry is turned off when the user has never chosen")
    func telemetryOffByDefault() throws {
        let (defaults, domain) = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: domain) }

        Mapbox.turnOffTelemetryUnlessChosen(in: defaults, domain: domain)

        #expect(defaults.object(forKey: Mapbox.telemetryKey) as? Bool == false)
    }

    @Test("Telemetry the user turned on in the (i) menu stays on")
    func usersChoiceKept() throws {
        let (defaults, domain) = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: Mapbox.telemetryKey)

        Mapbox.turnOffTelemetryUnlessChosen(in: defaults, domain: domain)

        #expect(defaults.bool(forKey: Mapbox.telemetryKey) == true)
    }

    @Test("A default the SDK registers doesn't count as the user's choice")
    func registeredDefaultIgnored() throws {
        let (defaults, domain) = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.register(defaults: [Mapbox.telemetryKey: true])

        Mapbox.turnOffTelemetryUnlessChosen(in: defaults, domain: domain)

        #expect(defaults.bool(forKey: Mapbox.telemetryKey) == false)
    }

    @Test("The app carries a real Mapbox public token, not the example's placeholder")
    func accessToken() throws {
        let token = try #require(Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String)

        #expect(token.hasPrefix("pk."))
        #expect(token != "pk.your-token-here")
    }

    @Test("The Story card's map is zoomed so the framed stretch of map spans the card exactly")
    func storyCardZoom() {
        let world = MKMapRect(origin: MKMapPoint(x: 0, y: 0), size: MKMapSize.world)

        #expect(StoryCardBackground.zoom(showing: world, across: 512) == 0)
        #expect(StoryCardBackground.zoom(showing: world, across: 1_024) == 1)
        let quarter = MKMapRect(x: 0, y: 0, width: MKMapSize.world.width / 4, height: MKMapSize.world.height / 4)
        #expect(StoryCardBackground.zoom(showing: quarter, across: 512) == 2)
    }
}
