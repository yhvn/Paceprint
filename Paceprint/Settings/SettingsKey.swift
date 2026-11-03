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
    /// Body weight in kg entered in Settings; 0 when not set.
    static let bodyMass = "bodyMass"
    /// The latest body weight in Apple Health, in kg, as last read; 0 when there's none to read.
    /// Kept on the device only, never synced (App Review 5.1.3).
    static let healthBodyMass = "healthBodyMass"
    /// "Save runs to Health": finished Runs are written to Apple Health.
    static let saveToHealth = "saveToHealth"
    /// The one-time "Save runs to Apple Health?" card has been answered, either way.
    static let isHealthCardAnswered = "isHealthCardAnswered"
}

extension UserDefaults {
    /// The body weight CAL (EST) is worked out with, in kg: Apple Health's latest, else the one entered
    /// in Settings; nil if neither.
    var bodyMass: Double? {
        healthBodyMass ?? positive(SettingsKey.bodyMass)
    }

    /// Apple Health's latest body weight in kg, as last read, or nil.
    var healthBodyMass: Double? {
        positive(SettingsKey.healthBodyMass)
    }

    private func positive(_ key: String) -> Double? {
        let value = double(forKey: key)
        return value > 0 ? value : nil
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
