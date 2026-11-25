import Foundation
import UIKit
import ManagedSettings

/// Copy shown on the Screen Time shield. Friendly, never shaming.
public enum ShieldCopy {
    public static let titles = [
        "Hey, it's %@ again!",
        "Psst… %@ here.",
        "%@ is guarding this one",
        "A tiny pause from %@",
        "%@ saved your spot",
    ]

    public static let reflections = [
        "What were you hoping to find in %@?",
        "Is %@ what you need right now, or just what's nearby?",
        "Take one breath. Does opening %@ match your plan?",
        "Your future self says hi. Still want %@?",
        "Quick check-in: bored, tired, or curious?",
        "You set this shield for a reason. Want to honour it?",
        "Stretch, sip some water, then decide about %@.",
    ]

    public static let breathing = [
        "Breathe in for 4… hold… out for 6. Tap “I'm ready” once %d seconds have passed.",
        "Roll your shoulders and look at something far away. In %d seconds you can choose again.",
    ]

    /// Deterministic per-minute rotation so the copy changes but doesn't flicker.
    public static func pick(_ list: [String], salt: Int = 0) -> String {
        let minute = Int(Date().timeIntervalSince1970 / 60)
        return list[abs(minute &+ salt) % list.count]
    }
}

/// Colours for the shield, matching the theme chosen in the app.
public struct ShieldPalette {
    public var background: UIColor
    public var title: UIColor
    public var subtitle: UIColor
    public var button: UIColor
    public var buttonText: UIColor
    public var secondaryText: UIColor

    public static func forTheme(_ id: String) -> ShieldPalette {
        func hex(_ v: UInt32) -> UIColor {
            UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                    blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        }
        let (bg, accent): (UInt32, UInt32) = {
            switch id {
            case "space": return (0x14123A, 0x9B8CFF)
            case "ocean": return (0x0B3A5B, 0x46D3E6)
            case "forest": return (0x163B2C, 0x7EDC8A)
            case "candy": return (0xFFE3F1, 0xFF5FA8)
            case "neon": return (0x120A2A, 0xFF3DC8)
            case "dream": return (0x2B2557, 0xC7A6FF)
            case "sunset": return (0x4A1F3D, 0xFF9A5C)
            case "winter": return (0xE7F1FA, 0x4A90E2)
            case "minimal": return (0xF4F2EE, 0x2E2A26)
            default: return (0x3B2A2F, 0xFFB36B) // cozy
            }
        }()
        let lightBackground = ["candy", "winter", "minimal"].contains(id)
        return ShieldPalette(
            background: hex(bg),
            title: lightBackground ? hex(0x231A2E) : .white,
            subtitle: lightBackground ? hex(0x4C4458) : UIColor.white.withAlphaComponent(0.82),
            button: hex(accent),
            buttonText: lightBackground && id != "minimal" ? .white : (id == "minimal" ? .white : hex(0x1B1324)),
            secondaryText: lightBackground ? hex(accent) : .white
        )
    }
}

/// State for the two-tap "mindful pause" flow on the shield:
/// first tap starts a short waiting period, a second tap after it has passed unlocks.
public enum MindfulPause {
    public static func key<T: Encodable>(for token: T) -> String {
        guard let data = try? JSONEncoder().encode(token) else { return "unknown" }
        return data.base64EncodedString()
    }

    static var pending: [String: Date] {
        get { SharedStore.load([String: Date].self, .pendingPauses, default: [:]) }
        set {
            // Forget pauses older than ten minutes.
            let cutoff = Date().addingTimeInterval(-600)
            SharedStore.save(newValue.filter { $0.value > cutoff }, .pendingPauses)
        }
    }

    public static func startedAt(for key: String) -> Date? {
        guard let date = pending[key], Date().timeIntervalSince(date) < 600 else { return nil }
        return date
    }

    public static func begin(for key: String) {
        var all = pending
        all[key] = Date()
        pending = all
    }

    public static func clear(for key: String) {
        var all = pending
        all.removeValue(forKey: key)
        pending = all
    }

    public static func secondsRemaining(for key: String, settings: MindfulUnlockSettings) -> Int? {
        guard let start = startedAt(for: key) else { return nil }
        let remaining = Double(settings.waitSeconds) - Date().timeIntervalSince(start)
        return max(0, Int(remaining.rounded(.up)))
    }
}
