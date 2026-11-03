import SwiftUI

/// A glass card telling the runner something, with a row of buttons: e.g. location access lost on Active
/// run, or the one-time Apple Health card on Summary.
struct NoticeCard<Buttons: View>: View {
    let title: String
    let message: String
    @ViewBuilder var buttons: Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
            HStack(spacing: 20) {
                buttons
            }
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.Colors.glass, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder))
    }
}
