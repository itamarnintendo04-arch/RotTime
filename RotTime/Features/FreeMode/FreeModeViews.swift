import SwiftUI
import UIKit

/// Shields tab content when Apple's paid Screen Time entitlement isn't available.
struct FreeModeShieldsSection: View {
    @EnvironmentObject private var app: AppState
    @State private var showCheckIn = false
    @State private var expandedSteps = true

    var body: some View {
        VStack(spacing: RTSpacing.l) {
            intro
            iosScreenTimeGuide
            shortcutsGuide
            todayApps
        }
        .sheet(isPresented: $showCheckIn) { ManualCheckInSheet() }
    }

    private var intro: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "gift.fill").font(.title2).foregroundStyle(app.theme.accent)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Free mode").font(RTFont.title(20))
                    Text("This build can't use Apple's paid Screen Time blocking, so RotTime teams up with tools already on your iPhone: **iOS Screen Time** does the blocking, and **Shortcuts** lets \(app.brainName) step in whenever you open a scrolly app.")
                        .font(RTFont.label(.medium)).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: 1. Real blocking with iOS Screen Time

    private var iosScreenTimeGuide: some View {
        Card {
            SectionHeader(title: "1 · Block apps (iOS Screen Time)", symbol: "hourglass")
            VStack(alignment: .leading, spacing: 10) {
                StepRow(n: 1, text: "Open **Settings → Screen Time** and turn it on.")
                StepRow(n: 2, text: "**App Limits → Add Limit** → pick *Social* (or single apps) → set a time, e.g. 30 min.")
                StepRow(n: 3, text: "Keep **Block at End of Limit** on.")
                StepRow(n: 4, text: "**Downtime** → schedule quiet hours, like 22:30–07:00.")
                StepRow(n: 5, text: "Optional: **Use Screen Time Passcode** and let a friend choose it, so “Ignore Limit” isn't one tap away.")
            }
            .padding(.top, RTSpacing.s)
            SecondaryButton(title: "Open Settings", symbol: "gearshape.fill", tint: app.theme.accent) {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .padding(.top, RTSpacing.m)
            Text("Settings opens on RotTime's page. Go back one level to find Screen Time.")
                .font(RTFont.caption(.medium)).foregroundStyle(.secondary).padding(.top, 4)
        }
    }

    // MARK: 2. Let Noodle step in (Shortcuts)

    private var shortcutsGuide: some View {
        Card {
            SectionHeader(title: "2 · Let \(app.brainName) step in", symbol: "wand.and.stars",
                          trailing: FreeUsageStore.isSetUp ? "Working ✓" : "Not set up")
            Text("When you open Instagram (or any app you choose), \(app.brainName) pops up — a chat, a call, a voice note, a letter or a breath — and asks if you really want to scroll.")
                .font(RTFont.caption(.medium)).foregroundStyle(.secondary).padding(.top, 4)
            DisclosureGroup(isExpanded: $expandedSteps) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("When the app opens").font(RTFont.label(.bold)).padding(.top, 6)
                    StepRow(n: 1, text: "Open **Shortcuts → Automation → + → App**.")
                    StepRow(n: 2, text: "Choose the app (e.g. Instagram), tick **Is Opened**, pick **Run Immediately** → Next.")
                    StepRow(n: 3, text: "**New Blank Automation** → add **RotTime ▸ Should Noodle Step In?** and set App to Instagram.")
                    StepRow(n: 4, text: "Add **If** → condition *Shortcut Result* **is true**.")
                    StepRow(n: 5, text: "Inside the If, add **RotTime ▸ Talk to Noodle** (App: Instagram). Done.")
                    Text("When the app closes (counts your time)").font(RTFont.label(.bold)).padding(.top, 6)
                    StepRow(n: 6, text: "New automation → **App** → same app → **Is Closed** → Run Immediately.")
                    StepRow(n: 7, text: "Add **RotTime ▸ Log App Closed** (App: Instagram).")
                    Text("Repeat for each app you want help with. While you have extra time that you chose, \(app.brainName) stays quiet.")
                        .font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                }
            } label: {
                Text("How to set it up").font(RTFont.label(.semibold))
            }
            .padding(.top, RTSpacing.s)
            HStack(spacing: 10) {
                SecondaryButton(title: "Open Shortcuts", symbol: "square.stack.3d.up.fill", tint: app.theme.accent) {
                    if let url = URL(string: "shortcuts://") { UIApplication.shared.open(url) }
                }
                SecondaryButton(title: "Preview", symbol: "play.fill", tint: app.theme.accent2) {
                    InterventionCenter.shared.preview()
                }
            }
            .padding(.top, RTSpacing.m)
            if let last = FreeUsageStore.lastAutomationRun {
                Text("Last automation run: \(last.formatted(.relative(presentation: .named)))")
                    .font(RTFont.caption(.medium)).foregroundStyle(.secondary).padding(.top, 6)
            }
        }
    }

    // MARK: Today per app

    private var todayApps: some View {
        let today = FreeUsageStore.today().sorted { $0.value.seconds > $1.value.seconds }
        return Card {
            SectionHeader(title: "Today in your apps", symbol: "chart.bar.fill")
            if today.isEmpty {
                Text("Once your automations run, you'll see how often you opened each app and how long you stayed.")
                    .font(RTFont.label(.medium)).foregroundStyle(.secondary).padding(.top, 4)
            } else {
                VStack(spacing: 10) {
                    ForEach(today, id: \.key) { entry in
                        HStack(spacing: 10) {
                            Image(systemName: entry.key.symbol)
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 9).fill(app.theme.buttonGradient))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.key.name).font(RTFont.label(.bold))
                                Text("Opened \(entry.value.opens)×").font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(entry.value.seconds.shortDuration).font(RTFont.label(.bold)).monospacedDigit()
                        }
                    }
                }
                .padding(.top, RTSpacing.s)
            }
            SecondaryButton(title: "Daily check-in: total time & pickups", symbol: "checklist", tint: app.theme.accent) {
                showCheckIn = true
            }
            .padding(.top, RTSpacing.m)
        }
    }
}

struct StepRow: View {
    var n: Int
    var text: String
    @EnvironmentObject private var app: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(RTFont.caption(.heavy))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(app.theme.accent))
            Text(LocalizedStringKey(text)).font(RTFont.label(.medium)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Free mode: copy today's numbers from iOS Settings → Screen Time.
struct ManualCheckInSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var hours = 0
    @State private var minutes = 0
    @State private var pickups = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Open **Settings → Screen Time → See All App & Website Activity** and copy today's numbers here.")
                        .font(RTFont.label(.medium))
                }
                Section("Time on your phone today") {
                    Stepper(value: $hours, in: 0...23) { LabeledContent("Hours", value: "\(hours)") }
                    Stepper(value: $minutes, in: 0...55, step: 5) { LabeledContent("Minutes", value: "\(minutes)") }
                }
                Section("Pickups today") {
                    Stepper(value: $pickups, in: 0...1000, step: 1) { LabeledContent("Pickups", value: "\(pickups)") }
                    HStack {
                        ForEach([10, 25, 50], id: \.self) { n in
                            Button("+\(n)") { pickups += n }.buttonStyle(.bordered)
                        }
                    }
                }
                Section {
                    let total = hours * 60 + minutes
                    Text(total > app.phoneGoal
                         ? "That's \((total - app.phoneGoal).minutesText) over the \(app.phoneGoal.minutesText) you wanted. \(app.brainName) will feel it. 🤒"
                         : "\((app.phoneGoal - total).minutesText) left of the \(app.phoneGoal.minutesText) you wanted. 💪")
                        .font(RTFont.caption(.semibold))
                        .foregroundStyle(total > app.phoneGoal ? Color(hex: 0xE2505F) : .secondary)
                }
            }
            .navigationTitle("Daily check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        app.saveManualCheckIn(screenMinutes: hours * 60 + minutes, pickups: pickups)
                        Haptics.success(app.profile.hapticsEnabled)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                let t = app.today
                hours = t.manualScreenMinutes / 60
                minutes = (t.manualScreenMinutes % 60) / 5 * 5
                pickups = t.manualPickups
            }
        }
    }
}

/// Home card content in free mode: phone time (check-in or automations) and pickups.
struct FreePhoneTimeSummary: View {
    @EnvironmentObject private var app: AppState
    @State private var showCheckIn = false

    var body: some View {
        let t = app.today
        let tracked = Int(FreeUsageStore.today().values.reduce(0) { $0 + $1.seconds } / 60)
        let opens = FreeUsageStore.today().values.reduce(0) { $0 + $1.opens }
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                summaryTile("On the phone", app.phoneMinutesToday > 0 ? app.phoneMinutesToday.minutesText : "—", "iphone",
                            app.isOverPhoneGoal ? Color(hex: 0xE2505F) : app.theme.accent)
                summaryTile("Pickups", t.manualPickups > 0 ? "\(t.manualPickups)" : "—", "hand.tap.fill", Color(hex: 0x6C5CE7))
                summaryTile("Focused", app.todayFocusMinutes.minutesText, "timer", Color(hex: 0x3BAA66))
            }
            if app.phoneMinutesToday > 0 {
                ProgressBar(progress: min(1, app.phoneProgress), tint: app.isOverPhoneGoal ? Color(hex: 0xE2505F) : app.theme.accent)
                Text(app.isOverPhoneGoal
                     ? "\((app.phoneMinutesToday - app.phoneGoal).minutesText) over the \(app.phoneGoal.minutesText) you wanted 😵‍💫"
                     : "\(app.phoneMinutesLeft.minutesText) left of the \(app.phoneGoal.minutesText) you wanted")
                    .font(RTFont.caption(.semibold)).foregroundStyle(.secondary)
            }
            if tracked > 0 || opens > 0 {
                Text("Apps you track: \(tracked.minutesText) · opened \(opens)×")
                    .font(RTFont.caption(.medium)).foregroundStyle(.secondary)
            }
            SecondaryButton(title: t.manualScreenMinutes > 0 ? "Update check-in" : "Check in: today's time & pickups",
                            symbol: "checklist", tint: app.theme.accent) { showCheckIn = true }
        }
        .padding(.top, RTSpacing.s)
        .sheet(isPresented: $showCheckIn) { ManualCheckInSheet() }
    }

    private func summaryTile(_ title: String, _ value: String, _ symbol: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol).font(.caption.weight(.bold)).foregroundStyle(tint)
            Text(value).font(RTFont.title(20)).lineLimit(1).minimumScaleFactor(0.6).monospacedDigit()
            Text(title).font(RTFont.caption(.semibold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.opacity(0.12)))
    }
}
