//
//  ContentView.swift
//  Paceprint
//
//  Created by tungdevpro on 28/10/26.
//

import SwiftUI

/// Placeholder until Home lands in "Record a first Run, end to end".
struct ContentView: View {
    var body: some View {
        ZStack {
            Theme.Colors.inkBlack.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("PACEPRINT")
                    .font(Theme.Typography.label)
                    .tracking(Theme.Typography.wordmarkTracking)
                    .foregroundStyle(Theme.Colors.textSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("KM")
                        .font(Theme.Typography.label)
                        .tracking(Theme.Typography.labelTracking)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("0.00")
                        .font(Theme.Typography.metric(.xl))
                        .tracking(Theme.Typography.metricTracking(.xl))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }

                HStack(spacing: 0) {
                    Theme.Colors.paceFast
                    Theme.Colors.paceMid
                    Theme.Colors.paceSlow
                }
                .frame(width: 120, height: 6)
                .clipShape(Capsule())
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
