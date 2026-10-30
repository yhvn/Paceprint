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

/// What's drawn for a Run's Route: its stretches and Pace-colored pieces, start and finish.
struct RouteDrawing {
    struct Piece {
        let coordinates: [CLLocationCoordinate2D]
        let color: Color
    }

    let stretches: [[CLLocationCoordinate2D]]
    let pieces: [Piece]
    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D

    /// Nil if the Route can't be read, or has nothing to draw.
    init?(_ run: Run, palette: RoutePalette) {
        guard let route = try? run.decodedRoute() else { return nil }
        let stretches = PaceColoring.stretches(of: route, pauses: run.pauses)
        guard let start = stretches.first?.first, let end = stretches.last?.last else { return nil }
        self.stretches = stretches.map { $0.map(\.coordinate) }
        pieces = PaceColoring.pieces(of: route, pauses: run.pauses, averagePace: run.averagePace).map {
            Piece(coordinates: $0.points.map(\.coordinate), color: palette.color(for: $0.color))
        }
        self.start = start.coordinate
        self.end = end.coordinate
    }

    /// Frames the Route, with `roomBelow` times its height of empty map below it.
    func camera(roomBelow: Double) -> MapCameraPosition {
        let coordinates = Array(stretches.joined())
        let bounds = coordinates.map(MKMapPoint.init).reduce(MKMapRect.null) {
            $0.union(MKMapRect(origin: $1, size: MKMapSize(width: 0, height: 0)))
        }
        // At least ~200 m across, so a short Route isn't zoomed into a blur.
        let side = max(bounds.width, bounds.height, 200 * MKMapPointsPerMeterAtLatitude(coordinates[0].latitude))
        let route = MKMapRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side)
        let margin = side * 0.25
        return .rect(MKMapRect(x: route.minX - margin, y: route.minY - margin, width: side + 2 * margin, height: side * (1 + roomBelow) + 2 * margin))
    }
}

/// The start (red) or finish (green) of the Route: a colored dot in a white ring.
private struct EndpointDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .padding(3)
            .background(.white, in: Circle())
    }
}

private extension RoutePoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
