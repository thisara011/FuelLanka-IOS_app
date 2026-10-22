//
//  FuelLankaApp.swift
//  FuelLanka
//
//  Created by Thisara Madhubashana Edirisingha on 2026-10-17.
//

import SwiftUI
import SwiftData

@main
struct FuelLankaApp: App {
    @UIApplicationDelegateAdaptor(FirebaseAppDelegate.self) private var appDelegate
    @State private var authentication: AuthenticationSession

    init() {
        FirebaseConfiguration.configureIfNeeded()
        let service: any AuthenticationService = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            ? UITestAuthenticationService()
            : FirebaseAuthenticationService()
        _authentication = State(initialValue: AuthenticationSession(service: service))
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(authentication: authentication)
        }
        .modelContainer(sharedModelContainer)
    }
}

@MainActor
private struct UITestAuthenticationService: AuthenticationService {
    func restoreAccount() async throws -> AuthenticatedAccount? { nil }

    func signIn(email: String, password: String) async throws -> AuthenticatedAccount {
        throw AuthenticationIssue.configurationMissing
    }

    func registerCustomer(email: String, password: String) async throws -> AuthenticatedAccount {
        throw AuthenticationIssue.configurationMissing
    }

    func sendRegistrationLink(email: String) async throws {
        throw AuthenticationIssue.configurationMissing
    }

    func completeRegistrationLink(_ url: URL) async throws -> AuthenticatedAccount {
        throw AuthenticationIssue.configurationMissing
    }

    func updatePassword(_ password: String) async throws {
        throw AuthenticationIssue.configurationMissing
    }

    func sendPasswordReset(email: String) async throws {
        throw AuthenticationIssue.configurationMissing
    }

    func signOut() throws {}
}
