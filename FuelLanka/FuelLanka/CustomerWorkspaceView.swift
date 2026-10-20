import SwiftUI

enum CustomerTab: Hashable {
    case home, find, map, predict, profile
}

/// Customer workspace presentation. The authentication coordinator must authorize
/// the customer role before presenting this view; it does not create a session.
struct CustomerWorkspaceView: View {
    let authentication: AuthenticationSession
    @State private var selectedTab: CustomerTab = .home
    @State private var stationStore = StationStore()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                NavigationStack {
                    CustomerHomeView(
                        stationStore: stationStore,
                        onFindStations: { selectedTab = .find },
                        onViewOutlook: { selectedTab = .predict }
                    )
                }
            }
            Tab("Find", systemImage: "magnifyingglass", value: .find) {
                NavigationStack {
                    FindFuelView()
                }
            }
            Tab("Map", systemImage: "map", value: .map) {
                NavigationStack {
                    StationMapView(onListView: { selectedTab = .find })
                }
            }
            Tab("Predict", systemImage: "chart.line.uptrend.xyaxis", value: .predict) {
                CustomerPendingDestination(
                    title: "Predictions",
                    symbol: "chart.line.uptrend.xyaxis",
                    message: "Forecasts are unavailable. Reliable estimates require recent station reports and a validated model."
                )
            }
            Tab("Profile", systemImage: "person", value: .profile) {
                NavigationStack {
                    CustomerProfileView(
                        authentication: authentication,
                        onFindStations: { selectedTab = .find }
                    )
                }
            }
        }
        .tint(Color("WelcomeAccent"))
    }
}

private struct CustomerPendingDestination: View {
    let title: LocalizedStringKey
    let symbol: String
    let message: LocalizedStringKey

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(title, systemImage: symbol)
            } description: {
                Text(message)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview("Customer Home") {
    CustomerWorkspaceView(authentication: AuthenticationSession())
}

#Preview("Customer Home Dark") {
    CustomerWorkspaceView(authentication: AuthenticationSession())
        .preferredColorScheme(.dark)
}

#Preview("Customer Home Large Text") {
    CustomerWorkspaceView(authentication: AuthenticationSession())
        .environment(\.dynamicTypeSize, .accessibility3)
}
