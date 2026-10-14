"""The Vạn Thủy lock-district kit (VANTHUY; places_se.md page 1, build order 1), authored procedurally in Blender in
the World of Warcraft Classic spirit of the style guide: chunky, exaggerated, roofs 45-55% of a building's height with
fat upturned eaves and curled gilt ridge ends, towers 2-3x real, ropes and piles 2x, lanterns and banners 1.3-1.5x.
Our own designs after the owner's Vạn Thủy sheet (shape, colour and mood only; no sheet pixels, no Hán, no roundels or
seal: our own court and district marks, marks_vt.py). Run headless through the shared lock wrapper:

    zsh tools/thuyvan/bin/blender_run.sh -b -P tools/thuyvan_art/vanthuy/vt_kit.py -- \
        --out assets/thuyvan/vanthuy [--blend X.blend] [--only piece,piece]

Paint the textures first (paint_vanthuy.py). Writes one GLB per piece (+Y up; Blender -Y = Godot +Z = the front;
origin on the ground, or on the water line for pieces standing in water), <piece>_lod1.glb where the budget has an LOD1,
and manifest.json (triangles per LOD against places_se.md's budgets, material keys, sizes, anchors, colliders).

The lock_* pieces are the FIRST BLOCK-IN pieces of the ONE shared lock kit planned for Phase 3 M2's Fifth Lock (none
existed on 2026-10-06), at the Fifth Lock's own scale; Vạn Thủy places them scaled x1.6 (gate towers 46 m, leaves 22 m,
winch wheels 7 m). Phase 3 M2 owns and finishes them; nobody builds a second lock kit.
"""

import argparse
import json
import math
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "village"))
import vtkit  # noqa: E402
from vtkit import Builder, rot_x, rot_y, rot_z  # noqa: E402
import village_kit as vk  # noqa: E402  (roof(), wall(), cloth_sheet(), lantern_round(): the village's shape idiom)

VT_SCALE = 1.6          # Vạn Thủy's lock pieces = the shared lock kit x1.6 (places_se.md 1 kit list)


# ================================================================================================ shared shapes
def block(b, x0, x1, y0, y1, z0, z1, key, batter=0.0, chamfer=0.15, top_key=None, bottom=False):
    """A stone mass with chamfered vertical edges (the big-edge bevel) and an optional batter (top inset per side)."""
    c = chamfer
    def ring(z, ins):
        X0, X1, Y0, Y1 = x0 + ins, x1 - ins, y0 + ins, y1 - ins
        return [np.array(p) for p in ((X0 + c, Y0, z), (X1 - c, Y0, z), (X1, Y0 + c, z), (X1, Y1 - c, z),
                                       (X1 - c, Y1, z), (X0 + c, Y1, z), (X0, Y1 - c, z), (X0, Y0 + c, z))]
    lo, hi = ring(z0, 0.0), ring(z1, batter)
    for i in range(8):
        j = (i + 1) % 8
        b.face([lo[i], lo[j], hi[j], hi[i]], key)
    b.face(hi, top_key or key)
    if bottom:
        b.face(lo[::-1], key)


def coping(b, x0, x1, y0, y1, z, key="paving", h=0.5, over=0.25):
    block(b, x0 - over, x1 + over, y0 - over, y1 + over, z, z + h, key, chamfer=0.12)


def troof(b, c, A, B, H, up, flare, thick, p=1.6, gilt=True, ns=12, nt=6, ridge_r=None, top="tile", hooks=True,
          curls=True, under="timber"):
    """The city roof: the village hip roof (fat rim, upturned and flared eaves) with gilt curled ridge ends and gilt-
    tipped corner hooks flicking up from every eave corner (the WoW-Classic exaggeration: read from 1 km)."""
    rr = ridge_r or (0.12 + 0.03 * B)
    c = np.asarray(c, float)
    vk.roof(b, c, A, B, H, top=top, under=under, p=p, upturn=up, flare=flare, thick=thick, ridge=True, ridge_r=rr,
            hips=True, curls=False, finial=False, ns=ns, nt=nt)
    k = max(0.6, B / 5.0)
    rl = max(A - B, 0.0)
    gk = "gilt" if gilt else top
    if curls and rl > 0.05:
        for sx in (-1, 1):
            pts, rad = [], []
            for t in np.linspace(0.0, 1.0, 7):
                a = t * math.pi * 0.6          # a flick up and out, never a closed loop or a pair of horns
                pts.append(c + [sx * (rl + 0.1 + 0.95 * k * math.sin(a)), 0.0, H + rr + 0.55 * k * (1 - math.cos(a))])
                rad.append(rr * 1.35 * (1.0 - 0.55 * t))
            b.tube(pts, rad, 7, gk)
    if hooks:
        for sx in (-1, 1):
            for sy in (-1, 1):
                base = c + [sx * (A + flare), sy * (B + flare), up]
                d = np.array([sx, sy, 0.0]) / math.sqrt(2)
                path = [base - d * 0.3 * k, base + d * 0.25 * k + [0, 0, 0.45 * k], base + d * 0.4 * k + [0, 0, 1.0 * k],
                        base + d * 0.2 * k + [0, 0, 1.35 * k]]
                b.tube(path, [rr * 1.1, rr * 0.95, rr * 0.75, rr * 0.5], 6, top)
                if gilt:
                    b.pebble(path[-1] + [0, 0, rr * 0.3], (rr * 0.9, rr * 0.9, rr * 0.9), "gilt", segs=6, rings=4)
    return c[2] + H


def columns_ring(b, cx, cy, z0, w, d, h, r, step, key="lacquer", segs=6, skip_front=None, front_only=False):
    """Columns round a w x d rectangle (or along its front only), about `step` apart; skip_front: an x span left open
    on the front (a door)."""
    pts = []
    for (ax, ay, bx, by) in ((-w / 2, -d / 2, w / 2, -d / 2), (w / 2, -d / 2, w / 2, d / 2),
                             (w / 2, d / 2, -w / 2, d / 2), (-w / 2, d / 2, -w / 2, -d / 2)):
        L = math.hypot(bx - ax, by - ay)
        n = max(1, int(round(L / step)))
        for i in range(n):
            pts.append((ax + (bx - ax) * i / n, ay + (by - ay) * i / n))
    if front_only:
        n = max(1, int(round(w / step)))
        pts = [(-w / 2 + w * i / n, -d / 2) for i in range(n + 1)]
    for (x, y) in pts:
        if skip_front and y < -d / 2 + 0.01 and skip_front[0] < x < skip_front[1]:
            continue
        b.lathe([(r * 1.3, 0.0), (r, 0.45), (r, h)], segs, key, base=(cx + x, cy + y, z0))


def beam_ring(b, cx, cy, z, w, d, bw, bh, key="timber"):
    for (ax, ay, bx, by) in ((-w / 2, -d / 2, w / 2, -d / 2), (w / 2, -d / 2, w / 2, d / 2),
                             (w / 2, d / 2, -w / 2, d / 2), (-w / 2, d / 2, -w / 2, -d / 2)):
        b.beam((cx + ax * 1.0 - (bw / 2 if ax == bx else 0) * 0, cy + ay, z), (cx + bx, cy + by, z), bw, bh, key)


def railing(b, cx, cy, z, w, d, h=1.1, step=1.8, key="lacquer", post_w=0.16, open_front=None):
    """A gallery rail round w x d at deck level z: posts every `step`, a top rail and a mid rail."""
    for (ax, ay, bx, by) in ((-w / 2, -d / 2, w / 2, -d / 2), (w / 2, -d / 2, w / 2, d / 2),
                             (w / 2, d / 2, -w / 2, d / 2), (-w / 2, d / 2, -w / 2, -d / 2)):
        L = math.hypot(bx - ax, by - ay)
        n = max(1, int(round(L / step)))
        front = ay == by == -d / 2
        for i in range(n + 1):
            x, y = ax + (bx - ax) * i / n, ay + (by - ay) * i / n
            if front and open_front and open_front[0] < x < open_front[1]:
                continue
            b.box((cx + x, cy + y, z + h / 2), (post_w, post_w, h), key, grain=2)
        if front and open_front:
            for (x0, x1) in ((ax, open_front[0]), (open_front[1], bx)):
                for zz in (h, h * 0.5):
                    b.beam((cx + x0, cy + ay, z + zz), (cx + x1, cy + ay, z + zz), 0.12, 0.12, key)
        else:
            for zz in (h, h * 0.5):
                b.beam((cx + ax, cy + ay, z + zz), (cx + bx, cy + by, z + zz), 0.12, 0.12, key)


def storey(b, cx, cy, z0, w, d, h, wall="lacquer", col="lacquer", r=None, step=3.0, door=None, open_=False,
           band="timber", front_only=False):
    """One storey: a wall core inset behind a ring of columns, a beam band under the eaves; open_: columns only."""
    r = r or max(0.16, 0.03 * w)
    if not open_:
        ins = r * 2.2
        block(b, cx - w / 2 + ins, cx + w / 2 - ins, cy - d / 2 + ins, cy + d / 2 - ins, z0, z0 + h, wall, chamfer=0.05)
        if door:
            dw, dh = door
            b.box((cx, cy - d / 2 + ins - 0.06, z0 + dh / 2), (dw, 0.14, dh), "timber", grain=2)
            b.box((cx, cy - d / 2 + ins - 0.12, z0 + dh + 0.15), (dw + 0.6, 0.2, 0.3), band, grain=0)
    columns_ring(b, cx, cy, z0, w, d, h, r, step, col, front_only=front_only)
    beam_ring(b, cx, cy, z0 + h - 0.25 * max(1.0, w / 10), w, d, r * 1.6, 0.5 * max(1.0, w / 10), band)


def lantern(b, c, r=0.42, h=0.8, cord=0.6):
    """The city's paper lantern (1.3x real), lean enough to hang dozens on a tower: a six-sided round paper body,
    timber caps, a madder tassel (the village lantern_round at a third of its triangles)."""
    c = np.asarray(c, float)
    b.lathe([(r * 0.55, -h / 2), (r, -h / 4), (r * 1.02, h / 8), (r * 0.9, h * 0.35), (r * 0.55, h / 2)], 6, "paper",
            base=c, cap_top=False, cap_bottom=False)
    b.lathe([(r * 0.6, -h / 2 - 0.07), (r * 0.6, -h / 2 + 0.02)], 6, "timber", base=c)
    b.lathe([(r * 0.6, h / 2 - 0.02), (r * 0.48, h / 2 + 0.08)], 6, "timber", base=c)
    b.tube([c + [0, 0, -h / 2 - 0.07], c + [0, 0, -h / 2 - 0.42]], [0.05, 0.015], 4, "cloth_madder", caps=False)
    if cord > 0:
        b.tube([c + [0, 0, h / 2 + 0.08], c + [0, 0, h / 2 + 0.08 + cord]], 0.015, 3, "rope", caps=False)


# ================================================================================================ the shared lock kit
def lock_chamber_wall(name="lock_chamber_wall", L=20.0, seed=201):
    """A chamber wall module (Fifth Lock scale): battered ashlar face toward the chamber (-Y), paving coping, mooring
    rings and bollards, a recessed ladder; origin on the water line at the face's centre. Silt line in vertex colour."""
    b = Builder(name, seed)
    top = 6.5
    block(b, -L / 2, L / 2, -1.6, 10.0, -4.0, -1.0, "ashlar", chamfer=0.02)       # the battered foot
    block(b, -L / 2, L / 2, -1.0, 10.0, -1.0, top, "ashlar", chamfer=0.02)
    coping(b, -L / 2, L / 2, -1.25, 10.0, top, "paving", h=0.55, over=0.0)
    for x in (-L / 2 + 3.0, L / 2 - 3.0):           # bollards
        b.lathe([(0.32, 0), (0.28, 0.5), (0.36, 0.62), (0.2, 0.75)], 8, "iron", base=(x, 0.4, top + 0.55))
    for x in (-5.0, 5.0):                           # mooring rings in the face
        b.tube([(x + 0.35 * math.cos(a), -1.08, 1.6 + 0.35 * math.sin(a))
                for a in np.linspace(0, 2 * math.pi, 9)], 0.06, 4, "iron", caps=False)
    for zz in np.arange(-1.0, top, 0.35):           # the ladder's rungs in a recess
        y = -1.06
        b.beam((-0.4, y, zz), (0.4, y, zz), 0.05, 0.05, "iron")
    b.empty("anchor_mooring_a", (-5.0, -1.3, 1.6))
    b.empty("anchor_mooring_b", (5.0, -1.3, 1.6))
    b.collider("deck", [[(-L / 2, -1.25, top + 0.55), (L / 2, -1.25, top + 0.55), (L / 2, 10.0, top + 0.55),
                         (-L / 2, 10.0, top + 0.55)]])
    return b, top + 0.75, {"silt": 0.6}


def lock_gate_tower(name="lock_gate_tower", seed=202):
    """A gate tower (Fifth Lock scale, 29 m; Vạn Thủy x1.6 = 46 m): a battered ashlar shaft 9 m square with the gate
    plaque (our own court/gate mark, never the sheet's roundels), a timber gallery on brackets under double tiled eaves,
    a lantern at each gallery corner; origin on the water line at the shaft's centre. The winch wheel mounts at
    anchor_winch on the chamber face (-X here; mirror for the far tower)."""
    b = Builder(name, seed)
    W = 9.0
    block(b, -W / 2 - 0.8, W / 2 + 0.8, -W / 2 - 0.8, W / 2 + 0.8, -3.0, 1.2, "ashlar", chamfer=0.3)
    block(b, -W / 2, W / 2, -W / 2, W / 2, 1.2, 19.0, "ashlar", batter=0.6, chamfer=0.25)
    for zb in (6.5, 13.0):                          # string courses
        block(b, -W / 2 + 0.1, W / 2 - 0.1, -W / 2 + 0.1, W / 2 - 0.1, zb, zb + 0.45, "ashlar_new", chamfer=0.1)
    # the plaque on the front (-Y) face and the lacquer frame round it
    pw = 4.0
    b.face([(-pw / 2, -W / 2 + 0.25, 10.5), (pw / 2, -W / 2 + 0.25, 10.5), (pw / 2, -W / 2 + 0.25, 10.5 + pw),
            (-pw / 2, -W / 2 + 0.25, 10.5 + pw)], "gate_mark",
           uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
    for (x0, z0, x1, z1) in ((-pw / 2 - 0.2, 10.3, pw / 2 + 0.2, 10.55), (-pw / 2 - 0.2, 10.45 + pw, pw / 2 + 0.2, 10.7 + pw)):
        b.box(((x0 + x1) / 2, -W / 2 + 0.2, (z0 + z1) / 2), (x1 - x0, 0.3, z1 - z0), "lacquer", grain=0)
    # gallery deck on brackets, its rail, the gallery storey and the double eaves
    zg = 19.0
    for s in (-1, 1):
        for t in np.linspace(-W / 2 + 0.8, W / 2 - 0.8, 4):
            for (p0, p1) in (((t, s * (W / 2 - 0.4), zg - 2.2), (t, s * (W / 2 + 1.4), zg - 0.1)),
                             ((s * (W / 2 - 0.4), t, zg - 2.2), (s * (W / 2 + 1.4), t, zg - 0.1))):
                b.beam(p0, p1, 0.3, 0.35, "timber")
    b.box((0, 0, zg + 0.15), (W + 3.2, W + 3.2, 0.3), "plank", grain=0)
    railing(b, 0, 0, zg + 0.3, W + 3.0, W + 3.0, 1.15, 1.6, "lacquer", 0.18)
    storey(b, 0, 0, zg + 0.3, W - 0.6, W - 0.6, 3.6, wall="plaster", col="lacquer", r=0.28, step=2.8, door=(1.4, 2.4))
    troof(b, (0, 0, zg + 3.9), W / 2 + 2.6, W / 2 + 2.6, 2.6, 1.3, 0.8, 0.55, p=1.4, ns=10, nt=5)
    storey(b, 0, 0, zg + 5.4, W - 3.4, W - 3.4, 2.4, wall="lacquer", col="lacquer", r=0.22, step=2.4)
    zt = troof(b, (0, 0, zg + 7.8), W / 2 + 0.6, W / 2 + 0.6, 3.6, 1.0, 0.6, 0.5, p=1.25, ns=10, nt=5)
    b.lathe([(0.5, 0), (0.3, 0.4), (0.45, 0.9), (0.12, 1.6), (0.0, 2.2)], 8, "gilt", base=(0, 0, zt))
    for sx in (-1, 1):
        for sy in (-1, 1):
            lantern(b, (sx * (W / 2 + 1.3), sy * (W / 2 + 1.3), zg + 2.6), 0.45, 0.85, 0.5)
            b.empty("anchor_lantern_%s%s" % ("w" if sx < 0 else "e", "s" if sy < 0 else "n"),
                    (sx * (W / 2 + 1.3), sy * (W / 2 + 1.3), zg + 2.6))
    b.empty("anchor_winch", (-W / 2 + 0.3, 0.0, 9.0))
    b.empty("anchor_banner", (0.0, -W / 2 - 0.2, 17.5))
    b.collider("gallery", [[(-(W + 3.2) / 2, -(W + 3.2) / 2, zg + 0.3), ((W + 3.2) / 2, -(W + 3.2) / 2, zg + 0.3),
                            ((W + 3.2) / 2, (W + 3.2) / 2, zg + 0.3), (-(W + 3.2) / 2, (W + 3.2) / 2, zg + 0.3)]])
    return b, zt + 2.2, {"silt": 0.6}


def lock_gate_leaf_pair(name="lock_gate_leaf_pair", span=37.5, seed=203, open_=False):
    """The gate leaves (Fifth Lock scale: 14 m tall, the chamber 37.5 m; Vạn Thủy x1.6 = 22 m and 60 m): two iron-
    strapped dark timber leaves meeting in a shallow mitre pointing upstream (+Y), a plank catwalk with a rail on top;
    origin on the water line at the chamber's centre line."""
    b = Builder(name, seed)
    half = span / 2
    ang = math.radians(9.0)
    for s in (-1, 1):
        L = half / math.cos(ang)
        hinge = np.array([s * half, 0.0, 0.0])
        d = np.array([0.08 * -s, 1.0]) if open_ else np.array([-s * math.cos(ang), math.sin(ang)])
        d = d / np.linalg.norm(d)
        if s < 0:            # local +X from the hinge; local -Y is the downstream face
            org, yaw = hinge, math.atan2(d[1], d[0])
        else:                # mirrored: local +X from the tip back to the hinge keeps -Y downstream
            tip = hinge[:2] + L * d
            org, yaw = np.array([tip[0], tip[1], 0.0]), math.atan2(-d[1], -d[0])
        with b.at(org, yaw=yaw):
            # local frame: the leaf runs +X from its hinge
            b.box((L / 2, 0, 4.0), (L, 1.2, 14.0), "timber", grain=2)
            for zz in np.arange(-2.2, 11.0, 1.9):      # iron straps on the downstream face
                b.box((L / 2, -0.66, zz), (L - 0.2, 0.12, 0.38), "iron", grain=0)
            for xx in np.linspace(0.6, L - 0.6, 5):     # stiles
                b.box((xx, -0.7, 4.0), (0.45, 0.2, 14.0), "timber", grain=2)
            for xx in np.linspace(1.2, L - 1.2, 6):     # bronze bosses at the strap crossings (one row)
                b.pebble((xx, -0.8, 6.3), (0.22, 0.12, 0.22), "bronze", segs=6, rings=3)
            # the sluice port in the leaf's foot (a dark grated opening; the foam is a render/game card)
            b.box((L * 0.5, -0.67, -0.6), (2.6, 0.1, 1.8), "iron", grain=0)
            b.empty("anchor_sluice_%s" % ("w" if s < 0 else "e"), (L * 0.5, -0.9, -0.4))
            b.box((L / 2, 0, 11.15), (L, 2.2, 0.3), "plank", grain=0)
            for yy in (-1.05, 1.05):
                b.beam((0.0, yy, 12.3), (L, yy, 12.3), 0.12, 0.12, "timber")
                for xx in np.arange(0.0, L + 0.1, 2.0):
                    b.box((xx, yy, 11.75), (0.14, 0.14, 1.1), "timber", grain=2)
    if not open_:
        b.collider("catwalk", [[(-half, -1.1, 11.3), (half, -1.1, 11.3), (half, 1.1, 11.3), (-half, 1.1, 11.3)]])
    return b, 12.4, {"silt": 0.4}


def lock_winch_wheel(name="lock_winch_wheel", D=4.4, seed=204):
    """The winch wheel (Fifth Lock 4.4 m; Vạn Thủy x1.6 = 7 m, about 2x real): a spoked timber wheel with iron tyre and
    hand pegs, on an axle in two brackets, the chain run hanging to the leaf; the wheel turns about X (it stands in the
    YZ plane, against a wall face at -X... +X). Origin = the axle's wall end."""
    b = Builder(name, seed)
    R = D / 2
    cx = 1.2
    rim = [np.array([cx, R * math.cos(a), R * math.sin(a)]) for a in np.linspace(0, 2 * math.pi, 25)]
    b.tube(rim, 0.17, 6, "timber", caps=False)
    rim2 = [np.array([cx, (R + 0.12) * math.cos(a), (R + 0.12) * math.sin(a)]) for a in np.linspace(0, 2 * math.pi, 25)]
    b.tube(rim2, 0.08, 4, "iron", caps=False)
    for k in range(8):
        a = k * math.pi / 4
        b.beam((cx, 0.0, 0.0), (cx, R * math.cos(a), R * math.sin(a)), 0.2, 0.2, "timber", roll=0.0)
        b.beam((cx, (R + 0.05) * math.cos(a + 0.2), (R + 0.05) * math.sin(a + 0.2)),
               (cx + 0.0, (R + 0.65) * math.cos(a + 0.2), (R + 0.65) * math.sin(a + 0.2)), 0.12, 0.12, "timber")
    b.lathe([(0.45, -0.4), (0.45, 0.4)], 10, "bronze", base=(cx, 0, 0), rot=rot_y(math.pi / 2))
    b.lathe([(0.12, 0.0), (0.12, cx + 0.8)], 6, "iron", base=(0, 0, 0), rot=rot_y(math.pi / 2))
    for x in (0.25, cx + 0.7):
        b.box((x, 0, -0.9), (0.4, 0.5, 1.9), "timber", grain=2)
    # the chain run: links as alternating short flat boxes down to the leaf
    for k in range(18):
        z = -R * 0.2 - 0.5 * k
        b.box((cx + 0.35, R * 0.95, z), (0.08 if k % 2 else 0.22, 0.22 if k % 2 else 0.08, 0.52), "iron", grain=2)
    return b, D + 1.3, {}


def lock_sluice_port(name="lock_sluice_port", seed=205):
    """A sluice port (Fifth Lock 2.4 m wide; Vạn Thủy x1.6): an ashlar portal with a round arch, a bronze grille
    raised half open, its lifting rods; origin on the water line at the opening's centre; anchor_spout for the foam."""
    b = Builder(name, seed)
    block(b, -2.4, 2.4, 0.0, 1.6, -1.5, 3.6, "ashlar", chamfer=0.12)
    for k in range(9):                                # the arch voussoirs, proud of the face
        a0, a1 = math.pi * k / 9, math.pi * (k + 1) / 9
        am = (a0 + a1) / 2
        c = np.array([1.55 * math.cos(am), -0.12, 1.2 + 1.55 * math.sin(am)])
        b.box(c, (0.55, 0.3, 0.75), "ashlar_new", rot=rot_y(-am + math.pi / 2), grain=2)
    b.box((0, 0.05, 0.3), (2.4, 0.1, 2.0), "iron", grain=0)
    for x in np.linspace(-1.0, 1.0, 6):
        b.box((x, -0.05, 0.9), (0.1, 0.12, 2.6), "bronze", grain=2)
    b.box((0, -0.05, 2.1), (2.5, 0.16, 0.2), "bronze", grain=0)
    for x in (-0.9, 0.9):
        b.box((x, -0.1, 3.0), (0.1, 0.1, 1.9), "iron", grain=2)
    b.empty("anchor_spout", (0.0, -0.6, -0.3))
    return b, 3.6, {"silt": 0.5}


def lock_gate_gallery(name="lock_gate_gallery", span=37.5, seed=206):
    """The gate gallery: a covered timber bridge slung between a gate's two towers at the gallery level (Fifth Lock
    span 37.5 m), lattice sides, a tiled pent roof, lanterns; walkable. Origin at the span's centre, deck level."""
    b = Builder(name, seed)
    half = span / 2
    w = 3.2
    b.box((0, 0, -0.25), (span, w, 0.5), "plank", grain=0)
    for x in np.linspace(-half, half, 8):
        for y in (-w / 2, w / 2):
            b.box((x, y, 1.3), (0.28, 0.28, 2.6), "lacquer", grain=2)
        b.beam((x, -w / 2, -2.2), (x, -w / 2, -0.4), 0.3, 0.3, "timber")
    for y in (-w / 2, w / 2):
        b.beam((-half, y, 1.0), (half, y, 1.0), 0.15, 0.15, "lacquer")
        b.beam((-half, y, -0.6), (half, y, -0.6), 0.5, 0.8, "timber")
    troof(b, (0, 0, 2.7), half + 0.6, w / 2 + 1.0, 1.4, 0.5, 0.25, 0.3, p=1.3, ns=16, nt=3, hooks=False)
    for x in (-half / 2, half / 2):
        lantern(b, (x, -w / 2 - 0.3, 1.9), 0.4, 0.75, 0.4)
    b.collider("deck", [[(-half, -w / 2, 0.0), (half, -w / 2, 0.0), (half, w / 2, 0.0), (-half, w / 2, 0.0)]])
    return b, 4.5, {}


# ================================================================================================ VT1 the court
TOWER_VARIANTS = {
    # name: (storeys [(w, h, eave overhang, roof H, upturn)], spire, podium)    (owner question 2)
    "A": ([(20.0, 8.0, 6.0, 6.0, 2.4), (16.0, 6.5, 5.0, 5.2, 2.0), (13.0, 5.5, 4.0, 4.5, 1.7),
           (10.0, 5.0, 3.3, 4.0, 1.4), (7.5, 4.5, 3.0, 9.0, 1.3)], 9.6, 32.0),
    "B": ([(28.0, 8.0, 7.5, 6.5, 2.8), (23.0, 6.5, 6.0, 5.6, 2.3), (18.0, 5.5, 5.0, 4.8, 1.9),
           (13.0, 5.0, 4.0, 7.5, 1.6)], 6.0, 40.0),
    "C": ([(19.0, 9.0, 6.5, 6.4, 3.4), (15.5, 7.5, 5.5, 5.6, 2.9), (12.5, 6.5, 4.6, 5.0, 2.5),
           (10.0, 6.0, 3.9, 4.6, 2.1), (8.0, 5.5, 3.4, 4.2, 1.8), (6.0, 5.0, 3.0, 10.0, 1.6)], 13.0, 30.0),
}


def court_tower(name="vt_court_tower", variant="A", seed=301):
    """VT1 the Court Tower: five diminishing dark-tile roofs with fat upturned eaves, gilt ridge ends and corner hooks,
    red lacquer storeys with galleries, on a stepped ashlar podium; a gilt spire. Variant A (the design) stands about
    61 m on the top terrace = 95 m above the water (about 3x real); B is lower and wider (four roofs); C is bolder and
    taller (six roofs). Origin at the podium's foot on the top terrace deck."""
    b = Builder(name, seed)
    st, spire, P = TOWER_VARIANTS[variant]
    block(b, -P / 2, P / 2, -P / 2, P / 2, 0.0, 3.0, "ashlar", chamfer=0.3)
    block(b, -P / 2 + 2.5, P / 2 - 2.5, -P / 2 + 2.5, P / 2 - 2.5, 3.0, 5.0, "ashlar", chamfer=0.2)
    coping(b, -P / 2 + 2.5, P / 2 - 2.5, -P / 2 + 2.5, P / 2 - 2.5, 5.0, "paving", h=0.3, over=0.2)
    for k in range(8):                                   # the front stair up the podium
        z = 5.3 * (k + 1) / 8
        b.box((0, -P / 2 - 2.0 + k * 0.6, z / 2), (8.0, 0.6, z), "paving", grain=0)
    railing(b, 0, 0, 5.3, P - 5.0, P - 5.0, 1.2, 3.2, "lacquer", 0.22, open_front=(-4.2, 4.2))
    z = 5.3
    zt = z
    for i, (w, h, ov, H, up) in enumerate(st):
        last = i == len(st) - 1
        storey(b, 0, 0, z, w, w, h, wall="lacquer", col="lacquer", r=0.22 + 0.025 * w, step=4.2,
               door=(3.2, 4.0) if i == 0 else None)
        A = w / 2 + ov
        zr = troof(b, (0, 0, z + h), A, A, H, up, up * 0.45, 0.6 + 0.03 * A, p=1.55 if not last else 1.05,
                   ns=10 if i < 2 else 8, nt=5 if i < 2 else 4)
        if not last:
            nz = z + h + 0.42 * H
            nw = st[i + 1][0]
            b.box((0, 0, nz - 0.2), (nw + 3.4, nw + 3.4, 0.4), "plank", grain=0)
            railing(b, 0, 0, nz, nw + 3.2, nw + 3.2, 1.15, 3.0, "lacquer", 0.18)
            for sx in (-1, 1):
                for sy in (-1, 1):
                    lantern(b, (sx * (A - 0.6), sy * (A - 0.6), z + h - 0.8), 0.55, 1.05, 0.6)
                    if i == 0:
                        b.empty("anchor_lantern_%d%d" % (sx > 0, sy > 0), (sx * (A - 0.6), sy * (A - 0.6), z + h - 0.8))
            z = nz
        else:
            zt = zr
    prof = [(0.9, 0.0), (0.55, 0.6), (0.95, 1.1), (0.4, 1.7)]
    for k in range(6):
        zz = 1.9 + k * (spire - 3.4) / 6
        prof += [(0.32 - 0.03 * k, zz), (0.62 - 0.06 * k, zz + 0.35), (0.3 - 0.03 * k, zz + 0.7)]
    prof += [(0.12, spire - 0.9), (0.28, spire - 0.6), (0.0, spire)]
    b.lathe(prof, 10, "gilt", base=(0, 0, zt - 0.3))
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.empty("anchor_banner_%d%d" % (sx > 0, sy > 0), (sx * P / 2, sy * P / 2, 3.0))
    b.empty("anchor_smoke", (0, 0, 9.0))
    b.collider("podium", [[(-P / 2 + 2.5, -P / 2 + 2.5, 5.3), (P / 2 - 2.5, -P / 2 + 2.5, 5.3),
                           (P / 2 - 2.5, P / 2 - 2.5, 5.3), (-P / 2 + 2.5, P / 2 - 2.5, 5.3)]])
    return b, zt - 0.3 + spire, {"variant": variant}


TERRACES = {  # name: (width, depth, height, gallery depth, gate)
    "vt_court_terrace_1": (96.0, 76.0, 11.0, 6.0, True),
    "vt_court_terrace_2": (74.0, 58.0, 10.0, 5.5, False),
    "vt_court_terrace_3": (52.0, 44.0, 9.0, 5.0, False),
}


def court_terrace(name, seed=311):
    """VT1 a court terrace module: a battered ashlar mass of pale quay stone with a red lacquer frieze, a stone
    balustrade on its lip, a red lacquer gallery (colonnade under a long tiled roof) along its front; the lowest
    module carries the closed gate facade (dark iron-studded leaves under the court mark, never opened in Book I).
    Origin at the front-face centre on the module's foot; the next module sits back on its deck."""
    b = Builder(name, seed)
    W, D, H, G, gate = TERRACES[name]
    block(b, -W / 2, W / 2, 0.0, D, 0.0, H, "ashlar", batter=1.0, chamfer=0.4)
    block(b, -W / 2 + 0.9, W / 2 - 0.9, 0.9, D - 0.9, H - 1.6, H - 0.6, "lacquer", chamfer=0.1)   # the frieze
    coping(b, -W / 2 + 1.0, W / 2 - 1.0, 1.0, D - 1.0, H - 0.6, "paving", h=0.6, over=0.25)
    zt = H
    for x in np.arange(-W / 2 + 2.0, W / 2 - 1.9, 4.0):
        if gate and abs(x) < 6.0:
            continue
        b.box((x, 1.1, zt + 0.55), (0.5, 0.5, 1.1), "ashlar_new", grain=2)
    for (x0, x1) in (((-W / 2 + 2.0, -6.0), (6.0, W / 2 - 2.0)) if gate else ((-W / 2 + 2.0, W / 2 - 2.0),)):
        b.box(((x0 + x1) / 2, 1.1, zt + 1.15), (x1 - x0, 0.6, 0.25), "ashlar_new", grain=0)
    gw = W * 0.72
    gy = 3.0 + G / 2
    storey(b, 0, gy, zt, gw, G, 4.6, wall="plaster", col="lacquer", r=0.32, step=3.6, front_only=True)
    troof(b, (0, gy, zt + 4.6), gw / 2 + 1.6, G / 2 + 1.8, 3.4, 1.3, 0.6, 0.55, p=1.45, ns=16, nt=4)
    for k, x in enumerate(np.linspace(-gw / 2 + 2, gw / 2 - 2, 5)):
        lantern(b, (x, gy - G / 2 - 1.2, zt + 3.6), 0.48, 0.9, 0.5)
        b.empty("anchor_lantern_%d" % k, (x, gy - G / 2 - 1.2, zt + 3.6))
    if gate:
        block(b, -7.0, 7.0, -2.2, 0.6, 0.0, H + 0.4, "ashlar", chamfer=0.3)
        b.box((0, -2.25, 3.6), (7.0, 0.3, 7.2), "timber", grain=2)
        b.box((0, -2.42, 3.6), (0.25, 0.1, 7.2), "iron", grain=2)
        for zz in np.arange(0.8, 7.0, 1.4):
            b.box((0, -2.43, zz), (6.6, 0.08, 0.25), "iron", grain=0)
            for xx in np.linspace(-2.8, 2.8, 5):
                b.pebble((xx, -2.46, zz + 0.7), (0.16, 0.1, 0.16), "bronze", segs=4, rings=2)
        for k in range(11):
            a = math.pi * (k + 0.5) / 11
            b.box((3.9 * math.cos(a), -2.3, 7.2 + 1.2 * math.sin(a)), (0.9, 0.4, 0.8), "ashlar_new",
                  rot=rot_y(-a + math.pi / 2), grain=2)
        b.face([(-2.0, -2.32, 8.6), (2.0, -2.32, 8.6), (2.0, -2.32, 10.6), (-2.0, -2.32, 10.6)], "gate_mark",
               uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
        troof(b, (0, -0.8, H + 0.4), 8.4, 2.6, 2.2, 0.9, 0.4, 0.4, p=1.4, ns=12, nt=4)
        b.empty("anchor_gate", (0, -2.5, 0.0))
    for sx in (-1, 1):
        b.empty("anchor_banner_%s" % ("w" if sx < 0 else "e"), (sx * W * 0.38, 0.6, zt - 0.6))
    b.collider("deck", [[(-W / 2 + 1, 1.0, zt), (W / 2 - 1, 1.0, zt), (W / 2 - 1, D - 1, zt), (-W / 2 + 1, D - 1, zt)]])
    return b, zt + 9.0, {"footprint_m": [W, D], "deck_m": H}


def court_banner(name="vt_court_banner", key="banner_court", L=16.0, seed=321):
    """VT1 the court banner: 16 m of indigo with the Cửu Giang court mark in gilt (our own; never "Thủy Vân", never the
    sheets' medallions or seal), on a lacquered crossbar with gilt ends, madder tails; hangs from a terrace lip or a
    tower. Origin at the crossbar's centre; the cloth hangs -Z, pin weight in COLOR_0.a."""
    b = Builder(name, seed)
    cw = 3.6
    b.beam((-cw / 2 - 0.6, 0, 0), (cw / 2 + 0.6, 0, 0), 0.28, 0.28, "lacquer")
    for sx in (-1, 1):
        b.lathe([(0.2, 0), (0.3, 0.2), (0.12, 0.45), (0.0, 0.6)], 8, "gilt", base=(sx * (cw / 2 + 0.6), 0, 0),
                rot=rot_y(sx * math.pi / 2))
    vk.cloth_sheet(b, (0, -0.2, -0.15), cw, L, key, notch=0.9, amp=0.12, rows=16, cols=4)
    for sx in (-1, 1):
        vk.cloth_sheet(b, (sx * (cw / 2 + 0.3), -0.18, -0.15), 0.35, L * 0.82, "cloth_madder", notch=0.15, amp=0.05,
                       waves=1, rows=12, cols=2, unit=False, sway=0.2 * sx)
    b.tube([(-cw / 2 - 0.4, 0, 0.1), (0, 0, 1.4), (cw / 2 + 0.4, 0, 0.1)], 0.05, 4, "rope")
    return b, 1.5, {"cloth_m": [cw, L], "mark": key}


def lacquer_tower(name="vt_lacquer_tower", seed=331):
    """VT4 a district lacquer tower (lock-watch tower), 34 m (about 2.5x): an ashlar plinth, four red lacquer storeys
    with galleries under four tiled roofs, a bronze bell 2.2 m in the open top storey; the district banner (separate
    piece, vt_district_banner_*) mounts at anchor_banner. Origin at the plinth's foot."""
    b = Builder(name, seed)
    block(b, -6.0, 6.0, -6.0, 6.0, 0.0, 4.0, "ashlar", batter=0.4, chamfer=0.25)
    coping(b, -5.6, 5.6, -5.6, 5.6, 4.0, "paving", h=0.35, over=0.2)
    for k in range(6):
        z = 4.35 * (k + 1) / 6
        b.box((0, -7.6 + k * 0.32, z / 2), (3.0, 0.4, z), "paving", grain=0)
    z = 4.35
    zt = z
    spec = [(8.4, 5.2, 2.4, 2.8, 1.0), (7.2, 4.4, 2.2, 2.5, 0.95), (6.2, 4.0, 2.0, 2.3, 0.9), (5.4, 4.6, 2.1, 5.5, 0.9)]
    for i, (w, h, ov, H, up) in enumerate(spec):
        last = i == len(spec) - 1
        storey(b, 0, 0, z, w, w, h, wall="lacquer", col="lacquer", r=0.24, step=3.4, open_=last,
               door=(1.4, 2.5) if i == 0 else None)
        if last:
            b.lathe([(0.15, 0.0), (0.7, -0.2), (0.85, -1.2), (1.1, -2.0), (1.1, -2.2), (0.0, -2.2)], 10, "bronze",
                    base=(0, 0, z + h - 0.4))
            b.beam((-w / 2, 0, z + h - 0.3), (w / 2, 0, z + h - 0.3), 0.3, 0.35, "timber")
            b.empty("anchor_bell", (0, 0, z + h - 1.5))
        A = w / 2 + ov
        zr = troof(b, (0, 0, z + h), A, A, H, up, up * 0.45, 0.4, p=1.5 if not last else 1.1, ns=10, nt=5)
        if not last:
            nz = z + h + 0.4 * H
            b.box((0, 0, nz - 0.15), (spec[i + 1][0] + 2.0, spec[i + 1][0] + 2.0, 0.3), "plank", grain=0)
            railing(b, 0, 0, nz, spec[i + 1][0] + 1.8, spec[i + 1][0] + 1.8, 1.1, 2.2, "lacquer", 0.14)
            if i == 0:
                for sx in (-1, 1):
                    lantern(b, (sx * (A - 0.5), -(A - 0.5), z + h - 0.6), 0.42, 0.8, 0.5)
                    b.empty("anchor_lantern_%s" % ("w" if sx < 0 else "e"), (sx * (A - 0.5), -(A - 0.5), z + h - 0.6))
            z = nz
        else:
            zt = zr
    b.lathe([(0.35, 0), (0.2, 0.5), (0.4, 1.0), (0.1, 2.0), (0.0, 2.6)], 8, "gilt", base=(0, 0, zt - 0.1))
    b.empty("anchor_banner", (4.8, -4.8, 4.35))
    b.collider("plinth", [[(-5.6, -5.6, 4.35), (5.6, -5.6, 4.35), (5.6, 5.6, 4.35), (-5.6, 5.6, 4.35)]])
    return b, zt + 2.5, {}


DISTRICTS = {"lantern_ward": "jade", "grain_piers": "ochre", "naval_basin": "indigo", "archive": "bone",
             "rain_market": "madder"}


def district_banner(district, seed=341):
    """VT4 a district banner on its pole (1.5x real: 9.5 m pole, a 1.7 x 5.6 m cloth), the district's colour and mark
    (net knot, sheaf, hull, stacked tablets, umbrella ribs); madder tails (ochre on the madder banner). Origin at the
    pole's foot."""
    colour = DISTRICTS[district]
    b = Builder("vt_district_banner_" + district, seed)
    h, cw, cl = 9.5, 1.7, 5.6
    b.tube([(0, 0, 0), (0, 0, h / 2), (0, 0, h)], [0.14, 0.12, 0.1], 6, "lacquer")
    b.lathe([(0.16, 0), (0.1, 0.15), (0.18, 0.4), (0.0, 1.0)], 6, "gilt", base=(0, 0, h))
    zc = h - 0.4
    b.beam((-cw / 2 - 0.35, -0.14, zc), (cw / 2 + 0.35, -0.14, zc), 0.12, 0.14, "lacquer")
    b.tube([(-cw / 2 - 0.25, -0.14, zc + 0.05), (0, -0.05, h - 0.05), (cw / 2 + 0.25, -0.14, zc + 0.05)], 0.03, 4, "rope")
    vk.cloth_sheet(b, (0, -0.22, zc - 0.06), cw, cl, "banner_" + colour, notch=0.6, amp=0.08, rows=10, cols=4)
    tail = "cloth_ochre" if colour == "madder" else "cloth_madder"
    for sx in (-1, 1):
        vk.cloth_sheet(b, (sx * (cw / 2 + 0.24), -0.2, zc - 0.06), 0.24, cl * 0.8, tail, notch=0.12, amp=0.04, waves=1,
                       rows=10, cols=2, unit=False, sway=0.15 * sx)
    return b, h + 1.0, {"district": district, "colour": colour}


# ================================================================================================ VT10 quays and houses
def quay_house(name, W, D, storeys, roof_H, over, up, seed, gallery=None, base_z=0.0, footing=0.8, water_door=False):
    """Quay houses (VT, the Lantern Ward): stone footing, timber-framed plaster storeys (the ground storey a shop open
    to the quay: lacquer posts, raised plank shutters, a counter), skirt eaves between storeys, an optional lacquer
    gallery, and a big tiled roof (45-55% of the height) with curled ridge ends and corner hooks. Public doors 2.4 x
    1.3 m (places_se.md 9.2). Origin on the ground (or the water line, base_z > 0) under the footprint's centre."""
    b = Builder(name, seed)
    block(b, -W / 2 - 0.3, W / 2 + 0.3, -D / 2 - 0.3, D / 2 + 0.3, (-1.5 if base_z > 0 else 0.0), base_z + footing,
          "ashlar", chamfer=0.12)
    if water_door:
        b.box((0, -D / 2 - 0.32, base_z - 0.2), (1.6, 0.1, 2.0), "iron", grain=0)
        for k in range(7):
            a = math.pi * (k + 0.5) / 7
            b.box((1.0 * math.cos(a), -D / 2 - 0.38, base_z + 0.8 + 0.6 * math.sin(a)), (0.5, 0.2, 0.42), "ashlar_new",
                  rot=rot_y(-a + math.pi / 2), grain=2)
        for k in range(int(base_z / 0.3)):                 # side steps down to the water
            zz = base_z - (k + 1) * 0.3
            b.box((W / 2 + 0.9, -D / 2 + 0.6 + k * 0.4, zz + 0.15 - 0.6), (1.2, 0.42, 1.5), "ashlar", grain=0)
    y0, y1 = -D / 2, D / 2
    z = base_z + footing
    for i, (h, kind) in enumerate(storeys):
        if kind == "shop":
            for (p0, p1) in (((-W / 2, y1), (W / 2, y1)), ((W / 2, y0), (W / 2, y1)), ((-W / 2, y1), (-W / 2, y0))):
                vk.wall(b, p0, p1, z, h, key="plaster", thick=0.18,
                        openings=[(abs(p1[1] - p0[1]) / 2 if p0[0] == p1[0] else W / 2, 1.0, 1.0, 2.2, "window")]
                        if p0[0] == p1[0] else [])
            for x in np.linspace(-W / 2, W / 2, 4):
                b.lathe([(0.22, 0), (0.18, 0.3), (0.18, h)], 8, "lacquer", base=(x, y0, z))
            for k, x in enumerate(np.linspace(-W / 2, W / 2, 4)[:-1]):
                xc = x + W / 6
                b.box((xc, y0 - 0.55, z + h - 0.35), (W / 3 - 0.3, 1.25, 0.08), "plank", rot=rot_x(0.55), grain=0)
            b.box((0, y0 + 0.5, z + 0.5), (W * 0.62, 0.7, 1.0), "timber", grain=0)
            b.box((0, y1 - 0.2, z + h / 2), (W - 0.2, 0.1, h), "plaster", grain=0)
            b.empty("anchor_door", (W * 0.36, y0 - 0.3, z))
        else:
            ops = [(W / 2, 1.3, 0.0, 2.4, "door")] if (i == 0) else [(W * 0.28, 1.0, 0.9, 2.0, "window"),
                                                                     (W * 0.72, 1.0, 0.9, 2.0, "window")]
            vk.framed_plaster_wall(b, (-W / 2, y0), (W / 2, y0), z, h, openings=ops)
            vk.framed_plaster_wall(b, (W / 2, y0), (W / 2, y1), z, h,
                                   openings=[(D / 2, 0.9, 1.0, 1.9, "window")] if D > 4 else [])
            vk.framed_plaster_wall(b, (W / 2, y1), (-W / 2, y1), z, h)
            vk.framed_plaster_wall(b, (-W / 2, y1), (-W / 2, y0), z, h)
            if i == 0:
                b.empty("anchor_door", (0.0, y0 - 0.3, z))
        z += h
        last = i == len(storeys) - 1
        if not last:
            b.box((0, 0, z + 0.15), (W + 0.4, D + 0.4, 0.3), "timber", grain=0)
            if gallery == i:
                b.box((0, y0 - 0.8, z + 0.2), (W + 0.8, 1.8, 0.25), "plank", grain=0)
                railing(b, 0, y0 - 0.8, z + 0.32, W + 0.6, 1.6, 1.05, 1.2, "lacquer", 0.12)
                for x in (-W / 2 - 0.3, W / 2 + 0.3):
                    b.beam((x, y0 - 1.5, z + 0.1), (x, y0 + 0.1, z - 1.0), 0.18, 0.2, "timber")
            else:
                troof(b, (0, 0, z + 0.25), W / 2 + 0.9, D / 2 + 0.9, 1.6, 0.35, 0.2, 0.22, p=1.2, gilt=False,
                      ns=8, nt=3, hooks=False, curls=False)
            z += 0.3
    if W >= D:
        zt = troof(b, (0, 0, z), W / 2 + over, D / 2 + over, roof_H, up, up * 0.5, 0.36, p=1.6, gilt=False, ns=12, nt=6)
    else:                                   # a narrow house: the ridge runs front to back
        with b.at((0, 0, 0), yaw=math.pi / 2):
            zt = troof(b, (0, 0, z), D / 2 + over, W / 2 + over, roof_H, up, up * 0.5, 0.36, p=1.6, gilt=False,
                       ns=12, nt=6)
    lantern(b, (W * 0.3, y0 - over * 0.7, z - 0.9), 0.36, 0.7, 0.5)
    b.empty("anchor_lantern", (W * 0.3, y0 - over * 0.7, z - 0.9))
    b.empty("anchor_smoke", (0, y1, z - 0.3))
    b.empty("anchor_door_lamp", (W * 0.36 - 0.9, y0 - 0.2, base_z + footing + 2.0))
    return b, zt + 0.8, {"footprint_m": [W, D], "roof_share": round(roof_H / (zt - base_z), 2)}


def quay_steps(name="vt_quay_steps", W=6.0, patched=False, seed=401):
    """VT10 canal steps: 0.3 m risers (2x wide, 6 m) from the quay deck (+3.0) into the water (to -1.2), cheek walls with
    coping; the patched variant has one pale new block set into an old step. Origin on the water line at the foot of
    the flight's centre; the flight climbs toward +Y. Walkable collider."""
    b = Builder(name, seed)
    n = 14
    tread = 0.42
    for k in range(n):
        ztop = -1.2 + 0.3 * (k + 1)
        y = (k - 4) * tread
        if patched and k == 6:
            for (x0, x1, key) in ((-W / 2, -0.6, "ashlar"), (-0.6, 1.0, "ashlar_new"), (1.0, W / 2, "ashlar")):
                b.box(((x0 + x1) / 2, y + tread / 2, (ztop - 2.0) / 2), (x1 - x0 - 0.02, tread, ztop + 2.0), key,
                      grain=0)
        else:
            b.box((0, y + tread / 2, (ztop - 2.0) / 2), (W, tread, ztop + 2.0), "ashlar", grain=0)
    ytop = (n - 4) * tread
    for sx in (-1, 1):
        xa, xb = sorted((sx * W / 2, sx * (W / 2 + 1.2)))
        block(b, xa, xb, -4 * tread - 0.4, ytop + 1.0, -2.0, 3.3, "ashlar", chamfer=0.1)
        coping(b, xa, xb, -4 * tread - 0.4, ytop + 1.0, 3.3, "paving", h=0.3, over=0.05)
    b.box((0, ytop + 1.5, 1.2), (W + 2.4, 3.0, 3.6), "ashlar", grain=0)
    b.box((0, ytop + 1.5, 3.05), (W + 2.4, 3.0, 0.1), "paving", grain=0)
    b.collider("steps", [[(-W / 2, -4 * tread, -1.2), (W / 2, -4 * tread, -1.2), (W / 2, ytop, 3.0), (-W / 2, ytop, 3.0)]])
    b.empty("anchor_mooring", (W / 2 + 0.6, -4 * tread - 0.5, 0.8))
    return b, 3.6, {"risers_m": 0.3, "patched": patched, "silt": 0.4}


def quay_wall(name="vt_quay_wall_20m", L=20.0, seed=411):
    """VT10 a straight quay wall module: oversized ashlar from the canal bed to +3.0, paving deck 6 m deep with a
    coping lip, iron mooring rings in the face, two bollards; silt line in vertex colour. Origin on the water line at
    the face's centre; the deck runs +Y. Walkable collider."""
    b = Builder(name, seed)
    block(b, -L / 2, L / 2, -0.5, 6.0, -2.5, 3.0, "ashlar", chamfer=0.02)
    coping(b, -L / 2, L / 2, -0.7, 6.0, 3.0, "paving", h=0.3, over=0.0)
    for x in (-L / 4, L / 4):
        b.tube([(x + 0.3 * math.cos(a), -0.56, 1.2 + 0.3 * math.sin(a)) for a in np.linspace(0, 2 * math.pi, 9)],
               0.05, 4, "iron", caps=False)
        b.lathe([(0.3, 0), (0.26, 0.45), (0.34, 0.56), (0.18, 0.7)], 8, "iron", base=(x, 0.2, 3.3))
    b.collider("deck", [[(-L / 2, -0.7, 3.3), (L / 2, -0.7, 3.3), (L / 2, 6.0, 3.3), (-L / 2, 6.0, 3.3)]])
    return b, 3.3, {"silt": 0.5}


def drain_mouth(name="vt_drain_mouth", seed=421):
    """VT10 a tiled drain mouth (1.1 m) in a quay-wall panel: a ring of roof tiles round the arch, a dark mouth, a green
    streak below it (vertex colour), an eel basket on a rope. Origin on the water line at the face."""
    b = Builder(name, seed)
    block(b, -2.0, 2.0, 0.0, 1.0, -1.5, 3.0, "ashlar", chamfer=0.05)
    coping(b, -2.0, 2.0, -0.2, 1.0, 3.0, "paving", h=0.3, over=0.0)
    b.box((0, -0.02, 0.85), (1.1, 0.06, 1.1), "iron", grain=0)
    for k in range(11):
        a = math.pi * k / 10
        b.box((0.7 * math.cos(a), -0.1, 1.35 + 0.7 * math.sin(a) * 0.9), (0.26, 0.24, 0.4), "tile",
              rot=rot_y(-a + math.pi / 2), grain=2)
    for x in (-0.65, 0.65):
        b.box((x, -0.1, 0.85), (0.24, 0.24, 1.1), "tile", grain=2)
    b.beam((1.4, -0.1, 2.6), (1.4, -0.6, 2.6), 0.08, 0.08, "iron")
    b.tube([(1.4, -0.6, 2.6), (1.4, -0.62, 1.4)], 0.025, 4, "rope")
    b.lathe([(0.0, 0.0), (0.25, 0.06), (0.3, 0.4), (0.22, 0.8), (0.12, 0.95)], 8, "weave", base=(1.4, -0.62, 0.45),
            cap_top=False)
    b.empty("anchor_outflow", (0, -0.3, 0.4))
    return b, 3.3, {"streak": (-0.6, 0.6, 0.4)}


# ================================================================================================ VT7 the high bridge
def high_bridge(name="vt_high_bridge", S=38.0, clear=15.0, w=6.0, quay=3.0, gate_open=True, seed=431):
    """VT7 a high bridge: a steep round-headed stone arch 38 m span (30-45 m), 15 m clear so junks pass under, a humped
    crown, stair ramps of 0.3 m risers down to the quays (+3.0) both sides, a pale voussoir ring, a chunky parapet, and
    the bridge gate at the crown (open, or shut by decree: month 5). Origin on the water line under the crown; the
    deck runs along X. Walkable collider along the deck and stairs."""
    b = Builder(name, seed)
    hs = S / 2
    spring = 1.0
    crown_t = 1.4
    n = 18
    xs = np.linspace(-hs, hs, n + 1)
    intr = spring + (clear - spring) * np.sqrt(np.clip(1 - (xs / hs) ** 2, 0, 1)) ** 0.85
    deck = clear + crown_t - 2.2 * (xs / hs) ** 2
    zend = deck[0]
    nst = int(round((zend - quay) / 0.3))
    run = nst * 0.42
    # the arch's underside and its spandrel faces
    P = np.zeros((2, n + 1, 3))
    for j, y in enumerate((-w / 2, w / 2)):
        for i in range(n + 1):
            P[j, i] = (xs[i], y, intr[i])
    b.grid(P, "ashlar", smooth=True)
    for y, fl in ((-w / 2, False), (w / 2, True)):
        for i in range(n):
            q = [(xs[i], y, intr[i]), (xs[i + 1], y, intr[i + 1]), (xs[i + 1], y, deck[i + 1]), (xs[i], y, deck[i])]
            b.face(q[::-1] if fl else q, "ashlar")
    for i in range(n):        # the crown's paving
        b.face([(xs[i], -w / 2, deck[i]), (xs[i + 1], -w / 2, deck[i + 1]), (xs[i + 1], w / 2, deck[i + 1]),
                (xs[i], w / 2, deck[i])][::-1], "paving")
    # the voussoir ring on both faces
    for y in (-w / 2 - 0.12, w / 2 + 0.12):
        for k in range(15):
            t = (k + 0.5) / 15
            x = -hs + S * t
            z = spring + (clear - spring) * math.sqrt(max(0.0, 1 - (x / hs) ** 2)) ** 0.85
            dzdx = (spring + (clear - spring) * math.sqrt(max(0.0, 1 - ((x + 0.01) / hs) ** 2)) ** 0.85 - z) / 0.01
            a = math.atan(dzdx)
            b.box((x, y, z + 0.6), (1.7, 0.3, 1.3), "ashlar_new", rot=rot_y(-a), grain=0)
    # abutments and their stairs, both sides
    for sx in (-1, 1):
        x0, x1 = sx * hs, sx * (hs + run + 1.5)
        lo, hi = min(x0, x1), max(x0, x1)
        for y, fl in ((-w / 2 - 0.4, sx > 0), (w / 2 + 0.4, sx < 0)):
            q = [(x0, y, -2.0), (x1, y, -2.0), (x1, y, quay), (x0, y, zend)]
            b.face(q[::-1] if fl else q, "ashlar")
        b.face([(x1, -w / 2 - 0.4, -2.0), (x1, w / 2 + 0.4, -2.0), (x1, w / 2 + 0.4, quay), (x1, -w / 2 - 0.4, quay)]
               [::(1 if sx > 0 else -1)], "ashlar")
        b.face([(x0, -w / 2 - 0.4, -2.0), (x0, w / 2 + 0.4, -2.0), (x0, w / 2 + 0.4, spring), (x0, -w / 2 - 0.4, spring)]
               [::(-1 if sx > 0 else 1)], "ashlar")
        for k in range(nst):
            ztop = zend - 0.3 * k
            xa = x0 + sx * k * 0.42
            b.box((xa + sx * 0.21, 0, ztop - 0.4), (0.44, w + 0.8, 0.8), "paving", grain=1)
        b.face([(x0 + sx * nst * 0.42, -w / 2 - 0.4, quay), (x1, -w / 2 - 0.4, quay), (x1, w / 2 + 0.4, quay),
                (x0 + sx * nst * 0.42, w / 2 + 0.4, quay)][::(-1 if sx > 0 else 1)], "paving")
        # parapets down the stair
        for y in (-w / 2 - 0.15, w / 2 + 0.15):
            b.beam((x0, y, zend + 0.55), (x0 + sx * run, y, quay + 0.3 + 0.55), 0.5, 1.1, "ashlar_new")
            b.box((x0 + sx * run + sx * 0.4, y, quay + 0.75), (0.8, 0.8, 1.5), "ashlar_new", grain=2)
        b.box((x0 + sx * 0.4, 0, -0.5), (1.2, w + 0.8, 3.0), "ashlar", grain=1)
    for y in (-w / 2 - 0.15, w / 2 + 0.15):
        for i in range(n):
            b.beam((xs[i], y, deck[i] + 0.55), (xs[i + 1], y, deck[i + 1] + 0.55), 0.5, 1.1, "ashlar_new")
    # the bridge gate: four lacquer posts, a tiled hood, two leaves (shut across the walk, or folded open)
    zc = deck[n // 2]
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.lathe([(0.32, 0), (0.28, 0.4), (0.26, 5.4)], 8, "lacquer", base=(sx * 1.6, sy * (w / 2 - 0.1), zc))
    for sx in (-1, 1):
        b.beam((sx * 1.6, -w / 2 - 0.4, zc + 5.2), (sx * 1.6, w / 2 + 0.4, zc + 5.2), 0.4, 0.5, "timber")
    troof(b, (0, 0, zc + 5.5), w / 2 + 1.6, 2.6, 2.4, 0.9, 0.45, 0.35, p=1.4, gilt=False, ns=10, nt=4)
    lantern(b, (0, -w / 2 - 1.0, zc + 4.6), 0.4, 0.75, 0.4)
    b.empty("anchor_lantern", (0, -w / 2 - 1.0, zc + 4.6))
    for sy in (-1, 1):
        if gate_open:
            b.box((-1.75, sy * (w / 2 - 1.6), zc + 1.6), (0.18, 2.9, 3.2), "timber", grain=2)
        else:
            b.box((-1.6, sy * (w / 4), zc + 1.6), (0.18, w / 2 - 0.1, 3.2), "timber", grain=2)
            for zz in (0.6, 1.6, 2.6):
                b.box((-1.72, sy * (w / 4), zc + zz), (0.06, w / 2 - 0.2, 0.18), "iron", grain=1)
    # walkable deck: the hump and both stairs as ramps
    quads = []
    for i in range(n):
        quads.append([(xs[i], -w / 2, deck[i]), (xs[i + 1], -w / 2, deck[i + 1]), (xs[i + 1], w / 2, deck[i + 1]),
                      (xs[i], w / 2, deck[i])])
    for sx in (-1, 1):
        x0, xq = sx * hs, sx * (hs + run)
        quads.append([(x0, -w / 2, zend), (xq, -w / 2, quay), (xq, w / 2, quay), (x0, w / 2, zend)])
    b.collider("deck", quads)
    return b, zc + 8.5, {"span_m": S, "clear_m": clear, "length_m": round(S + 2 * (run + 1.5), 1),
                         "gate": "open" if gate_open else "closed"}


# ================================================================================================ VT5 the grain piers
def granary_hall(name="vt_granary_hall", seed=441):
    """VT5 a granary hall 40 x 18 m: an ashlar plinth, timber-framed plaster walls with cart doors and high vents, a
    great dark-tile hip roof (55% of the height) with curled ends; an ochre district banner mounts at anchor_banner.
    Origin on the ground at the front's centre."""
    b = Builder(name, seed)
    W, D, Hw = 40.0, 18.0, 6.0
    block(b, -W / 2 - 0.5, W / 2 + 0.5, -D / 2 - 0.5, D / 2 + 0.5, 0.0, 1.5, "ashlar", chamfer=0.15)
    z = 1.5
    ops = [(W * 0.3, 3.6, 0.0, 4.2, "door"), (W * 0.7, 3.6, 0.0, 4.2, "door"), (W * 0.5, 1.2, 3.2, 4.6, "window")]
    vk.framed_plaster_wall(b, (-W / 2, -D / 2), (W / 2, -D / 2), z, Hw, openings=ops)
    vk.framed_plaster_wall(b, (W / 2, -D / 2), (W / 2, D / 2), z, Hw, openings=[(D / 2, 1.2, 3.4, 4.8, "window")])
    vk.framed_plaster_wall(b, (W / 2, D / 2), (-W / 2, D / 2), z, Hw)
    vk.framed_plaster_wall(b, (-W / 2, D / 2), (-W / 2, -D / 2), z, Hw, openings=[(D / 2, 1.2, 3.4, 4.8, "window")])
    for x in np.linspace(-W / 2, W / 2, 11):
        b.box((x, -D / 2 - 0.14, z + Hw / 2), (0.36, 0.3, Hw), "timber", grain=2)
    for x in (-W * 0.2, W * 0.2):                      # the cart ramps
        b.box((x, -D / 2 - 1.6, 0.75), (4.4, 3.2, 1.5), "paving", rot=rot_x(-0.3), grain=0)
    zt = troof(b, (0, 0, z + Hw), W / 2 + 2.2, D / 2 + 2.2, 10.0, 1.6, 0.8, 0.5, p=1.5, gilt=False, ns=20, nt=6)
    for sx in (-1, 1):                                  # gable vents in the hip ends
        b.box((sx * (W / 2 - 3.0), 0, z + Hw + 6.0), (0.3, 2.2, 1.6), "timber", grain=1)
    b.empty("anchor_banner", (-W / 2 + 1.0, -D / 2 - 2.5, 0.0))
    b.empty("anchor_door_a", (-W * 0.2, -D / 2 - 3.0, 0.0))
    b.empty("anchor_door_b", (W * 0.2, -D / 2 - 3.0, 0.0))
    return b, zt + 1.5, {"footprint_m": [W, D], "roof_share": round(10.0 / (zt + 1.5), 2)}


def pier_finger(name="vt_pier_finger", L=20.0, Wd=8.0, deck=7.0, end=False, seed=451):
    """VT5 a pier module on a pile forest (piles 0.45 m, about 2x), the deck 7 m above the water, X-braced bents,
    bollards; `end`: a landing stage with stairs down to a floating step at the water. Origin on the water line at the
    module's centre; the pier runs along X. Walkable colliders."""
    b = Builder(name, seed)
    for x in np.arange(-L / 2 + 1.0, L / 2, 2.0):
        for y in np.linspace(-Wd / 2 + 0.4, Wd / 2 - 0.4, 4):
            lean = b.rng.normal(0, 0.012, 2)
            b.tube([(x, y, -2.0), (x + lean[0] * 9, y + lean[1] * 9, deck - 0.5)], [0.25, 0.22], 6, "timber", caps=False)
        b.beam((x, -Wd / 2, deck - 0.6), (x, Wd / 2, deck - 0.6), 0.35, 0.45, "timber")
    for y in (-Wd / 2 + 0.4, Wd / 2 - 0.4):
        for x in np.arange(-L / 2 + 1.0, L / 2 - 2.0, 4.0):
            b.beam((x, y, 0.8), (x + 2.0, y, deck - 1.0), 0.18, 0.22, "timber")
            b.beam((x + 2.0, y, 0.8), (x, y, deck - 1.0), 0.18, 0.22, "timber")
    b.box((0, 0, deck - 0.15), (L, Wd, 0.3), "plank", grain=1)
    for y in (-Wd / 2, Wd / 2):
        b.beam((-L / 2, y, deck - 0.2), (L / 2, y, deck - 0.2), 0.3, 0.5, "timber")
    for x in (-L / 2 + 3.0, L / 2 - 3.0):
        b.lathe([(0.3, 0), (0.26, 0.5), (0.34, 0.62), (0.18, 0.78)], 8, "timber", base=(x, -Wd / 2 + 0.5, deck))
        b.empty("anchor_mooring_%d" % int(x), (x, -Wd / 2 - 0.5, deck))
    quads = [[(-L / 2, -Wd / 2, deck), (L / 2, -Wd / 2, deck), (L / 2, Wd / 2, deck), (-L / 2, Wd / 2, deck)]]
    if end:
        xs = L / 2
        for k in range(int((deck - 0.6) / 0.3)):
            zz = deck - 0.3 * (k + 1)
            b.box((xs + 0.6 + k * 0.32, -Wd / 2 + 1.0, zz), (0.34, 1.8, 0.12), "plank", grain=1)
        nst = int((deck - 0.6) / 0.3)
        xe = xs + 0.6 + nst * 0.32
        for y in (-Wd / 2 + 0.05, -Wd / 2 + 1.95):
            b.beam((xs, y, deck), (xe, y, 0.6), 0.14, 0.3, "timber")
        b.box((xe + 1.5, -Wd / 2 + 1.5, 0.35), (3.6, 3.6, 0.5), "plank", grain=0)
        for xx in (xe, xe + 3.0):
            b.tube([(xx, -Wd / 2 - 0.2, -1.5), (xx, -Wd / 2 - 0.2, 1.6)], 0.2, 6, "timber")
        quads.append([(xs, -Wd / 2 + 0.1, deck), (xe, -Wd / 2 + 0.1, 0.6), (xe, -Wd / 2 + 1.9, 0.6),
                      (xs, -Wd / 2 + 1.9, deck)])
        quads.append([(xe - 0.3, -Wd / 2 - 0.3, 0.6), (xe + 3.3, -Wd / 2 - 0.3, 0.6), (xe + 3.3, -Wd / 2 + 3.3, 0.6),
                      (xe - 0.3, -Wd / 2 + 3.3, 0.6)])
    b.collider("deck", quads)
    return b, deck + 0.8, {"deck_m": deck, "module_m": L}


def treadwheel_crane(name="vt_treadwheel_crane", seed=461):
    """VT5 a treadwheel crane, 16 m (about 2x): a timber base frame, an A-frame mast, a long jib with stays, a walking
    treadwheel 5.6 m across turning the hoist drum, a rope over the jib's sheave to a basket hoist. Origin on the deck
    at the base's centre; the jib reaches toward -Y (over the water)."""
    b = Builder(name, seed)
    for (x, y) in ((-2.6, -2.6), (2.6, -2.6), (2.6, 2.6), (-2.6, 2.6)):
        b.box((x, y, 0.3), (0.5, 0.5, 0.6), "timber", grain=2)
    for y in (-2.6, 2.6):
        b.beam((-2.6, y, 0.55), (2.6, y, 0.55), 0.45, 0.45, "timber")
    for x in (-2.6, 2.6):
        b.beam((x, -2.6, 0.55), (x, 2.6, 0.55), 0.45, 0.45, "timber")
    top = np.array([0.0, 0.0, 11.5])
    for x in (-2.4, 2.4):
        b.beam((x, 0.0, 0.6), top + [x * 0.12, 0, 0], 0.42, 0.42, "timber")
        b.beam((x, 2.6, 0.6), top + [x * 0.12, 0, -0.6], 0.32, 0.32, "timber")
    b.beam((-2.2, 0, 5.5), (2.2, 0, 5.5), 0.3, 0.3, "timber")
    tip = np.array([0.0, -11.0, 16.0])
    for x in (-0.35, 0.35):
        b.beam((x, 0.6, 9.0), tip + [x * 0.4, 0, 0], 0.4, 0.45, "timber")
    b.tube([top + [0, 0.2, 0.3], tip + [0, 0, 0.4]], 0.06, 4, "rope", caps=False)
    b.tube([top + [0, 0.2, 0.3], (0.0, 3.0, 0.8)], 0.06, 4, "rope", caps=False)
    b.lathe([(0.45, -0.25), (0.45, 0.25)], 8, "iron", base=tip, rot=rot_y(math.pi / 2))
    # the treadwheel: two rims, slats, spokes; axis along X beside the mast
    R, Wt, c = 2.8, 2.0, np.array([-4.2, 1.0, 3.3])
    for dx in (-Wt / 2, Wt / 2):
        b.tube([c + [dx, R * math.cos(a), R * math.sin(a)] for a in np.linspace(0, 2 * math.pi, 21)], 0.13, 5,
               "timber", caps=False)
        for k in range(6):
            a = k * math.pi / 3
            b.beam(c + [dx, 0, 0], c + [dx, R * math.cos(a), R * math.sin(a)], 0.16, 0.16, "timber")
    for k in range(20):
        a = 2 * math.pi * k / 20
        b.beam(c + [-Wt / 2, R * math.cos(a), R * math.sin(a)], c + [Wt / 2, R * math.cos(a), R * math.sin(a)], 0.22,
               0.08, "plank")
    b.lathe([(0.2, -0.1), (0.2, 4.6)], 6, "timber", base=c + [-Wt / 2 - 0.1, 0, 0], rot=rot_y(math.pi / 2))
    for y in (-0.5, 2.5):
        b.box((c[0], y, 1.6), (0.3, 0.3, 3.4), "timber", grain=2)
    # the hoist: rope down from the sheave, a basket with a sack in it
    hz = 6.5
    b.tube([tip + [0, 0, -0.4], tip + [0, 0, -(tip[2] - hz - 1.4)]], 0.05, 4, "rope", caps=False)
    for a in (0.0, 2.1, 4.2):
        b.tube([tip + [0, 0, -(tip[2] - hz - 1.4)], tip + [0.55 * math.cos(a), 0.55 * math.sin(a), -(tip[2] - hz - 0.4)]],
               0.03, 3, "rope", caps=False)
    b.lathe([(0.0, 0.0), (0.55, 0.08), (0.7, 0.55), (0.72, 1.0)], 10, "weave", base=tip + [0, 0, -(tip[2] - hz)],
            cap_top=False)
    b.pebble(tip + [0, 0, -(tip[2] - hz) + 1.0], (0.55, 0.45, 0.4), "hessian", segs=7, rings=4)
    b.empty("anchor_hoist", tuple(tip + [0, 0, -(tip[2] - hz)]))
    return b, 16.6, {}


def sacks_heap(name="vt_sacks_heap", n=46, seed=471):
    """VT5 a sack mountain (about 4.5 m): hessian sacks stacked in courses, the top ones slumped; origin on the deck."""
    b = Builder(name, seed)
    rng = b.rng
    z = 0.0
    w, d = 6.0, 4.0
    k = 0
    while k < n and w > 1.0:
        for x in np.arange(-w / 2 + 0.55, w / 2 - 0.4, 1.0):
            for y in np.arange(-d / 2 + 0.4, d / 2 - 0.3, 0.75):
                if k >= n:
                    break
                b.pebble((x + rng.normal(0, 0.06), y + rng.normal(0, 0.05), z + 0.28),
                         (0.55, 0.38, 0.3 + rng.uniform(0, 0.05)), "hessian", rot=rot_z(rng.normal(0, 0.2)), segs=6,
                         rings=3)
                k += 1
        z += 0.56
        w -= 1.1
        d -= 0.8
    return b, z + 0.3, {"sacks": k}


def crates_stack(name="vt_crates_stack", seed=472):
    b = Builder(name, seed)
    rng = b.rng
    for (x, y, z, s) in ((0, 0, 0, 1.2), (1.3, 0.1, 0, 1.1), (0.6, 0.0, 1.2, 1.1), (-1.2, 0.2, 0, 1.0),
                         (-0.6, 0.1, 1.2, 0.9), (0.0, 1.3, 0, 1.2), (1.2, 1.3, 0, 1.0)):
        R = rot_z(rng.normal(0, 0.08))
        b.box((x, y, z + s / 2), (s, s, s), "timber", rot=R, grain=0)
        for dz in (0.12, s - 0.12):
            b.box((x, y, z + dz), (s + 0.04, s + 0.04, 0.1), "iron", rot=R, grain=0)
    b.tube([(-1.9, -0.6, 0.0), (-1.2, -0.6, 1.0), (0.0, -0.62, 1.25), (1.2, -0.6, 1.0), (1.9, -0.6, 0.0)], 0.04, 4,
           "rope", caps=False)
    return b, 2.4, {}


def jars_cluster(name="vt_jars_cluster", seed=473):
    b = Builder(name, seed)
    rng = b.rng
    for k in range(9):
        a = k * 2.4
        r = 0.0 if k == 0 else (0.9 if k < 6 else 1.6)
        s = rng.uniform(0.8, 1.15)
        c = (r * math.cos(a), r * math.sin(a), 0.0)
        b.lathe([(0.0, 0.0), (0.3 * s, 0.02), (0.48 * s, 0.35 * s), (0.5 * s, 0.6 * s), (0.3 * s, 0.95 * s),
                 (0.2 * s, 1.05 * s), (0.24 * s, 1.12 * s)], 8, "jar", base=c, cap_top=False)
        if k % 3 == 0:
            b.lathe([(0.26 * s, 0.0), (0.2 * s, 0.1), (0.0, 0.14)], 8, "weave", base=(c[0], c[1], 1.1 * s))
    return b, 1.4, {}


# ================================================================================================ boats
def hull_loft(b, L, B, D, draft, rise_stern, rise_bow, key="timber", n=20):
    """A junk hull: flat transoms at bow (+X) and stern (-X), a high stern, sheer rising to both ends; closed (deck)."""
    us = np.linspace(0, 1, n + 1)
    sec = [(1.0, 1.0), (1.0, 0.55), (0.92, 0.2), (0.7, 0.0), (0.35, -0.08), (0.0, -0.1)]
    rows = []
    for u in us:
        x = -L / 2 + u * L
        hb = B / 2 * max(0.45 if u < 0.5 else 0.3, math.sqrt(max(0.0, 1 - ((u - 0.42) / 0.62) ** 2)))
        sheer = D + rise_stern * (1 - u) ** 3 + rise_bow * u ** 4
        keel = -draft * (0.6 + 0.4 * math.sin(math.pi * u))
        row = []
        pts = sec + [(-s, z) for (s, z) in sec[::-1][1:]]
        for (s, zz) in pts:
            z = keel + (sheer - keel) * max(0.0, (zz + 0.1) / 1.1)
            row.append((x, s * hb, z))
        rows.append(row)
    P = np.array(rows)
    b.grid(P, key, smooth=True, flip=True)
    m = P.shape[1]
    b.face([P[0, j] for j in range(m)], key)                       # stern transom
    b.face([P[-1, j] for j in range(m)][::-1], key)                # bow transom
    for i in range(n):                                             # the deck (closes the hull)
        b.face([P[i, 0], P[i + 1, 0], P[i + 1, m - 1], P[i, m - 1]][::-1], "plank")
    return P


def junk_sail(s, base, height, width, nb, key="sail", rake=0.0, seed_off=0):
    """A battened lug sail in the XZ plane at `base` (the mast foot of the sail), luff a little forward of the mast,
    the leech fanning aft in scallops between battens, the head yard tilted up aft; battens and yard in timber."""
    base = np.asarray(base, float)
    rows, cols = nb + 1, 4
    P = np.zeros((rows, cols + 1, 3))
    U = np.zeros((rows, cols + 1))
    V = np.zeros((rows, cols + 1))
    M = np.zeros((rows, cols + 1))
    for i in range(rows):
        t = i / nb
        z = t * height
        luff = -0.18 * width
        leech = width * (0.62 + 0.45 * t) + (0.1 * width if i % 2 else 0.0)      # the fan, scalloped
        for j in range(cols + 1):
            q = j / cols
            x = luff + (leech - luff) * q
            zt = z + 0.42 * width * t * q - 0.08 * width * (1 - t) * q   # the head yard rises aft, the foot droops
            y = 0.25 * math.sin(math.pi * q) * (1 if i % 2 else 0.6)
            P[i, j] = base + [x + rake * z, y, zt]
            U[i, j] = x
            V[i, j] = zt
            M[i, j] = q
    s.grid(P, key, U, V, smooth=True, M=M)
    for i in range(rows):
        s.beam(P[i, 0] + [-0.3, 0, 0], P[i, -1] + [0.3, 0, 0], 0.11, 0.11, "timber")
    s.tube([P[i, -1] for i in range(rows)] + [P[-1, -1] + [0.5, 0, -height * 0.15]], 0.025, 3, "rope", caps=False)


def junk(name, L, B, D, masts, seed, sea=False):
    """vt_junk_river (two masts) / vt_junk_sea (three masts): a dark timber hull with a high stern castle and flat
    transoms, a lacquer rubbing strake, a deckhouse with a tiled roof, a rudder, tall masts with battened lug sails
    (sails in a separate child mesh '<name>_sails' so the game can wave them as cloth; 1.5x real). Origin on the water
    line amidships; the bow is +X."""
    b = Builder(name, seed)
    rise_s, rise_b = (5.2, 2.2) if sea else (3.4, 1.5)
    P = hull_loft(b, L, B, D, 1.6 if sea else 1.1, rise_s, rise_b)
    m = P.shape[1]
    for side in (0, m - 1):
        path = [P[i, side] + [0, 0.12 * np.sign(P[i, side][1]), -0.35] for i in range(P.shape[0])]
        b.tube(path, 0.18, 5, "lacquer")
    # the stern castle and deckhouse
    sx = -L / 2 + 0.16 * L
    ds = D + rise_s * 0.5
    b.box((sx, 0, ds + 1.1), (0.24 * L, B * 0.55, 2.2), "timber", grain=0)
    troof(b, (sx, 0, ds + 2.2), 0.14 * L, B * 0.36, 1.5, 0.45, 0.25, 0.2, p=1.3, gilt=False, ns=8, nt=3, hooks=False)
    b.box((-L / 2 - 0.4, 0, D * 0.5), (0.5, 0.35, D * 1.8), "timber", grain=2)          # rudder
    b.box((-L / 2 - 0.9, 0, -0.4), (1.2, 0.3, 1.6), "timber", grain=0)
    b.box((L / 2 * 0.65, 0, D + 0.4), (L * 0.12, B * 0.4, 0.8), "plank", grain=0)        # forehatch
    s = Builder(name + "_sails", seed + 1)
    for k, (mx, mh, sw, nb, rake) in enumerate(masts):
        z0 = D + 0.2
        b.tube([(mx, 0, z0 - 0.5), (mx + rake * mh, 0, z0 + mh)], [0.32, 0.18], 7, "timber")
        b.lathe([(0.25, 0), (0.0, 0.5)], 6, "lacquer", base=(mx + rake * mh, 0, z0 + mh))
        junk_sail(s, (mx + 0.2, 0.0, z0 + 1.2 + 0.05 * mh), mh * 0.86, sw, nb, rake=rake, seed_off=k)
    b.empty("anchor_mooring_bow", (L / 2, 0, D))
    b.empty("anchor_mooring_stern", (-L / 2, 0, D + rise_s))
    b.collider("deck", [[(-L / 2 + 1, -B * 0.35, D), (L / 2 - 1, -B * 0.35, D), (L / 2 - 1, B * 0.35, D),
                         (-L / 2 + 1, B * 0.35, D)]])
    return b, s


def market_barge(name="vt_market_barge", seed=481):
    """VT the Rain Market barge: a flat plank barge 14 x 5 m with raised ends, stall counters, baskets of fruit and jars;
    an awning (vt_awning_*) stands on it at anchor_awning. Origin on the water line amidships."""
    b = Builder(name, seed)
    hull_loft(b, 14.0, 5.0, 0.9, 0.5, 0.5, 0.6, key="plank", n=10)
    rng = b.rng
    for x in (-3.5, 3.0):
        b.box((x, -1.4, 1.45), (3.4, 1.0, 1.1), "timber", grain=0)
        for k in range(3):
            c = (x - 1.1 + 1.1 * k, -1.4, 2.0)
            b.lathe([(0.0, 0.0), (0.38, 0.05), (0.45, 0.3)], 8, "weave", base=c, cap_top=False)
            for f in range(5):
                b.pebble((c[0] + rng.normal(0, 0.14), c[1] + rng.normal(0, 0.14), c[2] + 0.28 + 0.05 * f),
                         (0.13, 0.13, 0.12), "jar" if k != 1 else "cloth_ochre", segs=5, rings=3)
    for k in range(4):
        b.lathe([(0.0, 0.0), (0.25, 0.03), (0.36, 0.3), (0.3, 0.6), (0.18, 0.75)], 8, "jar",
                base=(-0.8 + 0.6 * k, 1.3, 0.9), cap_top=False)
    b.empty("anchor_awning", (0.0, 0.0, 0.9))
    b.empty("anchor_lantern", (5.5, 0, 3.0))
    b.collider("deck", [[(-6, -2.0, 0.9), (6, -2.0, 0.9), (6, 2.0, 0.9), (-6, 2.0, 0.9)]])
    return b, 2.5, {}


def awning(name, key, W=6.0, D=4.6, H=3.4, seed=491):
    """The Rain Market's oiled-cloth awning bay: four bamboo poles, a sagging canopy with a scalloped valance, guy ropes;
    madder or ochre. Pin weight in COLOR_0.a (0 at the poles). Origin on the ground (or deck) at the centre."""
    b = Builder(name, seed)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.tube([(sx * W / 2, sy * D / 2, 0.0), (sx * W / 2, sy * D / 2, H + (0.6 if sy > 0 else 0.0))], 0.07, 6,
                   "bamboo")
    nx, ny = 8, 6
    P = np.zeros((ny + 1, nx + 1, 3))
    M = np.zeros((ny + 1, nx + 1))
    for i in range(ny + 1):
        for j in range(nx + 1):
            u, v = j / nx, i / ny
            x, y = (u - 0.5) * (W + 0.6), (v - 0.5) * (D + 0.6)
            sag = 0.35 * math.sin(math.pi * u) * math.sin(math.pi * v)
            P[i, j] = (x, y, H + 0.6 * v - sag)
            M[i, j] = min(1.0, 2.2 * min(u, 1 - u, v, 1 - v) + 0.2)
    b.grid(P, key, smooth=True, M=M)
    for j in range(nx):                              # the valance: a scalloped drop on the front
        x0, x1 = P[0, j][0], P[0, j + 1][0]
        z = P[0, j][2]
        b.face([(x0, P[0, j][1], z), (x1, P[0, j][1], z), (x1, P[0, j][1], z - 0.45), ((x0 + x1) / 2, P[0, j][1], z - 0.6),
                (x0, P[0, j][1], z - 0.45)], key, mask=[0.6] * 5)
    for sx in (-1, 1):
        b.tube([(sx * W / 2, -D / 2, H), (sx * (W / 2 + 1.4), -D / 2 - 1.4, 0.0)], 0.02, 3, "rope", caps=False)
    return b, H + 0.8, {"cloth": key}


# ================================================================================================ VT6 the archive walls
def archive_wall(name="vt_archive_wall", L=10.0, gauge=False, seed=501):
    """VT6 a two-age wall module: huge dark old blocks (2-3 m, tight joints) from the canal bed to +7, then new pale
    plaster with a timber band, barred windows and a tiled coping; a green-black silt line in vertex colour; the gauge
    variant carries a bronze water gauge cut with tallies (marks, never numerals). Origin on the water line at the
    face's centre; the wall runs along X."""
    b = Builder(name, seed)
    block(b, -L / 2, L / 2, -0.4, 3.0, -2.0, 7.0, "ashlar_old", chamfer=0.25)
    block(b, -L / 2 + 0.2, L / 2 - 0.2, -0.1, 2.6, 7.0, 7.4, "ashlar_old", chamfer=0.05)
    vk.wall(b, (-L / 2 + 0.25, 0.05), (L / 2 - 0.25, 0.05), 7.4, 4.4, key="plaster", thick=0.5,
            openings=[(L * 0.3, 0.9, 1.6, 2.8, "window"), (L * 0.7, 0.9, 1.6, 2.8, "window")])
    b.box((0, 2.0, 9.6), (L - 0.5, 3.6, 4.4), "plaster", grain=0)
    b.box((0, -0.25, 9.0), (L - 0.3, 0.25, 0.35), "timber", grain=0)
    troof(b, (0, 1.3, 11.8), L / 2 + 0.3, 2.0, 1.2, 0.35, 0.2, 0.25, p=1.2, gilt=False, ns=10, nt=3, hooks=False,
          curls=False)
    if gauge:
        b.box((L * 0.18, -0.48, 2.5), (0.5, 0.12, 9.0), "bronze", grain=2)
        for k in range(18):
            zz = -1.5 + 0.5 * k
            wl = 0.5 if k % 4 == 0 else 0.28
            b.box((L * 0.18 - 0.12 + wl / 2, -0.56, zz), (wl, 0.06, 0.08), "iron", grain=0)
    b.empty("anchor_lamp", (L * 0.42, -0.6, 8.6))
    return b, 13.2, {"silt": 2.2, "gauge": gauge}


# ================================================================================================ night and the quay props
def lantern_net(name="vt_lantern_net", L=10.0, n=10, seed=511):
    """The Seventh Tide's lantern net: a rope sagging over a canal with a knotted net under it and ten low round
    lanterns (paper, emissive at night). About 200 triangles. Origin at the rope's start; it ends at (L, 0, 0)."""
    b = Builder(name, seed)
    sag = L / 12
    pts = [np.array([L * t, 0.0, -4 * sag * t * (1 - t)]) for t in np.linspace(0, 1, 9)]
    b.tube(pts, 0.04, 3, "rope", caps=False)
    net = []
    for k in range(9):
        t = (k + 0.5) / 9
        net.append(np.array([L * t, 0.0, -4 * sag * t * (1 - t) - (0.45 if k % 2 else 0.15)]))
    b.tube([pts[0]] + net + [pts[-1]], 0.02, 3, "rope", caps=False)
    for k in range(n):
        t = (k + 0.5) / n
        c = np.array([L * t, 0.0, -4 * sag * t * (1 - t) - 0.65])
        b.lathe([(0.12, 0.28), (0.36, 0.0), (0.12, -0.3)], 5, "paper", base=c, cap_top=True, cap_bottom=True)
    return b, 0.2, {"span_m": L, "lanterns": n, "emission_key": "paper"}


def door_lamp(name="vt_door_lamp", seed=521):
    """The Seventh Tide's blue-oil doorway lamp (story #1: every doorway along the canal burns blue): an iron bracket,
    a bronze bowl and a glass chimney (oil_glass, emission #8fc8ff at night). Origin at the wall mount."""
    b = Builder(name, seed)
    b.beam((0, 0, 0), (0, -0.55, 0.0), 0.05, 0.05, "iron")
    b.beam((0, 0, -0.35), (0, -0.5, 0.0), 0.04, 0.04, "iron")
    b.lathe([(0.0, -0.1), (0.2, -0.05), (0.24, 0.08)], 6, "bronze", base=(0, -0.62, -0.15), cap_top=False)
    b.lathe([(0.12, 0.0), (0.14, 0.18), (0.08, 0.38), (0.0, 0.42)], 6, "oil_glass", base=(0, -0.62, -0.07))
    return b, 0.5, {"emission_key": "oil_glass"}


def notice_board(name="vt_notice_board", seed=531):
    """VT the grain office's notice board: two posts, a plank board with a tiled hood, the sheets (blank: notice text is
    drawn at run time in the approved OFL font, never baked; official sheets carry the court mark). Origin on the
    ground at the board's centre."""
    b = Builder(name, seed)
    for x in (-1.5, 1.5):
        b.box((x, 0, 1.4), (0.22, 0.22, 2.8), "timber", grain=2)
    b.box((0, 0.02, 1.75), (3.1, 0.12, 1.9), "timber", grain=0)
    b.face([(-1.4, -0.06, 0.9), (1.4, -0.06, 0.9), (1.4, -0.06, 2.6), (-1.4, -0.06, 2.6)], "notice",
           uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
    troof(b, (0, 0, 2.85), 1.9, 0.5, 0.45, 0.2, 0.1, 0.12, p=1.2, gilt=False, ns=6, nt=2, hooks=False, curls=False)
    return b, 3.4, {}


# ================================================================================================ build, bake, export
# (name, builder call, AO distance, LOD1 target or None, budget text from places_se.md 1, group, export?)
def pieces_list():
    L = []

    def add(name, fn, ao=2.0, lod1=None, budget="", group="", export=True, ground=True):
        L.append(dict(name=name, fn=fn, ao=ao, lod1=lod1, budget=budget, group=group, export=export, ground=ground))

    add("lock_chamber_wall", lambda: lock_chamber_wall(), 3.0, 500, "1-2k / 500 (shared lock kit block-in)", "lock")
    add("lock_gate_tower", lambda: lock_gate_tower(), 3.0, 1200, "4-6k / 1.2k", "lock")
    add("lock_gate_leaf_pair", lambda: lock_gate_leaf_pair(), 3.0, 800, "2-3k / 800 (block-in)", "lock")
    add("lock_gate_leaf_pair_open", lambda: lock_gate_leaf_pair("lock_gate_leaf_pair_open", open_=True), 3.0, 800,
        "2-3k / 800 (block-in)", "lock")
    add("lock_winch_wheel", lambda: lock_winch_wheel(), 1.5, 400, "1-1.5k / 400 (block-in)", "lock", ground=False)
    add("lock_sluice_port", lambda: lock_sluice_port(), 1.5, None, "300-600 (block-in)", "lock")
    add("lock_gate_gallery", lambda: lock_gate_gallery(), 2.0, 500, "1.5-2.5k / 500 (block-in)", "lock", ground=False)
    add("vt_court_tower", lambda: court_tower("vt_court_tower", "A"), 4.0, 3000, "10-14k / 3k / card", "court")
    add("vt_court_tower_B", lambda: court_tower("vt_court_tower_B", "B"), 4.0, None, "variant (review only)", "court",
        export=False)
    add("vt_court_tower_C", lambda: court_tower("vt_court_tower_C", "C"), 4.0, None, "variant (review only)", "court",
        export=False)
    for k in (1, 2, 3):
        add("vt_court_terrace_%d" % k, (lambda k=k: court_terrace("vt_court_terrace_%d" % k)), 4.0, 1000,
            "3-5k / 1k each", "court")
    add("vt_court_banner", lambda: court_banner(), 1.0, 80, "300 / 80", "court", ground=False)
    for v in ("b", "c"):
        add("vt_court_banner_" + v, (lambda v=v: court_banner("vt_court_banner_" + v, "banner_court_" + v)), 1.0, None,
            "variant (review only)", "court", export=False, ground=False)
    add("vt_lacquer_tower", lambda: lacquer_tower(), 3.0, 1500, "5-7k / 1.5k / 300", "district")
    for d in DISTRICTS:
        add("vt_district_banner_" + d, (lambda d=d: district_banner(d)), 1.0, 80, "200-400 / 80", "district")
    add("vt_quay_house_a", lambda: quay_house("vt_quay_house_a", 8.0, 7.0, [(3.4, "shop"), (2.8, "plaster")], 6.2, 1.3,
                                              0.9, 601), 2.0, 900, "3-5k / 900 / 150", "quay")
    add("vt_quay_house_b", lambda: quay_house("vt_quay_house_b", 9.0, 8.0, [(3.2, "plaster"), (2.8, "plaster"),
                                                                            (2.6, "plaster")], 7.2, 1.4, 1.0, 602,
                                              gallery=0), 2.0, 900, "3-5k / 900 / 150", "quay")
    add("vt_quay_house_c", lambda: quay_house("vt_quay_house_c", 4.6, 9.0, [(3.0, "plaster"), (2.6, "plaster")], 5.8,
                                              1.1, 0.8, 603, base_z=2.5, footing=0.6, water_door=True), 2.0, 900,
        "3-5k / 900 / 150", "quay")
    add("vt_quay_steps", lambda: quay_steps(), 2.0, None, "400-800", "quay")
    add("vt_quay_steps_patched", lambda: quay_steps("vt_quay_steps_patched", patched=True), 2.0, None, "400-800",
        "quay")
    add("vt_quay_wall_20m", lambda: quay_wall(), 2.0, None, "400-800", "quay")
    add("vt_drain_mouth", lambda: drain_mouth(), 1.5, None, "300", "quay")
    add("vt_high_bridge", lambda: high_bridge(), 3.0, 1500, "5-8k / 1.5k", "bridge")
    add("vt_high_bridge_closed", lambda: high_bridge("vt_high_bridge_closed", gate_open=False), 3.0, 1500,
        "5-8k / 1.5k", "bridge")
    add("vt_granary_hall", lambda: granary_hall(), 3.0, 1200, "4-6k / 1.2k", "piers")
    add("vt_pier_finger", lambda: pier_finger(), 2.0, None, "1-2k", "piers")
    add("vt_pier_finger_end", lambda: pier_finger("vt_pier_finger_end", end=True), 2.0, None, "1-2k", "piers")
    add("vt_treadwheel_crane", lambda: treadwheel_crane(), 2.0, 900, "3-4k / 900", "piers")
    add("vt_sacks_heap", lambda: sacks_heap(), 1.0, None, "500-1.5k", "piers")
    add("vt_crates_stack", lambda: crates_stack(), 1.0, None, "500-1.5k", "piers")
    add("vt_jars_cluster", lambda: jars_cluster(), 1.0, None, "500-1.5k", "piers")
    add("vt_junk_river", lambda: junk("vt_junk_river", 22.0, 6.0, 2.2,
                                      [(4.0, 15.0, 7.0, 6, 0.04), (-4.5, 11.0, 5.5, 5, 0.0)], 701), 2.0, 1500,
        "5-8k / 1.5k / card", "boats")
    add("vt_junk_sea", lambda: junk("vt_junk_sea", 30.0, 8.0, 3.0,
                                    [(11.0, 15.0, 6.0, 5, 0.12), (2.5, 24.0, 10.0, 8, 0.0), (-8.0, 17.0, 7.5, 6, 0.0)],
                                    702, sea=True), 2.0, 1500, "5-8k / 1.5k / card", "boats")
    add("vt_market_barge", lambda: market_barge(), 1.5, None, "1.5-2.5k", "boats")
    add("vt_awning_madder", lambda: awning("vt_awning_madder", "cloth_madder"), 1.5, None, "1.5-2.5k (with barge)",
        "boats")
    add("vt_awning_ochre", lambda: awning("vt_awning_ochre", "cloth_ochre", seed=492), 1.5, None,
        "1.5-2.5k (with barge)", "boats")
    add("vt_archive_wall", lambda: archive_wall(), 3.0, None, "1-2k per 10 m", "archive")
    add("vt_archive_wall_gauge", lambda: archive_wall("vt_archive_wall_gauge", gauge=True), 3.0, None,
        "1-2k per 10 m", "archive")
    add("vt_lantern_net", lambda: lantern_net(), 0.5, None, "200 per 10 lanterns", "night", ground=False)
    add("vt_door_lamp", lambda: door_lamp(), 0.4, None, "150", "night", ground=False)
    add("vt_notice_board", lambda: notice_board(), 1.0, None, "300", "quay")
    return L


def build_all(only=None):
    """Build every piece; returns {name: (object, info)}. AO is baked per piece; sails are a baked child mesh."""
    out = {}
    for spec in pieces_list():
        if only and spec["name"] not in only:
            continue
        res = spec["fn"]()
        sails = None
        if isinstance(res[1], Builder):           # a junk: (hull, sails)
            b, s = res
            h, info = 0.0, {}
            sails = s
        else:
            b, h, info = res
        ob = b.obj()
        vtkit.bake_vertex_ao(ob, dist=spec["ao"], ground=spec["ground"])
        if "silt" in info:
            vtkit.silt_line(ob, info["silt"])
        if "streak" in info:
            x0, x1, z = info["streak"]
            vtkit.silt_line(ob, z, xr=(x0, x1), below=(0.6, 0.72, 0.6))
        if sails is not None:
            so = sails.obj()
            vtkit.bake_vertex_ao(so, dist=1.0, ground=False)
            so.parent = ob
            h = max(c[2] for c in so.bound_box)
            info["sails_child"] = so.name
            info["sails_tris"] = vtkit.tri_count(so)
        info = {k: v for k, v in info.items() if k not in ("silt", "streak")}
        info.update(height=round(float(h), 2), budget=spec["budget"], group=spec["group"], export=spec["export"],
                    lod1_target=spec["lod1"])
        out[spec["name"]] = (ob, info)
        print("VANTHUY built %-30s tris=%6d" % (spec["name"], vtkit.tri_count(ob)))
    return out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--blend", default="")
    ap.add_argument("--only", default="")
    a = ap.parse_args(argv)
    run(a.out, a.blend, a.only)


def run(out, blend="", only_csv=""):
    """Build, bake and export the kit into `out` (render_vanthuy.py --build calls this too, so one Blender session
    under the shared lock can build and then render)."""
    a = argparse.Namespace(out=out, blend=blend, only=only_csv)
    os.makedirs(a.out, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    only = set(filter(None, a.only.split(",")))
    pieces = build_all(only or None)
    manifest = {"_about": "Thủy Vân Vạn Thủy kit (VANTHUY: vt_* pieces; lock_* = the first block-in pieces of the ONE "
                          "shared lock kit for Phase 3 M2, at the Fifth Lock's scale; Vạn Thủy places them x%.1f). Units "
                          "metres; Blender Z up exported glTF +Y up; a piece's front faces Blender -Y = Godot +Z. "
                          "COLOR_0 = baked AO x top light (multiply into albedo; silt lines darken it under the water "
                          "line); COLOR_0.a = cloth pin weight on cloth, 1 elsewhere. Materials tvvt_<key>: see "
                          "tools/thuyvan_art/vanthuy/materials.json. Emission keys (paper, oil_glass) are off by day."
                          % VT_SCALE,
                "vt_scale_for_lock_pieces": VT_SCALE,
                "materials": {
                    vtkit.PREFIX + k: {"texture": "res://assets/thuyvan/vanthuy/textures/%s.png" % k,
                                       "uv_tile_m": (None if v.get("unit_uv") else v["tile_m"]),
                                       "roughness": v["rough"], "specular": v["spec"],
                                       "emission": v.get("emission"),
                                       "double_sided": k in vtkit.DOUBLE_SIDED,
                                       "cloth": k.startswith(("banner_", "cloth_")) or k == "sail"}
                    for k, v in vtkit.MATS.items() if not v.get("variant")},
                "pieces": {}}
    for nm, (ob, info) in sorted(pieces.items()):
        dims = [round(float(v), 2) for v in ob.dimensions]
        info.update({"tris": vtkit.tri_count(ob), "materials": sorted({m.name for m in ob.data.materials}),
                     "size_m_xyz_blender": dims,
                     "anchors": {ch.name: [round(v, 3) for v in ch.location] for ch in ob.children if ch.type == "EMPTY"},
                     "colliders": [ch.name for ch in ob.children if ch.type == "MESH" and "-colonly" in ch.name]})
        if info.get("export"):
            vtkit.export_glb(ob, os.path.join(a.out, nm + ".glb"))
            info["glb"] = nm + ".glb"
            if info.get("lod1_target"):
                l1 = vtkit.decimated(ob, info["lod1_target"], nm + "_lod1")
                for ch in list(l1.children):
                    if ch.type == "MESH" and "_sails" in ch.name:
                        md = ch.modifiers.new("lod", "DECIMATE")
                        md.ratio = 0.5
                vtkit.export_glb(l1, os.path.join(a.out, nm + "_lod1.glb"))
                info["tris_lod1"] = vtkit.tri_count(l1)
                info["lod1"] = nm + "_lod1.glb"
                l1.hide_render = True
                l1.hide_viewport = True
                for ch in l1.children:
                    ch.hide_render = True
        manifest["pieces"][nm] = info
        print("VANTHUY %-30s tris=%6d lod1=%s  %s" % (nm, info["tris"], info.get("tris_lod1"), info["budget"]))
    mp = os.path.join(a.out, "manifest.json")
    if only and os.path.exists(mp):
        old = json.load(open(mp))
        old["pieces"].update(manifest["pieces"])
        manifest = old
    with open(mp, "w") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
    if a.blend:
        bpy.ops.wm.save_as_mainfile(filepath=a.blend)
    print("VANTHUY DONE")


if __name__ == "__main__":
    main()
