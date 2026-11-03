import Foundation
import Testing
import PaceprintCore
@testable import Paceprint

@Suite("What VoiceOver says")
struct SpokenFormatTests {
    @Test("Active run reads its metrics as one sentence")
    func activeRun() {
        let summary = SpokenFormat.activeRun(distance: 3_420, movingTime: 1_084, pace: Pace(secondsPerMetre: 0.316), units: .kilometers)

        #expect(summary == "Distance 3.42 kilometres. Time 18 minutes, 4 seconds. Pace 5 minutes, 16 seconds per kilometre.")
    }

    @Test("Before there's a Pace to give, Active run says so")
    func activeRunNoPace() {
        let summary = SpokenFormat.activeRun(distance: 40, movingTime: 12, pace: nil, units: .miles)

        #expect(summary == "Distance 0.02 miles. Time 12 seconds. No pace yet.")
    }

    @Test("A completed Split is announced with its number and time")
    func splitAnnouncement() {
        let split = Split(number: 3, distance: 1_000, movingTime: 312, cumulativeMovingTime: 960, isPartial: false)

        #expect(SpokenFormat.splitCompleted(split, units: .kilometers) == "Kilometre 3, 5 minutes, 12 seconds")
    }

    @Test("A Split row reads its Pace and the total Moving time; the Partial split its real distance")
    func splitRow() {
        let whole = Split(number: 1, distance: 1_000, movingTime: 301, cumulativeMovingTime: 301, isPartial: false)
        let partial = Split(number: 3, distance: 370, movingTime: 111, cumulativeMovingTime: 711, isPartial: true)

        #expect(SpokenFormat.splitRow(whole, units: .kilometers) == "Kilometre 1, 5 minutes, 1 second per kilometre, total 5 minutes, 1 second")
        #expect(SpokenFormat.splitRow(partial, units: .kilometers) == "Last 0.37 kilometres, 5 minutes per kilometre, total 11 minutes, 51 seconds")
    }

    @Test("The Route map names its length and where it started")
    func routeMap() {
        #expect(SpokenFormat.routeMap(distance: 5_420, startingIn: "Central Park", units: .kilometers) == "Route map, 5.42 kilometres, starting in Central Park")
        #expect(SpokenFormat.routeMap(distance: 1_609.344, startingIn: nil, units: .miles) == "Route map, 1 mile")
    }

    @Test("Drawn over a photo, the Route isn't called a map")
    func routeOverPhoto() {
        #expect(SpokenFormat.route(distance: 5_420, startingIn: "Central Park", units: .kilometers) == "Route, 5.42 kilometres, starting in Central Park")
    }
}
