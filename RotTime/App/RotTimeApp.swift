import SwiftUI
import UserNotifications

@main
struct RotTimeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var app = AppState.shared
    @StateObject private var screenTime = ScreenTimeManager.shared
    @StateObject private var focus = FocusTimerModel.shared
    @StateObject private var chat = ChatEngineStore.shared
    @StateObject private var interventions = InterventionCenter.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(app)
                .environmentObject(screenTime)
                .environmentObject(focus)
                .environmentObject(chat)
                .environmentObject(interventions)
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
        // A shield's "I want more time" button may have queued a request.
        interventions.presentPendingIfNeeded()
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
            let content = response.notification.request.content
            if response.notification.request.identifier == NotificationManager.focusEndID {
                AppState.shared.selectedTab = .focus
            } else if content.categoryIdentifier == MoreTimeRequests.notificationCategory {
                InterventionCenter.shared.presentPendingIfNeeded(requestID: content.userInfo["requestID"] as? String)
            }
        }
    }
}
