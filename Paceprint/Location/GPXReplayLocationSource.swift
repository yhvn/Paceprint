import Foundation
import PaceprintCore

/// Replays a GPX file's track, all at once, as if it were being run now.
struct GPXReplayLocationSource: LocationSource {
    private let track: [LocationFix]
    private let isAuthorized: Bool

    init(contentsOf url: URL, isAuthorized: Bool = true) throws {
        track = try GPX.fixes(from: Data(contentsOf: url))
        self.isAuthorized = isAuthorized
    }

    func requestAuthorization() async -> Bool {
        isAuthorized
    }

    func fixes() -> AsyncStream<LocationFix> {
        // Shift the track so its first fix happens now, after the Run's start.
        let shift = track.first.map { Date.now.timeIntervalSince($0.timestamp) } ?? 0
        return AsyncStream { continuation in
            for var fix in track {
                fix.timestamp += shift
                continuation.yield(fix)
            }
            continuation.finish()
        }
    }
}
