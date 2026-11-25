import Combine
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// App-side façade over FamilyControls / ManagedSettings / DeviceActivity.
@MainActor
final class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()

    @Published private(set) var authorizationStatus: AuthorizationStatus
    @Published private(set) var modes: [BlockMode]
    @Published private(set) var activeShields: [String: ActiveShield] = [:]
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        modes = SharedStore.blockModes
        activeShields = SharedStore.activeShields
        AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in self?.authorizationStatus = status }
            .store(in: &cancellables)
    }

    var isAuthorized: Bool { authorizationStatus == .approved }

    var statusText: String {
        switch authorizationStatus {
        case .approved: return "Screen Time connected"
        case .denied: return "Screen Time access denied"
        case .notDetermined: return "Screen Time not connected yet"
        @unknown default: return "Screen Time status unknown"
        }
    }

    // MARK: Authorization

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            errorMessage = Self.describe(error)
        }
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func revokeAuthorization() {
        ShieldController.clearEverything()
        for mode in modes { ActivityScheduler.unregister(mode); ActivityScheduler.unregisterLimit(mode) }
        AuthorizationCenter.shared.revokeAuthorization { _ in }
        refresh()
    }

    static func describe(_ error: Error) -> String {
        if let fc = error as? FamilyControlsError {
            switch fc {
            case .restricted: return "Screen Time is restricted on this device (for example by Screen Time parental settings)."
            case .unavailable: return "Screen Time isn't available. Make sure you're signed in to iCloud and Screen Time is turned on."
            case .invalidAccountType: return "This Apple Account type can't authorize Screen Time apps."
            case .invalidArgument: return "Screen Time rejected the request."
            case .authorizationConflict: return "Another app already manages Screen Time on this device."
            case .authorizationCanceled: return "Authorization was cancelled."
            case .networkError: return "Network error – please try again."
            case .authenticationMethodUnavailable: return "Set a device passcode to use Screen Time apps."
            @unknown default: return error.localizedDescription
            }
        }
        return error.localizedDescription
    }

    // MARK: State

    func refresh() {
        ShieldController.reapplyAll()
        activeShields = SharedStore.activeShields
        modes = SharedStore.blockModes
    }

    func mode(_ kind: BlockModeKind) -> BlockMode? { modes.first { $0.kind == kind } }

    func isActive(_ mode: BlockMode) -> Bool { activeShields[mode.shieldKey] != nil }

    var sleepModeActive: Bool {
        guard let sleep = mode(.sleep) else { return false }
        return isActive(sleep)
    }

    var sortedActiveShields: [ActiveShield] {
        activeShields.values.sorted { $0.startedAt > $1.startedAt }
    }

    // MARK: Editing

    func save(_ mode: BlockMode) {
        if let i = modes.firstIndex(where: { $0.id == mode.id }) { modes[i] = mode } else { modes.append(mode) }
        SharedStore.blockModes = modes
        // Keep the system schedule in sync with the edited mode.
        if mode.scheduleEnabled { setSchedule(mode, enabled: true) }
        if mode.kind == .custom { syncLimit(mode) }
        // If the mode is running, refresh its shield with the new selection.
        if var running = activeShields[mode.shieldKey] {
            running.selection = mode.selection
            running.strict = mode.strict
            ShieldController.activate(running)
            activeShields = SharedStore.activeShields
        }
    }

    func addCustomMode() -> BlockMode {
        let mode = BlockMode(kind: .custom, name: "My Mode \(modes.filter { $0.kind == .custom }.count + 1)",
                             schedule: BlockSchedule(startHour: 18, startMinute: 0, endHour: 20, endMinute: 0),
                             sessionMinutes: 30, breakMinutes: 5)
        modes.append(mode)
        SharedStore.blockModes = modes
        return mode
    }

    func delete(_ mode: BlockMode) {
        ActivityScheduler.unregister(mode)
        ActivityScheduler.unregisterLimit(mode)
        ActivityScheduler.stop(name: ActivityScheduler.manualActivityName(for: mode))
        ShieldController.deactivate(key: mode.shieldKey)
        modes.removeAll { $0.id == mode.id }
        SharedStore.blockModes = modes
        refresh()
    }

    @discardableResult
    func setSchedule(_ mode: BlockMode, enabled: Bool) -> Bool {
        var updated = mode
        updated.scheduleEnabled = enabled
        do {
            if enabled {
                guard mode.hasSelection else { throw ScheduleIssue.emptySelection }
                try ActivityScheduler.register(updated)
                // If we're already inside the window, shield right away.
                if mode.schedule.contains(Date()) {
                    ShieldController.activate(ActiveShield(key: mode.shieldKey, title: mode.name, source: .schedule,
                                                           selection: mode.selection, strict: mode.strict,
                                                           endsAt: nextEnd(of: mode.schedule)))
                }
            } else {
                ActivityScheduler.unregister(updated)
                if activeShields[mode.shieldKey]?.source == .schedule { ShieldController.deactivate(key: mode.shieldKey) }
            }
        } catch {
            updated.scheduleEnabled = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        if let i = modes.firstIndex(where: { $0.id == mode.id }) { modes[i] = updated }
        SharedStore.blockModes = modes
        activeShields = SharedStore.activeShields
        return updated.scheduleEnabled == enabled
    }

    private func syncLimit(_ mode: BlockMode) {
        do {
            if mode.dailyLimitMinutes != nil, mode.hasSelection {
                try ActivityScheduler.registerDailyLimit(for: mode)
            } else {
                ActivityScheduler.unregisterLimit(mode)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func nextEnd(of schedule: BlockSchedule, now: Date = Date()) -> Date? {
        let cal = Calendar.current
        guard var end = cal.date(bySettingHour: schedule.endHour, minute: schedule.endMinute, second: 0, of: now) else { return nil }
        if end <= now { end = cal.date(byAdding: .day, value: 1, to: end) ?? end }
        return end
    }

    enum ScheduleIssue: LocalizedError {
        case emptySelection, notAuthorized
        var errorDescription: String? {
            switch self {
            case .emptySelection: return "Choose at least one app, category or website first."
            case .notAuthorized: return "Connect Screen Time first so RotTime can shield apps."
            }
        }
    }

    // MARK: Running blocks

    /// Shields the mode's selection now. `minutes == nil` means "until I stop".
    @discardableResult
    func start(_ mode: BlockMode, minutes: Int?) -> Bool {
        guard isAuthorized else { errorMessage = ScheduleIssue.notAuthorized.errorDescription; return false }
        guard mode.hasSelection else { errorMessage = ScheduleIssue.emptySelection.errorDescription; return false }
        let end = minutes.map { Date().addingTimeInterval(TimeInterval($0 * 60)) }
        let source: ActiveShield.Source = mode.kind == .instant ? .instant : .manual
        ShieldController.activate(ActiveShield(key: mode.shieldKey, title: mode.name, source: source,
                                               selection: mode.selection, strict: mode.strict && end != nil, endsAt: end))
        let name = ActivityScheduler.manualActivityName(for: mode)
        if let end {
            do { try ActivityScheduler.startOneShot(name: name, until: end) } catch {
                errorMessage = "The shield is on, but the automatic end couldn't be scheduled: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription). Open RotTime to stop it."
            }
        } else {
            ActivityScheduler.stop(name: name)
        }
        AppState.shared.recordBlockSession()
        activeShields = SharedStore.activeShields
        return true
    }

    func canStop(_ shield: ActiveShield) -> Bool {
        !(shield.strict && (shield.endsAt ?? .distantFuture) > Date())
    }

    func stop(_ shield: ActiveShield) {
        guard canStop(shield) else {
            errorMessage = "This is a strict session — it ends on its own at \(shield.endsAt?.formatted(date: .omitted, time: .shortened) ?? "the scheduled time")."
            return
        }
        ShieldController.deactivate(key: shield.key)
        if shield.key.hasPrefix("mode."), let id = UUID(uuidString: String(shield.key.dropFirst(5))),
           let mode = modes.first(where: { $0.id == id }) {
            ActivityScheduler.stop(name: ActivityScheduler.manualActivityName(for: mode))
        }
        activeShields = SharedStore.activeShields
    }

    // MARK: Focus timer integration

    var focusSelection: FamilyActivitySelection? {
        guard let mode = mode(.focus), mode.hasSelection else { return nil }
        return mode.selection
    }

    func beginFocusShield(until end: Date, selection: FamilyActivitySelection, strict: Bool) {
        guard isAuthorized else { return }
        ShieldController.activate(ActiveShield(key: "focus", title: "Focus session", source: .focus,
                                               selection: selection, strict: strict, endsAt: end))
        do { try ActivityScheduler.startOneShot(name: ActivityScheduler.focusActivity, until: end) } catch {
            errorMessage = "Focus shield is on, but its automatic end couldn't be scheduled. It will be lifted when you return to RotTime."
        }
        activeShields = SharedStore.activeShields
    }

    func endFocusShield() {
        ShieldController.deactivate(key: "focus")
        ActivityScheduler.stop(name: ActivityScheduler.focusActivity)
        activeShields = SharedStore.activeShields
    }
}
