import Foundation
import PaceprintCore
import SwiftData

/// A recorded Run. Summary numbers sit beside the Route so lists never decode it (ADR 0001).
@Model
final class Run {
    var startDate: Date
    /// When the Run was stopped; for an unfinished Run, when it was last checkpointed.
    var endDate: Date
    /// Seconds from Start to `endDate`, Pauses included.
    var elapsedTime: TimeInterval
    /// Seconds from Start to `endDate` with Pauses removed: the TIME shown.
    var movingTime: TimeInterval = 0
    /// Every Pause, the source of truth for Moving time. All ended once the Run is finished.
    var pauses: [Pause] = []
    /// Metres.
    var distance: Double
    /// The Route's points in `RouteEncoding`'s versioned format.
    @Attribute(.externalStorage) var routeData: Data
    /// False while the Run is still being recorded: it's only a checkpoint, kept in case the app is
    /// killed, and never shown in History or totals.
    var isFinished = true
    /// The photo picked on Summary: a file in `RunPhotoStore`'s folder. Nil shows the dark map.
    var photoFileName: String?
    /// `photoFilter`'s raw value. Stored as a String: SwiftData can't store an enum with a case named `none`.
    private var photoFilterName = PhotoFilter.none.rawValue
    /// How much darker the photo is drawn so text over it reads; measured when it was picked.
    var photoScrimStrength = 0.0
    /// Where the Run happened, as found by looking it up after Stop; nil until found, or if nothing was.
    var placeName: String?
    /// Up to two wider names around the Place name, e.g. ["Brooklyn", "New York"].
    var placeContext: [String] = []
    /// The lookup has run and answered, whether or not it found a place. False until then, including
    /// after a failed lookup, so it's tried again on a later launch.
    var isPlaceLookedUp = false
    /// The body weight CAL (EST) was worked out with, in kg, kept so a later change of weight leaves the
    /// Run alone; nil if none was set at Stop.
    var bodyMass: Double?
    /// CAL (EST): active kcal, rounded to 5; nil without a body weight.
    var activeCalories: Double?
    /// The Apple Health workout this Run was saved as, so deleting the Run deletes it too.
    var healthWorkoutID: UUID?
    /// Health was on at Stop but the Run isn't in Health yet: saving it is tried again on a later launch.
    var awaitsHealthSave = false

    /// The Place name in capitals, or until it's found the time-of-day name, e.g. MORNING RUN.
    var placeNameShown: String {
        placeName?.uppercased() ?? PlaceNaming.timeOfDayName(startingAt: startDate, calendar: .current)
    }

    /// The Place context in capitals, joined: e.g. "MANHATTAN · NEW YORK"; empty until found.
    var placeContextShown: String {
        placeContext.joined(separator: " · ").uppercased()
    }

    /// Finished Runs waiting to be saved to Apple Health.
    static var awaitingHealth: Predicate<Run> {
        #Predicate { $0.isFinished && $0.awaitsHealthSave }
    }

    /// Finished Runs whose place hasn't been looked up yet.
    static var awaitingPlace: Predicate<Run> {
        #Predicate { $0.isFinished && !$0.isPlaceLookedUp }
    }

    /// Runs that were stopped and saved: everything History and totals show.
    static var finished: Predicate<Run> {
        #Predicate { $0.isFinished }
    }

    /// Runs still being recorded, or left behind when the app was killed.
    static var unfinished: Predicate<Run> {
        #Predicate { !$0.isFinished }
    }

    /// An unfinished Run started at `startDate`, with nothing recorded yet.
    init(startDate: Date) {
        self.startDate = startDate
        endDate = startDate
        elapsedTime = 0
        distance = 0
        routeData = RouteEncoding.encode([])
        isFinished = false
    }

    /// Replaces what's stored with what `tracker` has recorded up to `date`; the Run stays unfinished.
    func checkpoint(_ tracker: RunTracker, at date: Date) {
        endDate = date
        elapsedTime = date.timeIntervalSince(tracker.runStart)
        movingTime = tracker.movingTime(at: date)
        pauses = tracker.pauses
        distance = tracker.distance
        routeData = RouteEncoding.encode(tracker.points)
    }

    /// Stores the Run `tracker` recorded, stopped at `date`, and marks it finished, with CAL (EST) for
    /// `bodyMass` kg if there is one. A Pause still going ends at Stop.
    func finish(_ tracker: RunTracker, at date: Date, bodyMass: Double? = nil) {
        checkpoint(tracker, at: date)
        pauses = tracker.pauses.map { Pause(start: $0.start, end: $0.end ?? date) }
        isFinished = true
        self.bodyMass = bodyMass
        activeCalories = bodyMass.map { Calories.activeKilocalories(route: tracker.points, pauses: pauses, bodyMass: $0) }
    }

    /// The look the photo is drawn with.
    var photoFilter: PhotoFilter {
        get { PhotoFilter(rawValue: photoFilterName) ?? .none }
        set { photoFilterName = newValue.rawValue }
    }

    /// How much darker this Run's photo is drawn, on every screen it appears on.
    var scrim: Scrim {
        Scrim(strength: photoScrimStrength)
    }

    /// Moving time over distance, or nil under 0.1 km.
    var averagePace: Pace? {
        Pace.average(movingTime: movingTime, distance: distance)
    }

    func decodedRoute() throws -> [RoutePoint] {
        try RouteEncoding.decode(routeData)
    }

    /// A tracker carrying on from what this Run has stored.
    func resumedTracker() throws -> RunTracker {
        RunTracker(runStart: startDate, points: try decodedRoute(), pauses: pauses)
    }
}

extension RunTotals {
    /// `runs` added up.
    init(_ runs: [Run]) {
        self.init(runs, distance: { $0.distance }, movingTime: { $0.movingTime })
    }
}
