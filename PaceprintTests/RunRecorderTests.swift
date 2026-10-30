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

    /// A good fix `seconds` after the clock's current time, `step` steps of 0.0001° north of the start.
    private func fix(in seconds: TimeInterval, step: Int = 0) -> LocationEvent {
        let latitude = 40.78 + Double(step) * 0.0001
        return .fix(LocationFix(timestamp: clock.now + seconds, latitude: latitude, longitude: -73.966, altitude: 30, horizontalAccuracy: 5))
    }

    private func savedRun() throws -> Run {
        let runs = try container.mainContext.fetch(FetchDescriptor<Run>())
        let run = try #require(runs.count == 1 ? runs.first : nil)
        #expect(run.isFinished)
        return run
    }

    private func allRuns() throws -> [Run] {
        try container.mainContext.fetch(FetchDescriptor<Run>())
    }

    /// Records 31 s of running, one step a second, as fixes arrive in real time, then leaves the Run
    /// as if the app had been killed: only its last checkpoint, 30 s in, is in the store.
    private func recordThenKill() async {
        let killed = recorder(ScriptedLocationSource(script: (0...30).map { fix(in: Double($0) + 1, step: $0) }, clock: clock))
        await killed.start()
        await killed.waitUntilSourceFinishes()
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
        recorder.save()

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

    @Test("A Run in progress is checkpointed as an unfinished Run, which History doesn't show")
    func checkpointed() async throws {
        await recordThenKill()

        let run = try #require(try allRuns().first)
        #expect(!run.isFinished)
        // Checkpointed every 10 s: the last one, at 30 s, has the 30 fixes up to then.
        #expect(try run.decodedRoute().count == 30)
        #expect(run.endDate == run.startDate.addingTimeInterval(30))
        #expect(try container.mainContext.fetch(FetchDescriptor(predicate: Run.finished)).isEmpty)
    }

    @Test("After the app is closed mid-Run, it reopens on the Run Paused, the gap recorded as a Pause")
    func recoveredPaused() async throws {
        await recordThenKill()
        clock.advance(by: 100)

        let recorder = recorder(ScriptedLocationSource(script: []))
        recorder.recoverUnfinishedRun(relaunchedInBackground: false)

        #expect(recorder.isRecording)
        #expect(recorder.isPaused)
        #expect(abs(recorder.distance - 29 * stepMetres) < 0.01)
        #expect(recorder.movingTime == 30)
        let run = try #require(try allRuns().first)
        #expect(run.pauses == [Pause(start: run.startDate.addingTimeInterval(30), end: nil)])
    }

    @Test("When iOS relaunches the app in the background mid-Run, recording carries on")
    func recoveredInBackground() async throws {
        await recordThenKill()
        clock.advance(by: 30)

        let recorder = recorder(ScriptedLocationSource(script: [fix(in: 5, step: 40)]))
        recorder.recoverUnfinishedRun(relaunchedInBackground: true)
        await recorder.waitUntilSourceFinishes()

        #expect(!recorder.isPaused)
        #expect(recorder.movingTime == 61)
        #expect(abs(recorder.distance - 40 * stepMetres) < 0.01)
    }

    @Test("A checkpoint that can't be read isn't recovered, and isn't left in the store")
    func unreadableCheckpoint() throws {
        let broken = Run(startDate: clock.now)
        broken.routeData = Data([99])
        container.mainContext.insert(broken)

        let recorder = recorder(ScriptedLocationSource(script: []))
        recorder.recoverUnfinishedRun(relaunchedInBackground: false)

        #expect(!recorder.isRecording)
        #expect(try allRuns().isEmpty)
    }

    @Test("Stop on a short Run asks to discard it; Discard saves nothing")
    func discardShortRun() async throws {
        let recorder = recorder(ScriptedLocationSource(script: [fix(in: 1)]))
        await recorder.start()
        await recorder.waitUntilSourceFinishes()
        clock.advance(by: 30)

        recorder.stop()
        #expect(recorder.isAskingToDiscard)
        #expect(recorder.isRecording)

        recorder.discard()
        #expect(!recorder.isRecording)
        #expect(try allRuns().isEmpty)
        #expect(recorder.stoppedRun == nil)
    }

    @Test("Keeping a short Run saves it")
    func keepShortRun() async throws {
        let recorder = recorder(ScriptedLocationSource(script: [fix(in: 1)]))
        await recorder.start()
        clock.advance(by: 30)

        recorder.stop()
        recorder.save()

        #expect(!recorder.isRecording)
        #expect(try savedRun().elapsedTime == 30)
        #expect(try recorder.stoppedRun === savedRun())
    }

    @Test("Stop on a Run of 0.1 km and 1 min saves it without asking")
    func stopLongEnoughRun() async throws {
        await recordThenKill()
        let recorder = recorder(ScriptedLocationSource(script: [fix(in: 40, step: 40)]))
        recorder.recoverUnfinishedRun(relaunchedInBackground: true)
        await recorder.waitUntilSourceFinishes()
        clock.advance(by: 40)

        recorder.stop()

        #expect(!recorder.isAskingToDiscard)
        #expect(!recorder.isRecording)
        #expect(try savedRun().movingTime == 71)
        // Summary opens on the Run just saved.
        #expect(try recorder.stoppedRun === savedRun())
    }
}

/// A clock the test moves by hand.
final class TestClock {
    var now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func advance(by seconds: TimeInterval) {
        now += seconds
    }
}

/// Plays back a fixed list of location events, then ends. Given a clock, it moves the clock to each
/// fix's time as it hands the fix over, as if fixes arrived in real time.
struct ScriptedLocationSource: LocationSource {
    var problem: LocationProblem?
    var script: [LocationEvent]
    var clock: TestClock?

    func prepare() async -> LocationProblem? {
        problem
    }

    func events() -> AsyncStream<LocationEvent> {
        let playback = Playback(script: script, clock: clock)
        return AsyncStream(unfolding: { await playback.next() })
    }
}

/// The events still to play; handed over one at a time, each once the last has been handled.
private final class Playback {
    private var remaining: ArraySlice<LocationEvent>
    private let clock: TestClock?

    init(script: [LocationEvent], clock: TestClock?) {
        remaining = script[...]
        self.clock = clock
    }

    func next() -> LocationEvent? {
        guard let event = remaining.popFirst() else { return nil }
        if let clock, case .fix(let fix) = event {
            clock.now = max(clock.now, fix.timestamp)
        }
        return event
    }
}
