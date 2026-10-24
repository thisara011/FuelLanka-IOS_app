import SwiftUI

struct FavouritesView: View {
    let allStations: [StationDetails]
    let store: FavouriteStationStore
    let userID: String
    let onFindStations: () -> Void

    private var savedStations: [StationDetails] {
        allStations
            .filter { store.stationIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Saved stations")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)

                FavouriteStationContent(
                    stations: savedStations,
                    state: store.state,
                    store: store,
                    userID: userID
                )

                Button(action: onFindStations) {
                    Text("Find more stations")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.078, green: 0.337, blue: 0.604))
                .buttonBorderShape(.capsule)

                NavigationLink {
                    FuelComparisonView(stations: savedStations)
                } label: {
                    Label("Compare saved fuel prices", systemImage: "arrow.left.arrow.right")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(savedStations.isEmpty)

                Text("Your first saved station with a fuel report is synchronized to the FuelSmart widget.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(26)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await store.load(userID: userID) }
        .background(Color("WelcomeBackgroundTop"))
        .foregroundStyle(Color("WelcomeHeading"))
        .tint(Color("WelcomeAccent"))
        .navigationTitle("Favourites")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FavouriteStationContent: View {
    let stations: [StationDetails]
    let state: FavouriteStationState
    let store: FavouriteStationStore
    let userID: String

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView("Loading favourites…")
                .frame(maxWidth: .infinity, minHeight: 120)
        case .failed(let message):
            ContentUnavailableView {
                Label("Favourites unavailable", systemImage: "heart.slash")
            } description: {
                Text(message)
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        case .loaded where stations.isEmpty:
            ContentUnavailableView {
                Label("No saved stations", systemImage: "heart")
            } description: {
                Text("Open a station and select Save to favourites.")
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        case .loaded:
            ForEach(stations) { station in
                FavouriteStationRow(
                    station: station,
                    comparisonStations: stations,
                    store: store,
                    userID: userID,
                    isUpdating: store.updatingStationIDs.contains(station.id),
                    remove: {
                        Task {
                            await store.toggle(stationID: station.id, userID: userID)
                        }
                    }
                )
            }
        }
    }
}

private struct FavouriteStationRow: View {
    let station: StationDetails
    let comparisonStations: [StationDetails]
    let store: FavouriteStationStore
    let userID: String
    let isUpdating: Bool
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink {
                StationDetailsView(
                    station: station,
                    favourites: store,
                    userID: userID,
                    comparisonStations: comparisonStations
                )
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(station.name).font(.headline)
                    if let address = station.address {
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Label("View station reports", systemImage: "chevron.right")
                        .font(.footnote)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(role: .destructive, action: remove) {
                Image(systemName: "heart.slash")
                    .frame(width: 44, height: 44)
            }
            .disabled(isUpdating)
            .accessibilityLabel("Remove \(station.name) from favourites")
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

#Preview("Favourites") {
    NavigationStack {
        FavouritesView(
            allStations: [],
            store: FavouriteStationStore(),
            userID: "preview",
            onFindStations: {}
        )
    }
}
