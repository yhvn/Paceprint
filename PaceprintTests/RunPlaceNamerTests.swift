import Foundation
import SwiftData
import Testing
import PaceprintCore
@testable import Paceprint

@Suite("Run place names")
struct RunPlaceNamerTests {
    let container: ModelContainer
    /// 7:30 on a Monday morning, local time.
    let morning = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 7, minute: 30))!

    init() throws {
        container = try ModelContainer(for: Run.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// A finished 1 km Run due north, started this morning.
    private func savedRun() -> Run {
        let points = stride(from: 0.0, through: 1_000, by: 10).map {
            RoutePoint(timestamp: morning + $0 * 0.36, latitude: 40.78 + $0 / 111_195, longitude: -73.966, altitude: 30, horizontalAccuracy: 5, cumulativeDistance: $0, isPaused: false)
        }
        let run = Run(startDate: morning)
        run.finish(RunTracker(runStart: morning, points: points, pauses: []), at: morning + 360)
        container.mainContext.insert(run)
        return run
    }

    private func namer(_ lookup: FakePlaceLookup) -> RunPlaceNamer {
        RunPlaceNamer(lookup: lookup, modelContext: container.mainContext, requestSpacing: .zero)
    }

    private static let park = Placemark(areasOfInterest: ["Central Park"], neighbourhood: "Manhattan", city: "New York", region: "NY", country: "United States")

    @Test("A stopped Run is named from lookups along its Route, and keeps the name")
    func named() async {
        let run = savedRun()
        let lookup = FakePlaceLookup(answer: .found(Self.park))

        await namer(lookup).name(run)

        #expect(lookup.lookups == 5)
        #expect(run.placeNameShown == "CENTRAL PARK")
        #expect(run.placeContext == ["Manhattan", "New York"])
        #expect(run.isPlaceLookedUp)
    }

    @Test("Until it's named, a Run goes by the time of day it started")
    func timeOfDayUntilNamed() {
        let run = savedRun()

        #expect(run.placeNameShown == "MORNING RUN")
        #expect(run.placeContext.isEmpty)
    }

    @Test("A lookup that fails, e.g. offline, is tried again on a later launch")
    func retried() async {
        let run = savedRun()

        await namer(FakePlaceLookup(answer: .fails)).name(run)
        #expect(run.placeNameShown == "MORNING RUN")
        #expect(!run.isPlaceLookedUp)

        await namer(FakePlaceLookup(answer: .found(Self.park))).nameRunsAwaitingPlace()
        #expect(run.placeNameShown == "CENTRAL PARK")
    }

    @Test("A lookup that works but finds no place keeps the time-of-day name for good")
    func nothingFound() async {
        let run = savedRun()

        await namer(FakePlaceLookup(answer: .nothing)).name(run)
        let later = FakePlaceLookup(answer: .found(Self.park))
        await namer(later).nameRunsAwaitingPlace()

        #expect(run.placeNameShown == "MORNING RUN")
        #expect(run.isPlaceLookedUp)
        #expect(later.lookups == 0)
    }

    @Test("At launch, Runs waiting for their place stop at the first failed lookup, so the rest wait for a later launch")
    func retryStopsAtFailure() async {
        _ = savedRun()
        _ = savedRun()
        let lookup = FakePlaceLookup(answer: .fails)

        await namer(lookup).nameRunsAwaitingPlace()

        #expect(lookup.lookups == 1)
    }

    @Test("A Route that can't be read keeps its time-of-day name, rather than being looked up on every launch")
    func unreadableRoute() async {
        let run = savedRun()
        run.routeData = Data([99])
        let lookup = FakePlaceLookup(answer: .found(Self.park))

        await namer(lookup).name(run)

        #expect(run.isPlaceLookedUp)
        #expect(run.placeNameShown == "MORNING RUN")
        #expect(lookup.lookups == 0)
    }

    @Test("A Run deleted while its place is looked up isn't written to")
    func deletedDuringLookup() async throws {
        let run = savedRun()
        try container.mainContext.save()
        let lookup = FakePlaceLookup(answer: .found(Self.park)) { [container] in
            container.mainContext.delete(run)
            try? container.mainContext.save()
        }

        await namer(lookup).name(run)

        #expect(try container.mainContext.fetch(FetchDescriptor<Run>()).isEmpty)
    }

    @Test("Stopping a Run names it")
    func namedOnStop() async throws {
        let lookup = FakePlaceLookup(answer: .found(Self.park))
        let clock = TestClock()
        let source = ScriptedLocationSource(script: (0...30).map {
            .fix(LocationFix(timestamp: clock.now + Double($0) * 4, latitude: 40.78 + Double($0) * 0.0001, longitude: -73.966, altitude: 30, horizontalAccuracy: 5))
        }, clock: clock)
        let recorder = RunRecorder(source: source, modelContext: container.mainContext, placeNamer: namer(lookup), now: { clock.now })

        await recorder.start()
        await recorder.waitUntilSourceFinishes()
        recorder.stop()
        await recorder.waitUntilPlaceIsNamed()

        #expect(recorder.stoppedRun?.placeNameShown == "CENTRAL PARK")
    }
}

/// Answers every lookup the same way, and counts them.
final class FakePlaceLookup: PlaceLookup {
    enum Answer {
        case found(Placemark)
        case nothing
        case fails
    }

    struct Offline: Error {}

    let answer: Answer
    /// Runs during the first lookup, as if something happened while it was out.
    private var duringFirstLookup: (() -> Void)?
    private(set) var lookups = 0

    init(answer: Answer, duringFirstLookup: (() -> Void)? = nil) {
        self.answer = answer
        self.duringFirstLookup = duringFirstLookup
    }

    func placemark(latitude: Double, longitude: Double) async throws -> Placemark? {
        lookups += 1
        duringFirstLookup?()
        duringFirstLookup = nil
        switch answer {
        case .found(let placemark): return placemark
        case .nothing: return nil
        case .fails: throw Offline()
        }
    }
}
