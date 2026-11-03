import Foundation
import SwiftData
import Testing
import PaceprintCore
@testable import Paceprint

@Suite("Route thumbnails for older Runs")
@MainActor
struct RouteThumbnailBackfillTests {
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(for: Run.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// A finished Run as saved before thumbnails existed: 500 m due north, and no thumbnail.
    private func olderRun(routeData: Data? = nil) -> Run {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let route = (0...50).map { step in
            RoutePoint(
                timestamp: start + Double(step) * 3.6,
                latitude: 40.78 + Double(step) * 10 / 111_195,
                longitude: -73.966,
                altitude: 30,
                horizontalAccuracy: 5,
                cumulativeDistance: Double(step) * 10,
                isPaused: false
            )
        }
        let run = Run(startDate: start)
        run.routeData = routeData ?? RouteEncoding.encode(route)
        run.distance = 500
        run.movingTime = 180
        run.isFinished = true
        container.mainContext.insert(run)
        return run
    }

    @Test("A finished Run without a thumbnail gets one made from its stored Route")
    func fillsMissing() async throws {
        let run = olderRun()

        await Run.makeMissingThumbnails(in: container.mainContext)

        let thumbnail = try #require(run.routeThumbnail)
        #expect(thumbnail.lines.count == 1)
        #expect(thumbnail.lines.first?.points.count == 2)
    }

    @Test("A Run whose Route can't be read gets an empty thumbnail, so it isn't tried again")
    func unreadableRoute() async throws {
        let run = olderRun(routeData: Data([99]))

        await Run.makeMissingThumbnails(in: container.mainContext)

        #expect(run.routeThumbnailData != nil)
        #expect(try #require(run.routeThumbnail).lines.isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<Run>(predicate: Run.awaitingThumbnail)).isEmpty)
    }

    @Test("A Run still being recorded is left alone")
    func skipsUnfinished() async throws {
        let run = Run(startDate: .now)
        container.mainContext.insert(run)

        await Run.makeMissingThumbnails(in: container.mainContext)

        #expect(run.routeThumbnailData == nil)
    }
}
