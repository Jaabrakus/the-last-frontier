# Thủy Vân: handoff to the new session (2026-10-05)

You are the session that owns the Thủy Vân world conversion. Work in `/Users/kiwimango/Downloads/Frontier/.claude/worktrees/thuyvan`
(branch `thuyvan`). The previous Thủy Vân session was pinned to worktree-spellcraft and could not run commands here, so
phase 1 is half landed. Everything you need is in this folder (PLAN = this folder).

## Read first

1. `owner_answers.md` — the owner's answers; they override everything else. **Item 6, the art direction, is the
   priority:** the world must look like the owner's concept sheets in a **World of Warcraft Classic** spirit (stylized,
   hand-painted, saturated, chunky silhouettes, exaggerated landmarks, painted skies). The owner was unhappy to be shown a
   bare green height-field: never show a grey/placeholder render as progress; show the look.
2. `owner_summary.md`, then `plan.md` sections 1-3 and 6 (target, decisions, canon corrections, branch and lock rules).
3. The owner's world: `../bible_v3.txt`, `../series_bible.txt`, `../stories.txt` (text copies of the docx files on
   `/Volumes/The one/`), and the 15 concept sheets in `/Users/kiwimango/Downloads/New Folder With Items/` — look at them
   (Trường Sơn, Thạch Uyên, Đồng Lau, Vực Sen Sâu, Ảo Thành, Lâm Uyên, Vạn Thủy, the Buried Kingdom, the map, the
   peoples). They are the visual target.

## State of phase 1

| Piece | Where | State |
|---|---|---|
| T0 branch + lane | `thuyvan` at 6c56011; lane worktree exists | Lane not imported yet; `data/world/maps/r1/layout.json` not committed (use `phase1/r1_layout.final.json` byte for byte) |
| T1 canon data, ThuyVanCanon, text guard | branch `tv/T1` (3748849) | Done; Python tests pass; GDScript test not run |
| T2 fonts | branch `tv/T2` (fad0c45, contains tv/T1) | System fonts only. **Redo the font part:** the owner said YES to one free OFL family — fetch Be Vietnam Pro and Noto Serif from github.com/google/fonts (`ofl/bevietnampro`, `ofl/notoserif`), compare on the strip, ship one with its OFL.txt + a SOURCE.md row. Move UiFonts out of `scripts/ui` (a Tidebreak path) into `scripts/thuyvan` |
| T3 WaterNetwork | branch `tv/T3` (cca3a64) | Done; Python tests pass; GDScript test not run |
| T4 R1 terrain recipes | branch `tv/T4` (62ed0dc, contains tv/T3) | Done in Python; placeholder squares; relief views in `review/T4/` (bare — not the look) |
| T5 Still Water greybox | staged in `../t5_stage/` (new/, hunks.py, apply_t5.py, APPLY.md) | Written against the lane's text, never applied or run |
| Merge | `../merge_stage/run_merge.py` (`--list`, `--dry-run`, then run) | Resumable runner for: layout commit, first import, baseline, merges T1 → T5 → T3 → T4 → T2, UiFonts move, Python + GDScript tests, frontier start check, launcher check, renders |

Findings to fix while merging (from the merge review): T5 and T3 ease the still reach on opposite sides of its ends
(make them agree); `atlas.json` ships L13's later name "Ash Coast" (hide it until Book II content exists); L14's line
hints the digs and the Buried Kingdom are linked (use a neutral line); the barge basin overlaps the main channel's east
bank at M2 (move ~15 m east).

## What to do next, in order

1. Run the merge runner (dry run first). Fix what fails. Get the frontier tests and `tests/thuyvan/*` green.
2. **The look (owner priority):** a look-dev vista of R1 — the Đá Trắng reach under the Two Heights — dressed to the
   Trường Sơn sheet in the WoW Classic spirit: stylized karst towers, painted terrain textures, waterfalls, mist bands,
   a rope bridge, a few stilt houses, a painted sky. Show the owner 2-3 bold variants as images, then the playable
   greybox with that look (F9 stops the river). Own assets only (Blender/procedural; the existing CC0 textures may stay;
   one OFL font allowed).
3. Then continue the plan's phases (Tidebreak dress is the other session's round; see below).

## Rules that still apply

- One heavy process at a time: Godot and Blender only through `bin/godot_run.sh` / `bin/blender_run.sh` here (they take
  the shared lock `/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/godot.lock`;
  `GODOT_TIMEOUT` ≤ 1100).
- Never touch the main checkout (other sessions) or `worktree-spellcraft` (the Tidebreak session's). Spellcraft's gate
  commits merge one way into `thuyvan`; `thuyvan` never merges back before the cutover.
- Never edit the Tidebreak loop's paths (plan section 6 lists them).
- No `git stash`; WIP commits; attribution trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- The owner's game rules: no target cues; hits never slow the player or hurt aim; easy to learn, hard to master; own
  assets and own clips; the owner judges by eye — lineups and bold variants. No show words from Avatar: The Last
  Airbender. Respect the bible's canon (plan section 3: no later-book reveals in shipped data or text).

## The other session

The Tidebreak gameplay session ("8v8 arena with bots and modern guns", working in worktree-spellcraft) owns the ring
game: improvement rounds, the Smash layer (damage %, stocks, edges, recovery), feel and polish. It will schedule the
Tidebreak rename/dress (plan Phase 2a; `for_tidebreak.md`) as its own round after its round 3 — it asked for the 2a label
table to be REDONE against its round-2 merged `data/sway/moves.json` (the skills redesign: fixed layout Jab, Guard,
Strike, Push, Dash, Wall, Heal) once it says round 2 has landed. Thunder moves to Wind (owner). Message it via
SendMessage (find it with ListAgents) for anything ring-related.
