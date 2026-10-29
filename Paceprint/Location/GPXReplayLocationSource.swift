import Foundation
import PaceprintCore

/// Replays a GPX file's points, all at once, as if it were being run now.
struct GPXReplayLocationSource: LocationSource {
    private let recordedFixes: [LocationFix]
    private let isAuthorized: Bool

    init(contentsOf url: URL, isAuthorized: Bool = true) throws {
        recordedFixes = try GPX.fixes(from: Data(contentsOf: url))
        self.isAuthorized = isAuthorized
    }

    func requestAuthorization() async -> Bool {
        isAuthorized
    }

    func fixes() -> AsyncStream<LocationFix> {
        // Shift the recording so its first fix happens now, after the Run's start.
        let shift = recordedFixes.first.map { Date.now.timeIntervalSince($0.timestamp) } ?? 0
        return AsyncStream { continuation in
            for var fix in recordedFixes {
                fix.timestamp += shift
                continuation.yield(fix)
            }
            continuation.finish()
        }
    }
}
