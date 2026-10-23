import Foundation
import Testing
@testable import FuelLanka

struct FuelPredictionTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func station(
        stock: Double = 700,
        capacity: Double = 1_000,
        reportAgeHours: Double = 2,
        isStale: Bool = false
    ) -> StationDetails {
        StationDetails(
            id: "station-one",
            name: "Test Station",
            reports: [
                StationFuelReport(
                    id: "report",
                    fuel: .petrol92,
                    availability: .available,
                    stockLitres: stock,
                    capacityLitres: capacity,
                    pricePerLitre: nil,
                    reportedAt: now.addingTimeInterval(-reportAgeHours * 3_600),
                    source: "Station manager",
                    isStale: isStale
                )
            ]
        )
    }

    private func transaction(
        id: String,
        daysAgo: Double,
        litres: Double = 100,
        kind: StationTransaction.Kind = .sale,
        status: String = "Confirmed"
    ) -> StationTransaction {
        StationTransaction(
            id: id,
            stationID: "station-one",
            kind: kind,
            fuel: .petrol92,
            litres: litres,
            occurredAt: now.addingTimeInterval(-daysAgo * 86_400),
            reference: id,
            status: status
        )
    }

    @Test func estimatesFromConfirmedSalesAndCurrentStock() {
        let sales = (1...8).map {
            transaction(id: "sale-\($0)", daysAgo: Double($0), litres: 100)
        }

        let result = FuelPredictionCalculator.calculate(
            station: station(),
            fuel: .petrol92,
            sales: sales,
            now: now,
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(result.confidence == .high)
        #expect(result.averageDailyUsage == 100)
        #expect(result.estimatedDaysRemaining == 7)
        #expect(result.saleCount == 8)
        #expect(result.dailyUsage.count == 8)
        #expect(result.engine == .baseline)
    }

    @Test func bundledCoreMLModelPredictsLocally() {
        let calendar = Calendar(identifier: .gregorian)
        let sales = (1...14).map {
            transaction(id: "model-sale-\($0)", daysAgo: Double($0), litres: 100 + Double($0))
        }

        let result = FuelPredictionCalculator.calculate(
            station: station(stock: 2_000),
            fuel: .petrol92,
            sales: sales,
            demandPredictor: OnDeviceFuelDemandPredictor(),
            now: now,
            calendar: calendar
        )

        #expect(result.engine == .coreML)
        #expect(result.averageDailyUsage != nil)
        #expect(result.estimatedDaysRemaining != nil)
    }

    @Test func ignoresDeliveriesAndUnconfirmedSales() {
        let records = [
            transaction(id: "valid-one", daysAgo: 3, litres: 60),
            transaction(id: "valid-two", daysAgo: 2, litres: 60),
            transaction(id: "delivery", daysAgo: 1, litres: 900, kind: .delivery),
            transaction(id: "draft", daysAgo: 1, litres: 900, status: "Recorded")
        ]

        let result = FuelPredictionCalculator.calculate(
            station: station(stock: 120),
            fuel: .petrol92,
            sales: records,
            now: now,
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(result.saleCount == 2)
        #expect(result.averageDailyUsage == 40)
        #expect(result.estimatedDaysRemaining == 3)
    }

    @Test func staleReportBlocksForecast() {
        let sales = (1...8).map {
            transaction(id: "sale-\($0)", daysAgo: Double($0))
        }

        let result = FuelPredictionCalculator.calculate(
            station: station(reportAgeHours: 96, isStale: true),
            fuel: .petrol92,
            sales: sales,
            now: now,
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(result.confidence == .insufficient)
        #expect(result.estimatedDaysRemaining == nil)
        #expect(result.estimatedRunOutDate == nil)
    }

    @Test func oneDayOfSalesDoesNotCreateForecast() {
        let result = FuelPredictionCalculator.calculate(
            station: station(),
            fuel: .petrol92,
            sales: [transaction(id: "one", daysAgo: 1)],
            now: now,
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(result.confidence == .insufficient)
        #expect(result.averageDailyUsage == nil)
        #expect(result.estimatedDaysRemaining == nil)
    }
}
