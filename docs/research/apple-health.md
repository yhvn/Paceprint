# What Apple Health allows without an Apple Watch

Research for issue #5. Question: what can an iPhone-only app (no Apple Watch app) do with Apple Health for a **Run**, and what does it cost in permissions and App Review?

Researched 2026-10-28 against Apple's developer documentation (the DocC JSON behind developer.apple.com/documentation/healthkit), the WWDC25 session "Track workouts with HealthKit on iOS and iPadOS", and the App Store Review Guidelines. Where something is my inference rather than a stated fact, it says **(inference)**.

## TL;DR

- An iPhone app can save a full running workout to Health with **no Apple Watch**. You can do it today with `HKWorkoutBuilder` (iOS 12+), plus a **Route** via `HKWorkoutRouteBuilder` (iOS 11+), plus distance and active-energy samples.
- **iOS 26** added real iPhone workout sessions: `HKWorkoutSession(healthStore:configuration:)`, `HKLiveWorkoutBuilder`, and `HKLiveWorkoutDataSource`, with crash recovery. Here the system generates calories and distance for you. **iOS 17** only added *mirroring* a session that an Apple Watch started. That needs a Watch app, so it is no use to us.
- Body weight (`bodyMass`) can be read, but the app can never tell "denied" apart from "no data". It always needs an in-app fallback.
- Runs recorded elsewhere, such as by an Apple Watch with the built-in Workout app, can be read in later: query `HKWorkout`, then `HKWorkoutRoute`, then `HKWorkoutRouteQuery`. This needs read permission for workouts and routes.
- App Review: HealthKit must be used for health/fitness and integrate with the Health app (2.5.1). No ads or data-mining with the data, no writing false or inaccurate data, **no storing health data in iCloud** (5.1.3), and a privacy policy is required.

## 1. Saving a Run from iPhone

### Path A — `HKWorkoutBuilder` (works on our iOS 17 floor)

- `HKWorkoutBuilder` is "a builder object that incrementally constructs a workout", available iOS 12.0+. The docs say: "When the workout ends, call `finishWorkout(completion:)` to create an `HKWorkout` sample and save it to the HealthKit store." The note "For watchOS, use an `HKWorkoutSession` and an `HKLiveWorkoutBuilder` instead" applies to watchOS only. [HKWorkoutBuilder](https://developer.apple.com/documentation/healthkit/hkworkoutbuilder)
- `init(healthStore:configuration:device:)` (iOS 12+) "returns a new workout builder object that is not connected to a workout session or other data source". This is the standalone iPhone path. [init](https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/init(healthstore:configuration:device:))
- Lifecycle: `beginCollection(withStart:)` → `add(_:)` samples / `addWorkoutEvents(_:)` (pause/resume events) → `endCollection(withEnd:)` → `finishWorkout`. "You must call `endCollection(withEnd:completion:)` before calling this method. This function returns `nil` if finishing the workout succeeded but the workout sample is not available because the device is locked." [finishWorkout](https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/finishworkout(completion:))
- In this path **nothing is generated for you**. The app supplies its own `distanceWalkingRunning` and `activeEnergyBurned` samples. For `HKWorkout.totalEnergyBurned` the docs say: "add active energy burned samples to a workout … These samples should sum up to the total energy". [totalEnergyBurned](https://developer.apple.com/documentation/healthkit/hkworkout/totalenergyburned)
- `activeEnergyBurned` "should not include the resting energy burned during the sample's duration". So our calorie estimate must be *active* (net) kcal, not gross. [activeEnergyBurned](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/activeenergyburned)
- `distanceWalkingRunning` is cumulative, and "the system automatically records distance samples on iPhone and Apple Watch". The iPhone pedometer already writes passive distance. **(inference)** If we write our own GPS distance, the Health app's daily totals may count both, so we should attach our samples to the workout rather than treat them as the only source. [distanceWalkingRunning](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/distancewalkingrunning)

### Path B — iPhone workout session (iOS 26+)

- `HKWorkoutSession` has existed on iOS since 17.0. But on iOS 17 it only serves **mirroring**: `workoutSessionMirroringStartHandler` (iOS 17+) "is called on the companion iPhone when someone starts a mirrored workout on Apple Watch". The trigger, `startMirroringToCompanionDevice()`, is **watchOS-only**. Without a Watch app, iOS 17 gives us nothing here. [mirroring handler](https://developer.apple.com/documentation/healthkit/hkhealthstore/workoutsessionmirroringstarthandler), [startMirroring](https://developer.apple.com/documentation/healthkit/hkworkoutsession/startmirroringtocompaniondevice(completion:))
- Since **iOS 26.0**, an iPhone can run a primary session. These APIs are listed iOS 26.0+:
  - `HKWorkoutSession.init(healthStore:configuration:)`
  - `HKLiveWorkoutBuilder`
  - `HKLiveWorkoutDataSource`
  - `HKHealthStore.recoverActiveWorkoutSession(completion:)`

  [init](https://developer.apple.com/documentation/healthkit/hkworkoutsession/init(healthstore:configuration:)), [HKLiveWorkoutBuilder](https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilder), [HKLiveWorkoutDataSource](https://developer.apple.com/documentation/healthkit/hkliveworkoutdatasource), [recover](https://developer.apple.com/documentation/healthkit/hkhealthstore/recoveractiveworkoutsession(completion:))
- WWDC25 session 322 says existing Watch workout code runs on iPhone with minimal changes. The system produces "generated types … data types generated by the system during a workout activity like calories and distance". On iPhone the data source by default collects all types relevant to the activity. Heart rate needs a paired external BLE sensor. [WWDC25-322](https://developer.apple.com/videos/play/wwdc2025/322/)
- Locked phone: "health data is not normally available while a device is locked … The first time a workout session is started, the system will show a prompt indicating that workout data will be available to your app, even while the device is locked." The session also recommends a Live Activity and Siri intents (start/pause/resume/cancel from the Lock Screen). Apps relaunched after a crash recover through a new scene-delegate hook (`shouldHandleActiveWorkoutRecovery`). [WWDC25-322](https://developer.apple.com/videos/play/wwdc2025/322/), [HKWorkoutSession](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
- The session does **not** mention routes. There is also no documented iOS equivalent of watchOS's "Workout processing" background mode: iOS `UIBackgroundModes` values include `location` but no workout mode. **(inference)** Even on iOS 26 we still need Core Location with the `location` background mode for the GPS track, and `HKWorkoutRouteBuilder` to save it. [UIBackgroundModes](https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes), [Running workout sessions (watchOS)](https://developer.apple.com/documentation/healthkit/running-workout-sessions)

### Attaching the Route — `HKWorkoutRouteBuilder`

- Create it from the workout builder with `seriesBuilder(for: HKSeriesType.workoutRoute())`. "Instantiating a `HKWorkoutRouteBuilder` directly is discouraged." [HKWorkoutRouteBuilder](https://developer.apple.com/documentation/healthkit/hkworkoutroutebuilder)
- Feed it `CLLocation`s from Core Location with `insertRouteData(_:)`. Locations may arrive in any order; the builder sorts them by date. Apple's guidance: "Don't add any locations whose accuracy is greater than 50 meters. For best results, try to keep the time between locations to 3 seconds or less." [Creating a workout route](https://developer.apple.com/documentation/healthkit/creating-a-workout-route), [insertRouteData](https://developer.apple.com/documentation/healthkit/hkworkoutroutebuilder/insertroutedata(_:completion:))
- Order: save the workout first, then call `finishRoute(with:metadata:)`. "You can only associate a route with a single workout. After creating a route, you cannot change its workout." Permissions: read **and** share for both `HKWorkout` and `HKWorkoutRoute`, plus Core Location authorization. [Creating a workout route](https://developer.apple.com/documentation/healthkit/creating-a-workout-route)
- A stored route keeps timestamp, coordinate, altitude, speed, course and the accuracy fields. [Reading route data](https://developer.apple.com/documentation/healthkit/reading-route-data)

## 2. Reading body weight

- `HKQuantityTypeIdentifier.bodyMass` is "a quantity sample type that measures the user's weight", a discrete mass value, iOS 8+. Use the most recent sample. [bodyMass](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/bodymass)
- Read authorization is deliberately opaque: "your app cannot determine whether or not a user has granted permission to read data. If you are not given permission, it simply appears as if there is no data." [authorizationStatus(for:)](https://developer.apple.com/documentation/healthkit/hkhealthstore/authorizationstatus(for:))
- **New in iOS 27:** people can grant only a limited recent window of history. `getEarliestAuthorizedSampleDate(for:)` (iOS 27.0+) reveals that window, but "your app can't distinguish between denied and full access". A user's last weigh-in could fall outside the window. [Authorizing access](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data), [getEarliestAuthorizedSampleDate](https://developer.apple.com/documentation/healthkit/hkhealthstore/getearliestauthorizedsampledate(for:completion:))
- The HealthKit store is encrypted while the device is locked: reads may fail in the background, but writes are cached until unlock. Read weight while the app is in the foreground, for example at run start. [Protecting user privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)

## 3. Permissions and Info.plist

- Add the HealthKit capability. On iOS this adds `healthkit` to `UIRequiredDeviceCapabilities`. Remove that entry if Health is optional, so the app still installs everywhere. Leave "Clinical Health Records" unchecked, because App Review may reject an app that enables it without using it. [Setting up HealthKit](https://developer.apple.com/documentation/healthkit/setting-up-healthkit)
- `NSHealthShareUsageDescription` (read) and `NSHealthUpdateUsageDescription` (write) are mandatory: "You must set the usage keys, or your app will crash when you request authorization." [requestAuthorization](https://developer.apple.com/documentation/healthkit/hkhealthstore/requestauthorization(toshare:read:completion:))
- Call `HKHealthStore.isHealthDataAvailable()` first. Request authorization with `requestAuthorization(toShare:read:)` or SwiftUI's `.healthDataAccessRequest(...)` (needs `import HealthKitUI`). Apple says you may request just in time rather than all at once. The sheet shows per-type read/share toggles, and on iOS 27 a second screen for the history window. The app shows up in Health → Sources even if the user denies everything. [Authorizing access](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- Write status *is* knowable. Check `authorizationStatus(for:)` before saving. A save fails with `errorAuthorizationNotDetermined` or `errorAuthorizationDenied`. [Authorizing access](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- Likely request set for Paceline:
  - **Share:** `workoutType()`, `workoutRoute()`, `distanceWalkingRunning`, `activeEnergyBurned`
  - **Read:** `bodyMass`, plus `workoutType()` and `workoutRoute()` if we import runs
  - **Plus:** Core Location `NSLocationWhenInUseUsageDescription` and the `location` background mode **(inference: standard Core Location, not HealthKit)**

## 4. App Review rules

- **2.5.1:** "HealthKit should be used for health and fitness purposes and integrate with the Health app". Apps must "indicate that integration in their app description".
- **5.1.3(i):** no use or disclosure of HealthKit data for advertising, marketing or data mining, and "You must disclose the specific health data that you are collecting from the device."
- **5.1.3(ii):** "Apps must not write false or inaccurate data into HealthKit … and may not store personal health information in iCloud." Our on-device design is fine. **(inference)** We should never sync Health-derived data through CloudKit or iCloud, and we should not write a calorie estimate that duplicates system-generated calories on iOS 26.
- **5.1.2(vi), 2.5.18:** no ads or targeting based on HealthKit data.

[App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

- A privacy policy is required for any HealthKit app. Data may be shared with third parties only with express permission, and only with those that provide a health or fitness service. [Protecting user privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)

## 5. Reading runs recorded elsewhere (e.g. Apple Watch)

- Yes, if the user grants read access to workouts and workout routes. Steps:
  1. Query `HKWorkout` samples (filter to running).
  2. Get each workout's route with an `HKAnchoredObjectQuery` on `HKSeriesType.workoutRoute()`, using `predicateForObjects(from: workout)`.
  3. Pull the locations in batches with `HKWorkoutRouteQuery`.

  Apple recommends the anchored query because "route samples aren't static". Another app may add or replace a route after the workout is saved. [Reading route data](https://developer.apple.com/documentation/healthkit/reading-route-data), [HKWorkoutRouteQuery](https://developer.apple.com/documentation/healthkit/hkworkoutroutequery)
- Limits:
  - Denied read access looks like "no workouts".
  - iOS 27's limited-history grant may hide older runs.
  - Background reads fail while the phone is locked.

## Open questions

- The exact iPhone-side behaviour of `HKLiveWorkoutDataSource` for outdoor runs, such as GPS-based distance versus pedometer and whether a route is generated, is not documented in text. It needs a device spike on iOS 26.
- Whether an iOS 26 workout session alone keeps the app alive in the background, without the `location` background mode, is not documented.

## Recommendation

1. **Ship v1 on `HKWorkoutBuilder` + `HKWorkoutRouteBuilder`**, which works on the iOS 17 floor with no Watch. Own the GPS track (Core Location with the `location` background mode). On finish:
   - Write one `HKWorkout` (`.running`, `.outdoor`) with pause/resume events.
   - Write the Route.
   - Write `distanceWalkingRunning` and *active* `activeEnergyBurned` samples.
2. **Make Health optional and additive.** The Run lives in our on-device store first, and a Health export is a toggle. Remove `healthkit` from required device capabilities. Ask for permissions just in time, when the user enables the toggle.
3. **Body weight:** read `bodyMass` if granted. Always offer a manual weight in Settings as the fallback, since denial cannot be detected.
4. **Plan an iOS 26+ path** (`HKWorkoutSession` + `HKLiveWorkoutBuilder`) behind `#available`. It gives system-generated calories and distance, the locked-phone prompt, crash recovery, and Live Activity / Siri integration. When we use it, don't also write our own calorie estimate (5.1.3(ii)).
5. **Import of Watch runs** is feasible (workouts + routes read) but optional. Treat it as a later feature, not v1.
6. Write a privacy policy, mention Health integration in the App Store description, and never put Health-derived data in iCloud.
