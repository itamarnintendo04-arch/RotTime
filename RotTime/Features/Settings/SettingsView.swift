import FamilyControls
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @Environment(\.dismiss) private var dismiss
    @State private var unlock = SharedStore.unlockSettings
    @State private var confirmReset = false
    @State private var confirmRevoke = false
    @State private var showCustomize = false
    @State private var showUsagePicker = false

    private var reminderTime: Binding<Date> {
        Binding(get: { ModeEditorView.date(app.profile.checkInHour, app.profile.checkInMinute) },
                set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                    app.profile.checkInHour = c.hour ?? 9; app.profile.checkInMinute = c.minute ?? 0
                    updateReminder() })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("You & your brain") {
                    TextField("Your name (optional)", text: $app.profile.userName)
                    TextField("Brain name", text: $app.profile.brainName)
                    Button { showCustomize = true } label: { Label("Customize appearance & theme", systemImage: "paintpalette.fill") }
                }

                Section {
                    Stepper(value: $app.profile.phoneGoalMinutes, in: 15...720, step: 15) {
                        LabeledContent("I want to be on my phone", value: "\(app.profile.phoneGoalMinutes.minutesText)/day")
                    }
                    Stepper(value: $app.profile.phoneEstimateMinutes, in: 15...960, step: 15) {
                        LabeledContent("I usually spend", value: "\(app.profile.phoneEstimateMinutes.minutesText)/day")
                    }
                    Button { showUsagePicker = true } label: {
                        Label(SharedStore.usageTrackingConfigured ? "Change what counts as phone time" : "Choose what counts as phone time",
                              systemImage: "square.grid.2x2")
                    }
                    .disabled(!screenTime.isAuthorized)
                } header: {
                    Text("Phone time")
                } footer: {
                    Text("Screen Time tells \(app.brainName) each time you pass another 10 minutes, so the brain knows how much of your day is gone — and gets sick when you go over.")
                }

                Section {
                    LabeledContent("Status", value: screenTime.statusText)
                    NavigationLink {
                        ScreenTimeDiagnosticsView()
                    } label: {
                        Label("Check Screen Time connection", systemImage: "stethoscope")
                    }
                    if !screenTime.isAuthorized {
                        Button("Connect Screen Time") { Task { await screenTime.requestAuthorization() } }
                    } else {
                        Button("Disconnect Screen Time", role: .destructive) { confirmRevoke = true }
                    }
                } header: {
                    Text("Screen Time")
                } footer: {
                    Text("RotTime uses Apple's FamilyControls, ManagedSettings and DeviceActivity frameworks. Apple only gives the app anonymous tokens for the apps you pick.")
                }

                Section {
                    Toggle("“I want more time” button on shields", isOn: $unlock.enabled)
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { InterventionCenter.shared.preview() }
                    } label: {
                        Label("Preview what \(app.brainName) does", systemImage: "play.circle.fill")
                    }
                } header: {
                    Text("When you ask for more time")
                } footer: {
                    Text("Tapping “I want more time” on a shield sends you a notification. Open it and \(app.brainName) reaches out — a chat, a pretend FaceTime call, a voice message, a letter or a breathing moment, different every time — and asks if you really want to keep scrolling. You can always say “Actually, I don't want to”. If you take 5, 10 or 30 minutes, \(app.brainName) gets sick and sad until your next focus session. Strict sessions never offer more time.")
                }
                .onChange(of: unlock) { _, value in SharedStore.unlockSettings = value }

                Section("Notifications") {
                    Toggle("Daily check-in reminder", isOn: Binding(get: { app.profile.checkInReminderEnabled }, set: { v in
                        app.profile.checkInReminderEnabled = v
                        Task {
                            if v { _ = await NotificationManager.requestAuthorization() }
                            updateReminder()
                        }
                    }))
                    if app.profile.checkInReminderEnabled {
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section("Experience") {
                    Toggle("Haptic feedback", isOn: $app.profile.hapticsEnabled)
                    Toggle("Ambient background animation", isOn: $app.profile.ambientAnimations)
                }

                Section {
                    Button("Reset all progress", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Everything RotTime stores lives on this device in its App Group container. Nothing is uploaded.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    LabeledContent("Mascot", value: "\(app.brainName) — an original RotTime character")
                }
            }
            .tint(app.theme.accent)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.bold) } }
            .sheet(isPresented: $showCustomize) { CustomizationView() }
            .familyActivityPicker(isPresented: $showUsagePicker, selection: Binding(
                get: { screenTime.usageSelection },
                set: { screenTime.setUsageSelection($0) }))
            .confirmationDialog("Reset everything?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    app.resetAllData()
                    ChatEngineStore.shared.clearHistory()
                    dismiss()
                }
            } message: { Text("This removes your stats, rewards, chat history and block modes, and lifts all shields.") }
            .confirmationDialog("Disconnect Screen Time?", isPresented: $confirmRevoke, titleVisibility: .visible) {
                Button("Disconnect", role: .destructive) { screenTime.revokeAuthorization() }
            } message: { Text("All shields and schedules will be removed.") }
        }
    }

    private func updateReminder() {
        NotificationManager.updateCheckIn(enabled: app.profile.checkInReminderEnabled, hour: app.profile.checkInHour,
                                          minute: app.profile.checkInMinute, brainName: app.brainName)
    }
}
