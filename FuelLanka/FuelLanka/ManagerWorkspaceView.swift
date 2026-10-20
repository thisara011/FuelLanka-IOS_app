import SwiftUI

enum ManagerTab: Hashable {
    case home, stock, activity, more
}

/// Present only after server-authorized manager routing. This view does not grant access.
struct ManagerWorkspaceView: View {
    let authentication: AuthenticationSession
    var assignedStation: StationDetails? = nil
    @State private var selectedTab: ManagerTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                NavigationStack {
                    ManagerDashboardView(station: assignedStation) {
                        selectedTab = .stock
                    }
                }
            }
            Tab("Stock", systemImage: "shippingbox", value: .stock) {
                NavigationStack {
                    ManagerStockUpdateView(station: assignedStation)
                }
            }
            Tab("Activity", systemImage: "chart.bar", value: .activity) {
                NavigationStack {
                    ManagerSalesHistoryView(station: assignedStation)
                }
            }
            Tab("More", systemImage: "ellipsis.circle", value: .more) {
                NavigationStack {
                    List {
                        NavigationLink("Assigned station") {
                            StationDetailsView(station: assignedStation)
                        }
                        NavigationLink("Fuel prices") {
                            ManagerFuelPricesView(station: assignedStation)
                        }
                        NavigationLink("Deliveries") {
                            ManagerDeliveriesView(station: assignedStation)
                        }
                        NavigationLink("Notifications") {
                            ManagerNotificationsView(station: assignedStation)
                        }
                        NavigationLink("Analytics") {
                            ManagerAnalyticsView(station: assignedStation)
                        }
                        NavigationLink("Manager profile") {
                            ManagerProfileView(
                                authentication: authentication,
                                station: assignedStation
                            )
                        }
                    }
                    .navigationTitle("More")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .tint(Color("WelcomeAccent"))
    }
}

struct ManagerUnavailableView: View {
    let title: LocalizedStringKey
    let symbol: String
    let message: LocalizedStringKey

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Manager Dashboard") {
    ManagerWorkspaceView(authentication: AuthenticationSession())
}
