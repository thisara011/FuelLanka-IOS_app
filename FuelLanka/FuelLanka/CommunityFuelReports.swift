import Foundation
import Observation
import SwiftUI

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum CommunityReportPolicy {
    static let duplicateInterval: TimeInterval = 30 * 60
    static let publicFreshnessInterval: TimeInterval = 6 * 60 * 60

    static func isRecent(_ date: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(date) < duplicateInterval
    }

    static func isPublicReportExpired(_ date: Date?, now: Date = Date()) -> Bool {
        guard let date else { return true }
        return now.timeIntervalSince(date) > publicFreshnessInterval
    }
}

enum CommunityReportStatus: String, CaseIterable, Identifiable {
    case pending
    case accepted
    case rejected

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .pending: "Pending"
        case .accepted: "Accepted"
        case .rejected: "Rejected"
        }
    }
}

enum QueueLevel: String, CaseIterable, Identifiable {
    case none
    case short
    case moderate
    case long

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .none: "No queue"
        case .short: "Short queue"
        case .moderate: "Moderate queue"
        case .long: "Long queue"
        }
    }
}

struct CommunityFuelReportDraft: Equatable {
    var fuel: FuelGrade = .petrol92
    var availability: ReportedAvailability = .available
    var queueLevel: QueueLevel = .none
    var priceText = ""
    var note = ""

    var pricePerLitre: Double? {
        let trimmed = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Double(trimmed), value.isFinite, value > 0 else { return nil }
        return value
    }

    var validationMessage: LocalizedStringResource? {
        if fuel == .any { return "Choose a fuel type." }
        if availability == .any { return "Choose the observed availability." }
        if !priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pricePerLitre == nil {
            return "Enter a valid price greater than zero, or leave it blank."
        }
        if note.count > 300 { return "Keep the note within 300 characters." }
        return nil
    }
}

struct CommunityFuelReport: Identifiable, Equatable {
    let id: String
    let stationID: String
    let stationName: String
    let reporterID: String
    let fuel: FuelGrade
    let availability: ReportedAvailability
    let queueLevel: QueueLevel
    let pricePerLitre: Double?
    let note: String?
    let status: CommunityReportStatus
    let createdAt: Date?
    let reviewedAt: Date?
    let reviewedBy: String?
}

enum CommunityReportError: LocalizedError {
    case invalidDraft
    case duplicateReport
    case firestoreUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidDraft: "Complete the required report details and try again."
        case .duplicateReport: "You already submitted this fuel observation recently. Wait before sending another report."
        case .firestoreUnavailable: "The reporting service is unavailable in this build."
        }
    }
}

struct ReporterTrustSummary: Equatable {
    let accepted: Int
    let rejected: Int
    let pending: Int

    var reviewedCount: Int { accepted + rejected }
    var acceptanceRate: Double? {
        guard reviewedCount > 0 else { return nil }
        return Double(accepted) / Double(reviewedCount)
    }

    static func calculate(from reports: [CommunityFuelReport], reporterID: String) -> Self {
        let matching = reports.filter { $0.reporterID == reporterID }
        return Self(
            accepted: matching.count { $0.status == .accepted },
            rejected: matching.count { $0.status == .rejected },
            pending: matching.count { $0.status == .pending }
        )
    }
}

@MainActor
@Observable
final class CommunityFuelReportStore {
    private(set) var reports: [CommunityFuelReport] = []
    private(set) var isLoading = false
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?

    func submit(draft: CommunityFuelReportDraft, station: StationDetails, reporterID: String) async throws {
        guard draft.validationMessage == nil else { throw CommunityReportError.invalidDraft }
        #if canImport(FirebaseFirestore)
        isSubmitting = true
        defer { isSubmitting = false }
        let duplicateSnapshot = try await Firestore.firestore().collection("communityFuelReports")
            .whereField("reporterId", isEqualTo: reporterID)
            .whereField("stationId", isEqualTo: station.id)
            .limit(to: 20)
            .getDocuments()
        let now = Date()
        let hasDuplicate = duplicateSnapshot.documents.contains { document in
            let data = document.data()
            return data["fuel"] as? String == draft.fuel.rawValue
                && (data["createdAt"] as? Timestamp).map { CommunityReportPolicy.isRecent($0.dateValue(), now: now) } == true
        }
        guard !hasDuplicate else { throw CommunityReportError.duplicateReport }
        var data: [String: Any] = [
            "stationId": station.id,
            "stationName": station.name,
            "reporterId": reporterID,
            "fuel": draft.fuel.rawValue,
            "availability": draft.availability.rawValue,
            "queueLevel": draft.queueLevel.rawValue,
            "status": CommunityReportStatus.pending.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let price = draft.pricePerLitre { data["pricePerLitre"] = price }
        let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { data["note"] = note }
        try await Firestore.firestore().collection("communityFuelReports").addDocument(data: data)
        #else
        throw CommunityReportError.firestoreUnavailable
        #endif
    }

    func load(stationID: String? = nil, reporterID: String? = nil) async {
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            var query: Query = Firestore.firestore().collection("communityFuelReports")
            if let stationID { query = query.whereField("stationId", isEqualTo: stationID) }
            if let reporterID { query = query.whereField("reporterId", isEqualTo: reporterID) }
            let snapshot = try await query.limit(to: 100).getDocuments()
            reports = snapshot.documents.compactMap(Self.report(from:)).sorted {
                ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
            }
        } catch {
            reports = []
            errorMessage = error.localizedDescription
        }
        #else
        errorMessage = CommunityReportError.firestoreUnavailable.localizedDescription
        #endif
    }

    func review(_ report: CommunityFuelReport, decision: CommunityReportStatus, reviewerID: String) async throws {
        guard decision != .pending else { throw CommunityReportError.invalidDraft }
        #if canImport(FirebaseFirestore)
        let database = Firestore.firestore()
        let reportReference = database.collection("communityFuelReports").document(report.id)
        let auditReference = database.collection("adminAuditLogs").document()
        let batch = database.batch()
        batch.updateData([
            "status": decision.rawValue,
            "reviewedAt": FieldValue.serverTimestamp(),
            "reviewedBy": reviewerID
        ], forDocument: reportReference)

        if decision == .accepted {
            var verified: [String: Any] = [
                "id": report.id,
                "fuel": report.fuel.rawValue,
                "availability": report.availability.rawValue,
                "reportedAt": Timestamp(date: report.createdAt ?? Date()),
                "source": "Verified community report",
                "isStale": false
            ]
            if let price = report.pricePerLitre { verified["pricePerLitre"] = price }
            batch.updateData([
                "reports": FieldValue.arrayUnion([verified]),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: database.collection("stations").document(report.stationID))
        }

        batch.setData([
            "action": "communityReport\(decision == .accepted ? "Accepted" : "Rejected")",
            "actorUserId": reviewerID,
            "targetId": report.id,
            "targetLabel": report.stationName,
            "details": "\(report.fuel.rawValue) community report \(decision.rawValue).",
            "createdAt": FieldValue.serverTimestamp()
        ], forDocument: auditReference)
        try await batch.commit()
        reports.removeAll { $0.id == report.id }
        #else
        throw CommunityReportError.firestoreUnavailable
        #endif
    }

    func suspendReporter(_ reporterID: String, administratorID: String) async throws {
        #if canImport(FirebaseFirestore)
        let database = Firestore.firestore()
        let batch = database.batch()
        batch.updateData([
            "reportingSuspended": true,
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: database.collection("users").document(reporterID))
        batch.setData([
            "action": "communityReporterSuspended",
            "actorUserId": administratorID,
            "targetId": reporterID,
            "targetLabel": reporterID,
            "details": "Community fuel reporting access suspended.",
            "createdAt": FieldValue.serverTimestamp()
        ], forDocument: database.collection("adminAuditLogs").document())
        try await batch.commit()
        #else
        throw CommunityReportError.firestoreUnavailable
        #endif
    }

    #if canImport(FirebaseFirestore)
    private static func report(from document: QueryDocumentSnapshot) -> CommunityFuelReport? {
        let data = document.data()
        guard let stationID = data["stationId"] as? String,
              let stationName = data["stationName"] as? String,
              let reporterID = data["reporterId"] as? String,
              let fuelValue = data["fuel"] as? String,
              let fuel = FuelGrade(rawValue: fuelValue),
              let availabilityValue = data["availability"] as? String,
              let availability = ReportedAvailability(rawValue: availabilityValue),
              let queueValue = data["queueLevel"] as? String,
              let queueLevel = QueueLevel(rawValue: queueValue),
              let statusValue = data["status"] as? String,
              let status = CommunityReportStatus(rawValue: statusValue) else { return nil }
        return CommunityFuelReport(
            id: document.documentID,
            stationID: stationID,
            stationName: stationName,
            reporterID: reporterID,
            fuel: fuel,
            availability: availability,
            queueLevel: queueLevel,
            pricePerLitre: (data["pricePerLitre"] as? NSNumber)?.doubleValue,
            note: data["note"] as? String,
            status: status,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            reviewedAt: (data["reviewedAt"] as? Timestamp)?.dateValue(),
            reviewedBy: data["reviewedBy"] as? String
        )
    }
    #endif
}

struct CommunityFuelReportForm: View {
    let station: StationDetails
    let reporterID: String
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CommunityFuelReportDraft()
    @State private var store = CommunityFuelReportStore()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Observation") {
                    Picker("Fuel type", selection: $draft.fuel) {
                        ForEach(FuelGrade.allCases.filter { $0 != .any }) { fuel in
                            Text(fuel.title).tag(fuel)
                        }
                    }
                    Picker("Availability", selection: $draft.availability) {
                        ForEach(ReportedAvailability.allCases.filter { $0 != .any }) { availability in
                            Text(availability.title).tag(availability)
                        }
                    }
                    Picker("Queue", selection: $draft.queueLevel) {
                        ForEach(QueueLevel.allCases) { level in Text(level.title).tag(level) }
                    }
                }
                Section("Optional details") {
                    TextField("Observed price per litre", text: $draft.priceText)
                        .keyboardType(.decimalPad)
                    TextField("Short note", text: $draft.note, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if store.isSubmitting { ProgressView() } else { Text("Submit for verification") }
                    }
                    .disabled(store.isSubmitting || draft.validationMessage != nil)
                } footer: {
                    Text(draft.validationMessage ?? "A station manager will verify this observation before it changes public station data.")
                }
            }
            .navigationTitle("Report fuel status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .alert("Report not submitted", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
        }
    }

    private func submit() async {
        do {
            try await store.submit(draft: draft, station: station, reporterID: reporterID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CommunityReportReviewView: View {
    let stationID: String?
    let reviewerID: String
    var allowsReporterSuspension = false
    @State private var store = CommunityFuelReportStore()
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if store.isLoading && store.reports.isEmpty {
                ProgressView("Loading customer reports…")
            } else if store.reports.filter({ $0.status == .pending }).isEmpty {
                ContentUnavailableView("No pending reports", systemImage: "checkmark.seal", description: Text("New customer observations will appear here."))
            } else {
                List {
                    CommunityReportCountSection(reports: store.reports)
                    Section("Pending observations") {
                        ForEach(store.reports.filter { $0.status == .pending }) { report in
                            CommunityReportReviewRow(
                                report: report,
                                trust: ReporterTrustSummary.calculate(from: store.reports, reporterID: report.reporterID),
                                allowsReporterSuspension: allowsReporterSuspension,
                                review: { decision in Task { await review(report, decision: decision) } },
                                suspend: { Task { await suspend(report.reporterID) } }
                            )
                        }
                    }
                }
                .refreshable { await store.load(stationID: stationID) }
            }
        }
        .navigationTitle("Customer reports")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load(stationID: stationID) }
        .alert("Report not updated", isPresented: Binding(
            get: { errorMessage != nil || store.errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? store.errorMessage ?? "") }
    }

    private func review(_ report: CommunityFuelReport, decision: CommunityReportStatus) async {
        do { try await store.review(report, decision: decision, reviewerID: reviewerID) }
        catch { errorMessage = error.localizedDescription }
    }

    private func suspend(_ reporterID: String) async {
        do { try await store.suspendReporter(reporterID, administratorID: reviewerID) }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct CommunityReportCountSection: View {
    let reports: [CommunityFuelReport]

    var body: some View {
        Section("Report totals") {
            LabeledContent("Pending", value: reports.count { $0.status == .pending }.formatted())
            LabeledContent("Accepted", value: reports.count { $0.status == .accepted }.formatted())
            LabeledContent("Rejected", value: reports.count { $0.status == .rejected }.formatted())
        }
    }
}

private struct CommunityReportReviewRow: View {
    let report: CommunityFuelReport
    let trust: ReporterTrustSummary
    let allowsReporterSuspension: Bool
    let review: (CommunityReportStatus) -> Void
    let suspend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(report.stationName).font(.headline)
            Text(report.fuel.title)
            Label(report.availability.title, systemImage: "fuelpump")
            Label(report.queueLevel.title, systemImage: "car.2")
            if let price = report.pricePerLitre { Text(price, format: .currency(code: "LKR")) }
            if let note = report.note { Text(note).font(.footnote).foregroundStyle(.secondary) }
            ReporterTrustLabel(summary: trust)
            if let date = report.createdAt { Text(date, format: .dateTime.day().month().hour().minute()).font(.caption).foregroundStyle(.secondary) }
            CommunityReportDecisionButtons(review: review)
            if allowsReporterSuspension {
                Button("Suspend reporter", systemImage: "person.crop.circle.badge.xmark", role: .destructive, action: suspend)
                    .font(.footnote)
            }
        }
        .padding(.vertical, 6)
    }

}

private struct ReporterTrustLabel: View {
    let summary: ReporterTrustSummary

    var body: some View {
        if let rate = summary.acceptanceRate {
            Text("Reporter history: \(summary.accepted) accepted, \(summary.rejected) rejected (\(rate, format: .percent.precision(.fractionLength(0))))")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Reporter history: no reviewed reports")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct CustomerCommunityReportHistoryView: View {
    let userID: String
    @State private var store = CommunityFuelReportStore()

    var body: some View {
        List {
            CommunityReportCountSection(reports: store.reports)
            Section("Your observations") {
                if store.isLoading && store.reports.isEmpty {
                    ProgressView("Loading reports…")
                } else if store.reports.isEmpty {
                    ContentUnavailableView("No reports yet", systemImage: "fuelpump", description: Text("Reports you submit from a station will appear here."))
                } else {
                    ForEach(store.reports) { report in
                        CustomerCommunityReportRow(report: report)
                    }
                }
            }
        }
        .navigationTitle("My fuel reports")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.load(reporterID: userID) }
        .task { await store.load(reporterID: userID) }
    }
}

private struct CustomerCommunityReportRow: View {
    let report: CommunityFuelReport

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(report.stationName).font(.headline)
                Spacer()
                Text(report.status.title).font(.caption.weight(.semibold))
            }
            Text(report.fuel.title)
            Label(report.availability.title, systemImage: "fuelpump")
            Label(report.queueLevel.title, systemImage: "car.2")
            if let date = report.createdAt {
                Text(date, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct CommunityReportDecisionButtons: View {
    let review: (CommunityReportStatus) -> Void

    var body: some View {
        ViewThatFits {
            HStack {
                Button("Accept", systemImage: "checkmark") { review(.accepted) }
                    .buttonStyle(.borderedProminent)
                Button("Reject", systemImage: "xmark", role: .destructive) { review(.rejected) }
                    .buttonStyle(.bordered)
            }
            VStack {
                Button("Accept", systemImage: "checkmark") { review(.accepted) }
                    .buttonStyle(.borderedProminent)
                Button("Reject", systemImage: "xmark", role: .destructive) { review(.rejected) }
                    .buttonStyle(.bordered)
            }
        }
    }
}
