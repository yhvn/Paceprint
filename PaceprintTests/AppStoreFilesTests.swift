import Foundation
import Testing
@testable import Paceprint

/// What App Review reads from the app bundle itself (#32, as decided in #16).
@Suite("App Store files")
struct AppStoreFilesTests {
    private let info = Bundle.main.infoDictionary ?? [:]

    private func privacyManifest() throws -> [String: Any] {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    @Test("The privacy manifest: no tracking, no tracking domains, nothing collected, UserDefaults for the app's own settings")
    func privacyManifestContents() throws {
        let manifest = try privacyManifest()

        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true)
        #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        let reasons = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        #expect(reasons.count == 1)
        #expect(reasons.first?["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults")
        #expect(reasons.first?["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
    }

    @Test("Every purpose string says Paceprint", arguments: [
        "NSLocationWhenInUseUsageDescription",
        "NSHealthShareUsageDescription",
        "NSHealthUpdateUsageDescription",
    ])
    func purposeString(key: String) throws {
        let text = try #require(info[key] as? String)
        #expect(text.contains("Paceprint"))
        #expect(!text.contains("Paceline"))
    }

    @Test("Precise location is asked for with the RunRecording purpose")
    func temporaryAccuracy() throws {
        let purposes = try #require(info["NSLocationTemporaryUsageDescriptionDictionary"] as? [String: String])
        #expect(purposes[LiveLocationSource.fullAccuracyPurposeKey]?.contains("Paceprint") == true)
    }

    @Test("Location keeps recording in the background, and nothing else runs there")
    func backgroundModes() {
        #expect(info["UIBackgroundModes"] as? [String] == ["location"])
    }

    @Test("Only Apple's own encryption is used, so uploads skip the export-compliance question")
    func encryption() {
        #expect(info["ITSAppUsesNonExemptEncryption"] as? Bool == false)
    }

    @Test("No other apps are queried, Health isn't required to install, and Photos needs no permission string")
    func nothingExtra() {
        #expect(info["LSApplicationQueriesSchemes"] == nil)
        let required = info["UIRequiredDeviceCapabilities"] as? [String] ?? []
        #expect(!required.contains("healthkit"))
        #expect(info["NSPhotoLibraryUsageDescription"] == nil)
    }
}
