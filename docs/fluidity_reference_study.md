# Motion and particle reference study — 2026-10-08

## Implemented motion correction

`TreeBuilder._build_single` now plays `actor_b-p-fall` once and holds its last
pose until locomotion chooses another state. It retains the normalized timeline,
movement authority and upper-body cast layers. The runtime record reports the
same non-looping behavior. The source animation resource is unchanged.

The graph name resolves through `data/anim_author/locomotion_clips.json` to
`frontier_locomotion/own-arms-fall`. The graph's older seam metric was 0.92 rad;
the actual runtime override measured 0.729885 rad (about 42 degrees) across a
wrap. These are different measurements of different resources. The new regression
loads the actual override library and fails if the clip is missing, rather than
silently testing a fallback pose. With sustained playback, maximum measured
rotation drift after settling is 0.000691 rad (quaternion precision noise), and
position drift is zero over two additional normalized cycles.

This is a playback change, not new animation authorship. Existing motion-input
records remain in `animations/SOURCE.md` and `docs/animation_provenance.md`.

## Extracted reference data

Separate reference folder:
`/Users/kiwimango/Downloads/Spellbreak_Reference_Extracts/particle_reference`.
Open `index.html` for a searchable browser and links to the decoded records.

- 853 ParticleSystem packages, 1,706 files, about 63 MiB cooked.
- All bytes verified against archive SHA-1 and reread SHA-256.
- All 853 decoded through the existing UE4.22 UAssetAPI reader; no decoder errors
  or RawExport fallbacks. This does not prove native runtime equivalence.
- The new catalogue preserves module classes, explicitly serialized property
  names and material references; raw JSON preserves values and references.
- Examples include colour/alpha over life, size over life, lifetime, spawning by
  distance, mesh particles, ribbons, beam source/target and collision modules.
  Export counts include LOD/module copies, not simultaneously active instances.
- Referenced material/texture payloads have not been ported, and these cooked
  definitions do not run as Godot particle systems. Their original attribution
  and evidence stay in the separate reference directory.

The complete archive inventory additionally lists 922 Material, 3,997
MaterialInstanceConstant and 7,971 Texture2D packages. These are counts of
available records, not a claim of extracted or converted Godot assets. The
1,188 skeletal animation sequences were already converted in the earlier pass.

## Practical lessons and validation

The particle records support studying the separate envelope of spawn, size,
colour, opacity and lifetime, plus distance-based trails. They do not establish
effective spell timing or combat balance. Tidebreak already has separate impact
bursts and distance-aware ribbon sampling (`ToonRibbon._process`). The immediate
verified motion issue was repeated fall entry, so this pass fixes that rather
than adding more overlapping effects.

Validation: 875 scripts compiled; sustained-fall regression passed; 12/12 ring
pose transitions, 82 airborne casting checks at fixed 60 FPS, 30/30 cast-pose
handoffs, and the spell-combination Flow suite passed. Rendered before/after
comparison uses the actual dressed rig and runtime fall override at normal clip
speed. Headless integration tests also emit existing exit-time resource warnings.

Godot's [AnimationNodeAnimation custom timeline](https://docs.godotengine.org/en/stable/classes/class_animationnodeanimation.html)
provides the loop override. The implementation uses the installed Godot 4.7.2
API and preserves the existing normalized time scaling.
