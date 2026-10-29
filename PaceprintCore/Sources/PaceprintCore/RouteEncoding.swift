import Foundation

/// The binary format a Route is stored in on its Run (ADR 0001).
///
/// Version 1: one version byte, a little-endian `UInt32` point count, then per point six
/// little-endian `Double`s (timestamp as seconds since the reference date, latitude, longitude,
/// altitude, horizontal accuracy, cumulative distance) and one paused byte (0 or 1).
public enum RouteEncoding {
    public enum DecodingError: Error, Equatable {
        case unsupportedVersion(UInt8)
        case truncated
    }

    static let currentVersion: UInt8 = 1

    public static func encode(_ points: [RoutePoint]) -> Data {
        var data = Data()
        data.reserveCapacity(5 + points.count * 49)
        data.append(currentVersion)
        append(UInt32(points.count), to: &data)
        for point in points {
            for value in [
                point.timestamp.timeIntervalSinceReferenceDate,
                point.latitude,
                point.longitude,
                point.altitude,
                point.horizontalAccuracy,
                point.cumulativeDistance,
            ] {
                append(value.bitPattern, to: &data)
            }
            data.append(point.isPaused ? 1 : 0)
        }
        return data
    }

    public static func decode(_ data: Data) throws -> [RoutePoint] {
        var reader = Reader(bytes: [UInt8](data))
        let version = try reader.byte()
        guard version == currentVersion else { throw DecodingError.unsupportedVersion(version) }

        let count = Int(try reader.integer(UInt32.self))
        var points: [RoutePoint] = []
        points.reserveCapacity(count)
        for _ in 0..<count {
            let timestamp = try reader.double()
            points.append(RoutePoint(
                timestamp: Date(timeIntervalSinceReferenceDate: timestamp),
                latitude: try reader.double(),
                longitude: try reader.double(),
                altitude: try reader.double(),
                horizontalAccuracy: try reader.double(),
                cumulativeDistance: try reader.double(),
                isPaused: try reader.byte() != 0
            ))
        }
        return points
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
