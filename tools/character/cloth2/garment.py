"""cloth2 Garment: the recipe interface. A garment module is a SPEC and a few calls on a Garment (2026-09-28):

    def build(g):
        g.shell(TORSO + ARMS)                          # the body under the cloth: which regions
        g.top(1.336).bottom(0.905)                     # cut lines (height, m)
        g.sleeves(end=0.925, ease=(0.006, 0.013), gather=0.008)
        g.seams()                                      # straight centre-back and under-sleeve lines (the UV seams)
        g.fit(ease=0.0055)                             # offset off the cloth surface, smooth, clear of the skin
        g.tails(hem=0.60, side_hem=0.69, flare=0.06, slits=[(84, 96, 0.74)])
        g.zone(1, above=1.30)                          # the collar band is zone 1
    build_and_export = garment.runner(SPEC, build)     # build_and_export(ctx, fits, export)

Everything is done on the reference fit and replayed on the male fit and the bust gauge (cloth2.mesh): a cut, a
raised region or a button is placed once and exists in every fit, so `sex`, `breast_large`, `breast_small` stay exact
morph targets. Heights are on the reference fit (the female base: neck root ~1.33, waist ~1.02, hip ~0.93, knee
~0.47, ankle ~0.08); arm and leg parameters t run 0 at the root to 1 at the wrist / ankle (by length along the
joints); angles round the body are degrees from the front (0) to the back (180), the same both sides.

Most garments are one call of a recipe TYPE (cloth2.recipes: coat, jacket, capot, waistcoat, apron, neckwear,
soft_cap, rigid_hat, leggings, belt, sash, harness, pouch_belt, shirt) with a style dict; the operations below are
what the types are made of, and what a new type uses.

THE API (2026-10-02; every method returns the Garment, so calls chain)

  the shell and its cuts
    shell(regions, base="cloth"|"skin")   the covered body under the cloth (TORSO, NECK, ARMS, LEGS: region lists)
    top(z, dip) / bottom(z)               cut above / below a height (dip lowers the front: a neckline)
    neckline(a, b, z0, tilt, dip)         the opening round the neck (an ellipse round the neck's axis)
    sleeves(end, ease, gather) / legs()   cut the limbs at parameter `end`; the ease profile along them
    armholes(size, centre, t_cut)         sleeveless: round armholes about the shoulder joints (waistcoats)
    seams(back, limbs)                    straight centre-back and under-limb lines (UV seams)
    opening(table, x0, min_w)             the front open where |x - x0| < w(z), table [(z, half-width), ...]: a
                                          buttoned front (min_w), lapels' V, skirts cut away below the waist
    vent(z_top)                           a back vent from the hem; each side then follows its own leg
    split_sides(where)                    hanging cloth there follows only its own side's skirt panels
    crotch(drop)                          the gusset of breeches

  offsets and layers
    fit(ease, layer, smooth, gap)         off the cloth surface by the ease (LAYER_EASE by layer), clear of the skin
    relieve(points, radius, depth)        less ease round points (armpits(): where the arms fold the cloth in)
    over(ids, gap)                        pushed clear of the garments worn under it (catalog ids of cloth2 garments,
                                          built in the same run by `built`; open edges and inward faces of those are
                                          ignored, no vertex moves more than OVER_MAX_PUSH): a waistcoat over the shirt
                                          and breeches, a coat over all three. Spec.over lists them (entry "fit_over").
    tails(hem | hem_fn, side_hem, flare, folds, pleats, slits, gap, edge_angle)
                                          cloth hanging from the shell's bottom edge (shirt tails, coat skirts, a
                                          basque, an apron's front); its weights go over to the skirt panels down to
                                          SKIRT_Z_FULL (one ramp for every layer, so layers swing together)

  trims (cloth2.trims; selections are fields < 0 on reference positions, per-vertex arrays or face masks, cut
  along their zero line first so a colour or a fold has a clean edge)
    select(field)                         -> faces (after the cut)
    zone(idx, above, below, limb, t_above)  zone by height or along a limb
    raised(field, h, zone, rim)           the faces stand h proud with a rim (a fold of cloth has an edge): cuffs,
                                          lapels, pocket flaps, turnbacks, a hood lying on the back, overlaps
    cuffs(t0, h, zone, flare)             round cuffs square to the forearm, flaring at the top
    edge_zone(idx, width, select, h)      a band along open edges (piping, binding, a glow cord: spec Zone glow=)
    collar_fall(width) / stand_collar(height)   a turned-down or a standing collar at the neckline
    overlay(field, h, zone, rim, flip) / lining(field, zone)   a separate layer over or inside (skirt lining)
    hem_below(z)                          the hem for the cloth shader's hem field (rims and cuffs are not hems)

  pieces (joined to the garment; every one exists in every fit and keeps its weights' anchor)
    buttons(points, zone, r, h, segs)     rigid buttons on the surface (cloth2.hardware)
    hardware(points, prim, zone, up)      any rigid primitive: hardware.box / frame (buckle) / disc (cockade) /
                                          ellipsoid (knot) / ring / lathe
    front_points(x, z), around_points(z, angles), limb_points(limb, t, around_deg)   where to put them
    strap(waypoints, width, lift) / fin(waypoints, depth) / band(z0, z1, lift)   straps along the body and closed
                                          bands round it (cloth2.straps): belts, sashes, harness, a legging's flap
    hat(style)                            a rigid felt hat on the head (cloth2.hats: TRICORNE, ROUND_HAT); soft caps
                                          are recipes.soft_cap (hats.head_grid: the scalp in every fit)
    add(piece)                            join any cloth2 Mesh with the same fits

  finishing
    uv(axis_top, axis_bottom, limbs)      UV parts (the body round the vertical axis, each limb along itself; parts
                                          5.. set by an operation keep their own, planar by default)
    shape_alias {"sex_head": "m"}         extra morph targets repeating a fit (head items)
    notes {...}                           measurements for the entry's checks (a hat's scalp clearance)

Order matters: cut and offset the shell, hang the skirts, fit over the layers under it, then open it (opening,
vent), then raise trims, then add linings and hardware last (a later cut would cut the buttons too).
"""

import importlib

import numpy as np

from lib import regions as RG
from cloth2 import export as EX
from cloth2 import hardware as HW
from cloth2 import trims as TR
from cloth2.mesh import BIG_FIELD, REF, concat, smoothstep, weld
from cloth2.parts import angle_from_front, hang, split_sides

TORSO = ["neck_lower", "chest_upper_front", "chest_upper_side", "chest_upper_back", "chest_front", "chest_side",
         "chest_back", "abdomen_front", "abdomen_side", "abdomen_back", "pelvis_center", "pelvis_side"]
NECK = ["neck_upper"]
ARMS = ["upper_arm_l", "forearm_a_l", "forearm_b_l", "forearm_c_l", "wrist_l",
        "upper_arm_r", "forearm_a_r", "forearm_b_r", "forearm_c_r", "wrist_r"]
LEGS = ["thigh_upper_l", "thigh_lower_l", "shin_upper_l", "shin_lower_l", "ankle_l",
        "thigh_upper_r", "thigh_lower_r", "shin_upper_r", "shin_lower_r", "ankle_r"]
# base offsets off the smoothed body (m) by layer: inside the envelope bands of cloth2.layers (lib/layers.py)
LAYER_EASE = {"base": 0.0045, "mid": 0.0090, "legwear": 0.0140, "outer": 0.0165, "wrap": 0.026}
# hanging cloth goes over to the skirt panels from its top down to this height (parts.skirt_weights). Every layer
# that hangs from the hips takes the same ramp (the shirt's tails: 0.72): an inner skirt that followed the panels
# sooner than the one over it would swing through it (a waistcoat through its coat in a bent-knee stance).
SKIRT_Z_FULL = 0.72
OVER_MAX_PUSH = 0.05         # Garment.over moves no vertex farther than this (a coat's skirt over the shirt's flared tails)


class Garment:
    def __init__(self, fits, spec):
        self.fits = fits
        self.spec = spec
        self.m = None
        self.uvparts = {}
        self.hem = None
        self.skirt = None
        self._sleeve = None
        self._ease = 0.0
        self._neck = None
        self.shape_alias = {}
        self.notes = {}             # measurements a recipe records for the entry's checks (scalp clearance, ...)

    # ---- selecting and cutting -----------------------------------------------------------------------
    def shell(self, regions, base="cloth"):
        m = self.fits.surface(base)
        ids = [RG.REGIONS[n] for n in regions]
        self.m = m.faces_of(np.isin(m.fa["region"], ids))
        return self

    @property
    def P(self):
        return self.m.ref()

    def top(self, z, dip=0.0, dip_width=0.09):
        """Cuts everything above height z (m); `dip` lowers the front (a neckline that opens at the breast bone)."""
        f = -self.P[:, 2] + (dip * np.exp(-(self.P[:, 0] / dip_width) ** 2) * smoothstep(0.0, 0.05, -self.P[:, 1])
                             if dip else 0.0)
        self.m = self.m.clip(f, -z)
        return self

    # ---- neckline ---------------------------------------------------------------------------------------
    def _neck_frame(self):
        a, b, z0, tilt, yc, dip, dip_width = self._neck
        th = np.radians(tilt)
        d = np.array([0.0, -np.sin(th), np.cos(th)])         # the neck's axis (leaning forward)
        v = np.array([0.0, -np.cos(th), -np.sin(th)])        # front of the neck, across the axis
        return np.array([0.0, yc, z0]), d, v

    def _neck_coords(self, P):
        a, b, z0, tilt, yc, dip, dip_width = self._neck
        A0, d, v = self._neck_frame()
        q = P - A0
        t = q @ d
        u = q[:, 0]
        w = q @ v
        # the front dips: the plane the neck comes off lowers at the front centre
        t0 = -dip * np.exp(-(u / dip_width) ** 2) * smoothstep(0.0, 0.03, w)
        rho = np.sqrt((u / a) ** 2 + (w / b) ** 2)
        return rho, t - t0

    def neckline(self, a=0.078, b=0.068, z0=1.325, tilt=17.0, yc=0.0, dip=0.0, dip_width=0.09):
        """The opening round the neck: the shell keeps what lies outside the ellipse (half-widths a across, b front to
        back) round the neck's axis, or below the plane the neck comes off (perpendicular to the axis; `dip` lowers
        it at the front centre). The edge follows the neck's root on the shoulders instead of a level line (no horns
        at the trapezius, no boat neck)."""
        self._neck = (a, b, z0, tilt, yc, dip, dip_width)
        rho, t = self._neck_coords(self.P)
        # keep where rho > 1 or below the plane: the max is continuous
        f = np.maximum((rho - 1.0) * min(a, b), -t)
        self.m = self.m.clip(f, 0.0)
        return self

    def collar_zone(self, idx, width=0.035):
        """Zone `idx` for the band of width `width` (m) along the neckline (cut along its border first)."""
        a, b = self._neck[0], self._neck[1]
        def h(P):
            rho, t = self._neck_coords(P)
            return np.minimum((1.0 + width / min(a, b) - rho) * min(a, b), t + width)
        self.m = self.m.split(h(self.P), 0.0)
        c = self.m.face_centres()
        self.m.fa["zone"][h(c) > 0.0] = idx
        return self

    def bottom(self, z):
        """Cuts everything below height z: where the shell ends and the tails, skirt or hem begin."""
        self.m = self.m.clip(self.P[:, 2], z)
        return self

    def cut_limb(self, limb, end, keep_root=True):
        """Cuts a limb ('arm_l' ...) beyond its parameter `end` (0 root .. 1 end): sleeves, trouser legs."""
        t = self.m.A["t_" + limb]
        member = self.m.A["m_" + limb]
        f = (end - t) + BIG_FIELD * (1.0 - member)
        self.m = self.m.clip(f if keep_root else -f, 0.0)
        return self

    def sleeves(self, end=0.925, ease=(0.006, 0.013), gather=0.008, gather_from=0.80):
        """Both arms to parameter `end`; the ease (m) rises from ease[0] at the shoulder to ease[1] at mid arm and
        falls by `gather` at the cuff."""
        self.cut_limb("arm_l", end)
        self.cut_limb("arm_r", end)
        self._sleeve = (end, ease, gather, gather_from)
        return self

    def legs(self, end=1.0, ease=(0.014, 0.014), gather=0.0, gather_from=0.9):
        self.cut_limb("leg_l", end)
        self.cut_limb("leg_r", end)
        self._legs = (end, ease, gather, gather_from)
        return self

    def seams(self, back=True, limbs=("arm_l", "arm_r")):
        """Straight seam lines (mesh edges along them: the UV seams and a proper stitched look): down the centre back
        and under each limb."""
        f_ = self.fits
        if back:
            w = smoothstep(0.02, 0.05, self.P[:, 1])
            self.m = self.m.split(self.P[:, 0] + BIG_FIELD * (1.0 - w), 0.0)
        for limb in limbs:
            side, kind = limb.split("_")[1], limb.split("_")[0]
            chain = f_.arm(side) if kind == "arm" else f_.leg(side)
            ax = chain[-1] - chain[0]
            ax = ax / np.linalg.norm(ax)
            under = np.cross(ax, [0.0, 0.0, -1.0]) if kind == "arm" else np.array([0.0, 1.0, 0.0])
            under = under / np.linalg.norm(under)
            member = self.m.A["m_" + limb]
            t = self.m.A["t_" + limb]
            sgn = 1 if side == "l" else -1
            w = member * smoothstep(0.12, 0.20, t) * (smoothstep(0.0, 0.05, sgn * self.P[:, 0]) if kind == "arm" else 1.0)
            self.m = self.m.split((self.P - chain[0]) @ under + BIG_FIELD * (1.0 - w), 0.0)
        return self

    # ---- offsets ---------------------------------------------------------------------------------------
    def fit(self, ease=None, layer=None, smooth=3, gap=0.002):
        """Offsets the shell off the cloth surface (the layer's ease unless given; sleeves and legs by their
        profiles), smooths it and pushes it clear of the skin in every fit."""
        m = self.m
        if ease is None:
            ease = LAYER_EASE[layer or self._layer_name()]
        self._ease = ease
        off = np.full(m.n, float(ease))
        for limb, prof in (("arm_l", self._sleeve), ("arm_r", self._sleeve), ("leg_l", getattr(self, "_legs", None)),
                           ("leg_r", getattr(self, "_legs", None))):
            if prof is None:
                continue
            end, e, gather, g0 = prof
            t = m.A["t_" + limb]
            mem = m.A["m_" + limb]
            a = e[0] + (e[1] - e[0]) * smoothstep(0.18, 0.42, t) - gather * smoothstep(g0, end, t)
            off = off * (1.0 - mem) + (ease + a - e[0]) * mem
        m.offset(off, vertical=0.3)
        m.smooth(smooth, 0.5)
        self.fits.clear(m, np.maximum(gap, 0.0))
        return self

    def _layer_name(self):
        from cloth2.spec import LAYERS
        d = self.spec.layer.get("default", 10)
        for k, v in LAYERS.items():
            if v == d and k in LAYER_EASE:
                return k
        return "base"

    def crotch(self, drop=0.02, width=0.07, z_crotch=0.76):
        """Lowers the crotch of trousers and breeches a little (a gusset between the thighs). The male genitals are
        hidden under the garment (the fit's cloth surface leaves them out: cloth2.fit), so the seat needs no pad."""
        m = self.m
        P = self.P
        w = np.exp(-(P[:, 0] / width) ** 2) * np.exp(-((P[:, 2] - z_crotch) / 0.07) ** 2)
        w = w * smoothstep(-0.02, 0.03, P[:, 1] * -1.0 + 0.10)         # a little less far behind
        d = np.array([0.0, -0.35, -1.0])
        d = d / np.linalg.norm(d)
        for fit in m.V:
            m.V[fit] = m.V[fit] + w[:, None] * d * drop
        m.recompute_normals()
        return self

    # ---- hanging cloth ---------------------------------------------------------------------------------
    def tails(self, hem, side_hem=None, flare=0.06, folds=0.008, steps=9, slits=None, edge_z=None, x_limit=0.26,
              z_full=0.72, gap=0.004, pleats=None, edge_angle=None):
        """Cloth hanging from the shell's bottom edge (the torso's, not the sleeves') to height `hem` (front and
        back) / `side_hem` (at the sides); `hem` may be a function of the edge's reference positions instead
        (hem_by_angle). pleats: localized pleat groups (parts.pleat_offset); edge_angle: only the edge within this
        many degrees of the front hangs (an apron); gap: the hung cloth's clearance over the cloth surface (m, or a
        function of reference positions)."""
        side_hem = hem if side_hem is None else side_hem
        z0 = float(self.P[:, 2][self.m.boundary()[1]].min()) if edge_z is None else edge_z
        mask = (self.P[:, 2] < z0 + 0.03) & (np.abs(self.P[:, 0]) < x_limit)
        if edge_angle is not None:
            mask &= angle_from_front(self.P) < edge_angle
        hem_fn = hem if callable(hem) else \
            (lambda P: hem + (side_hem - hem) * np.exp(-((angle_from_front(P) - 90.0) / 28.0) ** 2))
        self.m = hang(self.fits, self.m, mask, hem=hem_fn, steps=steps, flare=flare, folds=folds, slits=slits,
                      z_full=z_full, pleats=pleats)
        self.m.smooth(2, 0.4)
        # (clearance over whatever is worn under: the breeches' 15 mm, the shift's tails; only the hanging cloth)
        hung = self.m.ref()[:, 2] < z0 - 0.004
        if callable(gap):
            gap = np.asarray(gap(self.m.ref()), float)
        self._hung_z = z0
        self.fits.clear(self.m, np.where(hung, gap, 0.002), surface="cloth")
        # a local push over a bulge (the male fit's pad) would stand up as a spike: spread it, then clear again
        for _ in range(3):
            self.m.smooth(4, 0.5, weights=hung.astype(float))
            self.fits.clear(self.m, np.where(hung, gap, 0.002), surface="cloth")
        # (the smoothing above pulled the shell back toward the skin: its clearance again, against the skin itself)
        self.fits.clear(self.m, np.where(hung, 0.0, 0.002), surface="skin")
        return self

    # ---- tailoring: openings, vents, armholes (cloth2.trims) ------------------------------------------------
    def opening(self, table, x0=0.0, min_w=0.0025, front_y=-0.04):
        """Cuts the front open where |x - x0| < w(z): `table` [(z, half-width m), ...] (z rising), interpolated; at
        least min_w (a buttoned edge-to-edge front still shows its line). Only the front (y below front_y .. 0)."""
        zs = np.array([t[0] for t in table], float)
        ws = np.maximum(np.array([t[1] for t in table], float), min_w)
        P = self.P
        f = np.abs(P[:, 0] - x0) - np.interp(P[:, 2], zs, ws) + BIG_FIELD * smoothstep(front_y, 0.0, P[:, 1])
        self.m = TR.drop_small(self.m.clip(f, 0.0))
        self._opening = (zs, ws, x0)
        return self

    def hem_below(self, z):
        """The hem for the cloth shader's hem field (export edge_fields): the boundary below height z (instead of the
        lowest third of every boundary, which rims and cuffs would join)."""
        self.hem = lambda m: m.boundary()[1] & (m.V[REF][:, 2] < z)
        return self

    def opening_w(self, z):
        zs, ws, _ = self._opening
        return np.interp(z, zs, ws)

    def vent(self, z_top, half=0.003, split=True):
        """A back vent: a slit up the centre back from the hem to z_top; each side then follows its own leg
        (parts.split_sides)."""
        P = self.P
        f = (np.abs(P[:, 0]) - half) + BIG_FIELD * smoothstep(z_top, z_top + 0.02, P[:, 2]) + \
            BIG_FIELD * (1.0 - smoothstep(0.0, 0.03, P[:, 1]))
        self.m = self.m.clip(f, 0.0)
        if split:
            self.split_sides(lambda P: (P[:, 1] > 0.0) & (P[:, 2] < z_top + 0.02))
        return self

    def split_sides(self, where):
        """The hanging cloth `where(P)` (bool per vertex, reference positions) takes only its own side's skirt panels."""
        split_sides(self.fits, self.m, np.asarray(where(self.P), bool) & (self.P[:, 2] < getattr(self, "_hung_z", 2.0)))
        return self

    def armholes(self, size=(0.052, 0.062, 0.092), centre=(0.012, 0.004, -0.040), t_cut=0.10):
        """Sleeveless (a waistcoat): the arms cut off at the shoulder by an ellipsoid round each shoulder joint (a round
        armhole, not the jagged region border) and beyond parameter t_cut along the arm."""
        P = self.P
        f = np.full(len(P), BIG_FIELD)
        for s in ("l", "r"):
            sg = 1.0 if s == "l" else -1.0
            c = self.fits.J[s + "_shoulder"] + np.array([sg * centre[0], centre[1], centre[2]])
            q = (P - c) / np.asarray(size)
            f = np.minimum(f, (np.linalg.norm(q, axis=1) - 1.0) * min(size))
            member = self.m.A["m_arm_" + s]
            f = np.minimum(f, (t_cut - self.m.A["t_arm_" + s]) + BIG_FIELD * (1.0 - member))
        self.m = TR.drop_small(self.m.clip(f, 0.0), 30)
        return self

    # ---- tailoring: raised and added cloth -------------------------------------------------------------------
    def _sel(self, where, cut=True):
        """A face selection from a field (callable on reference positions or per vertex: < 0 selected; cut along its
        zero line first) or a bool mask over faces."""
        if isinstance(where, np.ndarray) and where.dtype == bool and len(where) == len(self.m.F):
            return where
        if cut:
            self.m, sel = TR.split_mask(self.m, where)
            return sel
        return TR.face_mask(self.m, where)

    def select(self, where, cut=True):
        return self._sel(where, cut)

    def raised(self, where, h, zone=None, rim=True):
        """The faces `where` selects stand h (m) proud, a rim at their border: cuffs, lapels, flaps, turnbacks, collars."""
        sel = self._sel(where)
        self.m = TR.raise_region(self.m, sel, h, zone=zone, rim=rim)
        return self

    def overlay(self, where, h, zone, rim=False, flip=False, part=None):
        """A separate layer of cloth over (h > 0) or under (h < 0) the faces `where` selects."""
        sel = self._sel(where)
        piece = TR.overlay(self.m, sel, h, zone, rim=rim, flip=flip, part=part)
        if piece is not None:
            self.add(piece)
        return self

    def lining(self, where, zone, inset=0.0016):
        """The inside of the faces `where` selects in zone `zone` (a coat's skirt lining): a copy turned over, `inset`
        inside the cloth."""
        return self.overlay(where, -inset, zone, rim=False, flip=True)

    def cuffs(self, t0, h=0.005, zone=1, rim=True, limbs=("arm_l", "arm_r"), flare=0.0, end=None):
        """Round cuffs: the sleeve beyond the plane square to the forearm at arm parameter t0 raised h, in `zone`;
        `flare` (m) more at the cuff's top edge, tapering to nothing at `end` (the sleeve's end parameter)."""
        end = self._sleeve[0] if (end is None and self._sleeve) else (end or 0.92)
        for lb in limbs:
            ch = self.fits.arm(lb[-1]) if lb.startswith("arm") else self.fits.leg(lb[-1])
            L1, L2 = np.linalg.norm(ch[1] - ch[0]), np.linalg.norm(ch[2] - ch[1])
            s = t0 * (L1 + L2)
            seg = (ch[0], ch[1]) if s <= L1 else (ch[1], ch[2])
            ax = (seg[1] - seg[0]) / np.linalg.norm(seg[1] - seg[0])
            c = ch[0] + ax * s if s <= L1 else ch[1] + ax * (s - L1)
            mem = self.m.A["m_" + lb]
            f = -((self.P - c) @ ax) + BIG_FIELD * (1.0 - smoothstep(0.3, 0.6, mem)) + \
                BIG_FIELD * (1.0 - smoothstep(t0 - 0.15, t0 - 0.10, self.m.A["t_" + lb]))
            if flare:
                span = max((end - t0) * (L1 + L2), 1e-3)
                hh = lambda P, c=c, ax=ax, span=span: h + flare * np.clip(1.0 - ((P - c) @ ax) / span, 0.0, 1.0) ** 1.5
            else:
                hh = h
            self.raised(f, hh, zone, rim)
        return self

    def edge_zone(self, idx, width, select=None, h=0.0):
        """Zone `idx` for the band within `width` (m, along the cloth) of the boundary vertices select(P) keeps (all
        boundaries when None): piping, a binding, a glow cord (Zone glow=...); raised by h if given."""
        self.m, sel = TR.edge_band(self.m, select, width)
        if h:
            self.m = TR.raise_region(self.m, sel, h, zone=idx, rim=True)
        else:
            self.m.fa["zone"][sel] = idx
        return self

    def collar_fall(self, width=0.05, h=0.003, zone=1):
        """A falling collar: the band of `width` round the neckline turned down onto the shoulders (raised, a rim at
        its lower edge)."""
        a = self._neck
        nz = (a[2] - 0.08) if a else 1.25
        return self.edge_zone(zone, width, select=lambda P: P[:, 2] > nz, h=h)

    def stand_collar(self, height=0.03, lean=0.25, zone=1, rings=2):
        """A standing collar grown up from the neckline edge: `height` (m) along the neck's axis, leaning in by `lean`
        of the height."""
        a, b, z0, tilt, yc, dip, dip_width = self._neck
        th = np.radians(tilt)
        up = np.array([0.0, -np.sin(th), np.cos(th)])

        def disp(fit, P0, N0, s):
            inward = np.stack([-P0[:, 0], yc - P0[:, 1], np.zeros(len(P0))], 1)
            inward = inward / np.maximum(np.linalg.norm(inward, axis=1, keepdims=True), 1e-9)
            return (up[None] + inward * lean) * (height * s)
        piece = TR.extrude(self.m, lambda P: P[:, 2] > z0 - 0.09, disp, rings=rings, zone=zone)
        if piece is not None:
            self.add(piece)
        return self

    def relieve(self, centres, radius=0.065, depth=0.007):
        """Less ease round points (m, reference fit; a Gaussian of `radius`): the armpit, where the arms coming down
        from the bind pose fold the cloth into itself. Clear of the skin after; over() keeps the layers under."""
        P = self.P
        w = np.zeros(len(P))
        for c in np.atleast_2d(np.asarray(centres, float)):
            w = np.maximum(w, np.exp(-np.sum((P - c) ** 2, axis=1) / radius ** 2))
        self.m.offset(-depth * w, vertical=0.3)
        self.fits.clear(self.m, 0.002)
        return self

    def armpits(self, drop=0.085, inset=0.015):
        """The two armpit points (below and inside each shoulder joint) for relieve()."""
        J = self.fits.J
        return np.array([J["l_shoulder"] + [-inset, 0.0, -drop], J["r_shoulder"] + [inset, 0.0, -drop]])

    # ---- garments worn under ---------------------------------------------------------------------------------
    def over(self, ids, gap=0.004, where=None):
        """Pushes the garment clear of the garments `ids` (catalog ids of cloth2 garments, built in this run: see
        `built`) by `gap` (m; or per vertex / a function of reference positions) in every fit; `where` (a function of
        reference positions -> bool) limits it. The layer then never lets an inner one through in the bind pose."""
        meshes = [built(self.fits, gid)[0] for gid in ids if gid != self.spec.id]
        if not meshes:
            return self
        obs = self.fits.obstacles(meshes)
        g = gap(self.P) if callable(gap) else gap
        g = np.broadcast_to(np.asarray(g, float), (self.m.n,)).copy()
        if where is not None:
            g[~np.asarray(where(self.P), bool)] = -1.0
        before = self.m.V[REF].copy()
        self.fits.clear(self.m, g, surface=obs, max_push=OVER_MAX_PUSH)
        # a push over an inner layer's edge (a waistband, a shirt's tails) would stand as a ridge: spread it over the
        # neighbours that moved, then clear again
        moved = np.linalg.norm(self.m.V[REF] - before, axis=1) > 0.0005
        if moved.any():
            E = self.m.adjacency()
            w = moved.astype(float)
            for _ in range(3):
                nb = np.zeros(self.m.n)
                np.maximum.at(nb, E[:, 0], w[E[:, 1]])
                w = np.maximum(w, nb * 0.7)
            for _ in range(2):
                self.m.smooth(3, 0.5, weights=w)
                self.fits.clear(self.m, g, surface=obs, max_push=OVER_MAX_PUSH)
        self.fits.clear(self.m, 0.002, surface="skin")
        return self

    # ---- pieces: hardware and straps ------------------------------------------------------------------------
    def add(self, piece):
        """Joins a piece (hardware, a strap, an overlay) to the garment."""
        if piece is None or not len(piece.F):
            return self
        self.m = piece if self.m is None else concat([self.m, piece])
        return self

    def front_points(self, x, z, y0=-0.5):
        """Points of the garment's front at (x, z): rays from the front toward +y."""
        x, z = np.broadcast_arrays(np.asarray(x, float), np.asarray(z, float))
        O = np.stack([x, np.full(x.shape, y0), z], -1).reshape(-1, 3)
        P, ok = HW.ray_points(self.m, O, [0.0, 1.0, 0.0], 1.0)
        return P[ok]

    def around_points(self, z, angles):
        """Points of the garment at height z and degrees round from the front (+ the wearer's left)."""
        P, ok = HW.toward_axis(self.m, z, angles)
        return P[ok]

    def limb_points(self, limb, t, around_deg=0.0, side=None):
        """Points on a sleeve or leg at parameters t: rays toward the limb's axis from the outside, `around_deg`
        degrees round from its outer side toward the back."""
        chain = self.fits.arm(limb[-1]) if limb.startswith("arm") else self.fits.leg(limb[-1])
        t = np.atleast_1d(np.asarray(t, float))
        L = np.cumsum([0.0] + [np.linalg.norm(chain[i + 1] - chain[i]) for i in range(len(chain) - 1)])
        out = []
        sg = 1.0 if limb.endswith("l") else -1.0
        for tt in t:
            s = tt * L[-1]
            i = min(int(np.searchsorted(L, s, side="right")) - 1, len(chain) - 2)
            u = (s - L[i]) / max(L[i + 1] - L[i], 1e-9)
            c = chain[i] + (chain[i + 1] - chain[i]) * u
            ax = (chain[i + 1] - chain[i]) / max(L[i + 1] - L[i], 1e-9)
            outer = np.array([sg, 0.0, 0.0]) if side is None else np.asarray(side, float)
            outer = outer - ax * (outer @ ax)
            outer /= np.linalg.norm(outer)
            back = np.cross(ax, outer) * (-sg)
            a = np.radians(around_deg)
            d = outer * np.cos(a) + back * np.sin(a)
            P, ok = HW.ray_points(self.m, [c + d * 0.15], [-d], 0.16)
            if ok[0]:
                out.append(P[0])
        return np.array(out).reshape(-1, 3)

    def buttons(self, points, zone, r=0.0085, h=0.0032, segs=8, up=(0.0, 0.0, 1.0), lift=0.0):
        """Rigid buttons at `points` (on the garment's surface, reference fit), in `zone`."""
        P = np.asarray(points, float).reshape(-1, 3)
        if not len(P):
            return self
        b = HW.Binding(self.m, P)
        return self.add(HW.rigid(self.m, b, HW.button(r, h, segs), zone, up=up, lift=lift))

    def hardware(self, points, prim, zone, up=(0.0, 0.0, 1.0), lift=0.0, spin=None):
        """Any rigid piece (cloth2.hardware primitives: a buckle frame, a knot, a pouch box, a ring) at `points`."""
        P = np.asarray(points, float).reshape(-1, 3)
        if not len(P):
            return self
        b = HW.Binding(self.m, P)
        return self.add(HW.rigid(self.m, b, prim, zone, up=up, lift=lift, spin=spin))

    def strap(self, waypoints, width, lift, zone=0, step=0.012, width_fn=None):
        """A strap along the cloth surface through `waypoints` (reference fit), `lift` (m) off it, rigid across."""
        from cloth2 import straps as SP
        path = SP.surface_path(self.fits, waypoints, step)
        self._last_path = path
        return self.add(SP.strip(self, path, width, lift, zone, width_fn=width_fn))

    def fin(self, waypoints, depth, lift, zone=0, step=0.015):
        from cloth2 import straps as SP
        path = SP.surface_path(self.fits, waypoints, step)
        return self.add(SP.fin(self, path, depth, lift, zone))

    def band(self, z0, z1, lift, zone=0, regions=None):
        """A closed band round the torso (a belt, a sash, a waistband) joined to the garment."""
        from cloth2 import straps as SP
        return self.add(SP.band(self, z0, z1, lift, regions=regions, zone=zone))

    # ---- headwear (cloth2.hats) -----------------------------------------------------------------------------
    def hat(self, style, zones=(0, 1, 2, 3)):
        """A rigid felt hat (hats.TRICORNE, hats.ROUND_HAT or a variant) as the garment."""
        from cloth2 import hats as HT
        HT.rigid_hat(self, style, zones)
        self.notes["scalp_clearance_mm"] = {k: [round(v[0] * 1000, 1), round(v[1] * 1000, 1)] for k, v in
                                            HT.scalp_clearance(self.fits, self.m.V).items()}
        return self

    # ---- zones and UV -----------------------------------------------------------------------------------
    def zone(self, idx, above=None, below=None, limb=None, t_above=0.0, cut=True):
        """Marks faces as zone `idx`: by height (centre above / below z), or along a limb ('arm_l' or a list; t above).
        `cut`: the mesh is cut along the zone's border first, so the colour changes along a clean line."""
        if cut:
            if limb is not None:
                for lb in ([limb] if isinstance(limb, str) else limb):
                    f = (self.m.A["t_" + lb] - t_above) + BIG_FIELD * (1.0 - self.m.A["m_" + lb])
                    self.m = self.m.split(f, 0.0)
            for z in (above, below):
                if z is not None and limb is None:
                    self.m = self.m.split(self.P[:, 2] - z, 0.0)
        m = self.m
        c = m.face_centres()
        if limb is not None:
            sel = np.zeros(len(m.F), bool)
            for lb in ([limb] if isinstance(limb, str) else limb):
                t = m.A["t_" + lb][m.F].mean(1)
                mem = m.A["m_" + lb][m.F].min(1)
                sel |= (mem > 0.5) & (t > t_above)
        else:
            sel = np.ones(len(m.F), bool)
        if above is not None:
            sel &= c[:, 2] > above
        if below is not None:
            sel &= c[:, 2] < below
        m.fa["zone"][sel] = idx
        return self

    def uv(self, axis_top=1.4, axis_bottom=0.9, limbs=("arm_l", "arm_r", "leg_l", "leg_r")):
        """UV parts: the body round the vertical axis, each arm and leg along itself (the seams: centre back, under
        the arm, the outer side of the leg)."""
        m = self.m
        part = np.zeros(len(m.F), int)
        J = self.fits.J
        self.uvparts = {0: ("cyl", [0, 0.0, axis_bottom], [0, 0.0, axis_top], [0, -1, 0])}
        for pid, limb in ((1, "arm_l"), (2, "arm_r"), (3, "leg_l"), (4, "leg_r")):
            if limb not in limbs:
                continue
            part[m.A["m_" + limb][m.F].min(1) > 0.5] = pid
            s = limb.split("_")[1]
            if limb.startswith("arm"):
                self.uvparts[pid] = ("cyl", J[s + "_shoulder"], J[s + "_wrist"], [0, 0, 1])
            else:
                self.uvparts[pid] = ("cyl", J[s + "_upper_leg"], J[s + "_ankle"], [-1 if s == "l" else 1, 0, 0])
        # parts 5.. were set by the operations that made them (a brim, straps, hardware): kept, planar by default
        keep = m.fa["part"] >= 5
        part[keep] = m.fa["part"][keep]
        for pid in np.unique(part[keep]):
            self.uvparts.setdefault(int(pid), ("planar", [0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, 1.0]))
        m.fa["part"] = part
        return self

    def result(self):
        kw = {"skirt": self.skirt} if self.skirt else {}
        if callable(self.hem):
            kw["hem"] = self.hem
        if self.shape_alias:
            kw["shape_alias"] = dict(self.shape_alias)
        if self.notes:
            kw["extra_checks"] = dict(self.notes)
        return self.m, self.uvparts, kw


# ---- building, and the garments a garment is fitted over --------------------------------------------------------
_BUILT = {}


def built(fits, gid, build=None, spec=None):
    """(mesh, uvparts, kw) of garment `gid` built on `fits` (once per run: Garment.over() of a later garment and the
    garment's own export share it). `build` / `spec` default to the module cloth2.garments.<gid>."""
    key = (id(fits), gid)
    if key not in _BUILT:
        if build is None or spec is None:
            mod = importlib.import_module("cloth2.garments." + gid)
            build, spec = mod.build, mod.SPEC
        g = Garment(fits, spec)
        build(g)
        m, uvparts, kw = g.result()
        m = weld(m)
        m.recompute_normals()
        _BUILT[key] = (m, uvparts, kw)
    return _BUILT[key]


def runner(spec, build):
    def build_and_export(ctx, fits, export=True):
        m, uvparts, kw = built(fits, spec.id, build, spec)
        return EX.finish(ctx, fits, spec, m.copy(), uvparts, export=export, **kw)
    return build_and_export
