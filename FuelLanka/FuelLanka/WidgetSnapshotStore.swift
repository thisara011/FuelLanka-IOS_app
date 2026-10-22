import Foundation
import SwiftUI
import WidgetKit

struct FavouriteStationWidgetSnapshot: Codable, Equatable, Sendable {
    let stationID: String
    let stationName: String
    let fuelName: String
    let availability: String?
    let price: Double?
    let reportedAt: Date?
    let isStale: Bool
}

enum WidgetSnapshotStore {
    static let appGroupID = "group.thisara.FuelLanka"
    static let snapshotKey = "favouriteStationWidgetSnapshot"
    static let widgetKind = "FavouriteStationWidget"

    static func synchronize(stations: [StationDetails], favouriteIDs: Set<String>) {
        let defaults = UserDefaults(suiteName: appGroupID)
        guard let station = stations.first(where: { favouriteIDs.contains($0.id) }),
              let report = preferredReport(for: station) else {
            defaults?.removeObject(forKey: snapshotKey)
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
            return
        }

        let snapshot = FavouriteStationWidgetSnapshot(
            stationID: station.id,
            stationName: station.name,
            fuelName: String(localized: report.fuel.title),
            availability: report.availability.map { String(localized: $0.title) },
            price: report.pricePerLitre.map { NSDecimalNumber(decimal: $0).doubleValue },
            reportedAt: report.reportedAt,
            isStale: report.isStale
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: snapshotKey)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    private static func preferredReport(for station: StationDetails) -> StationFuelReport? {
        let latestByFuel = Dictionary(grouping: station.reports, by: \.fuel)
            .compactMapValues { reports in
                reports.max { ($0.reportedAt ?? .distantPast) < ($1.reportedAt ?? .distantPast) }
            }
        return latestByFuel[.petrol92]
            ?? latestByFuel.values.max { ($0.reportedAt ?? .distantPast) < ($1.reportedAt ?? .distantPast) }
    }
}

struct WidgetSnapshotSynchronizer: View {
    let stations: [StationDetails]
    let favouriteIDs: Set<String>

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: SynchronizationID(stations: stations, favouriteIDs: favouriteIDs)) {
                WidgetSnapshotStore.synchronize(stations: stations, favouriteIDs: favouriteIDs)
            }
    }
}

private struct SynchronizationID: Hashable {
    let favouriteIDs: Set<String>
    let reportIDs: Set<String>

    init(stations: [StationDetails], favouriteIDs: Set<String>) {
        self.favouriteIDs = favouriteIDs
        reportIDs = Set(stations.flatMap { $0.reports.map(\.id) })
    }
}
