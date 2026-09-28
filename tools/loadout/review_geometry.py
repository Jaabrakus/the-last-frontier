#!/usr/bin/env python3
"""Loadout review: penetration, floating and pair overlap measured on the rendered geometry.

    python3 tools/loadout/review_geometry.py <dump dir> [out.json]

Reads the dump of tools/loadout/review_geometry_dump.gd (the whole skinned body and every visible mesh
of the stowed copies and the in-hand model, skeleton space, per preset and pose) and measures, per item
and sample:

  - penetration into the body, per body layer (skin = Body + Face, clothes = the outfit, gear = belt,
    straps and pouch; the hidden legacy horn left out): signed distance of each item vertex to the
    nearest vertex of that layer (plane distance along its normal, agreed by the 3 nearest), deepest
    value and the body bone there;
  - pair overlap between items: the same signed distance of A's vertices to B's surface, both ways;
  - floating: for back items (points long_A, long_B, quiver) the gap between the item and anything
    under it (body or another item), over its lower and upper thirds along its long axis.

Independent of the runtime's capsules (the tests measure those). Numbers are metres in the JSON and cm
in the printout. Needs numpy only.

Provenance: the geometry is posed from Actor_B.
"""
import json
import os
import sys

import numpy as np

np.seterr(all="ignore")  # Accelerate BLAS raises spurious matmul warnings on macOS

HIDDEN_HORN = {"Gear/horn", "Gear/wood", "Gear/horn_tip"}
LAYERS = {"skin": ("Body/", "Face/"), "clothes": ("Clothes/",), "gear": ("Gear/",), "hair_hat": ("Hair/", "Hat/")}
BACK = ("long_A.", "long_B.", "quiver.")


def load(d, fn):
    a = np.fromfile(os.path.join(d, fn), dtype="<f4").reshape(-1, 6)
    return a[:, :3].astype(np.float64), a[:, 3:].astype(np.float64)


def nearest(P, V, k=3, chunk=2048):
    """Indices and distances of the k nearest V for each P (brute force in chunks)."""
    idx = np.empty((len(P), k), dtype=np.int64)
    dst = np.empty((len(P), k))
    Vn = (V * V).sum(1)
    for s in range(0, len(P), chunk):
        p = P[s:s + chunk]
        d2 = (p * p).sum(1)[:, None] - 2.0 * p @ V.T + Vn[None, :]
        part = np.argpartition(d2, k - 1, axis=1)[:, :k]
        pd = np.take_along_axis(d2, part, 1)
        o = np.argsort(pd, 1)
        idx[s:s + chunk] = np.take_along_axis(part, o, 1)
        dst[s:s + chunk] = np.sqrt(np.maximum(np.take_along_axis(pd, o, 1), 0.0))
    return idx, dst


def signed(P, V, N, near_m=0.08):
    """Signed distance of P to the surface sampled by V / N (inf where farther than near_m): the plane
    distance to the nearest vertex, kept negative only when the 3 nearest planes agree."""
    out = np.full(len(P), np.inf)
    at = np.full(len(P), -1, dtype=np.int64)
    if len(V) == 0 or len(P) == 0:
        return out, at
    # only the surface near the points' box, and only the points near the surface's box
    lo, hi = P.min(0) - near_m, P.max(0) + near_m
    vsel = np.where(((V >= lo) & (V <= hi)).all(1))[0]
    if len(vsel) < 3:
        return out, at
    V, N = V[vsel], N[vsel]
    lo, hi = V.min(0) - near_m, V.max(0) + near_m
    psel = np.where(((P >= lo) & (P <= hi)).all(1))[0]
    if len(psel) == 0:
        return out, at
    # coarse filter: points far from a thinned copy cannot be near the surface
    step = max(1, len(V) // 1500)
    _, dc = nearest(P[psel], V[::step], k=1)
    cand = psel[np.where(dc[:, 0] < near_m + 0.06)[0]]
    if len(cand) == 0:
        return out, at
    idx, dst = nearest(P[cand], V, k=3)
    keep = dst[:, 0] < near_m
    pl = np.einsum("ijk,ijk->ij", P[cand][:, None, :] - V[idx], N[idx])
    sd = np.where((pl < 0).all(1), pl.max(1), np.abs(pl[:, 0]))
    sd = np.where(keep, sd, np.inf)
    out[cand] = sd
    at[cand] = vsel[idx[:, 0]]
    return out, at


def main():
    d = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(d, "review_geometry.json")
    ix = json.load(open(os.path.join(d, "index.json")))
    surf = ix["body"]["surfaces"]
    counts = ix["body"]["counts"]
    bones = np.array(ix["body"]["dominant_bone"])
    lab = np.concatenate([np.full(c, s, dtype=object) for s, c in zip(surf, counts)])
    layer_mask = {L: np.array([any(str(x).startswith(p) for p in pre) for x in lab]) for L, pre in LAYERS.items()}
    horn_mask = np.array([str(x) in HIDDEN_HORN for x in lab])
    poses = {p["id"]: p["file"] for p in ix["poses"]}
    body_cache = {}
    results = []
    for s in ix["samples"]:
        pid, pose, held = s["preset"], s["pose"], s["held"]
        if pose not in body_cache:
            body_cache.clear()
            body_cache[pose] = load(d, poses[pose])
        BV, BN = body_cache[pose]
        hide = ix["body"].get("legacy_horn_hidden_" + pid, False)
        items = [(it["name"], it["item"]) + load(d, it["file"]) for it in s["items"]]
        rec = {"preset": pid, "pose": pose, "held": held, "items": {}, "pairs": {}}
        for name, item, P, _ in items:
            r = {}
            for L, m in layer_mask.items():
                mm = m & ~horn_mask if hide else m
                sd, at = signed(P, BV[mm], BN[mm])
                j = int(np.argmin(sd))
                if np.isfinite(sd[j]):
                    r[L] = [round(float(sd[j]), 4), str(bones[np.where(mm)[0][at[j]]]) if at[j] >= 0 else "",
                            [round(float(x), 3) for x in P[j]]]
            rec["items"][name] = {"body": r}
        # pairs (different entries; a flyer / hand model and its own stowed copy are never both shown)
        for a in range(len(items)):
            for b in range(a + 1, len(items)):
                na, ia, Pa, Na = items[a]
                nb, ib, Pb, Nb = items[b]
                s1, _ = signed(Pa, Pb, Nb, 0.06)
                s2, _ = signed(Pb, Pa, Na, 0.06)
                m = min(float(s1.min()), float(s2.min()))
                if np.isfinite(m):
                    rec["pairs"]["%s | %s" % (na, nb)] = round(m, 4)
        # floating: back items, gap to anything under them over the lower / upper third of their axis
        allP = [(n, P) for n, _, P, _ in items]
        for name, item, P, _ in items:
            if not name.startswith(BACK):
                continue
            c = P.mean(0)
            u, sv, vt = np.linalg.svd(P - c, full_matrices=False)
            ax = vt[0]
            tproj = (P - c) @ ax
            if ax[1] < 0:
                tproj = -tproj
            lo_t, hi_t = np.quantile(tproj, [0.33, 0.67])
            under = [BV[~horn_mask] if hide else BV]
            under += [Q for n, Q in allP if n != name and not n.startswith(("hand.", "flyer."))]
            U = np.concatenate(under)
            _, du = nearest(P, U, k=1)
            du = du[:, 0]
            _, db = nearest(P, BV[~horn_mask] if hide else BV, k=1)
            db = db[:, 0]
            rec["items"][name]["float"] = {
                "min_gap_any": round(float(du.min()), 4),
                "lower_gap_any": round(float(du[tproj <= lo_t].min()), 4),
                "upper_gap_any": round(float(du[tproj >= hi_t].min()), 4),
                "min_gap_body": round(float(db.min()), 4),
                "lower_gap_body": round(float(db[tproj <= lo_t].min()), 4),
                "upper_gap_body": round(float(db[tproj >= hi_t].min()), 4),
            }
        rec["entries"] = s.get("entries", {})
        results.append(rec)
    json.dump(results, open(out_path, "w"), indent=0)
    print("samples", len(results), "->", out_path)


if __name__ == "__main__":
    main()
