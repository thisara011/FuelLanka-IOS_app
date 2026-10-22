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
    @State private var favouriteStore = FavouriteStationStore()
    @State private var notificationRouter = NotificationRouter.shared
    @State private var findPath: [StationDetails] = []

    private var userID: String {
        authentication.currentAccount?.id ?? ""
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                NavigationStack {
                    CustomerHomeView(
                        stationStore: stationStore,
                        favouriteStore: favouriteStore,
                        userID: userID,
                        onFindStations: { selectedTab = .find },
                        onViewOutlook: { selectedTab = .predict }
                    )
                }
            }
            Tab("Find", systemImage: "magnifyingglass", value: .find) {
                NavigationStack(path: $findPath) {
                    FindFuelView(
                        stationStore: stationStore,
                        favouriteStore: favouriteStore,
                        userID: userID
                    )
                }
            }
            Tab("Map", systemImage: "map", value: .map) {
                NavigationStack {
                    StationMapView(
                        stations: stationStore.state == .loaded ? stationStore.stations : nil,
                        favourites: favouriteStore,
                        userID: userID,
                        onListView: { selectedTab = .find }
                    )
                }
            }
            Tab("Predict", systemImage: "chart.line.uptrend.xyaxis", value: .predict) {
                NavigationStack {
                    CustomerPredictionView(stationStore: stationStore)
                }
            }
            Tab("Profile", systemImage: "person", value: .profile) {
                NavigationStack {
                    CustomerProfileView(
                        authentication: authentication,
                        stationStore: stationStore,
                        favouriteStore: favouriteStore,
                        onFindStations: { selectedTab = .find }
                    )
                }
            }
        }
        .tint(Color("WelcomeAccent"))
        .overlay {
            WidgetSnapshotSynchronizer(
                stations: stationStore.stations,
                favouriteIDs: favouriteStore.stationIDs
            )
        }
        .task(id: userID) {
            guard !userID.isEmpty else { return }
            async let stations: Void = stationStore.load()
            async let favourites: Void = favouriteStore.load(userID: userID)
            _ = await (stations, favourites)
            await NotificationService.shared.syncForCurrentPreferences(
                userID: userID,
                stations: stationStore.stations
            )
            openPendingNotification()
        }
        .onChange(of: notificationRouter.pendingRoute) {
            openPendingNotification()
        }
    }

    private func openPendingNotification() {
        guard let route = notificationRouter.pendingRoute,
              let station = stationStore.stations.first(where: { $0.id == route.stationID }) else {
            return
        }
        selectedTab = .find
        findPath = [station]
        notificationRouter.consume()
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
