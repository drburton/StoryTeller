#!/usr/bin/env python3
"""Draws the art and makes the sounds of the Studio's starter library.

Backgrounds (park, forest, castle, space, beach), characters (Maya, Sam,
Robo the robot, and Whiskers the cat, each with several faces), music, and
sounds, in the same style as the "Where's Biscuit?" example. Run from the
repository root:

    python3 tools/demo_assets/starter_library.py

Requires Pillow and NumPy. Output goes to studio/library/art/.
"""

import math
import os
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from wheres_biscuit import INK, WHITE, Pen, darker, face, tear, vertical_gradient  # noqa: E402
from generate import RATE, midi, note  # noqa: E402

ROOT = os.path.join("studio", "library", "art")
WIDTH, HEIGHT = 1152, 648
MOODS = ("neutral", "happy", "sad", "surprised", "thinking")


def path(*parts):
    full = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    return full


def glow(img, box, color, blur):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(box, fill=color)
    return Image.alpha_composite(img, layer.filter(ImageFilter.GaussianBlur(blur)))


def cloud(d, cx, cy, scale=1.0, color=(255, 255, 255)):
    for dx, r in ((-50, 34), (0, 46), (50, 34)):
        d.ellipse((cx + (dx - r) * scale, cy - r * scale, cx + (dx + r) * scale, cy + r * scale), fill=color)


def tree(d, x, ground, height, radius, trunk=(120, 85, 55), leaves=(90, 160, 80)):
    d.rectangle((x - radius * 0.18, ground - height, x + radius * 0.18, ground), fill=trunk)
    top = ground - height
    for bx, by, r in ((0, 0, radius), (-radius * 0.7, radius * 0.45, radius * 0.7), (radius * 0.7, radius * 0.45, radius * 0.7)):
        d.ellipse((x + bx - r, top + by - r, x + bx + r, top + by + r), fill=leaves)


# --- Backgrounds --------------------------------------------------------------

def park():
    img = vertical_gradient((WIDTH, HEIGHT), (125, 190, 245), (215, 238, 250)).convert("RGBA")
    img = glow(img, (60, 30, 220, 190), (255, 240, 160, 150), 20)
    d = ImageDraw.Draw(img)
    d.ellipse((100, 70, 180, 150), fill=(255, 225, 110))
    cloud(d, 520, 80)
    cloud(d, 880, 120, 0.8)
    # Hills and trees far away.
    d.ellipse((-200, 300, 600, 620), fill=(140, 200, 120))
    d.ellipse((450, 320, 1400, 640), fill=(125, 190, 110))
    for x, h, r in ((90, 170, 60), (300, 150, 50), (980, 180, 66), (1100, 140, 46)):
        tree(d, x, 440, h, r, leaves=(95, 165, 85))
    grass = vertical_gradient((WIDTH, HEIGHT - 430), (125, 200, 100), (95, 170, 80))
    img.paste(grass, (0, 430))
    d = ImageDraw.Draw(img)
    # Path, pond, bench, and a lamp.
    d.polygon([(500, 430), (640, 430), (900, HEIGHT), (320, HEIGHT)], fill=(225, 205, 160))
    d.ellipse((760, 470, 1080, 560), fill=(110, 170, 230))
    d.ellipse((800, 486, 1040, 546), fill=(140, 195, 245))
    d.rounded_rectangle((120, 470, 340, 492), radius=6, fill=(160, 100, 60))
    d.rounded_rectangle((120, 440, 340, 460), radius=6, fill=(160, 100, 60))
    for x in (140, 310):
        d.rectangle((x, 490, x + 12, 540), fill=(70, 70, 75))
    d.rectangle((436, 300, 446, 520), fill=(60, 60, 70))
    d.ellipse((420, 280, 462, 322), fill=(255, 235, 150))
    for i, x in enumerate(range(40, 1150, 90)):
        y = 600 + (i % 2) * 18
        color = [(240, 90, 90), (250, 210, 80), (200, 120, 230)][i % 3]
        for ax, ay in ((-7, 0), (7, 0), (0, -7), (0, 7)):
            d.ellipse((x + ax - 6, y + ay - 6, x + ax + 6, y + ay + 6), fill=color)
    img.convert("RGB").save(path("backdrops", "park.png"))


def forest():
    img = vertical_gradient((WIDTH, HEIGHT), (150, 200, 170), (70, 120, 80)).convert("RGBA")
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(11)
    # Three rows of trees, far to near, darker as they come closer.
    for row, (shade, trunk, scale) in enumerate((((120, 175, 120), (110, 90, 70), 0.6), ((80, 140, 80), (95, 70, 50), 0.85), ((55, 110, 60), (80, 55, 40), 1.1))):
        ground = 400 + row * 70
        for x in range(-40, WIDTH + 80, int(140 * scale)):
            x += int(rng.integers(-30, 30))
            tree(d, x, ground, int(230 * scale), int(75 * scale), trunk=trunk, leaves=shade)
    floor = vertical_gradient((WIDTH, HEIGHT - 520), (90, 130, 70), (70, 105, 55))
    img.paste(floor, (0, 520))
    # Light through the leaves.
    rays = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    for x in (260, 560, 860):
        rd.polygon([(x, 0), (x + 60, 0), (x + 200, HEIGHT), (x + 80, HEIGHT)], fill=(255, 250, 200, 45))
    img = Image.alpha_composite(img, rays.filter(ImageFilter.GaussianBlur(8)))
    d = ImageDraw.Draw(img)
    # Mushrooms and a log.
    for x, y, s in ((180, 590, 1.0), (230, 600, 0.7), (960, 585, 0.9)):
        d.rectangle((x - 8 * s, y - 24 * s, x + 8 * s, y), fill=(245, 235, 215))
        d.chord((x - 30 * s, y - 50 * s, x + 30 * s, y - 10 * s), 180, 360, fill=(220, 70, 60))
        for dx in (-12, 8):
            d.ellipse((x + (dx - 4) * s, y - 40 * s, x + (dx + 4) * s, y - 32 * s), fill=WHITE)
    d.rounded_rectangle((520, 560, 780, 610), radius=25, fill=(120, 85, 55))
    d.ellipse((750, 560, 800, 610), fill=(170, 130, 90))
    d.ellipse((765, 575, 785, 595), fill=(140, 100, 65))
    img.convert("RGB").save(path("backdrops", "forest.png"))


def castle():
    img = vertical_gradient((WIDTH, HEIGHT), (250, 190, 150), (255, 230, 190)).convert("RGBA")
    d = ImageDraw.Draw(img)
    cloud(d, 200, 110, 0.9, (255, 245, 235))
    cloud(d, 960, 80, 0.7, (255, 245, 235))
    d.ellipse((-300, 420, 1450, 900), fill=(120, 175, 95))
    stone, dark = (190, 185, 200), (150, 145, 165)
    # Towers with pointed roofs and flags.
    for x, top, roof in ((360, 150, (90, 110, 200)), (780, 150, (90, 110, 200)), (570, 90, (200, 70, 90))):
        d.rectangle((x - 60, top, x + 60, 500), fill=stone)
        for bx in range(x - 60, x + 60, 30):
            d.rectangle((bx, top - 20, bx + 18, top), fill=stone)
        d.polygon([(x - 72, top - 20), (x, top - 150), (x + 72, top - 20)], fill=roof)
        d.line((x, top - 150, x, top - 200), fill=(80, 70, 70), width=4)
        d.polygon([(x, top - 200), (x + 46, top - 186), (x, top - 172)], fill=(250, 210, 80))
        d.rounded_rectangle((x - 16, top + 60, x + 16, top + 110), radius=16, fill=(70, 60, 80))
    # Walls, battlements, and a gate.
    d.rectangle((300, 300, 840, 500), fill=stone)
    for bx in range(300, 840, 36):
        d.rectangle((bx, 280, bx + 22, 300), fill=stone)
    for y in range(320, 500, 36):
        for bx in range(300 + (y // 36 % 2) * 30, 840, 60):
            d.rectangle((bx, y, bx + 56, y + 32), outline=dark, width=2)
    d.chord((510, 360, 630, 500), 180, 360, fill=(110, 80, 60))
    d.rectangle((510, 430, 630, 500), fill=(110, 80, 60))
    for x in range(522, 630, 22):
        d.line((x, 380, x, 500), fill=(80, 60, 45), width=4)
    d.polygon([(470, 648), (540, 500), (600, 500), (690, 648)], fill=(215, 195, 150))
    img.convert("RGB").save(path("backdrops", "castle.png"))


def space():
    img = vertical_gradient((WIDTH, HEIGHT), (15, 15, 45), (45, 30, 80)).convert("RGBA")
    rng = np.random.default_rng(7)
    d = ImageDraw.Draw(img)
    for _ in range(220):
        x, y = rng.integers(0, WIDTH), rng.integers(0, 470)
        r = rng.choice([1, 1, 1, 2, 3])
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 230))
    img = glow(img, (700, 40, 1000, 340), (255, 160, 120, 90), 30)
    d = ImageDraw.Draw(img)
    # A ringed planet and a small blue and green planet.
    d.ellipse((760, 100, 940, 280), fill=(240, 160, 110))
    d.arc((700, 160, 1000, 220), 0, 180, fill=(250, 220, 170), width=10)
    d.chord((760, 100, 940, 280), 200, 340, fill=(250, 190, 140))
    d.ellipse((150, 80, 250, 180), fill=(80, 140, 230))
    d.ellipse((170, 100, 215, 140), fill=(110, 190, 110))
    d.ellipse((205, 135, 235, 165), fill=(110, 190, 110))
    # Moon ground with craters, and a small rocket.
    d.ellipse((-200, 440, 1350, 900), fill=(175, 175, 190))
    for x, y, r in ((200, 560, 50), (520, 520, 30), (860, 580, 60), (1040, 520, 26)):
        d.ellipse((x - r, y - r * 0.4, x + r, y + r * 0.4), fill=(145, 145, 160))
        d.ellipse((x - r * 0.8, y - r * 0.3, x + r * 0.8, y + r * 0.35), fill=(160, 160, 175))
    d.rounded_rectangle((640, 400, 700, 520), radius=26, fill=(235, 235, 245))
    d.polygon([(640, 430), (670, 350), (700, 430)], fill=(220, 70, 80))
    d.polygon([(640, 490), (610, 530), (640, 520)], fill=(220, 70, 80))
    d.polygon([(700, 490), (730, 530), (700, 520)], fill=(220, 70, 80))
    d.ellipse((656, 430, 684, 458), fill=(110, 170, 240))
    img.convert("RGB").save(path("backdrops", "space.png"))


def beach():
    img = vertical_gradient((WIDTH, HEIGHT), (110, 190, 245), (200, 235, 250)).convert("RGBA")
    img = glow(img, (900, 40, 1060, 200), (255, 240, 160, 160), 20)
    d = ImageDraw.Draw(img)
    d.ellipse((940, 80, 1020, 160), fill=(255, 225, 110))
    cloud(d, 300, 100)
    sea = vertical_gradient((WIDTH, 130), (60, 150, 210), (90, 185, 220))
    img.paste(sea, (0, 340))
    d = ImageDraw.Draw(img)
    for y in (370, 410, 450):
        for x in range(0, WIDTH, 80):
            d.arc((x, y, x + 60, y + 16), 200, 340, fill=(220, 240, 250), width=3)
    sand = vertical_gradient((WIDTH, HEIGHT - 460), (245, 225, 170), (230, 205, 145))
    img.paste(sand, (0, 460))
    d = ImageDraw.Draw(img)
    d.polygon([(0, 470), (WIDTH, 455), (WIDTH, 480), (0, 490)], fill=(250, 245, 230))
    # Umbrella, towel, bucket, and shells.
    d.line((300, 380, 330, 600), fill=(120, 90, 60), width=8)
    d.chord((160, 330, 440, 470), 180, 360, fill=(240, 90, 90))
    for i in range(1, 6, 2):
        a0, a1 = 180 + i * 30, 180 + (i + 1) * 30
        d.pieslice((160, 330, 440, 470), a0, a1, fill=(255, 245, 235))
    d.polygon([(560, 560), (820, 540), (850, 610), (590, 630)], fill=(90, 160, 230))
    d.polygon([(580, 575), (830, 556), (838, 572), (588, 592)], fill=(255, 255, 255))
    d.polygon([(950, 560), (1010, 560), (1000, 620), (960, 620)], fill=(250, 210, 80))
    d.arc((950, 530, 1010, 580), 180, 360, fill=(200, 80, 60), width=5)
    for x, y in ((120, 600), (460, 615), (1080, 590)):
        d.chord((x - 16, y - 14, x + 16, y + 14), 180, 360, fill=(250, 200, 190))
    img.convert("RGB").save(path("backdrops", "beach.png"))


# --- Characters ---------------------------------------------------------------

MAYA = {"skin": (150, 100, 72), "hair": (40, 28, 25), "shirt": (250, 195, 60), "pants": (80, 70, 140),
        "shoes": (220, 80, 110), "badge": "heart"}
SAM = {"skin": (230, 180, 140), "hair": (200, 110, 50), "shirt": (70, 170, 120), "pants": (60, 60, 75),
       "shoes": (60, 60, 60), "badge": "circle"}


def kid(style, mood, hair):
    """A child sprite, 400 x 560 pixels, standing on the bottom edge."""
    p = Pen(400, 560)
    cx = 200
    skin, shirt = style["skin"], style["shirt"]
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
    if style["badge"] == "heart":
        p.ellipse((cx - 30, 350, cx + 2, 382), fill=(235, 80, 110))
        p.ellipse((cx - 2, 350, cx + 30, 382), fill=(235, 80, 110))
        p.poly([(cx - 29, 372), (cx, 408), (cx + 29, 372)], fill=(235, 80, 110))
    else:
        p.ellipse((cx - 26, 350, cx + 26, 402), fill=(255, 255, 255))
        p.ellipse((cx - 12, 364, cx + 12, 388), fill=darker(shirt, 20))
    if hair == "puffs":
        p.ellipse((52, 10, 152, 110), fill=style["hair"])
        p.ellipse((248, 10, 348, 110), fill=style["hair"])
    p.ellipse((70, 165, 106, 215), fill=skin)
    p.ellipse((294, 165, 330, 215), fill=skin)
    p.ellipse((84, 40, 316, 290), fill=skin)
    if hair == "puffs":
        p.chord((80, 34, 320, 230), 180, 360, fill=style["hair"])
        p.poly([(84, 132), (140, 96), (200, 110), (260, 96), (316, 132), (316, 110), (84, 110)], fill=style["hair"])
    else:
        # Curls.
        for i in range(9):
            x = 92 + i * 27
            y = 60 + abs(i - 4) * 9
            p.ellipse((x - 26, y - 26, x + 26, y + 26), fill=style["hair"])
        p.chord((84, 40, 316, 220), 180, 360, fill=style["hair"])
    face(p, cx, 180, 46, 16, 20, 238, mood)
    p.blush([(108, 210, 146, 232), (254, 210, 292, 232)])
    if hair == "curls":
        # Glasses.
        for ex in (cx - 46, cx + 46):
            p.ellipse((ex - 32, 150, ex + 32, 210), outline=(40, 40, 50), width=6)
        p.line([(cx - 14, 176), (cx + 14, 176)], 6, fill=(40, 40, 50))
    if mood == "sad":
        tear(p, 150, 204)
    return p.done()


def robot(mood):
    """Robo the robot, 380 x 540 pixels, with its face on a screen."""
    p = Pen(380, 540)
    cx = 190
    metal, dark, glow_color = (170, 185, 205), (120, 135, 160), (120, 230, 220)
    p.rect((110, 470, 180, 536), radius=12, fill=dark)
    p.rect((200, 470, 270, 536), radius=12, fill=dark)
    p.rect((90, 280, 290, 480), radius=30, fill=metal)
    p.rect((50, 300, 96, 440), radius=20, fill=dark)
    p.rect((284, 300, 330, 440), radius=20, fill=dark)
    for i, color in enumerate(((240, 90, 90), (250, 210, 80), (110, 200, 120))):
        p.ellipse((130 + i * 46, 330, 158 + i * 46, 358), fill=color)
    p.rect((130, 390, 250, 420), radius=10, fill=dark)
    p.line([(cx, 40), (cx, 80)], 6, fill=dark)
    p.ellipse((cx - 16, 20, cx + 16, 52), fill=(240, 90, 90))
    p.rect((60, 80, 320, 270), radius=40, fill=metal)
    p.rect((86, 104, 294, 246), radius=24, fill=(30, 45, 60))
    eye_y, mouth_y = 160, 214
    for ex in (cx - 52, cx + 52):
        if mood == "happy":
            p.arc((ex - 26, eye_y - 18, ex + 26, eye_y + 26), 200, 340, 8, fill=glow_color)
        elif mood == "surprised":
            p.ellipse((ex - 22, eye_y - 22, ex + 22, eye_y + 22), outline=glow_color, width=7)
        elif mood == "sad":
            p.rect((ex - 22, eye_y - 4, ex + 22, eye_y + 10), radius=6, fill=glow_color)
            p.line([(ex - 20, eye_y - 24 + (10 if ex < cx else 0)), (ex + 20, eye_y - 14 - (10 if ex < cx else 0))], 5, fill=glow_color)
        else:
            shift = 10 if mood == "thinking" else 0
            p.rect((ex - 16 + shift, eye_y - 18, ex + 16 + shift, eye_y + 18), radius=8, fill=glow_color)
    if mood == "happy":
        p.arc((cx - 40, mouth_y - 30, cx + 40, mouth_y + 14), 20, 160, 7, fill=glow_color)
    elif mood == "sad":
        p.arc((cx - 34, mouth_y - 6, cx + 34, mouth_y + 30), 200, 340, 7, fill=glow_color)
    elif mood == "surprised":
        p.ellipse((cx - 14, mouth_y - 14, cx + 14, mouth_y + 14), outline=glow_color, width=6)
    elif mood == "thinking":
        for i in range(3):
            p.ellipse((cx - 30 + i * 24, mouth_y - 5, cx - 20 + i * 24, mouth_y + 5), fill=glow_color)
    else:
        p.line([(cx - 34, mouth_y), (cx + 34, mouth_y)], 7, fill=glow_color)
    return p.done()


def cat(mood):
    """Whiskers the cat, 320 x 320 pixels, sitting."""
    p = Pen(320, 320)
    cx = 160
    fur, light = (240, 150, 70), (255, 220, 180)
    p.line([(250, 290), (300, 250), (290, 190)], 22, fill=fur)
    p.ellipse((70, 160, 250, 318), fill=fur)
    p.ellipse((115, 200, 205, 310), fill=light)
    p.ellipse((86, 290, 136, 318), fill=light)
    p.ellipse((184, 290, 234, 318), fill=light)
    p.poly([(70, 90), (82, 10), (140, 60)], fill=fur)
    p.poly([(250, 90), (238, 10), (180, 60)], fill=fur)
    p.poly([(86, 76), (92, 32), (124, 60)], fill=(250, 180, 180))
    p.poly([(234, 76), (228, 32), (196, 60)], fill=(250, 180, 180))
    p.ellipse((56, 40, 264, 210), fill=fur)
    for x in (110, 150, 190):
        p.line([(x, 46), (x + 10, 80)], 7, fill=darker(fur, 45))
    face(p, cx, 116, 44, 13, 17, 166, mood)
    p.poly([(cx - 10, 146), (cx + 10, 146), (cx, 158)], fill=(230, 110, 130))
    for side in (-1, 1):
        for dy in (-6, 6):
            p.line([(cx + side * 34, 156 + dy), (cx + side * 92, 150 + dy * 2.5)], 3, fill=INK)
    if mood == "sad":
        tear(p, cx - 54, 130)
    return p.done()


def write_profile(cast_id, display_name, color):
    import json
    with open(path("cast", cast_id, "profile.json"), "w") as f:
        json.dump({"display_name": display_name, "name_color": color, "default_mood": "neutral"}, f, indent="\t")
        f.write("\n")


# --- Music and sounds -----------------------------------------------------------

def save_wav(name, samples):
    samples = np.clip(samples, -1.0, 1.0)
    data = (samples * 32767 * 0.8).astype("<i2").tobytes()
    with wave.open(path("audio", name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def tune(name, melody, chords, beat):
    """A melody over held chords; melody is (midi note or None, beats)."""
    length = int(RATE * beat * sum(b for _, b in melody))
    total = np.zeros(length + RATE)
    pos = 0.0
    for n, beats in melody:
        if n is not None:
            tone = 0.25 * note(midi(n), beat * beats * 2.5, decay=2.5)
            s = int(pos * RATE)
            total[s:s + len(tone)] += tone[: len(total) - s]
        pos += beat * beats
    bar = length / len(chords)
    t = np.arange(int(bar)) / RATE
    env = np.minimum(1.0, t * 3) * np.minimum(1.0, (t[-1] - t) * 3)
    for i, chord in enumerate(chords):
        s = int(i * bar)
        for n in chord:
            total[s:s + len(t)] += 0.05 * env * np.sin(2 * math.pi * midi(n - 12) * t)
    tail = total[length:]
    total = total[:length]
    total[: len(tail)] += tail
    save_wav(f"music/{name}.wav", total / max(1e-6, np.abs(total).max()) * 0.7)


def pop():
    t = np.arange(int(RATE * 0.18)) / RATE
    freq = 900 * np.exp(-14 * t) + 300
    save_wav("sounds/pop.wav", 0.6 * np.exp(-22 * t) * np.sin(2 * math.pi * np.cumsum(freq) / RATE))


def whoosh():
    rng = np.random.default_rng(9)
    t = np.arange(int(RATE * 0.7)) / RATE
    noise = np.convolve(rng.standard_normal(len(t)), np.ones(12) / 12, mode="same")
    save_wav("sounds/whoosh.wav", 1.2 * noise * np.sin(np.pi * t / t[-1]) ** 2)


def magic():
    t = np.arange(int(RATE * 1.2)) / RATE
    sound = np.zeros_like(t)
    for i, n in enumerate((72, 76, 79, 84, 88)):
        s = int(i * 0.08 * RATE)
        tone = note(midi(n), 1.2 - i * 0.08, decay=4.0)
        sound[s:s + len(tone)] += 0.3 * tone[: len(sound) - s]
    save_wav("sounds/magic.wav", sound)


def main():
    park()
    forest()
    castle()
    space()
    beach()
    for mood in MOODS:
        kid(MAYA, mood, "puffs").save(path("cast", "maya", f"{mood}.png"))
        kid(SAM, mood, "curls").save(path("cast", "sam", f"{mood}.png"))
        robot(mood).save(path("cast", "robo", f"{mood}.png"))
        cat(mood).save(path("cast", "whiskers", f"{mood}.png"))
    write_profile("maya", "Maya", "#f0b030")
    write_profile("sam", "Sam", "#46aa78")
    write_profile("robo", "Robo", "#78e6dc")
    write_profile("whiskers", "Whiskers", "#f09646")
    tune("adventure", [(67, 1), (72, 1), (74, 1), (76, 2), (74, 1), (72, 1), (74, 1), (79, 2), (77, 1), (76, 1),
                       (74, 1), (72, 1), (71, 1), (72, 3), (None, 1)],
         [[60, 64, 67], [65, 69, 72], [67, 71, 74], [60, 64, 67]], 0.3)
    tune("mystery", [(69, 2), (72, 1), (71, 1), (69, 2), (64, 2), (65, 2), (69, 1), (68, 1), (69, 3), (None, 1)],
         [[57, 60, 64], [53, 57, 60], [52, 56, 59], [57, 60, 64]], 0.42)
    pop()
    whoosh()
    magic()
    print("Starter library written to", ROOT)


if __name__ == "__main__":
    main()
