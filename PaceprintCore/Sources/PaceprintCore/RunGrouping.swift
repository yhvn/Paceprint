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
        public let month: Date
        public let runs: [Run]
    }

    /// `runs` grouped by the month they started in, newest month first.
    public static func byMonth<Run>(_ runs: [Run], startedAt: (Run) -> Date, calendar: Calendar) -> [Month<Run>] {
        let newestFirst = runs.sorted { startedAt($0) > startedAt($1) }
        var months: [Month<Run>] = []
        for run in newestFirst {
            guard let month = calendar.dateInterval(of: .month, for: startedAt(run))?.start else { continue }
            if months.last?.month == month {
                months[months.count - 1] = Month(month: month, runs: months[months.count - 1].runs + [run])
            } else {
                months.append(Month(month: month, runs: [run]))
            }
        }
        return months
    }
}

/// Distance, Runs and Moving time added up over some Runs, e.g. all of History.
public struct RunTotals: Equatable, Sendable {
    /// Metres.
    public let distance: Double
    public let runs: Int
    public let movingTime: TimeInterval

    public init(distance: Double, runs: Int, movingTime: TimeInterval) {
        self.distance = distance
        self.runs = runs
        self.movingTime = movingTime
    }

    public init<Run>(_ runs: [Run], distance: (Run) -> Double, movingTime: (Run) -> TimeInterval) {
        self.init(
            distance: runs.reduce(0) { $0 + distance($1) },
            runs: runs.count,
            movingTime: runs.reduce(0) { $0 + movingTime($1) }
        )
    }

    /// All the Moving time over all the distance, not a mean of each Run's Pace; nil under 0.1 km.
    public var averagePace: Pace? {
        Pace.average(movingTime: movingTime, distance: distance)
    }
}
