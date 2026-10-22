import Foundation
import Testing
@testable import FuelLanka

struct CommunityFuelReportDraftTests {
    @Test func acceptsCompleteObservationWithoutOptionalDetails() {
        let draft = CommunityFuelReportDraft(
            fuel: .diesel,
            availability: .limited,
            queueLevel: .moderate
        )

        #expect(draft.validationMessage == nil)
        #expect(draft.pricePerLitre == nil)
    }

    @Test func parsesPositiveObservedPrice() {
        let draft = CommunityFuelReportDraft(priceText: " 347.50 ")

        #expect(draft.validationMessage == nil)
        #expect(draft.pricePerLitre == 347.5)
    }

    @Test(arguments: ["0", "-1", "NaN", "price"])
    func rejectsInvalidObservedPrice(_ value: String) {
        let draft = CommunityFuelReportDraft(priceText: value)

        #expect(draft.validationMessage != nil)
        #expect(draft.pricePerLitre == nil)
    }

    @Test func rejectsAnyFuelAndOverlongNotes() {
        var draft = CommunityFuelReportDraft(fuel: .any)
        #expect(draft.validationMessage != nil)

        draft.fuel = .petrol92
        draft.note = String(repeating: "a", count: 301)
        #expect(draft.validationMessage != nil)
    }

    @Test func duplicateAndFreshnessWindowsUseSeparateLimits() {
        let now = Date(timeIntervalSince1970: 1_000_000)

        #expect(CommunityReportPolicy.isRecent(now.addingTimeInterval(-10 * 60), now: now))
        #expect(!CommunityReportPolicy.isRecent(now.addingTimeInterval(-31 * 60), now: now))
        #expect(!CommunityReportPolicy.isPublicReportExpired(now.addingTimeInterval(-5 * 60 * 60), now: now))
        #expect(CommunityReportPolicy.isPublicReportExpired(now.addingTimeInterval(-7 * 60 * 60), now: now))
        #expect(CommunityReportPolicy.isPublicReportExpired(nil, now: now))
    }

    @Test func reporterTrustExcludesPendingReportsFromAcceptanceRate() {
        let reports = [
            report(id: "accepted", status: .accepted),
            report(id: "rejected", status: .rejected),
            report(id: "pending", status: .pending)
        ]

        let summary = ReporterTrustSummary.calculate(from: reports, reporterID: "reporter")

        #expect(summary.accepted == 1)
        #expect(summary.rejected == 1)
        #expect(summary.pending == 1)
        #expect(summary.acceptanceRate == 0.5)
    }

    private func report(id: String, status: CommunityReportStatus) -> CommunityFuelReport {
        CommunityFuelReport(
            id: id,
            stationID: "station",
            stationName: "Station",
            reporterID: "reporter",
            fuel: .petrol92,
            availability: .available,
            queueLevel: .short,
            pricePerLitre: nil,
            note: nil,
            status: status,
            createdAt: nil,
            reviewedAt: nil,
            reviewedBy: nil
        )
    }
}
