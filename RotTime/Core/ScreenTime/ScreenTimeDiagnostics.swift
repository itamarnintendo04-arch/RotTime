import FamilyControls
import Foundation
import SwiftUI
import UIKit
import UserNotifications

/// Explains *why* Screen Time might not connect, by inspecting the installed build itself.
///
/// The most common cause is a build without the Family Controls entitlement (e.g. an
/// unsigned IPA re-signed with a free Apple account): iOS then refuses authorization no
/// matter what the app does. This check reads the embedded provisioning profile so the
/// user sees the real reason instead of a vague failure.
struct ScreenTimeDiagnostics {
    enum Level { case ok, warning, problem }

    struct Item: Identifiable {
        let id = UUID()
        let level: Level
        let title: String
        let detail: String
    }

    var items: [Item] = []

    static func run() async -> ScreenTimeDiagnostics {
        var d = ScreenTimeDiagnostics()
        #if targetEnvironment(simulator)
        d.items.append(Item(level: .warning, title: "Running in the Simulator",
                            detail: "Apple's Screen Time shields only work on a real iPhone or iPad."))
        #endif

        // 1. Entitlement inside the installed build
        if let profile = embeddedProfile() {
            let ent = profile["Entitlements"] as? [String: Any] ?? [:]
            let name = profile["Name"] as? String ?? "provisioning profile"
            if (ent["com.apple.developer.family-controls"] as? Bool) == true {
                d.items.append(Item(level: .ok, title: "Family Controls entitlement present",
                                    detail: "Signed with “\(name)”."))
            } else {
                d.items.append(Item(level: .problem, title: "Family Controls entitlement missing",
                                    detail: "This build was signed with “\(name)”, which doesn't include Family Controls. Enable it on the App ID in the Apple Developer portal, regenerate the profile and rebuild (see docs/SIGNING.md). Free Apple accounts can't get this entitlement."))
            }
            let groups = ent["com.apple.security.application-groups"] as? [String] ?? []
            if !groups.contains(AppGroup.identifier) {
                d.items.append(Item(level: .problem, title: "App Group not in profile",
                                    detail: "The profile doesn't include \(AppGroup.identifier), so the shield extensions can't share settings with the app."))
            }
            if let expiry = profile["ExpirationDate"] as? Date, expiry < Date().addingTimeInterval(3 * 86400) {
                d.items.append(Item(level: .warning, title: "Profile expires soon",
                                    detail: "It expires \(expiry.formatted(date: .abbreviated, time: .shortened)). Rebuild with a fresh profile."))
            }
        } else {
            #if !targetEnvironment(simulator)
            d.items.append(Item(level: .warning, title: "No embedded provisioning profile",
                                detail: "Normal for App Store / TestFlight builds. For anything else this usually means the app was re-signed without its entitlements, and Screen Time will refuse to connect."))
            #endif
        }

        // 2. App Group container
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil {
            d.items.append(Item(level: .ok, title: "App Group available", detail: AppGroup.identifier))
        } else {
            d.items.append(Item(level: .problem, title: "App Group unavailable",
                                detail: "\(AppGroup.identifier) isn't accessible. Shields, schedules and “more time” requests won't reach the extensions."))
        }

        // 3. Authorization state
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved:
            d.items.append(Item(level: .ok, title: "Screen Time access approved", detail: "RotTime can shield apps."))
        case .denied:
            d.items.append(Item(level: .problem, title: "Screen Time access denied",
                                detail: "Open Settings → Screen Time → Apps With Screen Time Access and turn RotTime on, then come back."))
        case .notDetermined:
            d.items.append(Item(level: .warning, title: "Not connected yet", detail: "Tap “Connect Screen Time” to approve access."))
        @unknown default:
            break
        }

        // 4. Notifications (needed for “I want more time” → open RotTime)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            d.items.append(Item(level: .ok, title: "Notifications on", detail: "The brain can call you from a shield."))
        } else {
            d.items.append(Item(level: .warning, title: "Notifications off",
                                detail: "Turn them on so tapping “I want more time” on a shield can bring you to the brain."))
        }
        return d
    }

    /// Parses embedded.mobileprovision (a CMS-signed plist) without private APIs.
    static func embeddedProfile() -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex) else { return nil }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        return (try? PropertyListSerialization.propertyList(from: plistData, format: nil)) as? [String: Any]
    }
}

struct ScreenTimeDiagnosticsView: View {
    @State private var result: ScreenTimeDiagnostics?
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @EnvironmentObject private var app: AppState

    var body: some View {
        List {
            if let result {
                Section {
                    ForEach(result.items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: symbol(item.level))
                                .foregroundStyle(color(item.level))
                                .font(.headline)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(RTFont.label(.bold))
                                Text(item.detail).font(RTFont.caption(.medium)).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            } else {
                ProgressView()
            }
            Section {
                Button("Connect Screen Time") {
                    Task {
                        await screenTime.requestAuthorization()
                        result = await ScreenTimeDiagnostics.run()
                    }
                }
                Button("Allow notifications") {
                    Task {
                        _ = await NotificationManager.requestAuthorization()
                        result = await ScreenTimeDiagnostics.run()
                    }
                }
                Button("Open iOS Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
        }
        .navigationTitle("Screen Time check")
        .task { result = await ScreenTimeDiagnostics.run() }
        .refreshable { result = await ScreenTimeDiagnostics.run() }
    }

    private func symbol(_ l: ScreenTimeDiagnostics.Level) -> String {
        switch l {
        case .ok: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .problem: return "xmark.octagon.fill"
        }
    }

    private func color(_ l: ScreenTimeDiagnostics.Level) -> Color {
        switch l {
        case .ok: return .green
        case .warning: return .orange
        case .problem: return .red
        }
    }
}
