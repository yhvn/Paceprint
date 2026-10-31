import SwiftUI

/// The empty state on Home and History before any Run is saved.
struct NoRunsYet: View {
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Text("No runs yet")
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
