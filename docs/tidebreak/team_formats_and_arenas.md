# Team formats, the clan tournament and bigger arenas (2026-10-10)

The owner, 2026-10-10: "use the zelda looks to build different types of arena and dual modes like 4v4 2v2 and teams 1v1 ...
even a tournament clan mode where we have 4 1v1 2 2v2 and then 1 4v4 we need arenas built big enough for these right?";
then "is the square the best way? we can have 3d elements verticals and etc ramps". Build order chosen: team modes on the
bigger decks first.

## Formats and deck sizes

| Format | Deck (w x l) | Per fighter | Zones (neutral + 3 a side) | Spawn line | Respawn line |
|---|---|---|---|---|---|
| 1v1 | 14 x 34 m (today's) | 238 m2 | 4 + 3 x 5 m | s 4.5 m | s 12 m |
| 2v2 | 20 x 40 m | 200 m2 | 4 + 3 x 6 m | s 5 m | s 14 m |
| 4v4 | 28 x 52 m | 182 m2 | 4 + 3 x 8 m | s 6 m | s 18 m |

Room per fighter shrinks a little as teams grow, so team fights stay busy. 52 m is the ceiling: the longest moves reach
about 45 m, and a deck much longer than that splits the fight in two. The numbers live in `data/ring/ring.json` `formats`
(an overlay over the base and the rule set's overlay, like `modes.stock`); `RingArena.set_format` picks one.

## Clan tournament (planned, not built)

- A clan sends 4 players. 4 x 1v1, then 2 x 2v2, then the 4v4 finale; each member plays one 1v1, one 2v2 and the 4v4:
  three matches each.
- Scoring: weighted. A 1v1 win is 1 point, a 2v2 win 2, the 4v4 3 (11 in all: no ties; 6 wins it). Per player that is 1,
  1 and 0.75, so no one player carries the clan. With every match a coin flip the 4v4 decides about 59% of tournaments
  (1 point each: about 31%). The 4v4 is always played, even when the result is settled.
- Real clans need online play, which Tidebreak does not have yet (NetSession is the old open world's). Until then the
  bracket can run against bots.

## Height and cover (next after the team modes)

A flat deck stays right for 1v1 (readable, pure). Team arenas get height and cover, sized to the moves:
step-ups 1-1.5 m (one jump, apex 2.0 m), terraces 2.5-3.5 m (a ramp or the double jump, about 3.6 m together; the ledge
grab works), ramps, bridges, pillars and broken walls for cover and flank routes, nothing over about 4 m. The work it needs:
the arena built of pieces (the main deck plus raised pieces), "out" meaning touching the water rather than leaving one
rectangle, ledges on every piece's edge, wall placement per piece, and a small route map so bots take the ramps.

## The look

Original arenas in a Breath-of-the-Wild-like spirit (soft painted grass, big skies, ruins, lakes), built by us. Never the
files extracted from the Zelda disc (`artifacts/world_reference`, `tools/reference_world`, `data/retarget/botw_*`).
Ring-outs stay "into the water", so every arena keeps water below: a plateau ruin over a lake (earth), a river ford
(water), a crater rim over a crater lake (fire), a cliff-top over the sea (air).

## Built 2026-10-16: the Ruin and Crater arenas

The owner: "we can build a new and better arena with a headless blender", "like earth not the wood", "closer to the water
maybe a oval shape"; from a look board of four he picked **ruin and crater**. `tools/environment/arena/` (README there)
builds them in Blender from `ring.json`'s numbers with our own procedural materials baked to textures, and exports a glTF
per deck size (`assets/arena/<look>/`). `ring.json arenas` lays each over the rule set's numbers (an oval deck 2 m over
the water, the dressing's stands and gates left to the mesh); the match setup's ARENA chips and the Esc menu's Arena row
pick one (Classic stays). The oval's lip is the ellipse everywhere the rules and the bots read it
(`tests/ring/test_arena_shape.gd`). The 2v2 and 4v4 decks (and their Ruins layout pieces) are not built in Blender yet:
those formats play the classic deck until they are.

## Built (team modes)

- `MatchSetup` formats 1v1, 2v2, 4v4 (`team_size`, `lineup`): your side's other fighters and the other side beyond the chosen
  opponent are drawn by lot unless named (`mates=`, `foe=` lists). Practice and Quick match stay 1v1.
- `RingMode`: every bot of both sides spawned at its slot, kept across games, held through each countdown, released at the go;
  a team coach hands each bot a target every couple of seconds (the nearest opponent still in, spread so a side does not all
  pile on one).
- The main menu's match card: a format chooser in its header (a row of its own pushed the card past a 720-high window);
  the rules and sport lines say "2 lives each" in a team format.
- The stands' lamps, posts and awning poles follow the bigger tank (RingDressing out_x / out_z; the 1v1 ring unchanged).
- Checked: `tests/ring/test_team_formats.gd -- format=2v2` and `format=4v4` (bot against bot to DONE, no fall credited to a
  team-mate, the coach spreading the bots; headless a 4v4 physics frame averages about 1.7 ms); stills with
  `tools/ring/team_format_shots.gd -- format=4v4 out=<dir>`.
- Open: a ~130 ms hitch seen once in a headless 4v4 game (not traced yet).

## The AAA bar (the owner, 2026-10-10: "sounds good as a prototype but we need it Triple AAA quality")

An audit of a real 4v4 from the player's own camera (`tools/ring/team_player_view.gd`) found: two fighters both "Gale",
"Ember" on both sides, the hint card over the right plates and the fall line over the hint, "PERFECT!" for a bot's guard, a
1v1 end screen ("YOU vs EMBER", "the Ember sent the Ember flying"), nothing to watch after the last life, and a vast flat
empty deck. The order of work:

1. Team readability (DONE 2026-10-10): every fighter of a team format has his own name (`data/ring/names.json`, drawn by the
   match's seed; RingMode.name_of) on the plates, the fall line, the highlights and the board; the other side always in its
   away kit (sides.json always_teams) and each side its own colour on the plates and the board (team_colours: home teal, away
   coral; a 1v1 keeps the element colours); the hint card under the plates (PercentBar.right_bottom); callouts only for your
   own moments (callouts.json team_self_only); the end screen your team against theirs with THE FIGHTERS roster (falls, %
   dealt, lives lost, the best of each side; RingMode.roster, RingRules.pct_dealt); after your last life a spectator camera on
   your team (RingSpectate, Space for the next; your strip put away, no hints while away).
2. Team arenas with height and cover: a layout is chosen by the owner from top-down plans first.
3. The Breath-of-the-Wild-like art pass: a look board for the owner before building.
4. 8-fighter performance and sound mix; the clan bracket; online.
Still open from 1: the between-games plate (RoundScreen, best of 3) still says "the %s" of the first foe in a team format;
the HUD plates keep round 4's serif (the owner chose the broadcast style for the menus only).

## Built 2026-10-10 alongside (the owner's asks during this work)

- **The Ruins arenas (step 2):** `ring.json formats.2v2/4v4.layout` (RingArena THE LAYOUT): a 3 m perch with stone stairs on
  each team's flank, broken walls, a broken column, turned half round for the other end; the spawns, grates, respawn
  grates and sockets moved clear of them. Walking stops at a raised edge; Shift + Space hops down off it
  (`movement.json piece_edge`, RingMoves._piece_guard/_drop_off; the owner's pick). Bots' places are moved off the pieces
  (RingRules.clamp_for). Checked by `tests/ring/test_ring_layout.gd -- format=4v4|2v2`. The look is still the deck's own
  stone: the art pass (step 3) is next.
- **Stones shatter (the owner: "the boulders and rocks they need to explode", picked: shatter on impact):** in the ring a
  thrown Spike or Boulder (and a deck stone hurled) bursts on what it meets, a fighter, a wall, a piece or the deck: jagged
  shards, dust, a crack; nothing lies after (`moves.json stone_form.shatter`, GustLift._shatter). Its hit is unchanged.
- **Spike and Boulder grow when held (picked: "earth rocks grow when held", like fire's Punch into the Fireball):** held on
  past the full lock by grow_after_s the stone in the hands swells (Spike x1.45, Boulder x1.7) and flies slower and harder
  (`stone_form.grow`, FormEffects.grow_raised); its hit tag `.grown` launches harder (`rules.json` stock.classes). Bots grow
  them too, in the ring only (`bend_ai.json` old.stone_form grow 0.25 / 0.3), never with something coming at them or a
  caught stone in their hands, and from a roll of their own (their dice untouched: every other choice as before); Practice's
  dummy never grows (it throws the same plain stone to learn guards on). Checked by `tests/ring/test_stone_shatter.gd`; stills
  by `tools/ring/stone_shots.gd`. Tests that looked at a thrown stone after it hit were taken at the throw instead
  (test_r3_air, test_r3_combo, test_r2_cast; test_r2_cast keeps its own Spike ungrown as its "move that does not grow").
- Known before this work (they fail the same on the committed code): test_ring_predict 5 checks (the reach model), and
  test_practice's "recover: the dummy put off an end" now and then.
- Known: `tests/ring/test_ring_feel.gd` fails one check whose own baseline (the feel off run twice) does not repeat; it fails
  the same with this work's movement change taken out.
