import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @EnvironmentObject private var focus: FocusTimerModel
    @State private var showSettings = false
    @State private var showCustomize = false
    @State private var showRewards = false
    @State private var tipIndex = 0
    @State private var appeared = false

    private var state: BrainState { app.brainState(sleepActive: screenTime.sleepModeActive) }
    private var expression: BrainExpression { focus.isRunning ? .focused : state.expression }

    var body: some View {
        ZStack {
            ThemeBackgroundView(theme: app.theme, animated: app.profile.ambientAnimations)
            ScrollView(showsIndicators: false) {
                VStack(spacing: RTSpacing.l) {
                    header
                    hero
                    PhoneTimeCard()
                    ScreenTimeReportCard(kind: .today)
                    focusCard
                    quickActions
                    shieldCard
                    rewardCard
                }
                .padding(.horizontal, RTSpacing.l)
                .padding(.bottom, MainTabView.tabBarClearance)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.5)) { appeared = true } }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showCustomize) { CustomizationView() }
        .sheet(isPresented: $showRewards) { RewardsView() }
    }

    // MARK: Header

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = hour < 5 ? "Hey night owl" : hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : hour < 22 ? "Good evening" : "Hey night owl"
        return app.profile.userName.isEmpty ? part : "\(part), \(app.profile.userName)"
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                    .font(RTFont.caption())
                    .foregroundStyle(app.theme.onBackground.opacity(0.75))
                Text(greeting)
                    .font(RTFont.title(24))
                    .foregroundStyle(app.theme.onBackground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "flame.fill").foregroundStyle(.orange)
                Text("\(app.currentStreak)").font(RTFont.label(.heavy)).monospacedDigit()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial))
            .accessibilityLabel("\(app.currentStreak) day streak")
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.headline)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(BouncyButtonStyle())
            .foregroundStyle(app.theme.onBackground)
            .accessibilityLabel("Settings")
        }
        .padding(.top, RTSpacing.s)
    }

    // MARK: Hero

    private var tips: [String] {
        var t: [String] = []
        switch state {
        case .energetic: t.append("I'm buzzing! Let's do something great.")
        case .slightlyTired: t.append("Yawn… a focus session would wake me up!")
        case .resting: t.append("Shhh… quiet hours. Rest is productive too.")
        case .okay: t.append("Halfway through today's phone time. Pace yourself!")
        case .verySick: t.append("Everything hurts… 🤕 We're way over your goal.")
        case .sick: t.append("Ugh… I feel sick from all that scrolling. 🤒 Focus with me?")
        case .recovered: t.append("Goal reached! I'm fully recharged ✨")
        }
        if focus.isRunning { t = ["Deep focus mode. I believe in you!"] }
        if app.today.shieldResists > 0 { t.append("You chose focus \(app.today.shieldResists)× on a shield today!") }
        if app.currentStreak > 1 { t.append("\(app.currentStreak) days in a row. Wow!") }
        t.append("Tap me! I'm ticklish.")
        return t
    }

    private var hero: some View {
        VStack(spacing: 10) {
            InteractiveBrain(expression: expression, appearance: app.appearance, size: 250,
                             speech: tips[tipIndex % tips.count]) {
                tipIndex += 1
            }
            HStack(spacing: 8) {
                Image(systemName: state.symbol)
                    .foregroundStyle(app.theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(app.brainName) · \(state.title)").font(RTFont.label(.bold))
                    Text(state.caption).font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button { showCustomize = true } label: {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(app.theme.buttonGradient))
                }
                .buttonStyle(BouncyButtonStyle())
                .accessibilityLabel("Customize \(app.brainName)")
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.regularMaterial))
            BrainHealthMeter(health: app.brainHealth)
        }
    }

    // MARK: Focus

    private var focusCard: some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 12).fill(app.theme.buttonGradient))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Focus today").font(RTFont.caption()).foregroundStyle(.secondary)
                    Text("\(app.todayFocusMinutes.minutesText) · \(app.today.focusSessions) session\(app.today.focusSessions == 1 ? "" : "s")")
                        .font(RTFont.title(18)).monospacedDigit()
                }
                Spacer(minLength: 0)
            }
            if focus.isRunning || focus.isPaused {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    SecondaryButton(title: "\(focus.phase == .rest ? "Break" : "Focus") \(focus.isPaused ? "paused" : "running") · \(focus.remaining(at: ctx.date).clock)",
                                    symbol: "timer", tint: app.theme.accent) { app.selectedTab = .focus }
                }
                .padding(.top, RTSpacing.m)
            } else {
                PrimaryButton(title: "Quick Start Focus", symbol: "play.fill", theme: app.theme) {
                    focus.startFocus(minutes: focus.focusMinutes)
                    app.selectedTab = .focus
                }
                .padding(.top, RTSpacing.m)
            }
        }
    }

    // MARK: Quick actions

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            QuickActionTile(title: "App Blocking", subtitle: screenTime.activeShields.isEmpty ? "Set up shields" : "\(screenTime.activeShields.count) active",
                            symbol: "shield.lefthalf.filled", tint: Color(hex: 0x6C5CE7)) { app.selectedTab = .block }
            QuickActionTile(title: "Brain Chat", subtitle: "Talk to \(app.brainName)", symbol: "bubble.left.and.bubble.right.fill",
                            tint: Color(hex: 0xFF5F8F)) { app.selectedTab = .chat }
            QuickActionTile(title: "Customize", subtitle: "Themes & outfits", symbol: "paintpalette.fill",
                            tint: Color(hex: 0xFF8A5C)) { showCustomize = true }
            QuickActionTile(title: "Rewards", subtitle: "\(app.sparkPoints) spark points", symbol: "gift.fill",
                            tint: Color(hex: 0x1FB5D6)) { showRewards = true }
        }
    }

    // MARK: Shields

    private var shieldCard: some View {
        Card {
            SectionHeader(title: "Shields", symbol: "shield.lefthalf.filled",
                          trailing: screenTime.isAuthorized ? nil : "Not connected")
            if screenTime.activeShields.isEmpty {
                Text(screenTime.isAuthorized ? "No shields are up right now. Your apps are open." : "Connect Screen Time to start blocking distracting apps.")
                    .font(RTFont.label(.medium)).foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(screenTime.sortedActiveShields, id: \.key) { shield in
                        ActiveShieldRow(shield: shield)
                    }
                }
                .padding(.top, 6)
            }
        }
        .onTapGesture { app.selectedTab = .block }
    }

    // MARK: Rewards

    private var rewardCard: some View {
        Card {
            SectionHeader(title: "Next reward", symbol: "gift.fill", trailing: "\(app.sparkPoints) ✦")
            if let next = app.nextUnlock {
                HStack(spacing: 12) {
                    Image(systemName: next.symbol)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 14).fill(app.theme.buttonGradient))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(next.title).font(RTFont.label(.bold))
                        Text(next.requirement.text).font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                        ProgressBar(progress: next.requirement.progress(app.snapshot), tint: app.theme.accent, height: 8)
                    }
                }
                .padding(.top, 6)
            } else {
                Text("You've unlocked everything! Legendary brain status. 👑").font(RTFont.label(.medium)).padding(.top, 4)
            }
        }
        .onTapGesture { showRewards = true }
    }
}

struct QuickActionTile: View {
    var title: String
    var subtitle: String
    var symbol: String
    var tint: Color
    var action: () -> Void
    @EnvironmentObject private var app: AppState

    var body: some View {
        Button {
            Haptics.tap(app.profile.hapticsEnabled)
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(tint.gradient))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(RTFont.label(.bold)).foregroundStyle(.primary)
                    Text(subtitle).font(RTFont.caption(.medium)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.regularMaterial))
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

struct ActiveShieldRow: View {
    var shield: ActiveShield
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @EnvironmentObject private var app: AppState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: shield.strict ? "lock.fill" : "shield.fill")
                .foregroundStyle(app.theme.accent)
                .frame(width: 32, height: 32)
                .background(Circle().fill(app.theme.accent.opacity(0.15)))
            VStack(alignment: .leading, spacing: 1) {
                Text(shield.title).font(RTFont.label(.bold))
                Group {
                    if let end = shield.endsAt {
                        Text("Until \(end.formatted(date: .omitted, time: .shortened))")
                    } else {
                        Text("Until you stop it")
                    }
                }
                .font(RTFont.caption(.medium)).foregroundStyle(.secondary)
            }
            Spacer()
            if screenTime.canStop(shield) {
                Button("End") {
                    Haptics.tap(app.profile.hapticsEnabled)
                    if shield.key == "focus" { FocusTimerModel.shared.stop() } else { screenTime.stop(shield) }
                }
                .font(RTFont.caption(.bold))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            } else {
                Text("Strict").font(RTFont.caption(.bold)).foregroundStyle(.secondary)
            }
        }
    }
}

/// "How the brain feels" bar: drains as phone time approaches (and passes) your goal.
struct BrainHealthMeter: View {
    var health: Double
    @EnvironmentObject private var app: AppState

    private var tint: Color {
        health > 0.6 ? Color(hex: 0x3BAA66) : health > 0.33 ? Color(hex: 0xFF9A3C) : Color(hex: 0xE2505F)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: health > 0.6 ? "heart.fill" : health > 0.33 ? "heart.lefthalf.filled" : "heart.slash.fill")
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(app.brainName)'s health").font(RTFont.caption(.bold))
                    Spacer()
                    Text("\(Int((health * 100).rounded()))%").font(RTFont.caption(.heavy)).monospacedDigit().foregroundStyle(tint)
                }
                ProgressBar(progress: health, tint: tint, height: 8)
                Text(app.isTrackingPhoneTime
                     ? "Drops as your \(app.phoneMinutesToday.minutesText) of phone time gets closer to the \(app.phoneGoal.minutesText) you wanted."
                     : "Choose what counts as phone time so \(app.brainName) can feel it.")
                    .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.regularMaterial))
        .accessibilityElement(children: .combine)
    }
}
