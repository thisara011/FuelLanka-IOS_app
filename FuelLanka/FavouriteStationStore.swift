import Foundation
import Observation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum FavouriteStationState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

@MainActor
@Observable
final class FavouriteStationStore {
    private(set) var stationIDs: Set<String> = []
    private(set) var state: FavouriteStationState = .idle
    private(set) var updatingStationIDs: Set<String> = []

    func load(userID: String) async {
        guard state != .loading else { return }
        state = .loading

        #if canImport(FirebaseFirestore)
        do {
            let document = try await Firestore.firestore()
                .collection("users")
                .document(userID)
                .getDocument()
            let values = document.data()?["favouriteStationIDs"] as? [String] ?? []
            stationIDs = Set(values)
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
        #else
        state = .failed("Firestore is not available in this build.")
        #endif
    }

    func isFavourite(_ stationID: String) -> Bool {
        stationIDs.contains(stationID)
    }

    func toggle(stationID: String, userID: String) async {
        guard !updatingStationIDs.contains(stationID) else { return }
        updatingStationIDs.insert(stationID)
        defer { updatingStationIDs.remove(stationID) }

        #if canImport(FirebaseFirestore)
        let wasFavourite = stationIDs.contains(stationID)
        if wasFavourite {
            stationIDs.remove(stationID)
        } else {
            stationIDs.insert(stationID)
        }

        do {
            let value: FieldValue = wasFavourite
                ? FieldValue.arrayRemove([stationID])
                : FieldValue.arrayUnion([stationID])
            try await Firestore.firestore()
                .collection("users")
                .document(userID)
                .updateData([
                    "favouriteStationIDs": value,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            state = .loaded
            await NotificationService.shared.syncForCurrentPreferences(userID: userID)
        } catch {
            if wasFavourite {
                stationIDs.insert(stationID)
            } else {
                stationIDs.remove(stationID)
            }
            state = .failed(error.localizedDescription)
        }
        #else
        state = .failed("Firestore is not available in this build.")
        #endif
    }
}
