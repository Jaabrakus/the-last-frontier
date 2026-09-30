# Frontier Legacy animation preview

Worktree: `/Users/kiwimango/Downloads/Frontier_wt/agls-comparison`  
Branch: `codex/agls-comparison`  
Integrated main commit: `bff5ffcbae7098c72b40ebef0995bfb542797565`.

Open `launch-frontier-legacy.command` from the worktree root. The viewer starts on crouch walking with four columns: **Frontier Old**, **Frontier Updated**, **Frontier Blend**, **AGLS Retargeted**. Updated uses a frozen copy of main's current locomotion selection, rather than the old clips. Actions that main has not changed have the same reference in both columns.

Choose an action in the first dropdown. The second dropdown selects the approved blend, Grounded, Athletic, or the earlier AGLS base with Frontier upper body. Space pauses, R restarts, 1–6 select walk/run/sprint/jump/vault, right drag orbits, and the wheel zooms. “Align phases” compares body shapes on a common cycle; leave it off to see each clip's actual timing. Horizontal travel stays in separate lanes by default.

## Resources

- `Frontier_Legacy.res`: 33 approved comparison clips, each also saved independently under `clips/`.
- `Grounded/` and `Athletic/`: 33 resources each. Sixteen movement/jump/vault clips have authored timing and posture changes. Weapon and climbing contacts retain the approved preview until separately tuned.
- `Frontier_Legacy_Weapons.res` and `weapons/`: 72 graph-baked weapon poses: nine standing locomotion actions for six weapons, standing/crouched carry idles, and standing/crouched aim idles for bow, musket and pistol.
- `blend_settings.json` and `style_settings.json`: editable authoring parameters.
- `clip_manifest.json`, the style manifests, and `weapon_manifest.json`: action mapping, durations, weights and source records.

The comparison includes 16 standing movement/jump/vault and crouch actions, nine bow/rifle actions, and eight mantle/ladder/ledge actions (33 total). Four crouch directions and all bow/rifle clips come from the supplied AGLS FK animation data. Frontier weapon references sample the actual weapon graph, including aim elevation, bow draw, release and holster. The complete Frontier ladder top exit is assembled from its traversal parts.

## Game integration

Main’s forward-run stopping update is merged: planted feet during braking, a settle step, and direct blending to idle after short or long forward runs. Step assist, current native carry layers, and main’s other locomotion overrides are retained. The “Frontier Updated” comparison snapshot is refreshed to the commit above.

`launch-frontier-legacy-game.command` opens the actual worktree game with the bow equipped. The approved twelve movement clips are active: nine standing walk/run/sprint clips, jump, and two vault variants. Seven approved bow clips feed standing/crouched aim, draw, recoil, and sheath adapters. Rifle, crouch locomotion and climbing comparison blends remain preview only.

`data/anim_author/locomotion_clips.json` routes standing movement and jump. `data/anim_author/frontier_legacy_gameplay.json` routes the bow layers and the four stages of each vault. `Frontier_Legacy_Runtime.res` contains the runtime adapters; regenerate it with `tools/agls_comparison/author_runtime.gd`. The approved pose resources and native Actor_B library remain intact.

The bow sweep is sampled into a neutral aim and rest-relative up/down layers. Draw is a charge-seeked upper body trajectory. Recoil hands off from the held draw and returns to neutral. Sheath is reversed during baking to fit Frontier's existing reverse holster stage. The game continues to own input, draw time, arrows, ammo, fatigue, nocking, grip modifiers and attachment transforms. Movement speed, collisions, takeoff/landing decisions and traversal root paths stay under the existing controllers. Vault clips are cut into the existing four sprint-vault stages, retaining each stage's native root and translation tracks; other traversal families retain their clips.

Controls: WASD move, Alt walk, Shift sprint, Space jump/vault, C crouch, 1 bow, hold LMB draw and release to fire, RMB let down, R arrows, H holster. Press `[` or `]` while outside a traversal to choose the left or right approved vault for the next low running vault. Existing weapon holding layers still apply on top of movement clips.

For a worktree baseline comparison, append `--frontier-legacy-off` after `--` in the launch command. This uses `frontier_legacy_baseline.json` (the current-main locomotion snapshot) and skips the new bow and vault adapters. Main is not modified. This is a playable test integration; vault contacts on varied world geometry and bow transitions still need visual review before production use.

Focused verification: `tests/anim/run_all.gd -- --only=test_tree_build,test_direction_weights,test_loco_graph,test_air_land` and `tools/agls_comparison/runtime_smoke.gd` (actual player, bow, final modifiers, arrows and stance changes on a test floor). Reports are in `.comparison-private/reports/`.

The baked weapon files are pose resources. Reusing them requires the game's live grip and aim modifiers. They do not include firing, ammunition, input, climbing logic, Unreal Blueprint behavior or animation notifies.

The trimmed native Actor_B library remains byte-identical: **964 clips**, SHA256 `7513a6da541dc780ca0433242d686d78ee5a6f8338f7eac1737a305cbc7096fa`. No removed clips were restored. All edits are in this worktree.

Grounded uses a slower cadence, longer stance phase and restrained knee swing. Athletic uses a quicker cadence, shorter stance phase, more forward torso lean and stronger swing knee flex. Their gameplay speed values are proportional estimates; use a rendered contact check and measured travel speeds before production integration.

## Rebuild

From the worktree root, use the installed Godot 4.7.2 executable:

```sh
GODOT=/Applications/Godot_mono.app/Contents/MacOS/Godot
"$GODOT" --headless --path . -s tools/agls_comparison/build_preview.gd
"$GODOT" --headless --path . -s tools/agls_comparison/author_upper.gd
"$GODOT" --headless --path . -s tools/agls_comparison/build_weapon_references.gd -- --frontier-legacy-off
"$GODOT" --headless --path . -s tools/agls_comparison/author_frontier.gd
"$GODOT" --headless --path . -s tools/agls_comparison/author_styles.gd
"$GODOT" --headless --path . -s tools/agls_comparison/build_updated.gd
"$GODOT" --headless --path . -s tools/agls_comparison/install_game.gd -- style=approved
"$GODOT" --headless --path . -s tools/agls_comparison/bake_weapons.gd
"$GODOT" --headless --path . -s tools/agls_comparison/audit.gd
```

The decoded source data and snapshots are private working inputs under `.comparison-private/` (ignored). To recover them, the retained UAssetAPI reader and `extract_motion.py` read the supplied Unreal assets without modifying them. Native sample frames are converted to quaternions before interpolation. Animated ladder scales are preserved in the source reconstruction; retargeting keeps Frontier's bind lengths.

These resources are authored derivatives of existing Frontier and AGLS motion. Source identities, hashes, attribution and derivation metadata are retained. Naming or timing changes do not establish new ownership or guarantee that motion cannot be matched.

## Verification

- Source FK reconstruction checks passed for all 33 clips; maximum position discrepancy is below 0.000001 m.
- The actual four-column viewer loaded 99 clip/preset combinations with finite poses. Run, crouch walk and ladder playback changed pose in all four columns for all three Legacy presets (36 movement checks).
- Tree construction, direction weights, locomotion graph and air/landing: **209 checks passed** after the latest main merge.
- Carry-layer checks: 29 passed, three musket crouch failures. Current main's frozen configuration produces the same three values/failures; these predate Legacy integration.
- Full level weapon checks stopped during scene cleanup with Godot's `_exit_world` static-string error. This run did not produce a complete result; it is not counted as a pass.
- The audit checks the native library bytes, trim count, effective ten overrides, source identities, style clip sets and 72 weapon exports.

Rendered captures and machine-readable reports are under `.comparison-private/reports/`. Official engine references: [AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html), [Animation](https://docs.godotengine.org/en/stable/classes/class_animation.html), [Skeleton3D](https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html).

## Runtime API references

The adapters use Godot 4.7.2’s existing [AnimationNodeAdd2](https://docs.godotengine.org/en/stable/classes/class_animationnodeadd2.html) and [AnimationNodeOneShot](https://docs.godotengine.org/en/stable/classes/class_animationnodeoneshot.html) contracts. Bow gameplay smoke checks passed at standing/crouched camera pitches −40°, 0°, +40°; the worst measured barrel error was 1.542°. Rendered standing partial/full draw, release and crouch draw captures are in `.comparison-private/reports/gameplay-bow-*.png`.
