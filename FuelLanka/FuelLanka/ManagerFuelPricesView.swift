import SwiftUI

struct ManagerFuelPricesView: View {
    let station: StationDetails?
    let publishChanges: ([FuelPriceDraft]) async throws -> Void
    @State private var drafts: [FuelPriceDraft]
    @State private var showsReview = false
    @State private var showsDiscard = false
    @FocusState private var focusedFuel: PricedFuel?

    init(
        station: StationDetails?,
        publishChanges: @escaping ([FuelPriceDraft]) async throws -> Void = { _ in }
    ) {
        self.station = station
        self.publishChanges = publishChanges
        _drafts = State(initialValue: FuelPriceDraft.rows(for: station))
    }

    private var changes: [FuelPriceDraft] { drafts.filter(\.hasEntry) }
    private var hasDraft: Bool { drafts.contains { $0.hasEntry || $0.effectiveAt != nil } }
    private var canReview: Bool {
        station != nil && !changes.isEmpty && changes.allSatisfy { $0.validationMessage == nil }
    }

    var body: some View {
        Form {
            Section {
                Text(station?.name ?? "Assigned station unavailable").font(.headline)
                Text("Prices in LKR per litre. Leave unchanged prices blank. Dates and times use Sri Lanka time (UTC+05:30).")
                    .font(.subheadline).foregroundStyle(.secondary)
                if station == nil {
                    Text("An authorized station assignment is required to edit prices.")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach($drafts) { $draft in
                Section(draft.fuel.title) {
                    if let report = draft.report {
                        if let price = report.pricePerLitre, !price.isNaN, price >= 0 {
                            Text("Last reported: \(price.formatted(.currency(code: "LKR"))) / L")
                        } else {
                            Text("Reported price unavailable")
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
                        Text("Reported price unavailable").foregroundStyle(.secondary)
                    }
                    TextField("New price (LKR per litre)", text: $draft.text)
                        .keyboardType(.decimalPad)
                        .focused($focusedFuel, equals: draft.fuel)
                        .accessibilityLabel("New price for \(draft.fuel.title), LKR per litre")
                        .disabled(station == nil)
                    if draft.effectiveAt != nil {
                        DatePicker("Effective date and time", selection: Binding(
                            get: { draft.effectiveAt ?? Date() },
                            set: { draft.effectiveAt = $0 }
                        ))
                        .environment(\.timeZone, TimeZone(secondsFromGMT: 19_800) ?? .gmt)
                        .disabled(station == nil)
                    } else {
                        Button("Select effective date and time") { draft.effectiveAt = Date() }
                            .disabled(station == nil)
                    }
                    if let message = draft.validationMessage {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(.footnote).foregroundStyle(.red)
                    }
                }
            }
            Section {
                Button("Review price changes") {
                    focusedFuel = nil
                    showsReview = true
                }.disabled(!canReview)
                Button("Discard draft", role: .destructive) { showsDiscard = true }
                    .disabled(!hasDraft)
            } footer: {
                Text("Review every price and effective time before publishing it.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("WelcomeBackgroundTop"))
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Fuel prices")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("WelcomeAccent"))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedFuel = nil }
            }
        }
        .sheet(isPresented: $showsReview) {
            NavigationStack {
                FuelPriceReviewView(
                    stationName: station?.name ?? "",
                    changes: changes,
                    publishChanges: publishChanges
                )
            }
        }
        .confirmationDialog("Discard price draft?", isPresented: $showsDiscard, titleVisibility: .visible) {
            Button("Discard draft", role: .destructive) { drafts = FuelPriceDraft.rows(for: station) }
            Button("Keep editing", role: .cancel) {}
        }
        .onChange(of: station) { _, newStation in
            showsReview = false
            drafts = FuelPriceDraft.rows(for: newStation)
        }
    }
}

private struct FuelPriceReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let stationName: String
    let changes: [FuelPriceDraft]
    let publishChanges: ([FuelPriceDraft]) async throws -> Void
    @State private var isPublishing = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Text(stationName).font(.headline)
                Text("Review prices before publishing. No changes have been saved.")
            }
            ForEach(changes) { change in
                Section(change.fuel.title) {
                    if let oldPrice = change.report?.pricePerLitre, !oldPrice.isNaN, oldPrice >= 0 {
                        Text("Last reported: \(oldPrice.formatted(.currency(code: "LKR"))) / L")
                    } else {
                        Text("Previous price unavailable")
                    }
                    if let price = change.price {
                        Text("New price: \(price.formatted(.currency(code: "LKR"))) / L").font(.headline)
                    }
                    if let date = change.effectiveAt {
                        Text("Effective: \(date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, timeZone: TimeZone(secondsFromGMT: 19_800) ?? .gmt)))")
                        Text("Sri Lanka time · UTC+05:30").font(.footnote)
                    }
                    if change.report?.isStale == true {
                        Label("Previous report is stale", systemImage: "clock.badge.exclamationmark")
                    }
                }
            }
            Section {
                Button {
                    Task { await publish() }
                } label: {
                    if isPublishing {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Confirm and publish").frame(maxWidth: .infinity)
                    }
                }
                .disabled(isPublishing)
                Text("Published prices are timestamped and shown on the assigned station.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Review prices")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Keep editing") { dismiss() }
                    .disabled(isPublishing)
            }
        }
        .interactiveDismissDisabled(isPublishing)
        .alert("Price update failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "The price update could not be published.")
        }
    }

    private func publish() async {
        guard !isPublishing else { return }
        isPublishing = true
        defer { isPublishing = false }

        do {
            try await publishChanges(changes)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Manager Fuel Prices") {
    NavigationStack { ManagerFuelPricesView(station: nil) }
}
