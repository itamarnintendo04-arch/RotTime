import XCTest
@testable import RotTime

final class ScheduleTests: XCTestCase {
    private func date(weekday: Int, hour: Int, minute: Int) -> Date {
        // 2026-11-01 is a Sunday (weekday 1).
        var comps = DateComponents(year: 2026, month: 11, day: weekday, hour: hour, minute: minute)
        comps.calendar = Calendar(identifier: .gregorian)
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    func testDaytimeScheduleContains() {
        let s = BlockSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0, weekdays: Set(2...6))
        let cal = Calendar(identifier: .gregorian)
        XCTAssertTrue(s.contains(date(weekday: 2, hour: 10, minute: 0), calendar: cal))   // Monday 10:00
        XCTAssertFalse(s.contains(date(weekday: 1, hour: 10, minute: 0), calendar: cal))  // Sunday
        XCTAssertFalse(s.contains(date(weekday: 2, hour: 17, minute: 0), calendar: cal))  // end is exclusive
        XCTAssertEqual(s.durationMinutes, 480)
        XCTAssertFalse(s.crossesMidnight)
    }

    func testOvernightSchedule() {
        let s = BlockSchedule(startHour: 22, startMinute: 30, endHour: 7, endMinute: 0, weekdays: [6]) // Friday night
        let cal = Calendar(identifier: .gregorian)
        XCTAssertTrue(s.crossesMidnight)
        XCTAssertEqual(s.durationMinutes, 510)
        XCTAssertTrue(s.contains(date(weekday: 6, hour: 23, minute: 0), calendar: cal))  // Friday 23:00
        XCTAssertTrue(s.contains(date(weekday: 7, hour: 6, minute: 59), calendar: cal))  // Saturday early
        XCTAssertFalse(s.contains(date(weekday: 7, hour: 23, minute: 0), calendar: cal)) // Saturday night not scheduled
    }

    func testMinimumDeviceActivityLength() {
        XCTAssertFalse(BlockSchedule(startHour: 9, startMinute: 0, endHour: 9, endMinute: 10).isValidForDeviceActivity)
        XCTAssertTrue(BlockSchedule(startHour: 9, startMinute: 0, endHour: 9, endMinute: 15).isValidForDeviceActivity)
        XCTAssertFalse(BlockSchedule(startHour: 9, startMinute: 0, endHour: 10, endMinute: 0, weekdays: []).isValidForDeviceActivity)
    }

    func testActivityNameParsing() {
        let id = UUID()
        XCTAssertEqual(ActivityScheduler.modeID(fromActivity: "rt.mode.\(id.uuidString).d3"), id)
        XCTAssertEqual(ActivityScheduler.modeID(fromActivity: "rt.manual.\(id.uuidString)"), id)
        XCTAssertEqual(ActivityScheduler.modeID(fromActivity: "rt.limit.\(id.uuidString)"), id)
        XCTAssertNil(ActivityScheduler.modeID(fromActivity: "rt.focus"))
    }

    func testDefaultModesCoverAllKinds() {
        let kinds = Set(BlockMode.defaults.map(\.kind))
        XCTAssertEqual(kinds, Set(BlockModeKind.allCases))
    }

    func testBlockModeRoundTrip() throws {
        let mode = BlockMode.defaults[3]
        let data = try JSONEncoder().encode(mode)
        let decoded = try JSONDecoder().decode(BlockMode.self, from: data)
        XCTAssertEqual(decoded, mode)
    }
}

final class ChatEngineTests: XCTestCase {
    let responder = LocalBrainResponder()

    func testIntentDetection() {
        XCTAssertEqual(responder.detect("Hi!"), .greeting)
        XCTAssertEqual(responder.detect("How am I doing?"), .progress)
        XCTAssertEqual(responder.detect("How does blocking work?"), .blocking)
        XCTAssertEqual(responder.detect("Help me focus"), .focus)
        XCTAssertEqual(responder.detect("I need a break"), .rest)
        XCTAssertEqual(responder.detect("Tell me a joke"), .joke)
        XCTAssertEqual(responder.detect("What's a mindful pause?"), .mindfulPause)
        XCTAssertEqual(responder.detect("Is my data private?"), .privacy)
        XCTAssertEqual(responder.detect("I keep doomscrolling on tiktok"), .scrolling)
        XCTAssertEqual(responder.detect("This is interesting"), .unknown) // "this" ≠ "hi", "interesting" ≠ "rest"
        XCTAssertEqual(responder.detect("Show me hats!"), .customize)
    }

    func testEveryIntentProducesText() {
        let ctx = ChatContext(userName: "Sam", brainName: "Noodle", focusMinutesToday: 30, goalMinutes: 60, sessionsToday: 1,
                              streak: 2, resistsToday: 1, activeShieldNames: [], state: .energetic, hour: 10,
                              points: 50, isScreenTimeConnected: true, focusRunning: false)
        for intent in LocalBrainResponder.Intent.allCases {
            let reply = responder.respond(intent, ctx)
            XCTAssertFalse(reply.bubbles.isEmpty, "\(intent) has no reply")
            XCTAssertFalse(reply.bubbles.contains { $0.isEmpty })
        }
    }
}

final class RewardTests: XCTestCase {
    func testRequirementProgress() {
        var s = ProgressSnapshot()
        s.totalFocusMinutes = 30
        XCTAssertEqual(Requirement.focusMinutes(60).progress(s), 0.5, accuracy: 0.001)
        XCTAssertFalse(Requirement.focusMinutes(60).isMet(s))
        s.totalFocusMinutes = 90
        XCTAssertTrue(Requirement.focusMinutes(60).isMet(s))
        XCTAssertTrue(Requirement.free.isMet(ProgressSnapshot()))
    }

    func testCatalogIDsAreUnique() {
        let ids = RewardCatalog.cosmetics.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
        XCTAssertEqual(Theme.all.count, 10)
        XCTAssertEqual(Set(Theme.all.map(\.id)).count, 10)
        XCTAssertEqual(Set(Achievement.all.map(\.id)).count, Achievement.all.count)
    }

    func testEveryCategoryHasAFreeOption() {
        for category in CosmeticCategory.allCases {
            XCTAssertTrue(RewardCatalog.items(in: category).contains { $0.requirement == .free }, "\(category) has no free item")
        }
        XCTAssertTrue(Theme.all.contains { $0.requirement == .free })
    }
}

final class CharacterTests: XCTestCase {
    func testFaceBlendEndpoints() {
        let a = BrainExpression.idle.face(style: .classic)
        let b = BrainExpression.surprised.face(style: .classic)
        XCTAssertEqual(FaceParams.lerp(a, b, 0).eyeScale, a.eyeScale, accuracy: 0.0001)
        XCTAssertEqual(FaceParams.lerp(a, b, 1).eyeScale, b.eyeScale, accuracy: 0.0001)
        XCTAssertEqual(FaceParams.lerp(a, b, 1).mouth, b.mouth)
    }

    func testDayKeyRoundTrip() {
        let d = DayKey.date(from: "2026-11-25")!
        XCTAssertEqual(DayKey.string(for: d), "2026-11-25")
    }

    func testDurationFormatting() {
        XCTAssertEqual(TimeInterval(1500).clock, "25:00")
        XCTAssertEqual(TimeInterval(3725).clock, "1:02:05")
        XCTAssertEqual(90.minutesText, "1h 30m")
        XCTAssertEqual(45.minutesText, "45m")
    }
}

final class InterventionTests: XCTestCase {
    func testStyleNeverRepeatsTwiceInARow() {
        var previous = InterventionStyle.next()
        for _ in 0..<50 {
            let next = InterventionStyle.next()
            XCTAssertNotEqual(next, previous)
            previous = next
        }
    }

    func testDurationLinesExistForEveryOption() {
        for minutes in InterventionCenter.durations {
            XCTAssertFalse(InterventionCopy.durationLine(minutes).isEmpty)
        }
        let session = InterventionSession(request: nil, style: .chat)
        XCTAssertTrue(session.isPreview)
        XCTAssertTrue(session.grantedLine(10).contains("10"))
    }

    func testOldDayStatsStillDecode() throws {
        let old = #"{"focusSeconds":120,"focusSessions":1,"breaks":0,"blockSessions":0,"shieldResists":2,"mindfulUnlocks":0,"chatMessages":3}"#
        let stats = try JSONDecoder().decode(DayStats.self, from: Data(old.utf8))
        XCTAssertEqual(stats.shieldResists, 2)
        XCTAssertEqual(stats.extraMinutes, 0)
        XCTAssertEqual(stats.moreTimeDeclined, 0)
    }

    func testHurtAndHeal() {
        BrainHealth.heal()
        XCTAssertFalse(BrainHealth.isHurt)
        BrainHealth.hurt(forMinutes: 5)
        XCTAssertTrue(BrainHealth.isHurt)
        BrainHealth.heal()
        XCTAssertFalse(BrainHealth.isHurt)
    }

    func testSadFacesShowTearsOrSickness() {
        XCTAssertGreaterThan(BrainExpression.sad.face(style: .classic).tears, 0)
        XCTAssertGreaterThan(BrainExpression.sick.face(style: .classic).sickness, 0)
        XCTAssertGreaterThan(BrainExpression.hurt.face(style: .classic).bandage, 0)
    }
}

final class PhoneTimeTests: XCTestCase {
    func testUsageStepsIncludeGoalAndGoPastIt() {
        let steps = ActivityScheduler.usageSteps(goal: 95)
        XCTAssertTrue(steps.contains(95))
        XCTAssertEqual(steps.first, 10)
        XCTAssertGreaterThanOrEqual(steps.last ?? 0, 190)
        XCTAssertEqual(steps, steps.sorted())
        XCTAssertLessThanOrEqual(ActivityScheduler.usageSteps(goal: 720).count, 100)
    }

    func testOldProfileStillDecodes() throws {
        let old = #"{"userName":"Sam","brainName":"Noodle","dailyGoalMinutes":60,"weeklyGoalMinutes":300,"onboardingComplete":true,"hapticsEnabled":true,"ambientAnimations":true,"checkInReminderEnabled":false,"checkInHour":9,"checkInMinute":0,"themeID":"space"}"#
        let profile = try JSONDecoder().decode(UserProfile.self, from: Data(old.utf8))
        XCTAssertTrue(profile.onboardingComplete)
        XCTAssertEqual(profile.themeID, "space")
        XCTAssertEqual(profile.phoneGoalMinutes, 120)
    }
}

final class BrainMoodTests: XCTestCase {
    func testEveryBrainStateHasCopyAndFace() {
        let states: [BrainState] = [.energetic, .okay, .slightlyTired, .resting, .recovered, .sick, .verySick]
        for s in states {
            XCTAssertFalse(s.title.isEmpty)
            XCTAssertFalse(s.caption.isEmpty)
            _ = s.expression.face(style: .classic)
        }
    }
}
