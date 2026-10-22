import Foundation

struct SaleRecordDraft {
    var fuel: FuelGrade = .any
    var reference = ""
    var quantity = ""
    var occurredAt = Date()

    var litres: Double? {
        let text = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^[0-9]+([.][0-9]{1,3})?$"#, options: .regularExpression) != nil,
              let value = Double(text), value.isFinite, value > 0 else { return nil }
        return value
    }

    func issue(report: StationFuelReport?, now: Date = Date()) -> String? {
        guard fuel != .any else { return "Select the sold fuel grade." }
        guard !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Enter the shift, meter, or receipt reference."
        }
        guard let litres else {
            return "Enter a positive quantity with up to three decimal places."
        }
        guard occurredAt.timeIntervalSince1970.isFinite, occurredAt <= now else {
            return "Sale time cannot be in the future."
        }
        guard let report, report.fuel == fuel, !report.isStale,
              let reportedAt = report.reportedAt, reportedAt <= occurredAt,
              let stock = report.stockLitres, stock.isFinite, stock >= 0 else {
            return "A current inventory report from before this sale is required."
        }
        guard litres <= stock else { return "The sale cannot exceed current reported stock." }
        return nil
    }
}
