"""The Thủy Vân Reed Marches stilt kit (Đồng Lau, dl_*; places_se.md §3 and §9), authored procedurally in Blender in the
World of Warcraft Classic spirit of the style guide: forests of fat piles, three-tier thatch fort, Floodborn-built houses
with 2.8 x 1.8 m sill-less doors, haul-out ramps, reed watch towers, our own heron banners, mangroves with root arches,
reed cards, reed burial boats, dugouts and ferries, tally posts and the submerged causeway. Our own designs after the
Đồng Lau sheet and the Floodborn sheet's homeland panel; nothing copied from any game or show; no writing in any mark.

    zsh tools/thuyvan/bin/blender_run.sh -b -P tools/thuyvan_art/dong_lau/dong_lau_kit.py -- \
        --out assets/thuyvan/dong_lau [--blend X.blend] [--only piece,piece] [--no-lod]

Paint the textures first (paint_dong_lau.py). Writes one GLB per piece (+Y up; Blender -Y = Godot +Z = the piece's
front; over-water pieces have their origin on the water line, piles reaching the bed at -1.8 m), <piece>_lod1.glb for
the pieces with a LOD1 budget, and manifest.json. Materials are tvd_<key> (materials.json); COLOR_0 = baked AO x top
light (multiply into albedo), COLOR_0.a = cloth pin weight / reed wind weight (0 pinned or rooted .. 1 free), 1 elsewhere.
`--blend` also keeps the review-only objects for render_dong_lau.py: the A/C variants of the open choices, the 1.75 m
scale figure, and a Book II look-dev stone lintel (Khar-Ul's, never exported, never in a Book I scene).
"""

import argparse
import json
import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dlkit  # noqa: E402  (must come before village_kit: it rebinds tvkit to this kit)
from dlkit import Builder, frame_from, rot_x, rot_y, rot_z  # noqa: E402
import village_kit as vk  # noqa: E402

BED = -1.8          # the marsh bed under the piles (water line z 0)
PI = math.pi


# ================================================================================================ small parts
def pile(b, x, y, top, r=0.22, bed=BED, lean=(0.0, 0.0), segs=5, caps=True, key="pile", tie=False):
    """A round pile from the bed to `top`, tapering a little; `tie`: a rope wrap at the water line."""
    p0 = np.array([x, y, bed])
    p1 = np.array([x + lean[0] * (top - bed), y + lean[1] * (top - bed), top])
    b.tube([p0, p1], [r * 1.06, r * 0.9], segs, key, caps=caps)
    if tie:
        z = 0.35
        q = p0 + (p1 - p0) * ((z - bed) / (top - bed))
        b.lathe([(r * 1.12, z - 0.12), (r * 1.2, z), (r * 1.12, z + 0.12)], segs, "rope", base=(q[0], q[1], 0.0),
                cap_top=False, cap_bottom=False)


def beam(b, p0, p1, w=0.22, h=0.24, key="timber"):
    b.beam(p0, p1, w, h, key)


def deck(b, x0, x1, y0, y1, z, along="y", w=0.42, collider=None):
    vk.plank_deck(b, x0, x1, y0, y1, z, w=w, gap=0.05, thick=0.12, along=along, key="plank", jitter=0.015)
    if collider:
        b.collider(collider, [[(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]])


def pile_field(b, x0, x1, y0, y1, top, spacing=2.1, r=0.22, jitter=0.25, caps=False, posts_above=0.0,
               beams=True, segs=5):
    """A forest of piles under a deck (top = the deck's underside), beams along X on every row; perimeter piles may
    run `posts_above` past the deck as rail posts (capped)."""
    rng = b.rng
    nx = max(2, int(round((x1 - x0) / spacing)) + 1)
    ny = max(2, int(round((y1 - y0) / spacing)) + 1)
    xs = np.linspace(x0, x1, nx)
    ys = np.linspace(y0, y1, ny)
    n = 0
    for j, y in enumerate(ys):
        for i, x in enumerate(xs):
            edge = i in (0, nx - 1) or j in (0, ny - 1)
            jx = 0.0 if edge else rng.normal(0, jitter)
            jy = 0.0 if edge else rng.normal(0, jitter)
            t = top + (posts_above if edge and posts_above else 0.0)
            pile(b, x + jx, y + jy, t, r=r * rng.uniform(0.85, 1.15), lean=(rng.normal(0, 0.01), rng.normal(0, 0.01)),
                 caps=caps or (edge and posts_above > 0), segs=segs)
            n += 1
        if beams:
            beam(b, (x0 - 0.3, y, top - 0.14), (x1 + 0.3, y, top - 0.14), 0.24, 0.26)
    return n


def rail(b, p0, p1, z, h=1.05, spacing=1.8, key="timber", rope_mid=True, posts=True):
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    L = float(np.linalg.norm(p1 - p0))
    n = max(1, int(L / spacing))
    if posts:
        for k in range(n + 1):
            q = p0 + (p1 - p0) * k / n
            b.tube([(q[0], q[1], z), (q[0], q[1], z + h + 0.08)], 0.075, 5, key)
    b.tube([(p0[0], p0[1], z + h), (p1[0], p1[1], z + h)], 0.07, 5, key, caps=False)
    if rope_mid:
        pts = [p0 + (p1 - p0) * t for t in np.linspace(0, 1, 7)]
        b.tube([(q[0], q[1], z + h * 0.5 - 0.12 * math.sin(PI * k / 6)) for k, q in enumerate(pts)], 0.03, 4, "rope",
               caps=False)


def haul_ramp(b, x, y_edge, z_top, width=2.6, length=5.0, name="ramp"):
    """A Floodborn haul-out: a slick plank slide from the deck edge (at y_edge, facing -Y) down into the water to -0.9,
    side kerbs, two piles holding its foot; walkable (collider)."""
    z_end = -0.9
    y_end = y_edge - length
    d = np.array([0.0, y_end - y_edge, z_end - z_top])
    R = frame_from(d)
    Ls = float(np.linalg.norm(d))
    n = int(width / 0.36)
    for k in range(n):
        xx = x - width / 2 + (k + 0.5) * width / n
        c = np.array([xx, (y_edge + y_end) / 2, (z_top + z_end) / 2 - 0.05])
        b.box(c, (Ls, width / n - 0.04, 0.1), "plank", rot=R, grain=0)
    for s in (-1, 1):
        c = np.array([x + s * (width / 2 + 0.1), (y_edge + y_end) / 2, (z_top + z_end) / 2 + 0.05])
        b.box(c, (Ls, 0.16, 0.24), "timber", rot=R, grain=0)
        pile(b, x + s * (width / 2 + 0.1), y_end + 0.6, z_end + 0.4, r=0.16)
    b.collider(name, [[(x - width / 2, y_edge, z_top), (x + width / 2, y_edge, z_top),
                       (x + width / 2, y_end, z_end), (x - width / 2, y_end, z_end)]])


def steps_down(b, x, y_edge, z_top, width=1.4, dirn=-1, name="steps"):
    """Steps from a deck edge down to the water (0.3 m risers, the last tread at -0.2), on two stringers."""
    nst = int(math.ceil((z_top + 0.2) / 0.3))
    for k in range(nst):
        z = z_top - (k + 1) * (z_top + 0.2) / nst
        y = y_edge + dirn * (k + 0.5) * 0.32
        b.box((x, y, z - 0.05), (width, 0.34, 0.1), "plank", grain=0)
    y_end = y_edge + dirn * nst * 0.32
    for s in (-1, 1):
        beam(b, (x + s * width / 2, y_edge, z_top - 0.1), (x + s * width / 2, y_end, -0.4), 0.1, 0.22)
    b.collider(name, [[(x - width / 2, y_edge, z_top), (x + width / 2, y_edge, z_top),
                       (x + width / 2, y_end, -0.2), (x - width / 2, y_end, -0.2)]])


def lantern(b, c, cord=0.5, name=None, r=0.34, h=0.74):
    """A round paper lantern at 1.3x (0.68 m), low-poly for the marsh's many lanterns: six ribs, dark caps, a madder
    tassel, its cord."""
    c = np.asarray(c, float)
    prof = [(r * (0.55 + 0.45 * math.sin(math.pi * (0.06 + 0.88 * t))), -h / 2 + t * h) for t in np.linspace(0, 1, 5)]
    b.lathe(prof, 6, "paper", base=c, cap_top=False, cap_bottom=False)
    b.lathe([(r * 0.5, -h / 2 - 0.07), (r * 0.6, -h / 2 + 0.02)], 6, "timber", base=c, cap_top=False)
    b.lathe([(r * 0.6, h / 2 - 0.02), (r * 0.48, h / 2 + 0.08)], 6, "timber", base=c, cap_bottom=False)
    b.tube([c + [0, 0, -h / 2 - 0.07], c + [0, 0, -h / 2 - 0.42]], [0.05, 0.015], 4, "cloth_madder", caps=False)
    if cord > 0:
        b.tube([c + [0, 0, h / 2 + 0.08], c + [0, 0, h / 2 + 0.08 + cord]], 0.015, 3, "rope", caps=False)
    if name:
        b.empty(name, c)


def ladder(b, p_ground, p_top, width=0.55, step=0.42):
    """A bamboo ladder, low-poly: two rails and rungs every 0.42 m (4-sided, open-ended)."""
    p0, p1 = np.asarray(p_ground, float), np.asarray(p_top, float)
    d = p1 - p0
    side = np.cross(d, [0, 0, 1])
    side = side / np.linalg.norm(side) * width / 2
    for s in (-1, 1):
        b.tube([p0 + s * side, p1 + s * side + d * 0.06], 0.05, 5, "timber")
    n = int(np.linalg.norm(d) / step)
    for k in range(1, n):
        q = p0 + d * k / n
        b.tube([q - side * 1.12, q + side * 1.12], 0.032, 4, "timber", caps=False)


def heron_banner_on(b, x, y, mast_h=24.0, kind="banner_heron", cloth_w=3.3, cloth_l=10.0, bed=BED, yaw=0.0):
    """DL1/§3: a heron banner on a mast: a 1:3 indigo cloth with our heron in bone (the texture), madder tails, rope
    stays, an iron finial; the mast foot on the bed (or a deck). Faces -Y (turned by yaw)."""
    rng = b.rng
    with b.at((x, y, 0.0), yaw):
        pile(b, 0, 0, mast_h, r=0.2, bed=bed, segs=5)
        b.lathe([(0.16, 0), (0.09, 0.2), (0.17, 0.42), (0.0, 1.1)], 6, "iron", base=(0, 0, mast_h))
        zc = mast_h - 0.9
        beam(b, (-cloth_w / 2 - 0.6, -0.26, zc), (cloth_w / 2 + 0.6, -0.26, zc), 0.16, 0.18)
        for sx in (-1, 1):
            b.tube([(sx * (cloth_w / 2 + 0.5), -0.26, zc + 0.08), (0, -0.05, mast_h - 0.05)], 0.035, 4, "rope",
                   caps=False)
        vk.cloth_sheet(b, (0, -0.4, zc - 0.1), cloth_w, cloth_l, kind, notch=1.3, amp=0.16, waves=1.5, rows=9, cols=4)
        for sx in (-1, 1):
            vk.cloth_sheet(b, (sx * (cloth_w / 2 + 0.34), -0.36, zc - 0.1), 0.42, cloth_l * 0.82 + rng.uniform(-0.5, 0.5),
                           "cloth_madder", notch=0.25, amp=0.06, waves=1, rows=6, cols=1, unit=False,
                           sway=rng.uniform(-0.25, 0.25))
        b.empty("anchor_banner", (0, -0.4, zc - 0.1))


def thatch_roof(b, c, A, B, H, upturn=0.9, flare=0.55, p=0.9, curls=True, ns=8, nt=4, thick=0.45, finial=False):
    if A < B:
        A = B
    return vk.roof(b, c, A, B, H, top="thatch", under="thatch", p=p, upturn=upturn, flare=flare, thick=thick,
                   ridge_r=0.3, hips=True, curls=curls and (A - B) > 0.3, finial=finial, ns=ns, nt=nt,
                   ridge_key="reed")


def box_walls(b, cx, cy, W, D, z0, h, door=None, windows=(), key="weave"):
    """Four walls round a W x D body centred (cx, cy); door = (width, height, sill) on the front (-Y) wall."""
    x0, x1, y0, y1 = cx - W / 2, cx + W / 2, cy - D / 2, cy + D / 2
    ops = []
    if door:
        dw, dh, sill = door
        ops.append((W / 2, dw, sill, sill + dh, "door"))
    for (at, ww) in windows:
        ops.append((at, ww, 1.0, 1.75, "window"))
    vk.wall(b, (x0, y0), (x1, y0), z0, h, key=key, openings=ops)
    vk.wall(b, (x1, y0), (x1, y1), z0, h, key=key, openings=[(D / 2, 0.8, 1.0, 1.7, "window")] if D > 4 else [])
    vk.wall(b, (x1, y1), (x0, y1), z0, h, key=key)
    vk.wall(b, (x0, y1), (x0, y0), z0, h, key=key)


def basket(b, c, r=0.35, h=0.45):
    c = np.asarray(c, float)
    b.lathe([(r * 0.7, 0.0), (r, h * 0.45), (r * 0.92, h), (r * 0.7, h * 1.05)], 8, "screen", base=c, cap_top=False)


def jar(b, c, r=0.3, h=0.6):
    b.lathe([(r * 0.55, 0.0), (r, h * 0.4), (r * 0.8, h * 0.85), (r * 0.5, h), (r * 0.55, h * 1.08)], 8, "clay",
            base=c, cap_top=False)


def fish_on(b, p, s=1.0, yaw=0.0):
    """One split dried fish hanging by its tail at p: a flat diamond (two quads), 0.5 m."""
    p = np.asarray(p, float)
    R = rot_z(yaw)
    L, Wf = 0.52 * s, 0.17 * s
    pts = [p, p + R @ [Wf / 2, 0, -L * 0.45], p + R @ [0, 0, -L], p + R @ [-Wf / 2, 0, -L * 0.45]]
    b.face([pts[0], pts[1], pts[2], pts[3]], "fish", uvs=[(0.5, 1), (1, 0.55), (0.5, 0), (0, 0.55)])


# ================================================================================================ DL1 the mooring fort
FORT_STYLES = {
    #        upturn flare  p    tier heights           roof H         over
    "A": dict(up=0.35, fl=0.2, p=1.05, walls=(4.0, 4.6, 3.6), H=(3.4, 3.2, 4.6), over=1.6, curls=False),
    "B": dict(up=1.0, fl=0.6, p=0.9, walls=(4.2, 5.0, 3.8), H=(4.0, 3.6, 5.6), over=2.2, curls=True),
    "C": dict(up=1.9, fl=1.15, p=0.8, walls=(4.4, 5.4, 4.2), H=(4.8, 4.4, 7.0), over=3.0, curls=True),
}


def mooring_fort(name="dl_mooring_fort", style="B", seed=301):
    """DL1: the mooring fort. A 30 x 30 m pile platform (about 225 piles, 0.44 m thick, ~2x real) with its deck 2.8 m
    over the water; a three-tier tower-house of thatch and woven walls (galleries round the second tier), 30-34 m to
    the finial; four 24 m masts with 10 m heron banners; lanterns along the galleries; haul-out ramps on the front and
    west sides, steps on the east; Floodborn doors (2.8 x 1.8 m, no sill)."""
    S = FORT_STYLES[style]
    b = Builder(name, seed)
    rng = b.rng
    z = 2.8
    half = 15.0
    n_piles = pile_field(b, -half + 0.5, half - 0.5, -half + 0.5, half - 0.5, z - 0.12, spacing=2.08, r=0.22,
                         posts_above=1.25)
    deck(b, -half, half, -half, half, z, along="y", w=0.46, collider="fort_deck")
    for (p0, p1) in (((-half + 0.5, -half + 0.5), (-5.0, -half + 0.5)), ((5.0, -half + 0.5), (half - 0.5, -half + 0.5)),
                     ((half - 0.5, -half + 0.5), (half - 0.5, -2.0)), ((half - 0.5, 2.5), (half - 0.5, half - 0.5)),
                     ((half - 0.5, half - 0.5), (-half + 0.5, half - 0.5)),
                     ((-half + 0.5, half - 0.5), (-half + 0.5, 3.0)), ((-half + 0.5, -2.0), (-half + 0.5, -half + 0.5))):
        rail(b, p0, p1, z, h=1.15, spacing=2.08, posts=False)
    # haul-out ramps: front (centre) and west; steps on the east
    haul_ramp(b, 0.0, -half, z, width=4.0, length=6.5, name="ramp_front")
    with b.at((-half, 0.5, 0.0), -PI / 2):
        haul_ramp(b, 0.0, 0.0, z, width=3.6, length=6.0, name="ramp_west")
    with b.at((half, 0.25, 0.0), PI / 2):
        steps_down(b, 0.0, 0.0, z, width=1.6, name="steps_east")
    # the tower-house: three tiers
    w1, w2, w3 = S["walls"]
    H1, H2, H3 = S["H"]
    ov = S["over"]
    cy = 1.5
    # tier 1: the hall 18 x 15, veranda posts round it
    W1, D1 = 18.0, 15.0
    box_walls(b, 0, cy, W1, D1, z, w1, door=(1.8, 2.8, 0.0), windows=[(3.5, 1.0), (14.5, 1.0)])
    for x in np.linspace(-W1 / 2 - 1.2, W1 / 2 + 1.2, 6):
        for y in (cy - D1 / 2 - 1.2, cy + D1 / 2 + 1.2):
            b.tube([(x, y, z), (x, y, z + w1 + 0.3)], 0.17, 6, "timber")
    for y in np.linspace(cy - D1 / 2 - 1.2, cy + D1 / 2 + 1.2, 5)[1:-1]:
        for x in (-W1 / 2 - 1.2, W1 / 2 + 1.2):
            b.tube([(x, y, z), (x, y, z + w1 + 0.3)], 0.17, 6, "timber")
    e1 = z + w1 + 0.3
    for y in (cy - D1 / 2 - 1.2, cy + D1 / 2 + 1.2):
        beam(b, (-W1 / 2 - 1.6, y, e1), (W1 / 2 + 1.6, y, e1), 0.24, 0.3)
    for x in (-W1 / 2 - 1.2, W1 / 2 + 1.2):
        beam(b, (x, cy - D1 / 2 - 1.6, e1), (x, cy + D1 / 2 + 1.6, e1), 0.24, 0.3)
    thatch_roof(b, (0, cy, e1 + 0.15), W1 / 2 + 1.2 + ov, D1 / 2 + 1.2 + ov, H1, upturn=S["up"], flare=S["fl"],
                p=S["p"], curls=S["curls"])
    # tier 2: 12 x 10.5 rising out of the first roof, a gallery round it
    W2, D2 = 12.0, 10.5
    z2 = e1 + H1 * 0.55
    vk.plank_deck(b, -W2 / 2 - 1.5, W2 / 2 + 1.5, cy - D2 / 2 - 1.5, cy + D2 / 2 + 1.5, z2, w=0.46, gap=0.05,
                  thick=0.12, along="y", key="plank")
    b.collider("gallery", [[(-W2 / 2 - 1.5, cy - D2 / 2 - 1.5, z2), (W2 / 2 + 1.5, cy - D2 / 2 - 1.5, z2),
                            (W2 / 2 + 1.5, cy + D2 / 2 + 1.5, z2), (-W2 / 2 - 1.5, cy + D2 / 2 + 1.5, z2)]])
    gx, gy0, gy1 = W2 / 2 + 1.35, cy - D2 / 2 - 1.35, cy + D2 / 2 + 1.35
    for (p0, p1) in (((-gx, gy0), (gx, gy0)), ((gx, gy0), (gx, gy1)), ((gx, gy1), (-gx, gy1)), ((-gx, gy1), (-gx, gy0))):
        rail(b, p0, p1, z2, h=1.0, spacing=1.7)
    box_walls(b, 0, cy, W2, D2, z2, w2, door=(1.8, 2.8, 0.0), windows=[(2.5, 1.0), (9.5, 1.0)])
    e2 = z2 + w2 + 0.2
    for y in (cy - D2 / 2, cy + D2 / 2):
        beam(b, (-W2 / 2 - 0.8, y, e2), (W2 / 2 + 0.8, y, e2), 0.22, 0.28)
    thatch_roof(b, (0, cy, e2 + 0.1), W2 / 2 + ov, D2 / 2 + ov, H2, upturn=S["up"] * 0.9, flare=S["fl"] * 0.9,
                p=S["p"], curls=S["curls"], ns=6)
    # tier 3: the lookout 7 x 6
    W3, D3 = 7.0, 6.0
    z3 = e2 + H2 * 0.55
    box_walls(b, 0, cy, W3, D3, z3, w3, windows=[(1.6, 0.9), (5.4, 0.9)])
    e3 = z3 + w3 + 0.15
    top = thatch_roof(b, (0, cy, e3), W3 / 2 + ov * 0.8, D3 / 2 + ov * 0.8, H3, upturn=S["up"] * 0.8,
                      flare=S["fl"] * 0.8, p=S["p"], curls=S["curls"], ns=6)
    b.tube([(0, cy, top - 0.5), (0, cy, top + 3.2)], [0.16, 0.1], 6, "timber")
    b.lathe([(0.2, 0), (0.12, 0.25), (0.22, 0.5), (0.0, 1.3)], 6, "iron", base=(0, cy, top + 3.2))
    # four heron banners on 24 m masts at the platform's corners (their feet through the deck to the bed)
    for (x, y, yw) in ((-half + 1.4, -half + 1.4, 0.0), (half - 1.4, -half + 1.4, 0.0),
                       (-half + 1.4, half - 1.4, PI), (half - 1.4, half - 1.4, PI)):
        heron_banner_on(b, x, y, mast_h=24.0, kind="banner_heron")
    # lanterns: the platform's front rail, the hall's eaves, the gallery corners
    k = 0
    for x in (-10.0, -4.0, 4.0, 10.0):
        lantern(b, (x, -half - 0.1, z + 2.35), cord=0.35, name="anchor_lantern_%d" % k)
        b.tube([(x, -half + 0.5, z), (x, -half + 0.5, z + 3.3)], 0.07, 5, "timber")
        beam(b, (x, -half + 0.6, z + 3.2), (x, -half - 0.25, z + 3.2), 0.08, 0.1)
        k += 1
    for (x, y) in ((-W1 / 2 - 1.2, cy - D1 / 2 - 1.2), (W1 / 2 + 1.2, cy - D1 / 2 - 1.2), (-2.4, cy - D1 / 2 - 1.2),
                   (2.4, cy - D1 / 2 - 1.2)):
        lantern(b, (x, y, e1 - 0.9), cord=0.6, name="anchor_lantern_%d" % k)
        k += 1
    for (x, y) in ((-gx, gy0), (gx, gy0)):
        lantern(b, (x, y, e2 - 0.9), cord=0.8, name="anchor_lantern_%d" % k)
        k += 1
    b.empty("anchor_door", (0, cy - D1 / 2, z))
    b.empty("anchor_smoke", (5.0, cy + 2.0, e1 + H1 * 0.5))
    for (x, y) in ((-6.0, -half - 0.3), (6.0, -half - 0.3), (-half - 0.3, -8.0), (half - 0.3, 9.0)):
        b.empty("anchor_mooring", (x, y, 0.4))
    # dressing on the deck: baskets, jars, a fish rack along the east rail
    for k in range(5):
        basket(b, (-11.0 + k * 0.8 + rng.uniform(-0.1, 0.1), -half + 1.8 + rng.uniform(0, 0.4), z), r=0.38)
    for k in range(3):
        jar(b, (11.0 - k * 0.75, -half + 1.6, z), r=0.32, h=0.7)
    return b, top + 4.5, n_piles


# ================================================================================================ platforms and piles
def pile_forest(name, size, n, seed):
    """A merged pile cluster (size x size m): 0.35-0.5 m piles from the bed, some leaning, tied in pairs at the water
    line, two cross braces; a box collider for boats."""
    b = Builder(name, seed)
    rng = b.rng
    pts = []
    while len(pts) < n:
        p = rng.uniform(-size / 2 + 0.3, size / 2 - 0.3, 2)
        if all(np.hypot(*(p - q)) > 0.75 for q in pts):
            pts.append(p)
    for p in pts:
        pile(b, p[0], p[1], rng.uniform(1.6, 3.4), r=rng.uniform(0.18, 0.25),
             lean=(rng.normal(0, 0.03), rng.normal(0, 0.03)), segs=6, tie=rng.random() < 0.5)
    for k in range(2):
        i, j = rng.choice(len(pts), 2, replace=False)
        beam(b, (*pts[i], 1.2), (*pts[j], 0.2), 0.12, 0.16)
    s = size / 2
    b.collider("boat_block", [[(-s, -s, BED), (s, -s, BED), (s, -s, 3.0), (-s, -s, 3.0)],
                              [(s, -s, BED), (s, s, BED), (s, s, 3.0), (s, -s, 3.0)],
                              [(s, s, BED), (-s, s, BED), (-s, s, 3.0), (s, s, 3.0)],
                              [(-s, s, BED), (-s, -s, BED), (-s, -s, 3.0), (-s, s, 3.0)]])
    return b, 3.4


def platform(name, W, D, z, ramp=True, seed=320, mooring=True):
    """A plank platform on piles: deck z over the water, rope rail on the back and sides, a haul-out ramp (or steps)
    to the water at the front; a mooring post with a tied ring."""
    b = Builder(name, seed)
    pile_field(b, -W / 2 + 0.3, W / 2 - 0.3, -D / 2 + 0.3, D / 2 - 0.3, z - 0.12, spacing=2.0, r=0.21,
               posts_above=1.1)
    deck(b, -W / 2, W / 2, -D / 2, D / 2, z, collider="deck")
    rail(b, (-W / 2 + 0.3, D / 2 - 0.3), (W / 2 - 0.3, D / 2 - 0.3), z, h=1.1, posts=False, spacing=2.0)
    rail(b, (W / 2 - 0.3, -D / 2 + 0.3), (W / 2 - 0.3, D / 2 - 0.3), z, h=1.1, posts=False, spacing=2.0)
    if ramp:
        haul_ramp(b, -W / 4, -D / 2, z, width=2.6, length=4.6)
    else:
        steps_down(b, -W / 4, -D / 2, z, width=1.4)
    if mooring:
        pile(b, W / 2 - 0.8, -D / 2 - 0.9, z + 1.4, r=0.18, segs=6, tie=True)
        b.lathe([(0.22, -0.05), (0.26, 0.0), (0.22, 0.05)], 8, "iron", base=(W / 2 - 0.8, -D / 2 - 0.9, z + 0.9),
                cap_top=False, cap_bottom=False)
        b.empty("anchor_mooring", (W / 2 - 0.8, -D / 2 - 0.9, 0.4))
    return b, z + 1.4


# ================================================================================================ houses
def reed_house(name, kind, seed):
    """a: Floodborn-built (door 2.8 x 1.8 m, no sill; a veranda bench in two runs with a 0.5 m tail gap; a soaking
    trough at the door; a haul-out ramp). b: a human house at the public standard (door 2.4 x 1.3 m, 8 cm sill; steps to
    the water). c: the kitchen hut (open sides, a clay hearth at the edge so the smoke rolls on the water, a mangrove
    root up through the floor: the bible's sensory anchor)."""
    b = Builder(name, seed)
    rng = b.rng
    if kind == "a":
        W, D, z, wh, H, over, ver = 6.6, 5.2, 1.8, 3.5, 5.0, 1.5, 2.4
    elif kind == "b":
        W, D, z, wh, H, over, ver = 5.0, 4.0, 1.6, 2.7, 3.8, 1.2, 1.6
    else:
        W, D, z, wh, H, over, ver = 4.0, 3.4, 1.2, 2.3, 2.9, 1.0, 0.8
    PW, PD = W + 1.6, D + ver + 0.6
    pcy = (ver - 0.6) / -2.0
    y_front = pcy - PD / 2
    pile_field(b, -PW / 2 + 0.3, PW / 2 - 0.3, y_front + 0.3, y_front + PD - 0.3, z - 0.12, spacing=2.0, r=0.2,
               posts_above=0.0)
    deck(b, -PW / 2, PW / 2, y_front, y_front + PD, z, collider="deck")
    hy = y_front + ver + D / 2 + 0.3        # the house body's centre
    if kind == "a":
        box_walls(b, 0, hy, W, D, z, wh, door=(1.8, 2.8, 0.0), windows=[(1.2, 0.9), (W - 1.2, 0.9)])
        # the bench: two runs with a 0.5 m tail gap between them (and none against the door)
        yb = hy - D / 2 - 0.42
        for (x0, x1) in ((-W / 2 + 0.25, -1.75), (1.75, W / 2 - 0.25)):
            # each side of the door: two seat runs split by a 0.5 m tail gap
            mid = (x0 + x1) / 2
            for (a0, a1) in ((x0, mid - 0.25), (mid + 0.25, x1)):
                b.box(((a0 + a1) / 2, yb, z + 0.45), (a1 - a0, 0.5, 0.1), "plank", grain=0)
                for xx in (a0 + 0.15, a1 - 0.15):
                    b.box((xx, yb, z + 0.2), (0.12, 0.42, 0.4), "timber", grain=2)
        # the soaking trough by the door
        tx = 1.55 + 0.9
        b.box((tx, hy - D / 2 - 1.55, z + 0.32), (1.9, 0.08, 0.64), "timber", grain=0)
        b.box((tx, hy - D / 2 - 0.85, z + 0.32), (1.9, 0.08, 0.64), "timber", grain=0)
        for s in (-1, 1):
            b.box((tx + s * 0.95, hy - D / 2 - 1.2, z + 0.32), (0.08, 0.78, 0.64), "timber", grain=1)
        b.box((tx, hy - D / 2 - 1.2, z + 0.48), (1.84, 0.64, 0.04), "clay", grain=0)
        b.empty("anchor_soak_trough", (tx, hy - D / 2 - 1.2, z + 0.5))
        haul_ramp(b, -PW / 4 - 0.4, y_front, z, width=2.4, length=4.4)
        b.tube([(-PW / 2 + 0.25, y_front + 0.25, z), (-PW / 2 + 0.25, y_front + 0.25, z + 2.2)], 0.12, 6, "timber")
    elif kind == "b":
        box_walls(b, 0, hy, W, D, z, wh, door=(1.3, 2.4, 0.08), windows=[(1.0, 0.8)])
        b.box((0, hy - D / 2, z + 0.04), (1.5, 0.16, 0.08), "timber", grain=0)       # the 8 cm sill
        with b.at((PW / 2, y_front + 1.2, 0.0), PI / 2):
            steps_down(b, 0.0, 0.0, z, width=1.2)
        rail(b, (-PW / 2 + 0.2, y_front + 0.2), (-0.6, y_front + 0.2), z, h=0.95, spacing=1.4)
        for k in range(3):
            jar(b, (PW / 2 - 0.6 - k * 0.65, y_front + 0.6, z), r=0.28, h=0.62)
    else:
        for (x, y) in ((-W / 2, hy - D / 2), (W / 2, hy - D / 2), (-W / 2, hy + D / 2), (W / 2, hy + D / 2)):
            b.tube([(x, y, z), (x, y, z + wh + 0.2)], 0.14, 6, "timber")
        vk.wall(b, (W / 2, hy + D / 2), (-W / 2, hy + D / 2), z, 1.1, key="weave")
        vk.wall(b, (-W / 2, hy + D / 2), (-W / 2, hy - D / 2), z, 1.1, key="weave")
        # the clay hearth at the front edge, a pot, firewood
        hx, hyy = 0.6, y_front + 0.75
        b.box((hx, hyy, z + 0.28), (1.3, 1.0, 0.56), "clay", grain=0)
        b.lathe([(0.34, 0.0), (0.42, 0.18), (0.36, 0.38), (0.3, 0.42)], 8, "iron", base=(hx, hyy, z + 0.56),
                cap_top=False)
        b.empty("anchor_smoke", (hx, hyy, z + 1.0))
        b.empty("anchor_hearth_light", (hx, hyy, z + 0.7))
        for k in range(5):
            b.tube([(-1.4, hyy - 0.2 + k * 0.16, z + 0.1 + (k % 2) * 0.16), (-0.3, hyy - 0.25 + k * 0.16,
                                                                              z + 0.1 + (k % 2) * 0.16)], 0.08, 5,
                   "timber")
        # a mangrove root arching up through the floor
        for s in (-1, 1):
            pts = [(s * 1.4 - 1.0, hy + 0.5, BED), (s * 1.2 - 0.6, hy + 0.2, z - 0.3), (s * 0.6 - 0.2, hy - 0.1, z + 0.9),
                   (s * 0.2, hy - 0.3, z + 1.3), (s * -0.6 + 0.4, hy - 0.6, z + 0.6), (s * -1.1 + 0.8, hy - 1.0, BED)]
            b.tube(pts, [0.24, 0.22, 0.2, 0.18, 0.2, 0.22], 6, "bark")
        # fish hanging under the eave
        for k in range(6):
            fish_on(b, (-W / 2 + 0.6 + k * 0.5, hy - D / 2 + 0.2, z + wh - 0.1), 1.0, rng.normal(0, 0.2))
        b.tube([(-W / 2, hy - D / 2 + 0.2, z + wh - 0.05), (W / 2, hy - D / 2 + 0.2, z + wh - 0.05)], 0.04, 4, "bamboo")
    e = z + wh + 0.15
    for y in (hy - D / 2, hy + D / 2):
        beam(b, (-W / 2 - 0.5, y, e - 0.1), (W / 2 + 0.5, y, e - 0.1), 0.2, 0.22)
    for x in (-W / 2, W / 2):
        beam(b, (x, hy - D / 2 - ver * 0.9, e - 0.05), (x, hy + D / 2 + 0.4, e - 0.05), 0.2, 0.22)
    if kind != "c":
        for x in (-W / 2 - 0.1, W / 2 + 0.1):
            b.tube([(x, hy - D / 2 - ver * 0.85, z), (x, hy - D / 2 - ver * 0.85, e)], 0.13, 6, "timber")
    cy = hy - ver * 0.4
    top = thatch_roof(b, (0, cy, e), W / 2 + over, (D + ver * 0.8) / 2 + over * 0.8, H, upturn=0.8, flare=0.5,
                      p=0.88, ns=8, nt=5)
    lantern(b, (W / 2 - 0.3, hy - D / 2 - ver * 0.85, e - 0.8), cord=0.4, name="anchor_lantern_door")
    b.empty("anchor_door", (0, hy - D / 2, z))
    if kind != "c":
        b.empty("anchor_smoke", (0, cy, e + H * 0.5))
    b.empty("anchor_mooring", (-PW / 2 - 0.4, y_front - 0.4, 0.4))
    return b, top


def raft_house(name="dl_raft_house", seed=341):
    """DL6: a floating house: a raft of logs riding half under the water line, a woven house with a thatch roof, a
    veranda with a clay hearth at the very edge (smoke on the water), screens drying on poles, ropes to two mooring
    poles. Origin on the water line."""
    b = Builder(name, seed)
    rng = b.rng
    L, Wd = 8.5, 5.4
    for k in range(10):
        y = -Wd / 2 + (k + 0.5) * Wd / 10
        b.tube([(-L / 2 + rng.uniform(-0.2, 0.2), y, 0.02), (L / 2 + rng.uniform(-0.2, 0.2), y, 0.02)],
               [0.27, 0.25], 6, "pile")
    for x in (-L / 2 + 0.6, 0.0, L / 2 - 0.6):
        beam(b, (x, -Wd / 2 - 0.2, 0.3), (x, Wd / 2 + 0.2, 0.3), 0.18, 0.16)
    z = 0.42
    deck(b, -L / 2 + 0.3, L / 2 - 0.3, -Wd / 2 + 0.2, Wd / 2 - 0.2, z, along="y", collider="raft_deck")
    W, D, wh = 5.0, 3.4, 2.5
    hx, hy = 0.8, 0.7
    box_walls(b, hx, hy, W, D, z, wh, door=(1.3, 2.4, 0.06), windows=[(1.0, 0.8)])
    e = z + wh + 0.15
    for y in (hy - D / 2, hy + D / 2):
        beam(b, (hx - W / 2 - 0.4, y, e - 0.1), (hx + W / 2 + 0.4, y, e - 0.1), 0.18, 0.2)
    for x in (hx - W / 2 - 0.05, hx + W / 2 + 0.05):
        b.tube([(x, hy - D / 2 - 1.3, z), (x, hy - D / 2 - 1.3, e)], 0.12, 6, "timber")
        beam(b, (x, hy - D / 2 - 1.5, e - 0.05), (x, hy + D / 2 + 0.3, e - 0.05), 0.18, 0.2)
    top = thatch_roof(b, (hx, hy - 0.6, e), W / 2 + 1.2, (D + 1.4) / 2 + 1.0, 3.4, upturn=0.75, flare=0.45, p=0.88)
    # the hearth at the raft's edge
    b.box((-L / 2 + 1.0, -Wd / 2 + 0.9, z + 0.25), (1.1, 0.9, 0.5), "clay", grain=0)
    b.empty("anchor_smoke", (-L / 2 + 1.0, -Wd / 2 + 0.9, z + 0.9))
    b.empty("anchor_hearth_light", (-L / 2 + 1.0, -Wd / 2 + 0.9, z + 0.6))
    # screens drying on two poles at the stern
    for x in (-L / 2 + 0.4, -L / 2 + 2.6):
        b.tube([(x, Wd / 2 - 0.15, z), (x, Wd / 2 - 0.15, z + 2.6)], 0.06, 5, "bamboo")
    b.tube([(-L / 2 + 0.3, Wd / 2 - 0.15, z + 2.5), (-L / 2 + 2.7, Wd / 2 - 0.15, z + 2.5)], 0.05, 5, "bamboo")
    with b.at((0, 0, 0), PI):
        for k in range(2):
            vk.cloth_sheet(b, (L / 2 - 0.9 - k * 1.15, -(Wd / 2 - 0.21), z + 2.45), 1.0, 1.7, "screen", amp=0.05,
                           waves=1, rows=4, cols=2, unit=False)
    lantern(b, (hx + W / 2 - 0.2, hy - D / 2 - 1.3, e - 0.8), cord=0.4, name="anchor_lantern_door")
    # mooring poles and ropes
    for (x, y) in ((-L / 2 - 1.6, -Wd / 2 - 1.2), (L / 2 + 1.6, Wd / 2 + 1.2)):
        pile(b, x, y, 2.6, r=0.18, segs=6, tie=True)
        sx = -L / 2 if x < 0 else L / 2
        sy = -Wd / 2 if y < 0 else Wd / 2
        b.tube([(sx, sy, 0.45), ((sx + x) / 2, (sy + y) / 2, 0.2), (x, y, 1.6)], 0.04, 4, "rope", caps=False)
    b.empty("anchor_door", (hx, hy - D / 2, z))
    return b, top


# ================================================================================================ DL2 watch tower
def watch_tower(name="dl_watch_tower", style="B", seed=351):
    """DL2: a reed watch tower: four splayed piles from the bed to a 16.5 m lookout deck (~2x real), X-braced in four
    bands, a ladder up the front from a landing at the water, a thatched cap, a lantern and a horn. A: a plain pyramid
    cap; B (default): a hip cap with upturned corners and curled ridge ends; C: a two-tier cap with a pennant pole."""
    b = Builder(name, seed)
    zt = 16.5
    lo, hi = 2.3, 1.35
    legs = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            p0 = np.array([sx * lo, sy * lo, BED])
            p1 = np.array([sx * hi, sy * hi, zt])
            b.tube([p0, p1], [0.25, 0.19], 6, "pile")
            legs.append((p0, p1))

    def at(sx, sy, z):
        t = (z - BED) / (zt - BED)
        return np.array([sx * (lo + (hi - lo) * t), sy * (lo + (hi - lo) * t), z])
    bands = [BED + 1.0, 3.2, 7.6, 12.0, zt - 0.3]
    for (sa, sb) in (((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))):
        for k in range(len(bands) - 1):
            z0, z1 = bands[k], bands[k + 1]
            b.tube([at(*sa, z0), at(*sb, z1)], 0.075, 4, "timber", caps=False)
            b.tube([at(*sb, z0), at(*sa, z1)], 0.075, 4, "timber", caps=False)
            b.tube([at(*sa, z1), at(*sb, z1)], 0.09, 4, "timber", caps=False)
    deck(b, -hi - 0.5, hi + 0.5, -hi - 0.5, hi + 0.5, zt, along="x", w=0.36, collider="lookout")
    g = hi + 0.42
    for (p0, p1) in (((-g, -g), (g, -g)), ((g, -g), (g, g)), ((g, g), (-g, g)), ((-g, g), (-g, -g))):
        rail(b, p0, p1, zt, h=1.1, spacing=3.2, rope_mid=False)
    # the landing at the water and the ladder up the front face
    deck(b, -1.2, 1.2, -lo - 1.6, -lo + 0.2, 0.6, along="x", w=0.36, collider="landing")
    for x in (-1.0, 1.0):
        pile(b, x, -lo - 1.4, 0.48, r=0.15)
    ladder(b, (0.0, -lo - 0.3, 0.6), (0.0, -hi - 0.45, zt), width=0.6)
    # the cap
    cz = zt + 2.3
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.tube([(sx * (hi + 0.3), sy * (hi + 0.3), zt), (sx * (hi + 0.3), sy * (hi + 0.3), cz)], 0.1, 5, "timber")
    if style == "A":
        top = vk.roof(b, (0, 0, cz), 2.7, 2.7, 3.4, top="thatch", under="thatch", p=1.0, upturn=0.0, flare=0.0,
                      thick=0.35, ridge=False, hips=True, ns=6, nt=4, ridge_key="reed")
    elif style == "B":
        top = thatch_roof(b, (0, 0, cz), 3.2, 2.6, 3.0, upturn=0.9, flare=0.55, p=0.88, ns=6, nt=4)
    else:
        thatch_roof(b, (0, 0, cz), 3.4, 2.8, 2.0, upturn=1.1, flare=0.7, p=0.85, curls=False, ns=6, nt=4)
        for sx in (-1, 1):
            b.tube([(sx * 0.9, 0, cz + 1.2), (sx * 0.9, 0, cz + 2.4)], 0.09, 5, "timber")
        top = thatch_roof(b, (0, 0, cz + 2.4), 1.9, 1.5, 1.8, upturn=0.8, flare=0.5, p=0.85, ns=6, nt=4)
        b.tube([(0, 0, top - 0.2), (0, 0, top + 3.0)], 0.06, 5, "timber")
        vk.cloth_sheet(b, (0.45, -0.05, top + 2.9), 0.9, 2.2, "banner_heron", notch=0.4, amp=0.1, rows=5, cols=2)
        top += 3.0
    lantern(b, (hi + 0.3, -hi - 0.3, cz - 0.7), cord=0.4, name="anchor_lantern")
    # the horn on the rail
    hp = [np.array([-g, -0.3, zt + 1.15]) + np.array([0.0, -0.25 * math.sin(t * 1.6), 0.18 * t + 0.2 * t * t])
          for t in np.linspace(0, 1, 6)]
    b.tube(hp, [0.04, 0.05, 0.06, 0.08, 0.11, 0.14], 6, "clay", caps=False)
    b.empty("anchor_mooring", (0.0, -lo - 1.9, 0.4))
    return b, top


# ================================================================================================ the heron banner
def banner_piece(name="dl_heron_banner", kind="banner_heron", seed=361):
    b = Builder(name, seed)
    heron_banner_on(b, 0.0, 0.0, mast_h=24.0, kind=kind)
    pile(b, 0.0, 0.0, 0.9, r=0.38, segs=6, tie=True)     # the mast's foot sleeve at the water line
    b.empty("anchor_mooring", (0.0, -0.5, 0.4))
    return b, 25.1


# ================================================================================================ DL7 tally post, causeway
def tally_post(name="dl_tally_post", seed=371):
    """A law and causeway marker: a squared post 0.32 m from the bed to 2.2 m with the tally face (cut notches in fours
    and a slash, a ring cut at the top), three tied pegs and a rag strip; marks only, never writing."""
    b = Builder(name, seed)
    s = 0.16
    z0, z1 = BED, 2.2
    # four faces, the front (-Y) with the tally texture over its full height (unit UV)
    fr = [(-s, -s, z0), (s, -s, z0), (s, -s, z1), (-s, -s, z1)]
    b.face(fr, "tally", uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
    for q in ([(s, -s, z0), (s, s, z0), (s, s, z1), (s, -s, z1)], [(s, s, z0), (-s, s, z0), (-s, s, z1), (s, s, z1)],
              [(-s, s, z0), (-s, -s, z0), (-s, -s, z1), (-s, s, z1)]):
        b.face(q, "pile")
    b.lathe([(s * 1.45, 0.0), (s * 0.7, 0.32), (0.0, 0.4)], 4, "pile", base=(0, 0, z1), rot=rot_z(PI / 4), cap_bottom=True)
    for k, z in enumerate((1.75, 1.35, 0.95)):
        a = k * 2.1
        d = np.array([math.cos(a), math.sin(a), 0.0])
        b.tube([np.array([0, 0, z]) + d * 0.1, np.array([0, 0, z - 0.06]) + d * 0.55], [0.045, 0.03], 5, "timber")
        b.lathe([(s * 1.5, z - 0.05), (s * 1.6, z + 0.03), (s * 1.5, z + 0.1)], 6, "rope", base=(0, 0, 0),
                cap_top=False, cap_bottom=False)
    vk.cloth_sheet(b, (s + 0.04, -s - 0.02, 1.92), 0.16, 0.7, "cloth_madder", notch=0.06, amp=0.03, waves=1, rows=4,
                   cols=1, unit=False, sway=0.08)
    return b, z1 + 0.4


def causeway(name="dl_causeway", seed=381):
    """DL7: a hidden causeway module, 5 m along Y: a 1.2 m plank path whose top lies 15 cm under the water line, on
    short stakes; walkable (collider); a notched peg at its far end marks it for those who know."""
    b = Builder(name, seed)
    rng = b.rng
    zt = -0.15
    vk.plank_deck(b, -0.6, 0.6, 0.0, 5.0, zt, w=0.42, gap=0.04, thick=0.08, along="x", key="plank", jitter=0.02)
    for y in (0.5, 2.5, 4.5):
        beam(b, (-0.7, y, zt - 0.12), (0.7, y, zt - 0.12), 0.14, 0.14)
        for x in (-0.55, 0.55):
            pile(b, x, y, zt - 0.1, r=0.09, segs=4, caps=False, lean=(rng.normal(0, 0.02), 0.0))
    b.collider("path", [[(-0.6, 0.0, zt), (0.6, 0.0, zt), (0.6, 5.0, zt), (-0.6, 5.0, zt)]])
    b.tube([(0.75, 4.8, BED), (0.75, 4.8, 0.62)], [0.07, 0.055], 5, "pile")
    b.lathe([(0.075, 0.4), (0.085, 0.47), (0.075, 0.54)], 5, "rope", base=(0.75, 4.8, 0.0), cap_top=False,
            cap_bottom=False)
    for k in range(3):
        b.box((0.75, 4.8 - 0.07, 0.15 + k * 0.08), (0.08, 0.02, 0.02), "iron", grain=0)
    return b, 0.62


# ================================================================================================ screens, racks, nets
def screen_rack(name="dl_screen_rack", seed=391):
    """Woven screens drying on poles (the bible's sensory anchor): three bamboo poles, two crossbars, four screens."""
    b = Builder(name, seed)
    rng = b.rng
    xs = (-2.2, 0.0, 2.2)
    for x in xs:
        b.tube([(x, 0, 0), (x + rng.normal(0, 0.04), 0, 2.9)], [0.07, 0.055], 5, "bamboo")
    for z in (2.75, 1.5):
        b.tube([(-2.5, -0.06, z), (2.5, -0.06, z)], 0.045, 5, "bamboo")
    for k, x in enumerate((-1.65, -0.55, 0.55, 1.65)):
        vk.cloth_sheet(b, (x, -0.12, 2.72), 1.0, 1.6 + rng.uniform(-0.15, 0.15), "screen", amp=0.05, waves=1,
                       rows=4, cols=2, unit=False, sway=rng.uniform(-0.06, 0.06))
    return b, 2.9


def fish_rack(name="dl_fish_rack", seed=392):
    """PROPOSAL id: split fish drying on an A-frame rack (the sheet's 'Moorings & Means'): two A-frames 2.5 m, three
    rods, 30 fish."""
    b = Builder(name, seed)
    rng = b.rng
    for x in (-2.0, 2.0):
        for s in (-1, 1):
            b.tube([(x, s * 0.7, 0.0), (x, 0.0, 2.5)], 0.06, 5, "bamboo")
    for k, z in enumerate((2.35, 1.75, 1.15)):
        y = 0.7 * (1 - (z / 2.5)) * (1 if k % 2 else -1)
        b.tube([(-2.3, y, z), (2.3, y, z)], 0.035, 5, "bamboo")
        for i in range(10):
            fish_on(b, (-1.8 + i * 0.4 + rng.uniform(-0.05, 0.05), y, z - 0.02), rng.uniform(0.85, 1.15),
                    rng.normal(0, 0.25))
    return b, 2.5


def dip_net(name="dl_dip_net", seed=393):
    """PROPOSAL id: the marsh lift net (the sheet's 'Fishing Grounds'): a 9 m lever pole on an A-frame at a platform
    edge, four bamboo arms holding a 4 x 4 m net raised over the water. Origin at the A-frame's foot on the deck."""
    b = Builder(name, seed)
    for s in (-1, 1):
        b.tube([(s * 0.9, 0.4, 0.0), (0.0, 0.0, 2.6)], 0.08, 5, "bamboo")
    piv = np.array([0.0, 0.0, 2.6])
    tip = piv + np.array([0.0, -6.4, 2.3])
    butt = piv + np.array([0.0, 2.6, -1.6])
    b.tube([butt, piv, tip], [0.12, 0.1, 0.06], 6, "bamboo")
    b.box(butt + [0, 0, -0.1], (0.7, 0.5, 0.4), "clay", grain=0)
    nc = tip + np.array([0.0, -0.6, -3.6])
    b.tube([tip, nc + [0, 0, 0.9]], 0.02, 4, "rope", caps=False)
    corners = [nc + np.array([sx * 2.0, sy * 2.0, 0.0]) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    for c in corners:
        b.tube([nc + [0, 0, 0.9], (nc + c) / 2 + [0, 0, 0.8], c], [0.05, 0.04, 0.03], 5, "bamboo")
    n = 6
    P = np.zeros((n + 1, n + 1, 3))
    U = np.zeros((n + 1, n + 1))
    V = np.zeros((n + 1, n + 1))
    for i in range(n + 1):
        for j in range(n + 1):
            u, v = i / n, j / n
            P[i, j] = nc + [(u - 0.5) * 4.0, (v - 0.5) * 4.0, -1.1 * math.sin(PI * u) * math.sin(PI * v)]
            U[i, j], V[i, j] = u * 4.0, v * 4.0
    b.grid(P, "net", U, V, smooth=True)
    return b, float(tip[2])


def net_rack(name="dl_net_rack", seed=394):
    """PROPOSAL id: nets hung to dry between two poles on a rope."""
    b = Builder(name, seed)
    for x in (-2.4, 2.4):
        b.tube([(x, 0, 0), (x, 0, 3.0)], [0.08, 0.06], 5, "pile")
    pts = [(-2.4 + 4.8 * t, 0.0, 2.85 - 0.35 * math.sin(PI * t)) for t in np.linspace(0, 1, 9)]
    b.tube(pts, 0.03, 4, "rope", caps=False)
    for k, (x, w, L) in enumerate(((-1.3, 1.8, 2.3), (0.6, 2.4, 2.6))):
        vk.cloth_sheet(b, (x, -0.04, 2.6 - 0.05 * k), w, L, "net", amp=0.12, waves=1.5, rows=5, cols=4, unit=False,
                       sway=0.1)
    return b, 3.0


def soak_trough(name="dl_soak_trough", seed=395):
    b = Builder(name, seed)
    for y in (-0.42, 0.42):
        b.box((0, y, 0.32), (2.0, 0.08, 0.64), "timber", grain=0)
    for x in (-1.0, 1.0):
        b.box((x, 0, 0.32), (0.08, 0.92, 0.64), "timber", grain=1)
    b.box((0, 0, 0.5), (1.94, 0.78, 0.04), "clay", grain=0)
    b.box((0, 0, 0.04), (2.0, 0.9, 0.08), "timber", grain=0)
    b.empty("anchor_water_surface", (0, 0, 0.52))
    return b, 0.64


# ================================================================================================ DL4 mangrove
def mangrove(name="dl_mangrove_gallery", seed=401):
    """DL4: a giant mangrove (about 16 m, ~1.5x) standing on a dense skirt of fat prop roots, with three great roots
    arching 6-7 m over a side channel (along +X) where boats pass beneath; a wide umbrella crown of round leaf puffs in
    two layers (the WoW crown). Origin at the water."""
    b = Builder(name, seed)
    rng = b.rng
    base = np.array([0.0, 0.0, 3.0])
    trunk = [base + [0, 0, -1.4], base, base + [0.3, 0.2, 3.0], base + [0.1, 0.6, 6.0], base + [0.6, 0.4, 9.6]]
    b.tube(trunk, [1.35, 1.15, 0.9, 0.72, 0.55], 9, "bark")
    # the skirt of prop roots: fat, many, bowed
    for k in range(18):
        a = k * 2 * PI / 18 + rng.uniform(-0.15, 0.15)
        if math.cos(a) > 0.8:
            continue                       # leave the channel side to the great arches
        R = rng.uniform(4.0, 7.0)
        h0 = rng.uniform(2.5, 5.5)
        d = np.array([math.cos(a), math.sin(a), 0.0])
        pts = [base + [0, 0, h0 - 3.0] + d * 0.8, base + d * R * 0.35 + [0, 0, h0 - 2.2],
               base + d * R * 0.72 + [0, 0, h0 - 3.6], d * R + [0, 0, -0.2], d * R * 1.04 + [0, 0, BED]]
        b.tube(pts, [0.46, 0.4, 0.34, 0.32, 0.32], 6, "bark", caps=False)
    # the gallery: three great roots arching over the channel toward +X
    for k, (dy, top, reach) in enumerate(((-1.4, 7.4, 11.0), (0.4, 6.8, 9.5), (1.8, 5.8, 8.0))):
        pts = []
        for t in np.linspace(0, 1, 9):
            x = 0.6 + reach * t
            z = 2.0 + (top - 2.0) * math.sin(PI * min(t * 1.25, 1.0) * 0.8) - (t ** 3) * (top + 1.0)
            pts.append((x, dy + 0.7 * math.sin(t * 3.0 + k), max(z, BED) if t < 1 else BED))
        b.tube(pts, [0.75, 0.65, 0.56, 0.5, 0.46, 0.44, 0.42, 0.42, 0.42], 7, "bark", caps=False)
    # branches and the crown: a wide umbrella of puffs, a lower ring and a higher cap
    crown_c = base + np.array([0.6, 0.4, 9.8])
    puffs = [(crown_c + [0, 0, 1.6], 4.4, 0.7)]
    for k in range(8):
        a = k * 2 * PI / 8 + rng.uniform(-0.25, 0.25)
        r = rng.uniform(4.6, 6.4)
        c = crown_c + [r * math.cos(a), r * math.sin(a), rng.uniform(-1.0, 0.4)]
        puffs.append((c, rng.uniform(2.9, 3.8), 0.72))
        b.tube([base + [0.4, 0.4, 5.5], (base + [0.4, 0.4, 5.5] + c) / 2 + [0, 0, 1.0], c], [0.48, 0.34, 0.2], 6,
               "bark", caps=False)
    for k in range(4):
        a = k * 2 * PI / 4 + 0.6
        c = crown_c + [2.6 * math.cos(a), 2.6 * math.sin(a), 2.4]
        puffs.append((c, rng.uniform(2.6, 3.2), 0.75))
    for c, r, f in puffs:
        b.pebble(c, (r, r, r * f), "leaf", rot=rot_z(rng.uniform(0, 3)), segs=12, rings=8)
    b.empty("anchor_channel", (6.0, 0.0, 0.0))
    return b, float(crown_c[2] + 2.4 + 3.2 * 0.75)


# ================================================================================================ DL5 reeds
def reed_clump(name, cells, seed, n=7, h=3.6, w=2.6, spread=1.2):
    """DL5: a reed clump of crossed cards (3-4 m, ~1.5x real) from the reed atlas; COLOR_0.a = wind weight (0 root,
    1 tip). cells: atlas cells to use (0 gold, 1 green, 2 gold + cattails, 3 green + cattails)."""
    b = Builder(name, seed)
    rng = b.rng
    for k in range(n):
        cell = cells[k % len(cells)]
        yaw = k * PI / n + rng.uniform(-0.2, 0.2)
        off = rng.uniform(-spread, spread, 2) * (0 if k == 0 else 1)
        hh = h * rng.uniform(0.82, 1.1)
        ww = w * rng.uniform(0.8, 1.15)
        lean = rng.normal(0, 0.12)
        R = rot_z(yaw)
        P = np.zeros((3, 2, 3))
        U = np.zeros((3, 2))
        V = np.zeros((3, 2))
        M = np.zeros((3, 2))
        for i, t in enumerate((0.0, 0.5, 1.0)):
            for j, s in enumerate((-0.5, 0.5)):
                P[i, j] = np.array([off[0], off[1], -0.2]) + R @ [s * ww + lean * t * t * hh * 0.3, 0.0, t * hh]
                U[i, j] = (cell + 0.5 + s * 0.98) / 4.0
                V[i, j] = t * 0.995
                M[i, j] = t
        b.grid(P, "reedcard", U, V, smooth=False, unit=True, M=M)
    return b, h


# ================================================================================================ DL8 boats
def hull(b, L, Wd, D, rise, key_out="timber", key_in="plank", n=12, m=6, z0=0.0, thick=0.08, end_pow=2.2):
    """A boat hull along X: U-shaped sections, the sheer rising `rise` at both ends; outer, inner and rim surfaces."""
    xs = np.linspace(-L / 2, L / 2, n + 1)
    O = np.zeros((n + 1, m + 1, 3))
    I = np.zeros((n + 1, m + 1, 3))
    U = np.zeros((n + 1, m + 1))
    V = np.zeros((n + 1, m + 1))
    for i, x in enumerate(xs):
        t = abs(2 * x / L)
        w = Wd / 2 * max(1 - t ** end_pow, 0.0) ** 0.55 + 0.03
        d = D * max(1 - t ** 3, 0.0) ** 0.5 + 0.03
        zr = z0 + rise * t ** 3
        for j in range(m + 1):
            a = -PI / 2 + PI * j / m
            O[i, j] = (x, w * math.sin(a), zr - d * math.cos(a))
            I[i, j] = (x, (w - thick) * math.sin(a) if w > thick else 0.0, zr - max(d - thick, 0.01) * math.cos(a))
            U[i, j] = x
            V[i, j] = a * (w + d) / 2
    b.grid(O, key_out, U, V, smooth=True)
    b.grid(I, key_in, U, V, smooth=True, flip=True)
    for i in range(n):
        for j in (0, m):
            q = [O[i, j], O[i + 1, j], I[i + 1, j], I[i, j]]
            b.face(q if j == m else q[::-1], key_out)


def dugout(name="dl_dugout", seed=411):
    """A marsh dugout, 6.6 m, a pole and a fish basket; origin at the water line (the hull draws 0.25 m)."""
    b = Builder(name, seed)
    hull(b, 6.6, 0.95, 0.55, 0.35, z0=0.3)
    b.box((1.6, 0, 0.12), (0.3, 0.8, 0.06), "plank", grain=1)
    b.box((-2.0, 0, 0.12), (0.3, 0.7, 0.06), "plank", grain=1)
    b.tube([(-2.6, 0.25, 0.1), (3.0, 0.3, 0.35)], 0.035, 5, "bamboo")
    basket(b, (0.4, 0.0, -0.05), r=0.3, h=0.4)
    b.empty("anchor_seat_stern", (-2.0, 0, 0.15))
    return b, 0.7


def ferry_flat(name="dl_ferry_flat", seed=412):
    """A flat ferry, 9 x 3 m: a plank deck on a shallow scow hull with raked ends, low rails, a reed-mat canopy over the
    middle (2.0 m clear at the centre), a long pole; origin at the water line."""
    b = Builder(name, seed)
    L, Wd = 9.0, 3.0
    b.box((0, 0, 0.1), (L - 2.0, Wd, 0.5), "timber", grain=0)
    for s in (-1, 1):
        d = np.array([s * 1.6, 0.0, 0.55])
        b.box((s * (L / 2 - 0.6), 0, 0.37), (np.linalg.norm(d), Wd, 0.14), "timber", rot=frame_from(d), grain=0)
    deck(b, -L / 2 + 1.0, L / 2 - 1.0, -Wd / 2, Wd / 2, 0.42, along="y", w=0.36, collider="ferry_deck")
    for s in (-1, 1):
        rail(b, (-L / 2 + 1.2, s * (Wd / 2 - 0.1)), (L / 2 - 1.2, s * (Wd / 2 - 0.1)), 0.42, h=0.7, spacing=1.5,
             rope_mid=False)
    # the canopy: arched hoops and a mat
    n, m = 4, 6
    P = np.zeros((n + 1, m + 1, 3))
    U = np.zeros((n + 1, m + 1))
    V = np.zeros((n + 1, m + 1))
    for i in range(n + 1):
        x = -2.0 + 4.0 * i / n
        for j in range(m + 1):
            a = PI * j / m
            P[i, j] = (x, -(Wd / 2 - 0.1) * math.cos(a), 0.42 + 1.4 + 0.65 * math.sin(a))
            U[i, j], V[i, j] = x, a * 1.4
    b.grid(P, "screen", U, V, smooth=True, flip=True)
    for x in (-2.0, 2.0):
        for s in (-1, 1):
            b.tube([(x, s * (Wd / 2 - 0.1), 0.42), (x, s * (Wd / 2 - 0.1), 1.82)], 0.05, 5, "bamboo")
    b.tube([(-4.0, 1.0, 0.6), (4.4, 1.1, 1.1)], 0.045, 5, "bamboo")
    b.empty("anchor_pole", (-3.6, 0.0, 0.42))
    return b, 2.5


def reed_boat_burial(name="dl_reed_boat_burial", seed=421):
    """DL8: a burial reed boat (bound reed bundles, 9 m, upswept ends 3 m, ~1.5x) up on a drying frame of three bamboo
    A-frames at Har-Kel's yard; origin on the ground (or deck) under it."""
    b = Builder(name, seed)
    L = 9.0
    zb = 1.05
    for k, (dy, dz, r) in enumerate(((0.0, 0.0, 0.42), (-0.62, 0.18, 0.33), (0.62, 0.18, 0.33), (-1.0, 0.48, 0.22),
                                     (1.0, 0.48, 0.22))):
        pts, rad = [], []
        for t in np.linspace(-1, 1, 13):
            x = t * L / 2
            z = zb + dz + 2.6 * abs(t) ** 3.2
            inward = (1 - abs(t) ** 2) ** 0.5
            pts.append((x, dy * inward, z + r))
            rad.append(r * (0.25 + 0.75 * (1 - abs(t) ** 4)))
        b.tube(pts, rad, 7, "reed")
    # the curled tips
    for s in (-1, 1):
        p = np.array([s * L / 2, 0.0, zb + 2.6 + 0.42])
        b.tube([p, p + [s * 0.35, 0, 0.35], p + [s * 0.2, 0, 0.75]], [0.14, 0.11, 0.06], 6, "reed")
    for x in (-3.0, 0.0, 3.0):
        for s in (-1, 1):
            b.tube([(x, s * 1.3, 0.0), (x, s * 0.2, zb + 0.4)], 0.07, 5, "bamboo")
        b.tube([(x, -1.4, zb - 0.05), (x, 1.4, zb - 0.05)], 0.06, 5, "bamboo")
    return b, zb + 3.6


# ================================================================================================ review-only objects
def scale_figure(name="scale_figure", seed=501):
    """The 1.75 m scale figure for every lineup (render-only): a marsh ferry hand in a robe and a leaf hat."""
    b = Builder(name, seed)
    b.lathe([(0.27, 0.0), (0.3, 0.3), (0.25, 0.85), (0.21, 1.25), (0.2, 1.42), (0.08, 1.48)], 8, "cloth_indigo")
    b.lathe([(0.0, 1.44), (0.11, 1.47), (0.12, 1.58), (0.08, 1.66), (0.0, 1.68)], 8, "clay")
    b.lathe([(0.34, 1.6), (0.2, 1.68), (0.0, 1.82)], 10, "screen")
    for s in (-1, 1):
        b.tube([(s * 0.25, 0, 1.35), (s * 0.33, -0.08, 0.95), (s * 0.3, -0.12, 0.7)], 0.06, 5, "cloth_indigo")
    b.box((0, -0.02, 0.9), (0.62, 0.62, 0.08), "cloth_madder", grain=0)
    return b, 1.82


def old_lintel(name="review_old_lintel", seed=511):
    """BOOK II LOOK-DEV ONLY (Khar-Ul's 'half-submerged lintels', places_se.md §3: kh_lintel_* is not built for Book
    I). Two leaning dressed-stone jambs and a fallen lintel of much older stone, half under the water. Never exported,
    never placed in a Book I scene; it is in the diorama only because the review brief asked to see the look."""
    b = Builder(name, seed)
    for (x, lean) in ((-1.9, 0.10), (2.0, -0.06)):
        R = rot_y(lean)
        b.box((x, 0, 0.2), (0.95, 0.85, 4.2), "oldstone", rot=R, grain=2)
    R = rot_y(0.12) @ rot_z(0.06)
    b.box((0.1, 0.0, 2.6), (5.6, 1.0, 0.95), "oldstone", rot=R, grain=0)
    b.box((2.8, -1.1, -0.2), (1.4, 1.1, 0.9), "oldstone", rot=rot_z(0.4) @ rot_x(0.2), grain=0)
    return b, 3.1


# ================================================================================================ build and export
LOD1 = {"dl_mooring_fort": 2500, "dl_reed_house_a": 800, "dl_reed_house_b": 800, "dl_reed_house_c": 800,
        "dl_watch_tower": 300, "dl_mangrove_gallery": 1000, "dl_raft_house": 800, "dl_dugout": 500,
        "dl_ferry_flat": 500, "dl_reed_boat_burial": 700}
BUDGET = {"dl_pile_forest_4m": "400-900", "dl_pile_forest_6m": "400-900", "dl_platform_ramp": "600-1.2k",
          "dl_platform_steps": "600-1.2k", "dl_mooring_fort": "8-12k / 2.5k / 400",
          "dl_reed_house_a": "2.5-4k / 800 / 150", "dl_reed_house_b": "2.5-4k / 800 / 150",
          "dl_reed_house_c": "2.5-4k / 800 / 150", "dl_watch_tower": "1-1.5k / 300", "dl_heron_banner": "300 / 80",
          "dl_tally_post": "150-300", "dl_causeway": "200 per 5 m", "dl_raft_house": "2-3k",
          "dl_screen_rack": "300-600", "dl_mangrove_gallery": "3-5k / 1k / impostor", "dl_reed_clump_gold": "50-200",
          "dl_reed_clump_green": "50-200", "dl_reed_clump_cattail": "50-200", "dl_reed_boat_burial": "2-3k",
          "dl_dugout": "1-2k", "dl_ferry_flat": "1-2k", "dl_soak_trough": "150"}


def build_all(only=None, review=True):
    pieces = {}

    def add(b, height, ao=2.0, ground=True, info=None, keep_review=False):
        if only and b.name not in only and not keep_review:
            return None
        ob = b.obj()
        dlkit.bake_vertex_ao(ob, dist=ao, ground=ground)
        if keep_review:
            ob["review_only"] = True
        else:
            pieces[b.name] = (ob, dict(info or {}, height=round(float(height), 2)))
        return ob

    b, h, npl = mooring_fort()
    add(b, h, ao=3.0, info={"id": "DL1", "piles": npl, "deck_m": 2.8, "footprint_m": [30, 30],
                             "doors_m": "2.8 x 1.8, no sill (Floodborn-built)"})
    for nm, size, n, sd in (("dl_pile_forest_4m", 4.0, 11, 311), ("dl_pile_forest_6m", 6.0, 19, 312)):
        b, h = pile_forest(nm, size, n, sd)
        add(b, h, ao=1.5, info={"id": "DL1/DL6", "note": "piles 0.36-0.5 m from the bed (-1.8); box collider for boats"})
    b, h = platform("dl_platform_ramp", 6.0, 6.0, 2.0, ramp=True, seed=321)
    add(b, h, ao=1.5, info={"id": "DL6", "deck_m": 2.0, "note": "haul-out ramp at the front (-Y) to -0.9"})
    b, h = platform("dl_platform_steps", 8.0, 4.0, 1.6, ramp=False, seed=322)
    add(b, h, ao=1.5, info={"id": "DL6", "deck_m": 1.6, "note": "steps at the front (-Y) to -0.2"})
    for k, kind, note in (("a", "a", "Floodborn-built: door 2.8 x 1.8 m, no sill; bench with a 0.5 m tail gap; soaking "
                                     "trough; haul-out ramp"),
                          ("b", "b", "public standard: door 2.4 x 1.3 m, 8 cm sill; steps to the water"),
                          ("c", "c", "kitchen hut: hearth at the edge (smoke on the water); a mangrove root through "
                                     "the floor")):
        b, h = reed_house("dl_reed_house_" + k, kind, 330 + ord(k))
        add(b, h, ao=2.0, info={"id": "DL6", "note": note})
    b, h = raft_house()
    add(b, h, ao=2.0, info={"id": "DL6", "note": "floats: the log raft rides at the water line"})
    b, h = watch_tower()
    add(b, h, ao=2.0, info={"id": "DL2", "lookout_deck_m": 16.5})
    b, h = banner_piece()
    add(b, h, ao=1.0, info={"id": "DL1", "note": "24 m mast, 3.3 x 10 m cloth (our standing heron), madder tails"})
    b, h = tally_post()
    add(b, h, ao=0.8, info={"id": "DL7"})
    b, h = causeway()
    add(b, h, ao=0.8, info={"id": "DL7", "note": "5 m module along +Y; walk surface 15 cm under the water line"})
    for fn, i_d in ((screen_rack, "DL6"), (fish_rack, "DL6 (PROPOSAL id)"), (dip_net, "DL6 (PROPOSAL id)"),
                    (net_rack, "DL6 (PROPOSAL id)"), (soak_trough, "§3 Floodborn-built")):
        b, h = fn()
        add(b, h, ao=1.0, info={"id": i_d})
    b, h = mangrove()
    add(b, h, ao=3.0, info={"id": "DL4", "note": "great root arches over a side channel toward +X (anchor_channel)"})
    for nm, cells, sd in (("dl_reed_clump_gold", (0, 0, 2), 431), ("dl_reed_clump_green", (1, 1, 3), 432),
                          ("dl_reed_clump_cattail", (2, 0, 3, 1), 433)):
        b, h = reed_clump(nm, cells, sd)
        add(b, h, ao=0.5, ground=False, info={"id": "DL5", "note": "cards; COLOR_0.a = wind weight"})
    b, h = reed_boat_burial()
    add(b, h, ao=1.5, info={"id": "DL8"})
    b, h = dugout()
    add(b, h, ao=1.0, ground=False, info={"id": "DL6"})
    b, h = ferry_flat()
    add(b, h, ao=1.0, ground=False, info={"id": "DL6"})
    if review:
        for st in ("A", "C"):
            b, h, _ = mooring_fort("review_fort_" + st, style=st)
            add(b, h, ao=3.0, keep_review=True)
        for st in ("A", "C"):
            b, h = watch_tower("review_tower_" + st, style=st)
            add(b, h, ao=2.0, keep_review=True)
        for kind in ("banner_heron_b", "banner_heron_c"):
            b, h = banner_piece("review_" + kind, kind=kind)
            add(b, h, ao=1.0, keep_review=True)
        b, h = scale_figure()
        add(b, h, ao=0.5, keep_review=True)
        b, h = old_lintel()
        add(b, h, ao=2.0, ground=False, keep_review=True)
    return pieces


def make_lod1(ob, target):
    c = ob.copy()
    c.data = ob.data.copy()
    c.name = ob.name + "_lod1"
    bpy.context.scene.collection.objects.link(c)
    tris = dlkit.tri_count(ob)
    md = c.modifiers.new("dec", "DECIMATE")
    md.decimate_type = "COLLAPSE"
    md.ratio = min(1.0, target / max(tris, 1))
    md.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = c
    bpy.ops.object.select_all(action="DESELECT")
    c.select_set(True)
    bpy.ops.object.modifier_apply(modifier="dec")
    c.data.validate(clean_customdata=False)
    c["review_only"] = True
    c.hide_render = True
    return c


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--blend", default="")
    ap.add_argument("--only", default="")
    ap.add_argument("--no-lod", action="store_true")
    a, _ = ap.parse_known_args(argv)        # a render_dong_lau.py run may follow in the same Blender (-P twice)
    os.makedirs(a.out, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    only = set(filter(None, a.only.split(",")))
    pieces = build_all(only or None, review=bool(a.blend))
    manifest = {"_about": "Thủy Vân Reed Marches stilt kit (Đồng Lau, dl_*; places_se.md §3). Units metres; Blender Z "
                          "up exported glTF +Y up; a piece's front faces Blender -Y = Godot +Z. Over-water pieces: origin "
                          "on the water line, piles to the bed at -1.8 m. COLOR_0 = baked AO x top light (multiply into "
                          "albedo); COLOR_0.a = cloth pin / reed wind weight. Materials tvd_<key>: see materials.json. "
                          "*-colonly children are walkable decks, ramps, steps and the submerged causeway, and the "
                          "pile clusters' boat blocks.",
                "materials": {
                    dlkit.PREFIX + k: {"texture": "res://assets/thuyvan/dong_lau/textures/%s.png" % k,
                                       "uv_tile_m": (None if v.get("unit_uv") else v["tile_m"]),
                                       "roughness": v["rough"], "specular": v["spec"],
                                       "emission": v.get("emission"), "alpha_scissor": bool(v.get("alpha")),
                                       "double_sided": k in dlkit.DOUBLE_SIDED,
                                       "cloth": k.startswith(("banner_", "cloth_")) or k in ("screen", "net"),
                                       "wind": k == "reedcard"}
                    for k, v in dlkit.MATS.items()},
                "pieces": {}}
    for nm, (ob, info) in sorted(pieces.items()):
        dlkit.export_glb(ob, os.path.join(a.out, nm + ".glb"))
        info.update({"tris": dlkit.tri_count(ob), "budget": BUDGET.get(nm),
                     "materials": [m.name for m in ob.data.materials],
                     "size_m_xyz_blender": [round(float(v), 2) for v in ob.dimensions],
                     "anchors": {ch.name: [round(v, 3) for v in ch.location] for ch in ob.children
                                 if ch.type == "EMPTY"},
                     "colliders": [ch.name for ch in ob.children if ch.type == "MESH"]})
        if nm in LOD1 and not a.no_lod:
            lo = make_lod1(ob, LOD1[nm])
            dlkit.export_glb(lo, os.path.join(a.out, nm + "_lod1.glb"))
            info["tris_lod1"] = dlkit.tri_count(lo)
        manifest["pieces"][nm] = info
        print("DONGLAU %-26s tris=%6d lod1=%5s mats=%s" % (nm, info["tris"], info.get("tris_lod1", "-"),
                                                          ",".join(m[4:] for m in info["materials"])))
    for ob in bpy.data.objects:
        if ob.get("review_only") and ob.type == "MESH" and ob.parent is None:
            print("REVIEW %-26s tris=%6d" % (ob.name, dlkit.tri_count(ob)))
    mp = os.path.join(a.out, "manifest.json")
    if only and os.path.exists(mp):
        old = json.load(open(mp))
        old["pieces"].update(manifest["pieces"])
        manifest = old
    with open(mp, "w") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
    if a.blend:
        bpy.ops.wm.save_as_mainfile(filepath=a.blend)
    print("DONGLAU DONE")


if __name__ == "__main__":
    main()
