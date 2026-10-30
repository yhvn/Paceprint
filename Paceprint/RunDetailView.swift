import Charts
import PaceprintCore
import SwiftUI

/// Run detail: a Run picked from History, with its Route, headline numbers, pace chart and Splits.
struct RunDetailView: View {
    let run: Run
    @Environment(\.dismiss) private var dismiss
    /// Cut from the Route once the screen appears, so a change of units re-cuts every Run.
    @State private var splits: [Split] = []

    /// Kilometres until Settings lets the runner choose.
    private let unit = DistanceUnit.kilometers
    private let palette = RoutePalette.selected

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                routeStrip
                VStack(alignment: .leading, spacing: 0) {
                    RunHeadline(run: run, size: .system(size: 36, weight: .heavy))
                    RunMetrics(run: run, large: .lg, small: .md)
                        .padding(.top, 28)
                    if !wholeSplits.isEmpty {
                        paceChart
                            .padding(.top, 36)
                    }
                    if !splits.isEmpty {
                        splitsTable
                            .padding(.top, 28)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 230)
                .padding(.bottom, 30)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .top) { topBar }
        .background(Theme.Colors.inkBlack)
        .preferredColorScheme(.dark)
        .task {
            splits = (try? run.resumedTracker().splits(per: unit)) ?? []
        }
    }

    private var routeStrip: some View {
        RouteMap(run: run)
            .allowsHitTesting(false)
            .frame(height: 360)
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: Theme.Colors.photoTop, location: 0),
                        .init(color: Theme.Colors.photoMid, location: 0.4),
                        .init(color: Theme.Colors.inkBlack, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }

    private var topBar: some View {
        HStack {
            CircleButton(systemImage: "chevron.left", label: "Back") { dismiss() }
            Spacer()
            Text("RUN DETAIL")
                .font(Theme.Typography.label)
                .tracking(Theme.Typography.wordmarkTracking)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            // Keeps the title centred until Share takes this place.
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: Pace chart

    /// The Partial split is left out of the chart and of how bars are scaled.
    private var wholeSplits: [Split] {
        splits.filter { !$0.isPartial }
    }

    private func seconds(_ split: Split) -> Double {
        split.pace.seconds(per: unit)
    }

    /// The slowest and fastest whole Split, in seconds per unit; never a range of zero.
    private var paceRange: ClosedRange<Double> {
        let paces = wholeSplits.map(seconds)
        guard let fastest = paces.min(), let slowest = paces.max() else { return 0...1 }
        return fastest == slowest ? fastest - 10...slowest + 10 : fastest...slowest
    }

    private func color(_ split: Split) -> Color {
        palette.color(for: PaceColor(split.pace, comparedWith: run.averagePace))
    }

    private var paceChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                label("PACE BY KM")
                Spacer()
                label("\(RunFormat.pace(Pace(secondsPerMetre: paceRange.lowerBound / unit.metresPerUnit))) – \(RunFormat.pace(Pace(secondsPerMetre: paceRange.upperBound / unit.metresPerUnit)))")
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            // Slower Splits sit higher, as in the design.
            Chart(wholeSplits, id: \.number) { split in
                AreaMark(
                    x: .value("Split", split.number),
                    yStart: .value("Pace", paceRange.lowerBound),
                    yEnd: .value("Pace", seconds(split))
                )
                .foregroundStyle(LinearGradient(
                    colors: [palette.color(for: PaceColor(position: 0.25)).opacity(0.25), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                LineMark(x: .value("Split", split.number), y: .value("Pace", seconds(split)))
                    .foregroundStyle(palette.color(for: PaceColor(position: 0.25)))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                PointMark(x: .value("Split", split.number), y: .value("Pace", seconds(split)))
                    .symbol {
                        Circle()
                            .fill(.white)
                            .stroke(color(split), lineWidth: 1.5)
                            .frame(width: 6, height: 6)
                    }
                    .accessibilityLabel("KM \(split.number)")
                    .accessibilityValue(RunFormat.pace(split.pace))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: paceRange)
            .chartXScale(domain: 1...max(2, wholeSplits.count))
            .frame(height: 110)
        }
    }

    // MARK: Splits

    private var splitsTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("SPLITS")
            VStack(spacing: 0) {
                Divider().overlay(Theme.Colors.divider)
                ForEach(splits, id: \.number) { split in
                    splitRow(split)
                    Divider().overlay(Theme.Colors.divider.opacity(0.5))
                }
            }
        }
    }

    private func splitRow(_ split: Split) -> some View {
        HStack(spacing: 12) {
            Text(split.isPartial ? "\(RunFormat.kilometres(split.distance)) KM" : "KM \(split.number)")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 64, alignment: .leading)
            bar(split)
            Text(RunFormat.pace(split.pace))
                .font(.system(size: 15, weight: .heavy).monospacedDigit())
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 52, alignment: .trailing)
            // Moving time from Start to the end of this Split.
            Text(RunFormat.time(split.cumulativeMovingTime))
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    /// Longer for slower Splits; the Partial split's bar isn't Pace-colored.
    private func bar(_ split: Split) -> some View {
        let fraction = min(max((seconds(split) - paceRange.lowerBound) / (paceRange.upperBound - paceRange.lowerBound), 0), 1)
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06))
                Capsule()
                    .fill(split.isPartial ? Theme.Colors.textDisabled : color(split))
                    .frame(width: geometry.size.width * (0.2 + fraction * 0.75))
            }
        }
        .frame(height: 6)
    }

    private func label(_ text: String) -> Text {
        Text(text)
            .font(Theme.Typography.label)
            .tracking(Theme.Typography.labelTracking)
            .foregroundStyle(Theme.Colors.textSecondary)
    }
}
