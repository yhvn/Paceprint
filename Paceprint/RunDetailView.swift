import Charts
import PaceprintCore
import SwiftUI

/// Run detail: a Run picked from History, with its Route, headline numbers, pace chart and Splits.
struct RunDetailView: View {
    let run: Run
    @Environment(\.dismiss) private var dismiss
    /// Cut from the Route each time the screen appears, in the units shown.
    @State private var splits: [Split] = []
    @State private var isSharing = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @AppStorage(SettingsKey.units) private var unit = DistanceUnit.kilometers
    private let palette = RoutePalette.selected

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                routeStrip
                VStack(alignment: .leading, spacing: 0) {
                    // Over the Route strip, like the photo screens: up to XXXL. The chart and Splits below take every size.
                    Group {
                        RunHeadline(run: run, font: .system(size: 36, weight: .heavy))
                        RunMetrics(run: run, large: .lg, small: .md)
                            .padding(.top, 28)
                    }
                    .photoScreenTextSize()
                    // A chart needs two whole Splits to draw a line.
                    if wholeSplits.count >= 2 {
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
        .overlay(alignment: .top) { topBar.photoScreenTextSize() }
        .background(Theme.Colors.inkBlack)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isSharing) { ShareStorySheet(run: run) }
        // Re-cut whenever the units change.
        .task(id: unit) {
            splits = (try? run.resumedTracker().splits(per: unit, until: run.endDate)) ?? []
        }
    }

    /// The Run's photo with its Route drawn over it, else the dark map with its Route.
    private var routeStrip: some View {
        Group {
            if let fileName = run.photoFileName {
                RunPhoto(fileName: fileName, filter: run.photoFilter) { Theme.Colors.inkBlack }
            } else {
                RouteMap(run: run)
            }
        }
        .allowsHitTesting(false)
        .frame(height: 360)
        .overlay { ScrimGradient(stops: .detailStrip, scrim: run.scrim) }
        .overlay {
            if run.photoFileName != nil {
                // Clear of the top bar and the headline below.
                RouteOverlay(run: run)
                    .padding(.top, 120)
                    .padding(.bottom, 140)
                    .padding(.horizontal, 64)
            }
        }
    }

    private var topBar: some View {
        HStack {
            CircleButton(systemImage: "chevron.left", label: "Back") { dismiss() }
            Spacer()
            Text("RUN DETAIL")
                .paceprintLabel(tracking: Theme.Typography.wordmarkTracking)
            Spacer()
            CircleButton(systemImage: "square.and.arrow.up", label: "Share") { isSharing = true }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: Pace chart

    /// The Partial split is left out of the chart and of how bars are scaled.
    private var wholeSplits: [Split] {
        splits.filter { !$0.isPartial }
    }

    private func secondsPerUnit(_ split: Split) -> Double {
        split.pace.seconds(per: unit)
    }

    /// The fastest to the slowest whole Split, in seconds per unit; never a range of zero.
    private var paceRange: ClosedRange<Double> {
        let paces = wholeSplits.map(secondsPerUnit)
        guard let fastest = paces.min(), let slowest = paces.max() else { return 0...1 }
        return fastest == slowest ? fastest - 10...slowest + 10 : fastest...slowest
    }

    /// Where `split` sits from the fastest (0) to the slowest (1) whole Split; the Partial split is held inside.
    private func placeInRange(_ split: Split) -> Double {
        let fraction = (secondsPerUnit(split) - paceRange.lowerBound) / (paceRange.upperBound - paceRange.lowerBound)
        return min(max(fraction, 0), 1)
    }

    private func paceColor(_ split: Split) -> Color {
        palette.color(for: PaceColor(split.pace, comparedWith: run.averagePace))
    }

    /// The chart's line and fill: the palette a quarter of the way from fast to slow, as in the design.
    private var lineColor: Color {
        palette.color(for: PaceColor(position: 0.25))
    }

    private func formattedPace(secondsPerUnit seconds: Double) -> String {
        RunFormat.pace(Pace(secondsPerMetre: seconds / unit.metresPerUnit), per: unit)
    }

    private var paceChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                label("PACE BY \(unit.abbreviation)")
                Spacer()
                label("\(formattedPace(secondsPerUnit: paceRange.lowerBound)) – \(formattedPace(secondsPerUnit: paceRange.upperBound))")
            }
            // Slower Splits sit higher, as in the design.
            Chart(wholeSplits, id: \.number) { split in
                AreaMark(
                    x: .value("Split", split.number),
                    yStart: .value("Pace", paceRange.lowerBound),
                    yEnd: .value("Pace", secondsPerUnit(split))
                )
                .foregroundStyle(LinearGradient(colors: [lineColor.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Split", split.number), y: .value("Pace", secondsPerUnit(split)))
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                PointMark(x: .value("Split", split.number), y: .value("Pace", secondsPerUnit(split)))
                    .symbol {
                        Circle()
                            .fill(.white)
                            .stroke(paceColor(split), lineWidth: 1.5)
                            .frame(width: 6, height: 6)
                    }
                    .accessibilityLabel(SpokenFormat.splitName(split.number, units: unit))
                    .accessibilityValue(SpokenFormat.pace(split.pace, per: unit))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: paceRange)
            .chartXScale(domain: 1...wholeSplits.count)
            .frame(height: 110)
            .accessibilityLabel("Pace by \(unit.spokenName)")
            // An Audio Graph: VoiceOver can play the Splits' Paces as tones.
            .accessibilityChartDescriptor(PaceChartDescriptor(splits: wholeSplits, unit: unit, paceRange: paceRange))
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

    /// Across in one line; stacked at accessibility text sizes, where the columns wouldn't fit.
    @ViewBuilder
    private func splitRow(_ split: Split) -> some View {
        let name = Text(split.isPartial ? "\(RunFormat.distance(split.distance, in: unit)) \(unit.abbreviation)" : "\(unit.abbreviation) \(split.number)")
            .paceprintLabel(tracking: 1.6)
        // 15 pt at the default size, scaling: not one of the big metric numbers.
        let pace = Text(RunFormat.pace(split.pace, per: unit))
            .font(.system(.subheadline, weight: .heavy).monospacedDigit())
            .foregroundStyle(Theme.Colors.textPrimary)
        // Moving time from Start to the end of this Split.
        let total = Text(RunFormat.time(split.cumulativeMovingTime))
            .paceprintLabel(tracking: 0)
            .monospacedDigit()
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    name
                    bar(split)
                    HStack {
                        pace
                        Spacer()
                        total
                    }
                }
            } else {
                HStack(spacing: 12) {
                    name.frame(width: 64, alignment: .leading)
                    bar(split)
                    pace.frame(width: 52, alignment: .trailing)
                    total.frame(width: 56, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SpokenFormat.splitRow(split, units: unit))
    }

    /// Longer for slower Splits, colored by Pace.
    private func bar(_ split: Split) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06))
                Capsule()
                    .fill(paceColor(split))
                    .frame(width: geometry.size.width * (0.2 + placeInRange(split) * 0.75))
            }
        }
        .frame(height: 6)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .paceprintLabel()
    }
}

/// The pace chart as an Audio Graph: one point per whole Split, its Pace in seconds per unit.
private struct PaceChartDescriptor: AXChartDescriptorRepresentable {
    let splits: [Split]
    let unit: DistanceUnit
    /// As drawn: never a range of zero.
    let paceRange: ClosedRange<Double>

    func makeChartDescriptor() -> AXChartDescriptor {
        let paces = splits.map { $0.pace.seconds(per: unit) }
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: unit.spokenName.capitalized,
            categoryOrder: splits.map { SpokenFormat.splitName($0.number, units: unit) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Pace",
            range: paceRange,
            gridlinePositions: []
        ) { SpokenFormat.pace(Pace(secondsPerMetre: $0 / unit.metresPerUnit), per: unit) }
        let series = AXDataSeriesDescriptor(
            name: "Pace by \(unit.spokenName)",
            isContinuous: false,
            dataPoints: zip(splits, paces).map { split, pace in
                AXDataPoint(x: SpokenFormat.splitName(split.number, units: unit), y: pace)
            }
        )
        return AXChartDescriptor(
            title: "Pace by \(unit.spokenName)",
            summary: "Higher is slower.",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
