import Foundation
import Observation
import os
import PaceprintCore
import SwiftData

/// Owns the Run in progress: turns location fixes into a Route and saves the Run on Stop.
/// Screens only read its state and call `start()` / `stop()`.
@Observable
final class RunRecorder {
    /// When the current Run started; nil when no Run is being recorded.
    private(set) var startDate: Date?
    /// Metres covered by the current Run.
    var distance: Double { tracker?.distance ?? 0 }
    var isRecording: Bool { startDate != nil }

    private var tracker: RouteTracker?
    @ObservationIgnored private var isStarting = false
    @ObservationIgnored private var recording: Task<Void, Never>?

    @ObservationIgnored private let source: any LocationSource
    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let logger = Logger(subsystem: "com.yhlabs.paceprint", category: "RunRecorder")

    init(source: any LocationSource, modelContext: ModelContext) {
        self.source = source
        self.modelContext = modelContext
    }

    /// Starts a Run, asking for location permission first if it hasn't been decided.
    /// Does nothing if permission isn't granted.
    func start() async {
        guard !isRecording, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        guard await source.requestAuthorization() else { return }

        let startDate = Date.now
        self.startDate = startDate
        tracker = RouteTracker(runStart: startDate)
        let fixes = source.fixes()
        recording = Task { [weak self] in
            for await fix in fixes {
                _ = self?.tracker?.add(fix)
            }
        }
    }

    /// Ends the Run and saves it.
    func stop() {
        guard let startDate, let tracker else { return }
        recording?.cancel()
        recording = nil

        modelContext.insert(Run(startDate: startDate, endDate: .now, route: tracker.points))
        do {
            try modelContext.save()
        } catch {
            logger.error("Couldn't save the Run: \(error)")
        }
        self.startDate = nil
        self.tracker = nil
    }

    /// Waits until the location source runs out of fixes. Only a replayed source ever does.
    func sourceFinished() async {
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
