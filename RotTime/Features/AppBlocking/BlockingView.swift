import FamilyControls
import SwiftUI

struct BlockingView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @State private var editing: BlockMode?
    @State private var showInstantPicker = false
    @State private var instantSelection = FamilyActivitySelection()
    @State private var instantMinutes: Int? = 30
    @State private var instantStrict = false
    @State private var showDiagnostics = false

    private let durations: [Int?] = [15, 30, 60, 120, nil]

    var body: some View {
        ZStack {
            ThemeBackgroundView(theme: app.theme, animated: app.profile.ambientAnimations)
            ScrollView(showsIndicators: false) {
                VStack(spacing: RTSpacing.l) {
                    HStack {
                        Text("Shields").font(RTFont.display(32)).foregroundStyle(app.theme.onBackground)
                        Spacer()
                        BrainCharacterView(expression: screenTime.activeShields.isEmpty ? .idle : .focused,
                                           appearance: app.appearance, size: 70, showDecor: false)
                    }
                    .padding(.top, RTSpacing.s)

                    if app.isFreeMode {
                        FreeModeShieldsSection()
                    } else {
                        paidShields
                    }
                }
                .padding(.horizontal, RTSpacing.l)
                .padding(.bottom, MainTabView.tabBarClearance)
            }
        }
        .sheet(item: $editing) { mode in ModeEditorView(mode: mode) }
        .sheet(isPresented: $showDiagnostics) {
            NavigationStack {
                ScreenTimeDiagnosticsView()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showDiagnostics = false } } }
            }
        }
        .familyActivityPicker(isPresented: $showInstantPicker, selection: $instantSelection)
        .onAppear {
            if let instant = screenTime.mode(.instant) { instantSelection = instant.selection }
        }
        .onChange(of: instantSelection) { _, newValue in
            guard var instant = screenTime.mode(.instant) else { return }
            instant.selection = newValue
            screenTime.save(instant)
        }
    }

    /// Everything that needs Apple's Family Controls entitlement.
    @ViewBuilder
    private var paidShields: some View {
                    if !screenTime.isAuthorized { authorizationCard }
                    if let request = MoreTimeRequests.latest {
                        Card {
                            HStack(spacing: 12) {
                                BrainCharacterView(expression: .sad, appearance: app.appearance, size: 64, showDecor: false)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("You asked for more time").font(RTFont.label(.bold))
                                    RequestTargetLabel(request: request)
                                }
                                Spacer(minLength: 0)
                            }
                            SecondaryButton(title: "Talk to \(app.brainName)", symbol: "bubble.left.fill", tint: app.theme.accent) {
                                InterventionCenter.shared.presentPendingIfNeeded(requestID: request.id.uuidString)
                            }
                            .padding(.top, RTSpacing.m)
                        }
                    }
                    if !screenTime.activeShields.isEmpty { activeCard }
                    instantCard
                    VStack(spacing: RTSpacing.m) {
                        HStack {
                            Text("Modes").font(RTFont.title(20)).foregroundStyle(app.theme.onBackground)
                            Spacer()
                            Button {
                                editing = screenTime.addCustomMode()
                            } label: {
                                Label("New", systemImage: "plus.circle.fill").font(RTFont.label(.bold))
                            }
                            .foregroundStyle(app.theme.onBackground)
                        }
                        ForEach(screenTime.modes.filter { $0.kind != .instant }) { mode in
                            ModeCard(mode: mode) { editing = mode }
                        }
                    }
                    interventionCard
    }

    // MARK: Authorization

    private var authorizationCard: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(app.theme.accent)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Connect Screen Time").font(RTFont.title(18))
                    Text(screenTime.authorizationStatus == .denied
                         ? "Access was denied. Open Settings → Screen Time → Apps with Screen Time Access and allow RotTime, then come back."
                         : "RotTime uses Apple's Screen Time system to put real shields on apps and websites you choose. Apple asks you to approve this once with Face ID or your passcode.")
                        .font(RTFont.label(.medium)).foregroundStyle(.secondary)
                }
            }
            PrimaryButton(title: "Allow Screen Time access", symbol: "checkmark.shield.fill", theme: app.theme) {
                Task { await screenTime.requestAuthorization() }
            }
            .padding(.top, RTSpacing.m)
            Button { showDiagnostics = true } label: {
                Label("Not connecting? Run a check", systemImage: "stethoscope").font(RTFont.label(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
        }
    }

    private var activeCard: some View {
        Card {
            SectionHeader(title: "Active now", symbol: "shield.checkered", trailing: "\(screenTime.activeShields.count)")
            VStack(spacing: 10) {
                ForEach(screenTime.sortedActiveShields, id: \.key) { ActiveShieldRow(shield: $0) }
            }
            .padding(.top, RTSpacing.s)
        }
    }

    // MARK: Instant

    private var instantCard: some View {
        Card {
            SectionHeader(title: BlockModeKind.instant.title, symbol: BlockModeKind.instant.symbol)
            Text(BlockModeKind.instant.blurb).font(RTFont.caption(.medium)).foregroundStyle(.secondary).padding(.top, 2)

            Button { showInstantPicker = true } label: {
                SelectionSummary(selection: instantSelection)
            }
            .buttonStyle(BouncyButtonStyle(scale: 0.98))
            .padding(.top, RTSpacing.m)
            .disabled(!screenTime.isAuthorized)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(durations, id: \.self) { d in
                        Chip(title: d.map { $0.minutesText } ?? "Until I stop", symbol: nil, selected: instantMinutes == d, tint: app.theme.accent) {
                            instantMinutes = d
                            Haptics.selection(app.profile.hapticsEnabled)
                        }
                    }
                }
            }
            .padding(.top, RTSpacing.m)

            Toggle(isOn: $instantStrict) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strict").font(RTFont.label(.semibold))
                    Text("Can't be ended early or paused on the shield.").font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                }
            }
            .disabled(instantMinutes == nil)
            .tint(app.theme.accent)
            .padding(.top, RTSpacing.m)

            let running = screenTime.mode(.instant).map { screenTime.isActive($0) } ?? false
            PrimaryButton(title: running ? "Restart Instant Block" : "Block now", symbol: "bolt.shield.fill", theme: app.theme) {
                guard var instant = screenTime.mode(.instant) else { return }
                instant.selection = instantSelection
                instant.strict = instantStrict
                screenTime.save(instant)
                if screenTime.start(instant, minutes: instantMinutes) {
                    Haptics.success(app.profile.hapticsEnabled)
                    ChatEngineStore.shared.postEvent(.blockStarted(name: "Instant Block"))
                }
            }
            .padding(.top, RTSpacing.m)
            .disabled(!screenTime.isAuthorized || instantSelection.applicationTokens.isEmpty && instantSelection.categoryTokens.isEmpty && instantSelection.webDomainTokens.isEmpty)
            .opacity(screenTime.isAuthorized ? 1 : 0.5)
        }
    }

    // MARK: Interventions

    private var interventionCard: some View {
        Card {
            SectionHeader(title: "On the shield", symbol: "hand.wave.fill")
            VStack(alignment: .leading, spacing: 10) {
                InfoRow(symbol: "face.smiling.inverse", text: "\(app.brainName) greets you with a friendly message and a reflection question.")
                InfoRow(symbol: "phone.bubble.fill", text: "“I want more time” makes \(app.brainName) reach out — chat, a pretend FaceTime call, a voice note, a letter or a breath — different every time.")
                InfoRow(symbol: "hand.raised.fill", text: "There's always an “Actually, I don't want to” button. Taking 5, 10 or 30 minutes makes \(app.brainName) sick and sad until your next focus session.")
                InfoRow(symbol: "lock.fill", text: "Strict sessions never offer more time.")
                InfoRow(symbol: "star.fill", text: "Every “I'll stay focused” tap earns 2 spark points.")
                Button {
                    InterventionCenter.shared.preview()
                } label: {
                    Label("Preview it now", systemImage: "play.circle.fill").font(RTFont.label(.bold))
                }
                .padding(.top, 4)
            }
            .padding(.top, RTSpacing.s)
        }
    }
}

struct InfoRow: View {
    var symbol: String
    var text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).frame(width: 22).foregroundStyle(.secondary)
            Text(text).font(RTFont.label(.medium)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Shows the chosen apps / categories / websites using Apple's privacy-preserving labels.
struct SelectionSummary: View {
    var selection: FamilyActivitySelection
    @EnvironmentObject private var app: AppState

    private var count: Int { selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(app.theme.buttonGradient))
            VStack(alignment: .leading, spacing: 4) {
                Text(count == 0 ? "Choose apps & websites" : "\(selection.applicationTokens.count) apps · \(selection.categoryTokens.count) categories · \(selection.webDomainTokens.count) sites")
                    .font(RTFont.label(.bold))
                    .foregroundStyle(.primary)
                if count > 0 {
                    HStack(spacing: 6) {
                        ForEach(Array(selection.applicationTokens.prefix(5)), id: \.self) { token in
                            Label(token).labelStyle(.iconOnly).frame(width: 22, height: 22)
                        }
                        ForEach(Array(selection.categoryTokens.prefix(max(0, 5 - selection.applicationTokens.count))), id: \.self) { token in
                            Label(token).labelStyle(.iconOnly).frame(width: 22, height: 22)
                        }
                        if count > 5 { Text("+\(count - 5)").font(RTFont.caption()).foregroundStyle(.secondary) }
                    }
                } else {
                    Text("Tap to open Apple's picker").font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.primary.opacity(0.05)))
    }
}

struct ModeCard: View {
    var mode: BlockMode
    var onEdit: () -> Void
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var screenTime: ScreenTimeManager

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: mode.kind.symbol)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(app.theme.buttonGradient))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(mode.name).font(RTFont.label(.bold))
                        if mode.strict { Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary) }
                        if screenTime.isActive(mode) {
                            Text("ON").font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color(hex: 0x3BAA66)))
                        }
                    }
                    Text(mode.kind == .focus ? "Used by the focus timer" : "\(mode.schedule.weekdaysText) · \(mode.schedule.timeRangeText)")
                        .font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                    Text(mode.hasSelection ? "\(mode.selectionCount) item\(mode.selectionCount == 1 ? "" : "s") shielded"
                                           + (mode.dailyLimitMinutes.map { " · \($0.minutesText)/day limit" } ?? "")
                                           : "No apps chosen yet")
                        .font(RTFont.caption(.medium)).foregroundStyle(mode.hasSelection ? .secondary : app.theme.accent)
                }
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "slider.horizontal.3").font(.headline)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(BouncyButtonStyle())
                .accessibilityLabel("Edit \(mode.name)")
            }
            HStack(spacing: 10) {
                if mode.kind != .focus {
                    Toggle(isOn: Binding(get: { mode.scheduleEnabled }, set: { screenTime.setSchedule(mode, enabled: $0) })) {
                        Text("Schedule").font(RTFont.label(.semibold))
                    }
                    .tint(app.theme.accent)
                    .disabled(!screenTime.isAuthorized)
                    .fixedSize()
                }
                Spacer()
                if screenTime.isActive(mode), let shield = screenTime.activeShields[mode.shieldKey] {
                    if screenTime.canStop(shield) {
                        Button("Stop") { screenTime.stop(shield) }
                            .buttonStyle(.bordered).buttonBorderShape(.capsule).font(RTFont.caption(.bold))
                    }
                } else if mode.kind != .focus {
                    Button {
                        if screenTime.start(mode, minutes: mode.sessionMinutes) {
                            Haptics.success(app.profile.hapticsEnabled)
                            ChatEngineStore.shared.postEvent(.blockStarted(name: mode.name))
                        }
                    } label: {
                        Label("Start \(mode.sessionMinutes.minutesText)", systemImage: "play.fill").font(RTFont.caption(.bold))
                    }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                    .disabled(!screenTime.isAuthorized || !mode.hasSelection)
                }
            }
            .padding(.top, RTSpacing.m)
        }
    }
}
