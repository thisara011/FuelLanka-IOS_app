import ActivityKit
import Foundation
import Observation

nonisolated struct FuelJourneyAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let status: String
        let endsAt: Date
    }

    let stationID: String
    let stationName: String
}

enum FuelJourneyError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Live Activities are disabled for FuelSmart LK on this device."
    }
}

@MainActor
@Observable
final class FuelJourneyController {
    private(set) var isActive = false
    private(set) var errorMessage: String?

    func refresh(stationID: String) {
        isActive = Activity<FuelJourneyAttributes>.activities.contains {
            $0.attributes.stationID == stationID && $0.activityState == .active
        }
    }

    func start(station: StationDetails) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            errorMessage = FuelJourneyError.unavailable.localizedDescription
            return
        }
        let endsAt = Date().addingTimeInterval(2 * 60 * 60)
        do {
            _ = try Activity.request(
                attributes: FuelJourneyAttributes(stationID: station.id, stationName: station.name),
                content: ActivityContent(
                    state: .init(status: "Travelling to station", endsAt: endsAt),
                    staleDate: endsAt
                ),
                pushType: nil
            )
            isActive = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func end(stationID: String) async {
        let activities = Activity<FuelJourneyAttributes>.activities.filter {
            $0.attributes.stationID == stationID
        }
        for activity in activities {
            let finalState = FuelJourneyAttributes.ContentState(
                status: "Journey finished",
                endsAt: .now
            )
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .after(.now.addingTimeInterval(60))
            )
        }
        isActive = false
    }

    func clearError() {
        errorMessage = nil
    }
}
