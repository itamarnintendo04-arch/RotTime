import DeviceActivity
import SwiftUI

/// DeviceActivityReport extension. Apple only exposes real usage data inside this
/// sandboxed extension: it renders views that the app embeds, but the numbers never
/// leave the extension. That is why RotTime's own statistics only use data it measured itself.
@main
struct RotTimeReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { summary in TotalActivityView(summary: summary) }
        WeeklyActivityReport { week in WeeklyActivityView(week: week) }
    }
}

extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
    static let weeklyActivity = Self("Weekly Activity")
}

// MARK: - Today

struct ActivitySummary {
    struct AppUsage: Identifiable {
        let id = UUID()
        let name: String
        let duration: TimeInterval
        let pickups: Int
    }
    var total: TimeInterval
    var pickups: Int
    var apps: [AppUsage]
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (ActivitySummary) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivitySummary {
        var total: TimeInterval = 0
        var pickups = 0
        var byApp: [String: (TimeInterval, Int)] = [:]
        for await device in data {
            for await segment in device.activitySegments {
                total += segment.totalActivityDuration
                for await category in segment.categories {
                    for await app in category.applications {
                        let name = app.application.localizedDisplayName ?? "Unknown app"
                        let existing = byApp[name] ?? (0, 0)
                        byApp[name] = (existing.0 + app.totalActivityDuration, existing.1 + app.numberOfPickups)
                        pickups += app.numberOfPickups
                    }
                }
            }
        }
        let apps = byApp.map { ActivitySummary.AppUsage(name: $0.key, duration: $0.value.0, pickups: $0.value.1) }
            .sorted { $0.duration > $1.duration }
        return ActivitySummary(total: total, pickups: pickups, apps: Array(apps.prefix(6)))
    }
}

struct TotalActivityView: View {
    let summary: ActivitySummary

    /// The goal the user set in RotTime (read-only access to the shared App Group).
    private var goalMinutes: Int {
        let group = (Bundle.main.object(forInfoDictionaryKey: "RTAppGroupIdentifier") as? String) ?? "group.com.rottime.app"
        let v = UserDefaults(suiteName: group)?.integer(forKey: "rt.phoneGoalMinutes") ?? 0
        return v > 0 ? v : 120
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Screen time today")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(format(summary.total))
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Pickups").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("\(summary.pickups)").font(.system(.title3, design: .rounded).weight(.bold))
                }
            }
            let goal = TimeInterval(goalMinutes * 60)
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    Capsule().fill(Color.primary.opacity(0.08))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(summary.total > goal ? Color(red: 0.89, green: 0.31, blue: 0.37) : Color(red: 1, green: 0.48, blue: 0.62))
                                .frame(width: max(8, geo.size.width * min(1, summary.total / max(goal, 1))))
                        }
                }
                .frame(height: 12)
                Text(summary.total > goal
                     ? "\(format(summary.total - goal)) over the \(format(goal)) you wanted"
                     : "\(format(goal - summary.total)) left of the \(format(goal)) you wanted")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if summary.apps.isEmpty {
                Text("No app activity recorded yet today.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                let maxDuration = max(summary.apps.first?.duration ?? 1, 1)
                ForEach(summary.apps) { app in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(app.name).font(.system(.subheadline, design: .rounded).weight(.semibold)).lineLimit(1)
                            Spacer()
                            Text(format(app.duration)).font(.system(.subheadline, design: .rounded)).foregroundStyle(.secondary)
                        }
                        GeometryReader { geo in
                            Capsule().fill(Color.primary.opacity(0.08))
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(LinearGradient(colors: [Color(red: 1, green: 0.48, blue: 0.62), Color(red: 1, green: 0.7, blue: 0.4)],
                                                             startPoint: .leading, endPoint: .trailing))
                                        .frame(width: max(6, geo.size.width * app.duration / maxDuration))
                                }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
        .padding(18)
    }

    private func format(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: interval) ?? "0m"
    }
}

// MARK: - Week

struct DailyUsage: Identifiable {
    let id = UUID()
    let day: Date
    let duration: TimeInterval
}

struct WeeklyActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .weeklyActivity
    let content: ([DailyUsage]) -> WeeklyActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> [DailyUsage] {
        var byDay: [Date: TimeInterval] = [:]
        let calendar = Calendar.current
        for await device in data {
            for await segment in device.activitySegments {
                let day = calendar.startOfDay(for: segment.dateInterval.start)
                byDay[day, default: 0] += segment.totalActivityDuration
            }
        }
        return byDay.map { DailyUsage(day: $0.key, duration: $0.value) }.sorted { $0.day < $1.day }
    }
}

struct WeeklyActivityView: View {
    let week: [DailyUsage]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Screen time this week")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
            let maxDuration = max(week.map(\.duration).max() ?? 1, 1)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(week) { day in
                    VStack(spacing: 6) {
                        Text(hours(day.duration)).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(colors: [Color(red: 0.62, green: 0.55, blue: 1), Color(red: 1, green: 0.48, blue: 0.62)],
                                                 startPoint: .bottom, endPoint: .top))
                            .frame(height: max(6, 110 * day.duration / maxDuration))
                        Text(day.day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 150, alignment: .bottom)
        }
        .padding(18)
    }

    private func hours(_ t: TimeInterval) -> String {
        t >= 3600 ? String(format: "%.1fh", t / 3600) : "\(Int(t / 60))m"
    }
}
