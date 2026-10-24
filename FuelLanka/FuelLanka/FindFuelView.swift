import SwiftUI

struct FindFuelView: View {
    let stationStore: StationStore
    let favouriteStore: FavouriteStationStore
    let userID: String
    @State private var query = ""
    @State private var filters = FuelSearchFilters()
    @State private var showsFilters = false

    private var results: [StationDetails] {
        let normalized = filters.normalized()
        let searchText = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return stationStore.stations
            .filter { station in
                matchesText(searchText, station: station) &&
                    matchesLocation(normalized, station: station) &&
                    matchesFuel(normalized, station: station)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Search stations across Sri Lanka")
                    .font(.subheadline)
                    .foregroundStyle(Color("WelcomeSecondary"))

                FuelQuickFilters(filters: $filters, onMoreFilters: { showsFilters = true })

                if filters.hasFilters || !query.isEmpty {
                    SearchCriteriaSummary(query: query, filters: filters)
                    Button("Clear search and filters") {
                        query = ""
                        filters = FuelSearchFilters()
                    }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("find.clear")
                }

                StationSearchResults(
                    stations: results,
                    state: stationStore.state,
                    selectedFuel: filters.fuel,
                    onRetry: reload
                )

                Text("Reported stock and forecasts are different. Check the source and update time before travelling.")
                    .font(.footnote)
                    .foregroundStyle(Color("WelcomeSecondary"))
            }
            .padding(26)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await stationStore.load() }
        .background {
            LinearGradient(
                colors: [Color("WelcomeBackgroundTop"), Color("WelcomeBackgroundBottom")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .navigationDestination(for: StationDetails.self) { station in
            StationDetailsView(
                station: station,
                favourites: favouriteStore,
                userID: userID,
                comparisonStations: stationStore.stations
            )
        }
        .navigationTitle("Find Fuel")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Station, city or district"
        )
        .tint(Color("WelcomeAccent"))
        .sheet(isPresented: $showsFilters) {
            FuelSearchFiltersView(initialFilters: filters) { filters = $0 }
        }
        .task {
            if stationStore.state == .idle {
                await stationStore.load()
            }
        }
    }

    private func matchesText(_ text: String, station: StationDetails) -> Bool {
        guard !text.isEmpty else { return true }
        return [station.name, station.address, station.operatorName]
            .compactMap { $0 }
            .contains { $0.localizedCaseInsensitiveContains(text) }
    }

    private func matchesLocation(_ filters: FuelSearchFilters, station: StationDetails) -> Bool {
        let searchable = [station.name, station.address, station.operatorName]
            .compactMap { $0 }
            .joined(separator: " ")
        return [filters.province, filters.district, filters.city]
            .filter { !$0.isEmpty }
            .allSatisfy { searchable.localizedCaseInsensitiveContains($0) }
    }

    private func matchesFuel(_ filters: FuelSearchFilters, station: StationDetails) -> Bool {
        guard filters.fuel != .any || filters.availability != .any else { return true }

        let fuels = filters.fuel == .any
            ? FuelGrade.allCases.filter { $0 != .any }
            : [filters.fuel]

        return fuels.contains { fuel in
            guard let report = station.reports
                .filter({ $0.fuel == fuel })
                .max(by: { ($0.reportedAt ?? .distantPast) < ($1.reportedAt ?? .distantPast) }) else {
                return false
            }
            guard filters.availability != .any else { return true }
            return !report.isStale && report.availability == filters.availability
        }
    }

    private func reload() {
        Task { await stationStore.load() }
    }
}

private struct StationSearchResults: View {
    let stations: [StationDetails]
    let state: StationLoadingState
    let selectedFuel: FuelGrade
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch state {
            case .idle, .loading:
                ProgressView("Loading stations…")
                    .frame(maxWidth: .infinity, minHeight: 140)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Stations unavailable", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again", action: onRetry)
                }
            case .loaded where stations.isEmpty:
                ContentUnavailableView {
                    Label("No matching stations", systemImage: "magnifyingglass")
                } description: {
                    Text("Try a different station name, area, fuel type, or availability filter.")
                }
            case .loaded:
                HStack {
                    Text("Stations")
                        .font(.title3.bold())
                    Spacer()
                    Text(stations.count, format: .number)
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }
                ForEach(stations) { station in
                    NavigationLink(value: station) {
                        StationSearchRow(station: station, selectedFuel: selectedFuel)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct StationSearchRow: View {
    let station: StationDetails
    let selectedFuel: FuelGrade

    private var report: StationFuelReport? {
        let reports = selectedFuel == .any
            ? station.reports
            : station.reports.filter { $0.fuel == selectedFuel }
        return reports.max {
            ($0.reportedAt ?? .distantPast) < ($1.reportedAt ?? .distantPast)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name)
                        .font(.headline)
                    Text(station.address ?? station.operatorName ?? "Address unavailable")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color("WelcomeAccent"))
                    .accessibilityHidden(true)
            }

            if let report {
                HStack(spacing: 12) {
                    Label(String(localized: report.fuel.title), systemImage: "fuelpump")
                    if let price = report.pricePerLitre {
                        Text(price, format: .currency(code: "LKR"))
                    }
                    if let stock = report.stockLitres {
                        Text("\(stock.formatted()) L")
                    }
                }
                .font(.footnote)
                .foregroundStyle(report.isStale ? .secondary : Color("WelcomeHeading"))
                if let date = report.reportedAt {
                    Text(report.isStale ? "Stale report · \(date.formatted(date: .abbreviated, time: .shortened))" :
                            "Updated \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No current fuel report")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct FuelQuickFilters: View {
    @Binding var filters: FuelSearchFilters
    let onMoreFilters: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                FuelGradePicker(selection: $filters.fuel)
                AvailabilityPicker(selection: $filters.availability)
                Button(action: onMoreFilters) {
                    Label("Filters", systemImage: "line.3.horizontal.decrease")
                }
                .frame(minHeight: 44)
            }
            VStack(alignment: .leading, spacing: 8) {
                FuelGradePicker(selection: $filters.fuel)
                AvailabilityPicker(selection: $filters.availability)
                Button(action: onMoreFilters) {
                    Label("Filters", systemImage: "line.3.horizontal.decrease")
                }
                .frame(minHeight: 44)
            }
        }
        .buttonStyle(.bordered)
    }
}

struct FuelGradePicker: View {
    @Binding var selection: FuelGrade

    var body: some View {
        Picker("Fuel type", selection: $selection) {
            ForEach(FuelGrade.allCases) { fuel in
                Text(fuel.title).tag(fuel)
            }
        }
        .pickerStyle(.menu)
        .frame(minHeight: 44)
    }
}

struct AvailabilityPicker: View {
    @Binding var selection: ReportedAvailability

    var body: some View {
        Picker("Reported availability", selection: $selection) {
            ForEach(ReportedAvailability.allCases) { availability in
                Text(availability.title).tag(availability)
            }
        }
        .pickerStyle(.menu)
        .frame(minHeight: 44)
    }
}

private struct SearchCriteriaSummary: View {
    let query: String
    let filters: FuelSearchFilters

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your search").font(.headline)
            if !query.isEmpty { Text("Search: \(query)") }
            Text(filters.fuel.title)
            Text(filters.availability.title)
            if !filters.province.isEmpty { Text("Province: \(filters.province)") }
            if !filters.district.isEmpty { Text("District: \(filters.district)") }
            if !filters.city.isEmpty { Text("City: \(filters.city)") }
        }
        .font(.subheadline)
        .foregroundStyle(Color("WelcomeHeading"))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Find Fuel") {
    NavigationStack {
        FindFuelView(
            stationStore: StationStore(),
            favouriteStore: FavouriteStationStore(),
            userID: "preview"
        )
    }
}
