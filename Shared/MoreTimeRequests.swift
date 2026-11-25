import Foundation
import FamilyControls
import ManagedSettings
import UserNotifications

/// The in-app experience used when someone asks for more time on a shielded app.
/// A different one is picked every time (never the same twice in a row).
public enum InterventionStyle: String, Codable, CaseIterable {
    case chat, faceTime, voiceNote, letter, breathing

    private static let lastKey = "rt.intervention.lastStyle"

    /// Picks a random style that differs from the previous one.
    public static func next() -> InterventionStyle {
        let last = AppGroup.defaults.string(forKey: lastKey).flatMap(InterventionStyle.init(rawValue:))
        let choice = allCases.filter { $0 != last }.randomElement() ?? .chat
        AppGroup.defaults.set(choice.rawValue, forKey: lastKey)
        return choice
    }

    public func notificationTitle(brain: String) -> String {
        switch self {
        case .chat: return "💬 \(brain)"
        case .faceTime: return "📞 \(brain) is calling you…"
        case .voiceNote: return "🎙️ \(brain) sent you a voice message"
        case .letter: return "✉️ \(brain) wrote you a letter"
        case .breathing: return "🫧 \(brain) wants to breathe with you"
        }
    }

    public func notificationBody(brain: String) -> String {
        switch self {
        case .chat: return "Hey… can we talk before you go back in? Tap to open."
        case .faceTime: return "Incoming call. Tap to answer."
        case .voiceNote: return "0:12 · Tap to listen."
        case .letter: return "It's short, I promise. Tap to read."
        case .breathing: return "One slow breath together, then you decide."
        }
    }
}

/// A request for more time, created by the ShieldAction extension and handled by the app.
public struct MoreTimeRequest: Codable, Identifiable, Equatable {
    public enum Kind: String, Codable { case application, webDomain, category }

    public var id: UUID
    public var kind: Kind
    public var tokenData: Data
    public var createdAt: Date
    public var style: InterventionStyle

    public init(kind: Kind, tokenData: Data, style: InterventionStyle, createdAt: Date = Date()) {
        self.id = UUID()
        self.kind = kind
        self.tokenData = tokenData
        self.style = style
        self.createdAt = createdAt
    }

    public var applicationToken: ApplicationToken? {
        kind == .application ? try? JSONDecoder().decode(ApplicationToken.self, from: tokenData) : nil
    }
    public var webDomainToken: WebDomainToken? {
        kind == .webDomain ? try? JSONDecoder().decode(WebDomainToken.self, from: tokenData) : nil
    }
    public var categoryToken: ActivityCategoryToken? {
        kind == .category ? try? JSONDecoder().decode(ActivityCategoryToken.self, from: tokenData) : nil
    }
}

public enum MoreTimeRequests {
    public static let notificationCategory = "rt.moreTime"
    /// Requests older than this are ignored.
    public static let lifetime: TimeInterval = 20 * 60

    static var all: [MoreTimeRequest] {
        get { SharedStore.load([MoreTimeRequest].self, .moreTimeRequests, default: []) }
        set {
            let cutoff = Date().addingTimeInterval(-lifetime)
            SharedStore.save(Array(newValue.filter { $0.createdAt > cutoff }.suffix(10)), .moreTimeRequests)
        }
    }

    public static var pending: [MoreTimeRequest] {
        let cutoff = Date().addingTimeInterval(-lifetime)
        return all.filter { $0.createdAt > cutoff }
    }

    public static var latest: MoreTimeRequest? { pending.max { $0.createdAt < $1.createdAt } }

    public static func resolve(_ id: UUID) {
        all = all.filter { $0.id != id }
    }

    /// Records a request for a token and notifies the user so the app can open the intervention.
    @discardableResult
    public static func create<T: Encodable>(kind: MoreTimeRequest.Kind, token: T) -> MoreTimeRequest? {
        guard let data = try? JSONEncoder().encode(token) else { return nil }
        // Replace an older request for the same thing.
        var list = all.filter { $0.tokenData != data }
        let request = MoreTimeRequest(kind: kind, tokenData: data, style: InterventionStyle.next())
        list.append(request)
        all = list
        notify(request)
        return request
    }

    static func notify(_ request: MoreTimeRequest) {
        let brain = SharedStore.brainName
        let content = UNMutableNotificationContent()
        content.title = request.style.notificationTitle(brain: brain)
        content.body = request.style.notificationBody(brain: brain)
        content.sound = .default
        content.categoryIdentifier = notificationCategory
        content.userInfo = ["requestID": request.id.uuidString]
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "rt.moreTime.\(request.id.uuidString)", content: content, trigger: nil))
    }
}

/// The mascot's "hurt" state after extra scrolling time was taken.
public enum BrainHealth {
    private static let hurtUntilKey = "rt.brain.hurtUntil"

    public static var hurtUntil: Date? {
        get { AppGroup.defaults.object(forKey: hurtUntilKey) as? Date }
        set { AppGroup.defaults.set(newValue, forKey: hurtUntilKey) }
    }

    public static var isHurt: Bool { (hurtUntil ?? .distantPast) > Date() }

    /// Called whenever extra time is granted: hurts during the extra time and for a while after.
    public static func hurt(forMinutes minutes: Int) {
        let until = Date().addingTimeInterval(TimeInterval(minutes * 60 + 45 * 60))
        hurtUntil = max(hurtUntil ?? .distantPast, until)
    }

    /// A completed focus session heals the brain.
    public static func heal() { hurtUntil = nil }
}
