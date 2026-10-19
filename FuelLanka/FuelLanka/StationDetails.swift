import Foundation

/// Values supplied by station services, never fabricated by the presentation layer.
struct StationDetails: Identifiable, Hashable {
    let id: String
    let name: String
    var address: String?
    var operatorName: String?
    var openingHours: String?
    var latitude: Double?
    var longitude: Double?
    var reports: [StationFuelReport] = []

    var directionsURL: URL? {
        guard let latitude, let longitude,
              latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "daddr", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "dirflg", value: "d")
        ]
        return components?.url
    }
}

struct StationFuelReport: Identifiable, Hashable {
    let id: String
    let fuel: FuelGrade
    let availability: ReportedAvailability?
    let stockLitres: Double?
    let capacityLitres: Double?
    let pricePerLitre: Decimal?
    let reportedAt: Date?
    let source: String?
    /// Freshness is decided by the reporting policy/service, not inferred from a badge.
    let isStale: Bool

    var fillFraction: Double? {
        guard let stockLitres, let capacityLitres,
              stockLitres.isFinite, capacityLitres.isFinite,
              capacityLitres > 0, stockLitres >= 0, stockLitres <= capacityLitres else { return nil }
        return stockLitres / capacityLitres
    }
}
