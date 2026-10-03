"""cloth2 settlers: helpers the Palatine settlers', the British regulars' and the rangers' garments needed beside the
shared recipe types (2026-10-02). Additive only: nothing here changes how garment.py, recipes.py or trims.py behave.

  taut(g, iters, gap, smooth, where)     stiff cloth stretched over the body: smoothed and pushed clear of the skin in
                                         turns, so it bridges the hollows (the cleavage, under the bust) the way boned
                                         stays do, instead of following them
  keep(g, field)                         keeps where field(P) > 0 (reference positions): a free outline (a stays' tabs
                                         and pointed front, a kerchief's triangle)
  tabs(z_top, z_bottom, angles, ...)     the field of a bottom edge cut into tabs (stays): use with keep()
  stripe(g, field, zone)                 cut along field == 0 and put the faces where field < 0 in `zone` (a lace loop,
                                         a front panel, a ribbon round a cap): tailor.cut_select without the import
  cord(g, a, b, width, zone)             a straight cord between two points on the garment: a thin rigid strip lying
                                         on the cloth (lacing), bound in every fit
  eyelets(g, P, zone)                    worked eyelets (small rings) at points on the garment
  bow(g, point, zone, size, up, tails)   a ribbon bow (a knot, two loops) with hanging tie ends, rigid on its anchor
  sink(g, sel_v, depth)                  moves vertices inward along their normals in every fit (a recessed panel)
  loop_strip(g, points, half_w, lift)    a ribbon lying on the garment along points (a cap's ribbon), in every fit
  weights_from(g, gid, where)            cloth weighted like the garment under it (an apron like the petticoat)
  settle_gauge(g)                        the bust gauge's fits kept near the reference where the body did not change
  peak(g, front_deg, width, droop, zone) a stiff peak grown from a cap's front edge (the jockey cap)

Every piece exists in every fit (the reference fit's topology, each fit's positions), like the rest of cloth2.
"""

import numpy as np

from cloth2 import hardware as HW
from cloth2 import trims as TR
from cloth2.mesh import BIG_FIELD, REF, smoothstep, unit
from cloth2.parts import angle_from_front


# ---- shaping -------------------------------------------------------------------------------------------------------
def taut(g, iters=6, gap=0.008, smooth=4, lam=0.5, where=None, surface="cloth", skin_gap=0.003):
    """Stretches g.m over the body: `iters` rounds of Laplacian smoothing (pulling the cloth across hollows, flattening
    it over bulges) and clearing it `gap` m (a number, per vertex, or a field of reference positions) off the
    `surface` ("cloth": the smoothed body, so the nipples and the skin's detail leave no mark; "skin"), then skin_gap
    off the skin itself. A hollow fills, a dome stays: the cloth lies like stiffened, boned cloth. `where` (per vertex
    0..1 or a field of reference positions) limits the smoothing."""
    w = None
    if where is not None:
        w = np.asarray(where(g.P) if callable(where) else where, float)
    gv = np.asarray(gap(g.P) if callable(gap) else gap, float)
    for _ in range(iters):
        g.m.smooth(smooth, lam, weights=w)
        g.fits.clear(g.m, gv, surface=surface)
    g.fits.clear(g.m, skin_gap, surface="skin")
    return g


def near_joints(g, names, radius):
    """A field of reference positions: 1 at the joints `names` (cloth2.fit joints), falling off over `radius` m."""
    C = np.array([g.fits.J[n] for n in names])

    def f(P):
        d2 = ((P[:, None, :] - C[None]) ** 2).sum(-1).min(1)
        return np.exp(-d2 / radius ** 2)
    return f


def keep(g, field):
    """Keeps the part of g.m where field(P) > 0 (field: a callable on reference positions or a per-vertex array)."""
    f = np.asarray(field(g.P) if callable(field) else field, float)
    g.m = TR.drop_small(g.m.clip(f, 0.0), 12)
    return g


def tabs(z_line, z_tip, angles, half_slit=(0.0012, 0.009), r=0.13):
    """A field (> 0 kept) for a bottom edge cut into tabs: the edge at z_tip(theta) (a callable of the angle from the
    front, degrees), slit up to z_line(theta) at each angle in `angles` (both sides): a V notch half_slit[1] m wide at
    the bottom, half_slit[0] at its top (measured round the body at radius r)."""
    angles = np.asarray(angles, float)

    def f(P):
        th = angle_from_front(P)
        Z = P[:, 2]
        zl, zt = z_line(th), z_tip(th)
        base = Z - zt
        u = np.clip((zl - Z) / np.maximum(zl - zt, 1e-6), 0.0, 1.0)      # 0 at the slit's top, 1 at the bottom
        hw = half_slit[0] + (half_slit[1] - half_slit[0]) * u
        d = np.min(np.abs(th[:, None] - angles[None, :]), 1) * np.pi / 180.0 * r
        slit = np.where(Z < zl, d - hw, (Z - zl) + 0.01)
        return np.minimum(base, slit)
    return f


def stripe(g, field, zone):
    """Cuts g.m along field == 0 (a callable on reference positions, or a per-vertex array carried through the cut)
    and puts the faces where field < 0 in `zone`. Returns the face mask."""
    g.m, sel = TR.split_mask(g.m, field)
    g.m.fa["zone"][sel] = zone
    return sel


def sink(g, sel_v, depth):
    """Moves the vertices `sel_v` (bool or 0..1 per vertex) `depth` m inward along their normals, in every fit."""
    d = -np.asarray(sel_v, float) * depth
    g.m.offset(d, vertical=1.0)
    g.m.recompute_normals()
    return g


# ---- small rigid pieces --------------------------------------------------------------------------------------------
def cord(g, a, b, width=0.0035, thick=0.0016, zone=2, lift=0.0004, part=9):
    """A straight cord from a to b (points on g.m, reference fit) as one thin rigid strip lying on the cloth at its
    midpoint (it keeps its length in every fit: lacing over a few centimetres)."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    L = float(np.linalg.norm(b - a))
    if L < 1e-4:
        return g
    mid = (a + b) / 2.0
    prim = HW.box(width / 2.0, L / 2.0 + width * 0.3, thick / 2.0)
    bnd = HW.Binding(g.m, [mid])
    g.add(HW.rigid(g.m, bnd, prim, zone, part=part, up=[unit(b - a)], lift=lift))
    return g


def eyelets(g, P, zone=2, r=0.0026, tube=0.0009, segs=8, tube_segs=4):
    """Worked eyelets (small rings) at points P on the garment."""
    P = np.asarray(P, float).reshape(-1, 3)
    if len(P):
        g.hardware(P, HW.ring(r, tube, segs, tube_segs), zone)
    return g


def bow(g, point, zone, size=0.022, up=(0.0, 0.0, 1.0), tails=0.07, tail_w=0.012, lift=0.0, part=9):
    """A ribbon bow at `point` (on g.m): a knot, two flattened loops left and right, and two tails hanging below, one
    rigid piece (its anchor's weights)."""
    s = size
    knot = HW.ellipsoid(s * 0.22, s * 0.2, s * 0.16, segs=8, rings=4)
    loop_l = HW.translate(HW.ellipsoid(s * 0.42, s * 0.24, s * 0.11, segs=8, rings=4), (s * 0.42, s * 0.04, 0.0))
    loop_r = HW.translate(HW.ellipsoid(s * 0.42, s * 0.24, s * 0.11, segs=8, rings=4), (-s * 0.42, s * 0.04, 0.0))
    parts = [knot, loop_l, loop_r]
    if tails:
        for sx in (1.0, -1.0):
            V, F = HW.box(tail_w / 2.0, tails / 2.0, 0.0008)
            # (a tail leans out a little and hangs down from the knot)
            a = np.radians(12.0 * sx)
            R = np.array([[np.cos(a), -np.sin(a), 0.0], [np.sin(a), np.cos(a), 0.0], [0.0, 0.0, 1.0]])
            V = V @ R.T + np.array([sx * tails * 0.18, -tails / 2.0 - s * 0.1, 0.0005])
            parts.append((V, F))
    prim = HW.merge(parts)
    bnd = HW.Binding(g.m, [np.asarray(point, float)])
    g.add(HW.rigid(g.m, bnd, prim, zone, part=part, up=[np.asarray(up, float)], lift=lift))
    return g


def loop_strip(g, points, half_w, lift, zone, closed=True, part=8):
    """A ribbon lying on g.m along `points` (reference fit, in order; a closed loop unless closed=False): bound to
    g.m's faces, so in every fit it lies on that fit's surface, `lift` m off it, 2 * half_w wide. Weights: its anchors'
    (a cap's: rigid on the head). Returns g."""
    P = np.asarray(points, float)
    if closed:
        P = np.concatenate([P, P[:1]])
    b = HW.Binding(g.m, P)
    k = len(P)
    V = {}
    for fit in g.m.V:
        p, n = b.at(g.m, fit)
        t = np.gradient(p, axis=0)
        if closed:
            t[0] = t[-1] = p[1] - p[-2]
        a = unit(np.cross(unit(t), n))
        c = p + n * lift
        V[fit] = np.concatenate([c - a * half_w, c + a * half_w])
    F = []
    for i in range(k - 1):
        F += [(i, i + 1, k + i + 1), (i, k + i + 1, k + i)]
    F = np.array(F, int)
    Pr = V[REF]
    fn = np.cross(Pr[F[:, 1]] - Pr[F[:, 0]], Pr[F[:, 2]] - Pr[F[:, 0]])
    n0 = np.concatenate([b.at(g.m, REF)[1]] * 2)
    if ((fn * n0[F[:, 0]]).sum(1) < 0).mean() > 0.5:
        F = F[:, ::-1].copy()
    W = np.concatenate([b.weights(g.m)] * 2)
    A = {name: np.concatenate([b.attr(g.m, name)] * 2) for name in g.m.A if name != "W"}
    region = np.repeat(b.face_attr(g.m, "region")[:-1], 2)
    g.add(HW.piece_mesh(g.m, V, F, W, region, zone, part, A))
    return g


def settle_gauge(g, fits=("bl", "bs"), slack=0.01, radius=0.04):
    """The bust gauge's fits differ from the reference only round the bust; a push over a layer's open edge or a rim
    can still run a vertex of those fits centimetres off elsewhere (Garment.over's nearest-point push). Each vertex of
    `fits` stays within (how far the body moved within `radius` of it) + `slack` of its reference position."""
    from mathutils import kdtree
    B0 = g.fits.V[REF]
    kd = kdtree.KDTree(len(B0))
    for i, p in enumerate(B0):
        kd.insert(p, i)
    kd.balance()
    P0 = g.m.V[REF]
    near = [[j for _, j, _ in kd.find_range(p, radius)] or [kd.find(p)[1]] for p in P0]
    for fit in fits:
        if fit not in g.m.V or fit not in g.fits.V:
            continue
        dB = np.linalg.norm(g.fits.V[fit] - B0, axis=1)
        allow = np.array([dB[idx].max() for idx in near]) + slack
        d = g.m.V[fit] - P0
        L = np.linalg.norm(d, axis=1)
        k = np.minimum(1.0, allow / np.maximum(L, 1e-9))
        g.m.V[fit] = P0 + d * k[:, None]
    g.m.recompute_normals()
    return g


# ---- weights -------------------------------------------------------------------------------------------------------
def weights_from(g, gid, where):
    """The vertices of g.m that `where(P)` keeps take the skin weights of the nearest point of garment `gid` (a cloth2
    garment built in this run, reference fit): cloth lying over another follows it (an apron over the petticoat)."""
    from cloth2.garment import built
    under = built(g.fits, gid)[0]
    sel = np.nonzero(np.asarray(where(g.P), bool))[0]
    if not len(sel):
        return g
    b = HW.Binding(under, g.P[sel])
    W = g.m.A["W"].copy()
    W[sel] = b.weights(under)
    g.m.A["W"] = W
    return g


# ---- caps ----------------------------------------------------------------------------------------------------------
def peak(g, front_deg=62.0, width=0.055, droop=0.35, zone=1, centre=(0.0, -0.035, 0.075)):
    """A stiff peak grown from the front edge of a cap made by hats.head_grid (g.m, rigid on headb): the boundary
    within front_deg of the front, extruded forward (level, then drooping by `droop` of its width), one sheet (the
    cloth shader draws both sides). Its width tapers to the ends (a half-moon)."""
    from cloth2 import hats as HT
    c0 = HT.headb(g.fits) + np.asarray(centre, float)
    sel = lambda P: angle_from_front(P - np.array([0.0, c0[1], 0.0])) < front_deg + 4.0

    def prof(P0):
        a = angle_from_front(P0 - np.array([0.0, c0[1], 0.0]))
        return np.clip(1.0 - (a / front_deg) ** 2, 0.0, 1.0) ** 0.6

    def disp(fit, P0, N0, s):
        out = np.stack([P0[:, 0] - c0[0], P0[:, 1] - c0[1], np.zeros(len(P0))], 1)
        out = unit(out)
        w = width * prof(P0)
        down = np.array([0.0, 0.0, -1.0])
        return out * (w * s)[:, None] + down[None] * (droop * w * s * s)[:, None]
    top = TR.extrude(g.m, sel, disp, rings=3, zone=zone, part=7)
    if top is not None:
        g.add(top)
    return g
