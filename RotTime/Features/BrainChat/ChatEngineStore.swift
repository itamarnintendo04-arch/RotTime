import Foundation
import SwiftUI

/// Drives the Brain Chat conversation: history, typing indicator, quick replies and
/// app events (daily check-ins, finished sessions, shields resisted…).
@MainActor
final class ChatEngineStore: ObservableObject {
    static let shared = ChatEngineStore()

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isTyping = false
    @Published private(set) var quickReplies: [String] = ["Hi!", "How am I doing?", "What can you do?"]
    @Published private(set) var currentExpression: BrainExpression = .happy

    /// Swap this for an AI-backed responder in the future.
    var responder: BrainResponder = LocalBrainResponder()
    private let local = LocalBrainResponder()
    private var queue: [BrainReply] = []
    private var pendingEvents: [ChatEvent] = []

    init() {
        if let data = AppGroup.defaults.data(forKey: ChatStore.historyKey),
           let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = saved
        }
        if let last = messages.last(where: { $0.sender == .brain }), let e = last.expression { currentExpression = e }
    }

    private func persist() {
        let trimmed = Array(messages.suffix(300))
        if let data = try? JSONEncoder().encode(trimmed) { AppGroup.defaults.set(data, forKey: ChatStore.historyKey) }
    }

    func context() -> ChatContext {
        let app = AppState.shared
        let st = ScreenTimeManager.shared
        return ChatContext(
            userName: app.profile.userName,
            brainName: app.brainName,
            focusMinutesToday: app.todayFocusMinutes,
            goalMinutes: app.phoneGoal,
            phoneMinutesToday: app.phoneMinutesToday,
            phoneTracked: app.isTrackingPhoneTime,
            sessionsToday: app.today.focusSessions,
            streak: app.currentStreak,
            resistsToday: app.today.shieldResists,
            activeShieldNames: st.sortedActiveShields.map(\.title),
            state: app.brainState(sleepActive: st.sleepModeActive),
            hour: Calendar.current.component(.hour, from: Date()),
            points: app.sparkPoints,
            isScreenTimeConnected: st.isAuthorized,
            focusRunning: FocusTimerModel.shared.isRunning
        )
    }

    // MARK: Sending

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(ChatMessage(sender: .user, text: text))
        persist()
        AppState.shared.recordChatMessage()
        quickReplies = []
        let ctx = context()
        let history = messages
        Task {
            let reply = await responder.reply(to: text, context: ctx, history: history)
            deliver(reply)
        }
    }

    /// Queue an event; it's shown immediately if the chat is idle.
    func postEvent(_ event: ChatEvent) {
        deliver(local.eventReply(event, context()), isEvent: true)
    }

    /// Posts the once-per-day welcome if it hasn't been shown today.
    func runDailyEventsIfNeeded() {
        let today = DayKey.string(for: Date())
        guard AppGroup.defaults.string(forKey: ChatStore.dailyKey) != today else { return }
        AppGroup.defaults.set(today, forKey: ChatStore.dailyKey)
        postEvent(.dailyWelcome)
    }

    func ingestExtensionEvents(_ events: [ExtensionEvent]) {
        let resisted = events.filter { $0.kind == .shieldResisted }.count
        if resisted > 0 { postEvent(.shieldResisted(count: resisted)) }
        if events.contains(where: { $0.kind == .phoneGoalReached }) { postEvent(.phoneGoalReached) }
    }

    func clearHistory() {
        messages = []
        persist()
        quickReplies = ["Hi!", "How am I doing?", "What can you do?"]
    }

    // MARK: Typing simulation

    private func deliver(_ reply: BrainReply, isEvent: Bool = false) {
        queue.append(reply)
        if !isTyping { drain(isEvent: isEvent) }
    }

    private func drain(isEvent: Bool) {
        guard !queue.isEmpty else { return }
        let reply = queue.removeFirst()
        isTyping = true
        withAnimation(.easeInOut(duration: 0.25)) { currentExpression = .thinking }
        Task {
            for (index, bubble) in reply.bubbles.enumerated() {
                let delay = min(1.8, 0.45 + Double(bubble.count) * 0.018)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                let isLast = index == reply.bubbles.count - 1
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    messages.append(ChatMessage(sender: .brain, text: bubble, expression: reply.expression,
                                                actions: isLast ? reply.actions : [], isEvent: isEvent && index == 0))
                    currentExpression = reply.expression
                }
                Haptics.selection(AppState.shared.profile.hapticsEnabled)
            }
            isTyping = false
            quickReplies = reply.quickReplies
            persist()
            if !queue.isEmpty { drain(isEvent: false) }
        }
    }
}
