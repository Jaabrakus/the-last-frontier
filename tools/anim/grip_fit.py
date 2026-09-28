#!/usr/bin/env python3
"""Fits the long gun into the LEFT fist for the middle carry (push n01c; user 2026-09-26: "for the one hand hold
the left hand doesn grip it properly").

Input: the JSON of tests/torch/tools/grip_fit_export.gd (each candidate finger pose's left-hand skin vertices in
the l_palm frame, the gun's triangles round the grip in model space: origin at the wrist of the stock, barrel -Z,
up +Y, lock +X).

For each candidate the gun's model frame is placed in the palm frame (6 DOF) to minimise:
  * the skin inside the wood (vertices deeper than SKIN_GIVE_M: heavy);
  * the palm's gap to the wood (its nearest vertex, target PALM_TARGET_M);
  * each finger's gap (index..pinky, target FINGER_TARGET_M) and the thumb's (lighter), and each fingertip's (its
    distal phalanx, TIP_TARGET_M: a closed wrap, not only the first joints touching);
  * the palm's middle at the balance point along the barrel (BALANCE_M from the wrist of the stock);
  * the muzzle out of the thumb side of the fist (along the pinky -> index knuckle line) and the gun upright
    under the forearm (the gun's up within UP_SOFT_DEG of the forearm's line toward the elbow).
The wood's signed distance comes from slices across the barrel (SLICE_M) on a 1 mm grid (negative inside a part:
ray parity per mesh part), interpolated trilinearly.

  python3 tools/anim/grip_fit.py <export.json> [--balance 0.40] [--only name,...] [--curl name=deg,...]

Prints per candidate the gaps (cm), the depth, the wrap and the fit: the model frame in the palm frame (a Godot
Transform3D literal) and the palm in the model frame.
"""

import argparse
import json
import math
import sys

import numpy as np

SLICE_M = 0.002
GRID_M = 0.001
SKIN_GIVE_M = 0.002
PALM_TARGET_M = 0.002
FINGER_TARGET_M = 0.001
TIP_TARGET_M = 0.004
UP_SOFT_DEG = 15.0
AXIS_SOFT_DEG = 25.0
FINGERS = ["index", "middle", "ring", "pinky"]


def build_sdf(gun, z_lo, z_hi):
    tris = np.array([t[:9] for t in gun["tris"]], dtype=np.float64).reshape(-1, 3, 3)
    part = np.array([t[9] for t in gun["tris"]], dtype=np.int64)
    zs = np.arange(z_lo, z_hi + 1e-9, SLICE_M)
    xs = np.arange(-0.07, 0.07 + 1e-9, GRID_M)
    ys = np.arange(-0.06, 0.11 + 1e-9, GRID_M)
    gx, gy = np.meshgrid(xs, ys, indexing="ij")
    pts = np.stack([gx.ravel(), gy.ravel()], 1)
    sdf = np.full((len(zs), len(xs), len(ys)), 0.05)
    for i, zc in enumerate(zs):
        segs, sp = cut(tris, part, zc)
        if len(segs) == 0:
            continue
        a = segs[:, 0]
        b = segs[:, 1]
        ab = b - a
        l2 = np.maximum((ab * ab).sum(1), 1e-14)
        best = np.full(len(pts), np.inf)
        inside = np.zeros(len(pts), dtype=bool)
        chunk = 4000
        for s0 in range(0, len(pts), chunk):
            p = pts[s0:s0 + chunk]
            ap = p[:, None, :] - a[None]
            t = np.clip((ap * ab[None]).sum(2) / l2[None], 0.0, 1.0)
            c = a[None] + ab[None] * t[..., None]
            d2 = ((p[:, None, :] - c) ** 2).sum(2)
            best[s0:s0 + chunk] = np.sqrt(d2.min(1))
            # ray parity per part (+x)
            ay, by = a[:, 1], b[:, 1]
            cross = (ay[None] > p[:, 1:2]) != (by[None] > p[:, 1:2])
            with np.errstate(divide="ignore", invalid="ignore"):
                xi = a[None, :, 0] + (p[:, 1:2] - ay[None]) / (by - ay)[None] * (b[None, :, 0] - a[None, :, 0])
            hit = cross & (xi > p[:, 0:1])
            ins = np.zeros(len(p), dtype=bool)
            for pi in np.unique(sp):
                m = sp == pi
                ins |= (hit[:, m].sum(1) % 2) == 1
            inside[s0:s0 + chunk] = ins
        d = np.where(inside, -best, best)
        sdf[i] = d.reshape(len(xs), len(ys))
    return sdf, (zs[0], xs[0], ys[0]), (SLICE_M, GRID_M, GRID_M)


def cut(tris, part, zc):
    s = tris[:, :, 2] - zc
    segs = []
    parts = []
    for k in range(3):
        p = tris[:, k]
        q = tris[:, (k + 1) % 3]
        sp = s[:, k]
        sq = s[:, (k + 1) % 3]
        m = ((sp < 0) & (sq >= 0)) | ((sp >= 0) & (sq < 0))
        t = np.where(m, sp / np.where(m, sp - sq, 1.0), 0.0)
        r = p + (q - p) * t[:, None]
        segs.append(np.where(m[:, None], r[:, :2], np.nan))
    segs = np.stack(segs, 1)  # tri x 3 x 2 (nan where the edge does not cross)
    out = []
    for i in range(len(tris)):
        v = segs[i][~np.isnan(segs[i][:, 0])]
        if len(v) >= 2:
            out.append(v[:2])
            parts.append(part[i])
    if not out:
        return np.zeros((0, 2, 2)), np.zeros(0, dtype=np.int64)
    return np.array(out), np.array(parts)


def sample(sdf, org, step, q):
    """Trilinear signed distance at model points q (N x 3); 0.05 outside the grid."""
    iz = (q[:, 2] - org[0]) / step[0]
    ix = (q[:, 0] - org[1]) / step[1]
    iy = (q[:, 1] - org[2]) / step[2]
    nz, nx, ny = sdf.shape
    ok = (iz >= 0) & (iz < nz - 1) & (ix >= 0) & (ix < nx - 1) & (iy >= 0) & (iy < ny - 1)
    iz = np.clip(iz, 0, nz - 1.001)
    ix = np.clip(ix, 0, nx - 1.001)
    iy = np.clip(iy, 0, ny - 1.001)
    z0 = iz.astype(int)
    x0 = ix.astype(int)
    y0 = iy.astype(int)
    fz = iz - z0
    fx = ix - x0
    fy = iy - y0
    out = 0.0
    for dz in (0, 1):
        for dx in (0, 1):
            for dy in (0, 1):
                w = (fz if dz else 1 - fz) * (fx if dx else 1 - fx) * (fy if dy else 1 - fy)
                out = out + w * sdf[z0 + dz, x0 + dx, y0 + dy]
    return np.where(ok, out, 0.05)


def rotvec(r):
    th = np.linalg.norm(r)
    if th < 1e-12:
        return np.eye(3)
    k = r / th
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + math.sin(th) * K + (1 - math.cos(th)) * K @ K


def softmin(d, tau=0.002):
    m = d.min()
    return m - tau * math.log(np.exp(-(d - m) / tau).sum())


class Fit:
    def __init__(self, cand, sdf, org, step, balance):
        self.c = cand
        v = np.array([x[:3] for x in cand["verts"]])
        self.v = v
        self.reg = np.array([x[3] for x in cand["verts"]])
        self.tip = np.array([bool(x[4]) for x in cand["verts"]])
        self.sdf, self.org, self.step = sdf, org, step
        self.balance = balance
        j = cand["joints"]
        self.fore = np.array(cand["forearm"])
        # the fist's axis: pinky knuckle -> index knuckle (the muzzle out of the thumb side)
        ax = np.array(j["l_indexa"]) - np.array(j["l_pinkyb"])
        self.axis = ax / np.linalg.norm(ax)
        self.masks = {r: self.reg == r for r in ["palm", "thumb"] + FINGERS}

    def model_points(self, x):
        R = rotvec(x[:3])
        t = x[3:]
        return (self.v - t) @ R, R, t   # R: model -> palm basis (columns the model axes)

    def terms(self, x):
        q, R, t = self.model_points(x)
        d = sample(self.sdf, self.org, self.step, q)
        pen = np.maximum(-d - SKIN_GIVE_M, 0.0)
        e = {"pen": 4e4 * (pen ** 2).sum()}
        gp = softmin(d[self.masks["palm"]])
        e["palm"] = 2e3 * (gp - PALM_TARGET_M) ** 2
        for f in FINGERS:
            gf = softmin(d[self.masks[f]])
            e[f] = 1.5e3 * max(gf - FINGER_TARGET_M, 0.0) ** 2
        gt = softmin(d[self.masks["thumb"]])
        e["thumb"] = 4e2 * max(gt - FINGER_TARGET_M, 0.0) ** 2
        # the fingertips on the wood (a closed wrap, not only the first joints touching)
        for f in FINGERS + ["thumb"]:
            m = self.masks[f] & self.tip
            if m.any():
                e["tip_" + f] = (1e3 if f != "thumb" else 3e2) * max(softmin(d[m]) - TIP_TARGET_M, 0.0) ** 2
        # the palm's middle at the balance point
        pm = q[self.masks["palm"]].mean(0)
        e["bal"] = 2e2 * (pm[2] + self.balance) ** 2
        # the muzzle (model -Z) along the fist's axis, the gun's up under the forearm
        muzzle = -R[:, 2]
        up = R[:, 1]
        a_ax = math.degrees(math.acos(np.clip(muzzle @ self.axis, -1, 1)))
        a_up = math.degrees(math.acos(np.clip(up @ self.fore, -1, 1)))
        e["axis"] = 0.02 * max(a_ax - AXIS_SOFT_DEG, 0.0) ** 2
        e["up"] = 0.02 * max(a_up - UP_SOFT_DEG, 0.0) ** 2
        return e, d, q

    def cost(self, x):
        e, _, _ = self.terms(x)
        return sum(e.values())

    def report(self, x):
        e, d, q = self.terms(x)
        out = {}
        for r in ["palm", "thumb"] + FINGERS:
            out[r] = float(d[self.masks[r]].min())
            m = self.masks[r] & self.tip
            out["tip_" + r] = float(d[m].min()) if m.any() else float("nan")
        out["depth"] = float(max(-d.min(), 0.0))
        out["inside"] = int((d < -0.003).sum())
        near = d < 0.012
        pm = q[self.masks["palm"]].mean(0)
        # wrap: sectors round the outline's middle at the palm's z
        cyl = q[near]
        cy = 0.03
        ang = np.degrees(np.arctan2(cyl[:, 1] - cy, cyl[:, 0])) if len(cyl) else np.zeros(0)
        out["wrap"] = len(set(((ang + 180) // 10).astype(int).tolist())) / 36.0
        out["grip_z"] = float(-pm[2])
        R = rotvec(x[:3])
        out["axis_deg"] = math.degrees(math.acos(np.clip(-R[:, 2] @ self.axis, -1, 1)))
        out["up_deg"] = math.degrees(math.acos(np.clip(R[:, 1] @ self.fore, -1, 1)))
        out["terms"] = {k: round(v, 4) for k, v in e.items()}
        return out


def nelder_mead(f, x0, scale, iters=1500, tol=1e-9):
    n = len(x0)
    pts = [x0] + [x0 + np.eye(n)[i] * scale[i] for i in range(n)]
    vals = [f(p) for p in pts]
    for _ in range(iters):
        order = np.argsort(vals)
        pts = [pts[i] for i in order]
        vals = [vals[i] for i in order]
        if abs(vals[-1] - vals[0]) < tol:
            break
        c = np.mean(pts[:-1], 0)
        xr = c + (c - pts[-1])
        fr = f(xr)
        if fr < vals[0]:
            xe = c + 2 * (c - pts[-1])
            fe = f(xe)
            if fe < fr:
                pts[-1], vals[-1] = xe, fe
            else:
                pts[-1], vals[-1] = xr, fr
        elif fr < vals[-2]:
            pts[-1], vals[-1] = xr, fr
        else:
            xc = c + 0.5 * (pts[-1] - c)
            fc = f(xc)
            if fc < vals[-1]:
                pts[-1], vals[-1] = xc, fc
            else:
                for i in range(1, n + 1):
                    pts[i] = pts[0] + 0.5 * (pts[i] - pts[0])
                    vals[i] = f(pts[i])
    i = int(np.argmin(vals))
    return pts[i], vals[i]


def initial(fit, roll):
    """A start: the barrel along the fist's axis through the middle of the finger joints, rolled `roll` about it."""
    j = fit.c["joints"]
    names = ["l_indexb", "l_middleb", "l_ringb", "l_pinkyc", "l_indexa", "l_middlea", "l_ringa", "l_pinkyb"]
    centre = np.mean([np.array(j[n]) for n in names], 0)
    z = -fit.axis   # model +Z (toward the butt)
    up0 = fit.fore - z * (fit.fore @ z)
    up0 /= np.linalg.norm(up0)
    c, s = math.cos(roll), math.sin(roll)
    x0 = np.cross(up0, z)
    y = up0 * c + x0 * s
    x = np.cross(y, z)
    R = np.stack([x, y, z], 1)
    # rotation vector of R
    ang = math.acos(np.clip((np.trace(R) - 1) / 2, -1, 1))
    if ang < 1e-9:
        rv = np.zeros(3)
    else:
        rv = np.array([R[2, 1] - R[1, 2], R[0, 2] - R[2, 0], R[1, 0] - R[0, 1]]) / (2 * math.sin(ang)) * ang
    # put the gun's middle (x 0, y 0.03, z -balance) at the centre
    t = centre - R @ np.array([0.0, 0.03, -fit.balance])
    return np.concatenate([rv, t])


def godot_xf(R, t):
    """A Godot Transform3D literal (the basis given by its x, y, z axes: the columns of R)."""
    return "Transform3D(Basis(Vector3(%.5f, %.5f, %.5f), Vector3(%.5f, %.5f, %.5f), Vector3(%.5f, %.5f, %.5f)), Vector3(%.5f, %.5f, %.5f))" % (
        R[0, 0], R[1, 0], R[2, 0], R[0, 1], R[1, 1], R[2, 1], R[0, 2], R[1, 2], R[2, 2], t[0], t[1], t[2])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("json")
    ap.add_argument("--balance", type=float, default=0.40)
    ap.add_argument("--only", default="")
    ap.add_argument("--restarts", type=int, default=8)
    a = ap.parse_args()
    d = json.load(open(a.json))
    gun = d["gun"]
    z_lo = max(gun["z0"], -a.balance - 0.12)
    z_hi = min(gun["z1"], -a.balance + 0.12)
    sdf, org, step = build_sdf(gun, z_lo, z_hi)
    mid = sdf[len(sdf) // 2]
    ins = np.argwhere(mid < 0)
    print("gun %s: SDF %s, at z %.3f the wood spans x %.3f..%.3f y %.3f..%.3f" % (
        gun["name"], sdf.shape, org[0] + (len(sdf) // 2) * step[0], org[1] + ins[:, 0].min() * step[1],
        org[1] + ins[:, 0].max() * step[1], org[2] + ins[:, 1].min() * step[2], org[2] + ins[:, 1].max() * step[2]))
    only = [s for s in a.only.split(",") if s]
    results = []
    for cand in d["candidates"]:
        if only and cand["name"] not in only:
            continue
        fit = Fit(cand, sdf, org, step, a.balance)
        best = None
        rng = np.random.default_rng(7)
        for k in range(a.restarts):
            x0 = initial(fit, math.radians(-60 + 120 * k / max(a.restarts - 1, 1)))
            x0[3:] += rng.normal(0, 0.004, 3)
            x, v = nelder_mead(fit.cost, x0, np.array([0.15, 0.15, 0.15, 0.01, 0.01, 0.01]))
            x, v = nelder_mead(fit.cost, x, np.array([0.04, 0.04, 0.04, 0.003, 0.003, 0.003]))
            if best is None or v < best[1]:
                best = (x, v)
        x, v = best
        r = fit.report(x)
        R = rotvec(x[:3])
        t = x[3:]
        results.append((v, cand["name"], r, R, t))
        print("\n%s (%s, %s): cost %.4f" % (cand["name"], cand["clip"], cand["side"], v))
        print("  palm %.1f | index %.1f middle %.1f ring %.1f pinky %.1f | thumb %.1f cm | depth %.1f cm (%d in) | wrap %.0f%% | at %.3f m | axis %.0f up %.0f deg" % (
            r["palm"] * 100, r["index"] * 100, r["middle"] * 100, r["ring"] * 100, r["pinky"] * 100, r["thumb"] * 100,
            r["depth"] * 100, r["inside"], r["wrap"] * 100, r["grip_z"], r["axis_deg"], r["up_deg"]))
        print("  tips: index %.1f middle %.1f ring %.1f pinky %.1f thumb %.1f cm" % tuple(
            r["tip_" + f] * 100 for f in FINGERS + ["thumb"]))
        print("  terms", r["terms"])
        print("  model in palm:", godot_xf(R, t))
        Ri = R.T
        print("  palm in model:", godot_xf(Ri, -Ri @ t))
    results.sort(key=lambda r: r[0])
    print("\nranking:", ", ".join("%s %.4f" % (r[1], r[0]) for r in results))


if __name__ == "__main__":
    sys.exit(main())
