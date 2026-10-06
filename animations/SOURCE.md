# Frontier animation authoring record

Recorded 2026-10-01 from the project owner's account.

The owner states that they created animation motion using AI assistance and
Blender. YouTube videos were watched as tutorials, animation examples, and
visual references. The owner clarified that animation files were not imported
from those videos.

This is a record of the reported creation workflow, not an independently
verified per-clip inventory or a licence for third-party material. Specific AI
tools, Blender files, and reference links can be attached as supporting evidence.

The bundled resources and generators contain inherited input tags, aliases, and
graph keys. Their meanings must be traced through the relevant generator rather
than used alone to infer an originating product or unauthorized use.

See [the provenance review](../docs/animation_provenance.md) for observed generator
behavior, unresolved input lineage, and the distinction between source references
and the identity of newly authored output.

`tools/animation_sources.md` documents optional offline rebuild inputs. It is not
the project's authorship record. Release metadata customization operates on
export copies; development history and actual input attribution remain relevant.

## Bending cast poses: interim own clips (`data/bending/poses.json`)

Recorded 2026-10-04 from the generator code and data files (observations, not an independent audit of the binary
libraries). `scripts/bending/bend_poses.gd` plays these as the bending moves' cast poses in element mode (a duel or a ring
match) until the own bending clips exist; it reads them from the libraries below and samples no reference clip.

| Clip | Library | Generator | Inputs |
| --- | --- | --- | --- |
| `own-axe-stab` | `animations_extra/Frontier_Own.res` | `tools/anim_author/author_thrust.gd` keys the body by hand (a ready stance, the draw back, the lunge), posed by `tools/anim_author/pose_solver.gd`; `axe_stab` in `data/anim_author/axe_swings.json` has no `fit` record; baked by `tools/anim_author/author_swings.gd -- bake` (split at 0.14 s; the intro `own-axe-stab-intro` is not used) | The right hand's grip on the haft (`_carry_grip`) is measured from the end of the gathering carry clip `machete-draw--grab^idle--part` in `animations_extra/Actor_B_from_A.res` (`data/gathering/gathering.json` clips.carry); it places the right wrist relative to the keyed tool. That library's lineage is listed as not yet verified in `docs/animation_provenance.md`. Metas: `authored` names axe_swings.json, `source` reads "none: not extracted from any game". |
| `own-forage-grab-r`, `own-forage-grab-l` | `animations_extra/Frontier_Forage.res` | `tools/anim_author/blender/forage_grab.py` (IK paths and finger curls keyed in Blender on `assets/character/actor_b_body.glb`), installed by `tools/anim_author/install_forage.gd` | Starts and ends on frame 0 of `actor_b-p-relax-idle` (`data/anim_author/forage_idle_pose.json`), the same input as the Form clips below. The installer reads `actor_b-p-relax-idle` from `animations/Actor_B.res` only for the track path prefix and sets an `authored` meta; it copies no `native_asset_id`, `source_attribution` or `original_name`. The generator's header records a YouTube clip watched as a visual reference ("nothing taken from the reference but the idea of the move"); its link is not recorded. |
| `own-sway-push-two`, `own-sway-push-one`, `own-form-clap-press`, `own-form-release`, `own-form-press-wall` | `animations_extra/Frontier_Form.res` | See "Sway cast clips" below. | As recorded there. |

Held back from the poses (poses.json `exclude`, with `exclude_why`):

- `own-axe-d`, `own-axe-w` and their intros: `data/anim_author/axe_swings.json` has `fit` records naming reference swings
  (`atk-pipe-1-side-swing-intro` and `-miss`; `atk-pipe-3-to-knee-hit-intro` and `-hit`), and its summary says those key
  poses were measured off the reference (`tools/anim_author/fit_ref.gd`). The clips' `source` metas say the same.
  `own-axe-a` is `axe_d` mirrored.
- `own-axe-parry`, `own-axe-block-high` and their intros: their `source` metas read "none: not extracted from any game",
  but `tools/anim_author/author_parry.gd` and `author_high_block.gd` build every key from `axe_d`'s first key
  (`guard.duplicate(true)`; the parry then changes only the hips' and chest's yaw and the tool), and that key is one of
  the fitted ones above. `own-club-stab` takes its grip from the same key's tool (`author_thrust.gd`). This is a
  discrepancy between these clips' `source` metas and their generators' inputs; it concerns these clips, not the other
  `own-` clips. Held back until the owner decides; the poses that would have used them (Fire Parry, Catch deflect,
  Water Whip lash, Air Shield shield, Water Shield ice wall) use own push or floor-cast clips instead.

## Sway cast clips (`animations_extra/Frontier_Form.res`)

Recorded 2026-10-03 from the generator code (observations, not an independent audit of the binary library).

| Clip | Added | Generator |
| --- | --- | --- |
| `own-form-clap-press`, `own-form-release`, `own-form-press-wall` | 2026-10-02 (Form, first build) | `tools/anim_author/blender/form_clips.py` |
| `own-sway-push-two`, `own-sway-push-one` | 2026-10-02 (Sway v2 mastery pushes) | `tools/anim_author/blender/form_clips.py` (`--clips`) |

- `form_clips.py` keys body and palm targets by hand in its `CLIPS` table (root offset, hip/chest/head pitch, clavicles,
  palm places and facings, elbow poles, finger straightening, chest twist). It solves the arms and legs with two-bone IK
  (`rigkit`) on the skeleton of `assets/character/actor_b_body.glb` in Blender. Its header says it uses no reference motion.
- Input motion: every clip starts from one stand pose, frame 0 of `actor_b-p-relax-idle`
  (`data/anim_author/forage_idle_pose.json`, dumped by `tools/anim_author/blender/dump_pose.gd`; `forage_grab.py` uses the
  same input). Where the table does not move a joint, the joint keeps that pose's rotation; the finger straightening blends
  the fingers from it toward the rig's rest pose. `actor_b-p-relax-idle` comes from `animations/Actor_B.res`,
  whose lineage is listed as not yet verified in `docs/animation_provenance.md`.
- `tools/anim_author/install_form.gd` writes the baked rotations and root positions into new animations. It reads
  `actor_b-p-relax-idle` from `animations/Actor_B.res` only for the track path prefix. It copies no `native_asset_id`,
  `source_attribution` or `original_name`, and it sets an `authored` meta naming `form_clips.py`.

## Ring-sport clips (`animations_extra/Frontier_Bend.res`)

Recorded 2026-10-04 from the generator code at the time of the first build (observations, not an independent audit of the
binary library). The owner's account above (motion made with AI assistance and Blender, videos watched as tutorials and
visual references, no animation files imported) is his statement; the rows below are what the generator does.

| Clip | Added | Generator | Inputs | Visual references the owner watched |
| --- | --- | --- | --- | --- |
| `own-bend-earth-stomp` | 2026-10-04 (first set) | `tools/anim_author/blender/bend_clips.py` (`earth_stomp`) | the rig's rest pose; keys in `CLIPS` | (for the owner to fill) |
| `own-bend-earth-push` | 2026-10-04 (first set) | `bend_clips.py` (`earth_push`) | the rig's rest pose; keys in `CLIPS` | (for the owner to fill) |
| `own-bend-earth-rise` | 2026-10-04 (first set) | `bend_clips.py` (`earth_rise`) | the rig's rest pose; keys in `CLIPS` | (for the owner to fill) |
| `own-bend-throw-overhand` | 2026-10-04 (first set) | `bend_clips.py` (`throw_overhand`) | the rig's rest pose; keys in `CLIPS` | (for the owner to fill) |
| `own-bend-throw-overhand-l` | 2026-10-04 (first set) | `bend_clips.py` (`throw_overhand`, `mirror_clip`) | `throw_overhand`'s keys mirrored left for right | (as its original) |
| `own-bend-throw-sidearm` | 2026-10-04 (first set) | `bend_clips.py` (`throw_sidearm`) | the rig's rest pose; keys in `CLIPS` | (for the owner to fill) |
| `own-bend-throw-sidearm-l` | 2026-10-04 (first set) | `bend_clips.py` (`throw_sidearm`, `mirror_clip`) | `throw_sidearm`'s keys mirrored left for right | (as its original) |
| `own-bend-throw-underhand` | 2026-10-04 (first set) | `bend_clips.py` (`throw_underhand`) | the rig's rest pose; keys in `CLIPS` | (for the owner to fill) |
| `own-bend-knock-slide` | 2026-10-04 (first set) | `bend_clips.py` (`knock_slide`) | the rig's rest pose; keys in `CLIPS` | (for the owner to fill) |
| `own-bend-knock-air` | 2026-10-04 (first set) | `bend_clips.py` (`knock_air`) | the rig's rest pose; keys in `CLIPS` | (for the owner to fill) |
| `own-bend-stance-earth` | 2026-10-05 (second set) | `bend_clips.py` (`stance_earth`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-stance-fire` | 2026-10-05 (second set) | `bend_clips.py` (`stance_fire`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-stance-water` | 2026-10-05 (second set) | `bend_clips.py` (`stance_water`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-stance-air` | 2026-10-05 (second set) | `bend_clips.py` (`stance_air`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-earth-boulder` | 2026-10-05 (second set) | `bend_clips.py` (`earth_boulder`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-earth-raise` | 2026-10-05 (second set) | `bend_clips.py` (`earth_raise`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-earth-burrow` | 2026-10-05 (second set) | `bend_clips.py` (`earth_burrow`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-earth-catch` | 2026-10-05 (second set) | `bend_clips.py` (`earth_catch`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-earth-shove` | 2026-10-05 (second set) | `bend_clips.py` (`earth_shove`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-earth-shove-l` | 2026-10-05 (second set) | `bend_clips.py` (`earth_shove`, `mirror_clip`) | `earth_shove`'s keys mirrored left for right | (as its original) |
| `own-bend-fire-punch` | 2026-10-05 (second set) | `bend_clips.py` (`fire_punch`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-fire-punch-l` | 2026-10-05 (second set) | `bend_clips.py` (`fire_punch`, `mirror_clip`) | `fire_punch`'s keys mirrored left for right | (as its original) |
| `own-bend-fire-double` | 2026-10-05 (second set) | `bend_clips.py` (`fire_double`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-fire-kick` | 2026-10-05 (second set) | `bend_clips.py` (`fire_kick`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-fire-sweep` | 2026-10-05 (second set) | `bend_clips.py` (`fire_sweep`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-fire-sweep-l` | 2026-10-05 (second set) | `bend_clips.py` (`fire_sweep`, `mirror_clip`) | `fire_sweep`'s keys mirrored left for right | (as its original) |
| `own-bend-fire-breath` | 2026-10-05 (second set) | `bend_clips.py` (`fire_breath`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-fire-lightning` | 2026-10-05 (second set) | `bend_clips.py` (`fire_lightning`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-water-whip` | 2026-10-05 (second set) | `bend_clips.py` (`water_whip`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-water-whip-l` | 2026-10-05 (second set) | `bend_clips.py` (`water_whip`, `mirror_clip`) | `water_whip`'s keys mirrored left for right | (as its original) |
| `own-bend-water-wave` | 2026-10-05 (second set) | `bend_clips.py` (`water_wave`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-water-draw` | 2026-10-05 (second set) | `bend_clips.py` (`water_draw`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-water-shield` | 2026-10-05 (second set) | `bend_clips.py` (`water_shield`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-air-palm` | 2026-10-05 (second set) | `bend_clips.py` (`air_palm`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-air-palm-l` | 2026-10-05 (second set) | `bend_clips.py` (`air_palm`, `mirror_clip`) | `air_palm`'s keys mirrored left for right | (as its original) |
| `own-bend-air-sweep` | 2026-10-05 (second set) | `bend_clips.py` (`air_sweep`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-air-spin` | 2026-10-05 (second set) | `bend_clips.py` (`air_spin`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-air-leap` | 2026-10-05 (second set) | `bend_clips.py` (`air_leap`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-air-shield` | 2026-10-05 (second set) | `bend_clips.py` (`air_shield`) | the rig's rest pose; keys in `CLIPS` (`SET2`) | (for the owner to fill) |
| `own-bend-fire-kick-low` | 2026-10-05 (third set) | `bend_clips.py` (`fire_kick_low`) | the rig's rest pose; keys in `CLIPS` (`SET3`) | (for the owner to fill) |
| `own-bend-fire-kick-low-l` | 2026-10-05 (third set) | `bend_clips.py` (`fire_kick_low`, `mirror_clip`) | `fire_kick_low`'s keys mirrored left for right | (as its original) |
| `own-bend-fire-kick-l` | 2026-10-05 (third set) | `bend_clips.py` (`fire_kick`, `mirror_clip`) | `fire_kick`'s keys (`SET2`, unchanged) mirrored left for right | (as its original) |
| `own-bend-fire-fireball` | 2026-10-05 (third set) | `bend_clips.py` (`fire_fireball`) | the rig's rest pose; keys in `CLIPS` (`SET3`) | (for the owner to fill) |
| `own-bend-fire-fireball-l` | 2026-10-05 (third set) | `bend_clips.py` (`fire_fireball`, `mirror_clip`) | `fire_fireball`'s keys mirrored left for right | (as its original) |
| `own-bend-fire-parry` | 2026-10-05 (third set) | `bend_clips.py` (`fire_parry`) | the rig's rest pose; keys in `CLIPS` (`SET3`) | (for the owner to fill) |
| `own-bend-earth-kickup` | 2026-10-05 (third set) | `bend_clips.py` (`earth_kickup`) | the rig's rest pose; keys in `CLIPS` (`SET3`) | (for the owner to fill) |
| `own-bend-earth-kickup-l` | 2026-10-05 (third set) | `bend_clips.py` (`earth_kickup`, `mirror_clip`) | `earth_kickup`'s keys mirrored left for right | (as its original) |
| `own-bend-earth-uproot` | 2026-10-05 (third set) | `bend_clips.py` (`earth_uproot`) | the rig's rest pose; keys in `CLIPS` (`SET3`) | (for the owner to fill) |
| `own-bend-water-turn` | 2026-10-05 (third set) | `bend_clips.py` (`water_turn`) | the rig's rest pose; keys in `CLIPS` (`SET3`) | (for the owner to fill) |
| `own-bend-water-turn-hold` | 2026-10-05 (third set) | `bend_clips.py` (`water_turn_hold`) | the rig's rest pose; keys in `CLIPS` (`SET3`) | (for the owner to fill) |
| `own-bend-water-surf` | 2026-10-05 (third set) | `bend_clips.py` (`water_surf`) | the rig's rest pose; keys in `CLIPS` (`SET3`) | (for the owner to fill) |
| `own-bend-water-skate` | 2026-10-05 (third set) | `bend_clips.py` (`water_skate`) | the rig's rest pose; keys in `CLIPS` (`SET3`) | (for the owner to fill) |
| `own-bend-air-pull` | 2026-10-05 (third set) | `bend_clips.py` (`air_pull`) | the rig's rest pose; keys in `CLIPS` (`SET3`) | (for the owner to fill) |
| `own-bend-air-slip` | 2026-10-05 (third set) | `bend_clips.py` (`air_slip`) | the rig's rest pose; keys in `CLIPS` (`SET3`) | (for the owner to fill) |
| `own-bend-air-slip-l` | 2026-10-05 (third set) | `bend_clips.py` (`air_slip`, `mirror_clip`) | `air_slip`'s keys mirrored left for right | (as its original) |
| `own-bend-air-slip-back` | 2026-10-05 (third set) | `bend_clips.py` (`air_slip_back`) | the rig's rest pose; keys in `CLIPS` (`SET3`) | (for the owner to fill) |
| `own-bend-air-wall` | 2026-10-05 (third set) | `bend_clips.py` (`air_wall`) | the rig's rest pose; keys in `CLIPS` (`SET3`) | (for the owner to fill) |
| `own-bend-air-guard` | 2026-10-05 (third set) | `bend_clips.py` (`air_guard`) | the rig's rest pose; keys in `CLIPS` (`SET3`) | (for the owner to fill) |
| `own-bend-air-shield-hold` | 2026-10-05 (third set) | `bend_clips.py` (`air_shield_hold`) | the rig's rest pose; keys in `CLIPS` (`SET3`) | (for the owner to fill) |
| `own-bend-air-slice` | 2026-10-05 (third set) | `bend_clips.py` (`air_slice`) | the rig's rest pose; keys in `CLIPS` (`SET3`) | (for the owner to fill) |
| `own-bend-air-slice-l` | 2026-10-05 (third set) | `bend_clips.py` (`air_slice`, `mirror_clip`) | `air_slice`'s keys mirrored left for right | (as its original) |
| `own-bend-tumble` | 2026-10-06 (fourth set) | `bend_clips.py` (`tumble`, `tumble_at`) | the rig's rest pose; keys in `CLIPS` (`SET4`) | (for the owner to fill) |
| `own-bend-flinch` | 2026-10-06 (fourth set) | `bend_clips.py` (`flinch`) | the rig's rest pose; keys in `CLIPS` (`SET4`) | (for the owner to fill) |
| `own-bend-jump-double` | 2026-10-06 (fourth set) | `bend_clips.py` (`jump_double`) | the rig's rest pose; keys in `CLIPS` (`SET4`) | (for the owner to fill) |
| `own-bend-fall` | 2026-10-06 (fourth set) | `bend_clips.py` (`fall`, `fall_at`) | the rig's rest pose; keys in `CLIPS` (`SET4`) | (for the owner to fill) |
| `own-bend-fall-fast` | 2026-10-06 (fourth set) | `bend_clips.py` (`fall_fast`, `fall_fast_at`) | the rig's rest pose; keys in `CLIPS` (`SET4`) | (for the owner to fill) |
| `own-bend-helpless` | 2026-10-06 (fourth set) | `bend_clips.py` (`helpless`, `helpless_at`) | the rig's rest pose; keys in `CLIPS` (`SET4`) | (for the owner to fill) |
| `own-bend-air-dodge` | 2026-10-06 (fourth set) | `bend_clips.py` (`air_dodge`) | the rig's rest pose; keys in `CLIPS` (`SET4`) | (for the owner to fill) |
| `own-bend-air-legs` | 2026-10-06 (fourth set) | `bend_clips.py` (`air_legs`, `air_legs_at`) | the rig's rest pose; keys in `CLIPS` (`SET4`) | (for the owner to fill) |
| `own-bend-land-light` | 2026-10-06 (fourth set) | `bend_clips.py` (`land_light`) | the rig's rest pose; keys in `CLIPS` (`SET4`) | (for the owner to fill) |
| `own-bend-land-heavy` | 2026-10-06 (fourth set) | `bend_clips.py` (`land_heavy`) | the rig's rest pose; keys in `CLIPS` (`SET4`) | (for the owner to fill) |
| `own-bend-edge-grab` | 2026-10-06 (fifth set) | `bend_clips.py` (`edge_grab`) | the rig's rest pose; keys in `CLIPS` (`SET5`) | (for the owner to fill) |
| `own-bend-edge-hang` | 2026-10-06 (fifth set) | `bend_clips.py` (`edge_hang`, `hang_at`) | the rig's rest pose; keys in `CLIPS` (`SET5`) | (for the owner to fill) |
| `own-bend-edge-climb` | 2026-10-06 (fifth set) | `bend_clips.py` (`edge_climb`) | the rig's rest pose; keys in `CLIPS` (`SET5`) | (for the owner to fill) |
| `own-bend-edge-roll` | 2026-10-06 (fifth set) | `bend_clips.py` (`edge_roll`) | the rig's rest pose; keys in `CLIPS` (`SET5`) | (for the owner to fill) |
| `own-bend-edge-jump` | 2026-10-06 (fifth set) | `bend_clips.py` (`edge_jump`) | the rig's rest pose; keys in `CLIPS` (`SET5`) | (for the owner to fill) |
| `own-bend-edge-attack` | 2026-10-06 (fifth set) | `bend_clips.py` (`edge_attack`) | the rig's rest pose; keys in `CLIPS` (`SET5`) | (for the owner to fill) |
| `own-bend-roll-f` | 2026-10-06 (fifth set) | `bend_clips.py` (`roll_f`, `_roll`) | the rig's rest pose; keys in `CLIPS` (`SET5B`) | (for the owner to fill) |
| `own-bend-roll-b` | 2026-10-06 (fifth set) | `bend_clips.py` (`roll_b`, `_roll`) | the rig's rest pose; keys in `CLIPS` (`SET5B`) | (for the owner to fill) |
| `own-bend-roll-side` | 2026-10-06 (fifth set) | `bend_clips.py` (`roll_side`, `_roll`) | the rig's rest pose; keys in `CLIPS` (`SET5B`) | (for the owner to fill) |
| `own-bend-roll-side-l` | 2026-10-06 (fifth set) | `bend_clips.py` (`roll_side`, `mirror_clip`) | `roll_side`'s keys mirrored left for right | (as its original) |
| `own-bend-duck` | 2026-10-06 (fifth set) | `bend_clips.py` (`duck`) | the rig's rest pose; keys in `CLIPS` (`SET5B`) | (for the owner to fill) |
| `own-bend-rise-earth` | 2026-10-06 (sixth set) | `bend_clips.py` (`rise_earth`) | the rig's rest pose; keys in `CLIPS` (`SET6`) | (for the owner to fill) |
| `own-bend-rise-water` | 2026-10-06 (sixth set) | `bend_clips.py` (`rise_water`, `_rise_water`) | the rig's rest pose; keys in `CLIPS` (`SET6`) | (for the owner to fill) |
| `own-bend-rise-fire` | 2026-10-06 (sixth set) | `bend_clips.py` (`rise_fire`) | the rig's rest pose; keys in `CLIPS` (`SET6`) | (for the owner to fill) |
| `own-bend-rise-air` | 2026-10-06 (sixth set) | `bend_clips.py` (`rise_air`, `_rise_air`, `glide_at`) | the rig's rest pose; keys in `CLIPS` (`SET6`) | (for the owner to fill) |
| `own-bend-edge-scramble` | 2026-10-06 (sixth set) | `bend_clips.py` (`edge_scramble`) | the rig's rest pose; keys in `CLIPS` (`SET6`) | (for the owner to fill) |
| `own-bend-tech` | 2026-10-06 (sixth set) | `bend_clips.py` (`tech`, `_tech_slap`) | the rig's rest pose; keys in `CLIPS` (`SET6`) | (for the owner to fill) |
| `own-bend-tech-roll` | 2026-10-06 (sixth set) | `bend_clips.py` (`tech_roll`, `_tech_roll`, `_roll`) | the rig's rest pose; keys in `CLIPS` (`SET6`) | (for the owner to fill) |
| `own-bend-tech-roll-l` | 2026-10-06 (sixth set) | `bend_clips.py` (`tech_roll`, `mirror_clip`) | `tech_roll`'s keys mirrored left for right | (as its original) |
| `own-bend-tech-wall` | 2026-10-06 (sixth set) | `bend_clips.py` (`tech_wall`) | the rig's rest pose; keys in `CLIPS` (`SET6`) | (for the owner to fill) |
| `own-bend-lie` | 2026-10-06 (sixth set) | `bend_clips.py` (`lie`, `lie_at`, `_wclip`) | the rig's rest pose; keys in `CLIPS` (`SET6`) | (for the owner to fill) |
| `own-bend-getup` | 2026-10-06 (sixth set) | `bend_clips.py` (`getup`, `_getup`, `_wclip`) | the rig's rest pose; keys in `CLIPS` (`SET6`) | (for the owner to fill) |
| `own-bend-getup-roll` | 2026-10-06 (sixth set) | `bend_clips.py` (`getup_roll`, `_getup_roll`, `_wclip`) | the rig's rest pose; keys in `CLIPS` (`SET6`) | (for the owner to fill) |
| `own-bend-getup-roll-l` | 2026-10-06 (sixth set) | `bend_clips.py` (`getup_roll`, `mirror_clip`) | `getup_roll`'s keys mirrored left for right | (as its original) |
| `own-bend-getup-attack` | 2026-10-06 (sixth set) | `bend_clips.py` (`getup_attack`, `_getup_attack`, `_wclip`) | the rig's rest pose; keys in `CLIPS` (`SET6`) | (for the owner to fill) |
| `own-bend-knock-spiked` | 2026-10-06 (sixth set) | `bend_clips.py` (`knock_spiked`) | the rig's rest pose; keys in `CLIPS` (`SET6`) | (for the owner to fill) |
| `own-bend-knock-bounce` | 2026-10-06 (sixth set) | `bend_clips.py` (`knock_bounce`, `_wclip`) | the rig's rest pose; keys in `CLIPS` (`SET6`) | (for the owner to fill) |

- Second set and polish (2026-10-05, after the owner approved the first ten: "looks good but you can always perfect them"):
  the same generator and the same inputs (the rig's rest pose and keys typed into the table, now its `SET2` part); no clip,
  dump or reference motion read. The first ten were re-baked with the keys that had been out of the arm's or the leg's reach
  pulled in (the IK clamped them straight: the underhand's back-swing 0.125 m, the slide's guard 0.093 m, the air knock's
  flail 0.068 m, the rise 0.054 m, the stomp 0.044 m) and a few settle keys added; their `hold_s` and `strike_s` are unchanged.
  `--fit` lists the frames where a limb is within 1.5 cm of straight and the striking limb's slack at `strike_s`. The
  stances are loops (meta `loop`, installed `LOOP_LINEAR`, interpolated across the seam); `spin` turns the whole figure on
  the spot (the air spin). The martial-art styles named in the table's comments (Hung Gar, Northern Shaolin, tai chi,
  Baguazhang: `docs/bending_design.md`'s Animations table) are style labels for the typed key poses; no recording or
  animation file of them was read by the generator.
- Third set (2026-10-05, round 2 of the ring sport's skills): the same generator and the same inputs (the rig's rest pose and
  keys typed into the table, now its `SET3` part, two loops' circles written as `_ring` over typed centres and radii); no
  clip, dump or reference motion read. `fire_kick` (the second set's kick, now the High Kick) gained `"mirror": True` so its
  twin `own-bend-fire-kick-l` is baked; its own keys are unchanged. `own-bend-earth-catch` was re-keyed in place at the owner's
  request that every guard read at a glance (the hold wider and higher, the rock held between the palms, the right on top and
  the left under, instead of two fists); its length and moments (`hold_s`, `strike_s`, `back_s`) are unchanged. The other 38
  clips were not re-baked (their tracks are as before). The bake now also writes `ik_miss_m`, the two-bone IK's worst miss
  over the clip's frames, onto each clip it bakes. The style labels named in the table's comments (Northern Shaolin, Hung Gar,
  tai chi, Baguazhang) are labels for the typed key poses, as above.
- Fourth set (2026-10-06, round 3's first playable: the air and hit states of the % ring): the same generator and the same
  inputs (the rig's rest pose and keys typed into the table, now its `SET4` part); no clip, dump or reference motion read.
  The loops (`fall`, `fall_fast`, `helpless`, `air_legs`) have their channels written as typed functions of the loop's phase
  (`fall_at`, `fall_fast_at`, `helpless_at`, `air_legs_at`) sampled at its eighths (`_loop`); the tumble and the helpless
  fall turn the whole keyed figure about the hips' height (the new `flip`, `cart` and `flip_turns` channels: the keys stay
  the body's own pose, turned whole); `air_legs` bakes only the legs' bones (`"bones": "legs"`, no root track). None has a
  side, so none is mirrored. Only these ten were baked (`--clips`); the other clips' tracks are as before.
  Revised the same day after a review of the sheets (pass 2): the same generator, the same inputs and the same ten clips,
  re-keyed and re-baked (`--clips`); no clip, dump or reference motion read. The tumble's somersault is now typed as a turn
  rate (`tumble_at`: an average and a swing in degrees a frame, fastest in the tuck), its channels keyed at every frame; the
  loops' typed functions are sampled at every frame instead of their eighths (`_loop`); `own-bend-flinch` is 9 frames (was 8)
  and `own-bend-land-heavy` 14 (was 12), their `strike_s` and `hold_s` unchanged (`own-bend-flinch`'s `back_s` 5 frames, was
  4); `own-bend-jump-double`'s `strike_s` is 2 frames (was 3) and its `back_s` 8 (was 7). The other clips' tracks are as before.
  Revised again the same day after a second review (pass 3): the same generator, the same inputs and the same ten clips,
  re-keyed and re-baked (`--clips`); no clip, dump or reference motion read. New in the generator: a `tilt` channel (the head's
  side tilt, keyed only by `helpless`), `"hands_from": "shoulder"` (`helpless`'s hands keyed as the arm's reach from its
  shoulder, still typed numbers) and `--angles` (a printout of the elbow and knee bends); clips that key none of them pose as
  before. `own-bend-land-heavy` is 16 frames (was 14), its `strike_s`, `hold_s` and `back_s` unchanged;
  `own-bend-jump-double`'s `hold_s` is 2 frames (was 1) and its `strike_s` 3 (was 2), `back_s` unchanged. The other clips'
  tracks are as before.
- Fifth set (2026-10-06, round 3's first playable: the deck's edge and the ground dodges of the % ring): the same generator
  and the same inputs (the rig's rest pose and keys typed into the table, now its `SET5` and `SET5B` parts; the hang's loop
  written as a typed function of its phase, `hang_at`, sampled at every frame by `_loop`; the three rolls from one typed
  sequence, `_roll`); no clip, dump or reference motion read. The edge clips are keyed in the hang's frame (the origin where
  the game snaps a hanger, the lip at `LIP_Y` over it and `LIP_Z` ahead; metas `lip_y`, `lip_out`, and `end_in` where a
  get-up ends standing on the deck). New in the generator: a `pivot` channel (the point the flip and the cart turn the
  figure about; a ground roll turns about its tucked ball's middle), a `ground` channel with the clip's `floor` (the whole
  figure shifted by that share of the gap between the deck and its lowest surface, from the typed joint radii `SURF`: a
  contact constraint like the IK's, a uniform shift that leaves every rotation as keyed) and `--points` (a printout of key
  joints and the lowest surface). Clips that key none of them pose as before. `roll_side` has `"mirror": True`, so its twin
  `own-bend-roll-side-l` is the same keys mirrored. Only these eleven were baked (`--clips`); the other clips' tracks are as
  before.
  Revised the same day after a review of the sheets (pass 2): the same generator, the same inputs and the same eleven clips,
  re-keyed and re-baked (`--clips`); no clip, dump or reference motion read; their lengths and moments (`hold_s`, `strike_s`,
  `back_s`) are unchanged. New in the generator: `lift` and `lift_w` (the edge jump's keys over the code's own carry, spec
  5.3's vy 11.8 m/s: the share of that typed parabola the clip takes back, a uniform shift like `ground`), `substeps` (the
  grab baked four times a frame, meta fps 120 in the json, so its planted palms hold between the keys; `install_bend.gd`
  reads a clip's own rate), and typed helpers that turn a typed place back through a typed flip or cart (`_unturn`, so a
  hand keyed on the deck lands there while the figure turns) or through a heel lift (`_heel_place`); `--points` also prints
  `spinec`. The rolls key the head's `tilt`, `look` and the trunk's `twist` (a shoulder roll's diagonal). Clips that key none
  of them pose as before. The martial-art styles in the comments remain labels for the typed key poses.
  Revised again the same day after a third review (pass 3): the same generator, the same inputs and the same eleven clips,
  re-keyed and re-baked (`--clips`); no clip, dump or reference motion read; their lengths and moments (`hold_s`,
  `strike_s`, `back_s`) are unchanged. The keys changed are typed numbers in `SET5` and `SET5B` (the hang's feet and sway in
  `hang_at`, the forward roll's closed ball in the new typed table `BALL`, two typed facings, `fling` and `guard_out`). New
  in the generator: the side roll's meta `travel` ("right"; "left" on its mirrored twin, which `mirror_clip` swaps;
  `install_bend.gd` keeps it as a word) and
  `HAT_REST`/`hat_low`, five typed points on the rig's `headb` measured off the glb's own Hat mesh at rest (its bounds, not
  any animation), printed by `--points` as the hat's lowest point; it is a report only and moves nothing. Clips that key
  none of the new channels pose as before.
- Sixth set (2026-10-06, round 3's P2: the four Rises, the scramble up the deck's face, breaking the fall, lying and getting
  up, the spiked and bounce knocks): the same generator and the same inputs (the rig's rest pose and keys typed into the
  table, now its `SET6` part; the lie's loop and the air Rise's glide written as typed functions of their phase, `lie_at`
  and `glide_at`, sampled at every frame; the water Rise's arm circles as a typed function, `water_swirl`); no clip, dump or
  reference motion read. `own-bend-tech-roll` is `_roll("side")`'s typed keys (the fifth set's side roll, unchanged) with
  its first three frames replaced by the typed breakfall slap (`_tech_slap`). New in the generator: a `barrel` channel (the
  figure turned about its own long axis after the flip and the cart: the getup roll's log roll), `"toes": "foot"` (the toes
  kept with the foot, for a sole laid flat on the deck while the figure lies), `_heel_key` (the foot key that lands the
  ankle exactly where it is typed through a heel lift and toe-out) and `_wclip` (a clip typed in the deck's frame: the
  pelvis's place, the figure's turn and the palms' and ankles' places on the deck, turned back into the figure's own keys
  at every frame by the same rotations `pose()` applies; typed numbers in, typed numbers out). Clips that key none of them
  pose as before. Metas new to this set: `loop_from_s` (the air Rise loops from there to its end: its glide), `wall_z` (the
  wall breaker's wall ahead), `haul_m` (the part of the scramble's climb its own keys carry) and `lying` (a figure on its
  back the whole clip). `tech_roll` and `getup_roll` have `"mirror": True` (and meta `travel`). Only these sixteen clips
  were baked (`--clips`); the other clips' tracks are as before. The martial-art styles in the comments (Hung Gar's horse,
  tai chi's golden rooster, Northern Shaolin's rising punch and carp skip-up, Baguazhang's turning) remain labels for the
  typed key poses.
- `bend_clips.py` is derived from `form_clips.py` (above) and keys body and limb targets by hand in its `CLIPS` table: the
  root's offset, a whole-body yaw, hip pitch and tilt, chest pitch, side bend and twist, head pitch and turn, clavicles,
  palm places and facings, elbow poles, finger closing, and per foot the ankle's place, toe-out, heel lift and knee pole.
  It solves the arms and legs with two-bone IK (`rigkit.ik2`) on the skeleton of `assets/character/actor_b_body.glb`
  (read from the checkout it runs in) in Blender, interpolating the keys with a monotone cubic.
- Input motion: none. Unlike `form_clips.py`, it does not start from `actor_b-p-relax-idle` or
  `data/anim_author/forage_idle_pose.json`: every clip starts from the rig's rest (bind) pose in the glb, keyed into the
  table's own stand. It does not import `rigkit.Native`/`MirrorNative`, read `dump_move.gd`/`dump_pose.gd` output or any
  animation library, and `tools/anim_author/fit_ref.gd` was not run. The glb's rest finger rotations are the relaxed hand
  the finger closing starts from.
- The `-l` twins are the same keys mirrored across the body's middle (`mirror_clip`), not a mirror of baked rotations.
- `tools/anim_author/install_bend.gd` writes the baked rotations and root positions into new animations named
  `own-bend-*`. It reads `own-form-release` from `animations_extra/Frontier_Form.res` only for the track path prefix. It
  writes no `native_asset_id`, `source_attribution` or `original_name`, and it sets an `authored` meta naming
  `bend_clips.py` plus the clip's moments (`strike_s`, `hold_s`, `back_s`, `up_s`) and words (`hand`, `mask`, `root`).
- `--blend` keeps the baked clips as Blender actions on the rig for hand refinement;
  `tools/anim_author/blender/bake_blend.py` reads the actions of that .blend back into the same json for `install_bend.gd`
  (a hand-refined clip keeps this record's generator plus the owner's edits in that file). `tests/bending/test_bend_clips.gd`
  checks this table against the library.
- The throw clips replace, for the ring sport, the throwables' throw clips (`actor_b-p-1h-aim-throw-*` in
  `animations/Actor_B.res`, used by `ThrowChain`); the owner chose new own throw clips for it on 2026-10-04.

### Interim clips the ring sport may wire before its own exist (observed 2026-10-04)

| Clip | Library | Generator | Inputs observed |
| --- | --- | --- | --- |
| `own-axe-stab`, `own-club-stab` | `animations_extra/Frontier_Own.res` | `tools/anim_author/author_thrust.gd` keys, baked by `author_swings.gd -- bake` with `pose_solver.gd` | Key poses typed in `author_thrust.gd` (no `fit` record in `data/anim_author/axe_swings.json`). `own-axe-stab`'s grip reads the prop bone's place in the right hand from the gathering `carry` clip in `animations_extra/Actor_B_from_A.res` (`_carry_grip`). `own-club-stab` takes its tool hold from the first key of `axe_d`. |
| `own-axe-parry`, `own-axe-block-high` | `animations_extra/Frontier_Own.res` | `author_parry.gd`, `author_high_block.gd`, baked by `author_swings.gd -- bake` | Start and end on the first key of `axe_d` ("from the D swing's guard"). `axe_d` carries a `fit` record naming `atk-pipe-1-side-swing-intro` / `-miss` (`author_swings.gd`'s header: `fit_ref.gd` writes the keys of a clip measured off a reference). |
| `own-forage-grab-r`, `own-forage-grab-l` | `animations_extra/Frontier_Forage.res` | `tools/anim_author/blender/forage_grab.py`, `install_forage.gd` | Blender IK on keyed paths and finger curls, starting from frame 0 of `actor_b-p-relax-idle` (`data/anim_author/forage_idle_pose.json`), as for `form_clips.py`. |

- These rows record inputs that bear on wiring the clips into the ring sport. They do not establish any clip's origin.
  The `axe_d` fit and the `Actor_B_from_A.res` carry read are the specific inputs to trace for the parry, high-block and stab
  clips before they are counted as fully own.
