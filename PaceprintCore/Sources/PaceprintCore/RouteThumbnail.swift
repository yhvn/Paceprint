import Foundation

/// A small, simplified copy of a Run's Route in Pace colors, stored beside its summary so the cards on
/// Home and History can draw it without decoding the Route (ADR 0001).
///
/// One line per stretch (the Route breaks at Pauses), each cut down with Douglas–Peucker so the whole
/// thumbnail has at most `maximumPoints` points. Each segment between two kept points keeps the Pace
/// color of the part of the Route it stands for, so drawing it needs neither the Route nor the Run's
/// Average pace.
public struct RouteThumbnail: Equatable, Sendable {
    public struct Point: Equatable, Sendable {
        public let latitude: Double
        public let longitude: Double

        public init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    /// One stretch of the Route: its kept points, and the Pace color of each segment between them.
    public struct Line: Equatable, Sendable {
        public let points: [Point]
        /// One fewer than `points`: `colors[i]` is the segment from `points[i]` to `points[i + 1]`.
        public let colors: [PaceColor]
    }

    public enum DecodingError: Error, Equatable {
        case unsupportedVersion(UInt8)
        case truncated
    }

    /// A few dozen points: enough for a Route's shape at card size. A Route broken by more than 24
    /// Pauses goes over, since every stretch keeps both its ends.
    public static let maximumPoints = 48
    /// Points nearer than this to the line through their neighbours are always dropped, so a straight
    /// stretch is two points however many fixes it has.
    static let minimumTolerance = 1.0

    public let lines: [Line]

    public var pointCount: Int {
        lines.reduce(0) { $0 + $1.points.count }
    }

    /// The thumbnail of `route`, with Pace colors compared with `averagePace` (all the middle color
    /// without one). Empty if the Route has nothing to draw.
    public init(route: [RoutePoint], pauses: [Pause], averagePace: Pace?) {
        let stretches = PaceColoring.stretches(of: route, pauses: pauses)
        guard let origin = stretches.first?.first else {
            lines = []
            return
        }
        let projected = stretches.map { $0.map { Self.metres($0, from: origin) } }
        let tolerance = Self.tolerance(for: projected)
        lines = zip(stretches, projected).map { stretch, projected in
            let kept = Self.simplified(projected, tolerance: tolerance)
            let colors = PaceColoring.segmentColors(of: stretch, averagePace: averagePace)
            return Line(
                points: kept.map { Point(latitude: stretch[$0].latitude, longitude: stretch[$0].longitude) },
                colors: zip(kept, kept.dropFirst()).map { Self.averageColor(colors, from: $0, to: $1, along: stretch) }
            )
        }
    }

    init(lines: [Line]) {
        self.lines = lines
    }

    // MARK: Simplifying

    private struct Metres {
        let east: Double
        let north: Double
    }

    /// Where `point` is in metres east and north of `origin`: flat-Earth, plenty for one Run.
    private static func metres(_ point: RoutePoint, from origin: RoutePoint) -> Metres {
        let metresPerDegree = 111_195.0
        return Metres(
            east: (point.longitude - origin.longitude) * metresPerDegree * cos(origin.latitude * .pi / 180),
            north: (point.latitude - origin.latitude) * metresPerDegree
        )
    }

    /// The smallest tolerance, at least `minimumTolerance`, that keeps every stretch together within
    /// `maximumPoints`. Douglas–Peucker never keeps more points for a larger tolerance, so it's found
    /// by bisection.
    private static func tolerance(for stretches: [[Metres]]) -> Double {
        func keptCount(_ tolerance: Double) -> Int {
            stretches.reduce(0) { $0 + simplified($1, tolerance: tolerance).count }
        }
        guard keptCount(minimumTolerance) > maximumPoints else { return minimumTolerance }
        let all = stretches.joined()
        // Wider than the whole Route: every stretch comes down to its two ends.
        var high = (all.map(\.east).max()! - all.map(\.east).min()!) + (all.map(\.north).max()! - all.map(\.north).min()!) + 1
        var low = minimumTolerance
        for _ in 0..<40 {
            let middle = (low + high) / 2
            if keptCount(middle) > maximumPoints { low = middle } else { high = middle }
        }
        return high
    }

    /// The indices of `points` Douglas–Peucker keeps at `tolerance` metres: always both ends.
    private static func simplified(_ points: [Metres], tolerance: Double) -> [Int] {
        guard points.count > 2 else { return Array(points.indices) }
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var ranges = [(0, points.count - 1)]
        while let (first, last) = ranges.popLast() {
            guard last - first > 1 else { continue }
            var farthest = first, farthestDistance = 0.0
            for index in (first + 1)..<last {
                let distance = distance(from: points[index], toLineThrough: points[first], points[last])
                if distance > farthestDistance {
                    farthest = index
                    farthestDistance = distance
                }
            }
            guard farthestDistance > tolerance else { continue }
            keep[farthest] = true
            ranges.append((first, farthest))
            ranges.append((farthest, last))
        }
        return points.indices.filter { keep[$0] }
    }

    /// How far `point` is from the segment from `a` to `b`, in metres.
    private static func distance(from point: Metres, toLineThrough a: Metres, _ b: Metres) -> Double {
        let dx = b.east - a.east, dy = b.north - a.north
        let lengthSquared = dx * dx + dy * dy
        let t = lengthSquared > 0 ? min(max(((point.east - a.east) * dx + (point.north - a.north) * dy) / lengthSquared, 0), 1) : 0
        return hypot(point.east - (a.east + t * dx), point.north - (a.north + t * dy))
    }

    /// The color of the kept segment from point `first` to point `last` of `stretch`: the colors of the
    /// segments it replaces, averaged by their length.
    private static func averageColor(_ colors: [PaceColor], from first: Int, to last: Int, along stretch: [RoutePoint]) -> PaceColor {
        var weighted = 0.0, total = 0.0
        for index in first..<last {
            let length = stretch[index + 1].cumulativeDistance - stretch[index].cumulativeDistance
            weighted += colors[index].position * length
            total += length
        }
        guard total > 0 else {
            return PaceColor(position: colors[first..<last].reduce(0) { $0 + $1.position } / Double(last - first))
        }
        return PaceColor(position: weighted / total)
    }
}

// MARK: Encoding

extension RouteThumbnail {
    static let currentVersion: UInt8 = 1

    /// Version 1: one version byte, a little-endian `UInt16` line count, then per line a `UInt16` point
    /// count, per point two little-endian `Double`s (latitude, longitude), and per segment one byte
    /// for its Pace color (0 fast to 255 slow).
    public func encoded() -> Data {
        var data = Data()
        data.reserveCapacity(3 + lines.count * 2 + pointCount * 17)
        data.append(Self.currentVersion)
        Self.append(UInt16(lines.count), to: &data)
        for line in lines {
            Self.append(UInt16(line.points.count), to: &data)
            for point in line.points {
                Self.append(point.latitude.bitPattern, to: &data)
                Self.append(point.longitude.bitPattern, to: &data)
            }
            for color in line.colors {
                data.append(UInt8((min(max(color.position, 0), 1) * 255).rounded()))
            }
        }
        return data
    }

    public init(decoding data: Data) throws {
        var reader = Reader(bytes: [UInt8](data))
        let version = try reader.byte()
        guard version == Self.currentVersion else { throw DecodingError.unsupportedVersion(version) }

        let lineCount = Int(try reader.integer(UInt16.self))
        var lines: [Line] = []
        for _ in 0..<lineCount {
            let pointCount = Int(try reader.integer(UInt16.self))
            var points: [Point] = []
            for _ in 0..<pointCount {
                points.append(Point(latitude: try reader.double(), longitude: try reader.double()))
            }
            var colors: [PaceColor] = []
            for _ in 0..<max(pointCount - 1, 0) {
                colors.append(PaceColor(position: Double(try reader.byte()) / 255))
            }
            lines.append(Line(points: points, colors: colors))
        }
        self.init(lines: lines)
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    private struct Reader {
        let bytes: [UInt8]
        var offset = 0

        mutating func byte() throws -> UInt8 {
            guard offset < bytes.count else { throw DecodingError.truncated }
            defer { offset += 1 }
            return bytes[offset]
        }

        mutating func integer<T: FixedWidthInteger>(_: T.Type) throws -> T {
            let size = MemoryLayout<T>.size
            guard offset + size <= bytes.count else { throw DecodingError.truncated }
            var value: T = 0
            for index in 0..<size {
                value |= T(bytes[offset + index]) << (8 * index)
            }
            offset += size
            return value
        }

        mutating func double() throws -> Double {
            Double(bitPattern: try integer(UInt64.self))
        }
    }
}
