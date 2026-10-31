import MapKit
import PaceprintCore
import SwiftUI

/// What a RouteMap or RouteOverlay draws for a Run: its Route cut into stretches and Pace-colored pieces.
struct RouteDrawing {
    struct Piece {
        let coordinates: [CLLocationCoordinate2D]
        let color: Color
    }

    let stretches: [[CLLocationCoordinate2D]]
    let pieces: [Piece]
    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D
    /// The Route's extent, at least ~200 m each way so a short Route isn't zoomed into a blur.
    private let bounds: MKMapRect

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
        bounds = Self.bounds(of: self.stretches.joined().map(MKMapPoint.init), atLatitude: start.latitude)
    }

    /// Frames the Route on a map, with `roomBelow` times its height of empty map below it.
    func camera(roomBelow: Double) -> MapCameraPosition {
        let side = max(bounds.width, bounds.height)
        let route = MKMapRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side)
        let margin = side * 0.25
        return .rect(MKMapRect(x: route.minX - margin, y: route.minY - margin, width: side + 2 * margin, height: side * (1 + roomBelow) + 2 * margin))
    }

    /// Where each coordinate lands when the Route is fitted into `rect`, centred, north up.
    func projection(into rect: CGRect) -> (CLLocationCoordinate2D) -> CGPoint {
        let bounds = bounds
        let scale = min(rect.width / bounds.width, rect.height / bounds.height)
        return { coordinate in
            let point = MKMapPoint(coordinate)
            return CGPoint(x: rect.midX + (point.x - bounds.midX) * scale, y: rect.midY + (point.y - bounds.midY) * scale)
        }
    }

    private static func bounds(of points: [MKMapPoint], atLatitude latitude: CLLocationDegrees) -> MKMapRect {
        let tight = points.reduce(MKMapRect.null) { $0.union(MKMapRect(origin: $1, size: MKMapSize(width: 0, height: 0))) }
        let minimum = 200 * MKMapPointsPerMeterAtLatitude(latitude)
        let width = max(tight.width, minimum), height = max(tight.height, minimum)
        return MKMapRect(x: tight.midX - width / 2, y: tight.midY - height / 2, width: width, height: height)
    }
}

/// A Run's Route in Pace colors drawn straight over its photo: a white halo under the Pace-colored pieces,
/// with red start and green finish dots, fitted into the space it's given.
struct RouteOverlay: View {
    let run: Run
    /// Worked out once the overlay appears; nil until then, or if the Route has nothing to draw.
    @State private var route: RouteDrawing?

    var body: some View {
        Canvas { context, size in
            guard let route else { return }
            // Inset by the halo's half-width, so the line isn't cut off at the edges.
            let place = route.projection(into: CGRect(origin: .zero, size: size).insetBy(dx: 9, dy: 9))
            func path(_ coordinates: [CLLocationCoordinate2D]) -> Path {
                Path { $0.addLines(coordinates.map(place)) }
            }
            for stretch in route.stretches {
                context.stroke(path(stretch), with: .color(Theme.Colors.routeHalo), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
            }
            for piece in route.pieces {
                context.stroke(path(piece.coordinates), with: .color(piece.color), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            for (coordinate, color) in [(route.start, Theme.Colors.liveRed), (route.end, Theme.Colors.paceFast)] {
                let center = place(coordinate)
                context.fill(Path(ellipseIn: CGRect(x: center.x - 9, y: center.y - 9, width: 18, height: 18)), with: .color(.white))
                context.fill(Path(ellipseIn: CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12)), with: .color(color))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            route = RouteDrawing(run, palette: .selected)
        }
    }
}

/// The start (red) or finish (green) of the Route on a map: a colored dot in a white ring.
struct EndpointDot: View {
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
