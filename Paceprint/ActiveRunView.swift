import SwiftUI

/// Active run: the live distance, TIME and Paces, Pause/Resume and Stop.
struct ActiveRunView: View {
    @Environment(RunRecorder.self) private var recorder

    var body: some View {
        ZStack {
            Theme.Colors.inkBlack.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Metric(label: "KM", value: RunFormat.kilometres(recorder.distance), size: .hero)

                // Time-based values are read from the recorder's clock; redraw them every second.
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    VStack(spacing: 32) {
                        Metric(label: "TIME", value: RunFormat.time(recorder.movingTime), size: .lg)
                        HStack(spacing: 48) {
                            Metric(label: "PACE", value: RunFormat.pace(recorder.currentPace), size: .md)
                            Metric(label: "AVG PACE", value: RunFormat.pace(recorder.averagePace), size: .md)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 32) {
                    if recorder.isPaused {
                        RoundButton(title: "RESUME", color: Theme.Colors.actionWhite, textColor: Theme.Colors.textOnLight) {
                            recorder.resume()
                        }
                    } else {
                        RoundButton(title: "PAUSE", color: Theme.Colors.pauseAmber, textColor: Theme.Colors.textOnLight) {
                            recorder.pause()
                        }
                    }
                    RoundButton(title: "STOP", color: Theme.Colors.liveRed, textColor: Theme.Colors.textPrimary) {
                        recorder.stop()
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct RoundButton: View {
    let title: String
    let color: Color
    let textColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.label)
                .tracking(Theme.Typography.labelTracking)
                .foregroundStyle(textColor)
                .frame(width: 104, height: 104)
                .background(color, in: Circle())
        }
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
