# Pure Run rules live in a separate PaceprintCore package

Every rule that can be computed without the system (noise filter, distance, Pauses → Moving time, Pace, Splits, Pace colors, calories, Place name choice, Route encoding, week/month grouping) lives in a local Swift package, `PaceprintCore`, that imports no SwiftUI, SwiftData, Core Location or HealthKit. The app target holds the screens, SwiftData models and system adapters. We chose a package over folders in one target so the compiler stops system code leaking into the rules, and so `swift test` runs the rules on the Mac in seconds with no simulator.

## Consequences

- `PaceprintCore` types are `Sendable` and non-isolated; the app target keeps Xcode's MainActor-by-default.
- System behaviour reaches the rules only through four seams the app owns: `LocationSource`, `PlaceLookup`, `HealthExporter` and a clock.
