import CoreImage
import CoreImage.CIFilterBuiltins
import PaceprintCore

/// The design's CSS filter chains, in Core Image.
nonisolated extension PhotoFilter {
    func apply(to image: CIImage) -> CIImage {
        switch self {
        case .none:
            image
        case .chroma:
            // saturate(1.3) contrast(1.05)
            image.colorControls(saturation: 1.3, contrast: 1.05)
        case .noir:
            // saturate(0) contrast(1.15) brightness(0.85)
            image.colorControls(saturation: 0, contrast: 1.15).brightness(0.85)
        case .dusk:
            // sepia(0.3) saturate(1.1) hue-rotate(-10deg)
            image.sepia(0.3).colorControls(saturation: 1.1, contrast: 1).hueRotated(degrees: -10)
        case .film:
            // contrast(1.1) saturate(0.85) brightness(0.95)
            image.colorControls(saturation: 0.85, contrast: 1.1).brightness(0.95)
        }
    }
}

private nonisolated extension CIImage {
    func colorControls(saturation: Float, contrast: Float) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = self
        filter.saturation = saturation
        filter.contrast = contrast
        return filter.outputImage ?? self
    }

    /// Every channel multiplied by `factor`, as CSS `brightness()` does.
    func brightness(_ factor: CGFloat) -> CIImage {
        let filter = CIFilter.colorMatrix()
        filter.inputImage = self
        filter.rVector = CIVector(x: factor, y: 0, z: 0, w: 0)
        filter.gVector = CIVector(x: 0, y: factor, z: 0, w: 0)
        filter.bVector = CIVector(x: 0, y: 0, z: factor, w: 0)
        return filter.outputImage ?? self
    }

    func sepia(_ intensity: Float) -> CIImage {
        let filter = CIFilter.sepiaTone()
        filter.inputImage = self
        filter.intensity = intensity
        return filter.outputImage ?? self
    }

    func hueRotated(degrees: Float) -> CIImage {
        let filter = CIFilter.hueAdjust()
        filter.inputImage = self
        filter.angle = degrees * .pi / 180
        return filter.outputImage ?? self
    }
}
