import Foundation
import Observation
import os
import SwiftData

/// Keeps finished Runs in Apple Health while "Save runs to Health" is on: saved on Stop, retried quietly
/// on a later launch if that failed, and removed from Health when the Run is deleted.
@Observable
final class RunHealthSync {
    @ObservationIgnored private let exporter: any HealthExporter
    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let settings: UserDefaults
    /// Runs being saved now, so the same Run isn't saved twice at once.
    @ObservationIgnored private var inProgress: Set<PersistentIdentifier> = []
    @ObservationIgnored private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Paceprint", category: "Health")

    init(exporter: any HealthExporter, modelContext: ModelContext, settings: UserDefaults = .standard) {
        self.exporter = exporter
        self.modelContext = modelContext
        self.settings = settings
    }

    var isSavingToHealth: Bool {
        settings.bool(forKey: SettingsKey.saveToHealth)
    }

    var isAvailable: Bool {
        exporter.isAvailable
    }

    /// The system sheet was shown and saving wasn't allowed, so Settings says where to allow it.
    var isRefused: Bool {
        settings.bool(forKey: SettingsKey.isHealthPermissionAsked) && !exporter.isWriteAllowed
    }

    /// Asks for Health permission (the system sheet shows only the first time) and turns "Save runs to
    /// Health" on if saving was allowed. Returns whether it's on.
    @discardableResult
    func connect() async -> Bool {
        settings.set(true, forKey: SettingsKey.isHealthCardAnswered)
        settings.set(true, forKey: SettingsKey.isHealthPermissionAsked)
        do {
            try await exporter.requestAuthorization()
        } catch {
            logger.error("Couldn't ask for Health permission: \(error)")
        }
        let isAllowed = exporter.isWriteAllowed
        settings.set(isAllowed, forKey: SettingsKey.saveToHealth)
        await refreshBodyMass()
        return isAllowed
    }

    /// Turns "Save runs to Health" off. Runs still waiting to be saved there are forgotten: turning it
    /// on again later doesn't back-fill them.
    func turnOff() {
        settings.set(false, forKey: SettingsKey.saveToHealth)
        let waiting = (try? modelContext.fetch(FetchDescriptor<Run>(predicate: Run.awaitingHealth))) ?? []
        waiting.forEach { $0.awaitsHealthSave = false }
        persist()
    }

    /// Saves a finished Run to Health if "Save runs to Health" is on and it isn't there yet: on Stop,
    /// and on Connect for the Run on Summary. Marked first, so a failure is retried on a later launch.
    func save(_ run: Run) async {
        guard isSavingToHealth, run.healthWorkoutID == nil else { return }
        run.awaitsHealthSave = true
        persist()
        await write(run)
    }

    /// Saves the Runs that couldn't be saved to Health before, one after another, stopping at the first
    /// failure: the rest wait for a later launch.
    func saveRunsAwaitingHealth() async {
        guard isSavingToHealth else { return }
        let runs = (try? modelContext.fetch(FetchDescriptor<Run>(predicate: Run.awaitingHealth))) ?? []
        for run in runs {
            guard await write(run) else { return }
        }
    }

    /// Deletes `run` for good, and its Health workout if it has one.
    func delete(_ run: Run) async throws {
        if let id = run.healthWorkoutID {
            do {
                try await exporter.deleteWorkout(id)
            } catch {
                // The Run still goes; the workout stays in Health, where the runner can delete it.
                logger.error("Couldn't delete a Run's Health workout: \(error)")
            }
        }
        try modelContext.deleteRun(run)
    }

    /// Reads Health's latest body weight into settings, for CAL (EST); clears it if there's none to read.
    func refreshBodyMass() async {
        guard exporter.isAvailable else { return }
        settings.set(await exporter.latestBodyMass() ?? 0, forKey: SettingsKey.healthBodyMass)
    }

    /// Writes `run` to Health; false if that failed and it's left for a later launch.
    @discardableResult
    private func write(_ run: Run) async -> Bool {
        guard inProgress.insert(run.persistentModelID).inserted else { return true }
        defer { inProgress.remove(run.persistentModelID) }
        do {
            let id = try await exporter.save(HealthWorkout(run))
            // Deleted while it was being saved: take the workout back out of Health.
            guard run.modelContext != nil, !run.isDeleted else {
                try? await exporter.deleteWorkout(id)
                return true
            }
            run.healthWorkoutID = id
            run.awaitsHealthSave = false
            persist()
            return true
        } catch {
            logger.info("Couldn't save a Run to Health yet: \(error)")
            return false
        }
    }

    private func persist() {
        do {
            try modelContext.save()
        } catch {
            logger.error("Couldn't save a Run's Health state: \(error)")
        }
    }
}

#if DEBUG
extension RunHealthSync {
    /// For SwiftUI previews, against a throwaway in-memory store.
    static var preview: RunHealthSync {
        let container = try! ModelContainer(for: Run.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return RunHealthSync(exporter: HealthKitExporter(), modelContext: container.mainContext)
    }
}
#endif
