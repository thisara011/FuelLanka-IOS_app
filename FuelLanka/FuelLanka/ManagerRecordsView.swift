import SwiftUI

struct StationTransaction: Identifiable {
    enum Kind {
        case sale, delivery
    }
    let id: String
    let stationID: String
    let kind: Kind
    let fuel: FuelGrade
    let litres: Double?
    let occurredAt: Date?
    let reference: String?
    let status: String
}

enum StationRecordsState {
    case loading
    case unavailable
    case loaded([StationTransaction])
}

struct ManagerSalesHistoryView: View {
    let station: StationDetails?
    var state: StationRecordsState = .unavailable
    @State private var fuel: FuelGrade = .any

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(station?.name ?? "Assigned station unavailable")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Sales overview").font(.title.bold())
                VStack(alignment: .leading, spacing: 10) {
                    Text("Daily total unavailable").font(.title3.bold())
                    Text("A complete daily report is required to show sales totals.")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .foregroundStyle(.white)
                .background(Color(red: 0.063, green: 0.18, blue: 0.29), in: RoundedRectangle(cornerRadius: 22))

                FuelGradePicker(selection: $fuel)
                ManagerRecordsContent(stationID: station?.id, state: state, kind: .sale, fuel: fuel)
                ViewThatFits {
                    HStack {
                        NavigationLink("Deliveries") {
                            ManagerDeliveriesView(station: station)
                        }
                        NavigationLink("Analytics") {
                            ManagerAnalyticsView(station: station, state: state)
                        }
                    }
                    VStack(alignment: .leading) {
                        NavigationLink("Deliveries") {
                            ManagerDeliveriesView(station: station)
                        }
                        NavigationLink("Analytics") {
                            ManagerAnalyticsView(station: station, state: state)
                        }
                    }
                }
                .frame(minHeight: 44)
                Label("Export requires a complete sales report", systemImage: "square.and.arrow.up")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(26)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background(Color("WelcomeBackgroundTop"))
        .navigationTitle("Sales history")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("WelcomeAccent"))
    }
}

struct ManagerDeliveriesView: View {
    @State private var showsReceipt = false
    let station: StationDetails?
    var state: StationRecordsState = .unavailable

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(station?.name ?? "Assigned station unavailable")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Incoming fuel").font(.title.bold())
                VStack(alignment: .leading, spacing: 10) {
                    Text("Schedule unavailable").font(.title3.bold())
                    Text("No delivery arrival time can be confirmed.")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .foregroundStyle(.white)
                .background(Color(red: 0.063, green: 0.18, blue: 0.29), in: RoundedRectangle(cornerRadius: 22))
                Text("Delivery log").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                ManagerRecordsContent(stationID: station?.id, state: state, kind: .delivery, fuel: .any)
                Button("Record delivery receipt") { showsReceipt = true }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                    .sheet(isPresented: $showsReceipt) {
                        NavigationStack { DeliveryReceiptView(station: station) }
                    }
                Text("Check the receipt and meter before recording received fuel. Receipt scanning is not available yet.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(26)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background(Color("WelcomeBackgroundTop"))
        .navigationTitle("Deliveries")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("WelcomeAccent"))
    }
}

private struct ManagerRecordsContent: View {
    let stationID: String?
    let state: StationRecordsState
    let kind: StationTransaction.Kind
    let fuel: FuelGrade

    var body: some View {
        Group {
            if let stationID {
                switch state {
                case .loading:
                    ProgressView("Loading records…").frame(maxWidth: .infinity, minHeight: 100)
                case .unavailable:
                    ContentUnavailableView("Records unavailable", systemImage: "tray",
                                           description: Text("Station records cannot be loaded yet."))
                case .loaded(let records):
                    let matching = records.filter {
                        $0.stationID == stationID && $0.kind == kind && (fuel == .any || $0.fuel == fuel)
                    }.sorted { ($0.occurredAt ?? .distantPast) > ($1.occurredAt ?? .distantPast) }
                    if matching.isEmpty {
                        ContentUnavailableView("No matching records", systemImage: "tray",
                                               description: Text("No records match this station and fuel selection."))
                    } else {
                        ForEach(matching) { record in
                            NavigationLink {
                                TransactionDetailsView(record: record)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(record.fuel.title).font(.headline)
                                    Text(record.status).font(.subheadline)
                                    if let litres = record.litres, litres.isFinite, litres > 0 {
                                        Text("\(litres.formatted()) L").font(.subheadline)
                                    } else {
                                        Text("Quantity unavailable").font(.subheadline)
                                    }
                                    Text(record.occurredAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Time unavailable")
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(18)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                ContentUnavailableView("Station assignment unavailable", systemImage: "building.2",
                                       description: Text("An authorized station assignment is required to view records."))
            }
        }
    }
}

private struct TransactionDetailsView: View {
    let record: StationTransaction

    var body: some View {
        List {
            Section("Record") {
                Text(record.fuel.title).font(.headline)
                LabeledContent("Status", value: record.status)
                LabeledContent("Reference", value: record.reference ?? "Unavailable")
                if let litres = record.litres, litres.isFinite, litres > 0 {
                    Text("Quantity: \(litres.formatted()) L")
                } else {
                    Text("Quantity unavailable")
                }
                if let date = record.occurredAt {
                    Text(date, format: .dateTime.day().month().year().hour().minute())
                } else {
                    Text("Time unavailable")
                }
            }
            Section {
                Text("Viewing a record does not change inventory or confirm a delivery.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(record.kind == .sale ? "Sale details" : "Delivery details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Sales History") {
    NavigationStack { ManagerSalesHistoryView(station: nil) }
}

#Preview("Deliveries") {
    NavigationStack { ManagerDeliveriesView(station: nil) }
}
