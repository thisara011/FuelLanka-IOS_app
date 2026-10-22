import SwiftUI

/// Account-scoped alerts supplied by the notification service.
struct CustomerNotification: Identifiable, Equatable {
    let id: String
    let stationID: String
    let title: String
    let message: String
    let receivedAt: Date?
    let station: StationDetails?
}

enum NotificationInboxState: Equatable {
    case loading
    case unavailable
    case loaded([CustomerNotification])
}

struct CustomerNotificationsView: View {
    private let previewState: NotificationInboxState?
    @State private var notificationService = NotificationService.shared
    @State private var showsPreferences = false

    init(state: NotificationInboxState? = nil) {
        previewState = state
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Recent alerts")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                switch previewState ?? notificationService.inboxState {
                case .loading:
                    ProgressView("Loading alerts…")
                        .frame(maxWidth: .infinity, minHeight: 120)
                case .unavailable:
                    ContentUnavailableView {
                        Label("Alerts unavailable", systemImage: "bell.slash")
                    } description: {
                        Text("Your account’s notifications cannot be loaded yet.")
                    }
                    .notificationCard()
                case .loaded(let alerts):
                    if alerts.isEmpty {
                        ContentUnavailableView {
                            Label("No notifications yet", systemImage: "bell")
                        } description: {
                            Text("Alerts for your saved stations will appear here when available.")
                        }
                        .notificationCard()
                    } else {
                        ForEach(alerts.sorted {
                            ($0.receivedAt ?? .distantPast) > ($1.receivedAt ?? .distantPast)
                        }) { alert in
                            NavigationLink {
                                CustomerNotificationDetailView(alert: alert)
                            } label: {
                                NotificationSummary(alert: alert)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button { showsPreferences = true } label: {
                    Label("Alert preferences", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.bordered)
                Text("An alert describes a past report. Check the station’s latest report before travelling.")
                    .font(.footnote)
                    .foregroundStyle(Color("WelcomeSecondary"))
            }
            .padding(26)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background {
            LinearGradient(
                colors: [Color("WelcomeBackgroundTop"), Color("WelcomeBackgroundBottom")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("WelcomeAccent"))
        .alert("Manage alert preferences", isPresented: $showsPreferences) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Open Profile → Alert preferences to update restock and price alerts.")
        }
    }
}

private struct NotificationSummary: View {
    let alert: CustomerNotification

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(alert.title).font(.headline)
                    .foregroundStyle(Color("WelcomeHeading"))
                Text(alert.message).font(.subheadline)
                    .foregroundStyle(Color("WelcomeSecondary"))
                if let date = alert.receivedAt {
                    Text(date, format: .dateTime.day().month().year().hour().minute())
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Alert time unavailable").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(Color("WelcomeAccent"))
                .accessibilityHidden(true)
        }
        .notificationCard()
        .accessibilityElement(children: .combine)
    }
}

private struct CustomerNotificationDetailView: View {
    let alert: CustomerNotification

    var body: some View {
        List {
            Section {
                Text(alert.title).font(.title3.bold())
                Text(alert.message)
                if let date = alert.receivedAt {
                    Text("Received \(date.formatted(date: .abbreviated, time: .shortened))")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Alert time unavailable").foregroundStyle(.secondary)
                }
            }
            Section {
                if let station = alert.station {
                    NavigationLink {
                        StationDetailsView(station: station)
                    } label: {
                        Label("View \(station.name)", systemImage: "fuelpump")
                    }
                } else {
                    Text("Station details are unavailable for this alert.")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("This notification does not guarantee current fuel availability.")
            }
        }
        .navigationTitle("Alert details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension View {
    func notificationCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

#Preview("Notifications Unavailable") {
    NavigationStack { CustomerNotificationsView() }
}

#Preview("Notifications Empty") {
    NavigationStack { CustomerNotificationsView(state: .loaded([])) }
}

#Preview("Notifications Loading") {
    NavigationStack { CustomerNotificationsView(state: .loading) }
}
