import Foundation

/// Pricing includes kerosene without expanding the four-grade inventory workflow.
enum PricedFuel: String, CaseIterable, Identifiable {
    case petrol92, petrol95, diesel, superDiesel, kerosene
    var id: Self { self }
    var title: String {
        switch self {
        case .petrol92: "Petrol 92"
        case .petrol95: "Petrol 95"
        case .diesel: "Diesel"
        case .superDiesel: "Super Diesel"
        case .kerosene: "Kerosene"
        }
    }
    var inventoryGrade: FuelGrade? {
        switch self {
        case .petrol92: .petrol92
        case .petrol95: .petrol95
        case .diesel: .diesel
        case .superDiesel: .superDiesel
        case .kerosene: nil
        }
    }
}

struct FuelPriceDraft: Identifiable {
    let fuel: PricedFuel
    let report: StationFuelReport?
    var text = ""
    var effectiveAt: Date?
    var id: PricedFuel { fuel }
    var hasEntry: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var price: Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: #"^[0-9]{1,8}([.][0-9]{1,2})?$"#, options: .regularExpression) != nil,
              let value = Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX")),
              !value.isNaN, value > 0 else { return nil }
        return value
    }
    var validationMessage: String? {
        guard hasEntry else { return nil }
        guard price != nil else { return "Enter a positive LKR price with up to eight digits and two decimal places." }
        guard let effectiveAt, effectiveAt.timeIntervalSince1970.isFinite else {
            return "Select an effective date and time."
        }
        return nil
    }
    static func rows(for station: StationDetails?) -> [Self] {
        PricedFuel.allCases.map { fuel in
            let report = station?.reports.filter { $0.fuel == fuel.inventoryGrade }.max {
                ($0.reportedAt ?? .distantPast) < ($1.reportedAt ?? .distantPast)
            }
            return Self(fuel: fuel, report: report)
        }
    }
}
