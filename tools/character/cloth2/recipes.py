"""cloth2 recipes shared by several garments: the recipe TYPES (2026-10-02). Each takes a Garment and a style dict
(the defaults below, overridden per garment), so a garment module is a SPEC and one call:

  shirt(g, ...)                   a linen shirt or shift: body and sleeves as one shell, tails from the hips
  coat(g, style)                  a fitted coat with skirts: justaucorps, regimental, frock, officer's long coat
                                  (COAT; MARINE_JUSTAUCORPS, REGIMENTAL_1751, FROCK below); jacket(g, style) is the
                                  same cut short (a sailor's or ranger's jacket, the women's jacket with its basque),
                                  capot(g, style) the hooded wrap-over coat
  waistcoat(g, style)             a waistcoat or veste: sleeveless (armholes) or sleeved, V-neck, buttoned front with
                                  parting points, pocket flaps, a linen back (WAISTCOAT)
  apron(g, style)                 a waistband and a front-only gathered skirt over the petticoat (APRON)
  neckwear(g, kind, style)        "stock", "cravat", "neckerchief": a band round the neck, a knot, hanging ends
  soft_cap(g, kind, style)        "monmouth", "tuque", "womens": knit or linen caps grown over the head
  rigid_hat(g, style)             a felt hat: hats.TRICORNE, hats.ROUND_HAT
  leggings(g, style)              wool leggings (a side flap, garters) and gaiters (buttons down the outer side)
  belt(g, style), sash(g, style), harness(g, style), pouch_belt(g, style)
                                  strap accessories: bands round the body, straps along it, rigid hardware
  robe, tunic, trousers, wrap_skirt, drape, cloak, head_wrap, lathe_hat, hose
                                  the peoples' dress types (2026-10-03): defined in cloth2.dress (its docstring and
                                  garment.py's list every key), wrapped here; sash(g, {"turns": n}) winds a sash,
                                  soft_cap "skullcap", shirt(bottom=, slits=, front_slit=, sleeve_wide=)

Zones by convention: 0 the cloth, 1 facings / lining / trim, 2 buttons and metal, 3 lace, piping or a glow cord
(spec.Zone(..., glow=Glow()) flags it emissive). Heights are on the reference fit (the female base: waist ~1.02,
hip ~0.93, knee ~0.47, ankle ~0.08; the joints in fits.J).
"""

import copy

import numpy as np

from cloth2 import garment as G
from cloth2 import hardware as HW
from cloth2 import trims as TR
from cloth2.mesh import BIG_FIELD, REF, smoothstep
from cloth2.parts import angle_from_front, closed_skirt_weights, split_sides


def shirt(g, hem=0.60, side_hem=0.69, sleeve_end=0.925, neck=None, dip=0.0, dip_width=0.09, gather=0.008,
          sleeve_ease=(0.006, 0.013), ease=0.0055, slit_top=0.74, collar=True, band_t=0.88, steps=9, flare=0.06,
          tail_gap=0.024, z_full=0.72, bottom=0.905, slits=None, front_slit=None, sleeve_wide=0.0, wide_from=0.45,
          over=(), over_gap=0.004):
    """A linen shirt or shift: the body and sleeves as one shell, tails from the hips.

    The hem cuts (2026-10-03, the peoples' dress): `bottom` is where the shell ends and the tails begin (a hem at or
    above it is a short shirt cut straight there, no tails: the Filipino baro at 0.96); `slits` replaces the side slits
    [(from deg, to deg, up to z)] (default the side slits to slit_top); `front_slit` {"z0", "w": (bottom, top half-
    width), "x", "angle"} an open slit down from the neck (dress.front_slit: the collarless shirt's to 1.20, the
    Persian left-shoulder opening at an angle); `sleeve_wide` (m) the sleeves widening toward an open cuff from arm
    parameter `wide_from` (band_t None: no wrist band); `over` the garments it is fitted over (a frock worn over the
    clothes)."""
    g.shell(G.TORSO + G.ARMS)
    tails = min(hem, side_hem) < bottom - 0.01
    g.neckline(dip=dip, dip_width=dip_width, **(neck or {})).bottom(bottom if tails else max(hem, side_hem))
    if sleeve_wide:
        g.sleeves(end=sleeve_end, ease=sleeve_ease, gather=-sleeve_wide, gather_from=wide_from)
    else:
        g.sleeves(end=sleeve_end, ease=sleeve_ease, gather=gather)
    g.seams()
    g.fit(ease=ease)
    if tails:
        g.tails(hem=hem, side_hem=side_hem, flare=flare, steps=steps,
                slits=[(84.0, 96.0, slit_top)] if slits is None else slits, gap=tail_gap, z_full=z_full)
    if over:
        g.over(over, over_gap)
    if front_slit:
        from cloth2 import dress as DR
        DR.front_slit(g, **front_slit)
    if collar:
        g.collar_zone(1, 0.035)
    if band_t is not None:
        g.zone(1, limb=("arm_l", "arm_r"), t_above=band_t if sleeve_end > 0.9 else sleeve_end - 0.05)
    g.uv()


def style(_base, **over):
    """A copy of a style dict with some entries replaced (nested dicts replaced whole)."""
    s = copy.deepcopy(_base)
    s.update(over)
    return s


def hem_by_angle(front, side, back):
    """hem(P): the hem height by the angle round from the front (front at 0, side at 90, back at 180 degrees)."""
    return lambda P: np.interp(angle_from_front(P), [0.0, 90.0, 180.0], [front, side, back])


# ======================================================================================================================
# coats
# ======================================================================================================================
COAT = {
    "neck": {"a": 0.094, "b": 0.086, "z0": 1.335, "tilt": 17.0},   # collarless: the edge ~2 cm off the neck
    "bottom": 0.905,                    # the shell ends at the hips; the skirts hang from there
    "ease": G.LAYER_EASE["outer"],
    "sleeve_end": 0.90, "sleeve_ease": (0.0, 0.008), "gather": 0.0,
    "hem": (0.555, 0.535, 0.525),       # front, side, back (m)
    "flare": 0.07, "folds": 0.003, "steps": 8, "z_full": G.SKIRT_Z_FULL,
    "pleats": [(122.0, 34.0, 2, 0.011)],      # two pleats behind each hip
    "skirt_gap": 0.03,                  # the skirts' room over the cloth surface (shirt tails, breeches)
    "over": (), "over_gap": 0.007,      # catalog ids fitted over (Garment.over), and the room left over them
    "opening": [(0.40, 0.11), (0.52, 0.10), (0.62, 0.085), (0.75, 0.06), (0.86, 0.03), (0.93, 0.012), (1.0, 0.0),
                (1.6, 0.0)],            # front opening half-width by height (m): buttoned to the waist, cut away below
    "overlap": None,                    # instead of an opening: {"x": -0.05, "split_below": 0.86, "h": 0.003}
    "overlap_line": None,               # the robes' overlap (cloth2.dress.ROBE): {"line": [(z, theta deg)], "split_below",
                                        # "w", "h", "outer", "split_weights"}: an edge running round the body
    "sleeveless": None,                 # Garment.armholes keys: no sleeves, round armholes (cloth2.dress.ROBE sleeves None)
    "slits": None,                      # side slits in the skirts [(from deg, to deg, up to z)] (both sides)
    "over_relax": 0,                    # rounds of smoothing the skirts and fitting them over the layers again
    "vent": 0.80,                       # back vent up to (m), or None
    "cuffs": {"t0": 0.64, "h": 0.005, "flare": 0.007},  # round cuffs from arm parameter t0, flaring at the top
    "lapels": None,                     # {"z": (z0, z1), "w": (w0, w1), "h": 0.0022}: facing-coloured lapels
    "collar": None,                     # ("fall", width) or ("stand", height)
    "pockets": {"z": (0.83, 0.88), "a": (52.0, 98.0), "h": 0.0032, "buttons": 5, "on_flap": True},
    "turnbacks": None,                  # {"w_hem": 0.105, "z_top": 0.90}: the skirt fronts turned back (facing)
    "hood": None,                       # {"z": 1.10, "x": 0.14, "h": 0.022}: a hood lying on the back (capot)
    "lining": True,                     # the skirts lined in the facing zone
    "front_buttons": {"n": 13, "z": (1.265, 0.92), "inset": 0.012, "side": -1},
    "cuff_buttons": 3, "back_buttons": True, "button_r": 0.0080, "shoulder_strap": False,
    "piping": None,                     # {"width": 0.006, "edges": ("front", "hem", "cuff", "neck"), "zone": 3}
    "armpit_relief": {"depth": 0.007, "radius": 0.065},   # less ease under the arms (Garment.relieve)
    "bust": None,                       # {"fits": ("f", "bl", "bs"), "z_min": 0.90, "gap": 0.012}: on those fits the
                                        # front hangs straight from the bust's apex (cloth2.bridge.flat_front, 2026-10-03)
    "zones": {"cloth": 0, "facing": 1, "button": 2, "trim": 3},
}
# The colonial regulars' justaucorps (Compagnies franches de la marine): collarless, buttoned to the skirts, deep
# cuffs with three buttons, pocket flaps with five, blue lining (old garments/military_lib/_coat.py FRENCH_MARINE).
MARINE_JUSTAUCORPS = style(COAT)
# The British 1751 regimental coat: lapels to the waist, small round cuffs with four buttons, turned-back skirts.
REGIMENTAL_1751 = style(COAT, opening=[(0.40, 0.215), (0.52, 0.205), (0.62, 0.185), (0.75, 0.145), (0.86, 0.095),
                                        (0.93, 0.055), (1.00, 0.038), (1.10, 0.028), (1.20, 0.020), (1.28, 0.018),
                                        (1.36, 0.030), (1.6, 0.06)],
                        lapels={"z": (0.975, 1.285), "w": (0.058, 0.074), "h": 0.0022},
                        cuffs={"t0": 0.74, "h": 0.006}, cuff_buttons=4,
                        pockets={"z": (0.835, 0.885), "a": (52.0, 98.0), "h": 0.0032, "buttons": 4, "on_flap": False},
                        turnbacks={"w_hem": 0.105, "z_top": 0.90}, front_buttons=None, shoulder_strap=True,
                        hem=(0.575, 0.54, 0.525))
# A civilian frock: a falling collar, buttons to the waist, skirts curving away, a vent.
FROCK = style(COAT, collar=("fall", 0.05), cuffs={"t0": 0.70, "h": 0.005}, cuff_buttons=2,
              pockets={"z": (0.865, 0.905), "a": (52.0, 98.0), "h": 0.003, "buttons": 0, "on_flap": True},
              front_buttons={"n": 9, "z": (1.30, 1.00), "inset": 0.012, "side": -1}, hem=(0.56, 0.54, 0.52),
              opening=[(0.40, 0.16), (0.52, 0.15), (0.62, 0.13), (0.75, 0.10), (0.86, 0.06), (0.95, 0.022),
                       (1.0, 0.0), (1.6, 0.0)])
# Short coats: no skirts below the hips (a sailor's or ranger's jacket), or a short basque (the women's jacket).
JACKET = style(COAT, hem=(0.86, 0.865, 0.87), flare=0.02, steps=3, pleats=None, vent=None, lining=False,
               skirt_gap=0.025, pockets=None, opening=[(0.80, 0.03), (0.86, 0.01), (1.0, 0.0), (1.6, 0.0)],
               front_buttons={"n": 7, "z": (1.26, 0.90), "inset": 0.012, "side": -1}, cuffs={"t0": 0.80, "h": 0.005},
               cuff_buttons=0, back_buttons=False)
# The hooded capot: wrapped over (the left front over the right), one button at the neck, a hood on the back.
CAPOT = style(COAT, hem=(0.50, 0.49, 0.48), opening=None, overlap={"x": -0.055, "split_below": 0.86, "h": 0.003},
              vent=None, lapels=None, pockets=None, turnbacks=None, lining=False, pleats=None, flare=0.09,
              front_buttons={"n": 1, "z": (1.27, 1.27), "inset": 0.0, "side": -1}, cuff_buttons=0,
              back_buttons=False, cuffs={"t0": 0.78, "h": 0.006}, hood={"z": 1.10, "x": 0.125, "h": 0.022},
              neck={"a": 0.088, "b": 0.080, "z0": 1.335, "tilt": 17.0})


def coat(g, st=None):
    """A coat with skirts (style: COAT and the variants above; see COAT for every key)."""
    st = style(COAT, **(st or {}))
    Z = st["zones"]
    g.shell(G.TORSO + G.ARMS)
    g.neckline(**st["neck"]).bottom(st["bottom"])
    if st.get("sleeveless"):
        # (2026-10-06, the Thủy Vân vests and work tunics: cloth2.dress.ROBE sleeves None) round armholes
        g.armholes(**st["sleeveless"])
        g.seams(limbs=())
    else:
        g.sleeves(end=st["sleeve_end"], ease=st["sleeve_ease"], gather=st["gather"])
        g.seams()
    g.fit(ease=st["ease"])
    if st["armpit_relief"] and not st.get("sleeveless"):
        g.relieve(g.armpits(), st["armpit_relief"]["radius"], st["armpit_relief"]["depth"])
    front, side, back = st["hem"]
    hung = min(front, side, back) < st["bottom"] - 0.01
    if hung:
        g.tails(hem=hem_by_angle(front, side, back), flare=st["flare"], folds=st["folds"], steps=st["steps"],
                z_full=st["z_full"], pleats=st["pleats"], gap=st["skirt_gap"], slits=st.get("slits"))
    if st["over"]:
        g.over(st["over"], st["over_gap"])
        if hung and st.get("over_relax"):
            # (the robes' skirts over wide trousers: each push smoothed out over the hanging cloth, then fitted again)
            zh = getattr(g, "_hung_z", st["bottom"])
            for _ in range(int(st["over_relax"])):
                arm = np.maximum(g.m.A["m_arm_l"], g.m.A["m_arm_r"])
                g.m.smooth(4, 0.5, weights=smoothstep(zh + 0.01, zh - 0.08, g.P[:, 2]) * (1.0 - arm))
                g.over(st["over"], st["over_gap"])
    if st.get("bust"):
        from cloth2 import bridge as BR
        BR.flat_front(g, **st["bust"])
        if st["over"]:
            g.over(st["over"], st["over_gap"])
    z_hung = getattr(g, "_hung_z", st["bottom"])
    if st["opening"]:
        g.opening(st["opening"])
        g.split_sides(lambda P: P[:, 1] < 0.0)
    if st["overlap"]:
        ov = st["overlap"]
        x0 = ov["x"]
        P = g.P
        # the skirts part along the overlap's edge below split_below (a slit, each side its own leg)
        f = (np.abs(P[:, 0] - x0) - 0.003) + BIG_FIELD * smoothstep(ov["split_below"], ov["split_below"] + 0.02, P[:, 2]) + \
            BIG_FIELD * smoothstep(-0.04, 0.0, P[:, 1])
        g.m = g.m.clip(f, 0.0)
        split_sides(g.fits, g.m, (g.P[:, 1] < 0.0) & (g.P[:, 2] < z_hung) & (np.abs(g.P[:, 0] - x0) < 0.04), x0=x0)
    if st.get("overlap_line") and hung:
        from cloth2 import dress as DR
        DR.overlap_cut(g, st["overlap_line"], z_hung)
    if st["vent"] and hung:
        g.vent(st["vent"])
    # the skirt lining: a copy of the plain skirts made now, joined at the end (raised flaps must not move it)
    lining = None
    if st["lining"] and hung:
        sel = _skirt_faces(g, z_hung)
        lining = TR.overlay(g.m, sel, -0.0016, Z["facing"], flip=True)
    if st["cuffs"] and not st.get("sleeveless"):
        g.cuffs(st["cuffs"]["t0"], st["cuffs"]["h"], Z["facing"], flare=st["cuffs"].get("flare", 0.0))
    if st["lapels"]:
        _lapels(g, st)
    if st["overlap"]:
        ov = st["overlap"]
        g.raised(lambda P: np.maximum(np.abs(P[:, 0] - (ov["x"] + 0.022)) - 0.022, P[:, 2] - 1.30) +
                 BIG_FIELD * smoothstep(-0.04, 0.0, P[:, 1]), ov["h"], None)
    if st.get("overlap_line"):
        from cloth2 import dress as DR
        DR.overlap_raise(g, st["overlap_line"])
    if st["turnbacks"] and hung:
        _turnbacks(g, st, z_hung)
    if st["pockets"] and hung:
        pk = st["pockets"]
        arm = np.maximum(g.m.A["m_arm_l"], g.m.A["m_arm_r"])
        P = g.P
        a = angle_from_front(P)
        f = np.maximum.reduce([pk["a"][0] - a, a - pk["a"][1], (pk["z"][0] - P[:, 2]) * 300.0,
                               (P[:, 2] - pk["z"][1]) * 300.0]) + BIG_FIELD * arm
        g.raised(f, pk["h"], Z["cloth"])
    if st["hood"]:
        _hood(g, st["hood"], Z["facing"])
    if st["collar"]:
        kind, size = st["collar"]
        if kind == "fall":
            g.collar_fall(size, 0.003, Z["facing"])
        else:
            g.stand_collar(size, zone=Z["facing"])
    if st["piping"]:
        _piping(g, st, z_hung)
    if lining is not None:
        g.add(lining)
    _coat_buttons(g, st, z_hung)
    g.hem_below(max(st["hem"]) + 0.03 if hung else st["bottom"] + 0.02)
    if st["shoulder_strap"]:
        S, C = g.fits.J["l_shoulder"], g.fits.J["l_clavicle"]
        a = S + np.array([-0.01, 0.0, 0.03])
        b = C + np.array([0.088, 0.0, 0.03])
        g.strap([a, b], 0.022, st["ease"] + 0.003, Z["cloth"])
    g.uv()
    return g


def jacket(g, st=None):
    return coat(g, style(JACKET, **(st or {})))


def capot(g, st=None):
    return coat(g, style(CAPOT, **(st or {})))


def _skirt_faces(g, z_hung):
    c = g.m.face_centres()
    arm = np.maximum(g.m.A["m_arm_l"], g.m.A["m_arm_r"])[g.m.F].max(1)
    return (c[:, 2] < z_hung - 0.004) & (arm < 0.5)


def _lapels(g, st):
    lp = st["lapels"]
    z0, z1 = lp["z"]
    w0, w1 = lp["w"]
    zs, ws, _ = g._opening

    def f(P):
        X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
        t = np.clip((Z - z0) / (z1 - z0), -0.5, 1.5)
        xe = np.interp(Z, zs, ws) + w0 + (w1 - w0) * t
        return np.maximum.reduce([np.abs(X) - xe, (z0 - Z), (Z - z1 - 0.08)]) + BIG_FIELD * smoothstep(-0.03, -0.005, Y)
    g.raised(f, lp["h"], st["zones"]["facing"])


def _turnbacks(g, st, z_hung):
    tb = st["turnbacks"]
    zs, ws, _ = g._opening
    P = g.P
    edge = TR.boundary_vertices(g.m, lambda P: (P[:, 1] < 0.0) & (P[:, 2] < tb["z_top"]) &
                                (np.abs(np.abs(P[:, 0]) - np.interp(P[:, 2], zs, ws)) < 0.006))
    d = TR.surface_distance(g.m, edge)
    hem = min(st["hem"])
    width = tb["w_hem"] * np.clip((tb["z_top"] - P[:, 2]) / (tb["z_top"] - hem), 0.0, 1.0)
    f = d - width + BIG_FIELD * smoothstep(tb["z_top"], tb["z_top"] + 0.01, P[:, 2]) + \
        BIG_FIELD * smoothstep(-0.02, 0.02, P[:, 1])
    g.raised(f, 0.0018, st["zones"]["facing"])


def _hood(g, hd, zone):
    """A hood lying on the back: a raised, puffed patch from the neckline down to hd['z'], |x| < hd['x'] (off the
    sleeves)."""
    zt = 1.40
    arm = np.maximum(g.m.A["m_arm_l"], g.m.A["m_arm_r"])

    def f(P):
        X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
        # an ellipse in (x, z) on the back: wide at the neck, round below
        zc = (zt + hd["z"]) / 2.0
        r = np.sqrt((X / hd["x"]) ** 2 + ((Z - zc) / ((zt - hd["z"]) / 2.0)) ** 2)
        return (r - 1.0) * 0.1 + BIG_FIELD * (1.0 - smoothstep(0.0, 0.04, Y)) + BIG_FIELD * smoothstep(0.1, 0.3, arm)

    def h(P):
        X, Z = P[:, 0], P[:, 2]
        u = np.clip(np.abs(X) / hd["x"], 0, 1)
        v = np.clip((Z - hd["z"]) / (zt - hd["z"]), 0, 1)
        return hd["h"] * (0.35 + 0.65 * np.sqrt(np.clip((1 - u ** 2) * np.sin(np.pi * np.clip(v * 0.9 + 0.1, 0, 1)), 0, 1)))
    g.raised(f(g.P), h, zone)


def _piping(g, st, z_hung):
    pp = st["piping"]
    edges = pp.get("edges", ("front", "hem", "cuff", "neck"))
    nz = g._neck[2] - 0.09 if g._neck else 1.24

    def sel(P):
        X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
        arm = np.zeros(len(P), bool)
        s = np.zeros(len(P), bool)
        if "neck" in edges:
            s |= Z > nz
        if "hem" in edges:
            s |= (Z < z_hung - 0.02) & (np.abs(X) < 0.30)
        if "front" in edges:
            s |= (Y < -0.02) & (Z < nz) & (Z > z_hung - 0.5)
        if "cuff" in edges:
            s |= (np.abs(X) > 0.30)
        return s
    g.edge_zone(pp.get("zone", 3), pp.get("width", 0.006), select=sel)


def _coat_buttons(g, st, z_hung):
    Z = st["zones"]
    br = st["button_r"]
    fb = st["front_buttons"]
    if fb:
        zs = np.linspace(fb["z"][0], fb["z"][1], fb["n"])
        x = np.array([fb["side"] * (float(g.opening_w(z)) + fb["inset"]) if st["opening"] else
                      (st["overlap"]["x"] + 0.03 if st["overlap"] else 0.0) for z in zs])
        g.buttons(g.front_points(x, zs), Z["button"], r=br)
    n = st["cuff_buttons"]
    if n and st["cuffs"] and not st.get("sleeveless"):
        t0 = st["cuffs"]["t0"]
        ts = np.linspace(t0 + 0.04, st["sleeve_end"] - 0.035, n)
        for lb in ("arm_l", "arm_r"):
            P = g.limb_points(lb, ts, around_deg=55.0)
            ch = g.fits.arm(lb[-1])
            g.buttons(P, Z["button"], r=br * 0.85, up=ch[1] - ch[2], segs=6)
    pk = st["pockets"]
    if pk and pk.get("buttons") and min(st["hem"]) < st["bottom"] - 0.01:
        n = pk["buttons"]
        a = np.linspace(pk["a"][0] + 7.0, pk["a"][1] - 7.0, n)
        zc = pk["z"][0] + (0.012 if pk["on_flap"] else -0.018)
        P = np.concatenate([g.around_points(zc, a), g.around_points(zc, -a)])
        g.buttons(P, Z["button"], r=br * 0.9, segs=6)
    if st["back_buttons"] and min(st["hem"]) < st["bottom"] - 0.01:
        P = g.around_points(z_hung - 0.004, np.array([118.0, -118.0]))
        g.buttons(P, Z["button"], r=br)


# ======================================================================================================================
# waistcoats
# ======================================================================================================================
WAISTCOAT = {
    "neck": {"a": 0.080, "b": 0.072, "z0": 1.330, "tilt": 17.0},
    "sleeves": None,                    # {"end": 0.88, "ease": (0.0, 0.004), "cuffs": None}: a sleeved veste
    "bottom": 0.905, "ease": G.LAYER_EASE["mid"],
    "hem": (0.80, 0.85, 0.86), "flare": 0.025, "folds": 0.0, "steps": 5, "z_full": G.SKIRT_Z_FULL, "skirt_gap": 0.02,
    # V from 1.16 m, buttoned to 0.92, the fronts parting below into two points at the hem
    "opening": [(0.76, 0.07), (0.80, 0.05), (0.86, 0.022), (0.92, 0.0), (1.16, 0.0), (1.24, 0.034), (1.30, 0.060),
                (1.40, 0.10), (1.6, 0.12)],
    "buttons": {"n": 11, "z": (1.15, 0.925), "x": -0.0075, "r": 0.0065},
    "pockets": {"z": (0.886, 0.914), "x": (0.048, 0.132), "h": 0.0028},
    "back": {"angle": 105.0, "below": 1.285},       # the linen back (zone 1) behind the side seams
    "over": ("shirt_linen", "breeches"), "over_gap": 0.005,
    "piping": None,
    "zones": {"cloth": 0, "back": 1, "button": 2, "trim": 3},
}
VESTE = style(WAISTCOAT, sleeves={"end": 0.88, "ease": (0.0, 0.004), "cuffs": None}, hem=(0.74, 0.75, 0.76),
              opening=[(0.70, 0.05), (0.80, 0.02), (0.90, 0.0), (1.20, 0.0), (1.28, 0.03), (1.40, 0.09), (1.6, 0.12)],
              buttons={"n": 13, "z": (1.19, 0.90), "x": -0.0075, "r": 0.0065},
              pockets={"z": (0.875, 0.905), "x": (0.05, 0.135), "h": 0.0028}, back=None, steps=6)


def waistcoat(g, st=None):
    """A waistcoat (WAISTCOAT) or sleeved veste (VESTE)."""
    st = style(WAISTCOAT, **(st or {}))
    Z = st["zones"]
    sl = st["sleeves"]
    g.shell(G.TORSO + G.ARMS)
    g.neckline(**st["neck"]).bottom(st["bottom"])
    if sl:
        g.sleeves(end=sl["end"], ease=sl["ease"], gather=0.0)
        g.seams()
    else:
        g.armholes()
        g.seams(limbs=())
    g.fit(ease=st["ease"])
    front, side, back = st["hem"]
    g.tails(hem=hem_by_angle(front, side, back), flare=st["flare"], folds=st["folds"], steps=st["steps"],
            z_full=st["z_full"], gap=st["skirt_gap"], x_limit=0.30)
    if st["over"]:
        g.over(st["over"], st["over_gap"])
    z_hung = getattr(g, "_hung_z", st["bottom"])
    g.opening(st["opening"])
    g.split_sides(lambda P: P[:, 1] < 0.0)
    if st["back"]:
        bk = st["back"]
        sel = g.select(lambda P: np.maximum(bk["angle"] - angle_from_front(P), (P[:, 2] - bk["below"]) * 300.0))
        g.m.fa["zone"][sel] = Z["back"]
    if sl and sl.get("cuffs"):
        g.cuffs(sl["cuffs"]["t0"], sl["cuffs"]["h"], Z["cloth"])
    pk = st["pockets"]
    if pk:
        g.raised(lambda P: np.maximum.reduce([np.abs(P[:, 0]) - pk["x"][1], pk["x"][0] - np.abs(P[:, 0]),
                                              pk["z"][0] - P[:, 2], P[:, 2] - pk["z"][1]]) +
                 BIG_FIELD * smoothstep(-0.03, 0.0, P[:, 1]), pk["h"], Z["cloth"])
    if st["piping"]:
        g.edge_zone(st["piping"].get("zone", 3), st["piping"].get("width", 0.006))
    g.hem_below(max(st["hem"]) + 0.02)
    b = st["buttons"]
    zs = np.linspace(b["z"][0], b["z"][1], b["n"])
    g.buttons(g.front_points(np.full(len(zs), b["x"]), zs), Z["button"], r=b["r"], h=0.0028, segs=8)
    g.uv()
    return g


# ======================================================================================================================
# the apron
# ======================================================================================================================
APRON = {"band": (1.003, 1.033), "ease": 0.024, "hem": 0.36, "edge_angle": 70.0, "flare": 0.06, "folds": 0.012,
         "steps": 9, "z_full": 0.55, "gap": 0.012, "over": ("shift_linen", "petticoat"), "over_gap": 0.004,
         "zones": {"cloth": 0, "band": 1}}


def apron(g, st=None):
    """A waistband tied round the waist and a gathered skirt hanging from its front only, over the petticoat; it
    moves with the petticoat's closed-skirt panels (parts.closed_skirt_weights)."""
    st = style(APRON, **(st or {}))
    g.shell(G.TORSO)
    g.top(st["band"][1]).bottom(st["band"][0])
    g.seams(back=True, limbs=())
    g.fit(ease=st["ease"], gap=0.01)
    g.tails(hem=st["hem"], side_hem=st["hem"] + 0.02, flare=st["flare"], folds=st["folds"], steps=st["steps"],
            z_full=st["z_full"], gap=st["gap"], x_limit=0.5, edge_angle=st["edge_angle"])
    if st["over"]:
        g.over(st["over"], st["over_gap"])
    g.zone(st["zones"]["band"], above=st["band"][0] + 0.002)
    closed_skirt_weights(g.fits, g.m)
    g.uv(axis_top=1.05, axis_bottom=0.3, limbs=())
    return g


# ======================================================================================================================
# neckwear
# ======================================================================================================================
NECKWEAR = {
    "stock": {"t": (0.004, 0.058), "ease": 0.006, "knot": None, "ends": None, "buckle": True},
    "cravat": {"t": (0.0, 0.045), "ease": 0.008, "knot": (0.016, 0.012, 0.010), "ends": {"len": 0.10, "w": 0.036}, "buckle": False},
    "neckerchief": {"t": (-0.012, 0.034), "ease": 0.012, "knot": (0.020, 0.016, 0.012), "ends": {"len": 0.14, "w": 0.030},
                    "buckle": False},
}


def neckwear(g, kind="stock", st=None):
    """A band round the neck between two heights along its axis (t above the neck's root plane, m), a knot at the
    throat and hanging ends (cravat, neckerchief), or a buckle behind (stock). Zones: 0 the cloth, 2 the buckle."""
    st = style(NECKWEAR[kind], **(st or {}))
    g.shell(G.NECK + ["neck_lower", "chest_upper_front", "chest_upper_side", "chest_upper_back"], base="cloth")
    g._neck = (0.078, 0.068, 1.325, 17.0, 0.0, 0.0, 0.09)
    A0, d, v = g._neck_frame()
    t = (g.P - A0) @ d
    g.m = g.m.clip(t - st["t"][0], 0.0)
    t = (g.P - A0) @ d
    g.m = g.m.clip(st["t"][1] - t, 0.0)
    g.seams(back=True, limbs=())
    g.m.offset(st["ease"], vertical=0.2)
    g.m.smooth(2, 0.5)
    g.fits.clear(g.m, 0.003)
    if st["knot"] or st["ends"]:
        P = g.front_points(np.zeros(9), np.linspace(1.27, 1.37, 9))
        if len(P):
            k = P[np.argmin(P[:, 2])] + np.array([0.0, 0.0, 0.006])      # the knot at the band's lower front edge
            if st["knot"]:
                g.hardware([k], HW.ellipsoid(*st["knot"], segs=8, rings=5), 0, lift=-0.004)
            if st["ends"]:
                e = st["ends"]
                for s in (1, -1):
                    way = [k + np.array([s * 0.006, -0.01, -0.01]), k + np.array([s * 0.016, -0.03, -e["len"] * 0.5]),
                           k + np.array([s * 0.022, -0.04, -e["len"]])]
                    g.strap(way, e["w"], 0.010, 0, step=0.01)
    if st["buckle"]:
        P = g.around_points(1.36, np.array([180.0]))
        g.hardware(P, HW.frame(0.022, 0.018, 0.003, 0.0025), 2)
    g.uv(axis_top=1.45, axis_bottom=1.2, limbs=())
    return g


# ======================================================================================================================
# soft caps
# ======================================================================================================================
SOFT_CAP = {
    # phi_max: the cap's edge in degrees from the crown at the front, the sides and the back
    "monmouth": {"edge": (62.0, 74.0, 82.0), "ease": 0.011, "band": {"width": 0.045, "h": 0.004, "front_deg": 181.0},
                 "tail": None, "caul": 0.0, "frill": None},
    "tuque": {"edge": (62.0, 74.0, 82.0), "ease": 0.011, "band": {"width": 0.05, "h": 0.004, "front_deg": 181.0},
              "tail": {"len": 0.25, "r0": 0.048, "r1": 0.018, "side": 1.0}, "caul": 0.0, "frill": None},
    "womens": {"edge": (68.0, 104.0, 134.0), "ease": 0.010, "band": {"width": 0.03, "h": 0.002, "front_deg": 105.0},
               "tail": None, "caul": 0.036, "frill": {"depth": 0.026, "front_deg": 78.0}},
    # the plain skullcap of the peoples' dress (2026-10-03): a small close cap on the crown, no band (the core under
    # the turbans, cloth2.dress.head_wrap; the Ottoman women's cap, the Chinese guapimao as styles)
    "skullcap": {"edge": (60.0, 72.0, 80.0), "ease": 0.0068, "band": None, "tail": None, "caul": 0.0, "frill": None},
}


def soft_cap(g, kind="monmouth", st=None):
    """A knit or linen cap over the head (hats.head_grid): its edge (degrees from the crown, front / side / back), an
    ease over the scalp (>= hats.HAIR_CLEAR, over the pressed hair), a turned-up band, a knitted tail (tuque), a
    puffed caul over the bun and a frill round the face (women's cap). Zones: 0 the cap, 1 the band / frill."""
    from cloth2 import hats as HT
    st = style(SOFT_CAP[kind], **(st or {}))
    fr, sd, bk = [np.radians(a) for a in st["edge"]]
    caul = st["caul"]

    def phi_max(th):
        c = np.cos(th)        # 1 front, -1 back
        return np.where(c > 0, sd + (fr - sd) * c, sd + (bk - sd) * (-c))

    def ease(th, ph):
        back = np.clip(-np.cos(th), 0, 1)
        return st["ease"] + caul * back ** 1.5 * np.sin(np.clip(ph, 0, np.pi)) ** 2
    m, ids, TH, PH = HT.head_grid(g.fits, segs=32, rows=10, phi_max=phi_max, ease=ease)
    g.m = m
    c0 = HT.headb(g.fits) + np.array([0.0, -0.035, 0.075])
    if st["band"]:
        bd = st["band"]
        g.edge_zone(1, bd["width"], h=bd["h"],
                    select=lambda P: angle_from_front(P - np.array([0.0, c0[1], 0.0])) < bd["front_deg"])
    if st["frill"]:
        fl = st["frill"]

        def disp(fit, P0, N0, s):
            # the frill carries on down from the cap's edge and stands a little off the face
            down = np.array([0.0, 0.0, -1.0]) - (N0 @ np.array([0.0, 0.0, -1.0]))[:, None] * N0
            down = down / np.maximum(np.linalg.norm(down, axis=1, keepdims=True), 1e-9)
            d = down * 0.75 + N0 * 0.6
            d = d / np.linalg.norm(d, axis=1, keepdims=True)
            return d * fl["depth"] * s
        piece = TR.extrude(g.m, lambda P: angle_from_front(P - np.array([0.0, c0[1], 0.0])) < fl["front_deg"], disp,
                           rings=2, zone=1)
        g.add(piece)
    if st["tail"]:
        tl = st["tail"]
        top = HT.headb(g.fits) + np.array([0.0, -0.03, 0.15])
        s = tl["side"]
        path = np.array([top + np.array([0.0, 0.0, 0.012]), top + np.array([s * 0.03, 0.02, 0.05]),
                         top + np.array([s * 0.09, 0.05, 0.03]), top + np.array([s * 0.13, 0.07, -0.04]),
                         top + np.array([s * 0.15, 0.08, -0.10])])
        k = np.linspace(0, 1, 9)
        P = np.stack([np.interp(k * (len(path) - 1), np.arange(len(path)), path[:, i]) for i in range(3)], 1)
        r = tl["r0"] + (tl["r1"] - tl["r0"]) * k ** 0.8
        g.add(HT.tube(g.fits, g.m, P, r, segs=12, zone=0))
    g.notes["scalp_clearance_mm"] = {k: [round(v[0] * 1000, 1), round(v[1] * 1000, 1)] for k, v in
                                     HT.scalp_clearance(g.fits, g.m.V).items()}
    c = HT.headb(g.fits)
    g.uvparts = {0: ("cyl", c, c + np.array([0.0, 0.0, 0.2]), [0, -1, 0])}
    g.m.fa["part"][:] = 0
    g.shape_alias = {"sex_head": "m"}
    return g


def rigid_hat(g, st):
    """A felt hat (hats.TRICORNE / hats.ROUND_HAT or a style made from them)."""
    return g.hat(st)


# ======================================================================================================================
# leggings and gaiters
# ======================================================================================================================
LEGGINGS = {"top": 0.70, "ease": 0.006, "base": "skin", "flap": {"depth": 0.035, "lift": 0.0}, "garter": {"z": (0.43, 0.455), "h": 0.003},
            "buttons": None, "over": ("breeches",), "over_gap": 0.004, "zones": {"cloth": 0, "garter": 1, "button": 2}}
GAITERS = style(LEGGINGS, top=0.56, flap=None, garter={"z": (0.53, 0.56), "h": 0.003},
                buttons={"n": 12, "z": (0.52, 0.10)})


def leggings(g, st=None):
    """Leg coverings from the ankle up to `top` over the stockings and breeches: wool leggings with the flap standing
    out at the outer side and a garter below the knee (LEGGINGS), or buttoned gaiters (GAITERS)."""
    st = style(LEGGINGS, **(st or {}))
    Z = st["zones"]
    g.shell(G.LEGS, base=st["base"])
    g.top(st["top"])
    g.seams(back=False, limbs=())
    g.fit(ease=st["ease"], smooth=2, gap=0.002)
    if st["over"]:
        g.over(st["over"], st["over_gap"])
    if st["garter"]:
        z0, z1 = st["garter"]["z"]
        g.raised(lambda P: np.maximum(z0 - P[:, 2], P[:, 2] - z1), st["garter"]["h"], Z["garter"])
    for s in ("l", "r"):
        sg = 1.0 if s == "l" else -1.0
        zs = np.linspace(st["top"] - 0.01, 0.10, 12)
        x = np.interp(zs, [0.08, 0.47, 0.82], [g.fits.J[s + "_ankle"][0], g.fits.J[s + "_knee"][0], g.fits.J[s + "_upper_leg"][0]])
        O = np.stack([x + sg * 0.25, np.interp(zs, [0.08, 0.47, 0.82], [g.fits.J[s + "_ankle"][1], g.fits.J[s + "_knee"][1],
                                                                           g.fits.J[s + "_upper_leg"][1]]), zs], 1)
        P, ok = HW.ray_points(g.m, O, [-sg, 0.0, 0.0], 0.3)
        P = P[ok]
        if st["flap"] and len(P) > 2:
            g.fin(P, st["flap"]["depth"], 0.0015, Z["cloth"])
        if st["buttons"] and len(P) > 2:
            b = st["buttons"]
            zb = np.linspace(b["z"][0], b["z"][1], b["n"])
            Pb = np.stack([np.interp(zb, P[::-1, 2], P[::-1, k]) for k in range(3)], 1)
            g.buttons(Pb + np.array([sg * 0.001, -0.004, 0.0]), Z["button"], r=0.0055, h=0.0025)
    g.uv(limbs=("leg_l", "leg_r"))
    return g


# ======================================================================================================================
# strap accessories
# ======================================================================================================================
BELT = {"z": (0.955, 1.005), "lift": 0.022, "over": (), "over_gap": 0.004, "buckle": {"w": 0.05, "h": 0.055},
        "frog": None, "pouch": None, "zones": {"strap": 0, "metal": 2, "pouch": 1}}
SASH = {"z": (0.955, 1.045), "lift": 0.030, "over": (), "over_gap": 0.004, "knot_angle": 70.0,
        "ends": {"len": 0.30, "w": 0.07}, "zones": {"cloth": 0, "fringe": 3}}
HARNESS = {"belly": (1.00, 1.07), "lift": 0.012, "strap_w": 0.04, "over": (), "over_gap": 0.004,
           "ring": True, "zones": {"strap": 0, "metal": 2}}
POUCH_BELT = {"w": 0.055, "lift": 0.026, "over": (), "over_gap": 0.004, "pouch": {"size": (0.08, 0.05, 0.025)},
              "zones": {"strap": 0, "pouch": 1, "metal": 2}}


def belt(g, st=None):
    """A waist belt (a closed band) with a buckle at the front; optionally a pouch box at the right front."""
    st = style(BELT, **(st or {}))
    Z = st["zones"]
    g.m = None
    g.band(st["z"][0], st["z"][1], st["lift"], Z["strap"])
    if st["over"]:
        g.over(st["over"], st["over_gap"])
    zc = (st["z"][0] + st["z"][1]) / 2.0
    P = g.front_points([0.0], [zc])
    b = st["buckle"]
    if b and len(P):
        g.hardware(P, HW.frame(b["w"], b["h"], 0.006, 0.004), Z["metal"])
    pk = st["pouch"]
    if pk:
        P = g.around_points(zc - 0.03, np.array([-35.0]))
        g.hardware(P, HW.box(*pk["size"]), Z["pouch"], lift=0.002)
    g.uv(axis_top=1.1, axis_bottom=0.9, limbs=())
    return g


def sash(g, st=None):
    """A worsted sash: two turns round the waist (a band), knotted at the left hip, the ends hanging (fringed). With
    "turns" (2026-10-03) the sash wound several times on a helix, the end tucked (cloth2.dress.wound_sash)."""
    if (st or {}).get("turns"):
        from cloth2 import dress as DR
        return DR.wound_sash(g, st)
    st = style(SASH, **(st or {}))
    Z = st["zones"]
    g.m = None
    g.band(st["z"][0], st["z"][1], st["lift"], Z["cloth"])
    if st["over"]:
        g.over(st["over"], st["over_gap"])
    zc = (st["z"][0] + st["z"][1]) / 2.0
    P = g.around_points(zc, np.array([st["knot_angle"]]))
    if len(P):
        k = P[0]
        g.hardware([k], HW.ellipsoid(0.035, 0.03, 0.02, segs=8, rings=5), Z["cloth"], lift=-0.006)
        e = st["ends"]
        for dx, ln in ((-0.01, e["len"]), (0.02, e["len"] * 0.82)):
            way = [k + np.array([dx, -0.01, -0.02]), k + np.array([dx + 0.01, -0.02, -ln * 0.5]),
                   k + np.array([dx + 0.015, -0.02, -ln])]
            g.strap(way, e["w"], st["lift"] + 0.012, Z["cloth"], step=0.015,
                    width_fn=lambda s: e["w"] * (1.0 - 0.15 * s))
        # the fringe: the last 5 cm of each end (the strips are part 8)
        c = g.m.face_centres()
        g.m.fa["zone"][(g.m.fa["part"] == 8) & (c[:, 2] < k[2] - e["len"] * 0.82 + 0.05)] = Z["fringe"]
    g.uv(axis_top=1.1, axis_bottom=0.6, limbs=())
    return g


def harness(g, st=None):
    """A rigging harness: a belly band, two straps over the shoulders crossing in an X behind, a ring at the crossing."""
    st = style(HARNESS, **(st or {}))
    Z = st["zones"]
    g.m = None
    g.band(st["belly"][0], st["belly"][1], st["lift"], Z["strap"])
    J = g.fits.J
    zb = st["belly"][1] - 0.01
    for s in ("l", "r"):
        sg = 1.0 if s == "l" else -1.0
        S = J[s + "_shoulder"]
        way = [np.array([sg * 0.09, -0.20, zb]), np.array([sg * 0.10, -0.12, 1.22]), S + np.array([-sg * 0.045, 0.0, 0.06]),
               np.array([sg * 0.06, 0.15, 1.24]), np.array([0.0, 0.15, 1.19]), np.array([-sg * 0.09, 0.15, zb])]
        g.strap(way, st["strap_w"], st["lift"] + 0.003, Z["strap"])
    if st["over"]:
        g.over(st["over"], st["over_gap"])
    if st["ring"]:
        P = g.around_points(1.19, np.array([180.0]))
        g.hardware(P, HW.ring(0.016, 0.004, 12, 4), Z["metal"], lift=0.002)
    g.uv(axis_top=1.4, axis_bottom=0.9, limbs=())
    return g


def pouch_belt(g, st=None):
    """A cross belt from the left shoulder to the right hip with a pouch (a rigid box) at the hip."""
    st = style(POUCH_BELT, **(st or {}))
    Z = st["zones"]
    g.m = None
    J = g.fits.J
    S = J["l_shoulder"]
    way = [np.array([0.10, -0.16, 1.18]), S + np.array([-0.05, -0.02, 0.07]), np.array([0.02, 0.17, 1.22]),
           np.array([-0.14, 0.14, 1.00]), np.array([-0.19, 0.02, 0.88])]
    g.strap(way, st["w"], st["lift"], Z["strap"])
    way2 = [np.array([0.10, -0.16, 1.18]), np.array([-0.05, -0.17, 1.02]), np.array([-0.19, 0.02, 0.88])]
    g.strap(way2, st["w"], st["lift"], Z["strap"])
    if st["over"]:
        g.over(st["over"], st["over_gap"])
    # the pouch hangs at the belt's end on the right hip (its box on the strap's last point)
    end = g._last_path.at(REF)
    p = end[0][-1] + end[1][-1] * (st["lift"] + 0.004)
    g.hardware([p], HW.box(*st["pouch"]["size"]), Z["pouch"], lift=0.034, up=(0.0, 0.0, 1.0))
    g.uv(axis_top=1.4, axis_bottom=0.8, limbs=())
    return g


# ======================================================================================================================
# the peoples' dress types (cloth2.dress, 2026-10-03: docs/research/peoples_dress_1750s.md section 2)
# ======================================================================================================================
def robe(g, st=None):
    """T2: a long robe or kaftan (dress.ROBE / OPEN_ROBE)."""
    from cloth2 import dress as DR
    return DR.robe(g, st)


def tunic(g, st=None):
    """T3: a long pull-over tunic with a closed skirt (dress.TUNIC)."""
    from cloth2 import dress as DR
    return DR.tunic(g, st)


def trousers(g, st=None):
    """T6: drawers, wide trousers, wide breeches (dress.TROUSERS / DRAWERS / WIDE_BREECHES)."""
    from cloth2 import dress as DR
    return DR.trousers(g, st)


def wrap_skirt(g, st=None):
    """T5: a wrapped or tube skirt (dress.WRAP_SKIRT)."""
    from cloth2 import dress as DR
    return DR.wrap_skirt(g, st)


def drape(g, st=None):
    """T8: a drape cut to an outline (dress.DRAPE, the belted plaid dress.BELTED)."""
    from cloth2 import dress as DR
    return DR.drape(g, st)


def cloak(g, st=None):
    """T9: a cloak from the neck (dress.CLOAK)."""
    from cloth2 import dress as DR
    return DR.cloak(g, st)


def head_wrap(g, st=None):
    """T10: cloth wound round the head (dress.HEAD_WRAP turban, HEAD_BAND)."""
    from cloth2 import dress as DR
    return DR.head_wrap(g, st)


def lathe_hat(g, st):
    """rigid_hat profiles of revolution (dress.DOME_FINIAL, CONE, UMBRELLA, TALL_CROWN)."""
    from cloth2 import dress as DR
    return DR.lathe_hat(g, st)


def hose(g, st=None):
    """Stockings with gartering: the cuff turned down, the garter's ends hanging (dress.HOSE)."""
    from cloth2 import dress as DR
    return DR.hose(g, st)


# ======================================================================================================================
# the Thủy Vân types (cloth2.tv_dress, 2026-10-06: peoples_design.md section 2.9)
# ======================================================================================================================
def leg_wraps(g, st=None):
    """A strip wound down each shin over the trousers, a crossing cord, a knot under the knee (tv_dress.LEG_WRAPS)."""
    from cloth2 import tv_dress as TV
    return TV.leg_wraps(g, st)


def sandals(g, st=None):
    """A sole slab and straps kept from a sock tube (tv_dress.SANDALS rope; TOE_SANDALS, HEAVY_SANDALS, SLIPPERS)."""
    from cloth2 import tv_dress as TV
    return TV.sandals(g, st)


def fringe_mantle(g, st=None):
    """A shoulder capelet cut into ragged strips, a fur ruff, feathers (tv_dress.FRINGE_MANTLE)."""
    from cloth2 import tv_dress as TV
    return TV.fringe_mantle(g, st)


def carry(g, st=None):
    """A back basket on shoulder straps (tv_dress.TALL_BASKET, ROUND_BASKET)."""
    from cloth2 import tv_dress as TV
    return TV.carry(g, st)


def dangles(g, strings, obstacles=(), lift=0.008):
    """Strings of rigid pieces hung from the garment (tv_dress.dangles)."""
    from cloth2 import tv_dress as TV
    return TV.dangles(g, strings, obstacles, lift)
