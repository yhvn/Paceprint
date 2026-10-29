//
//  ContentView.swift
//  Paceprint
//
//  Created by tungdevpro on 28/10/26.
//

import SwiftUI

/// Home: start a Run, or look back through History.
struct ContentView: View {
    @Environment(RunRecorder.self) private var recorder
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.inkBlack.ignoresSafeArea()

                VStack {
                    Text("PACEPRINT")
                        .font(Theme.Typography.label)
                        .tracking(Theme.Typography.wordmarkTracking)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.top, 24)

                    Spacer()

                    Button {
                        Task { await recorder.start() }
                    } label: {
                        Text("START")
                            .font(Theme.Typography.metric(.sm))
                            .tracking(Theme.Typography.labelTracking)
                            .foregroundStyle(Theme.Colors.textOnLight)
                            .frame(width: 160, height: 160)
                            .background(Theme.Colors.actionWhite, in: Circle())
                    }

                    Spacer()

                    NavigationLink("History") {
                        HistoryView()
                    }
                    .font(Theme.Typography.label)
                    .tracking(Theme.Typography.labelTracking)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.bottom, 24)
                }
            }
        }
        .alert(
            recorder.startProblem?.title ?? "",
            isPresented: Binding(get: { recorder.startProblem != nil }, set: { if !$0 { recorder.startProblem = nil } }),
            presenting: recorder.startProblem
        ) { problem in
            if problem.offersSettings {
                Button("Open Settings") { openURL(.appSettings) }
            }
            Button(problem.dismissTitle, role: .cancel) {}
        } message: { problem in
            Text(problem.message)
        }
        .fullScreenCover(isPresented: .constant(recorder.isRecording)) {
            ActiveRunView()
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environment(RunRecorder.preview)
}
