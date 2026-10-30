import Foundation

/// How Home and History pick out and group Runs by the calendar. Generic over the Run type so
/// the app can pass its stored Runs.
public enum RunGrouping {
    /// The Runs that started in the calendar week containing `now`; the week begins on `calendar`'s
    /// first weekday, as the locale sets it. A Run crossing midnight counts on the day it started.
    public static func startedThisWeek<Run>(_ runs: [Run], startedAt: (Run) -> Date, now: Date, calendar: Calendar) -> [Run] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        return runs.filter { week.start <= startedAt($0) && startedAt($0) < week.end }
    }

    /// One month of History: the Runs that started in it, newest first.
    public struct Month<Run> {
        /// The first moment of the month.
        public let start: Date
        public let runs: [Run]
    }

    /// `runs` grouped by the month they started in, newest month first.
    public static func byMonth<Run>(_ runs: [Run], startedAt: (Run) -> Date, calendar: Calendar) -> [Month<Run>] {
        let newestFirst = runs.sorted { startedAt($0) > startedAt($1) }
        var months: [Month<Run>] = []
        for run in newestFirst {
            guard let start = calendar.dateInterval(of: .month, for: startedAt(run))?.start else { continue }
            if months.last?.start == start {
                months[months.count - 1] = Month(start: start, runs: months[months.count - 1].runs + [run])
            } else {
                months.append(Month(start: start, runs: [run]))
            }
        }
        return months
    }
}

extension RunGrouping.Month: Sendable where Run: Sendable {}

/// Distance, Runs and Moving time added up over some Runs, e.g. all of History.
public struct RunTotals: Equatable, Sendable {
    /// Metres.
    public let distance: Double
    public let runCount: Int
    public let movingTime: TimeInterval

    public init(distance: Double, runCount: Int, movingTime: TimeInterval) {
        self.distance = distance
        self.runCount = runCount
        self.movingTime = movingTime
    }

    public init<Run>(_ runs: [Run], distance: (Run) -> Double, movingTime: (Run) -> TimeInterval) {
        self.init(
            distance: runs.reduce(0) { $0 + distance($1) },
            runCount: runs.count,
            movingTime: runs.reduce(0) { $0 + movingTime($1) }
        )
    }

    /// Average pace across all these Runs: all their Moving time over all their distance, not a mean
    /// of each Run's Average pace; nil under 0.1 km.
    public var averagePace: Pace? {
        Pace.average(movingTime: movingTime, distance: distance)
    }
}
