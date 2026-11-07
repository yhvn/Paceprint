import MapboxMaps
import PaceprintCore
import SwiftUI

/// A Run's Route in Pace colors on the dark map: a white halo under Pace-colored pieces, with
/// red start and green finish dots. Plain dark background when there's no Route to draw.
struct RouteMap: View {
    let run: Run
    @AppStorage(SettingsKey.units) private var units = DistanceUnit.kilometers
    /// Empty map to leave below the Route, as a multiple of its height, for whatever sits over it.
    var roomBelow = 0.0
    /// Worked out once the map appears; nil until then, or if the Route has nothing to draw.
    @State private var route: RouteDrawing?

    var body: some View {
        ZStack {
            Theme.Colors.mapNight
            if let route {
                map(route)
            }
        }
        // One element; the Pace colors are never the only way to tell the Route.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SpokenFormat.routeMap(distance: run.distance, startingIn: run.placeName, units: units))
        .task {
            route = RouteDrawing(run, palette: .selected)
        }
    }

    private func map(_ route: RouteDrawing) -> some View {
        Map(initialViewport: route.viewport(roomBelow: roomBelow)) {
            RouteLine(route: route)
            MapViewAnnotation(coordinate: route.start) { EndpointDot(color: Theme.Colors.liveRed) }
                .allowOverlap(true)
            MapViewAnnotation(coordinate: route.end) { EndpointDot(color: Theme.Colors.paceFast) }
                .allowOverlap(true)
        }
        .mapStyle(Mapbox.style)
        .ornamentOptions(.paceprint())
    }
}
