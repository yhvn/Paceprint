import PaceprintCore

/// Where a Run's location fixes come from: the device's GPS, or a replayed GPX file.
protocol LocationSource {
    /// Asks for When In Use permission if it hasn't been decided yet.
    /// Returns whether location can be used to record a Run.
    func requestAuthorization() async -> Bool

    /// Fixes as they arrive, unfiltered, until the stream is cancelled or the source runs out.
    func fixes() -> AsyncStream<LocationFix>
}
