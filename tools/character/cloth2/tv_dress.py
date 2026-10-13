"""cloth2 Thủy Vân dress: the recipe types the six human-shaped peoples need beyond cloth2.dress (2026-10-06;
peoples_design.md section 2.9). Same idiom as cloth2.dress: each type is a style dict of documented defaults
(override any key per garment) and one call, re-exported by cloth2.recipes:

  leg_wraps(g, st)       a cloth strip wound on a helix down each shin from `top` to the ankle (each turn shingled over
                         the one below it, as wrapping from the ankle up lays it), a cord crossing over it `crosses`
                         times, a knot under the knee with two hanging ends. Zones: 0 the strip, 1 the cord. Slot
                         legs.over
  sandals(g, st)         a sole slab under each foot (feet.SockTube's downward faces flattened, thickened, a welt) and
                         straps kept from the same tube: across the foot, round the heel, a toe loop, ankle cords
                         crossing twice. Styles ROPE_SANDALS, TOE_SANDALS, HEAVY_SANDALS, SLIPPERS (closed toe, ties).
                         Zones: 0 the sole, 1 the straps / cords
  fringe_mantle(g, st)   a shoulder capelet (cloth2.dress.cloak's envelope, the arms inside) whose hem is cut into
                         strips 3-6 cm wide and 8-15 cm long (ragged: each strip its own length, every other strip
                         standing a little proud), a fur ruff rolled round the neck, feathers tucked at one shoulder,
                         `tiers` 1-2 (the second a longer layer under the first). Zones: 0 the cloth, 1 the fringe
                         strips, 2 the fur ruff, 3 the feathers
  dangles(g, strings)    hardware: strings of rigid pieces (beads, discs, teeth, tassels, shells, coins, plaques,
                         feathers) hung straight down from a point of the garment; above the waist each rides its anchor,
                         below it each piece goes over to the skirt panels (parts.skirt_weights) so it swings with the
                         skirts; every piece is pushed clear of the garment and the body in every fit
  carry(g, st)           hardware: a back basket (a tapered lathe of woven cane with a rim and ribs; TALL_BASKET,
                         ROUND_BASKET with a lid) or a carry frame (CARRY_FRAME: an A-frame of poles, a shelf, a dressed
                         block lashed on) on two shoulder straps, rigid on the upper back. Zones: 0 the cane / poles, 1
                         the rim, ribs, bars and straps, 2 the block. Slot accessories.shoulder
  hip_panels(g, st)      layered hanging panels over a wrapped skirt: woven panels of the skirt's own cut (a longer
                         wrap_skirt clipped to an angle window), each with a ragged hem, fitted over the skirt

Prims for the hardware (the local frame of cloth2.hardware: x across, y up, z out of the surface): bead, disc_bead,
tooth, tassel, shell, coin, feather, chisel, jade_disc, mark_disc (a disc carrying our own mark: one ring and straight
cuts), plaque.

Anyone may wear any garment built from these: sets order the Outfit tab, they do not lock dress to a people.
"""

import copy
import math

import numpy as np

from cloth2 import drift as D
from cloth2 import feet as FT
from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import trims as TR
from cloth2.mesh import BIG_FIELD, REF, Mesh, concat, smoothstep, unit, vertex_normals
from cloth2.parts import skirt_weights


def _style(base, st):
    s = copy.deepcopy(base)
    s.update(st or {})
    return s


def _wrap(a):
    return (np.asarray(a, float) + 180.0) % 360.0 - 180.0


def _theta(P):
    P = np.atleast_2d(P)
    return np.degrees(np.arctan2(P[:, 0], -P[:, 1]))


# ======================================================================================================================
# prims (local frame: x across, y up, z out)
# ======================================================================================================================
def _axis_y(prim):
    """A lathe made round local z turned to hang along local -y (its z = 0 end at the top)."""
    V, F = prim
    return np.stack([V[:, 0], -V[:, 2], V[:, 1]], 1), F


def bead(r=0.006):
    return HW.ellipsoid(r, r, r * 0.9, segs=8, rings=4)


def disc_bead(r=0.008, h=0.004):
    return _axis_y(HW.lathe([(r * 0.4, 0.0), (r, h * 0.3), (r, h * 0.7), (r * 0.4, h), (0.0, h)], segs=10))


def tooth(length=0.045, r=0.007, curve=0.010):
    """A tooth or claw: a cone hanging point down, its tip curving outward."""
    V, F = _axis_y(HW.lathe([(r * 0.7, 0.0), (r, length * 0.15), (r * 0.75, length * 0.55), (r * 0.25, length * 0.9),
                             (0.0, length)], segs=8))
    t = np.clip(-V[:, 1] / length, 0, 1)
    V = V.copy()
    V[:, 2] += curve * t ** 2
    return V, F


def tassel(length=0.07, r=0.012):
    """A tassel: a bound head and a flaring skirt of cord, closed at the bottom (chunky, one piece)."""
    return _axis_y(HW.lathe([(r * 0.35, 0.0), (r * 0.55, length * 0.08), (r * 0.5, length * 0.22),
                             (r * 0.7, length * 0.28), (r, length * 0.8), (r * 1.05, length * 0.97),
                             (0.0, length)], segs=10))


def shell(r=0.016):
    """A scallop shell facing out: a flattened half-dome with ribs (straight radial cuts)."""
    segs = 12
    V, F = HW.lathe([(r, 0.0), (r * 0.8, r * 0.25), (r * 0.45, r * 0.42), (0.0, r * 0.48)], segs=segs)
    V = V.copy()
    ang = np.arctan2(V[:, 1], V[:, 0])
    V[:, 2] *= 1.0 + 0.18 * np.cos(ang * 7)
    V[:, 1] *= 0.92
    return V, F


def coin(r=0.011, h=0.0022):
    return HW.disc(r, h, segs=12)


def feather(length=0.12, w=0.022, t=0.003):
    """A feather as a chunky flattened leaf hanging tip down (no alpha card: it reads in any shader)."""
    V, F = HW.ellipsoid(w / 2, length / 2, t, segs=10, rings=5)
    V = V.copy()
    V[:, 1] -= length / 2
    V[:, 2] += 0.004 * (1 - (V[:, 1] / -length - 0.5) ** 2 * 4)
    return V, F


def mark_disc(r=0.045, h=0.006):
    """A cast disc with our own mark: one raised ring and three straight bars (a pass over the ridge): no Hán, no
    swirl."""
    parts = [HW.disc(r, h, segs=20), HW.translate(HW.ring(r * 0.66, 0.0032, 20, 4), (0.0, 0.0, h)),
             HW.translate(HW.box(r * 0.42, 0.0035, 0.0018), (0.0, 0.0, h)),
             HW.translate(HW.box(0.0035, r * 0.30, 0.0018), (-r * 0.18, -r * 0.16, h)),
             HW.translate(HW.box(0.0035, r * 0.30, 0.0018), (r * 0.18, -r * 0.16, h))]
    return HW.merge(parts)


def plaque(w=0.06, h=0.04, t=0.006):
    return HW.box(w / 2, h / 2, t / 2)


def chisel(length=0.13, w=0.011):
    """A mason's chisel hanging blade down: a square shaft, a struck head, a wedge blade."""
    head = HW.translate(HW.box(w * 0.75, 0.008, w * 0.75 / 2, z0=-w * 0.75 / 2), (0.0, -0.008, 0.0))
    shaft = HW.translate(HW.box(w / 2, length * 0.35, w / 2 / 2, z0=-w / 4), (0.0, -0.016 - length * 0.35, 0.0))
    V, F = HW.lathe([(w * 0.5, 0.0), (w * 0.62, length * 0.1), (w * 0.1, length * 0.28), (0.0, length * 0.3)], segs=4)
    V = np.stack([V[:, 0], -V[:, 2], V[:, 1] * 0.5], 1) - np.array([0.0, 0.016 + length * 0.7, 0.0])
    return HW.merge([head, shaft, (V, F)])


def jade_disc(r=0.024, h=0.006):
    """A jade disc with a hole (one ring: the pendant at the sash)."""
    return HW.ring(r * 0.62, r * 0.38, 16, 6, z0=h * 0.5)


PRIMS = {"bead": bead, "disc_bead": disc_bead, "tooth": tooth, "tassel": tassel, "shell": shell, "coin": coin,
         "chisel": chisel, "jade_disc": jade_disc,
         "feather": feather, "mark_disc": mark_disc, "plaque": plaque}


def prim_height(V):
    return float(V[:, 1].max() - V[:, 1].min())


# ======================================================================================================================
# dangles: strings of rigid pieces
# ======================================================================================================================
WAIST_Z = 0.95                       # above it a piece rides its anchor's weights; below, the skirt panels'


def dangles(g, strings, obstacles=(), lift=0.008, part=9):
    """Strings of rigid pieces hung straight down from points of the garment `g.m` (reference fit), joined to it.

    strings: [{"at": (x, y, z) point near the garment, "pieces": [(prim name, kwargs dict, zone), ...], "gap": m
    between pieces, "cord": (zone, width) or None (a thin cord strip down the string), "sway": deg (a little turn
    about the vertical so a row of strings is not a fence)}]. Each piece hangs below the one above; in every fit it
    sits under its anchor's place in that fit and is pushed out of the garment, the obstacle garments and the body by
    `lift`. Weights: the anchor's above WAIST_Z, the skirt panels' below it (parts.skirt_weights)."""
    fits = g.fits
    m = g.m
    obst = fits.obstacles([m] + list(obstacles)) if m is not None else None
    pieces = []
    for st in strings:
        a = np.asarray(st["at"], float)
        b = HW.Binding(m, a[None])
        anc = {k: b.at(m, k)[0][0] for k in m.V}
        w_anchor = b.weights(m)[0]
        y = 0.0
        gap = st.get("gap", 0.002)
        spin = math.radians(st.get("sway", 0.0))
        cs, sn = math.cos(spin), math.sin(spin)
        for name, kw, zone in st["pieces"]:
            Vl, Fl = PRIMS[name](**(kw or {}))
            top = float(Vl[:, 1].max())
            Vl = Vl - np.array([0.0, top, 0.0])          # hang from its top
            hgt = prim_height(Vl)
            # local -> world: x across (world x turned by sway), y up (world z), z out (world -y, the front)
            out_dir = unit(np.array([anc[REF][0], anc[REF][1], 0.0]))
            if np.linalg.norm(out_dir) < 1e-6:
                out_dir = np.array([0.0, -1.0, 0.0])
            across = np.cross(np.array([0.0, 0.0, 1.0]), out_dir)
            ax = across * cs + out_dir * sn
            az = out_dir * cs - across * sn
            Rm = np.stack([ax, np.array([0.0, 0.0, 1.0]), az], 1)
            c_off = np.array([0.0, 0.0, -y])
            V = {}
            for k in m.V:
                c = anc[k] + c_off + out_dir * lift
                # pushed clear: of the garment and the obstacles, and of the body
                for _ in range(3):
                    probe = c + Rm @ np.array([0.0, -hgt / 2, 0.0])
                    if obst is not None and k in obst:
                        d, loc, nrm = fits.dist(k, probe[None], obst)
                        if d[0] < lift:
                            c = c + nrm[0] * (lift - d[0])
                    d, loc, nrm = fits.dist(k, probe[None], "cloth")
                    if d[0] < lift + 0.004:
                        c = c + nrm[0] * (lift + 0.004 - d[0])
                V[k] = c + Vl @ Rm.T
            zc = V[REF][:, 2].mean()
            W1 = np.repeat(w_anchor[None], len(Vl), 0)
            if zc < WAIST_Z:
                W1 = skirt_weights(fits, V[REF], W1, WAIST_Z, G.SKIRT_Z_FULL)
            pieces.append(HW.piece_mesh(m, V, Fl, W1, int(b.face_attr(m, "region")[0]), zone, part))
            y += hgt + gap
        if st.get("cord"):
            zone, wd = st["cord"]
            path = np.array([anc[REF] + np.array([0.0, 0.0, -s]) for s in np.linspace(0.0, max(y - 0.004, 0.01), 6)])
            path = path + unit(np.array([anc[REF][0], anc[REF][1], 0.0]))[None] * (lift - 0.002)
            Vc = {}
            for k in m.V:
                d = anc[k] - anc[REF]
                Vc[k] = path + d
            k6 = len(path)
            sd = np.cross(np.array([0.0, 0.0, 1.0]), unit(np.array([anc[REF][0], anc[REF][1], 0.0])))
            VV = {k: np.concatenate([Vc[k] - sd * wd / 2, Vc[k] + sd * wd / 2]) for k in m.V}
            F = []
            for i in range(k6 - 1):
                F += [(i, i + 1, k6 + i + 1), (i, k6 + i + 1, k6 + i)]
            Wc = np.repeat(w_anchor[None], 2 * k6, 0)
            pieces.append(HW.piece_mesh(m, VV, np.array(F, int), Wc, int(b.face_attr(m, "region")[0]), zone, part))
    for p in pieces:
        g.add(p)
    return g


# ======================================================================================================================
# leg wraps
# ======================================================================================================================
LEG_WRAPS = {
    "top": 0.46, "bottom": 0.105,             # the wound strip from the knee to the ankle (m)
    "width": 0.068, "overlap": 0.30,          # the strip's width and how much of it each turn covers of the one below
    "lift": 0.004,                            # off the cloth surface before it is fitted over the garments under it
    "shingle": 0.0035,                        # each turn's lower edge stands this much prouder than its upper edge
    "bulge": 0.0015,                          # the strip's middle rounded out (a soft cloth, not a ribbon)
    "r0": 0.085,                              # the waypoints' radius round the leg's line (projected onto the surface)
    "step": 0.015,                            # path resolution (m)
    "cord": {"w": 0.0045, "crosses": 4, "lift": 0.003},   # a round cord crossing over the wraps (None: none)
    "tie": {"z": None, "len": 0.085, "w": 0.011},         # the knot under the knee (z None: the top) and its ends
    "over": (), "over_gap": 0.003,
    "zones": {"strip": 0, "cord": 1},
}


def _leg_line(fits, side, top, bottom):
    """Points on the middle of the leg's cross-sections from top to bottom (feet.SockTube's line)."""
    tube = FT.SockTube(fits, side, top=top + 0.04, segs=8, step_leg=0.02)
    P = tube.path[:tube.n_leg + 1]
    P = P[(P[:, 2] <= top + 0.045) & (P[:, 2] >= bottom - 0.04)]
    return P[np.argsort(-P[:, 2])]


def _centre_at(line, z):
    zs = line[::-1, 2]
    return np.array([np.interp(z, zs, line[::-1, 0]), np.interp(z, zs, line[::-1, 1]), z])


def shingle_strip(g, path, width, lift, shingle, bulge=0.0, zone=0, part=8, across=3):
    """A strip `width` wide along `path` (straps.SurfacePath), `lift` off the cloth surface, rigid across: its lower
    edge `shingle` prouder than its upper edge (it lies over the turn below), its middle rounded out by `bulge`."""
    from cloth2.straps import _template
    k = len(path)
    us = np.linspace(-0.5, 0.5, across)
    V = {}
    for fit in g.fits.V:
        p, n, t = path.at(fit)
        side = unit(np.cross(n, t))
        down = np.where((side[:, 2] < 0.0)[:, None], side, -side)       # the side toward the lower edge (u = +0.5)
        V[fit] = np.concatenate([p + n * (lift + shingle * (u + 0.5) + bulge * (1.0 - (2 * u) ** 2)) + down * (u * width)
                                 for u in us])
    F = []
    for j in range(across - 1):
        for i in range(k - 1):
            a, b, c, d = j * k + i, j * k + i + 1, (j + 1) * k + i + 1, (j + 1) * k + i
            F += [(a, b, c), (a, c, d)]
    F = np.array(F, int)
    P = V[REF]
    _, n0, _ = path.at(REF)
    fn = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    if ((fn * np.concatenate([n0] * across)[F[:, 0]]).sum(1) < 0).mean() > 0.5:
        F = F[:, ::-1].copy()
    W = np.concatenate([path.weights()] * across)
    A = {name: np.concatenate([v] * across) for name, v in path.limb_attrs().items()}
    region = g.fits.p_region[path.tri]
    reg_f = np.tile(np.repeat(region[:-1], 2), across - 1)
    return HW.piece_mesh(g.m if g.m is not None else _template(g), V, F, W, reg_f, zone, part, A)


def leg_wraps(g, st=None):
    """Leg wraps (LEG_WRAPS) on both shins: the shingled helix strip, the crossing cord, the knot and its ends."""
    from cloth2 import straps as SP
    st = _style(LEG_WRAPS, st)
    Z = st["zones"]
    fits = g.fits
    g.m = None
    top, bot, w = st["top"], st["bottom"], st["width"]
    pitch = w * (1.0 - st["overlap"])
    turns = (top - bot - w * 0.5) / pitch
    strips = []
    lines = {}
    for s in ("l", "r"):
        sg = 1.0 if s == "l" else -1.0
        line = _leg_line(fits, s, top, bot)
        lines[s] = line
        n = max(int(turns * 40), 40)
        u = np.linspace(0.0, 1.0, n)
        z = (bot + w * 0.25) + (top - bot - w * 0.5) * u
        psi = 2.0 * np.pi * turns * u * sg
        C = np.array([_centre_at(line, zz) for zz in z])
        way = C + st["r0"] * np.stack([np.sin(psi), -np.cos(psi), np.zeros(n)], 1)
        path = SP.surface_path(fits, way, st["step"])
        strips.append(shingle_strip(g, path, w, st["lift"], st["shingle"], st["bulge"], Z["strip"], part=8))
    g.m = concat(strips)
    if st["over"]:
        g.over(st["over"], st["over_gap"])
    base = g.m.copy()
    cd = st["cord"]
    if cd:
        for s in ("l", "r"):
            sg = 1.0 if s == "l" else -1.0
            line = lines[s]
            k_turns = max(cd["crosses"] / 2.0, 0.5)
            for hand in (1.0, -1.0):
                n = 44
                u = np.linspace(0.0, 1.0, n)
                z = (bot + 0.02) + (top - bot - 0.04) * u
                psi = hand * 2.0 * np.pi * k_turns * u * sg + (0.0 if hand > 0 else np.pi)
                C = np.array([_centre_at(line, zz) for zz in z])
                way = C + 0.12 * np.stack([np.sin(psi), -np.cos(psi), np.zeros(n)], 1)
                # onto the wraps: the nearest point of the strips from outside
                Pw, ok = HW.ray_points(base, way, C - way, 0.2)
                Pw = Pw[ok]
                if len(Pw) > 4:
                    D.tube_piece(_on(g, base), Pw, cd["w"], Z["cord"], part=8, segs=4,
                                 lift=st["shingle"] + cd["lift"])
    tie = st["tie"]
    if tie:
        zt = tie["z"] if tie["z"] is not None else top - 0.012
        for s in ("l", "r"):
            sg = 1.0 if s == "l" else -1.0
            c = _centre_at(lines[s], zt)
            o = c + np.array([sg * 0.12, -0.02, 0.0])
            P, ok = HW.ray_points(base, [o], [c - o], 0.2)
            if not ok[0]:
                continue
            k = P[0]
            g.m = concat([g.m] + [_rigid_on(g, base, k, HW.ellipsoid(0.013, 0.011, 0.008, segs=8, rings=4),
                                            Z["cord"], lift=st["shingle"] + 0.002)])
            for dx, ln in ((-0.006, tie["len"]), (0.008, tie["len"] * 0.8)):
                way = [k + np.array([0.0, dx, -0.006]), k + np.array([sg * 0.004, dx * 1.5, -ln * 0.5]),
                       k + np.array([sg * 0.008, dx * 2.0, -ln])]
                D.tube_piece(_on(g, base), np.array(_dense(way, 0.01)), tie["w"] * 0.45, Z["cord"], part=8,
                             segs=5, lift=st["shingle"] + 0.004)
    g.uv(axis_top=0.6, axis_bottom=0.0, limbs=("leg_l", "leg_r"))
    g.hem = lambda m: np.zeros(m.n, bool)
    return g


def _dense(way, step):
    P = np.asarray(way, float)
    seg = np.linalg.norm(np.diff(P, axis=0), axis=1)
    L = np.concatenate([[0.0], np.cumsum(seg)])
    n = max(int(L[-1] / step) + 1, 3)
    s = np.linspace(0, L[-1], n)
    return np.stack([np.interp(s, L, P[:, i]) for i in range(3)], 1)


class _On:
    """A stand-in Garment whose mesh is `m` (drift.tube_piece binds to g.m); the pieces go to the real garment."""

    def __init__(self, g, m):
        self.fits, self.m, self.spec, self._g = g.fits, m, g.spec, g

    def add(self, piece):
        self._g.add(piece)
        return self


def _on(g, m):
    return _On(g, m)


def _rigid_on(g, m, point, prim, zone, lift=0.0, up=(0.0, 0.0, 1.0)):
    b = HW.Binding(m, np.asarray(point, float)[None])
    return HW.rigid(m, b, prim, zone, up=up, lift=lift)


# ======================================================================================================================
# sandals
# ======================================================================================================================
SANDALS = {
    "style": "rope",
    "ease": 0.0032,                     # the straps' clearance over the skin
    "sole": {"z": -0.010, "h": 0.012, "edge": 0.006},   # the sole's underside (m), its thickness, how far it stands out
    "straps": [{"y": "ball", "dy": 0.012, "w": 0.018}, {"y": "instep", "dy": -0.035, "w": 0.020}],
    "heel": None,                       # {"z": (z0, z1)}: a strap round the back of the heel
    "toe": None,                        # {"w": m}: a loop round the big toe
    "cords": {"z": (0.055, 0.155), "w": 0.010, "turns": 1.0},   # ankle cords: two helices crossing twice
    "closed": None,                     # {"y_back": m}: a closed toe box back to y = ball + y_back (slippers)
    "zones": {"sole": 0, "strap": 1},
}
ROPE_SANDALS = SANDALS
TOE_SANDALS = _style(SANDALS, {"style": "toe", "straps": [{"y": "instep", "dy": -0.030, "w": 0.018}], "toe": {"w": 0.012},
                               "cords": None, "sole": {"z": -0.007, "h": 0.009, "edge": 0.005}})
HEAVY_SANDALS = _style(SANDALS, {"style": "heavy", "sole": {"z": -0.022, "h": 0.024, "edge": 0.008},
                                 "straps": [{"y": "ball", "dy": 0.010, "w": 0.026}, {"y": "instep", "dy": -0.034, "w": 0.030}],
                                 "heel": {"z": (0.030, 0.058)}, "cords": {"z": (0.06, 0.12), "w": 0.012, "turns": 0.5}})
SLIPPERS = _style(SANDALS, {"style": "slipper", "straps": [], "closed": {"y_back": 0.055}, "heel": {"z": (0.0, 0.045)},
                            "cords": {"z": (0.06, 0.13), "w": 0.007, "turns": 1.0}, "sole": {"z": -0.010, "h": 0.014,
                                                                                             "edge": 0.004}})


def sandals(g, st=None):
    """Sandals (SANDALS rope; TOE_SANDALS, HEAVY_SANDALS, SLIPPERS): one feet.SockTube per foot; the faces kept are
    the sole (rays pointing down: flattened onto the sole plane and thickened) and the straps (bands of the tube)."""
    st = _style(SANDALS, st)
    Z = st["zones"]
    fits = g.fits
    J = fits.J
    pieces = []
    for s in ("l", "r"):
        sg = 1.0 if s == "l" else -1.0
        tube = FT.SockTube(fits, s, top=0.17, segs=16, step_leg=0.011, step_foot=0.0095, cap=4)
        m = tube.mesh(st["ease"], foot_smooth=6)
        P = m.V[REF]
        down = FT.ray_down(m)
        foot = m.A["foot"]
        A, B = J[s + "_ankle"], J[s + "_ball"]
        rx, ry = m.A["ray_x"], m.A["ray_y"]
        psi = np.degrees(np.arctan2(sg * rx, -ry))          # 0 the front of the leg, + its outer side
        # the strap field: > 0 inside a strap
        f = np.full(m.n, -1.0)
        top_of_foot = (1.0 - smoothstep(0.35, 0.6, down)) * foot
        for sp in st["straps"]:
            y0 = (B[1] + sp["dy"]) if sp["y"] == "ball" else (A[1] + sp["dy"])
            band = sp["w"] / 2 - np.abs(P[:, 1] - y0)
            f = np.maximum(f, np.where(top_of_foot > 0.5, band * 20.0, -1.0))
        if st["heel"]:
            z0, z1 = st["heel"]["z"]
            band = np.minimum(P[:, 2] - z0, z1 - P[:, 2])
            behind = P[:, 1] > A[1] - 0.01
            f = np.maximum(f, np.where(behind & (down < 0.6), band * 20.0, -1.0))
        if st["toe"]:
            # a loop round the big toe: the inner front of the toes
            inner = (sg * (P[:, 0] - B[0])) < 0.0
            y0 = B[1] - 0.030
            band = st["toe"]["w"] / 2 - np.abs(P[:, 1] - y0)
            f = np.maximum(f, np.where(inner & (m.A["toe"] > 0.5), band * 20.0, -1.0))
        if st["closed"]:
            box = (B[1] + st["closed"]["y_back"]) - P[:, 1]
            f = np.maximum(f, np.where(foot > 0.5, box * 20.0, -1.0))
        cd = st["cords"]
        if cd:
            z0, z1 = cd["z"]
            on_leg = (foot < 0.5) & (P[:, 2] > z0 - 0.01) & (P[:, 2] < z1 + 0.01)
            for hand in (1.0, -1.0):
                ph = (P[:, 2] - z0) / max(z1 - z0, 1e-3) * cd["turns"] * 360.0 * hand + (0.0 if hand > 0 else 180.0)
                dd = np.abs(_wrap(psi - ph)) / 360.0 * 0.24          # ~ distance along the ring (m)
                band = cd["w"] / 2 - dd
                band = np.minimum(band, np.minimum(P[:, 2] - z0, z1 - P[:, 2]))
                f = np.maximum(f, np.where(on_leg, band * 20.0, -1.0))
        sole_f = (down - 0.5) * foot - (1.0 - foot)
        straps = m.clip(f, 0.0)
        straps = TR.drop_small(straps, 4)
        straps.fa["zone"][:] = Z["strap"]
        # the sole: the downward faces, flattened, pushed out into a welt, thickened
        sole = m.clip(sole_f, 0.0)
        sole = TR.drop_small(sole, 20)
        sole = _sole_slab(fits, sole, st["sole"], s)
        sole.fa["zone"][:] = Z["sole"]
        pieces += [straps, sole]
    g.m = concat(pieces)
    g.m.fa["part"][:] = 0
    left = g.m.V[REF][g.m.F].mean(1)[:, 0] > 0.0
    g.m.fa["part"] = np.where(left, 5, 6)
    g.uvparts = {5: ("planar", [0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [0.0, -1.0, 0.0]),
                 6: ("planar", [0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [0.0, -1.0, 0.0])}
    g.hem = lambda m: np.zeros(m.n, bool)
    return g


def _sole_slab(fits, sole, sd, side):
    """The sole faces made a slab: every vertex onto the plane z = sd["z"], the rim pushed out by sd["edge"] (along the
    horizontal ray), a rim grown up by sd["h"] and a top cap (facing up, under the foot)."""
    P0 = sole.V[REF]
    _, onb = sole.boundary()
    hr = np.stack([sole.A["ray_x"], sole.A["ray_y"], np.zeros(sole.n)], 1)
    hr = unit(hr)
    for k in sole.V:
        V = sole.V[k].copy()
        V[:, 2] = sd["z"]
        V = V + hr * (sd["edge"] * onb)[:, None]
        sole.V[k] = V
    # flatten the inner vertices a little toward the outline (a sole is flat, not a foot print)
    sole.recompute_normals()
    # faces down
    fn = np.cross(sole.V[REF][sole.F[:, 1]] - sole.V[REF][sole.F[:, 0]], sole.V[REF][sole.F[:, 2]] - sole.V[REF][sole.F[:, 0]])
    if (fn[:, 2] > 0).mean() > 0.5:
        sole.F = sole.F[:, ::-1].copy()
        sole.recompute_normals()
    rim = TR.extrude(sole, lambda P: np.ones(len(P), bool), lambda fit, P0, N0, s: np.broadcast_to(
        np.array([0.0, 0.0, sd["h"] * s]), P0.shape), rings=1, zone=0)
    cap = sole.copy()
    cap.V = {k: v + np.array([0.0, 0.0, sd["h"]]) for k, v in sole.V.items()}
    cap.F = cap.F[:, ::-1].copy()
    cap.recompute_normals()
    out = concat([sole, cap] + ([rim] if rim is not None else []))
    return out


# ======================================================================================================================
# the fringed mantle
# ======================================================================================================================
FRINGE_MANTLE = {
    "z_c": 1.22, "phi": (18.0, 90.0), "n_polar": 8, "z_step": 0.028, "cols": 150,
    "arms_inside": True,                      # the capelet lies on the upper arms (they come out under its hem)
    "front": [(1.45, 2.5), (1.25, 2.5), (1.15, 8.0), (0.0, 12.0)],   # the front edges' angle from the front by height
    "hem": (1.12, 1.05),                      # the strips' TOP (where the cut begins): front, back
    "fringe": {"len": (0.10, 0.19), "cols": 4, "gap_cols": 1, "seed": 5, "proud": 0.0045},
    "ease": 0.016, "drape": 0.004, "folds": (0.010, 11.0, 1.0), "flare": (0.035, 1.0), "smooth": 3,
    "neck_cut": (1.36, 1.40),
    "ruff": {"w": 0.055, "h": 0.022, "lump": 0.006},          # a fur ruff rolled round the neck edge (None: none)
    "feathers": {"theta": 66.0, "z": 1.29, "n": 3, "len": 0.19, "w": 0.034, "tilt": 45.0},   # tucked at the left
                                                                                            # shoulder (None: none)
    "tiers": 1, "tier2": {"drop": 0.10, "len": (0.10, 0.18)},  # a second, longer layer of strips under the first
    "clasp": None,
    "hang_from": 1.0,
    "over": (), "over_gap": 0.006,
    "zones": {"cloth": 0, "fringe": 1, "fur": 2, "feather": 3},
}


def _mantle_layer(g, st, hem_top, lens, seed, under):
    """One envelope layer: the capelet down to hem_top - max(lens), its lower part cut into strips."""
    fits = g.fits
    from cloth2 import dress as DR
    with_arms = DR.side_hits(fits, ("l", "r"), under)
    no_arms = DR.side_hits(fits, (), under)
    fr = st["fringe"]
    zmin = min(hem_top) - max(lens) - 0.04
    z_level = list(np.arange(st["z_c"] - 0.03, zmin, -st["z_step"]))
    rows = D.cape_rows(z_c=st["z_c"], phi=st["phi"], n_polar=st["n_polar"], z_rows=z_level)
    arms = [True] * st["n_polar"] + [st["arms_inside"] or z >= 1.08 for z in z_level]
    hits_by_row = [with_arms if a else no_arms for a in arms]
    ft = st["front"]
    fz = np.array([z for z, _ in ft], float)
    fd = np.array([d for _, d in ft], float)
    o = np.argsort(fz)
    e0 = float(fd.min())
    C = st["cols"]
    thetas = np.linspace(e0 - 1.0, 360.0 - e0 + 1.0, C)
    m, _ = D.envelope(g, rows, thetas, None, st["ease"], smooth=st["smooth"], hits_by_row=hits_by_row,
                      drape=st["drape"], folds=st["folds"], flare=st["flare"], weight_arms=arms)
    from cloth2 import dress as DR2
    DR2.envelope_uv(g, m, rows, C, seam=180.0, closed=False)
    P = m.V[REF]
    col = m.A["_col"].copy()
    th = m.A["_th"]
    # the strips: below the cut, every (cols + gap_cols)-th column of faces is cut away; each strip its own length
    per = fr["cols"] + fr["gap_cols"]
    a = np.abs(_wrap(_theta(P)))
    cut_top = hem_top[1] + (hem_top[0] - hem_top[1]) * np.clip((180.0 - a) / 180.0, 0.0, 1.0) ** 1.5
    rng = np.random.default_rng(seed)
    nstrip = C // per + 2
    L = rng.uniform(lens[0], lens[1], nstrip)
    grp = np.floor(np.maximum(col - 1, 0) / per).astype(int)
    fcol = m.A["_col"][m.F].min(1)
    fz_c = P[m.F].mean(1)[:, 2]
    fcut = cut_top[m.F].mean(1)
    gap_face = ((fcol.astype(int) % per) < fr["gap_cols"]) & (fz_c < fcut)
    m = m.faces_of(~gap_face)
    P = m.V[REF]
    col = m.A["_col"]
    grp = np.clip(np.floor(np.maximum(col - 1, 0) / per).astype(int), 0, nstrip - 1)
    a = np.abs(_wrap(_theta(P)))
    cut_top = hem_top[1] + (hem_top[0] - hem_top[1]) * np.clip((180.0 - a) / 180.0, 0.0, 1.0) ** 1.5
    # the strip's bottom: its own length below the cut, the corners a little rounded off (a cut strip, not a tooth)
    hem_v = cut_top - L[grp]
    m = m.clip(P[:, 2] - hem_v, 0.0)
    # the front edges
    th = m.A["_th"]
    ev = np.interp(m.V[REF][:, 2], fz[o], fd[o])
    m = m.clip(np.minimum(th - ev, 360.0 - ev - th), 0.0)
    P = m.V[REF]
    col = m.A["_col"]
    grp = np.clip(np.floor(np.maximum(col - 1, 0) / per).astype(int), 0, nstrip - 1)
    a = np.abs(_wrap(_theta(P)))
    cut_top = hem_top[1] + (hem_top[0] - hem_top[1]) * np.clip((180.0 - a) / 180.0, 0.0, 1.0) ** 1.5
    below = P[:, 2] < cut_top
    # every other strip a little prouder (the strips overlap like shingles, not a flat comb)
    proud = fr["proud"] * ((grp % 2) == 1) * smoothstep(0.0, 0.03, cut_top - P[:, 2])
    m.offset(proud, vertical=0.0)
    fc = m.face_centres()
    a_f = np.abs(_wrap(_theta(fc)))
    ct_f = hem_top[1] + (hem_top[0] - hem_top[1]) * np.clip((180.0 - a_f) / 180.0, 0.0, 1.0) ** 1.5
    m.fa["zone"][fc[:, 2] < ct_f] = st["zones"]["fringe"]
    if st.get("neck_cut"):
        nf, nb = st["neck_cut"]
        aa = np.abs(_wrap(_theta(m.V[REF])))
        m = TR.drop_small(m.clip(nf + (nb - nf) * (aa / 180.0) ** 1.5 - m.V[REF][:, 2], 0.0), 20)
    D.hang_weights(fits, m, st["hang_from"])
    return m


def fringe_mantle(g, st=None):
    """A fringed shoulder mantle (FRINGE_MANTLE): the capelet, its strips, the fur ruff, the feathers."""
    from cloth2 import dress as DR
    st = _style(FRINGE_MANTLE, st)
    Z = st["zones"]
    fits = g.fits
    under = DR.under_meshes(fits, st["over"])
    fr = st["fringe"]
    layers = []
    if st["tiers"] >= 2:
        t2 = st["tier2"]
        hem2 = (st["hem"][0] - t2["drop"], st["hem"][1] - t2["drop"])
        low = _mantle_layer(g, _style(st, {"ease": st["ease"] - 0.004}), hem2, t2["len"], fr["seed"] + 11, under)
        layers.append(low)
    top = _mantle_layer(g, st, st["hem"], fr["len"], fr["seed"], under)
    g.m = top
    D.drop_attrs(g.m)
    g.fits.clear(g.m, 0.003)
    if st["over"]:
        g.over(st["over"], st["over_gap"])
    if layers:
        low = layers[0]
        D.drop_attrs(low)
        fits.clear(low, 0.003)
        if st["over"]:
            obs = fits.obstacles(under)
            fits.clear(low, st["over_gap"], surface=obs, max_push=0.05)
        # the top layer over the lower one
        fits.clear(g.m, 0.005, surface=fits.obstacles([low]), max_push=0.04)
        g.m = concat([low, g.m])
    if st["ruff"]:
        rf = st["ruff"]
        nf = st["neck_cut"][0] if st.get("neck_cut") else 1.36
        g.edge_zone(Z["fur"], rf["w"], h=rf["h"], select=lambda P: P[:, 2] > nf - 0.06)
        # lumps: the fur's locks
        sel = g.m.fa["zone"] == Z["fur"]
        vs = np.unique(g.m.F[sel])
        rng = np.random.default_rng(3)
        th = _theta(g.m.V[REF][vs])
        lump = rf["lump"] * (0.5 + 0.5 * np.sin(np.radians(th) * 23.0 + rng.uniform(0, 6)))
        for k in g.m.V:
            n = g.m.N[k][vs]
            g.m.V[k][vs] = g.m.V[k][vs] + n * lump[:, None]
        g.m.recompute_normals()
        g.fits.clear(g.m, 0.004)
    if st["feathers"]:
        fe = st["feathers"]
        P = g.around_points(fe["z"], np.array([fe["theta"]]))
        if len(P):
            k0 = P[0]
            for i in range(fe["n"]):
                prim = _tilt_out(feather(fe["len"] * (1.0 - 0.15 * i), fe.get("w", 0.03), 0.004), fe.get("tilt", 35.0))
                up = (0.45 + 0.25 * i, 0.25, 1.0)          # leaning away from the head, a little back
                g.hardware([k0 + np.array([0.012 * i, 0.01 * i, 0.0])], _flip_up(prim), Z["feather"], up=up,
                           lift=0.006 + 0.004 * i)
    g.hem_below(min(st["hem"]) - 0.02)
    from cloth2 import dress as DR3
    DR3._cloth_uv(g)
    return g


def _tilt_out(prim, deg):
    """A hanging prim (y < 0 down) leaned out of the surface by `deg` (its tip away from the cloth)."""
    V, F = prim
    a = math.radians(deg)
    V = V.copy()
    y, z = V[:, 1].copy(), V[:, 2].copy()
    V[:, 1] = y * math.cos(a) + z * math.sin(a)
    V[:, 2] = -y * math.sin(a) + z * math.cos(a)
    return V, F


def _flip_up(prim):
    """A prim hanging down (y < 0) turned to stand up (a feather tucked in, its tip up)."""
    V, F = prim
    V = V.copy()
    V[:, 1] = -V[:, 1]
    return V, F[:, ::-1].copy()


# ======================================================================================================================
# carry: baskets on the back
# ======================================================================================================================
TALL_BASKET = {
    "kind": "tall", "h": 0.55, "r_top": 0.17, "r_bottom": 0.13, "segs": 18, "rings": 8, "wall": 0.010,
    "z_bottom": 0.86, "back_gap": 0.045,       # the basket's foot height and its room off the back
    "rim": {"r": 0.012}, "ribs": 4, "lid": None,
    "straps": {"w": 0.035, "lift": 0.012},
    "over": (), "over_gap": 0.005,
    "zones": {"cane": 0, "rim": 1},
}
ROUND_BASKET = _style(TALL_BASKET, {"kind": "round", "h": 0.30, "r_top": 0.15, "r_bottom": 0.12, "z_bottom": 0.98,
                                    "lid": {"h": 0.05}, "ribs": 0})
# the quarry hands' carry frame: an A-frame of poles on the back, a shelf at its foot, a dressed block lashed on
CARRY_FRAME = _style(TALL_BASKET, {"kind": "frame", "h": 0.78, "z_bottom": 0.70, "back_gap": 0.035,
                                   "frame": {"pole": 0.016, "spread": (0.30, 0.10), "shelf": 0.24,
                                             "block": (0.30, 0.24, 0.22), "lash": 0.006},
                                   "zones": {"cane": 0, "rim": 1, "block": 2}})


def _basket_prim(st):
    """The basket in the local frame (x across, y up the back, z out of it): a double wall of revolution round its own
    axis, a rolled rim, ribs, a lid. Returns parts [(V, F, zone)]."""
    h, r0, r1, wall = st["h"], st["r_bottom"], st["r_top"], st["wall"]
    n = st["rings"]
    belly = 1.0 if st["kind"] == "tall" else 1.12
    prof_out = []
    for i in range(n + 1):
        t = i / n
        r = r0 + (r1 - r0) * t
        r *= 1.0 + (belly - 1.0) * math.sin(math.pi * t)
        prof_out.append((r, h * t))
    prof_in = [(max(r - wall, 0.01), z) for r, z in prof_out[::-1]]
    prof = [(r0 * 0.6, 0.0)] + prof_out + prof_in + [(0.0, wall)]
    V, F = HW.lathe(prof, segs=st["segs"])
    V = V.copy()
    V[:, 0] -= 0.0
    parts = [(V, F, st["zones"]["cane"])]
    if st["rim"]:
        Vr, Fr = HW.ring(r1 - wall / 2, st["rim"]["r"], st["segs"], 6, z0=h)
        parts.append((Vr, Fr, st["zones"]["rim"]))
        Vb, Fb = HW.ring(r0 + 0.002, st["rim"]["r"] * 0.8, st["segs"], 6, z0=st["rim"]["r"] * 0.8)
        parts.append((Vb, Fb, st["zones"]["rim"]))
    for i in range(st["ribs"]):
        a = 2 * math.pi * (i + 0.5) / st["ribs"]
        path = [((r0 + (r1 - r0) * t) * (1.0 + (belly - 1.0) * math.sin(math.pi * t)) + 0.004, h * t)
                for t in np.linspace(0.0, 1.0, 7)]
        P = np.array([[r * math.cos(a), r * math.sin(a), z] for r, z in path])
        Vt, Ft = D._sweep(P, 0.006, segs=5)
        parts.append((Vt, Ft, st["zones"]["rim"]))
    if st["lid"]:
        lh = st["lid"]["h"]
        Vl, Fl = HW.lathe([(r1 + 0.008, h), (r1 + 0.004, h + lh * 0.4), (r1 * 0.6, h + lh * 0.85), (0.04, h + lh),
                           (0.0, h + lh)], segs=st["segs"])
        parts.append((Vl, Fl, st["zones"]["cane"]))
        Vk, Fk = HW.ring(0.02, 0.008, 10, 6, z0=h + lh + 0.008)
        parts.append((Vk, Fk, st["zones"]["rim"]))
    out = []
    rmax = max(r for r, _ in prof_out)
    for Vp, Fp, z in parts:
        # lathe axis (z) -> local y (up the back); its centre rmax + back_gap out of the surface
        Vq = np.stack([Vp[:, 0], Vp[:, 2], Vp[:, 1] + rmax + st["back_gap"]], 1)
        out.append((Vq, Fp, z))
    return out


def _frame_prim(st):
    """The A-frame in the local frame (x across, y up the back, z out): two poles leaning in to the top, three cross
    bars, a shelf at the foot, a dressed block on the shelf lashed with two cords."""
    fr = st["frame"]
    Z = st["zones"]
    h = st["h"]
    w0, w1 = fr["spread"]
    r = fr["pole"]
    out = []
    zc = r + st["back_gap"]
    for sgn in (1.0, -1.0):
        P = np.array([[sgn * w0 / 2, -0.04, zc + 0.02], [sgn * w1 / 2, h + 0.06, zc]])
        Vt, Ft = D._sweep(_dense(P, 0.1), r, segs=6)
        out.append((Vt, Ft, Z["cane"]))
    for t in (0.18, 0.52, 0.88):
        x = (w0 + (w1 - w0) * t) / 2 + 0.02
        P = np.array([[-x, h * t, zc + 0.012], [x, h * t, zc + 0.012]])
        Vt, Ft = D._sweep(_dense(P, 0.1), r * 0.75, segs=6)
        out.append((Vt, Ft, Z["rim"]))
    sh = fr["shelf"]
    out.append(HW.translate(HW.box(w0 / 2 + 0.03, 0.012, sh / 2, z0=-sh / 2), (0.0, 0.0, zc + sh / 2)) + (Z["cane"],))
    bx, by, bz = fr["block"]
    out.append(HW.translate(HW.box(bx / 2, by / 2, bz / 2, z0=-bz / 2), (0.0, by / 2 + 0.012, zc + bz / 2 + 0.02))
               + (Z["block"],))
    for yy in (0.06, by - 0.05):
        ring = [[-bx / 2 - 0.004, yy, zc + 0.016], [-bx / 2 - 0.004, yy, zc + bz + 0.024],
                [bx / 2 + 0.004, yy, zc + bz + 0.024], [bx / 2 + 0.004, yy, zc + 0.016]]
        Vt, Ft = D._sweep(_dense(np.array(ring), 0.02), fr["lash"], segs=5)
        out.append((Vt, Ft, Z["rim"]))
    return out


def carry(g, st=None):
    """A back basket (TALL_BASKET, ROUND_BASKET) on two shoulder straps: rigid on the upper back."""
    st = _style(TALL_BASKET, st)
    Z = st["zones"]
    fits = g.fits
    J = fits.J
    g.m = None
    sp = st["straps"]
    for s in ("l", "r"):
        sg = 1.0 if s == "l" else -1.0
        S = J[s + "_shoulder"]
        way = [np.array([sg * 0.085, -0.13, 1.07]), np.array([sg * 0.105, -0.11, 1.22]), S + np.array([-sg * 0.045, 0.0, 0.075]),
               np.array([sg * 0.10, 0.12, 1.25]), np.array([sg * 0.11, 0.15, 1.08])]
        g.strap(way, sp["w"], sp["lift"], Z["rim"])
    # the bar across the back the basket is lashed to
    g.strap([np.array([-0.12, 0.13, 1.17]), np.array([0.0, 0.16, 1.17]), np.array([0.12, 0.13, 1.17])], sp["w"],
            sp["lift"], Z["rim"])
    if st["over"]:
        g.over(st["over"], st["over_gap"])
    # the basket: bound to the straps' back (between the two shoulder blades) at the basket's middle height
    zc = st["z_bottom"] + st["h"] * 0.5
    anchor = np.array([0.0, 0.17, 1.17])
    b = HW.Binding(g.m, anchor[None])
    parts = _frame_prim(st) if st["kind"] == "frame" else _basket_prim(st)
    pieces = []
    base_m = g.m
    for Vl, Fl, zone in parts:
        # the local origin at the anchor; the basket's foot at z_bottom
        V0 = Vl.copy()
        V0[:, 1] += st["z_bottom"] - anchor[2]
        pc = HW.rigid(base_m, b, (V0, Fl), zone, part=11, up=(0.0, 0.0, 1.0), lift=0.0)
        pieces.append(pc)
    for pc in pieces:
        g.add(pc)
    # (the basket hangs on the back: the anchor point's surface normal points back; the frame's up is world up)
    g.uv(axis_top=1.5, axis_bottom=0.8, limbs=())
    sel = g.m.fa["part"] == 11
    if sel.any():
        Q = g.m.V[REF][np.unique(g.m.F[sel])]
        a = Q[Q[:, 2] < np.percentile(Q[:, 2], 3)].mean(0)
        c = Q[Q[:, 2] > np.percentile(Q[:, 2], 97)].mean(0)
        g.uvparts[11] = ("cyl", a, c, [0.0, 1.0, 0.0])
    g.hem = lambda m: np.zeros(m.n, bool)
    return g


# ======================================================================================================================
# hip panels over a wrapped skirt
# ======================================================================================================================
HIP_PANELS = {
    "panels": [{"from": -24.0, "to": 24.0, "hem": 0.42}, {"from": 58.0, "to": 104.0, "hem": 0.46}],
    "ragged": 0.035,                           # the hems' ragged depth (m)
    "skirt": {"hem": 0.40, "flare": 0.06, "folds": 0.008},   # the long wrap the panels are cut from (dress.WRAP_SKIRT)
    "gap": 0.005,                              # off the skirt under them
    "zone": 1,
}


def hip_panels(g, base_style, st=None):
    """Panels hanging over the wrapped skirt g.m: a longer wrap_skirt (base_style with st["skirt"]) clipped to each
    panel's signed angle window, a ragged hem; fitted over g.m; joined to it."""
    from cloth2 import dress as DR
    st = _style(HIP_PANELS, st)
    main = g.m
    main_uv = dict(g.uvparts)
    sub = G.Garment(g.fits, g.spec)
    sst = _style(base_style, dict(st["skirt"]))
    sst["overlap"] = None
    sst["rims"] = None
    DR.wrap_skirt(sub, sst)
    rng = np.random.default_rng(9)
    pieces = []
    b0 = base_style["top"] - base_style["band"]
    for pn in st["panels"]:
        m = sub.m.copy()
        th = _theta(m.V[REF])
        lo, hi = pn["from"], pn["to"]
        mid = 0.5 * (lo + hi)
        half = 0.5 * (hi - lo)
        f = half - np.abs(_wrap(th - mid))
        m = m.clip(f, 0.0)
        # below the band only, and the ragged hem: a few straight cuts (a hand-cut edge)
        m = m.clip(b0 - 0.005 - m.V[REF][:, 2], 0.0)
        th = _theta(m.V[REF])
        knots = rng.uniform(-1.0, 1.0, 7)
        u = np.clip((_wrap(th - lo)) / max(hi - lo, 1.0), 0.0, 1.0)
        rag = np.interp(u, np.linspace(0, 1, 7), knots) * st["ragged"]
        m = m.clip(m.V[REF][:, 2] - (pn["hem"] + rag), 0.0)
        m = TR.drop_small(m, 10)
        g.fits.clear(m, st["gap"], surface=g.fits.obstacles([main]), max_push=0.05)
        m.fa["zone"][:] = st["zone"]
        pieces.append(m)
    g.m = concat([main] + pieces)
    g.uvparts = main_uv
    return g
