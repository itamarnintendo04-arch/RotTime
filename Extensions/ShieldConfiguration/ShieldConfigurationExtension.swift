import FamilyControls
import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Draws RotTime's custom shield: the brain mascot, a friendly title, a reflection
/// prompt and (for non-strict shields) an "I want more time" button that starts
/// the in-app conversation with the brain.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: application.localizedDisplayName ?? category.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: webDomain.domain ?? category.localizedDisplayName)
    }

    private func make(name: String?) -> ShieldConfiguration {
        let brain = SharedStore.brainName
        let target = name ?? "this app"
        let palette = ShieldPalette.forTheme(SharedStore.selectedThemeID)
        let strict = ShieldController.anyStrictActive
        let allowMoreTime = SharedStore.unlockSettings.enabled && !strict

        let title = String(format: ShieldCopy.pick(ShieldCopy.titles), brain)
        var subtitle = String(format: ShieldCopy.pick(ShieldCopy.reflections, salt: 3), target)
        if allowMoreTime {
            subtitle += "\n\n" + String(format: ShieldCopy.pick(ShieldCopy.moreTimeHints, salt: 7), brain)
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
            secondaryButtonLabel: allowMoreTime ? ShieldConfiguration.Label(text: "I want more time", color: palette.secondaryText) : nil
        )
    }
}
