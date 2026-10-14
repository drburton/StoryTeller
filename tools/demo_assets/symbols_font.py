#!/usr/bin/env python3
"""Draws StoryTeller Symbols, a small font with the symbols StoryTeller's
screens and the Studio show: arrows, triangles, music notes, a house, a
pencil, and a few more.

Godot's built-in font has none of them. On desktops and tablets Godot
borrows them from the system's fonts, but a web page has no system fonts,
so a web game showed empty boxes. The Story autoload adds this font as a
fallback to Godot's default font (addons/storyteller/core/story.gd).

Every glyph is drawn here from simple shapes, so the font is original and
MIT licensed like the rest of StoryTeller. Run from the repository root:

    python3 tools/demo_assets/symbols_font.py

Requires fontTools (pip install fonttools). Output goes to
addons/storyteller/ui/storyteller_symbols.ttf.
"""

import math
import os

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

OUT = os.path.join("addons", "storyteller", "ui", "storyteller_symbols.ttf")
UNITS = 1000


# --- Shapes -----------------------------------------------------------------

def area(points):
    return sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(points, points[1:] + points[:1])) / 2


def outer(points):
    """A filled shape: clockwise, as TrueType draws outlines."""
    return points if area(points) < 0 else points[::-1]


def hole(points):
    """A hole cut out of the shape around it: counterclockwise."""
    return points if area(points) > 0 else points[::-1]


def rect(x0, y0, x1, y1):
    return [(x0, y0), (x0, y1), (x1, y1), (x1, y0)]


def circle(cx, cy, rx, ry=None, turn=0.0, steps=32):
    ry = rx if ry is None else ry
    points = []
    for i in range(steps):
        a = 2 * math.pi * i / steps
        x, y = rx * math.cos(a), ry * math.sin(a)
        c, s = math.cos(turn), math.sin(turn)
        points.append((cx + x * c - y * s, cy + x * s + y * c))
    return points


def bar(x0, y0, x1, y1, width):
    """A straight stroke from one point to another."""
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    nx, ny = -dy / length * width / 2, dx / length * width / 2
    return [(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)]


def ring_part(cx, cy, r_out, r_in, start, end, steps=24):
    """Part of a ring from angle start to end, in degrees."""
    angles = [math.radians(start + (end - start) * i / steps) for i in range(steps + 1)]
    out = [(cx + r_out * math.cos(a), cy + r_out * math.sin(a)) for a in angles]
    inner = [(cx + r_in * math.cos(a), cy + r_in * math.sin(a)) for a in reversed(angles)]
    return out + inner


def mirror(contours, width):
    return [[(width - x, y) for x, y in contour] for contour in contours]


def turned(points, angle, cx, cy):
    c, s = math.cos(angle), math.sin(angle)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in points]


# --- Glyphs -----------------------------------------------------------------

def house():
    return [outer([(130, 0), (380, 0), (380, 230), (520, 230), (520, 0), (770, 0), (770, 380), (450, 690), (130, 380)])]


def pencil():
    # Drawn lying down with its point on the left, then turned 45 degrees.
    tip = [(0, 0), (140, 75), (140, -75)]
    body = rect(160, -75, 560, 75)
    cap = rect(580, -75, 660, 75)
    shapes = []
    for shape in (tip, body, cap):
        moved = [(x + 120, y + 90) for x, y in shape]
        shapes.append(outer(turned(moved, math.radians(45), 120, 90)))
    return shapes


def undo_arrow():
    return [outer(ring_part(470, 250, 330, 230, 0, 180)), outer([(80, 250), (300, 250), (190, 90)])]


def share_arrow():
    return [outer([(450, 720), (210, 460), (690, 460)]), outer(rect(390, 200, 510, 470)), outer(rect(170, 40, 730, 140))]


def dots():
    return [outer(circle(x, 330, 75)) for x in (190, 500, 810)]


def note():
    return [outer(circle(250, 130, 145, 100, math.radians(20))), outer(rect(355, 130, 420, 700)),
            outer([(420, 700), (620, 520), (600, 420), (420, 580)])]


def notes():
    return [outer(circle(230, 130, 140, 95, math.radians(20))), outer(circle(690, 80, 140, 95, math.radians(20))),
            outer(rect(330, 130, 395, 650)), outer(rect(790, 80, 855, 600)),
            outer([(330, 650), (855, 600), (855, 490), (330, 540)])]


def warning():
    return [outer([(50, 20), (950, 20), (500, 800)]), hole(rect(452, 250, 548, 580)), hole(circle(500, 140, 58))]


def cross():
    return [outer(bar(150, 60, 650, 590, 115)), outer(bar(150, 590, 650, 60, 115))]


def left_arrow():
    return [outer(rect(260, 285, 920, 395)), outer([(60, 340), (330, 560), (330, 120)])]


def two_squares():
    shapes = []
    for x, y in ((90, 30), (330, 250)):
        shapes.append(outer(rect(x, y, x + 470, y + 470)))
        shapes.append(hole(rect(x + 80, y + 80, x + 390, y + 390)))
    return shapes


# Character, advance width, contours.
GLYPHS = [
    (0x2190, 980, left_arrow()),
    (0x2192, 980, [outer(c) for c in mirror(left_arrow(), 980)]),
    (0x21B6, 900, undo_arrow()),
    (0x21B7, 900, [outer(c) for c in mirror(undo_arrow(), 900)]),
    (0x21EA, 900, share_arrow()),
    (0x22EF, 1000, dots()),
    (0x2302, 900, house()),
    (0x25A0, 800, [outer(rect(120, 40, 680, 600))]),
    (0x25B2, 800, [outer([(90, 40), (710, 40), (400, 620)])]),
    (0x25B6, 800, [outer([(150, 40), (150, 640), (690, 340)])]),
    (0x25B8, 600, [outer([(150, 170), (150, 510), (460, 340)])]),
    (0x25BC, 800, [outer([(90, 640), (710, 640), (400, 60)])]),
    (0x25BE, 600, [outer([(120, 500), (480, 500), (300, 190)])]),
    (0x266A, 700, note()),
    (0x266B, 1000, notes()),
    (0x26A0, 1000, warning()),
    (0x270E, 900, pencil()),
    (0x2715, 800, cross()),
    (0x29C9, 900, two_squares()),
]


def glyph(contours):
    pen = TTGlyphPen(None)
    for contour in contours:
        pen.moveTo((round(contour[0][0]), round(contour[0][1])))
        for x, y in contour[1:]:
            pen.lineTo((round(x), round(y)))
        pen.closePath()
    return pen.glyph()


def main():
    names = [".notdef", "space"] + ["uni%04X" % code for code, _, _ in GLYPHS]
    builder = FontBuilder(UNITS, isTTF=True)
    builder.setupGlyphOrder(names)
    builder.setupCharacterMap({0x20: "space", **{code: "uni%04X" % code for code, _, _ in GLYPHS}})
    glyphs = {".notdef": glyph([outer(rect(100, 0, 600, 700)), hole(rect(160, 60, 540, 640))]), "space": glyph([])}
    metrics = {".notdef": (700, 100), "space": (300, 0)}
    for code, width, contours in GLYPHS:
        name = "uni%04X" % code
        glyphs[name] = glyph(contours)
        left = min((x for contour in contours for x, _ in contour), default=0)
        metrics[name] = (width, round(left))
    builder.setupGlyf(glyphs)
    builder.setupHorizontalMetrics(metrics)
    builder.setupHorizontalHeader(ascent=900, descent=-250)
    builder.setupNameTable({
        "familyName": "StoryTeller Symbols",
        "styleName": "Regular",
        "uniqueFontIdentifier": "StoryTeller Symbols Regular",
        "fullName": "StoryTeller Symbols",
        "psName": "StoryTellerSymbols-Regular",
        "version": "Version 1.0",
        "licenseDescription": "MIT License. Part of StoryTeller; see its LICENSE file.",
    })
    builder.setupOS2(sTypoAscender=900, sTypoDescender=-250, usWinAscent=900, usWinDescent=250)
    builder.setupPost()
    builder.save(OUT)
    print("Wrote %s with %d symbols." % (OUT, len(GLYPHS)))


if __name__ == "__main__":
    main()
