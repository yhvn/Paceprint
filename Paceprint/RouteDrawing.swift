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
        self.init(
            stretches: PaceColoring.stretches(of: route, pauses: run.pauses).map { $0.map(\.coordinate) },
            pieces: PaceColoring.pieces(of: route, pauses: run.pauses, averagePace: run.averagePace).map {
                Piece(coordinates: $0.points.map(\.coordinate), color: palette.color(for: $0.color))
            }
        )
    }

    /// The Run in progress so far, colored as the live map colors it (`PaceColoring.livePieces`); nil
    /// until it has something to draw.
    init?(live route: [RoutePoint], pauses: [Pause], averagePace: Pace?, palette: RoutePalette) {
        self.init(
            stretches: PaceColoring.stretches(of: route, pauses: pauses).map { $0.map(\.coordinate) },
            pieces: PaceColoring.livePieces(of: route, pauses: pauses, averagePace: averagePace).map {
                Piece(coordinates: $0.points.map(\.coordinate), color: palette.color(for: $0.color))
            }
        )
    }

    /// What a card draws from a Run's stored thumbnail; nil if it has nothing to draw.
    init?(_ thumbnail: RouteThumbnail, palette: RoutePalette) {
        let lines = thumbnail.lines.map { line in (line.points.map(\.coordinate), line.colors) }
        self.init(
            stretches: lines.map(\.0),
            pieces: lines.flatMap { coordinates, colors in
                // Neighbouring segments of one color are drawn as one piece, so their joins are round.
                var pieces: [(coordinates: [CLLocationCoordinate2D], color: PaceColor)] = []
                for (index, color) in colors.enumerated() {
                    if pieces.last?.color == color {
                        pieces[pieces.count - 1].coordinates.append(coordinates[index + 1])
                    } else {
                        pieces.append(([coordinates[index], coordinates[index + 1]], color))
                    }
                }
                return pieces.map { Piece(coordinates: $0.coordinates, color: palette.color(for: $0.color)) }
            }
        )
    }

    private init?(stretches: [[CLLocationCoordinate2D]], pieces: [Piece]) {
        guard let start = stretches.first?.first, let end = stretches.last?.last else { return nil }
        self.stretches = stretches
        self.pieces = pieces
        self.start = start
        self.end = end
        bounds = Self.bounds(of: stretches.joined().map(MKMapPoint.init), atLatitude: start.latitude)
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

    /// The stretch of map that fills `size` with the Route fitted into `band` the way `projection(into:)`
    /// fits it, so a map drawn behind it puts the Route on its own streets.
    func mapRect(fitting band: CGRect, in size: CGSize) -> MKMapRect {
        let scale = min(band.width / bounds.width, band.height / bounds.height)
        return MKMapRect(
            x: bounds.midX - band.midX / scale,
            y: bounds.midY - band.midY / scale,
            width: size.width / scale,
            height: size.height / scale
        )
    }

    /// How thick the Route is drawn.
    struct Style {
        let lineWidth: Double
        let haloWidth: Double
        /// The start and finish dots, white ring included.
        let dotDiameter: Double
        let dotRing: Double

        /// Over a photo or map that fills the screen.
        static let full = Style(lineWidth: 5, haloWidth: 10, dotDiameter: 18, dotRing: 3)
        /// On a card on Home or History.
        static let thumbnail = Style(lineWidth: 3.5, haloWidth: 6.5, dotDiameter: 9, dotRing: 1.5)

        /// How far in from its frame the Route is fitted, so the halo and dots aren't cut off at the edges.
        var inset: Double { max(haloWidth, dotDiameter) / 2 }
    }

    /// How far in from its frame the Route is fitted, so the halo and dots aren't cut off at the edges.
    static let haloInset = Style.full.inset

    /// Draws the Route into `context`, fitted into `rect`: a white halo under the Pace-colored pieces,
    /// with red start and green finish dots.
    func draw(in context: GraphicsContext, fittedInto rect: CGRect, style: Style = .full) {
        let place = projection(into: rect)
        func path(_ coordinates: [CLLocationCoordinate2D]) -> Path {
            Path { $0.addLines(coordinates.map(place)) }
        }
        for stretch in stretches {
            context.stroke(path(stretch), with: .color(Theme.Colors.routeHalo), style: StrokeStyle(lineWidth: style.haloWidth, lineCap: .round, lineJoin: .round))
        }
        for piece in pieces {
            context.stroke(path(piece.coordinates), with: .color(piece.color), style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round, lineJoin: .round))
        }
        for (coordinate, color) in [(start, Theme.Colors.liveRed), (end, Theme.Colors.paceFast)] {
            let center = place(coordinate)
            let outer = style.dotDiameter / 2, inner = outer - style.dotRing
            context.fill(Path(ellipseIn: CGRect(x: center.x - outer, y: center.y - outer, width: 2 * outer, height: 2 * outer)), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: center.x - inner, y: center.y - inner, width: 2 * inner, height: 2 * inner)), with: .color(color))
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
    @AppStorage(SettingsKey.units) private var units = DistanceUnit.kilometers
    /// Worked out once the overlay appears; nil until then, or if the Route has nothing to draw.
    @State private var route: RouteDrawing?

    var body: some View {
        Canvas { context, size in
            route?.draw(in: context, fittedInto: CGRect(origin: .zero, size: size).insetBy(dx: RouteDrawing.haloInset, dy: RouteDrawing.haloInset))
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(SpokenFormat.route(distance: run.distance, startingIn: run.placeName, units: units))
        .task {
            route = RouteDrawing(run, palette: .selected)
        }
    }
}

/// A Run's Route on a card on Home or History, drawn from its stored thumbnail so the Route is never
/// decoded (ADR 0001). Decorative: the card already says where the Run was.
struct RouteThumbnailView: View {
    let run: Run
    @AppStorage(SettingsKey.routePalette) private var palette = RoutePalette.pace

    var body: some View {
        let route = run.routeThumbnail.flatMap { RouteDrawing($0, palette: palette) }
        Canvas { context, size in
            // Room around the Route so its ends don't touch the card's edges.
            let inset = RouteDrawing.Style.thumbnail.inset + 8
            route?.draw(in: context, fittedInto: CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset), style: .thumbnail)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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

extension RoutePoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension RouteThumbnail.Point {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
