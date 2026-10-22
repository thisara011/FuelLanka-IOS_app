import SwiftUI

struct ManagerSaleRecordView: View {
    let station: StationDetails?
    let saveSale: (SaleRecordDraft) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = SaleRecordDraft()
    @State private var hasSubmitted = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case reference, quantity
    }

    private var report: StationFuelReport? {
        station?.reports
            .filter { $0.fuel == draft.fuel }
            .max { ($0.reportedAt ?? .distantPast) < ($1.reportedAt ?? .distantPast) }
    }

    var body: some View {
        Form {
            Section {
                Text(station?.name ?? "Assigned station unavailable")
                    .font(.headline)
                Text("Record the verified total sold for a completed shift or meter reading.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Sale details") {
                Picker("Fuel type", selection: $draft.fuel) {
                    Text("Select fuel").tag(FuelGrade.any)
                    ForEach(FuelGrade.allCases.filter { $0 != .any }) { fuel in
                        Text(fuel.title).tag(fuel)
                    }
                }
                TextField("Shift, meter, or receipt reference", text: $draft.reference)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .reference)
                TextField("Litres sold", text: $draft.quantity)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .quantity)
                DatePicker("Sale completed at", selection: $draft.occurredAt, in: ...Date())
                    .environment(\.timeZone, TimeZone(secondsFromGMT: 19_800) ?? .gmt)
                Text("Sri Lanka time · UTC+05:30")
                    .font(.footnote)
            }
            .disabled(station == nil || isSaving)

            Section("Inventory check") {
                if let stock = report?.stockLitres {
                    Text("Current reported stock: \(stock.formatted()) L")
                    if let litres = draft.litres, litres <= stock {
                        Text("Stock after sale: \((stock - litres).formatted()) L")
                    }
                } else {
                    Text("Current inventory unavailable")
                        .foregroundStyle(.secondary)
                }
                if hasSubmitted, let issue = draft.issue(report: report) {
                    Label(issue, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Record sale and update stock").frame(maxWidth: .infinity)
                    }
                }
                .disabled(station == nil || isSaving)
            } footer: {
                Text("This creates one sales-history record and subtracts the verified litres from station stock.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("WelcomeBackgroundTop"))
        .navigationTitle("Record sale")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .interactiveDismissDisabled(isSaving)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.disabled(isSaving)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .alert("Sale could not be saved", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Try again.")
        }
    }

    private func save() async {
        hasSubmitted = true
        guard draft.issue(report: report) == nil, !isSaving else { return }
        focusedField = nil
        isSaving = true
        defer { isSaving = false }

        do {
            try await saveSale(draft)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Record Sale") {
    NavigationStack {
        ManagerSaleRecordView(station: nil) { _ in }
    }
}
