import Foundation
import FamilyControls
import ManagedSettings

/// Applies and removes real Screen Time shields using named `ManagedSettingsStore`s.
///
/// Every source of blocking (instant block, a schedule, the focus timer, a usage limit)
/// gets its own named store, so ending one never lifts another. The same code runs inside
/// the app and inside the DeviceActivityMonitor / ShieldAction extensions.
public enum ShieldController {
    public static func store(for key: String) -> ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: key))
    }

    /// Shields `selection` under `key` and records it as active.
    public static func activate(_ shield: ActiveShield) {
        var shields = SharedStore.activeShields
        var record = shield
        // Keep exemptions that are still running if this key was already active.
        if let existing = shields[shield.key], let until = existing.exemptionEndsAt, until > Date() {
            record.exemptApplications = existing.exemptApplications
            record.exemptWebDomains = existing.exemptWebDomains
            record.exemptCategories = existing.exemptCategories
            record.exemptionEndsAt = until
        }
        shields[shield.key] = record
        SharedStore.activeShields = shields
        write(record)
    }

    public static func deactivate(key: String) {
        store(for: key).clearAllSettings()
        var shields = SharedStore.activeShields
        shields.removeValue(forKey: key)
        SharedStore.activeShields = shields
    }

    public static func isActive(key: String) -> Bool {
        SharedStore.activeShields[key] != nil
    }

    /// Writes the managed settings for a record, honouring temporary exemptions.
    static func write(_ record: ActiveShield) {
        let store = store(for: record.key)
        let selection = record.selection

        let apps = selection.applicationTokens.subtracting(record.exemptApplications)
        store.shield.applications = apps.isEmpty ? nil : apps

        let categories = selection.categoryTokens.subtracting(record.exemptCategories)
        if categories.isEmpty {
            store.shield.applicationCategories = nil
            store.shield.webDomainCategories = nil
        } else {
            store.shield.applicationCategories = .specific(categories, except: record.exemptApplications)
            store.shield.webDomainCategories = .specific(categories, except: record.exemptWebDomains)
        }

        let domains = selection.webDomainTokens.subtracting(record.exemptWebDomains)
        store.shield.webDomains = domains.isEmpty ? nil : domains
    }

    /// Re-applies every recorded shield (used after a temporary unlock expires, or when
    /// the app launches to make sure the stores match the recorded state).
    public static func reapplyAll(now: Date = Date()) {
        var shields = SharedStore.activeShields
        for (key, var record) in shields {
            if let end = record.endsAt, end <= now {
                store(for: key).clearAllSettings()
                shields.removeValue(forKey: key)
                continue
            }
            if let until = record.exemptionEndsAt, until <= now {
                record.exemptApplications = []
                record.exemptWebDomains = []
                record.exemptCategories = []
                record.exemptionEndsAt = nil
                shields[key] = record
            }
            write(record)
        }
        SharedStore.activeShields = shields
    }

    /// Temporarily lets one token through every non-strict active shield.
    @discardableResult
    public static func grantTemporaryUnlock(application: ApplicationToken? = nil,
                                            webDomain: WebDomainToken? = nil,
                                            category: ActivityCategoryToken? = nil,
                                            minutes: Int) -> Bool {
        var shields = SharedStore.activeShields
        let until = Date().addingTimeInterval(TimeInterval(minutes * 60))
        var changed = false
        for (key, var record) in shields where !record.strict {
            if let application { record.exemptApplications.insert(application) }
            if let webDomain { record.exemptWebDomains.insert(webDomain) }
            if let category { record.exemptCategories.insert(category) }
            record.exemptionEndsAt = until
            shields[key] = record
            write(record)
            changed = true
        }
        SharedStore.activeShields = shields
        if changed {
            // Ask the system to wake the monitor extension when the unlock should end.
            try? ActivityScheduler.startOneShot(name: ActivityScheduler.relockActivity, until: until)
        }
        return changed
    }

    /// Ends every temporary unlock right away and re-applies the full shields.
    public static func revokeTemporaryUnlocks() {
        var shields = SharedStore.activeShields
        for (key, var record) in shields {
            record.exemptApplications = []
            record.exemptWebDomains = []
            record.exemptCategories = []
            record.exemptionEndsAt = nil
            shields[key] = record
            write(record)
        }
        SharedStore.activeShields = shields
        ActivityScheduler.stop(name: ActivityScheduler.relockActivity)
    }

    /// Whether any active shield covering the app is strict.
    public static var anyStrictActive: Bool {
        SharedStore.activeShields.values.contains { $0.strict }
    }

    public static func clearEverything() {
        for key in SharedStore.activeShields.keys { store(for: key).clearAllSettings() }
        SharedStore.activeShields = [:]
    }
}
