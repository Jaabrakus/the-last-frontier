"""The Thủy Vân village kit (VILLAGE: V01-V15 of look/vista_spec.md), authored procedurally in Blender for R1, the Đá
Trắng reach under the Two Heights (Mountain Folk / Stone Children borderland). Our own designs after the Trường Sơn
concept sheet (stilt and cliff houses with fat upturned roofs, hanging rope bridges with banners and rag flags, the clan
waystone); nothing copied from any game or show. Run headless (through the shared lock wrapper):

    zsh blender_run.sh -b -P tools/thuyvan_art/village/village_kit.py -- --out assets/thuyvan/village [--blend X.blend]

Paint the textures first (paint_village.py). Writes into --out one GLB per piece (+Y up; Blender -Y = Godot +Z = the
piece's front; origin on the ground unless noted), and manifest.json (triangles, material keys, sizes, anchors, the
rope bridge's deck curves). Materials are tvv_<key> (materials.json); the colour attribute COLOR_0 is baked AO x top
light (multiply it into albedo); its alpha is the cloth pin weight (0 pinned .. 1 free) on cloth, 1 elsewhere.
"""

import argparse
import json
import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tvkit  # noqa: E402
from tvkit import Builder, frame_from, rot_x, rot_y, rot_z  # noqa: E402


# ================================================================================================ roofs
def roof(b, c, A, B, H, top="tile", under="timber", p=1.5, upturn=0.5, flare=0.35, thick=0.3, ridge=True,
         ridge_r=0.16, hips=True, horns=None, curls=False, finial=False, ns=12, nt=6, ridge_key=None):
    """A hip roof centred c (eave level), half sizes A (along X, the ridge) >= B, H to the ridge: four panels with a
    slope profile t**p (p > 1 concave like tile, p < 1 full like thatch), eave corners turned up `upturn` and flared out
    `flare`, `thick` deep at the rim. horns: 'crossed' (Mountain Folk gable horns) ; curls: curled ridge ends."""
    c = np.asarray(c, float)
    rl = max(A - B, 0.0)
    slope_len = math.hypot(B, H)
    rk = ridge_key or top

    def pt(E, Rg, sgn, s, t):
        w = abs(s) ** 4 * (1 - t) ** 2
        q = E * (1 - t) + Rg * t
        z = H * (t ** p) + upturn * w
        return c + np.array([q[0] + sgn[0] * flare * w, q[1] + sgn[1] * flare * w, z])

    panels = []
    for side in range(4):
        S = np.linspace(-1, 1, ns + 1)
        T = np.linspace(0, 1, nt + 1)
        P = np.zeros((nt + 1, ns + 1, 3))
        U = np.zeros((nt + 1, ns + 1))
        V = np.zeros((nt + 1, ns + 1))
        for i, t in enumerate(T):
            for j, s in enumerate(S):
                if side == 0:      # front (-Y)
                    E, Rg, sg, ul = np.array([s * A, -B]), np.array([s * rl, 0]), (np.sign(s), -1), s * A
                elif side == 2:    # back (+Y)
                    E, Rg, sg, ul = np.array([-s * A, B]), np.array([-s * rl, 0]), (-np.sign(s), 1), s * A
                elif side == 1:    # +X end
                    E, Rg, sg, ul = np.array([A, s * B]), np.array([rl, 0]), (1, np.sign(s)), s * B
                else:              # -X end
                    E, Rg, sg, ul = np.array([-A, -s * B]), np.array([-rl, 0]), (-1, -np.sign(s)), s * B
                P[i, j] = pt(E, Rg, sg, s, t)
                U[i, j] = ul * (1 - 0.0 * t)
                V[i, j] = t * slope_len
        panels.append((P, U, V))
        b.grid(P, top, U, V, smooth=True, flip=True)
        Pu = P.copy()
        Pu[..., 2] -= thick
        b.grid(Pu, under, U, V, smooth=True)
        # the rim along this panel's eave
        for j in range(ns):
            b.face([P[0, j], P[0, j + 1], Pu[0, j + 1], Pu[0, j]], under)
    zr = c[2] + H
    if ridge and rl > 0.05:
        b.tube([c + [-rl - 0.1, 0, H + ridge_r * 0.4], c + [rl + 0.1, 0, H + ridge_r * 0.4]], ridge_r, 8, rk)
    if hips:
        for (P, U, V) in panels[::2]:
            for j in (0, -1):
                path = [P[i, j] + [0, 0, ridge_r * 0.35] for i in range(P.shape[0])]
                rad = [ridge_r * (0.7 + 0.3 * i / (len(path) - 1)) for i in range(len(path))]
                b.tube(path, rad, 6, rk)
    if horns == "crossed" and rl > 0.05:
        # Mountain Folk gable horns: two boards crossing over each ridge end, flaring out and up
        for sx in (-1, 1):
            for sy in (-1, 1):
                p0 = c + [sx * (rl - 0.1), sy * 0.55, H - 0.45]
                p1 = c + [sx * (rl + 0.35), -sy * 0.55, H + 1.05]
                b.beam(p0, p1, 0.09, 0.32, "timber", roll=0.0)
    if curls and rl > 0.05:
        for sx in (-1, 1):
            pts, rad = [], []
            for t in np.linspace(0.0, 1.0, 9):
                a = t * math.pi * 0.62          # a flick up and out (an open curl, never a closed loop)
                pts.append(c + [sx * (rl + 0.1 + 0.62 * math.sin(a)), 0.0, H + ridge_r + 0.7 * (1 - math.cos(a))])
                rad.append(ridge_r * 1.3 * (1.0 - 0.6 * t))
            b.tube(pts, rad, 8, rk)
    if finial:
        b.lathe([(0.24, 0.0), (0.16, 0.2), (0.3, 0.45), (0.16, 0.7), (0.06, 1.2), (0.0, 1.3)], 8, rk,
                base=c + [0, 0, H])
    return zr


# ================================================================================================ small parts
def post(b, x, y, z0, h, r=0.13, key="timber", lean=(0.0, 0.0), segs=6, footing=True):
    p0 = np.array([x, y, z0])
    p1 = p0 + [lean[0] * h, lean[1] * h, h]
    b.tube([p0, (p0 + p1) / 2, p1], r, segs, key)
    if footing:
        b.pebble((x, y, z0 + 0.05), (r * 2.6, r * 2.4, r * 1.6), "limestone", rot=rot_z(b.rng.uniform(0, 3)), segs=5,
                 rings=3)


def plank_deck(b, x0, x1, y0, y1, z, w=0.3, gap=0.035, thick=0.08, along="y", key="plank", jitter=0.012):
    """Planks with gaps; `along`: the planks' long axis."""
    rng = b.rng
    if along == "y":
        n = max(1, int((x1 - x0) / (w + gap)))
        ww = (x1 - x0) / n
        for k in range(n):
            x = x0 + (k + 0.5) * ww
            R = rot_x(rng.normal(0, 0.01)) @ rot_z(rng.normal(0, 0.008))
            b.box((x, (y0 + y1) / 2 + rng.normal(0, 0.03), z - thick / 2 + rng.normal(0, jitter)),
                  (ww - gap, y1 - y0 + rng.uniform(-0.06, 0.06), thick), key, rot=R, grain=1)
    else:
        n = max(1, int((y1 - y0) / (w + gap)))
        ww = (y1 - y0) / n
        for k in range(n):
            y = y0 + (k + 0.5) * ww
            R = rot_y(rng.normal(0, 0.01)) @ rot_z(rng.normal(0, 0.008))
            b.box(((x0 + x1) / 2 + rng.normal(0, 0.03), y, z - thick / 2 + rng.normal(0, jitter)),
                  (x1 - x0 + rng.uniform(-0.06, 0.06), ww - gap, thick), key, rot=R, grain=0)


def wall(b, p0, p1, z0, h, key="weave", thick=0.09, openings=(), frame="timber"):
    """A wall panel from p0 to p1 (plan points) between z0 and z0+h, with openings [(at_m, width, bottom, top, kind)]
    (kind 'door' or 'window'); timber posts at its ends and a sill/top rail."""
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    d = p1 - p0
    L = float(np.linalg.norm(d))
    ux = d / L
    R = frame_from(np.array([ux[0], ux[1], 0.0]))
    nrm = np.array([-ux[1], ux[0]])        # left of the run (plan)

    def piece(a0, a1, zb, zt):
        if a1 - a0 < 0.02 or zt - zb < 0.02:
            return
        cpt = np.array([*(p0 + ux * (a0 + a1) / 2), z0 + (zb + zt) / 2])
        b.box(cpt, (a1 - a0, thick, zt - zb), key, rot=R, grain=0)

    cuts = sorted(openings)
    a = 0.0
    for (at, w, zb, zt, kind) in cuts:
        piece(a, at - w / 2, 0, h)
        piece(at - w / 2, at + w / 2, 0, zb)
        piece(at - w / 2, at + w / 2, zt, h)
        cpt = p0 + ux * at
        # frame round the opening
        for e in (-1, 1):
            q = np.array([*(cpt + ux * e * (w / 2 + 0.06)), z0 + (zb + zt) / 2])
            b.box(q, (0.12, thick + 0.08, zt - zb + 0.12), frame, rot=R, grain=2)
        b.box(np.array([*cpt, z0 + zt + 0.06]), (w + 0.36, thick + 0.1, 0.13), frame, rot=R, grain=0)
        if kind == "door":
            q = np.array([*(cpt + nrm * 0.0), z0 + (zb + zt) / 2])
            b.box(q - [*(nrm[:2] * 0.0), 0], (w, 0.05, zt - zb), "plank", rot=R, grain=2)
        else:
            b.box(np.array([*cpt, z0 + zb - 0.05]), (w + 0.3, thick + 0.12, 0.1), frame, rot=R, grain=0)
            b.box(np.array([*cpt, z0 + (zb + zt) / 2]), (w, 0.03, zt - zb), "iron", rot=R, grain=0)
            for k in range(3):
                q = np.array([*(cpt + ux * (k - 1) * w / 3.2), z0 + (zb + zt) / 2])
                b.box(q, (0.06, thick + 0.02, zt - zb), "bamboo", rot=R, grain=2)
        a = at + w / 2
    piece(a, L, 0, h)
    for e in (0.0, L):
        q = np.array([*(p0 + ux * e), z0 + h / 2])
        b.box(q, (0.18, thick + 0.1, h), frame, rot=R, grain=2)
    b.box(np.array([*(p0 + ux * L / 2), z0 + h - 0.06]), (L + 0.1, thick + 0.1, 0.14), frame, rot=R, grain=0)
    b.box(np.array([*(p0 + ux * L / 2), z0 + 0.07]), (L + 0.1, thick + 0.1, 0.14), frame, rot=R, grain=0)


def framed_plaster_wall(b, p0, p1, z0, h, openings=()):
    wall(b, p0, p1, z0, h, key="plaster", thick=0.14, openings=openings)
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    d = p1 - p0
    L = float(np.linalg.norm(d))
    ux = d / L
    R = frame_from(np.array([ux[0], ux[1], 0.0]))
    b.box(np.array([*(p0 + ux * L / 2), z0 + h * 0.55]), (L, 0.2, 0.12), "timber", rot=R, grain=0)


def ladder(b, p_ground, p_top, width=0.5, key="bamboo"):
    p0, p1 = np.asarray(p_ground, float), np.asarray(p_top, float)
    d = p1 - p0
    side = np.cross(d, [0, 0, 1])
    side = side / np.linalg.norm(side) * width / 2
    for s in (-1, 1):
        b.tube([p0 + s * side, p1 + s * side + d * 0.08], 0.045, 6, key)
    n = int(np.linalg.norm(d) / 0.32)
    for k in range(1, n):
        q = p0 + d * k / n
        b.tube([q - side * 1.15, q + side * 1.15], 0.03, 5, key)


def lantern_round(b, c, r=0.32, h=0.7, cord=0.0):
    c = np.asarray(c, float)
    prof = []
    for k in range(9):
        t = k / 8.0
        prof.append((r * (0.55 + 0.45 * math.sin(math.pi * (0.06 + 0.88 * t))), -h / 2 + t * h))
    b.lathe(prof, 10, "paper", base=c, cap_top=False, cap_bottom=False, ribs=0.06)
    b.lathe([(r * 0.5, -h / 2 - 0.07), (r * 0.6, -h / 2 + 0.02)], 10, "timber", base=c)
    b.lathe([(r * 0.6, h / 2 - 0.02), (r * 0.48, h / 2 + 0.08)], 10, "timber", base=c)
    b.tube([c + [0, 0, -h / 2 - 0.07], c + [0, 0, -h / 2 - 0.42]], [0.05, 0.015], 5, "cloth_madder")
    if cord > 0:
        b.tube([c + [0, 0, h / 2 + 0.08], c + [0, 0, h / 2 + 0.08 + cord]], 0.015, 4, "rope")


def lantern_barrel(b, c, r=0.26, h=0.85, cord=0.0):
    c = np.asarray(c, float)
    prof = [(r * 0.86, -h / 2), (r, -h / 4), (r * 1.02, 0), (r, h / 4), (r * 0.86, h / 2)]
    b.lathe(prof, 10, "paper", base=c, cap_top=False, cap_bottom=False, ribs=0.04)
    for z in (-h / 2, h / 2):
        b.lathe([(r * 0.92, z - 0.04), (r * 0.92, z + 0.04)], 10, "lacquer", base=c)
    b.tube([c + [0, 0, -h / 2 - 0.04], c + [0, 0, -h / 2 - 0.36]], [0.045, 0.012], 5, "cloth_madder")
    if cord > 0:
        b.tube([c + [0, 0, h / 2 + 0.04], c + [0, 0, h / 2 + 0.04 + cord]], 0.015, 4, "rope")


def cloth_sheet(b, top_c, width, length, key, notch=0.0, waves=2, amp=0.06, yaw_ax=0, unit=True, sway=0.0,
                ragged=0.0, cols=6, rows=14, uv=(0.0, 1.0)):
    """A hanging cloth in the XZ plane (faces -Y): top edge centred at top_c; `notch` cuts a swallowtail into the hem;
    unit UVs (u across uv[0]..uv[1], v 1 at the top); mask = pin weight (0 at the top, 1 at the hem)."""
    top_c = np.asarray(top_c, float)
    P = np.zeros((rows + 1, cols + 1, 3))
    U = np.zeros((rows + 1, cols + 1))
    V = np.zeros((rows + 1, cols + 1))
    M = np.zeros((rows + 1, cols + 1))
    for j in range(cols + 1):
        s = j / cols
        Lj = length - notch * (1 - abs(2 * s - 1))
        if ragged:
            Lj -= ragged * b.rng.uniform(0, 1) * (j not in (0, cols))
        for i in range(rows + 1):
            t = i / rows
            z = -t * Lj
            x = (s - 0.5) * width
            y = amp * math.sin(2 * math.pi * waves * s + 1.3 * t) * (0.3 + 0.7 * t) + sway * t * t
            P[i, j] = top_c + [x, y, z]
            U[i, j] = uv[0] + (uv[1] - uv[0]) * s
            V[i, j] = 1.0 - t * Lj / length
            M[i, j] = t * Lj / length
    b.grid(P, key, U, V, smooth=True, unit=unit, M=M)


def banner(b, kind="indigo", h=6.6, cloth_w=1.2, cloth_l=3.6, base=True):
    """V07: pole, crossbar, a 1:3 cloth with our clan mark, madder tails, a spear finial; origin at the pole foot."""
    rng = b.rng
    post(b, 0, 0, 0, h, r=0.085, key="timber", footing=False)
    b.lathe([(0.1, 0), (0.06, 0.12), (0.11, 0.3), (0.0, 0.75)], 6, "iron", base=(0, 0, h))
    zc = h - 0.35
    b.beam((-cloth_w / 2 - 0.3, -0.12, zc), (cloth_w / 2 + 0.3, -0.12, zc), 0.08, 0.1, "timber")
    b.tube([(-cloth_w / 2 - 0.2, -0.12, zc + 0.05), (0, -0.05, h - 0.05), (cloth_w / 2 + 0.2, -0.12, zc + 0.05)],
           0.018, 4, "rope")
    cloth_sheet(b, (0, -0.2, zc - 0.05), cloth_w, cloth_l, "banner_" + kind, notch=0.55, amp=0.07, rows=9, cols=4)
    for sx in (-1, 1):
        cloth_sheet(b, (sx * (cloth_w / 2 + 0.22), -0.17, zc - 0.05), 0.2, cloth_l * 0.78 + rng.uniform(-0.2, 0.2),
                    "cloth_madder", notch=0.12, amp=0.04, waves=1, rows=10, cols=2, unit=False,
                    sway=rng.uniform(-0.15, 0.15))
    if base:
        for k in range(5):
            a = k * 2 * math.pi / 5 + rng.uniform(-0.3, 0.3)
            b.pebble((0.32 * math.cos(a), 0.32 * math.sin(a), 0.12), (0.26, 0.22, 0.2), "limestone",
                     rot=rot_z(rng.uniform(0, 3)))


def flag_rope(b, p0, p1, sag=None, spacing=0.55, rope_r=0.022, seed_offset=0, flag=(0.30, 0.45)):
    """V08: a rope from p0 to p1 sagging `sag` (default 1/12 of the span) carrying ragged 30 x 45 cm flags (the flags
    atlas: indigo, madder, ochre, bone, jade)."""
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    L = float(np.linalg.norm(p1 - p0))
    sag = L / 12.0 if sag is None else sag
    n = max(6, int(L / 0.6))
    pts = [p0 + (p1 - p0) * t - [0, 0, 4 * sag * t * (1 - t)] for t in np.linspace(0, 1, n + 1)]
    b.tube(pts, rope_r, 4, "rope", caps=False)
    d = (p1 - p0) / L
    side = np.array([d[0], d[1], 0.0])
    if np.linalg.norm(side) < 1e-6:
        side = np.array([1.0, 0, 0])
    side /= np.linalg.norm(side)
    nf = int((L - 0.4) / spacing)
    rng = b.rng
    for k in range(nf):
        t = (0.2 + (k + 0.5) * spacing) / L
        c = p0 + (p1 - p0) * t - [0, 0, 4 * sag * t * (1 - t)]
        cell = (k + seed_offset) % 5
        w, h = flag
        yaw = math.atan2(side[1], side[0])
        R = rot_z(yaw + rng.normal(0, 0.12))
        rows, cols = 3, 2
        P = np.zeros((rows + 1, cols + 1, 3))
        U = np.zeros_like(P[..., 0])
        V = np.zeros_like(U)
        M = np.zeros_like(U)
        for j in range(cols + 1):
            s = j / cols
            hj = h * (1 - (rng.uniform(0.0, 0.22) if j == 1 else rng.uniform(0, 0.12)))
            for i in range(rows + 1):
                tt = i / rows
                local = np.array([(s - 0.5) * w, 0.04 * math.sin(3.0 * s + tt) + 0.06 * tt * tt * rng.uniform(-1, 1),
                                  -tt * hj])
                P[i, j] = c + R @ local
                U[i, j] = (cell + 0.04 + 0.92 * s) / 5.0
                V[i, j] = 1.0 - tt * hj / h * 0.95
                M[i, j] = tt
        b.grid(P, "flags", U, V, unit=True, M=M)


def pebble_pile(b, c, radius, n, key="limestone", height=0.9, size=(0.25, 0.45)):
    rng = b.rng
    c = np.asarray(c, float)
    for k in range(n):
        a = rng.uniform(0, 2 * math.pi)
        rr = radius * math.sqrt(rng.uniform(0, 1))
        z = height * (1 - rr / radius) * rng.uniform(0.5, 1.0)
        s = rng.uniform(*size)
        b.pebble(c + [rr * math.cos(a), rr * math.sin(a), z + s * 0.4], (s, s * rng.uniform(0.7, 1.0), s * 0.62), key,
                 rot=rot_z(rng.uniform(0, 3)) @ rot_x(rng.normal(0, 0.2)))


# ================================================================================================ V01 stilt houses
def stilt_house(name, W, D, pile_h, wall_h, roof_key, roof_H, over, ver, seed, rail=False, side_window=True,
                big=False, upturn=None, flare=None, roof_p=None):
    """V01: a Mountain Folk stilt house on piles (pile_h), walls wall_h, a fat hip roof roof_H tall overhanging `over`
    with crossed gable horns; `upturn`/`flare` override the roof's corner curve (the A/B/C roof lineup)."""
    b = Builder(name, seed)
    rng = b.rng
    fz = pile_h + 0.22                      # floor top
    yf = -D / 2 - ver                       # deck front edge
    # piles: a grid under body + veranda
    nx = 4 if W > 7 else 3
    xs = np.linspace(-W / 2 + 0.2, W / 2 - 0.2, nx)
    ys = [yf + 0.2] + list(np.linspace(-D / 2, D / 2 - 0.2, 3 if D > 5 else 2))
    for x in xs:
        for y in ys:
            post(b, x + rng.normal(0, 0.03), y, 0.0, fz - 0.16, r=0.14 if big else 0.13,
                 lean=(rng.normal(0, 0.012), rng.normal(0, 0.012)))
    for y in ys:
        b.beam((-W / 2 - 0.15, y, fz - 0.24), (W / 2 + 0.15, y, fz - 0.24), 0.2, 0.2, "timber")
    for x in xs:
        b.beam((x, yf - 0.1, fz - 0.42), (x, D / 2 + 0.1, fz - 0.42), 0.18, 0.18, "timber")
    # cross bracing between the piles (chunky, reads from far)
    for y in ys[1:]:
        b.beam((xs[0], y, 0.35), (xs[1], y, fz - 0.4), 0.09, 0.12, "timber")
    plank_deck(b, -W / 2 - 0.1, W / 2 + 0.1, yf, D / 2 + 0.05, fz, along="y")
    # walls
    door_w = 1.0
    wall(b, (-W / 2, -D / 2), (W / 2, -D / 2), fz, wall_h,
         openings=[(W / 2, door_w, 0, 2.0, "door")] + ([(W / 2 - 2.2, 0.8, 0.9, 1.6, "window"),
                                                        (W / 2 + 2.2, 0.8, 0.9, 1.6, "window")] if big else []))
    wall(b, (W / 2, -D / 2), (W / 2, D / 2), fz, wall_h,
         openings=[(D / 2, 0.8, 0.9, 1.6, "window")] if side_window else [])
    wall(b, (W / 2, D / 2), (-W / 2, D / 2), fz, wall_h)
    wall(b, (-W / 2, D / 2), (-W / 2, -D / 2), fz, wall_h,
         openings=[(D / 2, 0.8, 0.9, 1.6, "window")] if big else [])
    # veranda posts holding the eave, a rail on big houses
    for x in (-W / 2 + 0.15, W / 2 - 0.15):
        post(b, x, yf + 0.15, fz, wall_h + 0.2, r=0.11, footing=False)
    if rail:
        for x in np.linspace(-W / 2 + 0.15, W / 2 - 0.15, 7):
            if abs(x) < 0.8:
                continue
            post(b, x, yf + 0.12, fz, 0.95, r=0.05, key="bamboo", footing=False)
        for z in (0.5, 0.95):
            b.tube([(-W / 2 + 0.15, yf + 0.12, fz + z), (-0.8, yf + 0.12, fz + z)], 0.045, 6, "bamboo")
            b.tube([(0.8, yf + 0.12, fz + z), (W / 2 - 0.15, yf + 0.12, fz + z)], 0.045, 6, "bamboo")
    # tie beams on the wall tops
    ez = fz + wall_h + 0.12
    for y in (-D / 2, D / 2, yf + 0.15):
        b.beam((-W / 2 - 0.4, y, ez - 0.1), (W / 2 + 0.4, y, ez - 0.1), 0.18, 0.2, "timber")
    for x in (-W / 2, W / 2):
        b.beam((x, yf - 0.3, ez - 0.05), (x, D / 2 + 0.4, ez - 0.05), 0.18, 0.2, "timber")
    # the roof: 45-55 % of the height
    cy = (yf + D / 2) / 2
    A = W / 2 + over
    Bh = (D / 2 - yf) / 2 + over * 0.8
    if roof_key == "thatch":
        roof(b, (0, cy, ez), A, Bh, roof_H, top="thatch", under="thatch", p=roof_p or 0.92, upturn=0.55 if upturn is None else upturn,
             flare=0.3 if flare is None else flare, thick=0.42,
             ridge_r=0.26, hips=True, horns="crossed")
    else:
        roof(b, (0, cy, ez), A, Bh, roof_H, top=roof_key, under="timber", p=roof_p or 1.35, upturn=0.75 if upturn is None else upturn,
             flare=0.4 if flare is None else flare,
             thick=0.32, ridge_r=0.2, horns="crossed")
    # the ladder up to the veranda
    lx = W / 2 - 0.9 if big else -W / 4
    ladder(b, (lx, yf - 1.35, 0.0), (lx, yf - 0.05, fz), 0.55)
    # lanterns by the door, the smoke anchor under the eave
    lantern_round(b, (W / 2 * 0 + 0.95, yf + 0.2, ez - 0.75), cord=0.45)
    b.empty("anchor_smoke", (0, cy, ez + 0.2))
    b.empty("anchor_lantern_door", (0.95, yf + 0.2, ez - 0.75))
    b.empty("anchor_door", (0, -D / 2, fz))
    # firewood and a jar under the house
    for k in range(6):
        b.tube([(-W / 2 + 0.6 + k * 0.0, D / 2 - 0.6 - k % 3 * 0.24, 0.13 + (k // 3) * 0.22),
                (-W / 2 + 1.9, D / 2 - 0.6 - k % 3 * 0.24, 0.13 + (k // 3) * 0.22)], 0.11, 6, "timber")
    return b, ez + roof_H


# ================================================================================================ V02 cliff house
def cliff_house(name="cliff_house", seed=21):
    """Cantilevered over the gorge: the origin is on the lip line (land +Y, the drop -Y, the front faces the gorge).
    Floor at z 0.6; three beams carry it 4.5 m out; braces run down the wall to sockets 4.6 m below the lip."""
    b = Builder(name, seed)
    fz = 0.6
    # the land-side plinth of dry stone
    b.box((0, 1.6, -0.3), (7.4, 3.4, 1.8), "drystone", grain=0)
    for x in (-2.8, 0.0, 2.8):
        b.beam((x, 3.2, fz - 0.3), (x, -5.0, fz - 0.3), 0.36, 0.36, "timber")
        b.beam((x, -3.9, fz - 0.45), (x, 0.25, -4.6), 0.26, 0.26, "timber")
        b.beam((x, -2.0, fz - 0.45), (x, 0.25, -2.4), 0.2, 0.2, "timber")
        b.box((x, 0.55, -4.75), (0.9, 0.9, 0.7), "limestone")
        b.box((x, 0.5, -2.5), (0.6, 0.7, 0.5), "limestone")
    b.beam((-3.6, -4.6, fz - 0.2), (3.6, -4.6, fz - 0.2), 0.22, 0.22, "timber")
    b.beam((-3.6, -2.9, fz - 0.2), (3.6, -2.9, fz - 0.2), 0.22, 0.22, "timber")
    plank_deck(b, -3.5, 3.5, -4.75, 3.0, fz, along="y")
    # ground storey: framed plaster
    W, y0, y1 = 3.1, -2.9, 2.5
    h1 = 2.8
    framed_plaster_wall(b, (-W, y0), (W, y0), fz, h1, openings=[(W, 1.1, 0, 2.1, "door"), (1.0, 0.9, 1.0, 1.8, "window"),
                                                                (5.2, 0.9, 1.0, 1.8, "window")])
    framed_plaster_wall(b, (W, y0), (W, y1), fz, h1, openings=[(2.7, 0.9, 1.0, 1.8, "window")])
    framed_plaster_wall(b, (W, y1), (-W, y1), fz, h1)
    framed_plaster_wall(b, (-W, y1), (-W, y0), fz, h1, openings=[(2.7, 0.9, 1.0, 1.8, "window")])
    # balcony rail over the drop
    for x in np.linspace(-3.4, 3.4, 9):
        post(b, x, -4.65, fz, 1.05, r=0.07, footing=False)
    for z in (0.45, 1.0):
        b.beam((-3.45, -4.65, fz + z), (3.45, -4.65, fz + z), 0.1, 0.1, "timber")
    for sx in (-1, 1):
        b.beam((sx * 3.45, -4.65, fz + 1.0), (sx * 3.45, -2.9, fz + 1.0), 0.1, 0.1, "timber")
    for x in (-3.3, 3.3):
        post(b, x, -4.55, fz, h1 + 0.25, r=0.12, footing=False)
    # skirt roof over the ground storey and the balcony
    ez1 = fz + h1 + 0.1
    b.beam((-3.6, -4.55, ez1 - 0.12), (3.6, -4.55, ez1 - 0.12), 0.18, 0.2, "timber")
    roof(b, (0, -1.0, ez1), 4.6, 4.3, 1.5, top="tile", under="timber", p=1.6, upturn=0.65, flare=0.35, thick=0.3,
         ridge=False, ridge_r=0.15)
    # upper storey and the main roof (the tower-house silhouette of the sheet's cliff village)
    h2 = 2.4
    z2 = ez1 + 0.25
    wall(b, (-2.2, -1.9), (2.2, -1.9), z2, h2, key="plaster", thick=0.14,
         openings=[(1.1, 0.8, 0.7, 1.6, "window"), (3.3, 0.8, 0.7, 1.6, "window")])
    wall(b, (2.2, -1.9), (2.2, 1.6), z2, h2, key="plaster", thick=0.14, openings=[(1.75, 0.8, 0.7, 1.6, "window")])
    wall(b, (2.2, 1.6), (-2.2, 1.6), z2, h2, key="plaster", thick=0.14)
    wall(b, (-2.2, 1.6), (-2.2, -1.9), z2, h2, key="plaster", thick=0.14)
    ez2 = z2 + h2 + 0.1
    roof(b, (0, -0.15, ez2), 3.6, 3.0, 2.7, top="tile", under="timber", p=1.6, upturn=0.85, flare=0.45, thick=0.3,
         ridge_r=0.18, curls=True)
    for (x, y) in ((-4.0, -4.9), (4.0, -4.9)):
        lantern_round(b, (x, y, ez1 - 0.55), r=0.28, h=0.62, cord=0.4)
    lantern_barrel(b, (1.4, -3.1, fz + 2.2), cord=0.35)
    b.empty("anchor_smoke", (0, -0.15, ez2 + 0.3))
    b.empty("anchor_lantern_balcony_l", (-4.0, -4.9, ez1 - 0.55))
    b.empty("anchor_lantern_balcony_r", (4.0, -4.9, ez1 - 0.55))
    return b, ez2 + 2.7


# ================================================================================================ V03 clan house
def clan_house(name="clan_house", seed=31):
    b = Builder(name, seed)
    pz = 1.0
    b.box((0, 0, pz / 2 - 0.15), (13.0, 10.0, pz + 0.3), "drystone", grain=0)
    for k in range(3):     # front steps
        b.box((0, -5.0 - 0.38 * (k + 0.5), pz - 0.33 * (k + 1) + 0.16), (3.6, 0.42, 0.33), "limestone", grain=0)
    b.box((0, 0, pz + 0.04), (12.6, 9.6, 0.1), "plank", grain=0)
    # body
    W, D = 5.0, 3.4
    h = 3.6
    wall(b, (-W, -D), (W, -D), pz, h, key="plank", thick=0.14,
         openings=[(W - 3.0, 1.3, 0, 2.6, "door"), (W, 1.6, 0, 2.8, "door"), (W + 3.0, 1.3, 0, 2.6, "door")],
         frame="lacquer")
    wall(b, (W, -D), (W, D), pz, h, key="plank", thick=0.14, openings=[(D, 1.0, 1.2, 2.3, "window")])
    wall(b, (W, D), (-W, D), pz, h, key="plank", thick=0.14)
    wall(b, (-W, D), (-W, -D), pz, h, key="plank", thick=0.14, openings=[(D, 1.0, 1.2, 2.3, "window")])
    # the front veranda's red lacquer columns on stone drums
    for x in np.linspace(-5.4, 5.4, 6):
        b.lathe([(0.36, 0), (0.38, 0.12), (0.3, 0.32), (0.24, 0.4)], 10, "limestone", base=(x, -4.4, pz))
        b.cylinder((x, -4.4, pz + 0.38), 0.21, h + 0.3 - 0.38, 10, "lacquer")
    b.beam((-6.2, -4.4, pz + h + 0.2), (6.2, -4.4, pz + h + 0.2), 0.3, 0.34, "lacquer")
    # bracket blocks on the column heads
    for x in np.linspace(-5.4, 5.4, 6):
        b.box((x, -4.4, pz + h + 0.48), (0.7, 0.5, 0.22), "timber")
        b.box((x, -4.4, pz + h + 0.66), (0.4, 0.9, 0.16), "timber")
    ez1 = pz + h + 0.75
    roof(b, (0, -0.5, ez1), 7.3, 5.6, 1.9, top="tile", under="timber", p=1.6, upturn=0.9, flare=0.55, thick=0.34,
         ridge=False, ridge_r=0.18)
    # upper storey: plaster over a lacquer band, then the main roof with carved ridge, curls and a finial
    z2 = ez1 + 0.3
    h2 = 1.7
    for (p0, p1) in (((-3.8, -2.6), (3.8, -2.6)), ((3.8, -2.6), (3.8, 2.4)), ((3.8, 2.4), (-3.8, 2.4)),
                     ((-3.8, 2.4), (-3.8, -2.6))):
        framed_plaster_wall(b, p0, p1, z2, h2)
    ez2 = z2 + h2 + 0.12
    roof(b, (0, -0.1, ez2), 5.8, 3.9, 3.1, top="tile", under="timber", p=1.65, upturn=1.05, flare=0.65, thick=0.36,
         ridge_r=0.24, curls=True)
    b.lathe([(0.3, 0.0), (0.2, 0.25), (0.42, 0.55), (0.2, 0.9), (0.08, 1.5), (0.0, 1.62)], 8, "tile",
            base=(0, -0.1, ez2 + 3.1 + 0.2))
    # carved ridge panel: a pierced board along the ridge (the "carved ridge")
    b.box((0, -0.1, ez2 + 3.1 + 0.42), (3.6, 0.12, 0.34), "timber", grain=0)
    for x in np.linspace(-1.35, 1.35, 4):          # the board pierced: lacquer roundels between the cuts
        b.lathe([(0.16, -0.08), (0.16, 0.08)], 8, "lacquer", base=(x, -0.1, ez2 + 3.1 + 0.42), rot=rot_x(math.pi / 2))
    # the name board over the middle door (left blank: no writing in world art)
    b.box((0, -3.62, pz + 3.15), (2.4, 0.1, 0.62), "lacquer")
    b.box((0, -3.66, pz + 3.15), (2.1, 0.06, 0.44), "timber")
    for x in (-4.2, -1.6, 1.6, 4.2):
        lantern_round(b, (x, -5.6, ez1 - 0.2), r=0.34, h=0.74, cord=0.5)
    for sx in (-1, 1):
        with b.at((sx * 2.9, -6.3, 0.0)):
            banner(b, "indigo", h=6.8, base=True)
    b.empty("anchor_smoke", (0, 1.5, ez1 + 0.3))
    b.empty("anchor_door", (0, -3.4, pz))
    return b, ez2 + 3.1 + 1.8


# ================================================================================================ V04 gates
def gate_pavilion(name="gate_pavilion", seed=41):
    """The rope bridge's head gate: two posts 4.2 m, tie beams, bracket blocks, a tile hip roof, a lantern; the path
    runs along Y through it (origin on the ground at the middle of the opening)."""
    b = Builder(name, seed)
    for sx in (-1, 1):
        b.box((sx * 1.7, 0, 0.25), (0.8, 0.8, 0.5), "drystone")
        b.cylinder((sx * 1.7, 0, 0.5), 0.19, 4.0, 10, "timber")
        b.box((sx * 1.7, 0, 4.6), (0.5, 0.9, 0.2), "timber")
        # struts from the post up to the eave purlins
        for sy in (-1, 1):
            b.beam((sx * 1.7, 0, 3.4), (sx * 1.7, sy * 1.0, 4.5), 0.12, 0.12, "timber")
    b.beam((-2.4, 0, 4.1), (2.4, 0, 4.1), 0.24, 0.3, "timber")
    b.beam((-2.2, 0, 3.55), (2.2, 0, 3.55), 0.16, 0.2, "lacquer")
    for sy in (-1, 1):
        b.beam((-2.5, sy * 1.0, 4.62), (2.5, sy * 1.0, 4.62), 0.16, 0.18, "timber")
    # board with the clan's mark under the beam: the banner field (indigo) as a small plaque
    cloth_sheet(b, (0, -0.16, 3.42), 0.8, 0.9, "banner_indigo", notch=0.0, amp=0.0, rows=1, cols=1)
    roof(b, (0, 0, 4.72), 3.0, 1.75, 1.7, top="tile", under="timber", p=1.6, upturn=0.75, flare=0.45, thick=0.3,
         ridge_r=0.17, curls=True)
    lantern_round(b, (0, -0.45, 3.0), r=0.3, h=0.66, cord=0.45)
    b.box((0, 0, 0.08), (3.0, 0.5, 0.16), "timber")  # threshold log
    b.empty("anchor_lantern", (0, -0.45, 3.0))
    return b, 4.72 + 1.7 + 0.8


def arch_outline(w, h, hs, n=10):
    """A gate front: a w x h rectangle with a round-headed passage hs wide, cut up from the ground (a simple polygon)."""
    r = hs / 2
    spring = h * 0.55
    pts = [(-w / 2, 0), (-r, 0), (-r, spring)]
    for k in range(1, n):
        a = math.pi - math.pi * k / n
        pts.append((r * math.cos(a), spring + r * math.sin(a)))
    pts += [(r, spring), (r, 0), (w / 2, 0), (w / 2, h), (-w / 2, h)]
    return pts


def gate_tower(name="gate_tower", seed=42):
    """The Two Heights gate tower (Stone Children work under a Mountain Folk upper storey): a dressed-stone base with a
    round-headed passage along Y, a timber gallery, a tile roof with curled ridge ends."""
    b = Builder(name, seed)
    W, Dp, H = 6.0, 5.0, 5.4
    poly = arch_outline(W, H, 2.6)
    for sy in (-1, 1):
        pts = [(x, sy * Dp / 2, z) for x, z in poly]
        b.face(pts if sy > 0 else pts[::-1], "limestone")
    # the passage soffit and the outer walls
    for i in range(len(poly)):
        x0, z0 = poly[i]
        x1, z1 = poly[(i + 1) % len(poly)]
        if z0 == 0 and z1 == 0:
            continue
        b.face([(x0, -Dp / 2, z0), (x1, -Dp / 2, z1), (x1, Dp / 2, z1), (x0, Dp / 2, z0)], "limestone")
    # string course and quoins (chunky)
    b.box((0, 0, H + 0.12), (W + 0.4, Dp + 0.4, 0.3), "limestone", grain=0)
    for sx in (-1, 1):
        for k in range(4):
            b.box((sx * (W / 2 + 0.03), -Dp / 2 - 0.03, 0.6 + k * 1.3), (0.7, 0.12, 0.55), "drystone", grain=0)
    # upper gallery
    z1 = H + 0.27
    plank_deck(b, -3.1, 3.1, -2.6, 2.6, z1 + 0.08, along="x")
    for (x, y) in ((-2.6, -2.1), (2.6, -2.1), (-2.6, 2.1), (2.6, 2.1)):
        b.cylinder((x, y, z1), 0.18, 2.9, 10, "lacquer")
    for x in np.linspace(-2.9, 2.9, 7):
        for y in (-2.45, 2.45):
            b.box((x, y, z1 + 0.5), (0.1, 0.1, 0.9), "timber")
    for y in (-2.45, 2.45):
        b.beam((-3.0, y, z1 + 0.95), (3.0, y, z1 + 0.95), 0.12, 0.12, "timber")
    wall(b, (-2.3, 1.8), (2.3, 1.8), z1, 2.5, key="plaster", thick=0.14)
    ez = z1 + 2.95
    b.beam((-3.0, -2.1, ez - 0.15), (3.0, -2.1, ez - 0.15), 0.22, 0.24, "lacquer")
    b.beam((-3.0, 2.1, ez - 0.15), (3.0, 2.1, ez - 0.15), 0.22, 0.24, "lacquer")
    roof(b, (0, 0, ez), 4.2, 3.6, 2.8, top="tile", under="timber", p=1.6, upturn=1.0, flare=0.6, thick=0.34,
         ridge_r=0.2, curls=True)
    for (x, y) in ((-3.9, -3.4), (3.9, -3.4)):
        lantern_round(b, (x, y, ez - 0.2), cord=0.45)
    return b, ez + 2.8 + 1.0


# ================================================================================================ V05 rope bridge
def deck_z(t, L, dz, sag):
    return dz * t - 4 * sag * t * (1 - t)


def rope_bridge_span(name, L, dz=0.0, sag=None, width=1.7, seed=51, flags=True):
    """A hanging rope bridge span from (0,0,0) (deck surface at the start anchor) to (L, 0, dz), sagging `sag`
    (default L/15) below the chord; planks 0.3 m with 4 cm gaps across two stringer logs, posts every 3.5 m, two rope
    rails each side (hand rail 1.1 m), net diagonals, rag flags. A walkable deck collider (deck-colonly)."""
    b = Builder(name, seed)
    rng = b.rng
    sag = L / 15.0 if sag is None else sag
    n = int(L / 0.335)
    hw = width / 2
    quads = []
    for k in range(n):
        t = (k + 0.5) / n
        x = t * L
        z = deck_z(t, L, dz, sag)
        dzdx = (deck_z(t + 0.001, L, dz, sag) - z) / (0.001 * L)
        ang = math.atan(dzdx)
        R = rot_y(-ang) @ rot_x(rng.normal(0, 0.025)) @ rot_z(rng.normal(0, 0.025))
        b.box((x + rng.normal(0, 0.01), rng.normal(0, 0.04), z - 0.04 + rng.normal(0, 0.008)),
              (0.3, width + 0.2 + rng.uniform(-0.1, 0.1), 0.08), "plank", rot=R, grain=1)
    for k in range(0, n, 2):
        t0, t1 = k / n, min(k + 2, n) / n
        z0, z1 = deck_z(t0, L, dz, sag), deck_z(t1, L, dz, sag)
        quads.append([(t0 * L, -hw, z0), (t1 * L, -hw, z1), (t1 * L, hw, z1), (t0 * L, hw, z0)])
    b.collider("deck", quads)
    m = max(8, int(L / 2.0))
    ts = np.linspace(0, 1, m + 1)
    for sy in (-1, 1):
        b.tube([(t * L, sy * (hw - 0.25), deck_z(t, L, dz, sag) - 0.17) for t in ts], 0.1, 5, "timber", caps=True)
    # posts, rails, net
    npost = max(2, int(round(L / 3.5)))
    post_t = np.linspace(0, 1, npost + 1)[1:-1]
    rail_pts = {}
    for sy in (-1, 1):
        y = sy * (hw + 0.08)
        for tp in post_t:
            x = tp * L
            z = deck_z(tp, L, dz, sag)
            b.box((x, y, z + 0.42), (0.13, 0.13, 1.1), "timber", rot=rot_y(rng.normal(0, 0.03)), grain=2)
            b.tube([(x - 0.01, y, z + 0.97), (x + 0.01, y, z + 1.2)], 0.075, 6, "timber")
            b.tube([(x, y, z + 1.0), (x, y, z + 1.16)], 0.095, 6, "rope", caps=False)   # lashing
        for (zoff, r, key) in ((1.1, 0.06, "rope"), (0.55, 0.04, "rope")):
            pts = []
            for t in np.linspace(0, 1, npost * 2 + 1):     # post, mid-bay, post: the dip between posts
                # the rail dips a little between posts
                ph = (t * (npost)) % 1.0
                pts.append((t * L, y, deck_z(t, L, dz, sag) + zoff - 0.07 * math.sin(math.pi * ph)))
            b.tube(pts, r, 5, key, caps=True)
            rail_pts[(sy, zoff)] = pts
        bays = [0.0] + list(post_t) + [1.0]
        for i in range(len(bays) - 1):
            ta, tb = bays[i], bays[i + 1]
            za, zb = deck_z(ta, L, dz, sag), deck_z(tb, L, dz, sag)
            b.tube([(ta * L, y, za + 1.05), (tb * L, y, zb + 0.04)], 0.018, 3, "rope", caps=False)
            b.tube([(tb * L, y, zb + 1.05), (ta * L, y, za + 0.04)], 0.018, 3, "rope", caps=False)
    # rag flags tied to the hand rails
    if flags:
        k = 0
        for i, tp in enumerate(post_t):
            if i % 2:
                continue
            for sy in (-1, 1):
                if rng.random() < 0.35:
                    continue
                x = (tp + 0.5 / max(npost, 1)) * L
                t = x / L
                z = deck_z(t, L, dz, sag) + 1.07
                cell = int(rng.integers(0, 5))
                y = sy * (hw + 0.14)
                P = np.zeros((3, 3, 3))
                U = np.zeros((3, 3))
                V = np.zeros((3, 3))
                M = np.zeros((3, 3))
                hh = rng.uniform(0.4, 0.55)
                for a in range(3):
                    for c_ in range(3):
                        s, tt = c_ / 2, a / 2
                        P[a, c_] = (x + (s - 0.5) * 0.32, y + sy * 0.05 * tt * tt, z - tt * hh * (1 - 0.15 * (c_ == 1)))
                        U[a, c_] = (cell + 0.05 + 0.9 * s) / 5
                        V[a, c_] = 1 - tt * 0.95
                        M[a, c_] = tt
                b.grid(P, "flags", U, V, unit=True, M=M)
                k += 1
    curve = [[round(float(t * L), 3), round(float(deck_z(t, L, dz, sag)), 3)] for t in np.linspace(0, 1, 25)]
    return b, curve


def bridge_anchor(name="rope_bridge_anchor", seed=55, width=1.7):
    """A bridge head: two 5 m anchor posts on dry-stone footings either side of the deck end, a crossbar, back-stays to
    stakes, an indigo banner with madder tails on each post, a lantern. The span leaves toward +X; origin = deck surface
    at the span's end (the ground there)."""
    b = Builder(name, seed)
    hw = width / 2 + 0.25
    for sy in (-1, 1):
        y = sy * hw
        b.box((-0.4, y, -0.2), (1.5, 1.0, 0.9), "drystone", grain=0)
        b.tube([(-0.4, y, 0.2), (-0.38, y, 3.0), (-0.42, y, 5.0)], [0.24, 0.22, 0.2], 10, "timber")
        b.lathe([(0.22, 0), (0.28, 0.12), (0.12, 0.35), (0.0, 0.42)], 8, "timber", base=(-0.42, y, 5.0))
        for z in (1.1, 0.55):          # rails tied on, then back-stays down to stakes
            b.tube([(-0.4, y, z + 0.0), (-3.2, y * 1.6, 0.25)], 0.05, 5, "rope")
        b.tube([(-0.42, y, 4.6), (-3.6, y * 1.7, 0.2)], 0.06, 6, "rope")
        b.tube([(-3.4, y * 1.65, -0.4), (-3.45, y * 1.65, 0.55)], 0.09, 6, "timber")
        for z in (1.1, 0.55, 4.6):
            b.tube([(-0.4, y, z - 0.1), (-0.4, y, z + 0.12)], 0.27, 8, "rope", caps=False)   # lashing bands
        # banner arm and the banner hanging on the outside of the post
        b.beam((-0.42, y, 4.55), (-0.42, y + sy * 1.15, 4.55), 0.1, 0.12, "timber")
        with b.at((-0.42, y + sy * 0.78, 0.0), yaw=math.pi / 2 * sy):
            cloth_sheet(b, (0, 0, 4.45), 0.85, 2.6, "banner_indigo", notch=0.4, amp=0.05, rows=10, cols=5)
            cloth_sheet(b, (0.5, 0.03, 4.45), 0.16, 2.1, "cloth_madder", notch=0.1, amp=0.03, waves=1, rows=8, cols=2,
                        unit=False)
            cloth_sheet(b, (-0.5, 0.03, 4.45), 0.16, 1.9, "cloth_madder", notch=0.1, amp=0.03, waves=1, rows=8,
                        cols=2, unit=False)
    b.beam((-0.42, -hw - 0.45, 4.3), (-0.42, hw + 0.3, 4.3), 0.2, 0.24, "timber")
    b.beam((-0.42, -hw - 0.4, 4.22), (-0.2, -hw - 0.2, 4.22), 0.08, 0.08, "timber")      # the lantern's arm
    flag_rope(b, (-0.42, -hw, 4.25), (-0.42, hw, 4.25), sag=0.35, spacing=0.42, seed_offset=2)
    lantern_round(b, (-0.2, -hw - 0.2, 3.3), r=0.27, h=0.6, cord=0.62)   # hung from the crossbar's end
    plank_deck(b, -2.4, 0.15, -width / 2 - 0.1, width / 2 + 0.1, 0.0, along="y")
    b.collider("deck", [[(-2.4, -width / 2, 0), (0.15, -width / 2, 0), (0.15, width / 2, 0), (-2.4, width / 2, 0)]])
    b.empty("anchor_lamp", (-0.2, -hw - 0.2, 3.3))
    return b, 5.4


def needle_platform(name="rope_bridge_needle_platform", seed=57, width=1.7):
    """The 4 x 4 m plank platform on the needle (R07's cap): origin = the deck surface at its centre; bearers reach
    1.0 m below to sit on the rock; one banner and a lantern post; spans attach at x = +-2.0."""
    b = Builder(name, seed)
    for y in (-1.6, -0.55, 0.55, 1.6):
        b.beam((-2.2, y, -0.22), (2.2, y, -0.22), 0.22, 0.22, "timber")
    for (x, y) in ((-1.8, -1.8), (1.8, -1.8), (-1.8, 1.8), (1.8, 1.8)):
        b.tube([(x, y, -1.0), (x, y, 1.15)], 0.14, 8, "timber")
        b.tube([(x, y, 1.0), (x, y, 1.18)], 0.16, 8, "rope", caps=False)
    plank_deck(b, -2.05, 2.05, -2.0, 2.0, 0.0, along="y")
    for sy in (-1, 1):
        b.tube([(-1.8, sy * 1.8, 1.05), (1.8, sy * 1.8, 1.05)], 0.06, 6, "rope")
    with b.at((0.9, 1.75, 0.0)):
        banner(b, "indigo", h=5.6, cloth_w=1.0, cloth_l=2.9, base=False)
    post(b, -1.4, 1.6, 0.0, 2.6, r=0.08, footing=False)
    b.beam((-1.4, 1.6, 2.5), (-1.4, 1.0, 2.5), 0.08, 0.08, "timber")
    lantern_round(b, (-1.4, 1.05, 1.95), r=0.26, h=0.58, cord=0.22)
    b.collider("deck", [[(-2.0, -2.0, 0), (2.0, -2.0, 0), (2.0, 2.0, 0), (-2.0, 2.0, 0)]])
    return b, 5.6


# ================================================================================================ V06 waystone
def waystone(name="clan_waystone", seed=61):
    """A leaning, tapering, slightly twisted slab (4.4 m, 1.25 m wide) with the clan's carved face (waystone_face),
    a cairn base, two prayer-flag ropes from its head to two bamboo poles, rag offerings tied round it."""
    b = Builder(name, seed)
    rng = b.rng
    Hs = 4.4
    levels = np.linspace(0, 1, 9)
    lean = math.radians(6)
    sections = []
    for t in levels:
        w = 1.25 * (1 - 0.32 * t) * (1 - 0.4 * max(t - 0.85, 0) / 0.15)
        d = 0.55 * (1 - 0.25 * t)
        tw = math.radians(12) * t
        z = t * Hs - (0.25 * max(t - 0.9, 0) / 0.1 * 1.0)
        ch = 0.12
        loc = [(-w / 2 + ch, -d / 2), (w / 2 - ch, -d / 2), (w / 2, -d / 2 + ch), (w / 2, d / 2 - ch),
               (w / 2 - ch, d / 2), (-w / 2 + ch, d / 2), (-w / 2, d / 2 - ch), (-w / 2, -d / 2 + ch)]
        R = rot_z(tw)
        pts = []
        for (x, y) in loc:
            p = R @ np.array([x, y, 0.0])
            pts.append(np.array([p[0] + math.sin(lean) * z, p[1], z]))
        # the head is cut on a slant
        if t == 1.0:
            pts = [p + [0, 0, -0.35 * (p[0] - pts[0][0]) / max(w, 0.1)] for p in pts]
        sections.append((pts, w))
    for i in range(len(sections) - 1):
        A, wa = sections[i]
        Bs, wb = sections[i + 1]
        for k in range(8):
            q = [A[k], A[(k + 1) % 8], Bs[(k + 1) % 8], Bs[k]]
            if k == 0:   # the carved face (-Y): unit UVs over the whole face
                ta, tb = levels[i], levels[i + 1]
                uvs = [(0.1, ta), (0.9, ta), (0.9, tb), (0.1, tb)]
                b.face(q, "waystone_face", uvs=uvs)
            else:
                b.face(q, "limestone")
    top = sections[-1][0]
    b.face(top, "limestone")
    pebble_pile(b, (0, 0, 0), 1.25, 13, height=0.55, size=(0.22, 0.42))
    # rope band with rag offerings at 2.7 m
    zb = 2.65
    ring = []
    for k in range(13):
        a = 2 * math.pi * k / 12
        ring.append(np.array([math.sin(lean) * zb + 0.52 * math.cos(a), 0.3 * math.sin(a), zb + 0.05 * math.sin(2 * a)]))
    b.tube(ring, 0.035, 4, "rope", caps=False)
    for k, a in enumerate((0.3, 1.2, 2.4, 3.6, 4.9)):
        p = np.array([math.sin(lean) * zb + 0.55 * math.cos(a), 0.33 * math.sin(a), zb])
        with b.at(p, yaw=a + math.pi / 2):
            cloth_sheet(b, (0, 0, 0), 0.14, rng.uniform(0.6, 1.1), ["cloth_madder", "cloth_bone", "cloth_indigo"][k % 3],
                        notch=0.06, amp=0.02, waves=1, rows=4, cols=1, unit=False)
    # two bamboo flag poles and the ropes from the stone's head
    head = np.array([math.sin(lean) * Hs - 0.1, 0.0, Hs - 0.15])
    for (px, py, ph) in ((-3.6, 1.1, 4.0), (3.4, 1.4, 3.6)):
        b.tube([(px, py, -0.3), (px + 0.05, py, ph * 0.5), (px + 0.12, py, ph)], [0.06, 0.055, 0.045], 6, "bamboo")
        pebble_pile(b, (px, py, 0), 0.4, 4, height=0.2, size=(0.15, 0.24))
        flag_rope(b, head, (px + 0.12, py, ph - 0.1), sag=0.35, spacing=0.5, seed_offset=int(px))
    b.empty("anchor_offering", (0, -0.6, 0.6))
    return b, Hs


# ================================================================================================ V09 lanterns
def lantern_set():
    out = []
    b = Builder("lantern_round", 71)
    lantern_round(b, (0, 0, 0))
    b.empty("anchor_light", (0, 0, 0))
    out.append((b, 0.7, False))
    b = Builder("lantern_barrel", 72)
    lantern_barrel(b, (0, 0, 0))
    b.empty("anchor_light", (0, 0, 0))
    out.append((b, 0.85, False))
    b = Builder("lantern_post", 73)
    post(b, 0, 0, 0, 2.9, r=0.1, footing=True)
    b.beam((0, 0.0, 2.75), (0, -0.85, 2.75), 0.1, 0.12, "timber")
    b.beam((0, 0.0, 2.3), (0, -0.55, 2.72), 0.07, 0.07, "timber")
    lantern_round(b, (0, -0.78, 2.1), r=0.28, h=0.62, cord=0.25)
    b.empty("anchor_light", (0, -0.78, 2.1))
    out.append((b, 2.9, True))
    b = Builder("bridge_lamp", 74)
    # a timber cage lamp with paper panels under a little tile roof on a stout post
    b.box((0, 0, 0.3), (0.7, 0.7, 0.6), "drystone")
    b.cylinder((0, 0, 0.6), 0.12, 0.9, 8, "timber")
    b.box((0, 0, 1.55), (0.7, 0.7, 0.1), "timber")
    for (x, y) in ((-0.28, -0.28), (0.28, -0.28), (0.28, 0.28), (-0.28, 0.28)):
        b.box((x, y, 1.95), (0.08, 0.08, 0.72), "timber")
    for k in range(4):
        with b.at((0, 0, 0), yaw=k * math.pi / 2):
            b.face([(-0.24, -0.25, 1.62), (0.24, -0.25, 1.62), (0.24, -0.25, 2.28), (-0.24, -0.25, 2.28)], "paper",
                   uvs=[(0, 0), (0.5, 0), (0.5, 0.66), (0, 0.66)])
    roof(b, (0, 0, 2.36), 0.55, 0.55, 0.45, top="tile", under="timber", p=1.5, upturn=0.12, flare=0.1, thick=0.08,
         ridge=False, ridge_r=0.05, finial=False, ns=8, nt=4)
    b.empty("anchor_light", (0, 0, 1.95))
    out.append((b, 2.85, True))
    return out


# ================================================================================================ V10 terraces
def terrace_wall(name, length=4.0, h=1.2, curve=0.0, seed=81):
    """A dry-stone retaining wall module along X (front -Y), `curve` = 1/R (+ bows toward the front), battered 12°,
    lumpy face, a grass lip rolling over the top and a 0.7 m grass strip behind (meets the terrain). Origin: the wall
    foot's middle on the lower terrace."""
    b = Builder(name, seed)
    rng = b.rng
    nx, nz = 8, 3          # the painted drystone carries the stones; the mesh only bows and batters
    batter = math.tan(math.radians(12))

    def base_pt(s):
        x = s * length
        y = -curve * x * x / 2 + curve * (length / 2) ** 2 / 2 * 0
        return x, y

    P = np.zeros((nz + 1, nx + 1, 3))
    U = np.zeros((nz + 1, nx + 1))
    V = np.zeros((nz + 1, nx + 1))
    lump = rng.uniform(-1, 1, (nz + 1, nx + 1))
    for i in range(nz + 1):
        z = -0.25 + (h + 0.25) * i / nz
        for j in range(nx + 1):
            s = j / nx - 0.5
            x, y = base_pt(s)
            dy = batter * max(z, 0) + (0.05 * lump[i, j] if 0 < i < nz and 0 < j < nx else 0)
            P[i, j] = (x, y + dy, z)
            U[i, j] = x
            V[i, j] = z
    b.grid(P, "drystone", U, V, smooth=False)
    b.orient = {"drystone": (0.0, -1.0, 0.0)}       # the stone face looks down the hill (-Y), whatever the bow
    # grass lip: a fat roll along the top, and the strip behind
    top = [P[nz, j] + [0, 0.05, 0.02] for j in range(nx + 1)]
    b.tube(top, 0.17, 5, "grass", caps=True)
    back = np.array([[p + [0, 0.0, 0.05], p + [0, 0.7, 0.07]] for p in top]).transpose(1, 0, 2)
    b.grid(back, "grass", back[..., 0], back[..., 1], smooth=True)
    # ends: a few big capstones and stones at the foot
    for k in range(3):
        s = rng.uniform(-0.45, 0.45)
        x, y = base_pt(s)
        b.pebble((x, y - 0.25, 0.05), (rng.uniform(0.2, 0.35), 0.22, 0.18), "limestone", rot=rot_z(rng.uniform(0, 3)),
                 segs=5, rings=3)
    return b, h


def paddy_bund(name="paddy_bund_4m", length=4.0, seed=85):
    b = Builder(name, seed)
    nx = 12
    P = np.zeros((5, nx + 1, 3))
    U = np.zeros((5, nx + 1))
    V = np.zeros((5, nx + 1))
    prof = [(-0.55, -0.1), (-0.3, 0.25), (0.0, 0.38), (0.3, 0.25), (0.55, -0.1)]
    for j in range(nx + 1):
        x = (j / nx - 0.5) * length
        wob = 0.06 * math.sin(j * 1.7)
        for i, (y, z) in enumerate(prof):
            P[i, j] = (x, y + wob, z + 0.02 * math.sin(j * 2.3 + i))
            U[i, j] = x
            V[i, j] = y
    b.grid(P[:2], "earth", U[:2], V[:2], flip=True)
    b.grid(P[1:4], "grass", U[1:4], V[1:4], flip=True)
    b.grid(P[3:], "earth", U[3:], V[3:], flip=True)
    return b, 0.38


# ================================================================================================ V11 sampan
def sampan(name="sampan", seed=91):
    """About 7 m: a low hull with upswept bow and stern, a woven bamboo canopy amidships, thwarts, floorboards, a pole
    laid across and a fish basket beside. Origin on the ground under the keel's middle (bow toward +X)."""
    b = Builder(name, seed)
    L = 3.6
    ns, ng = 20, 8
    P = np.zeros((ng + 1, ns + 1, 3))
    Pi = np.zeros_like(P)
    U = np.zeros((ng + 1, ns + 1))
    V = np.zeros((ng + 1, ns + 1))
    for j in range(ns + 1):
        x = (j / ns * 2 - 1) * L
        u = abs(x) / L
        w = 0.88 * max(1 - u ** 2.2, 0.0) ** 0.55 + 0.02
        zt = 0.62 + 0.75 * u ** 3.2
        zb = 0.06 + 0.42 * u ** 2.4
        for i in range(ng + 1):
            s = i / ng * 2 - 1
            y = w * s
            z = zb + (zt - zb) * abs(s) ** 2.0
            P[i, j] = (x, y, z)
            Pi[i, j] = (x * 0.985, y * 0.9, z + 0.05)
            U[i, j] = x
            V[i, j] = s * (w + (zt - zb))
    b.grid(P, "plank", U, V, smooth=True)
    b.grid(Pi, "plank", U + 1.3, V, smooth=True, flip=True)
    for i in (0, ng):
        path = [(P[i, j] + Pi[i, j]) / 2 + [0, 0, 0.02] for j in range(ns + 1)]
        b.tube(path, 0.06, 6, "timber", caps=True)
    # stem and stern posts
    for sx in (-1, 1):
        b.tube([(sx * L * 0.92, 0, 0.5), (sx * (L + 0.15), 0, 1.25), (sx * (L + 0.05), 0, 1.5)], [0.08, 0.07, 0.05], 6,
               "timber")
    for x in (-2.2, 0.0, 2.0):
        w = 0.88 * (1 - (abs(x) / L) ** 2.2) ** 0.55
        b.box((x, 0, 0.55), (0.22, 2 * w * 0.92, 0.07), "timber", grain=1)
    plank_deck(b, -2.6, 2.6, -0.45, 0.45, 0.2, along="x", thick=0.05)
    # the canopy: a half barrel of weave on bamboo hoops
    cx0, cx1 = -1.3, 0.9
    r = 0.95
    ng2, nl = 8, 5
    Pc = np.zeros((nl + 1, ng2 + 1, 3))
    Uc = np.zeros((nl + 1, ng2 + 1))
    Vc = np.zeros((nl + 1, ng2 + 1))
    for i in range(nl + 1):
        x = cx0 + (cx1 - cx0) * i / nl
        for k in range(ng2 + 1):
            a = math.pi * k / ng2
            Pc[i, k] = (x, r * math.cos(a), 0.5 + r * 0.85 * math.sin(a))
            Uc[i, k] = x
            Vc[i, k] = a * r
    b.grid(Pc, "weave", Uc, Vc, smooth=True)
    for x in np.linspace(cx0, cx1, 4):
        b.tube([(x, r * math.cos(a), 0.5 + r * 0.85 * math.sin(a)) for a in np.linspace(0, math.pi, 9)], 0.035, 5,
               "bamboo", caps=False)
    # pole across, fish basket beside
    b.tube([(-3.2, -0.65, 0.72), (2.4, 0.75, 0.68)], 0.045, 6, "bamboo")
    b.lathe([(0.0, 0.0), (0.22, 0.02), (0.3, 0.2), (0.26, 0.45), (0.14, 0.62), (0.16, 0.7)], 10, "basket",
            base=(0.6, -1.45, 0.0), cap_top=False)
    b.empty("anchor_mooring", (L + 0.05, 0, 1.4))
    return b, 1.6


# ================================================================================================ V12 fences
def fence_bamboo(name="fence_bamboo_3m", length=3.0, seed=101):
    b = Builder(name, seed)
    rng = b.rng
    xs = np.linspace(-length / 2, length / 2, 3)
    tops = []
    for x in xs:
        h = rng.uniform(1.05, 1.25)
        lean = (rng.normal(0, 0.03), rng.normal(0, 0.04))
        b.tube([(x, 0, -0.25), (x + lean[0] * h, lean[1] * h, h)], 0.065, 6, "bamboo")
        tops.append((x, lean, h))
    for z in (0.45, 0.9):
        pts = [(x + lean[0] * z, lean[1] * z - 0.08, z + rng.normal(0, 0.03)) for (x, lean, h) in tops]
        b.tube([(pts[0][0] - 0.25, pts[0][1], pts[0][2])] + pts + [(pts[-1][0] + 0.25, pts[-1][1], pts[-1][2])],
               0.045, 6, "bamboo")
        for p in pts:
            b.tube([np.array(p) + [0, 0.0, -0.06], np.array(p) + [0, 0, 0.06]], 0.085, 6, "rope", caps=False)
    return b, 1.25


def fence_wattle(name="fence_wattle_2m", length=2.0, seed=102):
    b = Builder(name, seed)
    rng = b.rng
    n = 5
    for k in range(n):
        x = (k / (n - 1) - 0.5) * length
        b.tube([(x, 0.03 * (-1) ** k, -0.2), (x + rng.normal(0, 0.02), 0.03 * (-1) ** k, 1.15)], 0.04, 5, "timber")
    nx, nz = 10, 3
    P = np.zeros((nz + 1, nx + 1, 3))
    U = np.zeros((nz + 1, nx + 1))
    V = np.zeros((nz + 1, nx + 1))
    for i in range(nz + 1):
        z = 0.12 + 0.9 * i / nz
        for j in range(nx + 1):
            x = (j / nx - 0.5) * length
            P[i, j] = (x, 0.05 * math.sin(j / nx * (n - 1) * math.pi), z)
            U[i, j] = x
            V[i, j] = z
    b.grid(P, "weave", U, V, smooth=True)
    b.tube([P[nz, j] + [0, 0, 0.03] for j in range(nx + 1)], 0.045, 5, "basket")
    return b, 1.15


# ================================================================================================ V13 clutter
def drying_rack(name="drying_rack", seed=111):
    b = Builder(name, seed)
    rng = b.rng
    for sx in (-1.3, 1.3):
        for sy in (-1, 1):
            b.tube([(sx + 0.0, sy * 0.55, -0.15), (sx, 0, 2.1)], 0.05, 6, "bamboo")
    for z, y in ((2.05, 0.0), (1.3, -0.3), (1.3, 0.3)):
        b.tube([(-1.6, y, z), (1.6, y, z)], 0.045, 6, "bamboo")
    # bundles of drying rice / herbs and a hung cloth
    for x in np.linspace(-1.1, 1.1, 6):
        b.tube([(x, -0.32, 1.28), (x + rng.normal(0, 0.03), -0.36, 0.6)], [0.07, 0.13], 6, "thatch")
        b.tube([(x + 0.05, 0.32, 1.28), (x, 0.36, 0.7)], [0.06, 0.11], 6, "thatch")
    cloth_sheet(b, (0.3, 0.0, 2.02), 1.3, 1.1, "cloth_indigo", notch=0.0, amp=0.05, rows=4, cols=4, unit=False)
    return b, 2.2


def basket_set(name="basket_set", seed=112):
    b = Builder(name, seed)
    b.lathe([(0.0, 0), (0.28, 0.02), (0.36, 0.3), (0.4, 0.62), (0.42, 0.68)], 10, "basket", base=(0, 0, 0),
            cap_top=False)
    b.lathe([(0.0, 0), (0.4, 0.02), (0.5, 0.14), (0.55, 0.2)], 12, "basket", base=(0.9, 0.2, 0), cap_top=False)
    for k, (x, y) in enumerate(((0.85, 0.15), (1.0, 0.3), (0.75, 0.32))):
        b.pebble((x, y, 0.16), (0.09, 0.08, 0.07), "paper" if k % 2 else "jar")
    b.lathe([(0.0, 0), (0.2, 0.01), (0.26, 0.25), (0.18, 0.48), (0.2, 0.52)], 10, "basket", base=(-0.6, 0.4, 0),
            cap_top=False)
    return b, 0.7


def firewood_pile(name="firewood_pile", seed=113):
    b = Builder(name, seed)
    rng = b.rng
    for row in range(4):
        n = 6 - row
        for k in range(n):
            y = (k - (n - 1) / 2) * 0.24
            z = 0.12 + row * 0.2
            r = rng.uniform(0.08, 0.12)
            b.tube([(-0.75 + rng.normal(0, 0.05), y, z), (0.75 + rng.normal(0, 0.05), y, z)], r, 6, "timber")
    for sx in (-0.85, 0.85):
        for sy in (-0.75, 0.75):
            b.tube([(sx, sy, -0.15), (sx, sy, 0.95)], 0.05, 5, "timber")
    return b, 0.95


def water_jars(name="water_jars", seed=114):
    b = Builder(name, seed)
    prof = [(0.0, 0.0), (0.2, 0.01), (0.34, 0.22), (0.38, 0.42), (0.3, 0.66), (0.18, 0.76), (0.2, 0.82), (0.17, 0.84)]
    b.lathe(prof, 12, "jar", base=(0, 0, 0), cap_top=True)
    b.lathe([(p[0] * 0.75, p[1] * 0.75) for p in prof], 12, "jar", base=(0.75, 0.15, 0), cap_top=True)
    b.lathe([(0.24, 0.0), (0.24, 0.04), (0.08, 0.1), (0.0, 0.12)], 10, "timber", base=(0, 0, 0.84))
    b.lathe([(0.0, 0.0), (0.06, 0.0), (0.07, 0.3), (0.0, 0.32)], 6, "bamboo", base=(-0.3, -0.3, 0.0),
            rot=rot_x(1.3))
    return b, 0.95


# ================================================================================================ V14 survey camp
def tent(b, c, L=2.4, W=1.8, H=1.5, yaw=0.0):
    with b.at(c, yaw=yaw):
        for sy in (-1, 1):
            P = np.zeros((3, 5, 3))
            U = np.zeros((3, 5))
            V = np.zeros((3, 5))
            for i in range(3):
                t = i / 2
                for j in range(5):
                    x = (j / 4 - 0.5) * L
                    sagz = 0.06 * math.sin(math.pi * j / 4) * math.sin(math.pi * t)
                    P[i, j] = (x, sy * W / 2 * (1 - t), H * t - sagz)
                    U[i, j] = x
                    V[i, j] = t * math.hypot(W / 2, H)
            b.grid(P, "cloth_bone", U, V, smooth=True)
        for sx in (-1, 1):
            b.tube([(sx * L / 2, 0, -0.1), (sx * L / 2, 0, H + 0.15)], 0.035, 5, "timber")
        b.tube([(-L / 2 - 0.1, 0, H + 0.02), (L / 2 + 0.1, 0, H + 0.02)], 0.03, 5, "timber")
        for sx in (-1, 1):
            for sy in (-1, 1):
                b.tube([(sx * L / 2, 0, H), (sx * (L / 2 + 0.9), sy * 0.6, 0.0)], 0.01, 3, "rope", caps=False)


def survey_camp(name="survey_camp", seed=121):
    """V14 (story: the survey on the north route): two small tents, a measuring tripod with an instrument, three
    striped rods, a crate. Small and period-true. Origin at the camp's middle."""
    b = Builder(name, seed)
    tent(b, (-1.8, 0.8, 0), yaw=0.2)
    tent(b, (1.4, 1.6, 0), L=2.0, W=1.6, H=1.3, yaw=-0.4)
    # tripod and instrument
    top = np.array([0.6, -1.6, 1.45])
    for a in (0.3, 2.4, 4.4):
        b.tube([top, top + [0.55 * math.cos(a), 0.55 * math.sin(a), -1.5]], 0.025, 5, "timber")
    b.cylinder(top + [0, 0, -0.02], 0.09, 0.06, 8, "timber")
    b.tube([top + [-0.22, 0, 0.12], top + [0.22, 0, 0.12]], 0.05, 8, "iron")
    b.box(top + [0, 0, 0.04], (0.12, 0.12, 0.08), "iron")
    # striped rods: alternating madder and bone segments
    for k, (x, y, lean) in enumerate(((-0.6, -2.4, 0.04), (2.4, -0.6, -0.05), (-3.4, -1.0, 0.02))):
        for s in range(6):
            z0, z1 = s * 0.5, (s + 1) * 0.5
            b.tube([(x + lean * z0, y, z0 - 0.2 * (s == 0)), (x + lean * z1, y, z1)], 0.03, 6,
                   "cloth_madder" if s % 2 == 0 else "cloth_bone", caps=True)
    b.box((-0.2, 0.0, 0.25), (0.8, 0.5, 0.5), "plank", rot=rot_z(0.3))
    cloth_sheet(b, (-0.2, -0.02, 0.52), 0.85, 0.35, "cloth_ochre", notch=0.0, amp=0.02, rows=2, cols=2, unit=False)
    return b, 1.6


# ================================================================================================ V15 porters
def porter(name, pose="stand", seed=131, pole=False):
    """A simple painted porter, 1.75 m to the crown (the conical hat to 1.86 m): indigo jacket, bone trousers with
    indigo leg wraps, madder sash, a back basket (or a carrying pole with two baskets). Facing -Y."""
    b = Builder(name, seed)
    swing = 0.35 if pose == "walk" else 0.0
    hip = 0.92
    # legs
    for sx, ph in ((-1, 1), (1, -1)):
        a = swing * ph
        knee = np.array([sx * 0.11, -math.sin(a) * 0.45, hip - math.cos(a) * 0.45])
        foot = knee + [0, -math.sin(a * 0.6) * 0.45 + (0.08 if ph * swing > 0 else 0), -0.43]
        foot[2] = max(foot[2], 0.06)
        b.tube([(sx * 0.11, 0, hip), knee, foot], [0.09, 0.075, 0.06], 6, "cloth_bone")
        b.tube([knee + [0, 0, -0.05], foot + [0, 0, 0.05]], [0.075, 0.068], 6, "cloth_indigo", caps=False)
        b.box(foot + [0, -0.07, -0.03], (0.1, 0.24, 0.07), "timber", grain=1)
    # body: a jacket lathe from hips to shoulders
    b.lathe([(0.2, hip - 0.12), (0.24, hip + 0.02), (0.2, hip + 0.25), (0.23, 1.32), (0.17, 1.43), (0.07, 1.48)], 10,
            "cloth_indigo", base=(0, 0, 0), scale_xy=(1.0, 0.75))
    b.lathe([(0.215, hip), (0.215, hip + 0.1)], 10, "cloth_madder", base=(0, 0, 0), scale_xy=(1.05, 0.8))
    # arms
    for sx, ph in ((-1, -1), (1, 1)):
        a = swing * ph
        sh = np.array([sx * 0.25, 0, 1.36])
        el = sh + [sx * 0.05, -math.sin(a) * 0.3, -0.28]
        if pole:
            el = sh + [sx * 0.02, -0.18, -0.12]
            hand = el + [0, -0.12, 0.2]
        else:
            hand = el + [sx * 0.01, -math.sin(a) * 0.28 - 0.04, -0.26]
        b.tube([sh, el, hand], [0.07, 0.06, 0.05], 6, "cloth_indigo")
        b.pebble(hand + [0, 0, -0.03], (0.045, 0.045, 0.06), "skin")
    # head and the conical hat
    b.cylinder((0, 0, 1.46), 0.055, 0.1, 6, "skin")
    b.pebble((0, 0, 1.63), (0.1, 0.11, 0.12), "skin")
    b.lathe([(0.36, 0.0), (0.3, 0.04), (0.0, 0.26)], 14, "weave", base=(0, 0, 1.64), cap_bottom=True)
    if pole:
        b.tube([(0, 1.2, 1.5), (0, 0, 1.52), (0, -1.2, 1.5)], 0.03, 6, "bamboo")
        for sy in (-1, 1):
            for sx in (-1, 1):
                b.tube([(0, sy * 1.1, 1.5), (sx * 0.2, sy * 1.1, 0.75)], 0.008, 3, "rope", caps=False)
            b.lathe([(0.0, 0.0), (0.22, 0.02), (0.27, 0.25), (0.28, 0.32)], 10, "basket", base=(0, sy * 1.1, 0.45),
                    cap_top=False)
    else:
        b.lathe([(0.15, 0.0), (0.2, 0.15), (0.24, 0.55), (0.26, 0.62)], 10, "basket", base=(0, 0.32, 0.92),
                cap_top=False, scale_xy=(1.0, 0.8))
        for sx in (-1, 1):
            b.tube([(sx * 0.14, 0.2, 1.48), (sx * 0.16, -0.12, 1.3), (sx * 0.14, 0.15, 1.0)], 0.018, 4, "rope",
                   caps=False)
        b.lathe([(0.0, 0.0), (0.18, 0.05), (0.08, 0.3)], 8, "thatch", base=(0, 0.32, 1.52))
    return b, 1.86


# ================================================================================================ assembly
def assemble(name, parts):
    """parts: [(object, location, yaw)] -> one object (materials merge by name); children re-parented."""
    objs = []
    for ob, loc, yaw in parts:
        ob.location = loc
        ob.rotation_euler = (0, 0, yaw)
        objs.append(ob)
    bpy.ops.object.select_all(action="DESELECT")
    kids = []
    for ob in objs:
        for ch in list(ob.children):
            mw = ch.matrix_world.copy()
            ch.parent = None
            ch.matrix_world = mw
            kids.append(ch)
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    res = bpy.context.view_layer.objects.active
    res.name = name
    res.data.name = name
    ncol = 0
    for ch in kids:
        mw = ch.matrix_world.copy()
        ch.parent = res
        ch.matrix_world = mw
        if "-colonly" in ch.name:
            ncol += 1
            ch.name = "deck%d-colonly" % ncol
    return res


BUILD = []   # (name, function) filled below; each returns (Builder, height[, extras])


def build_all(only=None):
    """Build every piece: returns {name: (object, info)}; AO is baked per piece before any assembly."""
    pieces = {}

    def add(b, height, ao_dist=2.0, ground=True, info=None):
        if only and b.name not in only:
            return None
        ob = b.obj()
        tvkit.bake_vertex_ao(ob, dist=ao_dist, ground=ground)
        pieces[b.name] = (ob, dict(info or {}, height=round(float(height), 2)))
        return ob

    b, h = stilt_house("stilt_house_small", 5.4, 4.2, 2.0, 2.3, "thatch", 4.2, 1.25, 1.3, 11)
    add(b, h, info={"id": "V01", "roof": "thatch", "footprint_m": [5.4, 5.5]})
    b, h = stilt_house("stilt_house_large", 8.4, 5.6, 2.6, 2.5, "shingle", 4.6, 1.35, 1.8, 12, rail=True, big=True)
    add(b, h, info={"id": "V01", "roof": "wood shingle", "footprint_m": [8.4, 7.4]})
    b, h = cliff_house()
    add(b, h, info={"id": "V02", "note": "origin on the lip line; the drop is -Y (Godot +Z); braces end 4.6 m below"})
    b, h = clan_house()
    add(b, h, info={"id": "V03", "footprint_m": [13.0, 10.0]})
    b, h = gate_pavilion()
    add(b, h, info={"id": "V04", "note": "bridge-head gate; the path runs along Y (Godot Z)"})
    b, h = gate_tower()
    add(b, h, info={"id": "V04", "note": "Two Heights gate tower; the passage runs along Y (Godot Z)"})
    curves = {}
    for nm, L, dz in (("rope_bridge_span_63m", 63.0, -3.0), ("rope_bridge_span_73m", 73.0, 3.0),
                      ("rope_bridge_span_30m", 30.0, 0.0)):
        sag = 4.5 if L > 50 else L / 14.0
        b, curve = rope_bridge_span(nm, L, dz, sag=sag, seed=51 + int(L))
        curves[nm] = curve
        add(b, 1.2, ao_dist=1.0, ground=False, info={"id": "V05", "span_m": L, "end_dz_m": dz, "sag_m": round(sag, 2),
                                                      "deck_curve_xz": curve})
    b, h = bridge_anchor()
    add(b, h, ao_dist=1.5, info={"id": "V05", "note": "span leaves toward +X; turn 180° for the far end"})
    b, h = needle_platform()
    add(b, h, ao_dist=1.5, ground=False, info={"id": "V05", "note": "sits on R07's cap; spans attach at x +-2.0"})
    b, h = waystone()
    add(b, h, ao_dist=1.5, info={"id": "V06"})
    for kind in ("indigo", "ochre", "jade"):
        bb = Builder("banner_" + kind, 60 + len(kind))
        banner(bb, kind)
        add(bb, 7.3, ao_dist=1.0, info={"id": "V07"})
    for L in (4.0, 8.0, 12.0):
        bb = Builder("prayer_flags_%dm" % L, 70 + int(L))
        flag_rope(bb, (0, 0, 0), (L, 0, 0))
        add(bb, 0.0, ao_dist=0.5, ground=False, info={"id": "V08", "span_m": L,
                                                       "note": "origin at the start; ends at (L,0,0); sag L/12"})
    for bb, h, gr in lantern_set():
        add(bb, h, ao_dist=1.0, ground=gr, info={"id": "V09", "emission_key": "paper"})
    for nm, curve in (("terrace_wall_straight_4m", 0.0), ("terrace_wall_curve_in_4m", 1 / 10.0),
                      ("terrace_wall_curve_out_4m", -1 / 10.0)):
        bb, h = terrace_wall(nm, curve=curve)
        add(bb, h, ao_dist=1.5, info={"id": "V10", "length_m": 4.0, "height_m": 1.2})
    bb, h = paddy_bund()
    add(bb, h, ao_dist=1.0, info={"id": "V10", "length_m": 4.0})
    bb, h = sampan()
    add(bb, h, ao_dist=1.5, info={"id": "V11", "length_m": 7.6})
    bb, h = fence_bamboo()
    add(bb, h, ao_dist=1.0, info={"id": "V12", "length_m": 3.0})
    bb, h = fence_wattle()
    add(bb, h, ao_dist=1.0, info={"id": "V12", "length_m": 2.0})
    for fn in (drying_rack, basket_set, firewood_pile, water_jars):
        bb, h = fn()
        add(bb, h, ao_dist=1.0, info={"id": "V13"})
    bb, h = survey_camp()
    add(bb, h, ao_dist=1.5, info={"id": "V14"})
    for nm, pose, pole in (("porter_standing", "stand", False), ("porter_walking", "walk", False),
                           ("porter_pole", "walk", True)):
        bb, h = porter(nm, pose, pole=pole)
        add(bb, h, ao_dist=0.6, info={"id": "V15"})
    return pieces


def assemble_bridge(pieces):
    """The R1 rope bridge (D1-D4) as one piece: origin = the west anchor's deck end (Godot (757, 200, -1215));
    the needle platform's centre at x 63 (Godot x 820), deck 197; the east anchor at x 136 (Godot x 893)."""
    def dup(nm):
        ob = pieces[nm][0]
        c = ob.copy()
        c.data = ob.data.copy()
        bpy.context.scene.collection.objects.link(c)
        for ch in ob.children:
            cc = ch.copy()
            if ch.data:
                cc.data = ch.data.copy()
            cc.parent = c
            bpy.context.scene.collection.objects.link(cc)
        return c
    parts = [(dup("rope_bridge_anchor"), (0, 0, 0), 0.0),
             (dup("rope_bridge_span_63m"), (0, 0, 0), 0.0),
             (dup("rope_bridge_needle_platform"), (63.0, 0, -3.0), 0.0),
             (dup("rope_bridge_span_73m"), (63.0, 0, -3.0), 0.0),
             (dup("rope_bridge_anchor"), (136.0, 0, 0), math.pi)]
    # the spans end at the needle's centre; trim nothing: the platform deck covers the overlap
    return assemble("rope_bridge_r1", parts)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--blend", default="")
    ap.add_argument("--only", default="")
    a = ap.parse_args(argv)
    os.makedirs(a.out, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    only = set(filter(None, a.only.split(",")))
    pieces = build_all(only or None)
    manifest = {"_about": "Thủy Vân village kit (VILLAGE). Units metres; Blender Z up exported glTF +Y up; a piece's "
                          "front faces Blender -Y = Godot +Z. COLOR_0 = baked AO x top light (multiply into albedo); "
                          "COLOR_0.a = cloth pin weight. Materials tvv_<key>: see materials.json.",
                "materials": {
                    "tvv_" + k: {"texture": "res://assets/thuyvan/village/textures/%s.png" % k,
                                 "uv_tile_m": (None if v.get("unit_uv") else v["tile_m"]),
                                 "roughness": v["rough"], "specular": v["spec"],
                                 "emission": v.get("emission"),
                                 "double_sided": k in tvkit.DOUBLE_SIDED,
                                 "cloth": k.startswith(("banner_", "cloth_")) or k == "flags"}
                    for k, v in tvkit.MATS.items()},
                "pieces": {}}
    if not only or "rope_bridge_r1" in only:
        if all(k in pieces for k in ("rope_bridge_anchor", "rope_bridge_span_63m", "rope_bridge_needle_platform",
                                     "rope_bridge_span_73m")):
            ob = assemble_bridge(pieces)
            pieces["rope_bridge_r1"] = (ob, {"id": "V05", "height": 5.4, "note": "D1-D4 assembled; origin = Godot "
                                             "(757, 200, -1215), runs +X to (893, 200, -1215); needle platform centre "
                                             "at x 63 deck -3"})
    for nm, (ob, info) in sorted(pieces.items()):
        path = os.path.join(a.out, nm + ".glb")
        tvkit.export_glb(ob, path)
        dims = [round(float(v), 2) for v in ob.dimensions]
        info.update({"tris": tvkit.tri_count(ob), "materials": [m.name for m in ob.data.materials],
                     "size_m_xyz_blender": dims,
                     "anchors": {ch.name: [round(v, 3) for v in ch.location] for ch in ob.children if ch.type == "EMPTY"},
                     "colliders": [ch.name for ch in ob.children if ch.type == "MESH"]})
        manifest["pieces"][nm] = info
        print("VILLAGE %-30s tris=%6d mats=%s" % (nm, info["tris"], ",".join(m[4:] for m in info["materials"])))
    mp = os.path.join(a.out, "manifest.json")
    if only and os.path.exists(mp):
        old = json.load(open(mp))
        old["pieces"].update(manifest["pieces"])
        manifest = old
    with open(mp, "w") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
    if a.blend:
        bpy.ops.wm.save_as_mainfile(filepath=a.blend)
    print("VILLAGE DONE")


if __name__ == "__main__":
    main()
