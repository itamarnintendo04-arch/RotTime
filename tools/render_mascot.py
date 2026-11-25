#!/usr/bin/env python3
"""Renders RotTime's original brain mascot ("Noodle") to PNG assets.

The geometry mirrors `BrainRenderer.swift` (240x240 design space) so the app icon and the
Screen Time shield icon match the in-app animated character.

Usage:  python3 tools/render_mascot.py   (writes into RotTime/Resources and Extensions/ShieldConfiguration)
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SS = 4  # supersampling factor

BASE = (0xFF, 0xA3, 0xBE)
SHADE = (0xF2, 0x7B, 0x9E)
OUTLINE = (0xB4, 0x4C, 0x72)
INK = (0x2B, 0x1F, 0x3A)
IRIS2 = (0x5B, 0x4B, 0x8A)
CENTER = (120, 132)
BUMPS = [(-90, 29), (-58, 27), (-122, 27), (-28, 28), (-152, 28), (4, 27), (176, 27), (34, 25), (146, 25)]


def cubic(p0, p1, p2, p3, n=40):
    pts = []
    for i in range(n + 1):
        t = i / n
        mt = 1 - t
        x = mt**3 * p0[0] + 3 * mt * mt * t * p1[0] + 3 * mt * t * t * p2[0] + t**3 * p3[0]
        y = mt**3 * p0[1] + 3 * mt * mt * t * p1[1] + 3 * mt * t * t * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def quad(p0, c, p1, n=30):
    pts = []
    for i in range(n + 1):
        t = i / n
        mt = 1 - t
        pts.append((mt * mt * p0[0] + 2 * mt * t * c[0] + t * t * p1[0], mt * mt * p0[1] + 2 * mt * t * c[1] + t * t * p1[1]))
    return pts


class Canvas:
    def __init__(self, size, scale, offset=(0, 0)):
        self.size = size
        self.k = scale * SS
        self.off = offset
        self.img = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def P(self, p):
        return ((p[0] + self.off[0]) * self.k, (p[1] + self.off[1]) * self.k)

    def ellipse(self, c, rx, ry, fill=None, outline=None, width=0):
        x, y = self.P((c[0] - rx, c[1] - ry))
        x2, y2 = self.P((c[0] + rx, c[1] + ry))
        self.d.ellipse([x, y, x2, y2], fill=fill, outline=outline, width=int(width * self.k))

    def line(self, pts, color, width):
        w = int(width * self.k)
        pp = [self.P(p) for p in pts]
        self.d.line(pp, fill=color, width=w, joint="curve")
        r = w / 2
        for p in (pp[0], pp[-1]):
            self.d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=color)

    def polygon(self, pts, fill):
        self.d.polygon([self.P(p) for p in pts], fill=fill)

    def result(self):
        return self.img.resize((self.size, self.size), Image.LANCZOS)


def body_shapes(cv, inset, color):
    rx, ry = 70, 56
    cv.ellipse((CENTER[0], CENTER[1] + 4), rx + inset, ry + inset, fill=color)
    for ang, r in BUMPS:
        a = math.radians(ang)
        c = (CENTER[0] + math.cos(a) * rx * 0.8, CENTER[1] + math.sin(a) * ry * 0.8)
        cv.ellipse(c, r + inset, r + inset, fill=color)


def draw_mascot(cv):
    # shadow
    cv.ellipse((120, 207), 54, 7, fill=(0, 0, 0, 34))
    # feet
    for x in (98, 142):
        cv.ellipse((x, 197), 15, 9, fill=SHADE, outline=OUTLINE, width=3)
    # arms
    for x in (56 - 4, 184 + 4):
        cv.ellipse((x, 150), 12, 7.5, fill=BASE, outline=OUTLINE, width=3)
    body_shapes(cv, 3.5, OUTLINE)
    body_shapes(cv, 0, BASE)

    # bottom shading via mask
    mask = Image.new("L", cv.img.size, 0)
    mcv = Canvas(cv.size, cv.k / SS, cv.off)
    mcv.img = mask
    mcv.d = ImageDraw.Draw(mask)
    body_shapes(mcv, 0, 255)
    grad = Image.new("RGBA", cv.img.size, SHADE + (0,))
    gd = ImageDraw.Draw(grad)
    for y in range(cv.img.size[1]):
        dy = y / cv.k - cv.off[1]
        a = max(0.0, min(1.0, (dy - 120) / 80)) * 0.75
        gd.line([(0, y), (cv.img.size[0], y)], fill=SHADE + (int(a * 255),))
    shaded = Image.new("RGBA", cv.img.size, (0, 0, 0, 0))
    shaded.paste(grad, (0, 0), mask)
    cv.img.alpha_composite(shaded)
    cv.d = ImageDraw.Draw(cv.img)

    folds = [
        ((120, 62), (112, 76), (128, 86), (119, 100)),
        ((76, 82), (88, 74), (100, 84), (96, 96)),
        ((164, 82), (152, 74), (140, 84), (144, 96)),
        ((52, 110), (62, 100), (74, 108), (70, 120)),
        ((188, 110), (178, 100), (166, 108), (170, 120)),
        ((52, 150), (58, 162), (70, 160), (72, 172)),
        ((188, 150), (182, 162), (170, 160), (168, 172)),
        ((100, 70), (104, 64), (110, 66), (108, 74)),
        ((140, 70), (136, 64), (130, 66), (132, 74)),
    ]
    for f in folds:
        cv.line(cubic(*f), SHADE, 3.6)

    # highlight
    hl = Image.new("RGBA", cv.img.size, (0, 0, 0, 0))
    hcv = Canvas(cv.size, cv.k / SS, cv.off)
    hcv.img = hl
    hcv.d = ImageDraw.Draw(hl)
    hcv.ellipse((86, 88), 17, 7, fill=(255, 255, 255, 110))
    hl = hl.rotate(25, center=hcv.P((86, 88)), resample=Image.BICUBIC)
    cv.img.alpha_composite(hl)
    cv.d = ImageDraw.Draw(cv.img)
    cv.ellipse((108, 80), 3.2, 3.2, fill=(255, 255, 255, 128))

    # sprout
    stem = cubic((120, 64), (114, 54), (128, 46), (123, 36))
    cv.line(stem, (0x2F, 0x6B, 0x3A), 6.5)
    cv.line(stem, (0x7B, 0xD8, 0x8F), 3.6)
    cv.ellipse((113, 50), 8, 4.2, fill=(0x7B, 0xD8, 0x8F), outline=(0x2F, 0x6B, 0x3A), width=2)
    glow = Image.new("RGBA", cv.img.size, (0, 0, 0, 0))
    gcv = Canvas(cv.size, cv.k / SS, cv.off)
    gcv.img = glow
    gcv.d = ImageDraw.Draw(glow)
    gcv.ellipse((123, 31), 13, 13, fill=(0xFF, 0xE6, 0x80, 150))
    glow = glow.filter(ImageFilter.GaussianBlur(6 * SS))
    cv.img.alpha_composite(glow)
    cv.d = ImageDraw.Draw(cv.img)
    cv.ellipse((123, 31), 6.5, 6.5, fill=(0xFF, 0xE2, 0x7A), outline=(0xB8, 0x82, 0x1C), width=2)
    cv.ellipse((121, 29), 1.8, 1.8, fill=(255, 255, 255))

    # blush
    for x in (74, 166):
        cv.ellipse((x, 150), 13, 7.5, fill=(0xFF, 0x6F, 0x9A, 120))

    # eyes
    for x in (96, 144):
        cv.ellipse((x, 126), 14.5, 16.5, fill=(255, 255, 255), outline=OUTLINE + (140,), width=1.5)
        cv.ellipse((x + 1, 128), 11.5, 13.5, fill=INK)
        cv.ellipse((x + 1, 134), 9, 6, fill=IRIS2)
        cv.ellipse((x - 2.8, 122), 4, 4, fill=(255, 255, 255))
        cv.ellipse((x + 4.6, 132), 1.8, 1.8, fill=(255, 255, 255))

    # mouth (grin)
    w, h, c = 15, 16, (120, 152)
    top = quad((c[0] - w, c[1] - 3), (c[0], c[1] + 1), (c[0] + w, c[1] - 3))
    right = quad((c[0] + w, c[1] - 3), (c[0] + w * 0.9, c[1] + h), (c[0], c[1] + h))
    left = quad((c[0], c[1] + h), (c[0] - w * 0.9, c[1] + h), (c[0] - w, c[1] - 3))
    outline_pts = top + right + left
    cv.polygon(outline_pts, (0x5A, 0x21, 0x40))
    cv.ellipse((120, 164), 7.5, 4.5, fill=(0xFF, 0x7A, 0x9C))
    cv.line(outline_pts + [outline_pts[0]], INK, 3)


def gradient_bg(size, top, bottom):
    img = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        col = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        d.line([(0, y), (size, y)], fill=col)
    return img


def app_icon(path, size=1024):
    bg = gradient_bg(size, (0xFF, 0xC2, 0x8A), (0xFF, 0x6F, 0x9E))
    d = ImageDraw.Draw(bg)
    # soft sparkles
    for (x, y, r) in [(0.16, 0.18, 0.035), (0.84, 0.22, 0.025), (0.86, 0.78, 0.03), (0.12, 0.8, 0.02)]:
        cx, cy, rr = x * size, y * size, r * size
        d.polygon([(cx, cy - rr), (cx + rr * 0.25, cy - rr * 0.25), (cx + rr, cy), (cx + rr * 0.25, cy + rr * 0.25),
                   (cx, cy + rr), (cx - rr * 0.25, cy + rr * 0.25), (cx - rr, cy), (cx - rr * 0.25, cy - rr * 0.25)], fill=(255, 255, 255, 200))
    # Fit the 240 design (content spans ~x28..212, y18..214) into the icon.
    scale = size / 240 * 0.98
    cv = Canvas(size, scale, offset=(0, -6))
    draw_mascot(cv)
    bg.alpha_composite(cv.result())
    bg.convert("RGB").save(path)


def shield_icon(path, size=360):
    cv = Canvas(size, size / 240, offset=(0, -4))
    draw_mascot(cv)
    cv.result().save(path)


if __name__ == "__main__":
    icon_dir = os.path.join(ROOT, "RotTime/Resources/Assets.xcassets/AppIcon.appiconset")
    os.makedirs(icon_dir, exist_ok=True)
    app_icon(os.path.join(icon_dir, "AppIcon-1024.png"))
    for target in ["RotTime/Resources/Assets.xcassets/ShieldBrain.imageset",
                   "Extensions/ShieldConfiguration/Assets.xcassets/ShieldBrain.imageset"]:
        d = os.path.join(ROOT, target)
        os.makedirs(d, exist_ok=True)
        shield_icon(os.path.join(d, "ShieldBrain.png"))
    print("Rendered mascot assets.")
