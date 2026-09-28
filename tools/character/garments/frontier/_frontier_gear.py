"""Powder horn, shot pouch and their shoulder straps (frontier set accessories), built in
four envelope variants (design §5.5): the strap lies on the outermost torso layer.

    env10  over a shirt (base layer)          env20  over a waistcoat
    env40  over a coat / hunting shirt        env50  over a blanket, fur robe or fur coat

The catalog entry's glb is the env40 variant; `variants` maps every envelope key to its
glb (<id>_<env>.glb, same mesh name and surfaces). The horn hangs under the right arm from
a strap over the left shoulder (Knox 1757 via [M2]); the pouch on the left hip from a
strap over the right shoulder. Horn, pouch and fittings are rigid on the pelvis; each strap
takes the torso weights of its own centre line, averaged along the band (as the legacy
straps), so its cross-section never stretches.
"""

import os
import sys

import numpy as np

from garments.frontier import _frontier_common as FC
from lib import catalog as CAT
from lib.pipeline import Surface, body_weights_at, finish_part, write_import
from lib.remesh import Prims, join, material, mesh_arrays, sdf_object
from lib.rig import export_glb
from lib.sdf import (Fn, Inter, Offset, Onion, RoundBox, RoundCone, Union, frame_from, log, nrm, peval, smoothstep,
                     v3, zslab)
from lib.weights import band_smooth, chain_weights, limit_normalize

ENVS = ["env10", "env20", "env40", "env50"]
STRAP_T = 0.0016            # half thickness
STRAP_W = 0.0125            # half width (tube radius around the centre line)
STRAP_BOTTOM = 0.93
TORSO_BONES = ["pelvis", "spinea", "spineb", "spinec", "spined", "neck", "l_clavicle", "r_clavicle"]

# the horn (legacy horn_node: quadratic Bezier, wide base behind, spout forward)
HORN_P = [v3(-0.207, 0.085, 0.905), v3(-0.222, 0.000, 0.866), v3(-0.200, -0.070, 0.900)]
HORN_R = [0.027, 0.026, 0.023, 0.019, 0.015, 0.011, 0.008, 0.0055]
POUCH_C = v3(0.203, 0.030, 0.878)


def outer_ref(K, ctx, env):
    """The outermost layer at the hip for an envelope (the horn and pouch hang on it)."""
    body = ctx.body_sdf()
    if env == "env10":
        return Offset(body, 0.011)          # breeches / trousers over the hip
    if env == "env20":
        return Offset(body, 0.013)
    p = FC.CoatParams(hem=0.47, skirt_scale=(1.05, 1.06), skirt_flare=0.12)
    coat = Union([Offset(FC.skirt_form(p), 0.006), Offset(body, 0.018)], k=0.0)
    return coat if env == "env40" else Offset(coat, 0.024)


def horn_axis(dx):
    pts = [(1 - t) ** 2 * HORN_P[0] + 2 * (1 - t) * t * HORN_P[1] + t ** 2 * HORN_P[2]
           for t in np.linspace(0, 1, len(HORN_R))]
    return [p + v3(dx, 0, 0) for p in pts]


def fit_shift(ref, axis_fn, radii, side, clear=0.003, lo=-0.03, hi=0.08):
    """Smallest outward shift (x * side, from lo) that keeps the tube clear of `ref`."""
    for sh in np.arange(lo, hi, 0.002):
        pts = axis_fn(side * sh)
        d = np.min(peval(ref, np.array(pts)) - np.array(radii))
        if d >= clear:
            return float(sh)
    return float(hi)


def strap_node(K, s, env):
    P = FC.strap_path(K, s, env)
    tube = Union([RoundCone(P[i], P[(i + 1) % len(P)], STRAP_W, STRAP_W) for i in range(len(P))], k=0.0)
    form = FC.strap_form(K, env)
    return Inter(Inter(Onion(form, STRAP_T), tube), zslab(STRAP_BOTTOM, 1.46)), P


def strap_ends(P):
    """(front end, back end) of the strap loop at the hip (the points just above STRAP_BOTTOM)."""
    m = P[:, 2] > STRAP_BOTTOM + 0.004
    front = P[m & (P[:, 1] < 0.0)]
    back = P[m & (P[:, 1] >= 0.0)]
    return front[np.argmin(front[:, 2])], back[np.argmin(back[:, 2])]


def horn_parts(ctx, K, env):
    """(horn solid, strap node, strap path, fittings Prims object, shift) for an envelope."""
    ref = outer_ref(K, ctx, env)
    sh = fit_shift(ref, lambda d: horn_axis(-d), HORN_R, 1)
    ax = horn_axis(-sh)
    horn = Union([RoundCone(ax[i], ax[i + 1], HORN_R[i], HORN_R[i + 1]) for i in range(len(ax) - 1)], k=0.004)
    strap, path = strap_node(K, 1, env)
    f_end, b_end = strap_ends(path)
    cords = Union([RoundCone(f_end, ax[-2] + v3(0, 0, HORN_R[-2]), 0.0022, 0.0022),
                   RoundCone(b_end, ax[0] + v3(0, 0.004, HORN_R[0] * 0.8), 0.0022, 0.0022)], k=0.002)
    return horn, strap, cords, ax, sh


def pouch_node(c):
    R = frame_from(v3(0, 0.25, 1), v3(1, -0.12, 0))       # local x ~ outward, z ~ up
    body = RoundBox(c, (0.014, 0.060, 0.050), 0.009, R)
    flap = RoundBox(c + R @ v3(0.013, 0, 0.018), (0.0035, 0.063, 0.036), 0.003, R)
    loop = RoundBox(c + R @ v3(-0.004, 0, 0.058), (0.004, 0.012, 0.022), 0.002, R)
    return Union([body, flap, loop], k=0.003), R


def pouch_parts(ctx, K, env):
    ref = outer_ref(K, ctx, env)

    def samples(dx):
        c = POUCH_C + v3(dx, 0, 0)
        R = frame_from(v3(0, 0.25, 1), v3(1, -0.12, 0))
        return [c + R @ v3(-0.014, y, z) for y in (-0.05, 0.0, 0.05) for z in (-0.04, 0.0, 0.04)]
    sh = fit_shift(ref, samples, [0.009] * 9, 1)
    c = POUCH_C + v3(sh, 0, 0)
    pouch, R = pouch_node(c)
    strap, path = strap_node(K, -1, env)
    f_end, b_end = strap_ends(path)
    top_f = c + R @ v3(-0.004, -0.045, 0.05)
    top_b = c + R @ v3(-0.004, 0.045, 0.05)
    cords = Union([RoundCone(f_end, top_f, 0.0022, 0.0022), RoundCone(b_end, top_b, 0.0022, 0.0022)], k=0.002)
    return pouch, strap, cords, sh


def horn_fittings(ax):
    gp = Prims()
    d0 = nrm(ax[0] - ax[1])
    gp.cylinder(ax[0] + d0 * 0.004, d0, HORN_R[0] * 0.93, 0.014, mi=0, segs=12)          # wooden base plug
    gp.sphere(ax[0] + d0 * 0.012, (0.006, 0.006, 0.006), mi=0, segs=8, rings=5)            # plug knob
    d1 = nrm(ax[-1] - ax[-2])
    gp.cylinder(ax[-1] + d1 * 0.004, d1, HORN_R[-1] * 1.05, 0.016, mi=0, segs=8, r2=HORN_R[-1] * 0.7)  # stopper
    return gp.to_object("horn_fittings", [material("horn_wood_tmp", "#5e3e25")])


def strap_weights(ctx, ob, poly_mask, paths):
    """Weights of the strap vertices (polygons in poly_mask): the torso weights at the
    nearest point of their strap's centre line, averaged along the band; elsewhere rigid
    pelvis."""
    V = mesh_arrays(ob)
    bones = ctx.bones
    W = FC.rigid(bones, len(V), "pelvis")
    vm = np.zeros(len(V), bool)
    for p in ob.data.polygons:
        if poly_mask[p.index]:
            vm[list(p.vertices)] = True
    idx = np.nonzero(vm)[0]
    if len(idx) == 0:
        return W
    Pv = V[idx]
    C = np.zeros_like(Pv)
    band = np.zeros(len(idx), int)
    best = np.full(len(idx), np.inf)
    for k, Q in enumerate(paths):
        for i in range(len(Q)):
            a, b = Q[i], Q[(i + 1) % len(Q)]
            ab = b - a
            t = np.clip(((Pv - a) @ ab) / max(ab @ ab, 1e-12), 0.0, 1.0)
            q = a + t[:, None] * ab
            d = np.linalg.norm(Pv - q, axis=1)
            m = d < best
            best[m] = d[m]
            C[m] = q[m]
            band[m] = k + 1
    Wc = body_weights_at(ctx, C, torso_only=np.ones(len(C), bool))
    keep = np.zeros(len(bones), bool)
    keep[[bones.index(b) for b in TORSO_BONES]] = True
    Wc[:, ~keep] = 0.0
    Wc /= np.maximum(Wc.sum(1, keepdims=True), 1e-12)
    Wc = band_smooth(Wc, C, band)
    Wc = limit_normalize(chain_weights(Wc, np.ones(len(idx), bool), bones))
    W[idx] = Wc
    return W


def build_gear(ctx, spec, env, horn=True, pouch=True):
    """{surface: Surface} of the gear for one envelope."""
    K = ctx.K
    objs, zone_of, strap_polys, paths, shifts = [], [], [], [], {}
    if horn:
        hn, st, cords, ax, sh = horn_parts(ctx, K, env)
        shifts["horn_shift_x"] = round(-sh, 4)
        ho = FC.sdf_obj(spec.id + "_horn", hn, 0.0018, 360, material("horn_tmp", "#c9b48a"), symmetric=False)
        so = FC.sdf_obj(spec.id + "_hstrap", Union([st, cords], k=0.002), 0.0012, 320, material("strap_tmp", "#5b3d26"),
                        symmetric=False)
        fo = horn_fittings(ax)
        objs += [(ho, 0), (so, 1), (fo, 2)]
        paths.append(FC.strap_path(K, 1, env))
    if pouch:
        pn, st, cords, sh = pouch_parts(ctx, K, env)
        shifts["pouch_shift_x"] = round(sh, 4)
        po = FC.sdf_obj(spec.id + "_pouch", pn, 0.0016, 320, material("pouch_tmp", "#70502f"), symmetric=False)
        so = FC.sdf_obj(spec.id + "_pstrap", Union([st, cords], k=0.002), 0.0012, 320, material("strap_tmp", "#5b3d26"),
                        symmetric=False)
        objs += [(po, 3 if horn else 0), (so, 1)]
        paths.append(FC.strap_path(K, -1, env))
    zones = []
    strap_mask = []
    for ob, z in objs:
        n = len(ob.data.polygons)
        zones += [z] * n
        strap_mask += [z == 1] * n
    ob = join([o for o, _ in objs], spec.id)
    zones = np.array(zones)
    strap_mask = np.array(strap_mask)
    # the cords' lower ends are on the horn / pouch: rigid pelvis below the strap
    W = strap_weights(ctx, ob, strap_mask & (FC.poly_arrays(ob)[0][:, 2] > STRAP_BOTTOM - 0.001), paths)
    C, N, _ = FC.poly_arrays(ob)
    parts = [FC.Flat(v3(0, 0, 0.9), v3(0, 1, 0), v3(0, 0, 1))]
    uv_fn = lambda o: FC.part_uvs(o, parts, np.zeros(len(o.data.polygons), int))
    return {"main": Surface(ob, zones=zones, weights=W, uv=uv_fn)}, shifts


def exporting():
    return "--no-export" not in sys.argv


def variant_path(spec, env):
    return os.path.join(CAT.ASSETS, "garments", spec.set, "%s_%s.glb" % (spec.id, env))


def build_with_variants(ctx, spec, horn, pouch, generator):
    """Builds and exports the env10 / env20 / env50 variants (finish_part without its own
    export and catalog fragment, then glb export), and returns the env40 surfaces for the
    driver (catalog glb)."""
    shifts_all = {}
    for env in ENVS:
        if env == "env40":
            continue
        parts, sh = build_gear(ctx, spec, env, horn, pouch)
        shifts_all[env] = sh
        res = finish_part(ctx, spec, parts, generator=generator, export=False)
        ob = res["object"]
        path = variant_path(spec, env)
        if exporting():
            export_glb(ctx.bind_rig(), [ob], path, texcoords=True, morph=True)
            write_import(path)
            # sidecar (no id / slot: not a catalog fragment) with the deform limits the
            # checks read for this glb (check_body_deform.gd _read_fragment_limits)
            import json
            with open(os.path.splitext(path)[0] + ".json", "w") as f:
                json.dump({"variant_of": spec.id, "envelope": env, "glb": "res://" + os.path.relpath(path, CAT.FRONTIER),
                           "stats": res["stats"], "deform_limits": spec.extra.get("deform_limits", {})}, f, indent=1)
            log("  %s %s: %d tris -> %s" % (spec.id, env, res["stats"]["tris"], os.path.relpath(path, CAT.FRONTIER)))
        ob.name = ob.data.name = "%s_%s" % (spec.id, env)
        ob.hide_render = True
        ob.hide_viewport = True
    parts, sh = build_gear(ctx, spec, "env40", horn, pouch)
    shifts_all["env40"] = sh
    spec.variants = {env: ("res://assets/character/garments/%s/%s.glb" % (spec.set, spec.id) if env == "env40" else
                           "res://assets/character/garments/%s/%s_%s.glb" % (spec.set, spec.id, env)) for env in ENVS}
    spec.extra["variant_shifts"] = shifts_all
    return parts
