import PaceprintCore
import SwiftUI

/// Active run: the live distance, TIME and Paces, GPS and location access, Pause/Resume and Stop.
struct ActiveRunView: View {
    @Environment(RunRecorder.self) private var recorder
    @Environment(\.openURL) private var openURL
    @State private var isShowingAccessLost = false
    @AppStorage(SettingsKey.units) private var units = DistanceUnit.kilometers

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

                // Time-based values are read from the recorder's clock; redraw them every second.
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    VStack(spacing: 40) {
                        Metric(label: units.abbreviation, value: RunFormat.distance(recorder.distance, in: units), size: .hero)
                        VStack(spacing: 32) {
                            Metric(label: "TIME", value: RunFormat.time(recorder.movingTime), size: .lg)
                            HStack(spacing: 48) {
                                Metric(label: "PACE", value: RunFormat.pace(recorder.currentPace, per: units), size: .md)
                                Metric(label: "AVG PACE", value: RunFormat.pace(recorder.averagePace, per: units), size: .md)
                            }
                        }
                    }
                    // One element, read when focused; never re-announced as the numbers change.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(SpokenFormat.activeRun(distance: recorder.distance, movingTime: recorder.movingTime, pace: recorder.currentPace, units: units))
                }

                Spacer()

                HStack(spacing: 32) {
                    if recorder.isPaused {
                        // Dimmed while location access is off; tapping it then says why it won't Resume.
                        RoundButton(title: "RESUME", label: "Resume run", color: Theme.Colors.actionWhite, textColor: Theme.Colors.textOnLight) {
                            if recorder.isAccessLost {
                                isShowingAccessLost = true
                            } else {
                                recorder.resume()
                            }
                        }
                        .opacity(recorder.isAccessLost ? 0.4 : 1)
                    } else {
                        RoundButton(title: "PAUSE", label: "Pause run", color: Theme.Colors.pauseAmber, textColor: Theme.Colors.textOnLight) {
                            recorder.pause()
                        }
                    }
                    RoundButton(title: "STOP", label: "Stop run", color: Theme.Colors.liveRed, textColor: Theme.Colors.textPrimary) {
                        recorder.stop()
                    }
                }
                .padding(.bottom, 24)
            }
        }
        // Grouped with the photo screens (#15): labels scale up to XXXL.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        // Said aloud only while VoiceOver is on.
        .onChange(of: completedSplits) { before, after in
            guard after > before, let split = recorder.splits(per: units).last(where: { !$0.isPartial }) else { return }
            VoiceOverAnnouncement.post(SpokenFormat.splitCompleted(split, units: units))
        }
        .onChange(of: recorder.isPaused) { _, isPaused in
            if !isPaused {
                VoiceOverAnnouncement.post("Resumed")
            } else if recorder.isAccessLost {
                VoiceOverAnnouncement.post("Paused. Location access was turned off.")
            } else {
                VoiceOverAnnouncement.post("Paused")
            }
        }
        .alert("Discard this run?", isPresented: Bindable(recorder).isAskingToDiscard) {
            Button("Discard", role: .destructive) { recorder.discard() }
            Button("Save") { recorder.save() }
            Button("Keep Running", role: .cancel) {}
        } message: {
            Text("It's under 0.1 km or 1 minute.")
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

    /// Whole Splits completed so far, in the units shown.
    private var completedSplits: Int {
        Int(recorder.distance / units.metresPerUnit)
    }

    private var accessLostBanner: some View {
        NoticeCard(title: Self.accessLostTitle, message: Self.accessLostMessage) {
            Button("Open Settings") { openURL(.appSettings) }
                .foregroundStyle(Theme.Colors.info)
            Button("Stop run") { recorder.stop() }
                .foregroundStyle(Theme.Colors.error)
        }
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
            .onChange(of: status == .weak) { _, isWeak in
                if isWeak {
                    VoiceOverAnnouncement.post("Weak GPS")
                }
            }
    }
}

private struct RoundButton: View {
    let title: String
    /// What VoiceOver says, e.g. "Pause run".
    let label: String
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
        .accessibilityLabel(label)
    }
}

#Preview {
    ActiveRunView()
        .environment(RunRecorder.preview)
}
