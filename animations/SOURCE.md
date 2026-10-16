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

Re-baked 2026-10-11 (the owner: "do a animation for all the moves retouch or make it smoother") from the same generator and
the same typed keys, with one solver change and seven pole retouches; no new input of any kind, nothing imported or retargeted:
the limbs' two-bone IK became `rigkit.ik2_hinge` (the same joint places as `rigkit.ik2`, the twist decided so a knee or an
elbow bends only about its own hinge), and the elbow or knee pole keys of `fire_kick_low`, `fire_fireball`, `fire_axe_kick`,
`water_skate`, `fire_flip_kick` and `air_hit_earth` (and their mirrored twins), and of `hit_impact_back`, were retyped where
they had lain along the limb (`docs/tidebreak/animation_retouch_2026-10-11.md`).

Re-baked again later on 2026-10-11 (the owner: "sometime the body like glitches it turns elastic", then "fix them") from the
same generator and keys, with one solver change and no new input: the flip guard (`rigkit.ik2_hinge` `GUARD_DPS`), on every
clip but the loops and `air_hit_earth` and its twin, swings a knee's or an elbow's bend side round over a few frames where the
keys would flip it over 100 degrees in one; the knee pole keys of `roll_b` (frames 4-11) and `getup` (frames 2-8) were retyped
to keep each knee on one side. Nothing imported, retargeted or sampled (same document, "The elastic glitch").

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
| `own-bend-stance-water-wing-chun` | 2026-10-12 (the owner: "can we change the water idle stance to wing chun", then of three legs under its hands "A"; water's stance since, `own-bend-stance-water` its stand-in) | `bend_clips.py` (`stance_water_wing_chun`, `_wc_stance`) | the rig's rest pose; keys typed in `bend_clips.py`: Wing Chun's Man Sau and Wu Sau hands on a fighting stagger, keyed from the stance's standard mechanics (no video was looked at for it) | (for the owner to fill) |
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
| `own-bend-jab-rise` | 2026-10-07 (seventh set) | `bend_clips.py` (`jab_rise`) | the rig's rest pose; keys in `CLIPS` (`SET7`) | (for the owner to fill) |
| `own-bend-jab-rise-l` | 2026-10-07 (seventh set) | `bend_clips.py` (`jab_rise`, `mirror_clip`, `twin_tail`, `twin_keys`) | `jab_rise`'s keys mirrored left for right to frame 12, then `jab_rise`'s own keys (its held-stone end); the hands' and the fingers' keys typed for the twin (`twin_keys`, pass 3) | (as its original) |
| `own-bend-earth-hammer` | 2026-10-07 (seventh set) | `bend_clips.py` (`earth_hammer`) | the rig's rest pose; keys in `CLIPS` (`SET7`) | (for the owner to fill) |
| `own-bend-water-downpour` | 2026-10-07 (seventh set) | `bend_clips.py` (`water_downpour`) | the rig's rest pose; keys in `CLIPS` (`SET7`) | (for the owner to fill) |
| `own-bend-fire-axe-kick` | 2026-10-07 (seventh set) | `bend_clips.py` (`fire_axe_kick`, `_heel_key`) | the rig's rest pose; keys in `CLIPS` (`SET7`) | (for the owner to fill) |
| `own-bend-fire-axe-kick-l` | 2026-10-07 (seventh set) | `bend_clips.py` (`fire_axe_kick`, `mirror_clip`) | `fire_axe_kick`'s keys mirrored left for right | (as its original) |
| `own-bend-air-down-gust` | 2026-10-07 (seventh set) | `bend_clips.py` (`air_down_gust`, `_heel_key`) | the rig's rest pose; keys in `CLIPS` (`SET7`) | (for the owner to fill) |
| `own-bend-guard-hold-earth` | 2026-10-07 (seventh set) | `bend_clips.py` (`guard_hold_earth`, `guard_earth_at`, `_loop`) | the rig's rest pose; keys in `CLIPS` (`SET7`) | (for the owner to fill) |
| `own-bend-guard-hold-water` | 2026-10-07 (seventh set) | `bend_clips.py` (`guard_hold_water`, `guard_water_at`, `_loop`) | the rig's rest pose; keys in `CLIPS` (`SET7`) | (for the owner to fill) |
| `own-bend-guard-hold-fire` | 2026-10-07 (seventh set) | `bend_clips.py` (`guard_hold_fire`, `guard_fire_at`, `_loop`) | the rig's rest pose; keys in `CLIPS` (`SET7`) | (for the owner to fill) |
| `own-bend-guard-hold-air` | 2026-10-07 (seventh set) | `bend_clips.py` (`guard_hold_air`, `guard_air_at`, `_loop`) | the rig's rest pose; keys in `CLIPS` (`SET7`) | (for the owner to fill) |
| `own-bend-teeter` | 2026-10-07 (seventh set) | `bend_clips.py` (`teeter`, `teeter_at`, `_each`) | the rig's rest pose; keys in `CLIPS` (`SET7`) | (for the owner to fill) |
| `own-bend-spout-ride` | 2026-10-07 (eighth set) | `bend_clips.py` (`spout_ride`, `spout_at`, `_loop`) | the rig's rest pose; keys in `CLIPS` (`SET8`) | (for the owner to fill) |
| `own-bend-spout-step-off` | 2026-10-07 (eighth set) | `bend_clips.py` (`spout_step_off`) | the rig's rest pose; keys in `CLIPS` (`SET8`) | (for the owner to fill) |
| `own-bend-fire-flip-kick` | 2026-10-07 (eighth set) | `bend_clips.py` (`fire_flip_kick`, `_heel_key`) | the rig's rest pose; keys in `CLIPS` (`SET8`) | (for the owner to fill) |
| `own-bend-fire-flip-kick-l` | 2026-10-07 (eighth set) | `bend_clips.py` (`fire_flip_kick`, `mirror_clip`) | `fire_flip_kick`'s keys mirrored left for right | (as its original) |
| `own-bend-air-hit-earth` | 2026-10-07 (eighth set) | `bend_clips.py` (`air_hit_earth`) | the rig's rest pose; keys in `CLIPS` (`SET8`) | (for the owner to fill) |
| `own-bend-air-hit-earth-l` | 2026-10-07 (eighth set) | `bend_clips.py` (`air_hit_earth`, `mirror_clip`) | `air_hit_earth`'s keys mirrored left for right | (as its original) |
| `own-bend-air-hit-water` | 2026-10-07 (eighth set) | `bend_clips.py` (`air_hit_water`, `water_ring_at`, `_each`) | the rig's rest pose; keys in `CLIPS` (`SET8`) | (for the owner to fill) |
| `own-bend-air-hit-water-l` | 2026-10-07 (eighth set, pass 2) | `bend_clips.py` (`air_hit_water`, `mirror_clip`) | `air_hit_water`'s keys mirrored left for right | (as its original) |
| `own-bend-air-hit-fire` | 2026-10-07 (eighth set) | `bend_clips.py` (`air_hit_fire`, `_heel_key`) | the rig's rest pose; keys in `CLIPS` (`SET8`) | (for the owner to fill) |
| `own-bend-air-hit-fire-l` | 2026-10-07 (eighth set, pass 3) | `bend_clips.py` (`air_hit_fire`, `mirror_clip`) | `air_hit_fire`'s keys mirrored left for right | (as its original) |
| `own-bend-air-hit-air` | 2026-10-07 (eighth set) | `bend_clips.py` (`air_hit_air`) | the rig's rest pose; keys in `CLIPS` (`SET8`) | (for the owner to fill) |
| `own-bend-air-hit-air-l` | 2026-10-07 (eighth set, pass 2) | `bend_clips.py` (`air_hit_air`, `mirror_clip`) | `air_hit_air`'s keys mirrored left for right | (as its original) |
| `own-bend-hit-impact-front` | 2026-10-07 (ninth set) | `bend_clips.py` (`hit_impact_front`, `_struck`, `_arc`) | the rig's rest pose; keys in `CLIPS` (`SET9`) | (for the owner to fill) |
| `own-bend-hit-impact-back` | 2026-10-07 (ninth set) | `bend_clips.py` (`hit_impact_back`, `_struck`, `_arc`) | the rig's rest pose; keys in `CLIPS` (`SET9`) | (for the owner to fill) |
| `own-bend-hit-impact-left` | 2026-10-07 (ninth set) | `bend_clips.py` (`hit_impact_left`, `_struck`, `_arc`) | the rig's rest pose; keys in `CLIPS` (`SET9`) | (for the owner to fill) |
| `own-bend-hit-impact-right` | 2026-10-07 (ninth set) | `bend_clips.py` (`hit_impact_left`, `mirror_clip`) | `hit_impact_left`'s keys mirrored left for right | (as its original) |
| `own-bend-fire-embers-gun` | 2026-10-11 (tenth set) | `bend_clips.py` (`fire_embers_gun`, `point_r`) | the rig's rest pose; keys in `CLIPS` (`SET10`) | (for the owner to fill) |
| `own-bend-fire-embers-gun-l` | 2026-10-11 (tenth set) | `bend_clips.py` (`fire_embers_gun`, `mirror_clip`) | `fire_embers_gun`'s keys mirrored left for right | (as its original) |
| `own-bend-fire-lightning-duel` | 2026-10-11 (tenth set) | `bend_clips.py` (`fire_lightning_duel`, `point2_r`) | the rig's rest pose; keys in `CLIPS` (`SET10`) | (for the owner to fill) |
| `own-bend-water-ice-rifle` | 2026-10-11 (tenth set) | `bend_clips.py` (`water_ice_rifle`) | the rig's rest pose; keys in `CLIPS` (`SET10`) | (for the owner to fill) |

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
  Revised on 2026-10-07 (the animation lane's second run, P1-air polish pass 1, the critic's notes): the same generator and
  the same inputs (the rig's rest pose and keys typed into `SET4` and its typed loop functions); no clip, dump or reference
  motion read. Five clips re-keyed by hand and re-baked (`--clips`): `own-bend-tumble` (`tumble_at`: the arms drawn only 45%
  of the way in, to typed places beside the knees with the hands open, `TUMBLE_ARMS_IN`, `TUMBLE_HALF_R/L`; the legs 70%,
  `TUMBLE_LEGS_IN`, opened from f18), `own-bend-flinch` (the head and chest keys cushioned over f2-f4; the hands' f1 key up
  and out), `own-bend-jump-double` (a deeper gather, the push held over f3-f4 and bowed, the tuck at f7), `own-bend-fall-fast`
  (`fall_fast_at`: the knees drawn up together, `FALL_FAST_FOOT`, the hands beside the hips, `FALL_FAST_HAND`, pitched 20
  degrees, a larger buffet) and `own-bend-helpless` (`helpless_at`: the hips bowed forward, the knees bent, lying back
  34-50 degrees, `HELPLESS_FOOT_R/L`). Their lengths and metas (`strike_s`, `hold_s`, `back_s`, `hand`, `mask`, `root`) are
  unchanged; the other clips' tracks are as before.
  Integration follow-up on 2026-10-07: the saved `tb/ANIM-polish-wip-3` key edits were completed for four clips:
  `own-bend-tumble`, `own-bend-jump-double`, `own-bend-fall-fast` and `own-bend-helpless`. Direct code observations:
  `tools/anim_author/blender/bend_clips.py` uses its default input `assets/character/actor_b_body.glb` for the rig;
  these four motions come from its typed keys and loop functions. The generated JSON was installed with
  `tools/anim_author/install_bend.gd`, which takes track prefixes from `Frontier_Form.res` and merges the four clips
  into `animations_extra/Frontier_Bend.res`. Unreachable limb targets were shortened; the fast-fall knees and arm
  sweep and the double-jump push were corrected against the engine's geometry checks. This describes the observed
  generation route, not an independent ownership audit of the rig or the other bundled assets. The owner's reported
  AI/Blender workflow remains the account recorded above. The historical critic notes remain available; passing the
  technical checks does not assign these four clips a new artistic score.
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
  tai chi's cloud hands, Northern Shaolin's rising punch and carp skip-up, Baguazhang's palm change) remain labels for the
  typed key poses.
  Revised the same day (pass 2, the critic's notes): the same generator, the same inputs and the same sixteen clips,
  re-keyed and re-baked (`--clips`); no clip, dump or reference motion read. The keys changed are typed numbers in `SET6`
  and its typed functions (`lie_at`, `glide_at`, the water Rise's arm circles now `_cone_hand` on a typed cone about each
  shoulder, `GROLL_BARREL` and `GROLL_TWIST` for two log rolls, `GA_ARC`); the water Rise's golden rooster gave way to both
  hands raised over the head and the air Rise's crane to a palm change; the lie's raised foot was set further out (typed in
  `lie_at`) so its thigh lies at a slant, which also changes the first and last poses of the clips that start or end on
  the lie (the getups and the bounce key from `LIE`). Some of these clips' own moments changed
  (`own-bend-getup` `strike_s` 9/30 s and `back_s` 11/30 s, `own-bend-getup-roll` and its twin `strike_s` 5/30 s and
  `back_s` 15/30 s, `own-bend-knock-spiked` `hold_s` 5/30 s); no earlier set's clip was re-baked. `bend_preview.gd` and
  `bend_engine_strip.gd` now draw the wall a clip names (meta `wall_z`) for review; they read no motion.
  Revised again on 2026-10-07 (pass 3, the critic's pass-2 notes): the same generator, the same inputs and the same sixteen
  clips, re-keyed and re-baked (`--clips`); no clip, dump or reference motion read. The keys changed are typed numbers in
  `SET6` and its typed functions: the earth Rise's throw made asymmetric (the right fist driven up, the left chambered at
  the hip, the fists' path carried out in front clear of the hat); the water Rise's circles driven by the trunk (typed
  `WATER_TWIST`, `WATER_SIDE`, `WATER_SWAY`, `WATER_REACH`, `WATER_BOB`, `WATER_TURNS`) into a white-crane peak
  (`WATER_TOP`, `WATER_PRESS`); the glide's wings swept back with bent elbows (`glide_at`, `GLIDE_FLEX`, a typed facing
  `wing`); the scramble's right hand over the lip at f2; the breakfall slap leant over its arm with the head up (`SLAP`)
  and both breaks entered from one typed airborne frame (`TECH0`); the wall break's head kept back; the lie's beat moved
  early (`LIE_STIR`, `LIE_LIFT`, `LIE_SAG`); the getup's in-between and settle; the log roll eased into a rock up to the
  feet (`GROLL_BARREL`, the roll kept on the deck by the existing `ground` channel); the crab sweep's straight leg
  (`GA_ARC`, `GA_SLACK`, `_hip_at`: the hip's place from the rig's own rest turned by the clip's typed turn, as `pose()`
  turns it); the spiked and bounce knocks' limbs. `own-bend-tech-roll` and its twin are one frame longer (19 frames, the
  airborne entry first; `hold_s` 2/30 s, `strike_s` 8/30 s, `back_s` 14/30 s); `own-bend-edge-scramble`'s `strike_s` is now
  3/30 s (the right hand on the deck). New in the generator: `twin_keys` (channels typed for a twin alone: the tech roll's
  twin's hips tilt), and `--points` also prints the hat's farthest point ahead and how near a palm comes to the hat (a
  report only). No earlier set's clip was re-baked. `bend_preview.gd` gains `pairs=` (one clip's last frame beside
  another's first: the scramble onto the hang) and `nosheets=`; `bend_engine_strip.gd` poses the edge clips 2 m along the
  lip from its middle, clear of the stock ring's lantern pier; they read no motion.
- Seventh set (2026-10-07, round 3's P2: the Pop's rising hand, the four Slams, the four held guards and the teeter): the
  same generator and the same inputs (the rig's rest pose and keys typed into the table, now its `SET7` part; the guard
  holds' loops and the teeter's windmill written as typed functions of the frame, `guard_<element>_at` and `teeter_at`);
  no clip, dump or reference motion read. The guard holds take their held poses from round 2's own guard clips' typed keys
  (`earth_catch`, `water_turn`, `fire_parry`, `air_guard` in this table) as numbers retyped, not from a library. The Pop's
  hand ends at the place `scripts/bending/bend_r3.gd` (`pop_stone`) holds earth's Pop stone (typed as `POP_STONE`; a
  place in the game's code, not motion). Only these twelve clips were baked (`--clips`); no earlier set's clip was
  re-baked and their tracks and moments are unchanged. The martial-art styles in the comments (Hung Gar's double hammer
  fist, tai chi's pressing palms and ward-off, Northern Shaolin's axe kick and knife hand, Baguazhang's coiled palms and
  wheel) are labels for the typed key poses only. New in the generator: `twin_ends` (a twin that leaves and lands on its
  original's own unmirrored first and last keys, the fall's first pose: the Axe Kick's twin; meta `twin_ends`).
  Pass 2 (the same day, the critic's pass-1 notes; the same generator and inputs, keys retyped in `SET7`, only these twelve
  clips re-baked): the Pop's coil deeper and its fist driven straight up in one C with the spine, the guard hand a frame
  late with a dip; its twin rises on the left and from frame 12 takes the original's own keys, so both end with the right
  hand on the stone where the code holds it (new in the generator: `twin_tail`; metas `twin_tail_s` and `stone_hand`, the
  latter a word meta in `install_bend.gd`); the Hammer's hold one backward C with the fists behind the head and its fists
  finishing ahead of and below the knees in a wider, sunk air horse; the Downpour's press with long arms ahead of the hips
  on an upright, lifted column with the feet together and pointed, its V wider; the Axe Kick swung up outside on a
  crescent, chopped down with the knee long, the rear leg split back and the fists thrown back; the Down Gust's palms
  raised by the ears and driven 0.7 m down, a harder wring and unscrew with a side bend, a bigger lift; the earth guard's
  horse wider and lower with a breath and squeeze that read; the fire guard's bounce deeper and sharp at the bottom with
  the hands settling after it; the teeter 15 frames (`strike_s` 3/30 s, `hold_s` its end): tipped from the ankles, long
  arms windmilling from the shoulders on a spin-up and settle (`_trap`) that never steps more than about 55 degrees a
  frame, the arms splayed wide of the hat as they rise, caught with the right arm up and back and the left ahead. The
  timing metas of every earlier set are unchanged. `bend_preview.gd` gains `sheet_at=` (a clip's sheet at chosen frames:
  the Axe Kick twin's blend in-betweens); `bend_engine_strip.gd` gains `stone=` (the Pop stone drawn where the code holds
  it) and `lip=` (a clip posed at the deck's end lip facing the water, its own views), orders a strip's moments in time and
  labels the follow-through as the sheets do; they read no motion.
- Eighth set (2026-10-07, round 3's P3: the spout ride and a step-off from it, the air High Kick's back-flip crescent and
  the four air-only close hits the owner approved on 2026-10-05, one an element): the same generator and the same inputs (the
  rig's rest pose and keys typed into the table, now its `SET8` part; the spout ride's loop written as a typed function of
  its phase, `spout_at`, and the water hit's ring as a typed function of the frame over typed angles, `water_ring_at`); no
  clip, dump or reference motion read. The air clips start and end on AIR, the fall's first pose (the seventh set's own
  keys); the step-off starts on the spout ride's first pose. Only these nine clips were baked (`--clips`); no earlier set's
  clip was re-baked and their tracks and moments are unchanged. The martial-art styles in the comments (Hung Gar's driving
  elbow, tai chi's cloud hands, Northern Shaolin's double flying kick and back-flip kick, Baguazhang's turning palms) are
  labels for the typed key poses only. `own-bend-spout-step-off` is not named in `data/ring/movement.json`; it is there for
  the movement task to map when the spout is left. New in the generator: `mirror_clip`'s `twin_ends` keeps a whole turn on the
  spot (`spin`) mirrored at the twin's end (-360, the same pose as +360) instead of the original's unmirrored end.
  Pass 2 (the same day, the critic's pass-1 notes): the same generator and inputs; only the eighth set's clips re-keyed and
  re-baked (`--clips`), plus two new twins, `own-bend-air-hit-water-l` and `own-bend-air-hit-air-l` (the water sweep and the
  air whirl are sided). The spout ride a wide staggered riding stance with the knees out and round arms pressing the water,
  its surge a typed quick lift and long ease (`_surge`) taken late through the knees, the hands and the head; the step-off
  16 frames with a deep held dip and the arms in opposition; the flip kick's arms thrown back past the head and round one
  arc onto the shins, its kicking knee nearly straight and its other leg folded; the earth hit a boulder (both legs tucked,
  the knee raised, the elbow on it, the fists stacked, a hit-stop then a whip and an overshoot); the water hit's ball held at
  the arms' length from an approximate typed shoulder line (`_ring_shoulders`), the waist leading it and the legs swung
  against it; the fire hit's legs a frame apart with a recoil and its fists flung back on long arms; the air hit's palm
  change, long dragging arms and the head's spot. `bend_engine_strip.gd` gains `spout=` (the clip stood on RingSpout's own
  column and crown) and a forward drift on `rise=` (an air clip seen on a real jump's arc); it reads no motion.
  Pass 3 (the same day, the critic's pass-2 notes): the same generator and inputs (the rig's rest pose and keys typed into
  the table); no clip, dump or reference motion read; only the eighth set's clips re-baked (`--clips`), plus one new twin,
  `own-bend-air-hit-fire-l` (the fire hit's right foot leads). The spout ride's palms lower and nearer with the elbows out
  and dropped (round arms), the step-off's left hand reaching ahead of the chest with an open palm; the water hit re-keyed
  as tai chi's "hold the ball" (the right palm stacked over the left, the chest's heading typed in `WATER_C` with the hips
  leading it in `WATER_YAW` and the ball's offset off it in `RING_OFF`, a typed counter-lean in `WATER_ROLL` and
  `WATER_SIDE`, the knees tucked high), its strike moved from f5 to f4 (`strike_s` 0.133, `back_s` 0.300); the fire hit's
  trunk only a little back with the head down the legs and the fists chambered at the waist; the air hit's open slant on
  its strike frame, the lead palm at the eyes' height on a round arm with the wrist bent back, the feet tucked higher. The
  water hit's and the twins' other metas, and every earlier set's clip, are unchanged. `bend_engine_strip.gd` gains `at=`
  (a clip shown at chosen frames: the spout's surge); it reads no motion.
- Ninth set (2026-10-07, round 4's struck bodies: the contact poses round 4's hit-stop holds a struck body in, one a side
  the hit comes from): the same generator and the same inputs (the rig's rest pose and keys typed into the table, now its
  `SET9` part; each clip's contact pose typed as a channel's value at the hold and eased from the stand by a typed spacing
  a part (`_struck`, `STRUCK_SPACING`), the head's pitch, turn and tilt typed a frame, the palms keyed as their reach from
  the shoulders and carried round them on an arc (`_arc`)); no clip, dump or reference motion read. Each is 6 frames: the
  hit at f0 (`strike_s` 0), the contact at f3 (`hold_s` 0.1, the frame the hit-stop holds), the overlap after it
  (`back_s` 4/30 s) that `own-bend-tumble` or `own-bend-flinch` takes over from; a new word meta `from` (front, back,
  left, right: the side the hit comes from; `install_bend.gd` writes it as a word). `own-bend-hit-impact-right` is
  `hit_impact_left`'s keys mirrored. Only these four clips were baked (`--clips`); no earlier set's clip was re-baked and
  their tracks and moments are unchanged. `bend_preview.gd` gains `before=` (a sheet opening with another clip's frame:
  the stand the contact snaps out of) and a pair's `@frame` (a hand-over into the middle of the next clip); they read no
  motion.
  Revised the same day (pass 2, the critic's notes): the same generator, the same inputs and the same four clips, re-keyed
  by hand in `SET9` and `STRUCK_SPACING`. The front hit's arms flung forward at the shoulders' height (no raised V), its
  pelvis shoved behind the heels, the left leg the straighter with its toes up; the back hit re-keyed as an arch (the belly
  driven forward, the chest thrust out, the arms flung back and down in a low V, up on the balls of the feet); the side
  hit's struck arm out and back about 20 degrees above the shoulder, the weight further onto the far leg with the struck
  heel peeled (the right one still its mirror); the head and the arms overshoot the hold at f4 and settle, the knees keep
  giving a frame, and the trunk recoils first. The metas
  (6 frames, `strike_s` 0, `hold_s` 0.1, `back_s` 4/30 s, mask full, `from`) are unchanged; only these four clips were
  re-baked.
- Tenth set (2026-10-11, the owner: "the pistol set would be for embers right? ... the side one hand pistol will be
  lightning? and then the rifle will be a rifle stance and then water conjures in to take the rifles spot like a spear"):
  the same generator and the same inputs (the rig's rest pose and keys typed into the table, now its `SET10` part, with two
  new finger channels, `point_<side>` and `point2_<side>`, that straighten the index and thumb, or the index and middle
  finger, out of the grip); no clip, dump or reference motion read. The gun stances are a look the keys were typed toward
  (the owner likes the game's pistol aim); nothing of the game's gun clips was read or measured for them. In the game
  Embers plays `own-bend-fire-embers-gun` (and its twin), timed as the clip it replaced (`timed_as` in
  `data/bending/poses.json`: the sweep's hold, strike, back and end). Since 2026-10-12 the Ice Spear plays our own
  `own-bend-throw-overhand` (and its twin) with the Frontier spear's own model (`assets/weapons/spear.glb`, made by
  `tools/models/spear.py`) floating over the arm; `own-bend-water-ice-rifle` stays installed, cast by no move, as the
  timeline `frontier-pistol-ice` (below) is baked on. `own-bend-fire-lightning-duel` is installed but cast by no move: its right hand at
  its strike is the two-finger hand of `frontier-pistol-ice`.
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

## Frontier tech for the ring sport: the pistol's aim (`animations_extra/Frontier_Bend_Aim.res`)

| Clip | Made | Generator | Inputs | Lineage |
| --- | --- | --- | --- | --- |
| `frontier-pistol-ice` | 2026-10-12 (first baked 2026-10-11 as `frontier-pistol-lightning`, now removed from the library) | `tools/anim_author/bake_bend_aim.gd` | the body: `actor_b-p-pistol-aim-idle` from `animations_extra/Frontier_Downgraded.res` (the twisted stance, `mocap_downgrade_all.gd`'s `_twisted_stance`: the bow's aim mirrored under the pistol aim's own arm); the right arm: `own-pistol-bow-arm` from the same library (the bow's aim mirrored, at its start); the left arm: `actor_b-p-relax-idle` from `animations/Actor_B.res` (at phase 0); the right hand's fingers: `own-bend-fire-lightning-duel` at its strike (ours, above), the hand turned at the wrist so they go on along the forearm; the start and end pose: `own-bend-stance-water` (ours; `own-bend-stance-fire` for the removed Lightning version); the timing: `own-bend-water-ice-rifle`'s length, `hold_s`, `strike_s`, `back_s` (ours; `own-bend-fire-lightning`'s for the removed version) | the body and both arms are built from the base library (`animations/Actor_B.res`, whose lineage is listed as not yet verified in `docs/animation_provenance.md`); the hand, the timing and the kick are ours |

- The owner asked for it (2026-10-11): "im saying use our musket and pistol tech that we built in frontiers over", then
  "the lighting seems not like the pistol stand aim we have", then "we want both moves the orignal one and the lightning
  pistol it will be a skill tree thing have this or that and each has it perks and cons"; then (2026-10-12) "the lightning
  pistol... we dont have that skill and use that animation for the ice or water rifle spear for water? and we keep the
  orignal lightning animation". It is the game's own standing pistol aim (the pieces `PlayerAnim` puts together for a
  pistol aimed standing: the twisted stance, `STAND_AIM_ARM`, the hanging left arm) baked onto the Ice Spear's rifle
  timeline, with a raise from water's stance over 0.3 s, a kick at the strike and a lowering from `back_s`. In the game `BendAimArm` (the pistol's `JogAimArm`, aiming the two fingers) turns the arm onto the
  crosshair and the head toward it after the clip.
- It is NOT one of our own key-posed clips and is not named `own-`: it lives in its own library, and `BendPoses` lets a pose
  play it only because `data/bending/poses.json` lists it by name in `frontier_tech` (`BendPoses.frontier_tech`). The
  Lightning Pistol twist (`fire.lightning.pistol`) was taken out of the tree on 2026-10-12, and later that day the owner
  picked our own overhand throw for the Ice Spear over this aim. Since the evening of 2026-10-12 it is the Air Beam's (the
  Gust held long, `air_gust` gust's `grow`, timed as `own-bend-throw-overhand`): the owner, "the air should get the pistol
  animation thats perfect for that one like. beam". Lightning is `own-bend-fire-lightning`. Its `authored` and `lineage` metas name the inputs above; it carries no
  `native_asset_id`, `source_attribution` or `original_name`.
- Tracing it: the inputs that bear on its origin are the two `Frontier_Downgraded.res` clips (built by
  `tools/anim_author/mocap_downgrade_all.gd` from `actor_b-p-bow-aim-idle` and `actor_b-p-pistol-aim-idle` in
  `animations/Actor_B.res`) and `actor_b-p-relax-idle`; the rest is ours.

## Fighting style clips: Boxing for fire (`animations_extra/Frontier_Style_Boxing.res`)

Recorded 2026-10-09 from the generator code (observations, not an independent audit of the binary library). The first
fighting style (docs/fighting_styles_design.md: each element keeps its moves, a style re-animates how the body performs
them). The visual references were watched by Claude in the built-in browser for this task, on the owner's instruction
("we need to watch videos on martial art styles and create animations for them"); their links and the timestamps used are
in `docs/fighting_styles/boxing_reference.md` (V1-V4 below).

| Clip | Added | Generator | Inputs | Visual references watched |
| --- | --- | --- | --- | --- |
| `own-style-boxing-stance` | 2026-10-09 | `tools/anim_author/blender/style_boxing.py` (`stance`, a loop typed as a function, `stance_at`) | the rig's rest pose; keys typed in the generator | V1, V3 |
| `own-style-boxing-jab` | 2026-10-09 | `style_boxing.py` (`jab`) | the rig's rest pose; keys typed in `CLIPS` | V2, V4 (timing) |
| `own-style-boxing-cross` | 2026-10-09 | `style_boxing.py` (`cross`) | the rig's rest pose; keys typed in `CLIPS` | V2, V4 (timing) |
| `own-style-boxing-hook` | 2026-10-09 | `style_boxing.py` (`hook`) | the rig's rest pose; keys typed in `CLIPS` | V4 |
| `own-style-boxing-punch` | 2026-10-09 | `style_boxing.py` (`punch`) | the rig's rest pose; keys typed in `CLIPS` | V2 (the cross it extends with a step) |
| `own-style-boxing-fireball` | 2026-10-09 | `style_boxing.py` (`fireball`, an overhand) | the rig's rest pose; keys typed in `CLIPS` | none (keyed from standard boxing mechanics) |
| `own-style-boxing-lightning` | 2026-10-09 | `style_boxing.py` (`lightning`, a charged straight) | the rig's rest pose; keys typed in `CLIPS` | V2 (the straight it ends on) |
| `own-style-boxing-ground-punch` | 2026-10-09 | `style_boxing.py` (`ground_punch`, the Kick; the owner's choice) | the rig's rest pose; keys typed in `CLIPS` | none (the project's own move) |
| `own-style-boxing-uppercut` | 2026-10-09 | `style_boxing.py` (`uppercut`, the High Kick; the owner's choice) | the rig's rest pose; keys typed in `CLIPS` | none (keyed from standard boxing mechanics) |
| `own-style-boxing-flurry` | 2026-10-09 | `style_boxing.py` (`flurry`, a 1-2 flurry) | the rig's rest pose; keys typed in `CLIPS` | V2 (its jab and cross), V4 (timing) |
| `own-style-boxing-slip` | 2026-10-09 | `style_boxing.py` (`slip`, the Parry) | the rig's rest pose; keys typed in `CLIPS` | V2 (the counter jab); the slip itself none |
| `own-style-boxing-step-in`, `-step-back`, `-step-left`, `-step-right` | 2026-10-09 | `style_boxing.py` (`step_in`, `step_back`, `step_left`, `step_right`) | the rig's rest pose; keys typed in `CLIPS` | V3 (the stance in motion); the steps themselves none |

- V1 FightCamp, "Boxing Stance | Beginner Step-By-Step Tutorial", https://www.youtube.com/watch?v=SjLXzCpRS8U; V2 FightCamp,
  "How to Punch: Jab & Cross Beginner Boxing Tutorial", https://www.youtube.com/watch?v=YsFK1MMDQgk; V3 FightCamp, "LEARN
  BEGINNER BOXING FOOTWORK IN 5 MINUTES | Beginner Boxing", https://www.youtube.com/watch?v=dg2Jp3F30Lw; V4 Tony Jeffries,
  "Basics of Boxing - Training for Beginners at Home", https://www.youtube.com/watch?v=kKDHdsVN0b8. Watched as visual
  references only: paused and looked at, nothing downloaded, traced, motion-captured or pose-estimated. The clips marked
  "none" were not checked against a video: the browser pane could not draw the videos for the rest of the session and the
  owner chose to skip that check (2026-10-09); they are keyed from standard boxing mechanics.
- `style_boxing.py` keys body and limb targets by hand in its `CLIPS` table (bend_clips.py's channels) and poses and bakes
  them with `tools/anim_author/blender/bend_clips.py`'s own solver (`pose()`, two-bone IK with `rigkit.ik2`, and `bake()`),
  imported as a module, on the skeleton of `assets/character/actor_b_body.glb` in Blender. For this bake only (bend_clips.py
  itself is unchanged) it sets bend_clips' finger curl table to its own `BOX_CURL` and wraps `pose()` so that each thumb is
  then folded across its fist by two-bone IK on the thumb's own joints (`_thumb_fold`; the owner, 2026-10-09: "make sure the
  hand ik is closed"); both read only the posed rig. Every clip starts and ends on the boxing guard, the stance loop's
  first frame, keyed from the rig's rest pose. It reads no library clip, no `dump_move.gd` / `dump_pose.gd` output and no
  `rigkit.Native` / `MirrorNative`; `fit_ref.gd` was not run. There are no mirrored twins (the stance is orthodox).
- `tools/anim_author/install_style.gd` writes the baked rotations and root positions into new animations named
  `own-style-boxing-*`. It reads `own-form-release` from `animations_extra/Frontier_Form.res` only for the track path
  prefix (as `install_bend.gd` does), writes no `native_asset_id`, `source_attribution` or `original_name`, and sets an
  `authored` meta naming `style_boxing.py`, the clip's moments (`strike_s`, `hold_s`, `back_s`, `antic_s`, `follow_s`) and
  words (`hand`, `mask`, `root`, `style`, `element`, `move`, `mode`, `stills`).
- The clips are not wired into the game yet (animations only; no gameplay numbers). Stills:
  `tools/anim_author/style_preview.gd`.

## Fighting style clips: Capoeira for air (`animations_extra/Frontier_Style_Capoeira.res`)

Recorded 2026-10-09 from the generator code (observations, not an independent audit of the binary library). The second
fighting style (the owner chose it on 2026-10-09). No video was watched for these clips: the built-in browser pane could not
draw the videos (hidden, then the Mac restarted), so they are keyed from standard capoeira mechanics; only a catalogue's
chapter list was read (move names and times), Mestre Koioty, "60 movimentos de capoeira para Luta (51 Golpes e 9 esquivas)",
https://www.youtube.com/watch?v=hXyQk4LTlm8 (`docs/fighting_styles/capoeira_reference.md`).

| Clip | Added | Generator | Inputs | Visual references watched |
| --- | --- | --- | --- | --- |
| `own-style-capoeira-ginga` | 2026-10-09 | `tools/anim_author/blender/style_capoeira.py` (`ginga`, a loop) | the rig's rest pose; keys typed in the generator | none |
| `own-style-capoeira-meia-lua`, `-meia-lua-front` | 2026-10-09 | `style_capoeira.py` (`meia_lua`, `meia_lua_front`) | the rig's rest pose; keys typed in `CLIPS` | none |
| `own-style-capoeira-martelo` | 2026-10-09 | `style_capoeira.py` (`martelo`) | the rig's rest pose; keys typed in `CLIPS` | none |
| `own-style-capoeira-bencao` | 2026-10-09 | `style_capoeira.py` (`bencao`) | the rig's rest pose; keys typed in `CLIPS` | none |
| `own-style-capoeira-armada` | 2026-10-09 | `style_capoeira.py` (`armada`) | the rig's rest pose; keys typed in `CLIPS` | none |
| `own-style-capoeira-esquiva` | 2026-10-09 | `style_capoeira.py` (`esquiva`) | the rig's rest pose; keys typed in `CLIPS` | none |
| `own-style-capoeira-au` | 2026-10-09 | `style_capoeira.py` (`au`) | the rig's rest pose; keys typed in `CLIPS` | none |
| `own-style-capoeira-rasteira` | 2026-10-09 | `style_capoeira.py` (`rasteira`) | the rig's rest pose; keys typed in `CLIPS` | none |
| `own-style-capoeira-compasso` | 2026-10-09 | `style_capoeira.py` (`compasso`) | the rig's rest pose; keys typed in `CLIPS` | none |

- `style_capoeira.py` keys body and limb targets by hand in its `CLIPS` table and poses and bakes them with
  `tools/anim_author/blender/style_kit.py`: bend_clips.py's own solver (`pose()`, two-bone IK with `rigkit.ik2`) and
  `bake()`, imported, on the skeleton of `assets/character/actor_b_body.glb` in Blender, with the closed-hand finger table and
  thumb fold first made for the boxing clips (set on bend_clips for the bake only; bend_clips.py unchanged). Every clip
  starts and ends on the ginga's first frame, keyed from the rig's rest pose. It reads no library clip, no `dump_move.gd` /
  `dump_pose.gd` output and no `rigkit.Native` / `MirrorNative`; `fit_ref.gd` was not run. The armada and the compasso
  turn the figure with bend_clips' `spin` channel and the au with its `cart` channel and ground contact (the keys typed in
  the body's frame).
- `tools/anim_author/install_style.gd` installs them as for the boxing clips (above): the track path prefix from
  `own-form-release`, no `native_asset_id`, `source_attribution` or `original_name`, an `authored` meta naming the generator.
- Parked 2026-10-09: the owner played them ("the animations for the caporia looks whack") and chose to drop Capoeira for
  now; the library stays, mapped nowhere (not in `data/bending/style_poses.json`, not wired into the game).

## Elemental presentation polish (2026-10-08)

Direct generator changes: `tools/anim_author/blender/bend_clips.py` updates the
hips/torso turn keys on `earth_push`, `fire_punch` (and its generated mirrored
variant), `water_wave` and `air_sweep`. The keys are authored in that table and
baked from the same project rig rest pose. No Spellbreak motion file is read by
this authoring path. Timing metadata and runtime aliases remain unchanged.
The separate Spellbreak reference conversions retain their third-party origin
and stay outside the project animation libraries. See
`docs/animation_reference_lessons.md` for source observations, inferences,
conversion boundaries and validation.
Spellbreak licence (2026-10-08): Proletariat licensed all Spellbreak assets for use in Tidebreak, including public release. Written grant: [where you keep it].

## Fighting style clips: Taekwondo for air (`animations_extra/Frontier_Style_Taekwondo.res`)

Recorded 2026-10-16 from the generator code (observations, not an independent audit of the binary library). Air's fighting
style (docs/fighting_styles_design.md; the owner, 2026-10-16, picked Taekwondo next). Its kicks are NOT in this library: they
are the Motifect pack's Taekwondo clips, cut and retargeted (`motifect-tkd-*` in `Frontier_Motifect.res`, the Motifect section
below). This library holds only the standing clips the pack has no motion for (the stance, the knee guard and its hold, the three skip steps of the Shift movement), keyed by hand like Boxing's. No video was
watched for them: a sparring stance and a lifted-knee guard are plain standing poses, keyed from standard Taekwondo sparring
mechanics (the kyorugi stance); the acrobatics the Capoeira lesson warned about (2026-10-09) are left to the pack's real motion.

| Clip | Added | Generator | Inputs | Visual references watched |
| --- | --- | --- | --- | --- |
| `own-style-taekwondo-stance` | 2026-10-16 | `tools/anim_author/blender/style_taekwondo.py` (`stance`, a loop typed as a function, `stance_at`) | the rig's rest pose; keys typed in the generator | none |
| `own-style-taekwondo-knee-guard` | 2026-10-16 | `style_taekwondo.py` (`knee_guard`, the Wind Guard) | the rig's rest pose; keys typed in `CLIPS` | none |
| `own-style-taekwondo-knee-hold` | 2026-10-16 | `style_taekwondo.py` (`knee_hold`, the guard held, a loop) | the rig's rest pose; keys typed in the generator | none |
| `own-style-taekwondo-skip`, `-skip-back`, `-skip-side` | 2026-10-16 | `style_taekwondo.py` (`skip`, `skip_back`, `skip_side`: the Shift movement, air's Slip) | the rig's rest pose; keys typed in `CLIPS` | none |

- `style_taekwondo.py` keys its poses in bend_clips.py's channels and poses and bakes them through `style_kit.py` (the
  shared kit of the style generators: bend_clips.py's own solver and bake, imported; the closed-fist curl and thumb fold of
  the Boxing clips, here at grip 0.85 for the stance's loose fists) on the skeleton of `assets/character/actor_b_body.glb`
  in Blender. It reads no library clip, no `dump_move.gd` / `dump_pose.gd` output, no `rigkit.Native` / `MirrorNative` and
  nothing from the Motifect pack. Every clip starts and ends on the sparring stance, the stance loop's first frame, keyed
  from the rig's rest pose. No mirrored twins (the stance leads left, as the pack's kicks do).
- `tools/anim_author/install_style.gd` installs them as the Boxing clips (the track path prefix from `own-form-release` in
  `Frontier_Form.res`; no `native_asset_id`, `source_attribution` or `original_name`; an `authored` meta naming the
  generator; the stance and the hold looping).
- The game plays them only for a body wearing the Taekwondo style (`data/bending/style_poses.json` "taekwondo";
  `data/bending/loadout_apply.json` `styles_live`; `BendPoses.stance_pose`, `guard_hold_pose`, `_style_pick`), each cast
  timed as air's own clip for that move (`_timed_as`: the move's gameplay unchanged); every other airbender plays air's own.

## Fighting style clips: Muay Thai for fire (`animations_extra/Frontier_Style_Muay_thai.res`)

Recorded 2026-10-16 from the generator code (observations, not an independent audit of the binary library). Fire's second
fighting style (after Boxing). Its strikes are NOT in this library: they are the Motifect pack's Muay Thai clips, cut and
retargeted (`motifect-mt-*` in `Frontier_Motifect.res`, the Motifect section below). This library holds the standing clips
the pack has no motion for: the stance, the cross (key 1's Punch) and the three step-and-slide steps of the Shift movement,
keyed by hand like Boxing's. No video was watched: a guard, a straight punch and a step are plain standing motions, keyed
from standard Muay Thai mechanics.

| Clip | Added | Generator | Inputs | Visual references watched |
| --- | --- | --- | --- | --- |
| `own-style-muay-thai-stance` | 2026-10-16 | `tools/anim_author/blender/style_muay_thai.py` (`stance`, a loop typed as a function, `stance_at`) | the rig's rest pose; keys typed in the generator | none |
| `own-style-muay-thai-cross` | 2026-10-16 | `style_muay_thai.py` (`cross`, the Punch) | the rig's rest pose; keys typed in `CLIPS` | none |
| `own-style-muay-thai-step-in`, `-step-back`, `-step-side` | 2026-10-16 | `style_muay_thai.py` (`step_in`, `step_back`, `step_side`: the Shift movement, fire's Step) | the rig's rest pose; keys typed in `CLIPS` | none |

- Made and installed as the Taekwondo clips above (`style_kit.py`, `install_style.gd`), and played only for a body wearing
  the Muay Thai style (`data/bending/style_poses.json` "muay_thai", `loadout_apply.json` `styles_live`), each cast timed as
  fire's own clip for that move. `style_kit.game_name` now dashes a two-word style's name (`own-style-muay-thai-...`), as
  `BendPoses._style_library_of` looks it up.

## Motifect-derived clips (`animations_extra/Frontier_Motifect.res`)

Recorded 2026-10-12 from the generator code (observations, not an independent audit of the library). These are NOT our own
key-posed clips: their motion comes from the Motifect martial arts pack (Motifect AI, motifect.io: 40 AI-generated clips as BVH
and FBX; its README: "Free for personal and commercial use in your projects. Do not redistribute or resell these raw animation
files as a standalone product."). The owner found the pack (`~/Downloads/Motifect_martial_arts_v1_0`) and chose to take moves from
it into the game's clips (2026-10-12: "we can take some moves and then add it into our own", then "do and add what u can so we can
see what it looks like"). The pack's files are not copied into the project: the generator reads the BVH files from that folder,
as text, when it bakes.

| Clip | Made | Generator | Input (the pack's clip, its frames) | Edits on top of the retarget |
| --- | --- | --- | --- | --- |
| `motifect-fire-kick-low` | 2026-10-12 | `tools/anim_author/blender/motifect_clips.py` (`fire_kick_low`) | `muay_thai_roundhouse.bvh` f56-106 | the kicking (right) leg swung down about its hip so the ankle is at most 0.34 m over the deck through the kick (in over f68-73, out over f84-94): a leg kick, so the Kick's tell stays low |
| `motifect-fire-kick-low-l` | 2026-10-12 | the same (`mirror`) | the same, mirrored left for right before the retarget | as its original, on the left leg |
| `motifect-fire-kick-high` | 2026-10-12 | `motifect_clips.py` (`fire_kick_high`) | `tkd_roundhouse_high.bvh` f12-56 | none |
| `motifect-fire-kick-high-l` | 2026-10-12 | the same (`mirror`) | the same, mirrored | none |
| `motifect-fire-teep` | 2026-10-12 | `motifect_clips.py` (`fire_teep`) | `muay_thai_teep.bvh` f2-52 | the kicking leg's ankle at most 0.78 m (in over f19-23, out over f31-38): a push kick to the belly |
| `motifect-fire-teep-l` | 2026-10-12 | the same (`mirror`) | the same, mirrored | as its original, on the left leg |
| `motifect-air-jump-spin-kick` | 2026-10-12 | `motifect_clips.py` (`air_jump_spin_kick`) | `tkd_jump_spinning_kick.bvh` f34-72 (cut before its landing) | its lift off the deck taken off from its takeoff (f54: the game's jump carries the body); its heading made a whole turn by f72 (the turn short of it spread over f46-72) |
| `motifect-tkd-snap-kick` | 2026-10-16 | `motifect_clips.py` (`tkd_snap_kick`; Taekwondo's Palm, `data/bending/style_poses.json`) | `tkd_front_kick_high.bvh` f4-34 | none |
| `motifect-tkd-snap-kick-l` | 2026-10-16 | the same (`mirror`) | the same, mirrored | none |
| `motifect-tkd-jump-kick` | 2026-10-16 | `motifect_clips.py` (`tkd_jump_kick`; Taekwondo's Pop) | `tkd_jump_front_kick.bvh` f30-58 (from the push-off to the landing) | held in place (`pin`: the pack's run-up travel taken off every frame, its jump kept) |
| `motifect-tkd-jump-kick-l` | 2026-10-16 | the same (`mirror`) | the same, mirrored | as its original |
| `motifect-tkd-side-kick` | 2026-10-16 | `motifect_clips.py` (`tkd_side_kick`; Taekwondo's Slice) | `tkd_side_kick.bvh` f8-48 | none |
| `motifect-tkd-side-kick-l` | 2026-10-16 | the same (`mirror`) | the same, mirrored | none |
| `motifect-tkd-heel-kick` | 2026-10-16 | `motifect_clips.py` (`tkd_heel_kick`; Taekwondo's Gust) | `tkd_spinning_heel_kick.bvh` f34-78 (the turn, the kick, the foot set down) | held in place (`pin`: the step-through's travel taken off) |
| `motifect-tkd-axe-kick` | 2026-10-16 | `motifect_clips.py` (`tkd_axe_kick`; Taekwondo's Slam) | `tkd_axe_kick.bvh` f24-56 | its lift off the deck taken off and held in place from f24 (`air`: the game's jump carries the body) |
| `motifect-mt-elbow` | 2026-10-16 | `motifect_clips.py` (`mt_elbow`; Muay Thai's jab string, `style_poses.json`) | `muay_thai_elbow_cut.bvh` f2-34 | none |
| `motifect-mt-elbow-l` | 2026-10-16 | the same (`mirror`) | the same, mirrored | none |
| `motifect-mt-knee` | 2026-10-16 | `motifect_clips.py` (`mt_knee`; Muay Thai's Pop) | `muay_thai_knee_clinch.bvh` f18-56 | the left leg swung up about its hip and forward so its ankle is at least 0.52 m over the deck (`lift`, in over f27-31, out over f36-44): the pack's knee barely leaves the deck |
| `motifect-mt-body-kick` | 2026-10-16 | `motifect_clips.py` (`mt_body_kick`; Muay Thai's Kick) | `muay_thai_body_kick.bvh` f8-52 | none |
| `motifect-mt-body-kick-l` | 2026-10-16 | the same (`mirror`) | the same, mirrored | none |
| `motifect-mt-teep` | 2026-10-16 | `motifect_clips.py` (`mt_teep`; Muay Thai's Kick held) | `muay_thai_teep.bvh` f2-52 | none (fire's own `motifect-fire-teep` is this cut capped to the belly) |
| `motifect-mt-teep-l` | 2026-10-16 | the same (`mirror`) | the same, mirrored | none |
| `motifect-mt-round-high` | 2026-10-16 | `motifect_clips.py` (`mt_round_high`; Muay Thai's High Kick) | `muay_thai_roundhouse.bvh` f56-106 | none (fire's own `motifect-fire-kick-low` is this cut capped to the shin) |
| `motifect-mt-round-high-l` | 2026-10-16 | the same (`mirror`) | the same, mirrored | none |
| `motifect-mt-check` | 2026-10-16 | `motifect_clips.py` (`mt_check`; Muay Thai's Parry) | `muay_thai_push_kick_defense.bvh` f0-30 | none |

- The retarget, per frame: the BVH's global joint rotations (its rest is a T-pose, every joint unrotated) carried onto
  Actor_B's bones (`assets/character/actor_b_body.glb`, `rigkit.SK`) through each mapped bone's rest frame (our rest bone's
  direction and a second axis turned onto the BVH rest's: the left, the forward, the hip line or the knuckles' line), so a bone
  points where the BVH's points and twists as it twists; `spinec` half way between its neighbours; the bones the BVH has no
  match for (the bases, the pelvis, the palms, the heels) keep our rest under their parents. The fingers are our own closed fist
  (`style_kit.py`'s boxing hands at grip 1, the boxing clips' input), not the BVH's. The root's place is the BVH hips' scaled by
  the legs' lengths, the whole clip set down so its first frame's feet stand on the deck as our rest's do, and its drift across
  the deck taken back by its end. Mirrored twins are the BVH mirrored left for right before the retarget.
- `tools/anim_author/install_motifect.gd` installs them as `install_bend.gd` installs ours (the track path prefix from
  `own-form-release` in `Frontier_Form.res`, no `native_asset_id`, `source_attribution` or `original_name`), each with an
  `authored` meta naming the generator and a `source` meta naming the pack's clip and frames, so the library itself says what
  each clip was made from.
- The game plays one only as `data/bending/poses.json` lists it by name in `motifect` (`BendPoses.motifect`, `usable`):
  fire's Kick and its twin, the Kick held long (its `grow`: the teep), the High Kick and its twin, air's Leap. The `motifect-tkd-*` and `motifect-mt-*` clips (2026-10-16) are listed there too but played only through `data/bending/style_poses.json` for a body wearing the Taekwondo (air's) or Muay Thai (fire's) style (`BendPoses._style_pick`), never by the element's own poses. Each is timed as
  the move's own clip it replaces (`timed_as`: its hold, strike, back and end exactly the old ones, so the move's gameplay is
  unchanged) and that own clip stands in when the library is missing.
