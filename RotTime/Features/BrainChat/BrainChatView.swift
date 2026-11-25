import SwiftUI

struct BrainChatView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var chat: ChatEngineStore
    @EnvironmentObject private var focus: FocusTimerModel
    @State private var draft = ""
    @State private var showCustomize = false
    @State private var confirmClear = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            ThemeBackgroundView(theme: app.theme, animated: false)
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea().opacity(0.6)
            VStack(spacing: 0) {
                header
                messagesList
                inputBar
            }
            .padding(.bottom, inputFocused ? 0 : MainTabView.tabBarClearance - 18)
        }
        .onAppear { chat.runDailyEventsIfNeeded() }
        .sheet(isPresented: $showCustomize) { CustomizationView() }
        .confirmationDialog("Clear conversation history?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { chat.clearHistory() }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BrainCharacterView(expression: chat.isTyping ? .thinking : chat.currentExpression, appearance: app.appearance, size: 64, showDecor: false)
                .background(Circle().fill(app.theme.accent.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(app.brainName).font(RTFont.title(20))
                HStack(spacing: 5) {
                    Circle().fill(Color(hex: 0x3BAA66)).frame(width: 7, height: 7)
                    Text(chat.isTyping ? "typing…" : "here for you").font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Menu {
                Button { showCustomize = true } label: { Label("Customize \(app.brainName)", systemImage: "paintbrush") }
                Button(role: .destructive) { confirmClear = true } label: { Label("Clear history", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis").font(.headline)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.regularMaterial))
            }
            .accessibilityLabel("Chat options")
        }
        .padding(.horizontal, RTSpacing.l)
        .padding(.vertical, RTSpacing.s)
        .background(.bar)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if chat.messages.isEmpty {
                        VStack(spacing: 10) {
                            BrainCharacterView(expression: .happy, appearance: app.appearance, size: 150)
                            Text("Say hi to \(app.brainName)!").font(RTFont.title(20))
                            Text("Ask about your progress, focus, shields — or just chat.").font(RTFont.label(.medium)).foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                    }
                    ForEach(Array(chat.messages.enumerated()), id: \.element.id) { index, message in
                        let previous = index > 0 ? chat.messages[index - 1] : nil
                        if message.isEvent || previous == nil || message.date.timeIntervalSince(previous!.date) > 3600 {
                            Text(message.date.formatted(.relative(presentation: .named)))
                                .font(RTFont.caption(.semibold)).foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                        MessageRow(message: message, showAvatar: message.sender == .brain && previous?.sender != .brain) { action in
                            handle(action)
                        }
                        .id(message.id)
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                    }
                    if chat.isTyping {
                        TypingIndicator(tint: app.theme.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 40)
                            .id("typing")
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, RTSpacing.l)
                .padding(.vertical, RTSpacing.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: chat.messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: chat.isTyping) { _, _ in scrollToBottom(proxy) }
            .onAppear { scrollToBottom(proxy, animated: false) }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        let target: AnyHashable? = chat.isTyping ? AnyHashable("typing") : chat.messages.last.map { AnyHashable($0.id) }
        guard let target else { return }
        if animated { withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(target, anchor: .bottom) } }
        else { proxy.scrollTo(target, anchor: .bottom) }
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if !chat.quickReplies.isEmpty && !chat.isTyping {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chat.quickReplies, id: \.self) { reply in
                            Button {
                                Haptics.tap(app.profile.hapticsEnabled)
                                chat.send(reply)
                            } label: {
                                Text(reply)
                                    .font(RTFont.label(.semibold))
                                    .padding(.horizontal, 14).padding(.vertical, 9)
                                    .background(Capsule().strokeBorder(app.theme.accent, lineWidth: 1.5).background(Capsule().fill(.regularMaterial)))
                                    .foregroundStyle(app.theme.accent)
                            }
                            .buttonStyle(BouncyButtonStyle())
                        }
                    }
                    .padding(.horizontal, RTSpacing.l)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: 10) {
                TextField("Message \(app.brainName)…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .font(RTFont.body())
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(Capsule().fill(.regularMaterial))
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit(send)
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(app.theme.buttonGradient))
                }
                .buttonStyle(BouncyButtonStyle())
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, RTSpacing.l)
        }
        .padding(.vertical, 10)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: chat.quickReplies)
    }

    private func send() {
        let text = draft
        draft = ""
        chat.send(text)
    }

    private func handle(_ action: ChatAction) {
        Haptics.tap(app.profile.hapticsEnabled)
        switch action {
        case .startFocus25: focus.startFocus(minutes: 25); app.selectedTab = .focus
        case .startFocus50: focus.breakMinutes = 10; focus.startFocus(minutes: 50); app.selectedTab = .focus
        case .startBreak5: focus.startBreak(minutes: 5); app.selectedTab = .focus
        case .openBlocking: app.selectedTab = .block
        case .openCustomize: showCustomize = true
        case .openStats: app.selectedTab = .progress
        case .openFocus: app.selectedTab = .focus
        }
    }
}

struct MessageRow: View {
    var message: ChatMessage
    var showAvatar: Bool
    var onAction: (ChatAction) -> Void
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var focus: FocusTimerModel

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.sender == .brain {
                Group {
                    if showAvatar {
                        BrainCharacterView(expression: message.expression ?? .happy, appearance: app.appearance, size: 34, animated: false, showDecor: false)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 8) {
                    bubble
                    if !message.actions.isEmpty {
                        ForEach(message.actions, id: \.self) { action in
                            Button { onAction(action) } label: {
                                Label(action.title, systemImage: action.symbol)
                                    .font(RTFont.label(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 9)
                                    .background(Capsule().fill(app.theme.buttonGradient))
                            }
                            .buttonStyle(BouncyButtonStyle())
                            .disabled(focus.isRunning && [.startFocus25, .startFocus50, .startBreak5].contains(action))
                        }
                    }
                }
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 60)
                bubble
            }
        }
    }

    private var bubble: some View {
        Text(LocalizedStringKey(message.text))
            .font(RTFont.body())
            .foregroundStyle(message.sender == .user ? .white : .primary)
            .padding(.horizontal, 15).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(message.sender == .user ? AnyShapeStyle(app.theme.buttonGradient) : AnyShapeStyle(.regularMaterial))
            )
            .overlay(alignment: .topLeading) {
                if message.isEvent {
                    Image(systemName: "sparkle").font(.caption2.weight(.bold)).foregroundStyle(app.theme.accent).offset(x: -4, y: -4)
                }
            }
            .textSelection(.enabled)
    }
}

struct TypingIndicator: View {
    var tint: Color
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(tint.opacity(0.8))
                        .frame(width: 8, height: 8)
                        .offset(y: -4 * max(0, sin(t * 6 - Double(i) * 0.7)))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.regularMaterial))
        }
        .accessibilityLabel("Typing")
    }
}
