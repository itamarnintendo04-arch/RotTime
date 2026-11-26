import AVFoundation
import FamilyControls
import Foundation
import ManagedSettings
import SwiftUI

/// Everything the brain says during a "more time" intervention. Lines are picked at
/// random each time so the conversation never feels canned.
enum InterventionCopy {
    static let greetings = [
        "Hey… it's me. 👀",
        "Psst. Got a second?",
        "Oh! Hi. I saw that. 🫣",
        "Knock knock. It's your brain.",
        "Wait wait wait — before you go…",
    ]

    static let asks = [
        "Do you really want to keep scrolling? Like… really really?",
        "The internet will still be there later. Do you actually want more right now? 🥺",
        "Before you dive back in — is this what you truly want to be doing?",
        "I can feel my folds going soft… Do we *have* to scroll more?",
        "You asked me to help with exactly this moment. So: more scrolling, really?",
        "What if we did literally anything else? Do you truly want more time?",
        "Be honest with me: is this fun, or just… a habit?",
    ]

    static let chooseIntros = [
        "Okay… if you're sure. How long?",
        "Hmm. How much time are we talking about?",
        "Fine… pick how much. (I'm watching. Sadly.)",
        "If you have to… how many minutes?",
    ]

    static let durationLines: [Int: [String]] = [
        5: ["Just 5? …I'll hold my breath.", "5 minutes. I'll count every second. 😣", "Five. Tiny. Promise it's tiny?"],
        10: ["10 minutes… my head is already spinning.", "Ten whole minutes? I'll be lying down.", "10… I'm getting dizzy just thinking about it."],
        30: ["Half an hour?! I need to sit down. 🤒", "30 minutes… I might need a bandage.", "Thirty. Please don't make me watch."],
    ]

    static let declineButtons = [
        "Actually, I don't want to",
        "No — I'll stop here",
        "You're right, I don't want to",
        "Never mind, I'm good",
    ]

    static let declines = [
        "YES! You're my hero. 🦸 I feel stronger already!",
        "I knew it! So proud of you. Let's do something better.",
        "Phew! My sprout is glowing again ✨",
        "That was the hardest part, and you did it! 💪",
        "Best decision of the day. I'm doing a happy wiggle.",
    ]

    static let granted = [
        "Ow… my head really hurts now. 🤕 Okay, %d minutes. I'll be here with my thermometer.",
        "I don't feel so good… 🤒 Enjoy your %d minutes, I guess.",
        "*cough cough* It's fine. I'm fine. %d minutes. …I'm not fine. 😢",
        "My folds are aching. 😣 %d minutes, then please come back to me.",
        "Okay… %d minutes. I'm going to lie down and feel sad for a bit. 🥀",
    ]

    static func line(_ list: [String]) -> String { list.randomElement() ?? list[0] }

    static func durationLine(_ minutes: Int) -> String { line(durationLines[minutes] ?? durationLines[10]!) }
}

enum InterventionPhase: Equatable {
    case intro, ask, choose, granted(Int), declined
}

struct InterventionSession: Identifiable {
    let id = UUID()
    let request: MoreTimeRequest?
    var freeApp: DistractingApp? = nil
    let style: InterventionStyle
    let greeting = InterventionCopy.line(InterventionCopy.greetings)
    let ask = InterventionCopy.line(InterventionCopy.asks)
    let chooseIntro = InterventionCopy.line(InterventionCopy.chooseIntros)
    let declineLabel = InterventionCopy.line(InterventionCopy.declineButtons)
    let declineLine = InterventionCopy.line(InterventionCopy.declines)
    let grantedTemplate = InterventionCopy.line(InterventionCopy.granted)
    /// Previews (from Settings) don't unlock anything or touch stats.
    var isPreview: Bool { request == nil && freeApp == nil }

    func grantedLine(_ minutes: Int) -> String { String(format: grantedTemplate, minutes) }
}

/// Presents the intervention when a "more time" request arrives and applies the outcome.
@MainActor
final class InterventionCenter: ObservableObject {
    static let shared = InterventionCenter()

    @Published var session: InterventionSession?
    static let durations = [5, 10, 30]

    /// Opens the most recent unhandled request, if any.
    func presentPendingIfNeeded(requestID: String? = nil) {
        guard session == nil, AppState.shared.profile.onboardingComplete else { return }
        // Free mode: a Shortcuts automation asked Noodle to step in.
        if let app = FreeUsageStore.pendingApp {
            FreeUsageStore.pendingApp = nil
            session = InterventionSession(request: nil, freeApp: app, style: InterventionStyle.next())
            return
        }
        let pending = MoreTimeRequests.pending
        let request = requestID.flatMap { id in pending.first { $0.id.uuidString == id } } ?? MoreTimeRequests.latest
        guard let request else { return }
        session = InterventionSession(request: request, style: request.style)
    }

    func preview(style: InterventionStyle? = nil) {
        session = InterventionSession(request: nil, style: style ?? InterventionStyle.next())
    }

    func decline(_ s: InterventionSession) {
        Haptics.success(AppState.shared.profile.hapticsEnabled)
        if s.freeApp != nil {
            SharedStore.updateToday { $0.moreTimeDeclined += 1; $0.shieldResists += 1 }
            AppState.shared.refreshShared()
            AppState.shared.evaluateRewards()
            return
        }
        guard let request = s.request else { return }
        MoreTimeRequests.resolve(request.id)
        SharedStore.updateToday { $0.moreTimeDeclined += 1; $0.shieldResists += 1 }
        AppState.shared.refreshShared()
        AppState.shared.evaluateRewards()
    }

    func grant(_ s: InterventionSession, minutes: Int) {
        Haptics.warning(AppState.shared.profile.hapticsEnabled)
        if let app = s.freeApp {
            FreeUsageStore.allow(app, minutes: minutes)
            SharedStore.updateToday { $0.mindfulUnlocks += 1; $0.extraMinutes += minutes }
            BrainHealth.hurt(forMinutes: minutes)
            NotificationManager.scheduleAllowanceEnd(app: app.name, minutes: minutes, brainName: AppState.shared.brainName)
            AppState.shared.refreshShared()
            return
        }
        guard let request = s.request else { return }
        MoreTimeRequests.resolve(request.id)
        let unlocked = ShieldController.grantTemporaryUnlock(application: request.applicationToken,
                                                            webDomain: request.webDomainToken,
                                                            category: request.categoryToken,
                                                            minutes: minutes)
        if unlocked {
            SharedStore.updateToday { $0.mindfulUnlocks += 1; $0.extraMinutes += minutes }
            BrainHealth.hurt(forMinutes: minutes)
        }
        ScreenTimeManager.shared.refresh()
        AppState.shared.refreshShared()
    }

    /// "I changed my mind" after granting: put the shield straight back.
    func takeBack(_ s: InterventionSession) {
        Haptics.success(AppState.shared.profile.hapticsEnabled)
        guard !s.isPreview else { return }
        if let app = s.freeApp {
            FreeUsageStore.revokeAllowance(app)
            NotificationManager.cancelAllowanceEnd()
            BrainHealth.heal()
            SharedStore.updateToday { $0.moreTimeDeclined += 1 }
            AppState.shared.refreshShared()
            return
        }
        ShieldController.revokeTemporaryUnlocks()
        BrainHealth.heal()
        SharedStore.updateToday { $0.moreTimeDeclined += 1 }
        ScreenTimeManager.shared.refresh()
        AppState.shared.refreshShared()
    }

    func finish(openApp: DistractingApp? = nil) {
        Speaker.shared.stop()
        session = nil
        if let openApp {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { openApp.open() }
        }
    }
}

/// Gives the brain a (cute, high-pitched) voice for calls and voice messages.
final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var muted = false

    override init() {
        super.init()
        synth.delegate = self
    }

    func say(_ text: String) {
        guard !muted else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        synth.stopSpeaking(at: .immediate)
        let clean = text.replacingOccurrences(of: "*", with: "")
        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.pitchMultiplier = 1.55
        utterance.rate = 0.5
        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = true }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}
