import SwiftUI

/// Full-bleed illustrated background for a theme, with optional ambient animation.
struct ThemeBackgroundView: View {
    var theme: Theme
    var animated: Bool = true
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated || reduceMotion)) { timeline in
            Canvas { context, size in
                let t = animated && !reduceMotion ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600) : 12
                ThemeArt.draw(theme.id, in: &context, size: size, t: CGFloat(t), dark: scheme == .dark)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

enum ThemeArt {
    // MARK: Helpers

    static func rnd(_ i: Int, _ salt: Int = 0) -> CGFloat {
        let v = sin(Double(i * 127 + salt * 311) * 12.9898) * 43758.5453
        return CGFloat(v - floor(v))
    }

    static func fract(_ x: CGFloat) -> CGFloat { x - floor(x) }

    static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    static func sky(_ ctx: inout GraphicsContext, _ size: CGSize, _ colors: [Color]) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: colors), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
    }

    static func hills(_ ctx: inout GraphicsContext, _ size: CGSize, baseY: CGFloat, amplitude: CGFloat,
                      frequency: CGFloat, phase: CGFloat, color: Color) {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: size.height))
        let steps = 40
        for i in 0...steps {
            let x = size.width * CGFloat(i) / CGFloat(steps)
            let y = baseY + sin(x / size.width * .pi * frequency + phase) * amplitude
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: size.width, y: size.height))
        p.closeSubpath()
        ctx.fill(p, with: .color(color))
    }

    static func stars(_ ctx: inout GraphicsContext, _ size: CGSize, count: Int, t: CGFloat, maxY: CGFloat, color: Color = .white) {
        for i in 0..<count {
            let x = rnd(i, 1) * size.width
            let y = rnd(i, 2) * maxY
            let r = 0.6 + rnd(i, 3) * 1.6
            let tw = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * (1 + rnd(i, 4) * 2) + rnd(i, 5) * 6))
            ctx.fill(circle(CGPoint(x: x, y: y), r), with: .color(color.opacity(Double(tw))))
        }
    }

    static func cloud(_ ctx: inout GraphicsContext, at c: CGPoint, scale s: CGFloat, color: Color) {
        var p = Path()
        p.addEllipse(in: CGRect(x: c.x - 50 * s, y: c.y - 12 * s, width: 100 * s, height: 30 * s))
        p.addPath(circle(CGPoint(x: c.x - 18 * s, y: c.y - 10 * s), 20 * s))
        p.addPath(circle(CGPoint(x: c.x + 14 * s, y: c.y - 16 * s), 26 * s))
        p.addPath(circle(CGPoint(x: c.x + 38 * s, y: c.y - 2 * s), 14 * s))
        ctx.fill(p, with: .color(color))
    }

    // MARK: Dispatcher

    static func draw(_ id: String, in ctx: inout GraphicsContext, size: CGSize, t: CGFloat, dark: Bool) {
        switch id {
        case "space": space(&ctx, size, t)
        case "ocean": ocean(&ctx, size, t)
        case "forest": forest(&ctx, size, t)
        case "candy": candy(&ctx, size, t)
        case "neon": neon(&ctx, size, t)
        case "dream": dream(&ctx, size, t)
        case "sunset": sunset(&ctx, size, t)
        case "winter": winter(&ctx, size, t)
        case "minimal": minimal(&ctx, size, t, dark: dark)
        default: cozy(&ctx, size, t, dark: dark)
        }
    }

    // MARK: Cozy Room

    static func cozy(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: CGFloat, dark: Bool) {
        let w = size.width, h = size.height
        sky(&ctx, size, dark ? [Color(hex: 0x3B2A2F), Color(hex: 0x5A3A3A)] : [Color(hex: 0xFFE9D2), Color(hex: 0xF6C29C)])
        // Wallpaper dots
        for i in 0..<60 {
            let x = CGFloat(i % 8) / 8 * w + (i / 8 % 2 == 0 ? 0 : w / 16) + 10
            let y = CGFloat(i / 8) / 8 * h * 0.75 + 20
            ctx.fill(circle(CGPoint(x: x, y: y), 2.2), with: .color(Color.white.opacity(dark ? 0.05 : 0.35)))
        }
        // Window
        let win = CGRect(x: w * 0.58, y: h * 0.1, width: w * 0.32, height: h * 0.22)
        ctx.fill(Path(roundedRect: win, cornerRadius: 14), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x2B2A6B), Color(hex: 0x6B5BD6)]),
            startPoint: CGPoint(x: win.midX, y: win.minY), endPoint: CGPoint(x: win.midX, y: win.maxY)))
        var winCtx = ctx
        winCtx.clip(to: Path(roundedRect: win, cornerRadius: 14))
        for i in 0..<14 {
            let p = CGPoint(x: win.minX + rnd(i, 7) * win.width, y: win.minY + rnd(i, 8) * win.height)
            winCtx.fill(circle(p, 1.3), with: .color(.white.opacity(Double(0.5 + 0.5 * sin(t * 2 + CGFloat(i))))))
        }
        winCtx.fill(circle(CGPoint(x: win.maxX - 26, y: win.minY + 26), 12), with: .color(Color(hex: 0xFFF1B8)))
        ctx.stroke(Path(roundedRect: win, cornerRadius: 14), with: .color(Color(hex: 0xFFF6EC)), lineWidth: 7)
        var bars = Path()
        bars.move(to: CGPoint(x: win.midX, y: win.minY)); bars.addLine(to: CGPoint(x: win.midX, y: win.maxY))
        bars.move(to: CGPoint(x: win.minX, y: win.midY)); bars.addLine(to: CGPoint(x: win.maxX, y: win.midY))
        ctx.stroke(bars, with: .color(Color(hex: 0xFFF6EC)), lineWidth: 4)
        // Curtains
        let sway = sin(t * 0.8) * 3
        for side in [CGFloat(0), 1] {
            var c = Path()
            let x0 = side == 0 ? win.minX - 14 : win.maxX - 8
            c.move(to: CGPoint(x: x0, y: win.minY - 12))
            c.addLine(to: CGPoint(x: x0 + 22, y: win.minY - 12))
            c.addQuadCurve(to: CGPoint(x: x0 + 18 + sway, y: win.maxY + 18), control: CGPoint(x: x0 + 10, y: win.midY))
            c.addLine(to: CGPoint(x: x0 + sway, y: win.maxY + 18))
            c.closeSubpath()
            ctx.fill(c, with: .color(Color(hex: 0xFF9FB7)))
        }
        // Shelf
        let shelfY = h * 0.26
        ctx.fill(Path(roundedRect: CGRect(x: w * 0.06, y: shelfY, width: w * 0.36, height: 8), cornerRadius: 4), with: .color(Color(hex: 0xB87A52)))
        let bookColors: [UInt32] = [0x7EC8E3, 0xFFD45C, 0xFF8FA3, 0x9C8CF0]
        for i in 0..<4 {
            let bw: CGFloat = 12, bh: CGFloat = 30 + CGFloat(i % 2) * 8
            ctx.fill(Path(roundedRect: CGRect(x: w * 0.08 + CGFloat(i) * 15, y: shelfY - bh, width: bw, height: bh), cornerRadius: 2),
                     with: .color(Color(hex: bookColors[i])))
        }
        ctx.fill(Path(roundedRect: CGRect(x: w * 0.3, y: shelfY - 18, width: 22, height: 18), cornerRadius: 4), with: .color(Color(hex: 0xE07A5F)))
        for k in 0..<3 {
            var leaf = Path()
            leaf.addEllipse(in: CGRect(x: w * 0.3 + CGFloat(k) * 7 - 2, y: shelfY - 40, width: 9, height: 24))
            ctx.fill(leaf, with: .color(Color(hex: 0x6FCB7A)))
        }
        // Fairy lights
        var wire = Path()
        wire.move(to: CGPoint(x: 0, y: h * 0.05))
        wire.addQuadCurve(to: CGPoint(x: w, y: h * 0.06), control: CGPoint(x: w / 2, y: h * 0.13))
        ctx.stroke(wire, with: .color(Color(hex: 0x6B4A3A).opacity(0.6)), lineWidth: 1.5)
        let bulbColors: [UInt32] = [0xFFD45C, 0xFF8FA3, 0x8FE3FF, 0xB8F28F]
        for i in 0..<12 {
            let u = (CGFloat(i) + 0.5) / 12
            let x = u * w
            let y = (1 - u) * (1 - u) * h * 0.05 + 2 * (1 - u) * u * h * 0.13 + u * u * h * 0.06
            let glow = 0.55 + 0.45 * sin(t * 2.2 + CGFloat(i) * 1.7)
            let color = Color(hex: bulbColors[i % 4])
            ctx.fill(circle(CGPoint(x: x, y: y + 6), 12), with: .radialGradient(Gradient(colors: [color.opacity(Double(glow) * 0.6), .clear]),
                                                                                 center: CGPoint(x: x, y: y + 6), startRadius: 1, endRadius: 12))
            ctx.fill(circle(CGPoint(x: x, y: y + 6), 4), with: .color(color))
        }
        // Floor & rug
        let floorY = h * 0.72
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: w, height: h - floorY)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0xD49A6A), Color(hex: 0xB97B4E)]),
                                       startPoint: CGPoint(x: 0, y: floorY), endPoint: CGPoint(x: 0, y: h)))
        for i in 0..<6 {
            var plank = Path()
            plank.move(to: CGPoint(x: 0, y: floorY + CGFloat(i) * 26))
            plank.addLine(to: CGPoint(x: w, y: floorY + CGFloat(i) * 26))
            ctx.stroke(plank, with: .color(Color(hex: 0x9A6238).opacity(0.35)), lineWidth: 1.5)
        }
        let rug = CGRect(x: w * 0.1, y: floorY + 14, width: w * 0.8, height: 70)
        ctx.fill(Path(ellipseIn: rug), with: .color(Color(hex: 0xFFB7C8)))
        ctx.stroke(Path(ellipseIn: rug.insetBy(dx: 12, dy: 8)), with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
        if dark { ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.25))) }
    }

    // MARK: Space

    static func space(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: CGFloat) {
        let w = size.width, h = size.height
        sky(&ctx, size, [Color(hex: 0x07061C), Color(hex: 0x1C1450), Color(hex: 0x3A2170)])
        for (c, r, col) in [(CGPoint(x: w * 0.2, y: h * 0.25), w * 0.6, Color(hex: 0xE266FF)), (CGPoint(x: w * 0.85, y: h * 0.55), w * 0.5, Color(hex: 0x4FA3FF))] {
            ctx.fill(circle(c, r), with: .radialGradient(Gradient(colors: [col.opacity(0.28), .clear]), center: c, startRadius: 0, endRadius: r))
        }
        stars(&ctx, size, count: 110, t: t, maxY: h)
        // Shooting star every ~7s
        let ph = fract(t / 7)
        if ph < 0.18 {
            let p = ph / 0.18
            let start = CGPoint(x: w * 0.9, y: h * 0.08)
            let head = CGPoint(x: start.x - p * w * 0.55, y: start.y + p * h * 0.18)
            var trail = Path()
            trail.move(to: head); trail.addLine(to: CGPoint(x: head.x + 60, y: head.y - 20))
            ctx.stroke(trail, with: .linearGradient(Gradient(colors: [.white, .clear]), startPoint: head, endPoint: CGPoint(x: head.x + 60, y: head.y - 20)),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        // Ringed planet
        let pc = CGPoint(x: w * 0.2, y: h * 0.78)
        let pr = w * 0.22
        var back = ctx
        back.translateBy(x: pc.x, y: pc.y); back.rotate(by: .radians(-0.35))
        back.stroke(Path(ellipseIn: CGRect(x: -pr * 1.7, y: -pr * 0.35, width: pr * 3.4, height: pr * 0.7)), with: .color(Color(hex: 0xFFD27A).opacity(0.5)), lineWidth: 6)
        ctx.fill(circle(pc, pr), with: .linearGradient(Gradient(colors: [Color(hex: 0xFF9AC8), Color(hex: 0x8C5CE6)]),
                                                       startPoint: CGPoint(x: pc.x - pr, y: pc.y - pr), endPoint: CGPoint(x: pc.x + pr, y: pc.y + pr)))
        var bands = ctx
        bands.clip(to: circle(pc, pr))
        for i in 0..<4 {
            bands.fill(Path(CGRect(x: pc.x - pr, y: pc.y - pr * 0.6 + CGFloat(i) * pr * 0.4, width: pr * 2, height: pr * 0.12)), with: .color(.white.opacity(0.14)))
        }
        var front = ctx
        front.translateBy(x: pc.x, y: pc.y); front.rotate(by: .radians(-0.35))
        var ringFront = Path()
        ringFront.addArc(center: .zero, radius: 1, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        front.scaleBy(x: pr * 1.7, y: pr * 0.35)
        front.stroke(ringFront, with: .color(Color(hex: 0xFFD27A)), lineWidth: 6 / (pr * 0.35))
        // Moon
        let mc = CGPoint(x: w * 0.82, y: h * 0.18 + sin(t * 0.4) * 6)
        ctx.fill(circle(mc, 22), with: .color(Color(hex: 0xE9E4FF)))
        ctx.fill(circle(CGPoint(x: mc.x - 7, y: mc.y - 4), 5), with: .color(Color(hex: 0xC9C0F2)))
        ctx.fill(circle(CGPoint(x: mc.x + 8, y: mc.y + 6), 3.5), with: .color(Color(hex: 0xC9C0F2)))
    }

    // MARK: Ocean

    static func ocean(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: CGFloat) {
        let w = size.width, h = size.height
        sky(&ctx, size, [Color(hex: 0x8BE0F4), Color(hex: 0x2A8BC4), Color(hex: 0x14507F)])
        // Light rays
        for i in 0..<5 {
            let x = w * (0.1 + CGFloat(i) * 0.2) + sin(t * 0.5 + CGFloat(i)) * 18
            var ray = Path()
            ray.move(to: CGPoint(x: x - 18, y: 0)); ray.addLine(to: CGPoint(x: x + 18, y: 0))
            ray.addLine(to: CGPoint(x: x + 70, y: h * 0.75)); ray.addLine(to: CGPoint(x: x - 10, y: h * 0.75)); ray.closeSubpath()
            ctx.fill(ray, with: .linearGradient(Gradient(colors: [.white.opacity(0.22), .clear]), startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x, y: h * 0.75)))
        }
        // Fish
        for i in 0..<5 {
            let speed = 0.03 + rnd(i, 9) * 0.03
            let dir: CGFloat = i % 2 == 0 ? 1 : -1
            let ph = fract(t * speed + rnd(i, 10))
            let x = dir > 0 ? -40 + ph * (w + 80) : w + 40 - ph * (w + 80)
            let y = h * (0.2 + rnd(i, 11) * 0.45) + sin(t * 2 + CGFloat(i)) * 6
            var f = ctx
            f.translateBy(x: x, y: y); f.scaleBy(x: dir, y: 1)
            var fish = Path()
            fish.addEllipse(in: CGRect(x: -12, y: -6, width: 24, height: 12))
            fish.move(to: CGPoint(x: -10, y: 0)); fish.addLine(to: CGPoint(x: -20, y: -7)); fish.addLine(to: CGPoint(x: -20, y: 7)); fish.closeSubpath()
            f.fill(fish, with: .color([Color(hex: 0xFFB86B), Color(hex: 0xFF8FA3), Color(hex: 0xFFE27A)][i % 3].opacity(0.9)))
            f.fill(circle(CGPoint(x: 6, y: -1.5), 1.6), with: .color(Color(hex: 0x14507F)))
        }
        // Bubbles
        for i in 0..<22 {
            let ph = fract(t * (0.05 + rnd(i, 12) * 0.06) + rnd(i, 13))
            let x = rnd(i, 14) * w + sin(t + CGFloat(i)) * 6
            let y = h - ph * h * 1.05
            let r = 2 + rnd(i, 15) * 5
            ctx.stroke(circle(CGPoint(x: x, y: y), r), with: .color(.white.opacity(0.55)), lineWidth: 1.2)
        }
        // Sea floor + kelp
        hills(&ctx, size, baseY: h * 0.86, amplitude: 10, frequency: 3, phase: 0.6, color: Color(hex: 0xF2D59C))
        for i in 0..<7 {
            let x = w * (0.05 + CGFloat(i) * 0.15)
            var kelp = Path()
            kelp.move(to: CGPoint(x: x, y: h))
            let height = h * (0.18 + rnd(i, 16) * 0.12)
            let sway = sin(t * 1.2 + CGFloat(i)) * 14
            kelp.addCurve(to: CGPoint(x: x + sway, y: h - height), control1: CGPoint(x: x - 18, y: h - height * 0.35), control2: CGPoint(x: x + 20 + sway, y: h - height * 0.7))
            ctx.stroke(kelp, with: .color(Color(hex: 0x2FA66F)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        }
    }

    // MARK: Forest

    static func forest(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: CGFloat) {
        let w = size.width, h = size.height
        sky(&ctx, size, [Color(hex: 0xDDF5E3), Color(hex: 0xA9DDB8), Color(hex: 0x5BA477)])
        ctx.fill(circle(CGPoint(x: w * 0.78, y: h * 0.14), 34), with: .color(Color(hex: 0xFFF6C8).opacity(0.9)))
        let layers: [(CGFloat, Color, CGFloat)] = [(0.5, Color(hex: 0x8FCB9E), 0.7), (0.62, Color(hex: 0x5FAF7A), 0.85), (0.76, Color(hex: 0x2F7D55), 1)]
        for (li, layer) in layers.enumerated() {
            let count = 7 + li * 2
            for i in 0..<count {
                let x = (CGFloat(i) + rnd(i, li + 20) * 0.6) / CGFloat(count) * (w + 60) - 30
                let th = h * 0.22 * layer.2 * (0.8 + rnd(i, li + 30) * 0.4)
                let tw = th * 0.45
                let base = h * layer.0 + 20
                var tree = Path()
                for k in 0..<3 {
                    let kk = CGFloat(k)
                    let top = base - th + kk * th * 0.25
                    tree.move(to: CGPoint(x: x, y: top))
                    tree.addLine(to: CGPoint(x: x + tw * (0.6 + kk * 0.2), y: top + th * 0.45))
                    tree.addLine(to: CGPoint(x: x - tw * (0.6 + kk * 0.2), y: top + th * 0.45))
                    tree.closeSubpath()
                }
                ctx.fill(tree, with: .color(layer.1))
            }
            ctx.fill(Path(CGRect(x: 0, y: h * layer.0 + 18, width: w, height: h)), with: .color(layer.1))
        }
        hills(&ctx, size, baseY: h * 0.84, amplitude: 8, frequency: 2, phase: 1, color: Color(hex: 0x3E8E5E))
        // Fireflies
        for i in 0..<18 {
            let x = rnd(i, 40) * w + sin(t * 0.7 + CGFloat(i)) * 20
            let y = h * (0.35 + rnd(i, 41) * 0.55) + cos(t * 0.6 + CGFloat(i)) * 14
            let glow = max(0, sin(t * 1.5 + rnd(i, 42) * 8))
            ctx.fill(circle(CGPoint(x: x, y: y), 9), with: .radialGradient(Gradient(colors: [Color(hex: 0xF7FF9E).opacity(Double(glow) * 0.7), .clear]),
                                                                           center: CGPoint(x: x, y: y), startRadius: 0, endRadius: 9))
            ctx.fill(circle(CGPoint(x: x, y: y), 2), with: .color(Color(hex: 0xFBFFD0).opacity(Double(glow))))
        }
    }

    // MARK: Candy World

    static func candy(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: CGFloat) {
        let w = size.width, h = size.height
        sky(&ctx, size, [Color(hex: 0xFFE7F3), Color(hex: 0xFFD0E6), Color(hex: 0xFFC0DE)])
        for i in 0..<3 {
            let x = fract(t * 0.01 + CGFloat(i) * 0.37) * (w + 200) - 100
            cloud(&ctx, at: CGPoint(x: x, y: h * (0.1 + CGFloat(i) * 0.09)), scale: 0.8 + CGFloat(i) * 0.15, color: .white.opacity(0.85))
        }
        // Sprinkle rain
        let sprinkleColors: [UInt32] = [0xFF5FA8, 0x6FD0FF, 0xFFD45C, 0x8CE99A, 0xB28CFF]
        for i in 0..<40 {
            let ph = fract(t * (0.04 + rnd(i, 50) * 0.03) + rnd(i, 51))
            let x = rnd(i, 52) * w
            let y = ph * h
            var s = ctx
            s.translateBy(x: x, y: y); s.rotate(by: .radians(Double(rnd(i, 53) * 6 + t)))
            s.fill(Path(roundedRect: CGRect(x: -5, y: -1.6, width: 10, height: 3.2), cornerRadius: 1.6), with: .color(Color(hex: sprinkleColors[i % 5])))
        }
        hills(&ctx, size, baseY: h * 0.7, amplitude: 22, frequency: 2.4, phase: 0.3, color: Color(hex: 0xC9A7FF))
        // Lollipops
        for (i, x) in [w * 0.15, w * 0.82, w * 0.62].enumerated() {
            let top = h * (0.6 + CGFloat(i) * 0.02)
            ctx.fill(Path(roundedRect: CGRect(x: x - 2.5, y: top, width: 5, height: h * 0.16), cornerRadius: 2), with: .color(.white))
            let c = CGPoint(x: x, y: top)
            var l = ctx
            l.translateBy(x: c.x, y: c.y); l.rotate(by: .radians(Double(t * 0.4 + CGFloat(i))))
            l.fill(circle(.zero, 20), with: .color(Color(hex: [0xFF5FA8, 0x6FD0FF, 0xFFB84D][i])))
            var swirl = Path()
            for k in 0..<60 {
                let a = CGFloat(k) * 0.3
                let r = CGFloat(k) / 60 * 18
                let p = CGPoint(x: cos(a) * r, y: sin(a) * r)
                if k == 0 { swirl.move(to: p) } else { swirl.addLine(to: p) }
            }
            l.stroke(swirl, with: .color(.white.opacity(0.85)), lineWidth: 3)
        }
        hills(&ctx, size, baseY: h * 0.82, amplitude: 16, frequency: 3, phase: 2, color: Color(hex: 0xFF8CC0))
        // Frosting drips
        for i in 0..<10 {
            let x = CGFloat(i) / 10 * w + 12
            let y = h * 0.82 + sin(x / w * .pi * 3 + 2) * 16
            ctx.fill(Path(roundedRect: CGRect(x: x, y: y - 2, width: 10, height: 14 + rnd(i, 55) * 12), cornerRadius: 5), with: .color(Color(hex: 0xFFF3F8)))
        }
    }

    // MARK: Neon City

    static func neon(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: CGFloat) {
        let w = size.width, h = size.height
        sky(&ctx, size, [Color(hex: 0x0D0820), Color(hex: 0x2A0A4A), Color(hex: 0x5A0F6B)])
        stars(&ctx, size, count: 40, t: t, maxY: h * 0.45)
        // Neon sun
        let sc = CGPoint(x: w / 2, y: h * 0.5)
        let sr = w * 0.3
        ctx.fill(circle(sc, sr * 1.5), with: .radialGradient(Gradient(colors: [Color(hex: 0xFF3DC8).opacity(0.35), .clear]), center: sc, startRadius: sr * 0.5, endRadius: sr * 1.5))
        var sun = ctx
        sun.clip(to: circle(sc, sr))
        sun.fill(Path(CGRect(x: sc.x - sr, y: sc.y - sr, width: sr * 2, height: sr * 2)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0xFFD45C), Color(hex: 0xFF3DC8)]), startPoint: CGPoint(x: 0, y: sc.y - sr), endPoint: CGPoint(x: 0, y: sc.y + sr)))
        for i in 0..<6 {
            let y = sc.y + CGFloat(i) * sr * 0.16
            sun.fill(Path(CGRect(x: sc.x - sr, y: y, width: sr * 2, height: 3 + CGFloat(i) * 1.6)), with: .color(Color(hex: 0x2A0A4A)))
        }
        // Skyline
        let horizon = h * 0.62
        for i in 0..<14 {
            let bw = w / 14
            let bh = h * (0.08 + rnd(i, 60) * 0.2)
            let x = CGFloat(i) * bw
            let rect = CGRect(x: x, y: horizon - bh, width: bw - 2, height: bh)
            ctx.fill(Path(rect), with: .color(Color(hex: 0x16092E)))
            for wy in stride(from: rect.minY + 8, to: rect.maxY - 4, by: 10) {
                for wx in stride(from: rect.minX + 4, to: rect.maxX - 4, by: 8) {
                    let k = Int(wx * 3 + wy * 7)
                    let on = rnd(k, 61) > 0.55 && sin(t * 0.5 + rnd(k, 62) * 20) > -0.6
                    if on {
                        ctx.fill(Path(CGRect(x: wx, y: wy, width: 3.5, height: 4.5)),
                                 with: .color((rnd(k, 63) > 0.5 ? Color(hex: 0x29E0FF) : Color(hex: 0xFF8AE2)).opacity(0.85)))
                    }
                }
            }
        }
        // Grid floor
        ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0x2A0A4A), Color(hex: 0x0D0820)]), startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)))
        var grid = Path()
        for i in -10...10 {
            grid.move(to: CGPoint(x: w / 2 + CGFloat(i) * 12, y: horizon))
            grid.addLine(to: CGPoint(x: w / 2 + CGFloat(i) * w * 0.22, y: h))
        }
        let scroll = fract(t * 0.35)
        for i in 0..<10 {
            let u = (CGFloat(i) + scroll) / 10
            let y = horizon + (h - horizon) * u * u
            grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: w, y: y))
        }
        ctx.stroke(grid, with: .color(Color(hex: 0xFF3DC8).opacity(0.65)), lineWidth: 1.4)
        ctx.fill(Path(CGRect(x: 0, y: horizon - 1, width: w, height: 2)), with: .color(Color(hex: 0x29E0FF)))
    }

    // MARK: Dream World

    static func dream(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: CGFloat) {
        let w = size.width, h = size.height
        sky(&ctx, size, [Color(hex: 0x241F4E), Color(hex: 0x6E5CC4), Color(hex: 0xE9A8D8)])
        stars(&ctx, size, count: 60, t: t, maxY: h * 0.6)
        // Crescent moon
        let mc = CGPoint(x: w * 0.75, y: h * 0.17)
        var moon = ctx
        moon.fill(circle(mc, 46), with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF1C1).opacity(0.4), .clear]), center: mc, startRadius: 20, endRadius: 46))
        var crescent = Path()
        crescent.addPath(circle(mc, 26))
        moon.clip(to: crescent)
        moon.fill(circle(mc, 26), with: .color(Color(hex: 0xFFF1C1)))
        moon.fill(circle(CGPoint(x: mc.x + 12, y: mc.y - 8), 22), with: .color(Color(hex: 0x3C3380)))
        // Drifting clouds
        for i in 0..<5 {
            let speed = 0.006 + rnd(i, 70) * 0.006
            let x = fract(t * speed + rnd(i, 71)) * (w + 240) - 120
            let y = h * (0.3 + CGFloat(i) * 0.12)
            cloud(&ctx, at: CGPoint(x: x, y: y + sin(t * 0.5 + CGFloat(i)) * 5), scale: 0.9 + rnd(i, 72) * 0.6,
                  color: Color.white.opacity(0.35 + Double(i) * 0.1))
        }
        // Floating sparkles
        for i in 0..<14 {
            let x = rnd(i, 73) * w
            let y = h * (0.2 + rnd(i, 74) * 0.7) + sin(t * 0.8 + CGFloat(i)) * 10
            let s = max(0, sin(t * 1.4 + CGFloat(i) * 2))
            var sp = ctx
            sp.translateBy(x: x, y: y); sp.scaleBy(x: s, y: s)
            var star = Path()
            star.move(to: CGPoint(x: 0, y: -6)); star.addQuadCurve(to: CGPoint(x: 6, y: 0), control: .zero)
            star.addQuadCurve(to: CGPoint(x: 0, y: 6), control: .zero); star.addQuadCurve(to: CGPoint(x: -6, y: 0), control: .zero)
            star.addQuadCurve(to: CGPoint(x: 0, y: -6), control: .zero)
            sp.fill(star, with: .color(.white))
        }
        cloud(&ctx, at: CGPoint(x: w * 0.25, y: h * 0.95), scale: 3, color: .white.opacity(0.75))
        cloud(&ctx, at: CGPoint(x: w * 0.85, y: h * 0.98), scale: 2.6, color: .white.opacity(0.65))
    }

    // MARK: Sunset

    static func sunset(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: CGFloat) {
        let w = size.width, h = size.height
        sky(&ctx, size, [Color(hex: 0x5B3FA8), Color(hex: 0xC2459B), Color(hex: 0xFF8A65), Color(hex: 0xFFC46B)])
        let sc = CGPoint(x: w * 0.5, y: h * 0.62)
        let pulse = 1 + sin(t * 0.8) * 0.03
        ctx.fill(circle(sc, w * 0.55), with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE3A0).opacity(0.6), .clear]), center: sc, startRadius: 10, endRadius: w * 0.55))
        ctx.fill(circle(sc, w * 0.2 * pulse), with: .color(Color(hex: 0xFFE9A8)))
        // Birds
        for i in 0..<4 {
            let x = fract(t * 0.02 + CGFloat(i) * 0.21) * (w + 60) - 30
            let y = h * (0.18 + CGFloat(i) * 0.05) + sin(t + CGFloat(i)) * 6
            let flap = sin(t * 6 + CGFloat(i)) * 4
            var b = Path()
            b.move(to: CGPoint(x: x - 8, y: y - flap)); b.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - 4, y: y - 4))
            b.addQuadCurve(to: CGPoint(x: x + 8, y: y - flap), control: CGPoint(x: x + 4, y: y - 4))
            ctx.stroke(b, with: .color(Color(hex: 0x3B2160).opacity(0.7)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        hills(&ctx, size, baseY: h * 0.66, amplitude: 20, frequency: 1.6, phase: 0.4, color: Color(hex: 0xA2468E))
        hills(&ctx, size, baseY: h * 0.74, amplitude: 24, frequency: 2.2, phase: 2.1, color: Color(hex: 0x7A3384))
        hills(&ctx, size, baseY: h * 0.84, amplitude: 14, frequency: 2.8, phase: 1.2, color: Color(hex: 0x4E2366))
    }

    // MARK: Winter

    static func winter(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: CGFloat) {
        let w = size.width, h = size.height
        sky(&ctx, size, [Color(hex: 0xBFD9F2), Color(hex: 0xE3EFFA), Color(hex: 0xF7FBFF)])
        // Mountains
        for (i, m) in [(0.2, 0.42, 0xA9C4E2), (0.65, 0.36, 0x93B3D8), (0.95, 0.45, 0xB5CDE6)].enumerated() {
            let peak = CGPoint(x: w * CGFloat(m.0), y: h * CGFloat(m.1))
            var mount = Path()
            mount.move(to: CGPoint(x: peak.x - w * 0.45, y: h * 0.72)); mount.addLine(to: peak); mount.addLine(to: CGPoint(x: peak.x + w * 0.45, y: h * 0.72)); mount.closeSubpath()
            ctx.fill(mount, with: .color(Color(hex: UInt32(m.2))))
            var cap = Path()
            cap.move(to: CGPoint(x: peak.x - w * 0.09, y: peak.y + h * 0.07)); cap.addLine(to: peak); cap.addLine(to: CGPoint(x: peak.x + w * 0.09, y: peak.y + h * 0.07))
            cap.addLine(to: CGPoint(x: peak.x + w * 0.04, y: peak.y + h * 0.055)); cap.addLine(to: CGPoint(x: peak.x, y: peak.y + h * 0.075))
            cap.addLine(to: CGPoint(x: peak.x - w * 0.04, y: peak.y + h * 0.055)); cap.closeSubpath()
            ctx.fill(cap, with: .color(.white))
            _ = i
        }
        // Pines
        for i in 0..<9 {
            let x = CGFloat(i) / 8 * w + (rnd(i, 80) - 0.5) * 20
            let th = h * (0.1 + rnd(i, 81) * 0.06)
            let base = h * 0.74
            var tree = Path()
            tree.move(to: CGPoint(x: x, y: base - th)); tree.addLine(to: CGPoint(x: x + th * 0.32, y: base)); tree.addLine(to: CGPoint(x: x - th * 0.32, y: base)); tree.closeSubpath()
            ctx.fill(tree, with: .color(Color(hex: 0x2F6D73)))
            var snow = Path()
            snow.move(to: CGPoint(x: x, y: base - th)); snow.addLine(to: CGPoint(x: x + th * 0.12, y: base - th * 0.62)); snow.addLine(to: CGPoint(x: x - th * 0.12, y: base - th * 0.62)); snow.closeSubpath()
            ctx.fill(snow, with: .color(.white))
        }
        hills(&ctx, size, baseY: h * 0.76, amplitude: 10, frequency: 2, phase: 0.8, color: .white)
        // Snowfall
        for i in 0..<70 {
            let ph = fract(t * (0.03 + rnd(i, 82) * 0.04) + rnd(i, 83))
            let x = rnd(i, 84) * w + sin(t * (0.6 + rnd(i, 85)) + CGFloat(i)) * 14
            let y = ph * (h + 20) - 10
            ctx.fill(circle(CGPoint(x: x, y: y), 1.4 + rnd(i, 86) * 2.4), with: .color(.white.opacity(0.95)))
        }
    }

    // MARK: Minimal

    static func minimal(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: CGFloat, dark: Bool) {
        let w = size.width, h = size.height
        sky(&ctx, size, dark ? [Color(hex: 0x1B1A20), Color(hex: 0x26242E)] : [Color(hex: 0xF7F4EF), Color(hex: 0xEAE4DB)])
        let blobs: [(CGPoint, CGFloat, Color)] = [
            (CGPoint(x: w * 0.85 + sin(t * 0.2) * 12, y: h * 0.15), w * 0.45, Color(hex: 0xB9AEF2)),
            (CGPoint(x: w * 0.1, y: h * 0.62 + cos(t * 0.18) * 14), w * 0.5, Color(hex: 0xFFC7B5)),
        ]
        for b in blobs {
            ctx.fill(circle(b.0, b.1), with: .radialGradient(Gradient(colors: [b.2.opacity(dark ? 0.18 : 0.35), .clear]), center: b.0, startRadius: 0, endRadius: b.1))
        }
        ctx.stroke(circle(CGPoint(x: w * 0.5, y: h * 0.36), w * 0.36), with: .color(Color.primary.opacity(dark ? 0.06 : 0.05)), lineWidth: 1)
    }
}
