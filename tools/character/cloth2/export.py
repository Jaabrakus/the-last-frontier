"""cloth2 export: a finished garment Mesh -> glb (skinned, with the male fit and the bust gauge as morph targets),
its catalog entry and catalog.json.

  finish(ctx, fits, spec, mesh, uvparts, hem=None)

`uvparts`: {part id: ("cyl", axis point a, axis point b, front direction) or ("planar", origin, u dir, v dir)}: the UV
(metres, along the grain) of the faces of each `part` (mesh.fa["part"]); a cylinder's seam is at the back. ("arc", ...)
is a cylinder whose u is the angle times the part's median radius at that height (2026-10-03, cloth2.dress.arc_uv):
"cyl" multiplies by each corner's own radius, so across the back (the angle near 180 degrees) every hollow and
shoulder blade swung u by centimetres and a pattern's stripes swirled there. ("attr", u name, v name) takes the UV
from two per-vertex attributes the garment laid (mesh.A; cloth2.dress.envelope_uv).
"""

import heapq
import json
import math
import os

import numpy as np
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from lib import regions as RG
from lib.bands import write_edge_uv
from lib.context import ASSETS
from lib.pipeline import write_import
from lib.remesh import tri_count
from lib.rig import export_glb
from lib.sdf import log
from lib.shapes import add_shape_keys
from lib.weights import limit_normalize, write_groups
from cloth2.mesh import REF, SHAPE_FIT, unit

CATALOG = os.path.join(ASSETS, "catalog.json")
GENERATOR_DIR = "tools/character/cloth2/garments"
COVER_TILT_DEG = 25.0
HIDE_SHARE = 0.97
OCCUPY_SHARE = 0.25


# ---- UV ---------------------------------------------------------------------------------------------
def corner_uv(mesh, uvparts):
    """(faces, 3, 2) UV per face corner in metres."""
    m = len(mesh.F)
    uv = np.zeros((m, 3, 2))
    P = mesh.V[REF]
    parts = mesh.fa["part"]
    for pid in np.unique(parts):
        spec = uvparts.get(int(pid), uvparts.get(0))
        f = np.nonzero(parts == pid)[0]
        Q = P[mesh.F[f]]                                   # (k, 3, 3)
        if spec[0] in ("cyl", "arc"):
            a, b, front = [np.asarray(x, float) for x in spec[1:4]]
            d = unit(b - a)
            e1 = unit(front - d * (front @ d))
            e2 = np.cross(d, e1)
            rel = Q - a
            h = rel @ d
            r = rel - h[..., None] * d
            th = np.arctan2(r @ e2, r @ e1)               # 0 at the front, +-pi at the back
            # unwrap each face round its centre's angle (corners exactly on the seam would flip by chance)
            rc = rel.mean(1)
            rc = rc - (rc @ d)[:, None] * d
            thc = np.arctan2(rc @ e2, rc @ e1)[:, None]
            th = thc + (th - thc + np.pi) % (2 * np.pi) - np.pi
            rad = np.clip(np.linalg.norm(r, axis=-1), 0.03, 0.5)
            if spec[0] == "arc":
                rad = _arc_radius(h, rad)
            u = th * rad
            uv[f, :, 0] = u
            uv[f, :, 1] = h
        elif spec[0] == "attr":
            # the UV the garment laid itself as two per-vertex attributes (cloth2.dress.envelope_uv: a drape's or a
            # cloak's own rows and columns, so a stripe or a sett follows the cloth over the shoulder)
            uv[f, :, 0] = mesh.A[spec[1]][mesh.F[f]]
            uv[f, :, 1] = mesh.A[spec[2]][mesh.F[f]]
        else:
            o, ud, vd = [np.asarray(x, float) for x in spec[1:4]]
            rel = Q - o
            uv[f, :, 0] = rel @ unit(ud)
            uv[f, :, 1] = rel @ unit(vd)
    return uv


def _arc_radius(h, rad, step=0.02, smooth=2):
    """The radius an "arc" part's u is measured at, by height along its axis: the median radius of its corners in each
    `step` band, smoothed over `smooth` bands each way (u is then the arc round the body, straight down the back)."""
    hf, rf = h.ravel(), rad.ravel()
    edges = np.arange(hf.min(), hf.max() + step, step)
    mids, meds = [], []
    for e in edges:
        sel = (hf >= e) & (hf < e + step)
        if sel.sum() >= 3:
            mids.append(e + step / 2.0)
            meds.append(float(np.median(rf[sel])))
    if len(mids) < 2:
        return rad
    k = 2 * smooth + 1
    meds = np.convolve(np.pad(np.array(meds), smooth, mode="edge"), np.ones(k) / k, mode="valid")
    return np.interp(h, np.array(mids), meds)


# ---- distance along the surface to the hem / the openings -------------------------------------------
def surface_distance(mesh, sources):
    """Distance (m) along the mesh edges from the vertices in `sources` (bool)."""
    P = mesh.V[REF]
    E = np.unique(np.sort(mesh.edges(), 1), axis=0)
    adj = [[] for _ in range(mesh.n)]
    L = np.linalg.norm(P[E[:, 0]] - P[E[:, 1]], axis=1)
    for (a, b), l in zip(E, L):
        adj[a].append((b, l))
        adj[b].append((a, l))
    dist = np.full(mesh.n, 1e3)
    h = []
    for i in np.nonzero(sources)[0]:
        dist[i] = 0.0
        h.append((0.0, int(i)))
    heapq.heapify(h)
    while h:
        d, i = heapq.heappop(h)
        if d > dist[i]:
            continue
        for j, l in adj[i]:
            nd = d + l
            if nd < dist[j]:
                dist[j] = nd
                heapq.heappush(h, (nd, j))
    return np.minimum(dist, 1.0)


def edge_fields(mesh, hem):
    """(d_hem, d_open) per vertex: the distance to the hem (the boundary vertices `hem` marks, default the lowest
    third of the boundary) and to every other boundary (cuffs, collar, front opening)."""
    _, onb = mesh.boundary()
    P = mesh.V[REF]
    if hem is None:
        if onb.any():
            zb = P[onb, 2]
            hem = onb & (P[:, 2] < np.percentile(zb, 33))
        else:
            hem = onb
    return surface_distance(mesh, hem), surface_distance(mesh, onb & ~hem)


# ---- coverage of the body regions ----------------------------------------------------------------------
def coverage(fits, mesh, per_region=96):
    """{region name: (share hit along the skin normal, share hit by every ray of a cone)} over both the female
    base and the male fit: what the garment covers of the body and what it hides completely."""
    F = fits.F
    out = {}
    tilt = math.radians(COVER_TILT_DEG)
    rng = np.random.default_rng(3)
    for k in ("f", "m"):
        G = BVHTree.FromPolygons([tuple(p) for p in mesh.V[k]], [tuple(t) for t in mesh.F], all_triangles=True)
        Vb = fits.V[k]
        C = Vb[F].mean(1)
        N = fits.N[k][F].mean(1)
        N = unit(N)
        for name, rid in RG.REGIONS.items():
            if rid >= 48:
                continue
            idx = np.nonzero(fits.freg == rid)[0]
            if not len(idx):
                continue
            if len(idx) > per_region:
                idx = rng.choice(idx, per_region, replace=False)
            hit_n = hit_c = 0
            for i in idx:
                o = Vector(C[i] + N[i] * 0.0005)
                n = N[i]
                if G.ray_cast(o, Vector(n), 0.25)[0] is None:
                    continue
                hit_n += 1
                t1 = unit(np.cross(n, [0.0, 0.0, 1.0] if abs(n[2]) < 0.9 else [1.0, 0.0, 0.0]))
                t2 = np.cross(n, t1)
                ok = True
                for t in (t1, -t1, t2, -t2):
                    if G.ray_cast(o, Vector(n * math.cos(tilt) + t * math.sin(tilt)), 0.25)[0] is None:
                        ok = False
                        break
                hit_c += ok
            cur = out.get(name)
            share = (hit_n / len(idx), hit_c / len(idx))
            out[name] = share if cur is None else (min(cur[0], share[0]), min(cur[1], share[1]))
    return out


# ---- the Blender object, the glb and the catalog entry ------------------------------------------------------
def make_object(ctx, spec, mesh, uv, d_hem, d_open, shape_alias=None):
    name = spec.id
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(p) for p in mesh.V[REF]], [], [tuple(t) for t in mesh.F])
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = True
    lay = me.uv_layers.new(name="UVMap")
    lay.data.foreach_set("uv", uv.astype(np.float32).reshape(-1, 2).ravel())
    codes = mesh.fa["region"].astype(int) + 64 * mesh.fa["zone"].astype(int)
    RG.write_region_uv(ob, codes, "Region", None)
    write_edge_uv(ob, d_hem, d_open)
    attr = me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.ones(mesh.n * 4, np.float32))
    me.color_attributes.active_color = attr
    W = limit_normalize(mesh.A["W"])
    used = write_groups(ob, W, ctx.bones)
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    while len(me.materials):
        me.materials.pop()
    me.materials.append(mat)
    deltas = {}
    for shape, fit in SHAPE_FIT.items():
        if fit in mesh.V:
            deltas[shape] = mesh.V[fit] - mesh.V[REF]
    # extra shapes that repeat a fit (a hat's `sex_head`: the head-only male fit moves it like `sex`)
    for shape, fit in (shape_alias or {}).items():
        if fit in mesh.V:
            deltas[shape] = mesh.V[fit] - mesh.V[REF]
    add_shape_keys(ob, deltas)
    return ob, used, deltas, W


def finish(ctx, fits, spec, mesh, uvparts, hem=None, export=True, skirt=None, shape_alias=None, extra_checks=None):
    from cloth2.mesh import weld
    mesh = weld(mesh)
    mesh.recompute_normals()
    if os.environ.get("CLOTH2_DEBUG") == "1":
        be, onb = mesh.boundary()
        zb = mesh.V[REF][be].mean(1)[:, 2]
        hist = np.histogram(zb, bins=[0, 0.3, 0.6, 0.9, 0.96, 1.0, 1.04, 1.2, 1.4, 2.0])[0].tolist()
        print("BOUNDARY %s: %d open edges by height [0-.3,.3-.6,.6-.9,.9-.96,.96-1,1-1.04,1.04-1.2,1.2-1.4,>1.4]: %s" % (
            spec.id, len(be), hist))
    uv = corner_uv(mesh, uvparts)
    if callable(hem):
        hem = np.asarray(hem(mesh), bool)          # (after the weld: a garment's hem rule, Garment.hem)
    d_hem, d_open = edge_fields(mesh, hem)
    cov = coverage(fits, mesh)
    hides = sorted(set(r for r, (n, c) in cov.items() if c >= HIDE_SHARE) | set(spec.hides_force))
    occupies = [r for r, (n, c) in cov.items() if n >= OCCUPY_SHARE]
    clear = {}
    for k in mesh.V:
        if k in fits.bvh:
            d, _, _ = fits.dist(k, mesh.V[k])
            clear[k] = {"min_mm": round(float(d.min()) * 1000, 2), "p05_mm": round(float(np.percentile(d, 5)) * 1000, 2),
                        "inside_skin": int((d < 0).sum())}
            thr = -0.002 if os.environ.get("CLOTH2_DEBUG") == "1" else -0.01
            if (d < thr).any():
                bad = np.nonzero(d < thr)[0]
                log("  DEEP %s: %d vertices inside, e.g. %s (d %s mm)" % (
                    k, len(bad), [mesh.V[k][i].round(3).tolist() for i in bad[:3]], [round(float(d[i]) * 1000) for i in bad[:3]]))
    ob, used, deltas, W = make_object(ctx, spec, mesh, uv, d_hem, d_open, shape_alias)
    rig = ctx.bind_rig()
    ob.parent = rig
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    for bo in rig.data.bones:
        if bo.name in used:
            bo.use_deform = True
    tris = tri_count(ob)
    stats = {"surfaces": {"main": {"tris": tris, "verts": len(ob.data.vertices),
                                   "zones": sorted(int(z) for z in np.unique(mesh.fa["zone"])),
                                   "regions": sorted(RG.REGION_NAMES.get(int(r), str(r)) for r in np.unique(mesh.fa["region"])),
                                   "max_influences": int((W > 0).sum(1).max()), "bones": used}},
             "tris": tris, "verts": len(ob.data.vertices), "surface_count": 1,
             "shapes": {n: round(float(np.linalg.norm(d, axis=1).max()), 4) for n, d in deltas.items()},
             "coverage": {r: {"normal": round(n, 3), "cone": round(c, 3)} for r, (n, c) in cov.items() if n > 0}}
    ok = all(v["inside_skin"] == 0 for v in clear.values())
    checks = {"clearance": clear, "envelope": {"ok": ok, "layer": "cloth2", "groups": {}}}
    if extra_checks:
        checks.update(extra_checks)
    if tris > spec.budget:
        log("  BUDGET %s: %d tris > %d" % (spec.id, tris, spec.budget))
    log("  %s: %d tris %d verts, hides %d regions, clearance %s" % (spec.id, tris, len(ob.data.vertices), len(hides),
        {k: (v["min_mm"], v["inside_skin"]) for k, v in clear.items()}))
    entry = spec.entry(stats, sorted(occupies), sorted(hides), checks, "%s/%s.py" % (GENERATOR_DIR, spec.id), skirt)
    if export:
        glb = os.path.join(ASSETS, spec.glb_rel())
        export_glb(rig, [ob], glb, texcoords=True, morph=True)
        write_import(glb)
        stats["glb_kb"] = round(os.path.getsize(glb) / 1024.0, 1)
        print("CLOTH2_GLB " + glb)
        with open(os.path.splitext(glb)[0] + ".json", "w") as f:
            json.dump(entry, f, indent=1)
    ob.hide_render = True
    return entry


def merge_catalog(remove_sets=(), keep_ids=None):
    """catalog.json items <- the fragments next to the glbs (assets/character/garments/*/*.json); the garments of
    `remove_sets` that have no fragment are dropped (the old sets, once replaced)."""
    cat = json.load(open(CATALOG))
    items = cat["items"]
    root = os.path.join(ASSETS, "garments")
    frag = {}
    for s in sorted(os.listdir(root)):
        d = os.path.join(root, s)
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.endswith(".json") and f != "catalog.json":
                e = json.load(open(os.path.join(d, f)))
                if e.get("lib_version") == 2:
                    frag[e["id"]] = e
    for iid in list(items):
        e = items[iid]
        if e.get("kind") == "garment" and e.get("set") in remove_sets and iid not in frag:
            del items[iid]
    for iid, e in frag.items():
        items[iid] = e
        if e["set"] not in cat["sets"]:
            cat["sets"][e["set"]] = e["set"].replace("_", " ").title()
    with open(CATALOG, "w") as f:
        json.dump(cat, f, indent=1)
    return len(items)
