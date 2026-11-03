import os
import PaceprintCore
import SwiftData
import SwiftUI

/// History: all-time totals, then every saved Run by the month it started, newest first.
/// A Run still being recorded isn't one.
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: Run.finished, sort: \Run.startDate, order: .reverse) private var runs: [Run]
    @State private var openRun: Run?
    @State private var runToDelete: Run?
    @AppStorage(SettingsKey.units) private var units = DistanceUnit.kilometers
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Paceprint", category: "History")

    var body: some View {
        Group {
            if runs.isEmpty {
                NoRunsYet(message: "Your runs will show up here after you finish one.")
            } else {
                list
            }
        }
        .background(Theme.Colors.inkBlack)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $openRun) { RunDetailView(run: $0) }
        .alert("Delete this run?", isPresented: Binding(get: { runToDelete != nil }, set: { if !$0 { runToDelete = nil } }), presenting: runToDelete) { run in
            Button("Delete", role: .destructive) { delete(run) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It can't be brought back.")
        }
    }

    private var list: some View {
        List {
            totals
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            ForEach(RunGrouping.byMonth(runs, startedAt: \.startDate, calendar: .current), id: \.start) { month in
                Section {
                    ForEach(month.runs) { run in
                        Button {
                            openRun = run
                        } label: {
                            HistoryCard(run: run)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .swipeActions {
                            // Not a destructive role: that removes the row before the runner confirms.
                            Button("Delete", systemImage: "trash") { runToDelete = run }
                                .tint(Theme.Colors.error)
                        }
                    }
                } header: {
                    Text(RunFormat.monthHeader(month.start))
                        .font(Theme.Typography.label)
                        .tracking(Theme.Typography.labelTracking)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// All-time TOTAL, RUNS and AVG PACE.
    private var totals: some View {
        let totals = RunTotals(runs)
        return HStack(spacing: 12) {
            TotalTile(label: "TOTAL", value: RunFormat.distance(totals.distance, in: units), unit: units.abbreviation)
            TotalTile(label: "RUNS", value: "\(totals.runCount)", unit: nil)
            TotalTile(label: "AVG PACE", value: RunFormat.pace(totals.averagePace, per: units), unit: "/\(units.abbreviation)")
        }
    }

    /// Deletes `run` for good, with its photo; every total follows at once, as they're read from the store.
    private func delete(_ run: Run) {
        do {
            try modelContext.deleteRun(run)
        } catch {
            logger.error("Couldn't delete the Run: \(error)")
        }
    }
}

private struct TotalTile: View {
    let label: String
    let value: String
    let unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.Typography.label)
                .tracking(Theme.Typography.labelTracking)
                .foregroundStyle(Theme.Colors.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(Theme.Typography.metric(.sm))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let unit {
                    Text(unit)
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }
}

/// One Run in History over its photo: its date over where the Place name will go, then its numbers.
/// No Route: History never decodes one (ADR 0001).
private struct HistoryCard: View {
    let run: Run
    @AppStorage(SettingsKey.units) private var units = DistanceUnit.kilometers

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // e.g. "MAY 12 · DUMBO": the date, then the first name of the Place context, if any.
            Text(([RunFormat.cardDate(run.startDate)] + run.placeContext.prefix(1).map { $0.uppercased() }).joined(separator: " · "))
                .font(Theme.Typography.label)
                .tracking(Theme.Typography.labelTracking)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)
            Text(run.placeNameShown)
                .font(.system(size: 22, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.top, 4)
            Spacer(minLength: 12)
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                CardMetric(label: units.abbreviation, value: RunFormat.distance(run.distance, in: units))
                CardMetric(label: "TIME", value: RunFormat.time(run.movingTime))
                CardMetric(label: "PACE", value: RunFormat.pace(run.averagePace, per: units))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 132)
        .background { photo }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    /// The Run's photo, else the plain card.
    private var photo: some View {
        ZStack {
            Theme.Colors.sheetDark
            if let fileName = run.photoFileName {
                // A card is ~360 × 132 pt; this covers its width at 3× for most photos.
                RunPhoto(fileName: fileName, filter: run.photoFilter, maxPixelSize: 1200) { Color.clear }
                ScrimGradient(stops: .historyCard, startPoint: .leading, endPoint: .trailing, scrim: run.scrim)
            }
        }
    }
}

private struct CardMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.Typography.label)
                .tracking(Theme.Typography.labelTracking)
                .foregroundStyle(Theme.Colors.textTertiary)
            Text(value)
                .font(.system(size: 20, weight: .heavy).monospacedDigit())
                .foregroundStyle(Theme.Colors.textPrimary)
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: Run.self, inMemory: true)
    .preferredColorScheme(.dark)
}
