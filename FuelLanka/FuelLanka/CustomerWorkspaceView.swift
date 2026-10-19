import SwiftUI

enum CustomerTab: Hashable {
    case home, find, map, predict, profile
}

/// Customer workspace presentation. The authentication coordinator must authorize
/// the customer role before presenting this view; it does not create a session.
struct CustomerWorkspaceView: View {
    @State private var selectedTab: CustomerTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                NavigationStack {
                    CustomerHomeView(
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
                CustomerPendingDestination(
                    title: "Profile",
                    symbol: "person",
                    message: "Account details will be available after account services are connected."
                )
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
    CustomerWorkspaceView()
}

#Preview("Customer Home Dark") {
    CustomerWorkspaceView()
        .preferredColorScheme(.dark)
}

#Preview("Customer Home Large Text") {
    CustomerWorkspaceView()
        .environment(\.dynamicTypeSize, .accessibility3)
}
