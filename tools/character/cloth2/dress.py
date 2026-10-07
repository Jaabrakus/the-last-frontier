"""cloth2 dress: the recipe types of the peoples' dress of 1750-65 (docs/research/peoples_dress_1750s.md section 2;
2026-10-03). Each type is a style dict (the defaults below, overridden per garment) and one call, like cloth2.recipes
(which re-exports them: recipes.robe(g, st) and so on):

  robe(g, st)          T2: a long robe or kaftan on the coat's cut (recipes.coat): mode "crossed" (left over right),
                       "side_fastened" (neck to the right armpit, then down the side), "under_arm" (the jama crossover)
                       or "open" (edge to edge). The overlapping edge is an `overlap_line` [(z, theta deg)] round the
                       body; side slits, sleeves past the wrist, side ties, a collar band along the edge; `sleeves`
                       None: sleeveless with round armholes (2026-10-06, the Thủy Vân vests and work tunics)
  tunic(g, st)         T3: an unfitted pull-over (thawb, kamis, tob): a neck slit, wide open sleeves (or armholes),
                       side slits, a hood lying on the back, and a closed skirt to the hem (the runtime's closed-skirt
                       panels, as the petticoat)
  trousers(g, st)      T6: drawers, wide trousers (salvar), wide knee breeches: a drawstring band, a crotch dropped
                       0.015-0.32, the legs eased by a table along them (`flare`), soft folds round each leg, and a cuff
                       (band, open, gathered fall). Tag `pants`
  wrap_skirt(g, st)    T5: a wrapped or tube skirt (wrapper, sarong, lungi, futa, philabeg): a rolled band at the top
                       (waist 1.03, navel 1.06, breast 1.23), the hem, flare and folds, pleats, the overlap's open edge
                       split down to the band (a stride opens it: each side of it follows its own leg's panel) with
                       a raised fold edge, stepped rims for wound layers; a closed skirt
  drape(g, st)         T8: a rectangle of cloth laid over the body (drift.envelope, the cloak_hooded method) and cut to
                       an outline [(theta, z)] top and bottom: anchors "one_shoulder" (the mantle: over one shoulder,
                       the other arm bare), "shoulders" (a shawl), "belted" (the belted plaid: from the belt behind over
                       the back to one shoulder, pinned there, the end hanging behind); a rolled edge, a brooch, a
                       belt, a hanging end swinging with the skirt panels
  cloak(g, st)         T9: a cloak from the neck: "circle" (the arms inside, the capa), "capelet" (to the waist),
                       "aba" (square shoulders, arm slits); a stand collar, front facings (embozos, a lining strip),
                       a clasp, a hood (cloth2.hood), a shoulder cape
  head_wrap(g, st)     T10: cloth wound round the head on hats.head_grid: "turban" (a helix of rolls round a cap core),
                       "band" (one or more flat rolls round the brow, the crown bare), "flat" (a cap bound high and flat)
  lathe_hat(g, st)     rigid_hat profiles beside the felt hats: DOME_FINIAL (salakot), CONE (non la, douli, sugegasa:
                       one profile per people), UMBRELLA, TALL_CROWN (kalpak, the Zand cap); an inner head band, a chin
                       strap, a finial
  hose(g, st)          stockings with gartering: the top turned down into a cuff, a garter tape with its ends hanging
                       at the outer side (the Highland cut hose; cloth on the bias, a dicing pattern)
  wound_sash(g, st)    the sash wound several times (2-3 turns on a helix, each turn over the last, the end tucked or a
                       short end hanging): recipes.sash with "turns"

Patterns (checks, stripes, ticking, a plaid's sett, a print) are the Spec zone's `pattern` data that the cloth shader
draws (ClothMaterials.pattern_spec): a garment writes them, the recipe only lays the UVs (metres along the grain).

Every piece exists in every fit (the reference fit's topology, each fit's positions), like the rest of cloth2. Angles
round the body are degrees from the front; `theta` here is SIGNED (+ toward the wearer's left, +x; -180..180) where a
garment is not symmetric (an overlap, a drape over one shoulder); the hems and slits of the symmetric types use the
unsigned angle (parts.angle_from_front).
"""

import copy
import math

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from lib import regions as RG
from cloth2 import drift as D
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import hats as HT
from cloth2 import recipes as R
from cloth2 import trims as TR
from cloth2.mesh import BIG_FIELD, REF, Mesh, concat, smoothstep, unit, vertex_normals
from cloth2.parts import CLOSED_PANELS, closed_skirt_weights, split_sides


def _style(base, st):
    s = copy.deepcopy(base)
    s.update(st or {})
    return s


# ======================================================================================================================
# shared helpers
# ======================================================================================================================
def theta_signed(P, centre=(0.0, 0.0)):
    """Degrees round the vertical axis from the front (-y), + toward the wearer's left (+x): -180 .. 180."""
    P = np.atleast_2d(P)
    return np.degrees(np.arctan2(P[:, 0] - centre[0], -(P[:, 1] - centre[1])))


def wrap_deg(a):
    return (np.asarray(a, float) + 180.0) % 360.0 - 180.0


def periodic(table):
    """f(theta) of a table [(theta deg, value), ...] round the body, interpolated, wrapping at +-180."""
    th = np.array([float(t) for t, _ in table])
    v = np.array([float(x) for _, x in table])
    o = np.argsort(th)
    th, v = th[o], v[o]
    th3 = np.concatenate([th - 360.0, th, th + 360.0])
    v3 = np.tile(v, 3)
    return lambda a: np.interp(wrap_deg(a), th3, v3)


def line_field(P, line):
    """(d, dtheta) of reference positions P from an edge line round the body [(z, theta deg), ...]: d the distance
    (m) along the body from the line, + toward +theta (measured round the vertical axis at the point's own radius);
    dtheta the signed angle (deg). The line's theta is interpolated by height (held beyond its ends)."""
    zs = np.array([float(z) for z, _ in line])
    ts = np.array([float(t) for _, t in line])
    o = np.argsort(zs)
    tl = np.interp(P[:, 2], zs[o], ts[o])
    dth = wrap_deg(theta_signed(P) - tl)
    r = np.hypot(P[:, 0], P[:, 1])
    return np.radians(dth) * np.maximum(r, 0.03), dth


def closed_hems(m):
    """The hems of a closed skirt at the runtime panels' places (40, 90 and 140 degrees round from the front, left leg)
    in Godot bind space (x, y up, z the way the body faces), as skirt_hang.py prints them: the catalog's
    skirt.hems_godot."""
    P = m.V[REF]
    zlo = float(P[:, 2].min())
    ring = P[P[:, 2] < zlo + 0.012]
    cx, cy = float(ring[:, 0].mean()), float(ring[:, 1].mean())
    rr = float(np.hypot(ring[:, 0] - cx, ring[:, 1] - cy).mean())
    return [[round(rr * math.sin(math.radians(d)) + cx, 3), round(zlo, 3), round(rr * math.cos(math.radians(d)) - cy, 3)]
            for d in (40.0, 90.0, 140.0)]


def closed_weights(g, where=None, **kw):
    """The cloth below the hips weighted to the closed skirt's six panels (parts.closed_skirt_weights: the runtime drives
    them round both legs as one, CharacterBodyMesh skirt_closed), only where where(P) holds and never on a sleeve; the
    entry's skirt = {"closed": True, "hems_godot": ...}."""
    m = g.m
    W0 = m.A["W"].copy()
    closed_skirt_weights(g.fits, m, **kw)
    keep = np.ones(m.n, bool) if where is None else np.asarray(where(m.V[REF]), bool)
    if "m_arm_l" in m.A:
        keep &= np.maximum(m.A["m_arm_l"], m.A["m_arm_r"]) < 0.5
    W = m.A["W"]
    W[~keep] = W0[~keep]
    m.A["W"] = W
    g.skirt = {"closed": True, "hems_godot": closed_hems(m)}
    return g


def slit_weights(g, deg, z_top, hold=25.0, blend=30.0):
    """An open edge of a closed skirt at signed angle `deg`, below z_top: the cloth on each side of it takes only the
    panel on its own side (the nearest panel place each way round), fully within `hold` degrees of the edge and
    blending back to the closed weights over `blend` more; so a stride opens the edge instead of the two sides moving as
    one."""
    fits = g.fits
    m = g.m
    idx = {b: i for i, b in enumerate(fits.bones)}
    az = [a for a, _ in CLOSED_PANELS]
    pid = [idx[b] for _, b in CLOSED_PANELS]
    a0 = deg % 360.0
    k_up = next((i for i, a in enumerate(az) if a > a0), 0)       # the next panel round toward +theta
    k_dn = (k_up - 1) % len(az)
    P = m.V[REF]
    dth = wrap_deg(theta_signed(P) - deg)
    W = m.A["W"].copy()
    below = P[:, 2] < z_top
    for side, k in ((1.0, k_up), (-1.0, k_dn)):
        a = side * dth
        w = np.where(a >= 0.0, 1.0 - smoothstep(hold, hold + blend, a), 0.0) * below
        sel = np.nonzero(w > 0.0)[0]
        if not len(sel):
            continue
        share = W[np.ix_(sel, pid)].sum(1)
        tgt = W[sel].copy()
        tgt[:, pid] = 0.0
        tgt[:, pid[k]] = share
        W[sel] = W[sel] * (1.0 - w[sel, None]) + tgt * w[sel, None]
    m.A["W"] = W
    return g


def _arm_faces(fits, sides):
    regs = []
    for s in sides:
        regs += [r for r in D.ARM_REGIONS if r.endswith("_" + s)]
    return [RG.REGIONS[r] for r in regs]


def _without_sleeves(m, sides):
    if not sides or "m_arm_l" not in m.A:
        return m
    arm = np.max([m.A["m_arm_" + s] for s in sides], 0)[m.F].max(1)
    return m.faces_of(arm < 0.5)


def side_hits(fits, arms=("l", "r"), meshes=(), base="cloth"):
    """{fit: BVHTree} of the cloth surface with only the arms `arms` (drift.hit_bvhs keeps both or none) and the
    garments `meshes` worn under (their sleeves of the other arms left out): a drape over one shoulder lies over that
    arm and under the other."""
    drop = [s for s in ("l", "r") if s not in arms]
    keep = ~np.isin(fits.p_region, _arm_faces(fits, drop)) if drop else np.ones(len(fits.pF), bool)
    meshes = [_without_sleeves(m, drop) for m in meshes]
    out = {}
    for k in fits.V:
        if not all(k in m.V for m in meshes):
            continue
        Vs = [(fits.CV if base == "cloth" else fits.PV)[k]]
        Fs = [fits.pF[keep]]
        off = len(Vs[0])
        for m in meshes:
            Vs.append(m.V[k])
            Fs.append(m.F + off)
            off += m.n
        V = np.concatenate(Vs)
        F = np.concatenate(Fs)
        out[k] = BVHTree.FromPolygons([tuple(p) for p in V], [tuple(t) for t in F], all_triangles=True)
    return out


def arc_uv(g):
    """The garment's cylinder UV parts measured as arcs (export "arc": u = the angle times the part's median radius at
    that height), so a pattern's stripes run straight down the back instead of swirling over every hollow."""
    g.uvparts = {k: (("arc",) + tuple(v[1:]) if v[0] == "cyl" else v) for k, v in g.uvparts.items()}
    return g


def under_meshes(fits, ids):
    return [G.built(fits, gid)[0] for gid in ids]


def front_slit(g, z0=1.20, w=(0.0015, 0.012), x=0.0, angle=0.0, z_top=None, front_y=-0.03):
    """An open slit down from the neckline to z0 (recipes.shirt front_slit): half-width w[1] at the neck and w[0] at the
    bottom, its line from (x, the neck) leaning `angle` degrees toward the wearer's left as it goes down (0: the centre
    front; the Persian shirt's opening toward the left shoulder)."""
    zt = (g._neck[2] + 0.02) if (z_top is None and g._neck) else (z_top or 1.35)
    P = g.P
    xl = x + math.tan(math.radians(angle)) * (zt - P[:, 2])
    hw = np.interp(P[:, 2], [z0, zt], [w[0], w[1]])
    f = np.abs(P[:, 0] - xl) - hw + BIG_FIELD * (1.0 - smoothstep(z0 - 0.004, z0, P[:, 2])) + \
        BIG_FIELD * smoothstep(front_y, front_y + 0.03, P[:, 1])
    g.m = g.m.clip(f, 0.0)
    return g


# ======================================================================================================================
# T2 robe: a long robe or kaftan on the coat's cut
# ======================================================================================================================
# The overlapping front's edge (z, theta deg; + the wearer's left) of each mode. "crossed": the wearer's left front over
# the right, from the left of the neck down across the breast to the right of the waist, then straight down; the
# "side_fastened" front runs from the neck to the right armpit and down the right side; "under_arm" (the jama) crosses
# lower, under the right arm.
OVERLAP_LINES = {
    "crossed": [(1.345, 24.0), (1.25, 2.0), (1.10, -34.0), (1.02, -44.0), (0.0, -44.0)],
    "side_fastened": [(1.345, 6.0), (1.27, -40.0), (1.20, -78.0), (1.12, -90.0), (0.0, -90.0)],
    "under_arm": [(1.345, 14.0), (1.22, -30.0), (1.10, -70.0), (1.02, -88.0), (0.0, -90.0)],
}
ROBE = R.style(
    R.COAT,
    mode="crossed",
    neck={"a": 0.086, "b": 0.078, "z0": 1.335, "tilt": 17.0},
    ease=0.0125, sleeve_end=0.92, sleeve_ease=(0.002, 0.010), gather=0.0,
    hem=(0.38, 0.38, 0.38), flare=0.11, folds=0.006, steps=12, pleats=None, skirt_gap=0.03,
    opening=None, overlap=None, vent=None, pockets=None, lapels=None, turnbacks=None, lining=False,
    front_buttons=None, cuff_buttons=0, back_buttons=False, cuffs=None, collar=None,
    # the overlapping edge: the line (None: the mode's), split below `split_below` (the skirt fronts part along it), a
    # fold `w` wide raised `h` on the overlapping side (`outer`: +1, the side toward +theta)
    overlap_line={"line": None, "split_below": 0.86, "w": 0.040, "h": 0.0028, "outer": 1, "split_weights": False,
                  "binding": {"w": 0.010, "zone": 1}},
    slits=[(86.0, 94.0, 0.85)],          # side slits [(from deg, to deg, up to z)] (both sides)
    sleeve_past=None,                    # {"len": 0.08}: sleeves past the wrist (trims.extrude along the forearm)
    sleeves=True,                        # None: sleeveless, round armholes as TUNIC's (`armholes`: Garment.armholes keys)
    armholes=None,
    ties=None,                           # [(theta, z)]: tapes or toggles at points on the garment (zone 3)
    collar_band=None,                    # {"w": 0.03, "h": 0.003}: a band along the neckline and the overlap's edge
    over_relax=0,                        # rounds of smoothing the skirts and fitting them over the layers again
                                         # (recipes.coat)
    zones={"cloth": 0, "facing": 1, "button": 2, "trim": 3},
)
OPEN_ROBE = R.style(ROBE, mode="open", overlap_line=None, slits=None,
                    opening=[(0.0, 0.020), (0.95, 0.016), (1.20, 0.012), (1.6, 0.012)])


def robe(g, st=None):
    """A long robe (ROBE; OPEN_ROBE edge to edge): recipes.coat with the overlap line, side slits and the extras."""
    st = R.style(ROBE, **(st or {}))
    ol = st.get("overlap_line")
    if ol is not None and ol.get("line") is None:
        ol = dict(ol, line=OVERLAP_LINES[st["mode"]])
        st["overlap_line"] = ol
    if st["mode"] == "open":
        st["overlap_line"] = None
    if st.get("sleeves", True) is None:
        # (2026-10-06) sleeveless: the coat's cut with round armholes (recipes.coat "sleeveless")
        st["sleeveless"] = dict(st.get("armholes") or TUNIC["armholes"])
        st["cuffs"] = None
        st["sleeve_past"] = None
        st["cuff_buttons"] = 0
    R.coat(g, st)
    Z = st["zones"]
    if st.get("sleeve_past"):
        sleeve_past(g, st["sleeve_past"]["len"], st["sleeve_end"], Z["cloth"])
    if st.get("collar_band") and st.get("overlap_line"):
        cb = st["collar_band"]
        g.raised(lambda P: _collar_band_sel(g, P, st["overlap_line"], cb), cb.get("h", 0.003), Z["facing"])
    if st.get("ties"):
        from cloth2 import settlers as ST
        for th, z in st["ties"]:
            P = g.around_points(z, np.array([th]))
            if len(P):
                ST.bow(g, P[0], Z["trim"], size=0.018, up=(0.0, 0.0, 1.0), tails=0.05, tail_w=0.008, lift=0.001)
    g.uv()
    arc_uv(g)
    return g


def _collar_band_sel(g, P, ol, cb):
    d, dth = line_field(P, ol["line"])
    w = cb.get("w", 0.03)
    s = ol.get("outer", 1)
    zt = max(z for z, _ in ol["line"])
    return np.abs(s * d - w / 2.0) - w / 2.0 + BIG_FIELD * smoothstep(60.0, 90.0, np.abs(dth)) + \
        BIG_FIELD * smoothstep(zt + 0.01, zt + 0.03, P[:, 2]) + BIG_FIELD * (1.0 - smoothstep(0.60, 0.70, P[:, 2]))


def overlap_cut(g, ol, z_hung):
    """recipes.coat's overlap_line (the robe): the skirts split along the line below split_below; each side then its
    own leg's panels only when split_weights (a front that parts in a stride)."""
    if not ol.get("split_below"):
        return g
    P = g.P
    d, dth = line_field(P, ol["line"])
    sb = ol["split_below"]
    # (an unsigned field: a signed one under a BIG mask would cut a second slit where the mask ramps up)
    f = np.abs(d) - 0.0015 + BIG_FIELD * smoothstep(sb, sb + 0.02, P[:, 2]) + BIG_FIELD * smoothstep(60.0, 90.0, np.abs(dth))
    g.m = TR.drop_small(g.m.clip(f, 0.0))
    if ol.get("split_weights"):
        lo = min(ol["line"], key=lambda t: t[0])
        x0 = math.sin(math.radians(lo[1])) * 0.15          # the line's place across the front below the waist
        split_sides(g.fits, g.m, (g.P[:, 1] < 0.0) & (g.P[:, 2] < z_hung), x0=x0)
    return g


def overlap_raise(g, ol, zone=None):
    """The overlapping front's fold: a band `w` wide on the outer side of the line raised `h` (its rim the edge)."""
    w, h, s = ol.get("w", 0.04), ol.get("h", 0.0028), ol.get("outer", 1)
    zt = max(z for z, _ in ol["line"])

    def f(P):
        d, dth = line_field(P, ol["line"])
        return np.abs(s * d - w / 2.0) - w / 2.0 + BIG_FIELD * smoothstep(60.0, 90.0, np.abs(dth)) + \
            BIG_FIELD * smoothstep(zt, zt + 0.02, P[:, 2])
    g.raised(f, h, zone)
    bd = ol.get("binding")
    if bd:
        bw = bd.get("w", 0.010)

        def fb(P):
            d, dth = line_field(P, ol["line"])
            return np.abs(s * d - bw / 2.0) - bw / 2.0 + BIG_FIELD * smoothstep(60.0, 90.0, np.abs(dth)) + \
                BIG_FIELD * smoothstep(zt, zt + 0.02, P[:, 2])
        sel = g.select(fb)
        g.m.fa["zone"][sel] = bd.get("zone", 1)
    return g


def sleeve_past(g, length, end, zone=0, rings=3):
    """Sleeves that cover the hands: the cuff edge carried on `length` m along the forearm (trims.extrude), the same
    weights (the wrist's)."""
    fits = g.fits
    for s in ("l", "r"):
        ch = fits.arm(s)
        ax = unit(ch[2] - ch[1])
        mem = g.m.A["m_arm_" + s]
        tt = g.m.A["t_arm_" + s]
        keep = (mem > 0.5) & (tt > end - 0.03)

        def disp(fit, P0, N0, sv, ax=ax):
            return np.broadcast_to(ax * length * sv, P0.shape)
        piece = TR.extrude(g.m, lambda P, keep=keep: keep, disp, rings=rings, zone=zone)
        if piece is not None:
            g.add(piece)
    return g


# ======================================================================================================================
# T3 tunic: an unfitted pull-over shirt, long
# ======================================================================================================================
TUNIC = {
    "neck": {"a": 0.082, "b": 0.074, "z0": 1.325, "tilt": 17.0}, "dip": 0.0,
    "slit": {"z0": 1.17, "w": (0.0015, 0.016)},     # the neck slit down the front (bottom z; half-width there, at the neck)
    "bottom": 0.905, "ease": 0.0075,
    # sleeves: to arm parameter `end`; ease (shoulder, mid arm); `wide`: m more toward the cuff from parameter `from`
    # (an open sleeve 0.55 m round at the wrist); None: sleeveless (round armholes)
    "sleeves": {"end": 0.96, "ease": (0.008, 0.016), "wide": 0.050, "from": 0.45},
    "armholes": {"size": (0.060, 0.070, 0.100), "centre": (0.012, 0.004, -0.040), "t_cut": 0.10},
    "hem": 0.16, "side_hem": None, "flare": 0.13, "folds": 0.012, "steps": 14, "tail_gap": 0.03,
    "slits": None,                                  # side slits [(from deg, to deg, up to z)]
    "hood": None,                                   # cloth2.hood.hood_on_back keys
    "closed": True,                                 # a closed skirt (the runtime's closed-skirt panels)
    "over": (), "over_gap": 0.004,
    "trim": {"neck": 0.022, "slit": 0.012, "cuff": 0.030},   # zone-1 bands (embroidery): the neck, the slit, the cuffs
    "zones": {"cloth": 0, "trim": 1},
}


def tunic(g, st=None):
    """A T-shaped pull-over (TUNIC): the shirt's shell and sleeves, the closed skirt to the hem."""
    st = _style(TUNIC, st)
    Z = st["zones"]
    sl = st["sleeves"]
    g.shell(G.TORSO + G.ARMS)
    g.neckline(dip=st["dip"], **st["neck"]).bottom(st["bottom"])
    if sl:
        g.sleeves(end=sl["end"], ease=tuple(sl["ease"]), gather=-sl.get("wide", 0.0), gather_from=sl.get("from", 0.45))
        g.seams()
    else:
        g.armholes(**st["armholes"])
        g.seams(limbs=())
    g.fit(ease=st["ease"])
    hem = st["hem"]
    side = st["side_hem"] if st["side_hem"] is not None else hem + 0.01
    g.tails(hem=hem, side_hem=side, flare=st["flare"], folds=st["folds"], steps=st["steps"], slits=st["slits"],
            gap=st["tail_gap"], z_full=G.SKIRT_Z_FULL)
    if st["over"]:
        g.over(st["over"], st["over_gap"])
    tr = st["trim"] or {}
    if st["slit"]:
        s = st["slit"]
        D.clip_front_slit(g, s["z0"], st["neck"]["z0"] + 0.02, s["w"][0], s["w"][1])
        if tr.get("slit"):
            z0 = s["z0"]
            g.edge_zone(Z["trim"], tr["slit"], select=lambda P, z0=z0: (P[:, 1] < -0.02) & (np.abs(P[:, 0]) < 0.04) &
                        (P[:, 2] > z0 - 0.01) & (P[:, 2] < st["neck"]["z0"] - 0.03))
    if tr.get("neck"):
        g.collar_zone(Z["trim"], tr["neck"])
    if sl and tr.get("cuff"):
        D.wrist_band_zone(g, Z["trim"], tr["cuff"])
    if st["hood"]:
        from cloth2 import hood as HD
        HD.hood_on_back(g, **st["hood"])
    if st["closed"]:
        closed_weights(g, where=lambda P: P[:, 2] < st["bottom"] + 0.02)
    g.hem_below(max(hem, side) + 0.05)
    g.uv()
    arc_uv(g)
    return g


# ======================================================================================================================
# T6 trousers
# ======================================================================================================================
LEG_SHELL = ["abdomen_front", "abdomen_side", "abdomen_back", "pelvis_center", "pelvis_side",
             "thigh_upper_l", "thigh_lower_l", "shin_upper_l", "shin_lower_l", "ankle_l",
             "thigh_upper_r", "thigh_lower_r", "shin_upper_r", "shin_lower_r", "ankle_r"]
TROUSERS = {
    "kind": "wide",
    "regions": LEG_SHELL,
    "top": 1.06, "band": 0.035, "band_h": 0.004,       # the waistband: a rolled drawstring band from top - band
    "end": 0.93, "ease": 0.016, "leg_ease": (0.016, 0.018), "gather": 0.0, "gather_from": 0.9,
    # extra ease along each leg [(t, m)] (the outer side; never across the midline: drift.flare_legs `keep`)
    # (from t 0.18 on, below the crotch, as the slops: pushed out sooner, the crotch's own cloth tore)
    "flare": [(0.18, 0.0), (0.32, 0.034), (0.50, 0.072), (0.70, 0.058), (0.84, 0.022), (0.92, 0.0)], "keep": 0.012,
    "folds": {"amp": 0.007, "count": 7.0},          # soft folds round each leg, deepest where the flare is
    # the crotch (Garment.crotch): how far it is lowered between the thighs. The shell tears beyond about 0.04 (the
    # thighs bound it); a low-hanging crotch reads instead from the legs' fullness meeting at the midline down to the
    # knee (drift.flare_legs keep), as it does under a robe
    "crotch": {"drop": 0.030, "width": 0.075},
    "seat": 0.018,                                  # more room across the seat
    "cuff": {"kind": "band", "len": 0.040, "h": 0.003},   # band: a gathered band at the end; open: none; fall: the cloth
                                                    # above the band standing out and falling over it
    "fall": 0.0,                                    # (kind fall) how far the cloth above the band stands out (m)
    "over": (), "over_gap": 0.004, "over_above": None,   # fitted over those garments (only above over_above, m)
    "zones": {"cloth": 0, "band": 1, "cuff": 1},
}
DRAWERS = _style(TROUSERS, {"kind": "drawers", "top": 1.02, "band": 0.025, "band_h": 0.003, "end": 0.55,
                            "leg_ease": (0.022, 0.026),
                            "flare": [(0.18, 0.0), (0.32, 0.010), (0.55, 0.012)], "folds": {"amp": 0.004, "count": 6.0},
                            "crotch": {"drop": 0.030, "width": 0.075}, "seat": 0.012, "cuff": {"kind": "open"}})
WIDE_BREECHES = _style(TROUSERS, {"kind": "breeches", "top": 1.03, "band": 0.03, "end": 0.55,
                                  "flare": [(0.18, 0.0), (0.32, 0.030), (0.48, 0.045), (0.55, 0.030)],
                                  "folds": {"amp": 0.005, "count": 8.0}, "crotch": {"drop": 0.030, "width": 0.075},
                                  "cuff": {"kind": "band", "len": 0.03, "h": 0.003}})


def _leg_axis(fits, side, P):
    """Points on the leg's joint line at the heights of P (hip -> knee -> ankle), and the outer direction (+-x)."""
    ch = fits.leg(side)
    zs = np.array([c[2] for c in ch])[::-1]
    xs = np.array([c[0] for c in ch])[::-1]
    ys = np.array([c[1] for c in ch])[::-1]
    return np.stack([np.interp(P[:, 2], zs, xs), np.interp(P[:, 2], zs, ys), P[:, 2]], 1)


def trousers(g, st=None):
    """Trousers (TROUSERS: wide, the salvar; DRAWERS; WIDE_BREECHES), on the slops' and breeches' operations."""
    from cloth2 import bridge as BR
    st = _style(TROUSERS, st)
    Z = st["zones"]
    g.shell(st["regions"])
    g.top(st["top"]).legs(end=st["end"], ease=tuple(st["leg_ease"]), gather=st["gather"], gather_from=st["gather_from"])
    g.seams(back=True, limbs=())
    cr = st["crotch"]
    g.crotch(drop=cr["drop"], width=cr["width"])
    g.fit(ease=st["ease"], gap=0.003)
    P = g.P
    if st["seat"]:
        seat = smoothstep(0.0, 0.07, P[:, 1]) * smoothstep(0.74, 0.82, P[:, 2]) * \
            (1.0 - smoothstep(0.96, 1.02, P[:, 2])) * (1.0 - smoothstep(0.13, 0.19, np.abs(P[:, 0])))
        g.m.offset(st["seat"] * seat, vertical=0.3)
        g.m.smooth(2, 0.5, weights=np.minimum(1.0, seat * 2.0))
        g.fits.clear(g.m, 0.003)
    ft = np.array(st["flare"], float)
    D.flare_legs(g, lambda t: np.interp(t, ft[:, 0], ft[:, 1]), t0=float(ft[0, 0]), keep=st["keep"])
    fo = st["folds"]
    if fo and fo.get("amp"):
        _leg_folds(g, fo["amp"], fo["count"], ft)
    g.m.smooth(4, 0.4)
    # the seat and the crotch hang as one low seam (no shape of the body's own between the legs)
    P = g.P
    zc = 0.79
    w = np.exp(-(P[:, 0] / 0.07) ** 2) * np.exp(-((P[:, 2] - zc) / 0.08) ** 2)
    for _ in range(4):
        g.m.smooth(6, 0.5, weights=w)
        g.fits.clear(g.m, 0.003)
    oz = st.get("over_above")
    if st["over"]:
        g.over(st["over"], st["over_gap"], where=(lambda P: P[:, 2] > oz) if oz else None)
    BR.fill_holes(g, lambda P: (np.abs(P[:, 0]) < 0.06) & (P[:, 2] > 0.62) & (P[:, 2] < 0.86), max_edges=24)
    BR.crotch_bridge(g, window=BR.crotch_window(z_lo=(0.58, 0.64)),
                     male_window=lambda P: (1.0 - smoothstep(0.022, 0.048, np.abs(P[:, 0]))) *
                     smoothstep(0.0, -0.025, P[:, 1]) * smoothstep(0.64, 0.68, P[:, 2]) *
                     (1.0 - smoothstep(0.80, 0.85, P[:, 2])))
    if st["over"]:
        # (the bridge drew the crotch's front in again: a long shirt's tails hang there)
        g.over(st["over"], st["over_gap"], where=(lambda P: P[:, 2] > oz) if oz else None)
    zb = st["top"] - st["band"]
    g.zone(Z["band"], above=zb)
    if st["band_h"]:
        g.raised(lambda P: (zb - P[:, 2]) * 3.0, st["band_h"], Z["band"])
    cf = st["cuff"] or {"kind": "open"}
    if cf["kind"] in ("band", "fall"):
        t_cuff = st["end"] - cf["len"] / 0.745          # (the leg parameter runs ~0.745 m from the hip to the ankle)
        g.zone(Z["cuff"], limb=("leg_l", "leg_r"), t_above=t_cuff)
        if cf.get("h"):
            for s in ("l", "r"):
                mem, tt = g.m.A["m_leg_" + s], g.m.A["t_leg_" + s]
                fld = (t_cuff - tt) * 2.0 + BIG_FIELD * (1.0 - smoothstep(0.3, 0.6, mem))
                g.raised(fld, cf["h"], Z["cuff"])
    g.hem_below(0.30 if st["end"] > 0.8 else 0.60)
    g.uv(axis_top=st["top"] + 0.01, axis_bottom=0.75, limbs=("leg_l", "leg_r"))
    arc_uv(g)
    return g


def _leg_folds(g, amp, count, ft):
    """Soft folds round each leg: an offset amp * sin(count * angle round the leg) along the level normal, in
    proportion to the flare at that place along the leg."""
    m = g.m
    peak = max(float(ft[:, 1].max()), 1e-6)
    for s in ("l", "r"):
        sg = 1.0 if s == "l" else -1.0
        mem = m.A["m_leg_" + s]
        t = m.A["t_leg_" + s]
        P = m.V[REF]
        ax = _leg_axis(g.fits, s, P)
        q = P - ax
        phi = np.arctan2(q[:, 1], sg * q[:, 0])
        k = np.interp(t, ft[:, 0], ft[:, 1]) / peak
        d = amp * k * np.sin(count * phi + 0.7) * smoothstep(0.3, 0.8, mem) * smoothstep(0.22, 0.34, t)
        for fit in m.V:
            n = m.N[fit].copy()
            n[:, 2] = 0.0
            n = unit(n)
            m.V[fit] = m.V[fit] + n * d[:, None]
    m.recompute_normals()
    g.fits.clear(m, 0.002)
    return g


# ======================================================================================================================
# T5 wrap_skirt
# ======================================================================================================================
WRAP_SKIRT = {
    "top": 1.035, "band": 0.032, "band_h": 0.006,    # the rolled band at the top (zone `band`)
    "ease": 0.020, "gap": 0.012,
    "hem": 0.44, "side_hem": None, "flare": 0.05, "folds": 0.010, "steps": 9, "tail_gap": 0.022,
    "pleats": None,                                  # parts.pleat_offset groups [(centre deg, width deg, count, depth)]
    # the overlap: its open edge at signed angle `deg`, split from the hem to the band (`split`), a fold `w` wide raised
    # `h` on the `outer` side (+1: toward +theta)
    "overlap": {"deg": -30.0, "outer": 1, "w": 0.045, "h": 0.0028, "split": True},
    "rims": None,                                    # wound layers: [(z, h)] each a step raised h below z
    "over": (), "over_gap": 0.004,
    "closed": True,
    "zones": {"cloth": 0, "band": 1},
}


def wrap_skirt(g, st=None):
    """A wrapped skirt (WRAP_SKIRT): the petticoat's shell and closed skirt, the rolled band, the overlap's edge."""
    st = _style(WRAP_SKIRT, st)
    Z = st["zones"]
    top = st["top"]
    b0 = top - st["band"]
    g.shell(G.TORSO)
    g.top(top).bottom(b0)
    g.seams(back=True, limbs=())
    g.fit(ease=st["ease"], gap=st["gap"])
    hem = st["hem"]
    side = st["side_hem"] if st["side_hem"] is not None else hem
    g.tails(hem=hem, side_hem=side, flare=st["flare"], folds=st["folds"], steps=st["steps"], z_full=0.55, x_limit=0.6,
            gap=st["tail_gap"], pleats=st["pleats"])
    if st["over"]:
        g.over(st["over"], st["over_gap"])
    ov = st["overlap"]
    if ov and ov.get("split", True):
        P = g.P
        dth = wrap_deg(theta_signed(P) - ov["deg"])
        d = np.radians(dth) * np.hypot(P[:, 0], P[:, 1])
        f = np.abs(d) - 0.0016 + BIG_FIELD * smoothstep(b0 - 0.012, b0 - 0.004, P[:, 2]) + \
            BIG_FIELD * smoothstep(60.0, 90.0, np.abs(dth))
        g.m = TR.drop_small(g.m.clip(f, 0.0))
    if st["rims"]:
        for z, h in st["rims"]:
            g.raised(lambda P, z=z: (P[:, 2] - z) * 3.0 + BIG_FIELD * smoothstep(b0 - 0.01, b0, P[:, 2]), h, Z["cloth"])
    if ov:
        s, w = ov.get("outer", 1), ov["w"]

        def fo(P):
            dth = wrap_deg(theta_signed(P) - ov["deg"])
            d = np.radians(dth) * np.hypot(P[:, 0], P[:, 1])
            return np.abs(s * d - w / 2.0) - w / 2.0 + BIG_FIELD * smoothstep(60.0, 90.0, np.abs(dth)) + \
                BIG_FIELD * smoothstep(b0 - 0.006, b0, P[:, 2])
        g.raised(fo, ov["h"], Z["cloth"])
    g.zone(Z["band"], above=b0)
    if st["band_h"]:
        g.raised(lambda P: (b0 - P[:, 2]) * 3.0, st["band_h"], Z["band"])
    if st["closed"]:
        closed_weights(g)
        if ov and ov.get("split", True):
            slit_weights(g, ov["deg"], b0 - 0.02)
    g.hem_below(max(hem, side) + 0.03)
    g.uv(axis_top=top + 0.01, axis_bottom=0.3, limbs=())
    if ov:
        # the cylinder's seam (180 deg from its front) on the overlap's own edge: the pattern breaks where the cloth does
        a = math.radians(ov["deg"] + 180.0)
        g.uvparts[0] = ("cyl", [0.0, 0.0, 0.3], [0.0, 0.0, top + 0.01], [math.sin(a), -math.cos(a), 0.0])
    arc_uv(g)
    return g


# ======================================================================================================================
# T8 drape: a rectangle of cloth laid over the body, cut to an outline
# ======================================================================================================================
DRAPE = {
    "anchor": "one_shoulder",
    "z_c": 1.19, "phi": (26.0, 90.0), "n_polar": 7, "z_step": 0.036, "cols": 48,
    "arms": ("r",), "arm_z": 1.10,                   # the arms the cloth lies over above arm_z (under it, none)
    # the outline: keep where bottom(theta) < z < top(theta) (signed theta, + the wearer's left)
    "top": [(-180.0, 1.36), (-150.0, 1.70), (-30.0, 1.70), (0.0, 1.27), (45.0, 1.08), (90.0, 0.93), (135.0, 1.06)],
    "bottom": [(-180.0, 0.60), (-90.0, 0.62), (0.0, 0.58), (90.0, 0.62)],
    "ease": 0.012, "drape": 0.004, "folds": (0.012, 7.0, 1.0), "flare": (0.03, 1.0), "smooth": 3,
    "hang_from": 0.95,                               # below this the cloth swings with the skirt panels
    "edge": {"w": 0.014, "h": 0.0028},               # a rolled edge along the outline's top (zone `edge`)
    "fringe": None,                                  # {"len": m}: the ends' last `len` in zone `fringe`
    "brooch": None,                                  # {"theta": deg, "z": m, "r": m}: a ring brooch with its pin
    "belt": None,                                    # {"z": (z0, z1)}: a belt round the waist (zone `belt`)
    "over": (), "over_gap": 0.005,
    "uv_seam": 90.0,                                 # where the cloth's UV is cut (signed deg: little or no cloth there)
    "zones": {"cloth": 0, "edge": 0, "belt": 2, "metal": 3, "fringe": 1},
}
# the belted plaid (the drape anchor "belted"): from under the belt behind over the back to the left shoulder, pinned at
# the front of the shoulder, the right arm free; the end hanging behind over the left side of the back
BELTED = _style(DRAPE, {
    "anchor": "belted", "arms": ("l",), "arm_z": 1.12,
    "top": [(-180.0, 1.24), (-130.0, 1.06), (-115.0, 0.50), (15.0, 0.50), (25.0, 1.70), (140.0, 1.70), (160.0, 1.46)],
    "bottom": [(-180.0, 0.99), (-130.0, 0.99), (20.0, 1.23), (60.0, 1.20), (95.0, 1.13), (115.0, 0.56), (165.0, 0.56),
               (178.0, 0.99)],
    "folds": (0.010, 9.0, 1.1), "flare": (0.02, 1.0),
    "brooch": {"theta": 32.0, "z": 1.27, "r": 0.028},
    "belt": {"z": (0.978, 1.034), "lift": 0.032, "buckle": True},
    "uv_seam": -60.0,
})


def envelope_uv(g, m, rows, cols, seam=180.0, closed=True, smooth=3):
    """The cloth's own UV on an envelope grid (drift.envelope; vertex (i, j) at i * cols + j), as the attributes
    uv_u / uv_v (export "attr"): u across the cloth, the column's angle from `seam` (deg) times its row's mean radius
    (smoothed over the rows), v down each column, the distance along it from the top row. A stripe or a sett then runs
    with the cloth's grain over the shoulder and down, instead of round a body cylinder."""
    P = m.V[REF].reshape(len(rows), cols, 3)
    th = m.A["_th"].reshape(len(rows), cols)
    rr = np.hypot(P[..., 0], P[..., 1]).mean(1)
    k = 2 * smooth + 1
    rr = np.convolve(np.pad(rr, smooth, mode="edge"), np.ones(k) / k, mode="valid")
    a = np.radians((th - seam) % 360.0 if closed else th - seam)
    u = a * rr[:, None]
    dv = np.concatenate([np.zeros((1, cols)), np.linalg.norm(np.diff(P, axis=0), axis=2)], 0)
    v = -np.cumsum(dv, 0)
    m.A["uv_u"] = u.reshape(-1)
    m.A["uv_v"] = v.reshape(-1)
    return m


def _with_attrs(piece, like):
    """`piece` with zero per-vertex attributes for the names `like` has and it lacks (concat needs the same names)."""
    for k, v in like.A.items():
        if k not in piece.A:
            piece.A[k] = np.zeros((piece.n,) + v.shape[1:])
    return piece


def _cloth_uv(g, extra=None):
    """uvparts for an envelope garment: part 0 its own cloth UV (envelope_uv), parts >= 5 as set (planar), `extra`."""
    keep = {k: v for k, v in g.uvparts.items() if k >= 5}
    g.m.fa["part"][g.m.fa["part"] < 5] = 0
    g.uvparts = {0: ("attr", "uv_u", "uv_v")}
    for pid in np.unique(g.m.fa["part"]):
        if pid >= 5:
            g.uvparts[int(pid)] = keep.get(int(pid), ("planar", [0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, 1.0]))
    g.uvparts.update(extra or {})
    return g


def drape(g, st=None):
    """A drape (DRAPE; BELTED): an envelope over the shoulders and down the body (drift.envelope), cut to the outline,
    the lower cloth swinging with the skirt panels; a rolled top edge, a brooch, a belt. Its UV is the cloth's own
    (envelope_uv; the seam at `uv_seam` deg, where the outline leaves the least cloth)."""
    st = _style(DRAPE, st)
    Z = st["zones"]
    fits = g.fits
    under = under_meshes(fits, st["over"])
    hits_arm = side_hits(fits, st["arms"], under)
    hits_none = side_hits(fits, (), under)
    zmin = float(min(z for _, z in st["bottom"])) - 0.04
    z_level = list(np.arange(st["z_c"] - 0.03, zmin, -st["z_step"]))
    rows = D.cape_rows(z_c=st["z_c"], phi=st["phi"], n_polar=st["n_polar"], z_rows=z_level)
    use_arm = [True] * st["n_polar"] + [z >= st["arm_z"] for z in z_level]
    hits_by_row = [hits_arm if a else hits_none for a in use_arm]
    thetas = np.arange(st["cols"]) * (360.0 / st["cols"])
    m, _ = D.envelope(g, rows, thetas, None, st["ease"], smooth=st["smooth"], hits_by_row=hits_by_row, closed=True,
                      drape=st["drape"], folds=st["folds"], flare=st["flare"], weight_arms=use_arm)
    envelope_uv(g, m, rows, st["cols"], seam=st["uv_seam"] % 360.0, closed=True)
    g.m = m
    D.drop_attrs(g.m)
    top, bot = periodic(st["top"]), periodic(st["bottom"])
    g.m = TR.drop_small(g.m.clip(top(theta_signed(g.P)) - g.P[:, 2], 0.0), 20)
    g.m = TR.drop_small(g.m.clip(g.P[:, 2] - bot(theta_signed(g.P)), 0.0), 20)
    # (the UV's seam: the faces across it are cut off, so u never jumps inside a face)
    sd = wrap_deg(theta_signed(g.P) - st["uv_seam"])
    g.m = TR.drop_small(g.m.clip(np.abs(np.radians(sd)) * 0.2 - 0.0008 + BIG_FIELD * smoothstep(60.0, 90.0, np.abs(sd)),
                                 0.0), 20)
    D.hang_weights(fits, g.m, st["hang_from"])
    g.fits.clear(g.m, 0.003)
    if st["over"]:
        g.over(st["over"], st["over_gap"])
    if st["edge"]:
        e = st["edge"]
        g.edge_zone(Z["edge"], e["w"], h=e["h"],
                    select=lambda P: P[:, 2] > bot(theta_signed(P)) + 0.04)
    if st["fringe"]:
        fl = st["fringe"]["len"]
        c = g.m.face_centres()
        g.m.fa["zone"][c[:, 2] < bot(theta_signed(c)) + fl] = Z["fringe"]
    if st["belt"]:
        bt = st["belt"]
        sub = G.Garment(fits, g.spec)
        sub.band(bt["z"][0], bt["z"][1], bt.get("lift", 0.030), Z["belt"])
        if st["over"]:
            sub.over(st["over"], st["over_gap"])
        # the cloth tucked under it: the belt over the drape itself too
        fits.clear(sub.m, st["over_gap"], surface=fits.obstacles([g.m]), max_push=0.03)
        sub.m.fa["part"][:] = 5
        g.add(_with_attrs(sub.m, g.m))
        if bt.get("buckle"):
            P = g.front_points([0.0], [0.5 * (bt["z"][0] + bt["z"][1])])
            if len(P):
                g.hardware(P, HW.frame(0.045, 0.045, 0.006, 0.004), Z["metal"])
    if st["brooch"]:
        b = st["brooch"]
        P = g.around_points(b["z"], np.array([b["theta"]]))
        if len(P):
            r = b["r"]
            prim = HW.merge([HW.ring(r, 0.0035, 16, 4), HW.translate(HW.box(r * 1.15, 0.0016, 0.0012), (0.0, 0.0, 0.004))])
            g.hardware(P[:1], prim, Z["metal"], up=(0.0, 0.0, 1.0), lift=0.001)
    g.hem_below(float(max(z for _, z in st["bottom"])) + 0.02)
    _cloth_uv(g, {5: ("arc", [0.0, 0.0, 0.9], [0.0, 0.0, 1.1], [0, -1, 0])})
    return g


# ======================================================================================================================
# T9 cloak
# ======================================================================================================================
CLOAK = {
    "kind": "circle",
    "z_c": 1.21, "phi": (20.0, 90.0), "n_polar": 8, "z_step": 0.036, "cols": 60,
    # the arms the cloth lies over: above arm_z (or all the way down with arms_inside: a cloak whose sides follow the
    # arms); below it the cloth hangs behind them
    "arms_inside": False, "arm_z": 1.08,
    # the front edges' angle from the front by height [(z, deg)]: closed at the throat, parting below the arms so the
    # forearms come out in front of the edges (a number: the same all the way down)
    "front": [(1.45, 3.5), (1.25, 3.5), (1.15, 26.0), (1.06, 92.0), (0.0, 104.0)],
    "hem": (0.22, 0.20),                            # at the front edges, at the back
    "ease": 0.012, "drape": 0.003, "folds": (0.016, 9.0, 1.0), "flare": (0.05, 1.0), "smooth": 3,
    "neck_cut": (1.355, 1.39),                      # the neckline (front, back z) the collar grows from
    "collar": {"h": 0.034},                         # a stand collar grown from the neck edge (None: none)
    "facing": {"w": 0.05, "h": 0.0022},             # the front facings (embozos) turned back: a band along each front
    "clasp": {"z": 1.33},                           # a clasp at the throat (zone 2)
    "hood": None,                                   # cloth2.hood.hood_on_back keys
    "hang_from": 0.98,
    "over": (), "over_gap": 0.006,
    "zones": {"cloth": 0, "facing": 1, "metal": 2, "trim": 3},
}


def cloak(g, st=None):
    """A cloak from the neck (CLOAK): an envelope over the shoulders and the upper arms to the hem, behind the forearms,
    open in front by the `front` table, a stand collar, the facings turned back along the fronts, a clasp."""
    st = _style(CLOAK, st)
    Z = st["zones"]
    fits = g.fits
    under = under_meshes(fits, st["over"])
    with_arms = side_hits(fits, ("l", "r"), under)
    no_arms = side_hits(fits, (), under)
    zmin = min(st["hem"]) - 0.04
    z_level = list(np.arange(st["z_c"] - 0.03, zmin, -st["z_step"]))
    rows = D.cape_rows(z_c=st["z_c"], phi=st["phi"], n_polar=st["n_polar"], z_rows=z_level)
    arms = [True] * st["n_polar"] + [st["arms_inside"] or z >= st["arm_z"] - 0.005 for z in z_level]
    hits_by_row = [with_arms if a else no_arms for a in arms]
    ft = st["front"] if isinstance(st["front"], (list, tuple)) else [(2.0, st["front"]), (0.0, st["front"])]
    fz = np.array([z for z, _ in ft], float)
    fd = np.array([d for _, d in ft], float)
    o = np.argsort(fz)
    e0 = float(fd.min())
    thetas = np.linspace(e0 - 1.0, 360.0 - e0 + 1.0, st["cols"])
    m, _ = D.envelope(g, rows, thetas, None, st["ease"], smooth=st["smooth"], hits_by_row=hits_by_row,
                      drape=st["drape"], folds=st["folds"], flare=st["flare"], weight_arms=arms)
    envelope_uv(g, m, rows, st["cols"], seam=180.0, closed=False)
    g.m = m
    th = g.m.A["_th"]
    ev = np.interp(g.P[:, 2], fz[o], fd[o])
    g.m = g.m.clip(np.minimum(th - ev, 360.0 - ev - th), 0.0)
    D.drop_attrs(g.m)
    hf, hb = st["hem"]
    a = np.abs(wrap_deg(theta_signed(g.P)))
    hem = hb + (hf - hb) * np.clip((180.0 - a) / 180.0, 0.0, 1.0) ** 1.5
    g.m = g.m.clip(g.P[:, 2] - hem, 0.0)
    if st.get("neck_cut"):
        # a clean neckline (the first polar row hits the neck unevenly): front z, back z
        nf, nb = st["neck_cut"]
        a = np.abs(wrap_deg(theta_signed(g.P)))
        g.m = TR.drop_small(g.m.clip(nf + (nb - nf) * (a / 180.0) ** 1.5 - g.P[:, 2], 0.0), 20)
    D.hang_weights(fits, g.m, st["hang_from"])
    g.fits.clear(g.m, 0.003)
    if st["over"]:
        g.over(st["over"], st["over_gap"])
    if st["hood"]:
        from cloth2 import hood as HD
        HD.hood_on_back(g, **st["hood"])
    if st["facing"]:
        fc = st["facing"]
        zt = float(fz.max())
        g.edge_zone(Z["facing"], fc["w"], h=fc.get("h", 0.0),
                    select=lambda P: (np.abs(wrap_deg(theta_signed(P))) < np.interp(P[:, 2], fz[o], fd[o]) + 6.0) &
                    (P[:, 2] < 1.32) & (P[:, 2] > min(st["hem"]) + 0.02))
    if st["collar"]:
        neck_edge_collar(g, st["collar"]["h"], Z["cloth"], z_min=(st["neck_cut"][0] - 0.02) if st.get("neck_cut")
                         else 1.30, front_deg=e0 + 2.5)
        g.fits.clear(g.m, 0.003)
    if st["clasp"]:
        z = st["clasp"]["z"]
        for sg in (1.0, -1.0):
            P = g.around_points(z, np.array([sg * (e0 + 2.0)]))
            if len(P):
                g.hardware(P[:1], HW.disc(0.008, 0.003, segs=10), Z["metal"])
    g.hem_below(max(st["hem"]) + 0.04)
    _cloth_uv(g)
    return g


def neck_edge_collar(g, height, zone, z_min=1.30, front_deg=5.0, lean=0.18, rings=2):
    """A stand collar grown up from the top edge of an envelope (a cloak has no neckline ellipse): the open boundary
    above z_min, off the front edges (|theta| > front_deg), `height` up and leaning in by `lean` of it."""
    def sel(P):
        return (P[:, 2] > z_min) & (np.abs(theta_signed(P)) > front_deg)

    def disp(fit, P0, N0, s):
        inward = np.stack([-P0[:, 0], -P0[:, 1], np.zeros(len(P0))], 1)
        inward = unit(inward)
        return (np.array([0.0, 0.0, 1.0])[None] + inward * lean) * (height * s)
    piece = TR.extrude(g.m, sel, disp, rings=rings, zone=zone)
    if piece is not None:
        g.add(piece)
    return g


# ======================================================================================================================
# T10 head_wrap
# ======================================================================================================================
HEAD_WRAP = {
    "kind": "turban",
    # the core: a small cap (hats.head_grid): its edge (deg from the crown at the front, sides, back) and ease
    "core": {"edge": (58.0, 70.0, 78.0), "ease": 0.0095, "zone": 1},
    # the rolls: a helix of turns from z0 (the front's height; the band plane tilts), `rise` per turn, each roll a tube
    # of radius r on an ellipse (half-widths a0 across and a0 * ab front to back, growing by `grow` a turn), never
    # closer to the scalp than ease + r
    "rolls": {"turns": 4.0, "z0": 1.522, "rise": 0.016, "tilt": 0.026, "r": 0.0145, "a0": 0.100, "ab": 1.16,
              "grow": 0.004, "ease": 0.0095, "wobble": 0.004, "r_var": 0.15, "lift_var": 0.004, "per_turn": 40,
              "segs": 8, "start": 180.0, "flat": 1.0},
    "zones": {"cloth": 0, "core": 1},
}
HEAD_BAND = _style(HEAD_WRAP, {"kind": "band", "core": None,
                               "rolls": {"turns": 1.0, "z0": 1.535, "rise": 0.0, "tilt": 0.006, "r": 0.011, "a0": 0.0,
                                         "ab": 1.16, "grow": 0.0, "ease": 0.003, "wobble": 0.0, "per_turn": 48,
                                         "segs": 8, "start": 180.0, "flat": 0.45}})


def head_wrap(g, st=None):
    """Cloth wound round the head (HEAD_WRAP turban; HEAD_BAND): the core cap and the rolls, rigid on headb."""
    st = _style(HEAD_WRAP, st)
    Z = st["zones"]
    fits = g.fits
    core = st["core"]
    if core:
        fr, sd, bk = [np.radians(a) for a in core["edge"]]

        def phi_max(th):
            c = np.cos(th)
            return np.where(c > 0, sd + (fr - sd) * c, sd + (bk - sd) * (-c))
        m, ids, TH, PH = HT.head_grid(fits, segs=32, rows=9, phi_max=phi_max, ease=lambda th, ph: core["ease"])
        m.fa["zone"][:] = core.get("zone", Z["core"])
        g.m = m
    else:
        m, ids, TH, PH = HT.head_grid(fits, segs=8, rows=2, phi_max=lambda th: np.full_like(th, 0.3))
        g.m = None
        template = m
    rl = st["rolls"]
    path, radii = roll_path(fits, rl)
    piece = HT.tube(fits, g.m if g.m is not None else template, path, radii, segs=rl["segs"], zone=Z["cloth"], part=0)
    if rl.get("flat", 1.0) != 1.0:
        _flatten_roll(fits, piece, path, rl["segs"], rl["flat"])
    g.add(piece)
    g.notes["scalp_clearance_mm"] = {k: [round(v[0] * 1000, 1), round(v[1] * 1000, 1)] for k, v in
                                     HT.scalp_clearance(fits, g.m.V).items()}
    c = HT.headb(fits)
    g.uvparts = {0: ("cyl", c, c + np.array([0.0, 0.0, 0.2]), [0, -1, 0])}
    g.m.fa["part"][:] = 0
    g.shape_alias = {"sex_head": "m"}
    return g


def roll_path(fits, rl):
    """The centre line (reference fit) and radii of a wound roll: rl['turns'] turns from rl['start'] deg (0 the front,
    + the wearer's left) round the head on a helix."""
    bv = fits.bvh[REF]
    hb = HT.headb(fits)
    cx, cy = 0.0, hb[1] - 0.018
    n = max(int(rl["turns"] * rl["per_turn"]), 8)
    s = np.linspace(0.0, rl["turns"], n)
    th = np.radians(rl["start"]) + 2.0 * np.pi * s
    rng = np.random.default_rng(7)
    knots = max(int(rl["turns"] * 3) + 2, 4)
    noise = lambda: np.interp(s, np.linspace(0, rl["turns"], knots), rng.normal(0.0, 1.0, knots))
    wob = noise() * rl.get("wobble", 0.0)
    rvar = 1.0 + np.clip(noise(), -1.5, 1.5) * rl.get("r_var", 0.0)
    zvar = noise() * rl.get("lift_var", 0.0)
    P = []
    R = []
    for i in range(n):
        z = rl["z0"] + rl["rise"] * s[i] + rl["tilt"] * (1.0 - math.cos(th[i])) * 0.5 + zvar[i]
        d = np.array([math.sin(th[i]), -math.cos(th[i]), 0.0])
        o = np.array([cx, cy, z])
        loc, _, _, _ = bv.ray_cast(Vector(o + d * 0.3), Vector(-d), 0.3)
        r_scalp = float((np.array(loc) - o) @ d) if loc is not None else 0.0
        a = rl["a0"] + rl["grow"] * s[i]
        b = a * rl["ab"]
        r_e = 1.0 / math.sqrt((math.sin(th[i]) / max(a, 1e-4)) ** 2 + (math.cos(th[i]) / max(b, 1e-4)) ** 2) if a > 0 else 0.0
        r = max(r_e + wob[i], r_scalp + rl["ease"] + rl["r"] * rl.get("flat", 1.0))
        P.append(o + d * r)
        R.append(rl["r"] * rvar[i])
    P = np.array(P)
    R = np.array(R)
    if rl["turns"] < 1.01 and rl["rise"] == 0.0:
        # one closed band: the last point back onto the first
        P = np.concatenate([P, P[:1]])
        R = np.concatenate([R, R[:1]])
    else:
        # the end tucked in: the last points drawn in under the turn below
        k = min(6, len(P) // 4)
        t = np.linspace(0.0, 1.0, k)
        P[-k:] = P[-k:] + np.stack([-(P[-k:, 0] - cx), -(P[-k:, 1] - cy), np.zeros(k)], 1) * 0.10 * t[:, None] - \
            np.array([0.0, 0.0, 1.0]) * (rl["r"] * 0.6) * t[:, None]
        R[-k:] = R[-k:] * (1.0 - 0.35 * t)
    return P, R


def _flatten_roll(fits, piece, path, segs, flat):
    """A tube made a flat band (its cross-section squashed toward the head by `flat`): a folded cloth band."""
    hb = HT.headb(fits)
    aff = HT.head_affines(fits)
    k = len(path)
    for fit in piece.V:
        V = piece.V[fit]
        C = HT.apply_affine(aff, path, fit)
        c = HT.apply_affine(aff, np.array([[0.0, hb[1] - 0.018, hb[2]]]), fit)[0]
        for i in range(k):
            ring = V[i * segs:(i + 1) * segs]
            out = unit(np.array([C[i][0] - c[0], C[i][1] - c[1], 0.0]))
            q = ring - C[i]
            radial = (q @ out)[:, None] * out
            V[i * segs:(i + 1) * segs] = C[i] + (q - radial) + radial * flat
        piece.V[fit] = V
    piece.recompute_normals()


# ======================================================================================================================
# rigid hat profiles (rigid_hat beside hats.TRICORNE / ROUND_HAT): bodies of revolution in the hat frame
# ======================================================================================================================
DOME_FINIAL = {"profile": "dome", "R": 0.215, "H": 0.135, "rim_z": -0.012, "exp": 2.4, "thick": 0.005, "segs": 40,
               "rings": 9, "tilt": -4.0, "lower": 0.0,
               "band": {"a": 0.083, "b": 0.105, "z": (-0.006, 0.020)},     # the inner head band (zone 1)
               "finial": {"r": 0.012, "h": 0.040},                         # the knob or spike on top (zone 2)
               "chin": {"w": 0.007, "lift": 0.007}}                         # a chin strap (zone 3), None: none
CONE = _style(DOME_FINIAL, {"profile": "cone", "R": 0.235, "H": 0.165, "rim_z": -0.006, "exp": 1.0, "finial": None})
UMBRELLA = _style(DOME_FINIAL, {"profile": "cone", "R": 0.30, "H": 0.10, "rim_z": -0.004, "exp": 0.85, "finial": None})
TALL_CROWN = {"profile": "crown", "a": 0.086, "b": 0.107, "h": 0.17, "taper": 0.88, "top": "flat", "thick": 0.004,
              "segs": 36, "rings": 6, "tilt": -6.0, "lower": 0.012,
              "band": {"h": 0.050, "out": 0.007, "zone": 1},                 # a lambskin band round its foot
              "finial": None, "chin": None}


def _lathe_sheet(prof, segs, thick, zone_of_ring=None):
    """A double-sided body of revolution (rings from the rim inward to the apex) with a rim: (V, F, zone per face)."""
    th = 2.0 * np.pi * np.arange(segs) / segs
    ca, sa = np.cos(th), np.sin(th)
    V, F, Z = [], [], []
    rows = []
    for k, (r, z) in enumerate(prof):
        if r <= 1e-6:
            rows.append([len(V)])
            V.append([0.0, 0.0, z])
        else:
            rows.append(list(range(len(V), len(V) + segs)))
            V += np.stack([r * ca, r * sa, np.full(segs, z)], 1).tolist()
    top = []
    for k in range(len(rows) - 1):
        a, b = rows[k], rows[k + 1]
        for j in range(segs):
            j2 = (j + 1) % segs
            if len(b) == 1:
                top.append((a[j], a[j2], b[0]))
            else:
                top += [(a[j], a[j2], b[j2]), (a[j], b[j2], b[j])]
    top = np.array(top, int)
    P = np.array(V, float)
    nrm = vertex_normals(P, top)
    if (nrm[:, 2] < 0).mean() > 0.5:
        top = top[:, ::-1].copy()
        nrm = vertex_normals(P, top)
    under = P - nrm * thick
    n0 = len(P)
    Vall = np.concatenate([P, under])
    Fu = top[:, ::-1] + n0
    rim = []
    o = rows[0]
    for j in range(segs):
        j2 = (j + 1) % segs
        rim += [(o[j], o[j] + n0, o[j2] + n0), (o[j], o[j2] + n0, o[j2])]
    F = np.concatenate([top, Fu, np.array(rim, int)])
    return Vall, F


def lathe_hat(g, st):
    """A rigid hat of revolution on headb (DOME_FINIAL, CONE, UMBRELLA, TALL_CROWN): zones 0 the body, 1 the band, 2 the
    finial, 3 the chin strap; placed and weighted like hats.rigid_hat."""
    fits = g.fits
    C, Rm = HT.hat_frame(fits, st)
    parts = []                                       # (V, F, zone, part)
    if st["profile"] in ("dome", "cone"):
        Rr, H, z0, ex = st["R"], st["H"], st["rim_z"], st["exp"]
        rs = np.concatenate([np.linspace(Rr, 0.0, st["rings"] + 1)])
        prof = [(r, z0 + (H - z0) * (1.0 - (r / Rr) ** ex)) for r in rs]
        if st["profile"] == "cone":
            prof = [(r, z0 + (H - z0) * (1.0 - r / Rr) ** (1.0 / max(ex, 1e-3))) for r in rs]
        V, F = _lathe_sheet(prof, st["segs"], st["thick"])
        parts.append((V, F, 0, 5))
        bd = st.get("band")
        if bd:
            a, b = bd["a"], bd["b"]
            th = 2.0 * np.pi * np.arange(st["segs"]) / st["segs"]
            ring = lambda zz, sc=1.0: np.stack([a * sc * np.cos(th), b * sc * np.sin(th), np.full(len(th), zz)], 1)
            Vb = np.concatenate([ring(bd["z"][0]), ring(bd["z"][1]), ring(bd["z"][0], 1.04), ring(bd["z"][1], 1.04)])
            n = len(th)
            Fb = []
            for j in range(n):
                j2 = (j + 1) % n
                Fb += [(j, j2, n + j2), (j, n + j2, n + j), (2 * n + j, 3 * n + j2, 2 * n + j2), (2 * n + j, 3 * n + j, 3 * n + j2),
                       (n + j, n + j2, 3 * n + j2), (n + j, 3 * n + j2, 3 * n + j)]
            parts.append((Vb, np.array(Fb, int), 1, 0))
        fn = st.get("finial")
        if fn:
            prof_f = [(fn["r"] * 0.6, 0.0), (fn["r"], fn["h"] * 0.3), (fn["r"] * 0.8, fn["h"] * 0.65), (0.0, fn["h"])]
            Vf, Ff = HW.lathe(prof_f, segs=10)
            Vf = Vf + np.array([0.0, 0.0, H - 0.004])
            parts.append((Vf, Ff, 2, 6))
    else:
        a, b, h, tp = st["a"], st["b"], st["h"], st["taper"]
        th = 2.0 * np.pi * np.arange(st["segs"]) / st["segs"]
        rows = []
        for k in range(st["rings"] + 1):
            f = k / st["rings"]
            sc = 1.0 + (tp - 1.0) * f
            rows.append(np.stack([a * sc * np.cos(th), b * sc * np.sin(th), np.full(len(th), h * f)], 1))
        top_sc = tp * (0.96 if st["top"] == "flat" else 0.7)
        rows.append(np.stack([a * top_sc * np.cos(th), b * top_sc * np.sin(th), np.full(len(th), h + (0.004 if st["top"] == "flat" else 0.03))], 1))
        Vw = np.concatenate(rows + [np.array([[0.0, 0.0, h + (0.005 if st["top"] == "flat" else 0.04)]])])
        n = len(th)
        Fw = []
        for k in range(len(rows) - 1):
            for j in range(n):
                j2 = (j + 1) % n
                Fw += [(k * n + j, k * n + j2, (k + 1) * n + j2), (k * n + j, (k + 1) * n + j2, (k + 1) * n + j)]
        apex = len(Vw) - 1
        last = (len(rows) - 1) * n
        for j in range(n):
            Fw.append((last + j, last + (j + 1) % n, apex))
        parts.append((Vw, np.array(Fw, int), 0, 0))
        bd = st.get("band")
        if bd:
            hb = bd["h"]
            out = bd["out"]
            rr = []
            for zz, o in ((0.0, out * 0.6), (0.006, out), (hb - 0.006, out), (hb, out * 0.6), (hb + 0.002, 0.0)):
                sc = 1.0 + (tp - 1.0) * (zz / h)
                rr.append(np.stack([(a * sc + o) * np.cos(th), (b * sc + o) * np.sin(th), np.full(n, zz - 0.002)], 1))
            Vb = np.concatenate(rr)
            Fb = []
            for k in range(len(rr) - 1):
                for j in range(n):
                    j2 = (j + 1) % n
                    Fb += [(k * n + j, k * n + j2, (k + 1) * n + j2), (k * n + j, (k + 1) * n + j2, (k + 1) * n + j)]
            parts.append((Vb, np.array(Fb, int), bd.get("zone", 1), 0))
    Vs, Fs, Zs, Ps, off = [], [], [], [], 0
    for V, F, z, p in parts:
        Vs.append(C + V @ Rm.T)
        Fs.append(F + off)
        Zs.append(np.full(len(F), z))
        Ps.append(np.full(len(F), p))
        off += len(V)
    if st.get("chin"):
        Vc, Fc = _chin_strap(fits, st, C, Rm)
        Vs.append(Vc)
        Fs.append(Fc + off)
        Zs.append(np.full(len(Fc), 3))
        Ps.append(np.full(len(Fc), 6))
    m = HT.rigid_mesh(fits, {"W": None}, np.concatenate(Vs), np.concatenate(Fs), np.concatenate(Zs), np.concatenate(Ps))
    g.m = m
    up = Rm @ np.array([0.0, 0.0, 1.0])
    g.uvparts = {0: ("cyl", C, C + up * 0.1, Rm @ np.array([0.0, -1.0, 0.0])),
                 5: ("planar", C, Rm @ np.array([1.0, 0.0, 0.0]), Rm @ np.array([0.0, 1.0, 0.0])),
                 6: ("planar", C, Rm @ np.array([1.0, 0.0, 0.0]), Rm @ np.array([0.0, 0.0, 1.0]))}
    g.shape_alias = {"sex_head": "m"}
    g.notes["scalp_clearance_mm"] = {k: [round(v[0] * 1000, 1), round(v[1] * 1000, 1)] for k, v in
                                     HT.scalp_clearance(fits, g.m.V).items()}
    return g


def _chin_strap(fits, st, C, Rm):
    """A thin strap from the band at each temple down under the chin (reference fit), kept `lift` off the skin."""
    ch = st["chin"]
    bd = st.get("band") or {"a": 0.083, "b": 0.105, "z": (0.0, 0.02)}
    hb = HT.headb(fits)
    pts = []
    for t in np.linspace(0.0, 1.0, 13):
        a = np.pi * t                                 # from the left temple (0) under the chin to the right (pi)
        x = math.cos(a) * bd["a"] * 0.96
        zl = (bd["z"][0]) - 0.20 * math.sin(a) ** 0.8
        yl = -0.004 - 0.075 * math.sin(a) ** 1.4
        pts.append(C + Rm @ np.array([x, yl, zl]))
    P = np.array(pts)
    for _ in range(6):
        d, loc, nrm = fits.dist(REF, P)
        short = ch["lift"] - d
        P = P + nrm * np.maximum(short, 0.0)[:, None]
    w = ch["w"]
    T = unit(np.gradient(P, axis=0))
    out = unit(P - (hb + np.array([0.0, -0.01, -0.03])))
    side = unit(np.cross(T, out))
    V = np.concatenate([P - side * w / 2, P + side * w / 2, P - side * w / 2 - out * 0.0012, P + side * w / 2 - out * 0.0012])
    k = len(P)
    F = []
    for i in range(k - 1):
        F += [(i, i + 1, k + i + 1), (i, k + i + 1, k + i),
              (2 * k + i, 3 * k + i + 1, 2 * k + i + 1), (2 * k + i, 3 * k + i, 3 * k + i + 1)]
    return V, np.array(F, int)


# ======================================================================================================================
# stockings with gartering (hose)
# ======================================================================================================================
HOSE = {"top": 0.46, "ease": 0.0034, "segs": 16,
        "cuff": {"len": 0.040, "h": 0.0024},                 # the top turned down: a band `len` deep, raised h
        "garter": {"z": (0.414, 0.428), "h": 0.0032, "ends": {"len": 0.060, "w": 0.011, "deg": 70.0}},
        "zones": {"cloth": 0, "garter": 1}}


def hose(g, st=None):
    """Hose (HOSE): cloth2.feet.SockTube from the toes to `top`, the cuff turned down, the garter tied round under it
    with its two ends hanging at the outer side of the leg."""
    from cloth2 import feet as FT
    from cloth2 import tailor as TL
    from cloth2.garments import stockings as SK
    st = _style(HOSE, st)
    Z = st["zones"]
    fits = g.fits
    g.m = FT.both(fits, lambda s: FT.SockTube(fits, s, top=st["top"], segs=st["segs"], step_leg=0.025, step_foot=0.0120,
                                              cap=4).mesh(st["ease"], foot_smooth=6, gap=0.0021))
    g.fits.clear(g.m, np.where(g.m.A["foot"] > 0.5, SK.FOOT_GAP, -1.0))
    SK._unfold(g)
    cf = st["cuff"]
    if cf:
        g.raised(TL.band_select(g, st["top"] - cf["len"], st["top"] + 0.01), cf["h"], Z["cloth"])
    gt = st["garter"]
    if gt:
        g.raised(TL.band_select(g, *gt["z"]), gt["h"], Z["garter"])
        en = gt.get("ends")
        if en:
            J = fits.J
            for s in ("l", "r"):
                sg = 1.0 if s == "l" else -1.0
                zc = 0.5 * (gt["z"][0] + gt["z"][1])
                k = J[s + "_knee"]
                a = np.radians(en["deg"])
                for dx, ln in ((-0.008, en["len"]), (0.008, en["len"] * 0.8)):
                    d = np.array([sg * math.sin(a), -math.cos(a), 0.0])
                    p0 = np.array([k[0], k[1], zc]) + d * 0.07 + np.array([0.0, dx, 0.0])
                    way = [p0, p0 + np.array([0.0, dx * 0.5, -ln * 0.5]), p0 + np.array([0.0, dx, -ln])]
                    g.strap(way, en["w"], st["ease"] + cf["h"] + 0.003 if cf else st["ease"] + 0.004, Z["garter"], step=0.01)
    SK._uv(g)
    # the leg's UV down to the shoe's top (the foot's own cylinder met the leg's at the heel bend, above the shoe, and a
    # pattern broke into shards there)
    c = g.m.face_centres()
    above = c[:, 2] > st.get("leg_uv_to", 0.10)
    g.m.fa["part"][above & (g.m.fa["part"] == 5)] = 3
    g.m.fa["part"][above & (g.m.fa["part"] == 6)] = 4
    top = st["top"]
    g.hem = lambda m: m.boundary()[1] & (m.V[REF][:, 2] > top - 0.008)
    return g


# ======================================================================================================================
# the sash wound several times
# ======================================================================================================================
SASH_WOUND = {"z": (0.94, 1.09), "turns": 3, "height": 0.072, "lift": 0.026, "step": 0.0032, "start": 52.0,
              "end": None,                                    # {"len": 0.12, "w": 0.07}: a short end hanging at the tuck
              "over": (), "over_gap": 0.004, "zones": {"cloth": 0, "fringe": 3}}


def wound_sash(g, st=None):
    """A sash wound `turns` times round the waist (SASH_WOUND): each turn a band `height` tall on a helix from z0 up to
    z1, starting and ending at `start` deg (+ the wearer's left: the tuck), lying `step` over the turn under it."""
    st = _style(SASH_WOUND, st)
    Z = st["zones"]
    fits = g.fits
    z0, z1 = st["z"]
    n = int(st["turns"])
    H = st["height"]
    climb = max(z1 - z0 - H, 0.0)
    pieces = []
    prev = None
    for i in range(n):
        sub = G.Garment(fits, g.spec)
        sub.shell(G.TORSO)
        sub.top(z1 + 0.02).bottom(z0 - 0.02)
        # open at the tuck: a narrow wedge cut out at `start`
        P = sub.P
        dth = wrap_deg(theta_signed(P) - st["start"])
        f = np.abs(np.radians(dth)) * 0.16 - 0.0012 + BIG_FIELD * smoothstep(60.0, 90.0, np.abs(dth))
        sub.m = sub.m.clip(f, 0.0)

        def lo(P, i=i):
            u = (wrap_deg(theta_signed(P) - st["start"]) % 360.0) / 360.0
            return z0 + climb * (i + u) / n
        sub.m = TR.drop_small(sub.m.clip(sub.P[:, 2] - lo(sub.P), 0.0), 8)
        sub.m = TR.drop_small(sub.m.clip(lo(sub.P) + H - sub.P[:, 2], 0.0), 8)
        sub.m.offset(st["lift"] + st["step"] * i, vertical=0.0)
        sub.m.fa["zone"][:] = Z["cloth"]
        sub.m.fa["part"][:] = 0
        fits.clear(sub.m, 0.002)
        if st["over"]:
            sub.over(st["over"], st["over_gap"])
        if prev is not None:
            obs = fits.obstacles([prev])
            fits.clear(sub.m, st["step"] * 0.6, surface=obs, max_push=0.02)
        prev = sub.m if prev is None else concat([prev, sub.m])
        pieces.append(sub.m)
    g.m = concat(pieces)
    if st["end"]:
        e = st["end"]
        P = g.around_points(z0 + climb + H * 0.5, np.array([st["start"] + 6.0]))
        if len(P):
            k = P[0]
            way = [k + np.array([0.0, -0.006, 0.0]), k + np.array([0.004, -0.012, -e["len"] * 0.5]),
                   k + np.array([0.008, -0.014, -e["len"]])]
            g.strap(way, e["w"], st["lift"] + st["step"] * n + 0.004, Z["cloth"], step=0.012,
                    width_fn=lambda s: e["w"] * (1.0 - 0.2 * s))
    g.uv(axis_top=1.1, axis_bottom=0.9, limbs=())
    arc_uv(g)
    return g
