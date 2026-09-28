# Release animation metadata

This editor plugin is enabled in `project.godot`. Godot calls it during release exports,
including release PCK/ZIP exports. It works on export copies; the editor, play sessions and
debug exports use the original animation resources and tables.

The explicit policy in `policy.gd` removes optional tracking/authoring fields from exported
`Animation` and `AnimationLibrary` resources, selected animation JSON tables, and the
character skeleton's bind-rest tracking ID. It preserves clip names, all animation tracks,
keys, interpolation settings, looping, additive flags, sampling rates, graph IDs, JSON
alias names, transitions and the functional bind-rest stamp. It does not alter gameplay code.

Scope of JSON processing: `animations/*.json`, `data/traversal/*.json`,
`data/loadout/*.json` and `data/climb/*.json`. JSON aliases such as `original_name` and
`source_names` remain because `AnimGraphData` uses them to resolve clips. Other JSON and
credit/license files are unaffected. Free-text descriptions, script comments, filenames,
and every occurrence of a source name are not rewritten by this policy.

## Exporting

Use a normal Godot release export preset with this plugin enabled. Keep the runtime JSON
files and `CREDITS.md` in the preset's non-resource include filter. Exclude development
tools, tests, reports and authoring manifests from distributable packages as appropriate
for the target preset. No platform preset existed when this plugin was added; the plugin
is independent of which target is selected later.

In the Export dialog, turn off **Export With Debug**, or use:

```sh
Godot --headless --path . --export-release "Your preset" /absolute/path/to/output
```

Export customization is cached by Godot. The plugin's configuration hash incorporates
the policy and exporter source so changes to either invalidate the customized resources.
The export log reports processed resources/tables; a cached export can process zero resources.

Godot reserializes customized resources into its export cache. In the isolated test on
Godot 4.7.1, the release PCK was 288 MiB versus 93 MiB for the unchanged debug PCK. Budget
for larger uncompressed packages; the motion data was identical. A complete game/platform
build was not produced because this project has no target export preset yet.

This is metadata minimization. The exported game must contain the motion needed for
playback, so the plugin does not prevent extraction, reconstruction, recognition or AI
analysis of that motion. It does not establish asset ownership or permission. Keep
development provenance/permission records and satisfy the credits specified by those permissions.

## Verification

```sh
Godot --headless --path . -s tests/export/test_release_metadata.gd
python3 tests/export/test_export_pack.py --godot /absolute/path/to/standard/Godot
```

The first test checks all five current character libraries, exact stored motion after
serialization/reloading, source-file hashes, alias resolution, graph validation, tree
construction, and early/middle/late skeleton poses (including all eight custom axe clips).
It writes temporary resource copies to `/tmp/frontier-release-check` by default.

The second test creates a separate temporary project with the actual libraries, actor
scene and graph tables. It exports and runs release, debug, and cached release packs,
checks metadata at the package boundary, compares all motion data and a skeleton
pose evaluation, and verifies that the development files retain their original hashes.
It checks that unrelated JSON and a fixture credits file remain present. Output/logs
are retained in the printed temporary directory. On macOS, use the standard, non-Mono
Godot executable: the test copies and ad-hoc signs it in that directory, then uses
self-contained mode to keep editor settings separate from the working project.

API reference: [Godot EditorExportPlugin](https://docs.godotengine.org/en/latest/classes/class_editorexportplugin.html).
The callback signatures were also checked against the installed Godot 4.7.2 engine API.

Verified: Godot 4.7.2 passed 39,054 resource/graph/playback checks covering 2,798 clips and
63 sampled poses. Godot 4.7.1 passed the real-asset release/debug/cached-pack checks, including
all motion data, 366 graph aliases, retained debug metadata, credits and source-file hashes.
