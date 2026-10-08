# Restart with Astra — 2026-10-07

> Historical snapshot from before the restart. See [the restart verification record](astra_restart_verification.md) for the later character fixes, beginner flow and completed checks.

The user explicitly stopped the current implementation and requested a restart with Astra because the character models are glitching. Do not treat the prior technical checks as visual approval. The user also requires the game to be very easy for girls and women to pick up and play. Prioritize approachable controls and onboarding without assuming lower skill based on gender.

## Immediate priorities

1. Reproduce and inspect the reported character-model glitches in the actual game. Determine whether they are skinning, skeleton transforms, animation layers/blending, hit-stop transitions, or something else. Inspect player and bots during movement, casts and hit reactions. The current author has not reproduced or visually diagnosed this latest report.
2. Keep Basic controls easy to discover, prompts clear and readable, and the introduction forgiving. Test a complete beginner's first match and recovery. Preserve optional depth in Full controls. Confirm the user's intended ease in the actual playable flow, not only automated checks.
3. Review the uncommitted integration below before deciding what to keep or revert. Finish the saved work only after the model glitches are understood.

## Workspace and state

Canonical project: `/Users/kiwimango/Downloads/Frontier`, Godot 4.7.2 Mono. Branch `main`, HEAD `c47aef4` (HANDOFF), prior animation merge `6a61472`. No commits, pushes or branch changes were made in this task. Source edits are present in the working tree. No check started by this task is still running; the final performance run completed before the stop command.

Read `AGENTS.md`, `animations/SOURCE.md` and `docs/animation_provenance.md` before provenance claims. Apply the Godot project skill. Do not edit separate Thuy Van worktrees. Existing user media and `_tmp_slide_probe`/`_tmp_stopik_probe` files were already untracked before this task and were left untouched.

## Changes currently in the working tree

- Applied the saved `tb/R5-CLIPWIRE-wip` changes: poses/movement mappings, player SwayPose hit-stop and directional struck layer, bot struck bridge/guard loops/spout step-off, and the new `tests/bending/test_clip_situations.gd`.
- Fixed bot wall-tech animation priority in `scripts/npc/npc_fighter.gd` so the ring movement pose can take priority during flinch.
- Memoized `BendImpact.pose_rate` once per rendered frame so PlayerAnim and SwayPose share a rate rather than consuming hold debt twice. Added `BendImpact.clear_pose`, called from `BendKnock.reset`, to clear hold/debt/rate/struck state on reset.
- Applied the saved `tb/R5-BALANCE-wip` data/AI/test changes. No additional balance tuning was performed afterward. A small-sample pass does not establish the desired 40–60% win balance.
- Applied `tb/R5-PERF-wip` diagnostic test changes. Ring loading now draws an actual KO splash silently, waits 3.3 seconds under the loading screen, and then uncovers the ring. `ItemIcons.prewarm` skips unrelated open-world inventory icon painting in a RingLevel.
- Applied source keys from `tb/ANIM-polish-wip-3` for four clips: tumble, helpless, jump_double, fall_fast. Corrected unreachable limb keys and failed silhouette checks, then baked and installed only these four into `animations_extra/Frontier_Bend.res`. Current generator output: `polish7.json`; the other 37 historical critic notes were not all completed or independently rescored.
- Fixed a returned stone slowing repeatedly against one fighter's capsule/torso/head in `scripts/sway/gust_lift.gd`: exclude the fighter's complete `ray_exclude()` list after first impact and apply slowdown only for a first hit. A focused Catch comparison passed after this fix. A later assertion checking the full exclusion list was added but not run before the restart.
- Added a scoped integration record to `animations/SOURCE.md`. Historical evidence and aliases remain.

## Validation and limits

All logs/artifacts: `/private/tmp/frontier-update-verify`.

- Initial stale `.godot` global-class registration caused parse errors; headless editor import repaired the cache. Last full compile before the latest reset/stone/test edits: 855 OK, 0 bad. Run it again for final source.
- `situations-fixed.log`: 122 checks passed; all 65 new situation clips observed on player, 62 on bots (3 player-only). This was before the newest shared-rate assertion and balance/polish integration; rerun the current test.
- `polish7-test.log`: all 3,762 animation checks passed. Blender worst IK misses: tumble 0, helpless 0, jump_double 0, fall_fast 0.002 m. These are technical checks, not final rendered approval. The four revised clips still need rendered multi-angle/transition inspection.
- `feel-exact.log` and `feel-reset.log`: full ring feel test had one Catch trajectory failure out of 24. `catch-fixed.log`: the focused Catch test passed after the multiple-collider slowdown fix. The full current test has NOT been rerun. `only=catch` is now an optional test argument.
- All 16 baseline soak pairings passed. Report `balance-before.md`: water 100%, earth 66.7%, air 33.3%, fire 0% in six cross-element games each. Median game 280.5 s; life 96.4 s; true-string median 1; max move share 0.34.
- `balance-wip.log`: 16-game WIP smoke passed 6 gates. Cross-element game wins earth 3/6, water 4/6, fire 0/6, air 5/6. Life shares earth 48%, water 52%, fire 37%, air 63%. Larger seeded tuning remains needed.
- `perf-after.log`: 9 performance checks passed with music, 9 falls and 9 replays. Max fight 78.2 ms, fall 21.3 ms, replay 43.4 ms, restart 34.1 ms. Longest loading frame 1,063 ms; loading thresholds were disabled (`load_ms=0`), so the cold-loading target is not met.
- `perf-cold.log`: repeated with fresh PROJECT shader cache; 9 checks passed. Fight 71.1 ms, fall 21.5 ms, replay 35.8 ms, restart 44.6 ms. Longest load 513 ms, above the 250 ms aim. This does not clear OS/driver caches. Old project cache is preserved at `shader-cache-before-cold`; a new cache now exists in `.godot/shader_cache`.
- Initial R4 earth and air menu-to-match play checks passed 38 checks each before integration. Rerun all four elements after final fixes.
- ObjectDB/resource/RID shutdown leak warnings persist; they are not proof of an in-game character-model diagnosis.

## Recovery and tools

- Pre-polish binary: `/private/tmp/frontier-update-verify/Frontier_Bend.before-polish.res`.
- Tracked changes snapshot including binary: `/private/tmp/frontier-update-verify/restart-changes.patch`.
- New untracked situation-test backup: `/private/tmp/frontier-update-verify/test_clip_situations.gd`.
- A library-preservation probe was written at `check_library.gd` in that directory but has NOT been run. It compares untouched clips and timing metadata against the pre-polish binary.
- Use `tools/loop/godot_run.sh` and `blender_run.sh` (at most 3 heavy jobs). Keep rendered performance measurements on a quiet machine. Do not use the historical gate batch blindly: it references a different worktree and missing scratchpad helpers.
- Current source diff has no whitespace errors as of the last check; final broader checks remain incomplete.
