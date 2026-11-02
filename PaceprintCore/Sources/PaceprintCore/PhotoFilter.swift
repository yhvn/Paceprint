/// The look a Run's photo is drawn with, picked on Summary. Stored on the Run by raw value.
public enum PhotoFilter: String, CaseIterable, Codable, Sendable {
    case none
    case chroma
    case noir
    case dusk
    case film
}
