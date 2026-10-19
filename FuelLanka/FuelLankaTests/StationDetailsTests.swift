import Foundation
import Testing
@testable import FuelLanka

struct StationDetailsTests {
    @Test func directionsRequireValidCoordinates() {
        var station = StationDetails(id: "test", name: "Test")
        #expect(station.directionsURL == nil)
        station.latitude = 6.9
        station.longitude = 79.8
        #expect(station.directionsURL?.host == "maps.apple.com")
        station.latitude = 91
        #expect(station.directionsURL == nil)
        station.latitude = .nan
        #expect(station.directionsURL == nil)
    }

    @Test func invalidCapacityCannotProduceTankLevel() {
        func report(stock: Double?, capacity: Double?) -> StationFuelReport {
            StationFuelReport(id: "test", fuel: .petrol92, availability: nil,
                              stockLitres: stock, capacityLitres: capacity, pricePerLitre: nil,
                              reportedAt: nil, source: nil, isStale: true)
        }
        #expect(report(stock: 50, capacity: 100).fillFraction == 0.5)
        #expect(report(stock: 0, capacity: 100).fillFraction == 0)
        #expect(report(stock: nil, capacity: 100).fillFraction == nil)
        #expect(report(stock: 50, capacity: 0).fillFraction == nil)
        #expect(report(stock: -1, capacity: 100).fillFraction == nil)
        #expect(report(stock: 101, capacity: 100).fillFraction == nil)
        #expect(report(stock: .infinity, capacity: 100).fillFraction == nil)
    }
}
