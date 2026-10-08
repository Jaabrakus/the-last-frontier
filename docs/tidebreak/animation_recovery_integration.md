# Animation and recovery controls

The animation integration carries the contact/clip-routing prerequisites, the fluidity pass, and the correction to control after an elemental Rise.

## Animation behavior

Replacing or cancelling a cast blends from its displayed pose for at most 80 ms, ending by the incoming strike deadline. Interrupted blends retain masks and remain bounded. Light and heavy landings keep their immediate foot and hip contact while the upper body settles. Contact reactions keep priority.

Unarmed arena opponents select directional gait and playback speed from their own local movement, excluding knockback carry. Gait changes preserve planted-foot phase. Ordinary player footsteps exclude knock-only sliding and special body-state movement.

The prerequisites wire existing clips to their situations, normalize pose metadata, share hit-stop bookkeeping between animation consumers, clear visual hold state on reset, and preserve the contact/air-cast layer order. Animation resource files and clip generation are outside this integration.

## Control after recovery

Earth's Pillar, Water's Fountain, Fire's Jet and Air's Updraft previously ended in a helpless state. This blocked casting and dodging and reduced air steering until landing or grabbing the edge.

When recovery travel ends, ordinary steering and aerial attacks now return, along with an air dodge if it has not been spent. The Rise and double jump remain spent. Recovery travel distances, ending vertical velocities, Air's glide, ledge rules and hitstun restrictions retain their existing behavior. The recovery's 0.35-second landing penalty is tracked independently of whether air controls are available; normal resource refresh rules still apply.

The outgoing Rise pose fades beneath a follow-up attack, including the short upward portion before the ordinary falling clip becomes eligible. NPC recovery prediction follows the same control rule.

## Validation

The integration was checked in an isolated copy of `main` at `c47aef4` with only these animation/presentation and recovery changes applied. This keeps the checks independent of other uncommitted demo work in the working folder.

- Full script compilation: 858 passed, zero failed.
- Cast/landing handoffs and follow-up attack visibility: 30/30.
- Directional gait, phase and footsteps: 31/31.
- Recovery, travel geometry, refresh, hitstun and fast fall: 74/74.
- Pose metadata: 54/54; ring pose transitions: 12/12.
- Clip situations on players and bots: 122/122 (65 mappings loaded; 64 active clips played, with the retained helpless mapping inactive).

Four real-input before/after Practice recordings additionally demonstrated that all four elements previously ended helpless and blocked their follow-up. After the fix, Earth, Water and Air performed their remaining dodge, and Fire released an airborne attack. This rendered comparison used the current local demo, which also contains other uncommitted presentation changes; it is distinct from the isolated integration checks above. The existing camera partly crops Earth, Water and Air during the highest portion of their ascent in both recordings; this integration does not change camera framing.

Run the focused checks with the repository's engine wrapper:

```sh
GODOT_TIMEOUT=180 zsh tools/loop/godot_run.sh --headless --path . -s tools/compile_check.gd
GODOT_TIMEOUT=150 zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tests/bending/test_cast_pose_handoffs.gd
GODOT_TIMEOUT=150 zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tests/ring/test_ring_grounded_animation.gd
GODOT_TIMEOUT=180 zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tests/ring/test_ring_moves.gd -- only=recovery,rises,refresh,hitstun,fast_fall
```

Logs retain the existing startup diagnostics and shutdown resource warnings; the clip-situation harness also emits existing horse-scene transform and missing-lightning-sound diagnostics; the passing checks contain no script errors. These checks do not establish perfect foot locking, a hardware frame-rate target or new balance win rates.
