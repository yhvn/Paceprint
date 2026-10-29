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
