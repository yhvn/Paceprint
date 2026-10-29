import Foundation
import SwiftData
import Testing
import PaceprintCore
@testable import Paceprint

/// The fixture: 101 points due north, one step of 11.1195 m every 4 s (5:59.7 /km), for 400 s.
private let fixture = "straight-north-1112m"
private let stepMetres = 11.1195

@Suite("Run recorder")
struct RunRecorderTests {
    let container: ModelContainer
    let clock = TestClock()

    init() throws {
        container = try ModelContainer(for: Run.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func recorder(isAuthorized: Bool = true) throws -> RunRecorder {
        let url = try #require(Bundle(for: TestClock.self).url(forResource: fixture, withExtension: "gpx"))
        let clock = clock
        let source = try GPXReplayLocationSource(contentsOf: url, isAuthorized: isAuthorized, now: { clock.now })
        return RunRecorder(source: source, modelContext: container.mainContext, now: { clock.now })
    }

    private func savedRun() throws -> Run {
        let runs = try container.mainContext.fetch(FetchDescriptor<Run>())
        return try #require(runs.count == 1 ? runs.first : nil)
    }

    @Test("Replaying a GPX Run and stopping saves the Run with its distance and Route")
    func savesReplayedRun() async throws {
        let recorder = try recorder()

        await recorder.start()
        #expect(recorder.isRecording)
        await recorder.waitUntilSourceFinishes()
        clock.advance(by: 400)
        recorder.stop()

        let run = try savedRun()
        // 100 steps; the teleport fix in the fixture is dropped.
        #expect(abs(run.distance - 100 * stepMetres) < 0.5)
        let route = try run.decodedRoute()
        #expect(route.count == 101)
        #expect(route.last?.cumulativeDistance == run.distance)
        #expect(route.allSatisfy { $0.timestamp >= run.startDate && $0.timestamp <= run.endDate })
        #expect(run.elapsedTime == 400)
        #expect(run.movingTime == 400)
        #expect(run.pauses.isEmpty)
        #expect(!recorder.isRecording)
    }

    @Test("Pause and Resume: the Pause is saved and nothing in it counts")
    func pauseAndResume() async throws {
        let recorder = try recorder()

        await recorder.start()
        // The replay stamps its fixes from the same clock, so they're sorted into the Pause by timestamp.
        clock.advance(by: 100)
        recorder.pause()
        #expect(recorder.isPaused)
        clock.advance(by: 60)
        recorder.resume()
        #expect(!recorder.isPaused)
        await recorder.waitUntilSourceFinishes()
        clock.advance(by: 240)

        #expect(recorder.movingTime == 340)
        let currentPace = try #require(recorder.currentPace)
        #expect(abs(currentPace.seconds(per: .kilometers) - 359.73) < 0.01)
        recorder.stop()

        let run = try savedRun()
        #expect(run.pauses == [Pause(start: run.startDate.addingTimeInterval(100), end: run.startDate.addingTimeInterval(160))])
        #expect(run.elapsedTime == 400)
        #expect(run.movingTime == 340)
        // Moving from 0 s to 96 s (24 steps) and from 160 s to 400 s (60 steps).
        #expect(abs(run.distance - 84 * stepMetres) < 0.5)
        let route = try run.decodedRoute()
        #expect(route.filter(\.isPaused).count == 15)
    }

    @Test("Stopping while paused ends the Pause at Stop")
    func stopWhilePaused() async throws {
        let recorder = try recorder()

        await recorder.start()
        clock.advance(by: 100)
        recorder.pause()
        clock.advance(by: 50)
        recorder.stop()

        let run = try savedRun()
        #expect(run.pauses == [Pause(start: run.startDate.addingTimeInterval(100), end: run.endDate)])
        #expect(run.movingTime == 100)
    }

    @Test("Without location permission the Run doesn't start")
    func deniedPermission() async throws {
        let recorder = try recorder(isAuthorized: false)

        await recorder.start()

        #expect(!recorder.isRecording)
    }
}

/// A clock the test moves by hand.
final class TestClock {
    var now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func advance(by seconds: TimeInterval) {
        now += seconds
    }
}
