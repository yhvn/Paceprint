import Foundation

/// Which of a Run's Route points go into its Apple Health workout route.
public enum HealthRoute {
    /// Fixes vaguer than this, in metres, are left out of the Route Health keeps.
    public static let maximumHorizontalAccuracy = 50.0

    /// The Route's fixes taken while moving and good to 50 m, as Health's route builder wants them.
    public static func points(of route: [RoutePoint]) -> [RoutePoint] {
        route.filter { !$0.isPaused && $0.horizontalAccuracy <= maximumHorizontalAccuracy }
    }
}
