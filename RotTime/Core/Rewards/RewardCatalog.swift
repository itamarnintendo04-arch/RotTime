import Foundation

/// Everything the app can observe about the user's progress, aggregated.
struct ProgressSnapshot: Equatable {
    var totalFocusMinutes = 0
    var totalSessions = 0
    var currentStreak = 0
    var bestStreak = 0
    var points = 0
    var totalResists = 0
    var totalBlockSessions = 0
    var chatMessages = 0
    var goalDays = 0
}

/// How an item or achievement is earned. Always through activity — never money or chance.
enum Requirement: Equatable {
    case free
    case focusMinutes(Int)
    case sessions(Int)
    case streak(Int)
    case points(Int)
    case resists(Int)
    case blockSessions(Int)
    case chats(Int)
    case goalDays(Int)

    var text: String {
        switch self {
        case .free: return "Unlocked"
        case .focusMinutes(let n): return "Focus for \(n.minutesText) in total"
        case .sessions(let n): return "Complete \(n) focus sessions"
        case .streak(let n): return "Reach a \(n)-day streak"
        case .points(let n): return "Earn \(n) spark points"
        case .resists(let n): return "Choose focus on a shield \(n) times"
        case .blockSessions(let n): return "Run \(n) blocking sessions"
        case .chats(let n): return "Send \(SharedStore.brainName) \(n) messages"
        case .goalDays(let n): return "Stay under your phone-time goal on \(n) days"
        }
    }

    private func pair(_ s: ProgressSnapshot) -> (Int, Int) {
        switch self {
        case .free: return (1, 1)
        case .focusMinutes(let n): return (s.totalFocusMinutes, n)
        case .sessions(let n): return (s.totalSessions, n)
        case .streak(let n): return (s.bestStreak, n)
        case .points(let n): return (s.points, n)
        case .resists(let n): return (s.totalResists, n)
        case .blockSessions(let n): return (s.totalBlockSessions, n)
        case .chats(let n): return (s.chatMessages, n)
        case .goalDays(let n): return (s.goalDays, n)
        }
    }

    func progress(_ s: ProgressSnapshot) -> Double {
        let (have, need) = pair(s)
        return need == 0 ? 1 : min(1, Double(have) / Double(need))
    }

    func progressText(_ s: ProgressSnapshot) -> String {
        let (have, need) = pair(s)
        return "\(min(have, need))/\(need)"
    }

    func isMet(_ s: ProgressSnapshot) -> Bool { progress(s) >= 1 }
}

enum CosmeticCategory: String, CaseIterable, Identifiable {
    case color, hat, accessory, effect, decor, expression
    var id: String { rawValue }
    var title: String {
        switch self {
        case .color: return "Colors"
        case .hat: return "Hats"
        case .accessory: return "Accessories"
        case .effect: return "Effects"
        case .decor: return "Decor"
        case .expression: return "Personality"
        }
    }
    var singular: String {
        switch self {
        case .color: return "color"
        case .hat: return "hat"
        case .accessory: return "accessory"
        case .effect: return "effect"
        case .decor: return "decoration"
        case .expression: return "personality"
        }
    }
    var symbol: String {
        switch self {
        case .color: return "paintpalette.fill"
        case .hat: return "graduationcap.fill"
        case .accessory: return "eyeglasses"
        case .effect: return "sparkles"
        case .decor: return "leaf.fill"
        case .expression: return "face.smiling.inverse"
        }
    }
}

struct CosmeticItem: Identifiable {
    let category: CosmeticCategory
    let rawValue: String
    let title: String
    let requirement: Requirement
    var id: String { "\(category.rawValue).\(rawValue)" }
}

enum RewardCatalog {
    static let cosmetics: [CosmeticItem] = {
        var items: [CosmeticItem] = []
        let colorReq: [BodyColor: Requirement] = [
            .bubblegum: .free, .peach: .free, .mint: .sessions(2), .lavender: .focusMinutes(90),
            .sky: .streak(2), .lemon: .resists(5), .midnight: .focusMinutes(300), .golden: .goalDays(10),
        ]
        items += BodyColor.allCases.map { CosmeticItem(category: .color, rawValue: $0.rawValue, title: $0.title, requirement: colorReq[$0] ?? .free) }

        let hatReq: [HatStyle: Requirement] = [
            .none: .free, .beanie: .free, .headphones: .sessions(3), .party: .points(100), .flowerCrown: .streak(3),
            .gradCap: .focusMinutes(240), .propeller: .chats(20), .wizard: .sessions(20), .crown: .streak(14),
        ]
        items += HatStyle.allCases.map { CosmeticItem(category: .hat, rawValue: $0.rawValue, title: $0.title, requirement: hatReq[$0] ?? .free) }

        let accReq: [AccessoryStyle: Requirement] = [
            .none: .free, .roundGlasses: .free, .starClip: .sessions(1), .bowtie: .points(150), .sweatband: .focusMinutes(120),
            .scarf: .blockSessions(5), .sunglasses: .resists(15),
        ]
        items += AccessoryStyle.allCases.map { CosmeticItem(category: .accessory, rawValue: $0.rawValue, title: $0.title, requirement: accReq[$0] ?? .free) }

        let fxReq: [EffectStyle: Requirement] = [
            .none: .free, .sparkles: .sessions(1), .hearts: .chats(10), .bubbles: .focusMinutes(60), .aura: .goalDays(3),
            .notes: .sessions(8), .orbit: .points(600),
        ]
        items += EffectStyle.allCases.map { CosmeticItem(category: .effect, rawValue: $0.rawValue, title: $0.title, requirement: fxReq[$0] ?? .free) }

        let decorReq: [DecorStyle: Requirement] = [
            .none: .free, .plant: .free, .mug: .sessions(2), .books: .focusMinutes(150), .lamp: .streak(4),
            .mushroom: .blockSessions(10), .crystal: .goalDays(7),
        ]
        items += DecorStyle.allCases.map { CosmeticItem(category: .decor, rawValue: $0.rawValue, title: $0.title, requirement: decorReq[$0] ?? .free) }

        let exprReq: [ExpressionStyle: Requirement] = [.classic: .free, .calm: .free, .cheeky: .chats(5), .starry: .sessions(5)]
        items += ExpressionStyle.allCases.map { CosmeticItem(category: .expression, rawValue: $0.rawValue, title: $0.title, requirement: exprReq[$0] ?? .free) }
        return items
    }()

    static func items(in category: CosmeticCategory) -> [CosmeticItem] {
        cosmetics.filter { $0.category == category }
    }

    static func item(_ category: CosmeticCategory, _ raw: String) -> CosmeticItem? {
        cosmetics.first { $0.category == category && $0.rawValue == raw }
    }
}

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let requirement: Requirement
    let bonusPoints: Int
    /// Optional special animation unlocked with the achievement.
    let unlocksExpression: BrainExpression?

    static let all: [Achievement] = [
        Achievement(id: "first-focus", title: "First Spark", detail: "Finish your very first focus session.", symbol: "sparkle",
                    requirement: .sessions(1), bonusPoints: 20, unlocksExpression: nil),
        Achievement(id: "hour-power", title: "Hour Power", detail: "Focus for one hour in total.", symbol: "clock.badge.checkmark.fill",
                    requirement: .focusMinutes(60), bonusPoints: 40, unlocksExpression: nil),
        Achievement(id: "steady-3", title: "Steady Glow", detail: "Keep a 3-day streak going.", symbol: "flame.fill",
                    requirement: .streak(3), bonusPoints: 50, unlocksExpression: .proud),
        Achievement(id: "shield-5", title: "Gentle Guardian", detail: "Choose focus on a shield 5 times.", symbol: "shield.lefthalf.filled",
                    requirement: .resists(5), bonusPoints: 40, unlocksExpression: nil),
        Achievement(id: "chatty", title: "Brain Buddies", detail: "Have a proper chat with your brain.", symbol: "bubble.left.and.bubble.right.fill",
                    requirement: .chats(10), bonusPoints: 25, unlocksExpression: .love),
        Achievement(id: "ten-sessions", title: "Deep Diver", detail: "Complete 10 focus sessions.", symbol: "water.waves",
                    requirement: .sessions(10), bonusPoints: 80, unlocksExpression: nil),
        Achievement(id: "goal-3", title: "Goal Getter", detail: "Stay under your phone-time goal on 3 days.", symbol: "target",
                    requirement: .goalDays(3), bonusPoints: 60, unlocksExpression: nil),
        Achievement(id: "blocker-5", title: "Shield Smith", detail: "Run 5 blocking sessions.", symbol: "lock.shield.fill",
                    requirement: .blockSessions(5), bonusPoints: 50, unlocksExpression: nil),
        Achievement(id: "five-hours", title: "Marathon Mind", detail: "Focus for 5 hours in total.", symbol: "figure.run",
                    requirement: .focusMinutes(300), bonusPoints: 120, unlocksExpression: nil),
        Achievement(id: "week-streak", title: "Week of Wonder", detail: "Keep a 7-day streak.", symbol: "calendar.badge.checkmark",
                    requirement: .streak(7), bonusPoints: 150, unlocksExpression: .celebrating),
        Achievement(id: "twenty-five", title: "Focus Wizard", detail: "Complete 25 focus sessions.", symbol: "wand.and.stars",
                    requirement: .sessions(25), bonusPoints: 200, unlocksExpression: nil),
        Achievement(id: "ten-hours", title: "Big Brain Energy", detail: "Focus for 10 hours in total.", symbol: "brain.head.profile",
                    requirement: .focusMinutes(600), bonusPoints: 250, unlocksExpression: nil),
    ]
}
