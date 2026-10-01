# Actor_A -> Actor_B clip retarget

For the owner's reported authoring workflow and the interpretation of historical
source wording, see [the animation authoring record](../../animations/SOURCE.md)
and [the provenance review](../../docs/animation_provenance.md).

Offline tools that turn clips of the bundled Actor_A rig into clips for the game's
Actor_B rig (the player). Design, evidence and numbers:
- prototype and method: `source/graph_analysis/melee_horse_prone/retarget.md`
- production library `actor_b_from_a`: `.../melee_horse_prone/actor_b_from_a.md`

Provenance: every output clip keeps its source `native_asset_id`, `original_name`,
`source_attribution` and other metadata, plus a `retarget` stamp naming the source clip.

## Run

```sh
tools/retarget/build_actor_b_from_a.sh            # production: dump -> retarget + checks -> build -> Godot test
RENDER=1 tools/retarget/build_actor_b_from_a.sh   # also the comparison sheets (opens a window)
tools/retarget/run_prototype.sh                   # the 29-clip prototype (actor_a_rt_proto)
```

Outputs of the production build:

| File | What |
| --- | --- |
| `animations_extra/Actor_B_from_A.res` | AnimationLibrary `actor_b_from_a`, 152 clips (melee, crawl / prone, horse) |
| `animations_extra/Actor_B_from_A.json` | manifest: provenance, group / use / priority, `loop` / `seamless`, weapon frames and the mount runtime recipe, per-clip checks, FK reference |
| `tests/retarget/data/actor_b_from_a_ref.json` | Actor_A reference data for the Godot test |
| `source/graph_analysis/melee_horse_prone/actor_b_from_a_report.json` | full metrics and checks |

```gdscript
anim_player.add_animation_library("actor_b_from_a", load("res://animations_extra/Actor_B_from_A.res"))
anim_player.play("actor_b_from_a/atk-machete-1-slash")
```

Tests: `tests/retarget/test_actor_b_from_a.gd` (production, 638 checks: provenance, bone
paths, playback == tool FK, joint-path similarity, contact slide, prop / grip / weapon-frame
placement and roll, the guard weapon against the source's two hands, hinge direction, flexion
speed, limb rotation steps, wrist bend, straight knees and elbows, continuity, loop seams, the
floor per frame, the mount runtime recipe (push-off ball and ground contacts), clip-to-clip and
weapon seams (swing and roll in the hand), Add2) and
`tests/retarget/test_retarget_library.gd` (prototype). Rebuilding the prototype with
`run_prototype.sh` now uses retarget.py 0.4 (IK, contact, loop fixes; `loop_from_seam` keeps its old
loop choice), so its numbers will differ from `retarget.md`; the horse prototype uses the shipped
`actor_a_rt_proto.res`, which this pass did not rebuild.

## Files

| File | What it does |
| --- | --- |
| `dump_clips.gd` | Godot, headless, in `source/godot_export`: rests, bind-pose candidates and clips to JSON (30 fps). `every=N` samples a library for the bind probe. |
| `bind_pose_probe.py` | Finds an actor's true bind pose: constant bone offsets, `null-add` agreement, single-axis hinges. |
| `rtmath.py` | Batched quaternion / matrix math and skeleton FK (numpy). |
| `retarget.py` | The retarget (bind-relative rotations, anchor-mapped root, one-sided hinge IK, limb-length targets, straight-knee / straight-elbow caps, wrist limit, per-frame floor, contacts, props and the synthetic guard weapon, prop roll, additives, loops). `--report`, `--manifest`, `--test-ref`. |
| `contacts.py` | Automatic contact detection and plant locks: foot and hand plants, hands / knees on the floor, stirrups, rein hand, two-handed grip, the mount ground -> saddle align (baked into the saddle frame). |
| `weapon_frames.py` | One prop frame per weapon family (blade: Actor_B's knife frame, blade along +Y; two-handed: +Z to the working end, roll from the right palm, long guns turned), measured at build time; the canonical grips the guard clips' weapon is built from. |
| `metrics.py` | Joint-path similarity, foot sliding, floor contact, self-intersection proxies, native-clip comparison, additive checks. |
| `checks.py` | Production checks (contacts, floor per frame, props and weapon frames, the guard weapon against the source's hands, roll, hinges / straight limbs / rotation steps / wrist bend, continuity, loops, mount recipe and ground contacts, seams, weapon seams, native seams), manifest and Godot test reference. |
| `actor_b_from_a_clips.json` | Production clip set: group presets, per-clip use / priority / loop intent, weapon families, mount keys and align, validation clips, Add2 pairs, native and weapon seams. |
| `prototype_clips.json` | The prototype clip set. |
| `build_library.gd` | JSON to `AnimationLibrary` (metadata kept; library name as `resource_name`). |
| `render_compare.gd`, `render_jobs*.json`, `compose_grid.py` | Side-by-side capsule renders (Actor_A source / Actor_B retarget / Actor_B native, horse proxy, weapon bar per weapon frame (source guard clips: the line through the grip points), mount in the saddle frame and on the game horse) and labelled sheets. |
| `clip_lists.py`, `build_actor_b_from_a.sh`, `run_prototype.sh` | Pipeline glue. |
