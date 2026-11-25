import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

/// Handles taps on the shield buttons.
///
/// * Primary ("I'll stay focused") closes the app and counts as a win.
/// * Secondary runs the mindful-pause flow: first tap starts a waiting period (`.defer`
///   re-renders the shield with breathing copy); a tap after the wait temporarily
///   exempts just this app/site and schedules the shield to come back.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, key: MindfulPause.key(for: application), completionHandler) { minutes in
            ShieldController.grantTemporaryUnlock(application: application, minutes: minutes)
        }
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, key: MindfulPause.key(for: webDomain), completionHandler) { minutes in
            ShieldController.grantTemporaryUnlock(webDomain: webDomain, minutes: minutes)
        }
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, key: MindfulPause.key(for: category), completionHandler) { minutes in
            ShieldController.grantTemporaryUnlock(category: category, minutes: minutes)
        }
    }

    private func respond(_ action: ShieldAction, key: String,
                         _ completion: @escaping (ShieldActionResponse) -> Void,
                         unlock: (Int) -> Bool) {
        switch action {
        case .primaryButtonPressed:
            MindfulPause.clear(for: key)
            SharedStore.updateToday { $0.shieldResists += 1 }
            SharedStore.appendExtensionEvent(ExtensionEvent(kind: .shieldResisted))
            completion(.close)

        case .secondaryButtonPressed:
            let settings = SharedStore.unlockSettings
            guard settings.enabled, !ShieldController.anyStrictActive else {
                completion(.close)
                return
            }
            if let remaining = MindfulPause.secondsRemaining(for: key, settings: settings) {
                if remaining > 0 {
                    completion(.defer) // Still breathing – re-render with the countdown copy.
                } else {
                    MindfulPause.clear(for: key)
                    if unlock(settings.unlockMinutes) {
                        SharedStore.updateToday { $0.mindfulUnlocks += 1 }
                        SharedStore.appendExtensionEvent(ExtensionEvent(kind: .mindfulUnlock))
                    }
                    completion(.defer)
                }
            } else {
                MindfulPause.begin(for: key)
                completion(.defer)
            }

        @unknown default:
            completion(.close)
        }
    }
}
