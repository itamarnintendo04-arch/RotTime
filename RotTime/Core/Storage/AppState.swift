import Foundation
import SwiftUI

struct UserProfile: Codable, Equatable {
    var userName: String = ""
    var brainName: String = "Noodle"
    /// Legacy focus goals (no longer shown; kept so old data decodes).
    var dailyGoalMinutes: Int = 60
    var weeklyGoalMinutes: Int = 300
    /// How much the user *wants* to be on their phone each day.
    var phoneGoalMinutes: Int = 120
    /// How much the user said they currently spend per day (asked in onboarding).
    var phoneEstimateMinutes: Int = 240
    var onboardingComplete = false
    var hapticsEnabled = true
    var ambientAnimations = true
    var checkInReminderEnabled = false
    var checkInHour = 9
    var checkInMinute = 0
    var themeID: String = "cozy"

    init() {}

    private enum CodingKeys: String, CodingKey {
        case userName, brainName, dailyGoalMinutes, weeklyGoalMinutes, phoneGoalMinutes, phoneEstimateMinutes
        case onboardingComplete, hapticsEnabled, ambientAnimations, checkInReminderEnabled, checkInHour, checkInMinute, themeID
    }

    // Tolerant decoding so profiles saved by earlier versions keep working.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = UserProfile()
        userName = try c.decodeIfPresent(String.self, forKey: .userName) ?? d.userName
        brainName = try c.decodeIfPresent(String.self, forKey: .brainName) ?? d.brainName
        dailyGoalMinutes = try c.decodeIfPresent(Int.self, forKey: .dailyGoalMinutes) ?? d.dailyGoalMinutes
        weeklyGoalMinutes = try c.decodeIfPresent(Int.self, forKey: .weeklyGoalMinutes) ?? d.weeklyGoalMinutes
        phoneGoalMinutes = try c.decodeIfPresent(Int.self, forKey: .phoneGoalMinutes) ?? d.phoneGoalMinutes
        phoneEstimateMinutes = try c.decodeIfPresent(Int.self, forKey: .phoneEstimateMinutes) ?? d.phoneEstimateMinutes
        onboardingComplete = try c.decodeIfPresent(Bool.self, forKey: .onboardingComplete) ?? d.onboardingComplete
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? d.hapticsEnabled
        ambientAnimations = try c.decodeIfPresent(Bool.self, forKey: .ambientAnimations) ?? d.ambientAnimations
        checkInReminderEnabled = try c.decodeIfPresent(Bool.self, forKey: .checkInReminderEnabled) ?? d.checkInReminderEnabled
        checkInHour = try c.decodeIfPresent(Int.self, forKey: .checkInHour) ?? d.checkInHour
        checkInMinute = try c.decodeIfPresent(Int.self, forKey: .checkInMinute) ?? d.checkInMinute
        themeID = try c.decodeIfPresent(String.self, forKey: .themeID) ?? d.themeID
    }
}

struct RewardProgress: Codable, Equatable {
    var bonusPoints: Int = 0
    var unlockedAchievements: [String: Date] = [:]
    /// Item ids the user has already been told about (so toasts aren't repeated).
    var announcedItems: Set<String> = []
}

struct FocusRecord: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case focus, rest }
    var id = UUID()
    var start: Date
    var seconds: Double
    var kind: Kind
    var completed: Bool
    var label: String
}

/// Central app state. Persisted locally (App Group defaults) – nothing leaves the device.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var profile: UserProfile { didSet { persist(profile, Keys.profile); syncShared() } }
    @Published var appearance: BrainAppearance { didSet { persist(appearance, Keys.appearance) } }
    @Published var rewards: RewardProgress { didSet { persist(rewards, Keys.rewards) } }
    @Published var focusHistory: [FocusRecord] { didSet { persist(Array(focusHistory.suffix(2000)), Keys.history) } }
    @Published private(set) var dayStats: [String: DayStats] = [:]
    @Published var toast: Toast?
    @Published var celebrate = false
    @Published var selectedTab: AppTab = .home
    @Published var pendingFocusPreset: Int?

    private enum Keys {
        static let profile = "rt.app.profile"
        static let appearance = "rt.app.appearance"
        static let rewards = "rt.app.rewards"
        static let history = "rt.app.history"
    }

    private let defaults = AppGroup.defaults

    init() {
        func load<T: Decodable>(_ key: String, _ fallback: T) -> T {
            guard let data = AppGroup.defaults.data(forKey: key), let v = try? JSONDecoder().decode(T.self, from: data) else { return fallback }
            return v
        }
        profile = load(Keys.profile, UserProfile())
        appearance = load(Keys.appearance, BrainAppearance())
        rewards = load(Keys.rewards, RewardProgress())
        focusHistory = load(Keys.history, [])
        dayStats = SharedStore.dayStats
        syncShared()
    }

    private func persist<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private func syncShared() {
        SharedStore.brainName = profile.brainName
        SharedStore.selectedThemeID = profile.themeID
        if SharedStore.phoneGoalMinutes != profile.phoneGoalMinutes {
            SharedStore.phoneGoalMinutes = profile.phoneGoalMinutes
            // Thresholds depend on the goal, so re-register tracking.
            if SharedStore.usageTrackingConfigured {
                try? ActivityScheduler.registerUsageTracking(selection: SharedStore.usageSelection, goal: profile.phoneGoalMinutes)
            }
        }
    }

    var theme: Theme { Theme.with(id: profile.themeID) }
    var brainName: String { profile.brainName.isEmpty ? "Noodle" : profile.brainName }

    // MARK: Refresh from extensions

    /// Reloads counters written by the Screen Time extensions.
    func refreshShared() {
        dayStats = SharedStore.dayStats
    }

    // MARK: Day stats

    func stats(for date: Date) -> DayStats { dayStats[DayKey.string(for: date)] ?? DayStats() }
    var today: DayStats { stats(for: Date()) }

    var todayFocusMinutes: Int { today.focusMinutes }
    // MARK: Phone time

    var phoneGoal: Int { max(1, profile.phoneGoalMinutes) }
    /// Phone time so far today (10-minute steps reported by Screen Time).
    var phoneMinutesToday: Int { today.phoneMinutes }
    var isTrackingPhoneTime: Bool { SharedStore.usageTrackingConfigured }
    /// Can exceed 1 when over the goal.
    var phoneProgress: Double { Double(phoneMinutesToday) / Double(phoneGoal) }
    var phoneMinutesLeft: Int { max(0, phoneGoal - phoneMinutesToday) }
    var isOverPhoneGoal: Bool { isTrackingPhoneTime && phoneMinutesToday > phoneGoal }

    /// Kept for older callers: how far through today's phone budget we are (0…1).
    var todayGoalProgress: Double { min(1, phoneProgress) }

    func recordFocus(seconds: Double, kind: FocusRecord.Kind, completed: Bool, label: String, start: Date) {
        guard seconds >= 30 else { return }
        focusHistory.append(FocusRecord(start: start, seconds: seconds, kind: kind, completed: completed, label: label))
        SharedStore.update(day: start) { s in
            if kind == .focus {
                s.focusSeconds += seconds
                if completed { s.focusSessions += 1; BrainHealth.heal() }
            } else {
                s.breaks += 1
            }
        }
        refreshShared()
        evaluateRewards()
    }

    func recordBlockSession() {
        SharedStore.updateToday { $0.blockSessions += 1 }
        refreshShared()
        evaluateRewards()
    }

    func recordChatMessage() {
        SharedStore.updateToday { $0.chatMessages += 1 }
        refreshShared()
        evaluateRewards()
    }

    // MARK: Streaks

    /// A day counts towards the streak when at least one focus session was completed.
    func isActiveDay(_ date: Date) -> Bool { stats(for: date).focusSessions > 0 }

    var currentStreak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        if !isActiveDay(day) { day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
        var count = 0
        while isActiveDay(day) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    var bestStreak: Int {
        let days = dayStats.filter { $0.value.focusSessions > 0 }.keys.compactMap(DayKey.date(from:)).sorted()
        var best = 0, run = 0
        var last: Date?
        let cal = Calendar.current
        for d in days {
            if let l = last, cal.dateComponents([.day], from: l, to: d).day == 1 { run += 1 } else { run = 1 }
            best = max(best, run)
            last = d
        }
        return max(best, currentStreak)
    }

    // MARK: Progress snapshot & rewards

    var snapshot: ProgressSnapshot {
        let all = dayStats.values
        let focusMinutes = Int(all.reduce(0) { $0 + $1.focusSeconds } / 60)
        let goal = phoneGoal
        return ProgressSnapshot(
            totalFocusMinutes: focusMinutes,
            totalSessions: all.reduce(0) { $0 + $1.focusSessions },
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            points: focusMinutes + rewards.bonusPoints + all.reduce(0) { $0 + $1.shieldResists * 2 },
            totalResists: all.reduce(0) { $0 + $1.shieldResists },
            totalBlockSessions: all.reduce(0) { $0 + $1.blockSessions },
            chatMessages: all.reduce(0) { $0 + $1.chatMessages },
            goalDays: dayStats.filter { $0.key != DayKey.string(for: Date()) && $0.value.usageTracked && $0.value.phoneMinutes <= goal }.count
        )
    }

    var sparkPoints: Int { snapshot.points }

    func isUnlocked(_ requirement: Requirement) -> Bool { requirement.isMet(snapshot) }
    func isUnlocked(_ item: CosmeticItem) -> Bool { isUnlocked(item.requirement) }
    func isUnlocked(_ theme: Theme) -> Bool { isUnlocked(theme.requirement) }

    func isUnlocked(_ expression: BrainExpression) -> Bool {
        guard let a = Achievement.all.first(where: { $0.unlocksExpression == expression }) else { return true }
        return rewards.unlockedAchievements[a.id] != nil
    }

    /// Checks achievements and newly available items, awarding bonus points and showing a toast.
    func evaluateRewards() {
        var snap = snapshot
        var newToasts: [Toast] = []
        for achievement in Achievement.all where rewards.unlockedAchievements[achievement.id] == nil {
            if achievement.requirement.isMet(snap) {
                rewards.unlockedAchievements[achievement.id] = Date()
                rewards.bonusPoints += achievement.bonusPoints
                snap.points += achievement.bonusPoints
                newToasts.append(Toast(title: "Achievement: \(achievement.title)", message: "+\(achievement.bonusPoints) spark points", symbol: achievement.symbol))
            }
        }
        for item in RewardCatalog.cosmetics where item.requirement != .free && !rewards.announcedItems.contains(item.id) {
            if item.requirement.isMet(snap) {
                rewards.announcedItems.insert(item.id)
                newToasts.append(Toast(title: "New \(item.category.singular) unlocked", message: item.title, symbol: item.category.symbol))
            }
        }
        for theme in Theme.all where theme.requirement != .free && !rewards.announcedItems.contains("theme.\(theme.id)") {
            if theme.requirement.isMet(snap) {
                rewards.announcedItems.insert("theme.\(theme.id)")
                newToasts.append(Toast(title: "New theme unlocked", message: theme.name, symbol: theme.symbol))
            }
        }
        if let first = newToasts.first {
            show(first)
            Haptics.success(profile.hapticsEnabled)
        }
    }

    func show(_ toast: Toast) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { self.toast = toast }
        let id = toast.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { [weak self] in
            guard self?.toast?.id == id else { return }
            withAnimation(.easeInOut) { self?.toast = nil }
        }
    }

    struct NextUnlock {
        var title: String
        var symbol: String
        var requirement: Requirement
    }

    /// The locked item the user is closest to earning.
    var nextUnlock: NextUnlock? {
        let snap = snapshot
        var candidates: [NextUnlock] = Theme.all.filter { !$0.requirement.isMet(snap) }
            .map { NextUnlock(title: "\($0.name) theme", symbol: $0.symbol, requirement: $0.requirement) }
        candidates += RewardCatalog.cosmetics.filter { !$0.requirement.isMet(snap) }
            .map { NextUnlock(title: $0.title, symbol: $0.category.symbol, requirement: $0.requirement) }
        return candidates.max { $0.requirement.progress(snap) < $1.requirement.progress(snap) }
    }

    // MARK: Brain state

    /// Derived only from things RotTime measured itself.
    func brainState(now: Date = Date(), sleepActive: Bool) -> BrainState {
        let hour = Calendar.current.component(.hour, from: now)
        if BrainHealth.isHurt || isOverPhoneGoal { return .sick }
        if sleepActive || hour >= 23 || hour < 6 { return .resting }
        let s = today
        if isTrackingPhoneTime {
            if phoneProgress < 0.6 { return s.focusSessions > 0 ? .recovered : .energetic }
            return .slightlyTired
        }
        if s.focusSessions > 0 { return .recovered }
        return hour < 12 || s.shieldResists > 0 ? .energetic : .slightlyTired
    }

    // MARK: Reset

    func resetAllData() {
        ShieldController.clearEverything()
        for key in [Keys.profile, Keys.appearance, Keys.rewards, Keys.history] { defaults.removeObject(forKey: key) }
        for key in [SharedStore.Key.dayStats, .blockModes, .focusSession, .extensionEvents, .pendingPauses] { SharedStore.remove(key) }
        defaults.removeObject(forKey: ChatStore.historyKey)
        profile = UserProfile()
        appearance = BrainAppearance()
        rewards = RewardProgress()
        focusHistory = []
        refreshShared()
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home, focus, block, chat, progress
    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: return "Home"
        case .focus: return "Focus"
        case .block: return "Shields"
        case .chat: return "Chat"
        case .progress: return "Progress"
        }
    }
    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .focus: return "timer"
        case .block: return "shield.lefthalf.filled"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .progress: return "chart.bar.fill"
        }
    }
}
