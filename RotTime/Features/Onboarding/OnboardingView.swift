import FamilyControls
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @State private var page = 0
    @State private var name = ""
    @State private var brainName = "Noodle"
    @State private var phoneNow = 240
    @State private var phoneGoal = 120
    @State private var poke = false
    @State private var showUsagePicker = false

    private let pages = 5

    private var expression: BrainExpression {
        switch page {
        case 0: return poke ? .surprised : .happy
        case 1: return .focused
        case 2: return .love
        case 3: return phoneNow > phoneGoal * 2 ? .tired : .thinking
        default: return screenTime.isAuthorized ? .celebrating : .thinking
        }
    }

    var body: some View {
        ZStack {
            ThemeBackgroundView(theme: Theme.with(id: "cozy"))
            VStack(spacing: RTSpacing.l) {
                HStack(spacing: 6) {
                    ForEach(0..<pages, id: \.self) { i in
                        Capsule().fill(i == page ? Color(hex: 0xFF5F8F) : Color.white.opacity(0.6))
                            .frame(width: i == page ? 26 : 8, height: 8)
                    }
                }
                .animation(.spring(), value: page)
                .padding(.top, RTSpacing.l)

                Spacer(minLength: 0)
                BrainCharacterView(expression: expression,
                                   appearance: BrainAppearance(hat: page == 1 ? .headphones : .none, effect: page == 4 ? .sparkles : .none),
                                   size: 240)
                    .onTapGesture {
                        poke = true
                        Haptics.tap()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { poke = false }
                    }

                Group {
                    switch page {
                    case 0: intro
                    case 1: howItWorks
                    case 2: personalize
                    case 3: phoneTime
                    default: permissions
                    }
                }
                .padding(RTSpacing.xl)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(.regularMaterial))
                .padding(.horizontal, RTSpacing.l)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                .id(page)

                PrimaryButton(title: page == pages - 1 ? "Let's go!" : "Continue", symbol: page == pages - 1 ? "sparkles" : "arrow.right",
                              theme: Theme.with(id: "cozy")) {
                    Haptics.tap()
                    if page < pages - 1 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { page += 1 }
                    } else {
                        finish()
                    }
                }
                .padding(.horizontal, RTSpacing.xl)
                .padding(.bottom, RTSpacing.l)
            }
        }
    }

    private var intro: some View {
        VStack(spacing: 10) {
            Text("Meet your brain buddy").font(RTFont.display(28)).multilineTextAlignment(.center)
            Text("This little brain grows brighter every time you focus, rest well and choose what *you* actually want to do with your time.")
                .font(RTFont.body()).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How RotTime works").font(RTFont.display(26))
            InfoRow(symbol: "timer", text: "Focus sessions that keep counting even when you leave the app.")
            InfoRow(symbol: "shield.lefthalf.filled", text: "Real Screen Time shields on the apps and sites you choose.")
            InfoRow(symbol: "bubble.left.and.bubble.right.fill", text: "Chat with your brain for check-ins and encouragement.")
            InfoRow(symbol: "gift.fill", text: "Unlock themes, hats and effects by focusing — never by paying.")
        }
    }

    private var personalize: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Make it yours").font(RTFont.display(26))
            TextField("Your name (optional)", text: $name)
                .textFieldStyle(.roundedBorder)
                .textContentType(.givenName)
            TextField("Name your brain", text: $brainName)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var phoneTime: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your phone time").font(RTFont.display(26))
            VStack(alignment: .leading, spacing: 6) {
                Text("How much are you on your phone right now, per day?").font(RTFont.label(.semibold))
                Stepper(value: $phoneNow, in: 15...960, step: 15) {
                    Text(phoneNow.minutesText).font(RTFont.title(22)).monospacedDigit()
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("How much do you *want* to be on it?").font(RTFont.label(.semibold))
                Stepper(value: $phoneGoal, in: 15...720, step: 15) {
                    Text(phoneGoal.minutesText).font(RTFont.title(22)).monospacedDigit()
                }
            }
            let saved = max(0, phoneNow - phoneGoal)
            if saved > 0 {
                Label("That's \(Int((Double(saved) * 365 / 60 / 24).rounded())) days a year back for your life. \(brainName.isEmpty ? "Noodle" : brainName) will help.",
                      systemImage: "sparkles")
                    .font(RTFont.caption(.semibold))
                    .foregroundStyle(Color(hex: 0xFF5F8F))
            }
        }
        .onChange(of: phoneNow) { _, now in if phoneGoal > now { phoneGoal = now } }
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Let's connect").font(RTFont.display(26))
            if app.isFreeMode {
                PermissionRow(symbol: "gift.fill", title: "Free mode",
                              detail: "This install can't use Apple's paid Screen Time blocking. After setup, the Shields tab shows how to block with iOS Screen Time and let \(brainName.isEmpty ? "Noodle" : brainName) step in with Shortcuts.",
                              done: true)
            } else {
            Button {
                Task { await screenTime.requestAuthorization() }
            } label: {
                PermissionRow(symbol: "hourglass", title: "Screen Time",
                              detail: "Needed to shield apps. Apple asks for Face ID or your passcode.",
                              done: screenTime.isAuthorized)
            }
            .buttonStyle(.plain)
            Button {
                showUsagePicker = true
            } label: {
                PermissionRow(symbol: "square.grid.2x2.fill", title: "What counts as phone time",
                              detail: "Tap “All Apps & Categories” so \(brainName.isEmpty ? "Noodle" : brainName) can see how much you've used.",
                              done: screenTime.isAuthorized && SharedStore.usageTrackingConfigured)
            }
            .buttonStyle(.plain)
            .disabled(!screenTime.isAuthorized)
            .opacity(screenTime.isAuthorized ? 1 : 0.5)
            .familyActivityPicker(isPresented: $showUsagePicker, selection: Binding(
                get: { screenTime.usageSelection },
                set: { app.profile.phoneGoalMinutes = phoneGoal; screenTime.setUsageSelection($0) }))
            }
            Button {
                Task { _ = await NotificationManager.requestAuthorization() }
            } label: {
                PermissionRow(symbol: "bell.badge.fill", title: "Notifications",
                              detail: "So your brain can tell you when a session or break ends.", done: false)
            }
            .buttonStyle(.plain)
            Text("You can skip these and enable them later.").font(RTFont.caption(.medium)).foregroundStyle(.secondary)
        }
    }

    private func finish() {
        app.profile.userName = name.trimmingCharacters(in: .whitespaces)
        let trimmed = brainName.trimmingCharacters(in: .whitespaces)
        app.profile.brainName = trimmed.isEmpty ? "Noodle" : trimmed
        app.profile.phoneEstimateMinutes = phoneNow
        app.profile.phoneGoalMinutes = phoneGoal
        screenTime.startUsageTracking()
        app.profile.onboardingComplete = true
        AppGroup.defaults.set(DayKey.string(for: Date()), forKey: ChatStore.dailyKey)
        ChatEngineStore.shared.postEvent(.dailyWelcome)
        Haptics.success()
    }
}

struct PermissionRow: View {
    var symbol: String
    var title: String
    var detail: String
    var done: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xFF8A5C).gradient))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(RTFont.label(.bold))
                Text(detail).font(RTFont.caption(.medium)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: done ? "checkmark.circle.fill" : "chevron.right")
                .foregroundStyle(done ? Color(hex: 0x3BAA66) : .secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.primary.opacity(0.05)))
    }
}
