import Foundation

/// Rule-based, context-aware conversation engine that runs fully on device.
final class LocalBrainResponder: BrainResponder {
    enum Intent: String, CaseIterable {
        case greeting, progress, motivation, rest, blocking, howItWorks, focus, streak, customize
        case stressed, bored, feelingGood, feelingLow, thanks, joke, identity, affection, scrolling
        case sleep, goal, privacy, bye, rewards, mindfulPause, rename, decline, affirm, unknown
    }

    private var lastVariant: [Intent: Int] = [:]

    /// Ordered: the first matching intent wins, so specific topics come before generic ones.
    private let keywords: [(Intent, [String])] = [
        (.privacy, ["privacy", "private", "data", "spy", "track me", "tracking", "my info"]),
        (.mindfulPause, ["mindful", "waiting period", "unlock an app", "open an app"]),
        (.rename, ["rename", "call you", "change your name"]),
        (.blocking, ["block", "shield", "restrict", "schedule", "limit", "sleep mode", "study mode", "lock"]),
        (.scrolling, ["scroll", "tiktok", "instagram", "youtube", "reels", "shorts", "doom", "addict", "can't stop", "cant stop", "phone"]),
        (.stressed, ["stress", "anxious", "anxiety", "overwhelm", "worried", "panic", "too much"]),
        (.bored, ["bored", "boring", "nothing to do"]),
        (.rest, ["break", "rest", "tired", "exhausted", "burnt", "burned out", "pause", "what else helps"]),
        (.sleep, ["sleep", "bed", "insomnia", "late", "bedtime"]),
        (.streak, ["streak"]),
        (.goal, ["goal", "target"]),
        (.rewards, ["reward", "unlock", "achievement", "points", "spark"]),
        (.customize, ["theme", "hat", "hats", "color", "colour", "customize", "customise", "outfit", "background", "accessor", "look"]),
        (.progress, ["progress", "how am i", "today", "stats", "how did i", "doing", "report"]),
        (.motivation, ["motivat", "inspire", "encourag", "lazy", "procrastinat", "can't start", "cant start", "not feeling"]),
        (.joke, ["joke", "funny", "laugh", "pun", "another", "something else"]),
        (.focus, ["focus", "pomodoro", "timer", "study", "concentrate", "work session", "homework", "back to work", "read"]),
        (.identity, ["who are you", "your name", "what are you", "are you real", "are you ai"]),
        (.affection, ["love you", "cute", "best", "adorable", "i like you"]),
        (.thanks, ["thank", "thanks", "thx", "ty", "appreciate", "that helped"]),
        (.decline, ["nah", "no", "nope", "maybe later", "not now"]),
        (.bye, ["bye", "good night", "goodnight", "see you", "gtg"]),
        (.feelingLow, ["sad", "bad day", "down", "meh", "not great", "awful", "lonely"]),
        (.feelingGood, ["good", "great", "awesome", "happy", "amazing", "fine", "nice", "ha", "haha", "relatable", "good point", "chatting"]),
        (.affirm, ["okay", "ok", "sure", "let's go", "lets go", "yes", "yeah", "yep", "challenge accepted"]),
        (.howItWorks, ["how does", "how do", "what can you", "help", "explain", "how to use", "rottime", "features"]),
        (.greeting, ["hi", "hello", "hey", "yo", "sup", "morning", "hiya", "howdy"]),
    ]

    func detect(_ text: String) -> Intent {
        let lower = " " + text.lowercased().replacingOccurrences(of: "’", with: "'") + " "
        for (intent, words) in keywords {
            for w in words {
                if w.count <= 4 {
                    // Short words must match as whole words ("hi" shouldn't match "this").
                    let pattern = "\\b\(NSRegularExpression.escapedPattern(for: w))\\b"
                    if lower.range(of: pattern, options: .regularExpression) != nil { return intent }
                } else if lower.contains(w) {
                    return intent
                }
            }
        }
        return .unknown
    }

    private func pick(_ intent: Intent, _ options: [BrainReply]) -> BrainReply {
        guard options.count > 1 else { return options[0] }
        var index = Int.random(in: 0..<options.count)
        if index == lastVariant[intent] { index = (index + 1) % options.count }
        lastVariant[intent] = index
        return options[index]
    }

    func reply(to message: String, context c: ChatContext, history: [ChatMessage]) async -> BrainReply {
        let intent = detect(message)
        let defaultReplies = ["How am I doing?", "Start focus", "Tell me a joke"]
        var r = respond(intent, c)
        if r.quickReplies.isEmpty { r.quickReplies = defaultReplies }
        return r
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func respond(_ intent: Intent, _ c: ChatContext) -> BrainReply {
        let b = c.brainName
        switch intent {
        case .greeting:
            return pick(intent, [
                BrainReply(bubbles: ["Hey\(c.nameSuffix)! 👋", "Good \(c.partOfDay). I've been doing little brain stretches while you were away."],
                           expression: .happy, quickReplies: ["How am I doing?", "I need motivation", "What can you do?"]),
                BrainReply(bubbles: ["Oh hi! You made my spark sprout wiggle. ✨", c.focusMinutesToday == 0 ? "Fresh day, clean slate. Want to start small?" : "We've already focused \(c.focusMinutesToday.minutesText) today. Nice!"],
                           expression: .love, actions: c.focusMinutesToday == 0 ? [.startFocus25] : [], quickReplies: ["Start focus", "Show my progress"]),
                BrainReply(bubbles: ["Hello hello! \(b) reporting for duty. 🫡"], expression: .wink,
                           quickReplies: ["How am I doing?", "Tell me a joke", "Help me focus"]),
            ])

        case .progress:
            var bubbles: [String] = []
            if c.focusMinutesToday == 0 {
                bubbles.append("No focus minutes yet today — and that's okay! Every streak starts at zero.")
                bubbles.append("A single 25-minute session would get us \(min(100, Int(Double(25) / Double(max(1, c.goalMinutes)) * 100)))% of the way to your goal.")
                return BrainReply(bubbles: bubbles, expression: .thinking, actions: [.startFocus25], quickReplies: ["Motivate me", "How does blocking work?"])
            }
            bubbles.append("Today: \(c.focusMinutesToday.minutesText) of focus across \(c.sessionsToday) session\(c.sessionsToday == 1 ? "" : "s").")
            if c.goalLeft == 0 {
                bubbles.append("Daily goal: DONE. I'm literally glowing right now. 🌟")
            } else {
                bubbles.append("Only \(c.goalLeft.minutesText) to go until your \(c.goalMinutes.minutesText) goal.")
            }
            if c.resistsToday > 0 { bubbles.append("And you chose focus on a shield \(c.resistsToday) time\(c.resistsToday == 1 ? "" : "s"). That's real willpower!") }
            if c.streak > 1 { bubbles.append("Streak: \(c.streak) days 🔥") }
            return BrainReply(bubbles: bubbles, expression: c.goalLeft == 0 ? .proud : .happy,
                              actions: c.goalLeft == 0 ? [.openStats] : [.startFocus25, .openStats],
                              quickReplies: ["Thanks!", "What about my streak?", "I need a break"])

        case .motivation:
            return pick(intent, [
                BrainReply(bubbles: ["Here's a secret: motivation usually shows up *after* you start, not before.", "Let's trick it. Just 5 honest minutes — if you want to stop after that, you can."],
                           expression: .focused, actions: [.startFocus25], quickReplies: ["Okay, let's go", "Still not feeling it"]),
                BrainReply(bubbles: ["Future you is going to be SO smug about this session. 😌", "Pick the tiniest next step. Open the doc. Write one line. I'll cheer."],
                           expression: .proud, actions: [.startFocus25], quickReplies: ["Start focus", "Tell me a joke first"]),
                BrainReply(bubbles: ["You don't need to feel ready. You just need to be a little curious.", "What's one thing that would make today feel like a win?"],
                           expression: .thinking, quickReplies: ["Finish homework", "Read a bit", "Just rest, honestly"]),
            ])

        case .rest:
            return pick(intent, [
                BrainReply(bubbles: ["Breaks aren't slacking — they're how brains save their progress. 💾", "Try 5 minutes: water, a stretch, and look at something far away."],
                           expression: .sleeping, actions: [.startBreak5], quickReplies: ["Thanks, I needed that", "What else helps?"]),
                BrainReply(bubbles: ["Ooh, a rest! My favourite activity after thinking.", "Phones down is the comfiest kind of break. Want me to time it?"],
                           expression: .happy, actions: [.startBreak5], quickReplies: ["Sure", "Maybe later"]),
            ])

        case .blocking:
            return BrainReply(bubbles: [
                c.isScreenTimeConnected
                    ? "Shields use Apple's real Screen Time system. Pick apps or sites, and iOS itself covers them with my friendly shield."
                    : "First, connect Screen Time in the Shields tab — Apple asks you to approve it once.",
                "You can block instantly, on a schedule (like Sleep Mode at night), during focus sessions, or after a daily time limit.",
                c.activeShieldNames.isEmpty ? "No shields are up right now." : "Active right now: \(c.activeShieldNames.joined(separator: ", ")).",
            ], expression: .focused, actions: [.openBlocking], quickReplies: ["What's a mindful pause?", "Is my data private?"])

        case .howItWorks:
            return BrainReply(bubbles: [
                "Here's what we do together:",
                "⏱ Focus timer — Pomodoro or custom sessions that keep running when you leave the app.\n🛡 Shields — real Screen Time blocking, with schedules and limits.\n📈 Progress — your streaks, goals and focus history.\n🎨 Me! Unlock themes, hats and effects by focusing.",
                "Ask me about any of those, or just chat. I'm a good listener (I'm mostly ears… well, folds).",
            ], expression: .happy, actions: [.openFocus, .openBlocking], quickReplies: ["How does blocking work?", "How do I unlock stuff?", "Is my data private?"])

        case .focus:
            return pick(intent, [
                BrainReply(bubbles: ["Focus time! My favourite. 🎯", "Classic is 25 minutes then a 5-minute break. For deep work, try 50/10."],
                           expression: .focused, actions: [.startFocus25, .startFocus50], quickReplies: ["What's Pomodoro?", "Can I block apps too?"]),
                BrainReply(bubbles: ["Let's pick one task — just one — and give it our full attention.", "I'll keep the shields up and the snacks imaginary."],
                           expression: .focused, actions: [.startFocus25], quickReplies: ["Okay!", "Block apps while I focus"]),
            ])

        case .streak:
            if c.streak == 0 {
                return BrainReply(bubbles: ["No streak yet — finish one focus session today and day one begins. 🌱"],
                                  expression: .thinking, actions: [.startFocus25], quickReplies: ["Let's start one", "How do streaks work?"])
            }
            return BrainReply(bubbles: ["You're on a \(c.streak)-day streak! 🔥", c.streak >= 7 ? "A whole week+ of focus. I'm framing this." : "Keep it alive with one session a day — any length that you complete counts."],
                              expression: .celebrating, quickReplies: ["How am I doing?", "What can I unlock?"])

        case .goal:
            return BrainReply(bubbles: ["Your daily goal is \(c.goalMinutes.minutesText) of focus.", c.goalLeft == 0 ? "And you've already hit it today!" : "\(c.goalLeft.minutesText) left today. You can change the goal in Settings anytime."],
                              expression: .proud, actions: c.goalLeft == 0 ? [] : [.startFocus25], quickReplies: ["How am I doing?", "Motivate me"])

        case .rewards:
            return BrainReply(bubbles: ["Everything is earned by focusing — no shops, no random boxes.", "You have \(c.points) spark points. Each focus minute is a point, and achievements give bonuses that unlock themes, hats and effects."],
                              expression: .wink, actions: [.openCustomize, .openStats], quickReplies: ["Show me hats!", "How am I doing?"])

        case .customize:
            return pick(intent, [
                BrainReply(bubbles: ["Ooh, a makeover? 💅", "Pick my colour, a hat, accessories, effects and a whole new world to live in."],
                           expression: .love, actions: [.openCustomize], quickReplies: ["How do I unlock more?"]),
                BrainReply(bubbles: ["I've been eyeing that wizard hat… just saying. 🧙"], expression: .wink, actions: [.openCustomize], quickReplies: ["How do I unlock it?"]),
            ])

        case .stressed:
            return pick(intent, [
                BrainReply(bubbles: ["That sounds like a lot. Let's slow down together.", "Breathe in for 4… hold for 4… out for 6. Again, once more.", "Now: what's the *one* smallest thing you could do next? Just that."],
                           expression: .idle, actions: [.startBreak5], quickReplies: ["That helped", "Still overwhelmed"]),
                BrainReply(bubbles: ["Hey. You don't have to fix everything today.", "Write the worries down, choose one, and give it a short, kind 15 minutes. The rest can wait."],
                           expression: .love, actions: [.openFocus], quickReplies: ["Okay", "I need a break"]),
            ])

        case .bored:
            return pick(intent, [
                BrainReply(bubbles: ["Boredom is your brain asking for something real. 🧠", "Try: a 10-minute walk, doodling, tidying one shelf, or texting a friend you miss."],
                           expression: .thinking, quickReplies: ["Tell me a joke", "Start focus instead"]),
                BrainReply(bubbles: ["Bored is actually where good ideas hatch! 🐣", "Sit with it for 2 minutes without your phone. I dare you. (Lovingly.)"],
                           expression: .wink, quickReplies: ["Challenge accepted", "Nah"]),
            ])

        case .feelingGood:
            return pick(intent, [
                BrainReply(bubbles: ["Yay! Good vibes detected. 📡✨", "Want to ride that energy into a quick focus session?"], expression: .happy, actions: [.startFocus25], quickReplies: ["Sure!", "Just chatting"]),
                BrainReply(bubbles: ["Love that for us. 💖"], expression: .love, quickReplies: ["How am I doing?", "Tell me a joke"]),
            ])

        case .feelingLow:
            return BrainReply(bubbles: ["I'm sorry today feels heavy. 💜", "You don't need to be productive to deserve rest. Want to do something gentle — music, water, a few deep breaths?", "If things feel really hard, please reach out to someone you trust. You matter a lot."],
                              expression: .love, actions: [.startBreak5], quickReplies: ["Thanks", "Talk about something else"])

        case .thanks:
            return pick(intent, [
                BrainReply(bubbles: ["Anytime! That's what brain buddies are for. 🧠💕"], expression: .love),
                BrainReply(bubbles: ["Aww. *happy wiggle*"], expression: .happy),
            ])

        case .joke:
            return pick(intent, [
                BrainReply(bubbles: ["Why did the brain go to school?", "To get a little *smarter* — it had a lot of grey areas. 🙃"], expression: .wink, quickReplies: ["Another one!", "Okay back to work"]),
                BrainReply(bubbles: ["What do you call a brain that scrolls all night?", "A *neuron-stop* feed. …I'll see myself out. 🚪"], expression: .happy, quickReplies: ["Another one!", "Ha!"]),
                BrainReply(bubbles: ["I tried to write a joke about focus…", "…but I got distracted halfway through."], expression: .thinking, quickReplies: ["Another one!", "Relatable"]),
                BrainReply(bubbles: ["Why don't brains ever get lost?", "Because they always use their *mind map*. 🗺️"], expression: .wink, quickReplies: ["Another one!", "Start focus"]),
            ])

        case .identity:
            return BrainReply(bubbles: ["I'm \(b)! A small, squishy brain with a spark sprout on top. 🌱✨", "I live on your phone, help you focus, and get very excited about streaks. I'm not a person or a doctor — just your friendly focus buddy."],
                              expression: .proud, quickReplies: ["What can you do?", "Can I rename you?"])

        case .affection:
            return BrainReply(bubbles: ["Stop it, I'm blushing. My folds are going pink. 💗"], expression: .love, quickReplies: ["How am I doing?", "Customize you"])

        case .scrolling:
            return pick(intent, [
                BrainReply(bubbles: ["Infinite feeds are built to be hard to put down — it's not a willpower failure.", "Let's make it easier: put those apps behind a shield, and I'll greet you with a pause before they open."],
                           expression: .thinking, actions: [.openBlocking], quickReplies: ["What's a mindful pause?", "Block apps at night"]),
                BrainReply(bubbles: ["Next time you reach for the feed, ask: what was I hoping to feel?", "Bored → walk. Lonely → text a friend. Tired → rest. The feed rarely fixes those."],
                           expression: .idle, actions: [.openBlocking], quickReplies: ["Good point", "Set up shields"]),
            ])

        case .sleep:
            return BrainReply(bubbles: ["Sleep is when I file away everything you learned today. 🗂️💤", "Sleep Mode can shield your scroll apps overnight so bedtime stays bedtime."],
                              expression: .sleeping, actions: [.openBlocking], quickReplies: ["Set up Sleep Mode", "Good night!"])

        case .privacy:
            return BrainReply(bubbles: ["Your data stays on your device. 🔒", "Apple doesn't even let me see *which* apps you pick — I only get anonymous tokens. Screen time numbers are shown by Apple's own report view, and they never leave it.", "I don't use a server, ads or trackers."],
                              expression: .proud, quickReplies: ["Nice!", "How does blocking work?"])

        case .bye:
            return pick(intent, [
                BrainReply(bubbles: ["Bye for now! I'll keep the sprout warm. 🌱"], expression: .wink),
                BrainReply(bubbles: [c.partOfDay == "night" ? "Sleep well! Dream of tidy inboxes. 🌙" : "See you soon! Go be awesome."], expression: c.partOfDay == "night" ? .sleeping : .happy),
            ])

        case .mindfulPause:
            return BrainReply(bubbles: [
                "A mindful pause is a speed bump, not a wall. 🐢",
                "On a shield, tap “Take a mindful pause”. I'll ask you to breathe for a few seconds. Tap again afterwards and that one app opens for a few minutes — then the shield comes back by itself.",
                "Strict sessions don't offer it, so you can lock in when you really mean it. You can tune the wait in Settings.",
            ], expression: .idle, actions: [.openBlocking], quickReplies: ["Nice!", "Is my data private?"])

        case .rename:
            return BrainReply(bubbles: ["Of course! Go to Settings → Brain name. I'll answer to anything cute. 🥹"],
                              expression: .love, quickReplies: ["What can you do?"])

        case .decline:
            return BrainReply(bubbles: ["No pressure at all. I'll be right here when you're ready. 🌱"], expression: .idle,
                              quickReplies: ["Tell me a joke", "How am I doing?"])

        case .affirm:
            if c.focusRunning {
                return BrainReply(bubbles: ["We're already in a session — keep going, you're doing great! 💪"], expression: .focused)
            }
            return pick(intent, [
                BrainReply(bubbles: ["Yesss! Tap below and I'll start the timer. 🚀"], expression: .happy, actions: [.startFocus25, .startFocus50]),
                BrainReply(bubbles: ["Love the energy. Ready when you are!"], expression: .proud, actions: [.startFocus25]),
            ])

        case .unknown:
            return pick(intent, [
                BrainReply(bubbles: ["Hmm, my folds are folding on that one. 🤔", "I'm best at focus, breaks, blocking and cheering you on. Want to try one?"],
                           expression: .thinking, quickReplies: ["How am I doing?", "Help me focus", "What can you do?"]),
                BrainReply(bubbles: ["Ooh, interesting! I'm a pretty small brain though.", "Ask me about your progress, focus sessions, shields or customizing me!"],
                           expression: .wink, quickReplies: ["Show my progress", "Customize you", "Tell me a joke"]),
            ])
        }
    }

    // MARK: Events

    func eventReply(_ event: ChatEvent, _ c: ChatContext) -> BrainReply {
        switch event {
        case .dailyWelcome:
            var bubbles = ["Good \(c.partOfDay)\(c.nameSuffix)! ☀️ Daily check-in time."]
            switch c.state {
            case .recovered: bubbles.append("You've already hit today's goal. Everything from here is bonus glow.")
            case .energetic: bubbles.append("I'm feeling bright and bouncy. Shall we plan a focus session?")
            case .slightlyTired: bubbles.append("I'm a little sleepy — a focus session would wake me right up.")
            case .resting: bubbles.append("It's quiet hours. Rest well, and we'll go again tomorrow.")
            }
            if c.streak > 0 { bubbles.append("Current streak: \(c.streak) day\(c.streak == 1 ? "" : "s") 🔥") }
            return BrainReply(bubbles: bubbles, expression: c.state.expression,
                              actions: c.state == .resting ? [] : [.startFocus25],
                              quickReplies: ["How am I doing?", "Motivate me", "What can you do?"])
        case .focusCompleted(let minutes):
            return BrainReply(bubbles: ["WOOHOO! \(minutes) minutes of focus! 🎉", c.goalLeft == 0 ? "That completes your daily goal. I'm overflowing with sparks!" : "Only \(c.goalLeft.minutesText) left for today's goal. Take a breather first."],
                              expression: .celebrating, actions: [.startBreak5, .openStats], quickReplies: ["Thanks!", "How am I doing?"])
        case .shieldResisted(let count):
            return BrainReply(bubbles: ["I saw that! You chose focus on the shield \(count == 1 ? "just now" : "\(count) times"). 💪", "That's the hardest part, and you did it."],
                              expression: .proud, quickReplies: ["Thanks!", "How am I doing?"])
        case .blockStarted(let name):
            return BrainReply(bubbles: ["\(name) is on. I'll stand guard at the door. 🛡️"], expression: .focused)
        case .streakMilestone(let days):
            return BrainReply(bubbles: ["\(days)-DAY STREAK! 🔥🔥🔥", "Consistency is a superpower and you have it."], expression: .celebrating, actions: [.openCustomize])
        case .goalReached:
            return BrainReply(bubbles: ["Daily goal reached! 🌟 I'm fully recharged."], expression: .proud, actions: [.openStats])
        }
    }
}
