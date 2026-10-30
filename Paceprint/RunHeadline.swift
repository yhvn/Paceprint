import SwiftUI

/// Where the Place name will go: for now the Run's weekday, over its date and time.
struct RunHeadline: View {
    let run: Run
    let size: Font

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(run.startDate, format: .dateTime.weekday(.wide))
                .font(size)
                .foregroundStyle(Theme.Colors.textPrimary)
                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            Text(run.startDate.formatted(.dateTime.day().month(.abbreviated).year().hour().minute()).uppercased())
                .font(Theme.Typography.label)
                .tracking(Theme.Typography.labelTracking)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}

/// A Run's headline numbers, 2×2: distance and TIME in `large`, AVG PACE and CAL (EST) in `small`.
struct RunMetrics: View {
    let run: Run
    let large: Theme.Typography.MetricSize
    let small: Theme.Typography.MetricSize

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 22) {
            GridRow {
                Metric(label: "KM", value: RunFormat.kilometres(run.distance), size: large, alignment: .leading)
                Metric(label: "TIME", value: RunFormat.time(run.movingTime), size: large, alignment: .leading)
            }
            GridRow {
                Metric(label: "AVG PACE /KM", value: RunFormat.pace(run.averagePace), size: small, alignment: .leading)
                // Calories arrive with Settings, which asks for body weight.
                Metric(label: "CAL (EST)", value: "—", size: small, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
