import Foundation
import SwiftUI

/// Date-based focus timer.
///
/// Nothing ticks in the background: the model stores *when* a phase ends, schedules a local
/// notification for that moment, and (when blocking) a DeviceActivity interval so the
/// monitor extension lifts the shield on time even if RotTime is suspended or killed.
/// When the app returns to the foreground `reconcile()` catches up on anything that finished.
@MainActor
final class FocusTimerModel: ObservableObject {
    static let shared = FocusTimerModel()

    struct Runtime: Codable, Equatable {
        var session: SharedFocusSession?
        var pausedRemaining: TimeInterval?
        var pausedPhase: SharedFocusSession.Phase?
        var accumulated: TimeInterval = 0
        var segmentStart: Date?
        var firstStart: Date?
        var plannedSeconds: Double = 0
        /// "As long as I can" focus: counts up until stopped (optional so older saves decode).
        var openEnded: Bool?
    }

    struct Completion: Identifiable, Equatable {
        let id = UUID()
        let minutes: Int
        let points: Int
        var newRecord = false
    }

    @Published private(set) var runtime: Runtime { didSet { persist() } }
    @Published var focusMinutes: Int = 25 { didSet { savePrefs() } }
    @Published var breakMinutes: Int = 5 { didSet { savePrefs() } }
    @Published var blockApps: Bool = true { didSet { savePrefs() } }
    @Published var strict: Bool = false { didSet { savePrefs() } }
    @Published var autoStartBreak: Bool = true { didSet { savePrefs() } }
    /// Next focus session counts up with no fixed end.
    @Published var openEnded: Bool = false { didSet { savePrefs() } }
    /// Safety cap for open-ended sessions (the shield never stays up forever).
    static let openEndedMax: TimeInterval = 12 * 3600
    @Published var completion: Completion?

    private let runtimeKey = "rt.focus.runtime"
    private let prefsKey = "rt.focus.prefs"

    private struct Prefs: Codable { var focus: Int; var rest: Int; var block: Bool; var strict: Bool; var autoBreak: Bool; var open: Bool? }

    init() {
        let d = AppGroup.defaults
        if let data = d.data(forKey: runtimeKey), let r = try? JSONDecoder().decode(Runtime.self, from: data) {
            runtime = r
        } else {
            runtime = Runtime()
        }
        if let data = d.data(forKey: prefsKey), let p = try? JSONDecoder().decode(Prefs.self, from: data) {
            focusMinutes = p.focus; breakMinutes = p.rest; blockApps = p.block; strict = p.strict; autoStartBreak = p.autoBreak; openEnded = p.open ?? false
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(runtime) { AppGroup.defaults.set(data, forKey: runtimeKey) }
        SharedStore.save(runtime.session, .focusSession)
    }

    private func savePrefs() {
        let p = Prefs(focus: focusMinutes, rest: breakMinutes, block: blockApps, strict: strict, autoBreak: autoStartBreak, open: openEnded)
        if let data = try? JSONEncoder().encode(p) { AppGroup.defaults.set(data, forKey: prefsKey) }
    }

    // MARK: Derived state

    var isRunning: Bool { runtime.session != nil }
    var isPaused: Bool { runtime.pausedRemaining != nil }
    var isIdle: Bool { !isRunning && !isPaused }
    var phase: SharedFocusSession.Phase? { runtime.session?.phase ?? runtime.pausedPhase }
    var isOpenEnded: Bool { runtime.openEnded == true }
    /// Open-ended sessions are never strict, so you can always finish them.
    private var sessionStrict: Bool { strict && !isOpenEnded }
    var canPause: Bool { isRunning && !(sessionStrict && phase == .focus && runtime.session?.blocksApps == true) }

    /// Time focused so far in the current phase (excluding pauses).
    func elapsed(at date: Date = Date()) -> TimeInterval {
        runtime.accumulated + (runtime.segmentStart.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    func remaining(at date: Date = Date()) -> TimeInterval {
        if let r = runtime.pausedRemaining { return r }
        guard let s = runtime.session else { return TimeInterval((phase == .rest ? breakMinutes : focusMinutes) * 60) }
        return max(0, s.endsAt.timeIntervalSince(date))
    }

    func progress(at date: Date = Date()) -> Double {
        guard !isIdle else { return 0 }
        if isOpenEnded && phase == .focus {
            // Ring fills toward your personal best.
            let target = max(AppState.shared.longestFocusSeconds, 25 * 60)
            return min(1, elapsed(at: date) / target)
        }
        let planned = runtime.plannedSeconds > 0 ? runtime.plannedSeconds : Double(focusMinutes * 60)
        return min(1, max(0, 1 - remaining(at: date) / planned))
    }

    // MARK: Controls

    func startFocus(minutes: Int? = nil) {
        if let minutes { focusMinutes = minutes; openEnded = false }
        start(phase: .focus, seconds: openEnded ? Self.openEndedMax : TimeInterval(focusMinutes * 60), from: Date())
    }

    func startBreak(minutes: Int? = nil, from start: Date = Date()) {
        if let minutes { breakMinutes = minutes }
        self.start(phase: .rest, seconds: TimeInterval(breakMinutes * 60), from: start)
    }

    private func start(phase: SharedFocusSession.Phase, seconds: TimeInterval, from start: Date) {
        let end = start.addingTimeInterval(seconds)
        let selection = ScreenTimeManager.shared.focusSelection
        let shouldBlock = phase == .focus && blockApps && selection != nil && ScreenTimeManager.shared.isAuthorized
        runtime = Runtime(session: SharedFocusSession(phase: phase, startedAt: start, endsAt: end, plannedSeconds: seconds, blocksApps: shouldBlock),
                          pausedRemaining: nil, pausedPhase: nil, accumulated: 0, segmentStart: start, firstStart: start, plannedSeconds: seconds,
                          openEnded: phase == .focus && openEnded)
        if shouldBlock, let selection {
            ScreenTimeManager.shared.beginFocusShield(until: end, selection: selection, strict: sessionStrict)
        }
        if isOpenEnded { NotificationManager.cancelFocusEnd() } else {
            NotificationManager.scheduleFocusEnd(at: end, phase: phase, brainName: AppState.shared.brainName)
        }
        Haptics.tap(AppState.shared.profile.hapticsEnabled)
    }

    func pause() {
        guard canPause, let s = runtime.session else { return }
        let now = Date()
        var r = runtime
        r.accumulated += now.timeIntervalSince(r.segmentStart ?? s.startedAt)
        r.pausedRemaining = max(0, s.endsAt.timeIntervalSince(now))
        r.pausedPhase = s.phase
        r.session = nil
        r.segmentStart = nil
        runtime = r
        NotificationManager.cancelFocusEnd()
        if s.blocksApps { ScreenTimeManager.shared.endFocusShield() }
    }

    func resume() {
        guard let remaining = runtime.pausedRemaining, let phase = runtime.pausedPhase else { return }
        let now = Date()
        let end = now.addingTimeInterval(remaining)
        let selection = ScreenTimeManager.shared.focusSelection
        let shouldBlock = phase == .focus && blockApps && selection != nil && ScreenTimeManager.shared.isAuthorized
        var r = runtime
        r.session = SharedFocusSession(phase: phase, startedAt: now, endsAt: end, plannedSeconds: r.plannedSeconds, blocksApps: shouldBlock)
        r.pausedRemaining = nil
        r.pausedPhase = nil
        r.segmentStart = now
        runtime = r
        if shouldBlock, let selection { ScreenTimeManager.shared.beginFocusShield(until: end, selection: selection, strict: sessionStrict) }
        if !isOpenEnded { NotificationManager.scheduleFocusEnd(at: end, phase: phase, brainName: AppState.shared.brainName) }
    }

    /// Ends the current phase early. Focus time already spent still counts.
    func stop() {
        guard !isIdle else { return }
        if isOpenEnded && phase == .focus {
            finishOpenEnded()
            return
        }
        if let s = runtime.session, s.blocksApps, sessionStrict, s.phase == .focus { return }
        let now = Date()
        let elapsed = runtime.accumulated + (runtime.segmentStart.map { now.timeIntervalSince($0) } ?? 0)
        if phase == .focus {
            AppState.shared.recordFocus(seconds: elapsed, kind: .focus, completed: false, label: "Focus", start: runtime.firstStart ?? now)
        }
        NotificationManager.cancelFocusEnd()
        if runtime.session?.blocksApps == true { ScreenTimeManager.shared.endFocusShield() }
        runtime = Runtime()
    }

    /// "I'm done" for an open-ended session: it counts as a completed session (if ≥ 5 min).
    private func finishOpenEnded(now: Date = Date()) {
        let seconds = elapsed(at: now)
        let previousBest = AppState.shared.longestFocusSeconds
        if runtime.session?.blocksApps == true { ScreenTimeManager.shared.endFocusShield() }
        NotificationManager.cancelFocusEnd()
        let completed = seconds >= 5 * 60
        AppState.shared.recordFocus(seconds: seconds, kind: .focus, completed: completed, label: "Open focus", start: runtime.firstStart ?? now)
        runtime = Runtime()
        guard completed else { return }
        let minutes = Int((seconds / 60).rounded())
        completion = Completion(minutes: minutes, points: minutes, newRecord: seconds > previousBest && previousBest > 0)
        ChatEngineStore.shared.postEvent(.focusCompleted(minutes: minutes))
        Haptics.success(AppState.shared.profile.hapticsEnabled)
        if autoStartBreak && breakMinutes > 0 { startBreak(from: now) }
    }

    /// Catches up after the app was in the background.
    func reconcile(now: Date = Date()) {
        guard let s = runtime.session, s.endsAt <= now else { return }
        finish(session: s, at: s.endsAt, now: now)
    }

    private func finish(session s: SharedFocusSession, at end: Date, now: Date) {
        let elapsed = runtime.accumulated + end.timeIntervalSince(runtime.segmentStart ?? s.startedAt)
        if s.blocksApps { ScreenTimeManager.shared.endFocusShield() }
        switch s.phase {
        case .focus:
            AppState.shared.recordFocus(seconds: elapsed, kind: .focus, completed: true, label: "Focus", start: runtime.firstStart ?? s.startedAt)
            let minutes = Int((elapsed / 60).rounded())
            completion = Completion(minutes: minutes, points: minutes)
            ChatEngineStore.shared.postEvent(.focusCompleted(minutes: minutes))
            Haptics.success(AppState.shared.profile.hapticsEnabled)
            runtime = Runtime()
            if autoStartBreak && breakMinutes > 0 {
                // The break began the moment focus ended, even if we were in the background.
                startBreak(from: end)
                reconcile(now: now)
            }
        case .rest:
            AppState.shared.recordFocus(seconds: elapsed, kind: .rest, completed: true, label: "Break", start: runtime.firstStart ?? s.startedAt)
            if end < now.addingTimeInterval(-2) { NotificationManager.cancelFocusEnd() }
            runtime = Runtime()
        }
    }

    /// Called once per second by the UI while visible.
    func tick(_ date: Date) {
        if let s = runtime.session, s.endsAt <= date { finish(session: s, at: s.endsAt, now: date) }
    }
}
