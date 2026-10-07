"""Thủy Vân's look directions as Godot data (plain python3; deterministic).

    python3 tools/thuyvan_art/godot/write_look_directions.py [--check]

Writes data/thuyvan/look_directions.json, which ThuyVanLook (scripts/thuyvan/look/thuyvan_look.gd) applies to the
WorldEnvironment and the sun. Colours, angles, fog and mist heights come from the art director's palette
(docs/thuyvan/plan/look/palettes.json "directions"; nobody retypes a hex value) and PAINT's notes
(assets/thuyvan/paint/sky/sky.json, grade/grade.json, water/water.json). This file adds only what Godot needs on top:
the engine's energy scale (Blender's sun and world strengths do not carry over one to one), exposure, the renderer
settings of style_guide.md 5.4, the four fog-stepped karst ranks, the lanterns, and the day cycle (owner_answers.md 7:
jade mist in the morning, bright noon through the day, golden lantern dusk at evening, night after; blended as the
clock moves).

ENGINE is the calibration, tuned by eye and by the look test's mid-grey check (tools/thuyvan_look/look_test.gd: a
0.5 sRGB card under noon reads 0.55-0.60 on screen). "night" is a proposal (no painted night sky yet: the dusk
panorama, darkened and cooled).
--check: write nothing, exit 1 if the file would change.
"""

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
PALETTES = os.path.join(REPO, "docs", "thuyvan", "plan", "look", "palettes.json")
PAINT = os.path.join(REPO, "assets", "thuyvan", "paint")
OUT = os.path.join(REPO, "data", "thuyvan", "look_directions.json")
RES_PAINT = "res://assets/thuyvan/paint/"

DIRECTIONS = ["jade_mist_morning", "bright_saturated_noon", "golden_lantern_dusk"]

# Godot's own numbers per direction (the palette's are Blender's). sun_scale x the palette's sun energy; ambient_scale x
# its ambient energy; exposure: Environment.tonemap_exposure; sky_energy: the panorama's strength as background and
# sky light; fog_scale x the palette's depth-fog density (Blender's mist pass starts at 150 m; Godot's exponential fog
# starts at the camera, so the mistier directions are thinned to keep the near ground clear).
ENGINE = {
    "jade_mist_morning": dict(sun_scale=1.0, ambient_scale=1.0, exposure=1.08, sky_energy=1.0, fog_sky_affect=0.6,
                              fog_scale=0.7),
    "bright_saturated_noon": dict(sun_scale=1.0, ambient_scale=1.0, exposure=0.95, sky_energy=1.0, fog_sky_affect=0.5,
                                  fog_scale=1.0),
    "golden_lantern_dusk": dict(sun_scale=1.0, ambient_scale=1.0, exposure=1.0, sky_energy=1.0, fog_sky_affect=0.6,
                                fog_scale=0.85),
}

# The night after dusk (proposal): a cool moon key light, a deep indigo ambient and fog, the lanterns lit; the dusk
# panorama darkened and cooled by the sky's tint until a night sky is painted.
NIGHT = {
    "title": "Lantern Night (proposal)",
    "pitch": "After dusk: a cool moon over the gorge, indigo fog in the valleys, the lanterns and windows the warmest "
             "things in frame. A proposal until a night sky is painted: the dusk panorama, darkened and cooled.",
    "sun": {"azimuth_deg": 160.0, "elevation_deg": 38.0, "color": "#a9bbe8", "energy": 0.35, "angular_deg": 1.0},
    "sky_from": "golden_lantern_dusk",
    "sky_tint": "#3c4876",
    "ambient": {"color": "#3a4778", "energy": 0.55, "sky_contribution": 0.35},
    "fog": {"color": "#36406a", "light_energy": 1.0, "density": 0.0006, "aerial_perspective": 0.6, "sun_scatter": 0.05,
            "height": 170.0, "height_density": 0.01},
    "mist_bands_m": [[145, 165, "indigo, in the gorge"]],
    "grade_from": "golden_lantern_dusk",
    "contrast": 1.1,
    "lanterns": {"paper": 3.0, "window": 1.5, "lamp": 4.0},
}
NIGHT_ENGINE = dict(sun_scale=1.0, ambient_scale=1.0, exposure=1.15, sky_energy=1.0, fog_sky_affect=0.5)

# The day cycle (owner_answers.md 7): [hour, direction]; between two keys the look blends by smoothstep.
DAY_CYCLE = [
    [0.0, "night"], [4.75, "night"], [6.0, "jade_mist_morning"], [8.75, "jade_mist_morning"],
    [10.75, "bright_saturated_noon"], [16.0, "bright_saturated_noon"], [17.75, "golden_lantern_dusk"],
    [19.25, "golden_lantern_dusk"], [20.5, "night"], [24.0, "night"],
]

# style_guide.md 5.4 "Fog": the far karst layers step 15 / 35 / 60 / 80 % fog at the 4 depth layers (vista_spec D14-D15,
# 2-5 km, then the sky's painted silhouettes).
KARST_RANKS = [
    {"rank": 1, "from_m": 1500.0, "to_m": 2400.0, "fog": 0.15},
    {"rank": 2, "from_m": 2400.0, "to_m": 3200.0, "fog": 0.35},
    {"rank": 3, "from_m": 3200.0, "to_m": 4200.0, "fog": 0.6},
    {"rank": 4, "from_m": 4200.0, "to_m": 6000.0, "fog": 0.8},
]

# style_guide.md 5.4 "Renderer settings" (every direction the same).
RENDER = {
    "tonemap": "agx",
    "shadows": {"pssm_splits": 4, "max_distance_m": 1500.0, "blur": 1.5},
    "ssao": {"enabled": True, "radius": 1.0, "intensity": 0.6, "power": 1.5, "light_affect": 0.0},
    "sdfgi": False,
    "ssil": False,
    "ssr": False,
    "volumetric_fog": False,
    "glow": {"enabled": True, "threshold": 0.9, "intensity": 0.4, "bloom": 0.05, "strength": 1.0},
}

LANTERN_MATERIALS = {
    "paper": ["res://assets/thuyvan/village/materials/tvv_paper.tres"],
}


def hexrgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]


def tohex(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v * 255)))) for v in c)


def lin(c):
    return [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c]


def srgb(c):
    return [v * 12.92 if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055 for v in c]


def light_tint(sun_hex, amb_hex):
    """The cards' tint (style_guide 5.2): sun colour x 0.6 + ambient x 0.4, mixed in linear light."""
    s, a = lin(hexrgb(sun_hex)), lin(hexrgb(amb_hex))
    return tohex(srgb([0.6 * x + 0.4 * y for x, y in zip(s, a)]))


def lanterns_of(text_or_dict):
    if isinstance(text_or_dict, dict):
        return text_or_dict
    t = str(text_or_dict)
    if t.startswith("on"):
        # "on: paper emission 3.0 (#ffb45a), windows 1.5, bridge-head lamps 4.0, glow on"
        return {"paper": 3.0, "window": 1.5, "lamp": 4.0}
    return {"paper": 0.0, "window": 0.0, "lamp": 0.0}


def build():
    pal = json.load(open(PALETTES))["directions"]
    sky = json.load(open(os.path.join(PAINT, "sky", "sky.json")))["directions"]
    grade = json.load(open(os.path.join(PAINT, "grade", "grade.json")))
    water = json.load(open(os.path.join(PAINT, "water", "water.json")))["river_shader_uniforms"]
    out = {}
    for key in DIRECTIONS:
        d, e = pal[key], ENGINE[key]
        s, f, a = d["sun"], d["fog"], d["ambient"]
        out[key] = {
            "title": d["title"],
            "pitch": d["pitch"],
            "sun": {"azimuth_deg": s["azimuth_deg"], "elevation_deg": s["elevation_deg"], "color": s["color"],
                    "energy": round(s["energy"] * e["sun_scale"], 3), "angular_deg": s["angular_deg"]},
            "sky": {"panorama": RES_PAINT + sky[key]["file"], "sun_uv": sky[key]["sun_uv"], "tint": "#ffffff",
                    "energy": e["sky_energy"], "zenith": d["sky"]["zenith"], "horizon": d["sky"]["horizon"]},
            "ambient": {"color": a["color"], "energy": round(a["energy"] * e["ambient_scale"], 3),
                        "sky_contribution": a["sky_contribution"]},
            "fog": {"color": f["color"], "valley_color": f.get("valley_color", f["color"]),
                    "light_energy": f["light_energy"], "density": round(f["density"] * e.get("fog_scale", 1.0), 6),
                    "aerial_perspective": f["aerial_perspective"], "sun_scatter": f["sun_scatter"],
                    "sky_affect": e["fog_sky_affect"], "height": f["height"], "height_density": f["height_density"]},
            "mist_bands_m": d["mist_bands_m"],
            "tonemap": {"mode": "agx", "contrast": grade[key]["agx_contrast"], "exposure": e["exposure"]},
            "grade": {"lut": RES_PAINT + grade[key]["file"], "saturation": grade[key]["saturation"],
                      "shadow_tint": grade[key]["shadow_tint"], "highlight_tint": grade[key]["highlight_tint"]},
            "light_tint": light_tint(s["color"], a["color"]),
            "water": {"shallow_tint": water[key]["shallow_tint"], "deep_color": water[key]["deep_color"],
                      "sky_tint": d["sky"]["horizon"]},
            "lanterns": lanterns_of(d.get("lanterns", "off")),
            "targets": d["targets"],
        }
    n, e = NIGHT, NIGHT_ENGINE
    src = out[n["sky_from"]]
    out["night"] = {
        "title": n["title"], "pitch": n["pitch"], "proposal": True,
        "sun": dict(n["sun"], energy=round(n["sun"]["energy"] * e["sun_scale"], 3)),
        "sky": {"panorama": src["sky"]["panorama"], "sun_uv": src["sky"]["sun_uv"], "tint": n["sky_tint"],
                "energy": e["sky_energy"], "zenith": "#1b2246", "horizon": "#4a5a96"},
        "ambient": dict(n["ambient"], energy=round(n["ambient"]["energy"] * e["ambient_scale"], 3)),
        "fog": dict(n["fog"], valley_color=n["fog"]["color"], sky_affect=e["fog_sky_affect"]),
        "mist_bands_m": n["mist_bands_m"],
        "tonemap": {"mode": "agx", "contrast": n["contrast"], "exposure": e["exposure"]},
        "grade": dict(out[n["grade_from"]]["grade"]),
        "light_tint": light_tint(n["sun"]["color"], n["ambient"]["color"]),
        "water": dict(out[n["sky_from"]]["water"], sky_tint="#2e3a6e"),
        "lanterns": n["lanterns"],
        "targets": {},
    }
    return {
        "_about": "Thủy Vân's look directions for Godot (ThuyVanLook). Generated by "
                  "tools/thuyvan_art/godot/write_look_directions.py from docs/thuyvan/plan/look/palettes.json and "
                  "PAINT's sky/grade/water notes; edit the generator, not this file.",
        "directions": DIRECTIONS,
        "day_cycle": DAY_CYCLE,
        "render": RENDER,
        "karst_ranks": KARST_RANKS,
        "lantern_materials": LANTERN_MATERIALS,
        "looks": out,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    txt = json.dumps(build(), indent=1, ensure_ascii=False) + "\n"
    old = open(OUT).read() if os.path.exists(OUT) else ""
    if a.check:
        print("LOOK_DIRECTIONS", "same" if old == txt else "differs")
        sys.exit(0 if old == txt else 1)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w").write(txt)
    print("LOOK_DIRECTIONS ->", os.path.relpath(OUT, REPO))


if __name__ == "__main__":
    main()
