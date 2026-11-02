import Foundation
import os
import PaceprintCore
import SwiftData

/// Gives a Run its Place name and Place context: looked up once after Stop, and again on later
/// launches for Runs whose lookup couldn't be done.
final class RunPlaceNamer {
    private let lookup: any PlaceLookup
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Paceprint", category: "PlaceNamer")

    init(lookup: any PlaceLookup, modelContext: ModelContext) {
        self.lookup = lookup
        self.modelContext = modelContext
    }

    /// Looks up up to 5 points along `run`'s Route and stores the Place they make. If any lookup
    /// fails, the Run keeps its time-of-day name and is left for a later launch.
    func name(_ run: Run) async {
        guard !run.isPlaceLookedUp, let route = try? run.decodedRoute() else { return }
        var placemarks: [Placemark] = []
        do {
            for point in PlaceNaming.lookupPoints(of: route) {
                if let placemark = try await lookup.placemark(latitude: point.latitude, longitude: point.longitude) {
                    placemarks.append(placemark)
                }
            }
        } catch {
            logger.info("Couldn't look up a Run's place yet: \(error)")
            return
        }
        let place = PlaceNaming.place(from: placemarks)
        run.placeName = place?.name
        run.placeContext = place?.context ?? []
        run.isPlaceLookedUp = true
        do {
            try modelContext.save()
        } catch {
            logger.error("Couldn't save a Run's place: \(error)")
        }
    }

    /// Names every finished Run still waiting for its place, one after another.
    func nameUnnamedRuns() async {
        let runs = (try? modelContext.fetch(FetchDescriptor<Run>(predicate: Run.awaitingPlace))) ?? []
        for run in runs {
            await name(run)
        }
    }
}
