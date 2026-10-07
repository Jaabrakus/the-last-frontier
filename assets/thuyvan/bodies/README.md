# assets/thuyvan/bodies: grey-box body kits (review stage, not wired into the game)

| File | What | Skeleton | Morphs |
|---|---|---|---|
| `floodborn_greybox.glb` | Floodborn variant A, "Mooring Guard": body with its own crocodilian head and the tail, plus eyes, teeth and the quill crest | 291 Actor_B bones in rig order, then `tail_01..08`, `snout_tip` and `jaw_tip` | `sex` (projected onto the male fit) |
| `moc_tinh_greybox.glb` | Mộc Tinh variant A, "Grove-Tender": the creator body, reshaped, plus the bark shell, spurs, roots, crown, vines and flowers | 291 Actor_B bones in rig order, then `crown_root`, `crown_1..6_01/02` and `vine_1..4_01..04` | none yet (`sex` goes in by wrap transfer when the parts are final) |

## Provenance

- These meshes are our own, built procedurally in Blender by `tools/thuyvan_art/bodies/` (SDFs and the creator's own
  `assets/character/body/body.glb`). No sheet pixels, downloads or third-party meshes were used.
- The skeleton, bone names and bind pose come from the Actor_B rig (`lib/rig.py PROVENANCE_RIG`), read from a copy of
  the project's rig library.
- COLOR_0 carries the baked shading multiplier (the painted AO).

## Status

These are grey-box review assets for the owner's silhouette pick (bodies_design.md section 7, step 1). Nothing loads
them yet. The Godot lane attaches them through `BodyExtensions` (`data/thuyvan_art/body_kits.json`).
