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
| Toxic Gale (`air.ball.toxic_gale`) | his Wind Ball through gas bursts it 4 m on along its way into a radius-4 cloud with the time it had left, his now (a foe's gas blown back at him, an ally's spread); his Wind Ball adds 10% (11) | `AirTalents.toxic_gale` first in `BendZone.on_bolt` for a zone of kind `gas`: built against the gas zone's interface (kind, owner_node, radius, t, life_s). The gas is earth's Sulphur set (its own lane, tb/talents-earth-p1: BendGas); in this branch nothing makes gas, the test makes a gas zone as that set does. On the merge keep this line before the gas's own `BendGas.react` line, so a Toxic Gale Wind Ball bursts the cloud instead of the plain wind carry |
| Drift Guard (`air.guard.drift`) | walks at 1.5 m/s with his Wind Guard up (Classic: no walking); walking under it, a direction key pressed steers the walk; standing under it, a key pressed is the guard's Roll as ever; its beat 0.25 s (0.3) | `AirTalents.guard_walk` in `RingMoves._ground_physics`, `drift_steers` in `RingMoves._try_ground_dodge`; `SwayCaster._root` and a bot's `shield_tick` let him walk |
| Eye of the Gale (`air.guard.eye`) | E held through a perfect Wind Guard: the bounced air circles him (up to 0.6 s) and leaves along his aim (x1.2) when E is let go; the perfect guard's Carried wind 0.4 s (0.8); a bot wearing it (a test's) holds each catch 0.2-0.45 s of its own choosing, then sends it along its aim | `AirTalents.eye_catch` in `BendZone._guard_bolt` (BendBolt's swing, held by `swing_hold`: the player's E, a bot's `bot_eye_s`); `carry_wind(body, s)` |
| Rebound (`air.guard.rebound`) | his next Slice or Wind Ball begun within 1 s of a perfect Wind Guard starts its lock 40% full (once); his held guard drops at 2.0 s (2.5) | `AirTalents.on_guard` (BendZone.report), `start_fill` (SwayCaster._try_begin; NpcBending.begin, a share of the bot's whole lock, its parry cast reward in it); the tune path `rules:air_rules.guard.hold_max_s` |
| Carry the Edge (`air.slice.carry_edge`) | a Slice let go on the Beat while Carried wind is charged is carried and leaves it charged; the Slice adds 10% (11) | `AirTalents.keeps_carry` in `BendEffects._apply` |
| Carrying Wind (`air.gust.carrying`) | a Gust let go on the Beat takes the loose stones it crosses (anyone's) and throws them on 6 m along its way, each a pebble (`rock_jab/pebbles`: 5%, set knock 3; a stone bolt: a Catch holds it, walls stop it); only loose stones (FormStone's `LOOSE_META`), and only while the Gust is still his (sent back or turned, it carries nothing more); the Gust's lock 0.5 s (0.45) | `AirTalents.on_wind_wave` (BendEffects.wind_wave), `carry_stones` (BendBolt's flight, `carries`, its caster `CARRY_BY_META`) |
| Peak Wind (`air.leap.peak_wind`) | a Leap let go on the Beat charges his Carried wind fresh at its top (no extra height); the Leap itself is Classic's (key 3 is a click: it goes at its full lock held or tapped); the Leap's lock 0.3 s (0.25) | `AirTalents.on_dash` (BendEffects.dash: `PeakWatch` on him); the let go read by `SwayCaster._key3_beat_watch` (`AirTalents.key3_cast`, `key3_let_go`) |
| Dragon Fire (`air.gust.dragon_fire`) | his Gust through an ally's Fire Wall (or Breath, while its flame is in its smoke: 0.5 s) carries the flame 6 m on as a fire front (a fire floor wave of his: 6%, set knock 6, its own class `air_gust/gust+fire_front`); team only; the Gust adds 9% (10) | `AirTalents.through_ally_fire` / `fire_front` in `BendZone.on_bolt` (before an ally's zone lets it pass); `BendLoadout.worn_class` in `RingRules.on_hit` |
| Near Miss (`air.slip.near_miss`) | a near miss in his Slip counts within 1.44 m (1.2); his Slip 8.5 m/s (9.5) | `AirTalents.near_m` in `BendBolt._near_miss` (tune path `rules:passives.air.near_m`) |
| Second Wind (`air.patch.second_wind`) | his Patch begun within 0.8 s of a dash's end locks 1.25 s, any other time 1.6 s (1.5) | `AirTalents.patch_lock` in `SwayCaster._lock_time` and `NpcBending.lock_for` (a bot: as a share of its own Patch lock) |
| Dust Cloud (`air.slot.dust`) | a new skill on 4 tapped twice: a 3 m dust cloud where he aims (2-6 m, placed like a wall) for 2.5 s that hides as smoke does, one at a time, lock 0.9 s; his Wind Wall stands 3.5 s (4) | a talent mode `air_wall/dust` (moves.json `air_wall.talent_bend.dust`, never in `modes` or `bend`: the Classic fingerprint reads those): `AirTalents.extra_modes` (SwayCaster.my_modes), `modes_for` (Bending.other_move, the hotbar's double tap), `talent_spec` (SwayCaster.spec_of, FormEffects.apply, BendCast.cast), `talent_lock`, `pose_mode` (BendPoses.pick: the Wind Wall's pose), `label` |
| Frostwind (`air.set.frostwind`, the skill set) | his Gust or Wind Ball turns a puddle or a grate it crosses into frost crust (a snow ridge 0.4 m high, 3 m long across its way, 4 s; two of his at once); floor waves and rolling stones stop at it, anyone can jump it, never slippery; a frozen grate is no water source till its crust goes (however it goes: melted, crumbled, capped, or cleared by the round's reset); steam it crosses falls as snow and clears; water and ice his Wind Wall meets fall as shards; fire (a fire bolt, a Fire Wall or burning ground on it, a Breath) melts a crust back into its puddle, a grate's back into the grate; mud never freezes (only puddles do); his Wind Wall 3.5 s (4) | `AirTalents.frosts` (BendBolt.launch sets `frosts`), `frost_step` (its flight; only while the bolt is still his), `freeze_pool` / `make_crust` (a snow FormRaised with a `CrustWatch`: the grate back on `crumbled` or `_exit_tree`), `melt_crust` (BendBolt._hit), `wall_shards` (BendZone.on_bolt); a bot's `NpcBending._wall_on_line` skips a crust |
| Hail Ball (`air.frost.hail_ball`) | where his Wind Ball hits or ends its flight, 3 hailstones fall 1.2 m round it (the first along its way), each 2% to a foe within 0.8 m of where it falls, no knock, no flinch, no hurt (its whole class `matter/hail` the node's); the ball's knock base 7 (8); it is still air for every guard and wall | `AirTalents.hails` (BendBolt.launch sets `hails`), `hail_burst` (BendBolt._finish); `BendLoadout.worn_class` |
| Frost Gust (`air.frost.frost_gust`) | his Gust puts out a foe's Fire Wall or burning ground it crosses (a Gust is a wave from the deck up: the low burning ground under it counts); 1.8 m wide (2) | `AirTalents.snuffs` at the top of `BendZone.on_bolt` (its own crossing test) |
| Rime Wall (`air.frost.rime_wall`) | when his Wind Wall ends it drops a 3 m crust where it stood, along it, for 3 s; while it stands it is the same Wind Wall, pushing at 3.2 m/s (4) | `AirTalents.on_wall_end` in `BendZone.end`; a wind wall's push is its spec's `push_mps` (Classic's 4.0, as `WIND_WALL_KNOCK` was) |
| Blizzard (`air.frost.blizzard`) | a new skill on 4 tapped twice: a 2.5 m snow column 2-10 m off where he aims for 3 s, one at a time, lock 0.9 s; it hides both ways (snow in `NpcBendCaster.HIDING`), freezes the water in it to crust, a foe inside gains 1% each 0.5 s (6% at most; its whole class `matter/cold` the node's; no knock, no hurt), fire on it (a fire bolt, a Fire Wall or burning ground, a Breath) melts it out in 1 s; his Wind Wall 15% shorter (3 s with the set's 3.5) | talent mode `air_wall/blizzard` (moves.json `air_wall.talent_bend.blizzard`); `AirTalents.snow_every` (BendZone._every of kind `snow`), `melt_snow` (a fire bolt in it: BendZone.on_bolt; a Fire Wall or burning ground on it; a Breath: `breath_melt` from BendEffects.cone), `wall_life_k` (BendEffects' wind_wall) |
| Whiteout (`air.frost.whiteout`) | standing on his own crust or in his own Blizzard his locks fill x1.15; Patch 1.7 s (1.5) | `AirTalents.home_fill` in `SwayCaster._hold` and NpcBending's lock; `patch_lock` |

The Beat (`skill_tree.json` "beat", the owner's yes): a held cast let go within 0.2 s after its lock fills; never a click,
never a cast that goes by itself. Only a worn technique reads it (`AirTalents.beat_worn`): SwayCaster marks the release
(`rel.beat`, BendR3.release), the cast's hit info carries `beat` (BendR3.info_for), a brief flash on his own hands. With no
technique worn nothing of it exists (Classic's hit info has no `beat` key). Key 3 is always a click and stays one for a
wearer too: the Leap goes the moment its lock is full, held or tapped, as Classic's (2026-10-12: the first build held a Beat
wearer's full key-3 lock until the let go, which delayed his Leap and let it fizzle past `release_s`; gone). Its Beat is read
from the let go instead: key 3 still held as the Leap goes and let go within 0.2 s of the full lock (`SwayCaster.
_key3_beat_watch`, `AirTalents.key3_cast` / `key3_let_go`: the note `air_k3_beat` on him, the flash on his hands at the let
go) is on the Beat, and the Leap's `PeakWatch` charges his Carried wind at its top (the Leap rises longer than 0.2 s, so the let
go is known before the top). Tapped (let go before full), let go later, or held on past the window, it is not. A bot wearing a
Beat technique (a test's) lets a lock go on the Beat at its difficulty's `beat_rate` (bend_ai.json presets, else easy 0, normal
0.2, hard 0.5), within 0.2 s of its full lock. Online the Beat travels with the cast: `NetCasts.begin` puts `beat` in the cast
event only when it was on the Beat (Classic's events are as before), and every other machine replays the release with it
(`NetCasts.release_of`), so the host decides a joiner's Beat Gust's stones and his Beat Slice's kept wind as his own machine
did (read from the code: the net tests cannot connect in the test machine). The Beat's cue is a small air burst at the
wearer's own hands (`BendLooks.burst`, an existing look; nothing on anyone else, nothing on the HUD, only with a Beat technique
worn): new on screen, for the owner to see.

Two nodes that set the same number to the same value (Tailwind and Carry the Edge: the Slice's d 10; Full Sail and Carrying
Wind: the Gust's lock 0.5) no longer refuse each other when worn together (`BendLoadout._fold`: a clash is two values).

Notes:
- The tick contract's `no_hurt` (hail, cold): such a hit skips the struck one's hurt reaction (`BendR3.take`: no `took_hit`,
  so no Lightning-charge break; `BendStatus.hurt`: no `hurt` signal), and `no_flinch` keeps it out of the string and the stale
  queue (RingRules.on_hit returns before them). A body takes one matter tick each 0.5 s from any matter (meta
  `bend_matter_tick_at`, shared so the other elements' matter can read it too).
- Blizzard's two tree changes (2026-10-11): its cold tick's class `class:matter/cold` was only named in its `new` text, so it is
  written as Hail Ball's `class:matter/hail` is; its Wind Wall trade was `spec:air_wall/wall.life_s` 4.0 to 3.4, the number the
  set it requires sets to 3.5 (two values: a clash that refused Blizzard whenever it was worn), now `new:air_wall.wall_life_k`
  1.0 to 0.85 (its own note: it multiplies with the set's 3.5).
- tests/ring/test_loadout_apply.gd wears each live node with the nodes it requires (a set's nodes with their set), their changes
  counted as named.
- A bot can cast a worn new skill through its own path (BendCast.cast), but no bot mind picks Dust Cloud (bots never wear
  loadouts in a match; a mind that places dust is for when they do).
- Second Wind's quick lock has its own path in the tree (`new:patch.after_dash_lock_s`, from `stock:patch.lock_s`): its two
  Patch locks were the one number `stock:patch.lock_s` set twice, which a node may not do (2026-10-11).
- Near Miss and Second Wind change tune paths only, but needed the seam code, so they are listed in `behaviour` too (that is
  also how tests/ring/test_loadout_apply.gd picks them up).
- Dragon Fire is greyed out in 1v1 by the Advancement window's rules (no ally there); in the match it simply never meets an
  ally's fire.
- Drift Guard: standing under the guard, a direction pressed fresh is the guard's Roll (RingMoves' ground dodge, as for
  everyone). Walking under it (faster than 0.5 m/s: he held a direction as he raised it, or kept one held), a direction pressed
  steers the walk instead (`AirTalents.drift_steers`; the player's keys only: a bot's Roll is its own press). To roll from a
  walk under the guard he stops first. A bot wearing it walks with its shield up as its mind orders (`shield_tick` leaves its
  walk to RingMoves' 1.5 m/s cap; tested).
- Eye of the Gale: E held is the player's guard button (SwayCaster._guard_down). A bot has no E: a bot wearing it holds every
  perfect catch of its guard (a shield or a guard on the beat) for 0.2-0.45 s by its own dice (`AirTalents.bot_eye_s`), then
  sends it along its aim at its foe. Online, the swing's hold is the host's; the other machines see the swing until the host's
  word turns the bolt.
- Rebound's head start is the lock contract's "techniques may start a lock part-full"; never a zero lock. A bot's is 40% of its
  whole lock, set after its lock's own changes (the perfect guard's cast reward among them: 2026-10-12, it was set before them
  and came to 47%).
- Frostwind and Carrying Wind act only while the bolt is still the wearer's own (sent back, turned or caught by someone else, it
  freezes and carries nothing more for anyone); Hail Ball reads its wearer at the ball's end (a ball a non-wearer sent back
  drops no hail).
- A frost crust is a FormRaised of kind `wall` 0.4 m high: a foe bot's `NpcBending._wall_on_line` (its High Kick's
  `foe_up_or_walled`) does not count it as a wall. Nobody walks over it (no step-up on the deck): the player jumps it, and a bot
  running at one across its way jumps it (`AirTalents.crust_ahead` in `NpcFighter._ring_move`; 2026-10-12: a bot ran into it
  and stood there till it melted). While no crust stands, `crust_ahead` returns at once (`_crusts_up`, counted by the crusts'
  `CrustWatch`), so a Classic match reads nothing of it.
- Toxic Gale needs a test after the merge with earth's lane (nothing makes gas in this branch; the test makes a gas zone by
  hand): the stolen cloud's ticks hurting its old owner (BendGas.tick reads `owner_node` and `inside`), the order of
  `BendZone.on_bolt`'s first lines (Toxic Gale before `BendGas.react`), and a stolen cloud not counted in `BendGas._cap`'s 4 a
  caster.

Run:
```
zsh tools/loop/run_test_fps.sh <worktree> air_talents tests/ring/test_talents_air.gd [only=<id>,<id>]
```

For the merge of the four lanes (2026-10-11):
- The Beat is built in the earth lane too (tb/talents-earth-p1: `BendLoadout.beat_s` / `beat_paid`, `BendLooks.beat_flash`,
  the same `rel.beat` in `SwayCaster._cast` and `beat` in `BendR3.info_for`). Keep one: earth's gate and flash, with air's
  per-move check (`AirTalents.beat_worn`: an air technique pays only its own move's Beat) and air's key-3 let go read
  (`SwayCaster._key3_beat_watch`, `AirTalents.key3_cast` / `key3_let_go`: key 3 stays a click, its Beat read from the let go
  after the Leap went), the Beat on the wire (`NetCasts.begin` / `release_of`), and the bot's release on the Beat
  (`NpcBending._release`) once.
- tests/ring/test_loadout_apply.gd wears each live node with the nodes it requires in both lanes (the same intent).
- `BendZone.inside`'s round kinds: earth adds `gas`, air adds `snow`. `BendZone.on_bolt`'s first lines: air's Toxic Gale before
  earth's gas reactions. The matter tick's meta is `bend_matter_tick_at` in both (one tick a body each 0.5 s from any matter).
- `BendLoadout.TUNE_PATHS`: each lane appends its own paths at the end.
