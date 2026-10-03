"""The cartridge belt (cloth2: a band round the waist like recipes.belt, with rigid pieces placed on it): a buff
leather waist belt with a frame buckle in front, a curved cartridge pouch at the right front (the colonial regulars'
red Russia-leather gargoussier, or a British black belly box) and a bayonet frog and scabbard at the left hip.
Fitted over the capot and the justaucorps (and everything under them)."""

import numpy as np

from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2.mesh import REF, unit
from cloth2.spec import Spec, Zone

Z = (0.938, 0.988)                 # the belt: 5 cm of buff leather
LIFT = 0.020                       # off the cloth surface before it is fitted over the capot (it lies on it, 4 mm over)
POUCH = {"angle": -36.0, "size": (0.068, 0.044, 0.019), "flap": 0.058, "R": 0.15, "gap": 0.003}
SCABBARD = {"angle": 98.0, "len": 0.40, "w": (0.017, 0.010), "t": (0.009, 0.006), "lean": 13.0, "chape": 0.05,
            "gap": 0.006}

SPEC = Spec(
    id="belt_cartridge", name="Cartridge belt", set="colonial", slot="accessories.waist", layer={"default": 60},
    description="A buff leather waist belt with a brass frame buckle, a curved leather cartridge pouch at the right "
                "front and a bayonet in its scabbard at the left hip.",
    history="The colonial regulars of New France carried their cartridges in the gargoussier, a small pouch of red "
            "Russia leather on the buff waist belt, with the bayonet at the left hip; British regulars wore a "
            "9-round 'belly box' on the waist belt as well as the large pouch on the shoulder belt [M4][M5][S1][S4]. "
            "Worn over the capot on campaign, it tells a marine from a militiaman.",
    zones=[Zone(0, "belt", "leather", "LEA", ["buff", "white_buff", "pale_buff", "leather_black"], "buff"),
           Zone(1, "pouch", "leather", "LEA", ["madder_red", "leather_black", "leather_brown"], "madder_red"),
           Zone(2, "buckle and chape", "metal", "MET", ["brass", "pewter"], "brass", metal=True),
           Zone(3, "scabbard", "leather", "LEA", ["leather_black", "leather_brown"], "leather_black")],
    sources=["M4", "M5", "S1", "S4"], evidence="A", tags=["men", "colonial", "regulars"], budget=3000,
    over=["shirt_linen", "breeches", "veste_sleeved", "waistcoat_sb", "capot"],
    extra={"presets": {"marine": {"0": "buff", "1": "madder_red", "2": "brass", "3": "leather_black"},
                       "british": {"0": "white_buff", "1": "leather_black", "2": "brass", "3": "leather_black"}},
           "fit_note": "Fitted over the capot (2026-10-03: no longer over the justaucorps as well, whose waist "
                       "is fuller, so it cinches the capot's tucked waist; the city watch no longer wears it): worn over "
                       "a veste alone it stands off by about a coat's thickness.",
           "references": ["https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Battle-on-Snowshoes-French-Army-Colonial-Regulars-Guidelines-1.pdf",
                          "https://militaryheritage.com/c_franch.htm",
                          "https://www.fortticonderoga.org/wp-content/uploads/2023/11/1759-Siege-of-Carillon-British-Regulars-Guidelines.pdf"]})


def curved_box(hx, hy, hz, R, nx=8, y0=0.0, z0=0.0):
    """A box hx x hy (half sizes) x 2 hz deep, its back at z0, hanging below y0 (y from y0 - 2 hy to y0), bent round
    a vertical axis of radius R behind it (its sides fall back like the body under it). (V, F) in the local frame."""
    xs = np.linspace(-hx, hx, nx + 1)
    ys = [y0 - 2 * hy, y0]
    zs = [z0, z0 + 2 * hz]
    V = []
    idx = {}
    for i, x in enumerate(xs):
        sag = x * x / (2.0 * R)
        for j, y in enumerate(ys):
            for k, z in enumerate(zs):
                idx[(i, j, k)] = len(V)
                V.append([x, y, z - sag])
    F = []

    def quad(a, b, c, d):
        F.extend([(a, b, c), (a, c, d)])
    n = nx
    for i in range(n):
        # front (z1), back (z0), top (y1), bottom (y0)
        quad(idx[(i, 0, 1)], idx[(i + 1, 0, 1)], idx[(i + 1, 1, 1)], idx[(i, 1, 1)])
        quad(idx[(i, 1, 0)], idx[(i + 1, 1, 0)], idx[(i + 1, 0, 0)], idx[(i, 0, 0)])
        quad(idx[(i, 1, 1)], idx[(i + 1, 1, 1)], idx[(i + 1, 1, 0)], idx[(i, 1, 0)])
        quad(idx[(i, 0, 0)], idx[(i + 1, 0, 0)], idx[(i + 1, 0, 1)], idx[(i, 0, 1)])
    quad(idx[(0, 0, 0)], idx[(0, 0, 1)], idx[(0, 1, 1)], idx[(0, 1, 0)])
    quad(idx[(n, 1, 0)], idx[(n, 1, 1)], idx[(n, 0, 1)], idx[(n, 0, 0)])
    V, F = np.array(V, float), np.array(F, int)
    # outward, face by face: away from the box's mid-surface at the same x (it is bent)
    C = V[F].mean(1)
    ref = np.stack([C[:, 0], np.full(len(C), y0 - hy), z0 + hz - C[:, 0] ** 2 / (2.0 * R)], 1)
    return V, _orient_by(V, F, ref)


def tapered_case(L, w, t, segs=8):
    """A flat case along -y from the origin (length L), its cross-section an ellipse w x t (half axes) narrowing from
    the top to the tip, the tip rounded: a bayonet scabbard. (V, F) in the local frame (z out)."""
    rows = 9
    V, F = [], []
    for i in range(rows):
        s = i / (rows - 1)
        ww = w[0] + (w[1] - w[0]) * s
        tt = t[0] + (t[1] - t[0]) * s
        a = 2 * np.pi * np.arange(segs) / segs
        V += np.stack([ww * np.cos(a), np.full(segs, -L * s), tt * (1.0 + np.sin(a))], 1).tolist()
    V.append([0.0, -L - w[1] * 0.8, t[1]])
    V.append([0.0, 0.0, t[0]])
    for i in range(rows - 1):
        for j in range(segs):
            a0, a1 = i * segs + j, i * segs + (j + 1) % segs
            b0, b1 = (i + 1) * segs + j, (i + 1) * segs + (j + 1) % segs
            F += [(a0, b0, b1), (a0, b1, a1)]
    tip, top = len(V) - 2, len(V) - 1
    for j in range(segs):
        F.append(((rows - 1) * segs + j, tip, (rows - 1) * segs + (j + 1) % segs))
        F.append((j, (j + 1) % segs, top))
    V, F = np.array(V, float), np.array(F, int)
    # outward, face by face: away from the case's axis at the same height (the caps: away from the middle)
    C = V[F].mean(1)
    yc = np.clip(C[:, 1], -L * 0.98, -L * 0.02)
    ref = np.stack([np.zeros(len(C)), yc, np.full(len(C), 0.5 * (t[0] + t[1]))], 1)
    return V, _orient_by(V, F, ref)


def _orient_by(V, F, ref):
    """Each face turned to face away from its reference point (ref: (faces, 3))."""
    fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    flip = (fn * (V[F].mean(1) - ref)).sum(1) < 0
    F = F.copy()
    F[flip] = F[flip][:, ::-1]
    return F


def place(g, prims, frames, W_row, region, obstacles=None, gap=0.003, push_dir=None, skin=None):
    """Rigid pieces (prims: [(V, F, zone)] in one local frame) placed by frames {fit: (origin, R columns across, up,
    out)}, every vertex weighted W_row, then pushed out along the frame's out axis (or push_dir {fit}) until clear of
    the obstacles by `gap` in that fit (the same shape in every fit: only its position follows the body). `skin` (a
    cloth2 Mesh, the belt): each vertex takes instead the weights of that mesh's nearest point (2026-10-03: the pouch,
    rigid on one weight row, floated off the belt in the walk and the run; skinned with the belt it rides on it)."""
    fits = g.fits
    Vl = np.concatenate([p[0] for p in prims])
    Fl, Zl, off = [], [], 0
    for V, F, z in prims:
        Fl.append(F + off)
        Zl.append(np.full(len(F), z))
        off += len(V)
    Fl, Zl = np.concatenate(Fl), np.concatenate(Zl)
    Vf = {}
    for fit, (o, R) in frames.items():
        P = o + Vl @ R.T
        if obstacles is not None and fit in obstacles:
            for _ in range(4):
                d, _, _ = fits.dist(fit, P, surface={fit: obstacles[fit]})
                need = gap - float(d.min())
                if need <= 0.0002:
                    break
                P = P + (push_dir[fit] if push_dir else R[:, 2]) * (need + 0.0005)
        Vf[fit] = P
    if skin is not None:
        W = HW.Binding(skin, Vf[REF]).weights(skin)
    else:
        W = np.repeat(np.asarray(W_row, float)[None], len(Vl), 0)
    piece = HW.piece_mesh(g.m, Vf, Fl, W, region, Zl, 9)
    return piece


def build(g):
    from cloth2.garment import built
    fits = g.fits
    g.m = None
    g.band(Z[0], Z[1], LIFT, 0)
    g.over(SPEC.over, 0.004)
    band = g.m.copy()
    obs = fits.obstacles([built(fits, i)[0] for i in SPEC.over] + [band])
    zc = 0.5 * (Z[0] + Z[1])

    def on_band(angle, heights):
        """The band's point at `angle` at the first of `heights` a ray finds it at (over the hip it rides up a little)."""
        for z in heights:
            A = g.around_points(z, np.array([angle]))
            if len(A):
                return A
        return np.zeros((0, 3))
    # the buckle at the front, the belt's end through it
    P = g.front_points([0.0], [zc])
    g.hardware(P, HW.box(0.030, 0.019, 0.0015), 0, lift=0.0004)
    g.hardware(P, HW.frame(0.052, 0.058, 0.0055, 0.0040), 2, lift=0.0016)
    # the pouch: a curved box on the belt at the right front (the belt through the loops on its back), its flap over
    # the top; skinned with the belt (2026-10-03: hanging from the belt's top edge over the capot's skirt it was pushed
    # out 4-5 cm and floated)
    pk = POUCH
    A = on_band(pk["angle"], (zc, Z[1] - 0.01, Z[0] + 0.01))
    if len(A):
        b = HW.Binding(g.m, A)
        hx, hy, hz = pk["size"]
        box = curved_box(hx, hy, hz, pk["R"], nx=8, y0=hy)
        flap = curved_box(hx + 0.003, pk["flap"] / 2, 0.0016, pk["R"], nx=8, y0=hy + 0.0025, z0=2 * hz)
        frames = {}
        for fit in g.m.V:
            p, n = b.at(g.m, fit)
            R = HW.frames(n, [0.0, 0.0, 1.0])[0]
            frames[fit] = (p[0], R)
        g.add(place(g, [(box[0], box[1], 1), (flap[0], flap[1], 1)],
                    frames, b.weights(g.m)[0], int(b.face_attr(g.m, "region")[0]), obs, pk["gap"], skin=band))
    # the bayonet: a frog on the belt at the left hip and the scabbard hanging from it, leaning back, swinging with
    # the skirt (the outer garment's weights at its middle)
    sc = SCABBARD
    A = on_band(sc["angle"], (Z[0] + 0.012, zc, Z[1] - 0.01))
    if len(A):
        b = HW.Binding(g.m, A)
        cap = built(fits, "capot")[0]
        frog = HW.box(0.018, 0.030, 0.004)
        frog = (frog[0] + np.array([0.0, -0.012, 0.0]), frog[1])
        case = tapered_case(sc["len"], sc["w"], sc["t"])
        case = (case[0] + np.array([0.0, -0.022, 0.006]), case[1])
        ch = tapered_case(sc["chape"], (sc["w"][1] * 1.25, sc["w"][1] * 1.05), (sc["t"][1] * 1.25, sc["t"][1] * 1.1))
        ch = (ch[0] + np.array([0.0, -0.022 - sc["len"] + sc["chape"] - 0.002, 0.005]), ch[1])
        frames, push = {}, {}
        lean = np.radians(sc["lean"])
        for fit in g.m.V:
            p, n = b.at(g.m, fit)
            n = unit(n)
            nh = unit(np.array([n[0, 0], n[0, 1], 0.0]))
            back = np.array([0.0, 1.0, 0.0])
            down = unit(np.array([0.0, 0.0, -1.0]) * np.cos(lean) + back * np.sin(lean))
            up = -down
            out = unit(nh - (nh @ up) * up)
            across = np.cross(up, out)
            frames[fit] = (p[0] + n[0] * 0.002, np.stack([across, up, out], 1))
            push[fit] = out
        mid = A[0] + np.array([0.0, 0.06, -0.20])
        bm = HW.Binding(cap, [mid])
        W_case = bm.weights(cap)[0]
        g.add(place(g, [(frog[0], frog[1], 0)], frames, b.weights(g.m)[0], int(b.face_attr(g.m, "region")[0]), obs, 0.003,
                    push, skin=band))
        g.add(place(g, [(case[0], case[1], 3), (ch[0], ch[1], 2)], frames, W_case,
                    int(bm.face_attr(cap, "region")[0]), obs, sc["gap"], push))
    g.uv(axis_top=1.1, axis_bottom=0.5, limbs=())


build_and_export = G.runner(SPEC, build)
