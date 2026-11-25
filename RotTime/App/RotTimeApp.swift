import SwiftUI
import UserNotifications

@main
struct RotTimeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var app = AppState.shared
    @StateObject private var screenTime = ScreenTimeManager.shared
    @StateObject private var focus = FocusTimerModel.shared
    @StateObject private var chat = ChatEngineStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(app)
                .environmentObject(screenTime)
                .environmentObject(focus)
                .environmentObject(chat)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { syncOnForeground() }
                }
                .onAppear { syncOnForeground() }
        }
    }

    /// Catch up with anything that happened while RotTime was suspended.
    private func syncOnForeground() {
        screenTime.refresh()
        focus.reconcile()
        app.refreshShared()
        let events = SharedStore.drainExtensionEvents()
        if app.profile.onboardingComplete {
            chat.ingestExtensionEvents(events)
            chat.runDailyEventsIfNeeded()
        }
        app.evaluateRewards()
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Show banners even while the app is open (e.g. focus finished).
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run {
            if response.notification.request.identifier == NotificationManager.focusEndID {
                AppState.shared.selectedTab = .focus
            }
        }
    }
}
