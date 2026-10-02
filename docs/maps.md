# Maps for the main story

DRAFT v1 (2026-10-01). Nothing here is built. It plans the maps that Two Fires
(`docs/main_story.md`) needs. Each map is built the way the valley is built today: a
grid of 832 m squares (`data/world/squares.json`, `WorldSquares`, terrain from
`tools/environment/terrain/bake_terrain.py`), each square a type with its own woods,
stone, water and animals. Historical claims use the project's basis keys; every H
still has to be checked.

## The maps at a glance

| # | Map | Grid | Story parts | Years | State |
|---|---|---|---|---|---|
| 1 | **The Mohawk Valley** | 3×3 (exists) | Prologue, Part 3 (The Ford), Part 4 | 1757, 1765, 1775 | The fort's square is built; the other 8 aren't |
| 2 | **The North Woods town** | 3×3 | Parts 1 and 2 | 1757–60 | New |
| 3 | **The Mountain Road** | 2×4 (long) | Part 3 (the pack trains) | 1763–65 | New |
| 4 | **Albany** | 1×2 (a town) | Part 3 and Part 4 missions | 1765, 1770s | New |
| — | **The travel map** | not a 3D map | Between all of them | all | New |

Five 3D maps is a lot for one game. The build order at the end puts them in the order
the story needs them. The valley comes first because it already exists.

## How a map works

- **A map is a folder of data, the same as the valley today:**
  `data/world/maps/<map>/squares.json` (the grid, the river or lake, the types),
  plus its terrain bake, its places and its people.
- **Year layers.** A map has one terrain but a layer per year: which buildings stand,
  are ruined or haven't been built, who lives where, what's planted. A storyline picks
  the year. For example, the valley in 1757 has German Flatts farms and no fort at the
  ford, in 1765 the post in its last season, and in 1775 the post in ruins and the
  valley split. Layers are data (`year_layers.json`: place id, state, model), so a new
  storyline adds a layer and reuses the terrain.
- **The world remembers within a storyline.** Whatever the player burns or builds stays
  that way while that storyline's years run. A new storyline starts from its own year
  layer.
- **Leaving a map** happens at its edges: a road, a river or a trail goes onto the
  travel map.

## 1. The Mohawk Valley (exists, needs filling in)

The level the game already has. Squares (rows north to south):

| | west | middle | east |
|---|---|---|---|
| north | old woods | woods ridge | cliffs |
| middle | deep woods | **the fort's woods** (built) | open land |
| south | marsh | field land | lake |

**What the story adds:**
- **German Flatts** in the field land square (the south middle): a scatter of farms, a
  stone house and a church (H: the Palatine settlement; Fort Herkimer was the stone
  house and church fortified in 1756; verify). It's the neighbours in the Prologue, the
  1757 raid at night, and the farm family's home in 1765.
- **The player's homestead plot** in the open land (the middle east), across the river:
  the Prologue's tutorial. It's empty land with a spring, a meadow for the horse and good
  timber.
- **The ford's post** in the fort's woods. It is built already; the 1757 layer removes it.
- **The Carry** off the north-west edge: the trail toward the Oneida Carry and Fort
  Stanwix, leaving onto the travel map.
- **The lake** in the south-east square: the boats' lake, already planned.

**Year layers:** 1757 (no post, farms whole, then burned), 1765 (the post leaving, the
Flatts rebuilt), 1775 (the post in ruins; a liberty pole at the Flatts; Loyalist farms
abandoned).

## 2. The North Woods town (Parts 1 and 2)

*Where you're taken after the raid: a town on a river in the north, your new family's
home, and the place that burns in 1759.*

**This map is the one under the consultation rule.** Its layout, houses, fields, the
people and its burning are designed with the office of the nation whose town it is, and
the nation isn't chosen yet (Abenaki at Saint-Francis/Odanak, Kahnawake Mohawk or a
Seneca town are the candidates; H). What can be designed now is the land, and what the
story needs from the map. The town itself stays a marked area until then.

| | west | middle | east |
|---|---|---|---|
| north | big timber (old-growth pine and hemlock: the climbing woods) | hunting grounds (deer, moose, bear) | beaver meadows and ponds |
| middle | the cornfields and orchards | **the town** (on a bluff over the river) | the river landing and canoe beach |
| south | sugar bush (maple) and the winter hunting camp | the river trail south (toward the war and the valley) | marsh and wild rice |

**What the story needs from it:**
- **Learning places**, each tied to a system the game already has or plans: the climbing
  woods (climbing), the hunting grounds (the bow and tracking), a horse meadow (horses),
  the river (canoes, the boat stand), the winter camp (snowshoes, the sugar bush).
- **A town big enough to live in** for two in-game years: your family's house, the
  neighbours' houses, the fields, the council place, the landing. Day schedules for
  the people, the same NPC systems as the valley.
- **The 1759 dawn raid.** The town's 1759 layer burns it. The approach the rangers take
  (from the south marsh) has to be readable, so the player can try to warn people or
  fight.
- **Seasons matter more here than anywhere:** the planting, the summer, the harvest, the
  winter camp and the sugaring are what a year of the town's life looks like.

## 3. The Mountain Road (Part 3)

*1763–65: the frontier boils over. British troops hold the forts, traders' pack trains
carry goods west over the mountains, and frontier men in blackened faces stop them.*

H: modelled on the road over the Pennsylvania ridges (the Forbes Road, Sideling Hill,
Fort Loudoun) where the "Black Boys" stopped pack trains in 1765; verify. A long map,
because the story is about a road:

| | west | east |
|---|---|---|
| row 1 | the far valley and the trading post | the British fort (stone and earth, cannon) |
| row 2 | a gap through the ridge (the ambush pass) | the tavern and the crossroads farms |
| row 3 | the ridge top (cliffs, laurel, lookouts) | a frontier settlement (cabins, a mill) |
| row 4 | the last farms and the road east | the road down to the settled country |

**What the story needs from it:**
- **The road itself** as the main path: pack trains of horses on it (the horse and cart
  systems), switchbacks, the pass for ambushes.
- **The British fort**: soldiers, a gate, a guardhouse for a breakout mission.
- **The tavern**: the crime contacts, cards and fights (Sarah Kerr's role moves here,
  or a new tavern keeper).
- **Hideouts** in the ridge's cliffs for the outlaw life and for losing a hue and cry.

## 4. Albany (Part 3 and Part 4)

*The Hudson river town where the money is: Hollis and Company's warehouse, the
courthouse, the docks, the taverns and later the committees of the Revolution.*

H: Albany in the 1760s was a Dutch-built town of a few thousand people, with a fort
on the hill and a stockade; verify. A small, dense map:

| | river side | hill side |
|---|---|---|
| row 1 | the docks, sloops and the warehouses (Hollis and Company) | the fort on the hill |
| row 2 | the market street, the taverns, the courthouse | the church, the merchants' houses, the stockade gate out |

**Why a town:** heists, chases through streets, a courthouse for the trials, and in
Part 4 the committees, the broadsides and the Loyalist houses. It's the GTA "city" of the
game, small and dense next to the open maps. It's also the most new building work: a
street of Dutch town houses, which nothing in the game has yet.

## The travel map

*Between the 3D maps: a hand-drawn map of the north-east, period style.*

- You pick a route (the river, a trail, the road), and the game moves you along it in
  days. Your pack, horse and household come along; hunger and the weather keep running.
- **Stops on the way** are short scenes or small encounters (a camp, a river crossing,
  a party on the road, an ambush) that load a small piece of land made from the nearest
  map's square types.
- **The march north after the raid** (the Prologue's end) is played on the travel map as
  a forced journey with your gear taken.
- The backlog's M5 milestone ("the map: the Carry, the valley, the town and the hunting
  grounds, travel and camps") already plans travel and camps; this becomes its design.

## New designs the maps need

| Design | For | Notes |
|---|---|---|
| German Flatts farmhouses, barn, the stone church | Map 1 | The Palatine stone house style (H, verify) |
| The post in ruins (1775) | Map 1 | The existing fort, damaged |
| The town's houses, fields and council place | Map 2 | Only with the nation's office |
| Winter hunting camp, sugar camp | Map 2 | Partly the game's own shelters |
| A British stone-and-earth fort | Map 3 | Bigger than the stockade, with cannon |
| Tavern, crossroads farms, a mill | Map 3, 4 | The mill also fits the valley later |
| Pack train: pack saddles, loads, drivers | Map 3 | On the existing horse system |
| Dutch town houses, warehouses, a courthouse, docks, a sloop | Map 4 | The biggest new set |
| Clothing for each community | All | `graph_analysis/customizer/costume_bible.md` is the source |
| The travel map's art | Travel | One painted map image, routes and stops |

## Build order

1. **The valley's 1757 layer and the homestead plot**, so the Prologue (the tutorial and
   the raid) can be played. The terrain exists, and only German Flatts and the homestead
   are new.
2. **The travel map**, with the forced march north. It links everything that comes later.
3. **The North Woods land** (terrain, the learning places, seasons), with the town as a
   marked area, while the consultation goes on.
4. **The Mountain Road.**
5. **Albany.**
6. **The valley's 1765 and 1775 layers**, for The Ford and Part 4.

## Open questions for the owner

- **Map size.** The valley is 3×3 squares (about 2.5 km a side). Should the new maps be
  that big, or smaller and denser to make five maps realistic?
- **Albany or Boston?** Boston is where the famous Part 4 events happen (1770, 1773),
  but it's a big city to build. Albany is smaller and tied to the valley's story. The
  Boston events could reach the player as news and broadsides instead.
