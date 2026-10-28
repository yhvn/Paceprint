# Recording a Run's location in the background

Research for issue #2. Question: how should Paceline record a Run's location on iOS 17+ so that recording continues with the screen locked, is accurate enough to compute Pace, and doesn't drain the battery?

Researched 2026-10-28. Sources are Apple developer documentation, WWDC sessions, and Apple-engineer answers on the Apple Developer Forums. Each claim cites its source in brackets; the sources are listed at the end. Anything marked **(our judgement)** is not from Apple.

## 1. `CLLocationUpdate.liveUpdates` vs `CLLocationManager`

**`CLLocationUpdate.liveUpdates(_:)` (iOS 17+)** returns an `AsyncSequence` of `CLLocationUpdate`. Each update has an optional `location` and an `isStationary` flag [WWDC23-10180, doc:CLLocationUpdate]. "Explicit start and stop messages are not required anymore": iterating the sequence starts updates, and leaving the loop or cancelling the task stops them [WWDC23-10180].
- You configure it only with a `LiveConfiguration` preset: `default`, `automotiveNavigation`, `otherNavigation`, `fitness`, `airborne`, `maritime` [doc:LiveConfiguration]. `.fitness` is "for dedicated fitness sessions" [doc:LiveConfiguration.fitness] and matches `CLActivityType.fitness` [WWDC23-10180].
- It has **no `desiredAccuracy` or `distanceFilter` equivalent.** Developers have filed feedback asking for them (FB16218331, FB16226614), and no Apple engineer has replied in that thread [forum:731399]. The preset is the only accuracy and power setting.
- On iOS 18 and later, each update carries diagnostic flags: `stationary`, `locationUnavailable`, `accuracyLimited`, `authorizationDenied`, `authorizationDeniedGlobally`, `authorizationRestricted`, `authorizationRequestInProgress`, `insufficientlyInUse`, and `serviceSessionRequired` [doc:CLLocationUpdate, WWDC24-10212]. "whenever updates … won't be able to yield their intended result, Core Location will always let you know why" [WWDC24-10212]. On iOS 17 only `isStationary` and `location` exist.
- If no location is available, you receive an update whose `location` is `nil` [WWDC23-10180].

**`CLLocationManager`** (delegate-based, all versions) still works and gives full control: `activityType`, `desiredAccuracy`, `distanceFilter`, `pausesLocationUpdatesAutomatically`, `allowsBackgroundLocationUpdates`, `showsBackgroundLocationIndicator`.

Apple's current docs and sample code (the "Adopting live updates in Core Location" sample, which needs iOS 18) build on `liveUpdates`, `CLBackgroundActivitySession`, and `CLServiceSession` [doc:handling-bg, doc:sample].

## 2. Background recording with "When In Use" permission

**When In Use is enough. Always is not needed.**

- `CLBackgroundActivitySession` (iOS 17+) "allows a when-in-use authorized app to receive location updates or monitoring events" while in the background [doc:CLBackgroundActivitySession].
- Requirements [WWDC23-10180, doc:handling-bg]:
  - Turn on the **Location updates** background mode, which adds `UIBackgroundModes` = `location`.
  - Add `NSLocationWhenInUseUsageDescription`.
  - **Create the session while the app is in the foreground.** "If you don't have an outstanding session, then you must start the new session from the foreground, but you can only rejoin an existing one from the background."
  - **Keep a strong reference** in a property. If the object is deallocated, the session is invalidated. End it with `invalidate()`.
- **The indicator:** while the app is in the background, the session shows the blue background-location indicator (a status-bar pill, or in the Dynamic Island). "Just creating the session displays the indicator when your app is in the background" [WWDC23-10180]. For When In Use apps the indicator always appears and cannot be hidden. `showsBackgroundLocationIndicator` only affects apps with Always authorization [doc:showsBackgroundLocationIndicator]. An Apple engineer advised leaving the indicator alone: "let the users know that your app is tracking their location" [forum:810433]. For a running app the indicator is expected behaviour.
- A Live Activity is described as an alternative way to keep the app eligible for background updates [WWDC23-10180]. However, a June 2025 forum report says updates stopped after about 10 s with only a Live Activity, and that adding a `CLBackgroundActivitySession` fixed it. Nobody from Apple answered [forum:788647]. **(our judgement)** Always hold a `CLBackgroundActivitySession` during a Run, even if we also show a Live Activity.
- Without a session or Live Activity, a When In Use app that goes to the background gets no updates: Core Location "does not generate or deliver updates for which an app is not authorized, for example due to having .whenInUse authorization, and being backgrounded without a LiveActivity or CLBackgroundActivitySession in effect" [WWDC24-10212].
- **Implicit authorization:** iterating `liveUpdates` or creating a `CLBackgroundActivitySession` implicitly holds a `.whenInUse` service session, which triggers the permission prompt. Setting `NSLocationRequireExplicitServiceSession` in Info.plist turns that off [doc:handling-bg, WWDC24-10212]. To control *when* the prompt appears (for example after onboarding), create `CLServiceSession(authorization: .whenInUse)` explicitly (iOS 18+) or call `requestWhenInUseAuthorization()` on iOS 17.
- **Precise location:** if the user picks approximate location, updates arrive only every 15–20 minutes (`accuracyLimited`) [WWDC24-10212]. That is useless for Pace. Request temporary full accuracy with a purpose key (`CLServiceSession(authorization:fullAccuracyPurposeKey:)`, or `requestTemporaryFullAccuracyAuthorization`) when a Run starts.

**Relaunch after termination.** Core Location can relaunch a terminated app in the background when updates are pending. The app must immediately, in `application(_:didFinishLaunchingWithOptions:)` or its equivalent, recreate its `CLBackgroundActivitySession` (which rejoins the existing session) and restart `liveUpdates`. Core Location keeps the outstanding sessions "for only a few seconds after the app is launched again" [WWDC23-10180, WWDC24-10212, doc:handling-bg]. Paceline therefore has to persist "a Run is in progress" (and the points recorded so far) to disk, so that a relaunch can resume the same Run.

**Legacy path (`CLLocationManager`).** To get the same effect, set `allowsBackgroundLocationUpdates = true` and start updates in the foreground. "Core Location configures the system to keep the app running … and arranges to show the background location indicator". Setting it to true without the `location` background mode crashes the app [doc:allowsBackgroundLocationUpdates]. Since iOS 16.4, continuous background updates also need `distanceFilter = kCLDistanceFilterNone` and `desiredAccuracy` of `kCLLocationAccuracyHundredMeters` or better, or else the indicator turned on [forum:726945, Apple engineer].

## 3. Activity type, accuracy, and distance filter for running

- **`liveUpdates`:** use `CLLocationUpdate.liveUpdates(.fitness)`. There are no other settings.
- **`CLLocationManager` (fallback / iOS 17 alternative):**
  - `activityType = .fitness`. This means "dedicated fitness sessions, such as … running workouts". Note: "When activityType is fitness, the system disables indoor positioning" [doc:CLActivityType.fitness], which is fine for outdoor Runs.
  - `desiredAccuracy = kCLLocationAccuracyBest`. Not `BestForNavigation`, which Apple says to use "only while the device is plugged in" because of its extra power cost [doc:BestForNavigation].
  - `distanceFilter = kCLDistanceFilterNone` (the default). This is required for reliable background delivery since iOS 16.4 [doc:distanceFilter, forum:726945].
  - `pausesLocationUpdatesAutomatically = false`. The default is true, and "for apps that have in-use authorization, a pause to location updates ends access to location changes until the app launches again" [doc:pausesLocationUpdatesAutomatically]. That would silently end a Run.
- **Battery:** Apple offers no extra power setting beyond the `.fitness` preset. **(our judgement)** The biggest battery wins are app-side: don't redraw the map or the Route polyline while the app is in the background or the screen is locked, batch disk writes, and stop updates and invalidate the session as soon as the Run is stopped.

## 4. Discarding noisy or jumpy fixes

Apple documents the inputs but not a filtering algorithm. What is documented:
- `horizontalAccuracy` is the radius of uncertainty in metres. A **negative value means the coordinate is invalid** [doc:horizontalAccuracy].
- `CLLocation.sourceInformation.isSimulatedBySoftware` (iOS 15+) is true for locations simulated in Xcode or from GPX files. Apps may reject these "when the developer isn't debugging or testing the app" [doc:sourceInformation, doc:isSimulatedBySoftware].
- Using `first(where:)` on accuracy blocks until a match arrives, so be careful with accuracy predicates [WWDC23-10180].

**(our judgement)** A filter that is simple and testable, applied before a point joins the Route or counts toward distance:
1. Drop the point if `location == nil` or `horizontalAccuracy < 0`.
2. Drop the point if `horizontalAccuracy` is above a threshold (start with about 20–30 m, then tune on device).
3. Drop stale or out-of-order points (timestamp older than the last accepted point).
4. Drop "teleports": the implied speed from the last accepted point is above a running ceiling (for example 12 m/s).
5. Optionally, ignore movement smaller than the combined accuracy radii, to avoid GPS drift adding distance while standing still.

Keep this as a pure function `(lastAccepted, candidate) -> accept/reject` so it can be unit-tested with constructed `CLLocation` values.

## 5. Pauses and the location stream

There are two kinds of pause:

- **System stationary pause (`liveUpdates`):** when the device is still "for a sufficient amount of time", Core Location pauses automatically. You get an update with `isStationary == true` and a valid location, then no updates until the user moves again. Updates resume with `isStationary == false` automatically, without user interaction [WWDC23-10180, doc:isStationary]. This saves battery at traffic lights and ends no session. It is *not* a user Pause.
- **User Pause (the Run's pause):** **do not stop `liveUpdates` and do not invalidate the `CLBackgroundActivitySession`.** A new session can only be started from the foreground [WWDC23-10180]. If the user pauses from the lock screen or a Live Activity and we tore the session down, we could not resume in the background. An Apple engineer also warned that stopping updates risks the app never being relaunched if it is terminated while updates are inactive. "When the stationary property is set, you will stop getting updates until the device moves again. So there is no need to stop the updates" [forum:810433]. Instead, keep the stream running and mark incoming points as "paused": don't add them to distance or moving time. **(our judgement)** On resume, start a new Route segment, so that no line or distance is counted across the pause gap.

## 6. Simulating a Run in the Simulator and in tests

- **Simulator, interactive:** the Simulator app's Features ▸ Location menu offers presets including **City Run** and Freeway Drive, plus custom locations. In Xcode, the scheme editor's Run ▸ Options ▸ "Allow Location Simulation" can load a default location or a **GPX file** added to the project [Xcode help: simulate location in scheme]. GPX files with multiple waypoints (with `<time>`) replay as movement.
- **Test plans:** Product ▸ Test Plan ▸ Edit Test Plan ▸ Configuration ▸ Localization ▸ Simulated Location: pick a location, or "Add GPX File to Workspace" to "replay a journey while your tests are running, updating the simulated location, elevation, and velocity". This applies only to code in the test bundle, not to the app process in UI tests [doc:simulating-location-in-tests].
- **UI tests:** set `XCUIDevice.shared.location = XCUILocation(location: CLLocation(...))` [doc:simulating-location-in-tests].
- **Unit tests:** "you don't need to use CLLocationManager or get the device's location". Construct values and pass them to the code under test [doc:simulating-location-in-tests]. `CLLocation` has public initialisers that take accuracy, speed, and timestamp. **(our judgement)** `CLLocationUpdate` has no public initialiser, so hide the stream behind a small protocol, for example `LocationSource: AsyncSequence<LocationSample>`, with a live implementation over `liveUpdates` and a fake that replays an array or a GPX file. Run the filtering, Split, and Pace logic against the fake.
- Background behaviour, the indicator, termination and relaunch, and real GPS noise **must be verified on a physical iPhone**. Simulator behaviour around background sessions has been reported to differ [forum:788647].

## 7. Beyond iOS 17 (optional, later)

iOS 26 brings `HKWorkoutSession` to iPhone, with lock-screen start/pause/resume and crash recovery (`shouldHandleActiveWorkoutRecovery`) [WWDC25-322]. That would mean adopting HealthKit, which is outside the current "all data on-device, no Watch" scope. Note it as a possible later enhancement only.

## Recommendation

- Use **`CLLocationUpdate.liveUpdates(.fitness)` together with a `CLBackgroundActivitySession`**, held strongly for the whole Run, from Start to Stop including user Pauses.
- Ask only for **When In Use** permission, plus temporary full accuracy at Run start.
- Turn on the `location` background mode and accept the blue indicator.
- On launch, if a Run was in progress, immediately recreate the session and restart `liveUpdates` so a relaunched app resumes the same Run.
- Treat user Pause as a flag on incoming points, not as stopping the stream. Let Core Location's own stationary pause save battery.
- Filter fixes with a pure, unit-tested accept/reject function based on accuracy, staleness, and implied speed.
- Wrap the stream in a `LocationSource` protocol so tests use replayed points or GPX files. Verify background behaviour on a real device.
- Keep a `CLLocationManager` fallback in mind (`.fitness`, `kCLLocationAccuracyBest`, no distance filter, `pausesLocationUpdatesAutomatically = false`, `allowsBackgroundLocationUpdates = true`) only if on-device testing shows `liveUpdates` is too coarse. We can't tune `liveUpdates` accuracy.

## Sources

- [WWDC23-10180] WWDC23 "Discover streamlined location updates": https://developer.apple.com/videos/play/wwdc2023/10180/
- [WWDC24-10212] WWDC24 "What's new in location authorization": https://developer.apple.com/videos/play/wwdc2024/10212/
- [WWDC25-322] WWDC25 "Track workouts with HealthKit on iOS and iPadOS": https://developer.apple.com/videos/play/wwdc2025/322/
- [doc:handling-bg] Handling location updates in the background: https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background
- [doc:CLBackgroundActivitySession]: https://developer.apple.com/documentation/corelocation/clbackgroundactivitysession-3mzv3
- [doc:CLLocationUpdate]: https://developer.apple.com/documentation/corelocation/cllocationupdate
- [doc:isStationary]: https://developer.apple.com/documentation/corelocation/cllocationupdate/isstationary
- [doc:LiveConfiguration]: https://developer.apple.com/documentation/corelocation/cllocationupdate/liveconfiguration
- [doc:LiveConfiguration.fitness]: https://developer.apple.com/documentation/corelocation/cllocationupdate/liveconfiguration/fitness
- [doc:sample] Adopting live updates in Core Location: https://developer.apple.com/documentation/corelocation/adopting-live-updates-in-core-location
- [doc:allowsBackgroundLocationUpdates]: https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates
- [doc:showsBackgroundLocationIndicator]: https://developer.apple.com/documentation/corelocation/cllocationmanager/showsbackgroundlocationindicator
- [doc:pausesLocationUpdatesAutomatically]: https://developer.apple.com/documentation/corelocation/cllocationmanager/pauseslocationupdatesautomatically
- [doc:distanceFilter]: https://developer.apple.com/documentation/corelocation/cllocationmanager/distancefilter
- [doc:CLActivityType.fitness]: https://developer.apple.com/documentation/corelocation/clactivitytype/fitness
- [doc:BestForNavigation]: https://developer.apple.com/documentation/corelocation/kcllocationaccuracybestfornavigation
- [doc:horizontalAccuracy]: https://developer.apple.com/documentation/corelocation/cllocation/horizontalaccuracy
- [doc:sourceInformation]: https://developer.apple.com/documentation/corelocation/cllocation/sourceinformation
- [doc:isSimulatedBySoftware]: https://developer.apple.com/documentation/corelocation/cllocationsourceinformation/issimulatedbysoftware
- [doc:simulating-location-in-tests]: https://developer.apple.com/documentation/xcode/simulating-location-in-tests
- [Xcode help: simulate location in scheme]: https://help.apple.com/xcode/mac/current/en.lproj/dev8dbd2f820.html
- [forum:810433] Apple engineer on stopping/resuming liveUpdates and CLBackgroundActivitySession: https://developer.apple.com/forums/thread/810433
- [forum:726945] Apple engineer on iOS 16.4 background requirements for CLLocationManager: https://developer.apple.com/forums/thread/726945?page=2
- [forum:731399] Granularity/accuracy of liveUpdates (developer reports; no Apple answer): https://developer.apple.com/forums/thread/731399
- [forum:788647] Live Activity alone not keeping updates alive (developer report; no Apple answer): https://developer.apple.com/forums/thread/788647
