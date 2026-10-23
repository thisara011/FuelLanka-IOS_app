import Charts
import Foundation
import Observation
import SwiftUI

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct DailyFuelUsage: Identifiable, Equatable {
    let date: Date
    let litres: Double

    var id: Date { date }
}

enum PredictionConfidence: String, Equatable {
    case high
    case medium
    case low
    case insufficient

    var title: LocalizedStringResource {
        switch self {
        case .high: "High confidence"
        case .medium: "Medium confidence"
        case .low: "Low confidence"
        case .insufficient: "Insufficient data"
        }
    }

    var color: Color {
        switch self {
        case .high: .green
        case .medium: .orange
        case .low: .red
        case .insufficient: .secondary
        }
    }
}

struct FuelPrediction: Identifiable, Equatable {
    let stationID: String
    let stationName: String
    let fuel: FuelGrade
    let stockLitres: Double?
    let capacityLitres: Double?
    let reportDate: Date?
    let averageDailyUsage: Double?
    let estimatedDaysRemaining: Double?
    let estimatedRunOutDate: Date?
    let confidence: PredictionConfidence
    let dailyUsage: [DailyFuelUsage]
    let saleCount: Int
    let engine: FuelPredictionEngine
    let explanation: LocalizedStringResource

    var id: String { "\(stationID)-\(fuel.rawValue)" }

    var fillFraction: Double? {
        guard let stockLitres,
              let capacityLitres,
              capacityLitres > 0 else { return nil }
        return min(max(stockLitres / capacityLitres, 0), 1)
    }
}

enum FuelPredictionCalculator {
    static func calculate(
        station: StationDetails,
        fuel: FuelGrade,
        sales: [StationTransaction],
        demandPredictor: OnDeviceFuelDemandPredictor? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FuelPrediction {
        let latestReport = station.reports
            .filter { $0.fuel == fuel }
            .max { ($0.reportedAt ?? .distantPast) < ($1.reportedAt ?? .distantPast) }

        let windowStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let validSales = sales.filter { transaction in
            guard transaction.stationID == station.id,
                  transaction.kind == .sale,
                  transaction.fuel == fuel,
                  transaction.status.localizedCaseInsensitiveCompare("Confirmed") == .orderedSame,
                  let litres = transaction.litres,
                  litres > 0,
                  litres.isFinite,
                  let date = transaction.occurredAt else { return false }
            return date >= windowStart && date <= now
        }

        let grouped = Dictionary(grouping: validSales) { transaction in
            calendar.startOfDay(for: transaction.occurredAt ?? now)
        }
        let dailyUsage = grouped.map { date, records in
            DailyFuelUsage(
                date: date,
                litres: records.compactMap(\.litres).reduce(0, +)
            )
        }
        .sorted { $0.date < $1.date }

        let firstSaleDate = validSales.compactMap(\.occurredAt).min()
        let coveredDays = firstSaleDate.map {
            max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: now).day ?? 1)
        } ?? 0
        let totalLitres = validSales.compactMap(\.litres).reduce(0, +)
        let baselineDailyUsage = coveredDays >= 2 && validSales.count >= 2
            ? totalLitres / Double(coveredDays)
            : nil
        let coreMLDailyUsage = demandPredictor?.predict(
            dailyUsage: dailyUsage,
            now: now,
            calendar: calendar
        )
        let averageDailyUsage = coreMLDailyUsage ?? baselineDailyUsage
        let engine: FuelPredictionEngine = coreMLDailyUsage == nil ? .baseline : .coreML

        let reportAgeHours = latestReport?.reportedAt.map {
            max(0, now.timeIntervalSince($0) / 3_600)
        }
        let confidence = confidence(
            saleCount: validSales.count,
            coveredDays: coveredDays,
            reportAgeHours: reportAgeHours,
            reportIsStale: latestReport?.isStale ?? true
        )

        let currentStock = latestReport?.stockLitres.flatMap {
            $0 >= 0 && $0.isFinite ? $0 : nil
        }
        let daysRemaining: Double? = {
            guard confidence != .insufficient,
                  let currentStock,
                  let averageDailyUsage,
                  averageDailyUsage > 0 else { return nil }
            return currentStock / averageDailyUsage
        }()
        let runOutDate = daysRemaining.map {
            now.addingTimeInterval($0 * 86_400)
        }

        return FuelPrediction(
            stationID: station.id,
            stationName: station.name,
            fuel: fuel,
            stockLitres: currentStock,
            capacityLitres: latestReport?.capacityLitres,
            reportDate: latestReport?.reportedAt,
            averageDailyUsage: averageDailyUsage,
            estimatedDaysRemaining: daysRemaining,
            estimatedRunOutDate: runOutDate,
            confidence: confidence,
            dailyUsage: dailyUsage,
            saleCount: validSales.count,
            engine: engine,
            explanation: explanation(
                hasReport: latestReport != nil,
                saleCount: validSales.count,
                coveredDays: coveredDays,
                reportAgeHours: reportAgeHours,
                reportIsStale: latestReport?.isStale ?? true
            )
        )
    }

    private static func confidence(
        saleCount: Int,
        coveredDays: Int,
        reportAgeHours: Double?,
        reportIsStale: Bool
    ) -> PredictionConfidence {
        guard let reportAgeHours,
              !reportIsStale,
              saleCount >= 2,
              coveredDays >= 2,
              reportAgeHours <= 72 else {
            return .insufficient
        }
        if saleCount >= 7 && coveredDays >= 7 && reportAgeHours <= 24 {
            return .high
        }
        if saleCount >= 4 && coveredDays >= 3 && reportAgeHours <= 48 {
            return .medium
        }
        return .low
    }

    private static func explanation(
        hasReport: Bool,
        saleCount: Int,
        coveredDays: Int,
        reportAgeHours: Double?,
        reportIsStale: Bool
    ) -> LocalizedStringResource {
        if !hasReport {
            return "A current stock report is required before a forecast can be calculated."
        }
        if reportIsStale || (reportAgeHours ?? .infinity) > 72 {
            return "The latest stock report is too old. Ask the station manager to verify the tank level."
        }
        if saleCount < 2 || coveredDays < 2 {
            return "At least two confirmed sales across two days are required for a responsible estimate."
        }
        return "Estimated from the latest stock report and confirmed sales recorded during the last 14 days."
    }
}

@MainActor
@Observable
final class FuelPredictionStore {
    private(set) var predictions: [FuelPrediction] = []
    private(set) var state: StationLoadingState = .idle
    private let demandPredictor = OnDeviceFuelDemandPredictor()

    func load(stations: [StationDetails]) async {
        guard state != .loading else { return }
        state = .loading

        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await Firestore.firestore()
                .collection("stations")
                .getDocuments()
            let transactions = snapshot.documents.flatMap { document in
                Self.transactions(from: document.data()["transactions"], stationID: document.documentID)
            }
            predictions = stations.flatMap { station in
                FuelGrade.allCases
                    .filter { $0 != .any }
                    .map {
                        FuelPredictionCalculator.calculate(
                            station: station,
                            fuel: $0,
                            sales: transactions,
                            demandPredictor: demandPredictor
                        )
                    }
            }
            state = .loaded
        } catch {
            predictions = []
            state = .failed(error.localizedDescription)
        }
        #else
        predictions = []
        state = .failed("Firestore is not available in this build.")
        #endif
    }

    #if canImport(FirebaseFirestore)
    private nonisolated static func transactions(from value: Any?, stationID: String) -> [StationTransaction] {
        guard let values = value as? [[String: Any]] else { return [] }
        return values.compactMap { data in
            guard let id = data["id"] as? String,
                  let kindValue = data["kind"] as? String,
                  let fuelValue = data["fuel"] as? String,
                  let fuel = FuelGrade(rawValue: fuelValue),
                  let kind: StationTransaction.Kind = kindValue == "sale" ? .sale :
                    (kindValue == "delivery" ? .delivery : nil) else { return nil }

            return StationTransaction(
                id: id,
                stationID: stationID,
                kind: kind,
                fuel: fuel,
                litres: (data["litres"] as? NSNumber)?.doubleValue,
                occurredAt: (data["occurredAt"] as? Timestamp)?.dateValue(),
                reference: data["reference"] as? String,
                status: (data["status"] as? String) ?? "Recorded"
            )
        }
    }
    #endif
}

struct CustomerPredictionView: View {
    let stationStore: StationStore

    @State private var predictionStore = FuelPredictionStore()
    @State private var selectedStationID = ""
    @State private var selectedFuel: FuelGrade = .petrol92

    private var selectedPrediction: FuelPrediction? {
        predictionStore.predictions.first {
            $0.stationID == selectedStationID && $0.fuel == selectedFuel
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                PredictionFilterSection(
                    stations: stationStore.stations,
                    selectedStationID: $selectedStationID,
                    selectedFuel: $selectedFuel
                )

                switch predictionStore.state {
                case .idle, .loading:
                    ProgressView("Calculating from station records…")
                        .frame(maxWidth: .infinity, minHeight: 220)
                case .failed(let message):
                    ContentUnavailableView(
                        "Prediction unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                case .loaded:
                    if let selectedPrediction {
                        PredictionSummarySection(prediction: selectedPrediction)
                        PredictionUsageChartSection(prediction: selectedPrediction)
                        PredictionMethodSection(prediction: selectedPrediction)
                    } else {
                        ContentUnavailableView(
                            "Choose a station",
                            systemImage: "fuelpump",
                            description: Text("Select a station and fuel type to view its operational estimate.")
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Fuel outlook")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await reload()
        }
        .task(id: stationStore.stations.map(\.id)) {
            await reload(selectForecastReadyStation: selectedStationID.isEmpty)
        }
    }

    private func reload(selectForecastReadyStation: Bool = false) async {
        await predictionStore.load(stations: stationStore.stations)

        guard selectForecastReadyStation else { return }

        let preferredPrediction = predictionStore.predictions.first {
            $0.fuel == .petrol92 && $0.estimatedDaysRemaining != nil
        } ?? predictionStore.predictions.first {
            $0.estimatedDaysRemaining != nil
        }

        if let preferredPrediction {
            selectedStationID = preferredPrediction.stationID
            selectedFuel = preferredPrediction.fuel
        } else {
            selectedStationID = stationStore.stations.first?.id ?? ""
        }
    }
}

private struct PredictionFilterSection: View {
    let stations: [StationDetails]
    @Binding var selectedStationID: String
    @Binding var selectedFuel: FuelGrade

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Forecast selection", systemImage: "slider.horizontal.3")
                .font(.headline)

            Picker("Station", selection: $selectedStationID) {
                ForEach(stations) { station in
                    Text(station.name).tag(station.id)
                }
            }

            Picker("Fuel", selection: $selectedFuel) {
                ForEach(FuelGrade.allCases.filter { $0 != .any }) { fuel in
                    Text(fuel.title).tag(fuel)
                }
            }
            .pickerStyle(.segmented)
        }
        .predictionCard()
    }
}

private struct PredictionSummarySection: View {
    let prediction: FuelPrediction

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(prediction.stationName)
                        .font(.headline)
                    Text(prediction.fuel.title)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(prediction.confidence.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(prediction.confidence.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(prediction.confidence.color.opacity(0.12), in: Capsule())
            }

            if let days = prediction.estimatedDaysRemaining,
               let runOutDate = prediction.estimatedRunOutDate {
                Text(days < 1 ? "Less than one day remaining" : "\(days.formatted(.number.precision(.fractionLength(1)))) days remaining")
                    .font(.title2.bold())
                    .foregroundStyle(days <= 2 ? .red : .primary)
                Text("Estimated until \(runOutDate.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(.secondary)
            } else {
                ContentUnavailableView(
                    "No responsible estimate yet",
                    systemImage: "chart.line.downtrend.xyaxis",
                    description: Text(prediction.explanation)
                )
            }

            if let stock = prediction.stockLitres {
                PredictionMetricRow(
                    title: "Reported stock",
                    value: "\(stock.formatted(.number.precision(.fractionLength(0)))) L"
                )
            }
            if let average = prediction.averageDailyUsage {
                PredictionMetricRow(
                    title: "Average daily sales",
                    value: "\(average.formatted(.number.precision(.fractionLength(0)))) L/day"
                )
            }
            if let fraction = prediction.fillFraction {
                ProgressView(value: fraction) {
                    Text("Tank level")
                } currentValueLabel: {
                    Text(fraction, format: .percent.precision(.fractionLength(0)))
                }
                .tint(fraction <= 0.2 ? .red : .blue)
            }
        }
        .predictionCard()
    }
}

private struct PredictionMetricRow: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

private struct PredictionUsageChartSection: View {
    let prediction: FuelPrediction

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Confirmed sales — last 14 days", systemImage: "chart.bar")
                .font(.headline)

            if prediction.dailyUsage.isEmpty {
                Text("No confirmed sales are available for this fuel.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(prediction.dailyUsage) { usage in
                    BarMark(
                        x: .value("Day", usage.date, unit: .day),
                        y: .value("Litres", usage.litres)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                }
                .chartYAxisLabel("Litres")
                .frame(height: 210)
                .accessibilityLabel("Daily confirmed fuel sales")
            }
        }
        .predictionCard()
    }
}

private struct PredictionMethodSection: View {
    let prediction: FuelPrediction

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("How this estimate works", systemImage: "info.circle")
                .font(.headline)
            Text(prediction.explanation)
                .foregroundStyle(.secondary)
            Label(prediction.engine.title, systemImage: prediction.engine == .coreML ? "cpu" : "function")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(prediction.saleCount) confirmed sale records were found in the 14-day window.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("This is an operational estimate, not a guarantee. Demand, deliveries, manual corrections, and delayed reporting can change the result.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .predictionCard()
    }
}

private extension View {
    func predictionCard() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}
