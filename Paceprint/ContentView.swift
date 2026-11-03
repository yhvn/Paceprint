//
//  ContentView.swift
//  Paceprint
//
//  Created by tungdevpro on 28/10/26.
//

import PaceprintCore
import SwiftData
import SwiftUI

/// Home: start a Run, see this week's distance and the latest Run, or look back through History.
struct ContentView: View {
    @Environment(RunRecorder.self) private var recorder
    @Environment(\.openURL) private var openURL
    @Query(filter: Run.finished, sort: \Run.startDate, order: .reverse) private var runs: [Run]
    @State private var openRun: Run?
    @AppStorage(SettingsKey.units) private var units = DistanceUnit.kilometers
    @AppStorage(SettingsKey.name) private var name = ""

    var body: some View {
        NavigationStack {
            ZStack {
                background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    Text("PACEPRINT")
                        .font(Theme.Typography.label)
                        .tracking(Theme.Typography.wordmarkTracking)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.bottom, 20)
                    startButton
                    Spacer()
                    // Re-read the clock every minute, so the week and dates roll over while the app is open.
                    TimelineView(.everyMinute) { context in
                        VStack(spacing: 0) {
                            thisWeek(now: context.date)
                                .padding(.horizontal, 4)
                                .padding(.bottom, 14)
                            latestRun
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $openRun) { RunDetailView(run: $0) }
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
        // The Run in progress, then its Summary once stopped and saved.
        .fullScreenCover(isPresented: Binding(
            get: { recorder.isRecording || recorder.stoppedRun != nil },
            set: { if !$0 { recorder.stoppedRun = nil } }
        )) {
            if recorder.isRecording {
                ActiveRunView()
            } else if let run = recorder.stoppedRun {
                SummaryView(run: run)
            }
        }
        .preferredColorScheme(.dark)
    }

    /// The latest Run's photo, else the bundled one, under the design's Home gradient.
    @ViewBuilder
    private var background: some View {
        if let run = runs.first, let fileName = run.photoFileName {
            RunPhoto(fileName: fileName, filter: run.photoFilter) { Theme.Colors.inkBlack }
                .overlay { ScrimGradient(stops: .home, scrim: run.scrim) }
        } else {
            Color.clear
                .overlay {
                    Image(.defaultHomePhoto)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .accessibilityHidden(true)
                .overlay { ScrimGradient(stops: .home, scrim: .bundledPhoto) }
        }
    }

    private var topBar: some View {
        HStack {
            greeting
            Spacer()
            NavigationLink {
                HistoryView()
            } label: {
                CircleIcon(systemImage: "clock.arrow.circlepath")
            }
            .accessibilityLabel("History")
            NavigationLink {
                SettingsView()
            } label: {
                CircleIcon(systemImage: "gearshape")
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    /// "GOOD MORNING" over the runner's name, as in the design; just "Good morning." without one.
    @ViewBuilder
    private var greeting: some View {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            Text("Good morning.")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Theme.Colors.textPrimary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("GOOD MORNING")
                    .font(Theme.Typography.label)
                    .tracking(Theme.Typography.labelTracking)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text("\(name).")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var startButton: some View {
        Button {
            Task { await recorder.start() }
        } label: {
            VStack(spacing: 4) {
                Text("TAP TO")
                    .font(Theme.Typography.label)
                    .tracking(Theme.Typography.wordmarkTracking * 0.75)
                    .foregroundStyle(Color.black.opacity(0.5))
                Text("START")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(Theme.Colors.textOnLight)
                Text("RUN")
                    .font(Theme.Typography.label)
                    .tracking(Theme.Typography.labelTracking)
                    .foregroundStyle(Color.black.opacity(0.45))
            }
            .frame(width: 168, height: 168)
            .background(Theme.Colors.actionWhite, in: Circle())
            .shadow(color: .white.opacity(0.35), radius: 30, y: 12)
            .background(Circle().fill(Color.white.opacity(0.08)).padding(-12))
        }
        .accessibilityLabel("Start run")
    }

    /// Distance and Runs started this calendar week.
    private func thisWeek(now: Date) -> some View {
        let week = RunGrouping.startedThisWeek(runs, startedAt: \.startDate, now: now, calendar: .current)
        let totals = RunTotals(week)
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                weekLabel("THIS WEEK")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(RunFormat.distance(totals.distance, in: units))
                        .font(.system(size: 28, weight: .heavy).monospacedDigit())
                        .foregroundStyle(Theme.Colors.textPrimary)
                    weekLabel(units.abbreviation)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                weekLabel("RUNS")
                Text("\(totals.runCount)")
                    .font(.system(size: 28, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func weekLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.label)
            .tracking(Theme.Typography.labelTracking)
            .foregroundStyle(Theme.Colors.textSecondary)
    }

    @ViewBuilder
    private var latestRun: some View {
        if let run = runs.first {
            Button {
                openRun = run
            } label: {
                LatestRunCard(run: run)
            }
            .buttonStyle(.plain)
        } else {
            NoRunsYet(message: "Tap Run to record your first one.")
                .frame(height: 96)
                .background(Theme.Colors.sheetDark, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

/// The most recent Run on Home: its date over where the Place name will go, then its numbers.
/// No Route: Home never decodes one (ADR 0001).
private struct LatestRunCard: View {
    let run: Run
    @AppStorage(SettingsKey.units) private var units = DistanceUnit.kilometers

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LAST RUN · \(RunFormat.cardDate(run.startDate))")
                .font(Theme.Typography.label)
                .tracking(Theme.Typography.labelTracking)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(run.placeNameShown)
                .font(.system(size: 17, weight: .bold))
                .lineLimit(1)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.top, 4)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text("\(RunFormat.distance(run.distance, in: units)) \(units.abbreviation)")
                Text(RunFormat.time(run.movingTime))
                Text("\(RunFormat.pace(run.averagePace, per: units)) /\(units.abbreviation)")
            }
            .font(.system(size: 16, weight: .heavy).monospacedDigit())
            .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 96)
        .background(LinearGradient(colors: [Theme.Colors.sheetMid, Theme.Colors.sheetDark], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
        .environment(RunRecorder.preview)
        .environment(RunHealthSync.preview)
        .modelContainer(for: Run.self, inMemory: true)
}
