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
    @State private var authentication = AuthenticationSession()

    init() {
        FirebaseConfiguration.configureIfNeeded()
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
