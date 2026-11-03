import CoreImage
import Foundation
import ImageIO
import PaceprintCore
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// Run photos on disk: each picked photo is copied in, downscaled, as one file in Application Support.
/// No reference to the Photos library is kept.
nonisolated struct RunPhotoStore: Sendable {
    let directory: URL

    static let shared = RunPhotoStore(directory: .applicationSupportDirectory.appending(path: "RunPhotos", directoryHint: .isDirectory))

    /// A picked photo's longest side once copied in, in pixels.
    static let longestSide = 2048
    /// Summary's shape, width per unit of height, which the Scrim is measured for.
    static let summaryAspect = 390.0 / 844.0

    /// A photo copied in: its file, and the Scrim measured from it.
    struct Saved: Sendable, Equatable {
        let fileName: String
        let scrim: Scrim
    }

    enum Problem: Error {
        case unreadable
        case unwritable
    }

    func url(for fileName: String) -> URL {
        directory.appending(path: fileName, directoryHint: .notDirectory)
    }

    /// Downscales `data` (any image the photo picker hands over, upright), writes it as a new file,
    /// and measures its Scrim.
    @concurrent func save(_ data: Data) async throws -> Saved {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw Problem.unreadable }
        return try save(source)
    }

    /// As `save(_:)`, reading the image from `file`: only the downscaled copy is ever decoded, so a
    /// 48 MP original never sits in memory whole.
    @concurrent func save(contentsOf file: URL) async throws -> Saved {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { throw Problem.unreadable }
        return try save(source)
    }

    private func save(_ source: CGImageSource) throws -> Saved {
        guard let image = Self.downscaled(source, maxPixelSize: Self.longestSide) else { throw Problem.unreadable }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = try write(image)
        return Saved(fileName: fileName, scrim: Self.scrim(of: image))
    }

    /// The photo in `fileName`, downscaled to `maxPixelSize` on its longest side and drawn with `filter`;
    /// nil if the file is gone or unreadable.
    @concurrent func image(_ fileName: String, filter: PhotoFilter, maxPixelSize: Int) async -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url(for: fileName) as CFURL, nil),
              let image = Self.downscaled(source, maxPixelSize: maxPixelSize)
        else { return nil }
        if filter == .none { return image }
        let input = CIImage(cgImage: image)
        return Self.context.createCGImage(filter.apply(to: input), from: input.extent)
    }

    /// Removes `fileName` for good; nothing happens if it's already gone.
    func delete(_ fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    /// Measured where Summary puts the Place name and the metrics over `image`.
    static func scrim(of image: CGImage) -> Scrim {
        let visible = PhotoFraming.visibleRect(of: CGSize(width: image.width, height: image.height), frameAspect: summaryAspect)
        let input = CIImage(cgImage: image)
        return Scrim(
            placeNameBand: averageBrightness(of: input, in: PhotoFraming.rect(of: PhotoFraming.placeNameBand, in: visible)),
            metricsBand: averageBrightness(of: input, in: PhotoFraming.rect(of: PhotoFraming.metricsBand, in: visible))
        )
    }

    // MARK: Private

    /// Thread-safe; made once because it's costly.
    nonisolated(unsafe) private static let context = CIContext()

    private static func downscaled(_ source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary)
    }

    /// Writes `image` as HEIC, or JPEG where HEIC can't be written; returns the new file's name.
    private func write(_ image: CGImage) throws -> String {
        for type in [UTType.heic, .jpeg] {
            let fileName = "\(UUID().uuidString).\(type.preferredFilenameExtension ?? "img")"
            guard let destination = CGImageDestinationCreateWithURL(url(for: fileName) as CFURL, type.identifier as CFString, 1, nil) else { continue }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
            if CGImageDestinationFinalize(destination) { return fileName }
            delete(fileName)
        }
        throw Problem.unwritable
    }

    /// 0 (black) to 1 (white): the average color of `rect` (top-left origin, in pixels), as luminance.
    private static func averageBrightness(of image: CIImage, in rect: CGRect) -> Double {
        // Core Image puts the origin at the bottom left.
        let flipped = CGRect(x: rect.minX, y: image.extent.height - rect.maxY, width: rect.width, height: rect.height)
        let average = image.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: flipped)])
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(average, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        let red = Double(pixel[0]) / 255, green = Double(pixel[1]) / 255, blue = Double(pixel[2]) / 255
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }
}

extension ModelContext {
    /// Makes `photo` the Run's photo, saved at once; the photo it replaces is deleted. If the save
    /// fails, the Run keeps its old photo and the new file is deleted.
    func setPhoto(_ photo: RunPhotoStore.Saved, of run: Run, in store: RunPhotoStore = .shared) throws {
        let replaced = (fileName: run.photoFileName, scrimStrength: run.photoScrimStrength)
        run.photoFileName = photo.fileName
        run.photoScrimStrength = photo.scrim.strength
        do {
            try save()
        } catch {
            run.photoFileName = replaced.fileName
            run.photoScrimStrength = replaced.scrimStrength
            store.delete(photo.fileName)
            throw error
        }
        if let old = replaced.fileName { store.delete(old) }
    }

    /// Draws `run`'s photo with `filter` from now on, saved at once.
    func setFilter(_ filter: PhotoFilter, of run: Run) throws {
        run.photoFilter = filter
        try save()
    }

    /// Deletes `run` for good, with its photo.
    func deleteRun(_ run: Run, in store: RunPhotoStore = .shared) throws {
        let photo = run.photoFileName
        delete(run)
        try save()
        if let photo { store.delete(photo) }
    }
}

extension Scrim {
    /// Measured from the bundled photo Home shows before any Run has one, the first time it's needed.
    static let bundledPhoto: Scrim = {
        guard let image = UIImage(resource: .defaultHomePhoto).cgImage else { return .none }
        return RunPhotoStore.scrim(of: image)
    }()
}
