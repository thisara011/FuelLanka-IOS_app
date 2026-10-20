import SwiftUI

struct ManagerStockUpdateView: View {
    let station: StationDetails?
    @State private var drafts: [StockUpdateDraft]
    @State private var showsReview = false
    @State private var showsDiscard = false
    @FocusState private var focusedFuel: FuelGrade?

    init(station: StationDetails?) {
        self.station = station
        _drafts = State(initialValue: StockUpdateDraft.rows(for: station))
    }

    private var changes: [StockUpdateDraft] { drafts.filter(\.hasEntry) }
    private var canReview: Bool {
        station != nil && !changes.isEmpty && changes.allSatisfy { $0.validationMessage == nil }
    }

    var body: some View {
        Form {
            Section {
                Text(station?.name ?? "Assigned station unavailable").font(.headline)
                Text("Enter the measured total currently in each tank. Leave unchanged grades blank. Record deliveries separately.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if station == nil {
                    Text("An authorized station assignment is required to enter stock.")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach($drafts) { $draft in
                Section {
                    if let report = draft.report {
                        if let stock = report.stockLitres, stock.isFinite, stock >= 0 {
                            Text("Last reported: \(stock.formatted()) L")
                        } else {
                            Text("Previous stock unavailable")
                        }
                        if let date = report.reportedAt {
                            Text("Reported \(date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.footnote).foregroundStyle(.secondary)
                        } else {
                            Text("Report time unavailable").font(.footnote)
                        }
                        if report.isStale {
                            Label("Stale report — verify the tank measurement", systemImage: "clock.badge.exclamationmark")
                                .font(.footnote)
                        }
                        if let capacity = report.capacityLitres, capacity.isFinite, capacity > 0 {
                            Text("Tank capacity: \(capacity.formatted()) L")
                        } else {
                            Text("Tank capacity unavailable")
                        }
                    } else {
                        Text("Inventory report unavailable").foregroundStyle(.secondary)
                    }
                    TextField("New measured total (L)", text: $draft.quantity)
                        .keyboardType(.decimalPad)
                        .focused($focusedFuel, equals: draft.fuel)
                        .disabled(station == nil)
                        .accessibilityLabel(Text("New measured total in litres, \(String(localized: draft.fuel.title))"))
                    if let error = draft.validationMessage {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.footnote).foregroundStyle(.red)
                    }
                } header: {
                    Text(draft.fuel.title)
                }
            }
            Section {
                Button("Review stock update") {
                    focusedFuel = nil
                    showsReview = true
                }
                .disabled(!canReview)
                Button("Discard draft", role: .destructive) { showsDiscard = true }
                    .disabled(changes.isEmpty)
            } footer: {
                Text("Stock writes are not connected yet. Reviewing a draft does not update inventory.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("WelcomeBackgroundTop"))
        .navigationTitle("Update stock")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .tint(Color("WelcomeAccent"))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedFuel = nil }
            }
        }
        .sheet(isPresented: $showsReview) {
            NavigationStack {
                StockUpdateReviewView(stationName: station?.name ?? "", changes: changes)
            }
        }
        .confirmationDialog("Discard stock draft?", isPresented: $showsDiscard, titleVisibility: .visible) {
            Button("Discard draft", role: .destructive) {
                drafts = StockUpdateDraft.rows(for: station)
            }
            Button("Keep editing", role: .cancel) {}
        }
        .onChange(of: station) { _, updatedStation in
            // Never carry an old station's draft into a different assignment or report revision.
            showsReview = false
            drafts = StockUpdateDraft.rows(for: updatedStation)
        }
    }
}

private struct StockUpdateReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let stationName: String
    let changes: [StockUpdateDraft]

    var body: some View {
        List {
            Section {
                Text(stationName).font(.headline)
                Text("Review measured stock totals. No changes have been saved.")
            }
            ForEach(changes) { change in
                Section {
                    if let previous = change.report?.stockLitres, previous.isFinite, previous >= 0 {
                        Text("Previously reported: \(previous.formatted()) L")
                    } else {
                        Text("Previous quantity unavailable")
                    }
                    if let total = change.proposedLitres {
                        Text("New measured total: \(total.formatted()) L").font(.headline)
                    }
                    if let capacity = change.report?.capacityLitres {
                        Text("Tank capacity: \(capacity.formatted()) L")
                    }
                    if change.report?.isStale == true {
                        Label("Previous report is stale", systemImage: "clock.badge.exclamationmark")
                    }
                } header: {
                    Text(change.fuel.title)
                }
            }
            Section {
                Button("Confirm and save") {}
                    .disabled(true)
                Text("Saving is unavailable until authorized station writes are connected.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Review stock")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Keep editing") { dismiss() }
            }
        }
    }
}

#Preview("Stock Update") {
    NavigationStack { ManagerStockUpdateView(station: nil) }
}
