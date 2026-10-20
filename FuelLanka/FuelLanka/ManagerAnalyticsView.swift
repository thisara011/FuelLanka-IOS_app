import SwiftUI

typealias ManagerAnalyticsState = StationRecordsState

enum ManagerAnalyticsPeriod: String, CaseIterable, Identifiable {
    case sevenDays
    case thirtyDays

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .sevenDays: "7 days"
        case .thirtyDays: "30 days"
        }
    }

    var dayCount: Int {
        switch self {
        case .sevenDays: 7
        case .thirtyDays: 30
        }
    }
}

struct ManagerAnalyticsSummary {
    struct FuelTotal: Identifiable {
        let fuel: FuelGrade
        let litres: Double

        var id: FuelGrade { fuel }
    }

    let totalLitres: Double
    let transactionCount: Int
    let fuelTotals: [FuelTotal]
    let latestSaleAt: Date?

    init(
        records: [StationTransaction],
        stationID: String,
        period: ManagerAnalyticsPeriod,
        now: Date,
        calendar: Calendar = .current
    ) {
        let start = calendar.date(byAdding: .day, value: -period.dayCount, to: now) ?? now
        let validSales = records.filter { record in
            guard record.stationID == stationID,
                  record.kind == .sale,
                  let litres = record.litres,
                  litres.isFinite,
                  litres > 0,
                  let occurredAt = record.occurredAt else {
                return false
            }
            return occurredAt >= start && occurredAt <= now
        }

        totalLitres = validSales.reduce(0) { $0 + ($1.litres ?? 0) }
        transactionCount = validSales.count
        latestSaleAt = validSales.compactMap(\.occurredAt).max()

        fuelTotals = FuelGrade.allCases
            .filter { $0 != .any }
            .compactMap { fuel in
                let litres = validSales
                    .filter { $0.fuel == fuel }
                    .reduce(0) { $0 + ($1.litres ?? 0) }
                return litres > 0 ? FuelTotal(fuel: fuel, litres: litres) : nil
            }
            .sorted { $0.litres > $1.litres }
    }
}

struct ManagerAnalyticsView: View {
    let station: StationDetails?
    var state: ManagerAnalyticsState = .unavailable
    var now: Date = .now
    @State private var period: ManagerAnalyticsPeriod = .sevenDays

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ManagerAnalyticsHeader(stationName: station?.name)

                Picker("Reporting period", selection: $period) {
                    ForEach(ManagerAnalyticsPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                ManagerAnalyticsContent(
                    station: station,
                    state: state,
                    period: period,
                    now: now
                )

                Text("Analytics include only complete sales records for the assigned station. Inventory reports and forecasts are not treated as sales.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
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
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("WelcomeAccent"))
    }
}

private struct ManagerAnalyticsHeader: View {
    let stationName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sales analytics")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)
            Text(stationName ?? "Station assignment unavailable")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ManagerAnalyticsContent: View {
    let station: StationDetails?
    let state: ManagerAnalyticsState
    let period: ManagerAnalyticsPeriod
    let now: Date

    var body: some View {
        if let station {
            switch state {
            case .loading:
                ProgressView("Loading analytics…")
                    .frame(maxWidth: .infinity, minHeight: 180)
            case .unavailable:
                ContentUnavailableView(
                    "Analytics unavailable",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Complete authorized sales records are required to calculate station analytics.")
                )
            case .loaded(let records):
                let summary = ManagerAnalyticsSummary(
                    records: records,
                    stationID: station.id,
                    period: period,
                    now: now
                )
                if summary.transactionCount == 0 {
                    ContentUnavailableView(
                        "No sales data",
                        systemImage: "chart.bar",
                        description: Text("No complete sales records are available for this station and period.")
                    )
                } else {
                    ManagerAnalyticsOverview(summary: summary, period: period)
                    ManagerFuelBreakdown(fuelTotals: summary.fuelTotals)
                }
            }
        } else {
            ContentUnavailableView(
                "Station assignment required",
                systemImage: "building.2",
                description: Text("An authorized station assignment is required to view analytics.")
            )
        }
    }
}

private struct ManagerAnalyticsOverview: View {
    let summary: ManagerAnalyticsSummary
    let period: ManagerAnalyticsPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            LabeledContent("Period", value: String(localized: period.title))
            LabeledContent("Reported sales") {
                Text("\(summary.totalLitres, format: .number.precision(.fractionLength(0...1))) L")
            }
            LabeledContent("Complete records", value: summary.transactionCount.formatted())
            if let latestSaleAt = summary.latestSaleAt {
                LabeledContent("Latest record") {
                    Text(latestSaleAt, format: .dateTime.day().month().year().hour().minute())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct ManagerFuelBreakdown: View {
    let fuelTotals: [ManagerAnalyticsSummary.FuelTotal]

    private var maximumLitres: Double {
        fuelTotals.map(\.litres).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Sales by fuel")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(fuelTotals) { total in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(total.fuel.title)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(total.litres, format: .number.precision(.fractionLength(0...1))) L")
                    }
                    ProgressView(value: total.litres, total: maximumLitres)
                        .accessibilityLabel(Text(total.fuel.title))
                        .accessibilityValue(
                            Text("\(total.litres.formatted()) litres in the selected period")
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview("Manager Analytics") {
    NavigationStack {
        ManagerAnalyticsView(station: nil)
    }
}
