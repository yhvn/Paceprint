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
    private let container: ModelContainer
    @State private var recorder: RunRecorder

    init() {
        do {
            container = try ModelContainer(for: Run.self)
        } catch {
            fatalError("Couldn't open the Run store: \(error)")
        }
        _recorder = State(initialValue: RunRecorder(source: LiveLocationSource(), modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(recorder)
        }
        .modelContainer(container)
    }
}
