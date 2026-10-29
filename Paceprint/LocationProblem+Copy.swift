/// What the screens say about each location problem (decided in #9).
extension LocationProblem {
    var title: String {
        switch self {
        case .denied, .restricted: "Location is off for Paceprint"
        case .servicesOff: "Location Services are off"
        case .preciseOff: "Precise Location is off"
        }
    }

    var message: String {
        switch self {
        case .denied, .restricted: "Paceprint needs your location to record a run. Turn it on in Settings."
        case .servicesOff: "Turn them on in Settings › Privacy & Security › Location Services to record a run."
        case .preciseOff: "Paceprint can't measure distance and pace with approximate location. Turn on Precise Location for Paceprint in Settings."
        }
    }

    /// Whether the alert offers Paceprint's page in Settings. Restricted access can't be changed
    /// there, and the system Location Services switch isn't reachable by link.
    var offersSettings: Bool {
        switch self {
        case .denied, .preciseOff: true
        case .restricted, .servicesOff: false
        }
    }

    /// The button that just closes the alert: Cancel beside Open Settings, else OK,
    /// except Restricted, which is the denied alert without Open Settings.
    var dismissTitle: String {
        switch self {
        case .denied, .preciseOff, .restricted: "Cancel"
        case .servicesOff: "OK"
        }
    }
}
