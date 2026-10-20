import Foundation
import Testing
@testable import FuelLanka

struct FuelPriceDraftTests {
    @Test(arguments: ["0", "-1", "NaN", "inf", "1e2", "1,000", "2.001", "123456789"])
    func rejectsInvalidPrices(_ value: String) {
        let draft = FuelPriceDraft(fuel: .petrol92, report: nil, text: value, effectiveAt: Date())
        #expect(draft.price == nil)
        #expect(draft.validationMessage != nil)
    }

    @Test func exactDecimalAndRequiredDate() {
        var draft = FuelPriceDraft(fuel: .petrol95, report: nil, text: " 305.25 ")
        #expect(draft.price == Decimal(string: "305.25"))
        #expect(draft.validationMessage != nil)
        draft.effectiveAt = Date()
        #expect(draft.validationMessage == nil)
    }

    @Test func emptyPricesAndFiveGrades() {
        #expect(!FuelPriceDraft(fuel: .diesel, report: nil).hasEntry)
        #expect(FuelPriceDraft.rows(for: nil).count == 5)
        #expect(PricedFuel.kerosene.inventoryGrade == nil)
    }
}
