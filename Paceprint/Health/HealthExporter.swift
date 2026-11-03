import CoreLocation
import Foundation
import HealthKit
import os
import PaceprintCore

/// A finished Run as Apple Health gets it: a running workout with its Route, distance and active energy.
struct HealthWorkout {
    let start: Date
    let end: Date
    let pauses: [Pause]
    /// The Route's fixes taken while moving and good to 50 m (`HealthRoute`).
    let route: [RoutePoint]
    /// Metres.
    let distance: Double
    /// CAL (EST), nil without a body weight.
    let activeCalories: Double?

    init(_ run: Run) throws {
        start = run.startDate
        end = run.endDate
        pauses = run.pauses
        route = HealthRoute.points(of: try run.decodedRoute())
        distance = run.distance
        activeCalories = run.activeCalories
    }
}

/// Apple Health, as far as Paceprint uses it: saving and deleting Runs' workouts, and reading body weight.
/// The app's seam for HealthKit, faked in tests.
protocol HealthExporter {
    /// Health exists on this device.
    var isAvailable: Bool { get }
    /// The runner allowed Paceprint to save workouts; reading can't be checked, by Health's design.
    var isWriteAllowed: Bool { get }
    /// Shows the system sheet asking to save workouts, routes, distance and active energy, and to read
    /// body weight. Health shows it only once; after that this returns at once.
    func requestAuthorization() async throws
    /// Saves `workout`, returning the Health workout's identifier. Once the workout is saved, this
    /// returns its identifier even if its Route couldn't be attached, so it's never saved twice.
    func save(_ workout: HealthWorkout) async throws -> UUID
    /// Deletes the Health workout with `id`; nothing happens if it's already gone.
    func deleteWorkout(_ id: UUID) async throws
    /// The latest body weight in kg, or nil if there's none or reading isn't allowed (they look the same).
    func latestBodyMass() async -> Double?
}

/// Apple Health through HealthKit: `HKWorkoutBuilder` for the workout, `HKWorkoutRouteBuilder` for its Route.
final class HealthKitExporter: HealthExporter {
    private let store = HKHealthStore()

    private let typesToWrite: Set<HKSampleType> = [
        .workoutType(),
        HKSeriesType.workoutRoute(),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.activeEnergyBurned),
    ]
    private let typesToRead: Set<HKObjectType> = [HKQuantityType(.bodyMass)]
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Paceprint", category: "Health")

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var isWriteAllowed: Bool {
        isAvailable && store.authorizationStatus(for: .workoutType()) == .sharingAuthorized
    }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: typesToWrite, read: typesToRead)
    }

    func save(_ workout: HealthWorkout) async throws -> UUID {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())

        try await builder.beginCollection(at: workout.start)
        var samples: [HKSample] = [
            HKQuantitySample(type: HKQuantityType(.distanceWalkingRunning), quantity: HKQuantity(unit: .meter(), doubleValue: workout.distance), start: workout.start, end: workout.end),
        ]
        if let calories = workout.activeCalories {
            samples.append(HKQuantitySample(type: HKQuantityType(.activeEnergyBurned), quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories), start: workout.start, end: workout.end))
        }
        try await builder.addSamples(samples)
        let events = workout.pauses.flatMap { pause -> [HKWorkoutEvent] in
            var events = [HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: pause.start, duration: 0), metadata: nil)]
            if let end = pause.end {
                events.append(HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: end, duration: 0), metadata: nil))
            }
            return events
        }
        if !events.isEmpty {
            try await builder.addWorkoutEvents(events)
        }
        try await builder.endCollection(at: workout.end)
        guard let saved = try await builder.finishWorkout() else { throw HealthKitError.notSaved }

        if !workout.route.isEmpty {
            do {
                let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
                try await routeBuilder.insertRouteData(workout.route.map(\.location))
                try await routeBuilder.finishRoute(with: saved, metadata: nil)
            } catch {
                // The workout is in Health already; saving it again would duplicate it.
                logger.error("Saved a Run to Health without its Route: \(error)")
            }
        }
        return saved.uuid
    }

    func deleteWorkout(_ id: UUID) async throws {
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(HKQuery.predicateForObject(with: id))], sortDescriptors: [])
        let workouts = try await descriptor.result(for: store)
        guard !workouts.isEmpty else { return }
        try await store.delete(workouts)
    }

    func latestBodyMass() async -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.bodyMass))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        return try? await descriptor.result(for: store).first?.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }

    enum HealthKitError: Error {
        /// HealthKit finished the workout without returning it.
        case notSaved
    }
}

private extension RoutePoint {
    var location: CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: -1,
            timestamp: timestamp
        )
    }
}
