import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var focus: FocusTimerModel
    @EnvironmentObject private var screenTime: ScreenTimeManager

    var body: some View {
        ZStack {
            if app.profile.onboardingComplete {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: app.profile.onboardingComplete)
        .overlay(alignment: .top) {
            if let toast = app.toast {
                ToastView(toast: toast, tint: app.theme.accent)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation { app.toast = nil } }
            }
        }
        .fullScreenCover(item: $focus.completion) { completion in
            CelebrationView(completion: completion)
        }
        .alert("Heads up", isPresented: Binding(get: { screenTime.errorMessage != nil },
                                                set: { if !$0 { screenTime.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(screenTime.errorMessage ?? "")
        }
        .tint(app.theme.accent)
        .preferredColorScheme(nil)
    }
}

struct MainTabView: View {
    @EnvironmentObject private var app: AppState
    @Namespace private var tabNamespace

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch app.selectedTab {
                case .home: HomeView()
                case .focus: FocusView()
                case .block: BlockingView()
                case .chat: BrainChatView()
                case .progress: StatisticsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .id(app.selectedTab)

            tabBar
        }
        .animation(.easeInOut(duration: 0.22), value: app.selectedTab)
    }

    /// Height reserved at the bottom of each screen for the floating tab bar.
    static let tabBarClearance: CGFloat = 92

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    Haptics.selection(app.profile.hapticsEnabled)
                    app.selectedTab = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 18, weight: .bold))
                            .symbolEffect(.bounce, value: app.selectedTab == tab)
                        Text(tab.title).font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(app.selectedTab == tab ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if app.selectedTab == tab {
                            Capsule().fill(app.theme.buttonGradient)
                                .matchedGeometryEffect(id: "tab", in: tabNamespace)
                        }
                    }
                }
                .buttonStyle(BouncyButtonStyle(scale: 0.9))
                .accessibilityLabel(tab.title)
            }
        }
        .padding(6)
        .background(Capsule().fill(.ultraThickMaterial))
        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: app.selectedTab)
    }
}
