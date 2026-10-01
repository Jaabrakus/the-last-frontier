# Animation provenance: authorship and input lineage

Review date: 2026-10-01. This is a source-code review, not a determination of
copyright ownership or a complete audit of the binary animation libraries.
The project owner states that they made the animations using AI, Blender, and
YouTube videos. The owner clarified that the videos were watched as tutorials,
animation examples, and visual references; animation files were not imported
from those videos. The specific AI tools, Blender authoring files, and video
links have not yet been recorded. This statement describes the reported
workflow; it does not establish the lineage of every bundled clip.

The records below identify what the generators do so that inherited labels can
be interpreted accurately alongside that statement.

The owner's workflow is also recorded in `animations/SOURCE.md`. Future reviews
should consult it alongside the specific clip's inputs.

## Interpreting the previously raised concerns

| Concern | Supported finding |
| --- | --- |
| Optional `ANIMATION_SOURCE_ROOT` | Offline exporters need a separately configured input tree. Its existence and directory names do not establish who created its contents. |
| `native_asset_id` and hexadecimal graph records | IDs and record keys are used for identity and resolution. `tests/source_checks/test_export.py` checks clip IDs against a 64-character hexadecimal hash format; `tools/retarget/climb_from_c.py` populates one such field from `sha256`. These fields alone do not identify another product. |
| Copied tags on newly baked clips | The traversal installer explicitly copies source tags while writing rotations from baked frames. An inherited label is not a complete description of output authorship; trace the baked inputs. Other generators do reuse input motion. |
| Release field stripping | The documented export policy minimizes selected metadata in export copies. That behavior alone does not establish the origin of the motion or unauthorized use. |
| Missing animation licence entry | The former path-only documentation did not record the owner's account. `animations/SOURCE.md` now records it. The absence of a licence entry alone does not establish third-party origin; actual third-party inputs still require their own records. |
| AGLS/IWALS PDF in Downloads | The PDF's presence does not establish a dependency. A relationship requires evidence tied to a particular input, asset, or generator. |
| Historical origin wording | Generic origin wording in comments and documentation was replaced with descriptions of the bundled clips, input graph, measurements, and runtime assumptions at the owner's request. A specific commercial-origin statement in `tests/anim/lib/rig_fixture.gd` remains pending clarification. These edits do not verify the base libraries' origin. |

A supported interim review can state: "The owner reports creating motion with AI
assistance and Blender using watched tutorials and visual references. Some
generators retain input identifiers and some reuse input motion. The lineage of
the base libraries has not yet been independently verified. The listed markers
alone do not establish theft or identify a commercial source."

## What the current records establish

| Generator or record | Observed behavior | Meaning for the audit |
| --- | --- | --- |
| `tools/anim_author/blender/install_traversal.gd`, `_part` | Creates a new animation, writes rotations from baked frames, uses the source part's length and track paths, subtracts sequence alignment from root positions, and copies `native_asset_id`, `source_attribution`, and `original_name` from the source clip. Adds an `authored` description. | The copied ID identifies an input or association; it is not by itself evidence that the output rotation keys were copied. The baked frames and their authoring inputs still need tracing. |
| `tools/anim_author/author_locomotion.gd`, header and `_stamp` | Describes retiming and blending sprint and jog motion from `animations/Actor_B.res`; copies input IDs and attribution onto output clips. | Project modifications and input motion should both be recorded. An output named `own-*` does not establish that every input was independently authored. |
| `scripts/player/anim/tree_builder.gd` | Preserves source metadata when composing animation clips. | Composition metadata records lineage; it does not establish the original creator or permission. |
| `tools/anim_author/author_reload.gd`, `_bake_step` | Labels output as project key poses and sets a source description. | This is an authoring claim in the generator; inspect its pose data and upstream inputs when documenting individual clips. |
| `tools/animation_sources.md` | Specifies optional external inputs for offline rebuilding. | A filesystem layout is not an authorship or licence record. |
| `addons/release_metadata/README.md` | Says release customization leaves development resources intact and does not establish ownership or permission. | Release metadata minimization and provenance documentation are separate concerns. |

## Accurate corrections

For each library or clip family, record the creator, creation method, authoring
files, upstream inputs, and any applicable permission evidence. Retain source
files and development history as supporting records.

When an inherited ID labels an association rather than the output's identity,
record it explicitly as an input reference and give the output its own identity.
Keep actual input attribution alongside the project's authored contributions.
Do not remove functional aliases such as `original_name` without checking their
runtime consumers.

Correct inaccurate statements with a documented correction. Neither the mere
presence of an ID nor its removal resolves authorship. Do not infer a particular
commercial source from a hexadecimal identifier or from a licence PDF elsewhere
on disk.

## Still to establish

- The AI tools and retained scripts or outputs used in authoring, the Blender
  source files, and the YouTube tutorial/reference links.
- The original authoring inputs and creation method for `animations/Actor_B.res`.
- The inputs behind the Actor_A/Actor_C retargeted libraries.
- The lineage of traversal baked frames and reload/weapon pose data.
- Which inherited fields describe real inputs and which are stale associations.

The wording cleanup changes comments, documentation, a diagnostic message, and
descriptive JSON strings. It preserves motion, runtime mappings, animation
attribution fields, and Git history. Executable GDScript lines were checked
against snapshots at the time of each comment edit. Subsequent concurrent reload
authoring changes were left intact.

Validation: `git diff --check` passed. Source-independent tests ran 45 cases: two
passed and 43 skipped because external rebuild inputs were unavailable. Godot
4.7.2 Mono completed headless editor import without reported GDScript parse
errors; the sandbox denied its IDE socket and editor-settings write.
