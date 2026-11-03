import PaceprintCore
import SwiftUI

/// Where a Run happened: its Place context above its Place name, over its date and time.
/// Until the place is found, the name is the time of day, e.g. MORNING RUN, with no context.
struct RunHeadline: View {
    let run: Run
    let font: Font
    /// Lines the Place name may take before it shrinks to fit.
    var nameLines = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !run.placeContext.isEmpty {
                Text(run.placeContextShown)
                    .paceprintLabel()
                    .lineLimit(1)
            }
            Text(run.placeNameShown)
                .font(font)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(nameLines)
                .minimumScaleFactor(0.6)
                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            Text(run.startDate.formatted(.dateTime.day().month(.abbreviated).year().hour().minute()).uppercased())
                .paceprintLabel()
        }
    }
}

/// A Run's headline numbers, 2×2: distance and TIME in `large`, AVG PACE and CAL (EST) in `small`.
struct RunMetrics: View {
    let run: Run
    let large: Theme.Typography.MetricSize
    let small: Theme.Typography.MetricSize
    @AppStorage(SettingsKey.units) private var units = DistanceUnit.kilometers

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 22) {
            GridRow {
                Metric(label: units.abbreviation, value: RunFormat.distance(run.distance, in: units), size: large, alignment: .leading)
                Metric(label: "TIME", value: RunFormat.time(run.movingTime), size: large, alignment: .leading)
            }
            GridRow {
                Metric(label: "AVG PACE /\(units.abbreviation)", value: RunFormat.pace(run.averagePace, per: units), size: small, alignment: .leading)
                Metric(label: "CAL (EST)", value: RunFormat.calories(run.activeCalories), size: small, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
