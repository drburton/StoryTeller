#!/usr/bin/env python3
"""Generates the demo's placeholder art and audio from code.

Everything the demo shows or plays is drawn or synthesized here, so all demo
assets are original. Run from the repository root:

    python3 tools/demo_assets/generate.py

Requires Pillow and NumPy. Output goes to demo/story/.
"""

import math
import os
import random
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join("demo", "story")
WIDTH, HEIGHT = 1152, 648
RATE = 22050


def path(*parts):
    full = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    return full


def vertical_gradient(size, top, bottom):
    w, h = size
    t = np.linspace(0.0, 1.0, h)[:, None, None]
    colors = np.array(top, float) * (1 - t) + np.array(bottom, float) * t
    return Image.fromarray(np.repeat(colors, w, axis=1).astype(np.uint8), "RGB")


# --- Backdrops -------------------------------------------------------------

def bookshelf(draw, x, y, w, h, rng, dim=1.0):
    wood = tuple(int(c * dim) for c in (92, 60, 38))
    dark = tuple(int(c * dim) for c in (60, 38, 24))
    draw.rectangle((x, y, x + w, y + h), fill=dark)
    draw.rectangle((x + 8, y + 8, x + w - 8, y + h - 8), fill=tuple(int(c * 0.7) for c in dark))
    rows = 5
    row_h = (h - 16) / rows
    palette = [(150, 50, 45), (50, 90, 130), (60, 110, 70), (170, 130, 60), (110, 70, 120), (180, 160, 120), (70, 70, 80)]
    for r in range(rows):
        shelf_y = y + 8 + (r + 1) * row_h
        bx = x + 12
        while bx < x + w - 20:
            bw = rng.randint(9, 20)
            bh = rng.randint(int(row_h * 0.55), int(row_h * 0.9))
            color = tuple(int(c * dim * rng.uniform(0.8, 1.1)) for c in rng.choice(palette))
            if rng.random() < 0.08:
                draw.polygon([(bx, shelf_y - 6), (bx + bw, shelf_y - 6), (bx + bw + 14, shelf_y - bh), (bx + 14, shelf_y - bh)], fill=color)
                bx += bw + 16
                continue
            draw.rectangle((bx, shelf_y - 6 - bh, bx + bw, shelf_y - 6), fill=color)
            draw.line((bx + 2, shelf_y - bh + 4, bx + bw - 2, shelf_y - bh + 4), fill=tuple(min(255, c + 40) for c in color), width=2)
            bx += bw + rng.randint(1, 3)
        draw.rectangle((x + 8, shelf_y - 6, x + w - 8, shelf_y + 2), fill=wood)


def library(night=False):
    dim = 0.45 if night else 1.0
    img = vertical_gradient((WIDTH, HEIGHT), [int(c * dim) for c in (120, 84, 58)], [int(c * dim) for c in (78, 52, 36)])
    draw = ImageDraw.Draw(img)
    rng = random.Random(7)
    # Window in the middle.
    wx0, wy0, wx1, wy1 = 470, 70, 682, 380
    sky = vertical_gradient((wx1 - wx0, wy1 - wy0), (20, 28, 60) if night else (150, 200, 240), (40, 50, 90) if night else (215, 235, 250))
    img.paste(sky, (wx0, wy0))
    if night:
        draw.ellipse((600, 105, 650, 155), fill=(235, 235, 210))
        for _ in range(25):
            sx, sy = rng.randint(wx0 + 5, wx1 - 5), rng.randint(wy0 + 5, wy1 - 60)
            draw.point((sx, sy), fill=(220, 220, 255))
    frame = (70, 46, 30) if not night else (40, 28, 20)
    draw.rectangle((wx0 - 10, wy0 - 10, wx1 + 10, wy1 + 10), outline=frame, width=12)
    draw.line(((wx0 + wx1) // 2, wy0, (wx0 + wx1) // 2, wy1), fill=frame, width=8)
    draw.line((wx0, (wy0 + wy1) // 2, wx1, (wy0 + wy1) // 2), fill=frame, width=8)
    # Shelves on both sides.
    for x in (20, 240, 712, 932):
        bookshelf(draw, x, 40, 200, 430, rng, dim)
    # Floor.
    floor = vertical_gradient((WIDTH, HEIGHT - 470), [int(c * dim) for c in (100, 66, 42)], [int(c * dim) for c in (70, 45, 28)])
    img.paste(floor, (0, 470))
    for y in range(490, HEIGHT, 34):
        draw.line((0, y, WIDTH, y), fill=tuple(int(c * dim) for c in (60, 40, 25)), width=2)
    # Lamp glow.
    glow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    for cx in (230, 922):
        gdraw.ellipse((cx - 160, 420, cx + 160, 640), fill=(255, 210, 140, 70 if night else 35))
    glow = glow.filter(ImageFilter.GaussianBlur(40))
    img = Image.alpha_composite(img.convert("RGBA"), glow)
    draw = ImageDraw.Draw(img)
    for cx in (230, 922):
        draw.rectangle((cx - 4, 470, cx + 4, 560), fill=(50, 40, 30))
        draw.polygon([(cx - 40, 470), (cx + 40, 470), (cx + 24, 430), (cx - 24, 430)], fill=(240, 200, 120) if night else (210, 180, 120))
    img.convert("RGB").save(path("backdrops", "library_night.png" if night else "library.png"))


def classroom():
    img = vertical_gradient((WIDTH, HEIGHT), (238, 232, 214), (220, 210, 190)).convert("RGBA")
    draw = ImageDraw.Draw(img)
    # Chalkboard.
    draw.rectangle((90, 90, 560, 330), fill=(120, 90, 60))
    draw.rectangle((104, 104, 546, 316), fill=(46, 78, 62))
    draw.line((150, 160, 330, 160), fill=(200, 210, 200), width=3)
    draw.line((150, 200, 420, 200), fill=(200, 210, 200), width=3)
    draw.line((150, 240, 280, 240), fill=(200, 210, 200), width=3)
    # Windows with morning sky.
    for wx in (660, 900):
        sky = vertical_gradient((200, 300), (170, 210, 245), (250, 225, 190))
        img.paste(sky, (wx, 70))
        draw.rectangle((wx - 6, 64, wx + 206, 376), outline=(245, 245, 240), width=12)
        draw.line((wx + 100, 70, wx + 100, 370), fill=(245, 245, 240), width=8)
    # Sunlight shafts.
    light = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    ldraw = ImageDraw.Draw(light)
    for wx in (660, 900):
        ldraw.polygon([(wx, 370), (wx + 200, 370), (wx - 80, HEIGHT), (wx - 360, HEIGHT)], fill=(255, 240, 200, 60))
    light = light.filter(ImageFilter.GaussianBlur(18))
    # Floor and desks.
    floor = vertical_gradient((WIDTH, HEIGHT - 420), (190, 150, 110), (160, 120, 85)).convert("RGBA")
    img.paste(floor, (0, 420))
    img = Image.alpha_composite(img, light)
    draw = ImageDraw.Draw(img)
    for row, (y, scale) in enumerate([(430, 0.7), (500, 0.85), (580, 1.0)]):
        for col in range(5):
            cx = 140 + col * 220 + (row % 2) * 40
            w, h = 150 * scale, 30 * scale
            draw.polygon([(cx - w / 2, y), (cx + w / 2, y), (cx + w / 2 + 10, y + h), (cx - w / 2 - 10, y + h)], fill=(150, 110, 70))
            draw.rectangle((cx - w / 2, y + h, cx - w / 2 + 6, y + h + 50 * scale), fill=(90, 90, 95))
            draw.rectangle((cx + w / 2 - 6, y + h, cx + w / 2, y + h + 50 * scale), fill=(90, 90, 95))
    img.convert("RGB").save(path("backdrops", "classroom_morning.png"))


def riverside():
    """The river at dusk, for chapter 2."""
    img = vertical_gradient((WIDTH, HEIGHT), (64, 60, 110), (238, 150, 110)).convert("RGBA")
    draw = ImageDraw.Draw(img)
    # Low sun behind the far bank.
    glow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((720, 250, 900, 430), fill=(255, 210, 150, 200))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(24)))
    draw = ImageDraw.Draw(img)
    # Far bank with rooftops.
    rng = random.Random(5)
    x = 0
    while x < WIDTH:
        w = rng.randrange(60, 130)
        h = rng.randrange(30, 90)
        draw.rectangle((x, 330 - h, x + w, 340), fill=(58, 48, 70))
        draw.polygon([(x - 6, 330 - h), (x + w // 2, 300 - h), (x + w + 6, 330 - h)], fill=(52, 42, 62))
        x += w + rng.randrange(4, 20)
    draw.rectangle((0, 336, WIDTH, 350), fill=(48, 40, 58))
    # Water with streaks of reflected light.
    water = vertical_gradient((WIDTH, HEIGHT - 350), (120, 96, 120), (40, 44, 70)).convert("RGBA")
    img.paste(water, (0, 350))
    draw = ImageDraw.Draw(img)
    for i in range(26):
        y = 360 + i * 9
        half = 90 - i * 3
        draw.line((810 - half, y, 810 + half, y), fill=(255, 200, 150, 120), width=2)
    # Near bank: railing and lamp posts.
    draw.polygon([(0, 560), (WIDTH, 520), (WIDTH, HEIGHT), (0, HEIGHT)], fill=(70, 60, 64))
    for post in range(0, WIDTH + 1, 96):
        y = 560 - post * 40 // WIDTH
        draw.line((post, y - 70, post, y), fill=(36, 32, 40), width=6)
    draw.line((0, 490, WIDTH, 450), fill=(36, 32, 40), width=6)
    draw.line((0, 520, WIDTH, 480), fill=(36, 32, 40), width=4)
    for lamp_x in (180, 980):
        y = 560 - lamp_x * 40 // WIDTH
        draw.line((lamp_x, y - 260, lamp_x, y), fill=(30, 28, 34), width=8)
        draw.ellipse((lamp_x - 18, y - 290, lamp_x + 18, y - 254), fill=(255, 226, 160))
    img.convert("RGB").save(path("backdrops", "riverside_evening.png"))


# --- CGs -------------------------------------------------------------------

def window_table(variant):
    """The study table by the library window, used as a CG in chapter 1.
    Variants: "afternoon" (sunlight) and "rain" (after dark, lamp-lit)."""
    rain = variant == "rain"
    dim = 0.5 if rain else 1.0
    img = vertical_gradient((WIDTH, HEIGHT), [int(c * dim) for c in (128, 92, 64)], [int(c * dim) for c in (96, 66, 44)]).convert("RGBA")
    rng = random.Random(11)
    # Window with sky, clouds or rain on the glass.
    wx0, wy0, wx1, wy1 = 236, 40, 916, 410
    sky = vertical_gradient((wx1 - wx0, wy1 - wy0), (32, 40, 66) if rain else (150, 200, 240), (58, 66, 92) if rain else (248, 228, 196)).convert("RGBA")
    if rain:
        sdraw = ImageDraw.Draw(sky)
        for _ in range(140):
            x, y = rng.randint(0, sky.width), rng.randint(0, sky.height)
            sdraw.line((x, y, x - 4, y + rng.randint(14, 34)), fill=(150, 165, 200, 255), width=1)
        for _ in range(40):
            x, y, r = rng.randint(0, sky.width), rng.randint(0, sky.height), rng.randint(2, 5)
            sdraw.ellipse((x - r, y - r, x + r, y + r), fill=(170, 185, 215, 255))
    else:
        clouds = Image.new("RGBA", sky.size, (255, 255, 255, 0))
        cdraw = ImageDraw.Draw(clouds)
        for _ in range(6):
            cx, cy = rng.randint(40, sky.width - 40), rng.randint(30, 200)
            cdraw.ellipse((cx - 90, cy - 26, cx + 90, cy + 26), fill=(255, 255, 255, 150))
        sky = Image.alpha_composite(sky, clouds.filter(ImageFilter.GaussianBlur(14)))
    img.paste(sky, (wx0, wy0))
    draw = ImageDraw.Draw(img)
    frame = (60, 40, 26) if rain else (88, 60, 38)
    draw.rectangle((wx0 - 14, wy0 - 14, wx1 + 14, wy1 + 14), outline=frame, width=16)
    for i in (1, 2):
        x = wx0 + (wx1 - wx0) * i // 3
        draw.line((x, wy0, x, wy1), fill=frame, width=10)
    draw.line((wx0, (wy0 + wy1) // 2, wx1, (wy0 + wy1) // 2), fill=frame, width=10)
    # Table top in perspective, with grain.
    top_y = 392
    draw.polygon([(0, HEIGHT), (WIDTH, HEIGHT), (1040, top_y), (112, top_y)], fill=tuple(int(c * dim) for c in (156, 110, 70)))
    draw.line((112, top_y, 1040, top_y), fill=tuple(int(c * dim) for c in (190, 140, 95)), width=4)
    for i in range(1, 6):
        y = top_y + i * 48
        inset = 112 * (HEIGHT - y) / (HEIGHT - top_y)
        draw.line((inset + 20, y, WIDTH - inset - 20, y), fill=tuple(int(c * dim) for c in (136, 94, 58)), width=1)
    # Sunlight from the window, or a lamp's glow.
    light = Image.new("RGBA", (WIDTH, HEIGHT), (255, 200, 120, 0) if rain else (255, 240, 200, 0))
    ldraw = ImageDraw.Draw(light)
    if rain:
        ldraw.ellipse((700, 380, 1150, 648), fill=(255, 200, 120, 90))
    else:
        ldraw.polygon([(wx0 + 40, wy1), (wx1 - 40, wy1), (wx1 + 120, HEIGHT), (wx0 - 120, HEIGHT)], fill=(255, 240, 200, 55))
    img = Image.alpha_composite(img, light.filter(ImageFilter.GaussianBlur(30)))
    # Two open notebooks.
    paper = tuple(int(c * (0.75 if rain else 1.0)) for c in (246, 242, 230)) + (255,)
    ruling = (160, 175, 200, 255)
    for cx, cy, angle, cover in [(380, 520, 8, (70, 90, 130, 255)), (780, 530, -6, (130, 70, 70, 255))]:
        book = Image.new("RGBA", (300, 190), (0, 0, 0, 0))
        bdraw = ImageDraw.Draw(book)
        bdraw.rectangle((0, 0, 299, 189), fill=cover)
        bdraw.rectangle((8, 6, 145, 183), fill=paper)
        bdraw.rectangle((154, 6, 291, 183), fill=paper)
        for ly in range(30, 175, 16):
            bdraw.line((18, ly, 135, ly), fill=ruling)
            bdraw.line((164, ly, 281, ly), fill=ruling)
        book = book.rotate(angle, expand=True, resample=Image.BICUBIC)
        img.alpha_composite(book, (cx - book.width // 2, cy - book.height // 2))
    # Coffee cups, steaming in the afternoon.
    draw = ImageDraw.Draw(img)
    cup = tuple(int(c * (0.8 if rain else 1.0)) for c in (232, 226, 214))
    for cx, cy in [(160, 470), (960, 480)]:
        draw.ellipse((cx - 28, cy, cx + 28, cy + 20), fill=cup)
        draw.rectangle((cx - 28, cy - 40, cx + 28, cy + 10), fill=cup)
        draw.arc((cx + 18, cy - 30, cx + 46, cy - 2), -90, 90, fill=cup, width=6)
        draw.ellipse((cx - 28, cy - 50, cx + 28, cy - 30), fill=cup)
        draw.ellipse((cx - 22, cy - 46, cx + 22, cy - 34), fill=(90, 58, 36))
    if not rain:
        steam = Image.new("RGBA", (WIDTH, HEIGHT), (255, 255, 255, 0))
        sdraw = ImageDraw.Draw(steam)
        for cx, cy in [(160, 470), (960, 480)]:
            for k in (-8, 8):
                points = [(cx + k + 8 * math.sin(t / 6), cy - 56 - t) for t in range(0, 70, 4)]
                sdraw.line(points, fill=(255, 255, 255, 110), width=4)
        img = Image.alpha_composite(img, steam.filter(ImageFilter.GaussianBlur(3)))
    img.convert("RGB").save(path("cgs", "window_table", f"{variant}.png"))


# --- Characters --------------------------------------------------------------

S = 2  # Supersampling factor for smooth edges.


def character(style, mood):
    w, h = 420 * S, 640 * S
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    skin = style["skin"]
    hair = style["hair"]
    cx = w // 2

    def ellipse(x0, y0, x1, y1, **kw):
        d.ellipse((x0 * S, y0 * S, x1 * S, y1 * S), **kw)

    def poly(points, **kw):
        d.polygon([(x * S, y * S) for x, y in points], **kw)

    def line(points, width, **kw):
        d.line([(x * S, y * S) for x, y in points], width=width * S, **kw)

    def arc(box, start, end, width, **kw):
        d.arc(tuple(v * S for v in box), start, end, width=width * S, **kw)

    # Hair behind the head.
    if style["hair_style"] == "long":
        poly([(110, 170), (310, 170), (330, 430), (90, 430)], fill=hair)
    else:
        ellipse(160, 40, 260, 130, fill=hair)
    # Body.
    poly([(70, 640), (350, 640), (330, 430), (290, 395), (130, 395), (90, 430)], fill=style["outfit"])
    if style["collar"] == "uniform":
        poly([(170, 395), (250, 395), (210, 460)], fill=(245, 245, 245))
        poly([(202, 420), (218, 420), (224, 520), (210, 540), (196, 520)], fill=(185, 40, 50))
    else:
        poly([(175, 395), (245, 395), (210, 480)], fill=(235, 225, 200))
        line([(175, 395), (210, 480)], 6, fill=tuple(max(0, c - 40) for c in style["outfit"]))
        line([(245, 395), (210, 480)], 6, fill=tuple(max(0, c - 40) for c in style["outfit"]))
    # Neck and head.
    d.rectangle(((cx // S - 28) * S, 330 * S, (cx // S + 28) * S, 410 * S), fill=tuple(max(0, c - 15) for c in skin))
    ellipse(115, 130, 305, 360, fill=skin)
    ellipse(105, 230, 130, 280, fill=skin)
    ellipse(290, 230, 315, 280, fill=skin)
    # Bangs.
    if style["hair_style"] == "long":
        poly([(110, 210), (120, 140), (210, 105), (300, 140), (310, 210), (280, 175), (250, 200), (215, 170), (180, 200), (150, 175)], fill=hair)
    else:
        poly([(112, 220), (125, 145), (210, 112), (295, 145), (308, 220), (270, 170), (210, 160), (150, 172)], fill=hair)

    eye_y = 245
    look = (6, -4) if mood == "thinking" else (0, 0)
    for side, ex in ((-1, 170), (1, 250)):
        if mood == "smile":
            arc((ex - 20, eye_y - 10, ex + 20, eye_y + 14), 200, 340, 4, fill=(40, 30, 30))
            continue
        open_h = 30 if mood == "curious" else 24
        ellipse(ex - 20, eye_y - open_h / 2, ex + 20, eye_y + open_h / 2, fill=(250, 250, 250))
        ellipse(ex - 11 + look[0], eye_y - 11 + look[1], ex + 11 + look[0], eye_y + 11 + look[1], fill=style["eyes"])
        ellipse(ex - 5 + look[0], eye_y - 5 + look[1], ex + 5 + look[0], eye_y + 5 + look[1], fill=(25, 20, 20))
        ellipse(ex - 6 + look[0], eye_y - 8 + look[1], ex - 1 + look[0], eye_y - 3 + look[1], fill=(255, 255, 255))
        if mood == "soft":
            d.rectangle(((ex - 22) * S, (eye_y - 16) * S, (ex + 22) * S, (eye_y - 2) * S), fill=skin)
            line([(ex - 20, eye_y - 2), (ex + 20, eye_y - 2)], 3, fill=(60, 40, 40))
    # Brows.
    brows = {
        "neutral": ((-2, 0), (2, 0)), "smile": ((-4, 0), (4, 0)), "curious": ((-8, 8), (8, -8)),
        "thinking": ((4, -2), (-6, -6)), "soft": ((-2, 2), (2, -2)), "smirk": ((-2, 6), (6, 0)),
    }[mood]
    for (ex, (lift_in, lift_out)) in ((170, brows[0]), (250, brows[1])):
        inner = ex + (14 if ex < 210 else -14)
        outer = ex - (14 if ex < 210 else -14)
        line([(outer, eye_y - 28 - lift_out), (inner, eye_y - 28 - lift_in)], 5, fill=tuple(max(0, c - 30) for c in hair))
    # Mouth.
    mouth_y = 305
    mouth_color = (150, 70, 70)
    if mood in ("smile", "soft"):
        arc((190, mouth_y - 16, 230, mouth_y + 8 if mood == "smile" else mouth_y + 2), 20, 160, 4, fill=mouth_color)
    elif mood == "curious":
        ellipse(203, mouth_y - 6, 217, mouth_y + 8, fill=mouth_color)
    elif mood == "smirk":
        arc((200, mouth_y - 14, 236, mouth_y + 6), 10, 100, 4, fill=mouth_color)
        line([(192, mouth_y - 2), (212, mouth_y)], 3, fill=mouth_color)
    elif mood == "thinking":
        line([(198, mouth_y), (222, mouth_y - 3)], 4, fill=mouth_color)
    else:
        line([(196, mouth_y), (224, mouth_y)], 4, fill=mouth_color)
    if mood in ("smile", "soft"):
        blush = Image.new("RGBA", img.size, (0, 0, 0, 0))
        bd = ImageDraw.Draw(blush)
        for bx in (150, 270):
            bd.ellipse(((bx - 18) * S, 272 * S, (bx + 18) * S, 288 * S), fill=(240, 120, 120, 90))
        img = Image.alpha_composite(img, blush)
        d = ImageDraw.Draw(img)
    if style.get("glasses"):
        for ex in (170, 250):
            d.ellipse(((ex - 28) * S, (eye_y - 24) * S, (ex + 28) * S, (eye_y + 24) * S), outline=(60, 50, 40), width=4 * S)
        d.line(((198) * S, eye_y * S, (222) * S, eye_y * S), fill=(60, 50, 40), width=4 * S)
    return img.resize((420, 640), Image.LANCZOS)


ADA = {"skin": (238, 200, 170), "hair": (58, 40, 34), "eyes": (70, 120, 90), "outfit": (70, 110, 85),
       "hair_style": "bun", "collar": "cardigan", "glasses": True}
MIRA = {"skin": (242, 210, 185), "hair": (150, 70, 40), "eyes": (90, 70, 50), "outfit": (40, 55, 95),
        "hair_style": "long", "collar": "uniform"}


def write_profile(cast_id, display_name, color, default_mood, fields=None):
    """Writes a CastProfile. fields maps field names to whole-number starting values."""
    field_lines = ""
    if fields:
        field_lines = "fields = {\n" + ",\n".join(f'"{name}": {value}' for name, value in fields.items()) + "\n}\n"
    with open(path("cast", f"{cast_id}.tres"), "w") as f:
        f.write(f"""[gd_resource type="Resource" script_class="CastProfile" load_steps=4 format=3]

[ext_resource type="Script" path="res://addons/storyteller/stage/cast_profile.gd" id="1_profile"]
[ext_resource type="Script" path="res://addons/storyteller/stage/sprite_set_look.gd" id="2_look"]

[sub_resource type="Resource" id="Resource_look"]
script = ExtResource("2_look")
folder = "res://demo/story/cast/{cast_id}"

[resource]
script = ExtResource("1_profile")
id = "{cast_id}"
display_name = "{display_name}"
name_color = Color({color[0]}, {color[1]}, {color[2]}, 1)
look = SubResource("Resource_look")
default_mood = "{default_mood}"
{field_lines}""")


def props():
    img = Image.new("RGBA", (180, 130), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(10, 40), (90, 20), (90, 120), (10, 110)], fill=(150, 50, 45))
    d.polygon([(90, 20), (170, 40), (170, 110), (90, 120)], fill=(130, 40, 38))
    d.polygon([(18, 42), (88, 26), (88, 112), (18, 104)], fill=(245, 238, 220))
    d.polygon([(92, 26), (162, 42), (162, 104), (92, 112)], fill=(240, 232, 212))
    for i in range(6):
        y = 46 + i * 9
        d.line((28, y + 4 - i, 80, y - 8 - i), fill=(150, 140, 120), width=2)
        d.line((100, y - 10 - i, 152, y + 2 - i), fill=(150, 140, 120), width=2)
    img.save(path("props", "book.png"))


# --- Choice pictures -----------------------------------------------------------

def choice_pictures():
    """Pictures for the rain choice in chapter 1 (choose(style = "pictures"))."""
    size = (480, 300)

    def base(top, bottom):
        return vertical_gradient(size, top, bottom).convert("RGBA")

    # Share mine: an open umbrella in the rain.
    img = base((38, 52, 78), (22, 28, 44))
    d = ImageDraw.Draw(img)
    rng = random.Random(7)
    for _ in range(90):
        x, y = rng.randrange(0, 480), rng.randrange(0, 300)
        d.line((x, y, x - 6, y + 18), fill=(150, 175, 215), width=1)
    d.pieslice((120, 60, 360, 240), 180, 360, fill=(196, 72, 64))
    for i in range(5):
        x0 = 120 + i * 48
        d.arc((x0, 130, x0 + 48, 170), 180, 360, fill=(150, 50, 46), width=4)
    d.line((240, 150, 240, 262), fill=(70, 50, 40), width=6)
    d.arc((222, 246, 246, 276), 0, 180, fill=(70, 50, 40), width=6)
    img.save(path("choices", "umbrella.png"))

    # Wait it out here: a lamp-lit armchair by a dark window.
    img = base((58, 44, 34), (36, 26, 20))
    d = ImageDraw.Draw(img)
    d.rectangle((280, 40, 440, 190), fill=(24, 32, 52))
    d.rectangle((280, 40, 440, 190), outline=(110, 82, 58), width=8)
    d.line((360, 40, 360, 190), fill=(110, 82, 58), width=6)
    for i in range(12):
        x = 292 + i * 13
        d.line((x, 52 + (i * 7) % 40, x - 4, 64 + (i * 7) % 40), fill=(120, 140, 180), width=1)
    d.rounded_rectangle((70, 150, 250, 270), 18, fill=(120, 60, 52))
    d.rounded_rectangle((90, 110, 230, 190), 16, fill=(140, 72, 60))
    d.rounded_rectangle((56, 160, 96, 260), 12, fill=(108, 54, 46))
    d.rounded_rectangle((224, 160, 264, 260), 12, fill=(108, 54, 46))
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((-40, -60, 200, 160), fill=(255, 210, 140, 90))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(30)))
    d = ImageDraw.Draw(img)
    d.polygon([(40, 30), (110, 30), (125, 70), (25, 70)], fill=(236, 200, 130))
    d.line((75, 70, 75, 150), fill=(60, 44, 34), width=4)
    img.save(path("choices", "armchair.png"))

    # Run for it: an open door onto a rainy street.
    img = base((46, 40, 36), (30, 26, 24))
    d = ImageDraw.Draw(img)
    d.rectangle((150, 40, 330, 290), fill=(30, 44, 70))
    rng = random.Random(11)
    for _ in range(60):
        x, y = rng.randrange(155, 325), rng.randrange(45, 285)
        d.line((x, y, x - 4, y + 14), fill=(150, 175, 215), width=1)
    d.rectangle((150, 230, 330, 290), fill=(40, 52, 74))
    d.ellipse((190, 250, 290, 270), fill=(70, 90, 120))
    d.polygon([(330, 40), (400, 20), (400, 300), (330, 290)], fill=(96, 64, 42))
    d.ellipse((380, 160, 392, 172), fill=(210, 180, 90))
    d.rectangle((140, 30, 340, 40), fill=(80, 56, 40))
    d.rectangle((140, 30, 150, 290), fill=(80, 56, 40))
    img.save(path("choices", "door.png"))


# --- Audio -------------------------------------------------------------------

def save_wav(name, samples):
    samples = np.clip(samples, -1.0, 1.0)
    data = (samples * 32767 * 0.8).astype("<i2").tobytes()
    with wave.open(path("audio", name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def note(freq, seconds, decay=3.0):
    t = np.arange(int(RATE * seconds)) / RATE
    env = np.exp(-decay * t) * np.minimum(1.0, t * 200)
    return env * (np.sin(2 * math.pi * freq * t) + 0.25 * np.sin(4 * math.pi * freq * t))


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def music(name, chords, beat=0.42, pattern=(0, 1, 2, 1, 3, 2, 1, 2)):
    bar = beat * len(pattern)
    total = np.zeros(int(RATE * bar * len(chords)) + RATE)
    for c, chord in enumerate(chords):
        start = int(c * bar * RATE)
        pad_t = np.arange(int(bar * RATE)) / RATE
        pad_env = np.minimum(1.0, pad_t * 1.5) * np.minimum(1.0, (bar - pad_t) * 1.5)
        for n in chord[:3]:
            total[start:start + len(pad_t)] += 0.06 * pad_env * np.sin(2 * math.pi * midi(n - 12) * pad_t)
        for i, step in enumerate(pattern):
            n = chord[step % len(chord)] + (12 if i == len(pattern) - 2 else 0)
            tone = 0.22 * note(midi(n), beat * 3)
            s = start + int(i * beat * RATE)
            total[s:s + len(tone)] += tone[: len(total) - s]
    length = int(RATE * bar * len(chords))
    tail = total[length:]
    total = total[:length]
    total[: len(tail)] += tail
    save_wav(f"music/{name}.wav", total / max(1e-6, np.abs(total).max()) * 0.7)


def chime():
    t = np.arange(int(RATE * 1.6)) / RATE
    sound = sum(a * np.exp(-d * t) * np.sin(2 * math.pi * f * t) for f, a, d in [(880, 0.5, 2.5), (1320, 0.3, 3.5), (2210, 0.15, 5.0)])
    save_wav("sounds/chime.wav", sound * np.minimum(1.0, t * 400))


def page_turn():
    rng = np.random.default_rng(3)
    t = np.arange(int(RATE * 0.35)) / RATE
    noise = np.diff(rng.standard_normal(len(t) + 1))
    env = np.sin(np.pi * t / t[-1]) ** 2
    save_wav("sounds/page_turn.wav", 0.35 * noise * env)


def rain():
    rng = np.random.default_rng(5)
    seconds = 4.0
    n = int(RATE * seconds)
    noise = rng.standard_normal(n + RATE)
    smooth = np.convolve(noise, np.ones(6) / 6, mode="same")
    drops = np.zeros_like(smooth)
    for _ in range(140):
        p = rng.integers(0, len(drops) - 400)
        drops[p:p + 400] += rng.uniform(0.2, 0.6) * np.exp(-np.arange(400) / 60) * rng.standard_normal(400)
    sound = 0.25 * smooth + 0.2 * drops
    fade = RATE // 2
    loop = sound[:n].copy()
    loop[:fade] = loop[:fade] * np.linspace(0, 1, fade) + sound[n:n + fade] * np.linspace(1, 0, fade)
    save_wav("ambience/rain.wav", loop)


def main():
    library(False)
    library(True)
    classroom()
    riverside()
    window_table("afternoon")
    window_table("rain")
    for mood in ("neutral", "smile", "curious", "thinking"):
        character(ADA, mood).save(path("cast", "ada", f"{mood}.png"))
    for mood in ("neutral", "smile", "curious", "soft", "smirk"):
        character(MIRA, mood).save(path("cast", "mira", f"{mood}.png"))
    write_profile("ada", "Ada", (0.55, 0.85, 0.65), "neutral")
    write_profile("mira", "Mira", (0.95, 0.6, 0.45), "neutral", {"friendship": 0})
    props()
    choice_pictures()
    music("library_theme", [[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 64]])
    music("quiet_morning", [[62, 66, 69, 73], [59, 62, 66, 69], [55, 59, 62, 66], [57, 61, 64, 67]], beat=0.36)
    chime()
    page_turn()
    rain()
    print("Demo assets written to", ROOT)


if __name__ == "__main__":
    main()
