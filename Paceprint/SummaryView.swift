import MapKit
import PaceprintCore
import SwiftUI

/// Summary: a Run's Route in Pace colors on a dark map, its date where the Place name will go,
/// and its headline numbers. Opens after Stop and from History.
struct SummaryView: View {
    let run: Run
    @Environment(\.dismiss) private var dismiss
    /// Worked out once Summary appears, not when it's created: History creates one per row.
    @State private var route: RouteDrawing?

    var body: some View {
        ZStack {
            Theme.Colors.mapNight
                .ignoresSafeArea()
            if let route {
                map(route)
                    .ignoresSafeArea()
            }

            LinearGradient(
                stops: [
                    .init(color: Theme.Colors.photoTop, location: 0),
                    .init(color: Theme.Colors.photoMid, location: 0.3),
                    .init(color: Theme.Colors.photoMid, location: 0.6),
                    .init(color: Theme.Colors.photoBottom, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 28) {
                topBar
                Spacer()
                placeArea
                metrics
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 32)
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .task {
            route = RouteDrawing(run, palette: .selected)
        }
    }

    private func map(_ route: RouteDrawing) -> some View {
        Map(initialPosition: route.camera ?? .automatic) {
            // A faint white halo under the colored pieces, so the line reads on any map.
            ForEach(route.stretches.indices, id: \.self) { index in
                MapPolyline(coordinates: route.stretches[index])
                    .stroke(Theme.Colors.routeHalo, style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
            }
            ForEach(route.pieces.indices, id: \.self) { index in
                MapPolyline(coordinates: route.pieces[index].coordinates)
                    .stroke(route.pieces[index].color, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
            if let start = route.start, let end = route.end {
                Annotation("Start", coordinate: start, anchor: .center) { EndpointDot(color: Theme.Colors.liveRed) }
                    .annotationTitles(.hidden)
                Annotation("Finish", coordinate: end, anchor: .center) { EndpointDot(color: Theme.Colors.paceFast) }
                    .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls {}
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Theme.Colors.glass, in: Circle())
                    .overlay(Circle().stroke(Theme.Colors.glassBorder))
            }
            .accessibilityLabel("Close")
            Spacer()
            Text("PACEPRINT")
                .font(Theme.Typography.label)
                .tracking(Theme.Typography.wordmarkTracking)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            // Keeps the wordmark centred until Share takes this place.
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.top, 8)
    }

    private var placeArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(run.startDate, format: .dateTime.weekday(.wide))
                .font(Theme.Typography.placeName)
                .foregroundStyle(Theme.Colors.textPrimary)
                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            Text(run.startDate.formatted(.dateTime.day().month(.abbreviated).year().hour().minute()).uppercased())
                .font(Theme.Typography.label)
                .tracking(Theme.Typography.labelTracking)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private var metrics: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 22) {
            GridRow {
                Metric(label: "KM", value: RunFormat.kilometres(run.distance), size: .xl, alignment: .leading)
                Metric(label: "TIME", value: RunFormat.time(run.movingTime), size: .xl, alignment: .leading)
            }
            GridRow {
                Metric(label: "AVG PACE /KM", value: RunFormat.pace(route?.averagePace), size: .lg, alignment: .leading)
                // Calories arrive with Settings, which asks for body weight.
                Metric(label: "CAL (EST)", value: "—", size: .lg, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// What Summary draws for a Run: its Route cut into stretches and Pace-colored pieces.
private struct RouteDrawing {
    struct Piece {
        let coordinates: [CLLocationCoordinate2D]
        let color: Color
    }

    let stretches: [[CLLocationCoordinate2D]]
    let pieces: [Piece]
    let start: CLLocationCoordinate2D?
    let end: CLLocationCoordinate2D?
    let averagePace: Pace?
    /// Frames the Route in the top half of the screen, clear of the place name and metrics below.
    let camera: MapCameraPosition?

    /// Nil if the Route can't be read.
    init?(_ run: Run, palette: RoutePalette) {
        guard let tracker = try? run.resumedTracker() else { return nil }
        let averagePace = tracker.averagePace(at: run.endDate)
        let stretches = PaceColoring.stretches(of: tracker.points, pauses: tracker.pauses)
        self.stretches = stretches.map { $0.map(\.coordinate) }
        pieces = PaceColoring.pieces(of: tracker.points, pauses: tracker.pauses, averagePace: averagePace).map {
            Piece(coordinates: $0.points.map(\.coordinate), color: palette.color(for: $0.color))
        }
        start = stretches.first?.first?.coordinate
        end = stretches.last?.last?.coordinate
        self.averagePace = averagePace
        camera = Self.camera(framing: stretches.joined().map(\.coordinate))
    }

    private static func camera(framing coordinates: [CLLocationCoordinate2D]) -> MapCameraPosition? {
        guard !coordinates.isEmpty else { return nil }
        let bounds = coordinates.map(MKMapPoint.init).reduce(MKMapRect.null) {
            $0.union(MKMapRect(origin: $1, size: MKMapSize(width: 0, height: 0)))
        }
        // At least ~200 m across, so a short Route isn't zoomed into a blur.
        let side = max(bounds.width, bounds.height, 200 * MKMapPointsPerMeterAtLatitude(coordinates[0].latitude))
        let route = MKMapRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side)
        // A margin all round, plus as much again below for the place name and metrics.
        let margin = side * 0.25
        return .rect(MKMapRect(x: route.minX - margin, y: route.minY - margin, width: side + 2 * margin, height: side * 2 + 2 * margin))
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
