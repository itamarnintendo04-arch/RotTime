import AppIntents
import Foundation

// App Intents used by free Shortcuts automations. They need no special entitlement.
//
// Automation "When Instagram is opened" (Run Immediately):
//   1. RotTime ▸ Should Noodle Step In?  (App: Instagram)
//   2. If Shortcut Result is true → RotTime ▸ Talk to Noodle (App: Instagram)
// Automation "When Instagram is closed" (Run Immediately):
//   1. RotTime ▸ Log App Closed (App: Instagram)

extension DistractingApp: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "App" }

    static var caseDisplayRepresentations: [DistractingApp: DisplayRepresentation] {
        [
            .instagram: "Instagram", .tiktok: "TikTok", .youtube: "YouTube", .x: "X", .snapchat: "Snapchat",
            .facebook: "Facebook", .reddit: "Reddit", .threads: "Threads", .netflix: "Netflix",
            .games: "Games", .other: "Another app",
        ]
    }
}

/// Logs the open and tells the Shortcut whether to bring you to Noodle.
struct ShouldNoodleStepInIntent: AppIntent {
    static var title: LocalizedStringResource = "Should Noodle Step In?"
    static var description = IntentDescription("Records that you opened an app and returns true when Noodle should talk to you first (false while you have extra time).")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "App", default: .instagram)
    var app: DistractingApp

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        FreeUsageStore.logOpened(app)
        AppState.shared.refreshShared()
        return .result(value: FreeUsageStore.shouldIntervene(for: app))
    }
}

/// Opens RotTime straight into Noodle's "do you really want to scroll?" moment.
struct TalkToNoodleIntent: AppIntent {
    static var title: LocalizedStringResource = "Talk to Noodle"
    static var description = IntentDescription("Opens RotTime so Noodle can ask whether you really want to keep scrolling.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "App", default: .instagram)
    var app: DistractingApp

    @MainActor
    func perform() async throws -> some IntentResult {
        FreeUsageStore.pendingApp = app
        InterventionCenter.shared.presentPendingIfNeeded()
        return .result()
    }
}

/// Ends the visit so RotTime knows how long you spent in the app.
struct LogAppClosedIntent: AppIntent {
    static var title: LocalizedStringResource = "Log App Closed"
    static var description = IntentDescription("Records that you left an app, so RotTime can count your time in it.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "App", default: .instagram)
    var app: DistractingApp

    @MainActor
    func perform() async throws -> some IntentResult {
        FreeUsageStore.logClosed(app)
        AppState.shared.refreshShared()
        return .result()
    }
}
