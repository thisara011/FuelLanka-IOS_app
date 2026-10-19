import SwiftUI

struct FindFuelView: View {
    @State private var query = ""
    @State private var filters = FuelSearchFilters()
    @State private var showsFilters = false

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

                ContentUnavailableView {
                    Label("Station search unavailable", systemImage: "magnifyingglass")
                } description: {
                    Text("Station information cannot be loaded yet. Your search and filters are ready, but availability, prices and distances cannot be confirmed.")
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))

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
        .background {
            LinearGradient(
                colors: [Color("WelcomeBackgroundTop"), Color("WelcomeBackgroundBottom")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .navigationDestination(for: StationDetails.self) { station in
            StationDetailsView(station: station)
        }
        .navigationTitle("Find Fuel")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Station, city or district")
        .tint(Color("WelcomeAccent"))
        .sheet(isPresented: $showsFilters) {
            FuelSearchFiltersView(initialFilters: filters) { filters = $0 }
        }
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
                Button { onMoreFilters() } label: {
                    Label("Filters", systemImage: "line.3.horizontal.decrease")
                }
                    .frame(minHeight: 44)
            }
            VStack(alignment: .leading, spacing: 8) {
                FuelGradePicker(selection: $filters.fuel)
                AvailabilityPicker(selection: $filters.availability)
                Button { onMoreFilters() } label: {
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
    NavigationStack { FindFuelView() }
}

#Preview("Find Fuel Dark") {
    NavigationStack { FindFuelView() }.preferredColorScheme(.dark)
}

#Preview("Find Fuel Large Text") {
    NavigationStack { FindFuelView() }.environment(\.dynamicTypeSize, .accessibility3)
}
