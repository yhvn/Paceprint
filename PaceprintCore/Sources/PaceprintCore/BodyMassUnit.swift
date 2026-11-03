import Foundation

/// The unit body weight is shown and entered in: kilograms with kilometres, pounds with miles.
/// It's always stored in kilograms.
public enum BodyMassUnit: Equatable, Sendable {
    case kilograms, pounds

    static let kilogramsPerPound = 0.45359237
    /// The lightest and heaviest body weights taken, in kg; anything else is a slip of the finger.
    static let plausible = 20.0...350.0

    /// `kilograms` in this unit.
    public func value(ofKilograms kilograms: Double) -> Double {
        self == .pounds ? kilograms / Self.kilogramsPerPound : kilograms
    }

    /// `value` in this unit, in kilograms.
    public func kilograms(_ value: Double) -> Double {
        self == .pounds ? value * Self.kilogramsPerPound : value
    }

    /// Whether a runner could weigh `kilograms`.
    public static func isPlausible(kilograms: Double) -> Bool {
        plausible.contains(kilograms)
    }
}

extension DistanceUnit {
    /// The body weight unit that goes with these units.
    public var bodyMassUnit: BodyMassUnit {
        self == .miles ? .pounds : .kilograms
    }
}
