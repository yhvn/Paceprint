import PaceprintCore
import SwiftUI

/// Active run: the live map, the live distance, TIME and Paces, GPS and location access, Pause/Resume
/// and Stop.
struct ActiveRunView: View {
    @Environment(RunRecorder.self) private var recorder
    @Environment(\.openURL) private var openURL
    @State private var isShowingAccessLost = false
    @AppStorage(SettingsKey.units) private var units = DistanceUnit.kilometers

    private static let accessLostTitle = "Location access was turned off"
    private static let accessLostMessage = "Your run is paused. Turn location back on in Settings to continue."

    var body: some View {
        ZStack {
            // The map behind everything, the runner centred above the panel at the bottom.
            LiveRouteMap(roomBelow: Self.panelHeight)

            VStack(spacing: 0) {
                if recorder.isAccessLost {
                    accessLostBanner
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        GPSPill(status: recorder.gpsStatus)
                    }
                }

                Spacer()

                panel
            }
        }
        // Grouped with the photo screens (#15): labels scale up to XXXL.
        .photoScreenTextSize()
        // Said aloud only while VoiceOver is on.
        .onChange(of: wholeSplits.count) { before, after in
            // Every Split completed since the last update, usually one.
            for split in wholeSplits.dropFirst(before) where after > before {
                VoiceOverAnnouncement.post(SpokenFormat.splitCompleted(split, units: units))
            }
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

    /// About how tall the panel is at the default text size: the map keeps this much clear below the runner.
    private static let panelHeight: CGFloat = 400

    /// The metrics and the controls at the bottom, over a gradient so they read on the map.
    private var panel: some View {
        VStack(spacing: 28) {
            // Time-based values are read from the recorder's clock; redraw them every second.
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                VStack(spacing: 24) {
                    Metric(label: units.abbreviation, value: RunFormat.distance(recorder.distance, in: units), size: .hero)
                    VStack(spacing: 20) {
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

            HStack(spacing: 48) {
                if recorder.isPaused {
                    // Dimmed while location access is off; tapping it then says why it won't Resume.
                    RoundButton(systemImage: "play.fill", label: "Resume run", iconColor: Theme.Colors.textPrimary) {
                        if recorder.isAccessLost {
                            isShowingAccessLost = true
                        } else {
                            recorder.resume()
                        }
                    }
                    .opacity(recorder.isAccessLost ? 0.4 : 1)
                } else {
                    RoundButton(systemImage: "pause.fill", label: "Pause run", iconColor: Theme.Colors.pauseAmber) {
                        recorder.pause()
                    }
                }
                RoundButton(systemImage: "stop.fill", label: "Stop run", iconColor: Theme.Colors.liveRed) {
                    recorder.stop()
                }
            }
            .padding(.bottom, 24)
        }
        .padding(.top, 56)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(
                stops: [
                    .init(color: Theme.Colors.inkBlack.opacity(0), location: 0),
                    .init(color: Theme.Colors.inkBlack.opacity(0.78), location: 0.3),
                    .init(color: Theme.Colors.inkBlack.opacity(0.96), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    /// Whole Splits completed so far, in the units shown; cut by PaceprintCore, as Run detail cuts them.
    private var wholeSplits: [Split] {
        recorder.wholeSplits(per: units)
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
    /// "Weak GPS" is said at most this often, so a patchy signal doesn't keep repeating it.
    private static let weakAnnouncementInterval: TimeInterval = 60
    @State private var lastWeakAnnouncement: Date?

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
                guard isWeak, lastWeakAnnouncement.map({ Date.now.timeIntervalSince($0) >= Self.weakAnnouncementInterval }) ?? true else { return }
                lastWeakAnnouncement = .now
                VoiceOverAnnouncement.post("Weak GPS")
            }
    }
}

/// Pause, Resume or Stop: a glass circle like Home's History and Settings, larger, its icon in the
/// action's color.
private struct RoundButton: View {
    let systemImage: String
    /// What VoiceOver says, e.g. "Pause run".
    let label: String
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleIcon(systemImage: systemImage, diameter: 80, iconColor: iconColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#if DEBUG
#Preview {
    ActiveRunView()
        .environment(RunRecorder.preview)
}
#endif
