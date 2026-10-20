import Foundation
import Testing
@testable import FuelLanka

struct DeliveryReceiptDraftTests {
    let now = Date(timeIntervalSince1970: 1_000)

    func report(stale: Bool = false) -> StationFuelReport {
        StationFuelReport(id: "test", fuel: .petrol92, availability: nil,
                          stockLitres: 80, capacityLitres: 100, pricePerLitre: nil,
                          reportedAt: Date(timeIntervalSince1970: 900), source: nil, isStale: stale)
    }

    @Test func exactCapacityAndOverflow() {
        var draft = DeliveryReceiptDraft(fuel: .petrol92, reference: "receipt", quantity: "20", receivedAt: now)
        #expect(draft.issue(report: report(), now: now) == nil)
        draft.quantity = "20.001"
        #expect(draft.issue(report: report(), now: now) != nil)
    }

    @Test(arguments: ["0", "-1", "NaN", "1e2", "1,000", "1.0001"])
    func invalidQuantities(_ value: String) {
        #expect(DeliveryReceiptDraft(quantity: value).litres == nil)
    }

    @Test func requiresReferenceCurrentStockAndPastTime() {
        var draft = DeliveryReceiptDraft(fuel: .petrol92, reference: "receipt", quantity: "1", receivedAt: now)
        #expect(draft.issue(report: nil, now: now) != nil)
        #expect(draft.issue(report: report(stale: true), now: now) != nil)
        draft.receivedAt = now.addingTimeInterval(1)
        #expect(draft.issue(report: report(), now: now) != nil)
        draft.receivedAt = now
        draft.reference = " "
        #expect(draft.issue(report: report(), now: now) != nil)
    }
}
