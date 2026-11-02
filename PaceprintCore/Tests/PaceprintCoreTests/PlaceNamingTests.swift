import Foundation
import Testing
import PaceprintCore

private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

private func point(_ distance: Double, isPaused: Bool = false) -> RoutePoint {
    RoutePoint(
        timestamp: start + distance,
        latitude: 40.78 + distance / 111_195,
        longitude: -73.966,
        altitude: 30,
        horizontalAccuracy: 5,
        cumulativeDistance: distance,
        isPaused: isPaused
    )
}

/// Somewhere in Manhattan, in Central Park when `inPark`.
private func manhattan(inPark: Bool = true) -> Placemark {
    Placemark(
        areasOfInterest: inPark ? ["Central Park"] : [],
        neighbourhood: "Manhattan",
        city: "New York",
        region: "NY",
        country: "United States"
    )
}

@Suite("Place naming")
struct PlaceNamingTests {
    @Test("Up to 5 points are looked up: the start, 25%, 50% and 75% of the distance, and the end")
    func lookupPoints() {
        let route = stride(from: 0.0, through: 1_000, by: 10).map { point($0) }

        let points = PlaceNaming.lookupPoints(of: route)

        #expect(points.map(\.cumulativeDistance) == [0, 250, 500, 750, 1_000])
    }

    @Test("Points taken during a Pause aren't looked up, and a short Route has fewer points")
    func lookupPointsShortRoute() {
        let route = [point(0), point(0, isPaused: true), point(5)]

        #expect(PlaceNaming.lookupPoints(of: route).map(\.cumulativeDistance) == [0, 5])
        #expect(PlaceNaming.lookupPoints(of: [point(0)]).map(\.cumulativeDistance) == [0])
        #expect(PlaceNaming.lookupPoints(of: []).isEmpty)
    }

    @Test("An area of interest shared by 3 or more points is the Place name, with the wider names as its context")
    func areaOfInterest() {
        let placemarks = [manhattan(inPark: false), manhattan(), manhattan(), manhattan(), manhattan(inPark: false)]

        let place = PlaceNaming.place(from: placemarks)

        #expect(place == Place(name: "Central Park", context: ["Manhattan", "New York"]))
    }

    @Test("An area of interest shared by only 2 points gives way to the start's neighbourhood")
    func neighbourhood() {
        let start = Placemark(areasOfInterest: [], neighbourhood: "Williamsburg", city: "New York", region: "NY", country: "United States")
        let placemarks = [start, manhattan(), manhattan(), manhattan(inPark: false)]

        let place = PlaceNaming.place(from: placemarks)

        #expect(place == Place(name: "Williamsburg", context: ["New York", "NY"]))
    }

    @Test("With no neighbourhood at the start, the city is the Place name and its context its region and country")
    func city() {
        let placemarks = [Placemark(areasOfInterest: [], neighbourhood: nil, city: "Hanoi", region: nil, country: "Vietnam")]

        #expect(PlaceNaming.place(from: placemarks) == Place(name: "Hanoi", context: ["Vietnam"]))
    }

    @Test("The context never repeats the Place name, or itself")
    func contextDoesntRepeat() {
        let placemarks = [Placemark(areasOfInterest: [], neighbourhood: "Singapore", city: "Singapore", region: nil, country: "Singapore")]

        #expect(PlaceNaming.place(from: placemarks) == Place(name: "Singapore", context: []))
    }

    @Test("When every lookup finds nothing nameable, there's no Place")
    func nothingFound() {
        let empty = Placemark(areasOfInterest: [], neighbourhood: nil, city: nil, region: nil, country: "Atlantic Ocean")

        #expect(PlaceNaming.place(from: [empty, empty]) == nil)
        #expect(PlaceNaming.place(from: []) == nil)
    }

    @Test("Until a Place is found, a Run is named by the time it started", arguments: [
        (hour: 5, minute: 0, name: "MORNING RUN"),
        (hour: 11, minute: 59, name: "MORNING RUN"),
        (hour: 12, minute: 0, name: "AFTERNOON RUN"),
        (hour: 16, minute: 59, name: "AFTERNOON RUN"),
        (hour: 17, minute: 0, name: "EVENING RUN"),
        (hour: 20, minute: 59, name: "EVENING RUN"),
        (hour: 21, minute: 0, name: "NIGHT RUN"),
        (hour: 4, minute: 59, name: "NIGHT RUN"),
    ])
    func timeOfDay(hour: Int, minute: Int, name: String) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Ho_Chi_Minh"))
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: hour, minute: minute)))

        #expect(PlaceNaming.timeOfDayName(startingAt: date, calendar: calendar) == name)
    }
}
