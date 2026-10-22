import SwiftUI
import WidgetKit

private struct FavouriteStationSnapshot: Codable, Equatable {
    let stationID: String
    let stationName: String
    let fuelName: String
    let availability: String?
    let price: Double?
    let reportedAt: Date?
    let isStale: Bool
}

private struct FavouriteStationEntry: TimelineEntry {
    let date: Date
    let snapshot: FavouriteStationSnapshot?
}

private struct FavouriteStationProvider: TimelineProvider {
    private let appGroupID = "group.thisara.FuelLanka"
    private let snapshotKey = "favouriteStationWidgetSnapshot"

    func placeholder(in context: Context) -> FavouriteStationEntry {
        FavouriteStationEntry(
            date: .now,
            snapshot: FavouriteStationSnapshot(
                stationID: "preview",
                stationName: "Favourite station",
                fuelName: "Petrol 92",
                availability: "Availability unknown",
                price: nil,
                reportedAt: nil,
                isStale: true
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FavouriteStationEntry) -> Void) {
        completion(FavouriteStationEntry(date: .now, snapshot: context.isPreview ? placeholder(in: context).snapshot : load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavouriteStationEntry>) -> Void) {
        let entry = FavouriteStationEntry(date: .now, snapshot: load())
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func load() -> FavouriteStationSnapshot? {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(FavouriteStationSnapshot.self, from: data)
    }
}

private struct FavouriteStationWidgetView: View {
    let entry: FavouriteStationEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            FavouriteStationWidgetContent(snapshot: snapshot)
                .widgetURL(URL(string: "fuelsmart://station?id=\(snapshot.stationID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"))
        } else {
            FavouriteStationWidgetEmptyState()
                .widgetURL(URL(string: "fuelsmart://station"))
        }
    }
}

private struct FavouriteStationWidgetContent: View {
    let snapshot: FavouriteStationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("FuelSmart LK", systemImage: "fuelpump.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(snapshot.stationName)
                .font(.headline)
                .lineLimit(2)
            HStack {
                Text(snapshot.fuelName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let price = snapshot.price {
                    Text(price, format: .currency(code: "LKR").precision(.fractionLength(0)))
                        .font(.caption.weight(.semibold))
                }
            }
            Text(snapshot.isStale ? "Report is stale" : (snapshot.availability ?? "Availability unknown"))
                .font(.caption)
                .foregroundStyle(snapshot.isStale ? .orange : .primary)
            if let reportedAt = snapshot.reportedAt {
                Text(reportedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Update time unavailable")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct FavouriteStationWidgetEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "fuelpump")
                .font(.title2)
            Text("Choose a favourite")
                .font(.headline)
            Text("Open FuelSmart LK and save a station to show its latest report here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct FuelLankaWidgets: Widget {
    let kind = "FavouriteStationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavouriteStationProvider()) { entry in
            FavouriteStationWidgetView(entry: entry)
        }
        .configurationDisplayName("Favourite fuel station")
        .description("Shows the last report saved for your favourite station.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    FuelLankaWidgets()
} timeline: {
    FavouriteStationEntry(date: .now, snapshot: nil)
}
