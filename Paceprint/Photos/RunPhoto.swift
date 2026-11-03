import PaceprintCore
import SwiftUI

/// A Run's photo drawn with its filter, filling the space and centred; `placeholder` while it loads or
/// if its file can't be read.
struct RunPhoto<Placeholder: View>: View {
    let fileName: String
    let filter: PhotoFilter
    /// Longest side to decode at, in pixels: enough for where it's shown, no more.
    var maxPixelSize = RunPhotoStore.longestSide
    @ViewBuilder var placeholder: Placeholder
    @State private var loaded: CGImage?

    private var key: RunPhotoCache.Key {
        RunPhotoCache.Key(fileName: fileName, filter: filter, maxPixelSize: maxPixelSize)
    }

    var body: some View {
        // The color takes the space it's offered, so a photo of another shape can't widen the layout.
        Color.clear
            .overlay {
                // From the cache straight away, so History doesn't flash placeholders while scrolling.
                if let image = RunPhotoCache.shared.cached(key) ?? loaded {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder
                }
            }
            .clipped()
            .accessibilityHidden(true)
            .task(id: key) {
                loaded = await RunPhotoCache.shared.image(for: key)
            }
    }
}

/// Decoded, filtered photos, so scrolling History or going back to a filter doesn't decode a file again.
final class RunPhotoCache {
    struct Key: Hashable {
        let fileName: String
        let filter: PhotoFilter
        let maxPixelSize: Int

        fileprivate var name: NSString {
            "\(fileName)|\(filter.rawValue)|\(maxPixelSize)" as NSString
        }
    }

    static let shared = RunPhotoCache()

    private let store: RunPhotoStore
    private let images = NSCache<NSString, CGImage>()

    /// About eight full-size 2,048 px photos; History's small cards take far less each.
    static let memoryLimit = 128 * 1024 * 1024

    init(store: RunPhotoStore = .shared) {
        self.store = store
        images.totalCostLimit = Self.memoryLimit
    }

    func cached(_ key: Key) -> CGImage? {
        images.object(forKey: key.name)
    }

    func image(for key: Key) async -> CGImage? {
        if let image = cached(key) { return image }
        guard let image = await store.image(key.fileName, filter: key.filter, maxPixelSize: key.maxPixelSize) else { return nil }
        images.setObject(image, forKey: key.name, cost: image.bytesPerRow * image.height)
        return image
    }
}

/// One of the design's gradients over a photo, darkened by the photo's Scrim, under its overall dim.
struct ScrimGradient: View {
    struct Stop {
        var color = Color.black
        let opacity: Double
        let location: Double
    }

    let stops: [Stop]
    var startPoint = UnitPoint.top
    var endPoint = UnitPoint.bottom
    let scrim: Scrim

    var body: some View {
        ZStack {
            Color.black.opacity(scrim.dim)
            LinearGradient(
                stops: stops.map { .init(color: $0.color.opacity(scrim.darkened($0.opacity)), location: $0.location) },
                startPoint: startPoint,
                endPoint: endPoint
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The design's gradients, per screen.
extension [ScrimGradient.Stop] {
    /// Summary: dark under the top bar and behind the metrics, clear across the middle.
    static let summary: Self = [
        .init(opacity: 0.55, location: 0),
        .init(opacity: 0.10, location: 0.3),
        .init(opacity: 0.10, location: 0.6),
        .init(color: Color(hex: 0x080A10), opacity: 0.96, location: 1),
    ]

    /// Home: dark under the greeting and behind the week and latest Run.
    static let home: Self = [
        .init(opacity: 0.55, location: 0),
        .init(opacity: 0.10, location: 0.35),
        .init(opacity: 0.10, location: 0.55),
        .init(opacity: 0.85, location: 1),
    ]

    /// Run detail's top strip, fading into the page below.
    static let detailStrip: Self = [
        .init(opacity: 0.55, location: 0),
        .init(opacity: 0.10, location: 0.4),
        .init(color: Theme.Colors.inkBlack, opacity: 1, location: 1),
    ]

    /// The Story card: dark under the wordmark and behind the metrics and footer.
    static let storyCard: Self = [
        .init(opacity: 0.55, location: 0),
        .init(opacity: 0.05, location: 0.35),
        .init(opacity: 0.15, location: 0.6),
        .init(opacity: 0.92, location: 1),
    ]

    /// A History card, left to right: darkest behind its text.
    static let historyCard: Self = [
        .init(opacity: 0.7, location: 0),
        .init(opacity: 0.3, location: 0.6),
        .init(opacity: 0.6, location: 1),
    ]
}
