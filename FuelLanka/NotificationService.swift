import Foundation
import Observation
import UIKit
import UserNotifications

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct NotificationRoute: Equatable {
    let stationID: String
}

@MainActor
@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()

    private(set) var pendingRoute: NotificationRoute?

    private init() {}

    func route(toStationID stationID: String) {
        guard !stationID.isEmpty else { return }
        pendingRoute = NotificationRoute(stationID: stationID)
    }

    func consume() {
        pendingRoute = nil
    }
}

enum NotificationPermissionResult: Equatable {
    case enabled
    case disabled
    case denied
    case unavailable
}

@MainActor
@Observable
final class NotificationService {
    static let shared = NotificationService()

    private(set) var inboxState: NotificationInboxState = .unavailable

    private let center = UNUserNotificationCenter.current()
    private let seenAlertIDsKey = "FuelLankaSeenStationAlertIDs"

    #if canImport(FirebaseFirestore)
    private var alertListener: ListenerRegistration?
    #endif

    private var isInitialSnapshot = true
    private var activeUserID: String?
    private var knownStations: [StationDetails] = []

    private init() {}

    func configure() {
        center.delegate = FirebaseAppDelegate.shared
        registerCategories()
    }

    func syncForCurrentPreferences(userID: String, stations: [StationDetails] = []) async {
        #if canImport(FirebaseFirestore)
        guard FirebaseConfiguration.isAvailable, !userID.isEmpty else {
            inboxState = .unavailable
            return
        }

        do {
            if !stations.isEmpty {
                knownStations = stations
            }
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(userID)
                .getDocument()
            let data = snapshot.data()
            let restockAlerts = data?["restockAlerts"] as? Bool ?? false
            let priceAlerts = data?["priceAlerts"] as? Bool ?? false
            let favouriteIDs = Set(data?["favouriteStationIDs"] as? [String] ?? [])
            let fuelValues = data?["preferredFuels"] as? [String] ?? []
            let preferredFuels = Set(fuelValues)

            _ = await syncPreferences(
                restockAlerts: restockAlerts,
                priceAlerts: priceAlerts,
                userID: userID
            )
            startFreeAlertListener(
                userID: userID,
                favouriteStationIDs: favouriteIDs,
                preferredFuelValues: preferredFuels,
                restockAlerts: restockAlerts,
                priceAlerts: priceAlerts,
                stations: knownStations
            )
        } catch {
            inboxState = .unavailable
            print("Notification preference sync failed: \(error.localizedDescription)")
        }
        #else
        inboxState = .unavailable
        #endif
    }

    func syncPreferences(
        restockAlerts: Bool,
        priceAlerts: Bool,
        userID: String
    ) async -> NotificationPermissionResult {
        guard restockAlerts || priceAlerts else {
            stopListening()
            return .disabled
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted ? .enabled : .denied
        } catch {
            print("Notification authorization failed: \(error.localizedDescription)")
            return .unavailable
        }
    }

    func removeCurrentToken(userID: String? = nil) async {
        stopListening()
        inboxState = .unavailable
    }

    func handleNotification(userInfo: [AnyHashable: Any]) {
        let stationID = userInfo["stationID"] as? String
            ?? userInfo["stationId"] as? String
        guard let stationID else { return }
        NotificationRouter.shared.route(toStationID: stationID)
    }

    private func registerCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_STATION",
            title: String(localized: "View station"),
            options: [.foreground]
        )
        let stationCategory = UNNotificationCategory(
            identifier: "STATION_ALERT",
            actions: [viewAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([stationCategory])
    }

    private func stopListening() {
        #if canImport(FirebaseFirestore)
        alertListener?.remove()
        alertListener = nil
        #endif
        activeUserID = nil
        isInitialSnapshot = true
    }

    #if canImport(FirebaseFirestore)
    private func startFreeAlertListener(
        userID: String,
        favouriteStationIDs: Set<String>,
        preferredFuelValues: Set<String>,
        restockAlerts: Bool,
        priceAlerts: Bool,
        stations: [StationDetails]
    ) {
        guard restockAlerts || priceAlerts else {
            inboxState = .loaded([])
            stopListening()
            return
        }

        alertListener?.remove()
        activeUserID = userID
        isInitialSnapshot = true
        inboxState = .loading

        alertListener = Firestore.firestore()
            .collection("stationAlerts")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self, self.activeUserID == userID else { return }
                    guard error == nil, let snapshot else {
                        self.inboxState = .unavailable
                        return
                    }

                    let stationByID = Dictionary(
                        uniqueKeysWithValues: stations.map { ($0.id, $0) }
                    )
                    let alerts = snapshot.documents.compactMap { document in
                        Self.customerNotification(
                            from: document,
                            favouriteStationIDs: favouriteStationIDs,
                            preferredFuelValues: preferredFuelValues,
                            restockAlerts: restockAlerts,
                            priceAlerts: priceAlerts,
                            stationByID: stationByID
                        )
                    }
                    self.inboxState = .loaded(alerts)

                    if !self.isInitialSnapshot {
                        for change in snapshot.documentChanges where change.type == .added {
                            guard let alert = Self.customerNotification(
                                from: change.document,
                                favouriteStationIDs: favouriteStationIDs,
                                preferredFuelValues: preferredFuelValues,
                                restockAlerts: restockAlerts,
                                priceAlerts: priceAlerts,
                                stationByID: stationByID
                            ) else { continue }
                            await self.scheduleLocalNotification(for: alert)
                        }
                    }
                    self.isInitialSnapshot = false
                }
            }
    }

    private static func customerNotification(
        from document: QueryDocumentSnapshot,
        favouriteStationIDs: Set<String>,
        preferredFuelValues: Set<String>,
        restockAlerts: Bool,
        priceAlerts: Bool,
        stationByID: [String: StationDetails]
    ) -> CustomerNotification? {
        let data = document.data()
        guard let stationID = data["stationID"] as? String,
              favouriteStationIDs.contains(stationID),
              let kind = data["kind"] as? String,
              let fuel = data["fuel"] as? String else {
            return nil
        }
        guard preferredFuelValues.isEmpty || preferredFuelValues.contains(fuel) else {
            return nil
        }
        guard (kind == "restock" && restockAlerts) || (kind == "price" && priceAlerts) else {
            return nil
        }

        return CustomerNotification(
            id: document.documentID,
            stationID: stationID,
            title: data["title"] as? String ?? "Station update",
            message: data["message"] as? String ?? "New information is available.",
            receivedAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            station: stationByID[stationID]
        )
    }
    #endif

    private func scheduleLocalNotification(for alert: CustomerNotification) async {
        var seenIDs = Set(UserDefaults.standard.stringArray(forKey: seenAlertIDsKey) ?? [])
        guard seenIDs.insert(alert.id).inserted else { return }
        UserDefaults.standard.set(Array(seenIDs.suffix(200)), forKey: seenAlertIDsKey)

        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.message
        content.sound = .default
        content.categoryIdentifier = "STATION_ALERT"
        content.userInfo = ["stationID": alert.stationID]

        do {
            try await center.add(UNNotificationRequest(
                identifier: alert.id,
                content: content,
                trigger: nil
            ))
        } catch {
            print("Local station alert could not be scheduled: \(error.localizedDescription)")
        }
    }
}

extension FirebaseAppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            NotificationService.shared.handleNotification(
                userInfo: response.notification.request.content.userInfo
            )
        }
    }
}
