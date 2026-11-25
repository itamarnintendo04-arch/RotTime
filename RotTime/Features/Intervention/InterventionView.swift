import FamilyControls
import ManagedSettings
import SwiftUI

/// Full-screen "do you really want more time?" experience. The style changes every time.
struct InterventionView: View {
    let session: InterventionSession
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var center: InterventionCenter
    @StateObject private var speaker = Speaker.shared
    @State private var phase: InterventionPhase = .intro
    @State private var hurtCycle = 0

    private var expression: BrainExpression {
        switch phase {
        case .intro: return session.style == .breathing ? .idle : .surprised
        case .ask: return .sad
        case .choose: return .tired
        case .granted: return [.sick, .hurt, .sad][hurtCycle % 3]
        case .declined: return .celebrating
        }
    }

    /// What the brain is currently saying.
    private var line: String {
        switch phase {
        case .intro: return session.greeting
        case .ask: return session.ask
        case .choose: return session.chooseIntro
        case .granted(let m): return session.grantedLine(m)
        case .declined: return session.declineLine
        }
    }

    var body: some View {
        ZStack {
            switch session.style {
            case .chat: ChatInterventionStage(session: session, phase: phase, expression: expression, line: line)
            case .faceTime: FaceTimeStage(session: session, phase: $phase, expression: expression, line: line, onDecline: decline)
            case .voiceNote: VoiceNoteStage(session: session, phase: phase, expression: expression, line: line)
            case .letter: LetterStage(session: session, phase: phase, expression: expression, line: line)
            case .breathing: BreathingStage(session: session, phase: phase, expression: expression, line: line) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { phase = .ask }
            }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !(session.style == .faceTime && phase == .intro) {
                DecisionPanel(session: session, phase: phase,
                              onContinue: { advance(to: .ask) },
                              onYes: { advance(to: .choose) },
                              onChoose: choose,
                              onDecline: decline,
                              onTakeBack: {
                                  center.takeBack(session)
                                  advance(to: .declined)
                              },
                              onDone: { center.finish() })
                .padding(.horizontal, RTSpacing.l)
                .padding(.bottom, RTSpacing.s)
            }
        }
        .onChange(of: phase) { _, newPhase in
            if [.faceTime, .voiceNote].contains(session.style), newPhase != .intro { speaker.say(line) }
        }
        .task(id: phase) {
            // Cycle sick → hurt → sad after extra time was taken.
            guard case .granted = phase else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                withAnimation { hurtCycle += 1 }
            }
        }
        .onDisappear { speaker.stop() }
        .interactiveDismissDisabled()
    }

    private func advance(to next: InterventionPhase) {
        Haptics.tap(app.profile.hapticsEnabled)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { phase = next }
    }

    private func choose(_ minutes: Int) {
        center.grant(session, minutes: minutes)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { phase = .granted(minutes) }
    }

    private func decline() {
        center.decline(session)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { phase = .declined }
    }
}

// MARK: - Decision buttons (shared by every style)

struct DecisionPanel: View {
    let session: InterventionSession
    let phase: InterventionPhase
    var onContinue: () -> Void
    var onYes: () -> Void
    var onChoose: (Int) -> Void
    var onDecline: () -> Void
    var onTakeBack: () -> Void
    var onDone: () -> Void
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 10) {
            switch phase {
            case .intro:
                if session.style != .breathing {
                    PrimaryButton(title: continueTitle, symbol: "arrow.right", theme: app.theme, action: onContinue)
                }
                declineButton
            case .ask:
                declineButton
                Button(action: onYes) {
                    Text("Yes, I want more time")
                        .font(RTFont.label(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(.thinMaterial))
                }
                .buttonStyle(BouncyButtonStyle())
            case .choose:
                ForEach(InterventionCenter.durations, id: \.self) { m in
                    Button { onChoose(m) } label: {
                        HStack(spacing: 10) {
                            Text(m == 30 ? "½ hour" : "\(m) min")
                                .font(RTFont.title(17))
                                .frame(width: 70, alignment: .leading)
                            Text(InterventionCopy.durationLine(m))
                                .font(RTFont.caption(.medium))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.thinMaterial))
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .foregroundStyle(.primary)
                }
                declineButton
            case .granted(let minutes):
                if !session.isPreview {
                    Text("Unlocked for \(minutes) minutes — you can go back to it now.")
                        .font(RTFont.caption(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                PrimaryButton(title: "I changed my mind — block it again", symbol: "heart.fill", theme: app.theme, action: onTakeBack)
                Button("Okay…", action: onDone)
                    .font(RTFont.label(.semibold))
                    .padding(.vertical, 8)
            case .declined:
                PrimaryButton(title: session.isPreview ? "Close preview" : "Back to my day", symbol: "sparkles", theme: app.theme, action: onDone)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.ultraThinMaterial))
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: phase)
    }

    private var continueTitle: String {
        switch session.style {
        case .chat: return "Reply"
        case .voiceNote: return "Play message"
        case .letter: return "Open the letter"
        default: return "Continue"
        }
    }

    private var declineButton: some View {
        PrimaryButton(title: session.declineLabel, symbol: "hand.raised.fill", theme: app.theme, action: onDecline)
    }
}

// MARK: - Shared bits

/// Shows the app / site / category the request is about using Apple's private labels.
struct RequestTargetLabel: View {
    let request: MoreTimeRequest?

    var body: some View {
        Group {
            if let token = request?.applicationToken {
                Label(token)
            } else if let token = request?.webDomainToken {
                Label(token)
            } else if let token = request?.categoryToken {
                Label(token)
            } else {
                Label("Preview", systemImage: "eye")
            }
        }
        .font(RTFont.label(.bold))
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(.thinMaterial))
    }
}

// MARK: - 1. Chat

struct ChatInterventionStage: View {
    let session: InterventionSession
    let phase: InterventionPhase
    let expression: BrainExpression
    let line: String
    @EnvironmentObject private var app: AppState
    @State private var transcript: [(id: UUID, fromBrain: Bool, text: String)] = []
    @State private var typing = false

    var body: some View {
        ZStack {
            ThemeBackgroundView(theme: app.theme, animated: false)
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    BrainCharacterView(expression: expression, appearance: app.appearance, size: 56, showDecor: false)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.brainName).font(RTFont.title(18))
                        Text(typing ? "typing…" : "wants to talk").font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    RequestTargetLabel(request: session.request)
                }
                .padding(.horizontal, RTSpacing.l).padding(.vertical, 8)
                .background(.bar)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(transcript, id: \.id) { msg in
                                HStack {
                                    if !msg.fromBrain { Spacer(minLength: 60) }
                                    Text(LocalizedStringKey(msg.text))
                                        .font(RTFont.body())
                                        .foregroundStyle(msg.fromBrain ? Color.primary : .white)
                                        .padding(.horizontal, 15).padding(.vertical, 10)
                                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(msg.fromBrain ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(app.theme.buttonGradient)))
                                    if msg.fromBrain { Spacer(minLength: 60) }
                                }
                                .id(msg.id)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                            if typing {
                                TypingIndicator(tint: app.theme.accent).frame(maxWidth: .infinity, alignment: .leading).id("typing")
                            }
                            BrainCharacterView(expression: expression, appearance: app.appearance, size: 170)
                                .padding(.top, 10)
                                .id("brain")
                        }
                        .padding(RTSpacing.l)
                    }
                    .onChange(of: transcript.count) { _, _ in withAnimation { proxy.scrollTo("brain", anchor: .bottom) } }
                }
            }
        }
        .task { await brainSays(line) }
        .onChange(of: phase) { _, newPhase in
            Task {
                if let reply = userReply(for: newPhase) { add(false, reply) }
                await brainSays(line)
            }
        }
    }

    private func userReply(for phase: InterventionPhase) -> String? {
        switch phase {
        case .intro: return nil
        case .ask: return "Hey… what's up?"
        case .choose: return "Yes, I want more time."
        case .granted(let m): return m == 30 ? "Half an hour." : "\(m) minutes."
        case .declined: return session.declineLabel + "."
        }
    }

    @MainActor
    private func brainSays(_ text: String) async {
        withAnimation { typing = true }
        try? await Task.sleep(nanoseconds: UInt64(min(1.6, 0.5 + Double(text.count) * 0.02) * 1_000_000_000))
        withAnimation { typing = false }
        add(true, text)
    }

    private func add(_ fromBrain: Bool, _ text: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { transcript.append((UUID(), fromBrain, text)) }
    }
}

// MARK: - 2. Pretend FaceTime call

struct FaceTimeStage: View {
    let session: InterventionSession
    @Binding var phase: InterventionPhase
    let expression: BrainExpression
    let line: String
    var onDecline: () -> Void
    @EnvironmentObject private var app: AppState
    @StateObject private var speaker = Speaker.shared
    @State private var callStart = Date()
    @State private var ring = false

    var body: some View {
        ZStack {
            ThemeBackgroundView(theme: app.theme, animated: true)
            if phase == .intro { incoming } else { inCall }
        }
        .background(Color.black)
    }

    private var incoming: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer().frame(height: 40)
                BrainCharacterView(expression: .surprised, appearance: app.appearance, size: 150, showDecor: false)
                    .background(Circle().fill(.white.opacity(0.12)).frame(width: 170, height: 170))
                    .scaleEffect(ring ? 1.06 : 0.96)
                Text(app.brainName).font(.system(size: 34, weight: .semibold))
                Text("FaceTime Video…").font(.title3).foregroundStyle(.white.opacity(0.7))
                RequestTargetLabel(request: session.request).environment(\.colorScheme, .dark)
                Spacer()
                HStack {
                    callButton(symbol: "phone.down.fill", color: .red, title: "Decline", action: onDecline)
                    Spacer()
                    callButton(symbol: "video.fill", color: .green, title: "Accept") {
                        Haptics.tap(app.profile.hapticsEnabled)
                        callStart = Date()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { phase = .ask }
                    }
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 50)
            }
            .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { ring = true }
            Haptics.warning(app.profile.hapticsEnabled)
        }
    }

    private func callButton(symbol: String, color: Color, title: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(Circle().fill(color))
            }
            .buttonStyle(BouncyButtonStyle())
            Text(title).font(.footnote)
        }
    }

    private var inCall: some View {
        ZStack(alignment: .top) {
            BrainCharacterView(expression: speaker.isSpeaking && expression == .sad ? .thinking : expression,
                               appearance: app.appearance, size: 380)
                .offset(y: -40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.brainName).font(.headline)
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            Text(ctx.date.timeIntervalSince(callStart).clock).font(.subheadline).monospacedDigit().opacity(0.8)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.35)))
                    Spacer()
                    // Pretend self-view
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [Color(hex: 0x3A3355), Color(hex: 0x1D1A2B)], startPoint: .top, endPoint: .bottom))
                        Image(systemName: "person.fill").font(.system(size: 40)).foregroundStyle(.white.opacity(0.5))
                        Text("You").font(.caption2.weight(.bold)).foregroundStyle(.white.opacity(0.7))
                            .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 6)
                    }
                    .frame(width: 92, height: 130)
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.3)))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, RTSpacing.l)
                Spacer()
                Text(LocalizedStringKey(line))
                    .font(RTFont.title(19))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18).fill(.black.opacity(0.45)))
                    .padding(.horizontal, RTSpacing.xl)
                    .id(line)
                    .transition(.opacity)
                HStack(spacing: 22) {
                    Button { speaker.muted.toggle(); if speaker.muted { speaker.stop() } } label: {
                        Image(systemName: speaker.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .frame(width: 52, height: 52).background(Circle().fill(.white.opacity(0.2)))
                    }
                    Button { } label: {
                        Image(systemName: "video.fill").frame(width: 52, height: 52).background(Circle().fill(.white.opacity(0.2)))
                    }
                    Button(action: onDecline) {
                        Image(systemName: "phone.down.fill").frame(width: 52, height: 52).background(Circle().fill(.red))
                    }
                    .disabled(phase != .ask && phase != .choose)
                }
                .font(.title3)
                .foregroundStyle(.white)
                .padding(.vertical, 12)
            }
            .padding(.top, 8)
        }
        .onAppear { speaker.say(line) }
    }
}

// MARK: - 3. Voice message

struct VoiceNoteStage: View {
    let session: InterventionSession
    let phase: InterventionPhase
    let expression: BrainExpression
    let line: String
    @EnvironmentObject private var app: AppState
    @StateObject private var speaker = Speaker.shared

    var body: some View {
        ZStack {
            ThemeBackgroundView(theme: app.theme, animated: false)
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: RTSpacing.l) {
                HStack {
                    Label("Voice message", systemImage: "waveform").font(RTFont.label(.bold))
                    Spacer()
                    RequestTargetLabel(request: session.request)
                }
                .padding(.horizontal, RTSpacing.l)
                .padding(.top, RTSpacing.s)
                BrainCharacterView(expression: expression, appearance: app.appearance, size: 220)
                HStack(spacing: 14) {
                    Button { speaker.isSpeaking ? speaker.stop() : speaker.say(line) } label: {
                        Image(systemName: speaker.isSpeaking ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(app.theme.buttonGradient))
                    }
                    Waveform(active: speaker.isSpeaking, tint: app.theme.accent)
                        .frame(height: 40)
                    Text("0:\(String(format: "%02d", min(59, 3 + line.count / 12)))").font(RTFont.caption(.bold)).monospacedDigit().foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Capsule().fill(.regularMaterial))
                .padding(.horizontal, RTSpacing.l)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transcript").font(RTFont.caption(.bold)).foregroundStyle(.secondary)
                    Text(LocalizedStringKey(line)).font(RTFont.body(.semibold)).id(line).transition(.opacity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20).fill(.regularMaterial))
                .padding(.horizontal, RTSpacing.l)
                Spacer()
            }
        }
        .onAppear { speaker.say(line) }
    }
}

struct Waveform: View {
    var active: Bool
    var tint: Color
    var body: some View {
        TimelineView(.animation(paused: !active)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<28, id: \.self) { i in
                    let base = 0.25 + 0.35 * abs(sin(Double(i) * 1.7))
                    let wave = active ? 0.4 * abs(sin(t * 7 + Double(i) * 0.6)) : 0
                    Capsule().fill(tint.opacity(0.85))
                        .frame(width: 3, height: 40 * min(1, base + wave))
                }
            }
        }
    }
}

// MARK: - 4. Letter

struct LetterStage: View {
    let session: InterventionSession
    let phase: InterventionPhase
    let expression: BrainExpression
    let line: String
    @EnvironmentObject private var app: AppState

    private var opened: Bool { phase != .intro }

    var body: some View {
        ZStack {
            ThemeBackgroundView(theme: app.theme, animated: true)
            VStack(spacing: RTSpacing.l) {
                RequestTargetLabel(request: session.request).padding(.top, RTSpacing.s)
                if opened {
                    paper.transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    envelope.transition(.scale.combined(with: .opacity))
                }
                Spacer()
            }
            .padding(.horizontal, RTSpacing.l)
        }
    }

    private var envelope: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xFFF4E3))
                .frame(height: 210)
                .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
            EnvelopeFlap().fill(Color(hex: 0xF7E1C0)).frame(height: 210)
            Image(systemName: "heart.fill").font(.system(size: 34)).foregroundStyle(Color(hex: 0xFF5F8F)).offset(y: 6)
            Text("For you, from \(app.brainName)").font(.custom("Noteworthy-Bold", size: 18)).foregroundStyle(Color(hex: 0x6B4A3A))
                .offset(y: 70)
        }
        .padding(.top, 60)
    }

    private var paper: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(app.profile.userName.isEmpty ? "Dear you," : "Dear \(app.profile.userName),")
                .font(.custom("Noteworthy-Bold", size: 22))
            Text(LocalizedStringKey(line))
                .font(.custom("Noteworthy-Light", size: 21))
                .fixedSize(horizontal: false, vertical: true)
                .id(line)
                .transition(.opacity)
            HStack(alignment: .bottom) {
                Text("Love,\n\(app.brainName) 🧠").font(.custom("Noteworthy-Bold", size: 19))
                Spacer()
                BrainCharacterView(expression: expression, appearance: app.appearance, size: 110, showDecor: false)
            }
            if case .granted = phase {
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().fill(Color(hex: 0x7CC8FF).opacity(0.25)).frame(width: CGFloat(14 + i * 6))
                    }
                    Text("(sorry about the tear stains)").font(.custom("Noteworthy-Light", size: 14)).foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(Color(hex: 0x3B2A2F))
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: 0xFFFDF6))
                .overlay(
                    VStack(spacing: 26) { ForEach(0..<14, id: \.self) { _ in Rectangle().fill(Color(hex: 0xBFD9F2).opacity(0.5)).frame(height: 1) } }
                        .padding(.top, 60), alignment: .top)
                .clipped()
                .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
        )
        .rotationEffect(.degrees(-1.2))
        .padding(.top, 10)
    }
}

struct EnvelopeFlap: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.midY + 10))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - 5. Breathing

struct BreathingStage: View {
    let session: InterventionSession
    let phase: InterventionPhase
    let expression: BrainExpression
    let line: String
    var onBreathDone: () -> Void
    @EnvironmentObject private var app: AppState
    @State private var expanded = false
    @State private var label = "Breathe in…"
    @State private var breaths = 0

    var body: some View {
        ZStack {
            ThemeBackgroundView(theme: app.theme, animated: true)
            VStack(spacing: RTSpacing.l) {
                RequestTargetLabel(request: session.request).padding(.top, RTSpacing.s)
                Spacer()
                ZStack {
                    Circle().fill(app.theme.accent.opacity(0.18)).frame(width: expanded ? 330 : 190)
                    Circle().fill(app.theme.accent.opacity(0.25)).frame(width: expanded ? 270 : 160)
                    BrainCharacterView(expression: phase == .intro ? (expanded ? .idle : .sleeping) : expression,
                                       appearance: app.appearance, size: 200, showDecor: false)
                }
                .frame(height: 340)
                Text(LocalizedStringKey(phase == .intro ? label : line))
                    .font(RTFont.title(22))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(app.theme.onBackground)
                    .padding(.horizontal, RTSpacing.xl)
                    .id(phase == .intro ? label : line)
                    .transition(.opacity)
                if phase == .intro {
                    Text("Breath \(min(breaths + 1, 2)) of 2").font(RTFont.caption(.bold)).foregroundStyle(app.theme.onBackground.opacity(0.7))
                }
                Spacer()
            }
        }
        .task {
            for i in 0..<2 {
                breaths = i
                withAnimation(.easeInOut(duration: 0.4)) { label = "Breathe in…" }
                withAnimation(.easeInOut(duration: 4)) { expanded = true }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation(.easeInOut(duration: 0.4)) { label = "…and out." }
                withAnimation(.easeInOut(duration: 5)) { expanded = false }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
            if phase == .intro { onBreathDone() }
        }
    }
}
