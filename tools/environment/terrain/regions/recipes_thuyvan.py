"""Thủy Vân's terrain recipes (R1 first), one per square type of data/world/maps/r1/squares.json. bake_region.py blends
them across square borders and carves the water into the result.

A recipe is a function of WORLD position only, so squares baked one at a time meet without a seam:

    recipe(P, cell, prm) -> (h, v, aux)

  P     the sample points (bake_region.Points): P.x, P.z (1D arrays), P.U (the region's broad relief from every
        square's "relief" points), P.ch(cid) (the nearest centre-line point of a channel: off (+ on its right bank
        looking downstream), dp (metres past its bank; < 0 in its water), hw, bd (bed depth), exp, s, lvl (its surface
        level, smoothed far from it), lvl0 (the exact surface level), bed (its bed cross-section there)),
        P.channels (the ids), P.landmark(name), P.pound_group(id), P.sub(points) (the same recipe's inputs elsewhere)
  cell  the square's id ("C1"), its centre (cx, cz), its seed
  prm   the square's recipe parameters (squares.json: the type's params, then the cell's own)

  h     the upland: the recipe's ground with no water cut
  v     the valley ceiling: the bed in a channel's water, its bank at its level, and the recipe's valley walls rising
        from the bank (every profile is 0 at the bank, so a blend of them meets the water's edge exactly)
  aux   splat hints, each 0..1: path, pad, terrace, rock, forest (a share added or taken), karst

bake_region.py takes min(blend of h + the region's outer rim, blend of v), lifts the banks to their water level, and
sets the beds and the pounds' floors from water_net.py.

Karst towers and sheer faces are meshes (Phase 3); a recipe only marks their footprints (footprints()).
Recipes flagged "placeholder" in squares.json meet the layout's levels and seams; Phase 3 M2 finishes them.
"""
import math

import numpy as np

from common import fbm, noise, smoothstep

SQUARE_HALF = 416.0


# --- Shared pieces ----------------------------------------------------------------------------------

def softplus(x, k):
    return k * np.logaddexp(0.0, x / k)


def ridged(x, z, lam, octaves, seed):
    """Ridged noise in [0, 1]: sharp crests along the zero lines of an fbm."""
    return 1.0 - np.abs(fbm(x, z, lam, octaves, seed))


def micro(P, seed, amp=0.25):
    return amp * (0.6 * noise(seed)(P.x / 9.0, P.z / 9.0) + 0.4 * noise(seed + 1)(P.x / 5.5, P.z / 5.5))


def terrace(h, step, riser, align):
    """Contour terraces: flat treads at align + k*step, joined by risers over the top `riser` share of each step."""
    q = (h - align) / step
    k = np.floor(q)
    return align + step * (k + smoothstep(1.0 - riser, 1.0, q - k))


def terrace_riser(h, step, riser, align):
    """1 on a terrace's riser, 0 on its tread (for the splat: risers are grass banks, treads worked ground)."""
    q = (h - align) / step
    return smoothstep(1.0 - riser - 0.05, 1.0 - riser + 0.02, q - np.floor(q))


def seat_paddies(P, base, gid, reach):
    """Bend the slope so a paddy group sits in it: within `reach` m of the group the ground eases onto the plane through
    its paddies' levels (a least-squares fit in x and z of their centres), fully at the group itself."""
    ps = P.pound_group(gid)["pounds"]
    cx = np.array([np.mean([q[0] for q in p["polygon"]]) for p in ps])
    cz = np.array([np.mean([q[1] for q in p["polygon"]]) for p in ps])
    lv = np.array([float(p["level"]) for p in ps])
    A = np.stack([np.ones_like(cx), cx - cx.mean(), cz - cz.mean()], -1)
    coef = np.linalg.lstsq(A, lv, rcond=None)[0]
    plane = coef[0] + coef[1] * (P.x - cx.mean()) + coef[2] * (P.z - cz.mean())
    bx = [q[0] for p in ps for q in p["polygon"]]
    bz = [q[1] for p in ps for q in p["polygon"]]
    ex = np.maximum(np.maximum(min(bx) - P.x, P.x - max(bx)), 0.0)
    ez = np.maximum(np.maximum(min(bz) - P.z, P.z - max(bz)), 0.0)
    w = smoothstep(reach, 0.0, np.hypot(ex, ez))
    return base + (plane - base) * w


def wobble(P, dp, amp, lam, seed):
    """dp pushed in and out along the river so walls are not parallel to it; never at the bank itself."""
    return dp + amp * smoothstep(0.0, 12.0, dp) * fbm(P.x, P.z, lam, 2, seed)


def valley(P, profile, rough=None, channels=None):
    """The valley ceiling over every channel: its bed in the water, its level + profile(dp, f) on land. rough:
    (amp m, from m, seed) rumples the sides from `from` m past the bank so they are never planes."""
    v = np.full(P.x.shape, np.inf)
    for cid in channels or P.channels:
        f = P.ch(cid)
        dp = np.maximum(f["dp"], 0.0)
        rise = profile(dp, f)
        if rough is not None:
            amp, start, seed = rough
            rise = rise + amp * smoothstep(start, start + 60.0, dp) * fbm(P.x, P.z, 110.0, 4, seed)
        vc = np.where(f["dp"] < 0.0, f["bed"], f["lvl"] + rise)
        v = np.minimum(v, vc)
    return v


def vee(P, bank_h, side_slope, seed):
    """A plain valley: a bank bank_h over the water within 4 m, then sides rising side_slope a metre (steeper and
    gentler by turns along it)."""
    def prof(dp, f):
        dpw = wobble(P, dp, 14.0, 90.0, seed)
        sl = side_slope * (1.0 + 0.35 * fbm(P.x, P.z, 160.0, 2, seed + 1))
        return bank_h * smoothstep(0.0, 4.0, dp) + sl * np.maximum(dpw, 0.0) * smoothstep(0.0, 10.0, dp)
    return prof


def banks(P, bank_h, flood_w, hill_slope, seed):
    """A river with a floodplain: a bank bank_h over the water within 6 m, a flat (gently rumpled) plain about flood_w
    wide, then the valley's sides at hill_slope."""
    k = 25.0

    def prof(dp, f):
        plain = 0.5 * smoothstep(6.0, 30.0, dp) * fbm(P.x, P.z, 70.0, 2, seed)
        fw = flood_w * (1.0 + 0.3 * fbm(P.x, P.z, 220.0, 2, seed + 1))
        hill = hill_slope * (softplus(dp - fw, k) - softplus(-fw, k))
        return bank_h * smoothstep(0.0, 6.0, dp) + plain + hill
    return prof


def walled(depth, wall, strata, riser, beyond, bench_w=0.0, bench_h=0.0, wob=None):
    """A gorge or a slot: an optional bench on the right bank (looking downstream), then a wall rising depth over wall m
    (steepest at its foot, rounding at the lip), cut into ledges strata m high with steep risers, then on at beyond
    a metre. wob: (P, amp, lam, seed) to wander the wall's line."""
    def prof(dp, f):
        if wob is not None:
            P, amp, lam, seed = wob
            dpw = wobble(P, dp, amp, lam, seed)
        else:
            dpw = dp
        right = f["off"] > 0.0
        t0 = np.where(right, bench_w, 0.0)
        bench = np.where(right, bench_h * smoothstep(0.0, 3.0, dpw), 0.0)
        tw = np.clip((dpw - t0) / wall, 0.0, 1.0)
        w = depth * (1.0 - (1.0 - tw) ** 2)
        if strata > 0.0:
            w = terrace(w, strata, riser, 0.0)
        return bench + w + beyond * np.maximum(dpw - t0 - wall, 0.0)
    return prof


def lip(P, cid, rim_h, reach):
    """How far a channel's gorge lip (its level + rim_h) stands over the broad relief, faded out over `reach` m from
    the bank (the gorge cuts a ridge where the land is lower than its lip)."""
    f = P.ch(cid)
    return np.maximum(f["lvl"] + rim_h - P.U, 0.0) * smoothstep(reach, reach * 0.35, np.maximum(f["dp"], 0.0))


def line_frame(P, at, angle_deg):
    """Coordinates along (a) and across (n, + on the left of the direction) a line through `at` at angle_deg (0 = +x,
    90 = +z)."""
    ux, uz = math.cos(math.radians(angle_deg)), math.sin(math.radians(angle_deg))
    dx, dz = P.x - at[0], P.z - at[1]
    return dx * ux + dz * uz, -dx * uz + dz * ux


def pad(P, at, radius, feather, level, h):
    """A flat round pad at `level` (house floors, courts): h within radius, eased back over feather."""
    w = smoothstep(radius + feather, radius, np.hypot(P.x - at[0], P.z - at[1]))
    return h + (level - h) * w, w


def zeros(P):
    return np.zeros(P.x.shape)


# --- Full recipes (the slice: C1, B1, C2, B2, and the rim A4, B4) ------------------------------------

def gorge(P, cell, prm):
    """C1: the main channel in a gorge. The east wall rises sheer from the water; on the west (its right bank looking
    downstream) a walkable bench runs along the water before the wall, where the cordon and the undercut bank stand.
    The walls are cut into rock ledges; past the lip the ground eases back into the broad relief."""
    seed = cell["seed"]
    depth, wall = prm["depth_m"], prm["wall_m"]
    bench_w = prm["bench_m"] * (0.55 + 0.9 * (0.5 + 0.5 * fbm(P.x, P.z, 90.0, 2, seed + 7)))
    prof = walled(depth, wall, prm["strata_m"], prm["riser"], prm["beyond_slope"], bench_w, prm["bench_h_m"],
                  wob=(P, prm["wander_m"], 70.0, seed + 11))
    v = valley(P, prof, (8.0, wall, seed + 17))
    rough = prm["rough_m"] * fbm(P.x, P.z, 140.0, 4, seed + 3)
    h = P.U + lip(P, "main", depth + prm["bench_h_m"], wall + prm["lip_fade_m"]) + rough + micro(P, seed + 5)
    f = P.ch("main")
    near_wall = smoothstep(wall + 30.0, wall * 0.5, np.maximum(f["dp"], 0.0))
    aux = {"rock": near_wall * smoothstep(-0.2, 0.4, fbm(P.x, P.z, 25.0, 2, seed + 13)) * 0.6,
           "forest": 0.25 * smoothstep(wall + 40.0, wall + 160.0, f["dp"])}
    return h, v, aux


def terraced_slope(P, cell, prm):
    """B1: the village's slope in contour terraces with flat treads (the paddy steps), aligned so the layout's village
    paddies sit on treads; the terraces give way to forest up the slope, and a cliff band stands at the rope-rite
    cliff."""
    seed = cell["seed"]
    base = P.U + prm["rough_m"] * fbm(P.x, P.z, 120.0, 3, seed + 3)
    base = seat_paddies(P, base, prm["align_to"], prm["seat_m"])
    align = P.pound_group(prm["align_to"])["bed_top"]
    wob = prm["contour_wobble_m"] * fbm(P.x, P.z, prm["contour_lam_m"], 2, seed + 5)
    steps = terrace(base + wob, prm["step_m"], prm["riser"], align)
    riser = terrace_riser(base + wob, prm["step_m"], prm["riser"], align)
    wt = smoothstep(prm["terrace_top_m"] + 12.0, prm["terrace_top_m"] - 8.0, base)
    # The cliff: a band raised cliff_h on its uphill side, tapering over its ends; no terraces close under it.
    cl = prm["cliff"]
    a, n = line_frame(P, P.landmark(cl["at"]), cl["angle_deg"])
    n = n + 6.0 * fbm(P.x, P.z, 45.0, 2, seed + 9)
    taper = smoothstep(cl["length_m"] * 0.5 + 60.0, cl["length_m"] * 0.5, np.abs(a))
    raise_ = cl["height_m"] * smoothstep(-1.5, 1.5, n) * smoothstep(cl["top_m"], 0.3 * cl["top_m"], n) * taper
    wt = wt * (1.0 - smoothstep(45.0, 15.0, np.abs(n)) * taper)
    h = base + (steps - base) * wt + raise_
    v = valley(P, vee(P, 1.5, 0.5, seed + 19), (6.0, 10.0, seed + 17))
    cliff_rock = smoothstep(6.0, 1.0, np.abs(n)) * taper
    aux = {"terrace": wt, "riser": riser * wt, "rock": cliff_rock, "forest": 0.5 * (1.0 - wt) - 0.4 * wt}
    return h, v, aux


def middle_reach(P, cell, prm):
    """C2: the main channel widening through a floodplain, low banks, hills behind; at the ferry a long gentle landing
    on both banks (ferry_bank_m along the river) where the boats are drawn up; the torrent comes in from the west."""
    seed = cell["seed"]
    h = P.U + prm["rough_m"] * fbm(P.x, P.z, 150.0, 3, seed + 3) + micro(P, seed + 5)
    prof = banks(P, prm["bank_h_m"], prm["flood_m"], prm["hill_slope"], seed + 7)
    v = valley(P, prof, (6.0, prm["flood_m"], seed + 17))
    # The ferry landing: within ferry_bank_m of the ferry along the main channel, the bank is a ramp at ferry_slope.
    f = P.ch("main")
    s_ferry = P.landmark_s(prm["ferry_at"], "main")
    half = 0.5 * prm["ferry_bank_m"]
    wf = smoothstep(half + 15.0, half, np.abs(f["s"] - s_ferry)) * smoothstep(prm["ferry_reach_m"] + 30.0,
                                                                              prm["ferry_reach_m"], f["dp"])
    dp = np.maximum(f["dp"], 0.0)
    ramp = f["lvl0"] + prm["ferry_slope"] * dp
    v_main = np.where(f["dp"] < 0.0, f["bed"], f["lvl"] + prof(dp, f))
    v = np.where(f["dp"] < 0.0, v, np.minimum(v, v_main + (np.minimum(ramp, v_main) - v_main) * wf))
    h = h + (np.minimum(h, ramp) - h) * wf
    aux = {"path": wf * smoothstep(-1.0, 2.0, dp), "forest": -0.4 * smoothstep(prm["flood_m"], 20.0, dp)}
    return h, v, aux


def _hillside(P, cell, prm):
    seed = cell["seed"]
    h0 = P.U + prm["rough_m"] * fbm(P.x, P.z, 110.0, 3, seed + 3) + micro(P, seed + 5)
    v = valley(P, vee(P, 1.5, prm["side_slope"], seed + 19), (6.0, 10.0, seed + 17))
    return h0, v


class Trail:
    """The switchbacks' pack trail: `turns` hairpins zigzagging up across span_m about the shrine, from z_from_m to
    z_to_m of it. Its height along it is the hillside's ground there, eased over ~12 m so the grade runs even."""

    def __init__(self, P, cell, prm):
        sx, sz = P.landmark(prm["anchor"])
        legs = int(prm["turns"]) + 1
        z0, z1 = sz + prm["z_from_m"], sz + prm["z_to_m"]
        half = 0.5 * prm["span_m"]
        self.vx = np.array([sx - half if k % 2 == 0 else sx + half for k in range(legs + 1)], dtype=np.float64)
        self.vz = np.array([z0 + (z1 - z0) * k / legs for k in range(legs + 1)], dtype=np.float64)
        seg_l = np.hypot(np.diff(self.vx), np.diff(self.vz))
        self.vs = np.r_[0.0, np.cumsum(seg_l)]
        self.s = np.arange(0.0, self.vs[-1] + 1e-9, 2.0)
        xs, zs = np.interp(self.s, self.vs, self.vx), np.interp(self.s, self.vs, self.vz)
        h0, v = _hillside(P.sub(xs, zs), cell, prm)
        g = np.minimum(h0, v)
        sig = 6.0
        r = int(3 * sig)
        k = np.exp(-0.5 * (np.arange(-r, r + 1) / sig) ** 2)
        self.h = np.convolve(np.pad(g, r, mode="edge"), k / k.sum(), mode="valid")
        h0s, vs = _hillside(P.sub(np.array([float(sx)]), np.array([float(sz)])), cell, prm)
        self.shrine_level = float(min(h0s[0], vs[0]))

    def at(self, P):
        """Distance to the trail's line and the trail's height at the nearest point of it."""
        d = np.full(P.x.shape, np.inf)
        s = np.zeros(P.x.shape)
        for k in range(len(self.vx) - 1):
            ax, az = self.vx[k], self.vz[k]
            dx, dz = self.vx[k + 1] - ax, self.vz[k + 1] - az
            t = np.clip(((P.x - ax) * dx + (P.z - az) * dz) / (dx * dx + dz * dz), 0.0, 1.0)
            dk = np.hypot(P.x - (ax + t * dx), P.z - (az + t * dz))
            better = dk < d
            d = np.where(better, dk, d)
            s = np.where(better, self.vs[k] + t * (self.vs[k + 1] - self.vs[k]), s)
        return d, np.interp(s, self.s, self.h)


def switchbacks(P, cell, prm):
    """B2: the slope north of the torrent, with the pack trail climbing it in `turns` hairpins: a level bench 3-4 m wide
    cut into the hillside, its grade eased along it; the hillside shrine on a flat platform beside it."""
    h0, v = _hillside(P, cell, prm)
    ground = np.minimum(h0, v)
    trail = P.trail(cell, prm)
    seg_d, path_h = trail.at(P)
    half = 0.5 * prm["path_w_m"]
    w = smoothstep(half + prm["shoulder_m"], half, seg_d)
    g = ground + (path_h - ground) * w
    shrine = P.landmark(prm["anchor"])
    lvl = float(trail.shrine_level)
    g, wp = pad(P, shrine, prm["shrine_pad_m"], 10.0, lvl, g)
    # Both the upland and the valley take the cut and the fill, so their minimum is the bench wherever it runs.
    h = h0 + (g - ground)
    v = v + (g - ground)
    aux = {"path": np.maximum(smoothstep(half + 0.8, half - 0.4, seg_d), wp * 0.8), "pad": wp,
           "forest": 0.3 * (1.0 - w)}
    return h, v, aux


def rim(P, cell, prm):
    """A4, B4: the backdrop rim, rising to ridges toward the region's south edge so the edge is never seen; spurs and
    crests from ridged noise."""
    seed = cell["seed"]
    vcell = np.clip((P.z - (cell["cz"] - SQUARE_HALF)) / (2.0 * SQUARE_HALF), 0.0, 1.2)
    rise = prm["rise_m"] * smoothstep(prm["from_v"], 1.05, vcell) ** 1.5
    crest = prm["ridge_m"] * ridged(P.x, P.z, 260.0, 4, seed + 3) * smoothstep(prm["from_v"], 0.9, vcell)
    h = P.U + rise * (0.75 + 0.25 * fbm(P.x, P.z, 300.0, 2, seed + 4)) + crest + micro(P, seed + 5, 0.4)
    v = valley(P, vee(P, 1.5, 0.5, seed + 19), (8.0, 10.0, seed + 17))
    steep = smoothstep(0.35, 0.8, ridged(P.x, P.z, 260.0, 4, seed + 3))
    aux = {"rock": 0.5 * steep * smoothstep(0.4, 0.9, vcell), "forest": 0.2}
    return h, v, aux


# --- Placeholders (M2 finishes them) -------------------------------------------------------------------

def high_pass(P, cell, prm):
    """A1 (placeholder): rough high ground with a smoothed corridor north from the waystones (the pass)."""
    seed = cell["seed"]
    ws = P.landmark(prm["anchor"])
    a, n = line_frame(P, ws, -90.0)
    corridor = smoothstep(prm["corridor_m"] * 1.6, prm["corridor_m"] * 0.3, np.abs(n)) * smoothstep(-120.0, 0.0, a)
    crag = prm["crag_m"] * np.clip(0.55 + 0.5 * fbm(P.x, P.z, 260.0, 4, seed + 3)
                                   + 0.35 * (ridged(P.x, P.z, 420.0, 3, seed + 6) - 0.5), 0.0, 1.0)
    h = P.U + crag * (1.0 - corridor) + 3.0 * fbm(P.x, P.z, 90.0, 3, seed + 4) + micro(P, seed + 5, 0.4)
    v = valley(P, vee(P, 1.5, 0.6, seed + 19), (8.0, 10.0, seed + 17))
    return h, v, {"rock": 0.6 * (1.0 - corridor) * smoothstep(0.55, 0.85, crag / max(prm["crag_m"], 1e-6)),
                  "path": 0.5 * corridor * smoothstep(6.0, 2.0, np.abs(n)), "forest": -0.3}


def bridge_gorge(P, cell, prm):
    """A2 (placeholder): the torrent in a narrow slot between the two heights; the bridge (a mesh) spans it."""
    seed = cell["seed"]
    h = P.U + prm["rough_m"] * fbm(P.x, P.z, 120.0, 3, seed + 3) + micro(P, seed + 5)
    prof = walled(prm["depth_m"], prm["wall_m"], prm["strata_m"], 0.5, prm["beyond_slope"],
                  wob=(P, 6.0, 50.0, seed + 11))
    h = h + lip(P, "torrent", prm["depth_m"], prm["wall_m"] + 120.0)
    v = valley(P, prof, (6.0, prm["wall_m"], seed + 17))
    f = P.ch("torrent")
    return h, v, {"rock": smoothstep(prm["wall_m"] + 10.0, 0.0, np.maximum(f["dp"], 0.0)) * 0.8}


def stone_height(P, cell, prm):
    """A3 (placeholder): high ground, cut in stone terraces round the stone hamlet's flat court."""
    seed = cell["seed"]
    base = P.U + prm["rough_m"] * fbm(P.x, P.z, 130.0, 3, seed + 3)
    at = P.landmark(prm["anchor"])
    dh = np.hypot(P.x - at[0], P.z - at[1])
    quarry = smoothstep(prm["court_m"] + 200.0, prm["court_m"] + 90.0, dh) \
        * smoothstep(-0.1, 0.25, fbm(P.x, P.z, 120.0, 2, seed + 4))
    h = base + (terrace(base + 1.5 * fbm(P.x, P.z, 40.0, 2, seed + 5), prm["bench_m"], 0.3, 0.0) - base) * quarry
    court = float(P.sub(np.array([at[0]]), np.array([at[1]])).U[0])
    h, wp = pad(P, at, prm["court_m"], 25.0, court, h)
    v = valley(P, vee(P, 1.5, 0.5, seed + 19), (6.0, 10.0, seed + 17))
    return h, v, {"rock": 0.7 * quarry * (1.0 - wp), "pad": wp, "forest": -0.3 * quarry}


def foothill_paddies(P, cell, prm):
    """B3 (placeholder): gentle foothills in contour terraces aligned to the layout's paddy steps."""
    seed = cell["seed"]
    base = P.U + prm["rough_m"] * fbm(P.x, P.z, 140.0, 3, seed + 3)
    base = seat_paddies(P, base, prm["align_to"], prm["seat_m"])
    align = P.pound_group(prm["align_to"])["bed_top"]
    wob = 1.0 * fbm(P.x, P.z, 90.0, 2, seed + 5)
    steps = terrace(base + wob, prm["step_m"], prm["riser"], align)
    wt = smoothstep(prm["terrace_top_m"] + 10.0, prm["terrace_top_m"] - 6.0, base)
    h = base + (steps - base) * wt
    v = valley(P, vee(P, 1.2, 0.35, seed + 19), (4.0, 10.0, seed + 17))
    riser = terrace_riser(base + wob, prm["step_m"], prm["riser"], align)
    return h, v, {"terrace": wt, "riser": riser * wt, "forest": -0.4 * wt}


def river_flats_lock(P, cell, prm):
    """C3 (placeholder): broad river flats round the lock; the lock chamber and barge basin are carved as pounds."""
    seed = cell["seed"]
    h = P.U + prm["rough_m"] * fbm(P.x, P.z, 160.0, 3, seed + 3) + micro(P, seed + 5)
    v = valley(P, banks(P, prm["bank_h_m"], prm["flood_m"], prm["hill_slope"], seed + 7),
               (6.0, prm["flood_m"], seed + 17))
    f = P.ch("main")
    return h, v, {"forest": -0.5 * smoothstep(prm["flood_m"] + 40.0, 0.0, np.maximum(f["dp"], 0.0))}


def river_exit_karst(P, cell, prm):
    """C4 (placeholder): the river's flats leaving south; the karst towers' footprints raised as low plinths (the
    towers are meshes)."""
    seed = cell["seed"]
    h = P.U + prm["rough_m"] * fbm(P.x, P.z, 160.0, 3, seed + 3) + micro(P, seed + 5)
    karst = zeros(P)
    for at in P.landmark(prm["karst_at"]):
        d = np.hypot(P.x - at[0], P.z - at[1])
        karst = np.maximum(karst, smoothstep(prm["karst_r_m"] + 12.0, prm["karst_r_m"], d))
    h = h + prm["plinth_m"] * karst
    v = valley(P, banks(P, prm["bank_h_m"], prm["flood_m"], prm["hill_slope"], seed + 7),
               (6.0, prm["flood_m"], seed + 17))
    return h, v, {"rock": karst, "karst": karst}


RECIPES = {
    "gorge": gorge, "terraced_slope": terraced_slope, "middle_reach": middle_reach, "switchbacks": switchbacks,
    "rim": rim, "high_pass": high_pass, "bridge_gorge": bridge_gorge, "stone_height": stone_height,
    "foothill_paddies": foothill_paddies, "river_flats_lock": river_flats_lock, "river_exit_karst": river_exit_karst,
}


# --- Footprints (meshes in Phase 3) --------------------------------------------------------------------

def footprints(P0, cell, typ, prm):
    """The square's mesh footprints that a recipe places: karst towers (discs) and named sheer faces (lines). The
    baker adds the sheer faces it finds in the baked slope."""
    out = []
    if typ == "river_exit_karst":
        for at in P0.landmark(prm["karst_at"]):
            out.append({"kind": "karst_tower", "at": [float(at[0]), float(at[1])], "radius_m": prm["karst_r_m"]})
    if typ == "terraced_slope":
        cl = prm["cliff"]
        at = P0.landmark(cl["at"])
        ux, uz = math.cos(math.radians(cl["angle_deg"])), math.sin(math.radians(cl["angle_deg"]))
        hl = 0.5 * cl["length_m"]
        out.append({"kind": "sheer_face", "line": [[at[0] - ux * hl, at[1] - uz * hl], [at[0] + ux * hl, at[1] + uz * hl]],
                    "height_m": cl["height_m"], "for": cl["at"]})
    return out
