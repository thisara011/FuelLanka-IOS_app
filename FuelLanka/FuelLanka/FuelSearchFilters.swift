import Foundation

enum FuelGrade: String, CaseIterable, Identifiable {
    case any, petrol92, petrol95, diesel, superDiesel

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .any: "Any fuel"
        case .petrol92: "Petrol 92"
        case .petrol95: "Petrol 95"
        case .diesel: "Diesel"
        case .superDiesel: "Super Diesel"
        }
    }
}

enum ReportedAvailability: String, CaseIterable, Identifiable {
    case any, available, limited

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .any: "Any availability"
        case .available: "Available"
        case .limited: "Limited"
        }
    }
}

/// Search criteria only; selecting a filter never implies station availability.
struct FuelSearchFilters: Equatable {
    var fuel: FuelGrade = .any
    var availability: ReportedAvailability = .any
    var province = ""
    var district = ""
    var city = ""

    var hasFilters: Bool {
        self != FuelSearchFilters()
    }

    func normalized() -> Self {
        var value = self
        value.province = province.trimmingCharacters(in: .whitespacesAndNewlines)
        value.district = district.trimmingCharacters(in: .whitespacesAndNewlines)
        value.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        return value
    }
}
