import MapKit
import PaceprintCore
import SwiftUI

/// A Run's Route in Pace colors on the dark map: a white halo under Pace-colored pieces, with
/// red start and green finish dots. Plain dark background when there's no Route to draw.
struct RouteMap: View {
    let run: Run
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
        .task {
            route = RouteDrawing(run, palette: .selected)
        }
    }

    private func map(_ route: RouteDrawing) -> some View {
        Map(initialPosition: route.camera(roomBelow: roomBelow)) {
            // A faint white halo under the colored pieces, so the line reads on any map.
            ForEach(route.stretches.indices, id: \.self) { index in
                MapPolyline(coordinates: route.stretches[index])
                    .stroke(Theme.Colors.routeHalo, style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
            }
            ForEach(route.pieces.indices, id: \.self) { index in
                MapPolyline(coordinates: route.pieces[index].coordinates)
                    .stroke(route.pieces[index].color, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
            Annotation("Start", coordinate: route.start, anchor: .center) { EndpointDot(color: Theme.Colors.liveRed) }
                .annotationTitles(.hidden)
            Annotation("Finish", coordinate: route.end, anchor: .center) { EndpointDot(color: Theme.Colors.paceFast) }
                .annotationTitles(.hidden)
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls {}
    }
}
