import Foundation

/// The part of a Run covering one whole unit of distance, or the Partial split left over after the last.
public struct Split: Equatable, Sendable {
    /// 1 for the first Split.
    public let number: Int
    /// Metres covered: one whole unit, or less for the Partial split.
    public let distance: Double
    /// Moving time the Split took.
    public let movingTime: TimeInterval
    /// Moving time from Start to the end of this Split.
    public let cumulativeMovingTime: TimeInterval
    public let isPartial: Bool

    public init(number: Int, distance: Double, movingTime: TimeInterval, cumulativeMovingTime: TimeInterval, isPartial: Bool) {
        self.number = number
        self.distance = distance
        self.movingTime = movingTime
        self.cumulativeMovingTime = cumulativeMovingTime
        self.isPartial = isPartial
    }

    public var pace: Pace {
        Pace(secondsPerMetre: movingTime / distance)
    }
}

extension RunTracker {
    /// A leftover shorter than this isn't worth its own row; its time goes to the Split before it.
    static let shortestPartialSplit = 10.0

    /// Moving time against distance covered; both only ever grow along a Run.
    private struct Sample {
        let distance: Double
        let movingTime: TimeInterval
    }

    /// The Route cut into Splits of one `unit` each, then the Partial split left over, for a Run
    /// stopped at `stop`. Pauses don't count toward any Split's Moving time. The time before the
    /// first point counts toward the first Split and the time after the last toward the last, as
    /// both count toward TIME.
    public func splits(per unit: DistanceUnit, until stop: Date) -> [Split] {
        let samples = [Sample(distance: 0, movingTime: 0)]
            + points.map { Sample(distance: $0.cumulativeDistance, movingTime: movingTime(at: $0.timestamp)) }
        let total = distance
        var wholeSplits = Int(total / unit.metresPerUnit)
        // Floating point can round a hair under a whole unit up to it.
        if Double(wholeSplits) * unit.metresPerUnit > total {
            wholeSplits -= 1
        }
        let rest = total - Double(wholeSplits) * unit.metresPerUnit
        let hasPartialSplit = rest >= Self.shortestPartialSplit

        var ends = (0..<wholeSplits).map { (distance: Double($0 + 1) * unit.metresPerUnit, isPartial: false) }
        if hasPartialSplit {
            ends.append((distance: total, isPartial: true))
        }

        var splits: [Split] = []
        var previousEnd: (distance: Double, movingTime: TimeInterval) = (0, 0)
        for (index, end) in ends.enumerated() {
            let isLast = index == ends.count - 1
            let endTime = isLast ? movingTime(at: stop) : Self.movingTime(atDistance: end.distance, in: samples)
            splits.append(Split(
                number: index + 1,
                distance: end.distance - previousEnd.distance,
                movingTime: endTime - previousEnd.movingTime,
                cumulativeMovingTime: endTime,
                isPartial: end.isPartial
            ))
            previousEnd = (end.distance, endTime)
        }
        return splits
    }

    /// The Moving time when `distance` was first reached, interpolated between samples.
    private static func movingTime(atDistance distance: Double, in samples: [Sample]) -> TimeInterval {
        guard let after = samples.firstIndex(where: { $0.distance >= distance }) else {
            return samples[samples.count - 1].movingTime
        }
        guard after > 0 else { return samples[0].movingTime }
        let a = samples[after - 1], b = samples[after]
        let fraction = (distance - a.distance) / (b.distance - a.distance)
        return a.movingTime + fraction * (b.movingTime - a.movingTime)
    }
}
