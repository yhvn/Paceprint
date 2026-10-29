/// How well GPS is keeping up during a Run.
public enum GPSStatus: Equatable, Sendable {
    /// No point has been kept yet: "Finding GPS…".
    case finding
    /// No point has been kept for a while: "Weak GPS".
    case weak
    /// Points are being kept, or the device is standing still.
    case good
}
