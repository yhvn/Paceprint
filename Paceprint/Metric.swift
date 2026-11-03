import SwiftUI

/// One headline number with its label above, e.g. TIME over "24:31".
struct Metric: View {
    let label: String
    let value: String
    let size: Theme.Typography.MetricSize
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(label)
                .font(Theme.Typography.label)
                .tracking(Theme.Typography.labelTracking)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(value)
                .font(Theme.Typography.metric(size))
                .tracking(Theme.Typography.metricTracking(size))
                .foregroundStyle(Theme.Colors.textPrimary)
                // A long value, e.g. "1:42:05", shrinks rather than wraps into what's below.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}
