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
