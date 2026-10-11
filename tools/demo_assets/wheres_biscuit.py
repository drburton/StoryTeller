#!/usr/bin/env python3
"""Draws the placeholder art for the "Where's Biscuit?" example story.

Theo, Leo, baby Cleo, Biscuit the teddy bear, and two backdrops. Run from
the repository root:

    python3 tools/demo_assets/wheres_biscuit.py

Requires Pillow and NumPy. Output goes to examples/wheres_biscuit/.
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join("examples", "wheres_biscuit")
WIDTH, HEIGHT = 1152, 648
S = 3  # Supersampling factor for smooth edges.

INK = (45, 35, 40)
WHITE = (255, 255, 255)
BLUSH = (245, 140, 140, 110)


def path(*parts):
    full = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    return full


def vertical_gradient(size, top, bottom):
    w, h = size
    t = np.linspace(0.0, 1.0, h)[:, None, None]
    colors = np.array(top, float) * (1 - t) + np.array(bottom, float) * t
    return Image.fromarray(np.repeat(colors, w, axis=1).astype(np.uint8), "RGB")


def darker(color, amount=40):
    return tuple(max(0, c - amount) for c in color[:3])


class Pen:
    """Draws on a supersampled canvas in unscaled coordinates."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def ellipse(self, box, **kw):
        if "width" in kw:
            kw["width"] *= S
        self.d.ellipse(tuple(v * S for v in box), **kw)

    def rect(self, box, radius=0, **kw):
        if "width" in kw:
            kw["width"] *= S
        self.d.rounded_rectangle(tuple(v * S for v in box), radius=radius * S, **kw)

    def poly(self, points, **kw):
        self.d.polygon([(x * S, y * S) for x, y in points], **kw)

    def line(self, points, width, **kw):
        self.d.line([(x * S, y * S) for x, y in points], width=width * S, joint="curve", **kw)

    def arc(self, box, start, end, width, **kw):
        self.d.arc(tuple(v * S for v in box), start, end, width=width * S, **kw)

    def chord(self, box, start, end, **kw):
        self.d.chord(tuple(v * S for v in box), start, end, **kw)

    def blush(self, spots):
        layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        bd = ImageDraw.Draw(layer)
        for box in spots:
            bd.ellipse(tuple(v * S for v in box), fill=BLUSH)
        self.img = Image.alpha_composite(self.img, layer)
        self.d = ImageDraw.Draw(self.img)

    def done(self):
        return self.img.resize((self.w, self.h), Image.LANCZOS)


def face(p, cx, eye_y, spread, eye_w, eye_h, mouth_y, mood):
    """Eyes, brows and mouth for every character. Moods: neutral, happy, sad,
    surprised, thinking."""
    look = (5, -6) if mood == "thinking" else (0, 0)
    for ex in (cx - spread, cx + spread):
        if mood == "happy":
            p.arc((ex - eye_w, eye_y - eye_h * 0.6, ex + eye_w, eye_y + eye_h), 200, 340, 5, fill=INK)
            continue
        grow = 1.25 if mood == "surprised" else 1.0
        w, h = eye_w * grow, eye_h * grow
        p.ellipse((ex - w + look[0], eye_y - h + look[1], ex + w + look[0], eye_y + h + look[1]), fill=INK)
        p.ellipse((ex - w * 0.55 + look[0], eye_y - h * 0.7 + look[1], ex - w * 0.05 + look[0], eye_y - h * 0.15 + look[1]), fill=WHITE)
    # Brows: (inner lift, outer lift) per side.
    lifts = {"neutral": (0, 0), "happy": (4, 4), "sad": (10, -4), "surprised": (12, 12), "thinking": (6, -2)}[mood]
    brow_y = eye_y - eye_h - 14
    for side in (-1, 1):
        ex = cx + side * spread
        inner, outer = lifts
        if mood == "thinking" and side == 1:
            inner, outer = -2, 8
        p.line([(ex + side * 16, brow_y - outer), (ex - side * 16, brow_y - inner)], 5, fill=INK)
    # Mouth.
    if mood == "happy":
        p.chord((cx - 24, mouth_y - 18, cx + 24, mouth_y + 18), 0, 180, fill=(170, 60, 70))
        p.chord((cx - 14, mouth_y + 4, cx + 14, mouth_y + 16), 0, 180, fill=(240, 120, 130))
    elif mood == "sad":
        p.arc((cx - 18, mouth_y, cx + 18, mouth_y + 22), 200, 340, 5, fill=INK)
    elif mood == "surprised":
        p.ellipse((cx - 11, mouth_y - 8, cx + 11, mouth_y + 16), fill=(170, 60, 70))
    elif mood == "thinking":
        p.line([(cx - 8, mouth_y + 4), (cx + 16, mouth_y)], 5, fill=INK)
    else:
        p.arc((cx - 16, mouth_y - 10, cx + 16, mouth_y + 8), 30, 150, 5, fill=INK)


def tear(p, x, y):
    p.poly([(x, y), (x - 7, y + 14), (x + 7, y + 14)], fill=(120, 180, 240))
    p.ellipse((x - 7, y + 8, x + 7, y + 22), fill=(120, 180, 240))


# --- Theo and Leo -------------------------------------------------------------

THEO = {"skin": (240, 205, 175), "hair": (120, 80, 45), "shirt": (60, 120, 220), "pants": (70, 70, 90),
        "shoes": (40, 60, 120), "hair_style": "swoop", "badge": "star"}
LEO = {"skin": (235, 195, 165), "hair": (70, 45, 30), "shirt": (220, 60, 60), "pants": (60, 85, 140),
       "shoes": (150, 30, 40), "hair_style": "spiky", "badge": "bolt"}


def kid(style, mood):
    """A child sprite, 400 x 560 pixels, standing on the bottom edge."""
    p = Pen(400, 560)
    cx = 200
    skin, hair, shirt = style["skin"], style["hair"], style["shirt"]
    # Shoes, legs, body and arms.
    p.rect((112, 520, 190, 556), radius=16, fill=style["shoes"])
    p.rect((210, 520, 288, 556), radius=16, fill=style["shoes"])
    p.rect((128, 430, 188, 530), radius=10, fill=style["pants"])
    p.rect((212, 430, 272, 530), radius=10, fill=style["pants"])
    p.rect((118, 290, 282, 460), radius=40, fill=shirt)
    p.rect((80, 300, 130, 440), radius=24, fill=shirt)
    p.rect((270, 300, 320, 440), radius=24, fill=shirt)
    p.ellipse((84, 420, 126, 462), fill=skin)
    p.ellipse((274, 420, 316, 462), fill=skin)
    p.chord((160, 270, 240, 320), 0, 180, fill=darker(shirt, 30))
    if style["badge"] == "star":
        points = []
        for i in range(10):
            r = 30 if i % 2 == 0 else 13
            a = -math.pi / 2 + i * math.pi / 5
            points.append((cx + r * math.cos(a), 375 + r * math.sin(a)))
        p.poly(points, fill=(255, 255, 255))
    else:
        p.poly([(cx + 6, 340), (cx - 20, 382), (cx - 2, 382), (cx - 10, 412), (cx + 20, 368), (cx + 2, 368), (cx + 12, 340)],
               fill=(255, 220, 80))
    # Head.
    p.ellipse((70, 165, 106, 215), fill=skin)
    p.ellipse((294, 165, 330, 215), fill=skin)
    p.ellipse((84, 40, 316, 290), fill=skin)
    if style["hair_style"] == "swoop":
        p.chord((78, 26, 322, 250), 180, 360, fill=hair)
        p.poly([(82, 140), (140, 96), (230, 92), (318, 140), (300, 100), (220, 60), (130, 66)], fill=hair)
        p.poly([(120, 110), (250, 70), (300, 120), (250, 100), (150, 132)], fill=hair)
    else:
        p.chord((80, 34, 320, 250), 180, 360, fill=hair)
        for i in range(7):
            x = 88 + i * 32
            p.poly([(x, 110), (x + 16, 14 + abs(i - 3) * 8), (x + 32, 110)], fill=hair)
        p.poly([(86, 138), (120, 104), (160, 128), (200, 100), (240, 128), (280, 104), (314, 138), (314, 110), (86, 110)], fill=hair)
    face(p, cx, 180, 46, 16, 20, 238, mood)
    p.blush([(108, 210, 146, 232), (254, 210, 292, 232)])
    if mood == "sad":
        tear(p, 150, 204)
    return p.done()


# --- Cleo ---------------------------------------------------------------------

CLEO = {"skin": (245, 212, 190), "hair": (190, 130, 70), "onesie": (245, 150, 190), "bow": (235, 80, 140)}


def cleo(mood, holding=False):
    """Baby Cleo, 320 x 400 pixels. holding draws Biscuit in her arms."""
    p = Pen(320, 400)
    cx = 160
    skin = CLEO["skin"]
    onesie = CLEO["onesie"]
    # Feet, body, arms.
    p.ellipse((86, 352, 150, 398), fill=onesie)
    p.ellipse((170, 352, 234, 398), fill=onesie)
    p.rect((80, 220, 240, 380), radius=60, fill=onesie)
    p.ellipse((126, 280, 194, 330), fill=(255, 225, 235))
    # Head.
    p.ellipse((44, 110, 76, 150), fill=skin)
    p.ellipse((244, 110, 276, 150), fill=skin)
    p.ellipse((54, 20, 266, 230), fill=skin)
    # A curl of hair and a bow.
    p.arc((130, 0, 190, 60), 120, 400, 9, fill=CLEO["hair"])
    p.chord((96, 20, 224, 90), 180, 360, fill=CLEO["hair"])
    p.poly([(196, 28), (236, 8), (236, 52)], fill=CLEO["bow"])
    p.poly([(196, 28), (160, 6), (160, 50)], fill=CLEO["bow"])
    p.ellipse((186, 18, 206, 38), fill=darker(CLEO["bow"], 30))
    if mood == "sad":
        # Crying: shut eyes and a wide open mouth.
        for ex in (cx - 44, cx + 44):
            p.arc((ex - 18, 108, ex + 18, 132), 20, 160, 5, fill=INK)
        p.ellipse((cx - 22, 156, cx + 22, 196), fill=(170, 60, 70))
        p.line([(cx - 58, 92), (cx - 30, 100)], 5, fill=INK)
        p.line([(cx + 58, 92), (cx + 30, 100)], 5, fill=INK)
        tear(p, cx - 64, 132)
        tear(p, cx + 64, 132)
    else:
        face(p, cx, 118, 44, 15, 19, 168, mood)
    p.blush([(68, 146, 106, 170), (214, 146, 252, 170)])
    if holding:
        bear = biscuit().resize((150, 177), Image.LANCZOS)
        layer = Image.new("RGBA", (320 * S, 400 * S), (0, 0, 0, 0))
        layer.paste(bear.resize((150 * S, 177 * S), Image.LANCZOS), (85 * S, 215 * S))
        p.img = Image.alpha_composite(p.img, layer)
        p.d = ImageDraw.Draw(p.img)
        p.ellipse((70, 300, 120, 340), fill=onesie)
        p.ellipse((200, 300, 250, 340), fill=onesie)
        p.ellipse((80, 308, 112, 334), fill=skin)
        p.ellipse((208, 308, 240, 334), fill=skin)
    return p.done()


# --- Biscuit ------------------------------------------------------------------

def biscuit():
    """Biscuit the teddy bear, 220 x 260 pixels."""
    p = Pen(220, 260)
    fur = (190, 135, 85)
    light = (235, 200, 160)
    p.ellipse((40, 220, 100, 258), fill=fur)
    p.ellipse((120, 220, 180, 258), fill=fur)
    p.ellipse((44, 120, 176, 245), fill=fur)
    p.ellipse((78, 150, 142, 225), fill=light)
    p.ellipse((14, 130, 64, 190), fill=fur)
    p.ellipse((156, 130, 206, 190), fill=fur)
    p.ellipse((26, 6, 82, 62), fill=fur)
    p.ellipse((138, 6, 194, 62), fill=fur)
    p.ellipse((40, 20, 70, 50), fill=light)
    p.ellipse((150, 20, 180, 50), fill=light)
    p.ellipse((36, 20, 184, 150), fill=fur)
    p.ellipse((80, 82, 140, 132), fill=light)
    p.ellipse((96, 84, 124, 104), fill=INK)
    p.line([(110, 104), (110, 116)], 3, fill=INK)
    p.arc((96, 106, 124, 124), 20, 160, 3, fill=INK)
    p.ellipse((70, 62, 86, 80), fill=INK)
    p.ellipse((134, 62, 150, 80), fill=INK)
    # A bow tie, half blue for Theo and half red for Leo.
    p.poly([(110, 148), (76, 132), (76, 166)], fill=(60, 120, 220))
    p.poly([(110, 148), (144, 132), (144, 166)], fill=(220, 60, 60))
    p.ellipse((100, 138, 120, 158), fill=(250, 210, 80))
    return p.done()


# --- Backdrops ----------------------------------------------------------------

def living_room():
    img = vertical_gradient((WIDTH, HEIGHT), (250, 236, 205), (240, 220, 185)).convert("RGBA")
    d = ImageDraw.Draw(img)
    # Wallpaper stripes.
    for x in range(0, WIDTH, 48):
        d.rectangle((x, 0, x + 20, 430), fill=(245, 228, 195))
    # Window with sky and a tree.
    sky = vertical_gradient((300, 220), (150, 205, 250), (210, 235, 250))
    img.paste(sky, (420, 70))
    d = ImageDraw.Draw(img)
    d.ellipse((560, 170, 700, 300), fill=(110, 180, 100))
    d.rectangle((420, 270, 720, 290), fill=(120, 190, 110))
    d.rectangle((410, 60, 730, 300), outline=(255, 255, 255), width=14)
    d.line((570, 66, 570, 296), fill=(255, 255, 255), width=10)
    d.rectangle((396, 300, 744, 316), fill=(225, 210, 190))
    # Floor and rug.
    floor = vertical_gradient((WIDTH, HEIGHT - 430), (200, 150, 105), (175, 125, 85))
    img.paste(floor, (0, 430))
    d = ImageDraw.Draw(img)
    for x in range(0, WIDTH, 96):
        d.line((x, 430, x - 60, HEIGHT), fill=(185, 135, 92), width=3)
    d.ellipse((260, 510, 900, 640), fill=(120, 170, 150))
    d.ellipse((300, 525, 860, 625), fill=(150, 195, 170))
    # Couch.
    d.rounded_rectangle((70, 300, 400, 470), radius=30, fill=(150, 110, 170))
    d.rounded_rectangle((90, 360, 380, 440), radius=20, fill=(170, 130, 190))
    d.rounded_rectangle((50, 340, 110, 470), radius=24, fill=(135, 95, 155))
    d.rounded_rectangle((360, 340, 420, 470), radius=24, fill=(135, 95, 155))
    d.rectangle((90, 470, 110, 490), fill=(80, 60, 50))
    d.rectangle((360, 470, 380, 490), fill=(80, 60, 50))
    # Blue toy box.
    d.rounded_rectangle((800, 360, 980, 480), radius=10, fill=(60, 120, 220))
    d.rounded_rectangle((790, 340, 990, 372), radius=8, fill=(40, 95, 190))
    for i, color in enumerate([(250, 210, 80), (240, 120, 60), (120, 200, 120)]):
        d.rectangle((830 + i * 46, 318, 862 + i * 46, 344), fill=color)
    # Red wagon.
    d.rounded_rectangle((990, 470, 1130, 530), radius=8, fill=(220, 60, 60))
    for wx in (1015, 1105):
        d.ellipse((wx - 20, 518, wx + 20, 558), fill=(50, 50, 55))
        d.ellipse((wx - 8, 530, wx + 8, 546), fill=(200, 200, 200))
    d.line((990, 480, 940, 440), fill=(60, 60, 65), width=6)
    # Back door.
    d.rounded_rectangle((1000, 120, 1120, 430), radius=8, fill=(205, 170, 130))
    d.ellipse((1096, 270, 1110, 284), fill=(250, 210, 80))
    img.convert("RGB").save(path("backdrops", "living_room.png"))


def backyard():
    img = vertical_gradient((WIDTH, HEIGHT), (130, 195, 245), (215, 238, 250)).convert("RGBA")
    d = ImageDraw.Draw(img)
    # Sun and clouds.
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((900, 30, 1060, 190), fill=(255, 240, 160, 160))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(20)))
    d = ImageDraw.Draw(img)
    d.ellipse((940, 70, 1020, 150), fill=(255, 225, 110))
    for cx, cy in ((180, 90), (560, 60)):
        for dx, r in ((-50, 34), (0, 46), (50, 34)):
            d.ellipse((cx + dx - r, cy - r, cx + dx + r, cy + r), fill=(255, 255, 255))
    # Fence.
    for x in range(0, WIDTH, 60):
        d.polygon([(x + 6, 380), (x + 30, 350), (x + 54, 380), (x + 54, 470), (x + 6, 470)], fill=(250, 245, 235))
    d.rectangle((0, 400, WIDTH, 414), fill=(235, 228, 215))
    # Grass.
    grass = vertical_gradient((WIDTH, HEIGHT - 440), (120, 195, 95), (90, 165, 75))
    img.paste(grass, (0, 440))
    d = ImageDraw.Draw(img)
    # Tree.
    d.rectangle((90, 250, 130, 470), fill=(120, 85, 55))
    for bx, by, r in ((110, 200, 90), (50, 250, 60), (170, 250, 60)):
        d.ellipse((bx - r, by - r, bx + r, by + r), fill=(90, 160, 80))
    # Flowers.
    for i, x in enumerate(range(240, 1150, 110)):
        y = 470 + (i % 3) * 14
        color = [(240, 90, 90), (90, 140, 240), (250, 210, 80)][i % 3]
        d.line((x, y, x, y + 24), fill=(70, 130, 60), width=4)
        for ax, ay in ((-8, 0), (8, 0), (0, -8), (0, 8)):
            d.ellipse((x + ax - 7, y + ay - 7, x + ax + 7, y + ay + 7), fill=color)
        d.ellipse((x - 5, y - 5, x + 5, y + 5), fill=(255, 240, 150))
    # Sandbox.
    d.rounded_rectangle((420, 500, 740, 600), radius=10, fill=(150, 100, 60))
    d.rounded_rectangle((436, 512, 724, 588), radius=8, fill=(240, 215, 150))
    d.ellipse((520, 520, 600, 560), fill=(225, 195, 130))
    # Crumb trail across the grass.
    for i in range(8):
        x = 1000 - i * 50
        y = 470 + (i % 2) * 12 + i * 4
        d.ellipse((x - 4, y - 3, x + 4, y + 3), fill=(220, 180, 110))
    img.convert("RGB").save(path("backdrops", "backyard.png"))


def main():
    for mood in ("neutral", "happy", "sad", "surprised", "thinking"):
        kid(THEO, mood).save(path("cast", "theo", f"{mood}.png"))
        kid(LEO, mood).save(path("cast", "leo", f"{mood}.png"))
    for mood in ("neutral", "happy", "sad", "surprised"):
        cleo(mood).save(path("cast", "cleo", f"{mood}.png"))
    cleo("happy", holding=True).save(path("cast", "cleo", "hug.png"))
    biscuit().save(path("cast", "biscuit", "neutral.png"))
    living_room()
    backyard()
    print("Example art written to", ROOT)


if __name__ == "__main__":
    main()
