import os
import PaceprintCore
import SwiftData
import SwiftUI

/// Share: the exact Story card that will be sent, the filter strip to change its look, and Share,
/// which hands the card to the system share sheet.
struct ShareStorySheet: View {
    let run: Run
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var route: RouteDrawing?
    /// The card as it will be sent; nil while it's being drawn.
    @State private var card: UIImage?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Paceprint", category: "Share")

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                preview
                if run.photoFileName != nil {
                    FilterStrip(selection: Binding(get: { run.photoFilter }, set: { choose($0) }))
                        .padding(.horizontal, 14)
                }
                shareButton
                    .padding(.horizontal, 22)
            }
            .padding(.vertical, 16)
            .background(Theme.Colors.inkBlack)
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        // Drawn again whenever the filter changes.
        .task(id: run.photoFilter) {
            if route == nil {
                route = RouteDrawing(run, palette: .selected)
            }
            let background = await StoryCardBackground.load(for: run, route: route)
            card = StoryCard(run: run, background: background, route: route).rendered()
        }
    }

    private var preview: some View {
        ZStack {
            if let card {
                Image(uiImage: card)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .aspectRatio(StoryCard.Layout.size, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.glassBorder))
        .frame(maxHeight: .infinity)
        .accessibilityElement()
        .accessibilityLabel("Story card for \(run.placeNameShown)")
        .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private var shareButton: some View {
        if let card {
            let image = Image(uiImage: card)
            ShareLink(item: image, preview: SharePreview(run.placeNameShown, image: image)) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textOnLight)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.Colors.actionWhite, in: Capsule())
            }
        } else {
            Label("Share", systemImage: "square.and.arrow.up")
                .font(.headline)
                .foregroundStyle(Theme.Colors.textDisabled)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.Colors.glass, in: Capsule())
        }
    }

    /// The filter is the Run's, so changing it here changes it everywhere, as on Summary.
    private func choose(_ filter: PhotoFilter) {
        do {
            try modelContext.setFilter(filter, of: run)
        } catch {
            logger.error("Couldn't save the filter: \(error)")
        }
    }
}
