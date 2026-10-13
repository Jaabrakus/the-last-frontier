# tools/thuyvan_art/bodies: grey-box builds of the two new bodies (Floodborn, Mộc Tinh)

The first build of the Thủy Vân body kits (design: `peoples_places/bodies_design.md`; brief "PP-BODIES"):
three bold silhouettes of each body, rigged on the Actor_B skeleton plus the kit's extension bones, posed, rendered
beside a human of the same height and the owner's sheet crops, and a first paint pass of variant A.

It imports `tools/character/lib` (sdf, remesh, rig, weights, helpers, shapes, context) and never edits it; the
lib README's conventions hold (Blender space z up facing -y, null-add binds, segment weights, max 4 influences,
COLOR_0 = baked shading multiplier).

| Step | Runs in | File | What it does |
|---|---|---|---|
| 1 | python3 (no lock) | `prepare_greybox.py` | Polygonizes the kit SDFs (`floodborn_shapes.py`), reshapes the creator body for Mộc Tinh and builds its bark shell and parts (`moc_tinh_shapes.py`); one npz per figure |
| 2 | Blender, through `tools/thuyvan/bin/blender_run.sh` | `build_greybox.py` | QEM decimation to LOD0, weights (`kit_weights.py`), armature = 291 Actor_B bones in rig order + kit bones in table order, painted AO, saves a .blend; exports variant A as `assets/thuyvan/bodies/*_greybox.glb` |
| 3 | Blender, through the wrapper | `render_bodies.py` | Poses (`pose.py`: rest + the idle pose-layer targets; spear / walking-staff stances with the posture overlay), props, Eevee renders lit as style guide 11, silhouettes, and `--paint` for the paint pass |
| 4 | python3 | `compose.py` | The captioned 1920 x 1080 review sheets beside the sheet crops |

Support: `skeleton.py` (null-add joints without Blender; the extension bone tables), `glb_read.py` (the creator
body's arrays without Blender), `libshim.py` (imports the lib's numpy parts outside Blender), `sdf_extra.py`
(`ECapsule`, `Warp` leaves), `paint_tex.py` (painted value maps and cards after the style guide's brush recipe),
`blender_kit.py` (armatures, posing, AO, materials), `write_body_kits.py` (`data/thuyvan_art/body_kits.json`),
`draft_preview.py` / `preview2d.py` (quick software previews while drafting).

Rig source: copies of the drive's `Frontier_animations_001.blend` (as `Actor_B_001.blend`) and
`Frontier_animations_076.blend` (as `Actor_B_021.blend`, the null-add clip) in a scratch `blender_libraries`
folder, `ANIMATION_SOURCE_ROOT` pointing at its parent; the build opens a further copy (`lib.rig.guard_source`).

```
S=<scratch>/pp_bodies
python3 tools/thuyvan_art/bodies/prepare_greybox.py $S/npz floodborn ABC 0
python3 tools/thuyvan_art/bodies/prepare_greybox.py $S/npz floodborn A 1
python3 tools/thuyvan_art/bodies/paint_tex.py $S/tex
ANIMATION_SOURCE_ROOT=$S/src BLENDER_TIMEOUT=1000 zsh tools/thuyvan/bin/blender_run.sh -b $S/work/actor_b_rig_copy.blend \
    --python-exit-code 1 -P tools/thuyvan_art/bodies/build_greybox.py -- --kit floodborn --npz $S/npz --save $S/fb.blend --glb assets/thuyvan/bodies
BLENDER_TIMEOUT=1000 zsh tools/thuyvan/bin/blender_run.sh -b $S/fb.blend --python-exit-code 1 \
    -P tools/thuyvan_art/bodies/render_bodies.py -- --kit floodborn --tex $S/tex --out $S/renders
python3 tools/thuyvan_art/bodies/compose.py $S/renders <review>/bodies/ref <review>/BODIES
```

Visual only: no body changes a speed, aim, capsule or camera; heights stay within +4 % of the human's.
