import SwiftUI

/// Summary: a Run's Route in Pace colors on a dark map, its date where the Place name will go,
/// and its headline numbers. Opens after Stop.
struct SummaryView: View {
    let run: Run
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Room below the Route for the place name and metrics.
            RouteMap(run: run, roomBelow: 1)
                .ignoresSafeArea()

            LinearGradient(
                stops: [
                    .init(color: Theme.Colors.photoTop, location: 0),
                    .init(color: Theme.Colors.photoMid, location: 0.3),
                    .init(color: Theme.Colors.photoMid, location: 0.6),
                    .init(color: Theme.Colors.photoBottom, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 28) {
                topBar
                Spacer()
                RunHeadline(run: run, size: Theme.Typography.placeName)
                RunMetrics(run: run, large: .xl, small: .lg)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 32)
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            CircleButton(systemImage: "xmark", label: "Close") { dismiss() }
            Spacer()
            Text("PACEPRINT")
                .font(Theme.Typography.label)
                .tracking(Theme.Typography.wordmarkTracking)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            // Keeps the wordmark centred until Share takes this place.
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.top, 8)
    }
}
