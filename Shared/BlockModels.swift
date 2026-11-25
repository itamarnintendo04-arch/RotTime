import Foundation
import FamilyControls
import ManagedSettings

public enum BlockModeKind: String, Codable, CaseIterable, Identifiable {
    case instant, scheduled, focus, study, sleep, custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .instant: return "Instant Block"
        case .scheduled: return "Scheduled Block"
        case .focus: return "Focus Mode"
        case .study: return "Study Mode"
        case .sleep: return "Sleep Mode"
        case .custom: return "Custom Mode"
        }
    }

    public var symbol: String {
        switch self {
        case .instant: return "bolt.shield.fill"
        case .scheduled: return "calendar.badge.clock"
        case .focus: return "scope"
        case .study: return "book.closed.fill"
        case .sleep: return "moon.zzz.fill"
        case .custom: return "slider.horizontal.3"
        }
    }

    public var blurb: String {
        switch self {
        case .instant: return "Shield apps right now, for as long as you choose."
        case .scheduled: return "Automatically shield apps during set hours."
        case .focus: return "The block list used by your focus timer."
        case .study: return "Longer sessions with planned breaks for learning."
        case .sleep: return "Quiet the late-night scroll so your brain can rest."
        case .custom: return "Mix schedules, sessions and a daily time limit."
        }
    }
}

/// A recurring time window. Weekdays use `Calendar` numbering: 1 = Sunday … 7 = Saturday.
public struct BlockSchedule: Codable, Equatable, Hashable {
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int
    public var weekdays: Set<Int>

    public init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, weekdays: Set<Int> = Set(1...7)) {
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.weekdays = weekdays
    }

    public var startMinutesOfDay: Int { startHour * 60 + startMinute }
    public var endMinutesOfDay: Int { endHour * 60 + endMinute }
    public var crossesMidnight: Bool { endMinutesOfDay <= startMinutesOfDay }

    /// Length of one window in minutes.
    public var durationMinutes: Int {
        crossesMidnight ? (24 * 60 - startMinutesOfDay + endMinutesOfDay) : (endMinutesOfDay - startMinutesOfDay)
    }

    /// Apple's DeviceActivity framework rejects intervals shorter than 15 minutes.
    public var isValidForDeviceActivity: Bool { durationMinutes >= 15 && !weekdays.isEmpty }

    /// Whether `date` falls inside this schedule.
    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let comps = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = comps.weekday, let h = comps.hour, let m = comps.minute else { return false }
        let minute = h * 60 + m
        if !crossesMidnight {
            return weekdays.contains(weekday) && minute >= startMinutesOfDay && minute < endMinutesOfDay
        }
        // Overnight: either the late part of a scheduled day or the early part of the following day.
        if minute >= startMinutesOfDay { return weekdays.contains(weekday) }
        if minute < endMinutesOfDay {
            let previous = weekday == 1 ? 7 : weekday - 1
            return weekdays.contains(previous)
        }
        return false
    }

    public var timeRangeText: String {
        "\(Self.format(startHour, startMinute)) – \(Self.format(endHour, endMinute))"
    }

    public var weekdaysText: String {
        if weekdays.count == 7 { return "Every day" }
        if weekdays == Set(2...6) { return "Weekdays" }
        if weekdays == [1, 7] { return "Weekends" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return weekdays.sorted().map { symbols[$0 - 1] }.joined(separator: ", ")
    }

    static func format(_ hour: Int, _ minute: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

public struct BlockMode: Codable, Identifiable {
    public var id: UUID
    public var kind: BlockModeKind
    public var name: String
    public var selection: FamilyActivitySelection
    public var schedule: BlockSchedule
    /// Whether the recurring schedule is registered with DeviceActivityCenter.
    public var scheduleEnabled: Bool
    /// Default length when the mode is started manually.
    public var sessionMinutes: Int
    public var breakMinutes: Int
    /// Strict modes hide the "mindful pause" unlock on the shield and cannot be ended early.
    public var strict: Bool
    /// Optional daily usage limit (Custom Mode). When reached, the selection is shielded until midnight.
    public var dailyLimitMinutes: Int?

    public init(id: UUID = UUID(), kind: BlockModeKind, name: String? = nil,
                selection: FamilyActivitySelection = FamilyActivitySelection(),
                schedule: BlockSchedule, scheduleEnabled: Bool = false,
                sessionMinutes: Int, breakMinutes: Int, strict: Bool = false, dailyLimitMinutes: Int? = nil) {
        self.id = id
        self.kind = kind
        self.name = name ?? kind.title
        self.selection = selection
        self.schedule = schedule
        self.scheduleEnabled = scheduleEnabled
        self.sessionMinutes = sessionMinutes
        self.breakMinutes = breakMinutes
        self.strict = strict
        self.dailyLimitMinutes = dailyLimitMinutes
    }

    public var shieldKey: String { "mode.\(id.uuidString)" }
    public var activityPrefix: String { "rt.mode.\(id.uuidString)" }
    public var limitActivityName: String { "rt.limit.\(id.uuidString)" }

    public var selectionCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    public var hasSelection: Bool { selectionCount > 0 }

    public static var defaults: [BlockMode] {
        [
            BlockMode(kind: .instant, schedule: BlockSchedule(startHour: 9, startMinute: 0, endHour: 10, endMinute: 0),
                      sessionMinutes: 30, breakMinutes: 0),
            BlockMode(kind: .focus, schedule: BlockSchedule(startHour: 9, startMinute: 0, endHour: 12, endMinute: 0, weekdays: Set(2...6)),
                      sessionMinutes: 25, breakMinutes: 5),
            BlockMode(kind: .study, schedule: BlockSchedule(startHour: 16, startMinute: 0, endHour: 19, endMinute: 0, weekdays: Set(2...6)),
                      sessionMinutes: 50, breakMinutes: 10),
            BlockMode(kind: .sleep, schedule: BlockSchedule(startHour: 22, startMinute: 30, endHour: 7, endMinute: 0),
                      sessionMinutes: 60, breakMinutes: 0),
            BlockMode(kind: .scheduled, schedule: BlockSchedule(startHour: 13, startMinute: 0, endHour: 15, endMinute: 0, weekdays: Set(2...6)),
                      sessionMinutes: 60, breakMinutes: 0),
            BlockMode(kind: .custom, schedule: BlockSchedule(startHour: 18, startMinute: 0, endHour: 21, endMinute: 0),
                      sessionMinutes: 45, breakMinutes: 10, dailyLimitMinutes: 60),
        ]
    }
}

extension BlockMode: Equatable {
    public static func == (lhs: BlockMode, rhs: BlockMode) -> Bool {
        lhs.id == rhs.id && lhs.kind == rhs.kind && lhs.name == rhs.name && lhs.schedule == rhs.schedule
            && lhs.scheduleEnabled == rhs.scheduleEnabled && lhs.sessionMinutes == rhs.sessionMinutes
            && lhs.breakMinutes == rhs.breakMinutes && lhs.strict == rhs.strict
            && lhs.dailyLimitMinutes == rhs.dailyLimitMinutes
            && lhs.selection.applicationTokens == rhs.selection.applicationTokens
            && lhs.selection.categoryTokens == rhs.selection.categoryTokens
            && lhs.selection.webDomainTokens == rhs.selection.webDomainTokens
    }
}

/// A shield that is currently applied to a named ManagedSettingsStore.
public struct ActiveShield: Codable {
    public enum Source: String, Codable { case instant, schedule, focus, limit, manual }

    public var key: String
    public var title: String
    public var source: Source
    public var selection: FamilyActivitySelection
    public var strict: Bool
    public var startedAt: Date
    /// `nil` means "until the user stops it" (or until the schedule's interval ends).
    public var endsAt: Date?
    /// Tokens temporarily allowed through a mindful pause.
    public var exemptApplications: Set<ApplicationToken>
    public var exemptWebDomains: Set<WebDomainToken>
    public var exemptCategories: Set<ActivityCategoryToken>
    public var exemptionEndsAt: Date?

    public init(key: String, title: String, source: Source, selection: FamilyActivitySelection,
                strict: Bool, startedAt: Date = Date(), endsAt: Date? = nil) {
        self.key = key
        self.title = title
        self.source = source
        self.selection = selection
        self.strict = strict
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.exemptApplications = []
        self.exemptWebDomains = []
        self.exemptCategories = []
        self.exemptionEndsAt = nil
    }

    public var hasExemptions: Bool {
        !exemptApplications.isEmpty || !exemptWebDomains.isEmpty || !exemptCategories.isEmpty
    }
}

public struct MindfulUnlockSettings: Codable, Equatable {
    /// Whether non-strict shields offer the "mindful pause" button.
    public var enabled: Bool = true
    /// How long the user has to pause before the second tap unlocks the app.
    public var waitSeconds: Int = 15
    /// How long an app stays unlocked after a completed pause.
    public var unlockMinutes: Int = 5

    public init() {}
}

/// Persisted state of a running focus timer, shared so the monitor extension can
/// finish the session when the app isn't running.
public struct SharedFocusSession: Codable, Equatable {
    public enum Phase: String, Codable { case focus, rest }
    public var id: UUID
    public var phase: Phase
    public var startedAt: Date
    public var endsAt: Date
    public var plannedSeconds: Double
    public var blocksApps: Bool

    public init(id: UUID = UUID(), phase: Phase, startedAt: Date, endsAt: Date, plannedSeconds: Double, blocksApps: Bool) {
        self.id = id
        self.phase = phase
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.plannedSeconds = plannedSeconds
        self.blocksApps = blocksApps
    }
}
