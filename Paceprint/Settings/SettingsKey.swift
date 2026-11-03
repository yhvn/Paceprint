import Foundation
import PaceprintCore

/// Where the runner's settings are kept in `UserDefaults`, read with `@AppStorage`.
enum SettingsKey {
    /// The runner's name for Home's greeting; empty when not given.
    static let name = "name"
    /// A `DistanceUnit` raw value; kilometres when not set.
    static let units = "units"
    /// A `RoutePalette` raw value; the pace palette when not set.
    static let routePalette = "routePalette"
    /// Body weight in kg; 0 when not set.
    static let bodyMass = "bodyMass"
}

extension UserDefaults {
    /// The body weight set in Settings, in kg, or nil.
    var bodyMass: Double? {
        let kilograms = double(forKey: SettingsKey.bodyMass)
        return kilograms > 0 ? kilograms : nil
    }
}

extension BodyMassUnit {
    /// As shown beside a body weight: "kg" or "lb".
    var abbreviation: String {
        switch self {
        case .kilograms: "kg"
        case .pounds: "lb"
        }
    }
}
