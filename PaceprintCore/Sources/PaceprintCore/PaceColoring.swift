import Foundation

/// Where a Pace sits on the pace gradient: 0 is the palette's fast end, 0.5 its middle (the Run's
/// Average pace), 1 its slow end. Palettes turn it into an actual color.
public struct PaceColor: Hashable, Sendable {
    public let position: Double

    public init(position: Double) {
        self.position = position
    }

    /// A Pace this much faster or slower than average, in seconds per metre (30 s/km), gets the
    /// palette's end color.
    static let fullColorDifference = 0.03

    /// Where `pace` sits compared with `average`: its end colors 30 s/km or more either side,
    /// in between linearly. The middle without either.
    public init(_ pace: Pace?, comparedWith average: Pace?) {
        guard let pace, let average else {
            self = .average
            return
        }
        let difference = (pace.secondsPerMetre - average.secondsPerMetre) / Self.fullColorDifference
        position = 0.5 + min(max(difference, -1), 1) / 2
    }

    /// The Run's Average pace.
    public static let average = PaceColor(position: 0.5)
}

/// A stretch of Route drawn in one Pace color.
public struct RoutePiece: Equatable, Sendable {
    public let points: [RoutePoint]
    public let color: PaceColor
}

/// Cuts a Route into what's drawn: the stretches between Pauses, and pieces in Pace colors.
public enum PaceColoring {
    /// Each point's Pace is taken over this many metres around it.
    static let smoothingDistance = 100.0
    /// Pace colors are rounded to this many steps either side of the middle, so neighbouring
    /// stretches of similar Pace share a color and merge into one piece.
    static let stepsPerSide = 10.0

    /// The continuous stretches of the Route: it breaks at every Pause, and points taken during one
    /// aren't drawn. A stretch of a single point has nothing to draw and is left out.
    public static func stretches(of route: [RoutePoint], pauses: [Pause]) -> [[RoutePoint]] {
        var stretches: [[RoutePoint]] = []
        var current: [RoutePoint] = []
        for point in route where !point.isPaused {
            if let last = current.last, pauses.contains(where: { $0.falls(between: last.timestamp, and: point.timestamp) }) {
                stretches.append(current)
                current = []
            }
            current.append(point)
        }
        stretches.append(current)
        return stretches.filter { $0.count >= 2 }
    }

    /// The Route as pieces of one Pace color each, compared with `averagePace`; all the middle color
    /// without one. Each point's Pace is averaged over the surrounding 100 m of its stretch (less near
    /// its ends), each piece between two points takes the color between theirs, and neighbouring
    /// pieces of the same color are merged.
    public static func pieces(of route: [RoutePoint], pauses: [Pause], averagePace: Pace?) -> [RoutePiece] {
        stretches(of: route, pauses: pauses).flatMap { stretch in
            let colors = segmentColors(of: stretch, averagePace: averagePace)
            var pieces: [RoutePiece] = []
            var pieceStart = 0
            var pieceColor: PaceColor?
            for (index, color) in colors.enumerated() {
                guard color != pieceColor else { continue }
                if let pieceColor {
                    pieces.append(RoutePiece(points: Array(stretch[pieceStart...index]), color: pieceColor))
                }
                pieceStart = index
                pieceColor = color
            }
            if let pieceColor {
                pieces.append(RoutePiece(points: Array(stretch[pieceStart...]), color: pieceColor))
            }
            return pieces
        }
    }

    /// The Pace color of each segment of `stretch`, between one point and the next: the color between
    /// its two points', each point's Pace averaged over the surrounding 100 m, rounded to a step.
    static func segmentColors(of stretch: [RoutePoint], averagePace: Pace?) -> [PaceColor] {
        let positions = stretch.indices.map { index in
            PaceColor(smoothedPace(at: index, in: stretch), comparedWith: averagePace).position
        }
        return stretch.indices.dropLast().map { index in
            PaceColor(position: rounded((positions[index] + positions[index + 1]) / 2))
        }
    }

    /// The Pace over the 100 m of `stretch` around the point at `index`, or nil if it covers no distance.
    private static func smoothedPace(at index: Int, in stretch: [RoutePoint]) -> Pace? {
        let distance = stretch[index].cumulativeDistance
        let from = max(stretch[0].cumulativeDistance, distance - smoothingDistance / 2)
        let to = min(stretch[stretch.count - 1].cumulativeDistance, distance + smoothingDistance / 2)
        guard to > from else { return nil }
        let seconds = time(atDistance: to, in: stretch).timeIntervalSince(time(atDistance: from, in: stretch))
        return Pace(secondsPerMetre: seconds / (to - from))
    }

    /// When `stretch` first reached `distance`, interpolated between points.
    private static func time(atDistance distance: Double, in stretch: [RoutePoint]) -> Date {
        // Distance only grows along a stretch: binary search for the first point at or past `distance`.
        var low = 0, high = stretch.count
        while low < high {
            let middle = (low + high) / 2
            if stretch[middle].cumulativeDistance < distance { low = middle + 1 } else { high = middle }
        }
        let after = low
        guard after > 0, after < stretch.count else {
            return stretch[min(after, stretch.count - 1)].timestamp
        }
        let a = stretch[after - 1], b = stretch[after]
        let fraction = (distance - a.cumulativeDistance) / (b.cumulativeDistance - a.cumulativeDistance)
        return a.timestamp + fraction * b.timestamp.timeIntervalSince(a.timestamp)
    }

    private static func rounded(_ position: Double) -> Double {
        (position * 2 * stepsPerSide).rounded() / (2 * stepsPerSide)
    }
}
