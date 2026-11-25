import Charts
import SwiftUI

struct StatisticsView: View {
    enum Range: String, CaseIterable, Identifiable {
        case week = "Week", month = "Month"
        var id: String { rawValue }
    }

    struct DayPoint: Identifiable {
        let date: Date
        let minutes: Int
        let sessions: Int
        let resists: Int
        let blocks: Int
        let phone: Int
        let tracked: Bool
        var id: Date { date }
    }

    @EnvironmentObject private var app: AppState
    @State private var range: Range = .week
    @State private var showRewards = false
    @State private var editingGoals = false
    @State private var selectedDay: Date?

    private var points: [DayPoint] {
        let cal = Calendar.current
        let count = range == .week ? 7 : 30
        let today = cal.startOfDay(for: Date())
        return (0..<count).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let s = app.stats(for: d)
            return DayPoint(date: d, minutes: s.focusMinutes, sessions: s.focusSessions, resists: s.shieldResists, blocks: s.blockSessions,
                            phone: s.phoneMinutes, tracked: s.usageTracked)
        }
    }

    private var weekMinutes: Int {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date())) ?? Date()
        return (0..<7).reduce(0) { sum, i in
            sum + app.stats(for: cal.date(byAdding: .day, value: i, to: start) ?? start).focusMinutes
        }
    }

    var body: some View {
        ZStack {
            ThemeBackgroundView(theme: app.theme, animated: app.profile.ambientAnimations)
            ScrollView(showsIndicators: false) {
                VStack(spacing: RTSpacing.l) {
                    HStack {
                        Text("Progress").font(RTFont.display(32)).foregroundStyle(app.theme.onBackground)
                        Spacer()
                        Button { showRewards = true } label: {
                            Label("\(app.sparkPoints)", systemImage: "sparkles")
                                .font(RTFont.label(.heavy))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Capsule().fill(.ultraThinMaterial))
                        }
                        .foregroundStyle(app.theme.onBackground)
                        .accessibilityLabel("\(app.sparkPoints) spark points. Open rewards")
                    }
                    .padding(.top, RTSpacing.s)

                    tiles
                    phoneChartCard
                    chartCard
                    goalsCard
                    if range == .month { heatmapCard }
                    ScreenTimeReportCard(kind: .week)
                    honestyNote
                }
                .padding(.horizontal, RTSpacing.l)
                .padding(.bottom, MainTabView.tabBarClearance)
            }
        }
        .sheet(isPresented: $showRewards) { RewardsView() }
        .sheet(isPresented: $editingGoals) { PhoneGoalEditor() }
    }

    // MARK: Tiles

    private var tiles: some View {
        let snap = app.snapshot
        let rangePoints = points
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatTile(title: app.isTrackingPhoneTime ? "Phone today (of \(app.phoneGoal.minutesText))" : "Phone today",
                         value: app.isTrackingPhoneTime ? app.phoneMinutesToday.minutesText : "—", symbol: "iphone",
                         tint: app.isOverPhoneGoal ? Color(hex: 0xE2505F) : app.theme.accent)
                StatTile(title: "Focus today", value: app.todayFocusMinutes.minutesText, symbol: "clock.fill", tint: Color(hex: 0x3BAA66))
                StatTile(title: "Current streak", value: "\(app.currentStreak) d", symbol: "flame.fill", tint: .orange)
            }
            HStack(spacing: 12) {
                StatTile(title: "Sessions (\(range.rawValue.lowercased()))", value: "\(rangePoints.reduce(0) { $0 + $1.sessions })",
                         symbol: "checkmark.seal.fill", tint: Color(hex: 0x3BAA66))
                StatTile(title: "Block sessions", value: "\(rangePoints.reduce(0) { $0 + $1.blocks })", symbol: "shield.fill", tint: Color(hex: 0x6C5CE7))
                StatTile(title: "Chose focus", value: "\(rangePoints.reduce(0) { $0 + $1.resists })", symbol: "hand.raised.fill", tint: Color(hex: 0xFF5F8F))
            }
            HStack(spacing: 12) {
                StatTile(title: "All-time focus", value: snap.totalFocusMinutes.minutesText, symbol: "infinity", tint: Color(hex: 0x1FB5D6))
                StatTile(title: "Best streak", value: "\(snap.bestStreak) d", symbol: "trophy.fill", tint: Color(hex: 0xF5B731))
            }
        }
    }

    // MARK: Chart

    private var chartCard: some View {
        Card {
            HStack {
                SectionHeader(title: "Focus time", symbol: "chart.bar.fill")
                Picker("Range", selection: $range) {
                    ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            let data = points
            let total = data.reduce(0) { $0 + $1.minutes }
            let avg = data.isEmpty ? 0 : total / data.count
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(total.minutesText).font(RTFont.display(28)).monospacedDigit()
                Text("total · \(avg.minutesText) avg/day").font(RTFont.caption()).foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Chart {
                ForEach(data) { p in
                    BarMark(x: .value("Day", p.date, unit: .day), y: .value("Minutes", p.minutes))
                        .foregroundStyle(app.theme.buttonGradient)
                        .cornerRadius(range == .week ? 8 : 3)
                        .opacity(selectedDay == nil || Calendar.current.isDate(selectedDay!, inSameDayAs: p.date) ? 1 : 0.4)
                }
                if let selectedDay, let p = data.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }) {
                    RuleMark(x: .value("Selected", p.date, unit: .day))
                        .foregroundStyle(.clear)
                        .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                            VStack(spacing: 2) {
                                Text(p.date.formatted(.dateTime.weekday(.abbreviated).day())).font(RTFont.caption())
                                Text(p.minutes.minutesText).font(RTFont.label(.heavy))
                                Text("\(p.sessions) sessions").font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(.regularMaterial))
                        }
                }
            }
            .chartXSelection(value: $selectedDay)
            .chartXAxis {
                if range == .week {
                    AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) }
                } else {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()) }
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 210)
            .padding(.top, RTSpacing.m)
            .animation(.easeInOut, value: range)
        }
    }

    // MARK: Phone time chart

    private var phoneChartCard: some View {
        Card {
            SectionHeader(title: "Phone time vs. your goal", symbol: "iphone")
            let data = points.filter(\.tracked)
            if data.isEmpty {
                Text("Choose what counts as phone time (Settings → Phone time) and RotTime will chart each day against the \(app.phoneGoal.minutesText) you want.")
                    .font(RTFont.label(.medium)).foregroundStyle(.secondary).padding(.top, 6)
            } else {
                let under = data.filter { $0.phone <= app.phoneGoal }.count
                Text("Under your goal on \(under) of \(data.count) tracked days")
                    .font(RTFont.caption(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
                Chart {
                    ForEach(data) { p in
                        BarMark(x: .value("Day", p.date, unit: .day), y: .value("Phone minutes", p.phone))
                            .foregroundStyle(p.phone > app.phoneGoal ? Color(hex: 0xE2505F) : app.theme.accent)
                            .cornerRadius(range == .week ? 8 : 3)
                    }
                    RuleMark(y: .value("Goal", app.phoneGoal))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Goal \(app.phoneGoal.minutesText)").font(RTFont.caption()).foregroundStyle(.secondary)
                        }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 190)
                .padding(.top, RTSpacing.m)
            }
        }
    }

    // MARK: Goals

    private var goalsCard: some View {
        Card {
            HStack {
                SectionHeader(title: "Personal goals", symbol: "target")
                Button("Edit") { editingGoals = true }.font(RTFont.label(.bold))
            }
            VStack(alignment: .leading, spacing: 14) {
                goalRow(title: "Phone time today", value: app.phoneMinutesToday, target: app.phoneGoal)
                let tracked = points.filter(\.tracked)
                let under = tracked.filter { $0.phone <= app.phoneGoal }.count
                goalRow(title: "Days under your goal this \(range.rawValue.lowercased())", value: under, target: max(1, tracked.count), isCount: true)
                let saved = max(0, app.profile.phoneEstimateMinutes - app.phoneGoal)
                if saved > 0 {
                    Label("Before RotTime you guessed \(app.profile.phoneEstimateMinutes.minutesText)/day. Hitting your goal gives back \(saved.minutesText) every day.",
                          systemImage: "arrow.uturn.backward.circle.fill")
                        .font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                }
            }
            .padding(.top, RTSpacing.m)
        }
    }

    private func goalRow(title: String, value: Int, target: Int, isCount: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(RTFont.label(.semibold))
                Spacer()
                Text(isCount ? "\(value)/\(target)" : "\(value.minutesText) / \(target.minutesText)")
                    .font(RTFont.caption(.bold)).foregroundStyle(.secondary).monospacedDigit()
            }
            ProgressBar(progress: target == 0 ? 0 : Double(value) / Double(target), tint: app.theme.accent)
        }
    }

    // MARK: Heatmap

    private var heatmapCard: some View {
        Card {
            SectionHeader(title: "Last 30 days of focus", symbol: "calendar")
            let data = points
            let goal = max(1, data.map(\.minutes).max() ?? 1)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(data) { p in
                    let level = min(1, Double(p.minutes) / Double(goal))
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(p.minutes == 0 ? AnyShapeStyle(Color.primary.opacity(0.07)) : AnyShapeStyle(app.theme.accent.opacity(0.25 + level * 0.75)))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(Text("\(Calendar.current.component(.day, from: p.date))").font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(level > 0.6 ? .white : .secondary))
                        .accessibilityLabel("\(p.date.formatted(date: .abbreviated, time: .omitted)): \(p.minutes) minutes")
                }
            }
            .padding(.top, RTSpacing.m)
        }
    }

    private var honestyNote: some View {
        Label("Focus, sessions and shield taps are measured by RotTime itself. Screen time totals come from Apple's private report and are never collected by the app.",
              systemImage: "lock.shield")
            .font(RTFont.caption(.medium))
            .foregroundStyle(app.theme.onBackground.opacity(0.8))
            .padding(.horizontal, 6)
    }
}
