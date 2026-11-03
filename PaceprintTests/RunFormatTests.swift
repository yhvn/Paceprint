import Foundation
import PaceprintCore
import Testing
@testable import Paceprint

@Suite("Run format")
struct RunFormatTests {
    /// Noon on `day` `month` `year` in the device's calendar, clear of any time zone edge.
    private func noon(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test("A card's date leaves out the year for this year's Runs")
    func cardDateThisYear() {
        #expect(RunFormat.cardDate(noon(2026, 5, 12), now: noon(2026, 10, 31)) == "MAY 12")
    }

    @Test("A card's date shows the year for past years' Runs")
    func cardDatePastYear() {
        #expect(RunFormat.cardDate(noon(2025, 5, 12), now: noon(2026, 10, 31)) == "MAY 12, 2025")
        #expect(RunFormat.cardDate(noon(2025, 12, 31), now: noon(2026, 1, 1)) == "DEC 31, 2025")
    }

    @Test("Distance and Pace read in the chosen units")
    func units() {
        #expect(RunFormat.distance(5_000, in: .kilometers) == 5.0.formatted(.number.precision(.fractionLength(2))))
        #expect(RunFormat.distance(1_609.344, in: .miles) == 1.0.formatted(.number.precision(.fractionLength(2))))
        // 5:00 /km is 8:03 /mi.
        #expect(RunFormat.pace(Pace(secondsPerMetre: 0.3), per: .miles) == "8:03")
    }

    @Test("Body weight is shown and entered in kg with kilometres, lb with miles")
    func bodyMass() {
        #expect(BodyMassUnit(.kilometers) == .kilograms)
        #expect(BodyMassUnit(.miles) == .pounds)
        #expect(abs(BodyMassUnit.pounds.value(ofKilograms: 70) - 154.32) < 0.01)
        #expect(abs(BodyMassUnit.pounds.kilograms(154.32) - 70) < 0.01)
        #expect(BodyMassUnit.kilograms.kilograms(72.4) == 72.4)
    }

    @Test("A History month header spells out the month, with its year")
    func monthHeader() {
        #expect(RunFormat.monthHeader(noon(2026, 5, 1)) == "MAY 2026")
        #expect(RunFormat.monthHeader(noon(2026, 10, 1)) == "OCTOBER 2026")
    }
}
