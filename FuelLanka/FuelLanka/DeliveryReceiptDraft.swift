import Foundation

struct DeliveryReceiptDraft {
    var fuel: FuelGrade = .any
    var reference = ""
    var quantity = ""
    var receivedAt = Date()

    var litres: Double? {
        let text = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^[0-9]+([.][0-9]{1,3})?$"#, options: .regularExpression) != nil,
              let value = Double(text), value.isFinite, value > 0 else { return nil }
        return value
    }

    func issue(report: StationFuelReport?, now: Date = Date()) -> String? {
        guard fuel != .any else { return "Select the delivered fuel grade." }
        guard !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Enter the supplier receipt reference."
        }
        guard let litres else { return "Enter a positive quantity with up to three decimal places." }
        guard receivedAt.timeIntervalSince1970.isFinite, receivedAt <= now else {
            return "Receipt time cannot be in the future."
        }
        guard let report, report.fuel == fuel, !report.isStale,
              let reportedAt = report.reportedAt, reportedAt <= receivedAt,
              let stock = report.stockLitres, stock.isFinite, stock >= 0,
              let capacity = report.capacityLitres, capacity.isFinite, capacity > 0,
              stock <= capacity else {
            return "A current, valid inventory report from before this receipt is required."
        }
        guard litres <= capacity - stock else { return "This delivery would exceed tank capacity." }
        return nil
    }
}
