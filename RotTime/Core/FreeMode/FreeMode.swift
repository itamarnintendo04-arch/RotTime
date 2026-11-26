import Foundation
import SwiftUI
import UIKit

/// "Free mode": everything that works without Apple's paid Family Controls entitlement.
///
/// * Real blocking is done by iOS's own Screen Time (App Limits / Downtime) — RotTime guides you.
/// * Shortcuts automations ("When Instagram is opened / closed") call RotTime's App Intents,
///   so Noodle can step in before you scroll and RotTime can measure time per app.
/// * A quick daily check-in records total phone time and pickups as shown in iOS Settings.
enum ScreenTimeCapability {
    enum Entitlement { case present, missing, unknown }

    /// Reads the installed build's provisioning profile (no private APIs).
    static let entitlement: Entitlement = {
        #if targetEnvironment(simulator)
        return .unknown
        #else
        guard let profile = ScreenTimeDiagnostics.embeddedProfile() else { return .unknown }
        let ent = profile["Entitlements"] as? [String: Any] ?? [:]
        return (ent["com.apple.developer.family-controls"] as? Bool) == true ? .present : .missing
        #endif
    }()
}

/// Apps Noodle can step in for via Shortcuts automations.
enum DistractingApp: String, CaseIterable, Codable, Identifiable {
    case instagram, tiktok, youtube, x, snapchat, facebook, reddit, threads, netflix, games, other

    var id: String { rawValue }

    var name: String {
        switch self {
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .youtube: return "YouTube"
        case .x: return "X"
        case .snapchat: return "Snapchat"
        case .facebook: return "Facebook"
        case .reddit: return "Reddit"
        case .threads: return "Threads"
        case .netflix: return "Netflix"
        case .games: return "Games"
        case .other: return "Another app"
        }
    }

    var symbol: String {
        switch self {
        case .instagram: return "camera.fill"
        case .tiktok: return "music.note"
        case .youtube: return "play.rectangle.fill"
        case .x: return "xmark"
        case .snapchat: return "bolt.fill"
        case .facebook: return "person.2.fill"
        case .reddit: return "bubble.left.and.text.bubble.right.fill"
        case .threads: return "at"
        case .netflix: return "tv.fill"
        case .games: return "gamecontroller.fill"
        case .other: return "app.fill"
        }
    }

    /// Used to send you back to the app after you chose to take more time.
    var urlScheme: String? {
        switch self {
        case .instagram: return "instagram://"
        case .tiktok: return "snssdk1233://"
        case .youtube: return "youtube://"
        case .x: return "twitter://"
        case .snapchat: return "snapchat://"
        case .facebook: return "fb://"
        case .reddit: return "reddit://"
        case .threads: return "barcelona://"
        case .netflix: return "nflx://"
        case .games, .other: return nil
        }
    }

    func open() {
        guard let scheme = urlScheme, let url = URL(string: scheme) else { return }
        UIApplication.shared.open(url)
    }
}

/// Per-app opens/time (from Shortcuts automations) and "more time" allowances.
enum FreeUsageStore {
    struct AppDay: Codable, Equatable {
        var opens = 0
        var seconds: Double = 0
    }

    private static let usageKey = "rt.free.usage"
    private static let openKey = "rt.free.openedAt"
    private static let allowKey = "rt.free.allowances"
    private static let pendingKey = "rt.free.pending"
    private static let lastSeenKey = "rt.free.lastSeen"
    /// Longest stretch counted for one visit (in case a "closed" automation is missed).
    static let maxVisit: TimeInterval = 3 * 3600

    private static var d: UserDefaults { AppGroup.defaults }

    private static func load<T: Decodable>(_ key: String, _ fallback: T) -> T {
        guard let data = d.data(forKey: key), let v = try? JSONDecoder().decode(T.self, from: data) else { return fallback }
        return v
    }

    private static func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { d.set(data, forKey: key) }
    }

    static var usage: [String: [String: AppDay]] {
        get { load(usageKey, [:]) }
        set { save(newValue, usageKey) }
    }

    static func today(_ date: Date = Date()) -> [DistractingApp: AppDay] {
        let day = usage[DayKey.string(for: date)] ?? [:]
        var out: [DistractingApp: AppDay] = [:]
        for (k, v) in day { if let app = DistractingApp(rawValue: k) { out[app] = v } }
        return out
    }

    static var isSetUp: Bool { d.object(forKey: lastSeenKey) != nil }
    static var lastAutomationRun: Date? { d.object(forKey: lastSeenKey) as? Date }

    // MARK: Logging (called from App Intents)

    static func logOpened(_ app: DistractingApp, at date: Date = Date()) {
        d.set(date, forKey: lastSeenKey)
        var openMap: [String: Date] = load(openKey, [:])
        // Close a previous visit we never heard the end of.
        if let previous = openMap[app.rawValue] { addTime(app, from: previous, to: date) }
        openMap[app.rawValue] = date
        save(openMap, openKey)
        mutate(app, date) { $0.opens += 1 }
        syncDayStats(date)
    }

    static func logClosed(_ app: DistractingApp, at date: Date = Date()) {
        d.set(date, forKey: lastSeenKey)
        var openMap: [String: Date] = load(openKey, [:])
        if let start = openMap.removeValue(forKey: app.rawValue) {
            addTime(app, from: start, to: date)
            save(openMap, openKey)
            syncDayStats(date)
        }
    }

    private static func addTime(_ app: DistractingApp, from start: Date, to end: Date) {
        let seconds = min(max(0, end.timeIntervalSince(start)), maxVisit)
        mutate(app, start) { $0.seconds += seconds }
    }

    private static func mutate(_ app: DistractingApp, _ date: Date, _ change: (inout AppDay) -> Void) {
        var all = usage
        let key = DayKey.string(for: date)
        var day = all[key] ?? [:]
        var entry = day[app.rawValue] ?? AppDay()
        change(&entry)
        day[app.rawValue] = entry
        all[key] = day
        // Keep ~2 months.
        if all.count > 70 { for k in all.keys.sorted().prefix(all.count - 70) { all.removeValue(forKey: k) } }
        usage = all
    }

    /// Mirrors free-mode numbers into DayStats so Home, Progress and the brain all use them.
    static func syncDayStats(_ date: Date = Date()) {
        let tracked = Int(today(date).values.reduce(0) { $0 + $1.seconds } / 60)
        SharedStore.update(day: date) { s in
            s.usageTracked = true
            s.phoneMinutes = max(s.manualScreenMinutes, tracked)
        }
    }

    // MARK: Allowances ("Yes, 10 more minutes")

    static var allowances: [String: Date] {
        get { load(allowKey, [:]) }
        set { save(newValue.filter { $0.value > Date() }, allowKey) }
    }

    static func allow(_ app: DistractingApp, minutes: Int) {
        var a = allowances
        a[app.rawValue] = Date().addingTimeInterval(TimeInterval(minutes * 60))
        allowances = a
    }

    static func revokeAllowance(_ app: DistractingApp) {
        var a = allowances
        a.removeValue(forKey: app.rawValue)
        allowances = a
    }

    static func allowance(for app: DistractingApp) -> Date? {
        allowances[app.rawValue].flatMap { $0 > Date() ? $0 : nil }
    }

    /// Whether the automation should send you to Noodle right now.
    static func shouldIntervene(for app: DistractingApp) -> Bool { allowance(for: app) == nil }

    // MARK: Pending intervention (set by the intent, shown when RotTime opens)

    static var pendingApp: DistractingApp? {
        get {
            guard let raw = d.string(forKey: pendingKey), let date = d.object(forKey: pendingKey + ".at") as? Date,
                  Date().timeIntervalSince(date) < 600 else { return nil }
            return DistractingApp(rawValue: raw)
        }
        set {
            d.set(newValue?.rawValue, forKey: pendingKey)
            d.set(newValue == nil ? nil : Date(), forKey: pendingKey + ".at")
        }
    }
}
