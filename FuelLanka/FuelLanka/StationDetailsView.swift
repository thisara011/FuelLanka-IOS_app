import SwiftUI

struct StationDetailsView: View {
    let station: StationDetails?
    var favourites: FavouriteStationStore?
    var userID: String?
    @Environment(\.openURL) private var openURL
    @State private var showsDirectionsError = false
    @State private var showsCommunityReport = false
    @State private var journeyController = FuelJourneyController()

    var body: some View {
        List {
            Section {
                StationDetailsHeader(station: station)
                    .listRowBackground(Color.clear)
            }

            Section {
                if let address = station?.address {
                    Text(address)
                } else {
                    Text("Address unavailable").foregroundStyle(.secondary)
                }
                if let hours = station?.openingHours {
                    Text(hours)
                } else {
                    Text("Opening hours unavailable").foregroundStyle(.secondary)
                }
                if let phoneNumber = station?.phoneNumber,
                   let phoneURL = URL(string: "tel:\(phoneNumber)") {
                    Link(phoneNumber, destination: phoneURL)
                }
                if let sourceURL = station?.sourceURL {
                    Link("Verified operator listing", destination: sourceURL)
                }
                if let station, let favourites, let userID {
                    Button {
                        Task {
                            await favourites.toggle(stationID: station.id, userID: userID)
                        }
                    } label: {
                        Label(
                            favourites.isFavourite(station.id) ? "Remove from favourites" : "Save to favourites",
                            systemImage: favourites.isFavourite(station.id) ? "heart.fill" : "heart"
                        )
                    }
                    .disabled(favourites.updatingStationIDs.contains(station.id))
                    .accessibilityIdentifier("station.favourite")
                }
                Button("Get directions", systemImage: "arrow.up.right") {
                    guard let url = station?.directionsURL else { return }
                    openURL(url) { accepted in
                        showsDirectionsError = !accepted
                    }
                }
                .disabled(station?.directionsURL == nil)
                if let station {
                    Button {
                        Task {
                            if journeyController.isActive {
                                await journeyController.end(stationID: station.id)
                            } else {
                                await journeyController.start(station: station)
                            }
                        }
                    } label: {
                        Label(
                            journeyController.isActive ? "End fuel journey" : "Start fuel journey",
                            systemImage: journeyController.isActive ? "stop.circle" : "location.circle"
                        )
                    }
                }
                if station?.directionsURL == nil {
                    Text("Directions require verified station coordinates.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if station != nil, userID != nil {
                    Button("Report fuel status", systemImage: "person.wave.2") {
                        showsCommunityReport = true
                    }
                    .accessibilityIdentifier("station.reportFuelStatus")
                }
            }

            Section {
                if let station, !station.reports.isEmpty {
                    ForEach(station.reports) { report in
                        StationFuelReportRow(report: report)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Fuel reports unavailable").font(.headline)
                        Text("Reported stock, prices, sources and update times cannot be loaded yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            } header: {
                Text("Reported station data")
                    .textCase(nil)
                    .font(.headline)
                    .foregroundStyle(Color("WelcomeHeading"))
            } footer: {
                Text("Reports describe the last recorded stock. Availability can change before you arrive.")
            }

            Section {
                StationForecastUnavailable()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background {
            LinearGradient(
                colors: [Color("WelcomeBackgroundTop"), Color("WelcomeBackgroundBottom")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .navigationTitle("Station details")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("WelcomeAccent"))
        .alert("Unable to open directions", isPresented: $showsDirectionsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again later.")
        }
        .sheet(isPresented: $showsCommunityReport) {
            if let station, let userID {
                CommunityFuelReportForm(station: station, reporterID: userID)
            }
        }
        .task(id: station?.id) {
            if let station { journeyController.refresh(stationID: station.id) }
        }
        .alert("Live Activity unavailable", isPresented: Binding(
            get: { journeyController.errorMessage != nil },
            set: { if !$0 { journeyController.clearError() } }
        )) {
            Button("OK", role: .cancel) { journeyController.clearError() }
        } message: {
            Text(journeyController.errorMessage ?? "")
        }
    }
}

private struct StationDetailsHeader: View {
    let station: StationDetails?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let station {
                Text(station.name).font(.title2.bold())
            } else {
                Text("Station information unavailable").font(.title2.bold())
            }
            if let operatorName = station?.operatorName {
                Text(operatorName).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(Color("WelcomeHeading"))
        .accessibilityAddTraits(.isHeader)
        .padding(.vertical, 8)
    }
}

private struct StationFuelReportRow: View {
    let report: StationFuelReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(report.fuel.title)
                .font(.headline)
            if report.isStale {
                Label("Stale report — current availability unknown", systemImage: "clock.badge.exclamationmark")
                    .font(.subheadline)
            } else if let availability = report.availability, availability != .any,
                      report.reportedAt != nil {
                Text(availability.title).font(.subheadline.weight(.semibold))
            } else {
                Text("Availability unknown").font(.subheadline)
            }

            if let stock = report.stockLitres, stock.isFinite, stock >= 0 {
                Text("Reported stock: \(stock, format: .number) L")
            }
            if let fraction = report.fillFraction, let capacity = report.capacityLitres {
                ProgressView(value: fraction)
                    .accessibilityLabel("Reported tank level")
                Text("Capacity: \(capacity, format: .number) L")
            }
            if let price = report.pricePerLitre, price >= 0 {
                Text("\(price, format: .currency(code: "LKR")) per litre")
            } else {
                Text("Price unavailable")
            }

            if let date = report.reportedAt {
                Text("Reported: \(date, format: .dateTime.day().month().year().hour().minute())")
            } else {
                Text("Update time unavailable")
            }
            if let source = report.source, !source.isEmpty {
                Text("Source: \(source)")
            } else {
                Text("Source unavailable")
            }
        }
        .font(.footnote)
        .foregroundStyle(Color("WelcomeHeading"))
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct StationForecastUnavailable: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fuel outlook").font(.headline)
            Text("Forecast unavailable").font(.title3.weight(.semibold))
            Text("A reliable estimate requires recent reports and a validated model. Reported stock is shown separately.")
                .font(.footnote)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 25)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.078, green: 0.235, blue: 0.455),
                        Color(red: 0.075, green: 0.482, blue: 0.576)
                    ], startPoint: .top, endPoint: .bottom
                ))
        }
    }
}

#Preview("Station Details") {
    NavigationStack { StationDetailsView(station: nil) }
}

#Preview("Station Details Dark") {
    NavigationStack { StationDetailsView(station: nil) }.preferredColorScheme(.dark)
}

#Preview("Station Details Large Text") {
    NavigationStack { StationDetailsView(station: nil) }.environment(\.dynamicTypeSize, .accessibility3)
}
