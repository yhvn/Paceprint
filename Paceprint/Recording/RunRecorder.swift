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

    /// Starts a Run, asking for location permission first if it hasn't been decided.
    /// Does nothing if permission isn't granted.
    func start() async {
        guard !isRecording, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        guard await source.requestAuthorization() else { return }

        tracker = RunTracker(runStart: now())
        let fixes = source.fixes()
        recording = Task { [weak self] in
            for await fix in fixes {
                _ = self?.tracker?.add(fix)
            }
        }
    }

    /// Starts a Pause. The location stream keeps running; fixes taken now are flagged paused.
    func pause() {
        tracker?.pause(at: now())
    }

    /// Ends the Pause; fixes count toward the Run again from now.
    func resume() {
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
