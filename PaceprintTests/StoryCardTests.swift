import MapKit
import SwiftData
import Testing
import PaceprintCore
@testable import Paceprint

@Suite("Story card")
struct StoryCardTests {
    let container: ModelContainer
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    init() throws {
        container = try ModelContainer(for: Run.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// A finished Run running 1 km north then 500 m east.
    private func savedRun() -> Run {
        let north = stride(from: 0.0, through: 1_000, by: 10).map { metres in
            RoutePoint(timestamp: start + metres * 0.33, latitude: 40.78 + metres / 111_195, longitude: -73.966, altitude: 30, horizontalAccuracy: 5, cumulativeDistance: metres, isPaused: false)
        }
        let east = stride(from: 10.0, through: 500, by: 10).map { metres in
            RoutePoint(timestamp: start + 330 + metres * 0.39, latitude: 40.78 + 1_000 / 111_195, longitude: -73.966 + metres / 84_300, altitude: 30, horizontalAccuracy: 5, cumulativeDistance: 1_000 + metres, isPaused: false)
        }
        let run = Run(startDate: start)
        run.finish(RunTracker(runStart: start, points: north + east, pauses: []), at: start + 525)
        container.mainContext.insert(run)
        return run
    }

    @Test("The Route is fitted inside the card's band, which sits clear of the wordmark and the Place name")
    func routeInBand() throws {
        let route = try #require(RouteDrawing(savedRun(), palette: .pace))
        let band = StoryCard.Layout.routeBand

        let place = route.projection(into: StoryCard.Layout.routeFrame)
        let points = route.stretches.joined().map(place)

        #expect(points.allSatisfy { band.insetBy(dx: -0.5, dy: -0.5).contains($0) })
        #expect(band.minY >= StoryCard.Layout.wordmarkBottom)
        #expect(band.maxY <= StoryCard.Layout.placeTop)
    }

    @Test("Behind a card with no photo, the dark map is framed so the Route lands on its own streets")
    func mapFramedToRoute() throws {
        let route = try #require(RouteDrawing(savedRun(), palette: .pace))
        let size = StoryCard.Layout.size

        let mapRect = route.mapRect(fitting: StoryCard.Layout.routeFrame, in: size)
        let place = route.projection(into: StoryCard.Layout.routeFrame)

        for coordinate in [route.start, route.end] {
            let point = MKMapPoint(coordinate)
            let onMap = CGPoint(
                x: (point.x - mapRect.minX) / mapRect.width * size.width,
                y: (point.y - mapRect.minY) / mapRect.height * size.height
            )
            #expect(abs(onMap.x - place(coordinate).x) < 0.01)
            #expect(abs(onMap.y - place(coordinate).y) < 0.01)
        }
    }

    @Test("The card is shared as a full-size PNG")
    func sharedAsPNG() throws {
        let run = savedRun()
        let card = try #require(StoryCard(run: run, background: nil, route: RouteDrawing(run, palette: .pace)).rendered())

        let png = try #require(StoryCardImage(card).png)
        let image = try #require(UIImage(data: png))

        #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(image.size.width * image.scale == 1_080)
        #expect(image.size.height * image.scale == 1_920)
    }

    @Test("A card renders as a 1080 × 1920 image")
    func renders() throws {
        let run = savedRun()

        let image = try #require(StoryCard(run: run, background: nil, route: RouteDrawing(run, palette: .pace)).rendered())

        #expect(image.cgImage?.width == 1_080)
        #expect(image.cgImage?.height == 1_920)
    }
}
