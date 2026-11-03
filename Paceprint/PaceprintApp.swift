//
//  PaceprintApp.swift
//  Paceprint
//
//  Created by tungdevpro on 28/10/26.
//

import SwiftData
import SwiftUI

@main
struct PaceprintApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appDelegate.recorder)
                .environment(appDelegate.healthSync)
        }
        .modelContainer(appDelegate.container)
    }
}

/// Owns the store and the recorder, so a Run left unfinished can be picked up as soon as the app launches,
/// including when iOS relaunches it in the background to keep recording.
final class AppDelegate: NSObject, UIApplicationDelegate {
    let container: ModelContainer
    let recorder: RunRecorder
    let healthSync: RunHealthSync
    private let placeNamer: RunPlaceNamer

    override init() {
        do {
            container = try ModelContainer(for: Run.self)
        } catch {
            fatalError("Couldn't open the Run store: \(error)")
        }
        placeNamer = RunPlaceNamer(lookup: GeocoderPlaceLookup(), modelContext: container.mainContext)
        healthSync = RunHealthSync(exporter: HealthKitExporter(), modelContext: container.mainContext)
        recorder = RunRecorder(
            source: LiveLocationSource(),
            modelContext: container.mainContext,
            placeNamer: placeNamer,
            healthSync: healthSync,
            bodyMass: { UserDefaults.standard.bodyMass }
        )
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // iOS relaunches the app with this key when it was killed while recording location in the background.
        recorder.recoverUnfinishedRun(relaunchedInBackground: launchOptions?[.location] != nil)
        // Route thumbnails for Runs saved before there were any.
        Task { @MainActor [container] in await Run.makeMissingThumbnails(in: container.mainContext) }
        // Places that couldn't be looked up before, e.g. offline after Stop, are tried again quietly.
        Task { [placeNamer] in await placeNamer.nameRunsAwaitingPlace() }
        // Health's latest body weight for CAL (EST), and Runs that couldn't be saved to Health before.
        Task { [healthSync] in
            await healthSync.refreshBodyMass()
            await healthSync.saveRunsAwaitingHealth()
        }
        return true
    }
}
