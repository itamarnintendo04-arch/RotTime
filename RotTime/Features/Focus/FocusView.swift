import FamilyControls
import SwiftUI

struct FocusView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var focus: FocusTimerModel
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @State private var customMinutes: Double = 30
    @State private var showCustom = false
    @State private var editingFocusMode: BlockMode?
    @State private var confirmStop = false

    private let presets: [(String, Int, String)] = [("Pomodoro", 25, "leaf.fill"), ("Deep", 50, "brain.head.profile"), ("Sprint", 15, "hare.fill")]

    var body: some View {
        ZStack {
            ThemeBackgroundView(theme: app.theme, animated: app.profile.ambientAnimations)
            ScrollView(showsIndicators: false) {
                VStack(spacing: RTSpacing.l) {
                    HStack {
                        Text("Focus").font(RTFont.display(32)).foregroundStyle(app.theme.onBackground)
                        Spacer()
                    }
                    .padding(.top, RTSpacing.s)

                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        timerFace(now: ctx.date)
                            .onChange(of: ctx.date) { _, date in focus.tick(date) }
                    }

                    controls

                    if focus.isIdle {
                        presetCard
                        breakCard
                    }
                    optionsCard
                    todayCard
                }
                .padding(.horizontal, RTSpacing.l)
                .padding(.bottom, MainTabView.tabBarClearance)
            }
        }
        .sheet(item: $editingFocusMode) { mode in
            ModeEditorView(mode: mode)
        }
        .confirmationDialog("End this session early?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("End session", role: .destructive) { focus.stop() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("The minutes you've already focused still count.")
        }
    }

    // MARK: Timer face

    private var faceExpression: BrainExpression {
        if focus.isPaused { return .thinking }
        switch focus.phase {
        case .focus: return .focused
        case .rest: return .sleeping
        case nil: return .idle
        }
    }

    private func timerFace(now: Date) -> some View {
        let remaining = focus.remaining(at: now)
        let countingUp = (focus.isIdle && focus.openEnded) || (focus.isOpenEnded && focus.phase == .focus)
        let shown: TimeInterval = focus.isIdle ? (focus.openEnded ? 0 : TimeInterval(focus.focusMinutes * 60))
            : (countingUp ? focus.elapsed(at: now) : remaining)
        let best = app.longestFocusSeconds
        let label: String = {
            if focus.isPaused { return "Paused" }
            switch focus.phase {
            case .focus where focus.isOpenEnded:
                return best > 0 && focus.elapsed(at: now) > best ? "New record! Keep going 🔥" : "Focusing as long as you can"
            case .focus: return "Focusing"
            case .rest: return "Break time"
            case nil: return "Ready when you are"
            }
        }()
        return VStack(spacing: RTSpacing.m) {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                ProgressRing(progress: focus.progress(at: now), lineWidth: 16, gradient: app.theme.ringGradient)
                    .padding(8)
                BrainCharacterView(expression: faceExpression, appearance: app.appearance, size: 190, showDecor: false)
                    .offset(y: -10)
            }
            .frame(width: 290, height: 290)

            Text(shown.clock)
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: !countingUp))
                .foregroundStyle(app.theme.onBackground)
                .animation(.snappy, value: Int(shown))
            if countingUp && best > 0 {
                Label("Your record: \(best.shortDuration)", systemImage: "trophy.fill")
                    .font(RTFont.caption(.bold))
                    .foregroundStyle(app.theme.onBackground.opacity(0.85))
            }
            Text(label)
                .font(RTFont.label(.bold))
                .foregroundStyle(app.theme.onBackground.opacity(0.8))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Capsule().fill(.ultraThinMaterial))
        }
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        if focus.isIdle {
            PrimaryButton(title: focus.openEnded ? "Start — as long as I can" : "Start \(focus.focusMinutes)-min focus",
                          symbol: focus.openEnded ? "infinity" : "play.fill", theme: app.theme) {
                focus.startFocus()
            }
        } else {
            if focus.isOpenEnded && focus.phase == .focus {
                PrimaryButton(title: "I'm done", symbol: "flag.checkered", theme: app.theme) { focus.stop() }
            }
            HStack(spacing: RTSpacing.m) {
                if focus.isPaused {
                    PrimaryButton(title: "Resume", symbol: "play.fill", theme: app.theme) { focus.resume() }
                } else if focus.canPause {
                    PrimaryButton(title: "Pause", symbol: "pause.fill", theme: app.theme) { focus.pause() }
                }
                if focus.phase == .rest {
                    SecondaryButton(title: "Skip break", symbol: "forward.fill", tint: app.theme.accent) { focus.stop() }
                } else if (focus.canPause || focus.isPaused) && !focus.isOpenEnded {
                    SecondaryButton(title: "End", symbol: "stop.fill", tint: Color(hex: 0xE2505F)) { confirmStop = true }
                }
            }
            if focus.phase == .focus && !focus.canPause && !focus.isPaused {
                Label("Strict session: shields stay up until the timer ends.", systemImage: "lock.fill")
                    .font(RTFont.caption(.semibold))
                    .foregroundStyle(app.theme.onBackground.opacity(0.85))
            }
        }
    }

    // MARK: Presets

    private var presetCard: some View {
        Card {
            SectionHeader(title: "Session length", symbol: "timer")
            HStack(spacing: 8) {
                ForEach(presets, id: \.1) { preset in
                    Chip(title: "\(preset.0) \(preset.1)", symbol: preset.2, selected: focus.focusMinutes == preset.1 && !showCustom && !focus.openEnded, tint: app.theme.accent) {
                        showCustom = false
                        focus.openEnded = false
                        focus.focusMinutes = preset.1
                        if preset.1 == 50 { focus.breakMinutes = 10 } else if preset.1 == 25 { focus.breakMinutes = 5 }
                        Haptics.selection(app.profile.hapticsEnabled)
                    }
                }
            }
            .padding(.top, RTSpacing.s)
            HStack(spacing: 8) {
                Chip(title: showCustom ? "Custom: \(Int(customMinutes)) min" : "Custom", symbol: "slider.horizontal.3",
                     selected: !focus.openEnded && (showCustom || ![15, 25, 50].contains(focus.focusMinutes)), tint: app.theme.accent) {
                    focus.openEnded = false
                    withAnimation(.snappy) { showCustom.toggle() }
                    customMinutes = Double(focus.focusMinutes)
                }
                Chip(title: "As long as I can", symbol: "infinity", selected: focus.openEnded, tint: app.theme.accent) {
                    showCustom = false
                    focus.openEnded = true
                    Haptics.selection(app.profile.hapticsEnabled)
                }
            }
            .padding(.top, 8)
            if focus.openEnded {
                Text("No timer — focus until you tap “I'm done”. Try to beat your record\(app.longestFocusSeconds > 0 ? " of \(app.longestFocusSeconds.shortDuration)" : "")!")
                    .font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            if showCustom {
                VStack(alignment: .leading) {
                    Slider(value: $customMinutes, in: 5...180, step: 5) { Text("Minutes") }
                        .onChange(of: customMinutes) { _, v in focus.focusMinutes = Int(v) }
                    Text("\(Int(customMinutes).minutesText) of focus").font(RTFont.caption()).foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var breakCard: some View {
        Card {
            SectionHeader(title: "Break", symbol: "cup.and.saucer.fill")
            HStack(spacing: 8) {
                ForEach([0, 5, 10, 15], id: \.self) { m in
                    Chip(title: m == 0 ? "None" : "\(m) min", symbol: nil, selected: focus.breakMinutes == m, tint: app.theme.accent) {
                        focus.breakMinutes = m
                        Haptics.selection(app.profile.hapticsEnabled)
                    }
                }
            }
            .padding(.top, RTSpacing.s)
            if focus.isIdle && focus.breakMinutes > 0 {
                Button {
                    focus.startBreak()
                } label: {
                    Label("Start a \(focus.breakMinutes)-minute break now", systemImage: "play.circle.fill").font(RTFont.label(.semibold))
                }
                .padding(.top, 10)
            }
        }
    }

    // MARK: Options

    private var optionsCard: some View {
        Card {
            SectionHeader(title: "Session options", symbol: "gearshape.2.fill")
            VStack(spacing: 12) {
                Toggle(isOn: $focus.blockApps) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shield apps while focusing").font(RTFont.label(.semibold))
                        Text(blockSubtitle).font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                    }
                }
                .disabled(!focus.isIdle)
                if let mode = screenTime.mode(.focus) {
                    Button {
                        editingFocusMode = mode
                    } label: {
                        Label(mode.hasSelection ? "Edit focus block list" : "Choose apps to shield", systemImage: "app.badge.checkmark")
                            .font(RTFont.label(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                Toggle(isOn: $focus.strict) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Strict session").font(RTFont.label(.semibold))
                        Text(focus.openEnded ? "Not available for open-ended focus." : "No pausing and no extra time while shielded.")
                            .font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                    }
                }
                .disabled(!focus.isIdle || focus.openEnded)
                Toggle(isOn: $focus.autoStartBreak) {
                    Text("Start break automatically").font(RTFont.label(.semibold))
                }
            }
            .padding(.top, RTSpacing.s)
            .tint(app.theme.accent)
        }
    }

    private var blockSubtitle: String {
        if app.isFreeMode { return "Free mode: turn on an iOS Focus or Downtime for real blocking." }
        if !screenTime.isAuthorized { return "Connect Screen Time in the Shields tab first." }
        guard let mode = screenTime.mode(.focus), mode.hasSelection else { return "No apps chosen yet." }
        return "\(mode.selectionCount) item\(mode.selectionCount == 1 ? "" : "s") from your Focus Mode list."
    }

    private var todayCard: some View {
        HStack(spacing: 12) {
            StatTile(title: "Focused today", value: app.todayFocusMinutes.minutesText, symbol: "clock.fill", tint: app.theme.accent)
            StatTile(title: "Sessions", value: "\(app.today.focusSessions)", symbol: "checkmark.seal.fill", tint: Color(hex: 0x3BAA66))
            StatTile(title: "Breaks", value: "\(app.today.breaks)", symbol: "cup.and.saucer.fill", tint: Color(hex: 0xFF8A5C))
        }
    }
}

/// Full-screen celebration after a completed focus session.
struct CelebrationView: View {
    var completion: FocusTimerModel.Completion
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var focus: FocusTimerModel
    @Environment(\.dismiss) private var dismiss
    @State private var pop = false

    var body: some View {
        ZStack {
            ThemeBackgroundView(theme: app.theme)
            Color.black.opacity(0.15).ignoresSafeArea()
            VStack(spacing: RTSpacing.l) {
                Spacer()
                BrainCharacterView(expression: .celebrating, appearance: app.appearance, size: 280)
                    .scaleEffect(pop ? 1 : 0.4)
                Text("Session complete!")
                    .font(RTFont.display(34))
                    .foregroundStyle(app.theme.onBackground)
                Text(completion.newRecord ? "\(completion.minutes) minutes — your longest focus ever! 🏆" : "\(completion.minutes) minutes of real focus. \(app.brainName) is so proud of you.")
                    .font(RTFont.body())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(app.theme.onBackground.opacity(0.85))
                    .padding(.horizontal, 30)
                HStack(spacing: 10) {
                    Label("+\(completion.points) spark points", systemImage: "sparkles")
                    Label("\(app.currentStreak) day streak", systemImage: "flame.fill")
                }
                .font(RTFont.label(.bold))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Capsule().fill(.thinMaterial))
                Spacer()
                VStack(spacing: 10) {
                    PrimaryButton(title: focus.phase == .rest ? "Enjoy your break" : "Done", symbol: "checkmark", theme: app.theme) { dismiss() }
                    if focus.phase != .rest && focus.breakMinutes > 0 {
                        SecondaryButton(title: "Take a \(focus.breakMinutes)-min break", symbol: "cup.and.saucer.fill", tint: app.theme.onBackground) {
                            focus.startBreak()
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, RTSpacing.xl)
                .padding(.bottom, RTSpacing.xl)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { pop = true }
            Haptics.success(app.profile.hapticsEnabled)
        }
    }
}
