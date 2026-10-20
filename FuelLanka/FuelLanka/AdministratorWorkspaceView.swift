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
                    role: role
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
                    role: role
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
    case users
    case account
}

struct AdministratorWorkspaceView: View {
    let authentication: AuthenticationSession

    @State private var userStore = AdministratorUserStore()
    @State private var selectedTab: AdministratorTab = .overview

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Overview", systemImage: "chart.bar.xaxis", value: .overview) {
                NavigationStack {
                    AdministratorOverviewView(users: userStore.users) {
                        selectedTab = .users
                    }
                }
            }

            Tab("Users", systemImage: "person.2", value: .users) {
                NavigationStack {
                    AdministratorUsersView(
                        store: userStore,
                        currentUserID: authentication.currentAccount?.id
                    )
                }
            }

            Tab("Account", systemImage: "person.crop.circle", value: .account) {
                NavigationStack {
                    AdministratorAccountView(
                        email: authentication.currentAccount?.email,
                        signOut: authentication.signOut
                    )
                }
            }
        }
        .tint(Color("WelcomeAccent"))
        .task {
            await userStore.loadUsers()
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
    let showUsers: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                AdministratorHeader()
                AdministratorRoleSummary(users: users)
                Button(action: showUsers) {
                    Label("Manage user access", systemImage: "person.badge.key")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
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
    let email: String?
    let signOut: () -> Void

    var body: some View {
        List {
            Section("Signed in account") {
                LabeledContent("Role", value: "Administrator")
                LabeledContent("Email", value: email ?? "Unavailable")
            }

            Section {
                Button("Sign out", role: .destructive, action: signOut)
            }
        }
        .navigationTitle("Administrator account")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    AdministratorWorkspaceView(authentication: AuthenticationSession())
}
