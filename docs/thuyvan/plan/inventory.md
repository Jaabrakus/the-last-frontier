# Thủy Vân conversion: game inventory (read-only)

What this covers: every game system in the main checkout `/Users/kiwimango/Downloads/Frontier`, read from disk. Main's HEAD is
e04be5f, and the files on disk may also hold other sessions' uncommitted work. Tidebreak is on `worktree-spellcraft`, which
is e04be5f plus 631 files changed (+54.9k lines). Nothing was run, edited or committed. Godot and Blender were not opened.
Line counts come from `wc -l` over the `.gd` files. Data and asset sizes come from `du`.

Fate keys:
- KEEP: engine-level; it works as it is (at most retuned).
- RESKIN: the same system with new content (models, data rows, names).
- REWORK: the system stays but its logic or data model has to change for Thủy Vân.
- RETIRE: specific to 1765 or the old story; leaves the game and stays in git history.

Effort keys (one AI-assisted developer, one Godot/Blender at a time):
- S: about a day.
- M: a few days.
- L: one to three weeks.
- XL: a month or more.

## 0. Headline numbers

| | Size |
|---|---|
| Game code (scripts/) | 518 .gd files, 206,422 lines, 53 folders |
| Data (data/) | 2.2 MB of JSON without traversal and loadout, which add 11 MB and 4.2 MB of generated tables |
| Assets | 894 MB: polyhaven 323 MB, environment 267 MB, character 167 MB, wildlife 36 MB, horse 25 MB, bison 21 MB, weapons 18 MB |
| Audio | 573 MB: music 514 MB of WAV (55 cues), sfx 59 MB |
| Animations | 47 MB (Actor_B.res) plus 16 MB in animations_extra (own clips) |
| Tests | 232 test_*.gd files in 45 folders |
| Tools | 594 scripts: Blender generators, bakers and shot tools |
| Scenes | 4 tiny .tscn files; everything is built in code by `scripts/world/frontier_level.gd` |

Rough split of the 206k lines:
- About 45% is engine to KEEP: controller, animation, traversal, net, save, nav, env, UI, survival core, household.
- About 30% is RESKIN: boats, building, gathering, forage, fishing, farming, wildlife, horse, torch, fire, snow, survival_game.
- About 12% is REWORK: customizer and peoples, NPC factions, story content, terrain, vegetation, water.
- About 13%, roughly 27k lines, is RETIRE: firearms 7.2k, loadout gear 7k (partly), story stages 6k, fort 3.9k, the duel test,
  the mammoth, the wonder sky, gun IK.

The code is the smaller job. Art and content is about 85% of the conversion: terrain, vegetation, buildings, eight peoples'
bodies and dress, wildlife and music.

### "World streaming" is smaller than the brief assumes

The world is **not streamed**. FrontierTerrain loads a baked 833 x 833 height field at 1 m per 832 m "square", drawn as
13 x 13 LOD chunks of 64 m. Only grass streams round the camera. `data/world/squares.json` has a 3 x 3 grid of squares, and
only 2 are baked: `fort_woods` and `open_land`, about 1.4 km² in all. There is one river, `WorldRiver`: a single
north-south function with meanders and three rapids. The bible's atlas spans L01-L16, with travel windows measured in days
(6-9 days by cutter from Vạn Thủy to Đá Trắng). A Thủy Vân open world therefore needs one of these decisions:
1. Real cell streaming, which does not exist today (XL).
2. Separate regional levels joined by travel (L each).
3. One compressed home region for Book I (L).

The bible also says a scaled map is intentionally not fixed yet (section 15), so the owner has to set the scale.

## 1. System inventory

### 1.1 Engine to KEEP as it is

| System (path) | Purpose | Size | Fate and notes |
|---|---|---|---|
| core/ (BackgroundLoad, StartupPrefetch, StartupProfile, InputSetup, Hit) | Threaded loading, timing, default keys, damage routing | 342 | KEEP. `data/startup/prefetch.json` (33 KB) lists frontier files; regenerate it. |
| player/player.gd (FrontierPlayer) | Third-person controller, CS-style aim, stances, mount/aboard, arena switch | 1,811 (+221 on spellcraft) | KEEP. Builds the musket, pistol and bow in `_build_weapons` (38 firearm mentions). Spellcraft's `arena` flag already makes a gunless player: use it as the template for an "unarmed world" player. **Shared with Tidebreak.** |
| player/player_anim.gd + player/anim/ (26 files) | AnimationTree facade: LocoBrain, UpperBody, TreeBuilder, inertializers, aim stabilizer, IK | 1,671 + 12,186 | KEEP the core. RETIRE the gun-only modules (left_grip_ik, right_seat_ik, trigger_finger, gun_middle_carry_ik, gun_carry_damper, quick_offhand, musket_butt_ground: about 1.5k lines). 15 anim files mention firearms, so this is careful surgery, not a delete. **Shared with Tidebreak** (SwayPose/BendPoses play through it). |
| character_body.gd (CharacterBodyMesh), bone_mannequin, camera_shake, player_ragdoll, player_traversal | Skinned body on Actor_B, ragdoll, shake | about 2.5k | KEEP for human-shaped peoples. Non-human bodies (Floodborn, Mộc Tinh) need their own rigs; see 1.4. |
| player_wounds, player_blood_trail | Bleeding and blunt damage, no slows (owner rule) | 330 | KEEP. Already follows "hits never slow or hurt aim". |
| animations/ + animations_extra/ | Actor_B library (47 MB) and own authored clips (Own, Form, Forage, Locomotion, Traversal, Bend on spellcraft) | 63 MB | KEEP. Provenance stays as `animations/SOURCE.md` and `docs/animation_provenance.md` record it: the owner reports AI-assisted Blender authoring with YouTube as tutorials and references, and `Actor_B.res` lineage is listed there as not yet verified. The conversion changes none of that. New clips (Floodborn tail and gait, fox tail, Mộc Tinh motion, peoples' arts) come from the existing own-clip pipeline (tools/anim_author/blender). |
| traversal/ (26 + markers) | Vault, ladder, ledge, step assist, motion warping | 11,934 + data 11 MB | KEEP. Ledge baking works on any geometry, which suits stilt platforms, terraces and karst. |
| climb/player_grip, grip_*, perch_branches, tree_climb | Rock-face and moving-body grip, branch perches, tree climbing | about 2.4k | KEEP. Trường Sơn cliffs, Lâm Uyên trees and Thạch Uyên quarries fit. |
| net/ (NetSession, NetWildlife) | Co-op/PvP host-join, mirrored animals | 973 | KEEP. |
| save/ (SaveGame, SaveParts, DeathRule, PackDrop) | Saves per system, death drops the pack | 1,590 | KEEP the engine. Old saves are void (new world). The DeathRule respawn needs a framing decision because the bible's "the dead do not return" (owner question). |
| world/nav/ (NavWorld, NavMover, WalkGrid, WalkPath, NavLandmarks, RouteDecision) | NPC pathfinding | 3,275 | KEEP. Landmarks are the fort's gates today: reskin to bridges, locks and quays. Boats and water routes are not in nav yet; a river world will want water legs (L). |
| world/env/ (EnvironmentRig, DayNight, WorldClock, WeatherSystem, CloudField, GodRays, ForestLight, sky_*, grade_lut) | Sky, sun and moon, clouds, weather, light, grade | about 3.2k | KEEP and RETUNE: WorldClock's site is 43°N 74.5°W (Mohawk Valley) and the calendar is 1765. Move to a tropical latitude, set monsoon weather chains (S-M) and a new grade LUT (owner judges by eye). RETIRE wonder_look, sky_traffic and sky_tear (348 lines: sky galleons and the Downbelow story). |
| world/settings/, world_settings.gd | Quality presets, upscaling | 710 | KEEP. |
| fx/ (Fx, BloodFx, Anatomy, BodyModel, BodyBuild, InspectView, BoneRagdoll) | Particles, anatomically fitted hit bodies | 4,218 | KEEP. Fx.gd's powder-smoke effects go with guns. BodyBuild fits a human (or quadruped) skeleton, so a Floodborn body needs a fit (M). |
| interact/ (PlayerInteractor, DroppedItem, PlacedWeapon, WeaponRack, WeaponState) | E-interaction and world-placed gear | 1,728 | KEEP the interactor. Reskin racks to spear and tool racks. |
| inventory/, ui/inventory/, ui/character/, ui/hotbar, equip_wheel, how_to, trajectory_preview | Pack, chest, clothes, craft, skills, condition, hotbar | about 6.5k | KEEP. Text and icons get new content. Hotbar and HUD are **shared with Tidebreak** (heavily modified on spellcraft). |
| ui/hud.gd (FrontierHUD), ui/menu/* (MainMenu, PauseMenu, LoadingScreen, MenuPaintings, GameSettings) | HUD serif lettering, menus, painted loading screens | 951 + 1,359 | KEEP and RESKIN. Fonts are **SystemFont** (Baskerville/Georgia/Avenir), with no font file in the project, so Vietnamese diacritics depend on the OS fallback. Bundle a font with full Vietnamese coverage (S-M; owner question on the source). Menu rows "Story: Two Fires" and "Duel (test)" retire. MainMenu, HUD and loading screen are **shared with Tidebreak**. |
| audio/ engine (Sfx, AmbienceBed, Footsteps, MusicDirector, manifests) | Buses, voices, ambience, footsteps, music director | 2,204 | KEEP the engine. Content is in 1.5. WeaponAudio (319) retires with guns. |
| survival/ core (SurvivalCore, Clock, Needs, Conditions, Skills, Learning, Jobs, Inventory, Trade, Economy, Weather, Save, Sim) | Logic-only survival simulation and economy | 11,657 + sim 2,073 | KEEP the engine. All data is 1765 (see 1.3). SurvivalLearning (heard-of, seen, known, taught by NPCs) fits D-rule "expertise can be taught and shared": use it for how the peoples' arts are learned. |
| companion/ engine (Household, SpouseCore, HouseholdCrew, JobBook, ToolPool, WorkerOrders, Growth, Teaching, Recruit) | Household workers, supply chains, children growing up, recruiting | about 15k of 21.6k | KEEP the engine. RESKIN jobs.json, tools.json and recruit.json (region_peoples and names). See 1.6 for intimacy, pregnancy and cross-people children. |
| rts/ (RtsMode, RtsFell, RtsOrders, RtsHud) | Command mode over the household | 801 | KEEP. Felling needs the forest-consent rule (1.6). |
| perf/hitch_log, addons/release_metadata | Hitch log, export metadata plugin | small | KEEP. |
| tests/ | 232 headless tests | 12 MB | KEEP the harness. Roughly 60-70 test files assert frontier content: weapons, loadout, story, fort, survival balance, wildlife species. They must be retired or rewritten with their systems; budget this inside each item. |

### 1.2 RESKIN (same system, new content)

| System | Purpose | Size | Thủy Vân content | Effort |
|---|---|---|---|---|
| **world/water/ (WorldRiver, RiverWater) + boats/WaterSurface** | Procedural river with meanders, rapids, wading, drinking and ice; boats float on it | 587 + 29 | The best reusable piece for a river world. **Book I's opening phenomenon, Đá Trắng's stopped reach ("white stones visible beneath stopped water; fish suspended"), is a flow-speed and fish-behaviour change on this shader and FishLife: a cheap, strong set piece.** Its limit: one river function, no canals, delta channels, lakes, tide or sea. A general water network is REWORK (L). | M to reskin, L for the network |
| **boats/ (Boat, BoatRider, BoatStand, BoatBuild, HullMesh, 5 puzzles)** | Small boats with own physics, paddling, stage-by-stage building with puzzles | 2,830 + data 7 KB | RESKIN, with high value. The birchbark canoe, war canoe and rowboat become a dugout, a sampan or plank skiff, a river barge, and possibly a woven basket boat (coracle). The PitchSpread puzzle maps to resin-coating a woven hull; StakeBed, Lashing and RibSteam map to frame and plank work; BarkFit becomes weaving. Hulls are procedural from plans.json, so new hulls are data plus HullMesh stations. Left over from before: rowing animation, crew seats, the lake. | M-L |
| building/ (BuildMode, BuildSnap, BuildWorld, BuiltPiece, BuildGeometry, doors, campfire, chests, smokehouse, woodpile, cradle, StoreLedger) | Socket-snapping builder, 39 pieces | 6,210 | The engine and the ledger are KEEP. BuildGeometry (1,608 lines) is all log cabin, palisade and shingle, so RESKIN to stilt houses, bamboo and reed roofs, platforms over water (needs a "stands in water" snap rule; one already exists for the boat stand), terraces, kilns and stone (Thạch Uyên). fort_pieces, fort_plan and palisade_cuts RETIRE (1,042). | L |
| gathering/ (GatherTools, FelledTree, VegHarvest, GatherModels, TreeHarvest, ToolPose) | Felling, mining, skills | 4,307 | Engine KEEP. GatherModels' 1750s American felling axe and mattock become a dao/axe, hoe and pick, plus bamboo cutting. TreeHarvest's birch bark and wattap get new materials. | M |
| forage/ (ForageField, ForageModels, ForagePick, ForageUse) | Wild food and herbs, procedural plant models | 2,521 + 26 plants | RESKIN all 26 North American plants (plantain, yarrow, ginseng, wintergreen, groundnuts...) to the bible's medicinal gardens, lotus, water greens and the like. The models are own procedural code, so this is a data and model job. | M |
| farming/ (FarmField, FarmModels) | Hoed beds, Three Sisters, tobacco, flax | 1,337 | REWORK more than reskin: rice paddies need bunds and flooding (water level per bed), and terrace grain (Mountain Folk) needs slopes. Dry beds stay for gardens. | M-L |
| fishing/ (FishingGear, FishFightGauge, FishModels, RodStance) | Rod, spear, weir, fish fight | 1,472 | Keep the mechanics. RESKIN gear; nets and traps are new (M). | S-M |
| wildlife/fish/ (FishLife, FishMesh, FishSpecies, FishStock) + data/world/fish.json | Fish with minds, own procedural meshes | 2,298 + 9 species | RESKIN 9 North American species to carp, catfish, eel, snakehead and other river fish. The meshes are own procedural code. FishLife's "suspended fish" behaviour serves the Silence. | M |
| wildlife/ (WildAnimal, WildGroup, WildPlanner, Ecology, Land, Spawner, BirdLife, owl, raven, fireflies, field dressing) | Herds, packs, food chain, birds | about 6.4k | Engine KEEP. Species are deer, buck, wolf, fox, bison, mammoth and wild horse. Bodies are Quaternius CC0 stand-ins, a poly.pizza CC-BY owl, and own models (the bison and horse generator, the "smooth" set). New content: goats and mules (both in the stories), water buffalo (a natural reskin of the **bison generator**), small deer, herons and cranes, crows. **Sensitivities:** foxes as game animals beside the fox-blooded Hồ Tinh, and wild crocodiles beside the crocodilian Floodborn, could read as equating a people with an animal. Owner call. | L |
| horse/ (Horse, HorseCart, Wheelbarrow, HorseHaul, SkidLoad, CarcassLoad, HorseBreaking, rider link, terrain) | Riding, carts, log skidding, carcass haul, taming | 8,958 | The bible has almost no horses (2 mentions in the stories); mules and goats appear. RESKIN the generator to a mule or pack pony and a buffalo cart; the wheelbarrow keeps. Whether anyone rides is an owner question. Horse breaking may retire. | M-L |
| torch/ (PlayerTorch, TorchFire, DroppedTorch, TorchModels, TorchState) | Hand torch | 1,644 | RESKIN the pitch-pine torch to a bamboo/oil torch or a lantern (lanterns appear on every city sheet). | S |
| fire/ (FireSpread, FireFx, FireRuin, FireTorch) | Built pieces burn and fall to ruin | 2,209 | KEEP. Canon has burnings: the Ash Coast port burnings, H12 forest fires, H17 burned homes in the Reed Marches. | S |
| snow/ (SnowCover, SnowFall, SnowPrints, SeasonLeaves, RiverIce) | Winter snow, prints, river ice, autumn leaves | 1,012 | Mostly RETIRE for the lowlands. Keep the code for Trường Sơn heights only if the owner wants cold passes ("winter and washouts can close the fastest route", L04). SeasonLeaves maps to dry and wet seasons. | S |
| survival_game/ (SurvivalBridge, CampStation, CampCooking, Sleep, TrapStation, ClothesSlots, LastingConditions, Remedies, HandCraft, BareStart) | The world side of survival | 7,795 | KEEP the bridge, sleep, stations and conditions. RESKIN the stations (tanning frame, alchemy table) to kilns, a weaving frame and a herbalist table. RETIRE shot_making (casting lead balls). Vices (rum, tobacco, clay pipe; 955 lines) are an owner call: rice wine or betel, or retire. | M |
| customizer tattoos / PeopleEmblem | Tattoo editor; one line-art emblem per people | 812 + 659 | Systems KEEP. Content: all 35 real-people emblems and the period tattoo designs RETIRE. New: 8 emblems and the peoples' marks (Mountain Folk tattoos appear on their sheet). | M |
| world/story_layer (StoryLayer, StoryLayerProps) | Year layers of a place: what stands and who lives where, in a given year | 998 | KEEP. It fits Book I directly: a "before" and an "after the river stops" layer of the same region. data/world/layers/1757.json RETIRES. | S |

### 1.3 REWORK (the system stays; data model or logic changes)

| System | Purpose | Size | What changes | Effort |
|---|---|---|---|---|
| **customizer/** (CharacterCreator, CreatorOptions, CreatorStage, CustomizerOverlay, BodyMaterials, FaceExtras, PlayerAppearance, PlayerOutfit, CharacterPeoples, AppearanceStore, OutfitTab) + assets/character/body/peoples.json + data/customizer/world_peoples.json | Face engine on a MakeHuman-based body v4. Lists 35 real peoples, or the 4-people test (Downbelowers, Driftborn, Keelfolk, the Etched) | 8,967 code; body 33 MB, hair 48 MB | **world_peoples.json is already the right shape:** groups, invented peoples that keep every real face (no people maps onto one real ancestry), skin, eye and hair ranges, and a `trait` in the skin shader (people_trait.gdshaderinc: the Keelfolk's glowing flecks, the Etched's veins). Replace the 4 test peoples with P01-P08. Shader traits can carry Dragon-Sea scales and reflective eyes, Stone Children's mineral patches, and Riverborn blue skin with gills (gills also need a head morph). Hồ Tinh need ear and tail attachments plus tail bones (M-L). **Floodborn** (a full crocodilian head, snout, tail and scaled body on their sheet) and **Mộc Tinh** (wood bodies, vines) cannot be done on the MakeHuman body. Each needs its own body, rig and clip set: **XL each**. The bible says they are "not humans in costumes". Ancestor-Bound is a human lineage, not a body type, so it is a creator background, not a body. The old "Downbelow/Drift" test data and the 35-people list RETIRE from the creator (keep the faces). | L for 6 human-shaped peoples; XL x2 for the others |
| assets/character/garments (cloth2 pipeline: tools/character/build_cloth2.py, cloth_bake, catalog.json) | 129 garment GLBs in 11 sets: colonial, frontier, military, militia, woodlands, drift, africa, middle_east, highland, spanish, southeast_asia | 68 MB + catalog 912 KB | The pipeline is KEEP. **Nearly every garment RETIRES:** 1750s European, colonial and military dress; Eastern Woodlands dress held for consultation; real-people period dress; the Downbelow sky crews. Spellcraft's own Tidebreak ring garments (tunics, wide and wrapped trousers, sashes, arm wraps, a parka) are the closest starting point. New: Common Folk dress per people (the lineup sheet), layered silk and lacquer for the court, woven armour for the Mountain Folk, shade cloth for the Stone Children, Riverborn wet-wear, conical hats and headwraps. Roughly 60-100 garments for a first set. | XL |
| Hair (assets/character/hair, 26 styles) | Period and real-people hair: bag wig, queue, chonmage, qing queue, shikha | 48 MB | Generic styles keep. Ethnic and period styles leave the default lists. New: topknots, long loose hair, buns with pins and ornaments (every sheet). | M |
| npc/ (NpcFighter, NpcBrain, NpcCover, NpcSenses, NpcSquad, NpcBody, NpcLoot, NpcFactions, NpcBall) + data/npc/factions.json | Human fighters: patrol, notice, cover, squads | 4,416 (+ about 1.6k on spellcraft) | The engine is KEEP and **shared with Tidebreak**: NpcBending (1,441 lines on spellcraft) drives element bots through NpcFighter and NpcBody. factions.json (French marines, Canadian militia, valley militia, toughs, watchmen of 1757) RETIRES. New sides: Cửu Giang navy and toll guards, Floodborn war-clans (Ruk-Khan's and Tal-Kesh's factions differ), Mountain clan levies, Stone House crews, Hollow Communion. **Bible rule: no faction is the good one.** NpcFactions' `hostile` lists must be situational (per mission or per reputation), not a fixed good-versus-evil table. Fighters carry muskets today (NpcBall, musket anims); they switch to spears, bows and peoples' arts. The spellcraft bots are the template. | L |
| story/ engine (StoryDirector, Objectives, Effects, HUD, Dialogue, Contact, Bark, Walker, Actor) | Data-driven storylines, missions, dialogue, contacts | 5,051 | KEEP the engine. All content (data/story two_fires: 17 missions, 24 conversations, 17 speakers) RETIRES. The new storyline is "Book I as an ordinary person". The bible's reveal ladder (section 9) maps onto mission flags. Rule: no exposition dump, and nothing about the Ninth River (Memory) in Book I content. | engine S; content L-XL (writing) |
| Survival data (data/survival/*.json, 1 MB with the backlog) | Items (121), recipes (18), actions (46), skills (10), NPC archetypes, economy and markets, seasons (a 36-day year, the 1765 New York calendar), livelihoods, map regions | 1 MB | All rows are 1765: venison, cornmeal, johnnycake, rum, pelts, trade-post coin, firewood contracts. Rewrite for Thủy Vân. **The bible supplies the economy:** stamped bronze cash for small trade, silver-weight accounting, grain shares, witnessed service tallies, and no single coin across regions. Seasons become wet and dry; staples become rice, fish, salt and rope. The balance sim (SurvivalSim) re-runs on the new data. | L |
| data/items/item_text.json (151 items), data/companion/lines.json, recruit names | Player-facing descriptions and lines | about 50 KB | Rewrite in English with Vietnamese names and English titles. | M |
| **Terrain** (world/terrain: FrontierTerrain 803, FrontierGrass 535; tools/environment/terrain/bake_terrain.py; assets/environment/terrain 66 MB) | Baked height field per 832 m square, splat, grass | 1,338 + tools | The engine can take new height fields (bake_terrain.py cuts the river bed from squares.json). **What it cannot do:** karst towers and waterfalls (the Trường Sơn sheet) need mesh rock pieces, not a height field. A delta of islands and canals (Vạn Thủy) needs the water network. New terrain for every region is content. squares.json's frontier grid (old woods, cliffs, marsh, lake) RETIRES. | XL across the regions; L for one Book I home region |
| **Vegetation** (world/vegetation: VegLayout 1,637, FrontierVegetation, VegAssets, impostors, painted LOD look; assets 89 MB + Poly Haven models 160 MB) | Trees, undergrowth, rocks, logs, woodlots, canopy light | 3,510 | The layout and impostor engine is KEEP. Every species is North American (pine, oak, birch, hemlock). New sets: bamboo, banyan and fig, mangrove (Reed Marches), lotus and water plants (Deep Lotus Reaches), rice, palms, terrace crops, the giant root forest of Lâm Uyên. | XL |
| Structures kit (world/structures: StructureMeshKit, StructureGeometry, StructureMaterials) | Procedural building meshes and materials | 1,614 | The kit is KEEP. Fort and range geometry RETIRE (FrontierStructures, FortHollow, FortGate, DummyStyle, TargetDummy). New architecture: lock gates and floodgates, canal steps, pagoda roofs, stilt villages, archive islands, mooring platforms. Every city sheet is dense; one region's town is L, Vạn Thủy is XL. | XL |
| Music cues (tools/music cues, audio/music 514 MB WAV, 55 cues) | Shadow of the Colossus-style cues: VSCO 2 CE orchestra, synth choir, A = 432 Hz | 514 MB | MusicDirector KEEP. Cues: explore, night and home pieces could stay as placeholders. The 35 `people_<id>` themes for real peoples RETIRE, and so do the "Frontier folk air in D dorian" themes and the Two Fires story cues. New: 8 people themes and region cues. VSCO is a Western orchestra; Vietnamese and Southeast Asian timbres (đàn bầu, đàn tranh, sáo, gongs) are not in it, so they need synthesis or own recordings (owner question). Repo size: 514 MB of WAV, and an earlier unpushed commit holds 283 MB of them. | L |
| SFX and ambience (audio/sfx 59 MB, AmbienceBed bird recordings) | Gun sounds, North American birds and forest | 59 MB | Gun sounds RETIRE. Ambience gets new birds, insects, water and markets. Tidebreak's 142 own synthesized element sounds (spellcraft tools/sfx/bend) carry over. | M |

### 1.4 Tidebreak and the magic stack (spellcraft branch, read-only)

| System | Purpose | Size | Fate |
|---|---|---|---|
| sway/ (SwayCaster, SwayEffects, SwayPose, SwayRing, SwayThread, SwayTone, GustLift, Form*) on main | "The Sway": timed lock-on magic of the Downbelow story, with the Form (alchemy) art | 5,954 on main; about +1.8k on spellcraft | Engine KEEP: Tidebreak's casting runs on SwayCaster. RETIRE the player-facing names ("the Sway", "the Form", "Gust"), the Downbelow lore and the story grant. Note `FormMatter`: "the matter comes from the place" (a mud wall from mud, wood from a tree). That matches the bible's "power weakens away from home" and needs the relevant setting. Keep it. |
| bending/ (BendCaster, BendEffects, BendBolt, BendZone, BendKnock, BendLooks, BendSounds, BendStatus, BendPoses, Bending) on spellcraft | Four element kits, effects, statuses, water meter | about 5.2k | REWORK into peoples' arts (owner decision 3). The water meter that draws from pools is already relational ("needs the relevant setting"); keep it. The four-element set (earth, water, fire, air) is itself the show's shape. **Fire has no canon home:** Dragon-Sea explicitly have "no fire breath", and the owner's fox-fire for Hồ Tinh is a later kit. **Air has none either.** Owner question below. Bible limits to carry over: a trained practitioner, a relationship or pact, the setting, and **a stated cost** for each art. Tidebreak's free casting plus Mend/Heal have no cost beyond lock time. |
| ring/ (RingLevel, RingArena, RingRules, RingMode, RingMenu, RingDressing, RingCrowd, RingLessons, MatchSetup...) on spellcraft | The Tidebreak ring sport, its own light scene | about 6.6k | KEEP as a sport of the world, e.g. a festival or river-guild sport held in a town. RingLevel is deliberately separate from the open world (it turns WorldRiver off and never loads the terrain), so it keeps working as a separate scene reached from a town. Reskin RingDressing banners and friezes from element colours to peoples' or guild colours. |
| npc_bending, npc_bend_caster on spellcraft | Element bots | 1,564 | KEEP as the template for Thủy Vân NPC practitioners. |
| ui/bend_strip, match_bar, round_screen, lesson_card, first_hints, radial_wheel on spellcraft | Tidebreak HUD | about 2.1k | KEEP within the sport. first_hints and lesson_card double as the open world's "earn the cosmology" teaching. |

Show words: spellcraft has none in visible UI text. "bend", "waterbender" and "avatar the last airbender" appear only in internal names, `_doc` strings and code comments (data/sway/moves.json, data/npc/bend_ai.json, ring_level.gd and ring_arena.gd headers). Internal class names (Bending, BendCaster) are not player-facing. The visible element labels "Earth / Water / Fire / Air" (match_setup.gd) should become the peoples' art names.

### 1.5 RETIRE (1765-specific; to git history)

| What | Size | Notes |
|---|---|---|
| weapons/ (Musket, FlintlockPistol, Firearm, OverUnder*, MusketReload, MusketButtGround, ballistics/arc balance, WeaponModels for guns) | about 7.2k of 7,189 lines; data/weapons 208 KB (range_research.json 195 KB); assets/weapons 18 MB | **No gunpowder exists in the bible.** Keep Bow (Mountain Folk hunting, archers in the stories), Projectile, the throwing spear (spears in the stories), Throwable and Weapon. Retire the tomahawk and atlatl (North American). The saber pose maps to a dao (data/anim_author/saber_pose, grip_saber.glb). 108 script files mention firearms, so retiring guns touches player, anim, npc, companion (HuntKit muskets), loadout, story, audio and UI. Spellcraft's `arena` switch shows how to run with no gun built. |
| loadout/ (SlingRig 3,396, sling models, carry rules, LoadoutKeys...) + data/loadout 4.2 MB + assets/loadout 3.7 MB | 7,062 | The 1750s carry kit (powder horn, cartridge box, musket slings). The owner already replaced rigs on character slots with the hotbar (2026-10-02). Keep SlingRig's body-surface strap code only if slung spears and bows stay visible on the body (owner question). Otherwise retire most of it. |
| duel/ (DuelMode, DuelArena, DuelMenu): the 1v1 musket duel test | 983 (+201 on spellcraft) | Superseded by Tidebreak. Spellcraft's MatchSetup uses DuelMode paths, so retire after checking that link (it is **shared code**). |
| story stages: RaidStage, MarchStage, RookWalk, SkyBattle, WreckFall, StorySlice (Two Fires, 1757) | 5,982 | Retire. Captivity (1,038) is a reusable "taken, bound, led" engine; keep it only if a Book I mission needs it. |
| Fort and range: FrontierStructures, FortHollow, FortGate, DummyStyle, TargetDummy, FortPieces, FortPlan, PalisadeCuts + data/building/fort_*.json | 3,897 | The level's centre today. `frontier_level.gd` (238) is rewritten as the new region's level script (S-M). |
| Mammoth: StandInGiant, MammothTemper, MammothButchery, LimbCarcass (+ assets/wildlife/ice_age) | 2,321 | Not canon. The climb-a-moving-body engine (PlayerGrip) stays. Giants or great spirits in Thủy Vân are an owner question; the bible says spirits are local and relational. |
| Wonder sky (WonderLook, SkyTraffic, SkyTear) and sky galleons | 348 + tools | Downbelow and Treasure Planet direction, not Thủy Vân. |
| 1765 data: data/world/squares.json, woodlots, river_boulders, layers/1757; data/story/*; data/npc/factions.json; data/customizer/creator.json's 35 emblems and groups; recruit region_peoples; docs/main_story.md (103 KB), docs/maps.md, docs/peoples_world.md, docs/research/* | about 400 KB of data, 250 KB of docs | To history. docs/animation_provenance.md and docs/legal stay. |
| Period content in tests | about 60-70 files | Retire with each system. |

### 1.6 Bible and owner rules that collide with existing systems

1. **Intermarriage and children:** Pregnancy, ChildLook.from_parents, ChildProportion and Growth (about 5k lines) make a child's look from both parents. The bible deliberately leaves "detailed intermarriage biology" unlocked (section 15). Across Floodborn, Mộc Tinh and human-shaped peoples, the system would decide canon. Owner decision needed before cross-people households ship. The intimacy and tandem yoga features (features/tandem 12 MB, companion intimacy, pregnancy, tandem and yoga: about 1.5k lines) are engine-neutral; whether they stay in Thủy Vân is the owner's call.
2. **Felling and forest consent:** GatherTools, RtsFell and the household woodcutting fell any tree. In canon, logging and fire are Mộc Tinh's historical wound, Lâm Uyên needs grove permission, and harvesting is negotiated. A per-region consent or consequence rule is a new hook (M).
3. **Death:** DeathRule respawns the player where they last slept. The bible says death is final, though that rule governs characters. The owner should confirm that a respawn is a game convention, or frame it (for example, a wound and rescue rather than death).
4. **Arts cost:** Tidebreak casting costs only lock time, and Mend heals. The bible requires a named obligation for power (exhaustion, debt, loss of access). For the open world, add a cost track (M). The sport can keep its own rules.
5. **Peoples are not classes:** the player picks a people in the creator. Arts must be learnable through relationships (SurvivalLearning), not locked by people ("eight peoples do not supply eight irreplaceable racial keys"). Tidebreak's "pick one element" fits a sport, but in the world it must not mean "your race = your class".
6. **No target cues:** WorkerOrders draws a ring at a picked worker's feet. That is a friendly command marker, not an enemy cue, so it is fine. The duel and spellcraft bots "MAY show its cast circle at its feet" (an owner-approved exception). Nothing new.
7. **The Ninth River:** no system references it. Keep it out of item text, loading-screen captions and menu paintings.

## 2. Shared code between the open world and Tidebreak

Spellcraft changed these main files. A conversion on main must merge spellcraft first, or touch them only after it lands, to avoid conflicts:
- scripts/player/player.gd (+221: the arena switch)
- scripts/npc/npc_body.gd (+198), npc_fighter.gd (+147), npc_squad.gd (+57), npc_brain.gd
- scripts/sway/sway_caster.gd (+584), sway_pose.gd (+403), form_effects.gd (+407), form_raised.gd, gust_lift.gd, sway_effects.gd, form_* files
- scripts/ui/hud.gd (+267), hotbar.gd (+154), equip_wheel.gd, how_to.gd, inventory_screen.gd, hotbar_row.gd
- scripts/ui/menu/main_menu.gd (+510), loading_screen.gd (+114), game_settings.gd
- scripts/duel/duel_mode.gd (+139), duel_menu.gd
- scripts/customizer/player_appearance.gd (+71: arena_dress)
- scripts/core/input_setup.gd, scripts/world/water/world_river.gd (+17: `WorldRiver.off`)

Tidebreak also depends on main systems: EnvironmentRig, WorldSettings, FrontierTerrain (it is turned off), Sfx, MusicDirector, GameSettings, NpcSenses, NpcFactions, NpcLoot and PlayerAppearance.

**Recommendation:** merge worktree-spellcraft into main (the owner's call) *before* any Thủy Vân conversion edits. The improvement loop is still committing there, so convert in a branch off the merged head.

Keep internal class names (FrontierPlayer, FrontierHUD, FrontierTerrain): about 300 references, and renaming them is pure churn against concurrent sessions. Change only player-facing names. **Warning:** changing `project.godot` `config/name` ("Frontier") moves `user://`, which holds the settings, saves and the player's saved look, unless `use_custom_user_dir` is set. The description "Colonial frontier third-person shooter" also changes.

## 3. Reusable for a river world: the strongest carry-overs

- **The water:** RiverWater/WorldRiver with flow, rapids, wading and drinking, plus FishLife's fish with minds. The stopped river of Book I's first chapter is the system's own parameters (flow 0, fish suspended), not new tech.
- **Boats:** own physics, paddling, crouch-and-fight aboard, a stand where hulls grow by stage, five building puzzles graded rather than pass/fail, and knowledge-gated guidance. Thủy Vân is a boat culture ("household boat ownership ties status to water").
- **Household and supply chains:** jobs, a tool pool, ledgers kept in storage ("memory lives in the world thing"), and farming and hunting chains. This echoes the bible's ledgers, tallies and witnessed records.
- **SurvivalLearning:** knowledge from NPCs that is heard of, seen, taught and practised. It is the delivery system for "the player earns the cosmology" and for learnable arts.
- **StoryLayer year layers:** the same region before and after the river stops.
- **Fire spread and ruin:** burned moorings and port burnings.
- **Climbing, traversal and tree perches:** karst cliffs, stilt villages, root forests.
- **The creator's invented-peoples format (world_peoples.json) and the skin "trait" shader:** six of the eight peoples can be built on it.
- **NetSession co-op and the RTS command mode:** carry over unchanged.

## 4. The size of what must be replaced (content)

| Content | Today | Thủy Vân first playable (one Book I region) |
|---|---|---|
| Terrain | 2 baked squares, about 1.4 km² | 1 region (for example Đá Trắng's foothill reach plus a lock town). Karst and cliff mesh kit. Region-to-region travel later. |
| Water | 1 river function | The river plus canals and lock pools in that region. The full delta later. |
| Vegetation | North American forest set | Bamboo, banyan, rice, lotus, reeds and one tree family (impostors and painted LOD per species). |
| Buildings | Fort, cabin, palisade (39 build pieces) | Stilt house, reed and tile roofs, lock gate, quay steps, shrine; 30-40 build pieces. |
| Peoples' bodies | 1 human body, 35 real presets, 4 test peoples | 6 human-shaped peoples on body v4 with traits, ears and tail. Floodborn and Mộc Tinh as XL tracks (possibly NPC-only first, with player-selectable later as an owner call). |
| Dress | 129 period garments | 60-100 new garments, Common Folk first. |
| Hair | 26 styles | 10-15 new styles. |
| Wildlife | Deer, wolf, fox, bison, mammoth, horse, owl, raven, 9 fish | Goat, mule, water buffalo, small deer, herons and cranes, crows, 8-10 river fish. |
| Items and recipes | 121 + 151 text rows, 18 recipes, 46 actions | A full rewrite. |
| Story | Two Fires (17 missions, 24 dialogues) | Book I storyline for an ordinary person: new writing. |
| Music | 55 cues (514 MB) | 8 people themes and 6-8 region cues; instrument timbre decision. |
| Peoples' arts | 4 element kits (spellcraft) | Water and earth mapped, with costs; fire and air need a decision. |

## 5. Honest effort picture

- **Code cleanup and engine prep:** about 3-5 weeks. This covers the spellcraft merge, retiring guns, loadout, fort, duel, wonder and old story (with their tests), a new level script, the region and water network groundwork, fonts, WorldClock retune, factions as data, the arts cost track and forest consent.
- **First playable region with human-shaped peoples:** about 2-4 months of content work. That is terrain, vegetation, buildings, dress, wildlife, items and one Book I story arc. Asset generation is serialized because only one Blender and one Godot run at a time.
- **Floodborn and Mộc Tinh as full bodies:** about 1-2 months each, covering a new body, rig, deformation, clips, garments, the BodyModel fit and creator support.
- **The full atlas (L01-L16) as an open world:** a multi-month programme beyond that, and it needs real streaming or regional levels.

## 6. Review images the owner should see (they judge by eye)

1. Concept-sheet versus in-game lineups per people, with the existing tools: world_peoples_shots.gd, creator_shots.gd, face_portraits.gd.
2. A Common Folk garment lineup (outfit_shots.gd, ring_outfit_shots.gd) before and after.
3. Stopped-river A/B stills: flowing versus stopped, fish suspended (scenic_shots.gd pattern).
4. Boat lineup: canoe today against the dugout, sampan, barge and basket boat (boat_shots.gd).
5. Vegetation A/B: the North American forest against a bamboo and banyan test plot (forest_shots.gd).
6. Building kit lineup: log cabin against a stilt house with reed and tile roofs (structure_shots.gd).
7. Wildlife lineup: bison against water buffalo from the same generator (the bison lineup pattern).
8. Sky and grade A/B: the Mohawk latitude against the tropical latitude with the new LUT (god_rays_shots.gd, scenic_shots.gd).
9. Font sheet: HUD and menu text with Vietnamese diacritics ("Vạn Thủy, Capital of the Waters", "Hồ Tinh, the fox-blooded") in candidate fonts.
10. Arts VFX lineup: each Tidebreak kit renamed and recoloured as a people's art (vfx_lineup.gd on spellcraft).
