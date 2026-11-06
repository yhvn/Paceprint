import os
import PaceprintCore
import SwiftData
import SwiftUI

/// History: all-time totals, then every saved Run by the month it started, newest first.
/// A Run still being recorded isn't one.
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(RunHealthSync.self) private var healthSync
    @Query(filter: Run.finished, sort: \Run.startDate, order: .reverse) private var runs: [Run]
    @State private var openRun: Run?
    @State private var runToDelete: Run?
    @AppStorage(SettingsKey.units) private var units = DistanceUnit.kilometers
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        } message: { run in
            Text(run.healthWorkoutID == nil ? "It can't be brought back." : "It will also be removed from Apple Health.")
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
                        .paceprintLabel()
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// All-time TOTAL, RUNS and AVG PACE; stacked at accessibility text sizes, where three across won't fit.
    private var totals: some View {
        let totals = RunTotals(runs)
        let layout = AnyLayout.across(dynamicTypeSize, spacing: 12, stackedAlignment: .center)
        return layout {
            TotalTile(label: "TOTAL", value: RunFormat.distance(totals.distance, in: units), unit: units.abbreviation)
            TotalTile(label: "RUNS", value: "\(totals.runCount)", unit: nil)
            TotalTile(label: "AVG PACE", value: RunFormat.pace(totals.averagePace, per: units), unit: "/\(units.abbreviation)")
        }
    }

    /// Deletes `run` for good, with its photo and its Apple Health workout; every total follows at once,
    /// as they're read from the store.
    private func delete(_ run: Run) {
        Task {
            do {
                try await healthSync.delete(run)
            } catch {
                logger.error("Couldn't delete the Run: \(error)")
            }
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
                .paceprintLabel()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(Theme.Typography.metric(.sm))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let unit {
                    Text(unit)
                        .paceprintLabel(tracking: 0)
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

/// One Run in History over its photo: its date over where the Place name will go, then its numbers, with
/// its Route down the right. The Route is drawn from its thumbnail: History never decodes one (ADR 0001).
private struct HistoryCard: View {
    let run: Run
    @AppStorage(SettingsKey.units) private var units = DistanceUnit.kilometers
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // e.g. "MAY 12 · DUMBO": the date, then the first name of the Place context, if any.
            Text(([RunFormat.cardDate(run.startDate)] + run.placeContext.prefix(1).map { $0.uppercased() }).joined(separator: " · "))
                .paceprintLabel()
                .lineLimit(1)
            Text(run.placeNameShown)
                // 22 pt at the default size, scaling with the labels around it.
                .font(.system(.title2, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.top, 4)
            Spacer(minLength: 12)
            // Stacked at accessibility text sizes, where three across wouldn't fit.
            let layout = AnyLayout.across(dynamicTypeSize, spacing: 18, alignment: .firstTextBaseline, stackedSpacing: 10)
            layout {
                CardMetric(label: units.abbreviation, value: RunFormat.distance(run.distance, in: units))
                CardMetric(label: "TIME", value: RunFormat.time(run.movingTime))
                CardMetric(label: "PACE", value: RunFormat.pace(run.averagePace, per: units))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 132)
        .background { photo }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    /// The Run's photo, else the plain card, with the Route in a 130 pt band down the right.
    private var photo: some View {
        ZStack(alignment: .trailing) {
            Theme.Colors.sheetDark
            if let fileName = run.photoFileName {
                // A card is ~360 × 132 pt; this covers its width at 3× for most photos.
                RunPhoto(fileName: fileName, filter: run.photoFilter, maxPixelSize: 1200) { Color.clear }
                ScrimGradient(stops: .historyCard, startPoint: .leading, endPoint: .trailing, scrim: run.scrim)
            }
            RouteThumbnailView(run: run)
                .frame(width: 130)
                .opacity(0.95)
        }
    }
}

private struct CardMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .paceprintLabel()
            Text(value)
                .font(.system(size: 20, weight: .heavy).monospacedDigit())
                .foregroundStyle(Theme.Colors.textPrimary)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: Run.self, inMemory: true)
    .environment(RunHealthSync.preview)
    .preferredColorScheme(.dark)
}
#endif
