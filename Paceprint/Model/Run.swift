import Foundation
import PaceprintCore
import SwiftData

/// A recorded Run. Summary numbers sit beside the Route so lists never decode it (ADR 0001).
@Model
final class Run {
    var startDate: Date
    /// When the Run was stopped; for an unfinished Run, when it was last checkpointed.
    var endDate: Date
    /// Seconds from Start to `endDate`, Pauses included.
    var elapsedTime: TimeInterval
    /// Seconds from Start to `endDate` with Pauses removed: the TIME shown.
    var movingTime: TimeInterval = 0
    /// Every Pause, the source of truth for Moving time. All ended once the Run is finished.
    var pauses: [Pause] = []
    /// Metres.
    var distance: Double
    /// The Route's points in `RouteEncoding`'s versioned format.
    @Attribute(.externalStorage) var routeData: Data
    /// False while the Run is still being recorded: it's only a checkpoint, kept in case the app is
    /// killed, and never shown in History or totals.
    var isFinished = true

    /// Runs that were stopped and saved: everything History and totals show.
    static var finished: Predicate<Run> {
        #Predicate { $0.isFinished }
    }

    /// Runs still being recorded, or left behind when the app was killed.
    static var unfinished: Predicate<Run> {
        #Predicate { !$0.isFinished }
    }

    /// An unfinished Run started at `startDate`, with nothing recorded yet.
    init(startDate: Date) {
        self.startDate = startDate
        endDate = startDate
        elapsedTime = 0
        distance = 0
        routeData = RouteEncoding.encode([])
        isFinished = false
    }

    /// Replaces what's stored with what `tracker` has recorded up to `date`; the Run stays unfinished.
    func checkpoint(_ tracker: RunTracker, at date: Date) {
        endDate = date
        elapsedTime = date.timeIntervalSince(tracker.runStart)
        movingTime = tracker.movingTime(at: date)
        pauses = tracker.pauses
        distance = tracker.distance
        routeData = RouteEncoding.encode(tracker.points)
    }

    /// Stores the Run `tracker` recorded, stopped at `date`, and marks it finished.
    /// A Pause still going ends at Stop.
    func finish(_ tracker: RunTracker, at date: Date) {
        checkpoint(tracker, at: date)
        pauses = tracker.pauses.map { Pause(start: $0.start, end: $0.end ?? date) }
        isFinished = true
    }

    func decodedRoute() throws -> [RoutePoint] {
        try RouteEncoding.decode(routeData)
    }

    /// A tracker carrying on from what this Run has stored.
    func resumedTracker() throws -> RunTracker {
        RunTracker(runStart: startDate, points: try decodedRoute(), pauses: pauses)
    }
}
