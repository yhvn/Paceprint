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
        }
        .modelContainer(appDelegate.container)
    }
}

/// Owns the store and the recorder, so a Run left unfinished can be picked up as soon as the app launches,
/// including when iOS relaunches it in the background to keep recording.
final class AppDelegate: NSObject, UIApplicationDelegate {
    let container: ModelContainer
    let recorder: RunRecorder

    override init() {
        do {
            container = try ModelContainer(for: Run.self)
        } catch {
            fatalError("Couldn't open the Run store: \(error)")
        }
        recorder = RunRecorder(source: LiveLocationSource(), modelContext: container.mainContext)
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // iOS relaunches the app with this key when it was killed while recording location in the background.
        recorder.recoverUnfinishedRun(relaunchedInBackground: launchOptions?[.location] != nil)
        return true
    }
}
