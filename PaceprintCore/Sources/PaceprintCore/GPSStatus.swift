/// How well GPS is keeping up during a Run, for the Active run screen's pill.
public enum GPSStatus: Equatable, Sendable {
    /// No point has been kept yet: "Finding GPS…".
    case finding
    /// No point has been kept for a while: "Weak GPS".
    case weak
    case good
}
