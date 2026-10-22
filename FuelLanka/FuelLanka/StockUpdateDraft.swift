import Foundation

struct StockUpdateDraft: Identifiable {
    let fuel: FuelGrade
    let report: StationFuelReport?
    var quantity = ""

    var id: FuelGrade { fuel }
    var hasEntry: Bool { !quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Accept plain decimal litres only, avoiding ambiguous grouping separators.
    var proposedLitres: Double? {
        let text = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^[0-9]+(\.[0-9]{1,3})?$"#, options: .regularExpression) != nil,
              let value = Double(text), value.isFinite else { return nil }
        return value
    }

    var validationMessage: String? {
        guard hasEntry else { return nil }
        guard let value = proposedLitres else {
            return "Enter litres using digits and a decimal point, with up to three decimal places."
        }
        guard let capacity = report?.capacityLitres, capacity.isFinite, capacity > 0 else {
            return "A valid tank capacity is required before this update can be reviewed."
        }
        guard value <= capacity else { return "Stock cannot exceed tank capacity." }
        return nil
    }

    static func rows(for station: StationDetails?) -> [Self] {
        [FuelGrade.petrol92, .petrol95, .diesel, .superDiesel].map { fuel in
            let report = station?.reports.filter { $0.fuel == fuel }.max {
                ($0.reportedAt ?? .distantPast) < ($1.reportedAt ?? .distantPast)
            }
            return Self(fuel: fuel, report: report)
        }
    }
}
