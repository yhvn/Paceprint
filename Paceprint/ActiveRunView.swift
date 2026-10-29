import SwiftUI

/// Active run: the live distance and TIME, and Stop.
struct ActiveRunView: View {
    @Environment(RunRecorder.self) private var recorder

    var body: some View {
        ZStack {
            Theme.Colors.inkBlack.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Metric(label: "KM", value: RunFormat.kilometres(recorder.distance), size: .hero)

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = recorder.startDate.map { context.date.timeIntervalSince($0) } ?? 0
                    Metric(label: "TIME", value: RunFormat.time(elapsed), size: .lg)
                }

                Spacer()

                Button {
                    recorder.stop()
                } label: {
                    Text("STOP")
                        .font(Theme.Typography.metric(.sm))
                        .tracking(Theme.Typography.labelTracking)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 120, height: 120)
                        .background(Theme.Colors.liveRed, in: Circle())
                }
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct Metric: View {
    let label: String
    let value: String
    let size: Theme.Typography.MetricSize

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(Theme.Typography.label)
                .tracking(Theme.Typography.labelTracking)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(value)
                .font(Theme.Typography.metric(size))
                .tracking(Theme.Typography.metricTracking(size))
                .foregroundStyle(Theme.Colors.textPrimary)
        }
    }
}

#Preview {
    ActiveRunView()
        .environment(RunRecorder.preview)
}
