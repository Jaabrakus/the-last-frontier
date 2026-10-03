<!-- research track maps-assets, story-research workflow 2026-10-02 (web research by agents; verify H claims before in-game text) -->

# Maps and assets track: report to the lead designer

Short version: the frontier setting works for maps, and no new setting is needed. The plan in `docs/maps.md` needs about 19 new 832 m squares. The story can be served with **5 new squares plus a 2D travel map**, and 3 optional squares beyond that. The research also turned up several facts that change the current map draft (listed in section 1).

**How sure I am:** [High] means a museum, park service, archaeology or official source. [Med] means a reputable secondary source or encyclopedia. [Low] means a single secondary source or a search snippet I could not open. The session's web-search limit (200 searches) ran out partway through, so a few items are marked unverified. I edited no files and ran nothing heavy: only `ls`, `head`, `grep` and `du`, and no Godot.

---

## 0. How the current map is built (read from the code)

- **The grid.** The map is a grid of 832 m squares (`data/world/squares.json`, `WorldSquares`). Today it is 3×3, and only squares (0,0) (the fort) and (1,0) (the open land) are baked. Terrain is baked per square by `tools/environment/terrain/bake_terrain.py --square X,Y` and comes to about **11 MB per square** on disk (I measured `sq_1_0`).
- **Level of detail.** Terrain is drawn in 64 m chunks that switch to coarser versions at 100, 220 and 450 m. Trees use three detailed versions out to 30, 60 and 100 m, then flat stand-in images (impostors) in 50 m cells, which are drawn in a painted style.
- **Buildings.** They are made in code (`StructureMeshKit`, `FortStructures`) with Poly Haven textures.
- **Speed and heat.** Medium quality is "a steady 60 fps on an Apple M4 Mac mini". A frame in the forest takes 12–17 ms, against 26–35 ms on high (`world_settings.gd`, from the 2026-09-28 benchmark). The 60 fps cap is on by default (`game_settings.gd`: "Cap at 60 frames a second (cooler, quieter)").
- **The river.** It runs north–south through the **east column** of the grid (centre x = 832 m). It does not pass through the field-land square where `maps.md` puts German Flatts.

## 1. What the real places looked like, c.1757–1775

**German Flatts and Fort Herkimer** (this changes the Prologue layout)
- The settlement that was raided (Burnetsfield, now the village of Herkimer) was on the **north** bank of the river. Fort Herkimer was across the river on the **south** bank. At 3 a.m. on 12 November 1757 people **fled over the ford to Fort Herkimer**. [Med] [Wikipedia](https://en.wikipedia.org/wiki/Attack_on_German_Flatts_(1757)), [schenectadyhistory.org](https://schenectadyhistory.org/resources/mvgw/history/044.html)
- The settlement had about 60 houses and about 300 people, protected by five blockhouses on the Mohawk and on Canada and Bellinger creeks. Belestre led about 300 French regulars, militia and allied warriors, who came from the hills to the north. 40–50 settlers were killed or drowned and about 150 taken. Friendly Oneida had warned of the attack (that is Oneida content, so it stays a consultation slot). [Med] [Wikipedia](https://en.wikipedia.org/wiki/Attack_on_German_Flatts_(1757)), [NYS Military Museum](https://museum.dmna.ny.gov/forts/burnets-field)
- The French report lists barns, outbuildings and **a water-mill** burned. It also claims 3,000 cattle, 3,000 sheep and 1,500 horses taken; in my judgement those numbers are probably inflated. A second attack near Fort Herkimer in April 1758 killed 33 inhabitants. [Med/Low] [herkimer.nygenweb transcription](https://www.herkimer.nygenweb.net/gerflats/gerflatsattacks.html)
- **The fort itself.** Herkimer's stone house was built in 1740: 70 × 40 ft, two storeys, walls 2 ft thick, loopholes on every floor and in the cellar, with a store attached, and the place worked as a river "port". In 1756 it was enclosed by a palisade with a parapet, a 6 × 7 ft ditch and small bastions at the four corners. [Med] [herkimer.nygenweb](https://herkimer.nygenweb.net/gerflats/ofherkimer2.html), [Dartmouth Occom placeography](https://collections.dartmouth.edu/occom/html/ctx/placeography/place0077.ocp.html)
- **A period plan exists:** "Plan and profile of retrenched work round Harkemeis house at ye German Flatts 1756", reprinted in 1849. [Low/Med] [listing](https://mapsofantiquity.com/products/nyo1256-plan-and-profile-of-retrenched-work-round-harkemeis-house-at-ye-german-flatts-1756-pease-1849-genuine-antique-map). The original is probably in O'Callaghan's *Documentary History of the State of New York*; I did not verify that.
- **The church was not finished in 1757.** Fort Herkimer Church was built from **1753 to 1767**: two storeys of grey limestone, a gable roof and a frame cupola, with a date stone reading 1767 over the door facing the river. [Med] [Wikipedia](https://en.wikipedia.org/wiki/Fort_Herkimer_Church). This makes a good year layer: unfinished walls in 1757, finished by 1765–67.
- **What this means for the map:** put the settlement on one bank and Fort Herkimer with the church on the other, with **one of the existing rapids as the ford**. To do that, either move German Flatts into the east column or bend the river through the field-land square.

**A Palatine farmstead**
- **Fort Klock** (c.1750) was a stone farmhouse with 2-ft limestone walls and loopholes on every side, which also served as a trading post. Its Dutch barn dates from about 1790. [Med] [Wikipedia](https://en.wikipedia.org/wiki/Fort_Klock)
- **Nellis Tavern:** around 1747 the Nellis family built a fortified farmstead with a stone house and a mill. [Med] [timeline PDF](https://www.palatinesettlementsociety.org/Documents/Old%20docs/NellisTavernTimeline4072015.pdf)
- **The New World Dutch barn** is wider than it is long, framed with H-shaped bents (two posts joined by a beam). It has three aisles, a central threshing floor of about 25 ft, side aisles of about 10 ft for animals, and a steep roof whose eaves come down to about 14 ft. A barn from the 1760s survives at the Mabee Farm. [Med] [Wikipedia](https://en.wikipedia.org/wiki/Dutch_barn)

**Fort Stanwix and the Oneida Carry**
- **The Carry** was the portage between the Mohawk and Wood Creek. It was **1 mile long in the spring floods and up to about 6 miles after a dry autumn**. Each end had upper and lower landings, and sutlers' houses lined the road. In 1755–57 there were Fort Williams, Fort Craven (a five-sided fort), Fort Bull (burned in March 1756), Fort Wood Creek and Fort Newport (guarding a dam). By 1756 there were also a brick kiln, a sawpit, a forge, a garden and two dams. [High] [NPS](https://home.nps.gov/articles/000/the-oneida-carry-and-its-early-fortifications-1755-1757.htm)
- **Fort Stanwix** was begun in 1758. As reconstructed for 1777 it is a square with pentagonal earth-and-timber bastions (flanks 36 ft, faces 90 ft), surrounded by a berm, ditch, parapet, low palisade and a sloping outer bank (glacis). Inside are three log buildings round the parade and frame rooms built into the walls. The ground around it was cleared. [High] [NPS cultural landscape](https://www.nps.gov/articles/650027.htm)
- **Period plans:** 1758 (Montresor; Williams), 1759–60, and 1764 (Demler's "Sketch of Fort Stanwix, with its Buildings & outworks"). [High] [NPS Historic Structure Report illustrations](https://npshistory.com/publications/fost/history/hsr-illustrations.htm), [Leventhal Map Center 1758 plan](https://collections.leventhalmap.org/search/commonwealth:hx11z154z)
- **The treaty** was signed there on 5 November 1768. [Med] [Wikipedia](https://en.wikipedia.org/wiki/Treaty_of_Fort_Stanwix_(1768)). I could not verify how many people attended.

**The Native town candidates.** These are research notes only. Every design choice for the town goes to the nation's office.

Do not default to a longhouse or wigwam village. None of the three candidates looked like that in the 1750s.

- **Odanak / Saint-Francis:**
  - It stood on a bluff of about 60 ft, with board-and-timber houses round a church, a large council house, and barns and granaries on the edges. Paths led down to canoe landings. [Med] [HistoryNet](https://historynet.com/rogers-rangers-risky-1759-st-francis-raid/)
  - It had been a palisaded mission fort since 1704. Waban-Aki Nation excavations (2010–2021) found burned posts and pickets from 1759. [Med/High] [Grand Council of the Waban-Aki Nation](https://gcnwa.com/en/?p=17531), [fort-odanak.ca](http://www.fort-odanak.ca/index-eng)
  - A claim that the town had 51 houses, described in 1752 by a French engineer, Franquet, as squared logs covered with bark or boards, plus 12 frame and 3 stone houses, came from a search snippet I could not trace. [Low]
  - Rogers had about 142 men. They crossed swamp for about a week to get there and retreated about 200 miles to Number Four. Rogers claimed about 200 dead; French accounts say about 30. [Med] [Wikipedia](https://en.wikipedia.org/wiki/St._Francis_raid)
- **Seneca (the Townley-Read site, 1715–54):** separate neighbourhoods strung along streams, houses 65–90 yards apart, short longhouses, and no palisade, unlike the earlier fortified town. [Med/High] [Cornell](https://digital.library.cornell.edu/collections/onondowaga/townley-read), [Jordan, *The Seneca Restoration*](https://floridapress.org/9780813036854/the-seneca-restoration-1715-1754)
- **Mohawk (Canajoharie, the Upper Castle):** in 1756 the British built Fort Hendrick here, a square of upright pickets 15 ft high and 1 ft thick with portholes. [Med] [Dartmouth](https://collections.dartmouth.edu/occom/html/ctx/placeography/place0309.ocp.html). The Indian Castle site (1755–76) has excavated house floor plans. [Med/High] [tDAR](https://core.tdar.org/document/367534/indian-castle-floor-plans)

**Albany**
- In 1756 the town had more than 330 buildings, and about 600 in 1779. The population was about 1,500 in 1750 and 3,498 in 1790. [High] [NY State Museum homes](https://exhibitions.nysm.nysed.gov/albany/homes.html), [population](https://exhibitions.nysm.nysed.gov/albany/population.html)
- The centre was **about 9 blocks along the river and about 6 up the hill**. More than two dozen sloops would be at the docks, and the city paid for three earth-filled docks in 1766. The log stockade is gone from the 1770 map. [High] [NYSM "Last days"](https://exhibitions.nysm.nysed.gov/albany/lastdays.html)
- The Dutch church, St Peter's and the fort all stood in the middle of State Street. [High] [NYSM streets](https://exhibitions.nysm.nysed.gov/albany/streets.html)
- The fort on the hill had stone walls. The city bought it, abandoned, in 1765, and it was falling apart by the 1770s, which gives a natural year layer. [High] [NYSM fort](https://exhibitions.nysm.nysed.gov/albany/loc/fortalbany.html)
- There is a 1765 engineer's map. [High] [NYSM](https://exhibitions.nysm.nysed.gov/albany/map/map1765.html)
- Houses were gabled brick town houses, some with stepped gables. Lots were as narrow as 24 × 18 ft, with wider houses from the 1740s on, and many frame buildings. [High] [NYSM homes](https://exhibitions.nysm.nysed.gov/albany/homes.html)

**The Pennsylvania pack road and Fort Loudoun**
- On 6 March 1765 James Smith and about ten men with blackened faces stopped an **81-horse pack train** near Sideling Hill. The traders fled to Fort Loudoun, which was held by men of the 42nd Regiment. In November the rebels besieged it for two nights, and on 17–18 November the confiscated guns were handed back. [Med] [Wikipedia](https://en.wikipedia.org/wiki/Black_Boys), [EBSCO](https://ebsco.com/research-starters/history/black-boys-rebellion)
- **Fort Loudoun was a stockade about 100 ft square with bastions at the corners**, not the stone-and-earth fort with cannon that `maps.md` describes. Excavations in 1977 and 1980–82 found a 127 × 127 ft trench, a barracks, officers' quarters, a magazine, a kitchen, a storehouse and a stone-lined well. **Our stockade is 32 m square (`FORT_HALF = 16`), so it can stand in almost as it is.** [Med] [Wikipedia](https://en.wikipedia.org/wiki/Fort_Loudoun_(Pennsylvania))
- A pack horse carried about 200 lb, and horses travelled single file in strings of 12–15. [Low/Med] [Packhorse](https://en.wikipedia.org/wiki/Packhorse)

**Johnson Hall and Fort Johnson**
- **Johnson Hall** (1763) was a Georgian house built of wood, with planks cut to look like stone. It had two stone blockhouses (the west one is original), a mill on Hall Creek, a smithy and an "Indian store". [Med] [Wikipedia](https://en.wikipedia.org/wiki/Johnson_Hall_State_Historic_Site), [NY State Parks](https://parks.ny.gov/historic-sites/johnsonhall)
- **Fort Johnson** (1749) was a square two-storey stone house with a hipped roof, a cobbled yard, a grist mill and sawmill, and a council place used 1754–60. [Med] [Wikipedia](https://en.wikipedia.org/wiki/Old_Fort_Johnson)

**Base maps and reference images (public domain or open; check each rights statement)**
- Lewis Evans 1755: [Library of Congress](https://www.loc.gov/item/gm71005900/) (I did not open this record)
- Guy Johnson 1771, "Country of the VI Nations": [NYPL](https://digitalcollections.nypl.org/items/96fd0603-9b52-527c-e040-e00a18063f9b)
- Thomas Davies's 1760 views, already in `assets/ui/paintings/world/`
- Elevation data: [USGS 3DEP](https://www.usgs.gov/3d-elevation-program/about-3dep-products-services) is "free of charge and without use restrictions", at about 10 m resolution nationwide and 1 m in places. It could give `bake_terrain.py` the real shape of the Mohawk flats.

## 2. Asset sources

| Source | Licence | What is useful |
|---|---|---|
| **Poly Haven** (already the project's approved source) | CC0 | **Smugglers Cove set:** `cannon_01` (a colonial cannon on a wooden carriage), `modular_wooden_pier` (Albany docks and river landings), `wooden_barrels_01`, `wooden_bucket_01/02`, `wooden_crate_01/02`, `treasure_chest` (the strongbox heist), `wooden_lantern_01`, `ship_pinnace`, and the coastal cliff and limestone rock models (cliff squares). **Pine Forest set:** `pine_tree_01`, `fir_tree_01`, pine and fir saplings, `pine_roots` (North Woods). **The Shed set:** hand plane, handsaw, hand drill (check it isn't a 19th-century design), spade, wicker basket, clay pot, hammer, `CheeseBox_01`. **Also:** `brass_pot_01/02`, `ceramic_pot`, `brass_candleholders`, `carved_wooden_plate`, `wooden_cutting_board`, `food_apple_01`. **Avoid:** the Victorian or Gothic furniture, the hurricane `Lantern_01`, and `dutch_ship_*` (too big and too early; Albany needs Hudson sloops). [API listing](https://api.polyhaven.com/assets?t=models&c=collection:%20smugglers_cove) |
| **ambientCG** | CC0 ([licence](https://docs.ambientcg.com/license/)) | `ThatchedRoof001A/002A`, `WoodSiding001–013` (clapboard, and Johnson Hall's stone-imitating boards), 130 `Bricks` sets (Albany gables), `Plaster001–007`, `Bark001–015` |
| **Kenney** | CC0 ([support page](https://kenney.nl/support)) | Low-poly, so it won't match the world art. Use it for interface pieces, tavern cards and dice, and blocking out levels |
| **Quaternius** | CC0 | Medieval Village MegaKit, 300+ modular low-poly pieces ([page](https://quaternius.com/packs/medievalvillagemegakit.html)): good for blocking out Albany's street layout, not for the final look |
| **Sketchfab CC0 museum scans** | CC0, checked per item | About 1,700 scans from 27 institutions at launch ([Sketchfab blog](https://sketchfab.com/blogs/community/sketchfab-launches-public-domain-dedication-for-3d-cultural-heritage)). Scans are heavy, so run them through `decimate_props.py` |
| **Smithsonian 3D** | Only items marked CC0 are free to use commercially; the rest say "usage conditions apply" (non-commercial) ([summary](https://michaelweinberg.org/blog/2020/03/01/smithsonian-open-access/)) | The Gunboat *Philadelphia* (1776) is mainly useful as a reference for boat shapes; licence not checked |
| **BlenderKit** | **Unverified.** The site redirected to a different domain, and I did not follow it | Prefer CC0 sources |

**Better built in code or Blender, the way the project already works:**
- Every building type: the Dutch barn as a parametric H-bent frame, the Palatine stone house and Fort Herkimer, the stone church with its construction stages, stockades and blockhouses (already exist), Fort Stanwix's bastions and earthworks (made through the terrain's flat zones), a generator for Albany gable-front houses, and Johnson Hall.
- Pack saddles and loads, bateaux, a Hudson sloop.
- Burned and ruined versions of buildings, made by changing parameters, so every year layer reuses one model.

**Rules for sourcing:**
- No Native objects or buildings from museum scans, even CC0 ones, without the nation's office. The release rule applies whatever the licence says.
- Each download keeps the project's practice: the owner's approval, a `SOURCE.md` entry with its SHA-256, and `CREDITS.md`.

## 3. The map plan

**Ideas from Arc Raiders** [Med] ([fan wiki: maps](https://arcraiders.wiki/wiki/Maps), [Speranza](https://arcraiders.wiki/wiki/Speranza)). Arc Raiders has six maps and 30-minute raids for squads of up to three. Rotating **map conditions** (Night Raid, Electromagnetic Storm, Hurricane, Hidden Bunker, Locked Gate) make a few maps feel like many. A safe hub, Speranza, holds traders, a workshop, a stash and the mission list. For us:
- **Year layers** carry the story. **Conditions** carry replay and multiplayer: night raid, hard freeze (ice routes; boats stopped), high water (the Carry shrinks to 1 mile and the rapids get dangerous), low water (the Carry stretches up to 6 miles and the fords open), court day or market day (crowds), treaty congress, militia muster.
- **Hub:** the post in the valley, and Albany later.
- **Extraction points:** map edges that lead onto the travel map (the ferry, the head of the Carry trail, the King's road).

**Which story parts need a new map**

| Story part | Map | Size | Why |
|---|---|---|---|
| Prologue, Part 3 (The Ford), Part 4 | **The Valley** (exists): year layers for 1757, 1765, 1768 and 1775 | 3×3 (2.5 km) | Already built; it only needs German Flatts, Fort Herkimer and the homestead |
| Captive march, Rogers-style retreat, all trips | **2D travel map** | n/a | Cheap, and it links everything |
| Parts 1–2 | **North Woods** (new) | **2×2** (1.7 km), not 3×3 | All three candidate towns sit on lowland rivers, which the existing square types already make. The seasons give variety instead of extra land. The town stays a blank marked area until consultation |
| Heists, trials, committees; co-op hub | **Albany** (new) | **1 square**, not 1×2 | The real centre, 9 × 6 blocks, fits inside 832 m (my estimate is about 600 × 450 m). About 100–150 buildings from about 10 parametric house types; interiors only for the 5–6 mission buildings |
| 1758 The Carry, mission 16 (1768), 1777 The Siege | **The Carry** (optional) | 1 square | One square serves three storylines |
| Black Boys missions | **The Mountain Road** (optional) | 1×2, or 2 small scenes off the travel map | Fort Loudoun reuses the existing stockade |

**Travel map:**
- Draw it in the style of Evans (1755) and Johnson (1771). Routes are lines on the map, and days pass as you move along them.
- Stops load **4–6 small scenes baked in advance**: a camp, a river crossing, a swamp, a ridge pass, a winter camp, a lake shore. They are about 416 m each, built from the square recipes. Bake them once, not on the player's machine.

**Keeping the Mac mini cool**
- **The size of a map hardly matters to heat.** What heats the machine is how much detail is drawn near the camera, how far you can see, the shadows and the frame rate.
- At 60 fps a 12–17 ms forest frame keeps the GPU busy 70–100% of the time. A 40 or 30 fps cap would cut that work by roughly a third to a half (my arithmetic, not a measurement).
- **Settings to add:**
  - A "Cool" option: a 30 or 40 fps cap, upscaling at 0.75 render scale (the game already has MetalFX), and 2 shadow splits.
  - The travel map and menus at 30 fps with `OS.low_processor_usage_mode` on ([Godot docs](https://docs.godotengine.org/en/stable/classes/class_os.html)).
- **Streaming:** keep detailed trees, grass and nearby collision for the player's square and its 8 neighbours only. Farther away, use the impostor cells and the coarsest terrain. Terrain data is about 11 MB per square, so memory is not the problem.
- **Albany needs two engine features:**
  - Each block merged into one mesh beyond about 150 m, using visibility ranges with a visibility parent ([Godot docs](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html)).
  - Simple box occluders per block. Godot's docs say occlusion culling pays off in dense, walled spaces and does nothing in open land ([Godot docs](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html)), so turn it on in Albany and fort interiors only.
- **Multiplayer:** with 16 players, the host's simulation should only run in squares near players. The game already updates far animals less often.
- **Development work makes heat too.** Bake terrain and impostors one square at a time (`--square`), never several at once.

**Magic:** the valley already has mammoths, so the world already bends history. If the story goes magical, do it as a condition or layer, not a new map. Draw on the settlers' own folk belief, not Native spirituality, which falls under the consultation rule. I did not get to research the folk-belief sources.

## 4. Recommended smallest set and build order

1. **The valley's 1757 layer:** German Flatts and Fort Herkimer on either bank of the river with a rapid as the ford, the unfinished church, the mill and the homestead.
2. **The travel map** with 3–4 small scenes, which covers the march north.
3. **The North Woods land** (2×2), with the town left blank.
4. **The valley's 1765 and 1768 layers.**
5. **Albany** (1 square).
6. **Optional:** the Carry (1 square), then the Mountain Road (1×2, or travel-map scenes only).

That comes to **5 new squares in the core set, or 8 with the optional ones, against the 19 in `maps.md`.**

**Not verified in this pass:** the Franquet description of Odanak, the number of people at the treaty congress, the Albany fort's name and date, BlenderKit's terms, the Smithsonian *Philadelphia* licence, the 1757 raiders' route north, and how far apart these places really are (so the distances between maps are still unknown).