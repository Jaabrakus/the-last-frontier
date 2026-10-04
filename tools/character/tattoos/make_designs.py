#!/usr/bin/env python3
"""Writes the tattoo designs as SVG line art (tools/character/tattoos/designs/<id>.svg).

Our own drawings (2026-10-03): period sailors' marks (an anchor, a compass rose, a heart, a ship, initials and a
year, a mermaid), the sky crews' marks (a keelstone star, a wind spiral, the Drift's waves) and plain bands and dots.
No traditional or sacred designs of any people (no Polynesian or Maori designs, no Indigenous North American designs:
those wait on consultation, docs/research/peoples_dress_1750s.md 1.3). The crucifix is drawn but held (a sacred image:
tattoos.json "held_designs", out of the atlas until the owner decides); the crossed keys (Saint Peter's, the papal
emblem, with no period basis as a seaman's mark) were dropped on 2026-10-03.

Each design is white line art on transparency in a 512 x 512 box, inside a 34 px margin (the atlas's mip levels
must not bleed into the next cell). The geometry is computed here (trigonometry for the roses and spirals,
hand-placed Bezier curves for the figures); the SVG files are the build's source:

    python3 tools/character/tattoos/make_designs.py
    Godot --headless --path . -s tools/character/tattoos/build_tattoos.gd      # SVG -> atlas PNG, body map

The ids and the atlas cells are data/customizer/tattoos.json "designs".
"""

import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "designs")
W = 512
C = 256.0
INK = "#ffffff"
CUT = "#000000"


def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n%s\n</svg>\n'
            % (W, W, W, W, body))


def f(x):
    return ("%.1f" % x).rstrip("0").rstrip(".")


def pts(p):
    return " ".join("%s,%s" % (f(x), f(y)) for x, y in p)


def stroke(d, w=16, color=INK, extra=""):
    return ('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"%s/>'
            % (d, color, f(w), extra))


def fill(d, color=INK):
    return '<path d="%s" fill="%s"/>' % (d, color)


def poly(p, close=True):
    return "M " + " L ".join("%s %s" % (f(x), f(y)) for x, y in p) + (" Z" if close else "")


def circle(cx, cy, r, w=None, color=INK):
    if w is None:
        return '<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % (f(cx), f(cy), f(r), color)
    return '<circle cx="%s" cy="%s" r="%s" fill="none" stroke="%s" stroke-width="%s"/>' % (f(cx), f(cy), f(r), color, f(w))


def rot(p, a, c=(C, C)):
    ca, sa = math.cos(a), math.sin(a)
    return (c[0] + (p[0] - c[0]) * ca - (p[1] - c[1]) * sa, c[1] + (p[0] - c[0]) * sa + (p[1] - c[1]) * ca)


def unit(a):
    return (math.cos(a), math.sin(a))


# ---------------------------------------------------------------------------------------------
# Period sailors' marks
# ---------------------------------------------------------------------------------------------

def anchor():
    """An Admiralty anchor, fouled with a cable: ring, stock with ball ends, shank, curved arms, barbed flukes."""
    out = []
    out.append(circle(C, 68, 25, 15))
    out.append(stroke("M 150 122 L 362 122", 22))
    out.append(circle(146, 122, 16))
    out.append(circle(366, 122, 16))
    out.append(stroke("M 256 93 L 256 420", 22))
    # the arms: a quadratic from fluke to fluke through the crown
    a, q, b = (112.0, 318.0), (256.0, 476.0), (400.0, 318.0)
    out.append(stroke("M %s %s Q %s %s %s %s" % (f(a[0]), f(a[1]), f(q[0]), f(q[1]), f(b[0]), f(b[1])), 22))
    out.append(circle(C, 424, 18))
    for end, ctrl in ((a, q), (b, q)):
        d = (end[0] - ctrl[0], end[1] - ctrl[1])
        n = math.hypot(*d)
        d = (d[0] / n, d[1] / n)
        p = (-d[1], d[0])
        tip = (end[0] + d[0] * 50, end[1] + d[1] * 50)
        s1 = (end[0] + p[0] * 30 - d[0] * 8, end[1] + p[1] * 30 - d[1] * 8)
        s2 = (end[0] - p[0] * 30 - d[0] * 8, end[1] - p[1] * 30 - d[1] * 8)
        notch = (end[0] - d[0] * 2, end[1] - d[1] * 2)
        out.append(fill(poly([tip, s1, notch, s2])))
    # the cable: from the ring round the stock and down about the shank
    out.append(stroke("M 238 80 C 190 96 178 140 220 156 C 286 180 300 220 250 246 C 196 274 212 316 262 330 "
                      "C 304 342 312 372 280 392", 9))
    return svg("\n".join(out))


def compass_rose():
    """Eight points, each split into a filled and an open half, two rings with the quarter ticks, a small north mark."""
    out = []
    out.append(circle(C, C, 214, 11))
    out.append(circle(C, C, 182, 6))
    for k in range(32):
        a = k * math.pi / 16
        r0 = 186 if k % 4 else 176
        u = unit(a)
        out.append(stroke("M %s %s L %s %s" % (f(C + u[0] * r0), f(C + u[1] * r0), f(C + u[0] * 210), f(C + u[1] * 210)),
                          5 if k % 4 else 8))
    for major in (False, True):
        for k in range(4):
            a = -math.pi / 2 + k * math.pi / 2 + (0 if major else math.pi / 4)
            L, w = (232, 36) if major else (156, 27)
            u = unit(a)
            p = (-u[1], u[0])
            tip = (C + u[0] * L, C + u[1] * L)
            s1 = (C + p[0] * w, C + p[1] * w)
            s2 = (C - p[0] * w, C - p[1] * w)
            out.append(fill(poly([(C, C), tip, s1])))
            out.append(stroke(poly([(C, C), tip, s2]), 7))
    out.append(circle(C, C, 22))
    out.append(circle(C, C, 11, color=CUT))
    # north: a small lozenge over the north point
    out.append(fill(poly([(C, 10), (C + 13, 30), (C, 50), (C - 13, 30)])))
    return svg("\n".join(out))


HEART = ("M 256 438 C 136 352 66 276 82 186 C 96 112 196 92 256 170 C 316 92 416 112 430 186 "
         "C 446 276 376 352 256 438 Z")


def heart():
    """A heart in a double line, shaded on its right, pierced by an arrow."""
    out = []
    # the arrow, behind the heart: its tail and fletching low left, its head high right
    out.append(stroke("M 52 420 L 132 350", 11))
    out.append(stroke("M 392 156 L 456 100", 11))
    out.append(fill(poly([(474, 84), (436, 98), (458, 120)])))
    for k in range(3):
        o = k * 16
        out.append(stroke("M %d %d L %d %d" % (64 + o, 410 - o, 50 + o, 380 - o), 7))
        out.append(stroke("M %d %d L %d %d" % (64 + o, 410 - o, 94 + o, 424 - o), 7))
    out.append(fill(HEART, CUT))
    out.append(stroke(HEART, 17))
    out.append('<g transform="translate(256 262) scale(0.76) translate(-256 -262)">%s</g>' % stroke(HEART, 10))
    # shading on the right lobe: short strokes inside the inner line
    for k in range(5):
        y = 196 + k * 30
        x0 = 330 - k * 6
        out.append(stroke("M %d %d L %d %d" % (x0, y, x0 + 46 - k * 9, y + 12), 8))
    return svg("\n".join(out))


def ship():
    """A three-masted ship under square sail on the swell, seen from the side."""
    out = []
    hull = "M 78 318 L 430 318 Q 418 362 388 380 Q 256 398 128 382 Q 96 360 78 318 Z"
    out.append(stroke(hull, 13))
    out.append(stroke("M 104 344 Q 256 356 410 342", 7))
    for x in range(140, 400, 34):
        out.append(fill(poly([(x, 326), (x + 12, 326), (x + 12, 336), (x, 336)])))
    # the poop and the bowsprit
    out.append(stroke("M 78 318 L 76 288 L 132 288 L 132 318", 10))
    out.append(stroke("M 424 318 L 492 262", 10))
    masts = [(150, 120, 0.82), (262, 64, 1.0), (366, 106, 0.86)]
    for x, top, k in masts:
        out.append(stroke("M %d 318 L %d %d" % (x, x, top), 10))
        y = top + 16
        for j, (h, w) in enumerate(((54, 74), (66, 92), (78, 104))):
            if y + h > 300:
                break
            w *= k
            h *= k
            sail = "M %s %s L %s %s Q %s %s %s %s L %s %s Q %s %s %s %s Z" % (
                f(x - w / 2), f(y), f(x + w / 2), f(y), f(x + w / 2 + 10), f(y + h / 2), f(x + w / 2 + 2), f(y + h),
                f(x - w / 2 - 2), f(y + h), f(x - w / 2 + 6), f(y + h / 2), f(x - w / 2), f(y))
            out.append(stroke(sail, 8))
            out.append(stroke("M %s %s L %s %s" % (f(x - w / 2 - 6), f(y), f(x + w / 2 + 6), f(y)), 8))
            y += h + 10
    # the jib from the bowsprit to the foremast
    out.append(stroke("M 488 266 L 372 120 L 380 300 Z", 7))
    # the flag at the main truck
    out.append(fill("M 262 64 L 300 54 L 292 68 L 302 80 L 262 84 Z"))
    # the swell
    out.append(stroke("M 34 410 C 80 390 112 432 160 410 C 208 388 240 432 288 410 C 336 388 368 432 416 410 "
                      "C 446 396 466 404 480 412", 9))
    out.append(stroke("M 96 446 C 136 430 162 460 200 446 C 238 432 268 460 306 446 C 344 432 372 458 412 446", 7))
    return svg("\n".join(out))


def _glyphs(text, x0, y0, h, w, gap, sw):
    """Roman capitals and figures in strokes (a lettering hand of the period: plain strokes with short serifs)."""
    out = []
    x = x0
    for ch in text:
        if ch == " ":
            x += w * 0.5
            continue
        L, R, T, B, M = x, x + w, y0, y0 + h, x + w / 2
        ser = w * 0.22
        if ch == "W":
            out.append(stroke(poly([(L, T), (L + w * 0.24, B), (M, T + h * 0.3), (R - w * 0.24, B), (R, T)], False), sw))
            for xx in (L, R):
                out.append(stroke("M %s %s L %s %s" % (f(xx - ser), f(T), f(xx + ser), f(T)), sw * 0.6))
        elif ch == "H":
            out.append(stroke("M %s %s L %s %s M %s %s L %s %s M %s %s L %s %s" % (
                f(L + w * 0.1), f(T), f(L + w * 0.1), f(B), f(R - w * 0.1), f(T), f(R - w * 0.1), f(B),
                f(L + w * 0.1), f(T + h * 0.5), f(R - w * 0.1), f(T + h * 0.5)), sw))
            for xx in (L + w * 0.1, R - w * 0.1):
                for yy in (T, B):
                    out.append(stroke("M %s %s L %s %s" % (f(xx - ser), f(yy), f(xx + ser), f(yy)), sw * 0.6))
        elif ch == "1":
            out.append(stroke("M %s %s L %s %s L %s %s" % (f(M - w * 0.28), f(T + h * 0.2), f(M), f(T), f(M), f(B)), sw))
            out.append(stroke("M %s %s L %s %s" % (f(M - ser * 1.2), f(B), f(M + ser * 1.2), f(B)), sw * 0.7))
        elif ch == "7":
            out.append(stroke("M %s %s L %s %s L %s %s" % (f(L + w * 0.05), f(T), f(R), f(T), f(M - w * 0.1), f(B)), sw))
            out.append(stroke("M %s %s L %s %s" % (f(L + w * 0.05), f(T), f(L + w * 0.05), f(T + h * 0.14)), sw * 0.7))
        elif ch == "5":
            out.append(stroke("M %s %s L %s %s L %s %s C %s %s %s %s %s %s C %s %s %s %s %s %s" % (
                f(R - w * 0.05), f(T), f(L + w * 0.15), f(T), f(L + w * 0.1), f(T + h * 0.45),
                f(L + w * 0.4), f(T + h * 0.34), f(R + w * 0.05), f(T + h * 0.42), f(R), f(T + h * 0.7),
                f(R - w * 0.05), f(B + h * 0.05), f(L + w * 0.2), f(B + h * 0.05), f(L), f(B - h * 0.12)), sw))
        x += w + gap
    return out


def initials_date():
    """Initials over a year, as pricked on a forearm: "W H" with a stop, a rule with a lozenge, "1757"."""
    out = []
    out += _glyphs("W", 84, 92, 150, 136, 0, 20)
    out.append(fill(poly([(256, 152), (268, 166), (256, 180), (244, 166)])))
    out += _glyphs("H", 296, 92, 150, 118, 0, 20)
    out.append(stroke("M 80 280 L 222 280 M 290 280 L 432 280", 8))
    out.append(fill(poly([(256, 262), (276, 280), (256, 298), (236, 280)])))
    out += _glyphs("1757", 104, 322, 104, 62, 22, 15)
    return svg("\n".join(out))


def crucifix():
    """A Latin cross on its three Calvary steps with the title board, light rising behind it."""
    out = []
    for k in range(12):
        a = -math.pi + (k + 0.5) * math.pi / 12
        if abs(a + math.pi / 2) < 0.18:
            continue
        u = unit(a)
        out.append(stroke("M %s %s L %s %s" % (f(C + u[0] * 112), f(176 + u[1] * 112), f(C + u[0] * 168), f(176 + u[1] * 168)), 7))
    cross = [(236, 66), (276, 66), (276, 150), (360, 150), (360, 190), (276, 190), (276, 382), (236, 382), (236, 190),
             (152, 190), (152, 150), (236, 150)]
    out.append(fill(poly(cross), CUT))
    out.append(stroke(poly(cross), 13))
    out.append(stroke("M 256 82 L 256 366 M 168 170 L 344 170", 6))
    # the title board on the upright
    out.append(fill(poly([(222, 40), (290, 40), (290, 72), (222, 72)]), CUT))
    out.append(stroke(poly([(222, 40), (290, 40), (290, 72), (222, 72)]), 9))
    for i, (w, y) in enumerate(((112, 382), (156, 410), (204, 438))):
        out.append(stroke(poly([(C - w / 2, y), (C + w / 2, y), (C + w / 2, y + 26), (C - w / 2, y + 26)]), 10))
    return svg("\n".join(out))


def mermaid():
    """A mermaid in profile, seated on her curled tail: her hair down her back, a looking-glass raised in her hand, the
    tail scaled and ending in a two-lobed fin."""
    out = []
    # the tail: the convex edge from her hip, down and round to the fin; the concave edge inside it
    out.append(stroke("M 300 258 C 316 330 286 404 214 432 C 168 448 128 440 104 412", 15))
    out.append(stroke("M 250 262 C 252 322 232 366 186 386 C 154 398 128 392 110 378", 15))
    # the fin, two lobes spread behind
    out.append(stroke("M 110 378 C 92 352 66 332 34 318 C 46 352 62 376 80 392 C 62 408 50 430 44 460 "
                      "C 74 442 94 426 104 412", 13))
    out.append(stroke("M 52 336 C 66 356 76 372 86 390 M 56 446 C 70 428 82 414 92 404", 6))
    # scales: rows of little arcs between the edges
    for (x, y, a) in ((262, 290, 1.62), (288, 292, 1.62), (266, 322, 1.75), (290, 326, 1.8), (258, 354, 2.0),
                      (282, 362, 2.1), (240, 384, 2.4), (262, 396, 2.5), (210, 404, 2.75), (232, 416, 2.85),
                      (178, 412, 3.0), (196, 426, 3.05), (148, 410, 3.2), (160, 426, 3.2)):
        u = unit(a)
        pp = (-u[1], u[0])
        r = 11
        out.append(stroke("M %s %s Q %s %s %s %s" % (f(x - pp[0] * r), f(y - pp[1] * r), f(x + u[0] * r * 1.1),
                                                    f(y + u[1] * r * 1.1), f(x + pp[0] * r), f(y + pp[1] * r)), 6))
    # where the skin meets the tail: a scalloped girdle
    out.append(stroke("M 248 262 Q 262 276 274 264 Q 288 276 302 260", 9))
    # the body: her back, and her front from the throat over the breast to the waist
    out.append(stroke("M 274 132 C 262 170 252 214 250 262", 14))
    out.append(stroke("M 306 136 C 312 150 330 168 330 188 C 330 204 314 210 306 222 C 300 234 300 248 302 260", 14))
    # the head in profile (facing right), the neck
    out.append(circle(296, 98, 34, 14))
    out.append(stroke("M 330 96 L 340 104 L 330 108", 7))
    out.append(stroke("M 286 130 L 288 140 M 306 128 L 306 138", 10))
    # her hair, a solid mass from the crown down her back to the waist
    out.append(fill("M 300 60 C 266 58 244 80 238 112 C 230 152 214 196 200 236 C 196 250 204 262 218 258 "
                    "C 232 220 246 176 262 142 C 270 126 268 108 280 96 C 290 86 306 80 322 84 C 318 70 310 62 300 60 Z"))
    # the raised arm and the looking-glass
    out.append(stroke("M 310 152 C 338 164 356 168 364 150 C 370 138 372 128 374 118", 13))
    out.append(circle(384, 88, 28, 12))
    out.append(circle(384, 88, 14))
    out.append(stroke("M 376 114 L 372 126", 10))
    return svg("\n".join(out))


# ---------------------------------------------------------------------------------------------
# The sky crews' marks (our own: the Drift, docs/main_story.md)
# ---------------------------------------------------------------------------------------------

def keelstone_star():
    """The keelstone: a cut stone in a four-pointed star (the stone that floats a ship), four sparks, the keel's
    curve under it."""
    out = []
    star = [(C, 34), (282, 226), (448, C), (282, 286), (C, 430), (230, 286), (64, C), (230, 226)]
    out.append(stroke(poly(star), 13))
    stone = [(C, 182), (304, 226), (304, 286), (C, 330), (208, 286), (208, 226)]
    out.append(fill(poly(stone)))
    for a, b in (((C, 182), (C, 226)), ((208, 226), (C, 246)), ((304, 226), (C, 246)), ((C, 246), (C, 330)),
                 ((208, 286), (C, 300)), ((304, 286), (C, 300))):
        out.append(stroke("M %s %s L %s %s" % (f(a[0]), f(a[1]), f(b[0]), f(b[1])), 6, CUT))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        u = unit(a)
        cx, cy = C + u[0] * 140, C + u[1] * 140
        out.append(fill(poly([(cx, cy - 18), (cx + 6, cy), (cx, cy + 18), (cx - 6, cy)])))
        out.append(fill(poly([(cx - 18, cy), (cx, cy - 6), (cx + 18, cy), (cx, cy + 6)])))
    out.append(stroke("M 120 462 Q 256 500 392 462", 11))
    return svg("\n".join(out))


def wind_spiral():
    """A wind's spiral, two and a half turns, trailing three strokes of wind."""
    out = []
    cx, cy = 210.0, 244.0
    p = []
    turns = 2.5
    n = 160
    for i in range(n + 1):
        t = i / n
        a = t * turns * 2 * math.pi + math.pi
        r = 14 + 128 * t
        p.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    out.append(stroke(poly(p, False), 15))
    end = p[-1]
    out.append(stroke("M %s %s C %s %s %s %s %s %s" % (f(end[0]), f(end[1]), f(end[0] + 90), f(end[1] - 4),
                                                       f(410), f(end[1] + 20), f(470), f(end[1] - 6)), 13))
    out.append(stroke("M 300 200 C 352 184 400 206 456 186", 10))
    out.append(stroke("M 296 300 C 348 312 392 296 446 310", 10))
    return svg("\n".join(out))


def _wave(x, y, s):
    """One curling crest at (x, y), size s."""
    return ("M %s %s C %s %s %s %s %s %s C %s %s %s %s %s %s C %s %s %s %s %s %s C %s %s %s %s %s %s"
            % (f(x - 1.1 * s), f(y + 0.5 * s),
               f(x - 0.7 * s), f(y - 0.35 * s), f(x + 0.15 * s), f(y - 0.75 * s), f(x + 0.62 * s), f(y - 0.25 * s),
               f(x + 0.9 * s), f(y + 0.05 * s), f(x + 0.62 * s), f(y + 0.42 * s), f(x + 0.32 * s), f(y + 0.2 * s),
               f(x + 0.16 * s), f(y + 0.08 * s), f(x + 0.28 * s), f(y - 0.08 * s), f(x + 0.42 * s), f(y + 0.04 * s),
               f(x + 0.6 * s), f(y + 0.4 * s), f(x + 0.95 * s), f(y + 0.55 * s), f(x + 1.25 * s), f(y + 0.5 * s)))


def drift_waves():
    """The Drift's waves: two rows of curling crests of the upper sea under three of its stars."""
    out = []
    for i in range(3):
        out.append(stroke(_wave(118 + i * 138, 286, 64), 12))
    for i in range(3):
        out.append(stroke(_wave(80 + i * 138 + 69, 398, 52), 10))
    for (x, y, s) in ((150, 108, 30), (282, 72, 38), (390, 132, 26)):
        out.append(fill(poly([(x, y - s), (x + s * 0.24, y), (x, y + s), (x - s * 0.24, y)])))
        out.append(fill(poly([(x - s, y), (x, y - s * 0.24), (x + s, y), (x, y + s * 0.24)])))
    return svg("\n".join(out))


# ---------------------------------------------------------------------------------------------
# Plain marks (repeated round a limb: data/customizer/tattoos.json "repeat")
# ---------------------------------------------------------------------------------------------

def band():
    """A plain band (repeats round the limb)."""
    return svg('<rect x="0" y="198" width="512" height="116" fill="%s"/>' % INK)


def band_double():
    """Two narrow bands (repeat round the limb)."""
    return svg('<rect x="0" y="172" width="512" height="44" fill="%s"/>\n<rect x="0" y="296" width="512" height="44" fill="%s"/>'
               % (INK, INK))


def dots():
    """A dot (repeats round the limb: a ring of dots)."""
    return svg(circle(C, C, 62))


DESIGNS = {
    "anchor": anchor, "compass_rose": compass_rose, "heart": heart, "ship": ship,
    "initials_date": initials_date, "crucifix": crucifix, "mermaid": mermaid, "keelstone_star": keelstone_star,
    "wind_spiral": wind_spiral, "drift_waves": drift_waves, "band": band, "band_double": band_double, "dots": dots,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in DESIGNS.items():
        with open(os.path.join(OUT, name + ".svg"), "w") as fh:
            fh.write(fn())
    print("wrote %d designs to %s" % (len(DESIGNS), OUT))


if __name__ == "__main__":
    main()
