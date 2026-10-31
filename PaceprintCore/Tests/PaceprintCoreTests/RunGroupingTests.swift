import Foundation
import Testing
import PaceprintCore

/// A calendar in UTC, with weeks starting on `firstWeekday` (1 = Sunday, 2 = Monday).
private func calendar(firstWeekday: Int) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.firstWeekday = firstWeekday
    return calendar
}

/// `2026-10-<day> <hour>:00` UTC. 25 October 2026 is a Sunday.
private func october(_ day: Int, _ hour: Int = 9) -> Date {
    calendar(firstWeekday: 2).date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
}

private struct FakeRun: Equatable {
    let start: Date
    var distance = 5_000.0
    var movingTime = 1_800.0
}

@Suite("Run grouping and totals")
struct RunGroupingTests {
    // Wednesday 28 October.
    let now = october(28, 12)

    @Test("THIS WEEK counts Runs started since the locale's first weekday", arguments: [
        // Monday-first: the week began Monday 26th, so Sunday 25th is last week.
        (firstWeekday: 2, counted: [october(26, 6), october(28, 7)]),
        // Sunday-first: the week began Sunday 25th.
        (firstWeekday: 1, counted: [october(25, 8), october(26, 6), october(28, 7)]),
    ])
    func thisWeek(firstWeekday: Int, counted: [Date]) {
        let runs = [october(24, 8), october(25, 8), october(26, 6), october(28, 7)].map { FakeRun(start: $0) }

        let thisWeek = RunGrouping.startedThisWeek(runs, startedAt: \.start, now: now, calendar: calendar(firstWeekday: firstWeekday))

        #expect(thisWeek.map(\.start) == counted)
    }

    @Test("A Run crossing midnight into a new week counts in the week it started")
    func crossingMidnight() {
        // Started Sunday 25th 23:30, on a Monday-first calendar: last week.
        let runs = [FakeRun(start: october(25, 23) + 1_800)]

        #expect(RunGrouping.startedThisWeek(runs, startedAt: \.start, now: now, calendar: calendar(firstWeekday: 2)).isEmpty)
    }

    @Test("THIS WEEK starts at the first weekday's midnight and stops just before the next")
    func weekBoundaries() {
        // Monday-first: this week runs from Monday 26th 00:00 up to, not including, Monday 2 November 00:00.
        let nextMonday = calendar(firstWeekday: 2).date(from: DateComponents(year: 2026, month: 11, day: 2))!
        let runs = [october(26, 0), nextMonday - 1, nextMonday].map { FakeRun(start: $0) }

        let thisWeek = RunGrouping.startedThisWeek(runs, startedAt: \.start, now: now, calendar: calendar(firstWeekday: 2))

        #expect(thisWeek.map(\.start) == [october(26, 0), nextMonday - 1])
    }

    @Test("History groups Runs by the month they started, newest month and newest Run first")
    func byMonth() {
        let cal = calendar(firstWeekday: 2)
        let september = cal.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 23))!
        let lastYear = cal.date(from: DateComponents(year: 2025, month: 10, day: 3))!
        let runs = [october(2), september, october(28), lastYear].map { FakeRun(start: $0) }

        let groups = RunGrouping.byMonth(runs, startedAt: \.start, calendar: cal)

        #expect(groups.map(\.start) == [
            cal.date(from: DateComponents(year: 2026, month: 10))!,
            cal.date(from: DateComponents(year: 2026, month: 9))!,
            cal.date(from: DateComponents(year: 2025, month: 10))!,
        ])
        #expect(groups.map { $0.runs.map(\.start) } == [[october(28), october(2)], [september], [lastYear]])
    }

    @Test("Totals add distance, Runs and Moving time; Average pace is all Moving time over all distance")
    func totals() throws {
        let runs = [FakeRun(start: october(26), distance: 5_000, movingTime: 1_500), FakeRun(start: october(27), distance: 1_000, movingTime: 420)]

        let totals = RunTotals(runs, distance: \.distance, movingTime: \.movingTime)

        #expect(totals.distance == 6_000)
        #expect(totals.runCount == 2)
        #expect(totals.movingTime == 1_920)
        // 1,920 s over 6 km: 5:20 /km, not the mean of 5:00 and 7:00.
        #expect(try #require(totals.averagePace).seconds(per: .kilometers) == 320)
    }

    @Test("No Runs total nothing, with no Average pace")
    func noRuns() {
        let totals = RunTotals([FakeRun](), distance: \.distance, movingTime: \.movingTime)

        #expect(totals == RunTotals(distance: 0, runCount: 0, movingTime: 0))
        #expect(totals.averagePace == nil)
    }
}
