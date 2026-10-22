import SwiftUI
import Observation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct AdministratorUser: Identifiable, Equatable, Sendable {
    let id: String
    let email: String
    let displayName: String
    let role: AccountRole
    let assignedStationID: String?
}

@MainActor
@Observable
final class AdministratorUserStore {
    private(set) var users: [AdministratorUser] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func loadUsers() async {
        #if canImport(FirebaseFirestore)
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .order(by: "email")
                .getDocuments()

            users = snapshot.documents.compactMap { document in
                let data = document.data()
                guard let roleValue = data["role"] as? String,
                      let role = AccountRole(rawValue: roleValue) else {
                    return nil
                }

                return AdministratorUser(
                    id: document.documentID,
                    email: data["email"] as? String ?? "Email unavailable",
                    displayName: data["fullName"] as? String ?? "",
                    role: role,
                    assignedStationID: data["assignedStationId"] as? String
                )
            }
        } catch {
            errorMessage = "User accounts could not be loaded. Try again."
        }
        #else
        errorMessage = "Firebase Firestore is not available."
        #endif
    }

    func clearError() {
        errorMessage = nil
    }

    func updateAccess(
        for user: AdministratorUser,
        role: AccountRole,
        assignedStationID: String?,
        administratorID: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        let normalizedStationID = role == .manager ? assignedStationID : nil
        if role == .manager && normalizedStationID == nil {
            throw AdministratorOperationError.managerRequiresStation
        }

        let database = Firestore.firestore()
        let userReference = database.collection("users").document(user.id)
        let auditReference = database.collection("adminAuditLogs").document()
        let batch = database.batch()
        var changes: [String: Any] = [
            "role": role.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        changes["assignedStationId"] = normalizedStationID ?? FieldValue.delete()
        batch.updateData(changes, forDocument: userReference)
        batch.setData([
            "action": "userAccessUpdated",
            "actorUserId": administratorID,
            "targetId": user.id,
            "targetLabel": user.email,
            "details": role == .manager
                ? "Role changed to manager and station assigned."
                : "Role changed to \(role.rawValue).",
            "createdAt": FieldValue.serverTimestamp()
        ], forDocument: auditReference)
        try await batch.commit()
        await loadUsers()
        #else
        throw AdministratorOperationError.firestoreUnavailable
        #endif
    }

    func updateRole(for user: AdministratorUser, to role: AccountRole) async {
        guard user.role != role else { return }

        #if canImport(FirebaseFirestore)
        errorMessage = nil
        do {
            try await Firestore.firestore()
                .collection("users")
                .document(user.id)
                .updateData(["role": role.rawValue])

            if let index = users.firstIndex(where: { $0.id == user.id }) {
                users[index] = AdministratorUser(
                    id: user.id,
                    email: user.email,
                    displayName: user.displayName,
                    role: role,
                    assignedStationID: role == .manager ? user.assignedStationID : nil
                )
            }
        } catch {
            errorMessage = "The account role could not be updated."
        }
        #else
        errorMessage = "Firebase Firestore is not available."
        #endif
    }
}

private enum AdministratorTab: Hashable {
    case overview
    case stations
    case users
    case audit
    case account
}

struct AdministratorWorkspaceView: View {
    let authentication: AuthenticationSession

    @State private var userStore = AdministratorUserStore()
    @State private var stationStore = StationStore()
    @State private var auditStore = AdministratorAuditStore()
    @State private var selectedTab: AdministratorTab = .overview

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Overview", systemImage: "chart.bar.xaxis", value: .overview) {
                NavigationStack {
                    AdministratorOverviewView(
                        users: userStore.users,
                        stations: stationStore.stations,
                        stationState: stationStore.state,
                        showStations: { selectedTab = .stations },
                        showUsers: { selectedTab = .users }
                    )
                }
            }

            Tab("Stations", systemImage: "fuelpump", value: .stations) {
                NavigationStack {
                    AdministratorStationManagementView(store: stationStore)
                }
            }

            Tab("Users", systemImage: "person.2", value: .users) {
                NavigationStack {
                    AdministratorUserManagementView(
                        store: userStore,
                        stations: stationStore.stations,
                        currentUserID: authentication.currentAccount?.id
                    )
                }
            }

            Tab("Audit", systemImage: "list.bullet.clipboard", value: .audit) {
                NavigationStack {
                    AdministratorAuditView(
                        store: auditStore,
                        administratorID: authentication.currentAccount?.id ?? ""
                    )
                }
            }

            Tab("Account", systemImage: "person.crop.circle", value: .account) {
                NavigationStack {
                    AdministratorAccountView(authentication: authentication)
                }
            }
        }
        .tint(Color("WelcomeAccent"))
        .task {
            async let users: Void = userStore.loadUsers()
            async let stations: Void = stationStore.load()
            _ = await (users, stations)
        }
        .alert(
            "Administrator service unavailable",
            isPresented: Binding(
                get: { userStore.errorMessage != nil },
                set: { if !$0 { userStore.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) {
                userStore.clearError()
            }
        } message: {
            Text(userStore.errorMessage ?? "")
        }
    }
}

private struct AdministratorOverviewView: View {
    let users: [AdministratorUser]
    let stations: [StationDetails]
    let stationState: StationLoadingState
    let showStations: () -> Void
    let showUsers: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                AdministratorHeader()
                AdministratorRoleSummary(users: users)
                AdministratorStationSummary(
                    stations: stations,
                    state: stationState
                )
                ViewThatFits {
                    HStack {
                        AdministratorOverviewButton(
                            title: "Review stations",
                            symbol: "fuelpump",
                            action: showStations
                        )
                        AdministratorOverviewButton(
                            title: "Manage users",
                            symbol: "person.badge.key",
                            action: showUsers
                        )
                    }
                    VStack {
                        AdministratorOverviewButton(
                            title: "Review stations",
                            symbol: "fuelpump",
                            action: showStations
                        )
                        AdministratorOverviewButton(
                            title: "Manage users",
                            symbol: "person.badge.key",
                            action: showUsers
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Administration")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AdministratorHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 44))
                .foregroundStyle(Color("WelcomeAccent"))
            Text("Administrator workspace")
                .font(.title2.bold())
            Text("Review account access and manage authorized roles.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

private struct AdministratorRoleSummary: View {
    let users: [AdministratorUser]

    var body: some View {
        VStack(spacing: 12) {
            AdministratorCountRow(
                title: "Customers",
                count: users.filter { $0.role == .customer }.count,
                symbol: "person"
            )
            AdministratorCountRow(
                title: "Station managers",
                count: users.filter { $0.role == .manager }.count,
                symbol: "building.2"
            )
            AdministratorCountRow(
                title: "Administrators",
                count: users.filter { $0.role == .administrator }.count,
                symbol: "person.badge.shield.checkmark"
            )
        }
    }
}

private struct AdministratorCountRow: View {
    let title: LocalizedStringKey
    let count: Int
    let symbol: String

    var body: some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer()
            Text(count, format: .number)
                .font(.headline)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct AdministratorOverviewButton: View {
    let title: LocalizedStringKey
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.borderedProminent)
    }
}

private struct AdministratorStationSummary: View {
    let stations: [StationDetails]
    let state: StationLoadingState

    private var stationsNeedingAttention: Int {
        stations.filter { AdministratorStationHealth(station: $0).needsAttention }.count
    }

    private var currentReportCount: Int {
        stations.reduce(into: 0) { total, station in
            total += AdministratorStationHealth(station: station).currentReportCount
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Station reporting")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            switch state {
            case .idle, .loading:
                ProgressView("Loading station coverage…")
            case .failed(let message):
                Label(message, systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.secondary)
            case .loaded:
                AdministratorCountRow(
                    title: "Registered stations",
                    count: stations.count,
                    symbol: "fuelpump"
                )
                AdministratorCountRow(
                    title: "Current fuel reports",
                    count: currentReportCount,
                    symbol: "checkmark.circle"
                )
                AdministratorCountRow(
                    title: "Stations needing attention",
                    count: stationsNeedingAttention,
                    symbol: "exclamationmark.triangle"
                )
            }
        }
    }
}

private enum AdministratorStationFilter: String, CaseIterable, Identifiable {
    case all
    case attention
    case current

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .all: "All stations"
        case .attention: "Needs attention"
        case .current: "Reports current"
        }
    }
}

private struct AdministratorStationHealth {
    let currentReportCount: Int
    let staleReportCount: Int
    let missingReportCount: Int

    init(station: StationDetails) {
        let fuels = FuelGrade.allCases.filter { $0 != .any }
        let latest = fuels.compactMap { fuel in
            station.reports
                .filter { $0.fuel == fuel }
                .max { ($0.reportedAt ?? .distantPast) < ($1.reportedAt ?? .distantPast) }
        }
        currentReportCount = latest.filter { !$0.isStale && $0.reportedAt != nil }.count
        staleReportCount = latest.filter { $0.isStale || $0.reportedAt == nil }.count
        missingReportCount = max(0, fuels.count - latest.count)
    }

    var needsAttention: Bool {
        staleReportCount > 0 || missingReportCount > 0
    }
}

private struct AdministratorStationsView: View {
    let store: StationStore
    @State private var query = ""
    @State private var filter: AdministratorStationFilter = .all

    private var filteredStations: [StationDetails] {
        store.stations.filter { station in
            let matchesQuery = query.isEmpty ||
                [station.name, station.address, station.operatorName]
                    .compactMap { $0 }
                    .contains { $0.localizedCaseInsensitiveContains(query) }
            let health = AdministratorStationHealth(station: station)
            let matchesFilter = switch filter {
            case .all: true
            case .attention: health.needsAttention
            case .current: !health.needsAttention
            }
            return matchesQuery && matchesFilter
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Station status", selection: $filter) {
                ForEach(AdministratorStationFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            AdministratorStationList(
                stations: filteredStations,
                state: store.state,
                retry: { Task { await store.load() } }
            )
        }
        .searchable(text: $query, prompt: "Station or area")
        .refreshable { await store.load() }
        .navigationTitle("Station coverage")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AdministratorStationList: View {
    let stations: [StationDetails]
    let state: StationLoadingState
    let retry: () -> Void

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView("Loading stations…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Stations unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try again", action: retry)
            }
        case .loaded where stations.isEmpty:
            ContentUnavailableView {
                Label("No matching stations", systemImage: "fuelpump")
            } description: {
                Text("Change the search or station-status filter.")
            }
        case .loaded:
            List(stations) { station in
                NavigationLink {
                    AdministratorStationReviewView(station: station)
                } label: {
                    AdministratorStationRow(station: station)
                }
            }
            .listStyle(.plain)
        }
    }
}

private struct AdministratorStationRow: View {
    let station: StationDetails

    private var health: AdministratorStationHealth {
        AdministratorStationHealth(station: station)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(station.name)
                .font(.headline)
            Text(station.address ?? station.operatorName ?? "Address unavailable")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label(
                health.needsAttention
                    ? "\(health.staleReportCount) stale · \(health.missingReportCount) missing"
                    : "All fuel reports current",
                systemImage: health.needsAttention
                    ? "exclamationmark.triangle"
                    : "checkmark.circle"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(health.needsAttention ? .orange : .green)
        }
        .padding(.vertical, 5)
    }
}

private struct AdministratorStationReviewView: View {
    let station: StationDetails

    var body: some View {
        List {
            Section("Station") {
                LabeledContent("Name", value: station.name)
                LabeledContent("Operator", value: station.operatorName ?? "Unavailable")
                LabeledContent("Address", value: station.address ?? "Unavailable")
            }

            Section("Reporting coverage") {
                ForEach(FuelGrade.allCases.filter { $0 != .any }) { fuel in
                    AdministratorFuelCoverageRow(
                        fuel: fuel,
                        report: station.reports
                            .filter { $0.fuel == fuel }
                            .max {
                                ($0.reportedAt ?? .distantPast) <
                                    ($1.reportedAt ?? .distantPast)
                            }
                    )
                }
            }

            Section {
                NavigationLink("Open full station details") {
                    StationDetailsView(station: station)
                }
            }
        }
        .navigationTitle("Station review")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AdministratorFuelCoverageRow: View {
    let fuel: FuelGrade
    let report: StationFuelReport?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(fuel.title)
                .font(.headline)
            if let report {
                Label(
                    report.isStale || report.reportedAt == nil ? "Report stale" : "Report current",
                    systemImage: report.isStale || report.reportedAt == nil
                        ? "clock.badge.exclamationmark"
                        : "checkmark.circle"
                )
                .foregroundStyle(
                    report.isStale || report.reportedAt == nil ? .orange : .green
                )
                if let date = report.reportedAt {
                    Text(date, format: .dateTime.day().month().year().hour().minute())
                        .foregroundStyle(.secondary)
                }
                if let price = report.pricePerLitre {
                    Text(price, format: .currency(code: "LKR"))
                } else {
                    Text("Price missing")
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("Report missing", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.red)
            }
        }
        .font(.subheadline)
        .padding(.vertical, 4)
    }
}

private struct AdministratorUsersView: View {
    let store: AdministratorUserStore
    let currentUserID: String?

    var body: some View {
        Group {
            if store.isLoading && store.users.isEmpty {
                ProgressView("Loading users…")
            } else if store.users.isEmpty {
                ContentUnavailableView(
                    "No user profiles",
                    systemImage: "person.2.slash",
                    description: Text("User profiles will appear after account registration.")
                )
            } else {
                List(store.users) { user in
                    AdministratorUserRow(
                        user: user,
                        canEditRole: user.id != currentUserID
                    ) { role in
                        Task {
                            await store.updateRole(for: user, to: role)
                        }
                    }
                }
                .refreshable {
                    await store.loadUsers()
                }
            }
        }
        .navigationTitle("User access")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AdministratorUserRow: View {
    let user: AdministratorUser
    let canEditRole: Bool
    let updateRole: (AccountRole) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: roleSymbol)
                .foregroundStyle(Color("WelcomeAccent"))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(user.displayName.isEmpty ? user.email : user.displayName)
                    .font(.headline)
                if !user.displayName.isEmpty {
                    Text(user.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if canEditRole {
                Menu(roleTitle) {
                    Button("Customer") {
                        updateRole(.customer)
                    }
                    Button("Station manager") {
                        updateRole(.manager)
                    }
                    Button("Administrator") {
                        updateRole(.administrator)
                    }
                }
                .accessibilityLabel("Role for \(user.email)")
            } else {
                Text("Current admin")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var roleTitle: String {
        switch user.role {
        case .customer: "Customer"
        case .manager: "Manager"
        case .administrator: "Admin"
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

private struct AdministratorAccountView: View {
    let authentication: AuthenticationSession

    var body: some View {
        List {
            Section("Signed in account") {
                LabeledContent("Role", value: "Administrator")
                LabeledContent("Email", value: authentication.currentAccount?.email ?? "Unavailable")
            }

            Section {
                NavigationLink("Privacy and account") {
                    AccountPrivacyView(
                        authentication: authentication,
                        allowsAccountDeletion: false
                    )
                }
                Button("Sign out", role: .destructive, action: authentication.signOut)
            }
        }
        .navigationTitle("Administrator account")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    AdministratorWorkspaceView(authentication: AuthenticationSession())
}
