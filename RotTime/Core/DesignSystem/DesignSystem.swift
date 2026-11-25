import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum RTFont {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func title(_ size: CGFloat = 22) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func body(_ weight: Font.Weight = .medium) -> Font { .system(.body, design: .rounded).weight(weight) }
    static func caption(_ weight: Font.Weight = .semibold) -> Font { .system(.caption, design: .rounded).weight(weight) }
    static func label(_ weight: Font.Weight = .semibold) -> Font { .system(.subheadline, design: .rounded).weight(weight) }
}

enum RTSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let cardRadius: CGFloat = 26
}

enum Haptics {
    static func tap(_ enabled: Bool = true) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func success(_ enabled: Bool = true) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning(_ enabled: Bool = true) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func selection(_ enabled: Bool = true) {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

/// Rounded, translucent card used across the app.
struct Card<Content: View>: View {
    var padding: CGFloat = RTSpacing.l
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RTSpacing.cardRadius, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RTSpacing.cardRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(scheme == .dark ? 0.08 : 0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0.3 : 0.08), radius: 14, y: 6)
    }
}

struct SectionHeader: View {
    var title: String
    var symbol: String?
    var trailing: String?

    var body: some View {
        HStack(spacing: 6) {
            if let symbol { Image(systemName: symbol).font(.subheadline.weight(.bold)) }
            Text(title).font(RTFont.title(18))
            Spacer()
            if let trailing { Text(trailing).font(RTFont.caption()).foregroundStyle(.secondary) }
        }
    }
}

/// Springy press feedback for every tappable surface.
struct BouncyButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Big gradient call-to-action button.
struct PrimaryButton: View {
    var title: String
    var symbol: String?
    var theme: Theme
    var isDestructive = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol).font(.headline.weight(.bold)) }
                Text(title).font(RTFont.title(18))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule().fill(
                    isDestructive
                        ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFF6F7D), Color(hex: 0xE2505F)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(theme.buttonGradient)
                )
            )
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: (isDestructive ? Color(hex: 0xE2505F) : theme.accent).opacity(0.4), radius: 12, y: 6)
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

struct SecondaryButton: View {
    var title: String
    var symbol: String?
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.subheadline.weight(.bold)) }
                Text(title).font(RTFont.label(.bold))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Capsule().fill(tint.opacity(0.14)))
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

/// Small selectable pill.
struct Chip: View {
    var title: String
    var symbol: String?
    var selected: Bool
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol).font(.caption.weight(.bold)) }
                Text(title).font(RTFont.label(.bold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(selected ? .white : .primary)
            .background(Capsule().fill(selected ? AnyShapeStyle(tint) : AnyShapeStyle(Color.primary.opacity(0.07))))
        }
        .buttonStyle(BouncyButtonStyle())
        .animation(.snappy, value: selected)
    }
}

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 14
    var gradient: AngularGradient

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}

struct ProgressBar: View {
    var progress: Double
    var tint: Color
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, geo.size.width * min(1, max(0, progress))))
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
    }
}

/// Compact statistic tile.
struct StatTile: View {
    var title: String
    var value: String
    var symbol: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.15)))
            Text(value).font(RTFont.title(22)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(title).font(RTFont.caption()).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.regularMaterial))
    }
}

/// Toast-style banner for unlocks and confirmations.
struct Toast: Equatable, Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var symbol: String
}

struct ToastView: View {
    var toast: Toast
    var tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(tint))
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title).font(RTFont.label(.bold))
                Text(toast.message).font(RTFont.caption(.medium)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Capsule(style: .continuous).fill(.thickMaterial))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        .padding(.horizontal, 16)
    }
}

extension TimeInterval {
    /// "1h 05m" / "25m" / "45s"
    var shortDuration: String {
        let total = Int(self.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return "\(h)h \(String(format: "%02d", m))m" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }

    /// "24:59" clock style
    var clock: String {
        let total = max(0, Int(self.rounded(.up)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}

extension Int {
    var minutesText: String {
        if self >= 60 {
            let h = self / 60, m = self % 60
            return m == 0 ? "\(h)h" : "\(h)h \(m)m"
        }
        return "\(self)m"
    }
}
