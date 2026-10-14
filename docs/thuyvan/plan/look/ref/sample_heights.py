"""Sample the T4 R1 bake (read-only) at the vista's points, for vista_spec.md."""
import json
import os
import numpy as np

B = "/Users/kiwimango/Downloads/Frontier/.claude/worktrees/wf_c7a79ae5-f5c-6/tools/environment/terrain/build_regions/r1"
H = {}
for c in os.listdir(B):
    p = os.path.join(B, c, "height.bin")
    if os.path.exists(p):
        m = json.load(open(os.path.join(B, c, "meta.json")))
        H[c] = (np.fromfile(p, dtype=np.float32).reshape(833, 833), m["origin"])


def h(x, z):
    for c, (a, o) in H.items():
        i, j = x - o[0] + 416, z - o[1] + 416
        if 0 <= i <= 832 and 0 <= j <= 832:
            return float(a[int(round(j)), int(round(i))])
    return None


# sanity: orientation (row = z, col = x?) check on the C1 river: the bed should be low at x=820, z=-1300
for name, (x, z) in {
    "river C1 silent centre": (830, -1300), "C1 x=700 z=-1300": (700, -1300), "C1 x=950 z=-1300": (950, -1300),
    "village": (0, -1248), "clan_house": (60, -1330), "rope_rite_cliff": (-150, -1450),
    "village_paddies top": (80, -1150), "waystones": (-832, -1400), "two_heights_bridge": (-832, -460),
    "shrine_house": (100, -500), "ferry": (780, -150), "torrent B2": (0, -400), "survey_camp": (650, -1000),
    "cordon": (800, -1080), "gallery_mouth": (955, -1250), "burial_cairns": (700, -1580),
    "east rim 1050,-1000": (1050, -1000), "east rim 1100,-1150": (1100, -1150), "east 1150,-900": (1150, -900),
    "B1/C1 lip 520,-1250": (520, -1250), "C2 west 600,-700": (600, -700), "C2 900,-700": (900, -700),
}.items():
    print("%-28s x=%6d z=%6d  h=%s" % (name, x, z, None if h(x, z) is None else round(h(x, z), 1)))

for z in (-1400, -1300, -1180, -1050, -900):
    row = [(x, h(x, z)) for x in range(400, 1250, 25)]
    print("z=%d:" % z, " ".join("%d:%.0f" % (x, v) for x, v in row if v is not None))
for x in (-832, -700, -950):
    col = [(z, h(x, z)) for z in range(-700, -250, 25)]
    print("x=%d:" % x, " ".join("%d:%.0f" % (z, v) for z, v in col if v is not None))
