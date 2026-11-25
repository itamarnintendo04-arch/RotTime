import SwiftUI

/// The animated mascot. Expression changes blend over ~0.3 s and are masked by a blink,
/// so every transition feels alive.
struct BrainCharacterView: View {
    var expression: BrainExpression
    var appearance: BrainAppearance
    var size: CGFloat = 220
    var animated: Bool = true
    var showDecor: Bool = true

    @State private var shown: BrainExpression
    @State private var previous: BrainExpression
    @State private var changedAt: Date = .distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(expression: BrainExpression, appearance: BrainAppearance, size: CGFloat = 220,
         animated: Bool = true, showDecor: Bool = true) {
        self.expression = expression
        self.appearance = appearance
        self.size = size
        self.animated = animated
        self.showDecor = showDecor
        _shown = State(initialValue: expression)
        _previous = State(initialValue: expression)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !animated || reduceMotion)) { timeline in
            Canvas { context, canvasSize in
                let now = timeline.date
                let progress = min(1, max(0, now.timeIntervalSince(changedAt) / 0.32))
                let eased = CGFloat(progress < 0.5 ? 2 * progress * progress : 1 - pow(-2 * progress + 2, 2) / 2)
                let face = FaceParams.lerp(previous.face(style: appearance.style), shown.face(style: appearance.style), eased)
                BrainRenderer.draw(in: &context, size: canvasSize,
                                   time: animated && !reduceMotion ? now.timeIntervalSinceReferenceDate : 0.8,
                                   expression: shown, face: face, transition: progress,
                                   appearance: appearance, showDecor: showDecor)
            }
        }
        .frame(width: size, height: size)
        .onChange(of: expression) { _, newValue in
            guard newValue != shown else { return }
            previous = shown
            shown = newValue
            changedAt = Date()
        }
        .accessibilityElement()
        .accessibilityLabel("\(SharedStore.brainName), your brain buddy, looking \(expression.title.lowercased())")
    }
}

/// Mascot plus tap-to-poke interaction and an optional speech bubble.
struct InteractiveBrain: View {
    var expression: BrainExpression
    var appearance: BrainAppearance
    var size: CGFloat
    var speech: String?
    var onPoke: (() -> Void)?

    @State private var pokeExpression: BrainExpression?
    @State private var squish = false
    @EnvironmentObject private var app: AppState

    private let pokeReactions: [BrainExpression] = [.surprised, .happy, .wink, .love]

    var body: some View {
        VStack(spacing: 6) {
            if let speech {
                SpeechBubble(text: speech)
                    .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
                    .id(speech)
            }
            BrainCharacterView(expression: pokeExpression ?? expression, appearance: appearance, size: size)
                .scaleEffect(x: squish ? 1.08 : 1, y: squish ? 0.92 : 1, anchor: .bottom)
                .contentShape(Rectangle())
                .onTapGesture { poke() }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: speech)
    }

    private func poke() {
        Haptics.tap(app.profile.hapticsEnabled)
        withAnimation(.spring(response: 0.18, dampingFraction: 0.4)) { squish = true }
        pokeExpression = pokeReactions.randomElement()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { squish = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { pokeExpression = nil }
        onPoke?()
    }
}

struct SpeechBubble: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color(hex: 0x2B1F3A))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                BubbleShape()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            )
            .padding(.bottom, 8)
            .frame(maxWidth: 280)
    }
}

struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var body = Path(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height), cornerRadius: 18)
        var tail = Path()
        tail.move(to: CGPoint(x: rect.midX - 9, y: rect.maxY - 1))
        tail.addQuadCurve(to: CGPoint(x: rect.midX + 2, y: rect.maxY + 9), control: CGPoint(x: rect.midX - 2, y: rect.maxY + 4))
        tail.addQuadCurve(to: CGPoint(x: rect.midX + 9, y: rect.maxY - 1), control: CGPoint(x: rect.midX + 4, y: rect.maxY + 2))
        tail.closeSubpath()
        body.addPath(tail)
        return body
    }
}
