import Foundation
import UserNotifications

/// Local notifications only — used so timers finish correctly while the app is suspended.
enum NotificationManager {
    static let focusEndID = "rt.focus.end"
    static let checkInID = "rt.checkin"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func scheduleFocusEnd(at date: Date, phase: SharedFocusSession.Phase, brainName: String) {
        let content = UNMutableNotificationContent()
        switch phase {
        case .focus:
            content.title = "Focus complete! 🎉"
            content.body = "\(brainName) is doing a happy dance. Time for a little break."
        case .rest:
            content.title = "Break's over"
            content.body = "\(brainName) is refreshed and ready when you are."
        }
        content.sound = .default
        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: focusEndID, content: content, trigger: trigger))
    }

    static func cancelFocusEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [focusEndID])
    }

    static func updateCheckIn(enabled: Bool, hour: Int, minute: Int, brainName: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [checkInID])
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(brainName) says good morning"
        content.body = [
            "Want to plan one focus session today?",
            "A quick check-in keeps your streak glowing.",
            "Your brain buddy saved you a seat. Come say hi!",
        ].randomElement() ?? ""
        content.sound = .default
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        center.add(UNNotificationRequest(identifier: checkInID, content: content,
                                         trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
    }
}
