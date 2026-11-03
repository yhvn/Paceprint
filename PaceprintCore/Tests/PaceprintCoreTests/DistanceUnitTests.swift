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

    @Test("Body weight goes with the units: kilograms with kilometres, pounds with miles")
    func bodyMassUnit() {
        #expect(DistanceUnit.kilometers.bodyMassUnit == .kilograms)
        #expect(DistanceUnit.miles.bodyMassUnit == .pounds)
        #expect(abs(BodyMassUnit.pounds.value(ofKilograms: 70) - 154.32) < 0.01)
        #expect(abs(BodyMassUnit.pounds.kilograms(154.32) - 70) < 0.01)
        #expect(BodyMassUnit.kilograms.kilograms(72.4) == 72.4)
    }

    @Test("Only a body weight a runner could have is taken", arguments: [
        (kilograms: 72.4, isPlausible: true),
        (kilograms: 20, isPlausible: true),
        (kilograms: 350, isPlausible: true),
        (kilograms: 0.1, isPlausible: false),
        (kilograms: 2_268, isPlausible: false),
    ])
    func plausibleBodyMass(kilograms: Double, isPlausible: Bool) {
        #expect(BodyMassUnit.isPlausible(kilograms: kilograms) == isPlausible)
    }
}
