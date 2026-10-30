import MapKit
import SwiftUI

/// A Run's Route in Pace colors, drawn small with no map behind it, for Home and History cards.
struct RouteThumbnail: View {
    let run: Run
    var lineWidth: CGFloat = 2.5
    @State private var route: RouteDrawing?

    var body: some View {
        Canvas { context, size in
            guard let route else { return }
            let project = projection(of: route, into: size)
            for piece in route.pieces {
                var path = Path()
                path.addLines(piece.coordinates.map(project))
                context.stroke(path, with: .color(piece.color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
            for (coordinate, color) in [(route.start, Theme.Colors.liveRed), (route.end, Theme.Colors.paceFast)] {
                let point = project(coordinate)
                let ring = lineWidth * 2.2, dot = lineWidth * 1.4
                context.fill(Path(ellipseIn: CGRect(x: point.x - ring, y: point.y - ring, width: ring * 2, height: ring * 2)), with: .color(.white))
                context.fill(Path(ellipseIn: CGRect(x: point.x - dot, y: point.y - dot, width: dot * 2, height: dot * 2)), with: .color(color))
            }
        }
        .accessibilityHidden(true)
        .task(id: run.id) {
            route = RouteDrawing(run, palette: .selected)
        }
    }

    /// Fits the Route into `size`, keeping its shape, with a margin for the line and dots.
    private func projection(of route: RouteDrawing, into size: CGSize) -> (CLLocationCoordinate2D) -> CGPoint {
        let bounds = route.bounds
        let margin = lineWidth * 4
        let scale = min(
            (size.width - 2 * margin) / max(bounds.width, 1),
            (size.height - 2 * margin) / max(bounds.height, 1)
        )
        let offset = CGPoint(x: (size.width - bounds.width * scale) / 2, y: (size.height - bounds.height * scale) / 2)
        return { coordinate in
            let point = MKMapPoint(coordinate)
            return CGPoint(x: offset.x + (point.x - bounds.minX) * scale, y: offset.y + (point.y - bounds.minY) * scale)
        }
    }
}
