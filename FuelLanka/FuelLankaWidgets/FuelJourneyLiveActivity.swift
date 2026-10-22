import ActivityKit
import SwiftUI
import WidgetKit

nonisolated struct FuelJourneyAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let status: String
        let endsAt: Date
    }

    let stationID: String
    let stationName: String
}

struct FuelJourneyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FuelJourneyAttributes.self) { context in
            FuelJourneyLockScreenView(
                stationName: context.attributes.stationName,
                status: context.state.status,
                endsAt: context.state.endsAt,
                isStale: context.isStale
            )
            .activityBackgroundTint(Color(red: 0.06, green: 0.16, blue: 0.26))
            .activitySystemActionForegroundColor(.white)
            .widgetURL(stationURL(id: context.attributes.stationID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "fuelpump.fill")
                        .foregroundStyle(.cyan)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: .now...context.state.endsAt, countsDown: true)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.stationName)
                            .font(.headline)
                        Text("Latest reports may change before arrival")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "fuelpump.fill")
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                Text(timerInterval: .now...context.state.endsAt, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 42)
            } minimal: {
                Image(systemName: "fuelpump.fill")
                    .foregroundStyle(.cyan)
            }
            .widgetURL(stationURL(id: context.attributes.stationID))
            .keylineTint(.cyan)
        }
    }

    private func stationURL(id: String) -> URL? {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "fuelsmart://station?id=\(encoded)")
    }
}

private struct FuelJourneyLockScreenView: View {
    let stationName: String
    let status: String
    let endsAt: Date
    let isStale: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "fuelpump.fill")
                .font(.title2)
                .foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 4) {
                Text(stationName)
                    .font(.headline)
                    .lineLimit(1)
                Text(isStale ? "Journey update expired" : status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(timerInterval: .now...endsAt, countsDown: true)
                .font(.headline)
                .monospacedDigit()
        }
        .padding()
    }
}
