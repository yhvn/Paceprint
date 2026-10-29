import Foundation
import SwiftData
import Testing
import PaceprintCore
@testable import Paceprint

@Suite("Run recorder")
struct RunRecorderTests {
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(for: Run.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func replay(_ fixture: String, isAuthorized: Bool = true) throws -> GPXReplayLocationSource {
        let url = try #require(Bundle(for: FixtureBundle.self).url(forResource: fixture, withExtension: "gpx"))
        return try GPXReplayLocationSource(contentsOf: url, isAuthorized: isAuthorized)
    }

    @Test("Replaying a GPX Run and stopping saves the Run with its distance and Route")
    func savesReplayedRun() async throws {
        let recorder = RunRecorder(source: try replay("straight-north-1112m"), modelContext: container.mainContext)

        await recorder.start()
        #expect(recorder.isRecording)
        await recorder.waitUntilSourceFinishes()
        recorder.stop()

        let runs = try container.mainContext.fetch(FetchDescriptor<Run>())
        let run = try #require(runs.only)
        // 100 steps of 11.1195 m; the teleport fix in the fixture is dropped.
        #expect(abs(run.distance - 1_111.95) < 0.5)
        let route = try run.decodedRoute()
        #expect(route.count == 101)
        #expect(route.last?.cumulativeDistance == run.distance)
        #expect(run.endDate >= run.startDate)
        #expect(run.elapsedTime == run.endDate.timeIntervalSince(run.startDate))
        #expect(!recorder.isRecording)
    }

    @Test("Without location permission the Run doesn't start")
    func deniedPermission() async throws {
        let recorder = RunRecorder(source: try replay("straight-north-1112m", isAuthorized: false), modelContext: container.mainContext)

        await recorder.start()

        #expect(!recorder.isRecording)
    }
}

private final class FixtureBundle {}

private extension Array {
    var only: Element? { count == 1 ? first : nil }
}
