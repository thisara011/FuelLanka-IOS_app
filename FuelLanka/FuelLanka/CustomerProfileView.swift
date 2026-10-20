import SwiftUI

struct CustomerProfileView: View {
    let authentication: AuthenticationSession
    let onFindStations: () -> Void

    @State private var showsEdit = false
    @State private var profileStore = CustomerProfileStore()

    private var account: AuthenticatedAccount? {
        authentication.currentAccount
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CustomerProfileHeader(
                    fullName: profileStore.profile.fullName,
                    email: profileStore.profile.email,
                    isLoading: profileStore.state == .loading,
                    onEdit: { showsEdit = true }
                )

                ProfileSectionHeading("Personal information")
                editRow(
                    "Phone number",
                    detail: profileStore.profile.phone.nilIfEmpty ?? "Not added"
                )
                editRow(
                    "Location",
                    detail: profileStore.profile.district.nilIfEmpty.map { "Sri Lanka · \($0)" } ?? "Sri Lanka · district not added"
                )

                ProfileSectionHeading("Fuel preferences")
                editRow(
                    "Preferred fuels and district",
                    detail: fuelPreferenceDescription
                )

                ProfileSectionHeading("Account and alerts")
                NavigationLink {
                    CustomerNotificationsView()
                } label: {
                    ProfileRow(title: "Notifications", detail: "Recent restock and price alerts")
                }
                NavigationLink {
                    AccountSecurityView(authentication: authentication)
                } label: {
                    ProfileRow(title: "Face ID and security", detail: "Biometric setup and password recovery")
                }
                editRow("Alert preferences", detail: alertPreferenceDescription)

                ProfileSectionHeading("Your fuel tools")
                NavigationLink {
                    FavouritesView(onFindStations: onFindStations)
                } label: {
                    ProfileRow(title: "Favourite stations", detail: "Saved station availability")
                }
                NavigationLink {
                    FuelComparisonView()
                } label: {
                    ProfileRow(title: "Fuel prices", detail: "Reported prices and comparison")
                }

                Button("Sign out", role: .destructive) {
                    authentication.signOut()
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.bordered)
            }
            .buttonStyle(.plain)
            .padding(24)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await loadProfile() }
        .background(Color("WelcomeBackgroundTop"))
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("WelcomeAccent"))
        .sheet(isPresented: $showsEdit) {
            if let account, let email = account.email {
                NavigationStack {
                    EditCustomerProfileView(
                        store: profileStore,
                        userID: account.id,
                        email: email
                    )
                }
            }
        }
        .task(id: account?.id) {
            await loadProfile()
        }
    }

    private var fuelPreferenceDescription: String {
        let fuels = profileStore.profile.preferredFuels
            .map { String(localized: $0.title) }
            .sorted()
        let fuelText = fuels.isEmpty ? "No preferred fuels" : fuels.formatted()
        let district = profileStore.profile.district.nilIfEmpty ?? "No district"
        return "\(fuelText) · \(district)"
    }

    private var alertPreferenceDescription: String {
        var enabled: [String] = []
        if profileStore.profile.restockAlerts { enabled.append("Restock") }
        if profileStore.profile.priceAlerts { enabled.append("Price") }
        return enabled.isEmpty ? "No alerts enabled" : "\(enabled.formatted()) alerts enabled"
    }

    private func editRow(_ title: String, detail: String) -> some View {
        Button { showsEdit = true } label: {
            ProfileRow(title: title, detail: detail)
        }
    }

    private func loadProfile() async {
        guard let account else { return }
        await profileStore.load(userID: account.id, fallbackEmail: account.email)
    }
}

private struct CustomerProfileHeader: View {
    let fullName: String
    let email: String
    let isLoading: Bool
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image("ProfileAvatarBackground")
                    .frame(width: 57, height: 57)
                    .overlay {
                        Image(systemName: "person")
                            .foregroundStyle(Color("WelcomeAccent"))
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    if isLoading {
                        ProgressView("Loading profile…")
                    } else {
                        Text(fullName.nilIfEmpty ?? email.nilIfEmpty ?? "Customer")
                            .font(.headline)
                        Text(email.nilIfEmpty ?? "Email unavailable")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button("Edit profile", action: onEdit)
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
        }
        .profileCard()
    }
}

private struct ProfileSectionHeading: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.title3.bold())
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ProfileRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color("WelcomeHeading"))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(Color("WelcomeAccent"))
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .profileCard()
    }
}

private extension String {
    var nilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private extension View {
    func profileCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 19))
    }
}

#Preview("Customer Profile") {
    NavigationStack {
        CustomerProfileView(
            authentication: AuthenticationSession(),
            onFindStations: {}
        )
    }
}
