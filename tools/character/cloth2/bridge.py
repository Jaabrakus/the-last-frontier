"""cloth2 bridge: cloth laid taut over a hollow or a bulge of the body instead of following it (2026-10-03, the costume
review's fixes). Additive: recipes.coat calls flat_front only for a style that sets its new "bust" key (default None,
so no other coat changes); nothing here changes garment.py, drift.py or settlers.py.

  fill_holes(g, where, max_edges)        closes small boundary loops (the breeches' crotch: the cloth proxy leaves the
                                         genital faces out, a loop that is a point in the female base and opens into a
                                         ragged ring in the male fit)
  taut_window(g, weight, ...)            the cloth inside a window (weight(P) 0..1 on reference positions) smoothed
                                         like a membrane between its fixed rim and kept clear of the skin (a crotch
                                         bridged with a straight seam: no camel-toe; the cleavage spanned flat)
  crotch_window(...)                     the window of a crotch: the front of the fall down between the thighs
  crotch_bridge(g, ...)                  the male fit's crotch the female one moved (drift.smooth_fit_offset), then
                                         taut_window over the crotch in every fit (the genitals are hidden under any
                                         legs garment: the cloth lies flat over them from the waistband to the inseam)
  tube_clear_of_skin(g, path_fn, lift, r)  a cap's rigid tail or end (hats.tube) lifted where it would go into the skin in
                                         any fit (the male fit's thicker neck): the path made again with more lift
  ease_sides(g, d, x, z_max)             more room at the sides of a band round the neck (a stock or a neckerchief
                                         over the shirt's collar, whose open top edge Garment.over cannot see)
  flat_front(g, fits, ...)               a boned front (stays): one cone, the cleavage spanned by the straight line
                                         across from apex to apex, the cloth below each apex never behind the straight
                                         line down to the busk point or the tabs; with fits=("f", "bl", "bs") and
                                         z_min at the hips, a coat, capot or jacket on the female fits hanging
                                         straight from the bust's apex (no crease under the bust)

Every operation works on each fit's positions with the reference topology (cloth2.mesh), so the male fit and the bust
gauge stay exact morph targets.
"""

import numpy as np

from cloth2.mesh import REF, Mesh, smoothstep, unit, vertex_normals


# ---- small holes ---------------------------------------------------------------------------------------------------
def boundary_loops(m):
    """The boundary of m as ordered loops of vertex ids (face order)."""
    be, _ = m.boundary()
    nxt = {}
    for a, b in be:
        nxt.setdefault(int(a), []).append(int(b))
    seen = set()
    loops = []
    for a, b in be:
        a = int(a)
        if a in seen:
            continue
        loop = [a]
        seen.add(a)
        cur = nxt[a][0]
        while cur != a and cur not in seen and cur in nxt and len(loop) < 100000:
            loop.append(cur)
            seen.add(cur)
            cur = nxt[cur][0]
        loops.append(np.array(loop, int))
    return loops


def fill_holes(g, where, max_edges=16):
    """Closes every boundary loop of at most `max_edges` edges whose centre (reference fit) where(P) accepts: a fan to a
    new centre vertex (each fit's mean of the loop; attributes the loop's mean), turned like the faces round it."""
    m = g.m
    add_V = {k: [] for k in m.V}
    add_A = {k: [] for k in m.A}
    add_F, add_fa = [], {k: [] for k in m.fa}
    n = m.n
    filled = 0
    # the face each boundary edge belongs to (its attributes go to the fan)
    E = np.concatenate([m.F[:, [0, 1]], m.F[:, [1, 2]], m.F[:, [2, 0]]])
    fid = np.concatenate([np.arange(len(m.F))] * 3)
    edge_face = {(int(a), int(b)): int(f) for (a, b), f in zip(E, fid)}
    for loop in boundary_loops(m):
        if len(loop) > max_edges or len(loop) < 3:
            continue
        c = m.V[REF][loop].mean(0)
        if not bool(np.asarray(where(c[None]))[0]):
            continue
        ci = n + filled
        for k in m.V:
            add_V[k].append(m.V[k][loop].mean(0))
        for k in m.A:
            add_A[k].append(m.A[k][loop].mean(0))
        for i in range(len(loop)):
            a, b = int(loop[i]), int(loop[(i + 1) % len(loop)])
            f = edge_face.get((a, b), 0)
            add_F.append((b, a, ci))            # the edge a->b is the face's: the fan runs it the other way
            for k in m.fa:
                add_fa[k].append(m.fa[k][f])
        filled += 1
    if not filled:
        return 0
    out = Mesh.__new__(Mesh)
    out.V = {k: np.concatenate([m.V[k], np.array(add_V[k])]) for k in m.V}
    out.A = {k: np.concatenate([m.A[k], np.array(add_A[k])]) for k in m.A}
    out.F = np.concatenate([m.F, np.array(add_F, int)])
    out.fa = {k: np.concatenate([m.fa[k], np.array(add_fa[k], dtype=m.fa[k].dtype)]) for k in m.fa}
    out.N = {k: vertex_normals(v, out.F) for k, v in out.V.items()}
    g.m = out
    return filled


# ---- a taut window ---------------------------------------------------------------------------------------------------
def _genital_near(g, fit, idx):
    """Whether the skin nearest each vertex idx (fit) is the (hidden) genitals'."""
    from mathutils import Vector
    bv = g.fits.bvh[fit]
    out = np.zeros(len(idx), bool)
    for j, i in enumerate(idx):
        _, _, fi, _ = bv.find_nearest(Vector(g.m.V[fit][i]))
        out[j] = fi is not None and bool(g.fits.gen_face[fi])
    return out


def taut_window(g, weight, fits=None, rounds=8, iters=6, lam=0.5, gap=0.003, base_gap=0.003):
    """The cloth in the window weight(P) (reference positions -> 0..1) smoothed like a membrane between the window's rim
    and cleared `gap` m off the skin each round, in `fits` (default every fit but "m"): a hollow is spanned, a bulge
    is lain over; the vertices whose nearest skin is the genitals' are not pushed out of them. The rest of the
    garment is held (weight 0) and cleared `base_gap` at the end."""
    m = g.m
    w = np.clip(np.asarray(weight(m.V[REF]), float), 0.0, 1.0)
    fits = [k for k in m.V if k != "m"] if fits is None else list(fits)
    E = m.adjacency()
    cnt = np.bincount(E[:, 0], minlength=m.n).astype(float)
    sel = np.nonzero(w > 0.0)[0]
    for _ in range(rounds):
        for k in fits:
            P = m.V[k]
            for _ in range(iters):
                acc = np.zeros_like(P)
                np.add.at(acc, E[:, 0], P[E[:, 1]])
                P = P + (lam * w)[:, None] * (acc / np.maximum(cnt, 1.0)[:, None] - P)
            m.V[k] = P
        m.recompute_normals()
        gen = np.zeros(m.n, bool)
        for k in fits:
            gen[sel] |= _genital_near(g, k, sel)
        g.fits.clear(m, np.where(gen, -0.05, np.where(w > 0.0, gap, -1.0)))
    m.recompute_normals()
    gen = np.zeros(m.n, bool)
    for k in m.V:
        gen[sel] |= _genital_near(g, k, sel)
    g.fits.clear(m, np.where(gen, -0.05, base_gap))
    return w


def crotch_window(x_full=0.040, x_zero=0.085, z_lo=(0.62, 0.68), z_hi=(0.86, 0.92), y_back=(0.03, 0.08)):
    """The window of a crotch (reference positions -> 0..1): the centre front |x| < x_full (falling to 0 at x_zero)
    from z_lo up to z_hi, and under the crotch back to y_back (the seat is left as it is)."""
    def w(P):
        X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
        return (1.0 - smoothstep(x_full, x_zero, np.abs(X))) * smoothstep(z_lo[0], z_lo[1], Z) * \
            (1.0 - smoothstep(z_hi[0], z_hi[1], Z)) * (1.0 - smoothstep(y_back[0], y_back[1], Y))
    return w


def crotch_bridge(g, window=None, male_window=None, gap=0.003, rounds=10):
    """The crotch of breeches or slops bridged: the male fit's front of the crotch first the female one moved
    (drift.smooth_fit_offset: the genitals part the folded cloth into a slit and a pouch), then the window taut in every
    fit (a straight seam from the fall to the inseam: no camel-toe in the female fits; in the male fit the fall lies
    flat over the genitals, which are hidden under any legs garment and not cleared)."""
    from cloth2 import drift as D
    window = window or crotch_window()
    mw = male_window or (lambda P: (1.0 - smoothstep(0.024, 0.052, np.abs(P[:, 0]))) * smoothstep(0.02, -0.03, P[:, 1]) *
                         smoothstep(0.66, 0.70, P[:, 2]) * (1.0 - smoothstep(0.84, 0.89, P[:, 2])))
    D.smooth_fit_offset(g, "m", mw)
    taut_window(g, window, fits=list(g.m.V), rounds=rounds, gap=gap)
    return g


# ---- a boned front: one cone ---------------------------------------------------------------------------------------------
def _apex(V, sel, side):
    """The most forward (lowest y) vertex of `sel` on one side (x > 0 for side 1, x < 0 for side -1)."""
    idx = np.nonzero(sel & (np.sign(V[:, 0]) == side))[0]
    return idx[np.argmin(V[idx, 1])] if len(idx) else None


def flat_front(g, fits=None, apex_z=(1.06, 1.24), apex_x=(0.04, 0.14), reach=0.045, front_y=-0.02, z_min=None,
               bottom_z=None, top_z=None, smooth=4, lam=0.5, gap=0.0085, surface="cloth", skin_gap=0.003):
    """A boned front (stays) as one smooth cone: in each fit (1) between the bust apexes (each side's most forward point
    within apex_z, apex_x) the front at every height is the straight line across from the left apex column to the
    right: the cleavage spanned flat, the top edge straight across it; (2) below each column's most forward point it
    never lies behind the straight line from that point down to the column's point at bottom_z (the waist: the busk
    point's line, the tabs' tops; default its lowest point): no crease under the bust; above it, never behind the line
    up to the column's point at top_z (when given: the top edge); (3) the front smoothed (no point at the apex) and
    cleared `gap` off `surface`, then skin_gap off the skin. Moves (1) and (2) only bring the cloth forward. Only the
    front (y < front_y), |x| < the apex + reach, above z_min."""
    m = g.m
    Pr = m.V[REF]
    fits = list(m.V) if fits is None else list(fits)
    win = Pr[:, 1] < front_y
    if z_min is not None:
        win &= Pr[:, 2] > z_min
    wsm = np.zeros(m.n)
    for k in fits:
        V = m.V[k].copy()
        band = win & (V[:, 2] > apex_z[0]) & (V[:, 2] < apex_z[1]) & (np.abs(V[:, 0]) > apex_x[0]) & \
            (np.abs(V[:, 0]) < apex_x[1])
        aL, aR = _apex(V, band, 1.0), _apex(V, band, -1.0)
        if aL is None or aR is None:
            continue
        xL, xR = V[aL, 0], V[aR, 0]
        new_y = V[:, 1].copy()
        # (1) across, between the apexes, at each height: the line between the apex columns
        zb = np.round(V[:, 2] / 0.01).astype(int)
        colL = win & (np.abs(V[:, 0] - xL) < 0.012)
        colR = win & (np.abs(V[:, 0] - xR) < 0.012)
        mid = win & (V[:, 0] < xL) & (V[:, 0] > xR)
        for b in np.unique(zb[mid]):
            l = np.nonzero(colL & (np.abs(zb - b) <= 1))[0]
            r = np.nonzero(colR & (np.abs(zb - b) <= 1))[0]
            if not len(l) or not len(r):
                continue
            yl, yr = V[l, 1].min(), V[r, 1].min()
            i = np.nonzero(mid & (zb == b))[0]
            t = (V[i, 0] - xR) / max(xL - xR, 1e-6)
            new_y[i] = np.minimum(new_y[i], yr + (yl - yr) * t)
        V[:, 1] = new_y
        # (2) down (and up) each column, from its most forward point
        xb = np.round(V[:, 0] / 0.01).astype(int)
        cols = win & (np.abs(V[:, 0]) < max(xL, -xR) + reach)
        for b in np.unique(xb[cols]):
            c = np.nonzero(cols & (np.abs(xb - b) <= 0))[0]
            up = c[(V[c, 2] > apex_z[0]) & (V[c, 2] < apex_z[1])]
            if not len(up) or len(c) < 4:
                continue
            a = up[np.argmin(V[up, 1])]
            za, ya = V[a, 2], V[a, 1]
            if bottom_z is None:
                lo = c[np.argmin(V[c, 2])]
            else:
                cand = c[V[c, 2] >= bottom_z - 0.004]
                lo = cand[np.argmin(V[cand, 2])] if len(cand) else c[np.argmin(V[c, 2])]
            zl, yl = V[lo, 2], V[lo, 1]
            if za - zl > 0.03:
                below = c[(V[c, 2] < za) & (V[c, 2] >= zl)]
                line = ya + (yl - ya) * (za - V[below, 2]) / (za - zl)
                V[below, 1] = np.minimum(V[below, 1], line)
            if top_z is not None:
                cand = c[V[c, 2] <= top_z + 0.004]
                hi = cand[np.argmax(V[cand, 2])] if len(cand) else None
                if hi is not None and V[hi, 2] - za > 0.02:
                    zh, yh = V[hi, 2], V[hi, 1]
                    above = c[(V[c, 2] > za) & (V[c, 2] <= zh)]
                    line = ya + (yh - ya) * (V[above, 2] - za) / (zh - za)
                    V[above, 1] = np.minimum(V[above, 1], line)
        wsm = np.maximum(wsm, (cols | mid).astype(float))
        m.V[k] = V
    m.recompute_normals()
    # (3) smoothed over the window (the points at the apexes) and cleared
    E = m.adjacency()
    grow = wsm.copy()
    for _ in range(2):
        nb = np.zeros(m.n)
        np.maximum.at(nb, E[:, 0], grow[E[:, 1]])
        grow = np.maximum(grow, nb * 0.6)
    for _ in range(3):
        m.smooth(smooth, lam, weights=grow)
        g.fits.clear(m, gap, surface=surface)
    g.fits.clear(m, skin_gap, surface="skin")
    return g


# ---- neckwear over the shirt's collar ---------------------------------------------------------------------------------
def ease_sides(g, d=0.006, x=(0.050, 0.085), z_max=1.37, gap=0.003):
    """A band round the neck `d` m farther out at its sides (|x| from x[0], full by x[1]) below z_max: the shirt's
    collar stands there (its open top edge counts as clear for Garment.over, so it came 4-5 mm through)."""
    P = g.P
    w = smoothstep(x[0], x[1], np.abs(P[:, 0])) * (1.0 - smoothstep(z_max - 0.02, z_max, P[:, 2]))
    g.m.offset(d * w, vertical=0.2)
    g.m.smooth(2, 0.5, weights=np.minimum(1.0, 2.0 * w))
    g.m.recompute_normals()
    g.fits.clear(g.m, gap)
    return g


# ---- a cap's rigid tail clear of the skin in every fit ---------------------------------------------------------------
def tube_clear_of_skin(g, path_fn, lift, radii, gap=0.003, rounds=4, segs=12, zone=0):
    """A rigid tube on the head (hats.tube) along path_fn(lift) (lift per path point, m) with `radii`, its lift raised
    where any of its vertices lies closer than `gap` to the skin in any fit (the tail of a cap down the nape: the male
    fit's neck is thicker), then joined to g. Returns the lift used."""
    from cloth2 import hats as HT
    lift = np.asarray(lift, float).copy()
    k = len(lift)
    for _ in range(rounds):
        P = path_fn(lift)
        piece = HT.tube(g.fits, g.m, P, radii, segs=segs, zone=zone)
        need = np.zeros(k)
        for fit in piece.V:
            d, _, _ = g.fits.dist(fit, piece.V[fit])
            ring = np.minimum(np.arange(len(d)) // segs, k - 1)      # (the tip vertex counts with the last ring)
            np.maximum.at(need, ring, gap - d)
        need = np.maximum(need, 0.0)
        if need.max() < 2e-4:
            break
        # spread a little along the tube, so it bends out smoothly
        need = np.maximum(need, np.convolve(np.pad(need, 2, mode="edge"), np.ones(5) / 5.0, mode="valid"))
        lift = lift + need * 1.2
    g.add(HT.tube(g.fits, g.m, path_fn(lift), radii, segs=segs, zone=zone))
    return lift
