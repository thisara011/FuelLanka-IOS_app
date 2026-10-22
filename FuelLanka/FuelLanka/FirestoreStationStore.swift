import Foundation
import Observation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum StationLoadingState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

@MainActor
@Observable
final class StationStore {
    private(set) var stations: [StationDetails] = []
    private(set) var state: StationLoadingState = .idle

    func load() async {
        guard state != .loading else { return }
        state = .loading

        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await Firestore.firestore()
                .collection("stations")
                .order(by: "name")
                .getDocuments()
            stations = snapshot.documents.compactMap(Self.station(from:))
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
        #else
        state = .failed("Firestore is not available in this build.")
        #endif
    }

    #if canImport(FirebaseFirestore)
    static func station(from document: DocumentSnapshot) -> StationDetails? {
        guard let data = document.data(),
              let name = nonemptyString(data["name"]) else { return nil }

        return StationDetails(
            id: document.documentID,
            name: name,
            address: nonemptyString(data["address"]),
            operatorName: nonemptyString(data["operatorName"]),
            openingHours: nonemptyString(data["openingHours"]),
            phoneNumber: nonemptyString(data["phoneNumber"]),
            sourceURL: nonemptyString(data["sourceURL"]).flatMap(URL.init(string:)),
            latitude: number(data["latitude"]),
            longitude: number(data["longitude"]),
            reports: reports(from: data["reports"])
        )
    }

    private static func reports(from value: Any?) -> [StationFuelReport] {
        guard let values = value as? [[String: Any]] else { return [] }

        return values.compactMap { data in
            guard let fuelValue = nonemptyString(data["fuel"]),
                  let fuel = FuelGrade(rawValue: fuelValue),
                  fuel != .any else { return nil }

            let timestamp = data["reportedAt"] as? Timestamp
            let reportedAt = timestamp?.dateValue()
            let expired = CommunityReportPolicy.isPublicReportExpired(reportedAt)
            return StationFuelReport(
                id: nonemptyString(data["id"]) ?? UUID().uuidString,
                fuel: fuel,
                availability: nonemptyString(data["availability"]).flatMap(ReportedAvailability.init(rawValue:)),
                stockLitres: number(data["stockLitres"]),
                capacityLitres: number(data["capacityLitres"]),
                pricePerLitre: number(data["pricePerLitre"]).map { Decimal($0) },
                reportedAt: reportedAt,
                source: nonemptyString(data["source"]),
                isStale: (data["isStale"] as? Bool ?? true) || expired
            )
        }
    }

    private static func nonemptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        return value as? Double
    }
    #endif
}
