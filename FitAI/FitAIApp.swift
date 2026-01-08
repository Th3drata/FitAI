import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

//test for no connection message
import UIKit
import SystemConfiguration

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Vérifiez l'état de la connexion Internet
        if isInternetAvailable() {
            print("Connecté à internet")
        } else {
            print("Pas de connexion à internet")
            // Ici, vous pouvez ajouter une bannière ou un message pour indiquer que l'application est en mode hors-ligne
        }
    }
    
    func isInternetAvailable() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        var flags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
            return false
        }
        
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        return (isReachable && !needsConnection)
    }
}

@main
struct FitAIApp: App {
    @StateObject private var dataStore = DataStore.shared
    @StateObject private var localization = LocalizationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var notificationManager = NotificationManager.shared

    init() {
        // Configure Firebase
        FirebaseApp.configure()

        // Configure appearance
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environmentObject(localization)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .tint(themeManager.primaryColor)
                .onAppear {
                    // Sync language with profile
                    if let profile = dataStore.profile {
                        localization.setLanguage(profile.language)
                        // Re-schedule notifications on app launch
                        rescheduleNotificationsIfNeeded(profile: profile)
                    }
                }
                .onOpenURL { url in
                    // Handle Google Sign-In callback
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }

    private func rescheduleNotificationsIfNeeded(profile: UserProfile) {
        guard profile.notificationsEnabled else { return }

        // Check and reschedule notifications
        notificationManager.checkAuthorizationStatus()

        // Schedule daily workout reminder
        NotificationManager.shared.scheduleDailyWorkoutReminder(
            profile: profile,
            localization: localization
        )

        // Schedule weekly summary reminder
        NotificationManager.shared.scheduleWeeklyProgramReminder(
            localization: localization
        )

        // Debug: List pending notifications
        NotificationManager.shared.listPendingNotifications()
    }

    private func configureAppearance() {
        // Tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance

        // Tint color
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(AppTheme.primaryTeal)
    }
}
