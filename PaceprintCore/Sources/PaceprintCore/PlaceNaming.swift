import Foundation

/// What a reverse lookup found at one point of a Route, from the narrowest name to the widest.
public struct Placemark: Equatable, Sendable {
    /// Parks, waterfronts and other landmark areas the point is in.
    public var areasOfInterest: [String]
    /// A neighbourhood or borough, inside a city.
    public var neighbourhood: String?
    public var city: String?
    /// A state or province.
    public var region: String?
    public var country: String?

    public init(areasOfInterest: [String], neighbourhood: String?, city: String?, region: String?, country: String?) {
        self.areasOfInterest = areasOfInterest
        self.neighbourhood = neighbourhood
        self.city = city
        self.region = region
        self.country = country
    }
}

/// Where a Run happened: its Place name, and the wider names of its Place context.
public struct Place: Equatable, Sendable {
    public let name: String
    /// Up to two names, going outward from the Place name.
    public let context: [String]

    public init(name: String, context: [String]) {
        self.name = name
        self.context = context
    }
}

/// How a Run's Place name and Place context are chosen from lookups along its Route.
public enum PlaceNaming {
    /// How many of the looked-up points must share an area of interest for it to name the Run.
    static let pointsSharingArea = 3

    /// The points to look up: the start, 25%, 50% and 75% of the distance, and the end; fewer when
    /// the Route is too short for them to differ. Points taken during a Pause are left out.
    public static func lookupPoints(of route: [RoutePoint]) -> [RoutePoint] {
        let moving = route.filter { !$0.isPaused }
        guard let total = moving.last?.cumulativeDistance else { return [] }
        var indices: [Int] = []
        for fraction in [0, 0.25, 0.5, 0.75, 1.0] {
            let index = moving.firstIndex { $0.cumulativeDistance >= total * fraction } ?? moving.count - 1
            if indices.last != index {
                indices.append(index)
            }
        }
        return indices.map { moving[$0] }
    }

    /// The Place for lookups along a Route, the start's first: an area of interest shared by 3 or more
    /// points, else the start's neighbourhood, else its city. Nil if none of those were found.
    public static func place(from placemarks: [Placemark]) -> Place? {
        if let (area, placemark) = sharedAreaOfInterest(in: placemarks) {
            return Place(name: area, context: context(after: area, in: [placemark.neighbourhood, placemark.city, placemark.region, placemark.country]))
        }
        for placemark in placemarks {
            if let neighbourhood = placemark.neighbourhood {
                return Place(name: neighbourhood, context: context(after: neighbourhood, in: [placemark.city, placemark.region, placemark.country]))
            }
            if let city = placemark.city {
                // Just the one wider name: the region, else the country.
                return Place(name: city, context: Array(context(after: city, in: [placemark.region, placemark.country]).prefix(1)))
            }
        }
        return nil
    }

    /// The name a Run goes by until its Place is found: MORNING RUN 5:00–11:59, AFTERNOON RUN 12:00–16:59,
    /// EVENING RUN 17:00–20:59, NIGHT RUN 21:00–4:59, by when it started.
    public static func timeOfDayName(startingAt date: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: "MORNING RUN"
        case 12..<17: "AFTERNOON RUN"
        case 17..<21: "EVENING RUN"
        default: "NIGHT RUN"
        }
    }

    /// The area of interest the most points share, if 3 or more do, with the first placemark in it.
    private static func sharedAreaOfInterest(in placemarks: [Placemark]) -> (String, Placemark)? {
        var counts: [String: Int] = [:]
        for placemark in placemarks {
            for area in Set(placemark.areasOfInterest) {
                counts[area, default: 0] += 1
            }
        }
        // Most shared first; ties go to the one met first along the Route.
        guard let most = counts.values.max(), most >= pointsSharingArea,
              let area = placemarks.flatMap(\.areasOfInterest).first(where: { counts[$0] == most }),
              let placemark = placemarks.first(where: { $0.areasOfInterest.contains(area) })
        else { return nil }
        return (area, placemark)
    }

    /// Up to two of `wider`, in order, skipping missing names and any that repeat `name` or each other.
    private static func context(after name: String, in wider: [String?]) -> [String] {
        var context: [String] = []
        for case let next? in wider where context.count < 2 {
            let used = [name] + context
            if !used.contains(where: { $0.caseInsensitiveCompare(next) == .orderedSame }) {
                context.append(next)
            }
        }
        return context
    }
}
