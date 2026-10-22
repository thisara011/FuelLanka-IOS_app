import SwiftUI
import CoreLocation

struct FuelComparisonView: View {
    var stations: [StationDetails]? = nil
    @State private var fuel: FuelGrade = .petrol92
    @State private var location = MapLocationController()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Compare saved fuel")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Picker("Fuel grade", selection: $fuel) {
                    ForEach(FuelGrade.allCases.filter { $0 != .any }) { grade in
                        Text(grade.title).tag(grade)
                    }
                }
                .pickerStyle(.menu)
                .frame(minHeight: 44)

                Button {
                    location.locate()
                } label: {
                    Label(
                        location.isLocating ? "Finding your location…" : "Calculate distance",
                        systemImage: "location"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(location.isLocating)
                if let message = location.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let stations, !stations.isEmpty {
                    ForEach(stations) { station in
                        ComparisonStationCard(
                            station: station,
                            fuel: fuel,
                            userCoordinate: location.coordinate
                        )
                    }
                    if stations.count == 1 {
                        Text("Save another station to compare the same fuel at different locations.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    ContentUnavailableView {
                        Label(stations == nil ? "Prices unavailable" : "No saved stations", systemImage: "fuelpump")
                    } description: {
                        Text(stations == nil
                             ? "Saved stations and their reported prices cannot be loaded yet."
                             : "Save at least two stations to compare their fuel reports.")
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Prices are indicative").font(.headline)
                    Text("Compare reports for the same fuel grade. Check each report’s age and confirm with the station before travelling.")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .foregroundStyle(.white)
                .background(Color(red: 0.078, green: 0.337, blue: 0.604), in: RoundedRectangle(cornerRadius: 22))
            }
            .padding(26)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background(Color("WelcomeBackgroundTop"))
        .foregroundStyle(Color("WelcomeHeading"))
        .tint(Color("WelcomeAccent"))
        .navigationTitle("Compare prices")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ComparisonStationCard: View {
    let station: StationDetails
    let fuel: FuelGrade
    let userCoordinate: CLLocationCoordinate2D?

    private var report: StationFuelReport? {
        station.reports.filter { $0.fuel == fuel }.max {
            ($0.reportedAt ?? .distantPast) < ($1.reportedAt ?? .distantPast)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(station.name).font(.headline)
            Text(fuel.title).font(.subheadline.weight(.semibold))
            if let report {
                if let price = report.pricePerLitre, !price.isNaN, price >= 0 {
                    Text("\(price.formatted(.currency(code: "LKR"))) / L")
                        .font(.title3.bold())
                } else {
                    Text("Price unavailable")
                }
                if let availability = report.availability, availability != .any {
                    Text("Reported availability: \(String(localized: availability.title))")
                } else {
                    Text("Reported availability unknown")
                }
                if let stock = report.stockLitres, stock.isFinite, stock >= 0 {
                    Text("Reported stock: \(stock.formatted()) L")
                } else {
                    Text("Reported stock unavailable")
                }
                if let date = report.reportedAt {
                    Text("Reported \(date.formatted(date: .abbreviated, time: .shortened))")
                    if report.isStale {
                        Label("Stale report", systemImage: "clock.badge.exclamationmark")
                    }
                } else {
                    Label("Report age unknown", systemImage: "questionmark.circle")
                }
                Text(report.source.map { "Source: \($0)" } ?? "Source unavailable")
            } else {
                Text("No report for this fuel grade")
            }
            if let distanceKilometres {
                Text("Straight-line distance: \(distanceKilometres, format: .number.precision(.fractionLength(1))) km")
                    .foregroundStyle(.secondary)
            } else {
                Text("Distance unavailable").foregroundStyle(.secondary)
            }
            NavigationLink {
                StationDetailsView(station: station)
            } label: {
                Label("Station details", systemImage: "chevron.right")
                    .frame(minHeight: 44)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }

    private var distanceKilometres: Double? {
        guard let userCoordinate,
              let latitude = station.latitude,
              let longitude = station.longitude else { return nil }
        let origin = CLLocation(
            latitude: userCoordinate.latitude,
            longitude: userCoordinate.longitude
        )
        let destination = CLLocation(latitude: latitude, longitude: longitude)
        return origin.distance(from: destination) / 1_000
    }
}

#Preview("Compare prices") {
    NavigationStack { FuelComparisonView() }
}
