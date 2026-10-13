# The in-ring Rise and the perfect guard's cast reward — 11 October 2026

From the owner's play the same evening: "the tripple jump should allow the arena jump back button right it would be easier
with its own cooldown maybe? inside the ring?", and, told how the Kick's tap and hold differ: "maybe we have casting times? i
think we need where if users ... do a perfect parry E they can cast faster a littler and the person that got parried or E has a
slightly slower cast time?" His answers:

- **The in-ring Rise:** its own cooldown, the Rise for the way back kept; 6 s.
- **The reward:** only a perfect E on a spell counts ("if the user E a spell the it has to have that perfect thing they get
  one faster move cast buff"); 15%, within 3 s.

## The in-ring Rise (the triple jump)

Space, Space, then a third Space over the deck (0.2 s or more after the double jump, `double_jump.rise_after_s`) is the
element's Rise, as off the deck: earth's Pillar 5.5 m, water 4.5 m, fire's Jet 7.5 m along the aim (its 20-degree floor), air
3.5 m and its glide. Over the deck it goes straight up from where he is (the Pillar does not lean toward a lip; its tell and
its column show where he is, not at the nearest lip).

- **Its own cooldown:** once every `rise.ring_cooldown_s` (6 s, `data/ring/movement.json`) from its start
  (`RingMoves.ring_rise_ready`). Within it a third Space over the deck does nothing, as before.
- **The way back kept:** it never spends the airtime's Rise (`rise_ready`): knocked off the deck after an in-ring Rise, the
  Rise to get back is still there. An airtime whose Rise the way back spent has no in-ring Rise.
- **The rest is the Rise's own:** free air control after it, the 0.35 s landing lag, its hit on whoever it meets (the Pillar's
  8%, the others' few).
- **The HUD:** the Rise pip on his plate (`PercentBar.pips`) shows the Rise a press would give: over the deck the in-ring one
  (dim while its cooldown runs, the soft tick when it is back), off the deck the way back's.
- **Bots** do not use it (their recovery plans are unchanged).

## The perfect guard's cast reward

A perfect guard (E on the beat) of a spell, in the % ring: the guarder's next cast locks in 0.85 of its time, and the one he
parried casts his next at 1.15 (`rules.json` `stock.parry`: `k` 0.15, `window_s` 3.0).

- **One cast each:** the next lock takes it and its cast spends it (`BendStatus.parry_reward`, `cast_mult`, `spend_cast_mult`);
  a lock dropped before it casts keeps it. Unused, it is gone 3 s after the guard. A new perfect guard sets it anew.
- **What counts:** every guard result goes through `BendZone._result`; a perfect one on any spell (a bolt, a stone, a cone,
  lightning on a fire Parry, a shield block) rewards its owner and penalizes its caster (read before a send-back makes the bolt
  the guarder's). A late guard: nothing. A guard's own lock never takes it (E again stays E's own time).
- **Where it applies:** the player's lock (`SwayCaster._lock_time`, spent in `_cast`) and a bot's (`NpcBending.begin`, spent
  in `_release`): a bot parried casts slower too, a bot that parries casts faster.
- **Not shown yet:** no look or sound of its own; the guard's own perfect flash and sound tell it.

## Tests

- `tests/ring/test_ring_moves.gd` (jumps): over the deck a third Space is the in-ring Rise, the way back's kept, straight up
  (0.0 m off, 8 m up for water); again within its cooldown nothing; earth's Pillar straight up; its cooldown over after 6 s;
  off the deck the Rise as before.
- `tests/bending/test_r3_guard.gd` (the reward): a perfect fire Parry: the guarder x0.85, the shooter x1.15; his next lock
  0.30 s from 0.35, the shooter bot's 0.35 s from 0.31; his cast spends it (a dropped lock does not); late nothing; unused,
  gone after 3 s.
