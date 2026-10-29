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

    private func recorder() throws -> RunRecorder {
        let url = try #require(Bundle(for: TestClock.self).url(forResource: fixture, withExtension: "gpx"))
        let clock = clock
        let source = try GPXReplayLocationSource(contentsOf: url, now: { clock.now })
        return recorder(source)
    }

    private func recorder(_ source: some LocationSource) -> RunRecorder {
        let clock = clock
        return RunRecorder(source: source, modelContext: container.mainContext, now: { clock.now })
    }

    /// A good fix `seconds` after the clock's current time.
    private func fix(in seconds: TimeInterval) -> LocationEvent {
        .fix(LocationFix(timestamp: clock.now + seconds, latitude: 40.78, longitude: -73.966, altitude: 30, horizontalAccuracy: 5))
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
        // 3 s after the last fix: Current pace still covers the 30 s up to that fix.
        clock.advance(by: 403)
        let currentPace = try #require(recorder.currentPace)
        #expect(abs(currentPace.seconds(per: .kilometers) - 359.73) < 0.01)
        recorder.stop()

        let run = try savedRun()
        // 100 steps; the teleport fix in the fixture is dropped.
        #expect(abs(run.distance - 100 * stepMetres) < 0.5)
        let route = try run.decodedRoute()
        #expect(route.count == 101)
        #expect(route.last?.cumulativeDistance == run.distance)
        #expect(route.allSatisfy { $0.timestamp >= run.startDate && $0.timestamp <= run.endDate })
        #expect(run.elapsedTime == 403)
        #expect(run.movingTime == 403)
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

    @Test("When location can't be used, Start says why and the Run doesn't start", arguments: LocationProblem.allCases)
    func startBlocked(_ problem: LocationProblem) async {
        let recorder = recorder(ScriptedLocationSource(problem: problem, script: []))

        await recorder.start()

        #expect(!recorder.isRecording)
        #expect(recorder.startProblem == problem)
    }

    @Test("Losing location access mid-Run Pauses it, and Resume waits for access")
    func accessLost() async {
        let recorder = recorder(ScriptedLocationSource(script: [fix(in: 1), fix(in: 5), .accessLost]))

        await recorder.start()
        clock.advance(by: 30)
        await recorder.waitUntilSourceFinishes()

        #expect(recorder.isPaused)
        #expect(recorder.isAccessLost)
        #expect(recorder.movingTime == 30)
        recorder.resume()
        #expect(recorder.isPaused)
    }

    @Test("Once access is back, the Run stays paused until Resume")
    func accessBack() async {
        let recorder = recorder(ScriptedLocationSource(script: [fix(in: 1), .accessLost, fix(in: 40)]))

        await recorder.start()
        clock.advance(by: 30)
        await recorder.waitUntilSourceFinishes()

        #expect(recorder.isPaused)
        #expect(!recorder.isAccessLost)
        recorder.resume()
        #expect(!recorder.isPaused)
    }

    @Test("GPS reads weak 10 s after the last fix, unless the device reported standing still")
    func gpsStatus() async {
        let moving = recorder(ScriptedLocationSource(script: [fix(in: 1)]))
        let standing = recorder(ScriptedLocationSource(script: [fix(in: 1), .stationary]))

        await moving.start()
        await standing.start()
        await moving.waitUntilSourceFinishes()
        await standing.waitUntilSourceFinishes()
        clock.advance(by: 60)

        #expect(moving.gpsStatus == .weak)
        #expect(standing.gpsStatus == .good)
    }

    @Test("Access counts as back when the system reports the device standing still, with no fix")
    func accessBackWhileStanding() async {
        let recorder = recorder(ScriptedLocationSource(script: [fix(in: 1), .accessLost, .stationary]))

        await recorder.start()
        await recorder.waitUntilSourceFinishes()

        #expect(!recorder.isAccessLost)
        recorder.resume()
        #expect(!recorder.isPaused)
    }

    @Test("A manual Pause doesn't count as lost access")
    func manualPauseKept() async {
        let recorder = recorder(ScriptedLocationSource(script: [fix(in: 1), fix(in: 5)]))

        await recorder.start()
        recorder.pause()
        await recorder.waitUntilSourceFinishes()

        #expect(recorder.isPaused)
        #expect(!recorder.isAccessLost)
    }
}

/// A clock the test moves by hand.
final class TestClock {
    var now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func advance(by seconds: TimeInterval) {
        now += seconds
    }
}

/// Plays back a fixed list of location events, then ends.
struct ScriptedLocationSource: LocationSource {
    var problem: LocationProblem?
    var script: [LocationEvent]

    func prepare() async -> LocationProblem? {
        problem
    }

    func events() -> AsyncStream<LocationEvent> {
        AsyncStream { continuation in
            script.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
}
