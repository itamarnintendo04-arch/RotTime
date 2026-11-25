import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @Environment(\.dismiss) private var dismiss
    @State private var unlock = SharedStore.unlockSettings
    @State private var confirmReset = false
    @State private var confirmRevoke = false
    @State private var showCustomize = false

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
                    Stepper(value: $app.profile.dailyGoalMinutes, in: 10...600, step: 5) {
                        LabeledContent("Daily focus goal", value: app.profile.dailyGoalMinutes.minutesText)
                    }
                    Stepper(value: $app.profile.weeklyGoalMinutes, in: 30...4200, step: 30) {
                        LabeledContent("Weekly focus goal", value: app.profile.weeklyGoalMinutes.minutesText)
                    }
                } header: { Text("Goals") }

                Section {
                    LabeledContent("Status", value: screenTime.statusText)
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
                    Toggle("Offer a mindful pause on shields", isOn: $unlock.enabled)
                    if unlock.enabled {
                        Picker("Breathing wait", selection: $unlock.waitSeconds) {
                            ForEach([5, 10, 15, 30, 60], id: \.self) { Text("\($0) seconds").tag($0) }
                        }
                        Picker("Unlock for", selection: $unlock.unlockMinutes) {
                            ForEach([1, 3, 5, 10, 15], id: \.self) { Text("\($0) min").tag($0) }
                        }
                    }
                } header: {
                    Text("Interventions")
                } footer: {
                    Text("When enabled, non-strict shields show “Take a mindful pause”. You'll be asked to wait and breathe, then the app opens briefly and the shield returns automatically.")
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
