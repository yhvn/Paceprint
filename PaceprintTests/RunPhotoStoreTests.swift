import CoreImage
import Foundation
import ImageIO
import SwiftData
import Testing
import UniformTypeIdentifiers
import PaceprintCore
@testable import Paceprint

@Suite("Run photos")
struct RunPhotoStoreTests {
    let store = RunPhotoStore(directory: .temporaryDirectory.appending(path: "RunPhotoStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory))
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(for: Run.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// A JPEG, `width` × `height`, of one gray from 0 (black) to 1 (white).
    private func photo(width: Int, height: Int, gray: CGFloat) throws -> Data {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: gray, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func pixelSize(of fileName: String) throws -> (width: Int, height: Int) {
        let source = try #require(CGImageSourceCreateWithURL(store.url(for: fileName) as CFURL, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        return (try #require(properties[kCGImagePropertyPixelWidth] as? Int), try #require(properties[kCGImagePropertyPixelHeight] as? Int))
    }

    private func savedRun() -> Run {
        let run = Run(startDate: .now)
        container.mainContext.insert(run)
        return run
    }

    @Test("A picked photo is copied in, downscaled to 2,048 px on its longest side")
    func downscales() async throws {
        let saved = try await store.save(try photo(width: 4000, height: 3000, gray: 0.5))
        let size = try pixelSize(of: saved.fileName)
        #expect(size.width == 2048)
        #expect(size.height == 1536)
    }

    @Test("A photo already smaller than 2,048 px keeps its size")
    func smallPhoto() async throws {
        let saved = try await store.save(try photo(width: 800, height: 600, gray: 0.5))
        let size = try pixelSize(of: saved.fileName)
        #expect(size.width == 800)
        #expect(size.height == 600)
    }

    @Test("A bright photo gets the full Scrim, a dark one none")
    func scrim() async throws {
        #expect(try await store.save(try photo(width: 600, height: 1200, gray: 1)).scrim.strength == 1)
        #expect(try await store.save(try photo(width: 600, height: 1200, gray: 0.05)).scrim.strength == 0)
    }

    @Test("Data that isn't an image is refused")
    func notAnImage() async {
        await #expect(throws: RunPhotoStore.Problem.self) {
            try await store.save(Data("not a photo".utf8))
        }
    }

    @Test("NOIR draws the photo in grays")
    func noir() {
        let red = CIImage(color: CIColor(red: 0.9, green: 0.2, blue: 0.1)).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext().render(PhotoFilter.noir.apply(to: red), toBitmap: &pixel, rowBytes: 4, bounds: red.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        #expect(abs(Int(pixel[0]) - Int(pixel[1])) <= 1)
        #expect(abs(Int(pixel[1]) - Int(pixel[2])) <= 1)
    }

    @Test("Each filter reads its photo back from disk")
    func filteredImage() async throws {
        let saved = try await store.save(try photo(width: 400, height: 300, gray: 0.5))
        for filter in PhotoFilter.allCases {
            let image = try #require(await store.image(saved.fileName, filter: filter, maxPixelSize: 200))
            #expect(image.width == 200)
        }
    }

    @Test("A new photo replaces the Run's old one, whose file is deleted")
    func replace() async throws {
        let run = savedRun()
        let first = try await store.save(try photo(width: 400, height: 300, gray: 0.5))
        try container.mainContext.setPhoto(first, of: run, in: store)
        let second = try await store.save(try photo(width: 400, height: 300, gray: 1))
        try container.mainContext.setPhoto(second, of: run, in: store)

        #expect(run.photoFileName == second.fileName)
        #expect(run.scrim == second.scrim)
        #expect(!FileManager.default.fileExists(atPath: store.url(for: first.fileName).path()))
        #expect(FileManager.default.fileExists(atPath: store.url(for: second.fileName).path()))
    }

    @Test("Deleting a Run deletes its photo file")
    func deleteRun() async throws {
        let run = savedRun()
        let saved = try await store.save(try photo(width: 400, height: 300, gray: 0.5))
        try container.mainContext.setPhoto(saved, of: run, in: store)
        try container.mainContext.deleteRun(run, in: store)

        #expect(try container.mainContext.fetchCount(FetchDescriptor<Run>()) == 0)
        #expect(!FileManager.default.fileExists(atPath: store.url(for: saved.fileName).path()))
    }

    @Test("A Run starts with no photo: the dark map, no filter, no Scrim")
    func noPhoto() {
        let run = savedRun()
        #expect(run.photoFileName == nil)
        #expect(run.photoFilter == .none)
        #expect(run.scrim == .none)
    }
}
