import Foundation

enum ChatSender: String, Codable { case brain, user }

/// Buttons the brain can attach to a message.
enum ChatAction: String, Codable, Hashable {
    case startFocus25, startFocus50, startBreak5, openBlocking, openCustomize, openStats, openFocus

    var title: String {
        switch self {
        case .startFocus25: return "Start 25-min focus"
        case .startFocus50: return "Start 50-min deep focus"
        case .startBreak5: return "Take a 5-min break"
        case .openBlocking: return "Open Shields"
        case .openCustomize: return "Customize me"
        case .openStats: return "See my progress"
        case .openFocus: return "Open focus timer"
        }
    }

    var symbol: String {
        switch self {
        case .startFocus25, .startFocus50, .openFocus: return "timer"
        case .startBreak5: return "cup.and.saucer.fill"
        case .openBlocking: return "shield.lefthalf.filled"
        case .openCustomize: return "paintbrush.fill"
        case .openStats: return "chart.bar.fill"
        }
    }
}

struct ChatMessage: Codable, Identifiable, Equatable {
    var id = UUID()
    var sender: ChatSender
    var text: String
    var date = Date()
    var expression: BrainExpression?
    var actions: [ChatAction] = []
    /// Marks daily events / system cards.
    var isEvent = false
}

/// Everything the responder may use to personalise a reply. Only on-device data.
struct ChatContext {
    var userName: String
    var brainName: String
    var focusMinutesToday: Int
    /// The user's daily phone-time goal.
    var goalMinutes: Int
    var phoneMinutesToday: Int = 0
    var phoneTracked: Bool = false
    var sessionsToday: Int
    var streak: Int
    var resistsToday: Int
    var activeShieldNames: [String]
    var state: BrainState
    var hour: Int
    var points: Int
    var isScreenTimeConnected: Bool
    var focusRunning: Bool

    /// Phone minutes left before reaching the goal.
    var goalLeft: Int { max(0, goalMinutes - phoneMinutesToday) }
    var partOfDay: String {
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<22: return "evening"
        default: return "night"
        }
    }
    var nameSuffix: String { userName.isEmpty ? "" : ", \(userName)" }
}

struct BrainReply {
    var bubbles: [String]
    var expression: BrainExpression
    var actions: [ChatAction] = []
    var quickReplies: [String] = []
}

/// Pluggable conversation backend. The app ships with `LocalBrainResponder` (no network,
/// no paid API). A future AI provider can conform to this protocol and be swapped in via
/// `ChatEngineStore.responder` without touching the UI.
protocol BrainResponder {
    func reply(to message: String, context: ChatContext, history: [ChatMessage]) async -> BrainReply
}

enum ChatEvent {
    case dailyWelcome
    case focusCompleted(minutes: Int)
    case shieldResisted(count: Int)
    case blockStarted(name: String)
    case streakMilestone(days: Int)
    case goalReached
    case phoneGoalReached
}

enum ChatStore {
    static let historyKey = "rt.chat.history"
    static let dailyKey = "rt.chat.lastDaily"
}
