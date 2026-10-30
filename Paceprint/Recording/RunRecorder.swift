import Foundation
import Observation
import os
import PaceprintCore
import SwiftData

/// Owns the Run in progress: turns location fixes into a Route, tracks Pauses, checkpoints the Run
/// in case the app is killed, and saves it on Stop.
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
    /// Stop was chosen on a Run too short to be worth keeping; the screen asks whether to discard it,
    /// then calls `discard()` or `save()`, or clears this to carry on.
    var isAskingToDiscard = false

    /// How often the Run in progress is written to the store, in case the app is killed.
    static let checkpointInterval: TimeInterval = 10

    private var tracker: RunTracker?
    /// The Run in progress as last checkpointed; unfinished until Stop.
    @ObservationIgnored private var run: Run?
    @ObservationIgnored private var isStarting = false
    @ObservationIgnored private var recording: Task<Void, Never>?
    @ObservationIgnored private var checkpoints: Task<Void, Never>?

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

        let tracker = RunTracker(runStart: now())
        let run = Run(startDate: tracker.runStart)
        modelContext.insert(run)
        record(into: run, from: tracker)
    }

    /// Picks up a Run left unfinished when the app was killed, if there is one.
    /// Relaunched by iOS in the background to keep recording, it carries straight on. Otherwise the
    /// app was force-quit or crashed: the Run opens Paused from its last checkpoint, so the gap is a
    /// Pause, and the runner chooses Resume or Stop.
    func recoverUnfinishedRun(relaunchedInBackground: Bool) {
        guard !isRecording else { return }
        var descriptor = FetchDescriptor<Run>(predicate: Run.unfinished, sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        descriptor.fetchLimit = 1
        let run: Run
        do {
            guard let found = try modelContext.fetch(descriptor).first else { return }
            run = found
        } catch {
            logger.error("Couldn't look for an unfinished Run: \(error)")
            return
        }
        do {
            var tracker = try run.resumedTracker()
            if !relaunchedInBackground {
                tracker.pause(at: run.endDate)
            }
            record(into: run, from: tracker)
        } catch {
            // A checkpoint that can't be read can't be recovered; don't leave it in the store.
            logger.error("Couldn't recover the unfinished Run: \(error)")
            modelContext.delete(run)
            persist()
        }
    }

    /// Records into `run`, starting from `tracker`: checkpoints it now, then consumes location events,
    /// checkpointing at least every 10 s, even while none arrive.
    private func record(into run: Run, from tracker: RunTracker) {
        self.run = run
        self.tracker = tracker
        checkpoint()
        let events = source.events()
        recording = Task { [weak self] in
            for await event in events {
                self?.handle(event)
            }
        }
        checkpoints = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.checkpointInterval))
                self?.checkpointIfDue()
            }
        }
    }

    /// Writes the Run in progress to the store as it stands now.
    private func checkpoint() {
        guard let run, let tracker else { return }
        run.checkpoint(tracker, at: now())
        persist()
    }

    private func checkpointIfDue() {
        guard let run, now().timeIntervalSince(run.endDate) >= Self.checkpointInterval else { return }
        checkpoint()
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
        checkpointIfDue()
    }

    /// Starts a Pause. The location stream keeps running; fixes taken now are flagged paused.
    func pause() {
        tracker?.pause(at: now())
        checkpoint()
    }

    /// Ends the Pause; fixes count toward the Run again from now.
    /// Does nothing while location access is off: the screen is already saying so.
    func resume() {
        guard !isAccessLost else { return }
        tracker?.resume(at: now())
        checkpoint()
    }

    /// Ends the Run, and any Pause it's in, and saves it; or, if it's under 0.1 km or 1 min of
    /// Moving time, asks first by setting `isAskingToDiscard`.
    func stop() {
        guard let tracker else { return }
        if tracker.isTooShort(at: now()) {
            isAskingToDiscard = true
        } else {
            save()
        }
    }

    /// Ends the Run, and any Pause it's in, and saves it, however short.
    func save() {
        guard let tracker else { return }
        run?.finish(tracker, at: now())
        persist()
        end()
    }

    /// Ends the Run without saving it.
    func discard() {
        if let run {
            modelContext.delete(run)
            persist()
        }
        end()
    }

    private func persist() {
        do {
            try modelContext.save()
        } catch {
            logger.error("Couldn't write to the Run store: \(error)")
        }
    }

    private func end() {
        recording?.cancel()
        recording = nil
        checkpoints?.cancel()
        checkpoints = nil
        run = nil
        tracker = nil
        isAccessLost = false
        isAskingToDiscard = false
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
