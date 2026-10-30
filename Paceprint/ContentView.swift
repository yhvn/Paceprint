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

    var body: some View {
        NavigationStack {
            ZStack {
                // Until Runs have photos, a plain dark background.
                LinearGradient(colors: [Theme.Colors.sheetMid, Theme.Colors.inkBlack], startPoint: .top, endPoint: .bottom)
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

    private var topBar: some View {
        HStack {
            // The runner's name joins the greeting once Settings asks for it.
            Text("Good morning.")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            NavigationLink {
                HistoryView()
            } label: {
                CircleIcon(systemImage: "clock.arrow.circlepath")
            }
            .accessibilityLabel("History")
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
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
        let totals = RunTotals(week, distance: \.distance, movingTime: \.movingTime)
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                weekLabel("THIS WEEK")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(RunFormat.kilometres(totals.distance))
                        .font(.system(size: 28, weight: .heavy).monospacedDigit())
                        .foregroundStyle(Theme.Colors.textPrimary)
                    weekLabel("KM")
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

/// The most recent Run on Home: its Route, date, title and numbers.
private struct LatestRunCard: View {
    let run: Run

    var body: some View {
        HStack(spacing: 0) {
            RouteThumbnail(run: run, lineWidth: 2)
                .frame(width: 96)
                .background(Theme.Colors.mapIndigo)
            VStack(alignment: .leading, spacing: 0) {
                Text("LAST RUN · \(RunFormat.cardDate(run.startDate))")
                    .font(Theme.Typography.label)
                    .tracking(Theme.Typography.labelTracking)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(run.startDate, format: .dateTime.weekday(.wide))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.top, 4)
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text("\(RunFormat.kilometres(run.distance)) KM")
                    Text(RunFormat.time(run.movingTime))
                    Text("\(RunFormat.pace(run.averagePace)) /KM")
                }
                .font(.system(size: 16, weight: .heavy).monospacedDigit())
                .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
        .modelContainer(for: Run.self, inMemory: true)
}
