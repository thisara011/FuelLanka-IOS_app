import SwiftUI

struct ManagerDashboardView: View {
    let station: StationDetails?
    let records: [StationTransaction]
    let alerts: [ManagerAlert]
    let state: StationLoadingState
    let onUpdateStock: () -> Void
    let onRecordSale: () -> Void
    let publishPrices: ([FuelPriceDraft]) async throws -> Void
    let recordDelivery: (DeliveryReceiptDraft) async throws -> Void

    private var todayRecords: [StationTransaction] {
        records.filter {
            guard let date = $0.occurredAt else { return false }
            return Calendar.current.isDateInToday(date)
        }
    }

    private var todaySales: Double {
        todayRecords
            .filter { $0.kind == .sale }
            .compactMap(\.litres)
            .reduce(0, +)
    }

    private var todayDeliveries: Double {
        todayRecords
            .filter { $0.kind == .delivery }
            .compactMap(\.litres)
            .reduce(0, +)
    }

    private var status: ManagerStationStatus {
        switch state {
        case .loading, .idle:
            return .loading
        case .failed(let message):
            return .unavailable(message)
        case .loaded:
            if station == nil {
                return .unavailable("No station is assigned to this account.")
            }
            if alerts.contains(where: \.requiresAction) {
                return .attention
            }
            return .operational
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(station?.name ?? "Assigned station unavailable")
                    .font(.subheadline)
                    .foregroundStyle(Color("WelcomeSecondary"))

                ManagerStatusCard(status: status, alertCount: alerts.filter(\.requiresAction).count)

                Text("Today")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 12) {
                    ManagerMetricCard(
                        title: "Sales",
                        value: "\(todaySales.formatted()) L",
                        symbol: "fuelpump"
                    )
                    ManagerMetricCard(
                        title: "Deliveries",
                        value: "\(todayDeliveries.formatted()) L",
                        symbol: "truck.box"
                    )
                }

                Text("Fuel inventory")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(FuelGrade.allCases.filter { $0 != .any }) { fuel in
                        ManagerInventoryRow(fuel: fuel, reports: station?.reports ?? [])
                        if fuel != .superDiesel { Divider() }
                    }
                }
                .padding(18)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))

                Text("Quick actions")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    Button(action: onUpdateStock) {
                        ManagerQuickAction(title: "Update stock", symbol: "shippingbox")
                    }
                    Button(action: onRecordSale) {
                        ManagerQuickAction(title: "Record sale", symbol: "fuelpump")
                    }
                    NavigationLink {
                        ManagerDeliveriesView(
                            station: station,
                            state: .loaded(records),
                            recordDelivery: recordDelivery
                        )
                    } label: {
                        ManagerQuickAction(title: "Delivery", symbol: "truck.box")
                    }
                    NavigationLink {
                        ManagerFuelPricesView(station: station, publishChanges: publishPrices)
                    } label: {
                        ManagerQuickAction(title: "Fuel prices", symbol: "tag")
                    }
                }

                NavigationLink {
                    ManagerAnalyticsView(station: station, state: .loaded(records))
                } label: {
                    ManagerActionCard(
                        title: "View station analytics",
                        detail: "Review sales, deliveries, and fuel performance",
                        symbol: "chart.bar.xaxis"
                    )
                }

                NavigationLink {
                    StationDetailsView(station: station)
                } label: {
                    ManagerActionCard(
                        title: "Station details",
                        detail: "Address, contact details, and opening hours",
                        symbol: "info.circle"
                    )
                }
            }
            .buttonStyle(.plain)
            .padding(26)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background {
            LinearGradient(
                colors: [Color("WelcomeBackgroundTop"), Color("WelcomeBackgroundBottom")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .navigationTitle("Station dashboard")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum ManagerStationStatus {
    case loading
    case operational
    case attention
    case unavailable(String)

    var title: String {
        switch self {
        case .loading: "Loading station"
        case .operational: "Station operational"
        case .attention: "Action required"
        case .unavailable: "Station unavailable"
        }
    }

    var detail: String {
        switch self {
        case .loading: "Refreshing live station information."
        case .operational: "Inventory reports are current and complete."
        case .attention: "Review the active station alerts below."
        case .unavailable(let message): message
        }
    }

    var symbol: String {
        switch self {
        case .loading: "arrow.trianglehead.2.clockwise.rotate.90"
        case .operational: "checkmark.circle.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .unavailable: "xmark.circle.fill"
        }
    }
}

private struct ManagerStatusCard: View {
    let status: ManagerStationStatus
    let alertCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(status.title, systemImage: status.symbol)
                .font(.title3.bold())
            Text(status.detail)
                .font(.subheadline)
            if alertCount > 0 {
                Text("\(alertCount) active \(alertCount == 1 ? "alert" : "alerts")")
                    .font(.footnote.bold())
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 25)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.078, green: 0.235, blue: 0.455),
                        Color(red: 0.075, green: 0.482, blue: 0.576)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ))
        }
    }
}

private struct ManagerMetricCard: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.subheadline)
                .foregroundStyle(Color("WelcomeSecondary"))
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Color("WelcomeHeading"))
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct ManagerQuickAction: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.bold())
            .foregroundStyle(Color("WelcomeHeading"))
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct ManagerInventoryRow: View {
    let fuel: FuelGrade
    let reports: [StationFuelReport]

    private var report: StationFuelReport? {
        reports.filter { $0.fuel == fuel }.max {
            ($0.reportedAt ?? .distantPast) < ($1.reportedAt ?? .distantPast)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(fuel.title).font(.headline)
            if let report {
                if let fraction = report.fillFraction,
                   let stock = report.stockLitres,
                   let capacity = report.capacityLitres {
                    Text("\(stock.formatted()) / \(capacity.formatted()) L")
                        .font(.subheadline)
                    ProgressView(value: fraction)
                        .accessibilityLabel(Text(fuel.title))
                        .accessibilityValue(Text("\(stock.formatted()) of \(capacity.formatted()) litres reported"))
                } else {
                    Text("Stock or capacity unavailable").font(.subheadline)
                }
                if let date = report.reportedAt {
                    Text("Reported \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                } else {
                    Text("Report time unavailable").font(.footnote)
                }
                if report.isStale {
                    Label("Stale report", systemImage: "clock.badge.exclamationmark")
                        .font(.footnote)
                }
            } else {
                Text("No inventory report available")
                    .font(.subheadline)
                    .foregroundStyle(Color("WelcomeSecondary"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ManagerActionCard: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(Color("WelcomeHeading"))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(Color("WelcomeSecondary"))
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}
