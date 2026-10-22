import SwiftUI

enum ManagerTab: Hashable {
    case home, stock, activity, more
}

/// Present only after server-authorized manager routing. This view does not grant access.
struct ManagerWorkspaceView: View {
    let authentication: AuthenticationSession
    @State private var stationStore = ManagerStationStore()
    @State private var selectedTab: ManagerTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                NavigationStack {
                    ManagerDashboardView(
                        station: stationStore.station,
                        records: stationStore.records,
                        alerts: stationStore.alerts,
                        state: stationStore.state,
                        onUpdateStock: { selectedTab = .stock },
                        onRecordSale: { selectedTab = .activity },
                        publishPrices: { changes in
                            try await stationStore.updatePrices(changes: changes)
                        },
                        recordDelivery: { draft in
                            try await stationStore.recordDelivery(draft: draft)
                        }
                    )
                }
            }
            Tab("Stock", systemImage: "shippingbox", value: .stock) {
                NavigationStack {
                    ManagerStockUpdateView(station: stationStore.station) { changes in
                        try await stationStore.updateStock(changes: changes)
                    }
                }
            }
            Tab("Activity", systemImage: "chart.bar", value: .activity) {
                NavigationStack {
                    ManagerSalesHistoryView(
                        station: stationStore.station,
                        state: .loaded(stationStore.records)
                    ) { draft in
                        try await stationStore.recordSale(draft: draft)
                    }
                }
            }
            Tab("More", systemImage: "ellipsis.circle", value: .more) {
                NavigationStack {
                    List {
                        NavigationLink("Assigned station") {
                            StationDetailsView(station: stationStore.station)
                        }
                        NavigationLink("Fuel prices") {
                            ManagerFuelPricesView(station: stationStore.station) { changes in
                                try await stationStore.updatePrices(changes: changes)
                            }
                        }
                        NavigationLink("Deliveries") {
                            ManagerDeliveriesView(
                                station: stationStore.station,
                                state: .loaded(stationStore.records)
                            ) { draft in
                                try await stationStore.recordDelivery(draft: draft)
                            }
                        }
                        if let stationID = stationStore.station?.id,
                           let reviewerID = authentication.currentAccount?.id {
                            NavigationLink("Customer reports") {
                                CommunityReportReviewView(
                                    stationID: stationID,
                                    reviewerID: reviewerID
                                )
                            }
                        }
                        NavigationLink("Notifications") {
                            ManagerNotificationsView(
                                station: stationStore.station,
                                state: .loaded(stationStore.alerts),
                                updateStock: { changes in
                                    try await stationStore.updateStock(changes: changes)
                                },
                                publishPrices: { changes in
                                    try await stationStore.updatePrices(changes: changes)
                                },
                                recordDelivery: { draft in
                                    try await stationStore.recordDelivery(draft: draft)
                                }
                            )
                        }
                        NavigationLink("Analytics") {
                            ManagerAnalyticsView(
                                station: stationStore.station,
                                state: .loaded(stationStore.records)
                            )
                        }
                        NavigationLink("Manager profile") {
                            ManagerProfileView(
                                authentication: authentication,
                                station: stationStore.station,
                                profile: stationStore.profile,
                                alerts: stationStore.alerts,
                                records: stationStore.records,
                                updateStock: { changes in
                                    try await stationStore.updateStock(changes: changes)
                                },
                                publishPrices: { changes in
                                    try await stationStore.updatePrices(changes: changes)
                                },
                                recordDelivery: { draft in
                                    try await stationStore.recordDelivery(draft: draft)
                                },
                                saveProfile: { fullName, phone in
                                    try await stationStore.updateProfile(fullName: fullName, phone: phone)
                                }
                            )
                        }
                    }
                    .navigationTitle("More")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .tint(Color("WelcomeAccent"))
        .task(id: authentication.currentAccount?.id) {
            guard let userID = authentication.currentAccount?.id else { return }
            await stationStore.load(userID: userID)
        }
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
