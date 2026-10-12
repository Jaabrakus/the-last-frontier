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
| Carry the Edge (`air.slice.carry_edge`) | a Slice let go on the Beat while Carried wind is charged is carried and leaves it charged; the Slice adds 10% (11) | `AirTalents.keeps_carry` in `BendEffects._apply` |
| Carrying Wind (`air.gust.carrying`) | a Gust let go on the Beat takes the loose stones it crosses (anyone's) and throws them on 6 m along its way, each a pebble (`rock_jab/pebbles`: 5%, set knock 3; a stone bolt: a Catch holds it, walls stop it); the Gust's lock 0.5 s (0.45) | `AirTalents.on_wind_wave` (BendEffects.wind_wave), `carry_stones` (BendBolt's flight, `carries`) |
| Peak Wind (`air.leap.peak_wind`) | a Leap let go on the Beat charges his Carried wind fresh at its top (no extra height); the Leap's lock 0.3 s (0.25) | `AirTalents.on_dash` (BendEffects.dash: `PeakWatch` on him) |
| Dragon Fire (`air.gust.dragon_fire`) | his Gust through an ally's Fire Wall (or Breath, while its flame is in its smoke: 0.5 s) carries the flame 6 m on as a fire front (a fire floor wave of his: 6%, set knock 6, its own class `air_gust/gust+fire_front`); team only; the Gust adds 9% (10) | `AirTalents.through_ally_fire` / `fire_front` in `BendZone.on_bolt` (before an ally's zone lets it pass); `BendLoadout.worn_class` in `RingRules.on_hit` |
| Near Miss (`air.slip.near_miss`) | a near miss in his Slip counts within 1.44 m (1.2); his Slip 8.5 m/s (9.5) | `AirTalents.near_m` in `BendBolt._near_miss` (tune path `rules:passives.air.near_m`) |
| Second Wind (`air.patch.second_wind`) | his Patch begun within 0.8 s of a dash's end locks 1.25 s, any other time 1.6 s (1.5) | `AirTalents.patch_lock` in `SwayCaster._lock_time` and `NpcBending.lock_for` (a bot: as a share of its own Patch lock) |
| Dust Cloud (`air.slot.dust`) | a new skill on 4 tapped twice: a 3 m dust cloud where he aims (2-6 m, placed like a wall) for 2.5 s that hides as smoke does, one at a time, lock 0.9 s; his Wind Wall stands 3.5 s (4) | a talent mode `air_wall/dust` (moves.json `air_wall.talent_bend.dust`, never in `modes` or `bend`: the Classic fingerprint reads those): `AirTalents.extra_modes` (SwayCaster.my_modes), `modes_for` (Bending.other_move, the hotbar's double tap), `talent_spec` (SwayCaster.spec_of, FormEffects.apply, BendCast.cast), `talent_lock`, `pose_mode` (BendPoses.pick: the Wind Wall's pose), `label` |

The Beat (`skill_tree.json` "beat", the owner's yes): a held cast let go within 0.2 s after its lock fills; never a click,
never a cast that goes by itself. Only a worn technique reads it (`AirTalents.beat_worn`): SwayCaster marks the release
(`rel.beat`, BendR3.release), the cast's hit info carries `beat` (BendR3.info_for), a brief flash on his own hands. With no
technique worn nothing of it exists (Classic's hit info has no `beat` key). Key 3 is always a click (it goes when full); a Beat
wearer who holds key 3 through the full lock keeps it until he lets go (`SwayCaster._key3_beat_hold`), so a Leap can be let go
on the Beat; tapped, key 3 is the click it always was. A bot wearing a Beat technique (a test's) lets a lock go on the Beat at
its difficulty's `beat_rate` (bend_ai.json presets, else easy 0, normal 0.2, hard 0.5), within 0.2 s of its full lock.

Two nodes that set the same number to the same value (Tailwind and Carry the Edge: the Slice's d 10; Full Sail and Carrying
Wind: the Gust's lock 0.5) no longer refuse each other when worn together (`BendLoadout._fold`: a clash is two values).

Notes:
- A bot can cast a worn new skill through its own path (BendCast.cast), but no bot mind picks Dust Cloud (bots never wear
  loadouts in a match; a mind that places dust is for when they do).
- Second Wind's quick lock has its own path in the tree (`new:patch.after_dash_lock_s`, from `stock:patch.lock_s`): its two
  Patch locks were the one number `stock:patch.lock_s` set twice, which a node may not do (2026-10-11).
- Near Miss and Second Wind change tune paths only, but needed the seam code, so they are listed in `behaviour` too (that is
  also how tests/ring/test_loadout_apply.gd picks them up).
- Dragon Fire is greyed out in 1v1 by the Advancement window's rules (no ally there); in the match it simply never meets an
  ally's fire.
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
