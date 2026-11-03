import Foundation
import SwiftData
import Testing
import PaceprintCore
@testable import Paceprint

@Suite("Apple Health")
struct RunHealthSyncTests {
    let container: ModelContainer
    let settings: UserDefaults
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    init() throws {
        container = try ModelContainer(for: Run.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        settings = try #require(UserDefaults(suiteName: "RunHealthSyncTests-\(UUID().uuidString)"))
    }

    /// A finished 1 km Run with a 60 s Pause at 500 m (a paused fix in it) and one fix too vague for Health.
    private func savedRun() -> Run {
        var points = stride(from: 0.0, through: 1_000, by: 10).map { (metres: Double) -> RoutePoint in
            let seconds: Double = metres <= 500 ? metres * 0.36 : metres * 0.36 + 60
            return RoutePoint(timestamp: start + seconds, latitude: 40.78 + metres / 111_195, longitude: -73.966, altitude: 30, horizontalAccuracy: 5, cumulativeDistance: metres, isPaused: false)
        }
        points.insert(RoutePoint(timestamp: start + 200, latitude: 40.7845, longitude: -73.966, altitude: 30, horizontalAccuracy: 5, cumulativeDistance: 500, isPaused: true), at: 51)
        points[10].horizontalAccuracy = 60
        let pause = Pause(start: start + 181, end: start + 241)
        let run = Run(startDate: start)
        run.finish(RunTracker(runStart: start, points: points, pauses: [pause]), at: start + 420, bodyMass: 70)
        container.mainContext.insert(run)
        return run
    }

    private func sync(_ exporter: FakeHealthExporter) -> RunHealthSync {
        RunHealthSync(exporter: exporter, modelContext: container.mainContext, settings: settings)
    }

    @Test("With Health on, a stopped Run is saved to Health with its Route, distance, calories and Pauses")
    func saved() async throws {
        settings.set(true, forKey: SettingsKey.saveToHealth)
        let run = savedRun()
        let exporter = FakeHealthExporter()

        await sync(exporter).runStopped(run)

        let workout = try #require(exporter.saved.first)
        #expect(workout.start == run.startDate)
        #expect(workout.end == run.endDate)
        #expect(workout.distance == run.distance)
        #expect(workout.activeCalories == run.activeCalories)
        #expect(workout.pauses == run.pauses)
        // 101 fixes, less the paused one and the one too vague for Health.
        #expect(workout.route.count == 100)
        #expect(workout.route.allSatisfy { $0.horizontalAccuracy <= 50 })
        #expect(run.healthWorkoutID == exporter.lastID)
        #expect(!run.awaitsHealthSave)
    }

    @Test("With Health off, a stopped Run isn't saved to Health")
    func healthOff() async {
        let run = savedRun()
        let exporter = FakeHealthExporter()

        await sync(exporter).runStopped(run)

        #expect(exporter.saved.isEmpty)
        #expect(!run.awaitsHealthSave)
        #expect(run.healthWorkoutID == nil)
    }

    @Test("A save that fails is retried quietly on the next launch")
    func retried() async {
        settings.set(true, forKey: SettingsKey.saveToHealth)
        let run = savedRun()

        await sync(FakeHealthExporter(fails: true)).runStopped(run)
        #expect(run.awaitsHealthSave)
        #expect(run.healthWorkoutID == nil)

        let later = FakeHealthExporter()
        await sync(later).saveRunsAwaitingHealth()
        #expect(later.saved.count == 1)
        #expect(!run.awaitsHealthSave)
    }

    @Test("Deleting a Run deletes its Health workout")
    func deleted() async throws {
        settings.set(true, forKey: SettingsKey.saveToHealth)
        let run = savedRun()
        let exporter = FakeHealthExporter()
        let sync = sync(exporter)
        await sync.runStopped(run)
        let id = try #require(run.healthWorkoutID)

        try await sync.delete(run)

        #expect(exporter.deleted == [id])
        #expect(try container.mainContext.fetch(FetchDescriptor<Run>()).isEmpty)
    }

    @Test("Stopping a Run with Health on saves it to Health")
    func savedOnStop() async throws {
        settings.set(true, forKey: SettingsKey.saveToHealth)
        let exporter = FakeHealthExporter()
        let clock = TestClock()
        let source = ScriptedLocationSource(script: (0...30).map {
            .fix(LocationFix(timestamp: clock.now + Double($0) * 4, latitude: 40.78 + Double($0) * 0.0001, longitude: -73.966, altitude: 30, horizontalAccuracy: 5))
        }, clock: clock)
        let recorder = RunRecorder(source: source, modelContext: container.mainContext, healthSync: sync(exporter), now: { clock.now })

        await recorder.start()
        await recorder.waitUntilSourceFinishes()
        recorder.stop()
        await recorder.waitUntilSavedToHealth()

        #expect(exporter.saved.count == 1)
        #expect(recorder.stoppedRun?.healthWorkoutID == exporter.lastID)
    }

    @Test("Health's latest body weight is used over the one entered in Settings")
    func bodyMassFromHealth() {
        settings.set(80.0, forKey: SettingsKey.bodyMass)
        #expect(settings.bodyMass == 80)

        settings.set(72.4, forKey: SettingsKey.healthBodyMass)
        #expect(settings.bodyMass == 72.4)
    }

    @Test("Turning Health on asks for permission, and stays off if it's refused")
    func connect() async {
        let allowed = FakeHealthExporter()
        let refused = FakeHealthExporter(refuses: true)

        #expect(await sync(allowed).connect())
        #expect(settings.bool(forKey: SettingsKey.saveToHealth))
        settings.set(false, forKey: SettingsKey.saveToHealth)
        #expect(await !sync(refused).connect())
        #expect(!settings.bool(forKey: SettingsKey.saveToHealth))
        #expect(allowed.authorizationRequests == 1)
    }
}

/// Keeps what it's asked to save and delete, in memory.
final class FakeHealthExporter: HealthExporter {
    let fails: Bool
    let refuses: Bool
    private(set) var saved: [HealthWorkout] = []
    private(set) var deleted: [UUID] = []
    private(set) var lastID: UUID?
    private(set) var authorizationRequests = 0
    private var canWrite = false

    struct Unavailable: Error {}

    init(fails: Bool = false, refuses: Bool = false) {
        self.fails = fails
        self.refuses = refuses
    }

    var isAvailable: Bool { true }
    var isWriteAllowed: Bool { canWrite }

    func requestAuthorization() async throws {
        authorizationRequests += 1
        canWrite = !refuses
    }

    func save(_ workout: HealthWorkout) async throws -> UUID {
        if fails { throw Unavailable() }
        saved.append(workout)
        let id = UUID()
        lastID = id
        return id
    }

    func deleteWorkout(_ id: UUID) async throws {
        deleted.append(id)
    }

    func latestBodyMass() async -> Double? { nil }
}
