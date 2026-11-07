# Mapbox for maps, Apple for place names

Every map in Paceprint (Run detail, Summary, the live map on Active run and the Story card's map background) is drawn by **Mapbox** (`mapbox-maps-ios`), not MapKit. The reason is the look: Mapbox's Standard style, lit for night, sits better behind Paceprint's black screens than MapKit's muted presets, and its OpenStreetMap data often shows more paths where people run. Place names still come from Apple's geocoder (`CLGeocoder`): it's free, already in the app, and has nothing to do with how a map looks. The Route is drawn exactly as before, from the same `PaceprintCore` rules, so maps, thumbnails and the Story card still match.

This is the app's first third-party dependency, and it changes the privacy promise. Map tiles come from Mapbox's servers, so Mapbox sees the device's IP address and the areas shown. Its SDK also sends usage telemetry unless told not to. Paceprint stores `MGLMapboxMetricsEnabled = false` on first launch, so telemetry is off until the user turns it on in the map's (i) menu (Mapbox's terms require that switch to stay reachable). The privacy page names Mapbox next to Apple, and the listing says "no Paceprint servers" rather than "no servers".

## Considered Options

- **Keep MapKit**: free, private by default, no account or token, but its styling stops at a few presets.
- **Mapbox with a style designed in Mapbox Studio**: full control of every color and label, but the style lives on a Mapbox account outside the repo. The built-in Standard style set in code was enough; moving to a Studio style later is one style URL.
- **Mapbox with MapKit as a fallback when there's no token**: two map implementations to keep forever. Instead the build fails without a token.

## Consequences

- A Mapbox account and public token are needed to build. The token lives in `Config/Secrets.xcconfig`, which git ignores; `Config/Secrets.example.xcconfig` shows what to fill in.
- Mapbox's logo and (i) attribution button must stay visible on every map, so they're raised above whatever covers a map's bottom edge. A Story card over the map carries "© Mapbox © OpenStreetMap" and the Mapbox logo, drawn above its scrim.
- Free up to 25,000 monthly active users, then billed per user.
- Pinned to Mapbox **11.30.x**, the newest line that builds with Xcode 26.3; later versions need Xcode 26.5. Move up when Xcode is updated.
- `MGLMapboxMetricsEnabled` is a setting Mapbox's SDK reads, not a documented API; a test checks Paceprint sets it, but a future SDK could stop reading it. Check it when updating Mapbox.
