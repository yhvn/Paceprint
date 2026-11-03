import MapKit
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
            ScrimGradient(stops: .storyCard, scrim: run.scrim)
            Canvas { context, _ in
                route?.draw(in: context, fittedInto: Layout.routeFrame)
            }
            text
        }
        .frame(width: Layout.size.width, height: Layout.size.height)
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    private var text: some View {
        ZStack {
            Text("PACEPRINT")
                .font(Theme.Typography.label)
                .tracking(Theme.Typography.wordmarkTracking)
                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.85))
                .padding(.top, Layout.wordmarkTop)
                .frame(maxHeight: .infinity, alignment: .top)
            // One line, so the block stays between the Route's band and the metrics.
            RunHeadline(run: run, font: .system(size: 44, weight: .heavy), nameLines: 1)
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
                .padding(.bottom, Layout.footerBottom)
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
/// A map snapshot carries Apple's Maps mark itself.
struct StoryCardBackground {
    let image: CGImage

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Paceprint", category: "StoryCard")

    /// The Run's photo with its filter; without one, or if its file can't be read, the dark muted map
    /// framed so `route` lands on its streets. Nil if neither can be had, e.g. offline with no photo:
    /// the card is then plain dark. The map can only be drawn while the app is in front.
    static func load(for run: Run, route: RouteDrawing?) async -> StoryCardBackground? {
        if let fileName = run.photoFileName {
            // Decoded at the stored size, so a landscape photo filling the card's height isn't stretched.
            if let photo = await RunPhotoStore.shared.image(fileName, filter: run.photoFilter, maxPixelSize: RunPhotoStore.longestSide) {
                return StoryCardBackground(image: photo)
            }
            logger.error("Couldn't read a Run's photo for its Story card; using the map")
        }
        guard let route else { return nil }
        let options = MKMapSnapshotter.Options()
        options.mapRect = route.mapRect(fitting: StoryCard.Layout.routeFrame, in: StoryCard.Layout.size)
        options.size = StoryCard.Layout.size
        options.scale = StoryCard.Layout.scale
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        options.preferredConfiguration = configuration
        do {
            guard let map = try await MKMapSnapshotter(options: options).start().image.cgImage else { return nil }
            return StoryCardBackground(image: map)
        } catch {
            logger.error("Couldn't draw the map for a Story card: \(error)")
            return nil
        }
    }
}
