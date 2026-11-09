# Paceprint

An iPhone app for recording runs and sharing them as photo-backed, pace-colored route cards.

<!-- TODO: hero image. Export 2–3 screenshots (Active run, Run detail, Story card) into docs/images/ and replace this comment:
<p align="center">
  <img src="docs/images/active-run.png" width="30%" alt="Active run" />
  <img src="docs/images/run-detail.png" width="30%" alt="Run detail" />
  <img src="docs/images/story-card.png" width="30%" alt="Story card" />
</p>
-->

Paceprint draws every Run as a Route colored by Pace: green where you ran faster than your Average pace, red where you slowed down. Turn any Run into a 9:16 Story card over your own photo and share it anywhere.

## Features

- **Record:** live distance, Moving time and Current pace, with the screen locked too. A live map runs on Active run. Pauses never count toward time or Pace.
- **Review:** Splits per km or mile, a pace chart, a pace-colored Route map and a Place name for every Run.
- **Remember:** Runs stay on the iPhone (SwiftData). Home shows this week's distance, History shows all-time totals, and both have Route thumbnails.
- **Share:** Story cards with your photo (filters included) or a dark map, the Route in Pace colors and the headline numbers.
- **Apple Health:** finished Runs are saved as running workouts with route, distance and active calories. Body weight is read to estimate calories.
- **Private by design:** no Paceprint servers, no accounts, no ads. Map tiles come from Mapbox, and its telemetry is off unless the user turns it on.

## Requirements

- Xcode 26 or later (Swift 6)
- iOS 18.0 or later ([ADR 0002](docs/adr/0002-ios-18-minimum.md))
- A Mapbox account for a public access token (`pk.…`)

## Getting started

1. **Clone the repo**

   ```bash
   git clone https://github.com/yhvn/Paceprint.git
   cd Paceprint
   ```

2. **Add your Mapbox token.** The build stops with an error until you do.

   ```bash
   cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
   ```

   Set `MAPBOX_ACCESS_TOKEN` in `Config/Secrets.xcconfig` to your public token from <https://account.mapbox.com/access-tokens/>. Git ignores this file.

3. **Open and run**

   ```bash
   open Paceprint.xcodeproj
   ```

   Choose the `Paceprint` scheme and a simulator or device, then run. Swift Package Manager resolves `mapbox-maps-ios` on first open.

   To run on your own device, set your team under *Signing & Capabilities*. Personal (free) teams work too.

> **Tip:** to simulate a Run in the simulator, use *Features → Location → City Run*, or load the GPX fixture in `PaceprintTests/Fixtures/` from Xcode's *Debug → Simulate Location*.

## Project structure

```
Paceprint/             App target: SwiftUI screens, SwiftData models, system adapters
  Location/            Location sources: live GPS, GPX replay for tests
  Recording/           Run recorder (start / pause / stop)
  Health/              HealthKit workout sync
  Photos/              Run photos and photo filters
  Places/              Place names (CLGeocoder)
  Sharing/             Story card rendering and share sheet
  Settings/            Units, body weight, preferences
PaceprintCore/         Swift package of pure Run rules (no SwiftUI/SwiftData/CoreLocation/HealthKit)
PaceprintTests/        App-hosted tests
Config/                xcconfig build settings and secrets template
docs/
  adr/                 Architecture decision records
  app-store/           Listing draft and icon sources
  design/              Original design prototype
GLOSSARY.md            Domain language: Run, Route, Split, Pace, Pause, Story card, …
```

`PaceprintCore` holds every rule that can be computed without the system: noise filtering, distance, Pauses → Moving time, Pace, Splits, Pace colors, calories, Place name choice, Route encoding and week/month grouping. The compiler keeps system code out of it, and its tests run on the Mac in seconds ([ADR 0003](docs/adr/0003-pure-rules-in-paceprintcore-package.md)).

## Testing

```bash
# Pure rules: fast, no simulator
cd PaceprintCore && swift test

# App tests: needs a simulator
xcodebuild test -project Paceprint.xcodeproj -scheme Paceprint \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Architecture decisions

| ADR | Decision |
|---|---|
| [0001](docs/adr/0001-swiftdata-with-route-as-one-blob.md) | SwiftData for Runs, each Route stored as one encoded blob |
| [0002](docs/adr/0002-ios-18-minimum.md) | iOS 18 minimum, not iOS 17 |
| [0003](docs/adr/0003-pure-rules-in-paceprintcore-package.md) | Pure Run rules live in the `PaceprintCore` package |
| [0004](docs/adr/0004-product-named-paceprint.md) | The product is named Paceprint, not Paceline |
| [0005](docs/adr/0005-mapbox-for-maps-apple-for-place-names.md) | Mapbox for maps, Apple for place names |

## Contributing

- Use the words in [`GLOSSARY.md`](GLOSSARY.md) in code, UI copy and issues: *Run*, not workout. *Pace*, not speed.
- Issues live in GitHub Issues and use the triage labels in [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md).
- Record significant decisions as a new ADR in `docs/adr/`.

## Privacy & support

- Privacy policy: <https://yhvn.github.io/paceprint-site/privacy.html>
- Support: <https://yhvn.github.io/paceprint-site/support.html>
