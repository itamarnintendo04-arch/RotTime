import SwiftUI

/// Every face the mascot can make.
enum BrainExpression: String, CaseIterable, Codable, Identifiable {
    case idle, happy, sleeping, surprised, tired, focused, celebrating, love, thinking, wink, proud, sad, sick, hurt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idle: return "Chill"
        case .happy: return "Happy"
        case .sleeping: return "Sleepy"
        case .surprised: return "Surprised"
        case .tired: return "Tired"
        case .focused: return "Focused"
        case .celebrating: return "Party"
        case .love: return "Love"
        case .thinking: return "Thinking"
        case .wink: return "Wink"
        case .proud: return "Proud"
        case .sad: return "Sad"
        case .sick: return "Sick"
        case .hurt: return "Ouch"
        }
    }
}

enum EyeStyle { case open, happyArc, closed, star, heart }
enum MouthStyle { case smile, grin, oh, wavy, tongue, tiny }

/// Numeric description of a face so expressions can blend smoothly.
struct FaceParams {
    var leftEye: EyeStyle = .open
    var rightEye: EyeStyle = .open
    var eyeScale: CGFloat = 1
    /// 0 = no lid, 1 = fully covered (used for tired / focused squints).
    var lid: CGFloat = 0
    var pupilScale: CGFloat = 1
    var look: CGPoint = .zero
    var browAlpha: CGFloat = 0
    /// Positive tilts inner brow ends down (determined), negative lifts them (worried/soft).
    var browTilt: CGFloat = 0
    var browLift: CGFloat = 0
    var mouth: MouthStyle = .smile
    var mouthCurve: CGFloat = 0.6
    var mouthOpen: CGFloat = 0.5
    var mouthWidth: CGFloat = 1
    var blush: CGFloat = 0.35
    var tilt: CGFloat = 0
    var sparkGlow: CGFloat = 0.6
    /// 0…1 green "under the weather" tint, droopy sprout, thermometer.
    var sickness: CGFloat = 0
    /// 0…1 tear drops.
    var tears: CGFloat = 0
    /// 0…1 band-aid on the head.
    var bandage: CGFloat = 0

    static func lerp(_ a: FaceParams, _ b: FaceParams, _ t: CGFloat) -> FaceParams {
        func l(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * t }
        var r = t < 0.5 ? a : b
        r.eyeScale = l(a.eyeScale, b.eyeScale)
        r.lid = l(a.lid, b.lid)
        r.pupilScale = l(a.pupilScale, b.pupilScale)
        r.look = CGPoint(x: l(a.look.x, b.look.x), y: l(a.look.y, b.look.y))
        r.browAlpha = l(a.browAlpha, b.browAlpha)
        r.browTilt = l(a.browTilt, b.browTilt)
        r.browLift = l(a.browLift, b.browLift)
        r.mouthCurve = l(a.mouthCurve, b.mouthCurve)
        r.mouthOpen = l(a.mouthOpen, b.mouthOpen)
        r.mouthWidth = l(a.mouthWidth, b.mouthWidth)
        r.blush = l(a.blush, b.blush)
        r.tilt = l(a.tilt, b.tilt)
        r.sparkGlow = l(a.sparkGlow, b.sparkGlow)
        r.sickness = l(a.sickness, b.sickness)
        r.tears = l(a.tears, b.tears)
        r.bandage = l(a.bandage, b.bandage)
        return r
    }
}

/// Idle personality chosen in customization.
enum ExpressionStyle: String, CaseIterable, Codable, Identifiable {
    case classic, cheeky, calm, starry
    var id: String { rawValue }
    var title: String {
        switch self {
        case .classic: return "Classic"
        case .cheeky: return "Cheeky"
        case .calm: return "Calm"
        case .starry: return "Starry-eyed"
        }
    }
}

extension BrainExpression {
    func face(style: ExpressionStyle) -> FaceParams {
        var f = FaceParams()
        switch self {
        case .idle:
            switch style {
            case .classic: break
            case .cheeky:
                f.mouth = .tongue; f.mouthCurve = 0.7; f.browAlpha = 1; f.browTilt = -0.15; f.browLift = 2
                f.rightEye = .happyArc
            case .calm:
                f.leftEye = .happyArc; f.rightEye = .happyArc; f.mouthCurve = 0.45; f.blush = 0.5
            case .starry:
                f.pupilScale = 1.15; f.eyeScale = 1.08; f.mouthCurve = 0.75; f.blush = 0.5
            }
        case .happy:
            f.leftEye = .happyArc; f.rightEye = .happyArc
            f.mouth = .grin; f.mouthOpen = 0.8; f.blush = 0.65; f.sparkGlow = 0.9
        case .sleeping:
            f.leftEye = .closed; f.rightEye = .closed
            f.mouth = .tiny; f.mouthOpen = 0.4; f.blush = 0.45; f.tilt = -0.06; f.sparkGlow = 0.15
        case .surprised:
            f.eyeScale = 1.22; f.pupilScale = 0.7; f.browAlpha = 1; f.browLift = 9
            f.mouth = .oh; f.mouthOpen = 1; f.blush = 0.2; f.sparkGlow = 1
        case .tired:
            f.lid = 0.5; f.browAlpha = 0.9; f.browTilt = -0.35; f.look = CGPoint(x: 0, y: 2.5)
            f.mouth = .wavy; f.mouthCurve = 0; f.mouthWidth = 0.7; f.blush = 0.2; f.tilt = 0.05; f.sparkGlow = 0.25
        case .focused:
            f.lid = 0.28; f.browAlpha = 1; f.browTilt = 0.35; f.look = CGPoint(x: 0, y: -1)
            f.mouth = .smile; f.mouthCurve = 0.15; f.mouthWidth = 0.75; f.blush = 0.15; f.sparkGlow = 1
        case .celebrating:
            f.leftEye = .star; f.rightEye = .star
            f.mouth = .grin; f.mouthOpen = 1; f.mouthWidth = 1.15; f.blush = 0.8; f.sparkGlow = 1
        case .love:
            f.leftEye = .heart; f.rightEye = .heart
            f.mouth = .smile; f.mouthCurve = 0.9; f.blush = 0.9; f.sparkGlow = 0.9
        case .thinking:
            f.look = CGPoint(x: 4, y: -4); f.browAlpha = 1; f.browTilt = -0.2; f.browLift = 3
            f.mouth = .smile; f.mouthCurve = -0.15; f.mouthWidth = 0.55; f.tilt = 0.04
        case .wink:
            f.rightEye = .happyArc; f.mouth = .tongue; f.mouthCurve = 0.8; f.blush = 0.6
        case .proud:
            f.leftEye = .happyArc; f.rightEye = .happyArc; f.browAlpha = 1; f.browLift = 4; f.browTilt = -0.1
            f.mouth = .smile; f.mouthCurve = 1; f.mouthWidth = 1.1; f.blush = 0.6; f.sparkGlow = 1
        case .sad:
            f.lid = 0.18; f.look = CGPoint(x: 0, y: 3); f.browAlpha = 1; f.browTilt = -0.55; f.browLift = 2
            f.mouth = .smile; f.mouthCurve = -0.75; f.mouthWidth = 0.8; f.blush = 0.15; f.tears = 1
            f.sparkGlow = 0.15; f.tilt = -0.04
        case .sick:
            f.lid = 0.48; f.look = CGPoint(x: 0, y: 2.5); f.browAlpha = 0.9; f.browTilt = -0.4
            f.mouth = .wavy; f.mouthWidth = 0.75; f.blush = 0; f.sickness = 1; f.sparkGlow = 0.05; f.tilt = 0.07
        case .hurt:
            f.leftEye = .closed; f.lid = 0.22; f.browAlpha = 1; f.browTilt = -0.45; f.browLift = 1
            f.mouth = .wavy; f.mouthWidth = 0.85; f.blush = 0.1; f.tears = 0.7; f.bandage = 1
            f.sickness = 0.35; f.sparkGlow = 0.1; f.tilt = -0.06
        }
        return f
    }

    /// Bounce/breathing energy for the animation loop.
    var motionEnergy: Double {
        switch self {
        case .sleeping, .sick: return 0.35
        case .tired, .sad: return 0.5
        case .hurt: return 0.6
        case .focused, .thinking: return 0.7
        case .happy, .love, .wink, .proud: return 1.25
        case .celebrating: return 1.8
        case .surprised: return 1.1
        case .idle: return 1
        }
    }
}

/// The mascot's overall condition, derived from real in-app progress.
enum BrainState: String, Codable {
    case energetic, slightlyTired, resting, recovered, sick

    var title: String {
        switch self {
        case .energetic: return "Energetic"
        case .slightlyTired: return "A little sleepy"
        case .resting: return "Resting"
        case .recovered: return "Glowing"
        case .sick: return "Feeling sick"
        }
    }

    var caption: String {
        switch self {
        case .energetic: return "Plenty of phone time left and a clear head. Let's keep it that way!"
        case .slightlyTired: return "Getting close to your phone goal… maybe put it down for a bit?"
        case .resting: return "Winding down. Rest is part of the plan."
        case .recovered: return "Under your phone goal and you focused today — glowing!"
        case .sick: return "Too much phone time made me feel awful. A focus session would heal me."
        }
    }

    var expression: BrainExpression {
        switch self {
        case .energetic: return .happy
        case .slightlyTired: return .tired
        case .resting: return .sleeping
        case .recovered: return .proud
        case .sick: return .sick
        }
    }

    var symbol: String {
        switch self {
        case .energetic: return "bolt.heart.fill"
        case .slightlyTired: return "cup.and.saucer.fill"
        case .resting: return "moon.stars.fill"
        case .recovered: return "sparkles"
        case .sick: return "thermometer.medium"
        }
    }
}
