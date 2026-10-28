import Testing
import PaceprintCore

@Suite("Distance units")
struct DistanceUnitTests {
    @Test("A kilometre is 1,000 metres")
    func kilometre() {
        #expect(DistanceUnit.kilometers.metresPerUnit == 1_000)
    }

    @Test("A mile is 1,609.344 metres (international mile)")
    func mile() {
        #expect(DistanceUnit.miles.metresPerUnit == 1_609.344)
    }
}
