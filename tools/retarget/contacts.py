"""Automatic contact / grip detection for the Actor_A -> Actor_B batch retarget.

Every detector reads the Actor_A source pose (world positions in clip space, Godot axes:
+X = rider's left, +Y up, +Z forward) and returns per-frame weights in [0, 1] that
retarget.py uses as IK weights, support weights or blend curves. All thresholds are in
metres of the Actor_A clip and are documented next to each function, so a clip family
never needs hand-written contact keys unless a detector cannot know the answer (the
mount clips, whose reference frame moves from the ground to the saddle).
"""
import numpy as np


def ramp(x, full, zero):
    """1 where x <= full, 0 where x >= zero, smoothstep in between (full < zero)."""
    u = np.clip((np.asarray(x, float) - full) / (zero - full), 0.0, 1.0)
    return 1.0 - u * u * (3 - 2 * u)


def smooth(x, sigma, loop=False):
    """Gaussian smoothing along axis 0. loop=True treats the clip as a seamless loop whose
    last frame duplicates the first (period F - 1), so the seam stays exact."""
    x = np.asarray(x, float)
    F = len(x)
    if sigma <= 0 or F < 3:
        return x.copy()
    r = int(np.ceil(3 * sigma))
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    if loop:
        body = x[:-1]
        n = len(body)
        idx = (np.arange(-r, n + r)) % n
        pad = body[idx]
        out = np.zeros_like(body)
        for i, kv in enumerate(k):
            out += kv * pad[i:i + n]
        return np.concatenate([out, out[:1]])
    pad = np.concatenate([np.repeat(x[:1], r, 0), x, np.repeat(x[-1:], r, 0)])
    out = np.zeros_like(x)
    for i, kv in enumerate(k):
        out += kv * pad[i:i + F]
    return out


def is_loop(GPA, tol=0.005):
    """A clip is a seamless loop when its first and last frames are the same pose
    (every joint within tol metres in clip space)."""
    return GPA.shape[0] > 2 and float(np.abs(GPA[0] - GPA[-1]).max()) < tol


# ------------------------------------------------------------------ ground clips
def hand_floor_weights(GPA, A):
    """Hands near the floor (crawl plants, get-down / get-up pushes): IK the wrist to the
    ground-mapped Actor_A wrist. Weight 1 while A's wrist is below 0.25 m, 0 above 0.45 m,
    and only while the body is low (A's pelvis below 0.60 m, fading out by 0.75 m).
    A's planted crawl wrists sit at 5-6 cm and lift at most 23 cm in the loops (48 cm in the
    starts / stops), so the whole crawl stays under IK and the hand path matches the plants;
    standing melee clips keep the pelvis above 0.68 m, so a low punch (fist-4-to-knee: wrist
    0.35 m, pelvis 0.77 m) is not pulled."""
    gate = ramp(GPA[:, A.idx["pelvis"], 1], 0.60, 0.75)
    return {s: ramp(GPA[:, A.idx[s + "_wrist"], 1], 0.25, 0.45) * gate for s in "lr"}


def knee_contact_weights(GPA, A):
    """Knee on the floor: 1 below 4 cm, 0 above 8 cm of A's knee joint height (the
    prototype's crawl rule). Standing clips never go below 0.25 m."""
    return {s + "_knee": ramp(GPA[:, A.idx[s + "_knee"], 1], 0.04, 0.08) for s in "lr"}


# ------------------------------------------------------------------ two-handed grip
def grip_weights(GPA, GRA, A, main_prop, palm, ref=None):
    """Off hand on a two-handed weapon. The off palm's position in the main-hand prop frame
    is rigid while it grips; weight 1 within 4 cm of the clip's median grip point (or `ref`,
    the grip point of a chained clip), 0 beyond 10 cm (releases, e.g. a one-handed
    follow-through). Returns (weights, rigidity_sd_m)."""
    ip, ih = A.idx[main_prop], A.idx[palm]
    rel = np.einsum("fji,fj->fi", GRA[:, ip], GPA[:, ih] - GPA[:, ip])
    med = np.median(rel, axis=0) if ref is None else np.asarray(ref, float)
    d = np.linalg.norm(rel - med, axis=1)
    sd = float(np.sqrt(np.mean(np.sum((rel - rel.mean(0)) ** 2, 1))))
    return ramp(d, 0.04, 0.10), sd


# ------------------------------------------------------------------ horse clips
class HorseRef:
    """Rider reference points in the saddle frame, from Actor_A's own riding clips:
    stirrups = mean ankles of `actor_a-horse-idle`; rein line = the rein (left) wrist at
    idle -> gallop -> sprint (the hands travel forward along the neck with speed)."""

    def __init__(self, A, clips_fk):
        idle = clips_fk.get("actor_a-horse-idle")
        self.ok = idle is not None
        if not self.ok:
            return
        self.stirrup = {s: idle[:, A.idx[s + "_ankle"]].mean(0) for s in "lr"}
        line = {s: [idle[:, A.idx[s + "_wrist"]].mean(0)] for s in "lr"}
        for n in ("actor_a-horse-gallop-fw", "actor_a-horse-gallop-sprint"):
            if n in clips_fk:
                for s in "lr":
                    line[s].append(clips_fk[n][:, A.idx[s + "_wrist"]].mean(0))
        self.rein_line = {s: np.array(v) for s, v in line.items()}

    def as_dict(self):
        if not self.ok:
            return {}
        return {"stirrup_m": {s: np.round(v, 4).tolist() for s, v in self.stirrup.items()},
                "rein_line_m": {s: np.round(v, 4).tolist() for s, v in self.rein_line.items()}}


def _dist_to_polyline(P, line):
    best = np.full(len(P), np.inf)
    if len(line) == 1:
        return np.linalg.norm(P - line[0], axis=1)
    for a, b in zip(line[:-1], line[1:]):
        ab = b - a
        t = np.clip(np.sum((P - a) * ab, 1) / max(float(ab @ ab), 1e-12), 0, 1)
        best = np.minimum(best, np.linalg.norm(a + t[:, None] * ab - P, axis=1))
    return best


def stirrup_weights(GPA, A, ref):
    """Foot in the stirrup: A's ankle within 0.20 m of its idle stirrup position -> 1,
    beyond 0.35 m -> 0 (bail-offs, leg swings, the blind-fire layers whose pelvis sits
    0.2 m lower)."""
    return {s: ramp(np.linalg.norm(GPA[:, A.idx[s + "_ankle"]] - ref.stirrup[s], axis=1), 0.20, 0.35)
            for s in "lr"}


def rein_weights(GPA, A, ref, sides=("l",)):
    """Rein hand on the reins: A's wrist within 0.12 m of the rein line -> 1, beyond
    0.25 m -> 0. Actor_A rides one-handed (left hand on the reins, right hand free), so by
    default only the left hand is pulled to A's absolute rein positions; a free hand keeps
    the bind-relative (forward-kinematics) pose."""
    return {s: ramp(_dist_to_polyline(GPA[:, A.idx[s + "_wrist"]], ref.rein_line[s]), 0.12, 0.25)
            for s in sides}


# ------------------------------------------------------------------ plants
def plant_lock(free, planted, drift, loop=False, min_len=2, sigma=1.0, axes=(0, 2), pad=1):
    """Hold a contact point where its plant starts. free (F,3): the point's target without the
    lock; planted (F,) bool: the source has the point on the ground; drift (F,3): the source
    point's own (scaled) motion, added from the plant start so a source that slides keeps its
    slide. Runs of at least `min_len` frames are locked on `axes` (horizontal by default).
    Seamless loops (last frame = first) lock a plant that spans the seam as one run. Each run is
    extended by `pad` frames on both sides, where the point follows the source's own (scaled)
    motion into and out of the plant, so a short plant is not entered or left at the free
    target's speed.
    Returns (locked target (F,3), weight (F,)): 1 on every locked frame, released smoothly
    (sigma) outside the run, so the plant is held in full from its first to its last frame."""
    free = np.asarray(free, float)
    F = len(free)
    lock = free.copy()
    wl = np.zeros(F)
    n = F - 1 if (loop and F > 2) else F
    pl = np.asarray(planted[:n], bool)
    if pl.all():
        runs = [(0, n)]
    else:
        start = int(np.argmin(pl)) if (loop and F > 2) else 0  # begin scanning on a free frame
        runs = []
        k = 0
        while k < n:
            f = (start + k) % n
            if not pl[f]:
                k += 1
                continue
            L = 0
            while k + L < n and pl[(start + k + L) % n]:
                L += 1
            runs.append((f, L))
            k += L
    ax = list(axes)
    for f0, L in runs:
        if L < min_len:
            continue
        if loop and F > 2:
            f0, L = f0 - pad, min(L + 2 * pad, n)
        else:
            e0 = max(f0 - pad, 0)
            L = min(f0 + L + pad, n) - e0
            f0 = e0
        f0 %= n
        idx = (f0 + np.arange(L)) % n
        # drift continues across the seam of a loop (frame n duplicates frame 0)
        d = drift[idx] - drift[f0]
        if loop and F > 2:
            wrap = (f0 + np.arange(L)) >= n
            d[wrap] += drift[n] - drift[0]
        lock[np.ix_(idx, ax)] = free[f0, ax][None] + d[:, ax]
        wl[idx] = 1.0
    if n < F:
        lock[F - 1] = lock[0]
        wl[F - 1] = wl[0]
    return lock, np.maximum(wl, smooth(wl, sigma, loop))


# ------------------------------------------------------------------ mount clips
def hips_heading(GP, A):
    """Heading (rad, about +Y, 0 = facing +Z) of the hips (left hip - right hip = the left)."""
    d = GP[:, A.idx["l_upper_leg"]] - GP[:, A.idx["r_upper_leg"]]
    return np.arctan2(-d[:, 2], d[:, 0])


def yaw_matrices(psi):
    c, s = np.cos(psi), np.sin(psi)
    R = np.zeros(np.shape(psi) + (3, 3))
    R[..., 0, 0], R[..., 0, 2], R[..., 1, 1], R[..., 2, 0], R[..., 2, 2] = c, s, 1.0, -s, c
    return R


def _ss(u):
    u = np.clip(u, 0.0, 1.0)
    return u * u * (3 - 2 * u)


def _yaw_schedule(h, fa, fb, psiG, F):
    """Frame yaw per frame: psiG up to fa, 0 from fb, and in between the hips' saddle-frame heading
    turns by smoothstep from its ground value to its seated value (psi absorbs the rest of the
    clip-space turn)."""
    f = np.arange(F, dtype=float)
    u = _ss((f - fa) / max(fb - fa, 1))
    dH = (h[fb] - h[fa] - psiG + np.pi) % (2 * np.pi) - np.pi
    psi = psiG + dH * u - (h - h[fa])
    psi[f <= fa] = psiG
    psi[f >= fb] = 0.0
    return psi


def fit_ground_frame(A, GPA, spec, horse):
    """Fit the ground frame G (origin, yaw) of a mount clip so that, with the push-off ball fixed on
    the floor and the frame yaw scheduled as in mount_align, the stirrup foot's ankle stays at the
    stirrup (Actor_A's seated horse-idle ankle) over the frames where both feet carry the rider
    (spec fit.window). For a yaw the best origin is the mean residual (closed form), so the fit is a
    1-degree search over yaw within +-fit.yaw_range_deg of the starting yaw. The height of the
    origin is the saddle attach height above the ground that the source motion implies."""
    F = GPA.shape[0]
    gf, sf = spec["ground_foot"], spec["stirrup_foot"]
    fa, fb = spec["switch"]
    gp0 = spec["plant"][0]
    w0, w1 = spec["fit"]["window"]
    h = smooth(np.unwrap(hips_heading(GPA, A)), 2.0)
    ball = GPA[:, A.idx[gf + "_ball"]]
    sank = GPA[:, A.idx[sf + "_ankle"]]
    Ws = horse.stirrup[sf]
    y0 = float(spec["yaw_deg"])
    rng = float(spec["fit"].get("yaw_range_deg", 45.0))
    best = None
    win = np.arange(w0, w1 + 1)
    for yaw in np.arange(y0 - rng, y0 + rng + 0.5, 1.0):
        psiG = np.radians(yaw)
        psi = _yaw_schedule(h, fa, fb, psiG, F)
        Rm = yaw_matrices(psi[win])
        rest = Ws[None] - np.einsum("fij,fj->fi", Rm, sank[win] - ball[win]) - (yaw_matrices(psiG) @ ball[gp0])[None]
        o = rest.mean(0)
        rms = float(np.sqrt(np.mean(np.sum((rest - o) ** 2, 1))))
        if best is None or rms < best[0]:
            best = (rms, yaw, o)
    return {"origin": best[2], "yaw_deg": float(best[1]), "rms_m": best[0], "saddle_height_m": float(-best[2][1])}


def mount_align(A, GPA, spec, horse):
    """Mount clips switch their reference frame from the ground (the standing rider) to the saddle
    attach point during the clip, because the source's align channel was never baked. This solves
    that frame per frame, T(f) = (yaw psi, translation t), mapping clip space into the saddle frame,
    so the whole clip can be written in the saddle frame:
      * the ground frame G (origin, yaw) is fitted from the contacts (fit_ground_frame; the fit
        also gives the source's saddle height, the floor lying at origin y);
      * T = G up to frame switch[0], and the identity from switch[1] (the clip is already
        saddle-relative there); in between, the frame yaw follows _yaw_schedule;
      * the translation is a weighted least-squares fit of world-fixed contacts: the push-off
        foot's ball stays where it was planted (frames `plant`, dominant weight, fading out over 4
        frames), the stirrup foot's ankle stays at the stirrup (`stirrup`, fading in over the 6
        frames before and out over 6 after), and the identity takes over over the last 6 frames
        before switch[1]; lightly smoothed outside the plant.
    Returns psi (F,), t (F,3), the ground origin, the fitted frame, the per-frame contact weights
    and ground_to_saddle: 0 while the push-off foot is on the ground, then a smoothstep to 1 while it
    lifts off (see below): the weight of the saddle-relative placement, used to adapt the clip to
    another saddle height (the runtime shifts the clip origin by (1 - ground_to_saddle) x the
    difference)."""
    F = GPA.shape[0]
    f = np.arange(F, dtype=float)
    fit = fit_ground_frame(A, GPA, spec, horse) if spec.get("fit") else None
    if fit:
        psiG, tG = np.radians(fit["yaw_deg"]), np.asarray(fit["origin"], float)
    else:
        psiG, tG = np.radians(float(spec["yaw_deg"])), np.asarray(spec["origin"], float)
    fa, fb = spec["switch"]
    gp0, gp1 = spec["plant"]
    s0, s1 = spec["stirrup"]
    gf, sf = spec["ground_foot"], spec["stirrup_foot"]
    h = smooth(np.unwrap(hips_heading(GPA, A)), 2.0)
    psi = _yaw_schedule(h, fa, fb, psiG, F)
    R = yaw_matrices(psi)
    ball = GPA[:, A.idx[gf + "_ball"]]
    sank = GPA[:, A.idx[sf + "_ankle"]]
    Wg = yaw_matrices(psiG) @ ball[gp0] + tG
    Ws = horse.stirrup[sf] if (horse is not None and horse.ok) else sank[fb]
    wg = 10.0 * np.where(f < gp0, 0.0, np.where(f <= gp1, 1.0, 1.0 - _ss((f - gp1) / 4.0)))
    ws = np.where(f < s0, _ss((f - (s0 - 6)) / 6.0), np.where(f <= s1, 1.0, 1.0 - _ss((f - s1) / 6.0)))
    we = 4.0 * _ss((f - (fb - 6)) / 6.0)
    eps = 0.02
    u = _ss((f - fa) / max(fb - fa, 1))
    t_lin = (1 - u)[:, None] * tG[None]
    num = (wg[:, None] * (Wg - np.einsum("fij,fj->fi", R, ball)) + ws[:, None] * (Ws - np.einsum("fij,fj->fi", R, sank))
           + eps * t_lin)
    t = num / (wg + ws + we + eps)[:, None]
    t[f <= fa] = tG
    t[f >= fb] = 0.0
    ts = smooth(t, 1.5)
    keep = (f <= fa) | (f >= fb) | ((f >= gp0) & (f <= gp1))
    ts[keep] = t[keep]
    # ground_to_saddle: 0 up to the end of the push-off plant (the planted ball is then exact in the
    # world under the runtime recipe, whatever the saddle height), then a smoothstep while that foot
    # lifts off, done by the frame its ball is 0.25 m up (6..14 frames): a saddle-height difference
    # is taken up while neither foot is on the ground
    by = np.einsum("fij,fj->fi", R, ball)[:, 1] + ts[:, 1] - Wg[1]
    up = np.nonzero((f > gp1) & (by > 0.25))[0]
    r0 = gp1 + 1
    r1 = int(np.clip(up[0] if len(up) else r0 + 10, r0 + 6, r0 + 14))
    lam = _ss((f - r0) / float(r1 - r0))
    return {"psi": psi, "t": ts, "t_ground": tG, "fit": fit, "w_ground_foot": wg / 10.0, "w_stirrup": ws,
            "ground_to_saddle": lam, "stirrup_world": np.asarray(Ws, float), "ground_ball_world": Wg}
