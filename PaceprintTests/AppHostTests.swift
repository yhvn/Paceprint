import Testing
import Foundation
import PaceprintCore
@testable import Paceprint

@Suite("App test host")
struct AppHostTests {
    @Test("Tests run inside the Paceprint app")
    func hostIsPaceprint() {
        #expect(Bundle.main.bundleIdentifier == "com.yhlabs.paceprint")
    }

    @Test("The app links PaceprintCore")
    func linksCore() {
        #expect(DistanceUnit.allCases.contains(.kilometers))
    }
}
