import FamilyControls
import SwiftUI

struct ModeEditorView: View {
    @State private var draft: BlockMode
    @State private var showPicker = false
    @State private var confirmDelete = false
    @State private var limitEnabled: Bool
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @Environment(\.dismiss) private var dismiss

    init(mode: BlockMode) {
        _draft = State(initialValue: mode)
        _limitEnabled = State(initialValue: mode.dailyLimitMinutes != nil)
    }

    private var startBinding: Binding<Date> {
        Binding(get: { Self.date(draft.schedule.startHour, draft.schedule.startMinute) },
                set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                    draft.schedule.startHour = c.hour ?? 0; draft.schedule.startMinute = c.minute ?? 0 })
    }

    private var endBinding: Binding<Date> {
        Binding(get: { Self.date(draft.schedule.endHour, draft.schedule.endMinute) },
                set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                    draft.schedule.endHour = c.hour ?? 0; draft.schedule.endMinute = c.minute ?? 0 })
    }

    static func date(_ h: Int, _ m: Int) -> Date {
        Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: draft.kind.symbol)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: 16).fill(app.theme.buttonGradient))
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Mode name", text: $draft.name).font(RTFont.title(20))
                            Text(draft.kind.blurb).font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button { showPicker = true } label: { SelectionSummary(selection: draft.selection) }
                        .buttonStyle(.plain)
                        .disabled(!screenTime.isAuthorized)
                    if draft.selection.applicationTokens.count > 50 {
                        Label("Apple allows up to 50 individual apps per shield. Consider choosing categories instead.", systemImage: "exclamationmark.triangle.fill")
                            .font(RTFont.caption(.medium)).foregroundStyle(.orange)
                    }
                    if !draft.selection.applicationTokens.isEmpty {
                        ForEach(Array(draft.selection.applicationTokens.prefix(8)), id: \.self) { Label($0) }
                    }
                    if !draft.selection.webDomainTokens.isEmpty {
                        ForEach(Array(draft.selection.webDomainTokens.prefix(6)), id: \.self) { Label($0) }
                    }
                } header: {
                    Text("Apps & websites")
                } footer: {
                    Text(screenTime.isAuthorized ? "Apple shows app names here, but never shares them with RotTime." : "Connect Screen Time in the Shields tab to pick apps.")
                }

                if draft.kind != .focus && draft.kind != .instant {
                    Section {
                        DatePicker("Starts", selection: startBinding, displayedComponents: .hourAndMinute)
                        DatePicker("Ends", selection: endBinding, displayedComponents: .hourAndMinute)
                        WeekdayPicker(weekdays: $draft.schedule.weekdays, tint: app.theme.accent)
                        if draft.schedule.durationMinutes < 15 {
                            Label("Schedules need to be at least 15 minutes long.", systemImage: "exclamationmark.triangle.fill")
                                .font(RTFont.caption(.medium)).foregroundStyle(.orange)
                        }
                        if draft.schedule.crossesMidnight {
                            Label("Runs overnight until \(BlockSchedule.format(draft.schedule.endHour, draft.schedule.endMinute)) the next morning.", systemImage: "moon.fill")
                                .font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                        }
                        Toggle("Repeat on schedule", isOn: $draft.scheduleEnabled).tint(app.theme.accent)
                    } header: {
                        Text("Schedule")
                    } footer: {
                        Text("Schedules are run by iOS itself, so they work even when RotTime is closed.")
                    }
                }

                Section("Sessions") {
                    Stepper(value: $draft.sessionMinutes, in: 5...480, step: 5) {
                        LabeledContent("Session length", value: draft.sessionMinutes.minutesText)
                    }
                    Stepper(value: $draft.breakMinutes, in: 0...60, step: 5) {
                        LabeledContent("Break length", value: draft.breakMinutes == 0 ? "None" : draft.breakMinutes.minutesText)
                    }
                }

                Section {
                    Toggle("Strict mode", isOn: $draft.strict).tint(app.theme.accent)
                    Toggle("Daily time limit", isOn: $limitEnabled).tint(app.theme.accent)
                    if limitEnabled {
                        Stepper(value: Binding(get: { draft.dailyLimitMinutes ?? 60 }, set: { draft.dailyLimitMinutes = $0 }), in: 5...600, step: 5) {
                            LabeledContent("Allow per day", value: (draft.dailyLimitMinutes ?? 60).minutesText)
                        }
                    }
                } header: {
                    Text("Rules")
                } footer: {
                    Text("Strict: the shield has no mindful-pause button and timed sessions can't be ended early. Daily limit: once you've used these apps for that long today, they're shielded until midnight.")
                }

                if draft.kind == .custom {
                    Section {
                        Button("Delete mode", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LinearGradient(colors: [app.theme.skyTop.opacity(0.35), Color(.systemGroupedBackground)], startPoint: .top, endPoint: .center).ignoresSafeArea())
            .navigationTitle(draft.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.bold)
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $draft.selection)
            .confirmationDialog("Delete \(draft.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { screenTime.delete(draft); dismiss() }
            }
        }
    }

    private func save() {
        if !limitEnabled { draft.dailyLimitMinutes = nil } else if draft.dailyLimitMinutes == nil { draft.dailyLimitMinutes = 60 }
        let wantsSchedule = draft.scheduleEnabled
        draft.scheduleEnabled = false
        screenTime.save(draft)
        if wantsSchedule { screenTime.setSchedule(draft, enabled: true) } else { screenTime.setSchedule(draft, enabled: false) }
        if limitEnabled, draft.kind != .custom {
            do { try ActivityScheduler.registerDailyLimit(for: draft) } catch {
                screenTime.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        } else if !limitEnabled {
            ActivityScheduler.unregisterLimit(draft)
        }
        Haptics.success(app.profile.hapticsEnabled)
        dismiss()
    }
}

struct WeekdayPicker: View {
    @Binding var weekdays: Set<Int>
    var tint: Color

    var body: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                let on = weekdays.contains(day)
                Button {
                    if on { weekdays.remove(day) } else { weekdays.insert(day) }
                    Haptics.selection()
                } label: {
                    Text(symbols[day - 1])
                        .font(RTFont.label(.bold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .foregroundStyle(on ? .white : .primary)
                        .background(Circle().fill(on ? AnyShapeStyle(tint) : AnyShapeStyle(Color.primary.opacity(0.07))))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
