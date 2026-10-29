import Foundation

/// Reads the track points of a GPX 1.1 file as fixes, for replaying a Run in tests and the Simulator.
public enum GPX {
    public enum ParsingError: Error, Equatable {
        case malformed
        /// A `<trkpt>` without a `<time>`: replay needs every point's timestamp.
        case missingTime
    }

    /// GPX carries no accuracy, so replayed fixes claim a good GPS fix.
    static let replayedHorizontalAccuracy = 5.0

    public static func fixes(from data: Data) throws -> [LocationFix] {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        let parsed = parser.parse()
        if let error = delegate.error { throw error }
        guard parsed else { throw ParsingError.malformed }
        return delegate.fixes
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var fixes: [LocationFix] = []
        var error: ParsingError?

        private var point: (latitude: Double, longitude: Double)?
        private var elevation: Double?
        private var time: Date?
        private var text = ""

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
            text = ""
            guard name == "trkpt" else { return }
            guard let latitude = attributes["lat"].flatMap(Double.init),
                  let longitude = attributes["lon"].flatMap(Double.init)
            else {
                fail(.malformed, parser)
                return
            }
            point = (latitude, longitude)
            elevation = nil
            time = nil
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            text += string
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            guard point != nil else { return }
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            switch name {
            case "ele":
                elevation = Double(value)
            case "time":
                time = try? Date(value, strategy: .iso8601)
            case "trkpt":
                guard let point, let time else {
                    fail(.missingTime, parser)
                    return
                }
                fixes.append(LocationFix(
                    timestamp: time,
                    latitude: point.latitude,
                    longitude: point.longitude,
                    altitude: elevation ?? 0,
                    horizontalAccuracy: GPX.replayedHorizontalAccuracy
                ))
                self.point = nil
            default:
                break
            }
        }

        private func fail(_ error: ParsingError, _ parser: XMLParser) {
            self.error = error
            parser.abortParsing()
        }
    }
}
