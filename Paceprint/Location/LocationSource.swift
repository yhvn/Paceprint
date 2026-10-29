import PaceprintCore

/// Where a Run's location comes from: the device's GPS, or a replayed GPX file.
protocol LocationSource {
    /// Gets location ready for a Run: asks for When In Use permission if it hasn't been decided,
    /// and for temporary full accuracy if Precise Location is off.
    /// Returns what stops a Run from starting, or nil when it can start.
    func prepare() async -> LocationProblem?

    /// Location events as they happen, until the stream is cancelled or the source runs out.
    func events() -> AsyncStream<LocationEvent>
}

/// Why location can't be used to record a Run.
enum LocationProblem: CaseIterable, Equatable {
    /// The user turned location off for Paceprint.
    case denied
    /// Screen Time or device management doesn't allow location; the user can't change it.
    case restricted
    /// Location Services are off for the whole device.
    case servicesOff
    /// Only approximate location is allowed, and temporary full accuracy was declined.
    case preciseOff
}

enum LocationEvent: Equatable {
    /// A reading, before the noise filter.
    case fix(LocationFix)
    /// The device is standing still; the system sends no more fixes until it moves.
    case stationary
    /// Location access was turned off, or Precise Location was, during the Run.
    case accessLost
}
