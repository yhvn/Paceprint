import PaceprintCore
import SwiftUI

/// Active run: the live distance, TIME and Paces, GPS and location access, Pause/Resume and Stop.
struct ActiveRunView: View {
    @Environment(RunRecorder.self) private var recorder
    @Environment(\.openURL) private var openURL
    @State private var isShowingAccessLost = false

    private static let accessLostTitle = "Location access was turned off"
    private static let accessLostMessage = "Your run is paused. Turn location back on in Settings to continue."

    var body: some View {
        ZStack {
            Theme.Colors.inkBlack.ignoresSafeArea()

            VStack(spacing: 40) {
                if recorder.isAccessLost {
                    accessLostBanner
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        GPSPill(status: recorder.gpsStatus)
                    }
                }

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
                        // Dimmed while location access is off; tapping it then says why it won't Resume.
                        RoundButton(title: "RESUME", color: Theme.Colors.actionWhite, textColor: Theme.Colors.textOnLight) {
                            if recorder.isAccessLost {
                                isShowingAccessLost = true
                            } else {
                                recorder.resume()
                            }
                        }
                        .opacity(recorder.isAccessLost ? 0.4 : 1)
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
        .alert(Self.accessLostTitle, isPresented: $isShowingAccessLost) {
            Button("Open Settings") { openURL(.appSettings) }
            Button("Stop run", role: .destructive) { recorder.stop() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(Self.accessLostMessage)
        }
        .preferredColorScheme(.dark)
    }

    private var accessLostBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Self.accessLostTitle)
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(Self.accessLostMessage)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
            HStack(spacing: 20) {
                Button("Open Settings") { openURL(.appSettings) }
                    .foregroundStyle(Theme.Colors.info)
                Button("Stop run") { recorder.stop() }
                    .foregroundStyle(Theme.Colors.error)
            }
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.Colors.glass, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

/// "Finding GPS…" until the first point is kept, "Weak GPS" when points stop coming; nothing otherwise.
private struct GPSPill: View {
    let status: GPSStatus

    var body: some View {
        let text: String? = switch status {
        case .finding: "Finding GPS…"
        case .weak: "Weak GPS"
        case .good: nil
        }
        Text(text ?? " ")
            .font(Theme.Typography.label)
            .tracking(Theme.Typography.labelTracking)
            .foregroundStyle(Theme.Colors.warning)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.Colors.glass, in: Capsule())
            // Keeps its space when hidden so the metrics don't jump.
            .opacity(text == nil ? 0 : 1)
            .accessibilityHidden(text == nil)
            .padding(.top, 8)
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
