import CoreGraphics
import Foundation

/// How much darker a Run's photo is drawn so the text over it stays readable: 0 keeps the design's
/// own gradients (a dark photo), 1 is for the brightest photos. Measured once, when the photo is picked,
/// and used everywhere the photo appears.
public struct Scrim: Sendable, Equatable {
    /// 0 to 1.
    public let strength: Double

    /// Black laid over the whole photo at full strength.
    public static let maximumDim = 0.25
    /// At or below this average brightness a photo keeps the design's gradients.
    static let darkBrightness = 0.3
    /// At or above this average brightness a photo gets the full Scrim.
    static let brightBrightness = 0.65

    public init(strength: Double) {
        self.strength = min(max(strength, 0), 1)
    }

    /// From a photo's average brightness (0 black, 1 white) where the Place name and the metrics sit over it;
    /// the brighter band decides.
    public init(placeNameBand: Double, metricsBand: Double) {
        let brightness = max(placeNameBand, metricsBand)
        self.init(strength: (brightness - Self.darkBrightness) / (Self.brightBrightness - Self.darkBrightness))
    }

    /// A photo with no darkening beyond the design's gradients.
    public static let none = Scrim(strength: 0)

    /// The opacity of one of the design's gradient stops, darkened for this strength:
    /// at full strength, halfway from `opacity` to opaque.
    public func darkened(_ opacity: Double) -> Double {
        opacity + (1 - opacity) * strength / 2
    }

    /// Black laid over the whole photo, up to `maximumDim`.
    public var dim: Double {
        Self.maximumDim * strength
    }
}

/// Where text sits over a Run's photo, so the Scrim can be measured where it matters.
public enum PhotoFraming {
    /// Where Summary puts the Place name, as a fraction of the screen's height from the top.
    public static let placeNameBand = 0.5...0.65
    /// Where Summary puts the metrics, as a fraction of the screen's height from the top.
    public static let metricsBand = 0.65...0.92

    /// The part of a `photo`-sized image that shows when it fills a frame `frameAspect` wide per unit of
    /// height, centred and uncropped otherwise; top-left origin.
    public static func visibleRect(of photo: CGSize, frameAspect: Double) -> CGRect {
        let photoAspect = photo.width / photo.height
        if photoAspect > frameAspect {
            // Wider than the frame: the sides are cut off.
            let width = photo.height * frameAspect
            return CGRect(x: (photo.width - width) / 2, y: 0, width: width, height: photo.height)
        } else {
            // Taller than the frame: the top and bottom are cut off.
            let height = photo.width / frameAspect
            return CGRect(x: 0, y: (photo.height - height) / 2, width: photo.width, height: height)
        }
    }

    /// A horizontal `band` (fractions of height from the top) across `visible`.
    public static func rect(of band: ClosedRange<Double>, in visible: CGRect) -> CGRect {
        CGRect(
            x: visible.minX,
            y: visible.minY + visible.height * band.lowerBound,
            width: visible.width,
            height: visible.height * (band.upperBound - band.lowerBound)
        )
    }
}
