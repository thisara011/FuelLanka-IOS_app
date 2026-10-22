import Foundation
import Observation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
@Observable
final class ManagerStationStore {
    private(set) var station: StationDetails?
    private(set) var records: [StationTransaction] = []
    private(set) var alerts: [ManagerAlert] = []
    private(set) var profile: ManagerProfile?
    private(set) var state: StationLoadingState = .idle
    private var currentUserID: String?

    func load(userID: String) async {
        guard state != .loading else { return }
        state = .loading
        currentUserID = userID

        #if canImport(FirebaseFirestore)
        do {
            let database = Firestore.firestore()
            let userDocument = try await database.collection("users").document(userID).getDocument()
            let userData = userDocument.data() ?? [:]
            profile = ManagerProfile(
                fullName: (userData["fullName"] as? String) ?? "Station Manager",
                email: (userData["email"] as? String) ?? "",
                phone: userData["phone"] as? String
            )
            guard let stationID = userData["assignedStationId"] as? String,
                  !stationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                station = nil
                state = .failed("No station has been assigned to this manager.")
                return
            }

            try await loadStation(id: stationID, database: database)
        } catch {
            station = nil
            state = .failed(error.localizedDescription)
        }
        #else
        station = nil
        state = .failed("Firestore is not available in this build.")
        #endif
    }

    func updateStock(changes: [StockUpdateDraft]) async throws {
        #if canImport(FirebaseFirestore)
        guard let station else {
            throw ManagerStationError.missingAssignment
        }

        let timestamp = Timestamp(date: Date())
        let reports: [[String: Any]] = try changes.map { change in
            guard let stockLitres = change.proposedLitres,
                  let capacityLitres = change.report?.capacityLitres else {
                throw ManagerStationError.invalidStock
            }

            var report: [String: Any] = [
                "id": UUID().uuidString,
                "fuel": change.fuel.rawValue,
                "stockLitres": stockLitres,
                "capacityLitres": capacityLitres,
                "reportedAt": timestamp,
                "source": "Station manager",
                "isStale": false
            ]
            if stockLitres > 0 {
                report["availability"] = ReportedAvailability.available.rawValue
            }
            if let price = change.report?.pricePerLitre {
                report["pricePerLitre"] = NSDecimalNumber(decimal: price)
            }
            return report
        }

        guard !reports.isEmpty else {
            throw ManagerStationError.invalidStock
        }

        let database = Firestore.firestore()
        let reference = database.collection("stations").document(station.id)
        try await reference.updateData([
            "reports": FieldValue.arrayUnion(reports),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        for change in changes {
            guard let newStock = change.proposedLitres,
                  let oldStock = change.report?.stockLitres,
                  newStock > oldStock else { continue }
            await publishStationAlert(
                station: station,
                kind: "restock",
                fuelValue: change.fuel.rawValue,
                message: "\(change.fuel.rawValue) stock increased to \(Int(newStock.rounded())) litres."
            )
        }
        try await loadStation(id: station.id, database: database)
        #else
        throw ManagerStationError.firestoreUnavailable
        #endif
    }

    func updateProfile(fullName: String, phone: String) async throws {
        #if canImport(FirebaseFirestore)
        guard let currentUserID else { throw ManagerStationError.missingAccount }
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedPhone.isEmpty else {
            throw ManagerStationError.invalidProfile
        }
        try await Firestore.firestore().collection("users").document(currentUserID).updateData([
            "fullName": trimmedName,
            "phone": trimmedPhone,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        profile = ManagerProfile(fullName: trimmedName, email: profile?.email ?? "", phone: trimmedPhone)
        #else
        throw ManagerStationError.firestoreUnavailable
        #endif
    }

    func recordSale(draft: SaleRecordDraft) async throws {
        #if canImport(FirebaseFirestore)
        guard let station else { throw ManagerStationError.missingAssignment }
        guard let litres = draft.litres, litres > 0 else {
            throw ManagerStationError.invalidSale
        }
        let referenceText = draft.reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let database = Firestore.firestore()
        let stationReference = database.collection("stations").document(station.id)
        _ = try await database.runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(stationReference)
                var reports = snapshot.data()?["reports"] as? [[String: Any]] ?? []
                var transactions = snapshot.data()?["transactions"] as? [[String: Any]] ?? []
                guard !Self.containsReference(referenceText, kind: "sale", in: transactions) else {
                    throw ManagerStationError.duplicateSale
                }
                guard let previous = Self.latestReport(for: draft.fuel, in: reports),
                      let oldStock = Self.number(previous["stockLitres"]),
                      oldStock >= litres,
                      let reportedAt = (previous["reportedAt"] as? Timestamp)?.dateValue(),
                      reportedAt <= draft.occurredAt,
                      previous["isStale"] as? Bool != true else {
                    throw ManagerStationError.invalidSale
                }

                var report = Self.inventoryReport(
                    fuel: draft.fuel,
                    stock: oldStock - litres,
                    date: draft.occurredAt,
                    source: "Confirmed sale",
                    previous: previous
                )
                if oldStock - litres <= 0 {
                    report.removeValue(forKey: "availability")
                }
                reports.append(report)
                transactions.append(Self.transactionData(
                    kind: "sale", fuel: draft.fuel, litres: litres,
                    date: draft.occurredAt, reference: referenceText
                ))
                transaction.updateData([
                    "reports": reports,
                    "transactions": transactions,
                    "updatedAt": Timestamp(date: Date())
                ], forDocument: stationReference)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        try await loadStation(id: station.id, database: database)
        #else
        throw ManagerStationError.firestoreUnavailable
        #endif
    }

    func recordDelivery(draft: DeliveryReceiptDraft) async throws {
        #if canImport(FirebaseFirestore)
        guard let station else { throw ManagerStationError.missingAssignment }
        guard let litres = draft.litres, litres > 0 else {
            throw ManagerStationError.invalidDelivery
        }
        let referenceText = draft.reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let database = Firestore.firestore()
        let stationReference = database.collection("stations").document(station.id)
        _ = try await database.runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(stationReference)
                var reports = snapshot.data()?["reports"] as? [[String: Any]] ?? []
                var transactions = snapshot.data()?["transactions"] as? [[String: Any]] ?? []
                guard !Self.containsReference(referenceText, kind: "delivery", in: transactions) else {
                    throw ManagerStationError.duplicateReceipt
                }
                guard let previous = Self.latestReport(for: draft.fuel, in: reports),
                      let oldStock = Self.number(previous["stockLitres"]),
                      let capacity = Self.number(previous["capacityLitres"]),
                      oldStock + litres <= capacity,
                      let reportedAt = (previous["reportedAt"] as? Timestamp)?.dateValue(),
                      reportedAt <= draft.receivedAt,
                      previous["isStale"] as? Bool != true else {
                    throw ManagerStationError.invalidDelivery
                }

                reports.append(Self.inventoryReport(
                    fuel: draft.fuel,
                    stock: oldStock + litres,
                    date: draft.receivedAt,
                    source: "Confirmed delivery",
                    previous: previous
                ))
                transactions.append(Self.transactionData(
                    kind: "delivery", fuel: draft.fuel, litres: litres,
                    date: draft.receivedAt, reference: referenceText
                ))
                transaction.updateData([
                    "reports": reports,
                    "transactions": transactions,
                    "updatedAt": Timestamp(date: Date())
                ], forDocument: stationReference)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        await publishStationAlert(
            station: station,
            kind: "restock",
            fuelValue: draft.fuel.rawValue,
            message: "\(draft.fuel.rawValue) was restocked with \(Int(litres.rounded())) litres."
        )
        try await loadStation(id: station.id, database: database)
        #else
        throw ManagerStationError.firestoreUnavailable
        #endif
    }

    func updatePrices(changes: [FuelPriceDraft]) async throws {
        #if canImport(FirebaseFirestore)
        guard let station else {
            throw ManagerStationError.missingAssignment
        }

        let reports: [[String: Any]] = try changes.map { change in
            guard let price = change.price,
                  let effectiveAt = change.effectiveAt else {
                throw ManagerStationError.invalidPrice
            }

            var report: [String: Any] = [
                "id": UUID().uuidString,
                "fuel": change.fuel.rawValue,
                "pricePerLitre": NSDecimalNumber(decimal: price),
                "reportedAt": Timestamp(date: effectiveAt),
                "source": "Station manager",
                "isStale": false
            ]
            if let previous = change.report {
                if let availability = previous.availability {
                    report["availability"] = availability.rawValue
                }
                if let stock = previous.stockLitres {
                    report["stockLitres"] = stock
                }
                if let capacity = previous.capacityLitres {
                    report["capacityLitres"] = capacity
                }
            }
            return report
        }

        guard !reports.isEmpty else {
            throw ManagerStationError.invalidPrice
        }

        let database = Firestore.firestore()
        let reference = database.collection("stations").document(station.id)
        try await reference.updateData([
            "reports": FieldValue.arrayUnion(reports),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        for change in changes {
            guard let price = change.price,
                  price != change.report?.pricePerLitre else { continue }
            await publishStationAlert(
                station: station,
                kind: "price",
                fuelValue: change.fuel.rawValue,
                message: "\(change.fuel.rawValue) is now LKR \(NSDecimalNumber(decimal: price).stringValue) per litre."
            )
        }
        try await loadStation(id: station.id, database: database)
        #else
        throw ManagerStationError.firestoreUnavailable
        #endif
    }

    #if canImport(FirebaseFirestore)
    private func publishStationAlert(
        station: StationDetails,
        kind: String,
        fuelValue: String,
        message: String
    ) async {
        var data: [String: Any] = [
            "stationID": station.id,
            "stationName": station.name,
            "kind": kind,
            "fuel": fuelValue,
            "title": kind == "price"
                ? "\(station.name) price update"
                : "\(station.name) has been restocked",
            "message": message,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let currentUserID {
            data["managerID"] = currentUserID
        }

        do {
            try await Firestore.firestore().collection("stationAlerts").addDocument(data: data)
        } catch {
            print("Station alert publication failed: \(error.localizedDescription)")
        }
    }

    private nonisolated static func latestReport(
        for fuel: FuelGrade,
        in reports: [[String: Any]]
    ) -> [String: Any]? {
        reports
            .filter { ($0["fuel"] as? String) == fuel.rawValue }
            .max {
                (($0["reportedAt"] as? Timestamp)?.dateValue() ?? .distantPast) <
                    (($1["reportedAt"] as? Timestamp)?.dateValue() ?? .distantPast)
            }
    }

    private nonisolated static func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    private nonisolated static func containsReference(
        _ reference: String,
        kind: String,
        in transactions: [[String: Any]]
    ) -> Bool {
        transactions.contains {
            ($0["kind"] as? String) == kind &&
                ($0["reference"] as? String)?.localizedCaseInsensitiveCompare(reference) == .orderedSame
        }
    }

    private nonisolated static func inventoryReport(
        fuel: FuelGrade,
        stock: Double,
        date: Date,
        source: String,
        previous: [String: Any]
    ) -> [String: Any] {
        var report: [String: Any] = [
            "id": UUID().uuidString,
            "fuel": fuel.rawValue,
            "stockLitres": stock,
            "reportedAt": Timestamp(date: date),
            "source": source,
            "isStale": false
        ]
        if stock > 0 { report["availability"] = ReportedAvailability.available.rawValue }
        if let capacity = previous["capacityLitres"] { report["capacityLitres"] = capacity }
        if let price = previous["pricePerLitre"] { report["pricePerLitre"] = price }
        return report
    }

    private nonisolated static func transactionData(
        kind: String,
        fuel: FuelGrade,
        litres: Double,
        date: Date,
        reference: String
    ) -> [String: Any] {
        [
            "id": UUID().uuidString,
            "kind": kind,
            "fuel": fuel.rawValue,
            "litres": litres,
            "occurredAt": Timestamp(date: date),
            "reference": reference,
            "status": "Confirmed"
        ]
    }

    private func loadStation(id: String, database: Firestore) async throws {
        let stationDocument = try await database.collection("stations").document(id).getDocument()
        guard let decodedStation = StationStore.station(from: stationDocument) else {
            station = nil
            state = .failed("The assigned station record is unavailable.")
            return
        }

        station = decodedStation
        records = Self.transactions(from: stationDocument.data()?["transactions"], stationID: id)
        alerts = Self.operationalAlerts(for: decodedStation)
        state = .loaded
    }

    private static func transactions(from value: Any?, stationID: String) -> [StationTransaction] {
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

    private static func operationalAlerts(for station: StationDetails) -> [ManagerAlert] {
        FuelGrade.allCases.filter { $0 != .any }.compactMap { fuel in
            guard let report = station.reports
                .filter({ $0.fuel == fuel })
                .max(by: { ($0.reportedAt ?? .distantPast) < ($1.reportedAt ?? .distantPast) }) else {
                return nil
            }

            if report.isStale {
                return ManagerAlert(
                    id: "stale-\(fuel.rawValue)",
                    stationID: station.id,
                    title: "Inventory report needs verification",
                    message: "\(String(localized: fuel.title)) has a stale inventory report. Measure the tank before recording another operation.",
                    reportedAt: report.reportedAt,
                    requiresAction: true,
                    destination: .stock
                )
            }

            if let fraction = report.fillFraction, fraction <= 0.2 {
                return ManagerAlert(
                    id: "low-stock-\(fuel.rawValue)",
                    stationID: station.id,
                    title: fraction <= 0.05 ? "Critical stock level" : "Low stock level",
                    message: "\(String(localized: fuel.title)) is at \((fraction * 100).formatted(.number.precision(.fractionLength(0))))% capacity.",
                    reportedAt: report.reportedAt,
                    requiresAction: true,
                    destination: .stock
                )
            }

            if report.pricePerLitre == nil {
                return ManagerAlert(
                    id: "missing-price-\(fuel.rawValue)",
                    stationID: station.id,
                    title: "Fuel price required",
                    message: "\(String(localized: fuel.title)) does not have a current reported price.",
                    reportedAt: report.reportedAt,
                    requiresAction: true,
                    destination: .prices
                )
            }

            return nil
        }
    }
    #endif
}

private enum ManagerStationError: LocalizedError {
    case missingAssignment
    case invalidStock
    case invalidPrice
    case invalidDelivery
    case duplicateReceipt
    case invalidSale
    case duplicateSale
    case missingAccount
    case invalidProfile
    case firestoreUnavailable

    var errorDescription: String? {
        switch self {
        case .missingAssignment:
            "No station has been assigned to this manager."
        case .invalidStock:
            "The stock update contains invalid or incomplete values."
        case .invalidPrice:
            "The price update contains invalid or incomplete values."
        case .invalidDelivery:
            "The delivery receipt is invalid or the inventory report is no longer current."
        case .duplicateReceipt:
            "A delivery with this supplier receipt reference has already been recorded."
        case .invalidSale:
            "The sale is invalid or the inventory report is no longer current."
        case .duplicateSale:
            "A sale with this reference has already been recorded."
        case .missingAccount:
            "The authenticated manager account is unavailable."
        case .invalidProfile:
            "Enter a valid full name and phone number."
        case .firestoreUnavailable:
            "Firestore is not available in this build."
        }
    }
}
