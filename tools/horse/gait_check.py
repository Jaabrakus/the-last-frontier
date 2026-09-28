"""Gait diagnostics for the procedural horse without Blender (numpy only).

  python3 tools/horse/gait_check.py [--tools DIR] [--clips walk,trot] [--json OUT]

Solves every clip with gaits.Solver on a rest pose rebuilt from anatomy.bone_table()
(Blender's bone matrices: y = head->tail, z = the align_roll vector) and measures, per clip
and leg, in the GROUND frame (the frame in which planted hooves should not move):

  stance_slip      max toe movement per frame while the leg is in stance
  frame_jump       max movement per frame of the lowest point of the hoof (teleports)
  touchdown_speed  horizontal ground speed of the hoof sole in the frame before touchdown
                   (keyframes; depends on where the touchdown falls between frames)
  liftoff_speed    the same in the frame after lift-off
  ev_*             the same from the exact stance windows, independent of the frame
                   alignment: mean horizontal ground speed over the 1/30 s before each
                   touchdown (td_speed) and after each lift-off (lo_speed), the sole height
                   at the start of that window (td_height) and the approach angle
                   atan(height / distance) (td_angle)
  swing            peak sole clearance, where in the swing it peaks, the lowest sole height
                   over mid-swing (s = 0.2-0.8) and the ground distance covered while the
                   sole is lower than 2 cm (toe drag)
  sink             lowest sole point below the ground
  stretch          leg reach used (1 = straight)
  neck             neck elevation above the horizon (neck root -> poll) and poll height

The same functions run inside build_horse.py (horse_meta.json diagnostics).
"""

import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))


def load(tools_dir):
    sys.path.insert(0, tools_dir)
    sys.dont_write_bytecode = True
    import anatomy as A      # noqa: E402
    import gaits as G        # noqa: E402
    return A, G


def rest_matrices(A):
    """Armature-space rest matrices as Blender builds them in build_horse.build_armature."""
    rest = {}
    for name, (head, tail, parent, deform) in A.bone_table().items():
        h = np.asarray(head, float)
        y = np.subtract(tail, head)
        y = y / np.linalg.norm(y)
        x = np.array([1.0, 0, 0]) - y[0] * y
        if np.linalg.norm(x) < 1e-3:
            x = np.array([0, 1.0, 0]) - y[1] * y
        x /= np.linalg.norm(x)
        v = np.cross(x, y)                    # align_roll target for the bone's z axis
        z = v - (v @ y) * y
        z /= np.linalg.norm(z)
        x = np.cross(y, z)
        M = np.eye(4)
        M[:3, 0], M[:3, 1], M[:3, 2], M[:3, 3] = x, y, z, h
        rest[name] = M
    return rest


SOLE_BONES = {"LF": "hoof_l", "RF": "hoof_r", "LH": "hhoof_l", "RH": "hhoof_r"}


def sole_points(A, rest):
    """Bottom-ring vertices of each hoof in its hoof bone's rest frame."""
    out = {}
    for leg, bone in SOLE_BONES.items():
        V, _ = A.hoof_mesh("l" if leg[0] == "L" else "r", leg[1] == "H")
        P = V[V[:, 2] < 0.006]
        inv = np.linalg.inv(rest[bone])
        out[leg] = (inv @ np.c_[P, np.ones(len(P))].T).T[:, :3]
    return out


def ground_frame(G, name, t):
    """4x4 root space -> ground frame (planted hooves are fixed in it) at clip time t."""
    if hasattr(G, "ground_frame"):
        return G.ground_frame(name, t)
    g = G.GAITS[name]
    M = np.eye(4)
    yr = g.get("yaw_rate", 0.0) if g["kind"] == "cycle" else 0.0
    if yr:
        M[:3, :3] = G.rot(G.UP, yr * t)
        return M
    if hasattr(G, "ground_speed"):
        v = G.ground_speed(name)
    else:
        v = g.get("speed", 0.0) if g["kind"] in ("cycle", "jump") else 0.0
    M[:3, 3] = G.FWD * v * t
    lift = getattr(G, "root_lift", None)
    if lift is not None:
        M[2, 3] += lift(name, t)
    return M


def solve(G, rig, rc, name):
    solver = G.Solver(rig, rc)
    nf, L = G.clip_frames(name, rc)
    if hasattr(solver, "hip_window"):
        solver.hip_window(name, L, nf)
    solver.diag = {}
    solver.hipdiag = {}
    solver.reach_err = 0.0
    frames = []
    for i in range(nf):
        t = L * i / (nf - 1)
        pose = solver.pose_at(name, t, L, nf)
        st = {leg: bool(solver.legs_state[leg]["stance"]) for leg in G.LEGS}
        frames.append(dict(t=t, pose={k: v.copy() for k, v in pose.items()}, toes={k: v.copy() for k, v in solver.toes.items()},
                           stance=st))
    return frames, L, nf, solver


def measure(A, G, rig, rest, rc, name, soles=None):
    frames, L, nf, solver = solve(G, rig, rc, name)
    g = G.GAITS[name]
    loops = g["kind"] in ("cycle", "idle")
    soles = soles or sole_points(A, rest)
    dt = L / (nf - 1)
    res = {"frames": nf, "length": L, "legs": {}}
    # per frame ground-frame sole points; loops are unrolled over two cycles so that events
    # and swings crossing the loop seam are measured in one continuous ground frame
    n = nf - 1 if loops else nf
    K = 2 * n + 1 if loops else nf
    W = {leg: [] for leg in G.LEGS}
    toeW = {leg: [] for leg in G.LEGS}
    st_all = {leg: [] for leg in G.LEGS}
    for k in range(K):
        f = frames[k % n] if loops else frames[k]
        Gm = ground_frame(G, name, k * dt)
        for leg in G.LEGS:
            M = Gm @ f["pose"][SOLE_BONES[leg]]
            P = (M[:3, :3] @ soles[leg].T).T + M[:3, 3]
            W[leg].append(P)
            toeW[leg].append((Gm @ np.append(f["toes"][leg], 1.0))[:3])
            st_all[leg].append(f["stance"][leg])
    for leg in G.LEGS:
        low = np.array([P[np.argmin(P[:, 2])] for P in W[leg]])
        zlow = low[:, 2]
        cen = np.array([P.mean(0) for P in W[leg]])
        st = np.array(st_all[leg])
        toe = np.array(toeW[leg])
        slip = 0.0
        jump = 0.0
        for i in range(K - 1):
            if st[i] and st[i + 1]:
                slip = max(slip, float(np.linalg.norm((toe[i + 1] - toe[i])[:2])))
            jump = max(jump, float(np.linalg.norm(low[i + 1] - low[i])), float(np.linalg.norm(cen[i + 1] - cen[i])))
        # contact events (stance flag changes) in the first cycle (index 1..n for loops)
        rng = range(1, n + 1) if loops else range(1, nf)
        tds = [i for i in rng if st[i] and not st[i - 1]]
        los = [i for i in rng if not st[i] and st[i - 1]]

        def hspeed(a, b):
            return float(np.linalg.norm((cen[b] - cen[a])[:2]) / dt)
        # skating: horizontal ground speed of a swinging hoof whose sole is within 1 cm of
        # the ground (both ends of the frame step)
        skate = 0.0
        for i in range(K - 1):
            if (not st[i] or not st[i + 1]) and max(zlow[i], zlow[i + 1]) < 0.01:
                skate = max(skate, hspeed(i, i + 1))
        td_speed = [hspeed(i - 1, i) for i in tds]
        lo_speed = [hspeed(i - 1, i) for i in los]
        # swings
        swings = []
        for i0 in los:
            idx = []
            i = i0
            while i < K and not st[i]:
                idx.append(i)
                i += 1
            if len(idx) < 3:
                continue
            z = zlow[idx]
            k = int(np.argmax(z))
            m = len(idx)
            mid = [z[j] for j in range(m) if 0.2 <= (j + 0.5) / m <= 0.8]
            drag = 0.0
            for a, b in zip(idx[:-1], idx[1:]):
                if max(zlow[a], zlow[b]) < 0.02:
                    drag += float(np.linalg.norm((cen[b] - cen[a])[:2]))
            swings.append(dict(frames=m, peak=float(z.max()), peak_at=round((k + 0.5) / m, 3),
                               mid_min=float(min(mid)) if mid else float(z.min()), drag_m=drag))
        stretch = solver.diag.get(leg, [0.0])
        res["legs"][leg] = dict(
            stance_slip=slip, frame_jump=jump, skate=skate,
            touchdown_speed=max(td_speed) if td_speed else None,
            liftoff_speed=max(lo_speed) if lo_speed else None,
            swing_peak=min((s["peak"] for s in swings), default=None),
            swing_peak_at=max((s["peak_at"] for s in swings), default=None),
            swing_mid_min=min((s["mid_min"] for s in swings), default=None),
            swing_drag_m=max((s["drag_m"] for s in swings), default=0.0),
            sink=float(min(0.0, zlow.min())),
            stretch=float(np.max(stretch)))
    # neck carriage: neck_1 head -> head bone head (poll), in the ground frame
    el, poll = [], []
    for f in frames:
        Gm = ground_frame(G, name, f["t"])
        a = (Gm @ f["pose"]["neck_1"])[:3, 3]
        b = (Gm @ f["pose"]["head"])[:3, 3]
        d = b - a
        el.append(math.degrees(math.atan2(d[2], math.hypot(d[0], d[1]))))
        poll.append(float(b[2]))
    res["neck_elev_mean"] = float(np.mean(el))
    res["neck_elev_range"] = [float(np.min(el)), float(np.max(el))]
    res["poll_height_mean"] = float(np.mean(poll))
    res["poll_height_range"] = [float(np.min(poll)), float(np.max(poll))]
    ev = contact_events(A, G, rig, rc, name, soles)
    for leg, e in ev.items():
        res["legs"][leg].update({"ev_" + k: v for k, v in e.items()})
    sad = np.array([(ground_frame(G, name, f["t"]) @ f["pose"]["saddle"])[:3, 3] for f in frames])
    res["saddle_z_range"] = [float(sad[:, 2].min()), float(sad[:, 2].max())]
    # pelvis (hips bone) motion in the ground frame: pitch of the bone's axis, roll of its
    # lateral axis, yaw; and the pitch against the back
    pp, pr_, py_, prel = [], [], [], []
    for f in frames:
        Gm = ground_frame(G, name, f["t"])
        M = Gm[:3, :3] @ f["pose"]["hips"][:3, :3]
        y_ = M[:, 1]
        x_ = M[:, 0]
        pp.append(math.degrees(math.atan2(y_[2], math.hypot(y_[0], y_[1]))))
        pr_.append(math.degrees(math.asin(max(-1.0, min(1.0, x_[2])))))
        py_.append(math.degrees(math.atan2(y_[0], y_[1])))
        B = f["pose"]["back"][:3, :3]
        yb = B[:, 1]
        prel.append(pp[-1] - math.degrees(math.atan2((Gm[:3, :3] @ yb)[2], math.hypot(*(Gm[:3, :3] @ yb)[:2]))))
    res["pelvis_pitch_range"] = float(np.ptp(pp))
    res["pelvis_roll_range"] = float(np.ptp(pr_))
    res["pelvis_yaw_range"] = float(np.ptp(np.unwrap(np.radians(py_))) * 180 / math.pi)
    res["pelvis_pitch_vs_back_range"] = float(np.ptp(prel))
    # hind limb joints (revision 4): femur swing against the pelvis (hip), stifle and hock
    # angles, over the clip's frames; the natural (uncapped) swing for reference
    hd = getattr(solver, "hipdiag", {})
    for leg in ("LH", "RH"):
        v = hd.get(leg)
        if v:
            A_ = np.degrees(np.array([x[:4] for x in v]))
            res["legs"][leg].update(hip_rom=float(np.ptp(A_[:, 0])), hip_rom_natural=float(np.ptp(A_[:, 1])),
                                    hip_min=float(A_[:, 0].min()), hip_max=float(A_[:, 0].max()),
                                    stifle_rom=float(np.ptp(A_[:, 2])), hock_rom=float(np.ptp(A_[:, 3])),
                                    stifle_range=[float(A_[:, 2].min()), float(A_[:, 2].max())],
                                    hock_range=[float(A_[:, 3].min()), float(A_[:, 3].max())],
                                    stifle_hock_corr=float(np.corrcoef(A_[:, 2], A_[:, 3])[0, 1]) if np.ptp(A_[:, 2]) > 0 else None,
                                    reach_miss_stance=float(max([x[4] for x in v if x[5]], default=0.0)),
                                    reach_miss_swing=float(max([x[4] for x in v if not x[5]], default=0.0)))
    res["reach_err"] = float(solver.reach_err)
    res["loop_close"] = float(max(np.abs(frames[0]["pose"][b] - frames[-1]["pose"][b]).max() for b in rig.order)) if loops else None
    return res


def contact_events(A, G, rig, rc, name, soles, win=1.0 / 30.0):
    """Sampling-independent swing-end metrics from the exact stance windows: for every
    touchdown the mean horizontal ground speed of the sole over the last `win` s before it
    (one frame at 30 fps, whatever the frame alignment) and the sole height at its start
    (the approach), and for every lift-off the same over the first `win` s after it."""
    if not hasattr(G, "stance_windows"):
        return {}
    solver = G.Solver(rig, rc)
    nf, L = G.clip_frames(name, rc)
    g = G.GAITS[name]
    loops = g["kind"] in ("cycle", "idle")

    def sole(leg, t):
        pose = solver.pose_at(name, (t % L) if loops else min(max(t, 0.0), L), L, nf)
        M = ground_frame(G, name, t) @ pose[SOLE_BONES[leg]]
        P = (M[:3, :3] @ soles[leg].T).T + M[:3, 3]
        return P.mean(0), float(P[:, 2].min())
    out = {}
    lo_t, hi_t = (0.0, L) if loops else (win, L - win)
    for leg, wins in G.stance_windows(name, rc).items():
        td, lo = [], []
        for t0, t1 in wins:
            if lo_t <= t0 < hi_t and t0 > 0.0:
                c1, _ = sole(leg, t0 + 1e-5)
                c0, z0 = sole(leg, t0 - win)
                td.append((float(np.linalg.norm((c1 - c0)[:2]) / win), z0))
            if lo_t <= t1 < hi_t:
                c0, _ = sole(leg, t1 - 1e-5)
                c1, z1 = sole(leg, t1 + win)
                lo.append((float(np.linalg.norm((c1 - c0)[:2]) / win), z1))
        out[leg] = dict(td_speed=max((v for v, _ in td), default=None),
                        td_height=min((z for _, z in td), default=None),
                        td_angle=min((math.degrees(math.atan2(z, v * win)) for v, z in td), default=None),
                        lo_speed=max((v for v, _ in lo), default=None),
                        lo_height=min((z for _, z in lo), default=None))
    return out


# ---------------------------------------------------------------------------
# Playback check: the clip as the engine plays the exported keys
# ---------------------------------------------------------------------------
def _qslerp(q0, q1, f):
    d = float(q0 @ q1)
    if d < 0:
        q1, d = -q1, -d
    if d > 0.9995:
        q = q0 + (q1 - q0) * f
        return q / np.linalg.norm(q)
    th = math.acos(d)
    return (math.sin((1 - f) * th) * q0 + math.sin(f * th) * q1) / math.sin(th)


def playback_check(A, G, rig, rest, rc, name, hz=240.0, contact=0.005):
    """Sample the clip the way the engine plays the exported glb: keys at the clip's key
    rate (gaits.key_rate), each bone's local translation interpolated linearly and its
    rotation by slerp at `hz`, forward kinematics, and the render hoof mesh
    (anatomy.hoof_mesh_detail, the mesh that is shipped). In the ground frame: the deepest
    point of any hoof below the ground (sink) and the ground speed of hoof points on the
    ground (below `contact` at both ends of a step): per step the fastest such point, as the
    median, 95th percentile and maximum over the steps with contact."""
    if not hasattr(G, "key_times"):
        return {}
    solver = G.Solver(rig, rc)
    nf, L = G.clip_frames(name, rc)
    if hasattr(solver, "hip_window"):
        solver.hip_window(name, L, nf)
    kt = G.key_times(name, rc)
    need = set()
    for b in SOLE_BONES.values():
        n = b
        while n:
            need.add(n)
            n = rig.parent[n]
    order = [n for n in rig.order if n in need]
    keys = []
    for t in kt:
        loc = rig.to_local(solver.pose_at(name, t, L, nf))
        keys.append({n: (loc[n][:3, 3].copy(), G.mat_quat(loc[n][:3, :3])) for n in order})
    verts = {}
    for leg, b in SOLE_BONES.items():
        V = A.hoof_mesh_detail("l" if leg[0] == "L" else "r", leg[1] == "H")[0]
        inv = np.linalg.inv(rest[b])
        verts[leg] = (inv @ np.c_[V, np.ones(len(V))].T).T[:, :3]
    g = G.GAITS[name]
    loops = g["kind"] in ("cycle", "idle")
    n = int(round(L * hz))
    ts = np.arange(n + (0 if loops else 1)) / hz
    dk = L / (len(kt) - 1)
    pts = {leg: [] for leg in SOLE_BONES}
    for t in ts:
        x = min(t / dk, len(kt) - 1 - 1e-9)
        i = int(math.floor(x))
        f = x - i
        k0, k1 = keys[i], keys[min(i + 1, len(kt) - 1)]
        W = {}
        for nme in order:
            p = rig.parent[nme]
            M = np.eye(4)
            M[:3, :3] = G.quat_mat(_qslerp(k0[nme][1], k1[nme][1], f))
            M[:3, 3] = k0[nme][0] * (1 - f) + k1[nme][0] * f
            W[nme] = (W[p] @ rig.rel[nme] @ M) if p else (rest[nme] @ M)
        Gm = ground_frame(G, name, float(t))
        for leg, b in SOLE_BONES.items():
            Mw = Gm @ W[b]
            pts[leg].append((Mw[:3, :3] @ verts[leg].T).T + Mw[:3, 3])
    out = {}
    for leg in SOLE_BONES:
        P = np.array(pts[leg])                        # T x N x 3
        z = P[:, :, 2]
        low = (z[1:] < contact) & (z[:-1] < contact)
        sp = np.linalg.norm(P[1:, :, :2] - P[:-1, :, :2], axis=2) * hz
        step = np.where(low, sp, 0.0).max(axis=1)
        on = low.any(axis=1)
        # drift: how far a point that stays on the ground moves from where it touched down
        drift = 0.0
        inside = z < contact
        start = np.full(z.shape[1], -1)
        for k in range(len(z)):
            new = inside[k] & (start < 0)
            start[new] = k
            live = inside[k] & (start >= 0)
            if live.any():
                d = np.linalg.norm(P[k, live, :2] - P[start[live], np.nonzero(live)[0], :2], axis=1)
                drift = max(drift, float(d.max()))
            start[~inside[k]] = -1
        out[leg] = dict(sink=float(max(0.0, -z.min())), drift=drift,
                        slide_p50=float(np.median(step[on])) if on.any() else 0.0,
                        slide_p95=float(np.percentile(step[on], 95)) if on.any() else 0.0,
                        slide_max=float(step.max()) if on.any() else 0.0)
    return dict(hz=hz, key_rate=float(G.key_rate(name)), legs=out,
                sink=max(v["sink"] for v in out.values()),
                drift=max(v["drift"] for v in out.values()),
                slide_p50=max(v["slide_p50"] for v in out.values()),
                slide_p95=max(v["slide_p95"] for v in out.values()),
                slide_max=max(v["slide_max"] for v in out.values()))


def joint_rom(A, G, rig, rc, name, hz=240.0, span=2.4):
    """Hind limb joint ranges (deg) sampled finely (exact solver poses at `hz` over up to
    `span` s): the femur against the pelvis (hip), the stifle, the hock and the fetlock
    (cannon against pastern), and the pelvis pitch against the back; max over both hind legs."""
    solver = G.Solver(rig, rc)
    nf, L = G.clip_frames(name, rc)
    if not hasattr(solver, "hip_window"):
        return {}
    solver.hip_window(name, L, nf)
    solver.hipdiag = {}
    fet = {"l": [], "r": []}
    for t in np.arange(0.0, min(L, span), 1.0 / hz):
        pose = solver.pose_at(name, float(t), L, nf)
        for s in ("l", "r"):
            a = pose["hcannon_" + s][:3, 1]
            b = pose["hpastern_" + s][:3, 1]
            fet[s].append(math.degrees(math.acos(max(-1.0, min(1.0, float(-a @ b))))))
    out = {}
    for leg, v in solver.hipdiag.items():
        A_ = np.degrees(np.array([x[:4] for x in v]))
        out[leg] = dict(hip=float(np.ptp(A_[:, 0])), stifle=float(np.ptp(A_[:, 2])), hock=float(np.ptp(A_[:, 3])),
                        fetlock=float(np.ptp(fet["l" if leg[0] == "L" else "r"])))
    return dict(legs=out, hip=max(v["hip"] for v in out.values()), stifle=max(v["stifle"] for v in out.values()),
                hock=max(v["hock"] for v in out.values()), fetlock=max(v["fetlock"] for v in out.values()))


def summarize(res):
    legs = res["legs"]

    def mx(k):
        v = [legs[l][k] for l in legs if legs[l][k] is not None]
        return max(v) if v else None

    def mn(k):
        v = [legs[l][k] for l in legs if legs[l][k] is not None]
        return min(v) if v else None
    ev = {}
    if all("ev_td_speed" in legs[l] for l in legs):
        ev = dict(td_speed_win=mx("ev_td_speed"), td_height_win=mn("ev_td_height"), td_angle_min=mn("ev_td_angle"),
                  lo_speed_win=mx("ev_lo_speed"), lo_height_win=mn("ev_lo_height"))
    return dict(ev, stance_slip=mx("stance_slip"), frame_jump=mx("frame_jump"), skate=mx("skate"),
                touchdown_speed=mx("touchdown_speed"),
                liftoff_speed=mx("liftoff_speed"), swing_peak_min=mn("swing_peak"), swing_mid_min=mn("swing_mid_min"),
                swing_drag_m=mx("swing_drag_m"), sink=mn("sink"), stretch=mx("stretch"),
                neck_elev_mean=res["neck_elev_mean"], poll_height_mean=res["poll_height_mean"])


# ---------------------------------------------------------------------------
# Jump clearance
# ---------------------------------------------------------------------------
LOW_BONES = ["hoof_l", "hoof_r", "hhoof_l", "hhoof_r", "pastern_l", "pastern_r", "hpastern_l", "hpastern_r",
             "cannon_l", "cannon_r", "hcannon_l", "hcannon_r", "radius_l", "radius_r", "tibia_l", "tibia_r"]


def jump_clearance(A, G, rig, rest, rc, rates=(0.8, 1.0, 1.2), sub=4):
    """Rail clearance of the jump. At playback rate r the horse runs at speed x rate, so
    the ground distance covered per clip second is the clip's ground speed whatever the
    rate, while the root arc scales by 1 / r^2. For a thin rail at forward distance X from
    the root's position at the clip start, every sampled point of the legs and the belly
    passes X at some moment; the rail clears when all of them are above it then.
    Returns per rate: the highest clearable rail and its X (the take-off distance the
    runtime aims for), plus the X window in which a 0.6 m rail still clears."""
    name = "jump"
    solver = G.Solver(rig, rc)
    nf, L = G.clip_frames(name, rc)
    n = (nf - 1) * sub
    v = G.ground_speed(name)
    belly = [np.array([0.0, y, z]) for y, z in ((-0.55, 0.80), (-0.3, 0.76), (0.0, 0.77), (0.3, 0.80), (0.55, 0.92))]
    tracks = {}
    for i in range(n + 1):
        t = L * i / n
        pose = solver.pose_at(name, t, L, nf)
        pts = []
        for b in LOW_BONES:
            M = pose[b]
            pts.append(M[:3, 3])
            pts.append(M[:3, 3] + M[:3, 1] * rig.len[b])
        Mb = pose["body"] @ np.linalg.inv(rig.rest["body"])
        for p in belly:
            pts.append((Mb @ np.append(p, 1.0))[:3])
        for k, p in enumerate(pts):
            tracks.setdefault(k, []).append((t, p))
    out = {}
    for r in rates:
        paths = []
        for k, tr in tracks.items():
            xs = np.array([v * t - p[1] for t, p in tr])          # forward (-y) distance on the ground
            zs = np.array([p[2] + G.root_lift(name, t, r) for t, p in tr])
            paths.append((xs, zs))
        X = np.arange(0.0, v * L, 0.05)
        clear = []
        for x in X:
            lo = 9.0
            for xs, zs in paths:
                for a in range(len(xs) - 1):
                    if (xs[a] - x) * (xs[a + 1] - x) <= 0 and xs[a] != xs[a + 1]:
                        f = (x - xs[a]) / (xs[a + 1] - xs[a])
                        lo = min(lo, zs[a] + f * (zs[a + 1] - zs[a]))
            clear.append(lo if lo < 9.0 else 0.0)
        clear = np.array(clear)
        k = int(np.argmax(clear))
        ok = X[clear >= 0.6]
        out[r] = dict(max_rail=float(clear[k]), best_x=float(X[k]), window_060=[float(ok.min()), float(ok.max())] if len(ok) else None,
                      apex_root=float(max(G.root_lift(name, t, r) for t in np.linspace(0, L, 200))))
    return out


def main():
    a = sys.argv[1:]
    tools = HERE
    clips = None
    out = None
    i = 0
    while i < len(a):
        if a[i] == "--tools":
            tools = a[i + 1]
            i += 1
        elif a[i] == "--clips":
            clips = a[i + 1].split(",")
            i += 1
        elif a[i] == "--json":
            out = a[i + 1]
            i += 1
        i += 1
    A, G = load(tools)
    rest = rest_matrices(A)
    rig = G.Rig(rest)
    rc = G.load_rider_curves()
    soles = sole_points(A, rest)
    names = clips or [c for c in G.GAITS if c != "turn_r"]
    report = {}
    print("%-11s %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s %5s" % (
        "clip", "v", "slip", "fjump", "skate", "td33", "td_r", "td_z", "lo33", "pk_min", "midmin", "drag", "sink", "strch",
        "neck", "poll"))
    for c in names:
        r = measure(A, G, rig, rest, rc, c, soles)
        s = summarize(r)
        r["summary"] = s
        report[c] = r

        def f(v, fmt="%6.3f"):
            return fmt % v if v is not None else "%6s" % "-"
        v = G.ground_speed(c) if hasattr(G, "ground_speed") else G.GAITS[c].get("speed", 0.0)
        r["ground_speed"] = v
        tdr = s["td_speed_win"] / v if s.get("td_speed_win") is not None and v > 0.5 else None
        print("%-11s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s" % (
            c, f(v, "%6.2f"), f(s["stance_slip"]), f(s["frame_jump"]), f(s["skate"], "%6.2f"),
            f(s.get("td_speed_win"), "%6.2f"), f(tdr, "%6.2f"), f(s.get("td_height_win")), f(s.get("lo_speed_win"), "%6.2f"),
            f(s["swing_peak_min"]), f(s["swing_mid_min"]), f(s["swing_drag_m"]), f(s["sink"]), f(s["stretch"], "%6.3f"),
            f(s["neck_elev_mean"], "%6.1f"), f(s["poll_height_mean"], "%5.2f")))
    if "jump" in names and hasattr(G, "root_lift"):
        jc = jump_clearance(A, G, rig, rest, rc)
        report["jump"]["clearance"] = {str(k): v for k, v in jc.items()}
        for r_, v in jc.items():
            print("jump rate %.2f: highest rail %.2f m at %.2f m from the jump start; 0.6 m rail clears for X in %s; "
                  "root apex %.2f m" % (r_, v["max_rail"], v["best_x"], v["window_060"], v["apex_root"]))
    if out:
        json.dump(report, open(out, "w"), indent=1)
        print("wrote", out)


if __name__ == "__main__":
    main()
