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
