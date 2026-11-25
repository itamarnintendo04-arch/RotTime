import FamilyControls
import Foundation
import ManagedSettings

/// Handles taps on the shield buttons.
///
/// * Primary ("I'll stay focused") closes the app and counts as a win.
/// * Secondary ("I want more time") records a request and sends a notification
///   (“Noodle is calling you…”). Tapping it opens RotTime, where the brain talks it over
///   — by chat, a pretend FaceTime call, a voice message, a letter or a breathing moment —
///   before any extra time is granted. Shield extensions can't open apps themselves,
///   so a notification is the supported path.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler) { MoreTimeRequests.create(kind: .application, token: application) }
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler) { MoreTimeRequests.create(kind: .webDomain, token: webDomain) }
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler) { MoreTimeRequests.create(kind: .category, token: category) }
    }

    private func respond(_ action: ShieldAction,
                         _ completion: @escaping (ShieldActionResponse) -> Void,
                         request: () -> MoreTimeRequest?) {
        switch action {
        case .primaryButtonPressed:
            SharedStore.updateToday { $0.shieldResists += 1 }
            SharedStore.appendExtensionEvent(ExtensionEvent(kind: .shieldResisted))
            completion(.close)

        case .secondaryButtonPressed:
            guard SharedStore.unlockSettings.enabled, !ShieldController.anyStrictActive else {
                completion(.close)
                return
            }
            if request() != nil {
                SharedStore.appendExtensionEvent(ExtensionEvent(kind: .moreTimeRequested))
            }
            completion(.close)

        @unknown default:
            completion(.close)
        }
    }
}
