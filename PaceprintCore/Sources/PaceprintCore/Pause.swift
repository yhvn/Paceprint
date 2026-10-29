import Foundation

/// A stretch of a Run during which nothing counts toward its distance, Moving time or Route.
public struct Pause: Codable, Equatable, Sendable {
    public var start: Date
    /// When the Run was resumed; nil while the Pause is still going.
    public var end: Date?

    public init(start: Date, end: Date?) {
        self.start = start
        self.end = end
    }

    /// Whether `date` falls inside this Pause. A Pause includes its start but not its end.
    func contains(_ date: Date) -> Bool {
        date >= start && end.map { date < $0 } ?? true
    }
}
