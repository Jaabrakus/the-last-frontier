"""Prepare the trait renders (numpy + PIL only): every person's baked skin, the painted brow card, the painted ground,
and the render job for render_traits.py.

    python3 tools/thuyvan_art/traits/prep_traits.py <work dir> <review dir> [--test]

The people, their faces (stylized presets drawn from the WHOLE pool of the creator, never one ancestry per people:
every face is kept) and the variants the owner judges are in PEOPLE and VARIANTS below.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import skin_bake as SB  # noqa: E402

ROOT = SB.ROOT
CHAR = os.path.join(ROOT, "assets", "character")
DYES = "/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/d8726f05-a14a-44ac-97c9-351a2e11c5c5/scratchpad/peoples_places/peoples_dyes.json"
PRESETS = {p["id"]: p for p in json.load(open(os.path.join(CHAR, "body", "peoples.json")))["stylized_presets"]}
EYES = json.load(open(os.path.join(CHAR, "body", "body.json")))["eyes"]
EYES.update({"sea_grey": "#7d9496", "river_gold": "#c99a3a", "pale_jade": "#9cc0a8", "pearl_grey": "#b8c0c0",
             "jade": "#5f8a6a", "flint": "#7c7a74", "fox_amber": "#d4892a"})
HAIR_HEX = {"blue_black": "#101216", "black": "#1b1613", "dark_brown": "#33221a", "mid_brown": "#5a3d29",
            "chestnut": "#6b3b20", "auburn": "#7a3018", "sea_black": "#0e1416", "slate_black": "#1d1f22",
            "ash_white": "#cfccc6", "fox_russet": "#9a4020"}

# the neutral dress every figure wears (so only the people's body marks differ): a plain undyed sleeveless vest cut
# from the body itself (bscene.body_vest: shoulders, collarbones, arms and neck stay bare), charcoal wrapped trousers,
# a madder sash, plain shoes. Dyes from peoples_dyes.json.
def neutral_dress(dyes):
    r = lambda k: dyes[k]["ramp"]  # noqa: E731
    G = os.path.join(CHAR, "garments", "ring")
    return [
        {"glb": os.path.join(G, "ring_trousers_wrapped.glb"), "zones": {"0": r("tv_charcoal"), "1": r("tv_hemp")}},
        {"glb": os.path.join(G, "ring_sash_earth.glb"), "zones": {"0": r("tv_madder"), "1": r("tv_madder")}},
        {"glb": os.path.join(G, "ring_shoes.glb"), "zones": {"0": r("tv_walnut"), "1": ["#2a1c14", "#3b2a1f", "#5a4331", "#000000"], "2": r("tv_walnut")}},
    ]


def neutral_vest(dyes):
    return {"zones": {"0": dyes["tv_hemp"]["ramp"]}}


PEOPLE = [
    # id, label, title, look (trait), female preset, male preset, hair (f, m), extras
    {"id": "dragon_sea", "label": "Dragon-Sea People", "title": "People of the Estuaries",
     "look": {"trait_kind": 3, "trait": 0.5, "trait_tone": "#3f9a9a"}, "iris": "sea_grey", "reflect_tapetum": "#9fd08a",
     "f": "vietnamese_f_s2", "m": "vietnamese_m_s1", "hair": ("hair_long_loose", "hair_topknot"), "hair_color": "black",
     "caption": "scales (Marked 0.5, sea-teal): wrists, temples and cheekbones, shoulders and collarbones; reflective eyes"},
    {"id": "mountain_folk", "label": "Mountain Folk", "title": "People of the High Places",
     "look": {"trait_kind": 0}, "iris": "dark_brown",
     "f": "pacific_islander_f_s2", "m": "pacific_islander_m_s2", "hair": ("hair_long_loose", "hair_loose_tied"), "hair_color": "black",
     "caption": "no body trait: the people shows in dress, tattoos and hair (W1)"},
    {"id": "stone_children", "label": "Stone Children", "title": "of the Stone Valleys",
     "look": {"trait_kind": 4, "trait": 0.9, "trait_tone": "#6f7f8c"}, "iris": "jade",
     "f": "west_african_f_s1", "m": "chinese_m_s2", "hair": ("hair_cornrows", "hair_topknot"), "hair_color": "black",
     "caption": "mineral plates (0.9, slate) over the person's own skin; never lips, lids, palms, inner elbows"},
    {"id": "ho_tinh", "label": "Hồ Tinh", "title": "the Fox-Blooded",
     "look": {"trait_kind": 0}, "iris": "fox_amber", "ears": {"shape": "pointed", "fur": "cream"},
     "tails": {"n": 9, "fur": "cream", "theta0": 0.0, "spread": 128.0, "phis": [8, 26, 46, 62, 72], "curl": [0, 0, 0.12, 0.32, 0.55], "jitter": 9.0},
     "f": "korean_f_s2", "m": "japanese_m_s2", "hair": ("hair_bun_low", "hair_loose_tied"), "hair_color": "black",
     "caption": "features shown: pointed fox ears, nine cream tails on their own bones (any count 1-9, never a stat)"},
    {"id": "riverborn", "label": "Riverborn", "title": "Descendants of Water Spirits",
     "look": {"trait_kind": 5, "trait": 0.6, "trait_tone": "#3f9a9a", "tint": 0.75}, "iris": "river_gold", "reflect_tapetum": "#e8c060",
     "f": "filipino_f_s1", "m": "malay_m_s2", "hair": ("hair_long_loose", "hair_loose_tied"), "hair_color": "sea_black",
     "caption": "the water tint 0.75 over the person's own tone, wet sheen, scale patches, painted gills; reflective eyes"},
    {"id": "ancestor_bound", "label": "Ancestor-Bound", "title": "Bearers of Many Spirits",
     "look": {"trait_kind": 0, "ash": ["thumbprint", "cheeks"]}, "iris": "dark_brown",
     "f": "armenian_f_s2", "m": "english_m_s3", "hair": ("hair_bun_low", "hair_loose_tied"), "hair_color": "black",
     "caption": "not a body: the rite's pale ash marks (a marking anyone may wear) - thumbprint and cheek fingers"},
]


def with_hair(lk, style, color):
    """The scalp under the style in the hair's root colour (baked into the skin, as skin.gdshader's scalp_tint)."""
    sp = os.path.join(CHAR, "hair", "tex", style + "_scalp.png")
    out = dict(lk, hair_hex=HAIR_HEX.get(color, "#1b1613"))
    if os.path.exists(sp):
        out["scalp_png"] = sp
    return out


def person_look(p, sex):
    pre = PRESETS[p[sex]]
    lk = {"melanin": pre["melanin"], "undertone": pre.get("undertone", "neutral"), "haemoglobin": pre.get("haemoglobin", 0.5),
          "male": 1.0 if sex == "m" else 0.0}
    lk.update(p["look"])
    return pre, with_hair(lk, p["hair"][0 if sex == "f" else 1], p.get("hair_color", "black"))


def bake_all(F, items, work):
    """items: [(key, look)] -> {key: prefix}; a bake is skipped when its four maps exist (delete them to rebake)."""
    out = {}
    for key, lk in items:
        pre = os.path.join(work, "skin", key)
        os.makedirs(os.path.dirname(pre), exist_ok=True)
        if not all(os.path.exists(pre + s) for s in ("_albedo.png", "_rough.png", "_sheen.png", "_height.png")):
            SB.bake(F, lk, pre)
        out[key] = pre
    return out


def brow_png(path):
    """face_hair.gdshader brow_alpha_painted (thickness 0.7, arch 0.5, density 0.8), baked over the card's (u, v)."""
    W, H = 512, 256
    u = (np.arange(W) + 0.5) / W
    v = 1.0 - (np.arange(H) + 0.5) / H
    U, V = np.meshgrid(u, v)
    thick, arch, dens = 0.7, 0.5, 0.8
    sm = lambda a, b, x: np.clip((x - a) / (b - a), 0, 1) ** 2 * (3 - 2 * np.clip((x - a) / (b - a), 0, 1))  # noqa: E731
    vc = 0.46 + (arch - 0.5) * 0.30 * np.sin(np.pi * np.clip(U / 0.75, 0, 1) * 0.5) - 0.10 * sm(0.7, 1.0, U)
    h = thick * 1.3 * (0.36 + (0.13 - 0.36) * sm(0.15, 1.0, U)) * sm(-0.04, 0.05, U) * (1.0 - sm(0.92, 1.0, U))
    wave = 1.0 + 0.05 * np.sin(U * 17.0 + 0.6)
    inside = 1.0 - sm(h * wave * 0.86, h * wave + 1e-6, np.abs(V - vc))
    hu = np.maximum(0.09 - U, 0.0) / 0.09
    hv = (V - vc) / np.maximum(h, 1e-4)
    inside = inside * (1.0 - sm(0.8, 1.0, hu * hu + hv * hv * (0.09 - U >= 0)))
    a = inside * (0.6 + 0.4 * dens)
    Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8)).save(path)


def ground_png(path, n=2048, seed=7):
    """The painted grass plane (style guide 3.2 in brief): r1.grass's 4-stop ramp laid by soft value noise, then a few
    thousand short dabs of its light and dark tones, on a torus so it tiles; an 8 m tile."""
    rng = np.random.default_rng(seed)
    ramp = np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)] for h in ("#2f5a2c", "#4e8a36", "#84b546", "#c2d16a")], float) / 255.0
    lin = SB.srgb_to_lin(ramp)

    def tnoise(cells):
        g = rng.random((cells, cells))
        x = np.arange(n) * cells / n
        i0 = np.floor(x).astype(int)
        f = x - i0
        f = f * f * (3 - 2 * f)
        a = g[np.ix_(i0 % cells, i0 % cells)]
        b = g[np.ix_(i0 % cells, (i0 + 1) % cells)]
        c = g[np.ix_((i0 + 1) % cells, i0 % cells)]
        d = g[np.ix_((i0 + 1) % cells, (i0 + 1) % cells)]
        fy, fx = f[:, None], f[None, :]
        return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
    t = 0.55 * tnoise(5) + 0.30 * tnoise(13) + 0.15 * tnoise(40)
    t = np.clip((t - 0.2) / 0.6, 0, 1) * 0.7 + 0.25
    idx = t * 2.0
    i0 = np.clip(np.floor(idx).astype(int), 0, 2)
    fr = (idx - i0)[..., None]
    img = lin[i0] * (1 - fr) + lin[i0 + 1] * fr
    for k in range(3500):
        cx, cy = rng.random(2) * n
        L = rng.uniform(10, 26)
        W = L * rng.uniform(0.25, 0.4)
        ang = rng.uniform(-0.5, 0.5) + math.pi / 2
        tone = lin[rng.choice([1, 2, 3], p=[0.35, 0.4, 0.25])]
        r = int(L) + 2
        ys = (np.arange(int(cy) - r, int(cy) + r)) % n
        xs = (np.arange(int(cx) - r, int(cx) + r)) % n
        yy, xx = np.meshgrid(np.arange(-r, r) + (int(cy) - cy), np.arange(-r, r) + (int(cx) - cx), indexing="ij")
        ca, sa = math.cos(ang), math.sin(ang)
        du = (xx * ca + yy * sa) / L
        dv = (-xx * sa + yy * ca) / W
        a = np.clip(1.0 - (du * du + dv * dv), 0, 1) ** 1.5 * 0.55
        sub = img[np.ix_(ys, xs)]
        img[np.ix_(ys, xs)] = sub * (1 - a[..., None]) + tone * a[..., None]
    Image.fromarray(np.clip(np.round(SB.lin_to_srgb(img) * 255), 0, 255).astype(np.uint8)).save(path)


def cam_front(width, cx=0.0, cy=0.86, lens=70.0, h=1.0):
    d = width / (36.0 / lens)
    return {"loc": [cx, -d, h], "look": [cx, 0.0, cy], "lens": lens}


def bust_cam(x, male, turn=0.0, y=0.0):
    hz = 1.43 * (1.07 if male else 1.0)
    a = math.radians(turn)
    d = 1.55
    return {"loc": [x + d * math.sin(a), y - d * math.cos(a), hz + 0.04], "look": [x, y, hz - 0.03], "lens": 85.0}


def figure(name, p, sex, skin_prefix, x, dyes, rot=0.0, iris=None, reflect=0.0, ears=None, tails=None, hair=None,
           hair_color=None):
    pre = PRESETS[p[sex]]
    face = {k: v for k, v in pre["face"].items()}
    hc = hair_color or p.get("hair_color") or pre["hair"]["color"]
    f = {"name": name, "sex": 1.0 if sex == "m" else 0.0, "face": face, "skin_prefix": skin_prefix,
         "iris": EYES.get(iris or p["iris"], "#4a2e1a"), "reflect": reflect, "tapetum": p.get("reflect_tapetum", "#9fd08a"),
         "hair": hair or p["hair"][0 if sex == "f" else 1], "hair_hex": HAIR_HEX.get(hc, "#1b1613"),
         "hair_sheen": "#2f6f78" if hc == "sea_black" else None,
         "garments": neutral_dress(dyes), "vest": neutral_vest(dyes), "loc": [x, 0.0], "rot_z": rot}
    e = ears if ears is not None else p.get("ears")
    t = tails if tails is not None else p.get("tails")
    if e:
        f["ears"] = e
    if t:
        f["tails"] = t
    return f


def main():
    work, review = sys.argv[1], sys.argv[2]
    test = "--test" in sys.argv
    os.makedirs(work, exist_ok=True)
    os.makedirs(review, exist_ok=True)
    dyes = json.load(open(DYES))["dyes"]
    n = 2048 if test else 4096
    F = SB.Fields.load(n, os.path.join(work, "cache"))
    brow = os.path.join(work, "brow_card.png")
    brow_png(brow)
    ground = os.path.join(work, "ground_grass.png")
    if not os.path.exists(ground):
        ground_png(ground)
    items = []
    for p in PEOPLE:
        for sex in ("f", "m"):
            pre, lk = person_look(p, sex)
            items.append(("%s_%s" % (p["id"], sex), lk))
    V = variants()
    if not test:
        for key, lk in V["looks"]:
            items.append((key, lk))
    skins = bake_all(F, items, work)
    scenes = []
    if test:
        P = {q["id"]: q for q in PEOPLE}
        spec = [("dragon_sea", "f"), ("stone_children", "m"), ("ho_tinh", "f"), ("riverborn", "m"), ("ancestor_bound", "f")]
        figs, shots = [], []
        for i, (pid, sex) in enumerate(spec):
            x = (i - 2) * 0.95
            figs.append(figure("%s_%s" % (pid, sex), P[pid], sex, skins["%s_%s" % (pid, sex)], x, dyes))
            shots.append({"name": "tb_" + pid, "out": os.path.join(review, "bust_%s.png" % pid), "res": [480, 540], "cam": bust_cam(x, sex == "m")})
        shots += [{"name": "test_front", "out": os.path.join(review, "test_front.png"), "cam": cam_front(5.4)},
                  {"name": "test_34", "out": os.path.join(review, "test_34.png"), "turn": -35.0, "cam": cam_front(5.4)},
                  {"name": "test_back", "out": os.path.join(review, "test_back.png"), "turn": 180.0, "cam": cam_front(5.4)}]
        scenes.append({"name": "test", "res": [1280, 720], "samples": 24, "figures": figs, "shots": shots})
    else:
        for sex in ("f", "m"):
            figs, xs = [], []
            for i, p in enumerate(PEOPLE):
                x = (i - 2.5) * 0.95
                xs.append(x)
                figs.append(figure("%s_%s" % (p["id"], sex), p, sex, skins["%s_%s" % (p["id"], sex)], x, dyes))
            shots = [{"name": "lineup_%s_front" % sex, "out": os.path.join(review, "lineup_%s_front.png" % sex), "cam": cam_front(5.7)},
                     {"name": "lineup_%s_34" % sex, "out": os.path.join(review, "lineup_%s_34.png" % sex), "turn": -35.0, "cam": cam_front(5.7)},
                     {"name": "lineup_%s_back" % sex, "out": os.path.join(review, "lineup_%s_back.png" % sex), "turn": 180.0, "cam": cam_front(5.7)}]
            for i, p in enumerate(PEOPLE):
                shots.append({"name": "bust_%s_%s" % (p["id"], sex), "out": os.path.join(review, "bust", "bust_%s_%s.png" % (p["id"], sex)),
                              "res": [960, 1080], "cam": bust_cam(xs[i], sex == "m")})
                shots.append({"name": "bust34_%s_%s" % (p["id"], sex), "out": os.path.join(review, "bust", "bust34_%s_%s.png" % (p["id"], sex)),
                              "res": [960, 1080], "turn": -40.0, "cam": bust_cam(xs[i], sex == "m")})
                if p["id"] == "riverborn":
                    c = bust_cam(xs[i], sex == "m")
                    c["lens"] = 135.0
                    shots.append({"name": "gills_%s" % sex, "out": os.path.join(review, "bust", "gills_riverborn_%s.png" % sex),
                                  "res": [960, 1080], "turn": -78.0, "cam": c})
            scenes.append({"name": "lineup_" + sex, "figures": figs, "shots": shots})
        scenes += V["scenes"](skins, dyes, review)
    job = {"ground_png": ground, "brow_png": brow, "scenes": scenes}
    jp = os.path.join(work, "job_test.json" if test else "job.json")
    json.dump(job, open(jp, "w"), indent=1, ensure_ascii=False)
    print("PREP_JOB", jp, len(scenes), "scenes", sum(len(s["shots"]) for s in scenes), "shots")


# ------------------------------------------------------------------------------------------------- the bold variants
def variants():
    P = {p["id"]: p for p in PEOPLE}
    looks = []
    ds_amounts = [("none", 0.0), ("wrists", 0.2), ("marked", 0.5), ("heavy", 0.85)]
    ds_tones = [("sea_teal", "#3f9a9a"), ("silver", "#a9b4bc"), ("gold", "#c9a24a"), ("jade", "#5f9a80")]
    sc_amounts = [("patches", 0.3), ("half", 0.6), ("most", 0.9)]
    sc_tones = [("slate", "#6f7f8c"), ("sandstone", "#b49a72"), ("granite", "#8a8682"), ("jade_veined", "#6f8f80"), ("ochre", "#a8844e")]
    rb_skins = [("light", "dutch_f_s3"), ("mid", "filipino_f_s1"), ("deep", "central_african_f_s2")]
    rb_tints = [0.3, 0.75, 1.0]
    ab_sets = [("none", []), ("thumbprint", ["thumbprint"]), ("rite", ["thumbprint", "cheeks", "hands"])]
    base_ds = PRESETS["vietnamese_f_s2"]
    H = with_hair
    for k, a in ds_amounts:
        looks.append(("var_ds_amount_%s" % k, H(dict(melanin=base_ds["melanin"], undertone=base_ds["undertone"], trait_kind=3, trait=a, trait_tone="#3f9a9a"), "hair_long_loose", "black")))
    for k, t in ds_tones:
        looks.append(("var_ds_tone_%s" % k, H(dict(melanin=base_ds["melanin"], undertone=base_ds["undertone"], trait_kind=3, trait=0.85, trait_tone=t), "hair_long_loose", "black")))
    base_sc = PRESETS["chinese_m_s2"]
    for k, a in sc_amounts:
        looks.append(("var_sc_amount_%s" % k, H(dict(melanin=base_sc["melanin"], undertone=base_sc["undertone"], male=1.0, trait_kind=4, trait=a, trait_tone="#6f7f8c"), "hair_topknot", "black")))
    for k, t in sc_tones:
        looks.append(("var_sc_tone_%s" % k, H(dict(melanin=base_sc["melanin"], undertone=base_sc["undertone"], male=1.0, trait_kind=4, trait=0.9, trait_tone=t), "hair_topknot", "black")))
    for sk, pid in rb_skins:
        pr = PRESETS[pid]
        for t in rb_tints:
            looks.append(("var_rb_%s_%02d" % (sk, int(t * 100)), H(dict(melanin=pr["melanin"], undertone=pr["undertone"], trait_kind=5, trait=0.6, trait_tone="#3f9a9a", tint=t), "hair_long_loose", "sea_black")))
    base_ab = PRESETS["english_m_s3"]
    for k, a in ab_sets:
        looks.append(("var_ab_%s" % k, H(dict(melanin=base_ab["melanin"], undertone=base_ab["undertone"], male=1.0, ash=a), "hair_loose_tied", "black")))
    base_ab2 = PRESETS["west_african_m_s1"]
    for k, a in ab_sets:
        looks.append(("var_ab_deep_%s" % k, H(dict(melanin=base_ab2["melanin"], undertone=base_ab2["undertone"], male=1.0, ash=a), "hair_natural_short", "black")))

    def scenes(skins, dyes, review):
        out = []
        V = os.path.join(review, "variants")

        def row(name, specs, sex, extra_shots=(), full=True, bust=True, turn_bust=0.0, night=False, spacing=0.9):
            figs, shots = [], []
            n = len(specs)
            for i, (label, p, skin, kw) in enumerate(specs):
                x = (i - (n - 1) / 2) * spacing
                figs.append(figure(label, p, sex, skin, x, dyes, **kw))
                if bust:
                    shots.append({"name": "%s_%s" % (name, label), "out": os.path.join(V, name, "%s.png" % label), "res": [960, 1080],
                                  "turn": turn_bust, "cam": bust_cam(x, sex == "m")})
            if full:
                w = max(3.0, n * spacing + 0.8)
                shots.append({"name": name + "_full", "out": os.path.join(V, name, "full.png"), "cam": cam_front(w)})
            shots += list(extra_shots)
            return {"name": name, "figures": figs, "shots": shots, "night": night}

        out.append(row("ds_amount", [(k, P["dragon_sea"], skins["var_ds_amount_%s" % k], {}) for k, _ in ds_amounts], "f", turn_bust=-35.0))
        out.append(row("ds_tone", [(k, P["dragon_sea"], skins["var_ds_tone_%s" % k], {}) for k, _ in ds_tones], "f", full=False, turn_bust=-35.0))
        out.append(row("sc_amount", [(k, P["stone_children"], skins["var_sc_amount_%s" % k], {"hair": "hair_topknot"}) for k, _ in sc_amounts], "m", turn_bust=-30.0))
        out.append(row("sc_tone", [(k, P["stone_children"], skins["var_sc_tone_%s" % k], {"hair": "hair_topknot"}) for k, _ in sc_tones], "m", full=False, turn_bust=-30.0))
        rbs = []
        for sk, pid in rb_skins:
            for t in rb_tints:
                rp = dict(P["riverborn"])
                rp["f"] = pid
                rbs.append(("%s_%02d" % (sk, int(t * 100)), rp, skins["var_rb_%s_%02d" % (sk, int(t * 100))], {}))
        out.append(row("rb_tint", rbs, "f", full=False, turn_bust=-30.0, spacing=0.8))
        abs_ = []
        for k, _ in ab_sets:
            abs_.append((k, P["ancestor_bound"], skins["var_ab_%s" % k], {}))
        for k, _ in ab_sets:
            ap = dict(P["ancestor_bound"])
            ap["m"] = "west_african_m_s1"
            abs_.append(("deep_" + k, ap, skins["var_ab_deep_%s" % k], {"hair": "hair_natural_short"}))
        out.append(row("ab_ash", abs_, "m", full=False))
        # the Hồ Tinh tails: 1, 3 and 9, in the fur colours, seen from behind at 3/4 and from the front
        ht = P["ho_tinh"]
        T1 = {"theta0": 180.0, "spread": 0.0, "phis": [28, 50, 44, 14, -26]}
        T3 = {"theta0": 180.0, "spread": 62.0, "phis": [22, 48, 60, 50, 30], "curl": [0, 0, 0.2, 0.5, 0.8], "jitter": 6.0}
        T9 = {"theta0": 0.0, "spread": 128.0, "phis": [8, 26, 46, 62, 72], "curl": [0, 0, 0.12, 0.32, 0.55], "jitter": 9.0}
        tails = [("t1_cream", {"tails": dict(T1, n=1, fur="cream")}),
                 ("t3_russet", {"tails": dict(T3, n=3, fur="russet")}),
                 ("t9_cream", {"tails": dict(T9, n=9, fur="cream")}),
                 ("t9_silver", {"tails": dict(T9, n=9, fur="silver_white", spread=140.0)}),
                 ("t9_black_tipped", {"tails": dict(T9, n=9, fur="black_tipped", spread=110.0)})]
        figs = []
        for i, (label, kw) in enumerate(tails):
            figs.append(figure(label, ht, "f", skins["ho_tinh_f"], (i - 2) * 1.45, dyes, **kw))
        out.append({"name": "ht_tails", "figures": figs, "shots": [
            {"name": "ht_tails_back34", "out": os.path.join(V, "ht_tails", "back34.png"), "turn": 150.0, "cam": cam_front(7.2, cy=0.8)},
            {"name": "ht_tails_front", "out": os.path.join(V, "ht_tails", "front.png"), "cam": cam_front(7.2, cy=0.8)},
            {"name": "ht_tails_side", "out": os.path.join(V, "ht_tails", "side.png"), "turn": 90.0, "cam": cam_front(7.2, cy=0.8)}]})
        ears = [("pointed", {"ears": {"shape": "pointed", "fur": "cream"}}),
                ("rounded", {"ears": {"shape": "rounded", "fur": "russet"}}),
                ("tufted", {"ears": {"shape": "tufted", "fur": "silver_white"}}),
                ("pointed_back", {"ears": {"shape": "pointed", "fur": "cream", "keys": {"ear_back": 1.0}}}),
                ("pointed_flat", {"ears": {"shape": "pointed", "fur": "cream", "keys": {"ear_flat": 1.0}}})]
        out.append(row("ht_ears", [(k, ht, skins["ho_tinh_f"], dict(kw, tails=dict(T1, n=1, fur=kw["ears"]["fur"]))) for k, kw in ears],
                       "f", full=False, turn_bust=-38.0))
        # reflective eyes at night (the eye shader's tv_night): Dragon-Sea green-gold, Riverborn gold; off / strong
        eyes = [("ds_off", P["dragon_sea"], skins["dragon_sea_f"], {"reflect": 0.0}),
                ("ds_strong", P["dragon_sea"], skins["dragon_sea_f"], {"reflect": 1.0}),
                ("rb_off", P["riverborn"], skins["riverborn_f"], {"reflect": 0.0}),
                ("rb_strong", P["riverborn"], skins["riverborn_f"], {"reflect": 1.0})]
        out.append(row("eyes_night", eyes, "f", full=False, night=True))
        return out
    return {"looks": looks, "scenes": scenes}


if __name__ == "__main__":
    main()
