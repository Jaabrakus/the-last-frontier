# Handoff: where Tidebreak stands (2026-10-07)

> **Newer:** read `docs/tidebreak/start_here_2026-10-10.md` too: set-up on a new machine, what was built after this page was written, what is switched off, and what is waiting on the owner.

Read this first to continue the work. It covers the game as it is, how it was built, what is unfinished, and the
owner's standing rules. The design detail is in `docs/bending_design.md` and `docs/tidebreak/`.

## 1. The game now

**Tidebreak** is a 1v1 elemental ring sport in Godot 4.7 (GDScript). Earth, water, fire and air fighters fight on a
raised deck over water. It is inspired by Avatar: The Last Airbender, but uses none of its words or designs.
It is the playable core of the rebuild of the old 1765 "Frontier" open-world game. The open world is being converted
separately into **Thủy Vân**, the owner's own world (see section 6).

- **Run it:**
  ```bash
  /Applications/Godot_mono.app/Contents/MacOS/Godot --path <repo>
  ```
  Then choose **Tidebreak → Quick match**, **Practice**, or **Practice → Lessons**. The first ring load takes some
  seconds while shaders compile.
- **Rules (the default, "Lives"):**
  - Smash-style damage %: there is no health bar, and the higher your %, the farther a hit launches you.
  - You have 3 lives and are out only when you land in the water.
  - Your % resets after each fall, and you come back on a water spout.
  - A match lasts 8 minutes, with sudden death at the bell.
  - Esc → Rules switches to the older "Zones" rules.
- **Controls (Full):**

  | Input | Action |
  |---|---|
  | 1 Strike, 2 Push | Ready the move; right-click casts it. Tap twice for the partner move. Hold 2 to grow it; fire's 1 grows the Punch into a Fireball |
  | 3 | Dash on the deck, air dodge in the air |
  | 4 | Wall |
  | 5 | Heal (Patch / Mend) |
  | Left click | Jab; in the air, the element's close air hit |
  | E | Guard: tap for the timed guard, hold for a shield, with a direction to roll |
  | Space | Jump, then double jump; off the deck, the element's **Rise** |
  | C | Duck on the deck, fast fall in the air |
  | 2 in the air | The Slam (a spike) |

  The edge grab is automatic. While launched, hold left or right to steer the launch.
- **Basic controls** are the default for a new player: fewer keys, and holding Space recovers. Full controls are in
  Esc → Controls.
- **Feel:**
  - hit-stop and a screen jolt that never moves the aim
  - a KO splash, and a slow beat on the last fall
  - a **Splash Cam** replay of every fall, and highlight cards at match end
  - mid-air clashes and callouts ("SPLASH!", "CAUGHT!", "PERFECT!")
  - photo mode
  - Tidebreak's own music, and a crowd that reacts
- **Where the code is:**

  | Area | Location |
  |---|---|
  | Moves and effects | `scripts/bending/`, `scripts/sway/` (the cast engine), `data/sway/moves.json` (every move's numbers) |
  | Ring, rules, %, edges, replay | `scripts/ring/`; data in `data/ring/` (`rules.json` stock block = the % rules) |
  | Bots | `scripts/npc/npc_bending.gd`, `data/npc/bend_ai.json` |
  | HUD | `scripts/ui/` |
  | Own animation clips | `tools/anim_author/blender/bend_clips.py` → `animations_extra/Frontier_Bend.res` (hand-keyed; provenance in `animations/SOURCE.md`) |
  | Own synthesized sounds | `tools/sfx/bend/` → `audio/sfx/bend/` |
  | Ring music | `tools/music/cues/ring_*.py` |

## 2. How it was built (the improvement loop)

Each round followed the same pattern:
1. A short **design pass**: designers, a newcomer judge and an expert judge, then a spec with owner answers.
2. **Parallel builders**, each in an isolated git worktree on a branch `tb/R<n>-<TASK>`.
3. One **merge + gate** agent: an adversarial review, a merge in order, then the whole test batch compared with the
   last gate (no new reds allowed), a play-check from the menu, and a review page of images for the owner.

| Round | What landed | Specs |
|---|---|---|
| 1 | Staged ring load; the same bot kept across rounds; balance (air was 84%); 142 own synthesized sounds; Practice lessons | — |
| 2 | The **skills redesign**: one layout for every element (LMB Jab, E Guard, 1 Strike, 2 Push, 3 Dash, 4 Wall, 5 Heal; tap or double-tap); timed guards for all four elements; the fire Kick floor wave and High Kick; Fireball, Embers and Breath kept | `docs/tidebreak/r2_*` |
| Cleanup | 613 retired files (397 MB): old story stages, wonder sky, test peoples, period dress, real-peoples music except VN/TH/MY, musket club | `docs/tidebreak/cleanup_plan.md` |
| 3 | The **Smash layer**: % and launches, 3 lives, edge grab and recovery, the four Rises, air forms, the Slam, the Pop combo, bots, Practice | `docs/tidebreak/r3_*` |
| 4 | **Feel + viral + simple**: IMPACT, READ (camera C, flight sounds), LOOKS, HUD icons, SHOW (music, crowd), VIRAL (Splash Cam, highlights, clashes, callouts, photo mode), SIMPLE (Basic controls, recovery assist, a first-five-minutes test), BOTS2 | `docs/tidebreak/r4_*` |
| Animation lane | 65 new own clips + 4 "struck" poses, each batch looped animator → strict critic (8/10 bar); 28 meet the bar | Open critic notes for the other 37: `docs/tidebreak/anim_under_bar_notes.json` |

`main` on GitHub = **6a61472**: rounds 1-4 + the animation lane. Its tests pass, apart from the reds known before the
rounds: test_hud_skills 1/33, test_hud_vitals 2/16, test_fishing 2/17, test_story 1/30, test_mammoth_knee 1/19.

## 3. Unfinished: pick up here

The account's weekly limit stopped these mid-way. Each branch is on GitHub, unmerged and untested; read its diff
first.

| Branch | Holds | Next step |
|---|---|---|
| `tb/R5-BALANCE-wip` | Started on element balance (`bend_ai.json`, `rules.json`, `npc_bending.gd`, `test_balance.gd`) | Round 4's soak (non-mirror wins): **air 0%, water 94%**, earth 72%, fire 33%. Measure all 16 pairings first (`tests/ring/test_ring_soak.gd`), find why, then fix data before AI. Targets: every element 40-60%; life 60-100 s; game 240-420 s; top move share ≤ 0.3; median true string 2. Never weaken the earth catch-and-throw-back. |
| `tb/R5-PERF-wip` | Only a test edit | With music on, 1-4 s stalls appear in fights and restarts. Measure on a quiet machine (`tools/loop/exclusive_run.sh` takes every lock slot). Suspects: music streams loaded at play time, first-use materials, replay ghosts. Separately, the ring's longest load frame is the player build (~0.6 s). |
| `tb/R5-CLIPWIRE-wip` | Started wiring the lane's clips (`movement.json`, `npc_body.gd`, `sway_pose.gd`, a clip-situation test) | Map every new clip to its situation, for player and bots. Add at the top of `SwayPose._process`: `dt *= BendImpact.pose_rate(caster.player, dt)`, so hit-stop freezes the player's own body. Show `own-bend-hit-impact-<front/back/left/right>` during the hold. |
| `tb/ANIM-polish-wip-3` | Polish keys in progress | Second polish pass on the 37 under-bar clips (notes in `docs/tidebreak/anim_under_bar_notes.json`). Keep each clip's timing metas (strike_s, hold_s, back_s): code times casts on them. |
| `tb/ANIM-wip` | An older partial pass | Superseded by `tb/ANIM`; can be deleted. |

**Other open items:**
- **Owner calls answered by default, which the owner may still change:**
  - hit-stop holds your own launch up to 0.1 s
  - the slow beat only on a match's last fall
  - camera C, centred; round 4 widened the view instead of tilting it, after measuring
  - replays on every fall
  - Basic controls unlock Wall and Heal after the first win
- **Air's taught string is Pop → Gust:** Pop → Slice misses by 0.04 s.
- **Fire's away dress** is hard to tell from the home side at 25 m.

## 4. Waiting on the owner and the Thủy Vân session

- **Retire guns, the loadout, the mammoth and the old DuelMode.** These are cleanup tiers 2.6-2.9 in
  `docs/tidebreak/cleanup_plan.md`; the owner approved doing them after round 3, coordinated with the Thủy Vân session.
  - Keep a small bow and spear carry.
  - Move the 15 DuelMode-based Tidebreak tests onto the ring first.
  - Thủy Vân's branch still pins "no guns" in its greybox test.
  - After the guns go, play the bow, spear and torch to check for animation regressions.
- **The "2a" rename** of moves and the ring into Thủy Vân words: "art" instead of "element"; the arts are Current,
  Stone, Hearth and Wind; Lightning becomes **Thunder** under **Wind**.
  - The Thủy Vân session owes a label table redone against round 2's `moves.json`.
  - Schedule it as its own round.
- **Later:** 3v3, online 1v1 (NetSession exists from the open world), touch controls, and the open world converted
  to Thủy Vân.

## 5. How to run the tools

**Lock wrappers and helpers** (`tools/loop/`; the scratchpad copies vanish on reboot, so copy these back first):

| Tool | What it does |
|---|---|
| `godot_run.sh`, `blender_run.sh` | Run Godot or Blender through a lock of 3 slots (`GODOT_SLOTS` overrides). The owner chose "3 at once"; drop to 2 if the Mac runs hot. |
| `run_test_fps.sh <worktree> <log name> <tests/x.gd> <args>` | Runs one headless test. Green = EXIT 0 + a PASSED/OK line + 0 SCRIPT ERROR. |
| `gate_r4_batch.sh`, `gate_r4.tsv` | The last full gate (162 rows) and its results. |
| `recover.py` | Rebuilds the scratchpad's text files from the session transcripts. |

**Key tests:**
- `tests/ring/test_r4_playcheck.gd element=<earth|water|fire|air>`: a full match from the menu.
- `tests/ring/test_ring_soak.gd`: bots vs bots, for balance.
- `tests/ring/test_first_five.gd`: a newcomer in Basic.
- `tests/bending/test_bend_clips.gd`: the clips.
- `tools/compile_check.gd`: compile check for every script.

**Lessons learned:**
- Every isolated worktree is about **2.9 GB**. The disk filled once, so remove merged worktrees after each round.
- **Never SendMessage a running workflow agent.** It starts a duplicate copy in the same worktree.
- A Mac reboot empties `/private/tmp` (the scratchpad). Keep specs and wrappers in the repo.
- Rounds are lock-bound: tests and renders, not thinking, take the time.
- The **local** `~/Downloads/Frontier` checkout (main) is still on the old frontier commit; other sessions used it.
  Run `git pull` there when nothing else is working in it.

## 6. The owner's standing rules

- **No show words** in player-facing text: Avatar, bender, bending, pro-bending, Korra, nation names, the show's
  technique names. In the % ring, none of Smash's own words either (stock, DI, tech, meteor, smash…).
  - The player's words are "lives", "steer", "break your fall", "Pop", "Slam", "Rise", "dodge", "roll", "duck" and
    "edge".
- **No target cues** on enemies of any kind: no rings, outlines, markers or map dots. Your own % plate is a
  scoreboard, not a cue.
- **No painted zone lines.**
- **No cel shading of the world.** The stylized element VFX stay. The world's art direction (Thủy Vân) is "WoW Classic
  vibes": stylized, hand-painted, saturated.
- **Own animation clips only.** They are keyed by hand in Blender; nothing is imported or retargeted. Follow
  `AGENTS.md`, `animations/SOURCE.md` and `docs/animation_provenance.md`.
- **Own assets only:** procedural, synthesized or authored. CC0 Poly Haven stays.
- **Getting hit never slows the player or hurts their aim.** Hitstun is the launch, and the camera, aim and lock are
  never touched.
- **Lock time is the only spam limiter for casts.**
- **Earth catching a stone just before it hits and throwing it back is the fun core:** never weaken it.
- **Skills:** "easy to learn, hard to master… think human made, think avg IQ", "simple like RuneScape but hard to
  master". Never change a move's identity without asking.
- **The owner judges by eye and by playing:** show review images (go bold), then let them play.
- **Thủy Vân** is the owner's original world:
  - bibles on `/Volumes/The one/Thuy_Van_*.docx`
  - 8 peoples, 8 rivers + Memory, the Hollow Tide
  - Tidebreak becomes a sport inside it, with the kits as the peoples' arts
  - it has no firearms
  - its branch `thuyvan` merges this line one way
