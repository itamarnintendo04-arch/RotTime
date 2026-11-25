import FamilyControls
import SwiftUI

/// "How much you wanted vs. how much you've used so far today".
struct PhoneTimeCard: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @State private var showPicker = false
    @State private var showGoal = false

    private var ringColor: Color {
        let p = app.phoneProgress
        if p > 1 { return Color(hex: 0xE2505F) }
        if p > 0.8 { return Color(hex: 0xFF9A3C) }
        return app.theme.accent
    }

    var body: some View {
        Card {
            HStack {
                SectionHeader(title: "Phone time today", symbol: "iphone")
                Button { showGoal = true } label: {
                    Label("Goal \(app.phoneGoal.minutesText)", systemImage: "target").font(RTFont.caption(.bold))
                }
            }
            if app.isTrackingPhoneTime && screenTime.isAuthorized {
                tracked
            } else {
                setup
            }
        }
        .sheet(isPresented: $showGoal) { PhoneGoalEditor() }
        .familyActivityPicker(isPresented: $showPicker, selection: Binding(
            get: { screenTime.usageSelection },
            set: { screenTime.setUsageSelection($0) }))
    }

    private var tracked: some View {
        HStack(spacing: RTSpacing.l) {
            ZStack {
                ProgressRing(progress: min(1, app.phoneProgress), lineWidth: 12,
                             gradient: AngularGradient(colors: [ringColor.opacity(0.7), ringColor, ringColor.opacity(0.7)], center: .center))
                VStack(spacing: 0) {
                    Text(app.phoneMinutesToday.minutesText).font(RTFont.title(18)).monospacedDigit()
                    Text("used").font(RTFont.caption()).foregroundStyle(.secondary)
                }
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 6) {
                Text("You wanted \(app.phoneGoal.minutesText) today").font(RTFont.caption()).foregroundStyle(.secondary)
                if app.isOverPhoneGoal {
                    Text("\((app.phoneMinutesToday - app.phoneGoal).minutesText) over 😵‍💫")
                        .font(RTFont.title(20)).foregroundStyle(Color(hex: 0xE2505F))
                } else {
                    Text("\(app.phoneMinutesLeft.minutesText) left").font(RTFont.title(22)).monospacedDigit()
                }
                Label("Focused \(app.todayFocusMinutes.minutesText) today", systemImage: "timer")
                    .font(RTFont.caption(.bold)).foregroundStyle(Color(hex: 0x3BAA66))
                Text("Updated in 10-minute steps · exact time & pickups below")
                    .font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                Button("What counts?") { showPicker = true }.font(RTFont.caption(.bold))
            }
            Spacer(minLength: 0)
        }
        .padding(.top, RTSpacing.s)
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(screenTime.isAuthorized
                 ? "Choose what counts as phone time. Tip: tap “All Apps & Categories” so everything counts."
                 : "Connect Screen Time so \(app.brainName) can see how much of your \(app.phoneGoal.minutesText) you've used.")
                .font(RTFont.label(.medium)).foregroundStyle(.secondary)
            if screenTime.isAuthorized {
                SecondaryButton(title: "Choose apps to count", symbol: "square.grid.2x2.fill", tint: app.theme.accent) { showPicker = true }
            } else {
                SecondaryButton(title: "Connect Screen Time", symbol: "link", tint: app.theme.accent) {
                    Task { await screenTime.requestAuthorization() }
                }
            }
        }
        .padding(.top, RTSpacing.s)
    }
}

struct PhoneGoalEditor: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $app.profile.phoneGoalMinutes, in: 15...720, step: 15) {
                        LabeledContent("I want to be on my phone", value: "\(app.profile.phoneGoalMinutes.minutesText) / day")
                    }
                    Stepper(value: $app.profile.phoneEstimateMinutes, in: 15...960, step: 15) {
                        LabeledContent("I usually spend", value: "\(app.profile.phoneEstimateMinutes.minutesText) / day")
                    }
                } footer: {
                    let saved = max(0, app.profile.phoneEstimateMinutes - app.profile.phoneGoalMinutes)
                    Text(saved > 0 ? "That's about \(Int((Double(saved) * 365 / 60 / 24).rounded())) days a year back for you." : "Pick a goal that feels kind and realistic.")
                }
            }
            .navigationTitle("Phone time goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}
