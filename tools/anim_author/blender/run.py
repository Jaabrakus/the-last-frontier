"""Runs a move spec: evaluate (print the quality metrics), bake (write the clip JSON), or both.
  Blender -b --factory-startup --python tools/anim_author/blender/run.py -- <move> <data dir> eval|bake [out.json]
  <data dir> holds <move's native>/move_seq.json as dumped by dump_move.gd (subfolders by native move name)."""
import sys, os, importlib, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import rigkit

A = sys.argv[sys.argv.index("--") + 1:]
move, data, action = A[0], A[1], A[2]
mod = importlib.import_module("moves." + move)
nat = (rigkit.MirrorNative if getattr(mod, "MIRROR", False) else rigkit.Native)(os.path.join(data, mod.NATIVE, "move_seq.json"), t_a=mod.SPEC["t_a"])
if action in ("eval", "both"):
    r = rigkit.evaluate(mod.SPEC, nat)
    print("EVAL", move, json.dumps(r))
    print("NATV", move, json.dumps(rigkit.evaluate(mod.SPEC, nat, native_only=True)))
if action in ("bake", "both"):
    out = A[3]
    print("BAKED", move, rigkit.bake(mod.SPEC, nat, out))
    json.dump(nat.full() if mod.SPEC["t_a"] == 0.0 else _ if False else nat.full(), open(out.replace(".json", "_native.json"), "w"))
    json.dump([(n, list(lo), list(hi), list(c)) for n, lo, hi, c in mod.SPEC["obstacles"]], open(out.replace(".json", "_obstacles.json"), "w"))
if action == "dbg":
    for tt in [float(x) for x in A[3].split(",")]:
        rots, rp = rigkit.pose_at(mod.SPEC, nat, tt)
        P, G = rigkit.SK.fk(rots, rp)
        f = lambda v: tuple(round(x, 2) for x in v)
        ht = rigkit.hand_target(mod.SPEC, nat, "l", tt)
        print("DBG t=%.2f pelvis %s spined %s head %s | l_sh %s l_el %s l_wr %s l_palm %s  target %s | L_ankle %s knee %s hip %s" % (
            tt, f(P["pelvis"]), f(P["spined"]), f(P["headb"]), f(P["l_shoulder"]), f(P["l_elbow"]), f(P["l_wrist"]), f(P["l_palm"]), f(ht),
            f(P["l_ankle"]), f(P["l_knee"]), f(P["l_upper_leg"])))
if action == "knee":
    import math
    t0, t1 = [float(x) for x in A[3].split(",")]
    side = A[4] if len(A) > 4 else "l"
    f = t0
    prev = None
    while f <= t1 + 1e-6:
        rots, rp = rigkit.pose_at(mod.SPEC, nat, f)
        P, G = rigkit.SK.fk(rots, rp)
        ang = rigkit.angle_at(P[side + "_upper_leg"], P[side + "_knee"], P[side + "_ankle"])
        tg = rigkit.foot_target(mod.SPEC, nat, side, f)
        kq = rots[side + "_knee"]
        dq = 0 if prev is None else math.degrees(prev.rotation_difference(kq if prev.dot(kq) >= 0 else -kq).angle)
        print("KNEE t=%.3f angle %.0f knee %s ankle %s target %s dq %.0f" % (f, ang, tuple(round(x, 2) for x in P[side + "_knee"]), tuple(round(x, 2) for x in P[side + "_ankle"]), tuple(round(x, 2) for x in tg), dq))
        prev = kq if prev is None or prev.dot(kq) >= 0 else -kq
        f += 1 / 30
if action == "misses":
    fps = 30
    rows = {}
    for f in range(int(round(mod.SPEC["dur"] * fps)) + 1):
        t = f / fps
        rigkit.pose_at(mod.SPEC, nat, t)
        for b, d in rigkit.MISS:
            if d > 0.03:
                rows.setdefault(b, []).append((round(t, 2), round(d, 2)))
    for b, r in rows.items():
        print("MISSES", b, "from %.2f to %.2f, worst %.2f at %.2f" % (r[0][0], r[-1][0], max(x[1] for x in r), max(r, key=lambda x: x[1])[0]))
if action == "opt":
    budget = int(A[3]) if len(A) > 3 else 600
    import time
    t0 = time.time()
    plist = mod.params(mod.SPEC)
    print("OPT parameters", len(plist))
    rigkit.optimize(mod.SPEC, nat, plist, mod.shape, budget=budget, log=lambda m: print(m, flush=True))
    path = rigkit.save_keys(mod.SPEC, mod.__file__)
    print("OPT saved", path, "in %.0f s" % (time.time() - t0))
if action == "strain":
    fr = rigkit.simulate(mod.SPEC, nat)
    rows = []
    for f in fr:
        if f["wn"] >= 0.5:
            continue
        P = f["P"]
        for s_ in ("l", "r"):
            reach = (P[s_ + "_palm"] - P[s_ + "_shoulder"]).length
            el = rigkit.angle_at(P[s_ + "_shoulder"], P[s_ + "_elbow"], P[s_ + "_wrist"])
            if reach > 0.55 or el > 163:
                rows.append((round(f["t"], 2), s_, round(reach, 2), round(el)))
    print("STRAIN", len(rows), rows[:30])
    print("STRAINMISS", [(round(f["t"], 2), b, round(d, 2)) for f in fr for b, d in f["miss"] if d > 0.04][:20])
if action == "arm":
    import math
    side = A[4] if len(A) > 4 else "r"
    t0, t1 = [float(x) for x in A[3].split(",")]
    f = t0
    prev = {}
    while f <= t1 + 1e-6:
        rots, rp = rigkit.pose_at(mod.SPEC, nat, f)
        P, G = rigkit.SK.fk(rots, rp)
        el = rigkit.angle_at(P[side + "_shoulder"], P[side + "_elbow"], P[side + "_wrist"])
        tg = rigkit.hand_target(mod.SPEC, nat, side, f)
        dq = {}
        for b in (side + "_shoulder", side + "_elbow"):
            q = rots[b]
            if b in prev:
                p0 = prev[b]
                dq[b] = round(math.degrees(p0.rotation_difference(q if p0.dot(q) >= 0 else -q).angle))
            prev[b] = q
        f3 = lambda v: tuple(round(x, 2) for x in v)
        print("ARM t=%.3f elbow %.0f palm %s target %s elbowpos %s d %s" % (f, el, f3(P[side + "_palm"]), f3(tg), f3(P[side + "_elbow"]), dq))
        f += 1 / 30
