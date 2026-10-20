import Foundation
import Testing
@testable import FuelLanka

struct StockUpdateDraftTests {
    private func draft(_ quantity: String, capacity: Double? = 100) -> StockUpdateDraft {
        StockUpdateDraft(fuel: .petrol92, report: StationFuelReport(
            id: "test", fuel: .petrol92, availability: nil, stockLitres: 20,
            capacityLitres: capacity, pricePerLitre: nil, reportedAt: nil,
            source: nil, isStale: false
        ), quantity: quantity)
    }

    @Test(arguments: ["-1", "NaN", "inf", "1e2", "1,000", "1a2", "1.2345"])
    func rejectsInvalidQuantities(_ quantity: String) {
        #expect(draft(quantity).validationMessage != nil)
    }

    @Test func capacityBoundaries() {
        #expect(draft("0").validationMessage == nil)
        #expect(draft("100").validationMessage == nil)
        #expect(draft("100.001").validationMessage != nil)
        #expect(draft("1", capacity: nil).validationMessage != nil)
        #expect(draft("1", capacity: .infinity).validationMessage != nil)
        #expect(draft("1", capacity: 0).validationMessage != nil)
    }

    @Test func blankDoesNotMeanZero() {
        #expect(!draft(" ").hasEntry)
        #expect(draft(" ").proposedLitres == nil)
        #expect(draft(" 1.125 ").proposedLitres == 1.125)
    }
}
