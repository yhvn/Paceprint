import CoreLocation
import MapboxMaps
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
    @State private var viewport = Viewport.styleDefault

    /// How often the whole line is recolored.
    static let recolorInterval: TimeInterval = 5
    /// How close the camera is to the runner: a few blocks of streets around them.
    static let cameraZoom = 14.5

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
        Map(viewport: $viewport) {
            if let route {
                RouteLine(route: route)
                MapViewAnnotation(coordinate: route.start) { EndpointDot(color: Theme.Colors.liveRed) }
                    .allowOverlap(true)
            }
            MapViewAnnotation(coordinate: position) { PositionDot(isPulsing: !reduceMotion) }
                .allowOverlap(true)
        }
        .mapStyle(Mapbox.style)
        .gestureOptions(.none)
        // Just above the panel over the map's bottom, where they're seen and the (i) can be tapped.
        .ornamentOptions(.paceprint(bottom: roomBelow))
    }

    /// Follows the runner, and redraws the line if it's due or there wasn't one yet.
    private func update(at now: Date) {
        let points = recorder.route
        guard let last = points.last(where: { !$0.isPaused }) ?? points.last else { return }
        let coordinate = last.coordinate
        let isFirst = position == nil
        position = coordinate
        // Padded so the runner sits in the middle of the map left visible above the panel.
        let target = Viewport.camera(center: coordinate, zoom: Self.cameraZoom).padding(.bottom, roomBelow)
        if isFirst || reduceMotion {
            viewport = target
        } else {
            withViewportAnimation(.linear(duration: 1)) { viewport = target }
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
