import Foundation
import MapboxMaps
import SwiftUI
import UIKit

/// Paceprint's maps come from Mapbox (ADR 0005): its Standard style lit for night, with the Route
/// drawn over it as everywhere else.
enum Mapbox {
    /// Every map in the app, the Story card's included: Mapbox Standard, default except night lighting.
    static let style = MapStyle.standard(lightPreset: .night)

    /// The key Mapbox's SDK reads to decide whether it sends its usage telemetry, and writes when the
    /// user switches it in the map's (i) menu.
    static let telemetryKey = "MGLMapboxMetricsEnabled"

    /// Turns Mapbox's telemetry off unless the user has chosen for themselves in the (i) menu. Stored,
    /// not registered: the SDK registers `true` as its own default when it starts, which would win.
    static func turnOffTelemetryUnlessChosen(in defaults: UserDefaults = .standard, domain: String? = Bundle.main.bundleIdentifier) {
        guard let domain, defaults.persistentDomain(forName: domain)?[telemetryKey] == nil else { return }
        defaults.set(false, forKey: telemetryKey)
    }
}

/// A Route on a Mapbox map: a white halo under its Pace-colored pieces, as `RouteDrawing.draw` draws it
/// on a photo.
struct RouteLine: MapStyleContent {
    let route: RouteDrawing
    var lineWidth = 6.0
    var haloWidth = 12.0

    var body: some MapStyleContent {
        GeoJSONSource(id: "route-halo")
            .data(.geometry(.multiLineString(MultiLineString(route.stretches))))
        GeoJSONSource(id: "route-pieces")
            .data(.featureCollection(FeatureCollection(features: route.pieces.map { piece in
                var feature = Feature(geometry: LineString(piece.coordinates))
                feature.properties = ["color": .string(piece.color.cssRGBA)]
                return feature
            })))
        LineLayer(id: "route-halo", source: "route-halo")
            .lineColor(UIColor(Theme.Colors.routeHalo))
            .lineWidth(haloWidth)
            .lineCap(.round)
            .lineJoin(.round)
            // Lit by nothing: Standard's night lighting would otherwise dim the line with the map.
            .lineEmissiveStrength(1)
        LineLayer(id: "route-pieces", source: "route-pieces")
            .lineColor(Exp(.toColor) { Exp(.get) { "color" } })
            .lineWidth(lineWidth)
            .lineCap(.round)
            .lineJoin(.round)
            .lineEmissiveStrength(1)
    }
}

extension Color {
    /// As a CSS `rgba(…)` string, the form a Mapbox style expression turns into a color.
    var cssRGBA: String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func channel(_ value: CGFloat) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return "rgba(\(channel(red)), \(channel(green)), \(channel(blue)), \(alpha))"
    }
}

extension GestureOptions {
    /// A map that can't be touched: no panning, zooming, rotating or tilting.
    static var none: GestureOptions {
        var options = GestureOptions()
        options.panEnabled = false
        options.pinchEnabled = false
        options.rotateEnabled = false
        options.pitchEnabled = false
        options.doubleTapToZoomInEnabled = false
        options.doubleTouchToZoomOutEnabled = false
        options.quickZoomEnabled = false
        return options
    }
}

extension OrnamentOptions {
    /// Only what Mapbox requires on every map: its logo and the (i) attribution button, here raised by
    /// `bottom` points so whatever sits over the map's bottom edge doesn't cover them. No compass or
    /// scale bar.
    static func paceprint(bottom: CGFloat = 0) -> OrnamentOptions {
        OrnamentOptions(
            scaleBar: ScaleBarViewOptions(visibility: .hidden),
            compass: CompassViewOptions(visibility: .hidden),
            logo: LogoViewOptions(position: .bottomLeading, margins: CGPoint(x: 8, y: 8 + bottom)),
            attributionButton: AttributionButtonOptions(position: .bottomTrailing, margins: CGPoint(x: 8, y: 8 + bottom))
        )
    }
}
