import Foundation

/// Decides whether a fix is good enough to join the Route. Apple documents no algorithm;
/// these rules and limits come from the background-location research (#2), to be tuned on device.
enum NoiseFilter {
    /// Fixes less precise than this, in metres, are dropped.
    static let maximumHorizontalAccuracy = 25.0
    /// Fixes implying a faster speed than this from the last kept point, in m/s, are dropped as teleports.
    static let maximumSpeed = 12.0

    /// Whether `fix` should be kept, given the Run's start and the last point kept.
    /// Speed isn't checked `acrossPause`: the runner may have gone anywhere while paused.
    static func accepts(_ fix: LocationFix, runStart: Date, after last: RoutePoint?, acrossPause: Bool = false) -> Bool {
        guard fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= maximumHorizontalAccuracy else { return false }
        // A cached fix from before Start says nothing about this Run.
        guard fix.timestamp >= runStart else { return false }
        guard let last else { return true }

        let seconds = fix.timestamp.timeIntervalSince(last.timestamp)
        guard seconds > 0 else { return false }
        guard !acrossPause else { return true }
        return last.distance(to: fix) / seconds <= maximumSpeed
    }
}
