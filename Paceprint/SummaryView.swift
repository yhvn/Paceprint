import os
import PaceprintCore
import PhotosUI
import SwiftData
import SwiftUI

/// Summary: a Run's Route in Pace colors over its photo (or the dark map), its date where the Place name
/// will go, and its headline numbers. Opens after Stop; the runner picks the Run's photo and filter here.
struct SummaryView: View {
    let run: Run
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var isCopyingPhoto = false
    @State private var photoFailed = false
    @State private var isSharing = false
    @Environment(RunHealthSync.self) private var healthSync
    @AppStorage(SettingsKey.isHealthCardAnswered) private var isHealthCardAnswered = false
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Paceprint", category: "Summary")

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            ScrimGradient(stops: .summary, scrim: run.scrim)
                .ignoresSafeArea()

            if run.photoFileName != nil {
                // Above the text, clear of the top bar and the photo button.
                GeometryReader { geometry in
                    RouteOverlay(run: run)
                        .padding(.top, 70)
                        .padding(.horizontal, 64)
                        .frame(height: geometry.size.height * 0.47)
                }
            }

            VStack(alignment: .leading, spacing: 28) {
                topBar
                if healthSync.isAvailable && !isHealthCardAnswered {
                    healthCard
                }
                Spacer()
                RunHeadline(run: run, font: Theme.Typography.placeName)
                RunMetrics(run: run, large: .xl, small: .lg)
                if run.photoFileName != nil {
                    FilterStrip(selection: Binding(get: { run.photoFilter }, set: { choose($0) }))
                        .padding(.horizontal, -8)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, run.photoFileName == nil ? 32 : 16)
        }
        .overlay(alignment: .topTrailing) { photoButton }
        .preferredColorScheme(.dark)
        // A photo screen: labels scale up to XXXL.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task { await usePhoto(item) }
        }
        .sheet(isPresented: $isSharing) { ShareStorySheet(run: run) }
        .alert("Couldn't use that photo", isPresented: $photoFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try another one.")
        }
    }

    /// The Run's photo, else the dark map with its Route.
    @ViewBuilder
    private var background: some View {
        if let fileName = run.photoFileName {
            RunPhoto(fileName: fileName, filter: run.photoFilter) { Theme.Colors.inkBlack }
        } else {
            // Room below the Route for the place name and metrics.
            RouteMap(run: run, roomBelow: 1)
        }
    }

    /// Shown once, after the first saved Run: Connect asks for Health permission and saves this Run;
    /// Not now hides the card for good. Settings can turn Health on later.
    private var healthCard: some View {
        NoticeCard(
            title: "Save runs to Apple Health?",
            message: "Your runs, routes and calories appear in Health and count toward your Activity rings."
        ) {
            Button("Connect") {
                Task {
                    if await healthSync.connect() {
                        await healthSync.save(run)
                    }
                }
            }
            .foregroundStyle(Theme.Colors.info)
            Button("Not now") { isHealthCardAnswered = true }
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        // Below the photo button, which floats at the top right.
        .padding(.top, 36)
    }

    private var topBar: some View {
        HStack {
            CircleButton(systemImage: "xmark", label: "Close") { dismiss() }
            Spacer()
            Text("PACEPRINT")
                .paceprintLabel(tracking: Theme.Typography.wordmarkTracking)
            Spacer()
            CircleButton(systemImage: "square.and.arrow.up", label: "Share") { isSharing = true }
        }
        .padding(.top, 8)
    }

    /// Floats on the right, below the top bar, where the design keeps the map buttons.
    private var photoButton: some View {
        PhotosPicker(selection: $pickedPhoto, matching: .images, photoLibrary: .shared()) {
            ZStack {
                CircleIcon(systemImage: run.photoFileName == nil ? "photo.badge.plus" : "photo")
                if isCopyingPhoto {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 36, height: 36)
                        .background(Theme.Colors.glass, in: Circle())
                }
            }
        }
        .disabled(isCopyingPhoto)
        .accessibilityLabel(run.photoFileName == nil ? "Choose a photo" : "Change photo")
        .padding(.trailing, 22)
        .padding(.top, 64)
    }

    /// Copies the picked photo in and makes it the Run's.
    private func usePhoto(_ item: PhotosPickerItem) async {
        isCopyingPhoto = true
        defer {
            isCopyingPhoto = false
            pickedPhoto = nil
        }
        do {
            guard let picked = try await item.loadTransferable(type: PickedPhotoFile.self) else { throw RunPhotoStore.Problem.unreadable }
            defer { try? FileManager.default.removeItem(at: picked.url) }
            let photo = try await RunPhotoStore.shared.save(contentsOf: picked.url)
            try modelContext.setPhoto(photo, of: run)
        } catch {
            logger.error("Couldn't use the picked photo: \(error)")
            photoFailed = true
        }
    }

    private func choose(_ filter: PhotoFilter) {
        do {
            try modelContext.setFilter(filter, of: run)
        } catch {
            logger.error("Couldn't save the filter: \(error)")
        }
    }
}

/// A picked photo handed over as a file in the temporary directory, so a large original is never
/// read into memory whole. The caller deletes the file once it's copied in.
nonisolated private struct PickedPhotoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            // The picker's file only lasts for this call.
            let copy = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).\(received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedPhotoFile(url: copy)
        }
    }
}
