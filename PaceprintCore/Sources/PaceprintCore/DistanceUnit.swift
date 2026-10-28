/// The unit distances are shown in: one Split is one whole unit.
public enum DistanceUnit: String, CaseIterable, Sendable {
    case kilometers
    case miles

    /// Metres in one unit. Stored distances are always metres; this converts for display.
    public var metresPerUnit: Double {
        switch self {
        case .kilometers: 1_000
        case .miles: 1_609.344
        }
    }
}
