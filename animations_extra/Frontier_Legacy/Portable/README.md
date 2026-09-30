# Portable Frontier Legacy movement

**Use `Frontier_Legacy_Movement.res` for the approved Frontier blend shown in the comparison.** It is one Godot `AnimationLibrary` containing 19 embedded animations (12 movement clips and seven bow actions). Copying that file is sufficient; it does not depend on the separate `clips/` folder.

`Frontier_Legacy_Movement_Grounded.res` and `Frontier_Legacy_Movement_Athletic.res` contain the same 19 actions with their separately authored timing/posture presets. The approved version retains Frontier timing. The other versions are style derivatives, not newly captured or AI-generated motion. Source identities and attribution remain in each animation's metadata.

| Action | Animation name |
| --- | --- |
| Walk forward / backward / left / right | `frontier_legacy_walk_forward`, `frontier_legacy_walk_backward`, `frontier_legacy_walk_left`, `frontier_legacy_walk_right` |
| Run forward / backward / left / right | `frontier_legacy_run_forward`, `frontier_legacy_run_backward`, `frontier_legacy_run_left`, `frontier_legacy_run_right` |
| Sprint forward | `frontier_legacy_sprint_forward` |
| Jump | `frontier_legacy_jump` |
| Vault, left / right hand | `frontier_legacy_vault_left_hand`, `frontier_legacy_vault_right_hand` |
| Bow aim, standing / crouched | `frontier_legacy_bow_aim`, `frontier_legacy_bow_aim_crouch` |
| Bow draw, standing / crouched | `frontier_legacy_bow_draw`, `frontier_legacy_bow_draw_crouch` |
| Bow release | `frontier_legacy_bow_release` |
| Bow sheath, standing / crouched | `frontier_legacy_bow_sheath`, `frontier_legacy_bow_sheath_crouch` |

`Frontier_Legacy_Bow.res` is a separate, self-contained library with just the seven approved bow actions. The bow clips are unchanged across the movement presets.

## Load into Godot

Use the existing Frontier Actor_B skeleton with its bind rest. The animation track paths expect `Skeleton3D` under the AnimationPlayer's root. A different character needs retargeting.

```gdscript
var library: AnimationLibrary = load("res://animations/Frontier_Legacy_Movement.res")
$AnimationPlayer.add_animation_library(&"frontier_legacy", library)
$AnimationPlayer.play(&"frontier_legacy/frontier_legacy_run_forward")
```

When `AnimationTree` owns playback, set its `AnimationNodeAnimation.animation` to the library-qualified name instead. For the existing Frontier graph, use the worktree's nine locomotion override mappings. Weapon grip/aim controllers remain necessary; these libraries contain movement and bow poses; retain the game's weapon controllers for grip/aim, bowstring/arrow handling and firing.

Jump/vault resources are complete pose previews. Tune collision, trajectory and hand contacts before replacing the game's traversal actions. Original clip timing and root tracks are retained in the approved blend. Grounded/Athletic gameplay travel speeds still need measurement before production use.

Built and reloaded with Godot 4.7.2. `manifest.json` lists all clips, durations, derivative identities and file SHA256 hashes. Native source files were not changed.
