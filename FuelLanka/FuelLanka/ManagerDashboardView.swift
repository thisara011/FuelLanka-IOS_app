import SwiftUI

struct ManagerDashboardView: View {
    let station: StationDetails?
    let onUpdateStock: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(station?.name ?? "Assigned station unavailable")
                    .font(.subheadline)
                    .foregroundStyle(Color("WelcomeSecondary"))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Station status unavailable").font(.title3.bold())
                    Text("Opening status cannot be confirmed from inventory reports.")
                        .font(.subheadline)
                    NavigationLink {
                        StationDetailsView(station: station)
                    } label: {
                        Label("Station details", systemImage: "info.circle")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background {
                    RoundedRectangle(cornerRadius: 25)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.078, green: 0.235, blue: 0.455),
                                     Color(red: 0.075, green: 0.482, blue: 0.576)],
                            startPoint: .top, endPoint: .bottom
                        ))
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

                Button {
                    onUpdateStock()
                } label: {
                    Text("Update stock")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Color(red: 0.078, green: 0.337, blue: 0.604))

                NavigationLink {
                    ManagerFuelPricesView(station: station)
                } label: {
                    ManagerActionCard(title: "Edit fuel prices", detail: "Effective date and confirmation required", symbol: "tag")
                }

                NavigationLink {
                    ManagerUnavailableView(title: "Demand forecast", symbol: "chart.line.uptrend.xyaxis", message: "Forecasts require recent reports and a validated model. No depletion estimate is available.")
                } label: {
                    ManagerActionCard(title: "Demand forecast", detail: "Forecast unavailable", symbol: "chart.line.uptrend.xyaxis")
                }
            }
            .buttonStyle(.plain)
            .padding(26)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background {
            LinearGradient(colors: [Color("WelcomeBackgroundTop"), Color("WelcomeBackgroundBottom")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .navigationTitle("Station dashboard")
        .navigationBarTitleDisplayMode(.inline)
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
                   let stock = report.stockLitres, let capacity = report.capacityLitres {
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
                    .font(.subheadline).foregroundStyle(Color("WelcomeSecondary"))
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
            Label(title, systemImage: symbol).font(.headline)
                .foregroundStyle(Color("WelcomeHeading"))
            Text(detail).font(.footnote).foregroundStyle(Color("WelcomeSecondary"))
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}
