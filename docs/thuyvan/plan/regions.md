# Thủy Vân: regions and the map (planning part)

Read-only plan, 2026-10-05. Sources: the V3 master bible (canon decisions D01–D16, chronology H01–H23, peoples P01–P08,
atlas L01–L16 and its travel windows, the Book I act plan, the dossiers' per-book locations), the v1 series bible's place
table, the 32 paintbook stories' locations, and the 15 concept sheets. The game side comes from the main checkout and this
worktree: `docs/maps.md`, `data/world/squares.json`, `scripts/world/terrain/terrain.gd`, `scripts/world/water/*`,
`scripts/boats/*`, `tools/environment/terrain/bake_terrain.py`, `scripts/world/story_layer*.gd` and
`data/world/layers/1757.json`.

Review sketches made for this part (planning diagrams, not game art):
- `regions_route_graph.png`: the atlas as game regions, with the bible's travel windows on the links between them.
- `r1_slice_layout.png`: the first playable region, square by square, with the landmarks numbered.

Effort scale: **S** is up to 3 days, **M** is 1–2 weeks, **L** is 3–6 weeks and **XL** is more than 6 weeks. All of these
are for one session working under the one-Godot/one-Blender lock, with the owner's review loops included.

---

## 1. The decision in one paragraph

Thủy Vân becomes **a set of walkable regions joined by journeys**. It is not one seamless continent. Each region is a
grid of the engine's existing 832 m baked squares, usually 3×3 to 4×3, so about 2.5 to 3.5 km on a side. Inside a region
you walk, ride and paddle at 1:1 over ground compressed about 15–30×. Between regions you take a **journey**: a river
cutter through the locks, a pack trail, a coastal sailing or a threshold road. A journey costs game time taken from the
bible's travel windows. It is gated by what the route needs (a pilot, a permit, an open lock, the season, an invitation),
and it plays as a short sequence on the way. The **first playable region is R1, "the Đá Trắng Reach and Two Heights"**.
It holds the river that stops on Book I's first day, the foothill villages, a lock-and-toll town, and the Two Heights
Bridge where Book I's crossing dispute happens. Ten squares, built in two milestones.

---

## 2. What the sources say, and where they disagree

### 2.1 Facts used directly
- **Book I is mostly in the north.** The dossiers place Book I's action at L03 (Đá Trắng), L04 (Trường Sơn), L16 (Two
  Heights) and L05 (Thạch Uyên):
  - Kha Vũ: L03, L04, L16, L05.
  - Hạc: L03, L04. He "stops Kha touching the still water".
  - Nhạn: L04, L03.
  - Tấn: L04, L16.
  - Yên Dao: L04, L16.
  - Bạc Sơn: L04.
  - Mẹ Lửa: L04, L11. She gives "a rite for those lost at the stopped river".
  - Dương Sắt: L05, L16, L03.
  - Lệ Thạch: L05, L16.
  - General Trần Hổ: L03, "treats shrine destruction as rebellion".
  - Linh Hải: L02, L01, L03 (a relief convoy).
  - Bảo: L02, L03.
  - Vân Cổ: L03, L02 (the midpoint rescue).
  - An Tâm: L11, L03 (a relief party).
  - The White Stag is seen near a disturbed boundary (L04, L03).
- **Book I's act plan** has four beats:
  - I: the Silence at Đá Trắng.
  - II: "Kha needs Two Heights; Dương refuses compulsory Stone service; Yên Dao brokers reciprocal terms."
  - III: imperial reprisals.
  - IV: "A local containment failure destroys a politically charged crossing station", which is read as an enemy attack.
- **L03 Đá Trắng** is a cold, clear northern river through the Trường Sơn foothills.
  - Its anchor galleries regulate a gorge, and its banks are charged by the H19 survey killings.
  - The clans call its upper reach a burial witness. Excavation permits are contested, and toll barges work lower down.
  - The Silence is bounded. Its sensory anchors are white stones under stopped water, mist that holds, and fish
    suspended below the surface. Displaced flow is "tracked downstream over days".
- **L16 Two Heights** is a joint Mountain–Stone work with two maker signs on one pier.
  - Book II: the approach fails and Hạc dies there.
  - Book IV: the deeper anchor holds.
  - The bible's own rule: "Do not destroy the same intact bridge twice."
- **L14 Buried Kingdom** is a gallery *network* beneath several river works, with its "first entrance near the
  northern foothills". The Buried Kingdom sheet says the same.
- **Travel windows** (bible table, ordinary / disrupted):

  | Route | Mode | Ordinary / disrupted | Note |
  |---|---|---|---|
  | L02→L03 | upstream cutter | 6–9 / 9–14 d | five lock stages |
  | L03→L16 | pack trail | 2–3 / 4–6 d | |
  | L16→L05 | bridge road | 1–2 / 3–5 d | +2 d after Book II |
  | L05→L10 | forest path | 4–6 / 7–10 d | grove permission and a guide |
  | L02→L06 | barge | 4–6 / 6–9 d | 7–10 d back upstream |
  | L06→L07 | guided shallow boat | 1–2 / 2–4 d | |
  | L06→L08 | pilot route or submersion | 2–3 / 4–6 d | |
  | L02→L12 | coastal sail | 5–8 / 9–16 d | |
  | L12→L13 | small craft | 2–4 / 5–8 d | |
  | L02→L09 | road plus threshold | 7–10 / 12–16 d | invitation needed |
  | L03→L11 | shrine road | 2–4 / 4–7 d | |
  | L14→L15 | surveyed route | 3 d | only after preparation |

- **The stories cluster in the north.** At least 8 of the 32 paintbook stories are set in Trường Sơn, Thạch Uyên or a
  hillside shrine:
  - #4 Rope Across First Snow
  - #5 Smoke in Goat Pass
  - #6 His Brother's Bow
  - #7 Feast of the First Chisel
  - #8 The Noise Inside the Wall
  - #9 The Quarry That Spoke Back
  - #23 The Fourth Voice in the Shrine
  - #30 Bride Price at the Stone Steps

  #27 Crossing at Khe Lan Ferry has no fixed place. These are ready-made side content for R1.

### 2.2 Conflicts between the map sheet and the bible

None of these is fatal, but each needs the owner's call.

1. **Scale.** The map sheet's scale bar (0–400 km) makes the world about 2,300 km wide. It puts Vạn Thủy about 980 km
   from Đá Trắng and Two Heights about 1,300 km from Đá Trắng. The bible's travel windows imply much less. Using my own
   speed estimates (upstream tow about 20–35 km a day, mountain pack trail about 20–25 km a day):
   - Vạn Thủy to Đá Trắng is about **150–300 km**.
   - Đá Trắng to Two Heights is about **40–75 km**.
   - The whole world is roughly **600–700 km** across.

   The bible itself says distances are "route windows until a drawn map fixes scale". **Recommendation:** the travel
   windows govern, and the map sheet is topology and mood.
2. **Đá Trắng's position.** The sheet draws Đá Trắng north-centre, far east of Two Heights (west). The bible makes them
   a 2–3-day pack trail apart. **Recommendation:** the game's map moves Đá Trắng's upper reach west, so it rises in the
   Trường Sơn foothills close to the Two Heights pass.
3. **The Buried Kingdom's position.** The sheet labels it in the south, "Below the Waters", by the Outer Sea. The bible
   and the Buried Kingdom sheet put its first entrance in the northern foothills. **Recommendation:** it is a network,
   not a place on the map. Its first entrance is in R1's gorge, sealed in Book I and opened in Book II.
4. **Spoilers on the sheet.**
   - The legend names "THE NINTH RIVER: Sông Ký — Memory, a hidden current". That is a Book V truth (D15, guardrails).
   - "The Convergence, Hidden Nexus" is unnamed in Books I–III.
   - The in-game map must show neither before its book.
5. **Captions that contradict canon.** These must not be copied into game text:
   - "H10 Foundation of Cửu Giang: Eight rivers, one people". The bible says it was a Dragon-Sea coalition co-built
     with Riverborn, Floodborn and Stone crews.
   - The Vạn Thủy sheet's "founded in the 10th generation (H10)". H10 is a chronology entry, not a generation.
   - The Vực Sen Sâu sheet's "Edict H14". H14 is a withdrawal, not an edict.
6. **The rivers' numbers.** The sheet names eight rivers (I Sông Thiên to VIII Sông Hồi) but does not say which number
   Đá Trắng is.

---

## 3. The world's shape and scale for a game

### 3.1 Why not one seamless world

- Each square is an 833×833 height field at 1 m, about 11 MB on disk once baked; the two baked squares plus textures take
  66 MB today.
- A seamless world compressed 1:50 would be about 12–14 km a side: roughly 150–200 squares, about 2 GB, with each one
  baked and dressed by hand.
- The 32-bit transforms jitter visibly beyond about 8–10 km from the origin. There is no origin-shifting today.
- The Mac mini budget in `docs/maps.md` cannot fill that much land with stilt villages and karst.
- A 600 km world at 1:1 is out of the question.

### 3.2 The model

- **Regions.** Each region is a map folder like today's: `data/world/maps/<region>/squares.json` with its own grid of
  square types, its water network and its year layers. Regions stay at or under 4×4 squares (about 3.3 km), so float
  precision is never an issue.
- **Compression inside a region.** Landmarks a day or two apart in the bible sit 1–3 km apart. Example: the 2–3-day pack
  trail from Đá Trắng to Two Heights becomes about 2.5 km of switchbacks, roughly 15–20 minutes on foot. This is the GTA
  convention.
- **Journeys between regions.**
  - A journey starts at a pier, a trailhead or a threshold.
  - It checks its requirements: a pilot, a licence, an open lock, the season, an invitation, or grove leave.
  - It costs time from the bible's window. Ordinary or disrupted is chosen by world state: war closures, the Silence,
    storms.
  - It plays a short scene on the way, such as a lock passage, a towpath, a storm or a checkpoint. It can reuse one
    "route square" per mode instead of building the whole river.
  - It arrives at the destination's pier or trailhead.
  - This is the design `docs/maps.md` already uses ("Moving between maps happens through the story or the ship"), applied
    to a river world. Every region still has free roam.
- **Calendar mapping.**
  - The survival calendar (`WorldClock`) has 36 game days a year (12 months × 3). One game day is 57.6 real minutes.
  - The bible's year has 12 months of 30 days plus 5 flood-rite days.
  - **Proposal:** 1 bible month = 1 survival month = 3 game days, so 1 bible day = 2.4 game hours. Then:
    - The 6–9-day cutter trip takes 14–22 game hours: one night aboard.
    - Book I (months 1–5) is 15 game days, about 14 real hours of clock time before sleeps and skips.
  - Pick one rule and keep it everywhere.
- **Co-op.** A journey is a party action: the host proposes it and everyone aboard agrees. Players who stay behind stay
  in the region. This uses the existing everyone-asleep skip pattern.

---

## 4. The regions (the atlas turned into game maps)

| Region | Atlas | Peoples at home | Books | Size (squares) | What it needs that is new | Effort |
|---|---|---|---|---|---|---|
| **R1 Đá Trắng Reach & Two Heights** | L03, L16, edges of L04/L05, one L11 shrine house | Mountain Folk, Stone Children, Dragon-Sea (toll, boats, soldiers), Ancestor-Bound; Hồ Tinh hidden | I–IV (Book II: the bridge approach fails; Book IV: the anchor defence) | 10 (3×3 + 1 exit square), 2 of them backdrop rim | gorge, terraces, pass, karst foothill recipes; a water network; a lock; the stopped reach; the bridge; four building kits | see §6.8 |
| **R2 Vạn Thủy, Capital of the Waters** | L02 | Dragon-Sea; every people in the quay districts; Ancestor halls | I–IV (falls in IV) | 2×2 dense core plus a water rim | canals and still basins, locks in the city, island districts, crowd cards, interiors | XL+ |
| **R3 The Lock Road** | L01 (the Cửu Giang corridor) | Dragon-Sea lock towns, canal labourers, delta farms | I–II | a journey, plus 2 stops of 2×2 (a lock town, a towpath village) | reuses R1's lock and boat kits; paddies; levees | L |
| **R4 Trường Sơn, the Endless Range** | L04 | Mountain Folk clans | I–V | 3×3 | hanging-bridge kit, cliff villages, high terraces (shares R1's kits) | L–XL |
| **R5 Thạch Uyên, the Stone Valleys** | L05 | Stone Children | I–V | 2×3 | quarry walls, kilns, aqueduct and arch bridges, cliff sanctuaries | L–XL |
| **R6 Đồng Lau, the Reed Marches, and Khar-Ul** | L06, L07 | Floodborn; mixed ferry folk | I–V | 3×3, mostly water | flat-water squares, stilt platforms, mangroves, the Floodborn body | XL |
| **R7 Vực Sen Sâu, the Deep Lotus Reaches** | L08 | Riverborn | II–V | 2×2, much of it cavern | cavern interiors, lotus basins, submersion, the Riverborn body | XL |
| **R8 Ảo Thành, the City of Illusions** | L09 | Hồ Tinh | II–V (named only in I) | 1×2 night city, interior-heavy | threshold rule (no instant travel), the night-market kit, the Hồ Tinh true form | XL |
| **R9 Lâm Uyên, the Verdant Deep** | L10 | Mộc Tinh | II–V (dying-wood glimpses in I) | 2×2 | giant-tree kit, root bridges, the Mộc Tinh body | XL |
| **R10 Southern Delta Provinces and the Ash Coast** | L12, L13 | Dragon-Sea ports, Trần houses, refugees | II–V (Mai) | 2×3 with sea | open sea and coast (the hardest water), salt flats, camps | XL |
| **Buried Kingdom galleries** | L14 | (ruins of every people) | II–V | interiors under R1, R6, R2 | the interior streaming `docs/maps.md` planned but never built | L per gallery set |
| **The Convergence** | L15 | none | V (inferred in IV) | one interior | built last; never on the map before its book | L |
| **Ancestor Roads** | L11 | Ancestor-Bound | I–V | not a region: shrine houses placed in R1, R3 and R4; An Tâm's own house is a small 1×1 map 2–4 days from R1 | | S–M each |

Book order for building:
1. **Book I:** R1, then the R3 journey, then one R2 district (grain piers and a quay-family canal quarter).
2. **Book II:** R4, R5, R6, R7 and the first Buried Kingdom galleries, entered from R1's gorge.
3. **Later books:** R8, R9 and R10.

### 4.1 Connections (the route graph)

| Link | Mode in the game | Gate / state | Window (ordinary / disrupted) |
|---|---|---|---|
| R1 ⇄ R3 ⇄ R2 | River cutter or towed barge. Five lock stages, each a short playable lock passage; going downstream is quicker. | Locks close in war (disrupted). In Book I the Silence lowers the river below the reach, and barges ground. | 6–9 / 9–14 d upstream |
| R1 ⇄ R4 | Walked inside R1: the high-pass square is R4's doorstep. The full R4 is a separate map in Book II. | Snow and washouts close the fastest route. | (in-region) |
| R1 ⇄ R5 | Bridge road over Two Heights | After Book II's collapse, a detour that adds 2 days (a year-layer change in R1) | 1–2 / 3–5 d |
| R5 ⇄ R9 | Forest footpath | Grove permission plus a local guide (a requirement, not a key item) | 4–6 / 7–10 d |
| R1 ⇄ An Tâm's shrine | Road to the shrine circuit | none | 2–4 / 4–7 d |
| R2 ⇄ R6 | Downstream barge | Return trip 7–10 d | 4–6 / 6–9 d |
| R6 ⇄ Khar-Ul | Guided shallow boat (inside R6) | A guide chain; no deep-draft boats | 1–2 / 2–4 d |
| R6 ⇄ R7 | Pilot route or controlled submersion | A licensed pilot; air stops for unadapted crews | 2–3 / 4–6 d |
| R2 ⇄ R10 | Coastal sailing | Storms close the coast entirely | 5–8 / 9–16 d |
| R2 ⇄ R8 | Road and threshold corridor | Invitation; illusion does not shorten the distance | 7–10 / 12–16 d |
| Buried Kingdom → Convergence | Surveyed maintenance route | Book V; air, food and tested anchor access | 3 d after preparation |

**Boats are the spine.** Every link out of R2 except Ảo Thành's road is water. Building the boat system for a river world
(§6.6) pays off in every later region.

---

## 5. The first playable region

### 5.1 The choice: R1 (Đá Trắng Reach and Two Heights)

Why R1 and not a Vạn Thủy district or a Reed Marches edge:

1. **Book I happens here.** The Silence (H23, "Year 0, early rains: Đá Trắng stops"), the evacuation, the Two Heights
   crossing dispute, the shrine reprisals and the convoys all touch L03 and L16. An ordinary person living here lives
   through the whole of Book I at first hand: the river stops, and war begins for the wrong reason. Most of the Book I
   cast (§2.1) passes through, so the player crosses paths with the canon cast without replacing any of them.
2. **The engine already half-does this terrain.** Today's world is one meandering river through valley squares, with
   rapids, wading, drinking, flow sound and boats on its current. A cliff square type and grip-climbable rock exist.
   R1's core, a river through foothills, extends what is built. A delta city or a marsh is mostly flat open water, the
   thing the budget says the game cannot yet afford.
3. **Canon spares the hardest bodies.** In Book I's north:
   - Riverborn are present as an absence: "absent guides and closed licences".
   - Floodborn are a rumour; Book I "reads them as raiders", and they are far from their wet country.
   - Mộc Tinh appear only as "forest symptoms".

   So the slice needs only human-shaped bodies: Mountain Folk, Stone Children (mineral skin is a shader and patches on
   the human rig), Dragon-Sea (scales and reflective eyes), Ancestor-Bound, and Hồ Tinh in disguise. The three non-human
   rigs (Floodborn, Riverborn, Mộc Tinh) come with their own regions. This is canon-true, not a shortcut that misdraws
   them.
4. **It plants the long game.**
   - The Buried Kingdom's first entrance sits in R1's gorge (Book II).
   - The bridge's two maker signs are "the miniature of the final seal".
   - The Book II collapse and the Book IV anchor defence reuse the same map as later year layers.
5. **There is side content already.** Eight paintbook stories are northern (§2.1), and Tidebreak's earth arts are at
   home here.

The alternatives:
- **A Vạn Thủy district** is the most spectacular, but also the most expensive start: dense island blocks, canals,
  locks, crowds and open water. In Book I the capital is mostly closed offices and suppressed reports. Build it third,
  once the water network and lock kit exist.
- **A Reed Marches edge** fits boats best, but needs the Floodborn body, mangroves and a square that is mostly water. Its
  Book I content (the burned reopening site, Floodborn "read as raiders") would make a Floodborn village the player's
  first enemy contact, which is the wrong first impression for a world where no faction is the good one.

### 5.2 The layout

Ten squares, north up. See `r1_slice_layout.png`.

| Square | Type (new bake recipe) | What is there |
|---|---|---|
| A1 | high pass (Trường Sơn side) | Clan waystones (the "Clan Waystone" panel on the Trường Sơn sheet), the goat-pass watch trail (story #5), where the pass leads on to R4 |
| B1 | terraced slope | Mountain Folk village: terrace grain, medicinal gardens, the clan house above a pine valley (story #6), granary, smokehouse, lookout |
| C1 | **gorge** | **The Silent Reach.** Old anchor masonry in the gorge wall (the gallery mouth), H19 cairns on the burial-witness upper reach, the imperial survey / excavation-permit camp |
| D1 | rim (backdrop) | Upper gorge falling from the range; low detail |
| A2 | **bridge gorge** | **Two Heights Bridge** over a west–east torrent: the Mountain end north, the Stone end south, two maker signs on one pier, offerings above serviced bolts, the oath post |
| B2 | switchbacks | The pack trail's switchbacks, the **hillside shrine** (an Ancestor-Bound house on the circuit; story #23; not An Tâm's own house), the torrent going down to its confluence |
| C2 | middle reach | Rapids and a ford, a **ferry crossing** (story #27 "Khe Lan Ferry", if the owner places it here), a fishing hamlet |
| A3 | Stone height | Stone Child quarry hamlet: terrace court and steps (story #30), the retaining wall over the rain road (#8), the abandoned upper quarry (#9), kilns, the Feast of the First Chisel terrace (#7) |
| B3 | foothill paddies | Mixed farms, flooded terraces, herb gardens, buffalo; the rain road |
| C3 | river flats | **"The Fifth Lock"** (placeholder name: the upstream-most of the five lock stages from Vạn Thủy). It has the lock chamber, toll house, crossing station, barge basin, market quay, bell, the imperial post and boat sheds |
| D3 | river exit and first karst | The journey pier (a river cutter down the Lock Road); the first karst towers as the delta's promise |

**Peoples on screen** (Book I): Mountain Folk, Stone Children, Dragon-Sea (toll clerks, bargemen, fishers, soldiers),
Ancestor-Bound, and Hồ Tinh in disguise (a market broker or messenger, the bible's "hidden brokerage"). Riverborn appear
through closed licences, a missing pilot and a shuttered pilots' office at the lock. Floodborn and Mộc Tinh do not appear
on screen in the north in Book I.

**The player's home by people.** Each people starts in the place where its ordinary life is: Mountain Folk in the B1
village, Stone Children in the A3 hamlet, Dragon-Sea in the C3 lock town, Ancestor-Bound at the B2 shrine house (bound or
unbound; D03 says unbound kin exist), and Hồ Tinh at the C3 market, in disguise. Riverborn, Floodborn and Mộc Tinh starts
need their bodies and are an owner decision (§9).

### 5.3 Landmarks (the numbers on the sketch)

1. **The Silent Reach.** A bounded stretch, about 300–500 m long, that stops on day 0. White stones show under clear,
   motionless water. Mist hangs and does not move, and fish are suspended mid-water. At its ends the moving water meets
   the still water.
2. **The anchor-gallery mouth.** Old masonry in the gorge wall. It groans and sheds dust after the Silence ("northern
   anchors carry impossible loads"). It is sealed in Book I and opens in Book II.
3. **The H19 cairns.** The Northern Survey violence site where Kha's father died. The clans' burial witness.
4. **Two Heights Bridge.** The hero asset, with four states: intact (Book I), the approach failed (Book II), detour roads
   (Book III), and the anchor defence (Book IV).
5. **The Mountain Folk village.**
6. **The hillside shrine.**
7. **The Stone quarry hamlet.**
8. **The ferry and fishing hamlet.**
9. **The Fifth Lock and its crossing station.** My proposal is that this station is the one a "local containment
   failure" destroys in month 5, the one that is read as an enemy attack. It is not the bridge (the bible forbids
   destroying the bridge twice). The owner decides.
10. **A Tidebreak festival ring** moored in the barge basin. The sport's knock-off-into-water rule fits a floating
    platform.
11. **The imperial survey / excavation-permit camp** (H22: rising excavation quotas).
12. **The journey pier.**

### 5.4 Book I as world states

These are year-layer data, the system `data/world/layers/1757.json` already uses: places, sites, and what stands,
burns or changes.

| State | Bible window | What changes in R1 |
|---|---|---|
| **S0 Before the Silence** (tutorial) | Year 0, month 1, early rains | Full toll traffic; excavation quotas; shrine voices "inconsistent" (rumour only); market days; the ring festival |
| **S1 The Silence** | day 0 to week 3 | The reach stops; barges stranded; the gallery groans; the downstream level falls at the lock over days (the bible: "displaced flow tracked downstream over days"); evacuations from the gorge; soldiers arrive; a relief convoy |
| **S2 The price of crossing** | months 2–3 | Refugees on the trail; the bridge's toll and oath post contested; Stone crews refuse compulsory service; the reciprocal terms are written; Vân Cổ's rescue happens nearby (heard or seen, never played as him) |
| **S3 The useful account** | months 3–4 | Shrine destruction and arrests (General Trần Hổ); reprisals; checkpoints on the lock |
| **S4 War named too soon** | month 5 | The crossing station is destroyed (owner's call which one); muster; the lock closes to civilians; war is authorised on a false account |
| Book II and later | months 6+ | The bridge approach fails (Book II); the gallery opens (end of Book II); later states follow the book plans |

The player's missions are an ordinary person's: evacuating a household, carrying loads over the pass, ferrying, finding
food when the barges stop, witnessing at the shrine, and choosing whom to help. Nothing explains the Silence. The
cosmology is earned (bible: no early exposition).

### 5.5 Activities, mostly reused systems

| Activity | Existing system | Change needed |
|---|---|---|
| Fishing | `scripts/fishing`, `data/world/fish.json` | Northern cold-water species; the Silence's suspended fish (S1) |
| Terrace farming | `FarmJob`, farm fields | Paddy rice on flooded terrace steps |
| Herb foraging | `forage` | Medicinal garden plants (Trường Sơn resources panel) |
| Porter loads on the pass | carry and pack systems (`CarcassPack`, wheelbarrow) | A pack frame; buffalo or ox trains |
| Ferry and boat work | `Boat`, `BoatRider`, `WaterSurface` | Sampan and ferry, poling, a ferry rope |
| Boat building | `BoatStand`, hull plans, puzzles | Sampan and basket-boat plans |
| Quarrying | gathering and stone | Quarry faces in A3 |
| Lock work | none | New: gates, sluices, a level cycle (§6.3) |
| Market, trade, tolls | store ledger, items | Bronze cash and grain shares (bible §06) |
| Tidebreak festival | `scenes/ring.tscn` (separate light scene, `WorldRiver.off`) | Place the ring in the world on a moored platform |
| Hunting and wildlife | wildlife system, birds, fireflies | Goats, buffalo (from the bison generator), herons, hawks; retire mammoths and bison |

### 5.6 Assets the slice needs

| Group | Count | Notes |
|---|---|---|
| Terrain squares baked | 10 | 4 new recipes (gorge, terraced slope, high pass, karst foothill) plus reworked river-flat and paddy recipes |
| Water | 1 main channel (~3.5 km), 1 torrent (~2 km) with 3–5 falls, 1 lock chamber with 2 gate pairs, 1 barge basin, 30–60 small paddy water planes, the stopped-reach state | §6.2–6.4 |
| Hero assets | 6 | Two Heights Bridge (4 states); the lock with toll house and crossing station (intact and destroyed); the gallery mouth; the shrine; the H19 cairns; the ring platform |
| Building types | about 25 | Mountain Folk 7 (slope-stilt house, longhouse, granary, clan house, smokehouse, lookout, hanging footbridge); Stone hamlet 6 (stone house, kiln, quarry crane, retaining-wall kit, terrace-court steps, cliff niche); Dragon-Sea lock town 10 (toll house, warehouse, tiled house, stall, quay kit, bell tower, imperial post, boat shed, pilots' office (shuttered), tea house); shrine 2 |
| Props | about 60 | Baskets, nets, jars, lanterns, banners, waystones (5–8 variants), pack frames, carts, tally boards, offering bowls, toll scales |
| Vegetation species | 7–9 | Bamboo clump, mountain pine (retinted white pine first), broadleaf evergreen, banana, tree fern, reeds, paddy rice (grass variant), tea and herb gardens, mosses; birch, maple and autumn colour retired |
| Boats | 4 hull plans | Sampan, basket boat, toll barge, river cutter, plus poling and towing clips (own clips) |
| Animals | 3–4 | Buffalo or mountain ox (bison generator), goat (new small rig), heron/crane (bird flock), hawk |
| Bodies and clothes | (the peoples part) | Five human-shaped peoples' dress and skin features; the canon cast's looks |

---

## 6. What the current tech can do, and what it cannot yet

### 6.1 Terrain (`FrontierTerrain`, `bake_terrain.py`, `WorldSquares`)

**It can:**
- Bake 832 m squares as 1 m height fields, with recipes per square type that blend 100 m across borders, and lay out any
  grid from `squares.json`.
- Use triplanar rock texturing on slopes over 35°. Climbing works on grip-tagged colliders (`GripSurface`).
- Draw terrain in 4 LODs with no far cut-off, so loaded squares stay visible to the horizon, and keep detail streaming
  to the player's 3×3 neighbourhood.
- Raise an outer rim so the edge of the world is never seen.
- Put year layers (`StoryLayer`) on top: sites, places, burnable and ruin states.

**It cannot:**
- Make vertical or overhanging faces, caves or arches. A height field holds one height per point. **Karst towers,
  sheer gorge walls, cliff niches and the gallery mouth have to be meshes.**
- Do anything else in today's recipes: the woods, open land, fields, marsh, lake and cliffs are all Mohawk Valley
  ground. Gorge, terraces, high pass and karst foothill are new code in `bake_terrain.py` (L).

**To build:**
- A **rock and karst kit**: Blender-authored and our own, or procedural like the trees. It needs towers, cliff panels
  with overhangs, grip-tagged and ledge-baked colliders (`TravLedgeBaker`), and impostor cards for the far skyline (L).
- A **horizon backdrop** of karst and range silhouettes beyond the region, as cards in the haze, because Thủy Vân's look
  is long misty vistas (M).

### 6.2 Water (`WorldRiver`, `RiverWater`, `river.gdshader`, `WaterSurface`)

**It can:**
- Run **one** river, defined analytically in `squares.json`.
  - Its centre line is a sum of sines along z.
  - Its surface level depends on z only, falling southward.
  - Its rapids are listed by z.
  - Its ribbon is a fixed 12 m half-width.
- Draw flow-mapped ripples, depth colour, refraction, sky reflection by a probe, bank foam and rapids foam.
- Give boulders a wake, play a flow sound along a line, and handle wading slow-down, drinking and torches going out.
- Give boats current through `WaterSurface`. **`WaterSurface` is the right seam:** everything the boats ask of water
  already goes through it.

**It cannot:**
- Have a second river, a tributary, a confluence, canals, a lake, a still basin, a pond, paddy water, waterfalls, a
  lock, or a reach with a different flow.
- The unbuilt "lake" square is a type with nothing behind it.

**To build:**
1. **A `WaterNetwork`** to replace the single analytic river (L). Channels are polylines with nodes carrying width,
   level and flow scale. There are junctions, and still "pounds" (basins, paddies, lock chambers) as flat polygons.
   - `bake_terrain.py` carves beds from the same data.
   - `RiverWater` builds a ribbon per channel and a plane per pound.
   - `WaterSurface` and `WorldRiver`'s queries (`surface_at`, `depth_at`, `current_at`, `is_under_water`) keep their
     signatures, so boats, wading, fishing and torches keep working.
   - Regression risk: many callers. Run the boat, fishing, torch and wildlife tests.
2. **Waterfalls** as card and particle meshes on channel drops (M).

### 6.3 Locks and floodgates

Nothing like them exists. **To build** (M–L):
- A lock chamber is a pound between two gate pairs. Its level eases between the upper and lower pounds, driven by
  sluices.
- The gates are meshes with hinged leaves, opened by interaction or by a lock-keeper NPC.
- Boats inside rise and fall with the pound's level through `WaterSurface`.
- A toll stop is a station on the lock.
- The same kit serves R3's five stages and Vạn Thủy's central lock later.

### 6.4 The stopped reach (the Silence)

It is cheap once the water carries a per-reach flow scale (S–M after §6.2; also doable on today's single river):
- Set the flow and ripple speed to 0 in the shader for the bounded reach, with a short transition at each end.
- Raise the clarity so the white stones show.
- Put fish models suspended under the surface.
- Hold the mist with static fog cards that do not drift.
- Remove the flow sound there, so the near-silence is the effect.
- `WaterSurface.current_at` returns zero there.
- Downstream, the level drop at the lock unfolds over days, as a world-state curve.

What touching the still water does, and whether a boat on it can move, is the owner's decision (§9). Hạc stops Kha
touching it.

### 6.5 Settlements and buildings

**It can:**
- Build parametric meshes with `StructureMeshKit` (boxes, quads and smooth grids, with grain, AO and edge wear), as the
  fort, church, mill wheel and build pieces do.
- Use the Tidebreak **ring kit** (`assets/ring_kit`: curved roofs with upturned eaves, lacquered pillars, tile canopies,
  paper lanterns, gate pavilion; our own Blender authoring). It is the nearest starting point for Dragon-Sea and shrine
  architecture.
- Path NPCs on `WalkGrid`, which rasterises colliders, so platforms, stairs and bridges work if they have colliders.
  Doors and portals exist.

**It cannot:**
- Show any building of Thủy Vân. Every building today is 1750s log, plank or stone frontier.
- Stand buildings in water: stilts over water need a water pound under them, plus post colliders for boats.
- Do hanging rope bridges, which need sway as a visual and a walkable collider.
- Do interiors with streaming and occlusion (planned in `docs/maps.md`, not built).
- Do crowds: walking cards are planned, not built. The budget caps animated people at 12.

### 6.6 Boats

**It can:** run its own light boat physics on `WaterSurface`, with current, stroke surges, keel, shallows and banks;
boarding and paddling with our own clips; crouching aboard with weapons; and staged hull building with puzzles from JSON
hull plans.

**It cannot:** pole a boat, tow one from a towpath, carry a sail, pass a lock, use a ferry rope, carry several NPC crew,
or animate rowing. It also has no river-world hull plans: a sampan, a basket boat, a toll barge or a river cutter.

**To build:** the hull plans plus poling and towing clips (our own) plus lock passage plus journey departure (L).

### 6.7 Performance (the Mac mini budget)

- `docs/maps.md` says "No open water and no long open sight lines". That rule was written for the frontier. **Thủy Vân
  breaks it by nature**: rivers, basins and misty vistas.
- The river's frame cost has **never been measured**: there is no water benchmark in `tools/environment/perf`.
- SDFGI already misbehaves over the river channel (`terrain.gd` keeps the coarse LODs out of GI for that reason).
- **The first task, before any kit:** bake one gorge square and one lock-town square, put in the water network, and
  measure on the M4 at medium, 60 fps (M).
- Mist and haze are both the look and the budget: low sight lines in the gorge, haze at 600–1,200 m, and karst as cards
  past that.

### 6.8 The slice in milestones

| Milestone | Content | Effort |
|---|---|---|
| **M0 Proof** | 2 squares (C3, C1) with the water network, the stopped reach and the perf measure. Review: running vs stopped water side by side; lock-town water at dusk | about 6–8 weeks |
| **M1 The River Column** | C1, C2, C3 (+D3), the lock, the Dragon-Sea kit, the ferry, S0–S1 layers. Playable: the tutorial at the lock town, the Silence, an evacuation from the gorge | about 3–4 months after M0 |
| **M2 The full R1** | The B and A columns: the village, shrine, pass, bridge and Stone hamlet; S2–S4 layers; the ring in the basin | about 3–4 more months |

**Honest total.** About 9–12 months of single-session work for the whole of R1, counting the asset kits. That drops to
about 5–8 months if two or three sessions split water, kits and content under the one-Godot/one-Blender lock. The peoples'
bodies and dress, the arts and the story missions are other parts of the plan and come on top of this.

---

## 7. Review images and lineups (the owner judges by eye)

| When | What to show | Tool |
|---|---|---|
| Now | `regions_route_graph.png` and `r1_slice_layout.png` (this plan) | done |
| M0 | Each new square type from above and at eye level, in a lineup | `tools/environment/terrain/squares_shots.gd`, `terrain_shots.gd` |
| M0 | Running vs stopped Đá Trắng, side by side, from the same camera (dawn, noon, rain) | `tools/environment/water/river_film.gd` / `rapid_shots.gd` pattern |
| M0 | Perf: frame ms at medium on the gorge and lock squares (water on and off) | `tools/environment/benchmark.gd` |
| M1 | Two Heights Bridge A/B/C variants (stone arch with timber deck; all timber on stone piers; two different halves meeting), each with the two maker signs | Blender rest renders and in-game shots |
| M1 | The lock-town street and the toll house in three roof and lacquer palettes | an `OffscreenView` script |
| M1 | Karst skyline: cards vs meshes vs none (fog only) | in-game shots |
| M2 | Village, hamlet and shrine kit lineups beside the concept sheets (Trường Sơn, Thạch Uyên) | lineup PNGs |
| Each state | The same five viewpoints in S0, S1, S2, S3 and S4 | layer shots |

---

## 8. Risks

- **Water rewrite regressions.** Replacing `WorldRiver` touches boats, wading, drinking, fishing, torches, wildlife
  drinking and the ring's `WorldRiver.off` switch. Several sessions work on `main` at once.
- **Performance.** Open water plus vistas is unmeasured on the target machine, and the budget rule against it was set
  for good reason.
- **Karst and sheer gorges are mesh work**, not terrain. Collision, climbing and LOD cost scale with how many there are.
- **The map sheet conflicts with the bible** (§2.2: scale, Đá Trắng's position, the Buried Kingdom's position). It also
  shows spoilers (the Ninth River legend, the Convergence) and captions that contradict canon. Any in-game map or loading
  art taken from the sheet must be redrawn.
- **The scale of the slice** (§6.8). A smaller M1 "river column" is the realistic first playable.
- **Canon invention.**
  - The lock's name, the village's clan and name, the ferry's placement and which crossing station is destroyed are all
    proposals here.
  - What the stopped water does to a hand or a boat is unspecified in the bible.
  - These must be the owner's or author's decisions, not the game's.
- **Calendar mismatch.** The survival calendar has 36 days a year; the bible's has 365. The 1:10 mapping needs one rule
  applied everywhere.
- **Peoples not on screen.** Floodborn, Riverborn and Mộc Tinh absent from the first region is canon-true, but the owner
  may want to see them early.
- **Co-op.** Separate region maps mean a journey is a party decision. Players split across regions is a P8-scale problem.
- **Provenance.** The terrain, bark and props today use Poly Haven CC0 textures and models (downloads, recorded in
  `SOURCES.md`). The relayed rule "own assets only, no downloads" needs the owner's word on whether CC0 textures stay.
- **Tidebreak in the world.** The ring is a separate light scene today; a ring moored in a basin needs integration work.
- **Tidebreak's elements.** The fire and air arts and the ring dress (the marigold and tangerine air dress) should be
  checked for likeness to the show before they appear in Thủy Vân. That check belongs to the arts part, but the R1
  venue depends on it.

## 9. Questions for the owner

1. Do the travel windows govern scale (world about 600–700 km, the map sheet as topology), or does the sheet's
   400 km scale bar?
2. Move Đá Trắng's upper reach west so it is a 2–3-day trail from Two Heights, as the bible says? Or keep the sheet and
   change that travel window?
3. Which of the eight numbered rivers (Sông Thiên … Sông Hồi) is Đá Trắng?
4. Is R1 the first region? And the names:
   - the lock town ("the Fifth Lock" is a placeholder)
   - the foothill village and its clan (Kha Vũ's own village, or a new one?)
   - the ferry (story #27's Khe Lan Ferry?)
5. Which "politically charged crossing station" does Book I's month 5 destroy? My proposal is the Fifth Lock's crossing
   house, not the bridge.
6. The Silence's rules: what happens upstream and downstream of the stopped reach? Can a boat move on it? What happens
   to someone who touches it?
7. Do all eight peoples get a start in R1? Or do Riverborn, Floodborn and Mộc Tinh starts wait for their regions and
   bodies?
8. Animals: horses in Thủy Vân or not? Buffalo, mountain ox and goats in? Mammoths, bison and wolves retired?
9. Do the Poly Haven CC0 textures stay, or must every texture be re-authored?
10. Calendar: is 1 bible month = 1 survival month (3 game days), so Book I is 15 game days?
11. Are dossier C32 "Nhạn" (scout) and story #5's "Scout Nhàn" the same person, with a diacritic slip?
12. Regions joined by journeys (recommended), or a single continuous compressed world (about 150–200 squares; not
    feasible on today's tech)?
