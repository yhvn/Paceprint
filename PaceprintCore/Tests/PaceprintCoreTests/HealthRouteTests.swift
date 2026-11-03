import Foundation
import Testing
import PaceprintCore

@Suite("Health route")
struct HealthRouteTests {
    @Test("Apple Health gets the Route's moving fixes good to 50 m")
    func points() {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        func point(_ seconds: Double, accuracy: Double = 5, isPaused: Bool = false) -> RoutePoint {
            RoutePoint(timestamp: start + seconds, latitude: 40.78, longitude: -73.966, altitude: 30, horizontalAccuracy: accuracy, cumulativeDistance: seconds, isPaused: isPaused)
        }
        let route = [point(0), point(1, accuracy: 50), point(2, accuracy: 51), point(3, isPaused: true), point(4)]

        #expect(HealthRoute.points(of: route).map(\.cumulativeDistance) == [0, 1, 4])
    }
}
