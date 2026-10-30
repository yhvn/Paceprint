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

    public var pace: Pace {
        Pace(secondsPerMetre: movingTime / distance)
    }
}

extension RunTracker {
    /// A Partial split shorter than this is rounding noise, not a Split.
    static let shortestPartialSplit = 1.0

    /// The Route cut into Splits of one `unit` each, then the Partial split left over. Pauses don't
    /// count toward any Split's Moving time; the time before the first point counts toward the first,
    /// as it does toward TIME.
    public func splits(per unit: DistanceUnit) -> [Split] {
        // Moving time against distance covered, from Start; both only ever grow.
        let samples = [(distance: 0.0, movingTime: 0.0)]
            + points.map { (distance: $0.cumulativeDistance, movingTime: movingTime(at: $0.timestamp)) }
        let total = distance
        let wholeSplits = Int((total / unit.metresPerUnit).rounded(.down))

        var splits: [Split] = []
        var previousEnd = 0.0
        func addSplit(to end: Double, distance: Double, isPartial: Bool) {
            let endTime = Self.movingTime(atDistance: end, in: samples)
            splits.append(Split(
                number: splits.count + 1,
                distance: distance,
                movingTime: endTime - previousEnd,
                cumulativeMovingTime: endTime,
                isPartial: isPartial
            ))
            previousEnd = endTime
        }
        for number in stride(from: 1, through: wholeSplits, by: 1) {
            addSplit(to: Double(number) * unit.metresPerUnit, distance: unit.metresPerUnit, isPartial: false)
        }
        let rest = total - Double(wholeSplits) * unit.metresPerUnit
        if rest >= Self.shortestPartialSplit {
            addSplit(to: total, distance: rest, isPartial: true)
        }
        return splits
    }

    /// The Moving time when `distance` was first reached, interpolated between samples.
    private static func movingTime(atDistance distance: Double, in samples: [(distance: Double, movingTime: Double)]) -> Double {
        guard let after = samples.firstIndex(where: { $0.distance >= distance }), after > 0 else {
            return samples[0].movingTime
        }
        let a = samples[after - 1], b = samples[after]
        let fraction = (distance - a.distance) / (b.distance - a.distance)
        return a.movingTime + fraction * (b.movingTime - a.movingTime)
    }
}
