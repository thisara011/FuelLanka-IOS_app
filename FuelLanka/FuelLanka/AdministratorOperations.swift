import Foundation
import Observation
import SwiftUI

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum AdministratorOperationError: LocalizedError {
    case managerRequiresStation
    case invalidStation
    case firestoreUnavailable

    var errorDescription: String? {
        switch self {
        case .managerRequiresStation:
            "A station manager must be assigned to a station."
        case .invalidStation:
            "Enter a station name and valid optional coordinates."
        case .firestoreUnavailable:
            "Firebase Firestore is unavailable in this build."
        }
    }
}

struct AdministratorStationDraft: Equatable {
    var name = ""
    var address = ""
    var operatorName = ""
    var openingHours = ""
    var phoneNumber = ""
    var latitude = ""
    var longitude = ""

    init() {}

    init(station: StationDetails) {
        name = station.name
        address = station.address ?? ""
        operatorName = station.operatorName ?? ""
        openingHours = station.openingHours ?? ""
        phoneNumber = station.phoneNumber ?? ""
        latitude = station.latitude?.formatted(.number.precision(.fractionLength(0...6))) ?? ""
        longitude = station.longitude?.formatted(.number.precision(.fractionLength(0...6))) ?? ""
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var latitudeValue: Double? {
        let value = latitude.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : Double(value)
    }

    var longitudeValue: Double? {
        let value = longitude.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : Double(value)
    }

    var isValid: Bool {
        guard !trimmedName.isEmpty else { return false }
        let latitudeText = latitude.trimmingCharacters(in: .whitespacesAndNewlines)
        let longitudeText = longitude.trimmingCharacters(in: .whitespacesAndNewlines)
        if !latitudeText.isEmpty {
            guard let latitudeValue, (-90...90).contains(latitudeValue) else { return false }
        }
        if !longitudeText.isEmpty {
            guard let longitudeValue, (-180...180).contains(longitudeValue) else { return false }
        }
        return true
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = ["name": trimmedName]
        add(address, key: "address", to: &data)
        add(operatorName, key: "operatorName", to: &data)
        add(openingHours, key: "openingHours", to: &data)
        add(phoneNumber, key: "phoneNumber", to: &data)
        if let latitudeValue { data["latitude"] = latitudeValue }
        if let longitudeValue { data["longitude"] = longitudeValue }
        return data
    }

    private func add(_ value: String, key: String, to data: inout [String: Any]) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            data[key] = trimmed
        }
    }
}

extension StationStore {
    func createStation(
        draft: AdministratorStationDraft,
        administratorID: String
    ) async throws {
        guard draft.isValid else { throw AdministratorOperationError.invalidStation }
        #if canImport(FirebaseFirestore)
        let database = Firestore.firestore()
        let stationReference = database.collection("stations").document()
        let auditReference = database.collection("adminAuditLogs").document()
        let batch = database.batch()
        var data = draft.firestoreData
        data["reports"] = [[String: Any]]()
        data["transactions"] = [[String: Any]]()
        data["createdAt"] = FieldValue.serverTimestamp()
        data["updatedAt"] = FieldValue.serverTimestamp()
        batch.setData(data, forDocument: stationReference)
        batch.setData([
            "action": "stationCreated",
            "actorUserId": administratorID,
            "targetId": stationReference.documentID,
            "targetLabel": draft.trimmedName,
            "details": "Station record created.",
            "createdAt": FieldValue.serverTimestamp()
        ], forDocument: auditReference)
        try await batch.commit()
        await load()
        #else
        throw AdministratorOperationError.firestoreUnavailable
        #endif
    }

    func updateStation(
        id: String,
        originalName: String,
        draft: AdministratorStationDraft,
        administratorID: String
    ) async throws {
        guard draft.isValid else { throw AdministratorOperationError.invalidStation }
        #if canImport(FirebaseFirestore)
        let database = Firestore.firestore()
        let stationReference = database.collection("stations").document(id)
        let auditReference = database.collection("adminAuditLogs").document()
        let batch = database.batch()
        var data = draft.firestoreData
        for key in ["address", "operatorName", "openingHours", "phoneNumber"] where data[key] == nil {
            data[key] = FieldValue.delete()
        }
        if data["latitude"] == nil { data["latitude"] = FieldValue.delete() }
        if data["longitude"] == nil { data["longitude"] = FieldValue.delete() }
        data["updatedAt"] = FieldValue.serverTimestamp()
        batch.updateData(data, forDocument: stationReference)
        batch.setData([
            "action": "stationUpdated",
            "actorUserId": administratorID,
            "targetId": id,
            "targetLabel": draft.trimmedName,
            "details": originalName == draft.trimmedName
                ? "Station details updated."
                : "Station renamed from \(originalName).",
            "createdAt": FieldValue.serverTimestamp()
        ], forDocument: auditReference)
        try await batch.commit()
        await load()
        #else
        throw AdministratorOperationError.firestoreUnavailable
        #endif
    }
}

struct AdministratorAuditEntry: Identifiable, Equatable {
    let id: String
    let action: String
    let actorUserID: String
    let targetLabel: String
    let details: String
    let createdAt: Date?
}

@MainActor
@Observable
final class AdministratorAuditStore {
    private(set) var entries: [AdministratorAuditEntry] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func load() async {
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let snapshot = try await Firestore.firestore()
                .collection("adminAuditLogs")
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()
            entries = snapshot.documents.map { document in
                let data = document.data()
                return AdministratorAuditEntry(
                    id: document.documentID,
                    action: data["action"] as? String ?? "administrativeChange",
                    actorUserID: data["actorUserId"] as? String ?? "Unknown",
                    targetLabel: data["targetLabel"] as? String ?? "Unknown target",
                    details: data["details"] as? String ?? "",
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        #else
        errorMessage = "Firebase Firestore is unavailable."
        #endif
    }
}

struct AdministratorUserManagementView: View {
    let store: AdministratorUserStore
    let stations: [StationDetails]
    let currentUserID: String?

    @State private var query = ""

    private var filteredUsers: [AdministratorUser] {
        guard !query.isEmpty else { return store.users }
        return store.users.filter {
            $0.email.localizedCaseInsensitiveContains(query) ||
                $0.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        AdministratorUserList(
            users: filteredUsers,
            stations: stations,
            currentUserID: currentUserID,
            isLoading: store.isLoading,
            reload: { await store.loadUsers() },
            save: { user, role, stationID in
                guard let currentUserID else { return }
                try await store.updateAccess(
                    for: user,
                    role: role,
                    assignedStationID: stationID,
                    administratorID: currentUserID
                )
            }
        )
        .searchable(text: $query, prompt: "Name or email")
        .navigationTitle("User access")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AdministratorUserList: View {
    let users: [AdministratorUser]
    let stations: [StationDetails]
    let currentUserID: String?
    let isLoading: Bool
    let reload: () async -> Void
    let save: (AdministratorUser, AccountRole, String?) async throws -> Void

    var body: some View {
        if isLoading && users.isEmpty {
            ProgressView("Loading users…")
        } else if users.isEmpty {
            ContentUnavailableView(
                "No matching users",
                systemImage: "person.2.slash",
                description: Text("Registered Firebase profiles appear here.")
            )
        } else {
            List(users) { user in
                NavigationLink {
                    AdministratorUserAccessEditor(
                        user: user,
                        stations: stations,
                        isCurrentAdministrator: user.id == currentUserID,
                        save: { role, stationID in
                            try await save(user, role, stationID)
                        }
                    )
                } label: {
                    AdministratorManagedUserRow(user: user, stations: stations)
                }
            }
            .refreshable { await reload() }
        }
    }
}

private struct AdministratorManagedUserRow: View {
    let user: AdministratorUser
    let stations: [StationDetails]

    private var assignment: String? {
        guard let id = user.assignedStationID else { return nil }
        return stations.first(where: { $0.id == id })?.name ?? id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(user.displayName.isEmpty ? user.email : user.displayName)
                .font(.headline)
            Text(user.email)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Label(roleTitle, systemImage: roleSymbol)
                if let assignment {
                    Text("• \(assignment)")
                        .lineLimit(1)
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var roleTitle: String {
        switch user.role {
        case .customer: "Customer"
        case .manager: "Manager"
        case .administrator: "Administrator"
        }
    }

    private var roleSymbol: String {
        switch user.role {
        case .customer: "person"
        case .manager: "building.2"
        case .administrator: "person.badge.shield.checkmark"
        }
    }
}

private struct AdministratorUserAccessEditor: View {
    let user: AdministratorUser
    let stations: [StationDetails]
    let isCurrentAdministrator: Bool
    let save: (AccountRole, String?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var role: AccountRole
    @State private var stationID: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        user: AdministratorUser,
        stations: [StationDetails],
        isCurrentAdministrator: Bool,
        save: @escaping (AccountRole, String?) async throws -> Void
    ) {
        self.user = user
        self.stations = stations
        self.isCurrentAdministrator = isCurrentAdministrator
        self.save = save
        _role = State(initialValue: user.role)
        _stationID = State(initialValue: user.assignedStationID ?? "")
    }

    var body: some View {
        Form {
            Section("Account") {
                LabeledContent("Email", value: user.email)
                if !user.displayName.isEmpty {
                    LabeledContent("Name", value: user.displayName)
                }
            }

            Section("Authorized access") {
                Picker("Role", selection: $role) {
                    Text("Customer").tag(AccountRole.customer)
                    Text("Station manager").tag(AccountRole.manager)
                    Text("Administrator").tag(AccountRole.administrator)
                }
                .disabled(isCurrentAdministrator)

                if role == .manager {
                    Picker("Assigned station", selection: $stationID) {
                        Text("Select a station").tag("")
                        ForEach(stations) { station in
                            Text(station.name).tag(station.id)
                        }
                    }
                }
            }

            if isCurrentAdministrator {
                Section {
                    Label(
                        "You cannot change the role of the administrator currently signed in.",
                        systemImage: "lock.shield"
                    )
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    Task { await saveChanges() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Save access")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isCurrentAdministrator || isSaving || (role == .manager && stationID.isEmpty))
            }
        }
        .navigationTitle("User access")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Access not saved", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func saveChanges() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await save(role, role == .manager ? stationID : nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AdministratorStationManagementView: View {
    let store: StationStore

    @State private var query = ""
    @State private var showsCreateStation = false
    @State private var administratorID = ""

    private var filteredStations: [StationDetails] {
        guard !query.isEmpty else { return store.stations }
        return store.stations.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
                ($0.address?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        AdministratorManagedStationList(
            stations: filteredStations,
            state: store.state,
            administratorID: administratorID,
            reload: { await store.load() },
            update: { station, draft in
                try await store.updateStation(
                    id: station.id,
                    originalName: station.name,
                    draft: draft,
                    administratorID: administratorID
                )
            }
        )
        .searchable(text: $query, prompt: "Station or area")
        .navigationTitle("Station management")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add station", systemImage: "plus") {
                    showsCreateStation = true
                }
            }
        }
        .sheet(isPresented: $showsCreateStation) {
            NavigationStack {
                AdministratorStationEditor(
                    title: "New station",
                    initialDraft: AdministratorStationDraft()
                ) { draft in
                    try await store.createStation(
                        draft: draft,
                        administratorID: administratorID
                    )
                }
            }
        }
        .task {
            #if canImport(FirebaseAuth)
            administratorID = FirebaseAuth.Auth.auth().currentUser?.uid ?? ""
            #endif
        }
    }
}

private struct AdministratorManagedStationList: View {
    let stations: [StationDetails]
    let state: StationLoadingState
    let administratorID: String
    let reload: () async -> Void
    let update: (StationDetails, AdministratorStationDraft) async throws -> Void

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView("Loading stations…")
        case .failed(let message):
            ContentUnavailableView(
                "Stations unavailable",
                systemImage: "wifi.exclamationmark",
                description: Text(message)
            )
        case .loaded where stations.isEmpty:
            ContentUnavailableView(
                "No stations found",
                systemImage: "fuelpump",
                description: Text("Add the first station or change the search.")
            )
        case .loaded:
            List(stations) { station in
                NavigationLink {
                    AdministratorStationEditor(
                        title: "Edit station",
                        initialDraft: AdministratorStationDraft(station: station)
                    ) { draft in
                        try await update(station, draft)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(station.name)
                            .font(.headline)
                        Text(station.address ?? station.operatorName ?? "Details incomplete")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .refreshable { await reload() }
        }
    }
}

private struct AdministratorStationEditor: View {
    let title: LocalizedStringKey
    let save: (AdministratorStationDraft) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: AdministratorStationDraft
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        title: LocalizedStringKey,
        initialDraft: AdministratorStationDraft,
        save: @escaping (AdministratorStationDraft) async throws -> Void
    ) {
        self.title = title
        self.save = save
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        Form {
            Section("Station identity") {
                TextField("Station name", text: $draft.name)
                TextField("Operator", text: $draft.operatorName)
                TextField("Address", text: $draft.address, axis: .vertical)
                TextField("Opening hours", text: $draft.openingHours)
                TextField("Phone number", text: $draft.phoneNumber)
                    .keyboardType(.phonePad)
            }

            Section("Map coordinates") {
                TextField("Latitude", text: $draft.latitude)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Longitude", text: $draft.longitude)
                    .keyboardType(.numbersAndPunctuation)
                Text("Coordinates are optional, but both must be valid before directions can be offered.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    Task { await saveStation() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Save station")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!draft.isValid || isSaving)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .alert("Station not saved", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func saveStation() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await save(draft)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AdministratorAuditView: View {
    let store: AdministratorAuditStore
    let administratorID: String

    var body: some View {
        List {
            Section {
                NavigationLink {
                    CommunityReportReviewView(
                        stationID: nil,
                        reviewerID: administratorID,
                        allowsReporterSuspension: true
                    )
                } label: {
                    Label("Review customer reports", systemImage: "person.wave.2")
                }
                .disabled(administratorID.isEmpty)
            }
            Section("Administrative changes") {
                if store.isLoading && store.entries.isEmpty {
                    ProgressView("Loading audit history…")
                } else if let error = store.errorMessage, store.entries.isEmpty {
                    Text(error).foregroundStyle(.secondary)
                } else if store.entries.isEmpty {
                    Text("No administrative changes yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(store.entries) { entry in
                        AdministratorAuditRow(entry: entry)
                    }
                }
            }
        }
        .refreshable { await store.load() }
        .navigationTitle("Audit history")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
    }
}

private struct AdministratorAuditRow: View {
    let entry: AdministratorAuditEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.targetLabel)
                .font(.headline)
            Text(entry.details)
                .font(.subheadline)
            HStack {
                Text(entry.action)
                Spacer()
                if let createdAt = entry.createdAt {
                    Text(createdAt, format: .dateTime.day().month().year().hour().minute())
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
