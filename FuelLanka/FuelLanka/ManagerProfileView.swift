import SwiftUI

/// Identity supplied by the authenticated account service, never inferred from a station.
struct ManagerProfile {
    let fullName: String
    let email: String
    let phone: String?
}

struct ManagerProfileView: View {
    let authentication: AuthenticationSession
    let station: StationDetails?
    var profile: ManagerProfile? = nil
    @State private var showsEditNotice = false
    @State private var showsSignOutNotice = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("My profile").font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 10) {
                    Text(profile?.fullName ?? "Account details unavailable").font(.title3.bold())
                    Text(station?.name ?? "Station assignment unavailable").font(.subheadline)
                    Text(profile?.email ?? "Email unavailable").font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .foregroundStyle(.white)
                .background(Color(red: 0.07, green: 0.18, blue: 0.29), in: RoundedRectangle(cornerRadius: 20))

                Button { showsEditNotice = true } label: {
                    Label("Edit profile", systemImage: "pencil")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.bordered)
                Button("Log out", role: .destructive) {
                    authentication.signOut()
                }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .buttonStyle(.bordered)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Personal details").font(.headline).accessibilityAddTraits(.isHeader)
                    ManagerProfileField(title: "Full name", value: profile?.fullName)
                    Divider()
                    ManagerProfileField(title: "Email", value: profile?.email)
                    Divider()
                    ManagerProfileField(title: "Phone", value: profile?.phone)
                }
                .managerProfileCard()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Station access").font(.headline).accessibilityAddTraits(.isHeader)
                    ManagerProfileField(title: "Workspace", value: "Station manager")
                    Divider()
                    ManagerProfileField(title: "Assigned station", value: station?.name)
                    Divider()
                    ManagerProfileField(title: "Location", value: station?.address)
                    Text("Station assignments are managed by an administrator.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .managerProfileCard()

                NavigationLink {
                    StationDetailsView(station: station)
                } label: {
                    Label("Station details", systemImage: "building.2")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.bordered)
                NavigationLink {
                    AccountSecurityView(authentication: authentication)
                } label: {
                    Label("Sign-in and security", systemImage: "lock")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.bordered)
                NavigationLink {
                    ManagerNotificationsView(station: station)
                } label: {
                    Label("Operational notifications", systemImage: "bell")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.bordered)
                NavigationLink {
                    ManagerAnalyticsView(station: station)
                } label: {
                    Label("Station analytics", systemImage: "chart.bar")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background {
            LinearGradient(colors: [Color("WelcomeBackgroundTop"), Color("WelcomeBackgroundBottom")],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        }
        .navigationTitle("Manager profile")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("WelcomeAccent"))
        .sheet(isPresented: $showsEditNotice) {
            NavigationStack {
                EditManagerProfileView(profile: profile, station: station)
            }
        }
        .alert("Account service unavailable", isPresented: $showsSignOutNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Session management is not connected yet. No account session has been changed.")
        }
    }
}

private struct ManagerProfileField: View {
    let title: LocalizedStringKey
    let value: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value?.isEmpty == false ? value ?? "Unavailable" : "Unavailable")
                .font(.body.weight(.medium))
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    func managerProfileCard() -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview("Manager Profile") {
    NavigationStack {
        ManagerProfileView(
            authentication: AuthenticationSession(),
            station: nil
        )
    }
}
