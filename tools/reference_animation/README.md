# Offline animation reference conversion

These tools operate on the user's separate, attributed Spellbreak extraction.
They are not a runtime dependency and do not install reference motion into the
Tidebreak animation library.

1. Recover full Skeleton rest transforms and parent indices from the cooked
   assets. UE Viewer PSA export uses placeholder parents; do not reconstruct a
   hierarchy from those. The local UE Viewer diagnostic patch and recovered
   rests are retained in the external reference folder.
2. `python3 tools/reference_animation/psa_to_glb.py --reference <extract-root> --rests <skeleton-rests.log> --out <extract-root>/godot`
3. Godot: `--headless --path <empty-project> -s <absolute-path>/bake_godot_libraries.gd -- <extract-root>/godot`
4. `reference_viewer.gd` is the standalone Godot project's UI. It searches clips,
   plays their native libraries on matching source rig scenes, supports pause,
   scrubbing and camera orbit. The GLBs contain skeletons and a small skin marker,
   not a textured character model. The viewer draws bones for inspection.

Native libraries target `Skeleton3D:<source-bone-name>`. Instantiate the reported
source rig, add an AnimationPlayer below its root, and attach the reported library.
Using these on Actor_B requires a separate rest/proportion-aware retargeting pass.
Original Unreal graph nodes and spell C++ logic are not imported as Godot code.

`python3 tools/reference_animation/test_psa_to_glb.py` covers the missing-track and
coordinate-conversion defects that rendered checks exposed. Godot bulk validation
then reloads every saved library and samples its source motion at three times.

Reference files retain the source attribution and SHA-256. Do not relabel the
converted motion as project-authored or silently add it to the shipping build.

Conversion uses NumPy offline. Runtime and Godot tools use GDScript.
