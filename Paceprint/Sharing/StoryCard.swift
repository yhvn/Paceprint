// MapKit for its Web Mercator math only, to frame the Mapbox snapshot.
import MapKit
import MapboxMaps
import os
import PaceprintCore
import SwiftUI

/// The Story card: one Run as a 9:16 image to share, over its photo or the dark map, with its Route
/// fitted into a band of its own so it never crosses the text (unlike Summary's full-bleed Route).
/// Everything it shows is handed to it, so it can be rendered straight away.
struct StoryCard: View {
    /// Where things sit on the card, in points; rendered at 3× for 1080 × 1920 pixels.
    enum Layout {
        static let size = CGSize(width: 360, height: 640)
        static let scale = 3.0
        static let wordmarkTop = 28.0
        static let wordmarkBottom = 48.0
        /// The Route's band, between the wordmark and the Place name.
        static let routeBand = CGRect(x: 36, y: 64, width: 288, height: 250)
        /// Where the Route itself is fitted, inside its band; the map behind is framed to match.
        static let routeFrame = routeBand.insetBy(dx: RouteDrawing.haloInset, dy: RouteDrawing.haloInset)
        static let placeTop = 330.0
        static let metricsBottom = 48.0
        static let footerBottom = 20.0
        /// Over the map, the footer sits higher, clear of Mapbox's logo and attribution along the bottom.
        static let footerBottomOverMap = 34.0
    }

    let run: Run
    /// The Run's photo with its filter, or the dark map framed to its Route; nil draws plain dark.
    let background: StoryCardBackground?
    let route: RouteDrawing?

    var body: some View {
        ZStack {
            Theme.Colors.mapNight
            if let background {
                // Filling a fixed frame, so a photo of another shape can't stretch the card.
                Color.clear
                    .overlay {
                        Image(decorative: background.image, scale: Layout.scale)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            }
            if background?.isScrimmed != true {
                ScrimGradient(stops: .storyCard, scrim: run.scrim)
            }
            Canvas { context, _ in
                route?.draw(in: context, fittedInto: Layout.routeFrame)
            }
            text
        }
        .frame(width: Layout.size.width, height: Layout.size.height)
        .clipped()
        .environment(\.colorScheme, .dark)
        // A fixed image: the design's look, whatever the text size or contrast settings.
        .environment(\.isStoryCard, true)
        .dynamicTypeSize(.large)
    }

    private var text: some View {
        ZStack {
            Text("PACEPRINT")
                .font(Theme.Typography.label)
                .tracking(Theme.Typography.wordmarkTracking)
                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.85))
                .padding(.top, Layout.wordmarkTop)
                .frame(maxHeight: .infinity, alignment: .top)
            // One line, so the block stays between the Route's band and the metrics; a long Place name
            // shrinks further than elsewhere rather than being cut off.
            RunHeadline(run: run, font: .system(size: 44, weight: .heavy), nameLines: 1, nameMinimumScale: 0.4)
                .padding(.top, Layout.placeTop)
                .padding(.horizontal, 22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            RunMetrics(run: run, large: .lg, small: .md)
                .padding(.horizontal, 22)
                .padding(.bottom, Layout.metricsBottom)
                .frame(maxHeight: .infinity, alignment: .bottom)
            Text("SHARED VIA PACEPRINT")
                .font(Theme.Typography.label)
                .tracking(Theme.Typography.wordmarkTracking * 0.75)
                .foregroundStyle(Theme.Colors.textTertiary)
                .padding(.bottom, background?.isScrimmed == true ? Layout.footerBottomOverMap : Layout.footerBottom)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    /// The card as a 1080 × 1920 image.
    func rendered() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = Layout.scale
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// What a Story card is drawn over: the Run's photo with its filter, or the dark map.
struct StoryCardBackground {
    let image: CGImage
    /// Whether the card's scrim is already drawn into `image`: a map's is, under Mapbox's logo and
    /// attribution, so the card's gradient never hides them.
    var isScrimmed = false

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Paceprint", category: "StoryCard")

    /// The Run's photo with its filter; without one, or if its file can't be read, the night map
    /// framed so `route` lands on its streets. Nil if neither can be had, e.g. offline with no photo:
    /// the card is then plain dark. The map can only be drawn while the app is in front.
    @MainActor
    static func load(for run: Run, route: RouteDrawing?) async -> StoryCardBackground? {
        if let fileName = run.photoFileName {
            // Decoded at the stored size, so a landscape photo filling the card's height isn't stretched.
            if let photo = await RunPhotoStore.shared.image(fileName, filter: run.photoFilter, maxPixelSize: RunPhotoStore.longestSide) {
                return StoryCardBackground(image: photo)
            }
            logger.error("Couldn't read a Run's photo for its Story card; using the map")
        }
        guard let route else { return nil }
        let size = StoryCard.Layout.size
        let rect = route.mapRect(fitting: StoryCard.Layout.routeFrame, in: size)
        let snapshotter = Snapshotter(options: MapSnapshotOptions(size: size, pixelRatio: StoryCard.Layout.scale))
        snapshotter.mapStyle = Mapbox.style
        snapshotter.setCamera(to: CameraOptions(center: MKMapPoint(x: rect.midX, y: rect.midY).coordinate, zoom: zoom(showing: rect, across: size.width)))
        let scrim = scrimImage(for: run)
        let result = await withCheckedContinuation { continuation in
            snapshotter.start(overlayHandler: { overlay in
                // Drawn after the map and before Mapbox's logo and attribution, which land on top.
                guard let scrim else { return }
                overlay.context.saveGState()
                // Flipped back: the context is UIKit's, top down, and a CGImage draws bottom up.
                overlay.context.translateBy(x: 0, y: size.height)
                overlay.context.scaleBy(x: 1, y: -1)
                overlay.context.draw(scrim, in: CGRect(origin: .zero, size: size))
                overlay.context.restoreGState()
            }, completion: { continuation.resume(returning: $0) })
        }
        switch result {
        case .success(let map):
            guard let image = map.cgImage else { return nil }
            return StoryCardBackground(image: image, isScrimmed: scrim != nil)
        case .failure(let error):
            logger.error("Couldn't draw the map for a Story card: \(error)")
            return nil
        }
    }

    /// The Mapbox zoom at which `rect` spans `width` points: at zoom 0 the whole world, which MapKit
    /// measures as `MKMapSize.world.width` map points, is 512 points wide.
    static func zoom(showing rect: MKMapRect, across width: CGFloat) -> Double {
        log2(width / rect.width * MKMapSize.world.width / 512)
    }

    /// The card's scrim on its own, at the card's size and scale, to draw into the map.
    @MainActor
    private static func scrimImage(for run: Run) -> CGImage? {
        let renderer = ImageRenderer(content: ScrimGradient(stops: .storyCard, scrim: run.scrim)
            .frame(width: StoryCard.Layout.size.width, height: StoryCard.Layout.size.height)
            .environment(\.colorScheme, .dark)
            .environment(\.isStoryCard, true))
        renderer.scale = StoryCard.Layout.scale
        return renderer.cgImage
    }
}
