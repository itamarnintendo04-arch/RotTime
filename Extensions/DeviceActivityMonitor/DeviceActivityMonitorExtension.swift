import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

/// Woken by the system at the start/end of every schedule registered by `ActivityScheduler`.
/// This is what makes blocking work while RotTime itself is closed.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let name = activity.rawValue

        if name.hasPrefix("rt.mode."), let id = ActivityScheduler.modeID(fromActivity: name),
           let mode = SharedStore.blockModes.first(where: { $0.id == id }), mode.hasSelection {
            let end = Self.endDate(for: mode.schedule)
            ShieldController.activate(ActiveShield(key: mode.shieldKey, title: mode.name, source: .schedule,
                                                   selection: mode.selection, strict: mode.strict, endsAt: end))
            SharedStore.updateToday { $0.blockSessions += 1 }
            SharedStore.appendExtensionEvent(ExtensionEvent(kind: .scheduleStarted, detail: mode.name))
        } else if name == ActivityScheduler.usageActivity {
            SharedStore.updateToday { $0.usageTracked = true }
        } else if name == ActivityScheduler.focusActivity {
            // The app already applied the focus shield; re-assert it in case the store was reset.
            ShieldController.reapplyAll()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        let name = activity.rawValue

        switch name {
        case ActivityScheduler.focusActivity:
            ShieldController.deactivate(key: "focus")
            finishFocusSessionIfNeeded()
        case ActivityScheduler.relockActivity:
            ShieldController.reapplyAll()
        default:
            if name.hasPrefix("rt.mode."), let id = ActivityScheduler.modeID(fromActivity: name) {
                let key = "mode.\(id.uuidString)"
                let title = SharedStore.activeShields[key]?.title ?? "Schedule"
                ShieldController.deactivate(key: key)
                SharedStore.appendExtensionEvent(ExtensionEvent(kind: .scheduleEnded, detail: title))
            } else if name.hasPrefix("rt.manual."), let id = ActivityScheduler.modeID(fromActivity: name) {
                let key = "mode.\(id.uuidString)"
                let title = SharedStore.activeShields[key]?.title ?? "Block"
                ShieldController.deactivate(key: key)
                SharedStore.appendExtensionEvent(ExtensionEvent(kind: .scheduleEnded, detail: title))
                notify(title: "Shield lifted", body: "\(title) finished. \(SharedStore.brainName) is proud of you!")
            } else if name.hasPrefix("rt.limit."), let id = ActivityScheduler.modeID(fromActivity: name) {
                // Daily window over: the limit resets at midnight.
                ShieldController.deactivate(key: "limit.\(id.uuidString)")
            }
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        if activity.rawValue == ActivityScheduler.usageActivity {
            recordUsage(event)
            return
        }
        guard let id = ActivityScheduler.modeID(fromActivity: activity.rawValue),
              let mode = SharedStore.blockModes.first(where: { $0.id == id }) else { return }
        let midnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 3600)
        ShieldController.activate(ActiveShield(key: "limit.\(id.uuidString)", title: "\(mode.name) limit",
                                               source: .limit, selection: mode.selection,
                                               strict: mode.strict, endsAt: midnight))
        SharedStore.updateToday { $0.blockSessions += 1 }
        SharedStore.appendExtensionEvent(ExtensionEvent(kind: .limitReached, detail: mode.name))
        notify(title: "Daily limit reached",
               body: "You've used your \(mode.dailyLimitMinutes ?? 0) minutes for \(mode.name). \(SharedStore.brainName) shielded those apps until tomorrow.")
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }

    // MARK: Phone time

    private func recordUsage(_ event: DeviceActivityEvent.Name) {
        guard event.rawValue.hasPrefix("u."), let minutes = Int(event.rawValue.dropFirst(2)) else { return }
        SharedStore.updateToday { s in
            s.usageTracked = true
            s.phoneMinutes = max(s.phoneMinutes, minutes)
        }
        let goal = SharedStore.phoneGoalMinutes
        let brain = SharedStore.brainName
        if minutes == goal {
            SharedStore.appendExtensionEvent(ExtensionEvent(kind: .phoneGoalReached))
            notify(title: "\(brain) is starting to feel dizzy 😵‍💫",
                   body: "You've reached the \(Self.format(goal)) you wanted to spend on your phone today.")
        } else if minutes > goal, (minutes - goal) % 30 == 0 {
            notify(title: "\(brain) feels sick 🤒",
                   body: "\(Self.format(minutes)) on your phone today — \(Self.format(minutes - goal)) over your goal.")
        }
    }

    private static func format(_ minutes: Int) -> String {
        minutes >= 60 ? (minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m") : "\(minutes)m"
    }

    // MARK: Helpers

    private func finishFocusSessionIfNeeded() {
        guard let session = SharedStore.load(SharedFocusSession?.self, .focusSession, default: nil),
              session.endsAt <= Date().addingTimeInterval(5) else { return }
        SharedStore.appendExtensionEvent(ExtensionEvent(kind: .focusEnded, detail: session.id.uuidString))
    }

    private static func endDate(for schedule: BlockSchedule, now: Date = Date()) -> Date? {
        let calendar = Calendar.current
        var end = calendar.date(bySettingHour: schedule.endHour, minute: schedule.endMinute, second: 0, of: now) ?? now
        if end <= now { end = calendar.date(byAdding: .day, value: 1, to: end) ?? end }
        return end
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
