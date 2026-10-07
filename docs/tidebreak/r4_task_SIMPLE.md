# Round 4 task SIMPLE: easy to pick up like RuneScape, hard to master. A Basic control set as the default for a new player, the game doing the hard parts for him (recovery, the edge, aim), and a measured "first five minutes".

You build round 4's SIMPLE for Tidebreak (Godot 4.7) in an isolated worktree. SCRATCH means
/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad.
- Merge order: LAST in round 4. Build against round 3's merged head.
- The owner's words (2026-10-05/06): "make the skills easy hard to master ... think human made think avg IQ"; asked
  whether the game is "simple like runescape but hard to master like runescape". RuneScape is simple because one click
  does the thing and the game handles the rest; its depth is optional and underneath. Round 3 added Smash's movement on
  top of round 2's seven keys (Space x3, 3 = dash/air dodge, E = shield/roll, C = duck/fast fall, the edge options):
  that is fighting-game complexity for a newcomer. Keep every expert tool — make the DEFAULT simple.

FILES YOU OWN (new unless marked):
- scripts/ring/ring_assist.gd (class_name RingAssist): the newcomer's helpers, driving the player's own inputs the way
  NpcPad drives a bot (round 3 MOVE's input seam) — it never edits RingMoves' or SwayCaster's code.
- data/ring/assist.json; data/bending/schemes.json (the "basic" scheme only; existing schemes unchanged).
- scripts/ring/match_setup.gd (the Controls preset field and its GameSettings key only).
- data/ring/lessons.json (a new "Basics" track only; the existing tracks unchanged) — lessons code is HUD's/BOTS'; if a
  hook is needed, put the hunk in api_needed_from_others.
- tools/ring/newcomer_sim.gd; tests/ring/test_ring_assist.gd, test_basic_scheme.gd, test_first_five.gd.
Hooks in files you do not own (the menus' Controls row, the strip's chips for Basic, ring_mode's first-match setup):
write the exact hunks in your result's api_needed_from_others; the merger applies them.

BUILD

1. The Basic control set (default for a new player; "Full" in Esc → Controls and the main menu, remembered).
- Basic keys: LMB Jab; RMB casts the readied move; 1 Strike (tap twice: its partner); 2 Push (hold to grow); E Guard
  (tap = timed guard, hold = shield); Space jump (and double jump); 3 Dash. Wall (4) and Heal (5) appear after the
  player's first win or in Full; the air dodge, rolls, duck, fast fall, short hop and the edge options are Full-only
  (in Basic the edge climbs by itself after 0.4 s, or on Space/any direction).
- The strip shows only the Basic keys (hunk for HUD's strip); the lessons' Basics track teaches only them.

2. The game does the hard parts (Basic only, each a data toggle):
- RECOVERY ASSIST: off the deck below the lip with a recovery left, HOLDING Space steers toward the nearest safe lip
  (the input the player would give) and fires the double jump, then the Rise, at the right moments (RingPredict tells
  when). Mashing works too. A newcomer who holds Space after every launch should make it back whenever an expert could.
- STEER ASSIST: while launched, a light automatic steer toward the deck's centre (a fraction of the full steer, data).
- EDGE: the grab is already automatic; in Basic the hang climbs by itself after 0.4 s unless an expert option is held.
- AIM: keep the owner's Aim help setting (light default) — do not change it.
- None of these ever move the camera or the aim, and none run for bots or in Full.

3. The first five minutes (measured).
- tools/ring/newcomer_sim.gd: a scripted NEWCOMER input model — moves toward the foe, clicks LMB in range, taps 1 and
  right-clicks when the foe is far, taps E when something flies at him late and imperfectly (reaction 0.35-0.6 s), holds
  Space whenever launched — playing Basic against the EASY bot, and an EXPERT-ish model against NORMAL.
- test_first_five.gd: over 20 seeded runs the newcomer wins at least 1 life-match of 3 vs easy within 5 minutes of
  game time in >= 60% of runs, recovers from >= 70% of launches it could survive, and never falls with a recovery
  unused; Full mode untouched (the same seeds with Full give round 3's numbers).
- Basics lessons (data): five cards, each done by doing — move and jab; ready and cast (1, right-click); guard (E) a slow
  dummy shot; push someone off (2 held); get back (hold Space). The first launch of the game offers them once.

TESTS (watchdog, seed(1750), last line "<NAME> PASSED|FAILED", MatchSetup._aim_help pinned, GameSettings.path isolated):
test_basic_scheme (Basic keys do what they say; Full-only keys do nothing in Basic; Full unchanged), test_ring_assist
(each assist under its toggle; bots and Full never assisted; camera and aim never touched), test_first_five (above).

REVIEW: SCRATCH/review/r4_simple_strip_basic.png (the Basic strip), r4_simple_recovery_strip.png (a held-Space recovery,
8 frames), and the newcomer sim's numbers table in your result. METRIC lines: newcomer_win_rate, newcomer_recover_rate,
full_unchanged.

RULES: the round's COMMON rules (SCRATCH/smash_r3/round3/COMMON.md) hold: no show words and none of Smash's own words in
player text, NO target cues, no painted lines, own assets only, a hit never touches aim, camera or lock, lock time the
only cast limiter, Godot only through the lock, simple Bash, compile_check clean, new class_names need --import.
