import SwiftUI

struct FuelSearchFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: FuelSearchFilters
    let onApply: (FuelSearchFilters) -> Void

    init(initialFilters: FuelSearchFilters, onApply: @escaping (FuelSearchFilters) -> Void) {
        _draft = State(initialValue: initialFilters)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Refine results") {
                    LabeledContent("Province") {
                        TextField("Any province", text: $draft.province)
                    }
                    LabeledContent("District") {
                        TextField("Any district", text: $draft.district)
                    }
                    LabeledContent("City") {
                        TextField("Any city", text: $draft.city)
                    }
                }
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

                Section {
                    FuelGradePicker(selection: $draft.fuel)
                    AvailabilityPicker(selection: $draft.availability)
                } footer: {
                    Text("Availability refers to reported stock, not a forecast or a guarantee of fuel on arrival.")
                }

                Section("Distance") {
                    Text("Distance filtering requires your location and station coordinates. It is not available yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Reset filters") { draft = FuelSearchFilters() }
                        .accessibilityIdentifier("filters.reset")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Search filters")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color("WelcomeAccent"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply filters", systemImage: "checkmark") {
                        onApply(draft.normalized())
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("filters.apply")
                }
            }
        }
    }
}

#Preview("Search Filters") {
    FuelSearchFiltersView(initialFilters: FuelSearchFilters()) { _ in }
}
