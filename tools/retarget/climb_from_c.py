#!/usr/bin/env python3
"""Actor_C's climbing clips on the Actor_B rig (user 2026-09-27: climbing on moving giants; step 1, "move the 117 clips
from Actor_C's 29-bone skeleton onto our player").

Source: the 117 player grip / hang clips, decoded to JSON in ~/Downloads/giants_data (animations_json/player_climb/,
skeletons_json/player_climb/player_A.json, manifest.csv).

  python3 tools/retarget/climb_from_c.py --rig /tmp/actor_b_rig.json --out /tmp/climb_from_c.json \
      [--src ~/Downloads/giants_data] [--fps 30]
  Godot --headless --path . -s tools/retarget/build_library.gd -- in=/tmp/climb_from_c.json \
      out=res://animations_extra/Actor_B_from_C.res
(the rig: Godot --headless --path . -s tools/retarget/dump_rig_rest.gd -- /tmp/actor_b_rig.json)

The source data: 29 bones, two roots at the origin (Bone_KOSI, the hips, carrying the legs; Bone_HARA, the belly,
carrying the spine, neck, head and arms, as Actor_B's lower_base / upper_base), bind pose a T-pose, +Y up, facing +Z
with its left side at -X: a left-handed frame (the toes point +Z; the "_L" bones are the true left: in the hanging
attack the right hand leaves the ledge and reaches behind for the sword, as the source character is right-handed).
Rotations only (no translation keys: the climbing system places the body, from the grip).
The stored quaternions are row-vector rotations: the column-vector local rotation is the conjugate (checked on the
bind pose: conjugated, the feet stand 0.69 m under the hips, the head 0.36 m over them and the hands 0.5 m out at
shoulder height; as stored, the spine pointed down with the legs).

Retarget: per mapped bone, the source's world rotation change from its bind pose is applied to the Actor_B bone after
aligning the Actor_B rest (arms down) with the source bind (T-pose): A = F_src_bind * F_dst_rest^T, where F is the
bone's frame from its direction (to its child joint) and the forward side (world +Z, or the thumb for the hands);
world frames are mirrored on X (the source's left-handed frame into Actor_B's right-handed one; both face +Z). Then
    dst_global(t) = C * (src_global(t) * src_global_bind^T) * C^T * A * dst_global_rest,
and each mapped bone's local rotation follows from its parent's (unmapped bones stay at rest). Clips play at FPS
(30: the source's frame rate is not stored in the decoded data; 30 is the game's). A clip whose name has "loop" loops.
"""
from __future__ import annotations

import argparse
import csv
import json
import os

import numpy as np

# Actor_B bone <- Actor_C bone (per side: {s} is l / r and {S} is L / R)
MAP_CENTER = {
    "pelvis": "Bone_KOSI",
    "spinea": "Bone_HARA", "spineb": "Bone_HARA",
    "spinec": "Bone_MUNE", "spined": "Bone_MUNE",
    "neck": "Bone_KUBI",
    "heada": "Bone_KAO", "headb": "Bone_KAO",
}
MAP_SIDE = {
    "{s}_upper_leg": "Bone_MOMO_{S}", "{s}_knee": "Bone_SUNE_{S}", "{s}_ankle": "Bone_TOE_{S}", "{s}_ball": "Bone_TUMASAKI_{S}",
    "{s}_clavicle": "Bone_KATA_{S}", "{s}_shoulder": "Bone_JOWA_{S}", "{s}_elbow": "Bone_UDE_{S}", "{s}_wrist": "Bone_HAND_A_{S}",
    # the source's hand is a mitten: one two-joint finger for all four, and a two-joint thumb
    "{s}_indexa": "Bone_YUBI_A_{S}", "{s}_indexb": "Bone_YUBI_B_{S}", "{s}_indexc": "Bone_YUBI_B_{S}",
    "{s}_middlea": "Bone_YUBI_A_{S}", "{s}_middleb": "Bone_YUBI_B_{S}", "{s}_middlec": "Bone_YUBI_B_{S}",
    "{s}_ringa": "Bone_YUBI_A_{S}", "{s}_ringb": "Bone_YUBI_B_{S}", "{s}_ringc": "Bone_YUBI_B_{S}",
    "{s}_pinkyb": "Bone_YUBI_A_{S}", "{s}_pinkyc": "Bone_YUBI_B_{S}", "{s}_pinkyd": "Bone_YUBI_B_{S}",
    "{s}_thumba": "Bone_OYAYUBI_A_{S}", "{s}_thumbb": "Bone_OYAYUBI_B_{S}", "{s}_thumbc": "Bone_OYAYUBI_B_{S}",
}
# the child joint giving each bone's direction (source / Actor_B); none: the frame is taken as upright (spine, head)
SRC_CHILD = {"Bone_MOMO": "Bone_SUNE", "Bone_SUNE": "Bone_TOE", "Bone_TOE": "Bone_TUMASAKI",
             "Bone_KATA": "Bone_JOWA", "Bone_JOWA": "Bone_UDE", "Bone_UDE": "Bone_HAND_A", "Bone_HAND_A": "Bone_YUBI_A",
             "Bone_YUBI_A": "Bone_YUBI_B", "Bone_OYAYUBI_A": "Bone_OYAYUBI_B"}
DST_CHILD = {"upper_leg": "knee", "knee": "ankle", "ankle": "ball", "clavicle": "shoulder", "shoulder": "elbow",
             "elbow": "wrist", "wrist": "middlea", "indexa": "indexb", "indexb": "indexc", "middlea": "middleb",
             "middleb": "middlec", "ringa": "ringb", "ringb": "ringc", "pinkyb": "pinkyc", "pinkyc": "pinkyd",
             "thumba": "thumbb", "thumbb": "thumbc"}
C = np.diag([-1.0, 1.0, 1.0])   # the source's left-handed world into Actor_B's right-handed one: X mirrored


def qmat(q):
    x, y, z, w = q
    n = np.sqrt(x * x + y * y + z * z + w * w)
    x, y, z, w = x / n, y / n, z / n, w / n
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def mat_q(m):
    """Rotation matrix -> quaternion (x, y, z, w)."""
    t = np.trace(m)
    if t > 0:
        s = np.sqrt(t + 1.0) * 2
        w, x, y, z = 0.25 * s, (m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = np.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        w, x, y, z = (m[2, 1] - m[1, 2]) / s, 0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s
    elif m[1, 1] > m[2, 2]:
        s = np.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        w, x, y, z = (m[0, 2] - m[2, 0]) / s, (m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s
    else:
        s = np.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        w, x, y, z = (m[1, 0] - m[0, 1]) / s, (m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s
    q = np.array([x, y, z, w])
    return q / np.linalg.norm(q)


def frame(primary, secondary):
    """Orthonormal frame (columns) from a direction and a side vector."""
    x = primary / np.linalg.norm(primary)
    z = secondary - x * np.dot(secondary, x)
    if np.linalg.norm(z) < 1e-6:
        z = np.cross(x, [0.0, 1.0, 0.0]) if abs(x[1]) < 0.9 else np.cross(x, [1.0, 0.0, 0.0])
    z = z / np.linalg.norm(z)
    y = np.cross(z, x)
    return np.column_stack([x, y, z])


class Source:
    def __init__(self, root: str):
        sk = json.load(open(os.path.join(root, "skeletons_json/player_climb/player_A.json")))
        self.bones = sk["bones"]
        self.idx = {b["name"]: b["index"] for b in self.bones}
        self.parent = [b["parent_index"] for b in self.bones]
        self.bind_local = [qmat(b["bind_rotation_xyzw"]).T for b in self.bones]
        self.bind_t = [np.array(b["bind_translation_xyz"]) for b in self.bones]
        self.bind_g, self.bind_p = self.fk(self.bind_local)

    def fk(self, local):
        g, p = [None] * len(self.bones), [None] * len(self.bones)
        for i, b in enumerate(self.bones):
            pi = self.parent[i]
            if pi < 0:
                g[i], p[i] = local[i], self.bind_t[i]
            else:
                g[i], p[i] = g[pi] @ local[i], p[pi] + g[pi] @ self.bind_t[i]
        return g, p


class Rig:
    def __init__(self, path: str):
        d = json.load(open(path))
        self.bones = d["bones"]
        self.idx = {b["name"]: b["i"] for b in self.bones}
        self.parent = {b["i"]: b["parent"] for b in self.bones}
        self.rest_local = {b["i"]: qmat(b["rest_q"]) for b in self.bones}
        self.pos = {b["i"]: np.array(b["pos"]) for b in self.bones}
        self.rest_g = {}
        for b in self.bones:      # (parents come before children in the dump)
            i = b["i"]
            pi = self.parent[i]
            self.rest_g[i] = self.rest_local[i] if pi < 0 else self._g(pi) @ self.rest_local[i]

    def _g(self, i):
        if i not in self.rest_g:
            pi = self.parent[i]
            self.rest_g[i] = self.rest_local[i] if pi < 0 else self._g(pi) @ self.rest_local[i]
        return self.rest_g[i]


def mapping():
    m = dict(MAP_CENTER)
    for s, S in (("l", "L"), ("r", "R")):
        for k, v in MAP_SIDE.items():
            m[k.format(s=s)] = v.format(S=S)
    return m


def alignment(src: Source, rig: Rig, dst: str, s_name: str) -> np.ndarray:
    """A: Actor_B's rest frame of `dst` turned onto the source's bind frame of `s_name` (both in Actor_B's world)."""
    base = s_name.rsplit("_", 1)[0] if s_name.endswith(("_L", "_R")) else s_name
    side = s_name[-1] if s_name.endswith(("_L", "_R")) else ""
    dbase = dst.split("_", 1)[1] if dst[:2] in ("l_", "r_") else dst
    dside = dst[:2]
    fwd = np.array([0.0, 0.0, 1.0])
    if base in SRC_CHILD and dbase in DST_CHILD:
        si, sc = src.idx[s_name], src.idx[SRC_CHILD[base] + "_" + side]
        di, dc = rig.idx[dst], rig.idx[dside + DST_CHILD[dbase]]
        s_dir = C @ (src.bind_p[sc] - src.bind_p[si])
        d_dir = rig.pos[dc] - rig.pos[di]
        s_side, d_side = fwd, fwd
        if base == "Bone_HAND_A":        # the hand's roll: toward its thumb
            s_side = C @ (src.bind_p[src.idx["Bone_OYAYUBI_A_" + side]] - src.bind_p[si])
            d_side = rig.pos[rig.idx[dside + "thumba"]] - rig.pos[di]
        elif base in ("Bone_MOMO", "Bone_SUNE"):
            s_side, d_side = fwd, fwd
        return frame(s_dir, s_side) @ frame(d_dir, d_side).T
    if base in ("Bone_YUBI_B", "Bone_OYAYUBI_B", "Bone_TUMASAKI"):
        # (no child joint: as the joint before it)
        prev = {"Bone_YUBI_B": ("Bone_YUBI_A", {"indexb": "indexa", "indexc": "indexb", "middleb": "middlea",
                                                  "middlec": "middleb", "ringb": "ringa", "ringc": "ringb",
                                                  "pinkyc": "pinkyb", "pinkyd": "pinkyc"}),
                "Bone_OYAYUBI_B": ("Bone_OYAYUBI_A", {"thumbb": "thumba", "thumbc": "thumbb"}),
                "Bone_TUMASAKI": ("Bone_TOE", {"ball": "ankle"})}[base]
        pd = prev[1].get(dbase)
        if pd:
            return alignment(src, rig, dside + pd, prev[0] + "_" + side)
    return np.eye(3)


def retarget(src: Source, rig: Rig, clip: dict, fps: float, maps: dict, align: dict) -> dict:
    n = int(clip["pose_count"])
    tracks = {t["bone_index"]: t["quaternions_xyzw"] for t in clip["tracks"]}
    order = sorted(maps.keys(), key=lambda b: rig.idx[b])  # parents first (dump order)
    out = {b: [] for b in order}
    for f in range(n):
        local = []
        for i in range(len(src.bones)):
            ks = tracks.get(i)
            local.append(qmat(ks[min(f, len(ks) - 1)]).T if ks else src.bind_local[i])
        g, _ = src.fk(local)
        dst_g = {}
        for b in order:
            di = rig.idx[b]
            si = src.idx[maps[b]]
            delta = C @ (g[si] @ src.bind_g[si].T) @ C.T
            dst_g[di] = delta @ align[b] @ rig.rest_g[di]
        for b in order:
            di = rig.idx[b]
            # the parent's world frame: mapped (this frame's) or at rest under its own chain
            pi = rig.parent[di]
            chain = []
            while pi >= 0 and pi not in dst_g:
                chain.append(pi)
                pi = rig.parent[pi]
            pg = dst_g[pi] if pi >= 0 else np.eye(3)
            for c in reversed(chain):
                pg = pg @ rig.rest_local[c]
            loc = pg.T @ dst_g[di]
            out[b].append([round(float(v), 6) for v in mat_q(loc)])
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.expanduser("~/Downloads/giants_data"))
    ap.add_argument("--rig", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--fps", type=float, default=30.0)
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    src = Source(a.src)
    rig = Rig(a.rig)
    maps = {k: v for k, v in mapping().items() if k in rig.idx and v in src.idx}
    align = {b: alignment(src, rig, b, maps[b]) for b in maps}
    man = {}
    with open(os.path.join(a.src, "manifest.csv")) as fh:
        for row in csv.DictReader(fh):
            if row["giant_set"] == "player_climb":
                man[os.path.splitext(os.path.basename(row["name"]))[0]] = row
    clips = {}
    folder = os.path.join(a.src, "animations_json/player_climb")
    names = sorted(f[:-5] for f in os.listdir(folder) if f.endswith(".json"))
    only = [s for s in a.only.split(",") if s]
    for orig in names:
        if only and not any(o in orig for o in only):
            continue
        clip = json.load(open(os.path.join(folder, orig + ".json")))
        n = int(clip["pose_count"])
        short = orig.replace("player_A_", "")
        tr = retarget(src, rig, clip, a.fps, maps, align)
        row = man.get(orig, {})
        clips["actor_c-" + short] = {
            "length": max(n - 1, 1) / a.fps,
            "loop_mode": 1 if "loop" in short else 0,
            "tracks": {b: {"rot": ks} for b, ks in tr.items()},
            "meta": {
                "original_name": orig,
                "native_asset_id": row.get("sha256", ""),
                "source_file": row.get("name", ""),
                "disc_offset": int(row["disc_offset"]) if row.get("disc_offset") else -1,
                "sample_count": n,
                "sample_rate": a.fps,
            },
            "retarget": {"source_actor": "Actor_C", "source_clip": orig, "tool": "tools/retarget/climb_from_c.py",
                         "fps_assumed": a.fps},
        }
    data = {"fps": a.fps, "library_name": "actor_b_from_c", "source_actor": "Actor_C", "tool": "tools/retarget/climb_from_c.py",
            "clips": clips}
    with open(a.out, "w") as fh:
        json.dump(data, fh)
    print("climb_from_c: %d clips, %d bones mapped -> %s" % (len(clips), len(maps), a.out))


if __name__ == "__main__":
    main()
