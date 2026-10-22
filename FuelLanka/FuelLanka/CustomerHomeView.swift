import SwiftUI

struct CustomerHomeView: View {
    let stationStore: StationStore
    let favouriteStore: FavouriteStationStore
    let userID: String
    let onFindStations: () -> Void
    let onViewOutlook: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HomeLocationBanner()
                HomeSearchButton(action: onFindStations)
                FuelNetworkSummary(
                    stationCount: stationStore.stations.count,
                    availableReportCount: availableReportCount,
                    state: stationStore.state
                )
                NavigationLink {
                    FavouritesView(
                        allStations: stationStore.stations,
                        store: favouriteStore,
                        userID: userID,
                        onFindStations: onFindStations
                    )
                } label: {
                    Label("Favourite stations", systemImage: "heart")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.bordered)

                StationAvailabilitySection(
                    stations: stationStore.stations,
                    state: stationStore.state,
                    favouriteStore: favouriteStore,
                    userID: userID,
                    onSeeAll: onFindStations,
                    onRetry: reload
                )

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
        .refreshable { await stationStore.load() }
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
                    CustomerNotificationsView()
                } label: {
                    Label("Notifications", systemImage: "bell")
                }
                .accessibilityIdentifier("home.notifications")
            }
        }
        .task {
            if stationStore.state == .idle {
                await stationStore.load()
            }
        }
    }

    private var availableReportCount: Int {
        stationStore.stations.reduce(into: 0) { count, station in
            count += station.reports.filter {
                !$0.isStale && $0.availability == .available
            }.count
        }
    }

    private func reload() {
        Task { await stationStore.load() }
    }
}

private struct HomeLocationBanner: View {
    var body: some View {
        Label("Sri Lanka station network", systemImage: "location")
            .font(.footnote)
            .foregroundStyle(Color("WelcomeSecondary"))
    }
}

private struct HomeSearchButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Search station, city or district", systemImage: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(Color("WelcomeSecondary"))
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .padding(.horizontal, 18)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.search")
    }
}

private struct FuelNetworkSummary: View {
    let stationCount: Int
    let availableReportCount: Int
    let state: StationLoadingState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fuel network")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)

            switch state {
            case .idle, .loading:
                ProgressView("Loading station reports…")
                    .tint(.white)
            case .failed:
                Label("Live reports unavailable", systemImage: "wifi.exclamationmark")
            case .loaded:
                Text("\(stationCount) stations loaded")
                    .font(.subheadline)
                Label(
                    "\(availableReportCount) current availability reports",
                    systemImage: availableReportCount > 0 ? "checkmark.circle.fill" : "questionmark.circle"
                )
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.16), in: Capsule())
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 25)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.078, green: 0.235, blue: 0.455),
                            Color(red: 0.078, green: 0.337, blue: 0.604),
                            Color(red: 0.075, green: 0.482, blue: 0.576)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StationAvailabilitySection: View {
    let stations: [StationDetails]
    let state: StationLoadingState
    let favouriteStore: FavouriteStationStore
    let userID: String
    let onSeeAll: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Station availability")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("See all", action: onSeeAll)
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: 44)
            }

            switch state {
            case .idle, .loading:
                ProgressView("Loading stations…")
                    .frame(maxWidth: .infinity, minHeight: 120)
            case .failed(let message):
                HomeLoadingFailure(message: message, onRetry: onRetry)
            case .loaded where stations.isEmpty:
                ContentUnavailableView {
                    Label("No stations yet", systemImage: "fuelpump")
                } description: {
                    Text("Add station documents to the Firestore stations collection.")
                }
                .homeCard()
            case .loaded:
                ForEach(stations.prefix(3)) { station in
                    NavigationLink {
                        StationDetailsView(
                            station: station,
                            favourites: favouriteStore,
                            userID: userID
                        )
                    } label: {
                        HomeStationCard(station: station)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct HomeStationCard: View {
    let station: StationDetails

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "fuelpump.fill")
                .font(.title2)
                .foregroundStyle(Color("WelcomeAccent"))
                .frame(width: 42, height: 42)
                .background(Color("WelcomeAccent").opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(station.name)
                    .font(.headline)
                Text(station.address ?? station.operatorName ?? "Address unavailable")
                    .font(.subheadline)
                    .foregroundStyle(Color("WelcomeSecondary"))
                StationReportSummary(reports: station.reports)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .homeCard()
        .accessibilityElement(children: .combine)
    }
}

private struct StationReportSummary: View {
    let reports: [StationFuelReport]

    var body: some View {
        if let latest = reports.max(by: {
            ($0.reportedAt ?? .distantPast) < ($1.reportedAt ?? .distantPast)
        }) {
            Label(
                latest.isStale ? "Report is stale" : availabilityText(latest.availability),
                systemImage: latest.isStale ? "clock.badge.exclamationmark" : "checkmark.circle"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(latest.isStale ? .orange : Color("WelcomeAccent"))
        } else {
            Label("No fuel reports", systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func availabilityText(_ availability: ReportedAvailability?) -> String {
        switch availability {
        case .available: "Fuel reported available"
        case .limited: "Fuel reported limited"
        default: "Availability unknown"
        }
    }
}

private struct HomeLoadingFailure: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Could not load stations", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color("WelcomeSecondary"))
            Button("Try again", action: onRetry)
                .buttonStyle(.bordered)
        }
        .homeCard()
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
        .homeCard()
    }
}

private extension View {
    func homeCard() -> some View {
        self
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

#Preview("Customer Home") {
    NavigationStack {
        CustomerHomeView(
            stationStore: StationStore(),
            favouriteStore: FavouriteStationStore(),
            userID: "preview",
            onFindStations: {},
            onViewOutlook: {}
        )
    }
}
