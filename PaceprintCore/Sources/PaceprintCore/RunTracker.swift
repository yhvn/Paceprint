import Foundation

/// A Run in progress: builds its Route as fixes arrive, dropping noisy ones,
/// and keeps its Pauses and running distance.
public struct RunTracker: Sendable {
    /// Distance below which Average pace is too unsteady to show.
    static let averagePaceMinimumDistance = 100.0
    /// How much recent Moving time Current pace covers.
    static let currentPaceWindow: TimeInterval = 30
    /// Current pace slower than this, 20:00 /km, isn't shown.
    static let currentPaceSlowest = Pace(secondsPerMetre: 1.2)
    /// GPS counts as weak once no point has been kept for this long.
    static let weakGPSAfter: TimeInterval = 10

    public let runStart: Date
    public private(set) var points: [RoutePoint] = []
    public private(set) var pauses: [Pause] = []
    /// The system reported the device stationary and has stopped sending fixes until it moves.
    private var isStationary = false

    /// Metres covered so far.
    public var distance: Double { points.last?.cumulativeDistance ?? 0 }
    public var isPaused: Bool { pauses.last.map { $0.end == nil } ?? false }

    public init(runStart: Date) {
        self.runStart = runStart
    }

    /// Seconds from Start to `date` with Pauses removed.
    public func movingTime(at date: Date) -> TimeInterval {
        let paused = pauses.reduce(0.0) { total, pause in
            let end = min(pause.end ?? date, date)
            return total + max(0, end.timeIntervalSince(pause.start))
        }
        return date.timeIntervalSince(runStart) - paused
    }

    /// Whether GPS is still being found, has gone weak, or is fine at `date`.
    public func gpsStatus(at date: Date) -> GPSStatus {
        guard let last = points.last else { return .finding }
        guard !isStationary else { return .good }
        return date.timeIntervalSince(last.timestamp) >= Self.weakGPSAfter ? .weak : .good
    }

    /// Notes that the system reported the device stationary: no fixes will come until it moves,
    /// and that isn't weak GPS. The next kept point ends it.
    public mutating func markStationary() {
        isStationary = true
    }

    /// Moving time over distance, or nil until 0.1 km.
    public func averagePace(at date: Date) -> Pace? {
        guard distance >= Self.averagePaceMinimumDistance else { return nil }
        return Pace(secondsPerMetre: movingTime(at: date) / distance)
    }

    /// The Pace over the last 30 s of Moving time up to the latest point, or nil for the first 30 s,
    /// when standing still, or when slower than 20:00 /km. The window ends at the latest point rather
    /// than now, so the time since that fix isn't counted against distance not yet measured.
    public var currentPace: Pace? {
        guard let last = points.last else { return nil }
        let windowStart = movingTime(at: last.timestamp) - Self.currentPaceWindow
        guard windowStart >= 0 else { return nil }

        let metres = last.cumulativeDistance - distance(atMovingTime: windowStart)
        guard metres > 0 else { return nil }
        let pace = Pace(secondsPerMetre: Self.currentPaceWindow / metres)
        return pace.secondsPerMetre <= Self.currentPaceSlowest.secondsPerMetre ? pace : nil
    }

    /// The distance covered after `movingTime` seconds of Moving time, interpolated between points.
    private func distance(atMovingTime target: TimeInterval) -> Double {
        // Walk back from the newest point: the window only ever reaches a few points back.
        var later: (movingTime: TimeInterval, distance: Double)?
        for point in points.reversed() {
            let current = (movingTime: movingTime(at: point.timestamp), distance: point.cumulativeDistance)
            if current.movingTime <= target {
                guard let later, later.movingTime > current.movingTime else { return current.distance }
                let fraction = (target - current.movingTime) / (later.movingTime - current.movingTime)
                return current.distance + fraction * (later.distance - current.distance)
            }
            later = current
        }
        // The window starts before the first point: nothing had been covered yet.
        return points.first?.cumulativeDistance ?? 0
    }

    /// Starts a Pause at `date`, unless one is already going.
    public mutating func pause(at date: Date) {
        guard !isPaused else { return }
        pauses.append(Pause(start: date, end: nil))
    }

    /// Ends the Pause that's going, if any, at `date`.
    public mutating func resume(at date: Date) {
        guard isPaused else { return }
        pauses[pauses.count - 1].end = date
    }

    /// Adds `fix` to the Route if it passes the noise filter, returning the new point, else nil.
    /// A fix taken during a Pause is kept, flagged paused, and adds no distance.
    public mutating func add(_ fix: LocationFix) -> RoutePoint? {
        let last = points.last
        // Anything covered across a Pause, even one with no fix kept inside it, counts for nothing.
        let crossesPause = last.map { last in
            pauses.contains { $0.start <= fix.timestamp && ($0.end.map { $0 > last.timestamp } ?? true) }
        } ?? false
        guard NoiseFilter.accepts(fix, runStart: runStart, after: last, acrossPause: crossesPause) else { return nil }

        let isPaused = pauses.contains { $0.contains(fix.timestamp) }
        var cumulativeDistance = last?.cumulativeDistance ?? 0
        if let last, !crossesPause {
            cumulativeDistance += last.distance(to: fix)
        }
        let point = RoutePoint(
            timestamp: fix.timestamp,
            latitude: fix.latitude,
            longitude: fix.longitude,
            altitude: fix.altitude,
            horizontalAccuracy: fix.horizontalAccuracy,
            cumulativeDistance: cumulativeDistance,
            isPaused: isPaused
        )
        points.append(point)
        isStationary = false
        return point
    }
}
