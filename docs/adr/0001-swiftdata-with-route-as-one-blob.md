# SwiftData for Runs, with each Route stored as one encoded blob

Runs are stored with SwiftData (iOS 17+, on-device only), but a Run's Route is not modelled as child objects: it is a single binary-encoded `Data` property on the `Run` (`.externalStorage`), holding every filtered point (timestamp, latitude, longitude, altitude, horizontal accuracy, cumulative distance, paused flag). A one-hour Run is ~3,600 points; one SwiftData row per point would make saving, loading and deleting slow, and nothing ever queries individual points, since Splits and Pace colors are always recalculated from the whole Route.

## Considered Options

- **One SwiftData model per point**: natural-looking, but thousands of managed objects per Run for no query benefit.
- **GRDB / SQLite or plain files**: full control and fast, but gives up SwiftData's native SwiftUI integration for the Run list, which is the part that benefits from it.

## Consequences

- The point encoding needs a version byte so the format can change without a SwiftData migration.
- Summary fields (dates, Elapsed time, Moving time, distance, calories, body weight used) are stored alongside so Home and History never decode a Route.
