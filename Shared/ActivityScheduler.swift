import Foundation
import DeviceActivity
import FamilyControls

/// Registers DeviceActivity schedules so the system wakes `RotTimeMonitor`
/// (the DeviceActivityMonitor extension) at the right moments, even when the app is closed.
public enum ActivityScheduler {
    public static let focusActivity = "rt.focus"
    public static let instantActivity = "rt.instant"
    public static let relockActivity = "rt.relock"
    public static let usageActivity = "rt.usage"

    /// Threshold steps (minutes) reported to the monitor for phone-time tracking.
    public static func usageSteps(goal: Int) -> [Int] {
        let top = min(16 * 60, max(goal * 2, goal + 120))
        var steps = Set(stride(from: 10, through: top, by: 10))
        steps.insert(goal)
        return Array(steps).sorted().prefix(100).map { $0 }
    }

    /// Tracks today's phone time in 10-minute steps via DeviceActivity threshold events.
    /// The monitor extension writes each reached step into the shared DayStats.
    public static func registerUsageTracking(selection: FamilyActivitySelection, goal: Int) throws {
        stop(name: usageActivity)
        guard !(selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty) else { return }
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for minutes in usageSteps(goal: goal) {
            let threshold = DateComponents(minute: minutes)
            let event: DeviceActivityEvent
            if #available(iOS 17.4, *) {
                event = DeviceActivityEvent(applications: selection.applicationTokens, categories: selection.categoryTokens,
                                            webDomains: selection.webDomainTokens, threshold: threshold, includesPastActivity: true)
            } else {
                event = DeviceActivityEvent(applications: selection.applicationTokens, categories: selection.categoryTokens,
                                            webDomains: selection.webDomainTokens, threshold: threshold)
            }
            events[DeviceActivityEvent.Name(rawValue: "u.\(minutes)")] = event
        }
        let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0),
                                              intervalEnd: DateComponents(hour: 23, minute: 59), repeats: true)
        do {
            try center.startMonitoring(DeviceActivityName(rawValue: usageActivity), during: schedule, events: events)
        } catch {
            throw SchedulerError.system(error)
        }
    }

    static var center: DeviceActivityCenter { DeviceActivityCenter() }

    public enum SchedulerError: LocalizedError {
        case tooShort, noDays, system(Error)
        public var errorDescription: String? {
            switch self {
            case .tooShort: return "Schedules must be at least 15 minutes long (an Apple Screen Time rule)."
            case .noDays: return "Pick at least one day of the week."
            case .system(let error): return error.localizedDescription
            }
        }
    }

    /// Monitors a single, non-repeating window that ends at `until`.
    ///
    /// DeviceActivity requires windows of at least 15 minutes, so for shorter windows the
    /// start is moved into the past. The system then reports the interval as already
    /// running and calls `intervalDidEnd` exactly at `until`.
    public static func startOneShot(name: String, until end: Date, now: Date = Date()) throws {
        let minimum: TimeInterval = 15 * 60 + 30
        let start = min(now, end.addingTimeInterval(-minimum))
        let calendar = Calendar.current
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(fields, from: start),
            intervalEnd: calendar.dateComponents(fields, from: end),
            repeats: false
        )
        let activity = DeviceActivityName(rawValue: name)
        center.stopMonitoring([activity])
        do {
            try center.startMonitoring(activity, during: schedule)
        } catch {
            throw SchedulerError.system(error)
        }
    }

    public static func stop(name: String) {
        center.stopMonitoring([DeviceActivityName(rawValue: name)])
    }

    /// Registers the recurring schedule (and optional daily limit) for a mode.
    public static func register(_ mode: BlockMode) throws {
        unregister(mode)
        let schedule = mode.schedule
        guard !schedule.weekdays.isEmpty else { throw SchedulerError.noDays }
        guard schedule.durationMinutes >= 15 else { throw SchedulerError.tooShort }

        do {
            if schedule.weekdays.count == 7 {
                let daily = DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: schedule.startHour, minute: schedule.startMinute),
                    intervalEnd: DateComponents(hour: schedule.endHour, minute: schedule.endMinute),
                    repeats: true
                )
                try center.startMonitoring(DeviceActivityName(rawValue: "\(mode.activityPrefix).daily"), during: daily)
            } else {
                for weekday in schedule.weekdays.sorted() {
                    let endWeekday = schedule.crossesMidnight ? (weekday % 7) + 1 : weekday
                    let weekly = DeviceActivitySchedule(
                        intervalStart: DateComponents(hour: schedule.startHour, minute: schedule.startMinute, weekday: weekday),
                        intervalEnd: DateComponents(hour: schedule.endHour, minute: schedule.endMinute, weekday: endWeekday),
                        repeats: true
                    )
                    try center.startMonitoring(DeviceActivityName(rawValue: "\(mode.activityPrefix).d\(weekday)"), during: weekly)
                }
            }
        } catch {
            unregister(mode)
            throw SchedulerError.system(error)
        }
    }

    /// Registers a midnight-to-midnight window with a usage threshold event.
    public static func registerDailyLimit(for mode: BlockMode) throws {
        stop(name: mode.limitActivityName)
        guard let minutes = mode.dailyLimitMinutes, minutes > 0, mode.hasSelection else { return }
        let event = DeviceActivityEvent(
            applications: mode.selection.applicationTokens,
            categories: mode.selection.categoryTokens,
            webDomains: mode.selection.webDomainTokens,
            threshold: DateComponents(minute: minutes)
        )
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        do {
            try center.startMonitoring(DeviceActivityName(rawValue: mode.limitActivityName), during: schedule,
                                       events: [DeviceActivityEvent.Name(rawValue: "limit"): event])
        } catch {
            throw SchedulerError.system(error)
        }
    }

    public static func unregister(_ mode: BlockMode) {
        let names = center.activities.filter { $0.rawValue.hasPrefix(mode.activityPrefix) }
        if !names.isEmpty { center.stopMonitoring(names) }
    }

    public static func unregisterLimit(_ mode: BlockMode) {
        stop(name: mode.limitActivityName)
    }

    public static var monitoredActivityNames: [String] {
        center.activities.map(\.rawValue)
    }

    /// Activity used when a mode is started by hand ("Start now") for a fixed time.
    public static func manualActivityName(for mode: BlockMode) -> String { "rt.manual.\(mode.id.uuidString)" }

    /// Parses `rt.mode.<uuid>.<suffix>`, `rt.manual.<uuid>` or `rt.limit.<uuid>`.
    public static func modeID(fromActivity name: String) -> UUID? {
        let parts = name.split(separator: ".")
        guard parts.count >= 3, parts[0] == "rt", ["mode", "limit", "manual"].contains(String(parts[1])) else { return nil }
        return UUID(uuidString: String(parts[2]))
    }
}
