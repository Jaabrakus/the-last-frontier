"""P07: R1's painted vegetation as meshes (style guide 4 and 6): round-crowned broadleaf trees (3 sizes), karst
umbrella pines (3), bamboo clumps (2), a banana, ferns (3), flowering shrubs (3). Painted dab cards from
assets/thuyvan/paint/foliage/tv_foliage_atlas.png on puff spheres (normals bent to each puff and to the crown, so a
tree reads as 3-7 soft balls), painted bark tubes. Deterministic (seeded). Run through the shared lock:

    zsh <plan>/bin/blender_run.sh -b --factory-startup -P tools/thuyvan_art/blender/build_foliage.py -- [export=1]
        [render=1]

Output (export=1): assets/thuyvan/vegetation/<species>.glb, objects <species>_v<k>_lod<n> (LOD0, LOD1), the
frontier's tree format (tools/environment/vegetation/build_trees.py): one mesh, one surface per object; COLOR r =
painted AO (dark in the crown's core), g = outer-crown factor, b = per-card random, a = 1 foliage / 0 bark; UV = atlas
tile rect (foliage) or tiling bark UVs (bark: U around 1 m, V along bark_tile_m); UV2 x = metres from the trunk (wind
weight), y = phase; base at the origin. vegetation.json lists species, variants, heights, tris, the bark texture and
atlas per species.

Render (render=1): the lineup (look/PAINT/foliage_lineup_*.png) in bright game light on the painted grass, a 1.75 m
figure beside each plant, plus a silhouette render per plant for the 64 px black-silhouette test.
"""
import json
import math
import os
import random
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tvb  # noqa: E402
from tvb import UP, smooth  # noqa: E402

A = tvb.args()
FOL = os.path.join(tvb.PAINT, "foliage")
TILES = json.load(open(os.path.join(FOL, "tv_foliage_tiles.json")))["tiles"]
ATLAS = os.path.join(FOL, "tv_foliage_atlas.png")
OUT = os.path.join(tvb.ROOT, "assets", "thuyvan", "vegetation")


def ortho_basis(n, rng):
    n = n.normalized()
    t = n.cross(UP if abs(n.z) < 0.95 else Vector((1, 0, 0))).normalized()
    b = n.cross(t).normalized()
    a = rng.uniform(0, 2 * math.pi)
    r = t * math.cos(a) + b * math.sin(a)
    u = n.cross(r).normalized()
    return r, u


def puff_cards(md, rng, c, r, n_cards, tiles, crown_c, crown_r, size=1.15, flat=1.0, phase=0.0, attach=0.0,
               normal_bend=0.75, horizontal=0.0, ao_floor=0.45):
    """Cards on a puff sphere (centre c, radius r), facing outward; normals bent to the puff and the crown."""
    for i in range(n_cards):
        # golden-spiral-ish directions, a bit random; fewer underneath
        z = rng.uniform(-0.55, 1.0)
        a = rng.uniform(0, 2 * math.pi)
        d = Vector((math.sqrt(1 - z * z) * math.cos(a), math.sqrt(1 - z * z) * math.sin(a), z))
        if horizontal and rng.random() < horizontal:
            d = Vector((d.x * 0.35, d.y * 0.35, 1.0)).normalized()
        p = c + Vector((d.x * r, d.y * r, d.z * r * flat)) * rng.uniform(0.62, 0.86)
        # cards on the very top would lie flat and show their edge from the side: tilt them to <= 50 deg
        dc = Vector((d.x, d.y, min(d.z, 0.62))) if d.z > 0.62 else d
        if dc.length < 0.3:
            dc = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0.62))
        right, up = tvb_basis(dc, rng)
        s = r * size * rng.uniform(0.85, 1.2)
        tile = tiles[rng.integers(0, len(tiles))] if hasattr(rng, "integers") else rng.choice(tiles)

        def nf(q, c=c, r=r):
            pn = (q - c)
            pn = Vector((pn.x, pn.y, pn.z / max(flat, 0.2))).normalized()
            cn = Vector(((q - crown_c).x / crown_r.x, (q - crown_c).y / crown_r.y, (q - crown_c).z / crown_r.z))
            cn = cn.normalized() if cn.length > 1e-6 else UP
            return (pn * normal_bend + cn * (1 - normal_bend) * 0.8 + UP * 0.15).normalized()

        def ao(q, c=c, r=r):
            rel = Vector(((q - crown_c).x / crown_r.x, (q - crown_c).y / crown_r.y, (q - crown_c).z / crown_r.z))
            k = smooth(0.2, 1.05, rel.length)
            top = smooth(-1.0, 1.0, rel.z)
            return min(1.0, ao_floor + (1 - ao_floor) * (0.6 * k + 0.4 * top))

        outer = smooth(0.4, 1.0, ((p - crown_c).length / max(crown_r.length / 1.7, 1e-3)))
        tvb.card(md, TILES, tile, p, right, up, s, s, nf, ao, outer, rng.random(), attach + (p - c).length, phase)


def tvb_basis(d, rng):
    n = d.normalized()
    t = n.cross(UP if abs(n.z) < 0.95 else Vector((1, 0, 0))).normalized()
    b = n.cross(t).normalized()
    a = rng.uniform(-0.6, 0.6)  # keep the cards mostly upright, so the painted top light stays on top
    r = t * math.cos(a) + b * math.sin(a)
    u = r.cross(n).normalized()
    if u.z < 0:
        u = -u
        r = -r
    return r, u


class R:
    """A tiny seeded RNG with the numpy-ish calls the builders use."""

    def __init__(self, seed):
        self.r = random.Random(seed)

    def uniform(self, a, b):
        return self.r.uniform(a, b)

    def random(self):
        return self.r.random()

    def integers(self, a, b):
        return self.r.randrange(a, b)

    def normal(self, m, s):
        return self.r.gauss(m, s)

    def choice(self, seq):
        return self.r.choice(seq)


# ---------------------------------------------------------------- species

def broadleaf(seed, height, lod):
    rng = R(seed)
    md = tvb.MeshData()
    crown_h = height * rng.uniform(0.66, 0.74)
    trunk_top = height - crown_h * 0.6
    crown_c = Vector((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), height - crown_h * 0.5))
    crown_r = Vector((crown_h * 0.6, crown_h * 0.6, crown_h * 0.5))
    # trunk: thick, slightly twisted, flared foot
    base_r = height * 0.032
    pts, radii = [], []
    for i in range(7):
        t = i / 6
        pts.append((math.sin(t * 2.4 + seed) * 0.35 * t, math.cos(t * 1.7 + seed) * 0.3 * t, -0.6 + (trunk_top + 0.6) * t))
        radii.append(base_r * (1.35 - 0.55 * t) * (1.25 if i == 0 else 1.0))
    sides = 9 if lod == 0 else 6
    tvb.tube(md, pts, radii, sides, bark_tile_m=2.0, ao=(0.55, 0.85), wind=False)
    # puffs: 3-7 round balls round the crown, the biggest on top
    n_puffs = rng.integers(4, 8) if lod == 0 else rng.integers(3, 5)
    puffs = [(crown_c + Vector((0, 0, crown_r.z * 0.25)), crown_h * 0.36)]
    for i in range(n_puffs - 1):
        a = 2 * math.pi * i / (n_puffs - 1) + rng.uniform(-0.4, 0.4)
        rr = crown_r.x * rng.uniform(0.55, 0.7)
        puffs.append((crown_c + Vector((math.cos(a) * rr, math.sin(a) * rr, rng.uniform(-0.45, 0.05) * crown_r.z)),
                      crown_h * rng.uniform(0.27, 0.34)))
    top = Vector(pts[-1])
    for (c, r) in puffs:  # limbs from the trunk top to each puff
        mid = top.lerp(c, 0.5) + Vector((0, 0, 0.4))
        tvb.tube(md, [top - Vector((0, 0, 0.6)), mid, c.lerp(mid, 0.3)], [radii[-1] * 0.8, radii[-1] * 0.5,
                                                                        radii[-1] * 0.25],
                 6 if lod == 0 else 4, ao=(0.6, 0.7), attach0=0.0)
    for (c, r) in puffs:
        n = 38 if lod == 0 else 12
        tiles = ["broadleaf_a", "broadleaf_b", "broadleaf_c"] + (["broadleaf_top"] if c.z > crown_c.z else [])
        puff_cards(md, rng, c, r, n, tiles, crown_c, crown_r, size=0.78 if lod == 0 else 1.2, phase=rng.random(),
                   ao_floor=0.72, normal_bend=0.85)
    return md


def karst_pine(seed, height, lod):
    """A karst umbrella pine: a sinuous leaning trunk, 2-4 flat tiers of dark puffs, a small top tuft."""
    rng = R(seed)
    md = tvb.MeshData()
    lean = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)).normalized() * height * rng.uniform(0.12, 0.25)
    pts, radii = [], []
    for i in range(9):
        t = i / 8
        wig = Vector((math.sin(t * 5.0 + seed) * 0.25, math.cos(t * 4.0 + seed) * 0.25, 0)) * height * 0.06
        pts.append(Vector((0, 0, -0.5 + (height * 0.92 + 0.5) * t)) + lean * (t ** 1.5) + wig)
        radii.append(height * 0.028 * (1.3 - 0.75 * t))
    tvb.tube(md, pts, radii, 8 if lod == 0 else 5, bark_tile_m=2.0, ao=(0.5, 0.85), wind=False)
    tiers = rng.integers(2, 5) if height > 5 else 2
    crown_c = pts[-1] - Vector((0, 0, height * 0.12))
    crown_r = Vector((height * 0.42, height * 0.42, height * 0.22))
    for k in range(tiers):
        t = 0.55 + 0.45 * (k + 1) / tiers
        i = min(int(t * 8), 8)
        c0 = pts[i]
        side = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)).normalized()
        wide = height * (0.42 - 0.22 * k / max(tiers - 1, 1)) * rng.uniform(0.9, 1.15)
        c = c0 + side * wide * 0.35
        if k < tiers - 1:  # a branch out to an off-axis tier
            tvb.tube(md, [c0, c0.lerp(c, 0.6) + Vector((0, 0, 0.3)), c], [radii[i] * 0.6, radii[i] * 0.4, radii[i] * 0.2],
                     5 if lod == 0 else 4, ao=(0.6, 0.7))
        # the tier: 2-4 flattened puffs side by side (a flat-topped cloud layer), dark, lit along the top
        n_sub = rng.integers(2, 5) if lod == 0 else 2
        tier_c = c
        tier_r = Vector((wide, wide, wide * 0.35))
        for m in range(n_sub):
            aa = rng.uniform(0, 2 * math.pi)
            cc = c + Vector((math.cos(aa), math.sin(aa), 0)) * wide * rng.uniform(0.15, 0.45)
            puff_cards(md, rng, cc, wide * rng.uniform(0.45, 0.6), 16 if lod == 0 else 7,
                       ["pine_pad_a", "pine_pad_b", "pine_pad_c", "pine_tuft"], tier_c, tier_r, size=1.0,
                       flat=0.42, phase=rng.random(), attach=(cc - c0).length, ao_floor=0.68)
    return md


def bamboo(seed, height, lod):
    rng = R(seed)
    md = tvb.MeshData()
    n_culms = rng.integers(10, 18) if lod == 0 else rng.integers(6, 9)
    crown_c = Vector((0, 0, height * 0.65))
    crown_r = Vector((height * 0.35, height * 0.35, height * 0.4))
    for i in range(n_culms):
        a = rng.uniform(0, 2 * math.pi)
        r0 = rng.uniform(0.1, 0.7)
        base = Vector((math.cos(a) * r0, math.sin(a) * r0, -0.3))
        out = Vector((math.cos(a), math.sin(a), 0))
        H = height * rng.uniform(0.75, 1.05)
        bend = rng.uniform(0.18, 0.4)
        pts = [base + UP * H * t + out * (t ** 2) * H * bend for t in [k / 8 for k in range(9)]]
        rad = rng.uniform(0.055, 0.08)
        tvb.tube(md, pts, [rad * (1.0 - 0.4 * k / 8) for k in range(9)], 6 if lod == 0 else 4, bark_tile_m=1.2,
                 around_m=0.5, ao=(0.5, 0.95), wind=False)
        n_sprays = 7 if lod == 0 else 3
        for k in range(n_sprays):
            t = 0.4 + 0.6 * (k + rng.uniform(0, 0.8)) / n_sprays
            p = base + UP * H * t + out * (t ** 2) * H * bend
            d = (out + Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0.1))).normalized()
            right = UP.cross(d).normalized()
            s = rng.uniform(1.6, 2.4) * (1.3 if lod else 1.0)
            tile = rng.choice(["bamboo_a", "bamboo_b", "bamboo_c"])

            def nf(q):
                v = q - crown_c
                v = Vector((v.x / crown_r.x, v.y / crown_r.y, v.z / crown_r.z))
                return (v.normalized() * 0.65 + UP * 0.3).normalized()

            def ao(q):
                rel = Vector(((q - crown_c).x / crown_r.x, (q - crown_c).y / crown_r.y, (q - crown_c).z / crown_r.z))
                return min(1.0, 0.5 + 0.35 * smooth(0.0, 1.0, rel.length) + 0.25 * smooth(-1, 1, rel.z))

            # the spray's twig sits along the card's top edge: anchor the card from its top
            tvb.card(md, TILES, tile, p + d * s * 0.35 - UP * s * 0.75, right, UP, s, s, nf, ao, 0.6, rng.random(),
                     H * t * 0.3, rng.random())
    return md


def banana(seed, height, lod):
    rng = R(seed)
    md = tvb.MeshData()
    pts = [Vector((0, 0, -0.3 + (height * 0.62 + 0.3) * k / 5)) for k in range(6)]
    tvb.tube(md, pts, [0.2, 0.18, 0.16, 0.15, 0.13, 0.11], 8 if lod == 0 else 5, bark_tile_m=2.0, around_m=1.0,
             ao=(0.55, 0.9), wind=False)
    top = pts[-1]
    n = 8 if lod == 0 else 5
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-0.3, 0.3)
        out = Vector((math.cos(a), math.sin(a), 0))
        side = UP.cross(out).normalized()
        L = height * rng.uniform(0.55, 0.75)
        rise = rng.uniform(0.5, 1.1)
        droop = rng.uniform(0.6, 1.0)

        def pos(cu, cv, out=out, side=side, L=L, rise=rise, droop=droop):
            # tile: the leaf runs bottom-left (0, 1) -> top-right (1, 0); s along it 0..1, w across it
            s = ((cu - 0.5) - (cv - 0.5)) / math.sqrt(2) / 0.707 * 0.5 + 0.5
            w = ((cu - 0.5) + (cv - 0.5)) / math.sqrt(2)
            along = s * L
            z = rise * along - droop * (along ** 2) / L
            return top + out * along + UP * z + side * w * L * 0.95

        def nf(q, cu, cv, out=out):
            return (UP * 0.8 + out * 0.3).normalized()

        def ao(q):
            return min(1.0, 0.6 + 0.4 * smooth(0, L * 0.6, (q - top).length))

        tvb.grid_card(md, TILES, "banana_leaf", pos, 5 if lod == 0 else 3, 5 if lod == 0 else 3, nf, ao, rng.random(),
                      rng.random(), lambda cu, cv: cu * L)
    return md


def fern(seed, height, lod):
    rng = R(seed)
    md = tvb.MeshData()
    n = rng.integers(7, 11) if lod == 0 else 5
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-0.25, 0.25)
        out = Vector((math.cos(a), math.sin(a), 0))
        side = UP.cross(out).normalized()
        L = height * rng.uniform(1.0, 1.4)
        e = math.radians(rng.uniform(35, 60))
        W = L * 0.55
        tile = rng.choice(["fern_a", "fern_b"])

        def pos(cu, cv, out=out, side=side, L=L, e=e, W=W):
            s = 1.0 - cv  # the frond's stem runs up the tile (cv 1 = its base)
            along = s * L
            z = math.tan(e) * along - 1.1 * (along ** 2) / L
            return out * along * math.cos(e) * 1.2 + UP * max(z, 0.02) + side * (cu - 0.5) * W

        def nf(q, cu, cv, out=out):
            return (UP * 0.85 + out * 0.25).normalized()

        def ao(q):
            return min(1.0, 0.5 + 0.5 * smooth(0, height, q.length))

        tvb.grid_card(md, TILES, tile, pos, 2, 4 if lod == 0 else 3, nf, ao, rng.random(), rng.random(),
                      lambda cu, cv, L=L: (1 - cv) * L)
    return md


def shrub(seed, height, lod, tiles):
    rng = R(seed)
    md = tvb.MeshData()
    crown_c = Vector((0, 0, height * 0.5))
    crown_r = Vector((height * 0.6, height * 0.6, height * 0.5))
    n_puffs = rng.integers(3, 5)
    for i in range(n_puffs):
        a = 2 * math.pi * i / n_puffs + rng.uniform(-0.4, 0.4)
        rr = height * 0.28
        c = Vector((math.cos(a) * rr, math.sin(a) * rr, height * rng.uniform(0.35, 0.6)))
        tvb.tube(md, [Vector((0, 0, -0.2)), c * 0.6], [height * 0.03, height * 0.015], 5 if lod == 0 else 3,
                 ao=(0.5, 0.6))
        puff_cards(md, rng, c, height * rng.uniform(0.3, 0.38), 18 if lod == 0 else 6, tiles, crown_c, crown_r,
                   size=1.0 if lod == 0 else 1.5, phase=rng.random(), ao_floor=0.7)
    puff_cards(md, rng, crown_c + Vector((0, 0, height * 0.15)), height * 0.36, 16 if lod == 0 else 5, tiles, crown_c,
               crown_r, size=1.0, phase=rng.random(), ao_floor=0.7)
    return md


SPECIES = [  # name, builder, variant heights (m), bark texture, bark tile metres
    ("tv_broadleaf", broadleaf, [8.0, 12.0, 17.0], "tv_bark_broadleaf.png"),
    ("tv_karst_pine", karst_pine, [4.0, 7.0, 11.0], "tv_bark_pine.png"),
    ("tv_bamboo", bamboo, [6.5, 10.0], "tv_bamboo_culm.png"),
    ("tv_banana", banana, [4.2], "tv_banana_trunk.png"),
    ("tv_fern", fern, [0.8, 1.2, 1.6], "tv_bark_broadleaf.png"),
    ("tv_shrub", None, [1.2, 1.8, 2.4], "tv_bark_broadleaf.png"),
]
SHRUB_TILES = [["shrub_madder", "broadleaf_b"], ["shrub_white", "broadleaf_c"], ["shrub_madder", "shrub_white"]]


def build(name, fn, h, k, lod):
    seed = 4000 + hash(name) % 997 * 0 + sum(ord(c) for c in name) * 7 + k * 101
    if name == "tv_shrub":
        return shrub(seed, h, lod, SHRUB_TILES[k])
    return fn(seed, h, lod)


def main():
    tvb.reset()
    sc = tvb.lineup_scene()
    mats = {}
    meta = {"atlas": "res://assets/thuyvan/paint/foliage/tv_foliage_atlas.png", "species": {}}
    built = {}
    for name, fn, heights, bark in SPECIES:
        mats[name] = tvb.foliage_material(name, ATLAS, os.path.join(FOL, bark))
        objs = []
        info = {"bark": "res://assets/thuyvan/paint/foliage/" + bark, "variants": []}
        for k, h in enumerate(heights):
            for lod in (0, 1):
                md = build(name, fn, h, k, lod)
                ob = md.to_object("%s_v%d_lod%d" % (name, k, lod), mats[name])
                objs.append(ob)
                if lod == 0:
                    info["variants"].append({"height_m": h, "tris_lod0": md.ntris()})
                else:
                    info["variants"][-1]["tris_lod1"] = md.ntris()
                built[(name, k, lod)] = (ob, md.ntris(), h)
        meta["species"][name] = info
        print("built", name, info, flush=True)
    if A.get("export"):
        for name, fn, heights, bark in SPECIES:
            objs = [built[(name, k, lod)][0] for k in range(len(heights)) for lod in (0, 1)]
            tvb.export_glb(objs, os.path.join(OUT, name + ".glb"))
        json.dump(meta, open(os.path.join(OUT, "vegetation.json"), "w"), indent=1)
    if A.get("render"):
        render_lineups(built)


def render_lineups(built):
    sc = bpy.context.scene
    # hide the LOD1s
    for (name, k, lod), (ob, tris, h) in built.items():
        ob.hide_render = lod == 1
    d = tvb.PAL["directions"]["bright_saturated_noon"]
    tvb.world_color(tvb.hex_lin(d["ambient"]["color"]), 0.9)
    tvb.sun(200.0, 40.0, tvb.hex_lin("#fff3d9"), strength=4.2, angle_deg=1.5)
    # painted ground: the grass slice, 8 m tiles
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=200.0)
    me = bpy.data.meshes.new("ground")
    bm.to_mesh(me)
    g = bpy.data.objects.new("ground", me)
    sc.collection.objects.link(g)
    gpath = os.path.join(tvb.LOOK, "slices", "00_grass.png")
    me.materials.append(tvb.image_material("ground", gpath, scale=8.0, macro=0.12, anti_tile=True))
    labels = []
    rows = [("trees", ["tv_broadleaf", "tv_karst_pine", "tv_bamboo", "tv_banana"]),
            ("understorey", ["tv_fern", "tv_shrub"])]
    out_meta = {}
    for row_name, names in rows:
        for (name, k, lod), (ob, tris, h) in built.items():
            ob.hide_render = True
        x = 0.0
        placed = []
        figs = []
        for name in names:
            ks = sorted(set(k for (n, k, l) in built if n == name))
            for k in ks:
                ob, tris, h = built[(name, k, 0)]
                w = max(h * (0.75 if name != "tv_bamboo" else 0.6), 1.2) if h > 3 else h * 1.4 + 0.4
                x += w * 0.5
                ob.location = (x, 0, 0)
                ob.hide_render = False
                placed.append((name, k, ob, tris, built[(name, k, 1)][1], h, x))
                fx = x + w * 0.5 + (0.6 if h > 3 else 0.35)
                figs.append(tvb.figure((fx, 0.6, 0), "fig_%s_%d" % (name, k)))
                x += w * 0.5 + (1.6 if h > 3 else 0.9)
        total = x
        hmax = max(p[5] for p in placed)
        cx = total / 2
        dist = max(total, hmax * 2.2) * (0.95 if hmax > 4 else 1.25)
        cam = tvb.camera((cx - dist * 0.12, -dist * 0.95, hmax * 0.45 + dist * 0.1), (cx, 0, hmax * 0.36), lens=32)
        sc.render.film_transparent = False
        path = os.path.join(tvb.LOOK, "foliage", "lineup_%s.png" % row_name)
        tvb.render(path)
        out_meta[row_name] = []
        for (name, k, ob, t0, t1, h, x) in placed:
            sx, sy = tvb.screen_xy(cam, (x, 0, -0.3))
            out_meta[row_name].append({"name": name, "v": k, "height_m": h, "tris_lod0": t0, "tris_lod1": t1,
                                       "label_xy": [sx, sy], "material": name})
        # silhouettes: each plant alone, side-on, transparent film
        sc.render.film_transparent = True
        g.hide_render = True
        for f in figs:
            f.hide_render = True
        res = (sc.render.resolution_x, sc.render.resolution_y)
        sc.render.resolution_x, sc.render.resolution_y = 256, 256
        for (name, k, ob, t0, t1, h, x) in placed:
            for (n2, k2, o2, *_r) in placed:
                o2.hide_render = o2 is not ob
            c2 = tvb.camera((x, -h * 6, h * 0.5), (x, 0, h * 0.5), ortho=h * 1.15)
            tvb.render(os.path.join(tvb.LOOK, "foliage", "sil", "%s_v%d.png" % (name, k)))
        sc.render.resolution_x, sc.render.resolution_y = res
        g.hide_render = False
        for f in figs:
            f.hide_render = True
            bpy.data.objects.remove(f)
        for (name, k, ob, *_r) in placed:
            ob.hide_render = True
    json.dump(out_meta, open(os.path.join(tvb.LOOK, "foliage", "lineup.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
