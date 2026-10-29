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
    /// Metres.
    var distance: Double
    /// The Route's points in `RouteEncoding`'s versioned format.
    @Attribute(.externalStorage) var routeData: Data

    init(startDate: Date, endDate: Date, route: [RoutePoint]) {
        self.startDate = startDate
        self.endDate = endDate
        elapsedTime = endDate.timeIntervalSince(startDate)
        distance = route.last?.cumulativeDistance ?? 0
        routeData = RouteEncoding.encode(route)
    }

    func decodedRoute() throws -> [RoutePoint] {
        try RouteEncoding.decode(routeData)
    }
}
