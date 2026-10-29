import Foundation
import PaceprintCore

/// Replays a GPX file's points, all at once, as if they were being run now.
struct GPXReplayLocationSource: LocationSource {
    private let recordedFixes: [LocationFix]
    private let now: () -> Date

    init(contentsOf url: URL, now: @escaping () -> Date = { .now }) throws {
        recordedFixes = try GPX.fixes(from: Data(contentsOf: url))
        self.now = now
    }

    func prepare() async -> LocationProblem? {
        nil
    }

    func events() -> AsyncStream<LocationEvent> {
        // Shift the recording so its first fix happens now, after the Run's start.
        let shift = recordedFixes.first.map { now().timeIntervalSince($0.timestamp) } ?? 0
        return AsyncStream { continuation in
            for var fix in recordedFixes {
                fix.timestamp += shift
                continuation.yield(.fix(fix))
            }
            continuation.finish()
        }
    }
}
