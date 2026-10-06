# Round 3 task CLIPS: our own new Blender clips for the % ring: the tumble and flinch, the double jump, fall, fast fall and helpless loop, the air dodge, the edge grab, hang and four edge options, the scramble up the deck face, ground rolls and the duck, the air-legs mask, landing lag, the four Rises, breaking the fall and the getups, the spiked and bounce knocks, the Pop's rising hand, the four Slams, the held guard loops, the teeter, the spout ride and the air High Kick. P1 first. Each clip gets a SOURCE.md row and a contact sheet.

You author round 3's new clips for Tidebreak in an isolated worktree.
- Merge order: P1 whenever ready (it may merge before PERCENT), then P2 and P3. Code tasks run on stand-ins until your
  clips land, because BendPoses passes over a missing clip.
- Read first: AGENTS.md, animations/SOURCE.md and docs/animation_provenance.md (the project's CLAUDE.md requires it).
  - Every clip is keyed by hand on the rig's rest pose in tools/anim_author/blender/bend_clips.py.
  - No imported, retargeted or measured reference animation.
  - Real martial arts are a visual reference only: fire Northern Shaolin, earth Hung Gar, water tai chi, air Baguazhang.
- Blender ONLY via `zsh /private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/blender_run.sh -b -P ...`;
  Godot only via godot_run.sh. One heavy process at a time.
- Spec: smash_r3/spec.md (v2) §13 (the names are EXACT: MOVE maps them in movement.json and AIR in poses.json).

ROUND-2 FILES YOU WILL MEET:
- bend_clips.py with round 2's clips (fire kick-low, the High Kick's mirror, earth kick-up and uproot, water turn, air
  pull, slip, wall, slice, surf, skate, shield-hold, and the four guard poses).
- Frontier_Bend.res.
- SOURCE.md's bend rows.
- test_bend_clips.gd (the IK miss ≤ 5 mm rule).

FILES YOU OWN: tools/anim_author/blender/bend_clips.py, animations_extra/Frontier_Bend.res (rebuilt by your pipeline),
animations/SOURCE.md (the bend rows), tests/bending/test_bend_clips.gd. You do NOT edit poses.json or movement.json.

BUILD

**P1: the first playable**
- **own-bend-tumble:** a loop for a long launch, limbs flung, distinct from the knocked slide; it may grow out of
  own-bend-knock-air. Mask full.
- **own-bend-flinch:** upper mask, about 0.25 s; a light hit on the feet.
- **own-bend-jump-double:** about 12 f; a tucked knees-up spring.
- **own-bend-fall** (loop, about 20 f) and **own-bend-fall-fast** (a tucked arrow pose).
- **own-bend-helpless:** a loop of about 24 f, arms trailing up, a loose slow tumble that reads clearly apart from the
  fall. No stand-in.
- **own-bend-air-dodge:** about 15 f, a sharp tucked twist; the direction comes from code.
- **The edge set:** own-bend-edge-grab (6 f: both hands catch the lip, the body swings in under it); **own-bend-edge-hang**
  (a loop of about 30 f: hands and head clearly OVER the lip, feet on the face, a slight sway; no stand-in);
  own-bend-edge-climb (about 15 f: knee onto the deck, stand); own-bend-edge-roll (about 22 f: pull up into a forward
  roll; root by code, 3 m); own-bend-edge-jump (about 9 f: a hands-push spring straight up); own-bend-edge-attack (about
  18 f: pull up with a low sweeping leg).
- **own-bend-roll-f, own-bend-roll-b, own-bend-roll-side** (+ own-bend-roll-side-l): about 18 f each, low rolls, facing
  kept. **own-bend-duck:** about 14 f, a deep sway down and back, then a return.
- **own-bend-air-legs:** a lower-body mask, legs tucked under any air cast.
- **own-bend-land-light** and **own-bend-land-heavy:** about 10 f; the heavy crouch reads as the punish.

**P2**
- **The four Rises:**
  - own-bend-rise-earth: crouched on the rising column, fists down, the body leaning about 20° forward with the column
    (it leans toward the deck in play), thrown off the top;
  - own-bend-rise-water: rising on a water column, arms swirling up;
  - own-bend-rise-fire: a hover tell (8 f, knees drawn, fists at the hips), then a burst (10 f, straight-legged along the
    burst);
  - own-bend-rise-air: a spin up (14 f), then a glide loop with the arms spread (30 f).
- **own-bend-edge-scramble** (new in v2): about 18 f; the hands slap the deck's face and haul the body up it, feet
  scrabbling, ending exactly in own-bend-edge-hang's first pose.
- **Breaking the fall:** own-bend-tech (a slap-and-rise in place), own-bend-tech-roll (+ -l, 2.5 m in 0.4 s),
  own-bend-tech-wall (plant against a wall and push off).
- **Lying and getting up:** own-bend-lie (a loop), own-bend-getup, own-bend-getup-roll (+ -l), own-bend-getup-attack (a
  low sweep while rising).
- **own-bend-knock-spiked** (driven down, arms up) and **own-bend-knock-bounce** (the back meets the deck and bounces up).
- **own-bend-jab-rise** (+ -l): the Pop's rising hand, upper mask, one for all elements (the effect carries the element;
  for earth the hand closes round the kept stone at the end, so the held-stone pose follows cleanly).
- **The Slams:** own-bend-earth-hammer (both fists overhead, hammered down in mid-air); own-bend-water-downpour (arms
  raised and swept down, the body rising a little); own-bend-fire-axe-kick (+ -l; one leg raised overhead and chopped
  down); own-bend-air-down-gust (palms driven down, the body lifted). The strike must come early (lock 0.3-0.35 s).
- **own-bend-guard-hold-earth / -water / -fire / -air:** loops of round 2's four guard poses, held, readable at a glance.
- **own-bend-teeter:** about 12 f, a lean with windmilling arms at the lip.

**P3**
- **own-bend-spout-ride:** balanced on the rising water, arms out a little, an idle loop and a step-off.
- **own-bend-fire-flip-kick** (+ -l): the air High Kick, a back-flip crescent.

The steering lean is code (an additive tilt), not a clip.

Every clip gets:
- its metas: hand, mask, root, hold_s, strike_s, back_s, and legs_always as needed;
- its mirror where it has a side;
- a SOURCE.md row in the existing format: the date, the bend_clips.py key, "the rig's rest pose; keys in CLIPS", and the
  provenance column left for the owner to fill.

Existing clips must not change.

TESTS: extend tests/bending/test_bend_clips.gd.
- Every new clip exists in Frontier_Bend.res with its metas and its mirrored twin.
- The worst IK miss is ≤ 5 mm.
- The existing clips' timing metas are unchanged.
- own-bend-edge-hang's hands and head sit above the lip height (the hips' rest height + 0.4 m) at every frame.
- own-bend-edge-scramble's last frame matches own-bend-edge-hang's first within 1 cm per bone end.
- own-bend-helpless keeps both hands above the shoulders.
- The Slams' strike_s ≤ 0.2 s.

REVIEW OUTPUT, in /private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/review/:
- Contact sheets clips4_<name>.png: 8 frames with front and side rows, as in clips3_*.png.
- clips4_lineup_edge.png: grab, scramble, hang, climb, roll, jump, attack.
- clips4_lineup_rise.png: the four Rises.
- clips4_lineup_slam.png: the four Slams.
- clips4_lineup_air.png: the double jump, fall, fall-fast, helpless, air dodge and air-legs.
- clips4_lineup.png: all of them.

Report the files changed, the IK miss numbers and the test lines. The owner judges by eye: make the helpless fall, the
hang, the scramble and the four Rises bold and readable at 15 m.

---

RULES FOR EVERY ROUND-3 TASK (each task text repeats them)

- **The game:** Tidebreak, Godot 4.7 GDScript. Worktree /Users/kiwimango/Downloads/Frontier/.claude/worktrees/spellcraft
  (branch worktree-spellcraft).
- **Your base:** your own isolated worktree off its head after round 2 (CORE, CLIPS, KITS, HUD_LESSONS) **and the
  round-3 SEAMS commit** have merged. If SEAMS is missing, stop and report. Rebase on the tasks merged before yours
  before your final test run (merge order: CLIPS P1 whenever ready; PERCENT → MOVE → AIR → BOTS). Commit only your own
  files.
- **Read first:**
  - SPEC (v2): /private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/smash_r3/spec.md.
    It rules over the part designs and over spec_v1.md. §0 is the controls, §1 the settled conflicts, §14.3 the API
    contract between the tasks, §17 the owner's open questions with the defaults you build, §20 why v2 changed what it
    changed.
  - The long-form part design named in your task, in the same folder. Where it disagrees with spec.md, spec.md wins.
  - docs/bending_design.md (round 2 rewrote it).
  - Round 2's kit: .../scratchpad/skills_r2/spec.md, overridden by .../skills_r2/owner_answers.md. Remember round 2's
    casting: 1/2/4/5 READY a move and right click (RMB) casts it.
  - The owner's answers: .../scratchpad/critic_r2/owner_answers_r3.md.
  - The numbers' scripts (v2): smash_r3/lead_model.py, lead_table.py (lead_table.out), lead_combos.py
    (lead_combos.out) and lead_masher.py (lead_masher.out). The `*_v1.*` files are history.
- **Godot ONLY through the lock,** one Godot at a time:
  - Run: `zsh /private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/godot_run.sh <args>`.
  - Tests: `GODOT_TIMEOUT=420 FPS=60 zsh /private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/run_test_fps.sh <worktree> <log name> <tests/x.gd> <args...>`.
  - Green = EXIT 0, a PASSED or OK line, and 0 SCRIPT ERROR.
  - Blender only through `zsh /private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/blender_run.sh -b -P ...`.
- **Hygiene:**
  - Use simple Bash commands. The worktree guard refuses compound git commands, so write Python helpers under the
    scratchpad.
  - Run `--import` after adding class_name scripts or assets. tools/compile_check.gd must be clean.
  - Match the code's `##` doc-comment style. Every number goes in data.
- **New tests:** a watchdog, seed(1750), a last line `<NAME> PASSED` or `<NAME> FAILED`, exit 0 only on a pass,
  `MatchSetup._aim_help` pinned, `GameSettings.path` isolated. Visuals never use the global RNG.
- **Known red since baseline, not yours:** test_hud_skills 1/33, test_hud_vitals 2/16, throw_edges, throw_flesh and
  anim run_all. test_flow's catch-back flakes about 2 times in 25.
- **THE GATE:**
  - Everything new runs only while `RingRules.stock_on()` is true (a stock-rules ring match has installed its
    RingRules), or, per body, while `RingMoves.of(body) != null` (installed only then).
  - With the gate off, the open world, the duel and the classic zone rules are exactly today's, and a test pins it.
  - The shared files (player.gd, npc_fighter.gd, sway_caster.gd, bend_knock.gd) branch on the gate. They never change the
    ungated path.
- **THE CONTRACT:**
  - Never edit another task's file. Call its API (spec §14.3) through the SEAMS stubs.
  - If you need a change in another task's file, write it in your report with the exact function you need.
- **OWNER RULES (never break):**
  - The sport is "Tidebreak".
  - NO show words in player-facing text: never Avatar, bender, bend, bending, pro-bending, Korra, nation names, or the
    show's technique names. Also never Smash's own names: stock, blast zone, DI, tech, edge-guard, meteor, smash, Final
    Smash. The player's words are "lives", "steer", "break your fall", "Pop", "Slam", "Rise", "dodge", "roll", "duck" and
    "edge". Player text says "right-click" for RMB and "C" for down.
  - NO target cues on enemies of any kind: no rings, frames, chevrons, outlines, markers or map dots. Each competitor's
    own % and lives on a fixed HUD plate is a scoreboard, not a cue. Anything that tells you about YOUR OWN state (the
    pips, your drop shadow, your sounds) stays on your own plate, body or ears.
  - NO painted zone lines. NO cel shading. No guns or gun sounds.
  - Our own clips only (docs/animation_provenance.md, animations/SOURCE.md) and our own assets only.
  - Getting hit never slows the player or hurts his aim. Hitstun is the launch: the camera, the aim and the lock are
    never touched by a hit (the lock is frozen and resumed, never lost).
  - Lock time is the only spam limiter for casts. No hit shortens a lock except the jab step (spec §6.4).
  - Earth catching a stone just before it hits and throwing it back is the fun core: never weaken it.
  - The owner judges by eye: make review images and go bold.
- **Owner calls not yet made:** build the spec's defaults (spec §17) and don't decide them otherwise.
- **Review output** goes to /private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/review/
  with the prefix `r3_<task>_`. Report the files changed, the test lines and the METRIC lines.
