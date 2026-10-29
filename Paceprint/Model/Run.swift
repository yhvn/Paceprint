import Foundation
import PaceprintCore
import SwiftData

/// A recorded Run. Summary numbers sit beside the Route so lists never decode it (ADR 0001).
@Model
final class Run {
    var startDate: Date
    var endDate: Date
    /// Seconds from Start to Stop, Pauses included.
    var elapsedTime: TimeInterval
    /// Seconds from Start to Stop with Pauses removed: the TIME shown.
    var movingTime: TimeInterval = 0
    /// Every Pause, all ended; the source of truth for Moving time.
    var pauses: [Pause] = []
    /// Metres.
    var distance: Double
    /// The Route's points in `RouteEncoding`'s versioned format.
    @Attribute(.externalStorage) var routeData: Data

    /// The Run `tracker` recorded, stopped at `endDate`. A Pause still going ends at Stop.
    init(_ tracker: RunTracker, endDate: Date) {
        startDate = tracker.runStart
        self.endDate = endDate
        elapsedTime = endDate.timeIntervalSince(tracker.runStart)
        movingTime = tracker.movingTime(at: endDate)
        pauses = tracker.pauses.map { Pause(start: $0.start, end: $0.end ?? endDate) }
        distance = tracker.distance
        routeData = RouteEncoding.encode(tracker.points)
    }

    func decodedRoute() throws -> [RoutePoint] {
        try RouteEncoding.decode(routeData)
    }
}
