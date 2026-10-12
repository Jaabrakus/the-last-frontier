#!/usr/bin/env python3
"""Tidebreak's ring move icons (round 4, HUD): one picture per chip the strip can show, drawn by hand here as SVG path
data in the family of assets/ui/icons/spell_*.svg (the open world's Form spells: white line art on a 64 grid, round caps,
tinted at draw time). Our own drawings: no symbol of the show, no nation marks, nothing traced.

    python3 tools/ui/move_icons.py [out_dir]          (default assets/ui/icons; then Godot --import)

Writes spell_<id>__<mode>.svg for every (id, mode) a chip names (BendStrip.icon_texture asks for the mode's file first,
then the id's; a move with no mode names its file by its id twice, spell_mend__mend.svg), the air chips' pictures
(spell_slam__<element>.svg for the Slams, spell_dodge__<element>.svg for "Dodge"), the caught stone's return
(spell_stone_catch__return.svg), fire's grown Fireball (spell_fire_blast__fireball.svg) and the plates' element marks
(spell_mark__<element>.svg). The five open-world icons (spell_earth_wall, spell_gust, spell_mend, spell_pillar,
spell_stone_form) are left as they are.

One motif per element so a glance tells them apart: earth angular slabs and shards (straight edges, filled solids),
water curls and crests (round curves, droplets), fire tongues (pointed teardrops), air spirals and arcs (open strokes, no
fills). Each picture says what the move does: a shard rising for Spike, a round rock with a trail for Boulder, a crest
for Wave, a row of tongues for Fire Wall, and so on. Strokes 3.4 (the main line), 2.8 (the second) and 1.6 (detail).
"""
import math
import os
import sys

S1, S2, S3 = 3.4, 2.8, 1.6
FILL = 'fill="#fff" fill-opacity="0.92"'
HEAD = ('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64" fill="none" '
        'stroke="#ffffff" stroke-linecap="round" stroke-linejoin="round">')


def f(v):
    s = ("%.2f" % v).rstrip("0").rstrip(".")
    return s if s not in ("-0", "") else "0"


def P(d, w=S1, extra=""):
    return '  <path d="%s" stroke-width="%s"%s/>' % (d, f(w), (" " + extra) if extra else "")


def poly(pts, w=S2, fill=True, extra=""):
    d = "M" + " L".join("%s %s" % (f(x), f(y)) for x, y in pts) + " Z"
    return P(d, w, (FILL + " " + extra).strip() if fill else extra)


def line(pts, w=S1, extra=""):
    return P("M" + " L".join("%s %s" % (f(x), f(y)) for x, y in pts), w, extra)


def circle(cx, cy, r, w=S2, fill=False, extra=""):
    attrs = ((" " + FILL) if fill else "") + ((" " + extra) if extra else "")
    return '  <circle cx="%s" cy="%s" r="%s" stroke-width="%s"%s/>' % (f(cx), f(cy), f(r), f(w), attrs)


def dot(cx, cy, r):
    return '  <circle cx="%s" cy="%s" r="%s" stroke-width="1" %s/>' % (f(cx), f(cy), f(r), FILL)


def facet(d, w=1.2):
    """A dark facet line on a filled solid (the family's own: spell_stone_form's ball)."""
    return P(d, w, 'stroke="#000" stroke-opacity="0.35"')


def head(tip, frm, size=5.5, w=S1):
    """An arrowhead at `tip`, pointing away from `frm`."""
    ang = math.atan2(tip[1] - frm[1], tip[0] - frm[0])
    a1, a2 = ang + math.radians(150), ang - math.radians(150)
    return line([(tip[0] + math.cos(a1) * size, tip[1] + math.sin(a1) * size), tip,
                 (tip[0] + math.cos(a2) * size, tip[1] + math.sin(a2) * size)], w)


def ground(y=54, x0=6, x1=58, w=S2):
    return line([(x0, y), (x1, y)], w)


def tongue(cx, by, w, h, lean=None, fill=True, sw=S3, rot=0.0):
    """A flame tongue: a flame standing on (cx, by), w wide, h tall, a round foot, its left edge drawn in under a tip that
    leans `lean`; rot turns it round its base (degrees: 90 points it right)."""
    lean = w * 0.3 if lean is None else lean
    pts = [(-w / 2, 0), (-w * 0.66, -h * 0.38), (-w * 0.02 + lean * 0.4, -h * 0.5), (lean, -h),
           (w * 0.28 + lean * 0.2, -h * 0.66), (w * 0.66, -h * 0.42), (w / 2, 0),
           (w * 0.42, h * 0.2), (-w * 0.42, h * 0.2), (-w / 2, 0)]
    r = math.radians(rot)
    def tr(p):
        x, y = p
        return (cx + x * math.cos(r) - y * math.sin(r), by + x * math.sin(r) + y * math.cos(r))
    q = [tr(p) for p in pts]
    d = "M%s %s" % (f(q[0][0]), f(q[0][1]))
    for i in (1, 4, 7):
        d += " C %s %s, %s %s, %s %s" % (f(q[i][0]), f(q[i][1]), f(q[i + 1][0]), f(q[i + 1][1]), f(q[i + 2][0]), f(q[i + 2][1]))
    out = P(d + " Z", sw, FILL if fill else "")
    if fill and h >= 14:
        # (the inner flick: a flame, not a drop)
        k = [tr(p) for p in [(-w * 0.08, -h * 0.08), (-w * 0.3, -h * 0.3), (lean * 0.3 + w * 0.1, -h * 0.4), (lean * 0.45 - w * 0.05, -h * 0.62)]]
        out += "\n" + facet("M%s %s C %s %s, %s %s, %s %s" % tuple(f(v) for pt in k for v in pt), 1.1)
    return out


def ghosts(shape_fn, offsets):
    """A dodge's afterimages: the shape outlined at each offset, fading."""
    out = []
    for (dx, op) in offsets:
        out.append('  <g transform="translate(%s 0)" stroke-opacity="%s">' % (f(dx), f(op)))
        out.extend(shape_fn(False))
        out.append("  </g>")
    return out


def spiral(cx, cy, r0, r1, turns, a0=0.0, n=40, w=S2):
    pts = []
    for i in range(n + 1):
        t = i / n
        a = a0 + t * turns * math.tau
        r = r0 + (r1 - r0) * t
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    d = "M%s %s" % (f(pts[0][0]), f(pts[0][1])) + "".join(" L%s %s" % (f(x), f(y)) for x, y in pts[1:])
    return P(d, w)


def arc(cx, cy, r, a0, a1, w=S2, n=24):
    pts = [(cx + math.cos(math.radians(a0 + (a1 - a0) * i / n)) * r, cy + math.sin(math.radians(a0 + (a1 - a0) * i / n)) * r)
           for i in range(n + 1)]
    return P("M%s %s" % (f(pts[0][0]), f(pts[0][1])) + "".join(" L%s %s" % (f(x), f(y)) for x, y in pts[1:]), w), pts


# ======================================================================================== EARTH: slabs and shards
def pebble(cx, cy, r, rot=0.0):
    k = [(1.0, 0), (0.62, 0.9), (-0.45, 0.95), (-1.0, 0.1), (-0.5, -0.88), (0.55, -0.8)]
    a = math.radians(rot)
    pts = [(cx + (x * math.cos(a) - y * math.sin(a)) * r, cy + (x * math.sin(a) + y * math.cos(a)) * r) for x, y in k]
    return poly(pts, S3)


def earth_pebbles():
    return [pebble(20, 44, 5.0, 10), pebble(34, 32, 5.6, -20), pebble(50, 19, 6.4, 25),
            line([(4, 47), (11, 46)], S2), line([(17, 35), (25, 34)], S2), line([(32, 21), (40, 20)], S2),
            line([(7, 41), (12, 40.5)], S3), line([(21, 28.5), (26, 28)], S3)]


def earth_catch():
    return [line([(12, 26), (18, 48), (46, 48), (52, 26)], S1),            # the cradle, two slabs meeting
            line([(18, 48), (24, 40)], S3), line([(46, 48), (40, 40)], S3),
            poly([(24, 34), (29, 25), (38, 24), (43, 31), (39, 40), (28, 41)], S2),
            facet("M29 27 L 33 33 L 40 31"),
            line([(46, 6), (40, 16)], S2), line([(54, 10), (46, 18)], S3), line([(38, 4), (35, 12)], S3)]


def earth_return():
    return [poly([(38, 46), (42, 38), (50, 37), (55, 43), (52, 51), (42, 52)], S2),
            facet("M43 40 L 46 45 L 52 44"),
            P("M38 45 C 20 47, 9 34, 14 23 C 18 14, 32 12, 52 14", S1),
            head((52, 14), (42, 13), 6.5)]


def earth_spike():
    return [ground(54),
            poly([(23, 54), (28, 30), (26, 26), (33, 5), (38, 24), (36, 27), (42, 54)], S2),
            facet("M33 9 L 31 30 L 34 54"),
            poly([(10, 54), (14, 44), (19, 54)], S3), poly([(46, 54), (51, 45), (55, 54)], S3),
            line([(12, 36), (12, 27)], S3), line([(52, 36), (52, 27)], S3)]


def earth_boulder():
    pts = [(40 + math.cos(math.radians(a)) * r, 31 + math.sin(math.radians(a)) * r)
           for a, r in [(0, 14), (45, 13), (95, 14), (140, 13.5), (185, 14), (235, 13), (280, 14), (325, 13.5)]]
    return [poly(pts, S2),
            facet("M32 24 L 40 31 L 50 26 M40 31 L 38 43 M40 31 L 29 35"),
            line([(5, 25), (21, 25)], S2), line([(3, 32), (23, 32)], S1), line([(6, 39), (21, 39)], S2),
            line([(10, 46), (24, 44)], S3)]


def earth_shove():
    return [ground(54),
            poly([(14, 54), (16, 16), (34, 12), (36, 54)], S2),
            facet("M18 28 L 34 25 M17 41 L 35 39"),
            line([(42, 24), (50, 33), (42, 42)], S1), line([(50, 24), (58, 33), (50, 42)], S2),
            line([(4, 46), (10, 46)], S3), line([(4, 38), (9, 38)], S3)]


def earth_column():
    return [ground(54),
            poly([(25, 54), (25, 24), (32, 18), (39, 24), (39, 54)], S2),
            facet("M25 34 L 39 33 M25 44 L 39 45"),
            line([(32, 13), (32, 4)], S2), line([(26, 14), (20, 8)], S2), line([(38, 14), (44, 8)], S2),
            poly([(12, 54), (16, 47), (20, 54)], S3), poly([(44, 54), (48, 47), (52, 54)], S3)]


def earth_burrow():
    return [line([(4, 42), (34, 42)], S2),
            poly([(34, 42), (40, 33), (48, 30), (55, 36), (60, 42)], S2),
            line([(6, 50), (11, 50)], S2), line([(16, 50), (21, 50)], S2), line([(26, 50), (31, 50)], S2),
            poly([(38, 26), (40, 20), (43, 26)], S3), poly([(48, 24), (51, 17), (54, 23)], S3),
            head((61, 51), (50, 51), 4.5, S2), line([(38, 51), (60, 51)], S2)]


def earth_lift():
    return [ground(54),
            poly([(19, 54), (19, 36), (45, 36), (45, 54)], S2),
            facet("M19 45 L 45 45"),
            circle(32, 13, 4, S2),
            line([(32, 17), (32, 27)], S2), line([(32, 27), (27, 35)], S2), line([(32, 27), (37, 35)], S2),
            line([(32, 20), (25, 24)], S3), line([(32, 20), (39, 24)], S3),
            line([(9, 46), (9, 30)], S2), head((9, 28), (9, 40), 4.5, S2),
            line([(55, 46), (55, 30)], S2), head((55, 28), (55, 40), 4.5, S2)]


def earth_wall():
    return [ground(56, 6, 58),
            P("M11 56 L 11 22 L 18 17 L 29 21 L 40 15 L 53 22 L 53 56", S1),
            line([(11, 33), (53, 33)], S2), line([(11, 44), (53, 44)], S2),
            line([(25, 22), (25, 33)], S3), line([(39, 20), (39, 33)], S3),
            line([(18, 33), (18, 44)], S3), line([(32, 33), (32, 44)], S3), line([(46, 33), (46, 44)], S3),
            line([(25, 44), (25, 56)], S3), line([(39, 44), (39, 56)], S3)]


def earth_hammer():
    return [poly([(18, 6), (46, 6), (48, 24), (16, 24)], S2),
            facet("M20 15 L 44 15"),
            line([(32, 28), (32, 41)], S1), head((32, 43), (32, 30), 6),
            ground(52, 4, 60),
            line([(24, 52), (20, 59)], S3), line([(40, 52), (45, 59)], S3),
            line([(14, 47), (9, 41)], S2), line([(50, 47), (55, 41)], S2), line([(8, 9), (8, 22)], S3),
            line([(56, 9), (56, 22)], S3)]


def _earth_dodge_shape(filled):
    pts = [(44, 54), (40, 32), (46, 14), (52, 30), (50, 54)]
    return [poly(pts, S2, filled)]


def earth_dodge():
    return ghosts(_earth_dodge_shape, [(-30, 0.35), (-16, 0.6)]) + _earth_dodge_shape(True) + [ground(58, 8, 58, S3)]


def earth_mark():
    return [poly([(8, 56), (12, 44), (30, 40), (52, 43), (56, 56)], S2),
            poly([(16, 38), (20, 28), (38, 24), (46, 33), (42, 39)], S2),
            poly([(24, 22), (27, 12), (36, 7), (40, 18), (35, 22)], S2),
            facet("M12 49 L 52 49 M21 33 L 42 30 M30 15 L 37 13")]


# ======================================================================================== WATER: curls and crests
def water_splash():
    return [P("M5 44 C 14 40, 20 46, 28 40 C 33 36, 36 34, 40 32", S1),
            P("M8 50 C 14 48, 18 52, 24 49", S3),
            dot(46, 27, 2.6), dot(52, 33, 2.1), dot(49, 19, 2.0), dot(57, 24, 1.7), dot(56, 13, 1.4), dot(43, 21, 1.5),
            line([(42, 30), (46, 28)], S3)]


def water_turn():
    return [P("M58 16 L 30 16 C 12 16, 10 46, 30 46 L 50 46", S1),
            head((52, 46), (42, 46), 6),
            P("M22 24 C 18 28, 20 33, 25 32", S2),
            dot(40, 10, 1.6), dot(46, 9, 1.3), dot(36, 53, 1.5)]


def water_lash():
    return [P("M6 54 C 18 52, 20 34, 32 32", S1),
            P("M32 32 C 44 30, 44 16, 56 9", S2),
            line([(56, 9), (61, 6)], S3), line([(57, 5), (59, 1)], S3), line([(60, 11), (63, 12)], S3),
            dot(24, 43, 1.6), dot(40, 26, 1.5), dot(48, 16, 1.3)]


def water_spear():
    return [poly([(6, 56), (11, 47), (50, 12), (58, 6), (54, 14), (17, 51)], S2),
            facet("M10 52 L 54 10"),
            line([(12, 36), (12, 30)], S3), line([(9, 33), (15, 33)], S3),
            line([(32, 54), (32, 48)], S3), line([(29, 51), (35, 51)], S3)]


def water_tomahawk():
    return [line([(12, 52), (38, 13)], S1),
            P("M33 20 L 39 11 L 53 18 C 58 24, 56 31, 49 34 Z", S2, FILL),
            facet("M38 17 L 51 26"),
            line([(37, 14), (31, 8)], S2),
            P("M30 58 C 36 51, 54 51, 60 58", S2),
            dot(37, 47, 1.7), dot(45, 43, 1.5), dot(54, 46, 1.6)]


def water_wave():
    return [P("M4 50 C 14 50, 18 30, 34 24 C 46 20, 56 26, 54 36 C 52 42, 44 42, 43 35", S1),
            P("M8 57 L 58 57", S2), P("M14 50 C 22 48, 28 40, 36 36", S3),
            dot(48, 15, 1.8), dot(55, 18, 1.5), dot(41, 14, 1.4)]


def water_geyser():
    return [P("M26 52 C 27 40, 26 30, 28 20", S1), P("M38 52 C 37 40, 38 30, 36 20", S1),
            P("M28 20 C 22 12, 13 14, 14 22", S2), P("M36 20 C 42 12, 51 14, 50 22", S2),
            P("M32 18 L 32 8", S2),
            dot(22, 7, 1.7), dot(42, 6, 1.7), dot(32, 3, 1.5),
            P("M10 56 C 18 50, 46 50, 54 56", S2)]


def water_skate():
    return [P("M4 44 C 12 36, 20 52, 30 44 C 38 38, 46 48, 54 42", S1),
            head((58, 40), (50, 44), 5.5),
            P("M10 54 C 18 50, 26 56, 34 52", S3),
            P("M4 36 C 6 32, 10 32, 11 35", S2), dot(16, 30, 1.6)]


def water_surf():
    return [P("M4 56 C 16 56, 22 34, 40 32 C 52 31, 58 42, 60 56", S1),
            line([(20, 24), (52, 20)], S1), line([(26, 22), (28, 27)], S3), line([(46, 20), (47, 25)], S3),
            line([(6, 26), (14, 26)], S3), line([(4, 33), (14, 33)], S3)]


def water_ice_wall():
    out = []
    for x0, top, h in [(10, 20, 6), (25, 12, 6), (40, 18, 6)]:
        out.append(poly([(x0, 52), (x0 + 2, top), (x0 + 8, top - h), (x0 + 13, 52)], S2, False))
        out.append(line([(x0 + 5, 50), (x0 + 6, top + 3)], S3))
    out.append(P("M4 56 C 12 52, 18 58, 26 55 C 34 52, 40 58, 48 55 C 54 53, 58 55, 60 56", S2))
    return out


def water_downpour():
    return [line([(18, 4), (14, 32)], S2), line([(32, 3), (32, 38)], S1), line([(46, 4), (50, 32)], S2),
            head((32, 40), (32, 28), 6),
            P("M8 54 C 14 45, 21 45, 25 51", S2), P("M39 51 C 43 45, 50 45, 56 54", S2),
            line([(4, 56), (60, 56)], S3), dot(10, 44, 1.5), dot(54, 44, 1.5)]


def _water_dodge_shape(filled):
    d = "M46 10 C 52 22, 58 30, 58 40 C 58 48, 52 54, 46 54 C 40 54, 34 48, 34 40 C 34 30, 40 22, 46 10 Z"
    return [P(d, S2, FILL if filled else "")]


def water_dodge():
    return ghosts(_water_dodge_shape, [(-30, 0.35), (-16, 0.6)]) + _water_dodge_shape(True) + \
        [P("M41 40 C 41 45, 44 48, 48 48", S2, 'stroke="#000" stroke-opacity="0.35"')]


def water_mark():
    return [P("M6 50 C 14 50, 18 28, 34 22 C 48 17, 58 26, 56 37 C 54 45, 44 46, 42 38 C 41 33, 45 30, 49 32", S1),
            P("M6 57 L 58 57", S2), P("M14 50 C 22 46, 26 38, 34 34", S3)]


# ======================================================================================== FIRE: tongues
def fire_embers():
    return [tongue(26, 40, 6, 11, 0, True, S3, 70), tongue(38, 28, 7, 13, 0, True, S3, 60),
            tongue(40, 44, 5, 9, 0, True, S3, 95), tongue(52, 22, 5, 10, 0, True, S3, 55),
            tongue(54, 38, 4, 8, 0, True, S3, 85),
            line([(4, 40), (14, 38)], S2), line([(8, 32), (18, 31)], S3), line([(8, 47), (18, 45)], S3)]


def fire_parry():
    return [P("M12 54 C 6 34, 18 12, 40 8", S1),
            tongue(13, 44, 5, 9, 0, True, S3, -100), tongue(13, 30, 5, 9, 0, True, S3, -80),
            tongue(22, 18, 5, 9, 0, True, S3, -55), tongue(34, 11, 5, 8, 0, True, S3, -30),
            line([(62, 50), (40, 34)], S2, 'stroke-dasharray="3 4"'), line([(40, 34), (58, 18)], S2),
            head((58, 18), (40, 34), 5, S2), dot(40, 34, 2.2)]


def fire_punch():
    return [P("M10 32 C 22 20, 38 22, 54 32 C 38 42, 22 44, 10 32 Z", S2, FILL),
            facet("M20 32 C 30 28, 40 29, 50 32"),
            tongue(10, 26, 5, 9, 0, True, S3, -100), tongue(9, 38, 5, 9, 0, True, S3, -80),
            line([(58, 24), (62, 20)], S3), line([(59, 32), (63, 32)], S3), line([(58, 40), (62, 44)], S3)]


def fire_fireball():
    return [circle(38, 32, 13, S2, True),
            facet("M31 28 C 34 22, 42 22, 45 28 C 47 34, 41 38, 37 34"),
            tongue(26, 24, 8, 16, 0, True, S3, -105), tongue(25, 32, 9, 20, 0, True, S3, -90),
            tongue(26, 40, 8, 16, 0, True, S3, -75)]


def fire_lightning():
    return [line([(42, 4), (26, 30), (36, 30), (20, 60)], S1),
            line([(31, 22), (20, 20)], S3), line([(30, 44), (40, 50)], S3),
            tongue(42, 8, 6, 10, 0, True, S3, 30)]


def fire_kick():
    return [ground(54, 4, 60),
            tongue(14, 54, 7, 10, 2), tongue(26, 54, 8, 15, 3), tongue(39, 54, 9, 20, 4), tongue(52, 54, 10, 26, 4),
            line([(4, 46), (8, 46)], S3), line([(4, 40), (7, 40)], S3)]


def fire_high_kick():
    return [P("M10 56 C 10 32, 26 12, 52 10", S1), head((54, 10), (44, 11), 6),
            tongue(13, 42, 6, 10, 0, True, S3, -90 + 10), tongue(19, 27, 6, 11, 0, True, S3, -60),
            tongue(30, 17, 6, 11, 0, True, S3, -35), tongue(42, 12, 5, 9, 0, True, S3, -15)]


def fire_step():
    def sole(cx, cy):
        d = ("M%s %s C %s %s, %s %s, %s %s C %s %s, %s %s, %s %s C %s %s, %s %s, %s %s Z" % (
            f(cx - 1), f(cy - 10), f(cx + 6), f(cy - 10), f(cx + 6), f(cy + 1), f(cx + 3), f(cy + 9),
            f(cx + 1), f(cy + 13), f(cx - 6), f(cy + 12), f(cx - 5), f(cy + 4),
            f(cx - 5), f(cy - 3), f(cx - 7), f(cy - 10), f(cx - 1), f(cy - 10)))
        return P(d, S2, FILL)
    return [sole(20, 40), sole(42, 18),
            tongue(16, 60, 5, 8, -1), tongue(24, 60, 5, 7, 1), tongue(38, 38, 5, 8, -1), tongue(46, 38, 5, 7, 1),
            line([(6, 26), (13, 26)], S3), line([(28, 50), (35, 50)], S3)]


def fire_jets():
    return [line([(20, 24), (32, 10), (44, 24)], S1),
            tongue(26, 30, 7, 22, 0, True, S3, 180), tongue(38, 30, 7, 22, 0, True, S3, 180),
            line([(14, 46), (10, 54)], S3), line([(50, 46), (54, 54)], S3)]


def fire_wall():
    return [ground(56, 4, 60),
            tongue(11, 56, 8, 28, 3), tongue(21, 56, 9, 36, -3), tongue(32, 56, 10, 42, 3), tongue(43, 56, 9, 36, -3),
            tongue(53, 56, 8, 28, 3)]


def fire_breath():
    return [line([(8, 32), (52, 12)], S2), line([(8, 32), (52, 52)], S2),
            P("M52 12 C 46 20, 58 24, 52 32 C 58 40, 46 44, 52 52", S1),
            tongue(22, 32, 6, 14, 0, True, S3, 90), tongue(36, 26, 6, 12, 0, True, S3, 80),
            tongue(36, 38, 6, 12, 0, True, S3, 100), dot(8, 32, 2.2)]


def fire_axe_kick():
    return [P("M10 14 C 30 2, 52 12, 46 40", S1), head((46, 42), (47, 32), 6),
            tongue(16, 10, 5, 9, 0, True, S3, -40), tongue(28, 6, 5, 9, 0, True, S3, -10),
            tongue(40, 8, 5, 9, 0, True, S3, 20), tongue(50, 20, 5, 9, 0, True, S3, 60),
            ground(52, 4, 60), line([(36, 48), (30, 43)], S3), line([(56, 48), (61, 43)], S3)]


def _fire_dodge_shape(filled):
    return [tongue(48, 56, 16, 46, 6, filled, S2)]


def fire_dodge():
    return ghosts(_fire_dodge_shape, [(-30, 0.35), (-16, 0.6)]) + _fire_dodge_shape(True)


def fire_mark():
    return [tongue(32, 54, 16, 46, 5, True, S2), tongue(16, 54, 11, 28, -4, True, S2), tongue(48, 54, 11, 28, 4, True, S2),
            line([(8, 58), (56, 58)], S2)]


# ======================================================================================== AIR: spirals and arcs
def air_palm():
    out = [line([(6, 22), (6, 42)], S1)]
    for r, w in [(12, S1), (21, S2), (30, S3)]:
        out.append(arc(4, 32, r, -48, 48, w)[0])
    return out


def air_guard():
    a1, p1 = arc(32, 32, 24, 200, 470, S1, 36)
    a2, p2 = arc(32, 32, 14, 20, 290, S2, 30)
    return [a1, head(p1[-1], p1[-3], 6), a2, head(p2[-1], p2[-3], 4.5, S2), dot(32, 32, 2.2)]


def air_slice():
    return [P("M10 54 C 28 48, 46 32, 54 8 C 48 30, 32 44, 10 54 Z", S2, FILL),
            line([(6, 40), (24, 30)], S3), line([(14, 28), (30, 18)], S3), line([(24, 16), (36, 9)], S3)]


def air_ball():
    return [circle(36, 32, 15, S1), spiral(36, 32, 1.5, 10.5, 1.3, math.radians(90), 48, S2),
            line([(4, 26), (16, 26)], S3), line([(2, 33), (17, 33)], S2), line([(5, 40), (16, 40)], S3)]


def air_gust():
    return [P("M4 20 L 40 20 C 50 20, 52 10, 45 9 C 40 8, 39 15, 44 15", S1),
            P("M8 33 L 56 33", S2),
            P("M4 46 L 36 46 C 47 46, 49 56, 41 57 C 36 57, 36 51, 40 51", S1)]


def air_pull():
    return [P("M60 18 C 44 18, 34 22, 24 30", S1), head((22, 32), (30, 26), 6),
            P("M60 32 L 26 32", S2), head((24, 32), (34, 32), 5, S2),
            P("M60 46 C 44 46, 34 42, 24 34", S1), head((22, 32), (30, 38), 6),
            arc(14, 32, 7, 60, 300, S3)[0]]


def air_slip():
    return [P("M10 56 C 10 40, 30 42, 30 31 C 30 20, 48 22, 52 8", S1), head((53, 6), (50, 16), 6),
            line([(40, 50), (52, 50)], S3), line([(44, 44), (54, 44)], S3), line([(6, 24), (16, 24)], S3)]


def air_leap():
    _, pk = arc(32, 54, 24, 180, 340, S1, 30)
    return [P("M8 54 C 12 18, 46 10, 54 40", S1), head((55, 43), (52, 33), 6), ground(58, 4, 60, S3),
            arc(8, 54, 6, 200, 340, S3)[0], arc(8, 54, 11, 210, 330, S3)[0]]


def air_wind_wall():
    out = [ground(58, 4, 60)]
    for x, top in [(12, 20), (24, 14), (36, 18), (48, 12)]:
        out.append(P("M%s 56 L %s %s C %s %s, %s %s, %s %s C %s %s, %s %s, %s %s" % (
            f(x), f(x), f(top + 8), f(x), f(top - 2), f(x + 10), f(top - 3), f(x + 10), f(top + 4),
            f(x + 10), f(top + 8), f(x + 5), f(top + 8), f(x + 5), f(top + 4)), S2 if x in (12, 48) else S1))
    return out


def air_down_gust():
    return [line([(22, 4), (22, 34)], S2), line([(32, 2), (32, 38)], S1), line([(42, 4), (42, 34)], S2),
            head((32, 41), (32, 30), 6),
            P("M29 50 C 20 44, 10 46, 9 54", S2), P("M35 50 C 44 44, 54 46, 55 54", S2),
            ground(58, 4, 60, S3)]


def _air_dodge_shape(filled):
    return [spiral(46, 32, 2.0, 13.0, 1.15, math.radians(200), 40, S1 if filled else S2)]


def air_dodge():
    return ghosts(_air_dodge_shape, [(-30, 0.35), (-16, 0.6)]) + _air_dodge_shape(True)


def air_mark():
    return [P("M4 24 L 36 24 C 50 24, 56 12, 46 8 C 39 6, 36 14, 42 16", S1),
            P("M10 36 L 52 36", S2),
            P("M4 48 L 30 48 C 42 48, 44 58, 37 58", S1)]


# ======================================================================================== NEUTRAL: the heals
def patch():
    return [poly([(15, 18), (46, 14), (50, 46), (19, 50)], S2, False),
            poly([(19, 22), (42, 19), (45, 42), (22, 45)], S3, False, 'stroke-dasharray="2.5 3"'),
            line([(32, 24), (33, 40)], S1), line([(24, 33), (41, 31)], S1)]


def mend():
    a, _ = arc(32, 32, 26, -60, 240, S3, 40)
    return [a, line([(10, 42), (22, 28), (30, 36), (40, 20), (54, 26)], S1),
            line([(15, 32), (19, 39)], S3), line([(24, 25), (29, 30)], S3), line([(32, 28), (37, 33)], S3),
            line([(41, 16), (43, 26)], S3), line([(48, 20), (47, 30)], S3)]


# ======================================================================================== ADVANCEMENT: the tree's nodes
# (2026-10-09: the Character Advancement window's nodes that had no picture of their own, drawn in the same family. The
# mode-named ones are found by BendStrip.icon_path(move, mode) as they are; the passives, the skill sets and Kiln Stone,
# which have no mode, are named spell_passive__<name>, spell_set__<set>, spell_synergy__<name>.)
def _sole(cx, cy, rot=0.0, filled=True, w=S2):
    """A footprint's sole (fire_step's), turned `rot` degrees round its middle."""
    pts = [(-1, -10), (6, -10), (6, 1), (3, 9), (1, 13), (-6, 12), (-5, 4), (-5, -3), (-7, -10), (-1, -10)]
    a = math.radians(rot)
    q = [(cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)) for x, y in pts]
    d = "M%s %s C %s %s, %s %s, %s %s C %s %s, %s %s, %s %s C %s %s, %s %s, %s %s Z" % tuple(
        f(v) for p in q for v in p)
    return P(d, w, FILL if filled else "")


def _flake(cx, cy, r, w=S2, branch=True):
    """A six-armed snow crystal."""
    out = []
    for k in range(6):
        a = math.radians(90 + k * 60)
        tip = (cx + math.cos(a) * r, cy - math.sin(a) * r)
        out.append(line([(cx, cy), tip], w))
        if branch:
            mid = (cx + math.cos(a) * r * 0.58, cy - math.sin(a) * r * 0.58)
            for s in (-1, 1):
                b = a + s * math.radians(42)
                out.append(line([mid, (mid[0] + math.cos(b) * r * 0.32, mid[1] - math.sin(b) * r * 0.32)], S3))
    return out


def _star(cx, cy, r0, r1, n=8, w=S2, a0=0.0):
    """An impact burst: n short rays between r0 and r1."""
    out = []
    for k in range(n):
        a = math.radians(a0 + k * 360.0 / n)
        rr = r1 if k % 2 == 0 else r1 * 0.72
        out.append(line([(cx + math.cos(a) * r0, cy + math.sin(a) * r0), (cx + math.cos(a) * rr, cy + math.sin(a) * rr)], w))
    return out


def _puff(cx, cy, s, w=S2):
    """A gas or dust puff: a lumpy closed cloud, `s` its scale (1 = 28 wide)."""
    k = [(-14, 4), (-15, -3, -11, -9, -6, -7), (-5, -14, 6, -14, 6, -8), (11, -11, 16, -5, 13, 0), (17, 4, 13, 9, 8, 7),
         (4, 11, -4, 11, -6, 7), (-11, 10, -16, 8, -14, 4)]
    d = "M%s %s" % (f(cx + k[0][0] * s), f(cy + k[0][1] * s))
    for c in k[1:]:
        d += " C %s %s, %s %s, %s %s" % (f(cx + c[0] * s), f(cy + c[1] * s), f(cx + c[2] * s), f(cy + c[3] * s),
                                         f(cx + c[4] * s), f(cy + c[5] * s))
    return P(d + " Z", w)


def _roots(x, y, depth, spread, w1=S1, w2=S2):
    """Three roots down from (x, y): `depth` deep, fanning `spread` wide."""
    return [P("M%s %s C %s %s, %s %s, %s %s" % (f(x - 3), f(y), f(x - 4), f(y + depth * 0.4), f(x - spread * 0.6),
                                                f(y + depth * 0.7), f(x - spread), f(y + depth)), w2),
            P("M%s %s L %s %s" % (f(x), f(y), f(x), f(y + depth * 1.05)), w1),
            P("M%s %s C %s %s, %s %s, %s %s" % (f(x + 3), f(y), f(x + 4), f(y + depth * 0.4), f(x + spread * 0.6),
                                                f(y + depth * 0.7), f(x + spread), f(y + depth)), w2)]


def _block(x0, y0, x1, y1):
    """A squat slab standing on y1 (earth's filled solid), its top a little uneven."""
    return [poly([(x0, y1), (x0 + 1, y0 + 2), (x0 + (x1 - x0) * 0.45, y0), (x1 - 1, y0 + 1.5), (x1, y1)], S2),
            facet("M%s %s L %s %s" % (f(x0 + 2), f((y0 + y1) * 0.5), f(x1 - 2), f((y0 + y1) * 0.5 + 1)))]


# -- earth
def earth_shell():
    out = [circle(32, 32, 4, S2, True)]
    for (x0, y0, x1, y1) in [(19, 6, 45, 13), (19, 51, 45, 58), (6, 19, 13, 45), (51, 19, 58, 45)]:
        out.append(poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], S2))
    out += [facet("M24 9.5 L 40 9.5 M24 54.5 L 40 54.5 M9.5 24 L 9.5 40 M54.5 24 L 54.5 40"),
            line([(15, 15), (19, 19)], S3), line([(49, 15), (45, 19)], S3), line([(15, 49), (19, 45)], S3),
            line([(49, 49), (45, 45)], S3)]
    return out


def earth_vent():
    return [line([(4, 50), (24, 50)], S2), line([(40, 50), (60, 50)], S2),
            line([(24, 50), (28, 56), (32, 51), (36, 58), (40, 50)], S2),
            poly([(10, 50), (14, 43), (19, 50)], S3), poly([(46, 50), (51, 44), (55, 50)], S3),
            _puff(31, 34, 0.55, S2), _puff(25, 19, 0.42, S2), _puff(40, 10, 0.34, S3)]


def earth_disc():
    pts = [(32 + math.cos(math.radians(a)) * 24, 32 + math.sin(math.radians(a)) * 9) for a in range(0, 360, 36)]
    a1, p1 = arc(32, 32, 28, 195, 265, S2)
    a2, p2 = arc(32, 32, 28, 15, 85, S2)
    return [poly(pts, S2), facet("M14 32 C 20 28, 44 28, 50 32"),
            P("M27 32 C 27 30, 37 30, 37 32 C 37 34, 27 34, 27 32 Z", S3, 'stroke="#000" stroke-opacity="0.45"'),
            a1, head(p1[-1], p1[-3], 4.5, S2), a2, head(p2[-1], p2[-3], 4.5, S2)]


def earth_column_shell():
    out = [ground(58, 34, 60),
           poly([(39, 58), (39, 22), (46, 15), (53, 22), (53, 58)], S2), facet("M39 34 L 53 33 M39 46 L 53 47"),
           line([(46, 10), (46, 3)], S3), line([(40, 11), (36, 6)], S3), line([(52, 11), (56, 6)], S3),
           line([(4, 20), (28, 20)], S3, 'stroke-dasharray="3 3"'), head((33, 20), (24, 20), 4, S3),
           circle(16, 44, 2.6, S3, True)]
    for (x0, y0, x1, y1) in [(9, 33, 23, 37), (9, 51, 23, 55), (5, 37, 9, 51), (23, 37, 27, 51)]:
        out.append(poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], S3))
    return out


def earth_free_pillar():
    return [ground(56, 4, 60),
            poly([(6, 56), (32, 56), (32, 36)], S2), facet("M14 52 L 30 40"),
            poly([(40, 56), (40, 22), (46, 18), (54, 22), (54, 56)], S2), facet("M40 34 L 54 33 M40 45 L 54 46"),
            line([(47, 13), (47, 4)], S2), head((47, 3), (47, 10), 4.5, S2)]


def _seated(x0, x1, top, base, depth, gx0=4, gx1=60):
    """A broad stone seated on the ground at `base` (earth's filled solid, faceted), its roots spreading sideways under
    the ground and forking, `depth` deep."""
    cx = (x0 + x1) * 0.5
    k = depth / 20.0
    out = [line([(gx0, base), (gx1, base)], S2),
           poly([(x0, base), (x0 + 3, top + 6), (x0 + (x1 - x0) * 0.3, top + 1), (x0 + (x1 - x0) * 0.62, top),
                 (x1 - 3, top + 5), (x1, base)], S2),
           facet("M%s %s L %s %s L %s %s" % (f(x0 + 6), f(top + 9), f(cx), f(top + 12), f(x1 - 6), f(top + 8)))]
    for sgn in (-1, 1):
        a = (cx + sgn * 5, base + 1)
        b = (cx + sgn * 14 * k, base + 9 * k)
        c = (cx + sgn * 24 * k, base + 13 * k)
        out.append(P("M%s %s C %s %s, %s %s, %s %s" % (f(a[0]), f(a[1]), f(a[0] + sgn * 2), f(base + 6 * k), f(b[0] - sgn * 3),
                                                       f(b[1]), f(b[0]), f(b[1])), S1))
        out.append(line([b, c], S2))
        out.append(line([b, (b[0] + sgn * 3 * k, base + 19 * k)], S3))
        out.append(line([c, (c[0] + sgn * 4 * k, c[1] + 6 * k)], S3))
    out.append(P("M%s %s C %s %s, %s %s, %s %s" % (f(cx), f(base + 1), f(cx + 1), f(base + 8 * k), f(cx - 2), f(base + 12 * k),
                                                   f(cx), f(base + 18 * k)), S2))
    return out


def passive_rooted():
    return _seated(12, 52, 14, 40, 20)


def passive_deep_roots():
    return _seated(16, 48, 6, 30, 30) + [line([(5, 4), (5, 15)], S3), head((5, 18), (5, 11), 3.5, S3)]


def passive_swift_roots():
    return _seated(4, 34, 20, 42, 12, 2, 38) + \
        [line([(41, 18), (48, 27), (41, 36)], S1), line([(50, 18), (57, 27), (50, 36)], S2)]


def passive_sulphur_heart():
    return [_puff(32, 34, 1.45, S1), circle(32, 36, 5, S2, True),
            line([(32, 6), (32, 14)], S3), head((32, 4), (32, 10), 4, S3),
            line([(44, 9), (40, 15)], S3), line([(20, 9), (24, 15)], S3)]


def set_sulphur():
    return [poly([(6, 56), (8, 44), (18, 38), (30, 42), (32, 56)], S2), facet("M10 48 L 20 44 L 28 47"),
            _puff(36, 30, 0.62, S2), _puff(46, 16, 0.48, S2), _puff(54, 6, 0.3, S3),
            line([(30, 38), (32, 35)], S3)]


def synergy_kiln_stone():
    pts = [(42 + math.cos(math.radians(a)) * r, 32 + math.sin(math.radians(a)) * r)
           for a, r in [(0, 13), (50, 12), (100, 13), (150, 12.5), (200, 13), (250, 12), (300, 13)]]
    return [tongue(26, 22, 6, 16, 0, True, S3, -100), tongue(25, 32, 7, 20, 0, True, S3, -90),
            tongue(26, 42, 6, 16, 0, True, S3, -80),
            poly(pts, S2), facet("M36 26 L 42 32 L 50 28 M42 32 L 40 42"),
            P("M48 10 C 46 7, 50 5, 48 2", S3), P("M56 14 C 54 11, 58 9, 56 6", S3)]


# -- water
def water_bubble():
    return [circle(32, 30, 22, S1), P("M17 26 C 18 18, 24 12, 32 11", S2), P("M45 37 C 43 42, 39 45, 34 46", S3),
            dot(13, 57, 1.8), dot(51, 57, 1.8), dot(32, 59, 1.6), P("M14 52 C 24 55, 40 55, 50 52", S3)]


def water_mire():
    return [P("M5 46 C 5 37, 59 37, 59 46 C 59 55, 5 55, 5 46 Z", S1),
            P("M18 46 C 18 42, 46 42, 46 46 C 46 50, 18 50, 18 46 Z", S2),
            poly([(26, 46), (29, 41), (35, 40), (39, 46)], S3),
            circle(22, 28, 3.6, S2), circle(36, 22, 2.6, S3), circle(44, 31, 2.0, S3), dot(30, 33, 1.6)]


def water_freeze_river():
    return [P("M4 40 C 8 33, 12 47, 16 40 C 20 33, 24 47, 28 40", S1), line([(30, 40), (60, 40)], S1),
            line([(34, 46), (38, 44)], S3), line([(44, 47), (49, 44)], S3), line([(54, 46), (58, 44)], S3),
            line([(30, 52), (60, 52)], S3)] + _flake(45, 20, 11, S2)


def water_heal():
    return [P("M32 6 C 40 18, 50 28, 50 40 C 50 50, 42 58, 32 58 C 22 58, 14 50, 14 40 C 14 28, 24 18, 32 6 Z", S1),
            line([(32, 30), (32, 49)], S1), line([(22.5, 39.5), (41.5, 39.5)], S1)]


def passive_flowing():
    return [P("M6 56 C 8 38, 22 30, 34 30 C 44 30, 46 22, 44 16", S1, 'stroke-dasharray="1 0"'),
            P("M50 4 C 54 10, 58 14, 58 19 C 58 23, 55 26, 51 26 C 47 26, 44 23, 44 19 C 44 14, 47 10, 50 4 Z", S2, FILL),
            dot(14, 40, 1.4), dot(24, 33, 1.4), line([(4, 60), (14, 60)], S3)]


def passive_lazy_river():
    return [P("M4 18 C 26 18, 36 44, 60 44", S1), P("M4 30 C 22 30, 32 56, 60 56", S1),
            P("M14 24 C 18 22, 22 26, 26 24", S3), P("M38 44 C 42 42, 46 46, 50 44", S3)]


def passive_rapids():
    return [P("M4 34 C 9 20, 14 48, 20 34 C 26 20, 31 48, 37 34 C 43 20, 48 48, 54 34", S1),
            head((58, 26), (54, 34), 5, S1),
            dot(12, 14, 1.6), dot(28, 12, 1.5), dot(44, 16, 1.4), dot(20, 54, 1.4), dot(38, 55, 1.5)]


def passive_delta():
    return [P("M30 4 C 36 10, 26 16, 32 22", S1),
            P("M32 22 C 26 28, 22 30, 18 36 C 14 42, 18 46, 12 54", S2), P("M18 36 C 22 42, 28 46, 26 56", S3),
            P("M32 22 C 38 28, 42 30, 46 36 C 50 42, 46 46, 52 54", S2), P("M46 36 C 42 42, 36 46, 38 56", S3),
            P("M4 60 C 20 56, 44 56, 60 60", S3)]


def set_mud():
    return [P("M4 46 C 4 38, 60 38, 60 46 C 60 54, 4 54, 4 46 Z", S2),
            P("M16 46 C 16 43, 48 43, 48 46 C 48 49, 16 49, 16 46 Z", S3),
            poly([(26, 26), (30, 18), (38, 17), (42, 24), (38, 31), (29, 32)], S2), facet("M30 20 L 34 25 L 40 23"),
            line([(34, 34), (34, 39)], S3), dot(20, 36, 1.6), dot(47, 36, 1.6)]


# -- fire
def fire_cauterize():
    out = [line([(6, 48), (17, 44), (28, 48), (39, 44), (50, 48), (58, 45)], S1)]
    for x in (12, 23, 34, 45):
        out.append(line([(x - 3, 40), (x + 3, 53)], S3))
    out.append(tongue(32, 36, 13, 30, 3, True, S2))
    return out


def fire_hover():
    return [line([(15, 12), (29, 12)], S1), line([(35, 12), (49, 12)], S1),
            tongue(22, 15, 10, 26, 2, True, S3, 180), tongue(42, 15, 10, 26, -2, True, S3, 180),
            line([(4, 56), (60, 56)], S2, 'stroke-dasharray="4 5"'),
            line([(8, 26), (8, 44)], S3), head((8, 24), (8, 32), 3.5, S3), head((8, 46), (8, 38), 3.5, S3)]


def fire_heat():
    return [P("M18 34 C 12 28, 24 22, 18 16 C 12 10, 24 6, 18 2", S2),
            P("M32 34 C 26 28, 38 22, 32 16 C 26 10, 38 6, 32 2", S1),
            P("M46 34 C 40 28, 52 22, 46 16 C 40 10, 52 6, 46 2", S2),
            poly([(12, 56), (16, 42), (28, 39), (40, 41), (50, 45), (52, 56)], S2, False),
            line([(22, 46), (26, 52)], S3), line([(38, 46), (42, 51)], S3),
            dot(20, 61, 1.5), dot(36, 62, 1.5), dot(46, 60.5, 1.3)]


def passive_footwork():
    return [_sole(22, 38, -8), _sole(42, 30, 8),
            arc(32, 34, 26, 200, 300, S3)[0], head((45, 11.5), (38, 9), 4, S3),
            arc(32, 34, 26, 20, 120, S3)[0], head((19, 56.5), (26, 59), 4, S3)]


def passive_dancing_feet():
    return [_sole(18, 42, -25), _sole(38, 24, 20),
            P("M10 18 C 14 8, 26 4, 30 10", S3), head((31, 12), (27, 6), 3.5, S3)] + \
        _star(52, 46, 4, 10, 8, S3) + [tongue(52, 44, 5, 8, 0, True, S3)]


def passive_hot_feet():
    return [_sole(42, 24, 35), tongue(30, 40, 6, 14, 0, True, S3, -130), tongue(24, 34, 6, 16, 0, True, S3, -120),
            tongue(33, 47, 5, 11, 0, True, S3, -140), line([(6, 58), (60, 58)], S3),
            line([(50, 44), (58, 44)], S3), line([(52, 50), (60, 50)], S3)]


def passive_forge():
    return [poly([(4, 20), (12, 22), (52, 22), (54, 30), (42, 32), (38, 42), (46, 50), (18, 50), (26, 42), (24, 32),
                  (14, 30)], S2),
            facet("M30 22 L 33 27 L 29 31"), line([(12, 56), (52, 56)], S2),
            tongue(33, 18, 5, 9, 0, True, S3)] + _star(46, 10, 3, 8, 6, S3, -90)


def set_magma():
    return [poly([(4, 56), (6, 40), (28, 36), (30, 56)], S2), poly([(34, 56), (36, 36), (58, 40), (60, 56)], S2),
            line([(30, 56), (31, 46), (33, 44), (32, 36)], S2),
            tongue(32, 34, 9, 22, 1, True, S2), tongue(22, 34, 6, 12, -1, True, S3), tongue(43, 35, 6, 12, 1, True, S3),
            facet("M8 46 L 26 44 M38 44 L 56 47")]


# -- air
def air_dust_cloud():
    return [_puff(32, 34, 1.7, S1), dot(22, 34, 1.8), dot(31, 30, 1.5), dot(40, 36, 1.8), dot(28, 40, 1.3),
            dot(46, 30, 1.3), line([(4, 60), (60, 60)], S3)]


def air_blizzard():
    return [P("M12 8 C 30 2, 52 6, 48 13 C 44 20, 18 17, 18 24 C 18 31, 46 28, 43 35 C 40 42, 22 39, 23 45 "
              "C 24 51, 40 50, 36 57", S1)] + _flake(55, 26, 5, S3, False) + _flake(9, 38, 5, S3, False) + \
        _flake(54, 50, 4, S3, False) + _flake(10, 56, 3.5, S3, False)


def air_wind_run():
    return [spiral(14, 44, 1.5, 9, 1.1, math.radians(0), 36, S2),
            P("M22 44 C 32 44, 38 30, 52 30", S1), head((55, 30), (46, 30), 6),
            line([(8, 18), (34, 18)], S2), line([(16, 26), (38, 26)], S3), line([(30, 56), (58, 56)], S3)]


def air_glide():
    return [P("M6 8 C 26 10, 42 22, 50 44", S1), arc(52, 52, 7, 180, 360, S2)[0], arc(52, 52, 12, 200, 340, S3)[0],
            ground(58, 30, 62, S3), line([(16, 4), (26, 5)], S3), line([(30, 10), (38, 13)], S3)]


def passive_carried_wind():
    return [P("M4 52 C 16 52, 20 32, 34 32", S1), line([(6, 42), (16, 42)], S3), line([(10, 60), (22, 60)], S3)] + \
        _star(46, 30, 4, 13, 8, S2)


def passive_long_carry():
    return [line([(4, 32), (50, 32)], S1), head((54, 32), (44, 32), 6), arc(56, 24, 5, 90, 300, S3)[0],
            line([(4, 22), (40, 22)], S3), line([(8, 42), (36, 42)], S3), line([(4, 50), (24, 50)], S3)]


def passive_gale_force():
    return [line([(6, 22), (28, 22)], S1), line([(2, 32), (32, 32)], S1), line([(6, 42), (28, 42)], S1)] + \
        _star(46, 32, 5, 15, 8, S1)


def passive_whiteout():
    return _flake(32, 24, 17, S1) + [line([(4, 56), (12, 52), (20, 56), (28, 52), (36, 56), (44, 52), (52, 56), (60, 52)],
                                          S2)]


def set_frostwind():
    return [P("M4 20 L 34 20 C 44 20, 46 10, 39 9 C 34 8, 33 15, 38 15", S1), P("M8 33 L 30 33", S2),
            P("M4 46 L 26 46", S1)] + _flake(46, 42, 13, S2)


# ======================================================================================== the set
## file name (without "spell_" and ".svg") -> (the drawing, the element whose motif it is, what it shows)
ICONS = {
    # earth
    "rock_jab__pebbles": (earth_pebbles, "earth", "three angular pebbles thrown"),
    "stone_catch__catch": (earth_catch, "earth", "a stone stopped in a slab cradle"),
    "stone_catch__return": (earth_return, "earth", "the caught stone sent back round"),
    "stone_form__spike": (earth_spike, "earth", "a shard rising from the deck"),
    "stone_form__cannonball": (earth_boulder, "earth", "a round rock with a trail"),
    "earth_shove__push": (earth_shove, "earth", "a slab driven forward"),
    "earth_shove__column": (earth_column, "earth", "a column bursting up"),
    "earth_skate__burrow": (earth_burrow, "earth", "a mound running under the deck"),
    "pillar__self": (earth_lift, "earth", "a block lifting you"),
    "earth_wall__wall": (earth_wall, "earth", "a wall of coursed blocks"),
    "slam__earth": (earth_hammer, "earth", "a slab hammered down"),
    "dodge__earth": (earth_dodge, "earth", "a shard stepping aside"),
    "mark__earth": (earth_mark, "earth", "the plates' mark: three stacked slabs"),
    # water
    "water_jet__splash": (water_splash, "water", "a jet bursting into drops"),
    "water_redirect__redirect": (water_turn, "water", "a stream turned round"),
    "water_whip__whip": (water_lash, "water", "a lash cracking"),
    "ice__spear": (water_spear, "water", "a long ice shard"),
    "ice_axe__axe": (water_tomahawk, "water", "an ice tomahawk over its splash"),
    "wave__push": (water_wave, "water", "a breaking crest"),
    "wave__spout": (water_geyser, "water", "a column of water bursting up"),
    "flow__skate": (water_skate, "water", "a ribbon of water underfoot"),
    "flow__surf": (water_surf, "water", "a board on a swell"),
    "water_shield__ice_wall": (water_ice_wall, "water", "ice panels over a crest"),
    "slam__water": (water_downpour, "water", "water pouring down"),
    "dodge__water": (water_dodge, "water", "a drop stepping aside"),
    "mark__water": (water_mark, "water", "the plates' mark: one curling crest"),
    # fire
    "fire_jab__embers": (fire_embers, "fire", "a spray of small tongues"),
    "fire_parry__parry": (fire_parry, "fire", "a flame sweep turning a shot away"),
    "fire_blast__punch": (fire_punch, "fire", "a short flame bolt"),
    "fire_blast__fireball": (fire_fireball, "fire", "a big ball with tongues licking back"),
    "fire_arc__lightning": (fire_lightning, "fire", "a forked bolt"),
    "fire_kick__kick": (fire_kick, "fire", "tongues racing along the deck"),
    "fire_kick__high_kick": (fire_high_kick, "fire", "an arc of flame sweeping up"),
    "footwork__step": (fire_step, "fire", "two burning steps"),
    "fire_jets__jets": (fire_jets, "fire", "two jets driving you up"),
    "fire_wall__wall": (fire_wall, "fire", "a row of tall tongues"),
    "fire_breath__breath": (fire_breath, "fire", "a widening cone of flame"),
    "slam__fire": (fire_axe_kick, "fire", "a flame arc chopping down"),
    "dodge__fire": (fire_dodge, "fire", "a tongue stepping aside"),
    "mark__fire": (fire_mark, "fire", "the plates' mark: three tongues"),
    # air
    "air_palm__palm": (air_palm, "air", "a push of arcs from the palm"),
    "air_shield__shield": (air_guard, "air", "two turning arcs round you"),
    "air_blast__slice": (air_slice, "air", "a thin crescent blade"),
    "air_blast__ball": (air_ball, "air", "a ball with a spiral in it"),
    "air_gust__gust": (air_gust, "air", "three streaks with curls"),
    "air_gust__pull": (air_pull, "air", "streaks hooking back to you"),
    "evade__slip": (air_slip, "air", "a swerve"),
    "air_jump__leap": (air_leap, "air", "a high arc off a puff"),
    "air_wall__wall": (air_wind_wall, "air", "rising streaks curling at the top"),
    "slam__air": (air_down_gust, "air", "streaks driving down, a puff spreading"),
    "dodge__air": (air_dodge, "air", "a swirl stepping aside"),
    "mark__air": (air_mark, "air", "the plates' mark: streaks with a curl"),
    # any element
    "patch__patch": (patch, "any", "a stitched patch"),
    "mend__mend": (mend, "any", "a crack stitched shut"),
    # the Character Advancement window's nodes (2026-10-09): mode-named ones BendStrip.icon_path finds as they are
    "water_shield__bubble": (water_bubble, "water", "Bubble: a sphere of water round you"),
    "water_shield__mire": (water_mire, "water", "Mire: a mud pool, bubbling"),
    "frost__freeze_water": (water_freeze_river, "water", "Freeze the River: running water set flat, a crystal over it"),
    "water_shield__heal": (water_heal, "water", "Healing Water: a drop with a cross"),
    "patch__cauterize": (fire_cauterize, "fire", "Cauterize: a flame over a stitched wound"),
    "fire_jets__hover": (fire_hover, "fire", "Hover: two jets holding you over the ground"),
    "fire_breath__heat": (fire_heat, "fire", "Heat: heat shimmer over melting ice"),
    "air_wall__dust": (air_dust_cloud, "air", "Dust Cloud: a billowing cloud with grit in it"),
    "air_wall__blizzard": (air_blizzard, "air", "Blizzard: a whirling column of snow"),
    "wind_run__wind_run": (air_wind_run, "air", "Wind Run and Whirl Ride: a whirl and a long swoop forward"),
    "air_jump__glide": (air_glide, "air", "Glide Landing: a long glide onto a cushion of air"),
    "earth_wall__shell": (earth_shell, "earth", "Shell: four slabs closing round you, from above"),
    "earth_wall__vent": (earth_vent, "earth", "Sulphur Vent: the deck cracking, breathing gas"),
    "stone_form__disc": (earth_disc, "earth", "Stone Disc: a spinning stone disc"),
    "earth_wall__column": (earth_column_shell, "earth", "Raised Column and Shell: a far column, a shell of slabs"),
    "pillar__free": (earth_free_pillar, "earth", "Free Pillar and Ramp: a ramp and a pillar rising"),
    # ... and the ones with no mode: the element passives, the passive nodes, the skill sets, Kiln Stone
    "passive__rooted": (passive_rooted, "earth", "Rooted: a slab standing on its roots"),
    "passive__deep_roots": (passive_deep_roots, "earth", "Deep Roots: long roots, pressed down"),
    "passive__swift_roots": (passive_swift_roots, "earth", "Swift Roots: short roots, quick chevrons"),
    "passive__sulphur_heart": (passive_sulphur_heart, "earth", "Sulphur Heart: you in your own cloud, rising"),
    "set__sulphur": (set_sulphur, "earth", "Sulphur: a stone breathing gas"),
    "synergy__kiln_stone": (synergy_kiln_stone, "earth", "Kiln Stone: a stone through fire, hot"),
    "passive__flowing": (passive_flowing, "water", "Flowing: a drop whose trail bends after it leaves"),
    "passive__lazy_river": (passive_lazy_river, "water", "Lazy River: a wide, slow bend"),
    "passive__rapids": (passive_rapids, "water", "Rapids: a tight, quick zigzag"),
    "passive__delta": (passive_delta, "water", "Delta: a stream spreading into mud"),
    "set__mud": (set_mud, "water", "Mud: a clod dropping into a pool"),
    "passive__footwork": (passive_footwork, "fire", "Footwork: two soles turning"),
    "passive__dancing_feet": (passive_dancing_feet, "fire", "Dancing Feet: a step and a flare after it"),
    "passive__hot_feet": (passive_hot_feet, "fire", "Hot Feet: a sole running with flames behind"),
    "passive__forge": (passive_forge, "fire", "Forge: an anvil, sparks off it"),
    "set__magma": (set_magma, "fire", "Magma: cracked ground, fire out of the seam"),
    "passive__carried_wind": (passive_carried_wind, "air", "Carried wind: a dash into a burst"),
    "passive__long_carry": (passive_long_carry, "air", "Long Carry: a long streak, carried far"),
    "passive__gale_force": (passive_gale_force, "air", "Gale Force: short heavy streaks into a big burst"),
    "passive__whiteout": (passive_whiteout, "air", "Whiteout: a crystal over frozen crust"),
    "set__frostwind": (set_frostwind, "air", "Frostwind: a gust turning to crystal"),
}


def svg(name):
    fn = ICONS[name][0]
    return "\n".join([HEAD] + fn() + ["</svg>", ""])


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ui", "icons")
    os.makedirs(out, exist_ok=True)
    seen = {}
    for name in ICONS:
        body = svg(name)
        if body in seen:
            raise SystemExit("two icons draw the same picture: %s and %s" % (seen[body], name))
        seen[body] = name
        with open(os.path.join(out, "spell_%s.svg" % name), "w") as fh:
            fh.write(body)
    print("move_icons: %d icons -> %s" % (len(ICONS), os.path.abspath(out)))


if __name__ == "__main__":
    main()
