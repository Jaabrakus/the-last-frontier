# Round 4 task VIRAL: the moments people clip and share. The Splash Cam replay of every fall, the match's highlight cards, clashes in mid-air, the big callouts, and a photo mode.

You build round 4's VIRAL for Tidebreak (Godot 4.7) in an isolated worktree. SCRATCH means
/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad.
- Merge order: SIXTH in round 4 (after IMPACT, READ, LOOKS, HUD, SHOW; before SIMPLE). Build against round 3's merged
  head; use IMPACT's moment only through the signals named below (the merger wires them if IMPACT lands later).
- The owner's words: "do what you think would make a viral round 4". The genre's best spread through moments a player
  wants to watch again and send to a friend: a launch into the water seen from the side in slow motion, a stone caught
  a hair before it hit and thrown back, two attacks meeting in the air. Tidebreak has these moments; nothing shows them.

WHY (measured at round 3's head — re-check):
- A fall shows the KO splash once, from the faller's own camera, then the respawn. Nobody sees the throw that did it.
- The match screen shows the score only. Nothing remembers the best plays.
- Two attacks that meet in the air (stone vs stone, water dousing fire, a guard returning a bolt) resolve with the same
  small hit sparks as any hit.
- There is no photo mode; screenshots carry the HUD.

FILES YOU OWN (new unless marked):
- scripts/ring/ring_replay.gd (class_name RingReplay): the recorder and the player.
- scripts/ring/ring_highlights.gd (class_name RingHighlights): the play tracker and the cards' data.
- scripts/ui/replay_overlay.gd, scripts/ui/highlight_cards.gd, scripts/ui/callouts.gd, scripts/ui/photo_mode.gd.
- scripts/bending/bend_clash.gd (class_name BendClash): the clash moment.
- data/ring/replay.json, data/ring/highlights.json, data/ring/callouts.json.
- tools/ring/viral_shots.gd; tests/ring/test_ring_replay.gd, test_ring_highlights.gd, test_bend_clash.gd,
  test_photo_mode.gd.
You do NOT edit other round-4 tasks' files. Where you need a hook in a file you do not own (one call or one signal emit
in bend_bolt.gd, bend_zone.gd, ring_mode.gd, match_screen.gd or ring_menu.gd), write the exact hunk in your result's
api_needed_from_others; the merger applies it. Prefer signals that already exist: RingRules.current() and its ko,
launched, respawned and pct_changed signals; BendCaster.guarded(result, what) via BendZone.report; BendBolt's break and
douse paths.

BUILD

1. The Splash Cam (RingReplay).
- A ring buffer of the last 8 s (data), written every physics tick while a stock-rules match runs: each competitor's
  global transform, the pose clip name and its time (whatever BendPoses/SwayPose/NpcBody play), the % and visible state
  (tumbling, guarding, hanging); plus EVENTS: bolt and effect spawns (kind, transform, velocity, look), hits, guards,
  splashes. Bounded memory (pre-allocated arrays; no per-tick Dictionary churn).
- On every KO (RingRules ko), after the KO splash moment ends (IMPACT's RingMoment signal if present, else 0.6 s), play
  the last 3.5 s up to the splash as a REPLAY: visual-only GHOST PUPPETS (the competitors' meshes duplicated without
  physics or scripts, posed from the buffer), the recorded effects re-spawned visually, the live match paused behind it
  (process mode), a cinematic camera from data (a side dolly that keeps the thrower and the faller in frame, slowing to
  0.4x for the 0.5 s around the decisive hit, then back), a small REPLAY tag in a corner. Any key skips. The live match
  resumes exactly where it was (test it). No target cue: the camera frames the action; nothing is drawn on anyone.
- Esc row "Replays: Every fall / Last life only / Off" (default Every fall), remembered in GameSettings (the merger
  adds the row to ring_menu.gd from your result's hunk).
- Bots vs bots (spectate, soak) skip replays unless asked (arg replays=on).

2. Highlight cards (RingHighlights).
- Track plays during a match from events: the biggest launch (speed), the closest catch (the earth catch with the least
  time left before impact) and the longest catch rally, the perfect-guard streak, the clutch recovery (a Rise or double
  jump back to the edge from the deepest point), the comeback (won after being two lives down), the fastest KO (time
  from respawn), the clash. Score each by data weights; keep the best 3 with their 4 s snapshot (copied out of the ring
  buffer when the play happens).
- At match end, the match screen shows the 3 cards (title, one plain line, the number), each with "Watch" playing its
  snapshot through the Splash Cam player. Plain words, no show words, no Smash words ("fall", "lives", "Rise", "catch",
  "perfect guard"). The merger adds the card panel to match_screen.gd from your hunk.

3. Clashes (BendClash).
- When two attacks meet (BendBolt vs BendBolt break, water douses fire, steam, a perfect guard's return meeting
  another bolt), at the meeting point: a big two-colour burst in the two elements' colours, a shockwave ring on the air
  (an EFFECT at the clash point, never on a body), a clash sound (BendSounds: add a clash id only through
  api_needed_from_others if none fits; else reuse the loudest existing hit), and a short shared hit-stop for both casters
  through BendImpact (IMPACT) if present. Data in data/ring/feel.json is IMPACT's: put your numbers in callouts.json.

4. Callouts (callouts.gd).
- Big short words on the player's own screen for big moments, stylized, centred above the strip, 0.9 s, max one at a
  time with a priority queue: "SPLASH!" (a KO), "CAUGHT!" (an earth catch within 0.15 s of impact), "PERFECT!" (a
  perfect guard), "RISE!" (a recovery from the deepest third), "CLASH!", "COMEBACK!", "LAST LIFE" (sudden death or both on
  the last life). Readable, juicy (scale punch, a slight tilt, the element colour), never on or over the enemy, off in
  Esc ("Callouts: On/Off").

5. Photo mode (photo_mode.gd).
- Esc → Photo: the match pauses, the HUD hides, a free camera (WASD, mouse, Q/E up/down, wheel for FOV, a speed key),
  a "Take" key saving a PNG to user://photos/ (and printing the path), a small Tidebreak wordmark in the corner of saved
  photos (toggle). Leaving restores the exact camera and resumes.

TESTS (each with a watchdog, seed(1750), the last line "<NAME> PASSED|FAILED", MatchSetup._aim_help pinned,
GameSettings.path isolated):
- test_ring_replay: a scripted fall records, the replay plays ghosts at the recorded poses (sample frames match the
  buffer to 1 cm), the live match resumes with every competitor's transform, %, lives and lock unchanged; skip works;
  Off skips; memory is bounded (buffer sizes fixed after warm-up).
- test_ring_highlights: scripted plays produce the right top 3 and their snapshots; words scan clean.
- test_bend_clash: each clash pair makes one burst and one sound at the meeting point; nothing is added to a body.
- test_photo_mode: enter, move, take (a file appears), leave (camera and match restored).

REVIEW (the owner judges by eye; go bold): through the lock, windowed — a Splash Cam replay as a 12-frame strip
(SCRATCH/review/r4_viral_replay_strip.png), the three highlight cards (r4_viral_cards.png), each clash pair
(r4_viral_clash_*.png), every callout (r4_viral_callouts.png), a photo-mode shot with and without the wordmark.
METRIC lines: replay_resume_exact, replay_buffer_bytes, clash_pairs_covered, callouts_count.

RULES: the round's COMMON rules (SCRATCH/smash_r3/round3/COMMON.md) hold: no show words and none of Smash's own words in
player text, NO target cues of any kind, no painted zone lines, no cel shading of the world, own assets only, hits never
touch aim, camera or lock outside a replay (a replay is a cut-away, not the player's camera), Godot only through the
lock, simple Bash, compile_check clean, new class_names need --import.
