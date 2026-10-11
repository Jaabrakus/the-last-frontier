"""Shared tooling for authoring traversal moves on the Actor_B rig in Blender (background): the skeleton and its forward kinematics,
two-bone IK on joint positions, the native move sequence (tools/anim_author/blender/dump_move.gd), the key-pose model, and the
quality metrics an improvement loop reads. Used by climb.py and vault.py.

Key-pose model (a SPEC dict):  the move's frame is +Z forward, +X left, +Y up. t is seconds from the start of the authored span.
  t_a, dur          the span of the move's time that is authored (the rest stays the native's)
  blend             seconds the native pose is blended in at both ends of the span (the seams)
  pelvis            [(t, (x, y, z))]                  world position of the pelvis bone
  pelvis_rot, chest_rot, head_rot   [(t, (pitch, yaw, roll))] degrees, world rotations about +X, +Y, +Z (forward lean = +pitch);
                    the head's is relative to the chest
  l_ankle, r_ankle  [(t, (x, y, z) | "native" | None)] ankle targets; None = the native's at the span's start / end, "native" = the
                    native's at that key's time
  l_hand, r_hand    [(t, (x, y, z) | "native")] palm targets (default: the native's contact paths, traversal_runtime 'track')
  *_knee_pole, *_elbow_pole   [(t, (x, y, z))] directions from the hip / shoulder toward which the joint bends
  obstacles         [(name, lo, hi, (r, g, b))] boxes (for the metrics and the preview)
"""
import bpy, sys, json, math, os, bisect
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rigmap
from mathutils import Vector, Quaternion, Euler, Matrix

SPINE = [("spinea", 0.2), ("spineb", 0.4), ("spinec", 0.7), ("spined", 1.0)]
NECK = [("neck", 0.4), ("heada", 0.75), ("headb", 1.0)]


def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def seg(keys, t):
    if t <= keys[0][0]:
        return keys[0], keys[0], 0.0
    for a, b in zip(keys, keys[1:]):
        if t <= b[0]:
            return a, b, smooth((t - a[0]) / (b[0] - a[0]))
    return keys[-1], keys[-1], 0.0


def vkey(keys, t):
    a, b, u = seg(keys, t)
    return Vector(a[1]).lerp(Vector(b[1]), u)


def qkey(keys, t, nat=None, part=None):
    """Interpolated world rotation delta. A key may be (pitch, yaw, roll) degrees, or "native" / "native@t": the native's at that time."""
    a, b, u = seg(keys, t)
    return _qval(a, nat, part).slerp(_qval(b, nat, part), u)


def _qval(k, nat, part):
    v = k[1]
    if isinstance(v, str):
        tk = float(v[7:]) if v.startswith("native@") else k[0]
        return native_delta(nat, part, tk)
    return Euler([math.radians(x) for x in v], 'XYZ').to_quaternion()


def native_delta(nat, part, t):
    """The native's world rotation delta (on the rest orientation) of the pelvis / the chest (spined) / the head (relative to the chest) at t."""
    rots = nat.rots(t)
    _, G = SK.fk(rots, None)
    d = lambda b: G[b] @ SK.grest[b].inverted()
    if part == "pelvis":
        return d("pelvis")
    if part == "chest":
        return d("spined")
    return d("spined").inverted() @ d("headb")


class Skel:
    def __init__(self):
        g = rigmap.read_glb_json()
        nodes = g["nodes"]
        self.names = [n["name"] for n in nodes]
        self.parent = {}
        for i, n in enumerate(nodes):
            for c in n.get("children", []):
                self.parent[self.names[c]] = self.names[i]
        self.rest_t = {n["name"]: Vector(n.get("translation", [0, 0, 0])) for n in nodes}
        r = {n["name"]: n.get("rotation", [0, 0, 0, 1]) for n in nodes}
        self.rest_q = {k: Quaternion((v[3], v[0], v[1], v[2])) for k, v in r.items()}
        order, seen = [], set()

        def visit(nm):
            if nm in seen:
                return
            if nm in self.parent:
                visit(self.parent[nm])
            seen.add(nm)
            order.append(nm)
        for nm in self.names:
            visit(nm)
        self.order = order
        self.grest = self.fk(dict(self.rest_q), None)[1]
        P0, _ = self.fk(dict(self.rest_q), self.rest_t["root"])
        self.pelvis_off = P0["pelvis"] - P0["root"]

    def fk(self, rots, root_pos):
        P, G = {}, {}
        for nm in self.order:
            p = self.parent.get(nm)
            t = self.rest_t[nm]
            if nm == "root" and root_pos is not None:
                t = root_pos
            if p is None:
                P[nm], G[nm] = t.copy(), rots[nm].copy()
            else:
                P[nm] = P[p] + G[p] @ t
                G[nm] = G[p] @ rots[nm]
        return P, G


SK = Skel()


class Native:
    """The native move, dumped by dump_move.gd: frames on a fixed grid in the move's time."""

    def __init__(self, path, t_a=0.0):
        d = json.load(open(path))
        self.d = d
        self.frames = d["frames"]
        self.times = [f["t"] for f in self.frames]
        self.t_a = t_a
        self.duration = d["duration"]

    def _at(self, t):
        t = max(0.0, min(self.duration, t + self.t_a))
        i = max(0, min(len(self.times) - 2, bisect.bisect_right(self.times, t) - 1))
        d = self.times[i + 1] - self.times[i]
        f = max(0.0, min(1.0, (t - self.times[i]) / d)) if d > 1e-9 else 0.0
        return i, f

    def rots(self, t):
        i, f = self._at(t)
        out = {}
        for nm in SK.names:
            a = self.frames[i]["rot"].get(nm)
            b = self.frames[i + 1]["rot"].get(nm)
            qa = Quaternion((a[3], a[0], a[1], a[2])) if a else SK.rest_q[nm]
            qb = Quaternion((b[3], b[0], b[1], b[2])) if b else SK.rest_q[nm]
            if qa.dot(qb) < 0:
                qb = -qb
            out[nm] = qa.slerp(qb, f)
        return out

    def _vec(self, getter, t):
        i, f = self._at(t)
        return Vector(getter(self.frames[i])).lerp(Vector(getter(self.frames[i + 1])), f)

    def world(self, name, t):
        return self._vec(lambda fr: fr["world"][name], t)

    def align(self, t):
        return self._vec(lambda fr: fr["align"], t)

    def ankle(self, side, t):
        i, f = self._at(t)
        res = []
        for k in (i, i + 1):
            fr = self.frames[k]
            res.append(Vector(fr["fk"][side + "_ankle"]) + Vector(fr["align"]))
        return res[0].lerp(res[1], f)

    def root_loc(self, t):
        return self._vec(lambda fr: fr["loc"]["root"], t)

    def full(self):
        """The native as a baked clip in the same format as ours: the root plus the align."""
        out = []
        for fr in self.frames:
            r = Vector(fr["loc"]["root"]) + Vector(fr["align"])
            out.append({"t": fr["t"], "root": [r.x, r.y, r.z], "rot": fr["rot"]})
        return {"fps": self.d["fps"], "length": self.duration, "t_a": 0.0, "parts": self.d["parts"], "frames": out}


MISS = []        # the IK's misses (m) of the pose last built: [(bone, distance)]


def ik2(rots, pos_root, a, b, c, target, pole):
    """Two-bone IK: bones a (upper), b (lower), c (tip joint) so that c's origin reaches `target`, b's joint bending toward `pole`."""
    P, G = SK.fk(rots, pos_root)
    pa, pb, pc = P[a], P[b], P[c]
    L1, L2 = (pb - pa).length, (pc - pb).length
    d_raw = (target - pa).length
    d = min(max(d_raw, abs(L1 - L2) + 1e-4), L1 + L2 - 1e-4)
    u = (target - pa).normalized()
    cosA = max(-1.0, min(1.0, (L1 * L1 + d * d - L2 * L2) / (2 * L1 * d)))
    A = math.acos(cosA)
    pd = pole - pa
    perp = pd - u * pd.dot(u)
    perp = perp.normalized() if perp.length > 1e-6 else Vector((0, 0, 1))
    pb_new = pa + (u * math.cos(A) + perp * math.sin(A)) * L1
    rot_a = (pb - pa).rotation_difference(pb_new - pa)
    Ga_new = rot_a @ G[a]
    Gpar = G[SK.parent[a]]
    rots[a] = Gpar.inverted() @ Ga_new
    Gb_old = Ga_new @ rots[b]
    pc_now = pb_new + Gb_old @ SK.rest_t[c]
    rot_b = (pc_now - pb_new).rotation_difference(target - pb_new)
    Gb_new = rot_b @ Gb_old
    rots[b] = Ga_new.inverted() @ Gb_new
    reach = L1 + L2
    if d_raw > reach:
        MISS.append((c, d_raw - reach))


def _frame(f, n):
    """The rotation matrix whose columns are f, n and f x n (f and n perpendicular unit vectors)."""
    return Matrix((f, n, f.cross(n))).transposed()


_HINGES = {}
## The last ik2_hinge solve's pole conditioning by its upper bone (the sine of the pole's angle off the limb's line).
COND = {}
## The bend's plane rate limit (ik2_hinge, a bake run frame by frame in time order: NOW its time in s, None outside a bake):
## a knee's or an elbow's plane turns about the limb's line at most RATE_DPS deg/s (0: no limit), so a pole keyed across the
## limb's line between two frames (the elbow flipping to the other side of the arm in one frame) swings round over a few
## frames instead; the hand and the foot still reach their places exactly. PLANES: each limb's last planes (reset for each
## clip). OFF (2026-10-11): tried at 1200 deg/s it held an elbow on its old side while the arm moved on (fire's low kick:
## the elbow flared up and out for four frames, worse than the quick drop it replaced), so it waits for a clip-by-clip pass
## (bend_clips.py --plane-rate) rather than running on every clip.
RATE_DPS = 0.0
NOW = None
PLANES = {}


def hinge(a, b, c):
    """The chain a-b-c's hinge, in a's own frame: (a's way to b, the axis b bends about, the rest's bend in radians). The
    axis is the rest pose's own bend (a's way crossed with b's way at the rest: the elbow's and the knee's natural fold), so
    rotating a's way about it by the bend angle gives b's way."""
    key = (a, b, c)
    if key not in _HINGES:
        d1 = SK.rest_t[b].normalized()
        d2 = (SK.rest_q[b] @ SK.rest_t[c]).normalized()
        h = d1.cross(d2)
        if h.length < 1e-5:
            h = d1.orthogonal()
        _HINGES[key] = (d1, h.normalized(), math.atan2(d1.cross(d2).dot(h.normalized()), d1.dot(d2)))
    return _HINGES[key]


def ik2_hinge(rots, pos_root, a, b, c, target, pole):
    """Two-bone IK as ik2 (c's origin to `target`, b's joint toward `pole`: the same joint places), with the twist decided:
    a turned so its hinge lies across the bend's plane (a's twist follows the pole, so it never flips between frames the way
    a shortest-arc turn from the rest does when the limb swings far from it), and b only folded about that hinge from its
    rest (a knee and an elbow bend, they do not twist). c's own turn is the caller's (set_global)."""
    P, G = SK.fk(rots, pos_root)
    pa = P[a]
    L1, L2 = SK.rest_t[b].length, SK.rest_t[c].length
    d_raw = (target - pa).length
    d = min(max(d_raw, abs(L1 - L2) + 1e-4), L1 + L2 - 1e-4)
    u = (target - pa).normalized()
    cosA = max(-1.0, min(1.0, (L1 * L1 + d * d - L2 * L2) / (2 * L1 * d)))
    A = math.acos(cosA)
    pd = pole - pa
    perp = pd - u * pd.dot(u)
    # (how well the pole sets the bend's plane: the sine of its angle off the limb's line; near 0 the plane is ill-defined)
    COND[a] = perp.length / max(pd.length, 1e-9)
    perp = perp.normalized() if perp.length > 1e-6 else u.orthogonal().normalized()
    n = perp.cross(u).normalized()
    d1l, hl, rest_bend = hinge(a, b, c)
    if NOW is not None and RATE_DPS > 0.0:
        # (measured in the limb's parent's frame, the pelvis's or the chest's: a body turning whole (a somersault, a roll)
        # turns its limbs' planes with it, which is no swing of the limb's own)
        gp = G[SK.parent[a]]
        gpi = gp.inverted()
        nl, ul = gpi @ n, gpi @ u
        st = PLANES.setdefault(a, {"t_cur": None, "n_cur": None, "t_prev": None, "n_prev": None})
        if st["t_cur"] != NOW:
            st["t_prev"], st["n_prev"] = st["t_cur"], st["n_cur"]
        if st["n_prev"] is not None and NOW > st["t_prev"]:
            q = st["n_prev"] - ul * st["n_prev"].dot(ul)
            if q.length > 1e-6:
                q.normalize()
                ang = math.atan2(q.cross(nl).dot(ul), q.dot(nl))
                lim = math.radians(RATE_DPS) * (NOW - st["t_prev"])
                if abs(ang) > lim:
                    nl = Quaternion(ul, math.copysign(lim, ang)) @ q
                    n = (gp @ nl).normalized()
                    perp = u.cross(n).normalized()
        st["t_cur"], st["n_cur"] = NOW, nl.copy()
    dir1 = u * math.cos(A) + perp * math.sin(A)
    pb_new = pa + dir1 * L1
    dir2 = (pa + u * d - pb_new).normalized()
    Ga_new = (_frame(dir1, n) @ _frame(d1l, hl).inverted()).to_quaternion()
    rots[a] = G[SK.parent[a]].inverted() @ Ga_new
    phi = math.atan2(dir1.cross(dir2).dot(n), dir1.dot(dir2))
    rots[b] = Quaternion(hl, phi - rest_bend) @ SK.rest_q[b]
    if d_raw > L1 + L2:
        MISS.append((c, d_raw - (L1 + L2)))


def chain(rots, pos_root, bones, d_from, d_to):
    for nm, f in bones:
        P, G = SK.fk(rots, pos_root)
        Gk = d_from.slerp(d_to, f) @ SK.grest[nm]
        rots[nm] = G[SK.parent[nm]].inverted() @ Gk


def blend_weight(spec, t):
    return max(1.0 - smooth(t / spec["blend"]), 1.0 - smooth((spec["dur"] - t) / spec["blend"]))


def pose_at(spec, nat, t, native_only=False):
    """The pose at t (s from the span's start): local rotations (Quaternions by bone) and the root's position."""
    del MISS[:]
    if native_only:
        return nat.rots(t), nat.world("pelvis", t) - SK.pelvis_off
    if spec.get("native_body"):
        return _native_body_pose(spec, nat, t)
    K = spec["keys"]
    dur, blend = spec["dur"], spec["blend"]
    rots = nat.rots(t)
    native_r = dict(rots)
    P = vkey(K["pelvis"], t)
    root_pos = P - SK.pelvis_off
    dp, dc, dh = qkey(K["pelvis_rot"], t, nat, "pelvis"), qkey(K["chest_rot"], t, nat, "chest"), qkey(K["head_rot"], t, nat, "head")
    _, G = SK.fk(rots, root_pos)
    rots["pelvis"] = G["lower_base"].inverted() @ (dp @ SK.grest["pelvis"])
    chain(rots, root_pos, SPINE, dp, dc)
    chain(rots, root_pos, NECK, dc, dc @ dh)
    for s in ("l", "r"):
        for _ in range(2):
            Pn, Gn = SK.fk(rots, root_pos)
            palm = hand_target(spec, nat, s, t)
            wrist_t = palm - (Pn[s + "_palm"] - Pn[s + "_wrist"])
            ik2(rots, root_pos, s + "_shoulder", s + "_elbow", s + "_wrist", wrist_t, Pn[s + "_shoulder"] + vkey(K[s + "_elbow_pole"], t))
    for s in ("l", "r"):
        P_, G_ = SK.fk(rots, root_pos)
        ik2(rots, root_pos, s + "_upper_leg", s + "_knee", s + "_ankle", foot_target(spec, nat, s, t), P_[s + "_upper_leg"] + vkey(K[s + "_knee_pole"], t))
    wn = blend_weight(spec, t)
    if wn > 0.5:
        del MISS[:]      # (mostly the native's pose by now: the authored pose's misses do not show)
    if wn > 0.0:
        nat_root = nat.world("pelvis", t) - SK.pelvis_off
        for nm in SK.names:
            q, qn = rots[nm], native_r[nm]
            if q.dot(qn) < 0:
                qn = -qn
            rots[nm] = q.slerp(qn, wn)
        root_pos = root_pos.lerp(nat_root, wn)
    return rots, root_pos


def _resolve(spec, nat, side, key, v, tk, end_vec):
    if v is None:
        return end_vec
    if isinstance(v, str):
        if v.startswith("native@"):
            tk = float(v[7:])
        return nat.ankle(side, tk) if key.endswith("ankle") else nat.world(side + "_hand", tk)
    return Vector(v)


def foot_target(spec, nat, s, t):
    keys = spec["keys"][s + "_ankle"]
    a, b, u = seg(keys, t)
    n0, n1 = nat.ankle(s, 0.0), nat.ankle(s, spec["dur"])
    va = _resolve(spec, nat, s, "ankle", a[1], a[0], n0 if a[0] <= 0.0 else n1)
    vb = _resolve(spec, nat, s, "ankle", b[1], b[0], n0 if b[0] <= 0.0 else n1)
    # ankle_rel: numeric keys are offsets from the pelvis where it is now (the legs hang from the hips, wherever the body goes)
    if spec.get("ankle_rel"):
        pel = nat.world("pelvis", t)
        if a[1] is not None and not isinstance(a[1], str):
            va = pel + Vector(a[1])
        if b[1] is not None and not isinstance(b[1], str):
            vb = pel + Vector(b[1])
    return va.lerp(vb, u)


def _native_body_pose(spec, nat, t):
    """The native pose (body, arms, path) with only the legs re-solved to the spec's ankle keys, blended back to the native at both ends."""
    K = spec["keys"]
    rots = nat.rots(t)
    native_r = dict(rots)
    root_pos = nat.world("pelvis", t) - SK.pelvis_off
    # arm_calm: an arm's swing pulled toward its relaxed pose (the native's own arm at the span's start and end, relative to the chest):
    # {"side", "keep" (share of the swing kept), "w": [(t, (w, 0, 0))] how much of the calming shows}
    calms = spec.get("arm_calm") or []
    for calm in (calms if isinstance(calms, list) else [calms]):
        w = max(0.0, min(1.0, vkey(calm["w"], t).x))
        if w > 0.0:
            r0, r1 = nat.rots(0.0), nat.rots(spec["dur"])
            for part in ("clavicle", "shoulder", "elbow", "wrist"):
                b = calm["side"] + "_" + part
                q_ref = r0[b].slerp(r1[b] if r1[b].dot(r0[b]) >= 0 else -r1[b], 0.5)
                q = rots[b] if rots[b].dot(q_ref) >= 0 else -rots[b]
                q_calm = q_ref.slerp(q, float(calm["keep"]))
                rots[b] = q.slerp(q_calm, w)
    for s in ("l", "r"):
        if s + "_hand" in K:
            before = {b: rots[b] for b in (s + "_shoulder", s + "_elbow")}
            for _ in range(2):
                Pn, Gn = SK.fk(rots, root_pos)
                palm = hand_target(spec, nat, s, t)
                wrist_t = palm - (Pn[s + "_palm"] - Pn[s + "_wrist"])
                ik2(rots, root_pos, s + "_shoulder", s + "_elbow", s + "_wrist", wrist_t, Pn[s + "_shoulder"] + vkey(K[s + "_elbow_pole"], t))
            # (<side>_hand_w: how much of the solved arm shows, (w, 0, 0) keys; the native's arm elsewhere, so the hand eases in and out)
            if s + "_hand_w" in K:
                w = max(0.0, min(1.0, vkey(K[s + "_hand_w"], t).x))
                for b, q0 in before.items():
                    q1 = rots[b] if rots[b].dot(q0) >= 0 else -rots[b]
                    rots[b] = q0.slerp(q1, w)
        if s + "_ankle" not in K:
            continue
        P_, G_ = SK.fk(rots, root_pos)
        ik2(rots, root_pos, s + "_upper_leg", s + "_knee", s + "_ankle", foot_target(spec, nat, s, t), P_[s + "_upper_leg"] + vkey(K[s + "_knee_pole"], t))
    wn = blend_weight(spec, t)
    if wn > 0.0:
        for nm in SK.names:
            q, qn = rots[nm], native_r[nm]
            if q.dot(qn) < 0:
                qn = -qn
            rots[nm] = q.slerp(qn, wn)
    return rots, root_pos


def hand_target(spec, nat, s, t):
    keys = spec["keys"].get(s + "_hand")
    if not keys:
        return nat.world(s + "_hand", t)
    a, b, u = seg(keys, t)
    va = _resolve(spec, nat, s, "hand", a[1], a[0], None)
    vb = _resolve(spec, nat, s, "hand", b[1], b[0], None)
    # hand_rel: numeric keys are offsets from the pelvis where it is now (a hand carried with the body); "native" keys are the
    # native's hand where it is now, so a hold blends in and out of the native's own path
    if spec.get("hand_rel"):
        pel = nat.world("pelvis", t)
        va = pel + Vector(a[1]) if not isinstance(a[1], str) else nat.world(s + "_hand", t)
        vb = pel + Vector(b[1]) if not isinstance(b[1], str) else nat.world(s + "_hand", t)
    return va.lerp(vb, u)


# ---------------------------------------------------------------- metrics ---------------------------------------------------
RADIUS = {"pelvis": 0.14, "spined": 0.13, "headb": 0.10, "l_knee": 0.08, "r_knee": 0.08, "l_ankle": 0.07, "r_ankle": 0.07,
          "l_ball": 0.05, "r_ball": 0.05, "l_elbow": 0.06, "r_elbow": 0.06}
SPEED_BONES = ["pelvis", "spinea", "spinec", "spined", "neck", "l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_upper_leg", "r_upper_leg",
               "l_knee", "r_knee"]


def _depth(p, lo, hi, r):
    lo, hi = Vector(lo) - Vector((r, r, r)), Vector(hi) + Vector((r, r, r))
    if not all(lo[i] < p[i] < hi[i] for i in range(3)):
        return 0.0
    return min(min(p[i] - lo[i], hi[i] - p[i]) for i in range(3))


def angle_at(a, b, c):
    v1, v2 = a - b, c - b
    return math.degrees(v1.angle(v2)) if v1.length > 1e-6 and v2.length > 1e-6 else 180.0


def evaluate(spec, nat, fps=30, native_only=False):
    """Quality numbers for the improvement loop. Lower is better except where noted."""
    n = int(round(spec["dur"] * fps))
    worst_pen = {}
    misses = 0.0
    miss_log = []
    prev = None
    max_speed = {}
    min_knee, max_knee, min_elb, max_elb = 999, 0, 999, 0
    pelvis_acc = 0.0
    last_p, last_v = None, None
    for f in range(n + 1):
        t = min(f / fps, spec["dur"])
        rots, rp = pose_at(spec, nat, t, native_only)
        misses = max(misses, max([d for _, d in MISS] or [0.0]))
        for b_, d_ in MISS:
            miss_log.append((round(t, 2), b_, round(d_, 2)))
        P, G = SK.fk(rots, rp)
        for name, lo, hi, _c in spec.get("obstacles", []):
            for j, r in RADIUS.items():
                dp = _depth(P[j], lo, hi, r)
                if dp > 0.01 and dp > worst_pen.get(j, (0, 0))[0]:
                    worst_pen[j] = (dp, t)
        for s in ("l", "r"):
            k = angle_at(P[s + "_upper_leg"], P[s + "_knee"], P[s + "_ankle"])
            e = angle_at(P[s + "_shoulder"], P[s + "_elbow"], P[s + "_wrist"])
            min_knee, max_knee = min(min_knee, k), max(max_knee, k)
            min_elb, max_elb = min(min_elb, e), max(max_elb, e)
        if prev is not None:
            for b in SPEED_BONES:
                q0, q1 = prev[b], rots[b]
                a = math.degrees(q0.rotation_difference(q1 if q0.dot(q1) >= 0 else -q1).angle)
                if a > max_speed.get(b, (0, 0))[0]:
                    max_speed[b] = (a, t)
        prev = rots
        p = P["pelvis"]
        if last_p is not None:
            v = (p - last_p) * fps
            if last_v is not None:
                pelvis_acc = max(pelvis_acc, (v - last_v).length * fps)
            last_v = v
        last_p = p
    top = sorted(max_speed.items(), key=lambda kv: -kv[1][0])[:3]
    return {"penetration": {k: (round(v[0], 3), round(v[1], 2)) for k, v in worst_pen.items()},
            "ik_miss_m": round(misses, 3), "ik_miss_by_bone": {b: max(d for _, bb, d in miss_log if bb == b) for b in {bb for _, bb, _ in miss_log}},
            "ik_miss_at": sorted(miss_log, key=lambda x: -x[2])[:4], "knee_deg": (round(min_knee), round(max_knee)), "elbow_deg": (round(min_elb), round(max_elb)),
            "fastest_deg_per_frame": [(b, round(v[0], 1), round(v[1], 2)) for b, v in top], "pelvis_accel_m_s2": round(pelvis_acc, 1)}


# ---------------------------------------------------------------- output ----------------------------------------------------
def bake(spec, nat, path, fps=30):
    frames = []
    for f in range(int(round(spec["dur"] * fps)) + 1):
        t = min(f / fps, spec["dur"])
        rots, rp = pose_at(spec, nat, t)
        frames.append({"t": t, "root": [rp.x, rp.y, rp.z], "rot": {k: [q.x, q.y, q.z, q.w] for k, q in rots.items()}})
    json.dump({"fps": fps, "length": spec["dur"], "t_a": spec["t_a"], "parts": nat.d["parts"], "frames": frames}, open(path, "w"))
    return len(frames)


# ---------------------------------------------------------------- mirroring -------------------------------------------------
def partner(nm):
    """The other side's bone of the same name (itself when it has none: the midline, the face's unpaired helpers)."""
    if nm.startswith("l_"):
        p = "r_" + nm[2:]
    elif nm.startswith("r_"):
        p = "l_" + nm[2:]
    else:
        return nm
    return p if p in SK.rest_t else nm


def _mq(q):
    """A world rotation reflected in the YZ plane (x -> -x): (w, x, y, z) -> (w, x, -y, -z)."""
    return Quaternion((q.w, q.x, -q.y, -q.z))


def mirror_pose(rots):
    """The left-right mirror of a pose: each bone takes its partner's world rotation delta (on the rest orientation) reflected in
    the YZ plane; the rig is symmetric at rest, so this is exact for the limbs and the midline alike."""
    _, G = SK.fk(rots, None)
    Gm, out = {}, {}
    for nm in SK.order:
        pn = partner(nm)
        delta = G[pn] @ SK.grest[pn].inverted()
        Gm[nm] = _mq(delta) @ SK.grest[nm]
        par = SK.parent.get(nm)
        out[nm] = Gm[nm] if par is None else Gm[par].inverted() @ Gm[nm]
    return out


class MirrorNative(Native):
    """The native move mirrored left-right (as if it had been authored for the other hand)."""

    def rots(self, t):
        return mirror_pose(Native.rots(self, t))

    def world(self, name, t):
        v = Native.world(self, partner(name), t)
        return Vector((-v.x, v.y, v.z))

    def align(self, t):
        v = Native.align(self, t)
        return Vector((-v.x, v.y, v.z))

    def ankle(self, side, t):
        v = Native.ankle(self, "r" if side == "l" else "l", t)
        return Vector((-v.x, v.y, v.z))

    def root_loc(self, t):
        v = Native.root_loc(self, t)
        return Vector((-v.x, v.y, v.z))

    def full(self):
        out = []
        for fr in self.frames:
            r = Vector(fr["loc"]["root"]) + Vector(fr["align"])
            full = {nm: SK.rest_q[nm] for nm in SK.names}
            full.update({nm: Quaternion((q[3], q[0], q[1], q[2])) for nm, q in fr["rot"].items()})
            rots = mirror_pose(full)
            out.append({"t": fr["t"], "root": [-r.x, r.y, r.z], "rot": {k: [q.x, q.y, q.z, q.w] for k, q in rots.items()}})
        return {"fps": self.d["fps"], "length": self.duration, "t_a": 0.0, "parts": self.d["parts"], "frames": out}


def mirror_spec(spec):
    """The same move for the other side: left and right swapped, x negated, yaw and roll negated."""
    import copy
    m = copy.deepcopy(spec)
    K = spec["keys"]
    mk = {}

    def mv(v):
        return (-v[0], v[1], v[2]) if not isinstance(v, str) and v is not None else v

    def mr(v):
        return (v[0], -v[1], -v[2]) if not isinstance(v, str) and v is not None else v
    for name, keys in K.items():
        new = name
        if name[:2] in ("l_", "r_"):
            new = partner(name)
        conv = mr if name.endswith("_rot") else mv
        mk[new] = [(k[0], conv(k[1])) for k in keys]
    m["keys"] = mk
    m["obstacles"] = [(n, (-hi[0], lo[1], lo[2]), (-lo[0], hi[1], hi[2]), c) for n, lo, hi, c in spec["obstacles"]]
    m["ties"] = [(partner(n), a, b) for n, a, b in spec.get("ties", [])]
    return m


# ---------------------------------------------------------------- optimizer -------------------------------------------------
JOINTS_SIM = ["pelvis", "spinea", "spined", "headb", "l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_palm", "r_palm", "l_upper_leg", "r_upper_leg",
              "l_knee", "r_knee", "l_ankle", "r_ankle", "l_ball", "r_ball", "l_wrist", "r_wrist"]


def simulate(spec, nat, fps=30):
    """Every frame of the authored span: rotations, the joints' positions, the IK misses."""
    frames = []
    for f in range(int(round(spec["dur"] * fps)) + 1):
        t = min(f / fps, spec["dur"])
        rots, rp = pose_at(spec, nat, t)
        miss = list(MISS)
        P, G = SK.fk(rots, rp)
        frames.append({"t": t, "rots": rots, "P": {j: P[j].copy() for j in JOINTS_SIM}, "miss": miss, "wn": blend_weight(spec, t)})
    return frames


def cost_terms(spec, frames, fps=30):
    """Scalar terms (lower is better) from the simulated frames: reach, penetration, bend limits, joint speed, jerk."""
    T = {"miss": 0.0, "pen": 0.0, "bend": 0.0, "speed": 0.0, "jerk": 0.0}
    for fr in frames:
        for _b, d in fr["miss"]:
            d *= (1.0 - fr["wn"])           # (what shows: the native pose covers the rest at the ends)
            if d > 0.02:
                T["miss"] += (d - 0.02) ** 2 * 400.0
        P = fr["P"]
        for name, lo, hi, _c in spec.get("obstacles", []):
            for j, r in RADIUS.items():
                if j in P:
                    dp = _depth(P[j], lo, hi, r)
                    if dp > 0.005:
                        T["pen"] += dp ** 2 * 600.0
        if fr["wn"] < 0.5:
            for s in ("l", "r"):
                # arms: not stretched to full length (a locked elbow, an arm dragged back behind the body)
                reach = (P[s + "_palm"] - P[s + "_shoulder"]).length
                if reach > 0.55:
                    T["bend"] += (reach - 0.55) ** 2 * 900.0
                el = angle_at(P[s + "_shoulder"], P[s + "_elbow"], P[s + "_wrist"])
                if el > 163:
                    T["bend"] += (el - 163) ** 2 * 0.08
                k = angle_at(P[s + "_upper_leg"], P[s + "_knee"], P[s + "_ankle"])
                e = angle_at(P[s + "_shoulder"], P[s + "_elbow"], P[s + "_wrist"])
                if k > 174:
                    T["bend"] += (k - 174) ** 2 * 0.3
                if k < 32:
                    T["bend"] += (32 - k) ** 2 * 0.2
                if e < 35:
                    T["bend"] += (35 - e) ** 2 * 0.2
    # self contact and the ground, every frame: the legs do not pass through each other, the elbows and hands not through the torso,
    # the feet not into the ground, the head not into an obstacle
    def seg_dist(p, a, b):
        ab = b - a
        u = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
        return (p - (a + ab * u)).length
    T["self"] = 0.0
    for fr in frames:
        if fr["wn"] >= 0.5:
            continue
        P = fr["P"]
        for j, a, b in (("l_knee", "r_upper_leg", "r_knee"), ("l_ankle", "r_knee", "r_ankle"), ("r_knee", "l_upper_leg", "l_knee"),
                        ("r_ankle", "l_knee", "l_ankle")):
            d = seg_dist(P[j], P[a], P[b])
            if d < 0.11:
                T["self"] += (0.11 - d) ** 2 * 400.0
        for s in ("l", "r"):
            for j in (s + "_elbow", s + "_palm"):
                d = seg_dist(P[j], P["pelvis"], P["spined"])
                if d < 0.13:
                    T["self"] += (0.13 - d) ** 2 * 400.0
            for j in (s + "_ankle", s + "_ball"):
                if P[j].y < (0.06 if j.endswith("ankle") else 0.0):
                    T["self"] += ((0.06 if j.endswith("ankle") else 0.0) - P[j].y) ** 2 * 800.0
        for name, lo, hi, _c in spec.get("obstacles", []):
            dp = _depth(P["headb"], lo, hi, 0.12)
            if dp > 0.0:
                T["self"] += dp ** 2 * 600.0
    prev = None
    worst = {}
    for fr in frames:
        if prev is not None:
            for b in SPEED_BONES:
                q0, q1 = prev[b], fr["rots"][b]
                a = math.degrees(q0.rotation_difference(q1 if q0.dot(q1) >= 0 else -q1).angle)
                worst[b] = max(worst.get(b, 0.0), a)
        prev = fr["rots"]
    for b, a in worst.items():
        if a > 22.0:
            T["speed"] += (a - 22.0) ** 2 * 0.05
    # a foot on the ground does not slide
    for i in range(1, len(frames)):
        if frames[i]["wn"] > 0.5:
            continue
        for j in ("l_ankle", "r_ankle"):
            a, b = frames[i - 1]["P"][j], frames[i]["P"][j]
            if a.y < 0.14 and b.y < 0.14:
                v = math.hypot(b.x - a.x, b.z - a.z) * fps
                if v > 0.3:
                    T["slide"] = T.get("slide", 0.0) + (v - 0.3) ** 2 * 6.0
    for i in range(1, len(frames) - 1):
        a = frames[i - 1]["P"]["pelvis"] - 2 * frames[i]["P"]["pelvis"] + frames[i + 1]["P"]["pelvis"]
        T["jerk"] += a.length_squared * 400.0
        for j in ("l_ankle", "r_ankle", "l_palm", "r_palm"):
            aa = frames[i - 1]["P"][j] - 2 * frames[i]["P"][j] + frames[i + 1]["P"][j]
            T["jerk"] += aa.length_squared * 60.0
    return T


def get_param(spec, p):
    name, idx, comp = p[0], p[1], p[2]
    return spec["keys"][name][idx][1][comp]


def set_param(spec, p, v):
    name, idx, comp = p[0], p[1], p[2]
    k = spec["keys"][name][idx]
    val = list(k[1])
    val[comp] = v
    spec["keys"][name][idx] = (k[0], tuple(val))


def optimize(spec, nat, params, shape_fn, budget=600, log=print):
    """Derivative-free coordinate search over the key parameters `params` [(key name, key index, component, step, lo, hi)]."""
    import random, copy
    random.seed(7)
    steps = [p[3] for p in params]
    base = [get_param(spec, p) for p in params]

    def total(sp):
        for name, a, b in sp.get("ties", []):        # (a planted hand keeps one place while planted)
            sp["keys"][name][b] = (sp["keys"][name][b][0], sp["keys"][name][a][1])
        fr = simulate(sp, nat)
        T = cost_terms(sp, fr)
        T["shape"] = shape_fn(sp, fr) if shape_fn else 0.0
        reg = sum(((get_param(sp, p) - base[i]) / max(p[3] * 4, 1e-6)) ** 2 for i, p in enumerate(params)) * 0.15
        T["reg"] = reg
        return sum(T.values()), T

    best, T0 = total(spec)
    log("OPT start cost %.2f %s" % (best, {k: round(v, 2) for k, v in T0.items()}))
    evals, sweep = 1, 0
    while evals < budget:
        improved = 0
        order = list(range(len(params)))
        random.shuffle(order)
        for i in order:
            if evals >= budget:
                break
            p = params[i]
            cur = get_param(spec, p)
            for sgn in (1.0, -1.0):
                v = min(max(cur + sgn * steps[i], p[4]), p[5])
                if abs(v - cur) < 1e-9:
                    continue
                set_param(spec, p, v)
                c, _ = total(spec)
                evals += 1
                if c < best - 1e-6:
                    best, cur = c, v
                    improved += 1
                    break
                set_param(spec, p, cur)
        sweep += 1
        log("OPT sweep %d evals %d cost %.2f improved %d" % (sweep, evals, best, improved))
        if improved < max(1, len(params) // 12):
            steps = [st * 0.6 for st in steps]
            if max(steps[i] / params[i][3] for i in range(len(params))) < 0.12:
                break
    c, T = total(spec)
    log("OPT end cost %.2f %s evals %d" % (c, {k: round(v, 2) for k, v in T.items()}, evals))
    return spec


def load_keys(spec, module_file):
    """Replace the spec's keys with <module>_keys.json (written by the optimizer) when it exists."""
    path = os.path.splitext(module_file)[0] + "_keys.json"
    if os.path.exists(path):
        d = json.load(open(path))
        spec["keys"] = {k: [(t, tuple(v) if isinstance(v, list) else v) for t, v in lst] for k, lst in d.items()}
    return spec


def save_keys(spec, module_file):
    path = os.path.splitext(module_file)[0] + "_keys.json"
    json.dump({k: [[t, list(v) if isinstance(v, tuple) else v] for t, v in lst] for k, lst in spec["keys"].items()}, open(path, "w"), indent=1)
    return path


def param_list(spec, wanted):
    """wanted: [(key name, [times], [components], step, radius)] -> the optimizer's parameters for the keys that are numeric vectors."""
    out = []
    for name, times, comps, step, radius in wanted:
        for i, (t, v) in enumerate(spec["keys"][name]):
            if isinstance(v, str) or v is None or not any(abs(t - tt) < 1e-6 for tt in times):
                continue
            for c in comps:
                out.append((name, i, c, step, v[c] - radius, v[c] + radius))
    return out
