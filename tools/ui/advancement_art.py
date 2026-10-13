#!/usr/bin/env python3
"""The Character Advancement window's own SVG pieces (2026-10-09; artifacts/ui_audit/advancement/plan.md, its art section),
written by hand here as path data, our own drawings: no game's frame, mark or glyph traced or copied.

    python3 tools/ui/advancement_art.py [out_dir]       (default assets/ui/advancement; then Godot --import)

Writes into out_dir:
  frame_corner.svg      a corner knot for the window frame (top-left; the window mirrors it for the other corners)
  rail_frame.svg        the tall rail frame with diamond knot caps, at the plan's rail size (80 x 600 authored px)
  rail_cap.svg          the rail's diamond cap alone (top; flipped for the bottom), for a rail of another height
  padlock.svg           the gate's padlock (white, tinted at draw time)
  choice_arrow.svg      the gold arrow tab on a choice octagon's side (points right; mirrored for the left)
  rank_plate.svg        the rank badge's plate (the window writes "1/1" over it)
  toast_frame.svg       the "worn" toast's frame: a gold-edged plate with a soft gold glow and an icon socket at its left
  kind_<kind>.svg       the 7 kind marks, keyed by skill_tree.json's kind ids: variation (Twist: a fork), mastery
                        (Technique: a star), new_skill (a spark), synergy (two linked rings), skill_set (a hexagon),
                        passive (a ringed dot), world_only (World art: a peak). Enhance has none (its node is round).
  set_<set>.svg         the 4 skill-set marks: sulphur (a rising puff), mud (ringed ripples), magma (a cracked seam),
                        frostwind (a jagged crystal); outline shapes that read without their tint
  style_<style>.svg     one glyph per fighting style (17: each element's four and Jeet Kune Do)
  emblem_<element>_<style>.svg   the 20 class emblems (element + style): a medallion ring, the style's glyph, the
                        element's own plate mark (spell_mark__<element>, tools/ui/move_icons.py) in a badge
  art.json              what the window builder reads: every path above, the set tints, the theme colours, and the
                        icon of every skill_tree.json node (its own spell_<move>__<mode> picture, else the passive/set
                        picture, else its move's)
Marks, glyphs, emblems and the padlock are white line art in the move icons' family (round caps, strokes 3.4 / 2.8 /
1.6 on a 64 grid; marks a little bolder, with a dark halo so they read on any plate), tinted at draw time. The frame
pieces carry their own colours (the plan's AdvancementTheme: dark stone #12151c-#1a1f29, gold #a8844a / #d7b26a).
"""
import json
import math
import os
import re
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import move_icons as mi  # noqa: E402  (the line family: P, line, poly, circle, arc, spiral, head, tongue, dot, f)

from move_icons import P, line, poly, circle, arc, spiral, head, tongue, dot, f, FILL, S1, S2, S3  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RES = "res://assets/ui/advancement/"
ICON_RES = "res://assets/ui/icons/"

STONE_D, STONE_L, STONE_X = "#12151c", "#1a1f29", "#0b0d12"
GOLD_D, GOLD_L, GOLD_HI = "#a8844a", "#d7b26a", "#f3dc9a"
RED_D, RED_L = "#4a0f0b", "#7a1f17"
THEME = {"stone_dark": STONE_D, "stone_light": STONE_L, "gold": GOLD_D, "gold_light": GOLD_L, "gold_high": GOLD_HI,
         "button_dark": RED_D, "button_light": RED_L, "worn": "#ffd100", "links": "#c9a227", "available": "#3ee03e",
         "blocked": "#7d8794", "reason": "#ff4b3e"}
SET_TINTS = {"sulphur": "#c9d24a", "mud": "#8c6a45", "magma": "#e8642a", "frostwind": "#a9dcf2"}
SET_ELEMENT = {"sulphur": "earth", "mud": "water", "magma": "fire", "frostwind": "air"}
ELEMENTS = ["earth", "water", "fire", "air"]
## Each element's four styles (docs/fighting_styles_design.md's rosters; the canon style first) and Jeet Kune Do for all.
STYLES = {
    "earth": [("hung_gar", "Hung Gar"), ("karate", "Karate"), ("sumo", "Sumo"), ("wrestling", "Wrestling")],
    "water": [("tai_chi", "Tai Chi"), ("aikido", "Aikido"), ("judo", "Judo"), ("wing_chun", "Wing Chun")],
    "fire": [("northern_shaolin", "Northern Shaolin"), ("boxing", "Boxing"), ("muay_thai", "Muay Thai"),
             ("kickboxing", "Kickboxing")],
    "air": [("baguazhang", "Baguazhang"), ("capoeira", "Capoeira"), ("taekwondo", "Taekwondo"),
            ("drunken_boxing", "Drunken Boxing")],
}
ANY_STYLE = ("jeet_kune_do", "Jeet Kune Do")
## A node with no picture of its own and no mode: the picture drawn for it (tools/ui/move_icons.py), by node id.
NODE_PICTURE = {
    "earth.passive.deep_roots": "passive__deep_roots", "earth.passive.swift_roots": "passive__swift_roots",
    "earth.sulphur.heart": "passive__sulphur_heart", "earth.set.sulphur": "set__sulphur",
    "earth.stone.kiln_stone": "synergy__kiln_stone",
    "water.passive.lazy_river": "passive__lazy_river", "water.passive.rapids": "passive__rapids",
    "water.mud.delta": "passive__delta", "water.set.mud": "set__mud",
    "fire.passive.dancing_feet": "passive__dancing_feet", "fire.passive.hot_feet": "passive__hot_feet",
    "fire.magma.forge": "passive__forge", "fire.set.magma": "set__magma",
    "air.passive.long_carry": "passive__long_carry", "air.passive.gale_force": "passive__gale_force",
    "air.frost.whiteout": "passive__whiteout", "air.set.frostwind": "set__frostwind",
}
## A node whose move-mode is drawn under another chip's name: the Downpour is water's Slam (BendStrip: slam/water).
NODE_ALIAS = {("wave", "slam"): "slam__water"}
## The node pictures added to tools/ui/move_icons.py for this window that BendStrip finds by their move-mode as they are.
MODE_PICTURES = ["water_shield__bubble", "water_shield__mire", "frost__freeze_water", "water_shield__heal",
                 "patch__cauterize", "fire_jets__hover", "fire_breath__heat", "air_wall__dust", "air_wall__blizzard",
                 "wind_run__wind_run", "air_jump__glide", "earth_wall__shell", "earth_wall__vent", "stone_form__disc",
                 "earth_wall__column", "pillar__free"]
## The element passives (the passive line's root in the window).
PASSIVE_ROOT = {"earth": "passive__rooted", "water": "passive__flowing", "fire": "passive__footwork",
                "air": "passive__carried_wind"}

M1, M2 = 5.2, 4.2          # the marks' strokes (bolder than the icons': they are drawn at 16-24 px)


def head_svg(w, h, vw, vh, extra=""):
    """The <svg> head: white round-capped strokes by default; `extra` ' stroke="none"' for the coloured frame pieces."""
    stroke = "none" if 'stroke="none"' in extra else "#ffffff"
    extra = extra.replace(' stroke="none"', "")
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 %s %s" fill="none" '
            'stroke="%s" stroke-linecap="round" stroke-linejoin="round"%s>' % (f(w), f(h), f(vw), f(vh), stroke, extra))


def icon_svg(parts):
    return "\n".join([head_svg(128, 128, 64, 64)] + parts + ["</svg>", ""])


def haloed(parts, extra_w=3.4):
    """`parts` drawn twice: first as a dark halo (every stroke widened, fills dark), then as they are."""
    out = ['  <g stroke="#000" opacity="0.55">']
    for p in parts:
        q = p.replace(FILL, 'fill="#000"')
        q = re.sub(r'stroke-width="([0-9.]+)"', lambda m: 'stroke-width="%s"' % f(float(m.group(1)) + extra_w), q)
        q = q.replace('stroke="#000" stroke-opacity="0.35"', "")
        out.append(q)
    out.append("  </g>")
    return out + parts


# ===================================================================================================== frame pieces
GOLD_GRAD = ('<linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="%s"/>'
             '<stop offset="0.5" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>' % (GOLD_HI, GOLD_L, GOLD_D))


def frame_corner():
    """The corner knot (top-left): a diamond knot with a broken ring threaded through it where two gold rails meet, each
    rail a thick line with a thin one inside, ending in a small diamond, a stud along it."""
    s = [head_svg(128, 128, 64, 64, ' stroke="none"'), "  <defs>%s</defs>" % GOLD_GRAD]
    k = 13.0                                     # the knot's centre (both axes)

    def rail(d, w, col):
        s.append('  <path d="%s" stroke="%s" stroke-width="%s" fill="none" stroke-linecap="butt"/>' % (d, col, f(w)))

    rail("M%s 5 L 61 5 M5 %s L 5 61" % (f(k + 8), f(k + 8)), 5.4, STONE_X)
    rail("M%s 5 L 61 5 M5 %s L 5 61" % (f(k + 8), f(k + 8)), 3.0, "url(#g)")
    rail("M%s 10.5 L 52 10.5 M10.5 %s L 10.5 52" % (f(k + 11), f(k + 11)), 1.0, GOLD_D)
    for (x, y) in [(61, 5), (5, 61)]:
        s.append('  <path d="M%s %s L %s %s L %s %s L %s %s Z" fill="url(#g)" stroke="%s" stroke-width="0.8"/>' % (
            f(x - 3), f(y), f(x), f(y - 3), f(x + 3), f(y), f(x), f(y + 3), STONE_X))
    for (x, y) in [(36, 5), (5, 36)]:
        s.append('  <circle cx="%s" cy="%s" r="2.2" fill="%s" stroke="%s" stroke-width="0.7"/>' % (f(x), f(y), GOLD_L,
                                                                                               STONE_X))
    s.append('  <circle cx="%s" cy="%s" r="11" stroke="%s" stroke-width="3.4" fill="none"/>' % (f(k), f(k), STONE_X))
    s.append('  <circle cx="%s" cy="%s" r="11" stroke="url(#g)" stroke-width="1.6" fill="none" '
             'stroke-dasharray="11.5 5.8" stroke-dashoffset="3"/>' % (f(k), f(k)))
    s.append('  <path d="M%s %s L %s %s L %s %s L %s %s Z" fill="%s" stroke="url(#g)" stroke-width="2.2"/>' % (
        f(k), f(k - 8.5), f(k + 8.5), f(k), f(k), f(k + 8.5), f(k - 8.5), f(k), STONE_L))
    s.append('  <path d="M%s %s L %s %s L %s %s L %s %s Z" fill="url(#g)" stroke="%s" stroke-width="0.6"/>' % (
        f(k), f(k - 4), f(k + 4), f(k), f(k), f(k + 4), f(k - 4), f(k), STONE_X))
    s += ["</svg>", ""]
    return "\n".join(s)


def _cap(cx, cy, w, h, up=True):
    """A diamond knot cap centred at (cx, cy), w x h, its point up (or down)."""
    t = -1 if up else 1
    outer = "M%s %s L %s %s L %s %s L %s %s Z" % (f(cx), f(cy + t * h / 2), f(cx + w / 2), f(cy), f(cx), f(cy - t * h / 2),
                                                 f(cx - w / 2), f(cy))
    inner = "M%s %s L %s %s L %s %s L %s %s Z" % (f(cx), f(cy + t * h * 0.32), f(cx + w * 0.3), f(cy), f(cx),
                                                 f(cy - t * h * 0.32), f(cx - w * 0.3), f(cy))
    core = "M%s %s L %s %s L %s %s L %s %s Z" % (f(cx), f(cy + t * h * 0.13), f(cx + w * 0.12), f(cy), f(cx),
                                                f(cy - t * h * 0.13), f(cx - w * 0.12), f(cy))
    return ['  <path d="%s" fill="%s" stroke="%s" stroke-width="5"/>' % (outer, STONE_X, STONE_X),
            '  <path d="%s" fill="%s" stroke="url(#g)" stroke-width="2.6"/>' % (outer, STONE_L),
            '  <path d="%s" fill="none" stroke="%s" stroke-width="1.2"/>' % (inner, GOLD_D),
            '  <path d="%s" fill="url(#g)" stroke="none"/>' % core]


def rail_frame(w=80, h=600):
    s = [head_svg(w * 2, h * 2, w, h, ' stroke="none"'),
         '  <defs>%s<linearGradient id="p" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/>'
         '<stop offset="0.5" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient></defs>' % (
             GOLD_GRAD, STONE_X, STONE_L, STONE_X)]
    x0, x1, y0, y1 = 14, w - 14, 30, h - 30
    s.append('  <rect x="%s" y="%s" width="%s" height="%s" rx="5" fill="url(#p)" fill-opacity="0.9" stroke="%s" '
             'stroke-width="5"/>' % (f(x0), f(y0), f(x1 - x0), f(y1 - y0), STONE_X))
    s.append('  <rect x="%s" y="%s" width="%s" height="%s" rx="5" fill="none" stroke="url(#g)" stroke-width="2.6"/>' % (
        f(x0), f(y0), f(x1 - x0), f(y1 - y0)))
    s.append('  <rect x="%s" y="%s" width="%s" height="%s" rx="3" fill="none" stroke="%s" stroke-width="1"/>' % (
        f(x0 + 4.5), f(y0 + 4.5), f(x1 - x0 - 9), f(y1 - y0 - 9), GOLD_D))
    # the groove the trait chain runs down (the window draws the gold chain over it)
    s.append('  <path d="M%s %s L %s %s" stroke="%s" stroke-width="4" stroke-opacity="0.6"/>' % (
        f(w / 2), f(y0 + 26), f(w / 2), f(y1 - 26), STONE_X))
    # side studs at a third and two thirds
    for y in (y0 + (y1 - y0) / 3.0, y0 + (y1 - y0) * 2 / 3.0):
        for x in (x0, x1):
            s.append('  <path d="M%s %s L %s %s L %s %s L %s %s Z" fill="url(#g)" stroke="%s" stroke-width="0.8"/>' % (
                f(x - 3.5), f(y), f(x), f(y - 3.5), f(x + 3.5), f(y), f(x), f(y + 3.5), STONE_X))
    s += _cap(w / 2, y0 - 2, 40, 52, True) + _cap(w / 2, y1 + 2, 40, 52, False)
    s += ["</svg>", ""]
    return "\n".join(s)


def rail_cap():
    s = [head_svg(80, 104, 40, 52, ' stroke="none"'), "  <defs>%s</defs>" % GOLD_GRAD]
    s += _cap(20, 26, 36, 48, True)
    s += ["</svg>", ""]
    return "\n".join(s)


def padlock():
    return icon_svg(haloed([P("M20 30 L 20 20 C 20 6, 44 6, 44 20 L 44 30", M1),
                            P("M12 30 L 52 30 L 52 58 L 12 58 Z", M2, FILL),
                            P("M32 38 C 28 38, 28 44, 31 45 L 30 51 L 34 51 L 33 45 C 36 44, 36 38, 32 38 Z", 1.2,
                              'fill="#000" fill-opacity="0.55" stroke="#000" stroke-opacity="0.55"')], 3.0))


def choice_arrow():
    s = [head_svg(32, 48, 16, 24, ' stroke="none"'), "  <defs>%s</defs>" % GOLD_GRAD,
         '  <path d="M2 3 L 14 12 L 2 21 L 5 12 Z" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round"/>' % (
             STONE_X, STONE_X),
         '  <path d="M2 3 L 14 12 L 2 21 L 5 12 Z" fill="url(#g)" stroke="%s" stroke-width="0.8" '
         'stroke-linejoin="round"/>' % GOLD_D,
         '  <path d="M5 12 L 14 12" stroke="%s" stroke-width="0.7" stroke-opacity="0.7"/>' % STONE_X,
         "</svg>", ""]
    return "\n".join(s)


def rank_plate():
    s = [head_svg(88, 40, 44, 20, ' stroke="none"'), "  <defs>%s</defs>" % GOLD_GRAD,
         '  <rect x="1.5" y="1.5" width="41" height="17" rx="4" fill="%s" fill-opacity="0.92" stroke="%s" '
         'stroke-width="2.4"/>' % (STONE_X, STONE_X),
         '  <rect x="1.5" y="1.5" width="41" height="17" rx="4" fill="none" stroke="url(#g)" stroke-width="1.3"/>',
         '  <path d="M6 4.5 L 38 4.5" stroke="%s" stroke-width="0.6" stroke-opacity="0.5"/>' % GOLD_HI,
         "</svg>", ""]
    return "\n".join(s)


def toast_frame(w=320, h=64):
    s = [head_svg(w * 2, h * 2, w, h, ' stroke="none"'),
         '  <defs>%s<linearGradient id="p" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/>'
         '<stop offset="1" stop-color="%s"/></linearGradient><radialGradient id="gl" cx="0.5" cy="0.5" r="0.5">'
         '<stop offset="0" stop-color="%s" stop-opacity="0.55"/><stop offset="0.7" stop-color="%s" stop-opacity="0.18"/>'
         '<stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient></defs>' % (
             GOLD_GRAD, STONE_L, STONE_X, GOLD_L, GOLD_D, GOLD_D)]
    # the soft glow: a wide radial bloom and layered edges fading out
    s.append('  <ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="url(#gl)"/>' % (f(w / 2), f(h / 2), f(w / 2), f(h / 2)))
    for k, a in [(7, 0.08), (5, 0.12), (3, 0.18)]:
        s.append('  <rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="none" stroke="%s" stroke-width="2" '
                 'stroke-opacity="%s"/>' % (f(14 - k), f(10 - k), f(w - 28 + 2 * k), f(h - 20 + 2 * k), f(4 + k), GOLD_L,
                                            f(a)))
    s.append('  <rect x="14" y="10" width="%s" height="%s" rx="4" fill="url(#p)" fill-opacity="0.94"/>' % (f(w - 28),
                                                                                                    f(h - 20)))
    s.append('  <rect x="14" y="10" width="%s" height="%s" rx="4" fill="none" stroke="url(#g)" stroke-width="2"/>' % (
        f(w - 28), f(h - 20)))
    s.append('  <rect x="17.5" y="13.5" width="%s" height="%s" rx="2.5" fill="none" stroke="%s" stroke-width="0.8"/>' % (
        f(w - 35), f(h - 27), GOLD_D))
    # the icon socket at the left: a square of 34 with a gold frame
    s.append('  <rect x="21" y="15" width="34" height="34" rx="2" fill="%s" stroke="url(#g)" stroke-width="1.6"/>' % STONE_X)
    # diamond knots at the left and right edge middles
    for x in (14, w - 14):
        y = h / 2
        s.append('  <path d="M%s %s L %s %s L %s %s L %s %s Z" fill="url(#g)" stroke="%s" stroke-width="0.8"/>' % (
            f(x - 4), f(y), f(x), f(y - 5), f(x + 4), f(y), f(x), f(y + 5), STONE_X))
    s += ["</svg>", ""]
    return "\n".join(s)


# ======================================================================================================= kind marks
def _fork():
    return [P("M32 60 L 32 36", M1), P("M32 36 C 32 26, 22 22, 14 14", M1), P("M32 36 C 32 26, 42 22, 50 14", M1),
            head((12, 12), (20, 20), 9, M2), head((52, 12), (44, 20), 9, M2)]


def _star(cx=32, cy=33, r0=28, r1=12, n=5):
    pts = []
    for k in range(n * 2):
        a = math.radians(-90 + k * 180.0 / n)
        r = r0 if k % 2 == 0 else r1
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def _spark(cx, cy, r0, r1):
    pts = []
    for k in range(8):
        a = math.radians(-90 + k * 45)
        r = r0 if k % 2 == 0 else r1
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def _hex(cx, cy, r, rot=0.0):
    return [(cx + math.cos(math.radians(rot + 60 * k)) * r, cy + math.sin(math.radians(rot + 60 * k)) * r) for k in range(6)]


KINDS = {
    "variation": ("Twist: a path forking", lambda: _fork()),
    "mastery": ("Technique: a star", lambda: [poly(_star(), M2)]),
    "new_skill": ("New skill: a spark", lambda: [poly(_spark(28, 34, 26, 7), M2), poly(_spark(52, 12, 9, 2.6), S2)]),
    "synergy": ("Synergy: two linked rings", lambda: [circle(22, 32, 15, M1), circle(42, 32, 15, M1)]),
    "skill_set": ("Skill set: a hexagon", lambda: [poly(_hex(32, 32, 27, 30), M1, False), poly(_hex(32, 32, 11, 30), M2)]),
    "passive": ("Passive: a ringed dot", lambda: [circle(32, 32, 24, M1), circle(32, 32, 9, M2, True)]),
    "world_only": ("World art: a peak", lambda: [poly([(4, 56), (24, 16), (32, 28), (40, 20), (60, 56)], M2),
                                                 P("M18 28 L 24 34 L 28 28", 2.4, 'stroke="#000" stroke-opacity="0.45"')]),
}


# ======================================================================================================== set marks
def _puff(cx, cy, s, w=M2, fill=False):
    k = [(-14, 4), (-15, -3, -11, -9, -6, -7), (-5, -14, 6, -14, 6, -8), (11, -11, 16, -5, 13, 0), (17, 4, 13, 9, 8, 7),
         (4, 11, -4, 11, -6, 7), (-11, 10, -16, 8, -14, 4)]
    d = "M%s %s" % (f(cx + k[0][0] * s), f(cy + k[0][1] * s))
    for c in k[1:]:
        d += " C %s %s, %s %s, %s %s" % (f(cx + c[0] * s), f(cy + c[1] * s), f(cx + c[2] * s), f(cy + c[3] * s),
                                         f(cx + c[4] * s), f(cy + c[5] * s))
    return P(d + " Z", w, FILL if fill else "")


SETS = {
    "sulphur": ("Sulphur: a puff rising from a vent", lambda: [
        _puff(31, 40, 1.15, M2), _puff(39, 19, 0.72, M2), _puff(27, 6, 0.36, S2),
        P("M14 60 L 24 56 L 32 60 L 40 56 L 50 60", M2)]),
    "mud": ("Mud: ringed ripples round a clod", lambda: [
        P("M3 40 C 3 26, 61 26, 61 40 C 61 54, 3 54, 3 40 Z", M2),
        P("M14 40 C 14 33, 50 33, 50 40 C 50 47, 14 47, 14 40 Z", S2),
        poly([(24, 24), (28, 14), (37, 12), (42, 20), (38, 28), (28, 29)], M2)]),
    "magma": ("Magma: a cracked seam glowing in a slab", lambda: [
        P("M5 20 L 59 20 L 59 50 L 5 50 Z", M2),
        P("M5 34 L 16 30 L 24 38 L 34 28 L 44 36 L 52 30 L 59 33", M1),
        line([(24, 38), (22, 46)], S2), line([(34, 28), (36, 22)], S2), line([(44, 36), (47, 44)], S2)]),
    "frostwind": ("Frostwind: a jagged crystal", lambda: [
        poly([(30, 4), (40, 18), (38, 46), (28, 60), (20, 44), (22, 16)], M2),
        P("M30 6 L 30 58", 2.4, 'stroke="#000" stroke-opacity="0.45"'),
        poly([(46, 24), (54, 32), (52, 52), (46, 58), (42, 50), (42, 30)], S2)]),
}


# ===================================================================================================== style glyphs
def _sole(cx, cy, rot=0.0, w=S2, scale=1.0):
    pts = [(-1, -10), (6, -10), (6, 1), (3, 9), (1, 13), (-6, 12), (-5, 4), (-5, -3), (-7, -10), (-1, -10)]
    a = math.radians(rot)
    q = [(cx + (x * math.cos(a) - y * math.sin(a)) * scale, cy + (x * math.sin(a) + y * math.cos(a)) * scale)
         for x, y in pts]
    d = "M%s %s C %s %s, %s %s, %s %s C %s %s, %s %s, %s %s C %s %s, %s %s, %s %s Z" % tuple(f(v) for p in q for v in p)
    return P(d, w, FILL)


def _foot(x, y, rot=0.0, k=1.0, w=S2):
    """A bare foot seen from the side, its ankle at (x, y), the toes pointing along `rot` degrees (0: right), filled."""
    pts = [(-4, -9), (-5, -2), (-7, 3), (-6, 7), (2, 8), (12, 7), (17, 5), (17, 2), (12, 0), (5, -2), (3, -9)]
    a = math.radians(rot)
    q = [(x + (px * math.cos(a) - py * math.sin(a)) * k, y + (px * math.sin(a) + py * math.cos(a)) * k) for px, py in pts]
    return poly(q, w)


def _burst(cx, cy, r0, r1, n=8, w=S2, a0=0.0):
    out = []
    for k in range(n):
        a = math.radians(a0 + k * 360.0 / n)
        rr = r1 if k % 2 == 0 else r1 * 0.7
        out.append(line([(cx + math.cos(a) * r0, cy + math.sin(a) * r0), (cx + math.cos(a) * rr, cy + math.sin(a) * rr)], w))
    return out


def _claw(x, w):
    """One tapered claw slash, top right to bottom left, filled."""
    return P("M%s 6 C %s 20, %s 38, %s 58 C %s 40, %s 22, %s 6 Z" % (f(x + 14), f(x + 8), f(x - 2), f(x - 10), f(x - 2 + w),
                                                                      f(x + 8 + w), f(x + 14)), S3, FILL)


G1 = 4.2   # the glyphs' main line (a little bolder than the icons': they are read at 24-46 px)


def style_hung_gar():
    """Hung Gar: a tiger's claw, three tapered slashes."""
    return [_claw(18, 5), _claw(32, 6), _claw(46, 5)]


def style_karate():
    """Karate: the stacked boards broken through at one blow."""
    out = []
    for y, t in ((26, 0.0), (42, 2.0)):
        out.append(poly([(4, y), (29, y + 3 + t), (27, y + 10 + t), (4, y + 8)], S2))
        out.append(poly([(60, y), (35, y + 3 + t), (37, y + 10 + t), (60, y + 8)], S2))
    out += [line([(18, 58), (46, 58)], S2)] + _burst(32, 14, 3, 11, 8, S2, -90)
    return out


def style_sumo():
    """Sumo: the great twisted rope, its paper strips hanging."""
    out = [P("M4 18 C 20 9, 44 9, 60 18 L 60 28 C 44 20, 20 20, 4 28 Z", S2, FILL)]
    for x in (12, 22, 32, 42, 52):
        out.append(line([(x - 3, 14 + abs(x - 32) * 0.12), (x + 3, 26 - abs(x - 32) * 0.05)], 1.6,
                        'stroke="#000" stroke-opacity="0.4"'))
    for x in (18, 32, 46):
        out.append(line([(x, 26), (x + 5, 33), (x, 40), (x + 5, 47), (x, 54)], S2))
    return out


def style_wrestling():
    """Wrestling: the slam, straight down, the deck cracking under it."""
    return [line([(32, 4), (32, 34)], G1 + 1.2), head((32, 39), (32, 29), 10, G1 + 1.2),
            line([(4, 48), (60, 48)], G1), line([(24, 48), (20, 56), (24, 60)], S2), line([(40, 48), (45, 55), (42, 60)], S2)] + \
        _burst(32, 46, 8, 16, 6, S2, 180)[0:5]


def style_tai_chi():
    """Tai Chi: a circle and the slow S of push hands through it."""
    return [circle(32, 32, 26, G1), P("M32 6 C 46 12, 46 26, 32 32 C 18 38, 18 52, 32 58", S2)]


def style_aikido():
    """Aikido: a straight attack taken into a circle and turned away."""
    a, pts = arc(34, 34, 18, -90, 200, G1, 36)
    return [line([(2, 16), (34, 16)], G1), a, head(pts[-1], pts[-3], 7, G1), circle(34, 34, 3.2, S2, True)]


def style_judo():
    """Judo: thrown in an arc over the hip."""
    return [P("M8 46 C 10 12, 54 12, 56 42", G1), head((56.5, 47), (56, 37), 8, G1),
            P("M22 54 C 22 40, 42 40, 42 54 Z", S2, FILL), line([(4, 56), (60, 56)], S2)]


def style_wing_chun():
    """Wing Chun: the wooden dummy, its post and its three arms."""
    return [line([(26, 21), (9, 13)], G1 + 1.6), line([(38, 21), (55, 13)], G1 + 1.6), line([(38, 34), (57, 34)], G1 + 1.6),
            P("M25 58 L 25 12 C 25 3, 39 3, 39 12 L 39 58 Z", S2, FILL),
            P("M32 46 L 46 51 L 46 58", G1), line([(14, 59), (50, 59)], S2)]


def style_northern_shaolin():
    """Northern Shaolin: a long flying side kick, the knee bent then the leg thrown out long, the sole to the front."""
    return [line([(8, 58), (20, 40)], G1 + 1.2), line([(20, 40), (44, 34)], G1 + 1.2), circle(20, 40, 2.6, S2, True),
            _foot(46, 34, -90, 1.0), line([(4, 30), (18, 28)], S3), line([(8, 20), (26, 20)], S3),
            line([(28, 48), (42, 45)], S3)]


def style_boxing():
    """Boxing: a wrapped glove."""
    return [P("M20 30 C 18 14, 30 6, 42 8 C 54 10, 58 22, 54 34 C 52 42, 46 46, 38 46 L 26 46 C 22 46, 20 42, 20 38 Z",
              S2, FILL),
            P("M20 36 C 12 36, 9 27, 16 24 C 19 23, 21 25, 21 28", S2),
            P("M30 30 C 34 26, 42 26, 46 30", 1.6, 'stroke="#000" stroke-opacity="0.4"'),
            P("M24 46 L 24 58 L 46 58 L 46 46", G1), line([(24, 52), (46, 52)], S3)]


def style_muay_thai():
    """Muay Thai: the elbow, a hard bend striking."""
    return [P("M8 54 L 30 24 L 56 36", G1 + 2.2), circle(30, 24, 4.6, S2, True)] + _burst(30, 12, 5, 13, 6, S2, -90)


def style_kickboxing():
    """Kickboxing: a punch, then the round kick after it."""
    return [line([(6, 16), (40, 16)], G1), head((44, 16), (34, 16), 7, G1),
            P("M8 54 C 14 30, 40 26, 52 38", G1), head((54, 42), (50, 32), 7, G1)]


def style_baguazhang():
    """Baguazhang: the circle walked as an octagon, a spiral in it."""
    return [poly(_hex8(32, 32, 27), G1, False), spiral(32, 32, 2, 15, 1.4, math.radians(-90), 40, S2)]


def _hex8(cx, cy, r):
    return [(cx + math.cos(math.radians(22.5 + 45 * k)) * r, cy + math.sin(math.radians(22.5 + 45 * k)) * r) for k in range(8)]


def style_capoeira():
    """Capoeira: the half-moon kick, a crescent swung round."""
    a, pts = arc(30, 36, 23, 120, 222, S2, 30)
    return [P("M30 6 C 52 6, 62 30, 48 48 C 52 30, 46 14, 30 6 Z", S2, FILL), a, head(pts[-1], pts[-3], 6, S2)]


def style_taekwondo():
    """Taekwondo: a spinning kick, the turn ending in the foot high up."""
    a, pts = arc(26, 40, 17, 100, 385, G1, 40)
    return [a, head(pts[-1], pts[-3], 7, G1), line([(34, 34), (44, 20)], G1 + 1.0), _foot(45, 18, -35, 0.95),
            line([(10, 61), (40, 61)], S3)]


def style_drunken_boxing():
    """Drunken Boxing: the gourd, tipped."""
    g = ("M30 6 L 36 6 L 36 12 C 44 14, 44 26, 38 28 C 52 32, 54 54, 34 58 C 14 60, 14 34, 28 28 C 22 26, 22 14, 30 12 Z")
    return ['  <g transform="rotate(18 32 32)">', P(g, S2, FILL), line([(28, 9), (38, 9)], 2.0, 'stroke="#000" stroke-opacity="0.45"'),
            P("M36 18 C 46 16, 52 22, 50 30", S3), "  </g>"]


def style_jeet_kune_do():
    """Jeet Kune Do: the straight lead meeting the attack and stopping it."""
    return [line([(4, 32), (40, 32)], G1 + 0.8), head((44, 32), (34, 32), 8, G1), line([(50, 10), (50, 54)], G1 + 0.8)] + \
        _burst(50, 32, 6, 12, 4, S3, 45)


STYLE_DRAW = {k[0]: globals()["style_" + k[0]] for el in ELEMENTS for k in STYLES[el]}
STYLE_DRAW[ANY_STYLE[0]] = style_jeet_kune_do


# ============================================================================================================ emblems
def _inner(svg_text):
    """The drawing inside an SVG file's <svg> (one of the move icons, on the same 64 grid)."""
    body = svg_text.split(">", 1)[1]
    return body.rsplit("</svg>", 1)[0].strip("\n")


def emblem(el, style):
    """The class emblem: a medallion ring, the style's glyph, the element's plate mark in a badge at its foot."""
    mark = _inner(open(os.path.join(ROOT, "assets", "ui", "icons", "spell_mark__%s.svg" % el)).read())
    glyph = "\n".join(STYLE_DRAW[style]())
    parts = [head_svg(128, 128, 64, 64),
             circle(32, 32, 30, S2), circle(32, 32, 27, 1.0, False, 'stroke-opacity="0.5"'),
             '  <g transform="translate(12.2 7.4) scale(0.62)">', glyph, "  </g>",
             '  <circle cx="50" cy="50" r="12.5" fill="#000" fill-opacity="0.55" stroke="none"/>',
             circle(50, 50, 11, 1.8),
             '  <g transform="translate(42 42) scale(0.25)">', mark, "  </g>",
             "</svg>", ""]
    return "\n".join(parts)


# ========================================================================================================= the nodes
def _nodes():
    d = json.load(open(os.path.join(ROOT, "data", "sway", "skill_tree.json")))
    found = {}

    def walk(o):
        if isinstance(o, dict):
            if isinstance(o.get("id"), str) and "kind" in o and "." in o["id"]:
                found.setdefault(o["id"], o)
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    walk(d)
    return found


def node_icon(n, icons):
    """A node's picture (res path): its own (NODE_PICTURE), its move-mode's (BendStrip.icon_path's order: the mode's
    file, then the move's), or an alias's."""
    nid = n["id"]
    if nid in NODE_PICTURE:
        return ICON_RES + "spell_%s.svg" % NODE_PICTURE[nid]
    move, mode = n.get("extends_move", ""), n.get("mode", "")
    if (move, mode) in NODE_ALIAS:
        return ICON_RES + "spell_%s.svg" % NODE_ALIAS[(move, mode)]
    for name in ("spell_%s__%s.svg" % (move, mode if mode else move), "spell_%s.svg" % move):
        if name in icons:
            return ICON_RES + name
    return ""


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets", "ui", "advancement")
    os.makedirs(out, exist_ok=True)
    files = {}

    def write(name, body):
        ET.fromstring(body)                 # (well-formed, or stop here)
        with open(os.path.join(out, name), "w") as fh:
            fh.write(body)
        files[name] = RES + name

    write("frame_corner.svg", frame_corner())
    write("rail_frame.svg", rail_frame())
    write("rail_cap.svg", rail_cap())
    write("padlock.svg", padlock())
    write("choice_arrow.svg", choice_arrow())
    write("rank_plate.svg", rank_plate())
    write("toast_frame.svg", toast_frame())
    kinds = {}
    for k, (what, fn) in KINDS.items():
        write("kind_%s.svg" % k, icon_svg(haloed(fn())))
        kinds[k] = RES + "kind_%s.svg" % k
    sets = {}
    for k, (what, fn) in SETS.items():
        write("set_%s.svg" % k, icon_svg(haloed(fn())))
        sets[k] = {"mark": RES + "set_%s.svg" % k, "tint": SET_TINTS[k], "element": SET_ELEMENT[k],
                   "node_icon": ICON_RES + "spell_set__%s.svg" % k}
    styles = {}
    seen = {}
    for el in ELEMENTS + ["any"]:
        for sid, label in (STYLES[el] if el != "any" else [ANY_STYLE]):
            body = icon_svg(STYLE_DRAW[sid]())
            if body in seen:
                raise SystemExit("two styles draw the same glyph: %s and %s" % (seen[body], sid))
            seen[body] = sid
            write("style_%s.svg" % sid, body)
            styles[sid] = {"glyph": RES + "style_%s.svg" % sid, "element": el, "label": label}
    emblems = {}
    for el in ELEMENTS:
        emblems[el] = {}
        for sid, _ in STYLES[el] + [ANY_STYLE]:
            write("emblem_%s_%s.svg" % (el, sid), emblem(el, sid))
            emblems[el][sid] = RES + "emblem_%s_%s.svg" % (el, sid)
    icons = set(os.listdir(os.path.join(ROOT, "assets", "ui", "icons")))
    nodes = _nodes()
    node_icons = {nid: node_icon(n, icons) for nid, n in sorted(nodes.items())}
    missing = [nid for nid, p in node_icons.items() if not p]
    if missing:
        raise SystemExit("nodes with no picture: %s (tools/ui/move_icons.py)" % ", ".join(missing))
    manifest = {
        "format": "tidebreak-advancement-art", "version": 1,
        "_doc": "Written by tools/ui/advancement_art.py: the Character Advancement window's art (res paths). "
                "backdrops: tools/menu/paint_advancement.gd. node_icons: every data/sway/skill_tree.json node's picture "
                "(white line art, tint it); passive_roots: the element passive at the root of the passive line; "
                "kinds: the corner mark per node kind (enhance has none); sets: each skill set's mark, tint and node "
                "picture; styles and emblems: per fighting style (emblems per element + style, the 20 classes).",
        "backdrops": {el: RES + "backdrop_%s.jpg" % el for el in ELEMENTS},
        "frame": {k: files[k + ".svg"] for k in ["frame_corner", "rail_frame", "rail_cap", "padlock", "choice_arrow",
                                                 "rank_plate", "toast_frame"]},
        "kinds": kinds, "sets": sets, "styles": styles, "emblems": emblems,
        "passive_roots": {el: ICON_RES + "spell_%s.svg" % PASSIVE_ROOT[el] for el in ELEMENTS},
        "node_icons": node_icons, "theme": THEME,
        "drawn_for_window": sorted(ICON_RES + "spell_%s.svg" % n for n in
                                   MODE_PICTURES + list(NODE_PICTURE.values()) + list(PASSIVE_ROOT.values())),
    }
    with open(os.path.join(out, "art.json"), "w") as fh:
        json.dump(manifest, fh, indent=1)
        fh.write("\n")
    print("advancement_art: %d files, %d node icons -> %s" % (len(files) + 1, len(node_icons), os.path.abspath(out)))


if __name__ == "__main__":
    main()
