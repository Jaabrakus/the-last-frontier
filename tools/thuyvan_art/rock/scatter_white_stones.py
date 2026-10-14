"""Thủy Vân ROCK kit: the Đá Trắng white-stone scatter for C1 (vista_spec D16; plain python3 + numpy, deterministic).

    python3 tools/thuyvan_art/rock/scatter_white_stones.py [--bake <build_regions/r1>] [--out assets/thuyvan/rock]

About 400 of the kit's 12 white stones (white_stones.glb, nodes white_stone_00..11) along the main channel's bed and
banks in C1, z -1500 to -1000 (the silent reach and the cordon below it), in groups strung along the flow: small
stones everywhere, the 1-3 m ones where the bed steps. About 20% sit just under the surface (their tops 0.1-0.6 m
below the water's level), so the still state shows "white stones visible beneath stopped water" (bible L03).

Inputs (read only):
    docs/thuyvan/plan/phase1/r1_layout.final.json   channel 'main' nodes [x, z, half_width, level, flow_scale]
    <bake>/<cell>/height.bin + meta.json             the T4 ground (833 x 833 float32 per 832 m square, 1 m)
    assets/thuyvan/rock/rock_kit.json                the stones' sizes (written by rock_kit.py / rock_render.py)

Writes <out>/white_stones_c1.json: {"stones": [{"node": "white_stone_07", "pos": [x, y, z], "yaw_deg", "scale",
"under": bool}], ...} in Godot world coordinates (x east, y up, z south). pos is the stone's origin, which the kit
puts on the ground line (25% of the stone sunk), so the ground height is used as is.
"""

import argparse
import json
import math
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
LAYOUT = os.path.join(REPO, "docs", "thuyvan", "plan", "phase1", "r1_layout.final.json")
BAKE_DEFAULT = os.path.join(REPO, "tools", "environment", "terrain", "build_regions", "r1")


class Ground:
    def __init__(self, bake):
        self.cells = []
        for c in sorted(os.listdir(bake)):
            p = os.path.join(bake, c, "height.bin")
            if os.path.exists(p):
                m = json.load(open(os.path.join(bake, c, "meta.json")))
                n = int(m.get("N", 833))
                self.cells.append((np.fromfile(p, dtype=np.float32).reshape(n, n), m["origin"], n // 2))
        if not self.cells:
            raise SystemExit("no height.bin under %s (bake R1 with tv/T4's bake_region.py first)" % bake)

    def h(self, x, z):
        """Bilinear ground height at world (x, z), or None outside the bake."""
        for a, o, half in self.cells:
            i, j = x - o[0] + half, z - o[1] + half
            if 0 <= i < a.shape[1] - 1 and 0 <= j < a.shape[0] - 1:
                i0, j0 = int(i), int(j)
                fi, fj = i - i0, j - j0
                return float(a[j0, i0] * (1 - fi) * (1 - fj) + a[j0, i0 + 1] * fi * (1 - fj) +
                             a[j0 + 1, i0] * (1 - fi) * fj + a[j0 + 1, i0 + 1] * fi * fj)
        return None


def channel_at(nodes, z):
    """Interpolated (x, half_width, level) on the z-monotonic channel, plus the flow direction (dx, dz)."""
    zs = np.array([n[1] for n in nodes])
    k = int(np.clip(np.searchsorted(zs, z) - 1, 0, len(nodes) - 2))
    a, b = nodes[k], nodes[k + 1]
    t = (z - a[1]) / (b[1] - a[1])
    x = a[0] + t * (b[0] - a[0])
    hw = a[2] + t * (b[2] - a[2])
    lv = a[3] + t * (b[3] - a[3])
    d = np.array([b[0] - a[0], b[1] - a[1]], float)
    return x, hw, lv, d / np.linalg.norm(d)


def stone_sizes(kit_json):
    """node -> (length, height) in metres, from rock_kit.json (fallback: the kit's nominal lengths)."""
    L = [0.3, 0.4, 0.5, 0.65, 0.8, 1.0, 1.2, 1.5, 1.8, 2.2, 2.6, 3.0]
    out = {"white_stone_%02d" % i: (l, l * 0.5 * 0.5) for i, l in enumerate(L)}
    if os.path.exists(kit_json):
        meta = json.load(open(kit_json))
        for nd in meta.get("pieces", {}).get("white_stones", {}).get("nodes", []):
            s = nd["size"]
            out[nd["name"]] = (max(s["x"][1] - s["x"][0], s["z"][1] - s["z"][0]), s["y"][1])
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bake", default=BAKE_DEFAULT)
    ap.add_argument("--layout", default=LAYOUT)
    ap.add_argument("--out", default=os.path.join(REPO, "assets", "thuyvan", "rock"))
    ap.add_argument("--count", type=int, default=400)
    ap.add_argument("--z-from", type=float, default=-1500.0)
    ap.add_argument("--z-to", type=float, default=-1000.0)
    ap.add_argument("--seed", type=int, default=1603)
    a = ap.parse_args()
    lay = json.load(open(a.layout))
    nodes = next(c for c in lay["channels"] if c["id"] == "main")["nodes"]
    g = Ground(a.bake)
    sizes = stone_sizes(os.path.join(a.out, "rock_kit.json"))
    names = sorted(sizes)
    small = [n for n in names if sizes[n][0] < 1.0]
    big = [n for n in names if sizes[n][0] >= 1.0]
    rng = np.random.default_rng(a.seed)
    stones = []
    n_under = 0
    tries = 0
    while len(stones) < a.count and tries < a.count * 60:
        tries += 1
        # a group seed along the reach; the group strings 3-12 stones down the flow line
        z0 = rng.uniform(a.z_from, a.z_to)
        cx, hw, lv, fd = channel_at(nodes, z0)
        side = rng.uniform(-1.0, 1.0)
        lat = side * (hw + rng.uniform(0.0, 7.0))           # the bed and the low banks
        nrm = np.array([-fd[1], fd[0]])
        p0 = np.array([cx, z0]) + nrm * lat
        # the bed steps where the ground falls fast along the flow: big stones gather there
        h0, h1 = g.h(*(p0 - fd * 6)), g.h(*(p0 + fd * 6))
        if h0 is None or h1 is None:
            continue
        step = abs(h0 - h1) / 12.0
        n_in = int(rng.integers(3, 13))
        for k in range(n_in):
            if len(stones) >= a.count:
                break
            q = p0 + fd * (k * rng.uniform(1.2, 3.5)) + nrm * rng.normal(0, 1.4)
            gy = g.h(q[0], q[1])
            if gy is None:
                continue
            _, _, lvq, _ = channel_at(nodes, q[1])
            if gy > lvq + 3.0:                                # stays on the bed and the low banks
                continue
            pick_big = rng.random() < (0.12 + min(step * 3.0, 0.45))
            node = str(rng.choice(big if pick_big else small))
            L, H = sizes[node]
            sc = float(rng.uniform(0.85, 1.25))
            top = gy + H * sc
            under = top < lvq
            # about 20% just under the surface (tops 0.1-0.6 m below the level); deeper ones would never be seen
            if under:
                if not (lvq - 0.6 <= top <= lvq - 0.1) or n_under >= int(0.2 * a.count):
                    continue
                n_under += 1
            yaw = math.degrees(math.atan2(fd[0], fd[1])) + rng.normal(0, 18)
            stones.append({"node": node, "pos": [round(float(q[0]), 2), round(gy, 2), round(float(q[1]), 2)],
                           "yaw_deg": round(float(yaw), 1), "scale": round(sc, 3), "under": bool(under)})
    out = {
        "_about": "Đá Trắng white stones in C1 (tools/thuyvan_art/rock/scatter_white_stones.py, seed %d). Godot world "
                  "frame; pos = the stone's origin on the ground; node = a mesh in white_stones.glb (or its _lod1); "
                  "under = the top sits 0.1-0.6 m below the water (kept visible by the river shader's depth alpha)."
                  % a.seed,
        "z_range": [a.z_from, a.z_to], "count": len(stones), "under": sum(s["under"] for s in stones),
        "by_node": {n: sum(1 for s in stones if s["node"] == n) for n in names},
        "stones": stones,
    }
    os.makedirs(a.out, exist_ok=True)
    json.dump(out, open(os.path.join(a.out, "white_stones_c1.json"), "w"), indent=1, ensure_ascii=False)
    print("WHITE_STONES count %d under %d (%.0f%%) big %d" % (
        len(stones), out["under"], 100.0 * out["under"] / max(len(stones), 1), sum(1 for s in stones
                                                                                  if s["node"] in big)))


if __name__ == "__main__":
    main()
