import Foundation

/// Identifiers shared by the app and every Screen Time extension.
///
/// The App Group identifier is injected at build time through the `RT_APP_GROUP`
/// build setting (see `project.yml`) and exposed to code via each target's Info.plist,
/// so changing the bundle prefix for your own Apple Developer team never requires code edits.
public enum AppGroup {
    public static var identifier: String {
        (Bundle.main.object(forInfoDictionaryKey: "RTAppGroupIdentifier") as? String)
            .flatMap { $0.isEmpty || $0.contains("$(") ? nil : $0 } ?? "group.com.rottime.app"
    }

    /// Shared defaults. Falls back to `.standard` when the App Group container is
    /// unavailable (for example in an unsigned simulator build).
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// Small helpers around Codable values stored in the shared App Group defaults.
public enum SharedStore {
    public enum Key: String {
        case blockModes = "rt.blockModes"
        case activeShields = "rt.activeShields"
        case dayStats = "rt.dayStats"
        case pendingPauses = "rt.pendingPauses"
        case unlockSettings = "rt.unlockSettings"
        case selectedThemeID = "rt.selectedThemeID"
        case focusSession = "rt.focusSession"
        case brainName = "rt.brainName"
        case extensionEvents = "rt.extensionEvents"
        case moreTimeRequests = "rt.moreTimeRequests"
    }

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    public static func load<T: Decodable>(_ type: T.Type, _ key: Key, default fallback: @autoclosure () -> T) -> T {
        guard let data = AppGroup.defaults.data(forKey: key.rawValue),
              let value = try? decoder.decode(T.self, from: data) else { return fallback() }
        return value
    }

    public static func save<T: Encodable>(_ value: T, _ key: Key) {
        guard let data = try? encoder.encode(value) else { return }
        AppGroup.defaults.set(data, forKey: key.rawValue)
    }

    public static func remove(_ key: Key) {
        AppGroup.defaults.removeObject(forKey: key.rawValue)
    }

    // MARK: Convenience accessors

    public static var blockModes: [BlockMode] {
        get { load([BlockMode].self, .blockModes, default: BlockMode.defaults) }
        set { save(newValue, .blockModes) }
    }

    public static var activeShields: [String: ActiveShield] {
        get { load([String: ActiveShield].self, .activeShields, default: [:]) }
        set { save(newValue, .activeShields) }
    }

    public static var unlockSettings: MindfulUnlockSettings {
        get { load(MindfulUnlockSettings.self, .unlockSettings, default: MindfulUnlockSettings()) }
        set { save(newValue, .unlockSettings) }
    }

    public static var brainName: String {
        get { AppGroup.defaults.string(forKey: Key.brainName.rawValue) ?? "Noodle" }
        set { AppGroup.defaults.set(newValue, forKey: Key.brainName.rawValue) }
    }

    public static var selectedThemeID: String {
        get { AppGroup.defaults.string(forKey: Key.selectedThemeID.rawValue) ?? "cozy" }
        set { AppGroup.defaults.set(newValue, forKey: Key.selectedThemeID.rawValue) }
    }

    // MARK: Daily stats (written by the app *and* by extensions)

    public static var dayStats: [String: DayStats] {
        get { load([String: DayStats].self, .dayStats, default: [:]) }
        set {
            // Keep roughly one year of history.
            var trimmed = newValue
            if trimmed.count > 400 {
                let keep = Set(trimmed.keys.sorted().suffix(400))
                trimmed = trimmed.filter { keep.contains($0.key) }
            }
            save(trimmed, .dayStats)
        }
    }

    public static func updateToday(_ change: (inout DayStats) -> Void) {
        update(day: Date(), change)
    }

    public static func update(day: Date, _ change: (inout DayStats) -> Void) {
        let key = DayKey.string(for: day)
        var all = dayStats
        var stats = all[key] ?? DayStats()
        change(&stats)
        all[key] = stats
        dayStats = all
    }

    /// Events recorded by extensions so the app can react (e.g. the brain mentioning a
    /// shield you resisted) the next time it opens.
    public static func appendExtensionEvent(_ event: ExtensionEvent) {
        var events = load([ExtensionEvent].self, .extensionEvents, default: [])
        events.append(event)
        save(Array(events.suffix(50)), .extensionEvents)
    }

    public static func drainExtensionEvents() -> [ExtensionEvent] {
        let events = load([ExtensionEvent].self, .extensionEvents, default: [])
        remove(.extensionEvents)
        return events
    }
}

public enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public static func string(for date: Date) -> String { formatter.string(from: date) }
    public static func date(from key: String) -> Date? { formatter.date(from: key) }
}

/// Per-day counters. Only values the app can genuinely observe are stored here:
/// focus time it timed itself, and shield interactions reported by its own extensions.
public struct DayStats: Codable, Equatable {
    public var focusSeconds: Double = 0
    public var focusSessions: Int = 0
    public var breaks: Int = 0
    public var blockSessions: Int = 0
    /// Times the user tapped "I'll stay focused" on a shield.
    public var shieldResists: Int = 0
    /// Times the user took extra time on a shielded app.
    public var mindfulUnlocks: Int = 0
    public var chatMessages: Int = 0
    /// Times the user asked for more time and then said "actually, I don't want to".
    public var moreTimeDeclined: Int = 0
    /// Total extra minutes granted on shielded apps.
    public var extraMinutes: Int = 0

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case focusSeconds, focusSessions, breaks, blockSessions, shieldResists, mindfulUnlocks, chatMessages, moreTimeDeclined, extraMinutes
    }

    // Tolerant decoding so stats saved by older versions keep loading.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        focusSeconds = try c.decodeIfPresent(Double.self, forKey: .focusSeconds) ?? 0
        focusSessions = try c.decodeIfPresent(Int.self, forKey: .focusSessions) ?? 0
        breaks = try c.decodeIfPresent(Int.self, forKey: .breaks) ?? 0
        blockSessions = try c.decodeIfPresent(Int.self, forKey: .blockSessions) ?? 0
        shieldResists = try c.decodeIfPresent(Int.self, forKey: .shieldResists) ?? 0
        mindfulUnlocks = try c.decodeIfPresent(Int.self, forKey: .mindfulUnlocks) ?? 0
        chatMessages = try c.decodeIfPresent(Int.self, forKey: .chatMessages) ?? 0
        moreTimeDeclined = try c.decodeIfPresent(Int.self, forKey: .moreTimeDeclined) ?? 0
        extraMinutes = try c.decodeIfPresent(Int.self, forKey: .extraMinutes) ?? 0
    }

    public var focusMinutes: Int { Int(focusSeconds / 60) }
}

public struct ExtensionEvent: Codable, Equatable {
    public enum Kind: String, Codable {
        case shieldResisted, mindfulUnlock, moreTimeRequested, scheduleStarted, scheduleEnded, focusEnded, limitReached
    }
    public var kind: Kind
    public var date: Date
    public var detail: String?

    public init(kind: Kind, date: Date = Date(), detail: String? = nil) {
        self.kind = kind
        self.date = date
        self.detail = detail
    }
}
