import SwiftUI

/// Procedural vector renderer for Noodle, RotTime's brain mascot.
///
/// Everything is drawn in a 240×240 design space and scaled to the canvas, so the
/// character stays crisp at any size. Time (`t`) drives breathing, blinking, bouncing,
/// accessory motion and particle effects.
enum BrainRenderer {
    static let designSize: CGFloat = 240
    static let center = CGPoint(x: 120, y: 132)
    static let ink = Color(hex: 0x2B1F3A)
    static let mouthInk = Color(hex: 0x5A2140)
    static let tongue = Color(hex: 0xFF7A9C)

    struct Motion {
        var bob: CGFloat
        var jump: CGFloat
        var scaleX: CGFloat
        var scaleY: CGFloat
        var tilt: CGFloat
        var blink: CGFloat
        var armAngle: CGFloat
    }

    // MARK: Entry point

    static func draw(in context: inout GraphicsContext, size: CGSize, time rawTime: Double,
                     expression: BrainExpression, face: FaceParams, transition: Double,
                     appearance: BrainAppearance, showDecor: Bool = true) {
        let t = CGFloat(rawTime.truncatingRemainder(dividingBy: 3600))
        let scale = min(size.width, size.height) / designSize
        var ctx = context
        ctx.translateBy(x: (size.width - designSize * scale) / 2, y: (size.height - designSize * scale) / 2)
        ctx.scaleBy(x: scale, y: scale)

        let motion = makeMotion(t: t, expression: expression, face: face, transition: transition)
        let palette = appearance.color

        // Behind the character
        if appearance.effect == .aura { drawAura(&ctx, t: t, color: palette.base) }
        if showDecor { drawDecor(&ctx, appearance.decor, t: t) }
        drawShadow(&ctx, motion: motion)

        // Feet follow the jump but not the squash.
        var feet = ctx
        feet.translateBy(x: 0, y: motion.jump)
        drawFeet(&feet, palette: palette, t: t, expression: expression)

        // Body group pivots near the feet.
        var body = ctx
        body.translateBy(x: 120, y: 196 + motion.jump + motion.bob)
        body.rotate(by: .radians(Double(motion.tilt)))
        body.scaleBy(x: motion.scaleX, y: motion.scaleY)
        body.translateBy(x: -120, y: -196)

        drawArms(&body, palette: palette, angle: motion.armAngle)
        drawBody(&body, palette: palette, sickness: face.sickness)
        if !appearance.hat.hidesSprout { drawSprout(&body, t: t, glow: face.sparkGlow, droop: face.sickness) }
        drawFace(&body, face: face, palette: palette, motion: motion, t: t)
        drawAccessory(&body, appearance.accessory, palette: palette, t: t)
        drawHat(&body, appearance.hat, t: t)
        if face.bandage > 0.01 { drawBandage(&body, amount: face.bandage) }
        if face.sickness > 0.6 { drawThermometer(&body, t: t, amount: face.sickness) }

        // In front
        drawEffect(&ctx, appearance.effect, t: t, palette: palette)
        drawExpressionExtras(&ctx, expression: expression, t: t)
    }

    // MARK: Motion

    static func makeMotion(t: CGFloat, expression: BrainExpression, face: FaceParams, transition: Double) -> Motion {
        let e = CGFloat(expression.motionEnergy)
        let breathe = sin(t * 2.1 * max(e, 0.5)) * 0.022 * (expression == .sleeping ? 1.6 : 1)
        var bob = sin(t * 2.2 * e) * 2.5 * e
        var jump: CGFloat = 0
        switch expression {
        case .celebrating:
            jump = -abs(sin(t * 5.2)) * 16
            bob = 0
        case .happy, .love, .proud:
            jump = -abs(sin(t * 3.4)) * 5
        case .surprised:
            jump = transition < 1 ? -CGFloat(sin(transition * .pi)) * 14 : 0
        default: break
        }

        // Natural blink every ~4s, plus a blink that masks expression changes.
        let period: CGFloat = expression == .focused ? 5.5 : 4.2
        let phase = t.truncatingRemainder(dividingBy: period)
        var blink: CGFloat = phase < 0.16 ? 1 - sin(phase / 0.16 * .pi) : 1
        if phase > 1.1 && phase < 1.24 && Int(t / period) % 3 == 0 { // occasional double blink
            blink = min(blink, 1 - sin((phase - 1.1) / 0.14 * .pi))
        }
        if transition < 1 { blink = min(blink, 1 - CGFloat(sin(transition * .pi)) * 0.95) }

        let arm: CGFloat
        switch expression {
        case .celebrating: arm = -1.0 + sin(t * 10) * 0.5
        case .happy, .love: arm = -0.5 + sin(t * 7) * 0.35
        case .proud: arm = -0.2
        case .sleeping, .tired: arm = 0.45
        case .surprised: arm = -0.9
        default: arm = 0.15 + sin(t * 1.6) * 0.12
        }

        return Motion(bob: bob, jump: jump, scaleX: 1 - breathe * 0.6, scaleY: 1 + breathe,
                      tilt: face.tilt + sin(t * 1.1) * 0.025, blink: max(0.02, blink), armAngle: arm)
    }

    // MARK: Geometry helpers

    static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    static func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
    }

    static func local(_ ctx: GraphicsContext, at p: CGPoint, rotate: CGFloat = 0,
                      scale: CGSize = CGSize(width: 1, height: 1), _ body: (inout GraphicsContext) -> Void) {
        var c = ctx
        c.translateBy(x: p.x, y: p.y)
        if rotate != 0 { c.rotate(by: .radians(Double(rotate))) }
        if scale.width != 1 || scale.height != 1 { c.scaleBy(x: scale.width, y: scale.height) }
        body(&c)
    }

    static let roundStroke = StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
    static func stroke(_ w: CGFloat) -> StrokeStyle { StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round) }

    static func star(points: Int = 5, outer: CGFloat, inner: CGFloat) -> Path {
        var p = Path()
        for i in 0..<(points * 2) {
            let r = i.isMultiple(of: 2) ? outer : inner
            let a = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let pt = CGPoint(x: cos(a) * r, y: sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    static func sparkle(_ r: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -r))
        p.addQuadCurve(to: CGPoint(x: r, y: 0), control: CGPoint(x: r * 0.15, y: -r * 0.15))
        p.addQuadCurve(to: CGPoint(x: 0, y: r), control: CGPoint(x: r * 0.15, y: r * 0.15))
        p.addQuadCurve(to: CGPoint(x: -r, y: 0), control: CGPoint(x: -r * 0.15, y: r * 0.15))
        p.addQuadCurve(to: CGPoint(x: 0, y: -r), control: CGPoint(x: -r * 0.15, y: -r * 0.15))
        p.closeSubpath()
        return p
    }

    static func heart(_ s: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: s * 0.9))
        p.addCurve(to: CGPoint(x: -s, y: -s * 0.2), control1: CGPoint(x: -s * 0.4, y: s * 0.55), control2: CGPoint(x: -s, y: s * 0.25))
        p.addArc(center: CGPoint(x: -s * 0.5, y: -s * 0.25), radius: s * 0.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: s * 0.5, y: -s * 0.25), radius: s * 0.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: 0, y: s * 0.9), control1: CGPoint(x: s, y: s * 0.25), control2: CGPoint(x: s * 0.4, y: s * 0.55))
        p.closeSubpath()
        return p
    }

    static func fract(_ x: CGFloat) -> CGFloat { x - floor(x) }

    // MARK: Body

    struct Bump { let angle: CGFloat; let radius: CGFloat }
    static let bumps: [Bump] = [
        Bump(angle: -90, radius: 29), Bump(angle: -58, radius: 27), Bump(angle: -122, radius: 27),
        Bump(angle: -28, radius: 28), Bump(angle: -152, radius: 28), Bump(angle: 4, radius: 27),
        Bump(angle: 176, radius: 27), Bump(angle: 34, radius: 25), Bump(angle: 146, radius: 25),
    ]

    static func bodyPath(inset: CGFloat = 0) -> Path {
        var p = Path()
        let rx: CGFloat = 70, ry: CGFloat = 56
        p.addEllipse(in: CGRect(x: center.x - rx - inset, y: center.y - ry + 4 - inset,
                                width: (rx + inset) * 2, height: (ry + inset) * 2))
        for b in bumps {
            let a = b.angle * .pi / 180
            let c = CGPoint(x: center.x + cos(a) * rx * 0.8, y: center.y + sin(a) * ry * 0.8)
            p.addPath(circle(c, b.radius + inset))
        }
        return p
    }

    static func drawBody(_ ctx: inout GraphicsContext, palette: BodyColor, sickness: CGFloat = 0) {
        let outline = bodyPath(inset: 3.5)
        ctx.fill(outline, with: .color(palette.outline))
        let body = bodyPath()
        ctx.fill(body, with: .color(palette.base))

        ctx.drawLayer { layer in
            layer.clip(to: body)
            // Soft bottom shading
            layer.fill(Path(CGRect(x: 0, y: 60, width: 240, height: 150)),
                       with: .linearGradient(Gradient(colors: [palette.base.opacity(0), palette.shade.opacity(0.75)]),
                                             startPoint: CGPoint(x: 120, y: 120), endPoint: CGPoint(x: 120, y: 200)))
            // Folds
            let folds: [(CGPoint, CGPoint, CGPoint, CGPoint)] = [
                (CGPoint(x: 120, y: 62), CGPoint(x: 112, y: 76), CGPoint(x: 128, y: 86), CGPoint(x: 119, y: 100)),
                (CGPoint(x: 76, y: 82), CGPoint(x: 88, y: 74), CGPoint(x: 100, y: 84), CGPoint(x: 96, y: 96)),
                (CGPoint(x: 164, y: 82), CGPoint(x: 152, y: 74), CGPoint(x: 140, y: 84), CGPoint(x: 144, y: 96)),
                (CGPoint(x: 52, y: 110), CGPoint(x: 62, y: 100), CGPoint(x: 74, y: 108), CGPoint(x: 70, y: 120)),
                (CGPoint(x: 188, y: 110), CGPoint(x: 178, y: 100), CGPoint(x: 166, y: 108), CGPoint(x: 170, y: 120)),
                (CGPoint(x: 52, y: 150), CGPoint(x: 58, y: 162), CGPoint(x: 70, y: 160), CGPoint(x: 72, y: 172)),
                (CGPoint(x: 188, y: 150), CGPoint(x: 182, y: 162), CGPoint(x: 170, y: 160), CGPoint(x: 168, y: 172)),
                (CGPoint(x: 100, y: 70), CGPoint(x: 104, y: 64), CGPoint(x: 110, y: 66), CGPoint(x: 108, y: 74)),
                (CGPoint(x: 140, y: 70), CGPoint(x: 136, y: 64), CGPoint(x: 130, y: 66), CGPoint(x: 132, y: 74)),
            ]
            for f in folds {
                var p = Path()
                p.move(to: f.0)
                p.addCurve(to: f.3, control1: f.1, control2: f.2)
                layer.stroke(p, with: .color(palette.shade.opacity(0.85)), style: stroke(3.6))
            }
            // Glossy highlight
            local(layer, at: CGPoint(x: 86, y: 88), rotate: -0.45) { h in
                h.fill(ellipse(.zero, 17, 7), with: .color(.white.opacity(0.42)))
            }
            layer.fill(circle(CGPoint(x: 108, y: 80), 3.2), with: .color(.white.opacity(0.5)))
            // Under-the-weather green tint
            if sickness > 0.01 {
                layer.fill(Path(CGRect(x: 0, y: 0, width: 240, height: 240)),
                           with: .color(Color(hex: 0x9CCB5E).opacity(Double(sickness) * 0.45)))
            }
        }
    }

    static func drawBandage(_ ctx: inout GraphicsContext, amount: CGFloat) {
        var c = ctx
        c.opacity = Double(amount)
        for angle in [CGFloat(0.55), -0.55] {
            local(c, at: CGPoint(x: 150, y: 84), rotate: angle) { b in
                let strip = Path(roundedRect: CGRect(x: -20, y: -6, width: 40, height: 12), cornerRadius: 6)
                b.fill(strip, with: .color(Color(hex: 0xF5D3A8)))
                b.stroke(strip, with: .color(Color(hex: 0xB58A5A)), lineWidth: 2)
                b.fill(Path(roundedRect: CGRect(x: -6, y: -5, width: 12, height: 10), cornerRadius: 3), with: .color(Color(hex: 0xFFF1DE)))
            }
        }
    }

    static func drawThermometer(_ ctx: inout GraphicsContext, t: CGFloat, amount: CGFloat) {
        var c = ctx
        c.opacity = Double(min(1, (amount - 0.6) / 0.4))
        local(c, at: CGPoint(x: 130, y: 156), rotate: 0.45 + sin(t * 1.5) * 0.05) { th in
            let tube = Path(roundedRect: CGRect(x: 0, y: -3.5, width: 34, height: 7), cornerRadius: 3.5)
            th.fill(tube, with: .color(.white))
            th.stroke(tube, with: .color(Color(hex: 0x6B6478)), lineWidth: 1.8)
            th.fill(Path(roundedRect: CGRect(x: 14, y: -1.5, width: 18, height: 3), cornerRadius: 1.5), with: .color(Color(hex: 0xFF4F6E)))
            th.fill(circle(CGPoint(x: 34, y: 0), 5), with: .color(Color(hex: 0xFF4F6E)))
            th.stroke(circle(CGPoint(x: 34, y: 0), 5), with: .color(Color(hex: 0x6B6478)), lineWidth: 1.8)
        }
    }

    static func drawFeet(_ ctx: inout GraphicsContext, palette: BodyColor, t: CGFloat, expression: BrainExpression) {
        let tap: CGFloat = expression == .happy || expression == .celebrating ? sin(t * 9) * 2 : 0
        for (i, x) in [CGFloat(98), 142].enumerated() {
            let lift = i == 0 ? max(0, tap) : max(0, -tap)
            let foot = ellipse(CGPoint(x: x, y: 197 - lift), 15, 9)
            ctx.fill(foot, with: .color(palette.shade))
            ctx.stroke(foot, with: .color(palette.outline), lineWidth: 3)
        }
    }

    static func drawArms(_ ctx: inout GraphicsContext, palette: BodyColor, angle: CGFloat) {
        for side in [CGFloat(-1), 1] {
            let anchor = CGPoint(x: 120 + side * 64, y: 150)
            local(ctx, at: anchor, rotate: side * angle) { a in
                let arm = Path(roundedRect: CGRect(x: side < 0 ? -22 : 0, y: -7, width: 22, height: 14), cornerRadius: 7)
                a.fill(arm, with: .color(palette.base))
                a.stroke(arm, with: .color(palette.outline), lineWidth: 3)
            }
        }
    }

    static func drawShadow(_ ctx: inout GraphicsContext, motion: Motion) {
        let shrink = 1 + motion.jump / 40
        ctx.fill(ellipse(CGPoint(x: 120, y: 207), 54 * shrink, 7 * shrink), with: .color(.black.opacity(0.13)))
    }

    static func drawSprout(_ ctx: inout GraphicsContext, t: CGFloat, glow: CGFloat, droop: CGFloat = 0) {
        local(ctx, at: CGPoint(x: 120, y: 64), rotate: sin(t * 1.4) * 0.16 * (1 - droop * 0.7) + droop * 1.1) { s in
            var stem = Path()
            stem.move(to: .zero)
            stem.addCurve(to: CGPoint(x: 3, y: -28), control1: CGPoint(x: -6, y: -10), control2: CGPoint(x: 8, y: -18))
            s.stroke(stem, with: .color(Color(hex: 0x2F6B3A)), style: stroke(6.5))
            s.stroke(stem, with: .color(Color(hex: 0x7BD88F)), style: stroke(3.6))
            local(s, at: CGPoint(x: -1, y: -13), rotate: -0.7) { leaf in
                let l = ellipse(CGPoint(x: -7, y: 0), 8, 4.2)
                leaf.fill(l, with: .color(Color(hex: 0x7BD88F)))
                leaf.stroke(l, with: .color(Color(hex: 0x2F6B3A)), lineWidth: 2)
            }
            let orb = CGPoint(x: 3, y: -33)
            let pulse = 1 + sin(t * 3) * 0.08
            s.fill(circle(orb, 16 * pulse),
                   with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE680).opacity(Double(glow) * 0.8), .clear]),
                                         center: orb, startRadius: 2, endRadius: 16 * pulse))
            s.fill(circle(orb, 6.5), with: .color(Color(hex: 0xFFE27A)))
            s.stroke(circle(orb, 6.5), with: .color(Color(hex: 0xB8821C)), lineWidth: 2)
            s.fill(circle(CGPoint(x: orb.x - 2, y: orb.y - 2), 1.8), with: .color(.white))
        }
    }

    // MARK: Face

    static func drawFace(_ ctx: inout GraphicsContext, face: FaceParams, palette: BodyColor, motion: Motion, t: CGFloat) {
        // Blush
        for x in [CGFloat(74), 166] {
            ctx.fill(ellipse(CGPoint(x: x, y: 150), 13, 7.5), with: .color(Color(hex: 0xFF6F9A).opacity(Double(face.blush) * 0.75)))
        }

        var look = face.look
        if face.leftEye == .open && face.lid < 0.1 && face.look == .zero {
            look = CGPoint(x: sin(t * 0.55) * 2.4, y: sin(t * 0.83) * 1.3)
        }

        drawEye(&ctx, at: CGPoint(x: 96, y: 126), style: face.leftEye, face: face, look: look, blink: motion.blink, palette: palette, t: t)
        drawEye(&ctx, at: CGPoint(x: 144, y: 126), style: face.rightEye, face: face, look: look, blink: motion.blink, palette: palette, t: t)

        if face.browAlpha > 0.01 {
            let y = 103 - face.browLift
            for side in [CGFloat(-1), 1] {
                var b = Path()
                b.move(to: CGPoint(x: 120 + side * 36, y: y - face.browTilt * 4))
                b.addQuadCurve(to: CGPoint(x: 120 + side * 14, y: y + face.browTilt * 7),
                               control: CGPoint(x: 120 + side * 25, y: y - 4))
                ctx.stroke(b, with: .color(palette.outline.opacity(Double(face.browAlpha))), style: stroke(4))
            }
        }

        drawMouth(&ctx, face: face, palette: palette, t: t)

        if face.tears > 0.01 {
            for (i, x) in [CGFloat(90), 150].enumerated() {
                let ph = fract(t * 0.55 + CGFloat(i) * 0.45)
                var c = ctx
                c.opacity = Double(face.tears) * Double(1 - ph * 0.8)
                // streak
                var streak = Path()
                streak.move(to: CGPoint(x: x, y: 140)); streak.addLine(to: CGPoint(x: x - 1, y: 150))
                c.stroke(streak, with: .color(Color(hex: 0x7CC8FF).opacity(0.6)), style: stroke(3))
                // falling drop
                local(c, at: CGPoint(x: x - 1, y: 146 + ph * 34)) { d in
                    var drop = Path()
                    drop.move(to: CGPoint(x: 0, y: -6))
                    drop.addQuadCurve(to: CGPoint(x: 0, y: 5), control: CGPoint(x: 6, y: 3))
                    drop.addQuadCurve(to: CGPoint(x: 0, y: -6), control: CGPoint(x: -6, y: 3))
                    d.fill(drop, with: .color(Color(hex: 0x7CC8FF)))
                    d.fill(circle(CGPoint(x: -1.2, y: 1), 1.2), with: .color(.white.opacity(0.9)))
                }
            }
        }
    }

    static func drawEye(_ ctx: inout GraphicsContext, at c: CGPoint, style: EyeStyle, face: FaceParams,
                        look: CGPoint, blink: CGFloat, palette: BodyColor, t: CGFloat) {
        switch style {
        case .open:
            if blink < 0.18 {
                var p = Path()
                p.move(to: CGPoint(x: c.x - 12, y: c.y + 2))
                p.addQuadCurve(to: CGPoint(x: c.x + 12, y: c.y + 2), control: CGPoint(x: c.x, y: c.y + 7))
                ctx.stroke(p, with: .color(ink), style: stroke(4))
                return
            }
            local(ctx, at: c, scale: CGSize(width: face.eyeScale, height: face.eyeScale * blink)) { e in
                let sclera = ellipse(.zero, 14.5, 16.5)
                e.fill(sclera, with: .color(.white))
                let ps = face.pupilScale
                let irisCenter = CGPoint(x: look.x, y: look.y + 1)
                e.drawLayer { iris in
                    iris.clip(to: sclera)
                    iris.fill(ellipse(irisCenter, 11.5 * ps, 13.5 * ps),
                              with: .linearGradient(Gradient(colors: [ink, Color(hex: 0x5B4B8A)]),
                                                    startPoint: CGPoint(x: 0, y: -12), endPoint: CGPoint(x: 0, y: 14)))
                    iris.fill(circle(CGPoint(x: irisCenter.x - 3.8 * ps, y: irisCenter.y - 5 * ps), 4 * ps), with: .color(.white))
                    iris.fill(circle(CGPoint(x: irisCenter.x + 3.6 * ps, y: irisCenter.y + 4 * ps), 1.8 * ps), with: .color(.white.opacity(0.9)))
                    if face.lid > 0.01 {
                        let lidBottom = -16.5 + 33 * face.lid
                        iris.fill(Path(CGRect(x: -20, y: -20, width: 40, height: lidBottom + 20)), with: .color(palette.base))
                        var edge = Path()
                        edge.move(to: CGPoint(x: -16, y: lidBottom - 1))
                        edge.addQuadCurve(to: CGPoint(x: 16, y: lidBottom - 1), control: CGPoint(x: 0, y: lidBottom + 3))
                        iris.stroke(edge, with: .color(palette.outline), style: stroke(3))
                    }
                }
                e.stroke(sclera, with: .color(palette.outline.opacity(0.55)), lineWidth: 1.5)
            }
        case .happyArc:
            var p = Path()
            p.move(to: CGPoint(x: c.x - 12, y: c.y + 4))
            p.addQuadCurve(to: CGPoint(x: c.x + 12, y: c.y + 4), control: CGPoint(x: c.x, y: c.y - 13))
            ctx.stroke(p, with: .color(ink), style: stroke(4.5))
        case .closed:
            var p = Path()
            p.move(to: CGPoint(x: c.x - 12, y: c.y))
            p.addQuadCurve(to: CGPoint(x: c.x + 12, y: c.y), control: CGPoint(x: c.x, y: c.y + 9))
            ctx.stroke(p, with: .color(ink), style: stroke(4))
            // lashes
            for dx in [CGFloat(-8), 8] {
                var l = Path()
                l.move(to: CGPoint(x: c.x + dx, y: c.y + 4))
                l.addLine(to: CGPoint(x: c.x + dx * 1.3, y: c.y + 8))
                ctx.stroke(l, with: .color(ink), style: stroke(2.5))
            }
        case .star:
            local(ctx, at: c, rotate: sin(t * 3) * 0.2, scale: CGSize(width: 1 + sin(t * 8) * 0.06, height: 1 + sin(t * 8) * 0.06)) { s in
                let st = star(outer: 16, inner: 7.5)
                s.fill(st, with: .color(Color(hex: 0xFFD84D)))
                s.stroke(st, with: .color(ink), style: stroke(2.6))
                s.fill(circle(CGPoint(x: -3, y: -4), 2.4), with: .color(.white))
            }
        case .heart:
            let pulse = 1 + sin(t * 6) * 0.08
            local(ctx, at: CGPoint(x: c.x, y: c.y + 1), scale: CGSize(width: pulse, height: pulse)) { h in
                let hp = heart(14)
                h.fill(hp, with: .color(Color(hex: 0xFF4F7E)))
                h.stroke(hp, with: .color(Color(hex: 0x8C1F45)), style: stroke(2.4))
                h.fill(circle(CGPoint(x: -5, y: -4), 2.6), with: .color(.white.opacity(0.9)))
            }
        }
    }

    static func drawMouth(_ ctx: inout GraphicsContext, face: FaceParams, palette: BodyColor, t: CGFloat) {
        let c = CGPoint(x: 120, y: 152)
        switch face.mouth {
        case .smile, .tongue:
            let w = 13 * face.mouthWidth
            if face.mouth == .tongue {
                let tg = ellipse(CGPoint(x: c.x + 4, y: c.y + 4 + face.mouthCurve * 4), 5, 6)
                ctx.fill(tg, with: .color(tongue))
                ctx.stroke(tg, with: .color(mouthInk), lineWidth: 2)
            }
            var p = Path()
            p.move(to: CGPoint(x: c.x - w, y: c.y))
            p.addQuadCurve(to: CGPoint(x: c.x + w, y: c.y), control: CGPoint(x: c.x, y: c.y + 14 * face.mouthCurve))
            ctx.stroke(p, with: .color(ink), style: stroke(4))
        case .grin:
            let w = 15 * face.mouthWidth
            let h = 7 + 12 * face.mouthOpen
            var p = Path()
            p.move(to: CGPoint(x: c.x - w, y: c.y - 3))
            p.addQuadCurve(to: CGPoint(x: c.x + w, y: c.y - 3), control: CGPoint(x: c.x, y: c.y + 1))
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + h), control: CGPoint(x: c.x + w * 0.9, y: c.y + h))
            p.addQuadCurve(to: CGPoint(x: c.x - w, y: c.y - 3), control: CGPoint(x: c.x - w * 0.9, y: c.y + h))
            p.closeSubpath()
            ctx.fill(p, with: .color(mouthInk))
            ctx.drawLayer { m in
                m.clip(to: p)
                m.fill(ellipse(CGPoint(x: c.x, y: c.y + h - 1), w * 0.55, 6), with: .color(tongue))
            }
            ctx.stroke(p, with: .color(ink), style: stroke(3))
        case .oh:
            let o = ellipse(CGPoint(x: c.x, y: c.y + 4), 3 + 6 * face.mouthOpen, 4 + 8 * face.mouthOpen)
            ctx.fill(o, with: .color(mouthInk))
            ctx.stroke(o, with: .color(ink), lineWidth: 3)
        case .wavy:
            let w = 13 * face.mouthWidth
            var p = Path()
            p.move(to: CGPoint(x: c.x - w, y: c.y + 2))
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + 2), control: CGPoint(x: c.x - w / 2, y: c.y - 2))
            p.addQuadCurve(to: CGPoint(x: c.x + w, y: c.y + 2), control: CGPoint(x: c.x + w / 2, y: c.y + 6))
            ctx.stroke(p, with: .color(ink), style: stroke(3.6))
        case .tiny:
            let breathe = 1 + sin(t * 1.8) * 0.25
            let o = ellipse(CGPoint(x: c.x, y: c.y + 3), 3.4 * breathe, 4.2 * breathe)
            ctx.fill(o, with: .color(mouthInk))
        }
    }

    // MARK: Hats

    static func drawHat(_ ctx: inout GraphicsContext, _ hat: HatStyle, t: CGFloat) {
        let anchor = CGPoint(x: 120, y: 70)
        switch hat {
        case .none: break
        case .beanie:
            local(ctx, at: anchor) { h in
                var dome = Path()
                dome.move(to: CGPoint(x: -44, y: 6))
                dome.addCurve(to: CGPoint(x: 44, y: 6), control1: CGPoint(x: -46, y: -48), control2: CGPoint(x: 46, y: -48))
                dome.closeSubpath()
                h.fill(dome, with: .color(Color(hex: 0xFF6F7D)))
                h.stroke(dome, with: .color(Color(hex: 0x7A2E3A)), style: stroke(3))
                for x in stride(from: CGFloat(-30), through: 30, by: 12) {
                    var l = Path(); l.move(to: CGPoint(x: x * 0.8, y: -26)); l.addLine(to: CGPoint(x: x, y: 2))
                    h.stroke(l, with: .color(Color(hex: 0xE2505F)), style: stroke(2))
                }
                let band = Path(roundedRect: CGRect(x: -48, y: -2, width: 96, height: 17), cornerRadius: 8.5)
                h.fill(band, with: .color(Color(hex: 0xE2505F)))
                h.stroke(band, with: .color(Color(hex: 0x7A2E3A)), lineWidth: 3)
                let pom = circle(CGPoint(x: sin(t * 2) * 2, y: -40), 10)
                h.fill(pom, with: .color(Color(hex: 0xFFE7EC)))
                h.stroke(pom, with: .color(Color(hex: 0x7A2E3A)), lineWidth: 3)
            }
        case .party:
            local(ctx, at: CGPoint(x: 128, y: 72), rotate: 0.2) { h in
                var cone = Path()
                cone.move(to: CGPoint(x: -24, y: 4)); cone.addLine(to: CGPoint(x: 24, y: 4)); cone.addLine(to: CGPoint(x: 0, y: -60)); cone.closeSubpath()
                h.fill(cone, with: .color(Color(hex: 0x7ED3FF)))
                h.drawLayer { s in
                    s.clip(to: cone)
                    for i in 0..<5 {
                        var band = Path()
                        let y = CGFloat(-60 + i * 15)
                        band.addRect(CGRect(x: -30, y: y, width: 60, height: 6))
                        s.fill(band.applying(CGAffineTransform(rotationAngle: -0.3)), with: .color(Color(hex: 0xFFD45C)))
                    }
                }
                h.stroke(cone, with: .color(Color(hex: 0x245C80)), style: stroke(3))
                let pom = circle(CGPoint(x: 0, y: -62), 7)
                h.fill(pom, with: .color(Color(hex: 0xFF7AB8)))
                h.stroke(pom, with: .color(Color(hex: 0x8C1F55)), lineWidth: 2.5)
            }
        case .crown:
            local(ctx, at: CGPoint(x: 120, y: 66), rotate: sin(t * 1.5) * 0.04) { h in
                let pts: [CGPoint] = [CGPoint(x: -30, y: 8), CGPoint(x: -33, y: -18), CGPoint(x: -16, y: -4), CGPoint(x: 0, y: -27),
                                      CGPoint(x: 16, y: -4), CGPoint(x: 33, y: -18), CGPoint(x: 30, y: 8)]
                var p = Path(); p.addLines(pts); p.closeSubpath()
                h.fill(p, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFE98A), Color(hex: 0xF5B731)]),
                                                startPoint: CGPoint(x: 0, y: -26), endPoint: CGPoint(x: 0, y: 8)))
                h.stroke(p, with: .color(Color(hex: 0xA8740E)), style: stroke(3))
                for (pt, color) in [(CGPoint(x: 0, y: -1), 0xFF5C8A), (CGPoint(x: -18, y: 2), 0x5CC8FF), (CGPoint(x: 18, y: 2), 0x7EE08A)] {
                    h.fill(circle(pt, 4), with: .color(Color(hex: UInt32(color))))
                }
                for tip in [pts[1], pts[3], pts[5]] {
                    h.fill(circle(tip, 3.4), with: .color(Color(hex: 0xFFF3B0)))
                    h.stroke(circle(tip, 3.4), with: .color(Color(hex: 0xA8740E)), lineWidth: 1.8)
                }
                let glint = max(0, sin(t * 2.2))
                local(h, at: CGPoint(x: 10, y: -12), scale: CGSize(width: glint, height: glint)) { g in
                    g.fill(sparkle(6), with: .color(.white))
                }
            }
        case .wizard:
            local(ctx, at: CGPoint(x: 120, y: 72)) { h in
                let brim = ellipse(CGPoint(x: 0, y: 2), 56, 11)
                h.fill(brim, with: .color(Color(hex: 0x5B4FC7)))
                h.stroke(brim, with: .color(Color(hex: 0x2E2580)), lineWidth: 3)
                var cone = Path()
                cone.move(to: CGPoint(x: -32, y: 0))
                cone.addCurve(to: CGPoint(x: 18 + sin(t * 1.3) * 4, y: -82), control1: CGPoint(x: -20, y: -40), control2: CGPoint(x: -4, y: -70))
                cone.addCurve(to: CGPoint(x: 32, y: 0), control1: CGPoint(x: 10, y: -60), control2: CGPoint(x: 26, y: -30))
                cone.closeSubpath()
                h.fill(cone, with: .color(Color(hex: 0x6C5CE7)))
                h.stroke(cone, with: .color(Color(hex: 0x2E2580)), style: stroke(3))
                let band = Path(roundedRect: CGRect(x: -31, y: -12, width: 62, height: 10), cornerRadius: 4)
                h.fill(band, with: .color(Color(hex: 0xFFD45C)))
                for (p, r) in [(CGPoint(x: -6, y: -32), CGFloat(6)), (CGPoint(x: 8, y: -54), 4.2), (CGPoint(x: 12, y: -22), 3.2)] {
                    local(h, at: p, rotate: t * 0.6) { s in s.fill(star(outer: r, inner: r * 0.45), with: .color(Color(hex: 0xFFE27A))) }
                }
            }
        case .headphones:
            var band = Path()
            band.move(to: CGPoint(x: 46, y: 126))
            band.addCurve(to: CGPoint(x: 194, y: 126), control1: CGPoint(x: 44, y: 34), control2: CGPoint(x: 196, y: 34))
            ctx.stroke(band, with: .color(Color(hex: 0x3A3355)), style: stroke(10))
            ctx.stroke(band, with: .color(Color(hex: 0x8F86DB)), style: stroke(5))
            for x in [CGFloat(34), 186] {
                let cup = Path(roundedRect: CGRect(x: x, y: 108, width: 22, height: 38), cornerRadius: 11)
                ctx.fill(cup, with: .color(Color(hex: 0xFF8FB1)))
                ctx.stroke(cup, with: .color(Color(hex: 0x3A3355)), lineWidth: 3)
                ctx.fill(Path(roundedRect: CGRect(x: x + 6, y: 116, width: 10, height: 22), cornerRadius: 5), with: .color(Color(hex: 0xFFD1DF)))
            }
        case .flowerCrown:
            let colors: [UInt32] = [0xFFB3C7, 0xFFF1A8, 0xC9B6FF, 0xA8E6CF, 0xFFB3C7, 0xFFF1A8, 0xC9B6FF]
            for i in 0..<7 {
                let x = CGFloat(i - 3) * 15
                let y = 74 - cos(x / 52 * .pi / 2) * 14
                let leafAngle = CGFloat(i) * 0.9
                local(ctx, at: CGPoint(x: 120 + x + 7, y: y + 4), rotate: leafAngle) { l in
                    l.fill(ellipse(.zero, 6, 3), with: .color(Color(hex: 0x6FCB7A)))
                }
                local(ctx, at: CGPoint(x: 120 + x, y: y), rotate: t * 0.3 + CGFloat(i)) { f in
                    for k in 0..<5 {
                        let a = CGFloat(k) / 5 * 2 * .pi
                        f.fill(circle(CGPoint(x: cos(a) * 5, y: sin(a) * 5), 4.6), with: .color(Color(hex: colors[i])))
                    }
                    f.fill(circle(.zero, 3.4), with: .color(Color(hex: 0xFFC94D)))
                }
            }
        case .gradCap:
            local(ctx, at: CGPoint(x: 120, y: 70)) { h in
                let cap = Path(roundedRect: CGRect(x: -26, y: -6, width: 52, height: 18), cornerRadius: 5)
                h.fill(cap, with: .color(Color(hex: 0x3A3450)))
                h.stroke(cap, with: .color(Color(hex: 0x15111F)), lineWidth: 3)
                var board = Path()
                board.addLines([CGPoint(x: -48, y: -8), CGPoint(x: 0, y: -26), CGPoint(x: 48, y: -8), CGPoint(x: 0, y: 8)])
                board.closeSubpath()
                h.fill(board, with: .color(Color(hex: 0x2F2A44)))
                h.stroke(board, with: .color(Color(hex: 0x15111F)), style: stroke(3))
                let sway = sin(t * 2) * 3
                var tassel = Path()
                tassel.move(to: CGPoint(x: 0, y: -9))
                tassel.addLine(to: CGPoint(x: 36, y: -6))
                tassel.addLine(to: CGPoint(x: 38 + sway, y: 18))
                h.stroke(tassel, with: .color(Color(hex: 0xFFD45C)), style: stroke(2.6))
                h.fill(Path(roundedRect: CGRect(x: 34 + sway, y: 16, width: 8, height: 12), cornerRadius: 3), with: .color(Color(hex: 0xFFD45C)))
                h.fill(circle(CGPoint(x: 0, y: -9), 3), with: .color(Color(hex: 0xFFD45C)))
            }
        case .propeller:
            local(ctx, at: CGPoint(x: 120, y: 70)) { h in
                var dome = Path()
                dome.move(to: CGPoint(x: -40, y: 6))
                dome.addCurve(to: CGPoint(x: 40, y: 6), control1: CGPoint(x: -40, y: -36), control2: CGPoint(x: 40, y: -36))
                dome.closeSubpath()
                h.drawLayer { d in
                    d.clip(to: dome)
                    d.fill(Path(CGRect(x: -45, y: -40, width: 30, height: 50)), with: .color(Color(hex: 0xFF6F7D)))
                    d.fill(Path(CGRect(x: -15, y: -40, width: 30, height: 50)), with: .color(Color(hex: 0xFFD45C)))
                    d.fill(Path(CGRect(x: 15, y: -40, width: 30, height: 50)), with: .color(Color(hex: 0x5CC8FF)))
                }
                h.stroke(dome, with: .color(Color(hex: 0x2B2140)), style: stroke(3))
                let visor = ellipse(CGPoint(x: 26, y: 6), 22, 5)
                h.fill(visor, with: .color(Color(hex: 0x5CC8FF)))
                h.stroke(visor, with: .color(Color(hex: 0x2B2140)), lineWidth: 2.5)
                h.fill(Path(CGRect(x: -2, y: -36, width: 4, height: 10)), with: .color(Color(hex: 0x2B2140)))
                let spin = cos(t * 14)
                local(h, at: CGPoint(x: 0, y: -37), scale: CGSize(width: spin, height: 1)) { p in
                    p.fill(ellipse(CGPoint(x: -14, y: 0), 14, 4.5), with: .color(Color(hex: 0xFF6F7D)))
                    p.fill(ellipse(CGPoint(x: 14, y: 0), 14, 4.5), with: .color(Color(hex: 0x5CC8FF)))
                }
                h.fill(circle(CGPoint(x: 0, y: -37), 3.2), with: .color(Color(hex: 0xFFD45C)))
            }
        }
    }

    // MARK: Accessories

    static func drawAccessory(_ ctx: inout GraphicsContext, _ accessory: AccessoryStyle, palette: BodyColor, t: CGFloat) {
        switch accessory {
        case .none: break
        case .roundGlasses:
            let frame = Color(hex: 0x3A2E4F)
            for x in [CGFloat(96), 144] {
                ctx.fill(circle(CGPoint(x: x, y: 126), 20), with: .color(.white.opacity(0.14)))
                ctx.stroke(circle(CGPoint(x: x, y: 126), 20), with: .color(frame), lineWidth: 3.5)
            }
            var bridge = Path()
            bridge.move(to: CGPoint(x: 115, y: 124)); bridge.addQuadCurve(to: CGPoint(x: 125, y: 124), control: CGPoint(x: 120, y: 119))
            ctx.stroke(bridge, with: .color(frame), style: stroke(3))
            for (a, b) in [(CGPoint(x: 76, y: 122), CGPoint(x: 58, y: 116)), (CGPoint(x: 164, y: 122), CGPoint(x: 182, y: 116))] {
                var arm = Path(); arm.move(to: a); arm.addLine(to: b)
                ctx.stroke(arm, with: .color(frame), style: stroke(3))
            }
        case .sunglasses:
            for x in [CGFloat(73), 123] {
                let lens = Path(roundedRect: CGRect(x: x, y: 112, width: 44, height: 28), cornerRadius: 12)
                ctx.fill(lens, with: .linearGradient(Gradient(colors: [Color(hex: 0x2B2140), Color(hex: 0x4E3D7A)]),
                                                     startPoint: CGPoint(x: x, y: 112), endPoint: CGPoint(x: x, y: 140)))
                ctx.stroke(lens, with: .color(Color(hex: 0x15111F)), lineWidth: 3)
                var glare = Path(); glare.move(to: CGPoint(x: x + 9, y: 132)); glare.addLine(to: CGPoint(x: x + 20, y: 118))
                ctx.stroke(glare, with: .color(.white.opacity(0.55)), style: stroke(3))
            }
            var bridge = Path(); bridge.move(to: CGPoint(x: 117, y: 120)); bridge.addLine(to: CGPoint(x: 123, y: 120))
            ctx.stroke(bridge, with: .color(Color(hex: 0x15111F)), style: stroke(4))
        case .bowtie:
            local(ctx, at: CGPoint(x: 120, y: 180), rotate: sin(t * 2) * 0.05) { b in
                var left = Path(); left.addLines([CGPoint(x: -4, y: 0), CGPoint(x: -22, y: -11), CGPoint(x: -22, y: 11)]); left.closeSubpath()
                var right = Path(); right.addLines([CGPoint(x: 4, y: 0), CGPoint(x: 22, y: -11), CGPoint(x: 22, y: 11)]); right.closeSubpath()
                for p in [left, right] {
                    b.fill(p, with: .color(Color(hex: 0xFF5C8A)))
                    b.stroke(p, with: .color(Color(hex: 0x8C1F45)), style: stroke(2.8))
                }
                let knot = Path(roundedRect: CGRect(x: -6, y: -7, width: 12, height: 14), cornerRadius: 4)
                b.fill(knot, with: .color(Color(hex: 0xFF7FA3)))
                b.stroke(knot, with: .color(Color(hex: 0x8C1F45)), lineWidth: 2.5)
            }
        case .scarf:
            ctx.drawLayer { s in
                s.clip(to: bodyPath(inset: 4))
                s.fill(Path(CGRect(x: 30, y: 166, width: 180, height: 18)), with: .color(Color(hex: 0x4AB0F0)))
                for x in stride(from: CGFloat(40), through: 200, by: 16) {
                    s.fill(Path(CGRect(x: x, y: 166, width: 6, height: 18)), with: .color(.white.opacity(0.6)))
                }
            }
            local(ctx, at: CGPoint(x: 150, y: 176), rotate: 0.18 + sin(t * 1.8) * 0.06) { tail in
                let r = Path(roundedRect: CGRect(x: -8, y: 0, width: 17, height: 30), cornerRadius: 4)
                tail.fill(r, with: .color(Color(hex: 0x4AB0F0)))
                tail.stroke(r, with: .color(Color(hex: 0x1F5F8C)), lineWidth: 2.5)
                for k in 0..<4 {
                    var f = Path(); f.move(to: CGPoint(x: -6 + CGFloat(k) * 4.4, y: 30)); f.addLine(to: CGPoint(x: -6 + CGFloat(k) * 4.4, y: 36))
                    tail.stroke(f, with: .color(Color(hex: 0x1F5F8C)), style: stroke(2))
                }
            }
        case .sweatband:
            ctx.drawLayer { s in
                s.clip(to: bodyPath())
                s.fill(Path(CGRect(x: 30, y: 88, width: 180, height: 13)), with: .color(Color(hex: 0xFF6F7D)))
                s.fill(Path(CGRect(x: 30, y: 93, width: 180, height: 3)), with: .color(.white.opacity(0.85)))
            }
            local(ctx, at: CGPoint(x: 196, y: 96), rotate: 0.5 + sin(t * 3) * 0.15) { k in
                k.fill(Path(roundedRect: CGRect(x: 0, y: -4, width: 16, height: 8), cornerRadius: 4), with: .color(Color(hex: 0xFF6F7D)))
            }
        case .starClip:
            local(ctx, at: CGPoint(x: 78, y: 82), rotate: -0.3 + sin(t * 2) * 0.08) { s in
                let st = star(outer: 11, inner: 5)
                s.fill(st, with: .color(Color(hex: 0xFFD45C)))
                s.stroke(st, with: .color(Color(hex: 0xA8740E)), style: stroke(2.4))
            }
        }
    }

    // MARK: Decor (environment props)

    static func drawDecor(_ ctx: inout GraphicsContext, _ decor: DecorStyle, t: CGFloat) {
        let base = CGPoint(x: 212, y: 208)
        switch decor {
        case .none: break
        case .plant:
            for (i, a) in [CGFloat(-0.5), 0.05, 0.55].enumerated() {
                local(ctx, at: CGPoint(x: base.x, y: base.y - 18), rotate: a + sin(t * 1.2 + CGFloat(i)) * 0.06) { l in
                    let leaf = ellipse(CGPoint(x: 0, y: -13), 6, 13)
                    l.fill(leaf, with: .color(Color(hex: 0x6FCB7A)))
                    l.stroke(leaf, with: .color(Color(hex: 0x2F6B3A)), lineWidth: 2)
                }
            }
            var pot = Path()
            pot.addLines([CGPoint(x: base.x - 13, y: base.y - 20), CGPoint(x: base.x + 13, y: base.y - 20),
                          CGPoint(x: base.x + 10, y: base.y), CGPoint(x: base.x - 10, y: base.y)])
            pot.closeSubpath()
            ctx.fill(pot, with: .color(Color(hex: 0xE07A5F)))
            ctx.stroke(pot, with: .color(Color(hex: 0x7C3826)), style: stroke(2.5))
        case .books:
            let books: [(CGFloat, UInt32)] = [(30, 0x5CC8FF), (26, 0xFF7AA0), (28, 0xFFD45C)]
            for (i, b) in books.enumerated() {
                let r = Path(roundedRect: CGRect(x: base.x - b.0 / 2 + CGFloat(i % 2) * 2, y: base.y - CGFloat(i + 1) * 9, width: b.0, height: 9), cornerRadius: 2)
                ctx.fill(r, with: .color(Color(hex: b.1)))
                ctx.stroke(r, with: .color(Color(hex: 0x2B2140)), lineWidth: 2)
            }
        case .mug:
            let body = Path(roundedRect: CGRect(x: base.x - 11, y: base.y - 22, width: 22, height: 22), cornerRadius: 5)
            var handle = Path(); handle.addArc(center: CGPoint(x: base.x + 11, y: base.y - 11), radius: 6, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            ctx.stroke(handle, with: .color(Color(hex: 0x2B2140)), style: stroke(3))
            ctx.fill(body, with: .color(Color(hex: 0xFFF4E6)))
            ctx.stroke(body, with: .color(Color(hex: 0x2B2140)), lineWidth: 2.5)
            ctx.fill(heart(4).applying(CGAffineTransform(translationX: base.x, y: base.y - 11)), with: .color(Color(hex: 0xFF7AA0)))
            for k in 0..<2 {
                let ph = fract(t * 0.5 + CGFloat(k) * 0.5)
                var steam = Path()
                let x = base.x - 4 + CGFloat(k) * 8
                steam.move(to: CGPoint(x: x, y: base.y - 26 - ph * 10))
                steam.addCurve(to: CGPoint(x: x, y: base.y - 40 - ph * 10), control1: CGPoint(x: x - 5, y: base.y - 30 - ph * 10), control2: CGPoint(x: x + 5, y: base.y - 36 - ph * 10))
                ctx.stroke(steam, with: .color(.white.opacity(Double(1 - ph) * 0.8)), style: stroke(2.5))
            }
        case .lamp:
            ctx.fill(circle(CGPoint(x: base.x, y: base.y - 34), 22),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE680).opacity(0.5 + Double(sin(t * 2)) * 0.1), .clear]),
                                           center: CGPoint(x: base.x, y: base.y - 30), startRadius: 2, endRadius: 24))
            ctx.fill(Path(roundedRect: CGRect(x: base.x - 10, y: base.y - 4, width: 20, height: 4), cornerRadius: 2), with: .color(Color(hex: 0x2B2140)))
            ctx.fill(Path(CGRect(x: base.x - 1.5, y: base.y - 28, width: 3, height: 25)), with: .color(Color(hex: 0x2B2140)))
            var shade = Path()
            shade.addLines([CGPoint(x: base.x - 8, y: base.y - 44), CGPoint(x: base.x + 8, y: base.y - 44),
                            CGPoint(x: base.x + 14, y: base.y - 28), CGPoint(x: base.x - 14, y: base.y - 28)])
            shade.closeSubpath()
            ctx.fill(shade, with: .color(Color(hex: 0xFFC94D)))
            ctx.stroke(shade, with: .color(Color(hex: 0x2B2140)), style: stroke(2.5))
        case .mushroom:
            let glow = 0.4 + Double(sin(t * 1.6)) * 0.2
            ctx.fill(circle(CGPoint(x: base.x, y: base.y - 18), 22),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0xFF9AD5).opacity(glow), .clear]),
                                           center: CGPoint(x: base.x, y: base.y - 18), startRadius: 2, endRadius: 22))
            let stem = Path(roundedRect: CGRect(x: base.x - 5, y: base.y - 16, width: 10, height: 16), cornerRadius: 4)
            ctx.fill(stem, with: .color(Color(hex: 0xFFF4E6)))
            ctx.stroke(stem, with: .color(Color(hex: 0x2B2140)), lineWidth: 2)
            var cap = Path()
            cap.addArc(center: CGPoint(x: base.x, y: base.y - 15), radius: 15, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            cap.closeSubpath()
            ctx.fill(cap, with: .color(Color(hex: 0xFF7AA0)))
            ctx.stroke(cap, with: .color(Color(hex: 0x2B2140)), style: stroke(2.5))
            for p in [CGPoint(x: base.x - 6, y: base.y - 22), CGPoint(x: base.x + 6, y: base.y - 24), CGPoint(x: base.x, y: base.y - 18)] {
                ctx.fill(circle(p, 2.4), with: .color(.white))
            }
        case .crystal:
            let bob = sin(t * 1.8) * 3
            local(ctx, at: CGPoint(x: base.x, y: base.y - 22 + bob)) { c in
                var gem = Path()
                gem.addLines([CGPoint(x: 0, y: -18), CGPoint(x: 10, y: -6), CGPoint(x: 6, y: 14), CGPoint(x: -6, y: 14), CGPoint(x: -10, y: -6)])
                gem.closeSubpath()
                c.fill(gem, with: .linearGradient(Gradient(colors: [Color(hex: 0xBFF3FF), Color(hex: 0x7C9BFF)]),
                                                  startPoint: CGPoint(x: 0, y: -18), endPoint: CGPoint(x: 0, y: 14)))
                c.stroke(gem, with: .color(Color(hex: 0x2E3D8C)), style: stroke(2.4))
                var facet = Path(); facet.move(to: CGPoint(x: 0, y: -18)); facet.addLine(to: CGPoint(x: 0, y: 14))
                c.stroke(facet, with: .color(.white.opacity(0.6)), style: stroke(1.5))
            }
            ctx.fill(ellipse(CGPoint(x: base.x, y: base.y), 10, 3), with: .color(.black.opacity(0.12)))
        }
    }

    // MARK: Effects

    static func drawAura(_ ctx: inout GraphicsContext, t: CGFloat, color: Color) {
        let pulse = 0.5 + Double(sin(t * 1.4)) * 0.15
        ctx.fill(circle(CGPoint(x: 120, y: 130), 118),
                 with: .radialGradient(Gradient(colors: [color.opacity(pulse), color.opacity(0)]),
                                       center: CGPoint(x: 120, y: 130), startRadius: 40, endRadius: 118))
    }

    static func drawEffect(_ ctx: inout GraphicsContext, _ effect: EffectStyle, t: CGFloat, palette: BodyColor) {
        switch effect {
        case .none, .aura: break
        case .sparkles:
            let spots: [CGPoint] = [CGPoint(x: 28, y: 64), CGPoint(x: 210, y: 52), CGPoint(x: 220, y: 140),
                                    CGPoint(x: 22, y: 160), CGPoint(x: 170, y: 22), CGPoint(x: 64, y: 30)]
            for (i, p) in spots.enumerated() {
                let s = max(0, sin(t * 2.2 + CGFloat(i) * 1.3))
                local(ctx, at: p, rotate: t * 0.5, scale: CGSize(width: s, height: s)) { c in
                    c.fill(sparkle(9), with: .color(Color(hex: 0xFFF0A0)))
                }
            }
        case .hearts:
            for i in 0..<5 {
                let ph = fract(t * 0.22 + CGFloat(i) / 5)
                let x = 26 + CGFloat((i * 47) % 190) + sin(t * 1.5 + CGFloat(i)) * 8
                let y = 210 - ph * 190
                var c = ctx
                c.opacity = Double(sin(ph * .pi)) * 0.9
                local(c, at: CGPoint(x: x, y: y), rotate: sin(t + CGFloat(i)) * 0.3) { h in
                    h.fill(heart(7 + CGFloat(i % 3) * 2), with: .color(Color(hex: 0xFF6F9A)))
                }
            }
        case .bubbles:
            for i in 0..<8 {
                let ph = fract(t * 0.18 + CGFloat(i) * 0.125)
                let x = 20 + CGFloat((i * 61) % 200) + sin(t * 2 + CGFloat(i)) * 6
                let y = 220 - ph * 220
                let r = 4 + CGFloat(i % 4) * 2.5
                var c = ctx
                c.opacity = Double(sin(ph * .pi))
                c.stroke(circle(CGPoint(x: x, y: y), r), with: .color(.white.opacity(0.85)), lineWidth: 1.6)
                c.fill(circle(CGPoint(x: x - r * 0.35, y: y - r * 0.35), r * 0.25), with: .color(.white.opacity(0.9)))
            }
        case .notes:
            let glyphs = ["♪", "♫", "♪", "♬"]
            for i in 0..<4 {
                let ph = fract(t * 0.2 + CGFloat(i) * 0.25)
                let x: CGFloat = i.isMultiple(of: 2) ? 30 + sin(t + CGFloat(i)) * 10 : 210 + sin(t + CGFloat(i)) * 10
                var c = ctx
                c.opacity = Double(sin(ph * .pi))
                c.draw(Text(glyphs[i]).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(Color(hex: 0x8F86DB)),
                       at: CGPoint(x: x, y: 190 - ph * 150))
            }
        case .orbit:
            for i in 0..<3 {
                let a = t * 1.2 + CGFloat(i) * 2 * .pi / 3
                let p = CGPoint(x: 120 + cos(a) * 104, y: 136 + sin(a) * 26)
                let s = 0.7 + (sin(a) + 1) * 0.25
                local(ctx, at: p, rotate: t, scale: CGSize(width: s, height: s)) { c in
                    let st = star(outer: 8, inner: 3.6)
                    c.fill(st, with: .color(Color(hex: 0xFFD84D)))
                    c.stroke(st, with: .color(Color(hex: 0xA8740E)), lineWidth: 1.5)
                }
            }
        }
    }

    static func drawExpressionExtras(_ ctx: inout GraphicsContext, expression: BrainExpression, t: CGFloat) {
        switch expression {
        case .sleeping:
            for i in 0..<3 {
                let ph = fract(t * 0.32 + CGFloat(i) / 3)
                var c = ctx
                c.opacity = Double(sin(ph * .pi))
                let size = 14 + CGFloat(i) * 5
                c.draw(Text("z").font(.system(size: size, weight: .heavy, design: .rounded)).foregroundColor(Color(hex: 0x8F86DB)),
                       at: CGPoint(x: 172 + ph * 30 + sin(t * 2 + CGFloat(i)) * 4, y: 86 - ph * 60))
            }
        case .celebrating:
            let colors: [UInt32] = [0xFF6F9A, 0xFFD45C, 0x5CC8FF, 0x7EE08A, 0xC9B6FF, 0xFF9A5C]
            for i in 0..<30 {
                let fi = CGFloat(i)
                let ph = fract(t * 0.35 + fi * 0.137)
                let x = fract(fi * 0.618) * 240 + sin(t * 2 + fi) * 8
                let y = -10 + ph * 250
                local(ctx, at: CGPoint(x: x, y: y), rotate: t * 3 + fi, scale: CGSize(width: cos(t * 4 + fi), height: 1)) { c in
                    c.fill(Path(CGRect(x: -3, y: -5, width: 6, height: 10)), with: .color(Color(hex: colors[i % colors.count])))
                }
            }
        case .surprised:
            let pop = 0.8 + sin(t * 10) * 0.1
            for (p, a) in [(CGPoint(x: 70, y: 50), CGFloat(-0.6)), (CGPoint(x: 120, y: 30), 0), (CGPoint(x: 170, y: 50), 0.6)] {
                local(ctx, at: p, rotate: a, scale: CGSize(width: pop, height: pop)) { c in
                    var l = Path(); l.move(to: CGPoint(x: 0, y: -8)); l.addLine(to: CGPoint(x: 0, y: 6))
                    c.stroke(l, with: .color(Color(hex: 0xFFB84D)), style: stroke(4))
                }
            }
        case .thinking:
            for (i, r) in [CGFloat(3), 5, 8].enumerated() {
                let bob = sin(t * 2 + CGFloat(i)) * 2
                let p = CGPoint(x: 182 + CGFloat(i) * 10, y: 78 - CGFloat(i) * 14 + bob)
                ctx.fill(circle(p, r), with: .color(.white.opacity(0.9)))
                ctx.stroke(circle(p, r), with: .color(Color(hex: 0x8F86DB)), lineWidth: 1.5)
            }
        case .love:
            for i in 0..<3 {
                let ph = fract(t * 0.4 + CGFloat(i) / 3)
                var c = ctx
                c.opacity = Double(sin(ph * .pi))
                local(c, at: CGPoint(x: 60 + CGFloat(i) * 60, y: 60 - ph * 40), scale: CGSize(width: 0.6 + ph * 0.4, height: 0.6 + ph * 0.4)) { h in
                    h.fill(heart(8), with: .color(Color(hex: 0xFF4F7E)))
                }
            }
        case .focused:
            let p = 0.5 + sin(t * 3) * 0.5
            for side in [CGFloat(-1), 1] {
                var c = ctx
                c.opacity = Double(p) * 0.7
                var l = Path()
                l.move(to: CGPoint(x: 120 + side * 92, y: 100)); l.addLine(to: CGPoint(x: 120 + side * 104, y: 92))
                l.move(to: CGPoint(x: 120 + side * 96, y: 118)); l.addLine(to: CGPoint(x: 120 + side * 110, y: 116))
                c.stroke(l, with: .color(Color(hex: 0xFFB84D)), style: stroke(3))
            }
        case .sick:
            // Sweat drop and a little queasy swirl
            let bob = sin(t * 2) * 2
            local(ctx, at: CGPoint(x: 178, y: 92 + bob)) { d in
                var drop = Path()
                drop.move(to: CGPoint(x: 0, y: -8))
                drop.addQuadCurve(to: CGPoint(x: 0, y: 6), control: CGPoint(x: 8, y: 4))
                drop.addQuadCurve(to: CGPoint(x: 0, y: -8), control: CGPoint(x: -8, y: 4))
                d.fill(drop, with: .color(Color(hex: 0x9FE0FF)))
                d.stroke(drop, with: .color(Color(hex: 0x3D7FB0)), lineWidth: 1.5)
            }
            local(ctx, at: CGPoint(x: 62, y: 70), rotate: t * 2) { s in
                var swirl = Path()
                for k in 0..<40 {
                    let a = CGFloat(k) * 0.35
                    let r = CGFloat(k) / 40 * 10
                    let p = CGPoint(x: cos(a) * r, y: sin(a) * r)
                    if k == 0 { swirl.move(to: p) } else { swirl.addLine(to: p) }
                }
                s.stroke(swirl, with: .color(Color(hex: 0x7FB04A)), style: stroke(2.2))
            }
        case .hurt:
            // Seeing stars
            for i in 0..<3 {
                let a = t * 2.4 + CGFloat(i) * 2 * .pi / 3
                let p = CGPoint(x: 120 + cos(a) * 46, y: 52 + sin(a) * 10)
                local(ctx, at: p, rotate: t * 3) { c in
                    let st = star(outer: 7, inner: 3)
                    c.fill(st, with: .color(Color(hex: 0xFFD84D)))
                    c.stroke(st, with: .color(Color(hex: 0xA8740E)), lineWidth: 1.4)
                }
            }
        case .sad:
            // A tiny rain cloud
            let drift = sin(t * 0.8) * 4
            var cloud = Path()
            cloud.addEllipse(in: CGRect(x: 150 + drift, y: 34, width: 44, height: 18))
            cloud.addPath(circle(CGPoint(x: 164 + drift, y: 36), 10))
            cloud.addPath(circle(CGPoint(x: 180 + drift, y: 34), 12))
            ctx.fill(cloud, with: .color(Color(hex: 0x9AA3B8)))
            for k in 0..<3 {
                let ph = fract(t * 1.2 + CGFloat(k) * 0.33)
                var r = Path()
                let x = 160 + drift + CGFloat(k) * 10
                r.move(to: CGPoint(x: x, y: 54 + ph * 18)); r.addLine(to: CGPoint(x: x - 2, y: 60 + ph * 18))
                var c = ctx
                c.opacity = Double(1 - ph)
                c.stroke(r, with: .color(Color(hex: 0x7CC8FF)), style: stroke(2))
            }
        default:
            break
        }
    }
}
