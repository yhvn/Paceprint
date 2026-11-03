import MapKit
import PaceprintCore
import SwiftUI

/// The dark map behind Active run: the Route so far in Pace colors, the runner's position, and a camera
/// that follows them. The line is redrawn every 5 s, recolored against the running Average pace
/// (#7); the position and camera keep up every second.
struct LiveRouteMap: View {
    /// Map to keep clear at the bottom for the metrics and controls over it, so the runner stays centred
    /// in what's visible.
    var roomBelow: CGFloat = 0
    @Environment(RunRecorder.self) private var recorder
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SettingsKey.routePalette) private var palette = RoutePalette.pace
    @State private var route: RouteDrawing?
    @State private var routeDrawnAt: Date?
    @State private var position: CLLocationCoordinate2D?
    @State private var camera = MapCameraPosition.automatic

    /// How often the whole line is recolored.
    static let recolorInterval: TimeInterval = 5
    /// How much of the map the camera shows around the runner, in metres from the ground.
    static let cameraDistance: CLLocationDistance = 2_500

    var body: some View {
        ZStack {
            Theme.Colors.mapNight
            if let position {
                map(position)
            }
        }
        .ignoresSafeArea()
        // The metrics over it say everything the line does.
        .accessibilityHidden(true)
        .task {
            while !Task.isCancelled {
                update(at: .now)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func map(_ position: CLLocationCoordinate2D) -> some View {
        Map(position: $camera, interactionModes: []) {
            if let route {
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
            }
            Annotation("You", coordinate: position, anchor: .center) { PositionDot(isPulsing: !reduceMotion) }
                .annotationTitles(.hidden)
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls {}
        .safeAreaPadding(.bottom, roomBelow)
    }

    /// Follows the runner, and redraws the line if it's due or there wasn't one yet.
    private func update(at now: Date) {
        let points = recorder.route
        guard let last = points.last(where: { !$0.isPaused }) ?? points.last else { return }
        let coordinate = last.coordinate
        let isFirst = position == nil
        position = coordinate
        let target = MapCameraPosition.camera(MapCamera(centerCoordinate: coordinate, distance: Self.cameraDistance))
        if isFirst || reduceMotion {
            camera = target
        } else {
            withAnimation(.linear(duration: 1)) { camera = target }
        }
        if route == nil || routeDrawnAt.map({ now.timeIntervalSince($0) >= Self.recolorInterval }) ?? true {
            route = RouteDrawing(live: points, pauses: recorder.pauses, averagePace: recorder.averagePace, palette: palette)
            routeDrawnAt = now
        }
    }
}

/// Where the runner is now: a white dot in a green ring, with a soft pulse unless Reduce Motion is on.
private struct PositionDot: View {
    let isPulsing: Bool
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 34, height: 34)
                .scaleEffect(isPulsing && isExpanded ? 1.6 : 1)
                .opacity(isPulsing && isExpanded ? 0 : 1)
            Circle()
                .fill(.white)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Theme.Colors.paceFast, lineWidth: 3))
        }
        .onAppear {
            guard isPulsing else { return }
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) { isExpanded = true }
        }
    }
}
