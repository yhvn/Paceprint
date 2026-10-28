# iOS 18 is the minimum, not iOS 17

Paceline was charted against an iOS 17 floor (early research and decisions say "iOS 17"), but v1 targets **iOS 18.0**. SwiftData on iOS 17 has bugs serious enough to matter for an app whose only store is SwiftData, and iOS 18's location-update diagnostics report denied or accuracy-limited permission directly in the location stream, which simplifies the permission states. No earlier decision changes: the `HKWorkoutBuilder` Health path and `CLGeocoder` both work on 18.

## Considered Options

- **iOS 17**: widest reach, but buggy SwiftData and no in-stream permission diagnostics.
- **iOS 26** (the Xcode template's default): newest APIs (iPhone `HKWorkoutSession`, MapKit reverse geocoding), but cuts off every device still on 17 or 18, and `CLGeocoder` is deprecated there.
