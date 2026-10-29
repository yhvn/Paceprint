import CoreLocation
import PaceprintCore

/// The device's GPS through `CLLocationUpdate.liveUpdates(.fitness)` (#2), kept running with the
/// screen locked by a background activity session held for as long as the stream is (Start to Stop).
final class LiveLocationSource: NSObject, LocationSource, CLLocationManagerDelegate {
    /// Only used to ask for permission; updates come from `liveUpdates`.
    private let manager = CLLocationManager()
    private var authorizationWaiters: [CheckedContinuation<Void, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestAuthorization() async -> Bool {
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                authorizationWaiters.append(continuation)
                manager.requestWhenInUseAuthorization()
            }
        }
        return manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
    }

    func fixes() -> AsyncStream<LocationFix> {
        AsyncStream { continuation in
            let task = Task {
                // Must be created in the foreground (Start is a tap) and needs the `location` background mode.
                let session = CLBackgroundActivitySession()
                defer { session.invalidate() }
                do {
                    for try await update in CLLocationUpdate.liveUpdates(.fitness) {
                        // iOS 18 also sends location-less updates carrying only diagnostics.
                        guard let location = update.location else { continue }
                        continuation.yield(LocationFix(location))
                    }
                } catch {
                    // The stream only throws when cancelled.
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // The manager was created on the main thread, so it calls its delegate there.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            // The manager also reports the initial, undecided status when its delegate is set.
            guard status != .notDetermined else { return }
            let waiters = authorizationWaiters
            authorizationWaiters = []
            waiters.forEach { $0.resume() }
        }
    }
}

private extension LocationFix {
    init(_ location: CLLocation) {
        self.init(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy
        )
    }
}
