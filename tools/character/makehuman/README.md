# MakeHuman head data (CC0)

The player head of the customizer body (body.glb, head v3) is built from the MakeHuman base
mesh and its modelling targets, read by `tools/character/body/mh.py` during
`build_character.sh --body`.

| | |
| --- | --- |
| Source | MPFB 2.0.17 (MakeHuman Plugin For Blender), `add-on-mpfb-v2.0.17.zip` from extensions.blender.org, sha256 `4f0a879d64a39bf646fbf5f53601ac678855da329d650617dca5737548239a87`, downloaded 2026-09-27 with the owner's approval |
| Licence | The MakeHuman base mesh, targets and other core assets are released under CC0 (MakeHuman Community FAQ: "Can I sell models made with MPFB?", "Can I use models made with MPFB in a closed-source game?"). The MPFB add-on code (GPL-3.0-or-later) is not used or included. |
| Files | `base.obj` (the MakeHuman base mesh, decimetres, y up, facing +z) and the 119 targets under `targets/` that the head build uses: the young female and male macros (universal average build and the three ethnic macros), the face targets mapped from the creator's 30 face features (`mh.MAP`) and the mouth-corner target (a landmark). |

Hair: the MakeHuman hairs long01, ponytail01 and short02 (makehuman_system_assets, CC0) were used
from 2026-09-27 and removed on 2026-09-28, when every style was rebuilt in the project's own strand
strips (tools/character/hair/_recipe.py). The pack's skin textures still feed the head's skin detail
(tools/character/mh_skin_detail.py; not vendored, read from the staging folder).

Body v4 (2026-09-28): the whole base mesh is the body (tools/character/body/body_v4.py). Added from the
same MPFB 2.0.17 data: the young female and male muscle / weight builds (`targets/macrodetails/universal-*-young-*`),
the ideal-proportions targets (`targets/macrodetails/proportions/`), a breast firmness target (`targets/breast/`),
and MPFB's game-engine rig with its skin weights (`rigs/rig.game_engine.json`, `rigs/weights.game_engine.json`;
the weights file states CC0), used to re-pose the body onto the Actor_B bind pose. The male genitals are the base
mesh's own `helper-genital` group. The areola mask in `assets/character/body/body_detail.png` is drawn by
tools/character/mh_skin_detail.py (not MPFB's texture).

Soft tissue and the body gauges (2026-09-28), from the same MPFB 2.0.17 data (already on disk, no new
download): MPFB's CC0 breast weights (`rigs/breast_weights.json`, the breasts on the rig's breast bones),
the young female cup targets at average and min weight (`targets/breast/*-{min,max}cup-*`, the bust gauge's
`breast_large` / `breast_small` shapes) and the six genital targets (`targets/genitals/`: a smaller default
for every man and each man's `genital_small` / `genital_large` shapes).

Credit is not required by CC0; it is given anyway in the build notes (`assets/character/body/body.json` provenance).
