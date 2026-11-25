import DeviceActivity
import FamilyControls
import SwiftUI

extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
    static let weeklyActivity = Self("Weekly Activity")
}

/// Embeds Apple's DeviceActivityReport (rendered by RotTimeReport extension).
/// The app itself never sees these numbers — only the user does.
struct ScreenTimeReportCard: View {
    enum Kind { case today, week }
    var kind: Kind
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @EnvironmentObject private var app: AppState

    private var filter: DeviceActivityFilter {
        let cal = Calendar.current
        let now = Date()
        switch kind {
        case .today:
            return DeviceActivityFilter(segment: .daily(during: DateInterval(start: cal.startOfDay(for: now), end: now)),
                                        users: .all, devices: .init([.iPhone, .iPad]))
        case .week:
            let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
            return DeviceActivityFilter(segment: .daily(during: DateInterval(start: start, end: now)),
                                        users: .all, devices: .init([.iPhone, .iPad]))
        }
    }

    var body: some View {
        Card(padding: 0) {
            if screenTime.isAuthorized {
                DeviceActivityReport(kind == .today ? .totalActivity : .weeklyActivity, filter: filter)
                    .frame(minHeight: kind == .today ? 300 : 220)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: kind == .today ? "Screen time today" : "Screen time this week", symbol: "hourglass")
                    Text("Connect Screen Time to see Apple's usage report here. RotTime never reads or uploads these numbers.")
                        .font(RTFont.label(.medium))
                        .foregroundStyle(.secondary)
                    SecondaryButton(title: "Connect Screen Time", symbol: "link", tint: app.theme.accent) {
                        Task { await screenTime.requestAuthorization() }
                    }
                }
                .padding(RTSpacing.l)
            }
        }
    }
}
