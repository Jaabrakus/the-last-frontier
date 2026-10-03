# Maps for the main story

DRAFT v2 (2026-10-02). Nothing here is built except the valley's two baked squares. v2 replaces v1's
five maps (the valley, the North Woods town, the Mountain Road, Albany and a travel map) with the set the
v5 main story needs (`docs/main_story.md`): you start out primitive in the valley, the wonder breaks in,
you sail the sky, and you end in a bustling city of pyramids. Historical claims use the basis keys
(S / H / D); every H still has to be checked.

## The maps at a glance

| # | Map | Kind | Size | Story | State |
|---|---|---|---|---|---|
| 1 | **The Mohawk Valley** | Terrain, 832 m squares | 3×3 squares, ~2.5 km a side | Acts 1-2, the Home ending, *The Fallen Ship*, *The Ford* | Exists. 2 of 9 squares baked (`fort_woods`, `open_land`); the slice needs only these |
| 2 | **The galleon** (*Long Patience*) | Vehicle scene | Hull ~26 m, ~32.5 m overall, beam 7.5 m, 2 masts | Acts 3-4, crew co-op | Model in progress (`tools/models/sky_galleon.py`); not exported |
| 3 | **The Upper Sea** (the Drift) | Sky map, no terrain | 3 reaches, each ~1.5 km across and 600 m tall | Act 3 | New |
| 4 | **Wreck fields** | Sky map, no terrain | ~1 × 1 km, 300-400 m tall | Co-op raids from Vessary | New; the first reuses reach 2 |
| 5 | **Vessary** (the Ninepins) | Terrain, 1 square | 832 m, dense core ~600 × 450 m | Act 4, the hub, free roam | New |
| 6 | **The Hollows** | Interior | ~400 m of galleries | Act 4, a hideout | New |

**New terrain: one square** (Vessary), plus one optional valley square (the cliffs, as a backdrop for the
wreck). v1 planned 19.

## The Mac mini budget (every map)

The owner's M4 Mac mini sets the rules. These hold on every map:

- **Medium preset at 60 fps** is the target (today's forest frame is 12-17 ms on medium, 26-35 ms on high).
- **At most 12 animated people on screen.** NPCs use AnimationPlayer bodies with animation level of detail
  like the animals' (`WildAnimal._step_anim`); a full player animation tree costs about 2 ms each.
- **Crowds are walking cards** baked from Actor_B in the period garments (8 directions, moved along lanes by
  a shader). A card swaps for a full body only within about 15 m, and only when a mission needs it.
- **One shared fire light, no fire shadows** per scene (a torch light is 0.55 ms, 1.4 ms with its shadow).
  Other fire, lamps and glows are emissive materials and particles.
- **No open water and no long open sight lines.** Sky maps use haze and fog walls.
- **Ships:** at most 2 near in a fight; `Galleon_LOD1` (under 3,000 triangles) past 450 m.
- **Streaming:** detailed trees, grass, collision and simulation only in the player's square and its 8
  neighbours (in co-op, the squares near any player). Terrain is about 11 MB a square on disk, so memory
  is not the problem; detail near the camera is.
- **Co-op:** 8 players on a host Mac; 12 only after animation LOD for remote players; 16 on a headless
  server only.
- **The "Cool" preset** (30/40 fps cap, 0.75 render scale with MetalFX, 2 shadow splits) is a fallback,
  not a budget. Menus run at 30 fps with low-processor mode.
- **Development heat:** bake one square at a time (`bake_terrain.py --square X,Y`); one Blender process at
  a time.

## How a map works

- **Four kinds of map.**
  - **Terrain maps** are built the way the valley is: a grid of 832 m squares
    (`data/world/maps/<map>/squares.json`, `WorldSquares`), each a type with its own woods, stone, water and
    animals, baked by `tools/environment/terrain/bake_terrain.py`.
  - **Sky maps** have no terrain at all: the wonder sky, haze, cloud cards and instanced floating islands
    from a kit. They are the cheapest maps in the game.
  - **The vehicle scene** is the galleon. It is a level that moves: the world's origin follows the ship, and
    players and dropped items are held in the ship's own space (moving-platform sync, M, for co-op).
  - **Interiors** stream in as rooms, with occlusion culling on.
- **Year layers.** A terrain map has one terrain and a layer per year: which buildings stand, are ruined or
  are not yet built, who lives where, what is planted, which animals live there. Layers are data (place id,
  state, model), so a storyline picks a year and reuses the terrain.
- **The world remembers** within a storyline: what the player burns or builds stays that way.
- **Moving between maps** happens through the story or the ship. The *Long Patience* rises from the valley
  into reach 1; reaches join through fog-walled currents that hide the loading; Vessary's Tether Gates lead
  out to the wreck fields; the closing tide of 1761 takes you home. No travel map is needed.

## 1. The Mohawk Valley (exists; needs its layers)

Squares, rows north to south. The river runs north to south through the east column (its centre at
x0 = 832 m, meandering about ±95 m), flowing south, with rapids at z ≈ -250, 60 and 300.

| | west | middle | east |
|---|---|---|---|
| north | old woods | woods ridge | cliffs (optional bake: the wreck's backdrop) |
| middle | deep woods | **the fort's woods** (baked) | **open land** (baked) |
| south | marsh | field land | lake |

**The bank swap** (critic B10). The settlement that burned in 1757 was on the real north bank, and Fort
Herkimer on the real south bank held (H). In the game, the stockade stands in for Fort Herkimer **west** of
the river, so the game's west bank is the real south bank and its **east** bank is the real north bank.

**What the story adds:**
- **Fort Herkimer** (the stockade, in the fort's woods): the palisade, the store where Vane keeps his
  partner's accounts, and the **church with unfinished walls** (H: built 1753-67).
- **The ford** at the rapid at z ≈ 60, between the fort's side and the farms.
- **The Flatts farms and the mill** east of the river in the open land (H: about 60 houses, barns and a
  water-mill burned; the game shows a handful). The mill sits on a small creek cut into the bake (S).
- **The homestead** at about [1000, 100], east of the river: the Prologue's ground.
- **The raiders' camp and the wreck** at the head of the open land, about [1100, -380], near the upper rapid,
  in a stand of pines the 1757 layer adds. Both squares are baked, so the slice needs no new bake. The real
  force stayed through 13 November and drove back a sortie (H), so a camp close to the farms on the first
  night is fair. If the open land can't carry a convincing pine stand, bake the cliffs square (M) and put
  the wreck under its edge.
- **The frozen river** for *First Lesson*; the spring flood at the ford for *Noon Warning*.
- **The mast clearing** for *Broad Arrow* and *The Mast-Runners*: the three great pines are felled in the
  fort's woods and hauled across the ice.

**Year layers:**

| Layer | For | What changes |
|---|---|---|
| **1757** | Act 1 | Farms whole, the church unfinished, the homestead empty ground. **No mammoths and no bison** in any square (H: no record of bison in the valley then; verify). Free play keeps the sandbox numbers |
| **Winter 1757-58, burned** | Act 2, *The Fallen Ship* | Farms in ruins, your house a black square with its stone root cellar, snow, the wreck in the pines; in spring the flood and the mast clearing |
| **1761** | The Home ending | Farms rebuilding, the church walls higher, your clearing grown with birch (the backlog's 1761 start) |
| **1765** | *The Ford* | The garrison's last season, the Flatts rebuilt |

**Budget:**
- As today: 12-17 ms in the forest on medium.
- The raid: at most 10 fighters plus 2 neighbours animated. Farms burn in stages under **one shared fire
  light** without shadows; the rest is glow, smoke and sound.
- The wreck: an emissive keel crystal and glow strips; the one shared light moves to it.
- Wolves: at most two packs.
- Sky ships: at most 2 over the valley (`SkyTraffic`, 150-260 m up, far mesh past 450 m).
- *The Fallen Ship*: 8 players; only the squares near players are simulated.

## 2. The galleon (vehicle scene)

The *Long Patience* (Captain Sarrow's ship) is the one detailed ship model. The *Candlewake* wreck, the
*Albany Venture* and AI ships reuse it with paint, flags, damage states and the far mesh.

- **Size:** the model as built: a brigantine with a hull of about 26 m, about 32.5 m overall, a beam of
  7.5 m, and two masts (fore truck about 29.6 m above the keel). It carries 2-8 players.
- **Decks:** the main deck, quarterdeck and forecastle (in the model), plus a hold and great cabin below
  (a new interior, M). The rigging is climbable, reusing tree climbing.
- **Stations:** helm (the model's `Helm` empty), sails, keel, 2-4 guns, lookout, the Sway-hand.
- **States:** whole, damaged, broken and burning (the wreck, for the slice), and repaired through
  building pieces (`repair`).
- **Budget:** the cheapest map. One detailed ship; LOD1 far. At most 10 crew on looping station clips,
  inside the 12 cap. Simple deck collision. Occluders below deck. Story ships have no physics until a
  mission needs it.
- **Before release:** rename the `EtheriumGlow` material, and review the mast-top fans against our silhouette
  rule (deep stone keel, outrigger keel-fins, plain square rig) so they don't read as Treasure Planet's
  solar sails.

## 3. The Upper Sea (the Drift)

Act 3's voyage. Three **reaches**, each a sky volume about 1.5 km across and 600 m tall, joined by
fog-walled currents that hide the loading.

| Reach | Missions | Content |
|---|---|---|
| **1. The Veil-mouth** | 20, 21, 25 | Where ships come through from Earth's sky: calm currents, buoy-rocks, a tide-race course, the Dead Beacon on its floating rock |
| **2. The Dead Ships** | 22 | Old hulks lashed into a reef (an Earth sloop among them), wreck-dogs. Doubles as the first co-op wreck field |
| **3. The Shoal** | 23, 24, 26, 27 | The lightning shoal, the marooning rock (*The Rock*), and the approach to Ossel, which hands over to Vessary's sky edge |

- **Islands:** 100-300 m, from an island kit (`StructureMeshKit` plus CC0 rock models), merged per island,
  with flat stand-ins past 400 m.
- **Budget:** no terrain, no water. Haze at about 1.2 km. The galleon plus at most one other near ship. At
  most 12 animated people. Lightning is a screen flash and emissive bolts, not real lights.
- **Fallback:** if the galleon slips, one reach carries missions 20, 22, 23, 26 and 27.

## 4. Wreck fields (co-op raids)

PvPvE raids sail out from Vessary's Tether Gates.

- **The Dead Ships** (reach 2, reused): hulks lashed into a reef.
- **The Unpinned Town** (later): ruins on drifting rocks broken off Ossel's rim.
- **Size:** about 1 × 1 km and 300-400 m tall.
- **Content:** loot in hulks and ruins, AI Smoke crews and Company salvors, wreck-dogs (wolf rig), drift-oxen
  (bison rig) with a matriarch boss (mammoth rig), and the exits: the tide's channels, a Tether Gate call,
  a dead beacon.
- **Budget:** 8 players (2-4 crews); at most 12 animated AI and 2 dog packs; occluders inside the hulks;
  island LOD; one fire light.

## 5. Vessary, the Ninepins

Act 4's big city and the co-op hub, on the rust moon Ossel. One terrain square, built the way the valley is,
with a new square type: pinned basalt plain in the middle, the **Rim** at the edges. The Rim's cliffs drop
into the sky, so the map ends in haze and sky, not in water or more land.

- **The core:** about 600 × 450 m (the same footprint estimated for Albany's 9 × 6 blocks).
- **Nine pyramids,** 90-180 m tall, about 60° steep, chained to the bedrock. **5 in full detail** (the First
  with the Weighing Hall, the Second by the Scales, the Third over the Hollows, the Fourth with the High
  Docks, the Ninth or Dark Pin); **4 as far meshes** round the core's edge.
- **Buildings:** about 100-140 low courtyard houses from about 10 parametric types, plus docks, gantries,
  cranes and the Links' shanties in the chains. Interiors only for the mission buildings (the Weighing Hall,
  the lens school, a Landfall tavern and meeting hall, the Factory, the Still Water, Rook's room).
- **Places:** the twelve in `docs/main_story.md` 8.7. The Kitchen Isles are seen from the Rim.
- **First district** (build order 6): the High Docks, Landfall and the Scales, with the First, Second and
  Fourth Pins in full detail. The Third and Ninth Pins and the Terraces come with the rest of Act 4.
- **The law on the map:** the Lamp Chain's lamps sit on every pin's tiers as emissive sprites, so the wanted
  level climbs where everyone can see it.

**Budget:**
- Blocks merged into one mesh past about 150 m, using visibility ranges with a visibility parent.
- Box occluders per block; the pyramids are natural occluders. Occlusion culling on here (it pays off in
  dense, walled places).
- At most 12 animated NPCs plus crowd cards; text barks over the nearest heads.
- Lamps, lenses and keelstone glow by material, never by real lights; one shared fire light.
- 3-4 ships on dock lanes (`SkyTraffic` with dock routes); far meshes past 450 m.
- Kites as particles.
- 8 players in co-op.

## 6. The Hollows (interior)

The Hollow Brotherhood's mines under the Third Pin: about 400 m of galleries where loose rubble floats and
keelstone seams glow. *Into the Hollows*, a hideout from the Lamp Chain, and a way under the Factory.

- **Budget:** rooms stream in; occlusion culling on; few lights (the seams are emissive); floating rubble as
  a small number of physics bodies that only wake near the player.

## Later and optional

| Map | For | Size | Note |
|---|---|---|---|
| The cliffs square (valley) | A backdrop for the wreck | 1 square | Only if the open land's pine stand doesn't convince |
| The Kitchen Isles | Side chains, rustling drift-oxen | One reach, ~1 km | Farm islands on cables off Vessary's rim |
| The Unpinned Town | A second raid map | ~1 × 1 km | After the Dead Ships |
| The Convoy channel | 8v8 on a headless server | ~1.5 km reach | Two Company galleons and skiffs against two raider ships |

## Out of this map set

| v1 map | Where it went |
|---|---|
| The North Woods town (3×3, then 2×2) | The *Taken In* storyline, only with the nation's office (Odanak and Wôlinak first) |
| The Mountain Road | A future storyline (the 1765 pack trains); the existing stockade fits Fort Loudoun |
| Albany | A future storyline (*The Ford*'s later missions, the 1770s) |
| The travel map | Not needed: the march is one night, and the ship moves you between maps |
| Lake George (proposed in research) | Out of this set; it suits a Rangers storyline |
| The Carry | A future storyline (1758) |

## New designs the maps need

| Design | For | Notes |
|---|---|---|
| Palatine farmhouses, a barn, the water-mill | Map 1 | Burned and ruined versions by changing parameters (the New World Dutch barn, the stone farmhouse; H) |
| The church with unfinished walls | Map 1 | Grey limestone; a construction stage per layer (1757, 1761, 1765) |
| The stone root cellar | Map 1 | Survives your house burning; Rook's hiding place |
| The broken and burning galleon | Maps 1, 2 | A variant of the one model: snapped masts, fire states, a keel crystal still glowing |
| The galleon's below-decks interior | Map 2 | Hold, great cabin, brig |
| The island kit | Maps 3, 4 | Floating rocks, hulks lashed together, a dead beacon |
| The pyramid ("pin") generator | Map 5 | Parametric stepped faces, tiers, chains, docks and gantries, the crown lens (`StructureMeshKit` pattern) |
| Courtyard houses and Links shanties | Map 5 | About 10 parametric types; kites |
| The Company Factory | Map 5 | A Georgian brick warehouse that looks wrong on purpose |
| Crowd cards | Maps 1, 5 | Actor_B in the garments, 8 directions |
| Clothing for Vessary's peoples | Map 5 | The 90 existing garments with new palettes, pin-weighted hems, harnesses, aprons |
| The Hollows' galleries | Map 6 | Interior kit with emissive seams |

Sources follow the project's rules: Poly Haven and ambientCG (CC0) first, the owner's approval, a `SOURCE.md`
entry with its SHA-256, and `CREDITS.md`. No Native objects or buildings from museum scans without the
nation's office, whatever the licence says.

## Build order

1. **The valley's 1757 layer** on the two baked squares: the bank swap, the farms and the ford, the
   unfinished church, the mill, the homestead, the pine stand and the wreck site, no mammoths or bison.
   This is the vertical slice's map.
2. **Export the galleon** (`assets/sky/sky_galleon.glb`) with its broken and burning variant. The slice
   needs it.
3. **The valley's burned winter layer** (Act 2, *The Fallen Ship*).
4. **The galleon scene and reach 1,** then reaches 2 and 3 (Act 3).
5. **Vessary's first district** (the High Docks, Landfall, the Scales, three pins).
6. **The Dead Ships as a raid map,** the Hollows, and the rest of Vessary.
7. **The valley's 1761 layer** (the Home ending), then the Unpinned Town.
8. **Later:** the 1765 layer for *The Ford*, the Kitchen Isles, the Convoy channel.

## Open questions for the owner

- Is a pine stand at the head of the open land enough for the wreck, or should we bake the cliffs square
  so the ship falls under real cliffs?
- Should the Home ending get its own 1761 layer, or end on cards and hand straight to *The Ford*'s 1765?
- Is one city square with a 600 × 450 m core big enough to feel like GTA's "big city after the woods"?
