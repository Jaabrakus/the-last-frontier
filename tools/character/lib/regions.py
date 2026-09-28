"""Body regions (hide mask ids) and hair zones.

Every body, garment and hair vertex carries a region code in UV2.x (glTF TEXCOORD_1 U):
    code = region + 64 * zone
region 0..63 selects one bit of the material's `uniform uvec2 hide_mask` (bit r of x for
r < 32, bit r - 32 of y otherwise); the vertex shader collapses hidden vertices, so
covered skin and covered inner garment layers are never drawn and cast no shadow
(design §4). zone (0..3) selects the material zone of a surface (fabric, colour).
Each triangle lies in exactly one region: region borders are split (the glTF exporter
duplicates vertices where the per-loop Region UV changes), so a hidden region collapses
whole triangles and never stretches a triangle to the origin.

The body is cut along clean planes at the borders (cut_borders) before the region of
each triangle is taken from its centroid (classify_faces), so the borders are straight
(within BISECT_TOL) instead of following the remeshed triangles.

Region ids are stable save/catalog data: never renumber, only append.
"""

import math

import bmesh
import numpy as np

from .sdf import log, nrm, peval, v3

# id -> name. 38 body regions (design §4.1), hair zones 48..52; the rest is reserved.
REGION_LIST = [
    "head", "neck_upper", "neck_lower",
    "chest_upper_front", "chest_upper_side", "chest_upper_back",
    "chest_front", "chest_side", "chest_back",
    "abdomen_front", "abdomen_side", "abdomen_back",
    "pelvis_center", "pelvis_side",
    "upper_arm_l", "forearm_a_l", "forearm_b_l", "forearm_c_l", "wrist_l", "hand_l",
    "upper_arm_r", "forearm_a_r", "forearm_b_r", "forearm_c_r", "wrist_r", "hand_r",
    "thigh_upper_l", "thigh_lower_l", "shin_upper_l", "shin_lower_l", "ankle_l", "foot_l",
    "thigh_upper_r", "thigh_lower_r", "shin_upper_r", "shin_lower_r", "ankle_r", "foot_r",
]
REGIONS = {n: i for i, n in enumerate(REGION_LIST)}
HAIR_ZONES = {"crown": 48, "sides": 49, "back": 50, "queue": 51, "lock": 52}
REGIONS.update({"hair_" + k: v for k, v in HAIR_ZONES.items()})
REGION_NAMES = {v: k for k, v in REGIONS.items()}

# Region groups (layer overrides, deform limits, weathering; design §5.2).
REGION_GROUPS = ["head", "neck", "torso_upper", "torso_lower", "hips", "arms_upper", "arms_lower", "hands",
                 "thighs", "shins", "feet", "hair"]


def region_group(name):
    if name == "head":
        return "head"
    if name.startswith("neck"):
        return "neck"
    if name.startswith("chest"):
        return "torso_upper"
    if name.startswith("abdomen"):
        return "torso_lower"
    if name.startswith("pelvis"):
        return "hips"
    if name.startswith("upper_arm"):
        return "arms_upper"
    if name.startswith(("forearm", "wrist")):
        return "arms_lower"
    if name.startswith("hand"):
        return "hands"
    if name.startswith("thigh"):
        return "thighs"
    if name.startswith(("shin", "ankle")):
        return "shins"
    if name.startswith("foot"):
        return "feet"
    if name.startswith("hair"):
        return "hair"
    raise KeyError(name)


# How weathered (sun, wind) each region is when visible: the skin shader darkens and
# reddens these relative to the torso (design §10.1).
WEATHER = {"head": 1.0, "neck_upper": 0.85, "neck_lower": 0.55, "hand_l": 1.0, "hand_r": 1.0,
           "wrist_l": 0.85, "wrist_r": 0.85, "forearm_c_l": 0.75, "forearm_c_r": 0.75,
           "forearm_b_l": 0.6, "forearm_b_r": 0.6, "forearm_a_l": 0.45, "forearm_a_r": 0.45}


def encode(region, zone=0):
    """UV2.x code of a region (name or id) and zone."""
    r = REGIONS[region] if isinstance(region, str) else int(region)
    assert 0 <= r < 64 and 0 <= zone < 4
    return r + 64 * zone


def mask_bits(names):
    """[lo, hi] 32-bit halves of the hide mask for a list of region names (uvec2)."""
    lo = hi = 0
    for n in names:
        r = REGIONS[n]
        if r < 32:
            lo |= 1 << r
        else:
            hi |= 1 << (r - 32)
    return [lo, hi]


def regions_json():
    """Table for sidecars / the runtime."""
    return {"ids": {n: REGIONS[n] for n in REGION_LIST}, "hair_zones": HAIR_ZONES,
            "groups": {n: region_group(n) for n in REGION_LIST}, "weather": WEATHER,
            "encoding": "UV2.x = region + 64 * zone (exact integer); hide_mask uvec2: bit r of x (r < 32) or of y (r - 32)"}


# ---------------------------------------------------------------------------
# Body border geometry (Blender space, bind pose)
# ---------------------------------------------------------------------------
NECK_SPLIT_Z = 1.333         # neck_upper / neck_lower (was 1.345: the head seam ring is at 1.348 at the front, the cut sliced the 1-5 mm bridge strip: a hairline groove)
NECK_BOTTOM_Z = 1.27         # neck_lower / chest_upper
NECK_X = 0.075               # half width of the neck column below the jaw
TORSO_BANDS = (1.18, 1.03, 0.93)   # chest_upper / chest / abdomen / pelvis
FRONT_DEG, BACK_DEG = 40.0, 120.0  # front < 40 deg around the spine < side < 120 deg < back
PELVIS_X = 0.10              # pelvis_center |x| < 0.10 (the breechcloth), pelvis_side outside
ARM_T = (0.0, 0.5, 0.78, 0.90, 1.0)    # elbow -> wrist: upper_arm | a | b | c | wrist | hand
THIGH_T = 0.3                # hip -> knee: thigh_upper | thigh_lower
SHIN_T = (0.12, 0.55, 0.85)  # knee -> ankle: thigh_lower (knee) | shin_upper | shin_lower | ankle
FOOT_Z = 0.075               # ankle | foot
BISECT_TOL = 0.002           # m: vertices this close to a cut plane are taken as on it


def _seg_t(P, a, b):
    ab = b - a
    return ((P - a) @ ab) / (ab @ ab)


def group_labels(P, groups):
    """Nearest body group (torso, neck, head, arm_l, hand_l, leg_l, foot_l, ...) of points."""
    labels = list(groups)
    D = np.stack([peval(groups[g], P) for g in labels], 1)
    return np.array(labels, dtype=object)[np.argmin(D, 1)]


def _neckish(C, lab):
    X, Z = C[:, 0], C[:, 2]
    near = np.isin(lab, ["neck", "torso", "head"]) & (Z > NECK_BOTTOM_Z) & (np.abs(X) < NECK_X)
    return near | ((lab == "neck") & (Z > NECK_BOTTOM_Z))


def classify_faces(C, lab, K):
    """Region name per face from its centroid C (n, 3) and body group label."""
    X, Y, Z = C[:, 0], C[:, 1], C[:, 2]
    reg = np.array(["head"] * len(C), dtype=object)
    neck = _neckish(C, lab) & (lab != "head")
    reg[neck & (Z > NECK_SPLIT_Z)] = "neck_upper"
    reg[neck & (Z <= NECK_SPLIT_Z)] = "neck_lower"
    tor = ((lab == "torso") | (lab == "neck")) & ~neck
    yc = K["spineb"][1]
    ang = np.degrees(np.arctan2(np.abs(X), -(Y - yc)))
    face = np.where(ang < FRONT_DEG, "front", np.where(ang < BACK_DEG, "side", "back"))
    z0, z1, z2 = TORSO_BANDS
    for lo, hi, name in ((z0, 9.0, "chest_upper"), (z1, z0, "chest"), (z2, z1, "abdomen")):
        m = tor & (Z > lo) & (Z <= hi)
        reg[m] = np.char.add(name + "_", face[m].astype(str)).astype(object)
    m = tor & (Z <= z2)
    reg[m & (np.abs(X) < PELVIS_X)] = "pelvis_center"
    reg[m & (np.abs(X) >= PELVIS_X)] = "pelvis_side"
    for s, sd in ((1, "l"), (-1, "r")):
        m = (lab == "arm_" + sd) | (lab == "hand_" + sd)
        t = _seg_t(C, K.side("elbow", s), K.side("wrist", s))
        names = ["upper_arm", "forearm_a", "forearm_b", "forearm_c", "wrist", "hand"]
        idx = np.searchsorted(np.array(ARM_T), t, side="left")      # t <= 0 -> 0, (0, .5] -> 1 ...
        for k, n in enumerate(names):
            reg[m & (idx == k)] = n + "_" + sd
        m = (lab == "leg_" + sd) | (lab == "foot_" + sd)
        th = _seg_t(C, K.side("upper_leg", s), K.side("knee", s))
        sh = _seg_t(C, K.side("knee", s), K.side("ankle", s))
        r = np.where(th <= THIGH_T, "thigh_upper", "thigh_lower").astype(object)
        r[sh > SHIN_T[0]] = "shin_upper"
        r[sh > SHIN_T[1]] = "shin_lower"
        r[sh > SHIN_T[2]] = "ankle"
        r[Z < FOOT_Z] = "foot"
        reg[m] = np.char.add(r[m].astype(str), "_" + sd).astype(object)
    return reg


def border_planes(K):
    """[(name, point, normal, selector(C, lab) -> bool mask)] of the planar region borders."""
    out = []
    def lab_in(*names):
        return lambda C, lab: np.isin(lab, names)
    near_neck = lambda C, lab: np.isin(lab, ["neck", "torso"]) & (np.abs(C[:, 0]) < 0.10) & (C[:, 2] > 1.20) & (C[:, 2] < 1.40)
    out.append(("neck_split", v3(0, 0, NECK_SPLIT_Z), v3(0, 0, 1), near_neck))
    out.append(("neck_bottom", v3(0, 0, NECK_BOTTOM_Z), v3(0, 0, 1), near_neck))
    for s in (1, -1):
        out.append(("neck_side", v3(s * NECK_X, 0, 0), v3(1, 0, 0),
                    lambda C, lab, s=s: (lab == "torso") & (C[:, 2] > NECK_BOTTOM_Z - 0.01) & (C[:, 2] < 1.40) & (C[:, 0] * s > 0)))
    torso = lambda C, lab: ((lab == "torso") | (lab == "neck")) & ~_neckish(C, lab)
    for z in TORSO_BANDS:
        out.append(("band_%.2f" % z, v3(0, 0, z), v3(0, 0, 1), torso))
    yc = K["spineb"][1]
    for s in (1, -1):
        for a in (FRONT_DEG, BACK_DEG):
            r = math.radians(a)
            n = v3(-math.cos(r), -s * math.sin(r), 0.0)
            out.append(("angle_%d" % a, v3(0, yc, 0), n,
                        lambda C, lab, s=s: torso(C, lab) & (C[:, 2] > TORSO_BANDS[2] - 0.02) & (C[:, 0] * s > 0.002)))
        out.append(("pelvis_x", v3(s * PELVIS_X, 0, 0), v3(1, 0, 0),
                    lambda C, lab, s=s: torso(C, lab) & (C[:, 2] < TORSO_BANDS[2] + 0.02) & (C[:, 0] * s > 0)))
    for s, sd in ((1, "l"), (-1, "r")):
        E, W = K.side("elbow", s), K.side("wrist", s)
        for t in ARM_T:
            out.append(("arm_%.2f" % t, E + (W - E) * t, nrm(W - E), lab_in("arm_" + sd, "hand_" + sd)))
        H, Kn, A = K.side("upper_leg", s), K.side("knee", s), K.side("ankle", s)
        out.append(("thigh", H + (Kn - H) * THIGH_T, nrm(Kn - H), lab_in("leg_" + sd, "foot_" + sd)))
        for t in SHIN_T:
            out.append(("shin_%.2f" % t, Kn + (A - Kn) * t, nrm(A - Kn), lab_in("leg_" + sd, "foot_" + sd)))
        out.append(("foot", v3(0, 0, FOOT_Z), v3(0, 0, 1), lab_in("leg_" + sd, "foot_" + sd)))
    return out


def _face_centroids(bm):
    return np.array([f.calc_center_median() for f in bm.faces], float)


def cut_planes(ob, planes, labeler, tol=BISECT_TOL):
    """Cuts the mesh of `ob` along each plane, only through the faces its selector picks
    (labeler(C) gives the group label of centroids). Then triangulates. Returns the
    number of cuts made."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    n0 = len(bm.verts)
    for name, p, n, sel in planes:
        bm.faces.ensure_lookup_table()
        C = _face_centroids(bm)
        pick = sel(C, labeler(C))
        faces = [f for f, k in zip(bm.faces, pick) if k]
        if not faces:
            continue
        verts = {v for f in faces for v in f.verts}
        edges = {e for f in faces for e in f.edges}
        bmesh.ops.bisect_plane(bm, geom=list(verts) + list(edges) + faces, dist=tol,
                               plane_co=tuple(p), plane_no=tuple(n), clear_inner=False, clear_outer=False)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    added = len(bm.verts) - n0
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return added


def cut_borders(ob, K, groups):
    """Clean planar region borders on a body mesh (see border_planes)."""
    added = cut_planes(ob, border_planes(K), lambda C: group_labels(C, groups))
    log("  region borders cut: +%d verts" % added)
    return added


def face_regions(ob, K, groups):
    """(region name per polygon, group label per polygon) of a body mesh."""
    me = ob.data
    C = np.array([p.center for p in me.polygons], float)
    lab = group_labels(C, groups)
    return classify_faces(C, lab, K), lab


def write_region_uv(ob, codes_per_poly, name="Region", h_per_loop=None):
    """Per-loop UV layer `name`: u = code of the loop's polygon, v = h (default 0).
    The glTF exporter writes v as 1 - v (Godot reads UV2.y = 1 - h)."""
    me = ob.data
    lay = me.uv_layers.get(name) or me.uv_layers.new(name=name)
    nl = len(me.loops)
    poly_of_loop = np.empty(nl, int)
    for p in me.polygons:
        poly_of_loop[p.loop_start:p.loop_start + p.loop_total] = p.index
    uv = np.zeros((nl, 2), np.float32)
    uv[:, 0] = np.asarray(codes_per_poly, float)[poly_of_loop]
    if h_per_loop is not None:
        uv[:, 1] = h_per_loop
    lay.data.foreach_set("uv", uv.ravel())
    return lay


def poly_codes_from_vertex_regions(ob, vreg, vzone=None):
    """Polygon codes from per-vertex region ids (majority of the polygon's vertices)."""
    me = ob.data
    codes = np.zeros(len(me.polygons), int)
    for p in me.polygons:
        vs = list(p.vertices)
        rs = [int(vreg[v]) for v in vs]
        r = max(set(rs), key=rs.count)
        z = 0
        if vzone is not None:
            zs = [int(vzone[v]) for v in vs]
            z = max(set(zs), key=zs.count)
        codes[p.index] = r + 64 * z
    return codes
