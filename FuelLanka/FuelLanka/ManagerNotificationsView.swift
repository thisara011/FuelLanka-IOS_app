import SwiftUI

struct ManagerAlert: Identifiable {
    enum Destination {
        case stock, deliveries, prices, forecast, station
    }
    let id: String
    let stationID: String
    let title: String
    let message: String
    let reportedAt: Date?
    let requiresAction: Bool
    let destination: Destination
}

enum ManagerAlertsState {
    case loading
    case unavailable
    case loaded([ManagerAlert])
}

struct ManagerNotificationsView: View {
    let station: StationDetails?
    var state: ManagerAlertsState = .unavailable

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Station alerts and updates").font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(station?.name ?? "Station assignment unavailable")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let station {
                    switch state {
                    case .loading:
                        ProgressView("Loading station alerts…")
                            .frame(maxWidth: .infinity, minHeight: 120)
                    case .unavailable:
                        ContentUnavailableView("Alerts unavailable", systemImage: "bell.slash",
                                               description: Text("Operational notifications cannot be loaded yet."))
                    case .loaded(let alerts):
                        let scoped = alerts.filter { $0.stationID == station.id }.sorted {
                            ($0.reportedAt ?? .distantPast) > ($1.reportedAt ?? .distantPast)
                        }
                        if scoped.isEmpty {
                            ContentUnavailableView("No station alerts", systemImage: "bell",
                                                   description: Text("There are no alerts for your assigned station."))
                        } else {
                            ForEach(scoped) { alert in
                                NavigationLink {
                                    ManagerAlertDetailsView(alert: alert, station: station)
                                } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(alert.title).font(.headline)
                                            .foregroundStyle(Color("WelcomeHeading"))
                                        if alert.requiresAction {
                                            Label("Action needed", systemImage: "exclamationmark.circle")
                                                .font(.footnote).foregroundStyle(.red)
                                        }
                                        Text(alert.message).font(.subheadline).foregroundStyle(.secondary)
                                        if let date = alert.reportedAt {
                                            Text(date, format: .dateTime.day().month().year().hour().minute())
                                                .font(.footnote).foregroundStyle(.secondary)
                                        } else {
                                            Text("Alert time unavailable").font(.footnote).foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(18)
                                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("Station assignment required", systemImage: "building.2",
                                           description: Text("Your authorized station assignment is needed to load operational alerts."))
                }
                Text("Alerts describe earlier reports. Check current inventory or delivery records before taking action.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background(Color("WelcomeBackgroundTop"))
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("WelcomeAccent"))
    }
}

private struct ManagerAlertDetailsView: View {
    let alert: ManagerAlert
    let station: StationDetails

    var body: some View {
        List {
            Section {
                Text(alert.title).font(.title3.bold())
                Text(alert.message)
                Text(station.name).foregroundStyle(.secondary)
                if let date = alert.reportedAt {
                    Text(date, format: .dateTime.day().month().year().hour().minute())
                }
            }
            Section {
                switch alert.destination {
                case .stock:
                    NavigationLink("Review stock") { ManagerStockUpdateView(station: station) }
                case .deliveries:
                    NavigationLink("Review deliveries") { ManagerDeliveriesView(station: station) }
                case .prices:
                    NavigationLink("Review fuel prices") { ManagerFuelPricesView(station: station) }
                case .station:
                    NavigationLink("Station details") { StationDetailsView(station: station) }
                case .forecast:
                    Text("Forecast unavailable. Recent reports and a validated model are required.")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Opening an alert does not confirm a delivery or change stock or prices.")
            }
        }
        .navigationTitle("Alert details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Manager Notifications") {
    NavigationStack { ManagerNotificationsView(station: nil) }
}
