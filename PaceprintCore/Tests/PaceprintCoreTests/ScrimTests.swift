import Foundation
import Testing
@testable import PaceprintCore

@Suite("Scrim")
struct ScrimTests {
    @Test("A dark photo keeps the design's gradients")
    func darkPhoto() {
        let scrim = Scrim(placeNameBand: 0.1, metricsBand: 0.3)
        #expect(scrim.strength == 0)
        #expect(scrim.dim == 0)
        #expect(scrim.darkened(0.1) == 0.1)
    }

    @Test("A bright photo gets the full Scrim: darker gradients and a 25% dim")
    func brightPhoto() {
        let scrim = Scrim(placeNameBand: 0.2, metricsBand: 0.9)
        #expect(scrim.strength == 1)
        #expect(scrim.dim == 0.25)
        #expect(abs(scrim.darkened(0.1) - 0.55) < 1e-9)
        #expect(scrim.darkened(1) == 1)
    }

    @Test("In between, the brighter band sets a strength part way")
    func inBetween() {
        let scrim = Scrim(placeNameBand: 0.475, metricsBand: 0.2)
        #expect(abs(scrim.strength - 0.5) < 1e-9)
    }

    @Test("Strength is kept between 0 and 1")
    func clamped() {
        #expect(Scrim(strength: 3).strength == 1)
        #expect(Scrim(strength: -1).strength == 0)
    }
}

@Suite("Photo framing")
struct PhotoFramingTests {
    /// An iPhone screen, roughly.
    let portrait = 390.0 / 844.0

    @Test("A landscape photo filling a portrait screen loses its sides")
    func landscape() {
        let visible = PhotoFraming.visibleRect(of: CGSize(width: 2048, height: 1536), frameAspect: portrait)
        #expect(visible.minY == 0)
        #expect(visible.height == 1536)
        #expect(abs(visible.width - 1536 * portrait) < 1e-9)
        #expect(abs(visible.midX - 1024) < 1e-9)
    }

    @Test("A photo taller than the screen loses its top and bottom")
    func tall() {
        let visible = PhotoFraming.visibleRect(of: CGSize(width: 1000, height: 4000), frameAspect: 0.5)
        #expect(visible == CGRect(x: 0, y: 1000, width: 1000, height: 2000))
    }

    @Test("A band is measured across the visible part, from its top")
    func band() {
        let visible = CGRect(x: 0, y: 1000, width: 1000, height: 2000)
        #expect(PhotoFraming.rect(of: 0.5...0.75, in: visible) == CGRect(x: 0, y: 2000, width: 1000, height: 500))
    }

    @Test("The stored filter names never change")
    func filterRawValues() {
        #expect(PhotoFilter.allCases.map(\.rawValue) == ["none", "chroma", "noir", "dusk", "film"])
    }
}
