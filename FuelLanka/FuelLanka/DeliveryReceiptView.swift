import SwiftUI
import VisionKit

struct DeliveryReceiptView: View {
    let station: StationDetails?
    var saveReceipt: (DeliveryReceiptDraft) async throws -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @State private var draft = DeliveryReceiptDraft()
    @State private var showsValidation = false
    @State private var showsReview = false
    @State private var showsDiscard = false
    @State private var showsScanner = false
    @State private var scanMessage: String?
    @FocusState private var fieldFocused: Bool

    private var report: StationFuelReport? {
        station?.reports.filter { $0.fuel == draft.fuel }.max {
            ($0.reportedAt ?? .distantPast) < ($1.reportedAt ?? .distantPast)
        }
    }
    private var hasChanges: Bool {
        draft.fuel != .any || !draft.reference.isEmpty || !draft.quantity.isEmpty
    }

    var body: some View {
        Form {
            Section {
                Text(station?.name ?? "Assigned station unavailable").font(.headline)
                Text("Enter actual received litres after checking the receipt and meter. Do not enter a scheduled delivery.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Receipt details") {
                Button {
                    showsScanner = true
                } label: {
                    Label("Scan delivery receipt", systemImage: "doc.viewfinder")
                }
                .disabled(station == nil || !VNDocumentCameraViewController.isSupported)

                if !VNDocumentCameraViewController.isSupported {
                    Text("Document scanning requires a supported physical iPhone or iPad. Manual entry remains available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Picker("Fuel type", selection: $draft.fuel) {
                    Text("Select fuel").tag(FuelGrade.any)
                    ForEach(FuelGrade.allCases.filter { $0 != .any }) { fuel in
                        Text(fuel.title).tag(fuel)
                    }
                }
                TextField("Supplier receipt reference", text: $draft.reference)
                    .autocorrectionDisabled()
                    .focused($fieldFocused)
                TextField("Actual received litres", text: $draft.quantity)
                    .keyboardType(.decimalPad)
                    .focused($fieldFocused)
                DatePicker("Received at", selection: $draft.receivedAt, in: ...Date())
                    .environment(\.timeZone, TimeZone(secondsFromGMT: 19_800) ?? .gmt)
                Text("Sri Lanka time · UTC+05:30").font(.footnote)
            }
            .disabled(station == nil)

            Section("Inventory check") {
                if let report, let stock = report.stockLitres, stock.isFinite,
                   let capacity = report.capacityLitres, capacity.isFinite {
                    Text("Last reported: \(stock.formatted()) / \(capacity.formatted()) L")
                    if let date = report.reportedAt {
                        Text("Reported \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote)
                    }
                    if report.isStale {
                        Label("Stale report", systemImage: "clock.badge.exclamationmark")
                    }
                } else {
                    Text("Inventory and capacity unavailable").foregroundStyle(.secondary)
                }
                if showsValidation, let issue = draft.issue(report: report) {
                    Label(issue, systemImage: "exclamationmark.circle")
                        .font(.footnote).foregroundStyle(.red)
                }
            }
            Section {
                Button("Review delivery") {
                    fieldFocused = false
                    showsValidation = true
                    if draft.issue(report: report) == nil { showsReview = true }
                }
                .disabled(station == nil)
            } footer: {
                Text("Scanned values are suggestions. Check the receipt, meter and tank capacity before confirming.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("WelcomeBackgroundTop"))
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Record delivery")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("WelcomeAccent"))
        .interactiveDismissDisabled(hasChanges)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasChanges { showsDiscard = true } else { dismiss() }
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { fieldFocused = false }
            }
        }
        .confirmationDialog("Discard receipt draft?", isPresented: $showsDiscard, titleVisibility: .visible) {
            Button("Discard draft", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .navigationDestination(isPresented: $showsReview) {
            DeliveryReceiptReviewView(
                stationName: station?.name ?? "",
                draft: draft,
                report: report,
                saveReceipt: saveReceipt,
                onSaved: { dismiss() }
            )
        }
        .sheet(isPresented: $showsScanner) {
            DeliveryReceiptScanner(
                onResult: applyScan,
                onCancel: {},
                onFailure: { scanMessage = $0 }
            )
            .ignoresSafeArea()
        }
        .alert("Receipt scan", isPresented: Binding(
            get: { scanMessage != nil },
            set: { if !$0 { scanMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(scanMessage ?? "")
        }
        .onChange(of: station) { _, _ in
            showsReview = false
            draft = DeliveryReceiptDraft()
            showsValidation = false
        }
    }

    private func applyScan(_ result: DeliveryReceiptScanResult) {
        if let reference = result.reference { draft.reference = reference }
        if let quantity = result.quantity { draft.quantity = quantity }
        if let fuel = result.fuel { draft.fuel = fuel }
        let populatedCount = [result.reference != nil, result.quantity != nil, result.fuel != nil]
            .filter { $0 }.count
        scanMessage = populatedCount == 0
            ? "Text was recognized, but no receipt reference, fuel grade or litre quantity could be identified. Enter the values manually."
            : "Filled \(populatedCount) receipt field\(populatedCount == 1 ? "" : "s"). Review every value before saving."
    }
}

private struct DeliveryReceiptReviewView: View {
    let stationName: String
    let draft: DeliveryReceiptDraft
    let report: StationFuelReport?
    let saveReceipt: (DeliveryReceiptDraft) async throws -> Void
    let onSaved: () -> Void
    @State private var physicallyChecked = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Check receipt details") {
                Text(stationName).font(.headline)
                Text(draft.fuel.title)
                LabeledContent("Supplier reference", value: draft.reference.trimmingCharacters(in: .whitespacesAndNewlines))
                if let litres = draft.litres {
                    Text("Received: \(litres.formatted()) L")
                    if let stock = report?.stockLitres {
                        Text("Proposed tank total: \((stock + litres).formatted()) L")
                    }
                }
                Text(draft.receivedAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened,
                     timeZone: TimeZone(secondsFromGMT: 19_800) ?? .gmt))
                Text("Sri Lanka time · UTC+05:30").font(.footnote)
            }
            Section {
                Toggle("I checked the receipt and actual received quantity", isOn: $physicallyChecked)
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Confirm receipt and update stock").frame(maxWidth: .infinity)
                    }
                }
                .disabled(!physicallyChecked || isSaving)
            } footer: {
                Text("The confirmed receipt is added to delivery history and the received litres are added to current stock.")
            }
        }
        .navigationTitle("Review delivery")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isSaving)
        .alert("Delivery could not be saved", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Try again.")
        }
    }

    private func save() async {
        guard physicallyChecked, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await saveReceipt(draft)
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Delivery Receipt") {
    NavigationStack { DeliveryReceiptView(station: nil) }
}
