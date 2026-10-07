"""The Mountain Folk fringed shoulder mantle (cloth2 recipe type fringe_mantle: cloth2.tv_dress.FRINGE_MANTLE): a short
indigo-black capelet over the shoulders and upper arms whose lower edge is cut into ragged hemp-bound strips, a grey
goat-fur ruff rolled round the neck and two or three hawk feathers tucked at the left shoulder. The wide shaggy shoulder
line of the Mountain Folk silhouette."""

from cloth2 import garment as G
from cloth2 import recipes
from cloth2 import tv_dress as TVD
from cloth2.garments import _tv_common as TV
from cloth2.spec import Spec, Zone

UNDER = ["tv_mf_wrap_vest", "tv_mf_short_robe"]

SPEC = Spec(
    id="tv_mf_shoulder_mantle", name="Fringed shoulder mantle", set="tv_highland", slot="outer",
    layer={"default": 40},
    description="A short indigo-black capelet over the shoulders, its edge cut into ragged strips, a grey fur ruff at "
                "the neck and hawk feathers at the left shoulder.",
    history="Design note: the shaggy shoulders of the hunter's sheet and the lineup, made readable: strips 4-5 cm wide "
            "and 8-15 cm long (each its own length, every other one standing proud), a fur roll at the neck, "
            "feathers breaking the outline on one side only. Feathers are a hunter's, not a rank; no feather crown.",
    zones=[Zone(0, "cloth", "cloth", "WOOL", TV.HIGHLAND, "tv_indigo_black"),
           Zone(1, "fringe strips", "fringe", "HES", TV.HIGHLAND, "tv_hemp"),
           Zone(2, "goat fur ruff", "fur", "FUR", TV.HIGHLAND, "tv_fur_grey"),
           Zone(3, "feathers", "trim", "FLAT", TV.HIGHLAND, "tv_walnut")],
    sources=[], evidence="C", tags=["men", "women", "tv_highland", "mountain_folk", "everyday"], budget=7000,
    over=UNDER,
    extra=TV.extra({0: "felt", 1: "hemp", 2: "fur", 3: "feather"},
                   presets={"stone_ridge": {"0": "tv_indigo_black", "1": "tv_hemp", "2": "tv_fur_grey"},
                            "cloud_pass": {"0": "tv_bone", "1": "tv_jade_cloth", "2": "tv_fur_grey"},
                            "high_pine": {"0": "tv_pine_black", "1": "tv_ochre", "2": "tv_walnut"}},
                   note="cloth2.tv_dress.fringe_mantle: the cloak envelope over the shoulders and the arms (150 "
                        "columns), the strips from 1.12 (front) / 1.05 (back) down 8-15 cm, 4 columns wide with a "
                        "1-column cut between, every other strip 3.5 mm proud; a 5.5 cm ruff raised 2.2 cm with "
                        "lumps; three feathers at 62 deg, z 1.30.",
                   fringe_variant={"A": "short strips 8-15 cm", "B": "long strips 14-24 cm", "C": "two tiers"}))

STYLE = dict(TVD.FRINGE_MANTLE, over=tuple(UNDER))


def build(g, st=STYLE):
    recipes.fringe_mantle(g, st)


build_and_export = G.runner(SPEC, build)
