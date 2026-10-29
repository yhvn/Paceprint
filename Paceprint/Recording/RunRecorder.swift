import Foundation
import Observation
import os
import PaceprintCore
import SwiftData

/// Owns the Run in progress: turns location fixes into a Route, tracks Pauses, and saves the Run on Stop.
/// Screens only read its state and call `start()`, `pause()`, `resume()` and `stop()`.
@Observable
final class RunRecorder {
    var isRecording: Bool { tracker != nil }
    var isPaused: Bool { tracker?.isPaused ?? false }
    /// Metres covered by the current Run.
    var distance: Double { tracker?.distance ?? 0 }
    // Time-based values are read from the clock on each access; screens re-read them every second.
    var movingTime: TimeInterval { tracker?.movingTime(at: now()) ?? 0 }
    var currentPace: Pace? { tracker?.currentPace }
    var averagePace: Pace? { tracker?.averagePace(at: now()) }
    var gpsStatus: GPSStatus { tracker?.gpsStatus(at: now()) ?? .finding }

    /// Why the last Start didn't start a Run; the screen clears it once it has said so.
    var startProblem: LocationProblem?
    /// Location access was turned off mid-Run, so the Run is paused and can't Resume yet.
    private(set) var isAccessLost = false

    private var tracker: RunTracker?
    @ObservationIgnored private var isStarting = false
    @ObservationIgnored private var recording: Task<Void, Never>?

    @ObservationIgnored private let source: any LocationSource
    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Paceprint", category: "RunRecorder")

    init(source: any LocationSource, modelContext: ModelContext, now: @escaping () -> Date = { .now }) {
        self.source = source
        self.modelContext = modelContext
        self.now = now
    }

    /// Starts a Run once location is ready, asking for permission or precise location if needed.
    /// The clock starts straight away; it doesn't wait for GPS. If location can't be used,
    /// sets `startProblem` instead.
    func start() async {
        guard !isRecording, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        if let problem = await source.prepare() {
            startProblem = problem
            return
        }

        tracker = RunTracker(runStart: now())
        let events = source.events()
        recording = Task { [weak self] in
            for await event in events {
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: LocationEvent) {
        switch event {
        case .fix(let fix):
            // Fixes only arrive while access is allowed.
            isAccessLost = false
            _ = tracker?.add(fix)
        case .stationary:
            // The system only reports this while it can locate the device, so access is back too.
            isAccessLost = false
            tracker?.markStationary()
        case .accessLost:
            guard !isAccessLost else { return }
            isAccessLost = true
            tracker?.pause(at: now())
        }
    }

    /// Starts a Pause. The location stream keeps running; fixes taken now are flagged paused.
    func pause() {
        tracker?.pause(at: now())
    }

    /// Ends the Pause; fixes count toward the Run again from now.
    /// Does nothing while location access is off: the screen is already saying so.
    func resume() {
        guard !isAccessLost else { return }
        tracker?.resume(at: now())
    }

    /// Ends the Run, and any Pause it's in, and saves it.
    func stop() {
        guard let tracker else { return }
        recording?.cancel()
        recording = nil

        modelContext.insert(Run(tracker, endDate: now()))
        do {
            try modelContext.save()
        } catch {
            logger.error("Couldn't save the Run: \(error)")
        }
        self.tracker = nil
        isAccessLost = false
    }

    /// Waits until the location source runs out of fixes. Only a replayed source ever does.
    func waitUntilSourceFinishes() async {
        await recording?.value
    }
}

#if DEBUG
extension RunRecorder {
    /// A recorder for SwiftUI previews, saving to a throwaway in-memory store.
    static var preview: RunRecorder {
        let container = try! ModelContainer(for: Run.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return RunRecorder(source: LiveLocationSource(), modelContext: container.mainContext)
    }
}
#endif
