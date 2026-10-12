# Air's talents in matches

The owner, 2026-10-11: "we need to make sure all the talents work and they work in game right". This page covers the skill
tree's air nodes (`data/sway/skill_tree.json`) that needed new code, made live per wearer through BendLoadout's behaviour hook
(`docs/tidebreak/loadouts_live.md`; `data/bending/loadout_apply.json` `behaviour`, `live`, `nodes`). The code is
`scripts/bending/air_talents.gd` (AirTalents): each seam in the game asks it with one line, and a body that wears nothing
(Classic, every bot of a normal match) gets the game's own answer from one meta lookup. The proof is
`tests/ring/test_talents_air.gd`: a 2v2 % ring (air with a fire mate, against air), each talent worn and not worn through the
game's own casts, locks, guards and hits.

| Talent | What the wearer gets | Where |
|---|---|---|
| Full Sail (`air.gust.full_sail`) | the Gust 2.4 m wide (2), its lock 0.5 s (0.45); numbers only, switched on again | BendEffects (spec), SwayCaster / NpcBending (lock) |
| Tailwind (`air.slice.tailwind`) | a Slice of his that lands charges his Carried wind (0.8 s, as a dash); the Slice adds 10% (11) | `AirTalents.on_hit` from `BendR3._noted` (the hitter's side of a hit, his own machine online) |
| Drift Guard (`air.guard.drift`) | walks at 1.5 m/s with his Wind Guard up (Classic: no walking); its beat 0.25 s (0.3) | `AirTalents.guard_walk` in `RingMoves._ground_physics`; `SwayCaster._root` and a bot's `shield_tick` let him walk |
| Eye of the Gale (`air.guard.eye`) | E held through a perfect Wind Guard: the bounced air circles him (up to 0.6 s) and leaves along his aim (x1.2) when E is let go; the perfect guard's Carried wind 0.4 s (0.8) | `AirTalents.eye_catch` in `BendZone._guard_bolt` (BendBolt's swing, held by `swing_hold`); `carry_wind(body, s)` |
| Rebound (`air.guard.rebound`) | his next Slice or Wind Ball begun within 1 s of a perfect Wind Guard starts its lock 40% full (once); his held guard drops at 2.0 s (2.5) | `AirTalents.on_guard` (BendZone.report), `start_fill` (SwayCaster._try_begin, NpcBending.begin); the tune path `rules:air_rules.guard.hold_max_s` |

Notes:
- Drift Guard: a direction pressed fresh while the guard is up is still the guard's Roll (RingMoves' ground dodge, as for
  everyone). He walks by holding a direction as he raises the guard, or by keeping one held.
- Eye of the Gale: E held is the player's guard button (SwayCaster._guard_down); a bot's is its held shield (NpcRingMind.shield:
  up while what it guards against still comes, so a bot sends the caught shot back almost at once). Online, the swing's hold is
  the host's; the other machines see the swing until the host's word turns the bolt.
- Rebound's head start is the lock contract's "techniques may start a lock part-full"; never a zero lock.

Run:
```
zsh tools/loop/run_test_fps.sh <worktree> air_talents tests/ring/test_talents_air.gd [only=<id>,<id>]
```
