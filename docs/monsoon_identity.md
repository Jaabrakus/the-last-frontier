# Tidebreak elemental identity — first implementation pass

2026-10-08. This pass uses the existing project garment meshes, with new colour
overrides in `data/npc/factions.json`. It is a costume colour and release-effect
pass, not a replacement of the underlying character models or garment cuts.

| Element | Costume direction | Authored release shape |
| --- | --- | --- |
| Stone | Jade cloth, dark green wraps, brass trim | Three stepped peaks |
| Tide | Deep teal, navy, pearl trim | Three offset waves |
| Ember | Charcoal, copper and warm rust | Split seven-ray sun |
| Gale | Pale lilac, indigo and ivory | Four open turning vanes |

`scripts/bending/monsoon_identity.gd` generates the four marks from mathematical
paths. It reads only the local identity configuration. No Spellbreak clip,
texture, character mesh, particle package or Unreal graph is an input to this
new generator. This describes the new marks and colour edits, not a blanket
ownership review of existing assets. See `animations/SOURCE.md` and
`docs/animation_provenance.md` for the existing animation records.

`BendEffects._apply` triggers the mark at the existing spell effect release;
it does not add a windup, alter hitboxes, damage, aiming or movement. Marks sit
at the caster's feet, also during airborne casts. They last 0.22 seconds, or
0.32 seconds for grown/big casts, expand and fade. Shapes differ as well as
colours. Mirror matches retain separate away costumes. Ember's away costume is
now warm ivory to distinguish it from the charcoal home outfit. Home plate
colours follow the revised costume accents in `data/ring/sides.json`.

The existing ToonFxPool caps each mark mesh at twelve instances and reuses them.
The shared shader respects the existing camera fade and lighting gain. The
loading warm-up includes all four marks to prepare their rendering pipeline.
The generator consumes no gameplay RNG and adds no colliders or movement owners.

## Validation

- Godot 4.7.2: 873 scripts compiled, zero bad, including the warm-up addition.
- Cosmetic boundary regression: gameplay RNG unchanged; 48-instance total cap;
  no gameplay nodes/colliders; all marks expire; later releases reuse nodes.
- R4 effects regression: 43 checks passed.
- Ring sides regression: 22 checks passed.
- Bend Cast integration regression passed.
- R3 Air: all 82 checks passed with `--fixed-fps 60`; the isolated landing-lag
  group also passed all seven checks with that setting before this art pass.
- Rendered front and three-quarter views of both body fits, plus early/middle/late
  shader snapshots in `artifacts/monsoon_identity`, inspected in the desktop app.

These checks do not establish frame-time performance on other hardware or the
25-metre rendered home/away colour-distance metric. That metric should be
remeasured before final art approval. The earlier R3 Air suite's hit-discount
failure occurred in an unrestricted-frame run and was reproduced before this
art pass. Fixed-frame runs now pass, which points to a timing-sensitive test
condition; this is not evidence that this art pass fixed a gameplay bug.

Geometry uses Godot's [SurfaceTool](https://docs.godotengine.org/en/stable/classes/class_surfacetool.html)
contract: vertex attributes are set before vertices. Runtime effects reuse the
project's existing pool and shader instance parameters.
