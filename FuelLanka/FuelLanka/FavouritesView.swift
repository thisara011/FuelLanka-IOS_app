import SwiftUI

/// Nil represents unavailable account data; an empty array represents no saved stations.
struct FavouritesView: View {
    var stations: [StationDetails]? = nil
    let onFindStations: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Saved stations")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)

                if let stations, !stations.isEmpty {
                    ForEach(stations) { station in
                        NavigationLink {
                            StationDetailsView(station: station)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(station.name).font(.headline)
                                if let address = station.address {
                                    Text(address).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Label("View station reports", systemImage: "chevron.right")
                                    .font(.footnote)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(18)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ContentUnavailableView {
                        Label(stations == nil ? "Favourites unavailable" : "No saved stations", systemImage: "heart")
                    } description: {
                        Text(stations == nil
                             ? "Your account’s saved stations cannot be loaded yet."
                             : "Save stations from their details to find them here.")
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
                }

                Button {
                    onFindStations()
                } label: {
                    Text("Find more stations")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.078, green: 0.337, blue: 0.604))
                .buttonBorderShape(.capsule)

                NavigationLink {
                    FuelComparisonView(stations: stations)
                } label: {
                    Label("Compare saved fuel prices", systemImage: "arrow.left.arrow.right")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.bordered)

                Text("Favourite widgets will be available in a later update.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(26)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background(Color("WelcomeBackgroundTop"))
        .foregroundStyle(Color("WelcomeHeading"))
        .tint(Color("WelcomeAccent"))
        .navigationTitle("Favourites")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Favourites") {
    NavigationStack { FavouritesView(onFindStations: {}) }
}
