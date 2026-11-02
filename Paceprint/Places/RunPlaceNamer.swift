import Foundation
import os
import PaceprintCore
import SwiftData

/// Gives a Run its Place name and Place context: looked up once after Stop, and again on later
/// launches for Runs whose lookup couldn't be done.
final class RunPlaceNamer {
    private let lookup: any PlaceLookup
    private let modelContext: ModelContext
    /// Time between lookups, to stay under the geocoder's limit of about 50 a minute.
    private let requestSpacing: Duration
    /// Runs being looked up now, so the same Run isn't looked up twice at once.
    private var inProgress: Set<PersistentIdentifier> = []
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Paceprint", category: "PlaceNamer")

    init(lookup: any PlaceLookup, modelContext: ModelContext, requestSpacing: Duration = .milliseconds(1_200)) {
        self.lookup = lookup
        self.modelContext = modelContext
        self.requestSpacing = requestSpacing
    }

    /// Looks up up to 5 points along `run`'s Route and stores the Place they make. Returns false if a
    /// lookup failed, e.g. offline: the Run keeps its time-of-day name and is left for a later launch.
    @discardableResult
    func name(_ run: Run) async -> Bool {
        guard !run.isPlaceLookedUp, inProgress.insert(run.persistentModelID).inserted else { return true }
        defer { inProgress.remove(run.persistentModelID) }

        // A Route that can't be read never will be: keep the time-of-day name for good.
        let points = (try? run.decodedRoute()).map(PlaceNaming.lookupPoints) ?? []
        var placemarks: [Placemark] = []
        do {
            for (index, point) in points.enumerated() {
                if index > 0 {
                    try await Task.sleep(for: requestSpacing)
                }
                if let placemark = try await lookup.placemark(latitude: point.latitude, longitude: point.longitude) {
                    placemarks.append(placemark)
                }
            }
        } catch {
            logger.info("Couldn't look up a Run's place yet: \(error)")
            return false
        }
        // Deleted while the lookups were out.
        guard run.modelContext != nil, !run.isDeleted else { return true }

        let place = PlaceNaming.place(from: placemarks)
        run.placeName = place?.name
        run.placeContext = place?.context ?? []
        run.isPlaceLookedUp = true
        do {
            try modelContext.save()
        } catch {
            logger.error("Couldn't save a Run's place: \(error)")
        }
        return true
    }

    /// Names the finished Runs still waiting for their place, one after another, stopping at the first
    /// failed lookup: the rest wait for a later launch rather than run into the geocoder's limit.
    func nameRunsAwaitingPlace() async {
        let runs = (try? modelContext.fetch(FetchDescriptor<Run>(predicate: Run.awaitingPlace))) ?? []
        for run in runs {
            guard await name(run) else { return }
            try? await Task.sleep(for: requestSpacing)
        }
    }
}
