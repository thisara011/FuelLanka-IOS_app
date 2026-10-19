import SwiftUI

struct CustomerHomeView: View {
    let onFindStations: () -> Void
    let onViewOutlook: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Location not selected")
                    .font(.footnote)
                    .foregroundStyle(Color("WelcomeSecondary"))

                Button(action: onFindStations) {
                    Label("Search station, city or district", systemImage: "magnifyingglass")
                        .font(.subheadline)
                        .foregroundStyle(Color("WelcomeSecondary"))
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .padding(.horizontal, 18)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.search")

                NearbyFuelSummary()

                NavigationLink {
                    FavouritesView(onFindStations: onFindStations)
                } label: {
                    Label("Favourite stations", systemImage: "heart")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.bordered)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Availability now")
                            .font(.title3.bold())
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button("See all", action: onFindStations)
                            .font(.footnote.weight(.semibold))
                            .frame(minHeight: 44)
                    }
                    HomeInformationCard(
                        title: "Stock reports unavailable",
                        message: "Current fuel availability cannot be confirmed. Station reports will show their source and last update."
                    )
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Nearby stations")
                        .font(.title3.bold())
                        .accessibilityAddTraits(.isHeader)
                    HomeInformationCard(
                        title: "Station information unavailable",
                        message: "Nearby stations, distances and opening hours cannot be loaded yet."
                    )
                }

                Button(action: onViewOutlook) {
                    HomeOutlookCard()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.outlook")
            }
            .foregroundStyle(Color("WelcomeHeading"))
            .padding(.horizontal, 26)
            .padding(.vertical, 12)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background {
            LinearGradient(
                colors: [Color("WelcomeBackgroundTop"), Color("WelcomeBackgroundBottom")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .navigationTitle("Welcome")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ContentUnavailableView {
                        Label("Notifications", systemImage: "bell")
                    } description: {
                        Text("Notifications are not available yet.")
                    }
                    .navigationTitle("Notifications")
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Notifications", systemImage: "bell")
                }
                .accessibilityIdentifier("home.notifications")
            }
        }
    }
}

private struct NearbyFuelSummary: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fuel near you")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            Text("Station reports are not available yet.")
                .font(.subheadline)
            Label("Availability unknown", systemImage: "questionmark.circle")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.16), in: Capsule())
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 25)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.078, green: 0.235, blue: 0.455),
                        Color(red: 0.078, green: 0.337, blue: 0.604),
                        Color(red: 0.075, green: 0.482, blue: 0.576)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HomeInformationCard: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color("WelcomeSecondary"))
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }
}

private struct HomeOutlookCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tomorrow’s outlook")
                .font(.subheadline.bold())
                .foregroundStyle(Color("WelcomeAccent"))
            Text("Forecast unavailable")
                .font(.subheadline.weight(.semibold))
            Text("Estimates will appear only when recent reports and a validated model are available.")
                .font(.footnote)
                .foregroundStyle(Color("WelcomeSecondary"))
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color("WelcomeAccent").opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
    }
}
