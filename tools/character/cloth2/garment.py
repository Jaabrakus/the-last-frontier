"""cloth2 Garment: the recipe interface. A garment module is a few calls on a Garment (2026-09-28):

    def build(g):
        g.shell(TORSO + ARMS)                          # the body under the cloth: which regions
        g.top(1.336).bottom(0.905)                     # cut lines (height, m)
        g.sleeves(end=0.925, ease=(0.006, 0.013), gather=0.008)
        g.seams()                                      # straight centre-back and under-sleeve lines (the UV seams)
        g.fit(ease=0.0055)                             # offset off the cloth surface, smooth, clear of the skin
        g.tails(hem=0.60, side_hem=0.69, flare=0.06, slits=[(84, 96, 0.74)])
        g.zone(1, above=1.30)                          # the collar band is zone 1
    run = garment.runner(SPEC, build)                  # build_and_export(ctx, fits, export)

Everything is done on the reference fit and replayed on the male fit and the bust gauge (cloth2.mesh).
"""

import numpy as np

from lib import regions as RG
from cloth2 import export as EX
from cloth2.mesh import BIG_FIELD, REF, concat, smoothstep, weld
from cloth2.parts import angle_from_front, hang

TORSO = ["neck_lower", "chest_upper_front", "chest_upper_side", "chest_upper_back", "chest_front", "chest_side",
         "chest_back", "abdomen_front", "abdomen_side", "abdomen_back", "pelvis_center", "pelvis_side"]
NECK = ["neck_upper"]
ARMS = ["upper_arm_l", "forearm_a_l", "forearm_b_l", "forearm_c_l", "wrist_l",
        "upper_arm_r", "forearm_a_r", "forearm_b_r", "forearm_c_r", "wrist_r"]
LEGS = ["thigh_upper_l", "thigh_lower_l", "shin_upper_l", "shin_lower_l", "ankle_l",
        "thigh_upper_r", "thigh_lower_r", "shin_upper_r", "shin_lower_r", "ankle_r"]
# base offsets off the smoothed body (m) by layer: inside the envelope bands of cloth2.layers (lib/layers.py)
LAYER_EASE = {"base": 0.0045, "mid": 0.0090, "legwear": 0.0140, "outer": 0.0165, "wrap": 0.026}


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
              z_full=0.72, gap=0.004):
        """Cloth hanging from the shell's bottom edge (the torso's, not the sleeves') to height `hem` (front and
        back) / `side_hem` (at the sides)."""
        side_hem = hem if side_hem is None else side_hem
        z0 = float(self.P[:, 2][self.m.boundary()[1]].min()) if edge_z is None else edge_z
        mask = (self.P[:, 2] < z0 + 0.03) & (np.abs(self.P[:, 0]) < x_limit)
        self.m = hang(self.fits, self.m, mask,
                      hem=lambda P: hem + (side_hem - hem) * np.exp(-((angle_from_front(P) - 90.0) / 28.0) ** 2),
                      steps=steps, flare=flare, folds=folds, slits=slits, z_full=z_full)
        self.m.smooth(2, 0.4)
        # (clearance over whatever is worn under: the breeches' 15 mm, the shift's tails; only the hanging cloth)
        hung = self.m.ref()[:, 2] < z0 - 0.004
        self.fits.clear(self.m, np.where(hung, gap, 0.002), surface="cloth")
        # a local push over a bulge (the male fit's pad) would stand up as a spike: spread it, then clear again
        for _ in range(3):
            self.m.smooth(4, 0.5, weights=hung.astype(float))
            self.fits.clear(self.m, np.where(hung, gap, 0.002), surface="cloth")
        # (the smoothing above pulled the shell back toward the skin: its clearance again, against the skin itself)
        self.fits.clear(self.m, np.where(hung, 0.0, 0.002), surface="skin")
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
        m.fa["part"] = part
        return self

    def result(self):
        return self.m, self.uvparts, ({"skirt": self.skirt} if self.skirt else {})


def runner(spec, build):
    def build_and_export(ctx, fits, export=True):
        g = Garment(fits, spec)
        build(g)
        m, uvparts, kw = g.result()
        return EX.finish(ctx, fits, spec, m, uvparts, export=export, **kw)
    return build_and_export
