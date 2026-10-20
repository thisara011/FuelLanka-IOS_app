import Foundation
import Testing
@testable import FuelLanka

struct ManagerAnalyticsTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func record(
        id: String,
        stationID: String = "assigned",
        kind: StationTransaction.Kind = .sale,
        fuel: FuelGrade = .petrol92,
        litres: Double? = 10,
        daysAgo: TimeInterval = 1
    ) -> StationTransaction {
        StationTransaction(
            id: id,
            stationID: stationID,
            kind: kind,
            fuel: fuel,
            litres: litres,
            occurredAt: now.addingTimeInterval(-daysAgo * 86_400),
            reference: nil,
            status: "Recorded"
        )
    }

    @Test func scopesAndTotalsCompleteSales() {
        let records = [
            record(id: "one", litres: 15),
            record(id: "two", fuel: .diesel, litres: 25),
            record(id: "other-station", stationID: "other", litres: 100),
            record(id: "delivery", kind: .delivery, litres: 100),
            record(id: "missing-quantity", litres: nil)
        ]

        let summary = ManagerAnalyticsSummary(
            records: records,
            stationID: "assigned",
            period: .sevenDays,
            now: now
        )

        #expect(summary.totalLitres == 40)
        #expect(summary.transactionCount == 2)
        #expect(summary.fuelTotals.count == 2)
        #expect(summary.fuelTotals.first?.fuel == .diesel)
    }

    @Test func excludesInvalidAndOutOfPeriodRecords() {
        let records = [
            record(id: "old", litres: 12, daysAgo: 8),
            record(id: "zero", litres: 0),
            record(id: "negative", litres: -3),
            record(id: "infinite", litres: .infinity)
        ]

        let summary = ManagerAnalyticsSummary(
            records: records,
            stationID: "assigned",
            period: .sevenDays,
            now: now
        )

        #expect(summary.totalLitres == 0)
        #expect(summary.transactionCount == 0)
        #expect(summary.fuelTotals.isEmpty)
        #expect(summary.latestSaleAt == nil)
    }

    @Test func thirtyDayPeriodIncludesOlderCompleteRecord() {
        let summary = ManagerAnalyticsSummary(
            records: [record(id: "older", litres: 18, daysAgo: 20)],
            stationID: "assigned",
            period: .thirtyDays,
            now: now
        )

        #expect(summary.totalLitres == 18)
        #expect(summary.transactionCount == 1)
    }
}
