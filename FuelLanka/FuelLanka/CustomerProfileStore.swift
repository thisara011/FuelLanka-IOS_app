import Foundation
import Observation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct CustomerProfile: Equatable, Sendable {
    var fullName = ""
    var email = ""
    var phone = ""
    var district = ""
    var preferredFuels: Set<FuelGrade> = []
    var restockAlerts = false
    var priceAlerts = false
}

enum CustomerProfileState: Equatable {
    case idle
    case loading
    case loaded
    case saving
    case failed(String)
}

@MainActor
@Observable
final class CustomerProfileStore {
    private(set) var profile = CustomerProfile()
    private(set) var state: CustomerProfileState = .idle

    func load(userID: String, fallbackEmail: String?) async {
        guard state != .loading else { return }
        state = .loading

        #if canImport(FirebaseFirestore)
        do {
            let document = try await Firestore.firestore()
                .collection("users")
                .document(userID)
                .getDocument()
            profile = Self.profile(
                from: document.data(),
                fallbackEmail: fallbackEmail ?? ""
            )
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
        #else
        state = .failed("Firestore is not available in this build.")
        #endif
    }

    func save(_ updatedProfile: CustomerProfile, userID: String) async -> Bool {
        state = .saving

        #if canImport(FirebaseFirestore)
        do {
            try await Firestore.firestore()
                .collection("users")
                .document(userID)
                .setData([
                    "fullName": updatedProfile.fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                    "email": updatedProfile.email,
                    "phone": updatedProfile.phone.trimmingCharacters(in: .whitespacesAndNewlines),
                    "district": updatedProfile.district.trimmingCharacters(in: .whitespacesAndNewlines),
                    "preferredFuels": updatedProfile.preferredFuels.map(\.rawValue).sorted(),
                    "restockAlerts": updatedProfile.restockAlerts,
                    "priceAlerts": updatedProfile.priceAlerts,
                    "role": AccountRole.customer.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
            profile = updatedProfile
            state = .loaded
            return true
        } catch {
            state = .failed(error.localizedDescription)
            return false
        }
        #else
        state = .failed("Firestore is not available in this build.")
        return false
        #endif
    }

    private static func profile(from data: [String: Any]?, fallbackEmail: String) -> CustomerProfile {
        guard let data else {
            return CustomerProfile(email: fallbackEmail)
        }

        let fuelValues = data["preferredFuels"] as? [String] ?? []
        return CustomerProfile(
            fullName: data["fullName"] as? String ?? "",
            email: data["email"] as? String ?? fallbackEmail,
            phone: data["phone"] as? String ?? "",
            district: data["district"] as? String ?? "",
            preferredFuels: Set(fuelValues.compactMap(FuelGrade.init(rawValue:))),
            restockAlerts: data["restockAlerts"] as? Bool ?? false,
            priceAlerts: data["priceAlerts"] as? Bool ?? false
        )
    }
}
