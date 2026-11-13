#!/usr/bin/env python3
"""Drawing helpers shared by the placeholder art scripts.

Colors, gradients, a supersampling pen for smooth shapes, and cartoon faces
with moods. tools/demo_assets/starter_library.py uses them for the Studio's
starter characters. Requires Pillow and NumPy.
"""

import numpy as np
from PIL import Image, ImageDraw

S = 3  # Supersampling factor for smooth edges.

INK = (45, 35, 40)
WHITE = (255, 255, 255)
BLUSH = (245, 140, 140, 110)


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
