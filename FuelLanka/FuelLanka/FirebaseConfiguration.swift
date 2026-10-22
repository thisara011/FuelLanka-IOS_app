import Foundation
import UIKit

#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum FirebaseConfiguration {
    static var hasConfigurationFile: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    static var isAvailable: Bool {
        #if canImport(FirebaseCore)
        hasConfigurationFile && FirebaseApp.app() != nil
        #else
        false
        #endif
    }

    static func configureIfNeeded() {
        #if canImport(FirebaseCore)
        guard hasConfigurationFile, FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
        #endif
    }
}

final class FirebaseAppDelegate: NSObject, UIApplicationDelegate {
    static weak var shared: FirebaseAppDelegate?

    override init() {
        super.init()
        Self.shared = self
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseConfiguration.configureIfNeeded()
        Task { @MainActor in
            NotificationService.shared.configure()
        }
        return true
    }
}
