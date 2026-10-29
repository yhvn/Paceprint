import CoreLocation
import PaceprintCore

/// The device's GPS through `CLLocationUpdate.liveUpdates(.fitness)` (#2), kept running with the
/// screen locked by a background activity session held for as long as the stream is (Start to Stop).
final class LiveLocationSource: NSObject, LocationSource, CLLocationManagerDelegate {
    /// The `NSLocationTemporaryUsageDescriptionDictionary` entry explaining why a Run needs precise location.
    static let fullAccuracyPurposeKey = "RunRecording"

    /// Only used to ask for permission; updates come from `liveUpdates`.
    private let manager = CLLocationManager()
    private var authorizationWaiters: [CheckedContinuation<Void, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
    }

    func prepare() async -> LocationProblem? {
        // Apple warns this can block, so it's asked off the main thread.
        let servicesEnabled = await Task.detached { CLLocationManager.locationServicesEnabled() }.value
        guard servicesEnabled else { return .servicesOff }

        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                authorizationWaiters.append(continuation)
                manager.requestWhenInUseAuthorization()
            }
        }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: break
        case .restricted: return .restricted
        default: return .denied
        }

        if manager.accuracyAuthorization == .reducedAccuracy {
            await withCheckedContinuation { continuation in
                manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: Self.fullAccuracyPurposeKey) { _ in
                    continuation.resume()
                }
            }
            guard manager.accuracyAuthorization == .fullAccuracy else { return .preciseOff }
        }
        return nil
    }

    func events() -> AsyncStream<LocationEvent> {
        AsyncStream { continuation in
            let task = Task {
                // Must be created in the foreground (Start is a tap) and needs the `location` background mode.
                let session = CLBackgroundActivitySession()
                defer { session.invalidate() }
                do {
                    for try await update in CLLocationUpdate.liveUpdates(.fitness) {
                        // iOS 18 reports lost access in the stream itself (ADR 0002).
                        if update.authorizationDenied || update.authorizationDeniedGlobally
                            || update.authorizationRestricted || update.accuracyLimited {
                            continuation.yield(.accessLost)
                            continue
                        }
                        if let location = update.location {
                            continuation.yield(.fix(LocationFix(location)))
                        }
                        if update.stationary {
                            continuation.yield(.stationary)
                        }
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
