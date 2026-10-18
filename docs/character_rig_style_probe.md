# Character rig and style probe

Recorded 2026-10-09. This is a reference inspection and compatibility plan; it does not replace the playable character or validate a retargeter.

## Source actually inspected

The user supplied a local Wii U copy of *The Legend of Zelda: Breath of the Wild*. The inspected Link model is Nintendo source material, retained as a separately attributed reference, not newly authored Tidebreak content.

- Exact parsed input: `/Users/kiwimango/Downloads/Frontier/artifacts/world_reference/character_source/Model/Link.bfres`.
- Input SHA-256: `133573d93ce3325c1b19d219daae559dfaeaf87a80d38786fd7c477857897576` (readback agrees with the rig record).
- Source container: `artifacts/world_reference/world_sources/files/GM00050000101C9400000000000000/content/Pack/TitleBG.pack`, SHA-256 `86dab02825bfe7d36b7a320d3e4c09e93f3a651093b8ebb78d9a90a2ea39ee60`.
- Container member `Model/Link.sbfres`: SHA-256 `1606fa4b2495022188b90ee0b995fa45b634925470460938a0610caa93005f1a`; container attribution and member hashes remain in `artifacts/world_reference/character_source/resource_manifest.json`.

Direct parser observations in `artifacts/world_reference/character_source/link_rig.json`: one Link model, **121 bones, 11 shapes and 11 materials**, Maya scaling mode and EulerXYZ rotations. The rotation record's first three values are Euler radians; its fourth value is not a quaternion component in this mode. The reference scene preserves source names and hierarchy; its roundtrip check is recorded in `link_rig.tscn.verified.json`. This is structural evidence, not a rendered animation or appearance parity result.

The separate portable reference at `artifacts/world_reference/character_preview/link_reference.glb`
includes Link and default armor parts: 166 combined bones, 21 meshes and decoded
source textures. Godot 4.7.2 imported that scene and rendered head/hair views in
`artifacts/world_reference/character_preview/views`. Original source shaders and
actor visibility rules have not been ported; the preview uses portable materials
and is not a claim of matching the source game's final lighting or animation.
Default armor parts do not include a shirt, so the reference renders focus on the
head rather than presenting them as a complete outfit.

The standalone 121-bone Godot scene passed saved-scene name, parent and local-rest
readback. An independent NumPy matrix calculation checked all global positions
against that scene: maximum absolute component error 1.66e-7. The offline mesh
converter separately checks computed rests against stored inverse-bind matrices.
`rebuild_reference_rig.gd` follows the documented Skeleton3D rest/pose contract:
https://docs.godotengine.org/en/latest/classes/class_skeleton3d.html

`tools/character/botw_style_preview.gd` renders current clothed male/female
characters under unchanged materials, the requested palette, and softer cel
lighting. Its comparison is in `artifacts/character_style_preview/comparison.png`.
Material and shader resources are copied for the preview; region masks, clothing
and current character geometry remain intact. This directly tests colors and
lighting, not redesigned facial proportions or integration of the source mesh.

## Existing game contract

`characters/Actor_B.tscn` and both existing body GLBs have **291 bones**. Read the canonical bind transforms from `tools/character/rig/actor_b_skeleton.json`; serialized scene rests are repaired from `actor_b/null-add` at startup (`scripts/player/player.gd:432`, `scripts/player/anim/bind_rest.gd:85`).

`scripts/player/character_body.gd:526` rebinds imported mesh weights by bone name to those current bind transforms. The current Y-up, +Z-forward character is about 1.596 m tall. Its main body uses 83 weighted bones, at most four influences per vertex, and 37 morph targets. Changing names alone cannot compensate for different proportions, joint axes or hierarchy.

The graph, sockets, IK and ragdoll depend on current bone names and dimensions (`scripts/player/anim/tree_builder.gd:1872`, `scripts/player/player.gd:567`, `scripts/player/anim/palm_reach_ik.gd:41`, `scripts/player/player_ragdoll.gd:35`). Garments and face customization also depend on morph targets, material names and the body's UV/region layout.

A prototype setting `body_path` must also disable or explicitly override `use_appearance`: `scripts/customizer/player_appearance.gd:103` adds the existing creator body and hides imported meshes outside its parts.

## Semantic map, with unresolved differences

`data/retarget/botw_reference_bone_map.json` contains **54 unique candidate pairs**. Every named source and target resolves against the inspected records. It is disabled for runtime use and has no motion-transfer validation.

- Source `Skl_Root` is the elevated hip/root anchor; source `Root` is an organizational origin, not the current hip-height `root`.
- `Arm_2_L/R` maps to current `l/r_elbow`; source `Elbow_L/R` are deformation helpers. Similarly, `Leg_2_L/R` maps to current `l/r_knee`; source `Knee_L/R` are helpers.
- Two source spine joints must be redistributed across four current spine joints; current `upper_base`, `lower_base` and `heada` need separate driver decisions.
- Finger A–E as thumb/index/middle/ring/pinky is an anatomical inference from rest positions, pending visual verification. Current palm/metacarpal joints, pinky metacarpal joint and heel joint have no selected direct source counterpart.
- The map explicitly retains **67 unmapped source bones**: 36 face, 2 hair, 12 deformation helpers, 15 clothing/gear and 2 organization bones. It lists all 237 unmatched current bones separately. These require adaptation or new authoring rather than arbitrary renaming.

Correction recorded 2026-10-09: the initial pinky candidates used current pinkya/b/c. Measured bind positions place pinkya near the wrist as a metacarpal; pinkyb/c/d are the three finger joints. The candidate map now uses pinkyb/c/d on both sides. This correction changes only the disabled semantic map, not animations, source records or runtime consumers.

## Route to a playable character with the requested look

First inspect the separately converted source model, its texture colors, silhouette and rig in a Godot reference preview. A recoloring preview of the existing clothed character can assess the requested palette, but does not reproduce Link's geometry, texture art or clothing.

For integration, fit the replacement visual body and outfit to the existing 291-bone bind skeleton, rebuild skin weights and required customization channels, and keep the current combat/controller contract. Replacing the skeleton wholesale would additionally require retargeting the animation libraries, additive base, masks, sockets, helper drivers and ragdoll.

Reusable tools: `tools/character/rig/make_rig_blend.py` reconstructs the current Blender rig from its bind record; `tools/character/lib/rig.py` exports skinned GLBs. `tools/retarget/retarget.py` supplies contact-aware retargeting methods but currently asserts Actor_A-specific inputs; it is not a BOTW converter.

Before enabling a replacement, inspect idle/run, jump-cast, landing, each elemental cast, hand grips, knockout/get-up and clothing from several views; verify ground contacts and deformation in Godot. Name checks and parse tests alone do not establish visual parity. Preserve the source records and consult `animations/SOURCE.md` and `docs/animation_provenance.md` for any separate animation-origin review.
