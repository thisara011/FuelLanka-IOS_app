import SwiftUI
import MapKit

enum SriLankaMap {
    static let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 7.8731, longitude: 80.7718),
        span: MKCoordinateSpan(latitudeDelta: 4.8, longitudeDelta: 3.6)
    )
}

/// Nil means the station feed is unavailable, rather than a successful empty result.
struct StationMapView: View {
    var stations: [StationDetails]? = nil
    var favourites: FavouriteStationStore? = nil
    var userID: String? = nil
    let onListView: () -> Void
    @State private var camera: MapCameraPosition = .region(SriLankaMap.region)
    @State private var location = MapLocationController()
    @State private var selectedStationID: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var fuel: FuelGrade = .any
    @State private var availability: ReportedAvailability = .any

    private var visibleStations: [StationDetails] {
        (stations ?? []).filter { station in
            guard station.directionsURL != nil else { return false }
            if fuel == .any && availability == .any { return true }
            return station.reports.contains { report in
                (fuel == .any || report.fuel == fuel) &&
                (availability == .any ||
                    (!report.isStale && report.reportedAt != nil && report.availability == availability))
            }
        }
    }

    private var selectedStation: StationDetails? {
        visibleStations.first { $0.id == selectedStationID }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sri Lanka · station map")
                        .font(.subheadline)
                        .foregroundStyle(Color("WelcomeSecondary"))
                    let filterLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                        : AnyLayout(HStackLayout(spacing: 12))
                    filterLayout {
                        FuelGradePicker(selection: $fuel)
                        AvailabilityPicker(selection: $availability)
                        Button("List view", action: onListView)
                            .frame(minHeight: 44)
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    Map(position: $camera, selection: $selectedStationID) {
                        ForEach(visibleStations) { station in
                            if let latitude = station.latitude, let longitude = station.longitude {
                                Marker(station.name, systemImage: "fuelpump",
                                       coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                                    .tag(station.id)
                            }
                        }
                        if let coordinate = location.coordinate {
                            Annotation("Your location", coordinate: coordinate) {
                                Image(systemName: "location.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.blue)
                                    .background(.white, in: Circle())
                                    .accessibilityLabel("Your last located position")
                            }
                        }
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .mapControls {
                        MapCompass()
                        MapScaleView()
                    }
                    .frame(height: max(300, min(500, geometry.size.height * 0.55)))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .accessibilityLabel("Interactive map centered on Sri Lanka")

                    ViewThatFits {
                        HStack {
                            MapLocationActions(location: location, onReset: resetMap)
                        }
                        VStack(alignment: .leading) {
                            MapLocationActions(location: location, onReset: resetMap)
                        }
                    }
                    if let message = location.message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Color("WelcomeSecondary"))
                    }

                    if let station = selectedStation {
                        NavigationLink {
                            StationDetailsView(
                                station: station,
                                favourites: favourites,
                                userID: userID
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(station.name).font(.headline)
                                if let address = station.address {
                                    Text(address).font(.subheadline)
                                }
                                Text("View station details →").font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(18)
                        }
                        .buttonStyle(.plain)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(stations == nil ? "Station reports unavailable" : "Select a station")
                                .font(.headline)
                            Text(stations == nil
                                 ? "The map shows Sri Lanka. Verified station locations and fuel reports have not been connected yet."
                                 : visibleStations.isEmpty
                                 ? "No stations with valid coordinates match these filters."
                                 : "Tap a pin to see station details. Pins indicate locations, not confirmed fuel availability.")
                                .font(.subheadline)
                                .foregroundStyle(Color("WelcomeSecondary"))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
                    }
                }
                .padding(20)
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color("WelcomeBackgroundTop"))
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("WelcomeAccent"))
        .onChange(of: location.locationRevision) { _, _ in
            if let coordinate = location.coordinate {
                camera = .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
        }
    }

    private func resetMap() {
        camera = .region(SriLankaMap.region)
    }
}

private struct MapLocationActions: View {
    let location: MapLocationController
    let onReset: () -> Void

    var body: some View {
        Button("Show Sri Lanka", action: onReset)
            .frame(minHeight: 44)
        Button {
            location.locate()
        } label: {
            Label(location.isLocating ? "Locating…" : "My location", systemImage: "location")
        }
        .frame(minHeight: 44)
        .disabled(location.isLocating)
    }
}

#Preview("Sri Lanka Map") {
    NavigationStack { StationMapView(onListView: {}) }
}
