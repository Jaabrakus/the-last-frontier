# FX continuation handoff — 2026-10-08

## Owner's requested outcome and authorization

The owner asked: “please do that extract and make them one for one after that
merge them also give claude permission to use this as well we are about to
switch over”. This authorizes Claude to continue local extraction, conversion,
Godot reconstruction, testing and integration/merge after validation. No repeat
confirmation of this task scope is necessary. This is the owner's project task
authorization, not a licence from a third-party rights holder or a change to
Claude's sandbox settings. Source attribution remains accurate.

## Current state

The requested one-to-one rebuild and subsequent merge are NOT complete.
The working checkout is already on `main`; no new commit, merge or push was
performed in this pass. Preserve the unrelated local animation, gameplay,
costume and documentation changes visible in `git status`.

`/Users/kiwimango/Downloads/Frontier/artifacts/spell_fx_lab/project.godot`
is a working four-element approximation. Its 40 lifecycle/reuse checks passed
and a normal-speed 60 FPS movie was visually reviewed. The user rejected its
visual similarity to Spellbreak. Do not treat it as an accepted conversion.

The new source-first extraction is at:
`/Users/kiwimango/Downloads/Frontier/artifacts/spell_fx_source_fireball/`.
It contains the dependency closure of these two source packages:

- `g3/Content/VFX/Character/Fire/Fireball_Base_Projectile01_FxP`
- `g3/Content/VFX/Character/Fire/Fireball_Base_Impact01_FxP`

91 packages / 216 cooked files were extracted and hash-verified. All 91 decoded
with zero reported errors and zero RawExport fallbacks. There are no unresolved
package imports in the traversed `/Game/` and `/Engine/` dependency closure.
Script classes remain engine dependencies; a complete package closure does not
mean complete runtime behavior.

`recipes/` preserves every decoded export and import as well as explicit
emitter -> LOD -> required/spawn/type/modules relationships. Missing properties
remain unknown/inherited, not silently set to zero. The projectile emitters in
source array order are Head Mesh, Core Flames, FlameTrail and Center Wisp.
The impact has nine emitters: Hotball, Range Sphere, shockwave_ring, FlameBits,
Big Glow, bACKINGSMOKE, Sparks Omni shard, light, and Hotball sphere.

The actual projectile head mesh is `SM_EnergyMeshB`, not the prototype's sphere.
Its materials include `Fireball_Head01_FxMI`, `Fireball_CoreFlames01_FxMI`,
`FireballProjectile_Trail01_FxMI` and `MI_f_Particle_ArcAtlas`. Follow their Parent
chains and texture overrides. The wisps specify a 2×3 atlas and core flames a
2×2 atlas; the old prototype's generic 4×4 flame sheet is not a source-faithful
substitute.

## Unresolved technical work

1. Recover/inspect material graph input wiring before implementing shaders.
   The UAssetAPI JSON exposes material parameters, texture references, some
   expression exports and native Extras; it does not currently expose enough
   verified topology to claim equivalent shader evaluation. Inspect
   `M_f_FireBeam.json` and `PowerSurge_Glow01_FxM.json` in the new decoded tree.
   Do not conclude that wiring is irrecoverably stripped just from JSON:
   UAssetAPI's `MaterialInputPropertyData<T>` reads Expression/ExpressionName,
   masks and OutputIndex but those fields were absent from the inspected JSON.
   Next step: explicitly dump those parsed fields from the C# reader and compare
   to the native source payload. Some function-call exports also lack input
   connections in the JSON representation; investigate serialization.
2. Port each active LOD0 emitter with the actual source distributions, including
   local/world space, mesh orientation, spawn-per-distance, ribbon behavior,
   lifetime, per-axis size, colour/alpha, rotation, sub-UV and dynamic material
   parameters. Keep disabled modules disabled. Convert UE units and axes
   explicitly; do not normalize every source mesh to the old prototype size.
3. Establish inherited UE4.22 defaults and game-driven parameters; decoded
   ParticleSystem assets alone do not establish projectile speed or gameplay
   event timing.
4. Obtain source-game footage or an executable reference capture and compare
   projectile flight and impact at matched camera, scale, lighting and timing.
   The local supplied client is Windows; no source-game execution or matching
   source footage was available in this pass. An optional question asking the
   owner for the target effect / footage was sent; fireball was the default.
5. Verify Godot 4.7.2 imports, lifecycle/performance and actual rendered output.
   Integrate through existing bending FX owners only after parity is evaluated.
   Preserve movement, combat timing, targeting and networking authority. Merge
   validated work as requested; don't merge the rejected approximation merely
   to mark the task done. Videos remain local, per the owner's earlier request.

## Tools and reproduction

- `/Applications/Godot_mono.app/Contents/MacOS/Godot` (4.7.2, Metal mobile tested).
- `tools/reference_animation/extract_fx_dependencies.py`: checked pak extraction,
  recursive package dependency decode. Run `--help` for arguments.
- `tools/reference_animation/build_fx_recipe.py`: lossless source export retention
  and resolved emitter/LOD descriptions.
- Pak index: `/private/tmp/spellbreak-animation-study/pak_entries.json`.
- Reader: `/private/tmp/spellbreak-animation-study/TreeReader/bin/Release/net8.0/TreeReader.dll`.
- Reader source: `/private/tmp/spellbreak-animation-study/TreeReader/Program.cs`.
- UAssetAPI source: `/private/tmp/spellbreak-animation-study/UAssetAPI/UAssetAPI/PropertyTypes/Structs/Engine/MaterialInputProperties.cs`.
- Patched UE Viewer: `/private/tmp/spellbreak-animation-study/UEViewer/umodel`.
  Always pass absolute `-path=` and `-out=` paths; relative export output is
  resolved against the home directory by this tool.
- Source archive: `/Users/kiwimango/Downloads/spellbreak-community-version-client-windows/g3/Content/Paks/g3-WindowsNoEditor.pak`.
- Earlier full particle catalogue (853): `/Users/kiwimango/Downloads/Frontier/Spellbreak_Reference_Extracts/particle_reference/`.
- Earlier animation conversion (1188) and viewer: `/Users/kiwimango/Downloads/Frontier/Spellbreak_Reference_Extracts/godot/`.

The new extraction and the old lab are under ignored `artifacts/` and stay local.
Tracked scripts and this handoff are suitable for preserving the workflow without
committing the cooked archive, generated video or caches.

## Source folder retirement / full backup

The owner subsequently requested preserving as much as possible so the Windows
client folder can be deleted. A lossless full-client ZIP was completed and verified at:
`/Users/kiwimango/Downloads/Frontier/Spellbreak_Reference_Extracts/source_backup/spellbreak-client-source.zip`.
Only a finished `.zip` accompanied by `manifest.json` with `verified: true`
counts as a verified backup; `.zip.partial` does not. Check that marker before
relying on it. The backup retains the full asset pak and client binaries, not
just the already-converted subset. This preserves the option of running the
Windows client later in a suitable environment.

Restoration tooling: `tools/reference_animation/restore_client_backup.py`.
Pass the ZIP path and a new destination directory. Add `--pak-only` to recover
only `g3/Content/Paks/g3-WindowsNoEditor.pak` for extraction. The source archive
is roughly 22 GiB uncompressed, so check free space before restoring it. Full
restore also retains all original relative paths and file contents; the ZIP
stores timestamps/modes and the manifest records those source attributes.

The extraction index, patched UE Viewer executable, compiled TreeReader and
reader source were copied and hash-checked into
`/Users/kiwimango/Downloads/Frontier/artifacts/reference_toolkit/` (16 files).
Use these durable copies rather than depending on `/private/tmp` surviving.
The compiled reader requires .NET 8; UE Viewer requires Rosetta on this Mac.
The reader project source still refers to the original UAssetAPI checkout for
rebuilding, but the copied binaries include its runtime DLL.

Backup result: all 1,350 source files verified by decompression and SHA-256.
Source: 22.94 GiB; backup: 10.34 GiB. The original client folder can now be
deleted without losing its file contents. Keep `Spellbreak_Reference_Extracts`,
including `source_backup`, and the Frontier artifacts/toolkit. No source folder
was deleted by the agent. Final source file-set, sizes and modification times
were rechecked against the manifest after archive verification.
