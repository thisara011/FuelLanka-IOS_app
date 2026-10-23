import CoreML
import Foundation

enum FuelPredictionEngine: String, Equatable {
    case coreML
    case baseline

    var title: LocalizedStringResource {
        switch self {
        case .coreML: "On-device Core ML"
        case .baseline: "Local baseline"
        }
    }
}

struct OnDeviceFuelDemandPredictor {
    private let model: MLModel?

    init(bundle: Bundle = .main) {
        guard let modelURL = bundle.url(forResource: "FuelDemandRegressor", withExtension: "mlmodelc") else {
            model = nil
            return
        }

        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        model = try? MLModel(contentsOf: modelURL, configuration: configuration)
    }

    func predict(
        dailyUsage: [DailyFuelUsage],
        now: Date,
        calendar: Calendar
    ) -> Double? {
        guard let model,
              dailyUsage.count >= 7 else { return nil }

        let usageByDay = Dictionary(uniqueKeysWithValues: dailyUsage.map {
            (calendar.startOfDay(for: $0.date), $0.litres)
        })
        let today = calendar.startOfDay(for: now)
        let values = (-13...0).map { offset -> Double in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return 0 }
            return usageByDay[date] ?? 0
        }

        let previous7Average = values.prefix(7).reduce(0, +) / 7
        let recent7Average = values.suffix(7).reduce(0, +) / 7
        let recent3Average = values.suffix(3).reduce(0, +) / 3
        let recentTrend = recent3Average - previous7Average
        let weekday = calendar.component(.weekday, from: now)
        let isWeekend = weekday == 1 || weekday == 7 ? 1.0 : 0.0

        do {
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "recent3Average": recent3Average,
                "recent7Average": recent7Average,
                "previous7Average": previous7Average,
                "recentTrend": recentTrend,
                "isWeekend": isWeekend
            ])
            let output = try model.prediction(from: input)
            guard let prediction = output.featureValue(for: "predictedDailyLitres")?.doubleValue,
                  prediction.isFinite,
                  prediction > 0 else { return nil }

            let observedCeiling = max(recent3Average, recent7Average, previous7Average) * 2.5
            guard observedCeiling > 0 else { return nil }
            return min(prediction, observedCeiling)
        } catch {
            return nil
        }
    }
}
