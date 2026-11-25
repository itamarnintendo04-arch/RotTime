import FamilyControls
import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Draws RotTime's custom shield: the brain mascot, a friendly title, a reflection
/// prompt and (for non-strict shields) a two-step "mindful pause" option.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(name: application.localizedDisplayName, pauseKey: application.token.map { MindfulPause.key(for: $0) })
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: application.localizedDisplayName ?? category.localizedDisplayName,
             pauseKey: application.token.map { MindfulPause.key(for: $0) })
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(name: webDomain.domain, pauseKey: webDomain.token.map { MindfulPause.key(for: $0) })
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: webDomain.domain ?? category.localizedDisplayName,
             pauseKey: webDomain.token.map { MindfulPause.key(for: $0) })
    }

    private func make(name: String?, pauseKey: String?) -> ShieldConfiguration {
        let brain = SharedStore.brainName
        let target = name ?? "this app"
        let palette = ShieldPalette.forTheme(SharedStore.selectedThemeID)
        let settings = SharedStore.unlockSettings
        let strict = ShieldController.anyStrictActive
        let allowPause = settings.enabled && !strict

        var title = String(format: ShieldCopy.pick(ShieldCopy.titles), brain)
        var subtitle = String(format: ShieldCopy.pick(ShieldCopy.reflections, salt: 3), target)
        var secondary: String? = allowPause ? "Take a mindful pause" : nil

        if allowPause, let key = pauseKey, let remaining = MindfulPause.secondsRemaining(for: key, settings: settings) {
            if remaining > 0 {
                title = "Breathe with \(brain)"
                subtitle = String(format: ShieldCopy.pick(ShieldCopy.breathing), remaining)
                secondary = "I'm ready"
            } else {
                title = "Nice pause!"
                subtitle = "If you still want \(target), it opens for \(settings.unlockMinutes) minutes. Or stay focused — your call."
                secondary = "Open for \(settings.unlockMinutes) min"
            }
        } else if strict {
            subtitle += "\n\nThis is a strict session, so the shield stays up until it ends."
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: palette.background.withAlphaComponent(0.92),
            icon: UIImage(named: "ShieldBrain"),
            title: ShieldConfiguration.Label(text: title, color: palette.title),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: palette.subtitle),
            primaryButtonLabel: ShieldConfiguration.Label(text: "I'll stay focused", color: palette.buttonText),
            primaryButtonBackgroundColor: palette.button,
            secondaryButtonLabel: secondary.map { ShieldConfiguration.Label(text: $0, color: palette.secondaryText) }
        )
    }
}
