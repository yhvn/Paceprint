# App Store listing (draft)

Draft for #33. App Store Connect limits are noted against each field; counts are checked with the script at the bottom.

| Field | Value |
|---|---|
| Name (≤ 30) | Paceprint |
| Subtitle (≤ 30) | Run tracker with pace routes |
| Category | Health & Fitness (no secondary) |
| Price | Free, no in-app purchases, no ads |
| Age rating | 4+ |
| Availability | All countries |
| Privacy label | Paceprint itself collects nothing. Mapbox's SDK declares Precise Location, Coarse Location and User ID (not linked to identity, not tracking), sent only if the user turns Mapbox telemetry on: declare those as collected by a third party (ADR 0005) |
| Privacy policy URL | https://yhvn.github.io/paceprint-site/privacy.html |
| Support URL | https://yhvn.github.io/paceprint-site/support.html |
| Screenshots | 6.9" iPhone only |

## Keywords (≤ 100, comma-separated, no spaces)

```
running,run,gps,pace,route,map,splits,jogging,runner,tracker,workout,story,share,calories,km,miles
```

## Promotional text (≤ 170)

```
Record every run as a map of your pace: green where you flew, red where you dug in. Share it as a Story card over your own photo.
```

## Description (≤ 4000)

```
Paceprint records your runs and draws each one as a route colored by your pace: green where you ran faster than your average, red where you slowed down.

RECORD
• Tap Start and run. Distance, time and pace update live, with the screen locked too.
• Pause and resume whenever you like; pauses never count toward your time or pace.
• Splits per kilometre or mile, and a pace chart for every run.

REMEMBER
• Every run is kept on your iPhone with its route, splits and place name.
• See this week's distance on Home and all-time totals in History.
• Pick a photo for each run; Paceprint shows your route and numbers over it.

SHARE
• Turn any run into a Story-sized card: your photo, your route in pace colors and your numbers.
• Share it anywhere through the share sheet.

APPLE HEALTH
Paceprint uses Apple Health for fitness tracking. With your permission it saves each finished run to Health as a running workout, with its route, distance and active calories, so it counts toward your Activity rings. It can also read your body weight to estimate calories. Health data stays on your device: it is never sent to us, used for advertising or shared with anyone.

PRIVATE BY DESIGN
No account, no sign-up, no Paceprint servers. Your runs never leave your iPhone unless you share them yourself.

Paceprint is free, with no ads and no in-app purchases. iPhone, iOS 18 or later.
```

## What's New (1.0)

```
First release.
```

## App Review notes

```
No account or sign-in is needed. To try a run in the simulator or at a desk, start a run and walk a short distance outdoors; a run under 0.1 km or 1 minute offers to be discarded.
Apple Health is optional: it's offered once on the Summary after the first run and can be switched in Settings.
Location is used only while a run is being recorded (When In Use with background location updates).
```

## Checking the limits

```sh
python3 - <<'EOF'
import re
s = open('docs/app-store/listing.md').read()
blocks = re.findall(r'## (.+?)\n.*?```\n(.*?)```', s, re.S)
for title, body in blocks:
    print(f"{len(body.rstrip(chr(10))):5}  {title}")
EOF
```
