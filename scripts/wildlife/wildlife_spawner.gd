class_name WildlifeSpawner
extends Node3D
## The level's wildlife (first playable wildlife, 2026-09-26): herds of deer (does with a buck in some), a lone buck,
## foxes, a wolf pack and a band of wild horses (WildHorse; caught whole and given back, take_alive / release:
## HorseBreaking), placed in the forest round the fort and kept stocked; the world state the animals read.
##
##   var w := WildlifeSpawner.new(); w.name = "Wildlife"; add_child(w); w.setup(player, vegetation, environment_rig)
##
## Placement: on the terrain (FrontierTerrain.height_at), never within FORT_CLEAR of the fort or on the range lane
## (except the "range herd", grazing at the lane's far end where it is seen from the firing line), 1.2 m clear of
## every trunk (FrontierVegetation.layout.tree_pos). A group that is gone (shot, skinned, or wandered off the map)
## The land's numbers (WildlifeEcology: how many deer, wolves, foxes and mammoths it holds, growing while they are fed,
## one fewer for each that dies; user 2026-09-27, "if they keep eating without dying they populate more", no bar for the
## player) run with the game's days (_tick_ecology); every RESTOCK_S the bodies in the world are kept to them, out of
## sight RESPAWN_MIN_D+ from the player (_restock): a kill is not undone, the land breeds it back. Hungry for want of
## deer, the wolves are bolder by day (boldness), range nearer the fort and howl more (WildPlanner).
## Performance: animals further than ACTIVE_D from the player stop thinking and animating; beyond VISIBLE_D they are
## hidden. The brains: WildPlanner plans every group once a second (routines, memory, roles, the food chain; see it and
## WildGroup); find_place() picks feeding (open) and bedding (cover) places from a cover grid of the forest layout's
## trunks and undergrowth, away from remembered danger. Carcasses stay until they are eaten to the bones (ravens,
## foxes, wolves: user 2026-09-26, "instead of disappearing carcass we can have wolves and ravens come and eat the
## remains"); ravens come to every carcass (_ravens). A carcass is anything in the group "carcasses" with meat_left
## and eat(amount) (a dead WildAnimal, a chopped-off LimbCarcass, the dead mammoth's MammothButchery.Carcass;
## optional: species, eat_radius (m from its middle to where a scavenger eats), remove_carcass()); it touches itself
## (touch()) when a scavenger feeds or someone works on it. One left alone UNTOUCHED_S of real time is removed
## (_sweep_carcasses). A carcass on a horse's rope (CarcassLoad) is never cleared and no scavenger goes for it; its
## clock counts from where it was let go. Calls: sound() (the public-domain recordings).
## World state for the animals: `now` (s), the wind (the wind_direction / wind_strength globals: scent),
## boldness() (predators: 1 from dusk to dawn and at the golden hour, sun below 22 deg; 0.35 by day), nearest_fire()
## (lit torches in the hand, stuck in the ground or lying: TorchFire.GROUP), gunshots (each weapon's `fired`: muskets
## and pistols heard SHOT_LOUD_M away, bows and throws SHOT_QUIET_M).
## The land beyond the fort (user 2026-09-28: the bison "in the open plains a lot of them"; "reuse a lot of the animal
## things for different animals"): every built square of the world (WorldSquares: the fort's woods, the open land east
## of it) holds its own animals, its numbers (WildlifeLand) kept in bodies the same way, each group on its own square
## (range_of: the fort's LIMIT / WildAnimal.WORLD_LIMIT round the fort, a square's half less EDGE_M elsewhere). What a
## species is and does is its entry in WildlifeSpecies (its group, how a shortfall is made up, its brain, its traits);
## the squares beyond the fort draw on their own random numbers (_far_rng: the fort's woods stock as they always did).
## Off with the user arg wildlife=off; tool and test scripts (-s) run without it unless they pass wildlife=on.

const FORT_CLEAR := 60.0
const LANE_HALF_X := 22.0
const LANE_Z := Vector2(-195.0, 0.0)
const LIMIT := 300.0
## A square beyond the fort's: its animals kept this far inside its edges (placing; moving, EDGE_M * 0.5).
const EDGE_M := 60.0
const ACTIVE_D := 220.0
const VISIBLE_D := 300.0
const RESTOCK_S := 45.0
const RESPAWN_MIN_D := 150.0
const SHOT_LOUD_M := 260.0
const SHOT_QUIET_M := 20.0
const LOUD := ["musket", "over_under", "pistol"]
## The most drops of blood on the ground at once (all trails). Over it, the trail with the most drops loses its oldest
## (so a new slaughter does not wipe out the trail being followed).
const MAX_DROPS := 500
## Drops age (user 2026-09-28: "lets apply this drop age"): fresh and bright for DROP_FRESH_S (the wolves' nose too:
## WildAnimal.BLOOD_FRESH_S), darkening to dried brown by DROP_DARK_S (DROP_DRY, each look's), fading into the ground
## from DROP_FADE_S and gone at DROP_GONE_S (a game day). Their age by the game's clock (a night slept through dries a
## trail) or by the time played, whichever is more (drop_age). Drawn out to DROP_SEEN_M.
const DROP_FRESH_S := 180.0
const DROP_DARK_S := 900.0
const DROP_FADE_S := 1800.0
const DROP_GONE_S := 3456.0
const DROP_SEEN_M := 60.0
const DROP_DRY := {
	"": Color(0.17, 0.07, 0.045),
	"red": Color(0.17, 0.07, 0.045),
	"froth": Color(0.26, 0.09, 0.085),
	"gut": Color(0.065, 0.016, 0.01),
}
## The drops' looks, by wound (WildlifeSpecies.WOUNDS look): [colour, marks' colour, size x]. "red" bright blood (the
## heart, a leg, a graze, the head), "froth" the lungs' pink froth and its bubbles, "gut" dark smears (few, but wide:
## what leaks from the paunch spreads) with its green flecks; "" (the player's, a splash of no wound) the plain dark red.
const DROP_LOOKS := {
	"": [Color(0.3, 0.015, 0.015), Color.BLACK, 1.0],
	"red": [Color(0.36, 0.015, 0.015), Color.BLACK, 1.0],
	"froth": [Color(0.52, 0.1, 0.11), Color(0.8, 0.46, 0.46), 1.0],
	"gut": [Color(0.09, 0.02, 0.012), Color(0.24, 0.26, 0.05), 1.7],
}
## The player's own drops kept for the wolves (the newest), PlayerBloodTrail.
const PLAYER_BLOOD_MAX := 120
## The wounded animals' drops kept for the wolves' noses (the newest), WildPlanner's blood trails.
const ANIMAL_BLOOD_MAX := 400
## Cover grid: cell size (m); a cell's cover counts the trunks and the undergrowth in it and its neighbours.
const COVER_CELL := 6.0
const COVER_HALF := 56                 ## cells each way from the centre (+-336 m)
## Ravens: at most this many in the world, the first ones RAVEN_AFTER s after a death.
const MAX_RAVENS := 14
const RAVEN_AFTER := 25.0
## Real seconds to a game day where there is no world clock (a test, a tool): forage.json's game_day_s.
const GAME_DAY_S := 3456.0
## A wolf pack takes no more than this (more wolves: a pack of their own).
const PACK_MAX := 7
## Bones are cleared this long after the last meat is gone.
const BONES_S := 120.0
## A carcass nothing has gone for (no scavenger feeding, no one butchering or hauling it) this long is removed: 10
## minutes of real time, the spawner's clock (play time: it stops while the game is paused) (user 2026-09-27: "10 min
## timer if nothing goes for it it gets removed from the bored", "real time"). In a multiplayer session only
## (cleanup_untouched): a single player's carcasses stay, and are saved (user 2026-09-28: "for single player yes save
## it but multiplayer we do that").
const UNTOUCHED_S := 600.0
## The old name of the clean-up age (CarcassLoad, tests/horse/test_haul.gd): an untouched carcass goes after this.
const CARCASS_S := UNTOUCHED_S

## The fort's woods' first stocking: how many of each group (WildlifeSpecies.GROUPS: their members and sizes).
const STOCK := {
	"deer_herd": {"count": 4},
	"lone_buck": {"count": 1},
	"fox": {"count": 3},
	"wolf_pack": {"count": 1},
	# (a band of woods horses, strays gone wild: user 2026-09-28, "a herd of wild horses that can be tamed")
	"horse_herd": {"count": 1},
}
## The herd seen from the firing line: grazing in the meadow at the right of the lane's far end (off the targets' line).
const RANGE_HERD_HOME := Vector3(22.0, 0.0, -148.0)

var player: FrontierPlayer
var vegetation: FrontierVegetation
var environment_rig: EnvironmentRig
var now := 0.0
var wind := Vector2.ZERO
var wind_strength := 0.3
## The player's blood on the ground (user 2026-09-27: "bleeding on humans should also leave trails as well for other
## people to find"): {pos, t (now)}, oldest first.
var player_blood: Array[Dictionary] = []
## The wounded animals' blood on the ground, oldest first: [{pos, t, who}] (who: the WildAnimal that bled it).
var animal_blood: Array[Dictionary] = []
var groups: Array[Dictionary] = []      ## [{kind, group: WildGroup}]
## Skinning and butchering with the knife (the carcasses' E).
var dressing: FieldDressing
## The level's wild food plants (ForageField; null without): deer feed where their food grows.
var forage: ForageField
## Needs run this much faster than game time (tests; 1 in play).
var time_scale := 1.0
## Living wolves and prey (refreshed twice a second).
var live_wolves: Array[WildAnimal] = []
var live_prey: Array[WildAnimal] = []
## The last gunshot (ravens take off).
var last_shot_time := -1e9
var last_shot_pos := Vector3.ZERO
## [id, time] of every call played (tests).
var sound_log: Array = []
## Every square's numbers (WildlifeLand: the world's squares, each its type's animals and meters); this level's own, the
## fort's square (0, 0), as `ecology`; the game day they were last run to (-1: not yet).
var land := WildlifeLand.new()
## The squares beyond the fort's draw their random numbers here (the fort's woods keep `rng` as they always had it).
var _far_rng := RandomNumberGenerator.new()
var ecology: WildlifeEcology = land.ecology(Vector2i.ZERO)
var _eco_day := -1.0
var _eco_t := 0.0
var _plants_t := 0.0
var _rock_n := -1
var rng := RandomNumberGenerator.new()

var _trees := PackedVector3Array()
var _fires: Array[Vector3] = []
var _fires_t := 0.0
var _lod_t := 0.0
var _restock_t := 0.0
var _world_t := 0.0
var _drops: Array[Decal] = []
var _drop_texs := {}
var _age_t := 0.0
var _note_label: Label
var _note_t := 0.0
var _serial := 0
var _lists_t := 0.0
var _plan_t := 0.0
var _raven_t := 0.0
var _cover := PackedFloat32Array()


static func enabled() -> bool:
	var arg := ""
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("wildlife="):
			arg = s.get_slice("=", 1)
	if arg != "":
		return arg != "off" and arg != "0"
	# tool and test scripts (-s ...) keep their scenes as they were
	var args := OS.get_cmdline_args()
	return not ("-s" in args or "--script" in args)


func setup(p: FrontierPlayer, veg: FrontierVegetation, rig: EnvironmentRig) -> void:
	player = p
	vegetation = veg
	environment_rig = rig
	rng.seed = 1765
	_far_rng.seed = 1766
	if veg and veg.layout:
		_trees = veg.layout.tree_pos
	_build_cover()


func _ready() -> void:
	add_to_group(&"wildlife_spawner")
	_build_note()
	dressing = FieldDressing.new()
	dressing.name = "FieldDressing"
	dressing.player = player
	dressing.spawner = self
	add_child(dressing)
	_hook_weapons.call_deferred()
	_populate.call_deferred()


func _populate() -> void:
	_spawn_group("deer_herd", RANGE_HERD_HOME, true)
	for kind: String in STOCK:
		var want := int(STOCK[kind].count) - (1 if kind == "deer_herd" else 0)
		for i in want:
			var home := _find_spot(90.0, 280.0, Vector3.ZERO, false)
			if home != Vector3.INF:
				_spawn_group(kind, home, false)
	# the land's numbers start as the woods were stocked (a save's come back over them: SaveParts.load_wildlife)
	var live := live_counts(Vector2i.ZERO)
	for s: String in ["deer", "wolf", "fox", "horse"]:
		ecology.pop[s] = float(live.get(s, 0))
	# the squares beyond: bodies to their numbers (the open land's bison herds, its deer, wolves and foxes)
	for sq in stocked_squares():
		if sq != Vector2i.ZERO:
			for i in 12:
				if not _stock_square(sq, false):
					break


## The world's squares that hold animals in bodies: those built (WorldSquares "built": the fort's woods, the open land).
static func stocked_squares() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for sq in WorldSquares.squares():
		if bool(WorldSquares.type_of(sq).get("built", false)):
			out.append(sq)
	if not out.has(Vector2i.ZERO):
		out.push_front(Vector2i.ZERO)
	return out


## Square `sq`'s middle and how far from it (either way along x and z) its animals keep: [Vector3, float]; `moving`
## the bounds they turn back at (WildAnimal._move), else those they are placed within.
static func range_of(sq: Vector2i, moving := false) -> Array:
	if sq == Vector2i.ZERO:
		return [Vector3.ZERO, WildAnimal.WORLD_LIMIT if moving else LIMIT]
	return [WorldSquares.center_of(sq), WorldSquares.size_m() * 0.5 - EDGE_M * (0.5 if moving else 1.0)]


## The living animals in the world by species (a stag a deer): {deer, wolf, fox, bison}; with `sq`, those on it.
func live_counts(sq := Vector2i(-99, -99)) -> Dictionary:
	var out := {}
	for a in animals():
		if not a.is_dead() and (sq.x == -99 or a.home_sq == sq):
			var s := WildlifeEcology.kind_of(a.species)
			out[s] = int(out.get(s, 0)) + 1
	return out


## The game days since the last look run on the land's numbers (a night slept runs as the days it was).
func _tick_ecology() -> void:
	# the land's plants (every half minute: a look over every patch)
	_plants_t -= 2.0
	if _plants_t <= 0.0:
		_plants_t = 30.0
		if forage == null and is_inside_tree():
			forage = ForageField.find(get_tree())
		if forage:
			ecology.plants = forage.plant_level()
		var vh := VegHarvest.find(get_tree()) if is_inside_tree() else null
		if vh:
			_read_meters(vh)
	var d := game_day()
	if _eco_day >= 0.0 and d > _eco_day and d - _eco_day < 60.0:
		land.advance(d - _eco_day, month())
	_eco_day = d


## The fort's square's trees and stone as they stand, of its type's: the trees not felled, the rock not quarried
## (VegHarvest).
func _read_meters(vh: VegHarvest) -> void:
	if vh.lay == null or not land.meters.has(Vector2i.ZERO):
		return
	var t := WorldSquares.type_of(Vector2i.ZERO)
	var m: Dictionary = land.meters[Vector2i.ZERO]
	var trees_n := (vh.lay.tree_pos as PackedVector3Array).size()
	m.trees = float(t.get("trees", 1.0)) * (1.0 - float(vh.felled.size()) / float(maxi(trees_n, 1)))
	if _rock_n < 0:
		_rock_n = 0
		for k: int in vh.lay.prop_kind:
			if k >= VegHarvest.Assets.ROCK_FIRST and k <= VegHarvest.Assets.ROCK_LAST:
				_rock_n += 1
	var gone := 0.0
	for i in vh.rock_size:
		gone += 1.0 - float(vh.rock_size[i])
	m.stone = float(t.get("stone", 0.3)) * (1.0 - gone / float(maxi(_rock_n, 1)))


## The month (1-12): the world clock's; without one, September (the game's start).
func month() -> int:
	if environment_rig and environment_rig.clock_driver and environment_rig.clock_driver.clock:
		return WorldClock.month_of(environment_rig.clock_driver.clock.day_of_year) + 1
	return 9


## The game's time in days: the world clock's; without one, `now` over GAME_DAY_S.
func game_day() -> float:
	if environment_rig and environment_rig.clock_driver and environment_rig.clock_driver.clock:
		var c: WorldClock = environment_rig.clock_driver.clock
		return float(c.year) * 366.0 + c.day_of_year + c.hour / 24.0
	return now / GAME_DAY_S


## An animal died (WildAnimal._die): one fewer in the land's numbers (`by` a wolf: the wolves' hunting).
func animal_died(a: WildAnimal, by: String) -> void:
	land.at(a.global_position).on_death(a.species, by)


# --- Groups --------------------------------------------------------------------------------------

## `size`: its members (a herd, a pack); -1 as its group kind has it (WildlifeSpecies.GROUPS).
func _spawn_group(kind: String, home: Vector3, in_lane: bool, size := -1) -> WildGroup:
	var gd: Dictionary = WildlifeSpecies.GROUPS[kind]
	var r := _rng_for(home)
	var g := WildGroup.new()
	g.home = home
	g.species = String(gd.species)
	var sz: Array = gd.size
	var n := size if size > 0 else (int(sz[0]) if int(sz[0]) == int(sz[1]) else r.randi_range(int(sz[0]), int(sz[1])))
	var ms: Array = gd.members
	var members: Array[String] = []
	for i in n:
		# [first, its share, the rest] (a buck at the head of does), or [every one]
		if ms.size() >= 3:
			members.append(String(ms[0]) if i == 0 and r.randf() < float(ms[1]) else String(ms[2]))
		else:
			members.append(String(ms[0]))
	for sp in members:
		_add_member(g, sp, in_lane)
	g.activity_since = now
	g.activity = WildGroup.Activity.BED if String(gd.get("starts", "feed")) == "bed" else WildGroup.Activity.FEED
	g.last_howl = now - r.randf_range(200.0, 330.0)      # the first howl a minute or two in
	groups.append({"kind": kind, "group": g})
	return g


## The random numbers for a place: the fort's woods its own (as they always were), the squares beyond theirs.
func rng_for(p: Vector3) -> RandomNumberGenerator:
	return _rng_for(p)


func _rng_for(p: Vector3) -> RandomNumberGenerator:
	return rng if WorldSquares.square_at(p) == Vector2i.ZERO else _far_rng


## One more `sp` in group `g`, near its home (a wanderer joining a pack, a herd's member). Null when there is no room.
func _add_member(g: WildGroup, sp: String, in_lane := false) -> WildAnimal:
	var r := _rng_for(g.home)
	var pos := _near(g.home, 7.0 * float(WildlifeSpecies.get_data(sp).get("spacing", 1.0)), in_lane)
	if pos == Vector3.INF:
		return null
	var a := WildlifeSpecies.make(sp)
	_serial += 1
	a.name = "%s_%d" % [sp.capitalize(), _serial]
	a.setup(sp, self, g, 1765 + _serial * 7919)
	add_child(a)
	a.global_position = pos + Vector3.UP * 0.02     # on the ground: an animal far away starts asleep (_lod)
	a.rotation.y = r.randf() * TAU
	g.members.append(a)
	return a


## A living animal taken out of the wild whole (HorseBreaking: a wild horse caught): out of its group, which takes
## alarm and remembers the place, and one fewer in the land's numbers; the body goes.
func take_alive(a: WildAnimal) -> void:
	var pos := a.global_position
	if a.group:
		a.group.members.erase(a)
		a.group.raise_alarm(pos, now)
		a.group.remember(pos, 1.0, now)
	var e := land.at(pos)
	var s := WildlifeEcology.kind_of(a.species)
	if e.pop.has(s):
		e.pop[s] = maxf(float(e.pop[s]) - 1.0, 0.0)
	remove_animal(a)


## One taken out whole back in the wild (a wild horse that threw its rider): `species` at `xf` as it was (`st`: its
## health, hunger, fatigue, coat, gentled, whatever it has of them), in `g` when that group still lives within 400 m,
## else in a group of its own; one more in the land's numbers. It bolts from `from`.
func release(species: String, xf: Transform3D, st: Dictionary, g: WildGroup, from: Vector3) -> WildAnimal:
	var d := WildlifeSpecies.get_data(species)
	if g == null or g.alive().is_empty() or g.centroid().distance_to(xf.origin) > 400.0:
		var kind := String(d.get("group", ""))
		g = WildGroup.new()
		g.home = xf.origin
		g.species = String((WildlifeSpecies.GROUPS.get(kind, {}) as Dictionary).get("species", species))
		g.activity_since = now
		groups.append({"kind": kind, "group": g})
	var a := WildlifeSpecies.make(species)
	_serial += 1
	a.name = "%s_%d" % [species.capitalize(), _serial]
	a.setup(species, self, g, 1765 + _serial * 7919)
	for k: String in st:
		if k in a:
			a.set(k, st[k])
	var flat := -xf.basis.z
	a.transform = global_transform.affine_inverse() * Transform3D(Basis(Vector3.UP, atan2(-flat.x, -flat.z)), xf.origin)
	add_child(a)
	g.members.append(a)
	var e := land.at(xf.origin)
	var s := WildlifeEcology.kind_of(species)
	if e.pop.has(s):
		e.pop[s] = minf(float(e.pop[s]) + 1.0, e.cap_of(s) + 1.0)
	a._start_flee(from)
	return a


## All living and dead animals (for tests and tools).
## The animals in the world (not those already on their way out: queued to be freed this frame).
func animals() -> Array[WildAnimal]:
	var out: Array[WildAnimal] = []
	for c in get_children():
		if c is WildAnimal and not c.is_queued_for_deletion():
			out.append(c)
	return out


## An animal leaves the world: out of the live lists at once (they are rebuilt only now and then, and a deer reading a
## freed wolf from them was an error), then freed.
func remove_animal(a: WildAnimal) -> void:
	live_wolves.erase(a)
	live_prey.erase(a)
	a.queue_free()


## The live wolves still in the world (the list, less any freed since it was built).
func wolves_now() -> Array[WildAnimal]:
	var out: Array[WildAnimal] = []
	for w in live_wolves:
		if is_instance_valid(w) and not w.is_queued_for_deletion():
			out.append(w)
	return out


# --- Placement -----------------------------------------------------------------------------------

func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, FrontierTerrain.height_at(x, z), z)


## A place an animal may be put: on a stocked square (`sq`: that one), within its bounds (range_of), clear of the fort,
## the range lane and the trunks.
func _ok(p: Vector3, in_lane: bool, sq := Vector2i(-99, -99)) -> bool:
	var at := WorldSquares.square_at(p)
	if sq.x != -99 and at != sq:
		return false
	if at != Vector2i.ZERO and not stocked_squares().has(at):
		return false
	var rg := range_of(at)
	var c: Vector3 = rg[0]
	if absf(p.x - c.x) > float(rg[1]) or absf(p.z - c.z) > float(rg[1]):
		return false
	if Vector2(p.x, p.z).length() < FORT_CLEAR:
		return false
	if not in_lane and absf(p.x) < LANE_HALF_X and p.z > LANE_Z.x and p.z < LANE_Z.y:
		return false
	for t in _trees:
		if absf(t.x - p.x) < 1.2 and absf(t.z - p.z) < 1.2:
			return false
	return true


func _near(home: Vector3, r: float, in_lane: bool) -> Vector3:
	var rr := _rng_for(home)
	var sq := WorldSquares.square_at(home)
	for i in 20:
		var a := rr.randf() * TAU
		var d := rr.randf_range(0.0, r)
		var p := _ground(home.x + cos(a) * d, home.z + sin(a) * d)
		if _ok(p, in_lane, sq):
			return p
	return Vector3.INF


## A spot min_d..max_d from `center` (on square `sq` when given); unseen = behind the player's view (restocking).
func _find_spot(min_d: float, max_d: float, center: Vector3, unseen: bool, sq := Vector2i(-99, -99)) -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var r := rng if sq.x == -99 or sq == Vector2i.ZERO else _far_rng
	for i in 40:
		var a := r.randf() * TAU
		var d := r.randf_range(min_d, max_d)
		var p := _ground(center.x + cos(a) * d, center.z + sin(a) * d)
		if not _ok(p, false, sq):
			continue
		if unseen and cam and cam.global_position.distance_to(p) < VISIBLE_D:
			var to := (p - cam.global_position).normalized()
			if to.dot(-cam.global_basis.z) > 0.2:
				continue
		return p
	return Vector3.INF


# --- Frame ---------------------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	now += dt
	_eco_t -= dt
	if _eco_t <= 0.0:
		_eco_t = 2.0
		_tick_ecology()
	_age_t -= dt
	if _age_t <= 0.0:
		_age_t = 2.0
		_age_drops()
	_world_t -= dt
	if _world_t <= 0.0:
		_world_t = 1.0
		# the ground wind from the weather, which DayNight copies into the wind shader globals (reading a global back
		# from the renderer stalls it and logs an engine error each time); no DayNight (headless): as it was
		var wx: WeatherSystem = environment_rig.clock_driver.weather if environment_rig and environment_rig.clock_driver else null
		if wx:
			wind = wx.wind_ground_dir
			wind_strength = wx.wind_ground_strength
	_fires_t -= dt
	if _fires_t <= 0.0:
		_fires_t = 0.5
		_fires.clear()
		for f in get_tree().get_nodes_in_group(TorchFire.GROUP):
			var tf := f as TorchFire
			if tf and tf.is_inside_tree() and (tf.state == null or tf.state.lit):
				_fires.append(tf.global_position)
	_lists_t -= dt
	if _lists_t <= 0.0:
		_lists_t = 0.5
		_refresh_lists()
	_plan_t -= dt
	if _plan_t <= 0.0:
		_plan_t = 1.0
		for e in groups:
			WildPlanner.plan(e.group, self)
	_raven_t -= dt
	if _raven_t <= 0.0:
		_raven_t = 1.0
		_ravens()
	_lod_t -= dt
	if _lod_t <= 0.0:
		_lod_t = 0.5
		_lod()
	_restock_t -= dt
	if _restock_t <= 0.0:
		_restock_t = RESTOCK_S
		_restock()
	if _note_t > 0.0:
		_note_t -= dt
		_note_label.modulate.a = clampf(_note_t, 0.0, 1.0)


func _lod() -> void:
	if player == null:
		return
	var pp := player.global_position
	for a in animals():
		var d := a.global_position.distance_to(pp)
		var busy := a.state in [WildAnimal.State.FLEE, WildAnimal.State.CHASE, WildAnimal.State.STALK]
		a.set_active(d < ACTIVE_D or busy)
		a.visible = d < VISIBLE_D
		if a.is_dead():
			pass                           # (carcasses: _sweep_carcasses)
		else:
			# wandered off its land (its square's bounds and a margin), or fallen through the ground
			var rg := range_of(a.home_sq)
			var off := a.global_position - (rg[0] as Vector3)
			if absf(off.x) > float(rg[1]) + 60.0 or absf(off.z) > float(rg[1]) + 60.0 or a.global_position.y < -50.0:
				remove_animal(a)
	_sweep_carcasses()


## Whether untouched carcasses are cleared (UNTOUCHED_S): in a multiplayer session (a network peer, not Godot's offline
## one); tests set force_cleanup.
var force_cleanup := false


func cleanup_untouched() -> bool:
	if force_cleanup:
		return true
	var mp := multiplayer
	return mp != null and mp.has_multiplayer_peer() and not (mp.multiplayer_peer is OfflineMultiplayerPeer)


## The carcasses' clocks: each stamped with `now` when it is first seen (died_at), last touched (touched_at: a
## scavenger feeding, someone working on it) and picked clean (bones_at). Bones go BONES_S after the last meat (and
## the last touch: the tusks still being chopped off a picked mammoth); a
## carcass nothing has gone for in UNTOUCHED_S (from its death, its last touch or where a horse let it go) is removed
## (in multiplayer only: cleanup_untouched); never one on a horse's rope.
func _sweep_carcasses() -> void:
	for n in get_tree().get_nodes_in_group(&"carcasses"):
		var c := n as Node3D
		if c == null or c.is_queued_for_deletion():
			continue
		if not c.has_meta("died_at"):
			c.set_meta("died_at", now)
		if c.get_meta(&"touched", false):
			c.set_meta(&"touched_at", now)
			c.remove_meta(&"touched")
		if c.get_meta("bones", false) and not c.has_meta("bones_at"):
			c.set_meta("bones_at", now)
		if c.get_meta(&"on_chain", false):
			continue
		var since := maxf(maxf(float(c.get_meta("died_at")), float(c.get_meta(&"hauled_at", -INF))),
				float(c.get_meta(&"touched_at", -INF)))
		var bones_gone: bool = c.get_meta("bones", false) and now - maxf(float(c.get_meta("bones_at", now)), since) > BONES_S
		if bones_gone or (now - since > UNTOUCHED_S and cleanup_untouched()):
			remove_carcass(c)


## A carcass leaves the world (its own remove_carcass() when it has one: the dead mammoth goes whole).
func remove_carcass(c: Node3D) -> void:
	c.remove_from_group(&"carcasses")
	if c is WildAnimal and c.get_parent() == self:
		remove_animal(c as WildAnimal)
	elif c.has_method("remove_carcass"):
		c.call("remove_carcass")
	else:
		c.queue_free()


## Something went for carcass `c` (a scavenger fed, someone worked on it): its clean-up clock starts over.
static func touch(c: Node) -> void:
	c.set_meta(&"touched", true)


## How far from carcass `c`'s middle a scavenger eats (its eat_radius: a mammoth's side, a leg's length; 0 a deer).
## Untyped: a scavenger may still hold a carcass that has since been eaten up and freed (0 then).
static func carcass_rim(c) -> float:
	var r: Variant = c.get(&"eat_radius") if c != null and is_instance_valid(c) else null
	return float(r) if r != null else 0.0


## Keeps the bodies in the world to the land's numbers (WildlifeEcology.targets): short, some come in out of sight (a
## herd of the deer missing, a wolf to the pack or a new pack, a fox); over (the land could not feed them), one goes
## off out of sight. One change a restock: the woods fill and thin gradually.
func _restock() -> void:
	if player == null:
		return
	groups = groups.filter(func(e: Dictionary) -> bool: return not (e.group as WildGroup).alive().is_empty())
	for sq in stocked_squares():
		if _stock_square(sq, true):
			return


## One step toward square `sq`'s numbers (a group made or joined, or one gone off); `unseen` out of the player's sight.
## True when something was done (one a restock).
func _stock_square(sq: Vector2i, unseen: bool) -> bool:
	var want := land.ecology(sq).targets()
	var live := live_counts(sq)
	for s: String in WildlifeSpecies.eco_kinds():
		var short := int(want.get(s, 0)) - int(live.get(s, 0))
		var f := WildlifeSpecies.filler(s)
		if short >= int(f.get("min", 1)) and _fill(s, short, sq, unseen):
			return true
		if short < 0 and _thin(s, sq):
			return true
	return false


## Makes up `short` of eco kind `s` on square `sq` (WildlifeSpecies "fill"): a member for a group of its kind that has
## room (join: out of the player's sight), else (short new_min or more) a new group of fill.size.
func _fill(s: String, short: int, sq := Vector2i.ZERO, unseen := true) -> bool:
	var f := WildlifeSpecies.filler(s)
	var gk := String(f.get("group", ""))
	if gk.is_empty():
		return false
	if int(f.get("join", 0)) > 0:
		# a wanderer joins a group out of the player's sight (a pack, a herd); enough of them, a group of their own
		var ms: Array = (WildlifeSpecies.GROUPS[gk] as Dictionary).members
		for e in groups:
			var g: WildGroup = e.group
			if String(e.kind) == gk and WorldSquares.square_at(g.home) == sq and g.alive().size() < int(f.join) \
					and g.centroid().distance_to(player.global_position) > RESPAWN_MIN_D:
				return _add_member(g, String(ms[ms.size() - 1])) != null
		if short < int(f.get("new_min", 1)):
			return false
	var home := Vector3.INF
	if sq == Vector2i.ZERO:
		home = _find_spot(RESPAWN_MIN_D, 280.0, player.global_position, unseen, Vector2i.ZERO)
	else:
		# a square beyond the fort's: anywhere on it, out of the player's sight (far off it, anywhere)
		var rg := range_of(sq)
		home = _find_spot(0.0, float(rg[1]), rg[0] as Vector3, unseen, sq)
		if home != Vector3.INF and home.distance_to(player.global_position) < RESPAWN_MIN_D:
			home = Vector3.INF
	if home == Vector3.INF:
		return false
	var sz: Array = f.get("size", [])
	_spawn_group(gk, home, false, clampi(short, int(sz[0]), int(sz[1])) if sz.size() == 2 else -1)
	return true


## One of `s` goes off (starved, or away for food), out of the player's sight and not busy; never a pack's alpha. With
## `sq`, one of that square's.
func _thin(s: String, sq := Vector2i(-99, -99)) -> bool:
	for a in animals():
		if a.is_dead() or WildlifeEcology.kind_of(a.species) != s or (sq.x != -99 and a.home_sq != sq):
			continue
		if a.global_position.distance_to(player.global_position) < RESPAWN_MIN_D:
			continue
		if a.state in [WildAnimal.State.FLEE, WildAnimal.State.CHASE, WildAnimal.State.STALK, WildAnimal.State.ATTACK]:
			continue
		if a.group and a.group.alpha == a:
			continue
		remove_animal(a)
		return true
	return false


# --- World state ---------------------------------------------------------------------------------

## Predators' daring: 1 when the sun is low or down (dusk, night, dawn, the golden hour); by day 0.35, more as the
## wolves go hungry for want of deer (WildlifeEcology.wolf_hunger: short of deer, they hunt, the player too, by day).
func boldness() -> float:
	return 1.0 if sun_elevation() < 22.0 else day_boldness()


## Their daring by day: 0.35, up to 1 as the wolves go hungry.
func day_boldness() -> float:
	return 0.35 + 0.65 * clampf((ecology.wolf_hunger() - 0.2) / 0.6, 0.0, 1.0)


## Night: the sun more than 4 deg below the horizon (a gunshot then draws the wolves).
func is_night() -> bool:
	return sun_elevation() < -4.0


func sun_elevation() -> float:
	if environment_rig and environment_rig.clock_driver and environment_rig.clock_driver.clock:
		return environment_rig.clock_driver.clock.sun_elevation_deg()
	return WorldClock.DEFAULT_SUN_ELEVATION_DEG


## The nearest lit fire within r of pos, or Vector3.INF.
func nearest_fire(pos: Vector3, r: float) -> Vector3:
	var best := Vector3.INF
	var bd := r
	for f in _fires:
		var d := f.distance_to(pos)
		if d < bd:
			bd = d
			best = f
	return best


func _hook_weapons() -> void:
	if player == null:
		return
	for key: String in player.weapons:
		var w: Weapon = player.weapons[key]
		if w and not w.fired.is_connected(_on_fired):
			w.fired.connect(_on_fired.bind(key))


func _on_fired(key: String) -> void:
	shot(player.global_position, SHOT_LOUD_M if key in LOUD else SHOT_QUIET_M)


## A loud noise at pos heard radius m away (gunshots; tests).
func shot(pos: Vector3, radius: float) -> void:
	last_shot_time = now
	last_shot_pos = pos
	for a in animals():
		if not a.is_dead():
			a.hear(pos, radius)


# --- The brains' world ---------------------------------------------------------------------------

## The hour of the day (the world clock's; the level's validated golden hour when it has none).
func hour() -> float:
	if environment_rig and environment_rig.clock_driver and environment_rig.clock_driver.clock:
		return environment_rig.clock_driver.clock.hour
	return 17.0


func _refresh_lists() -> void:
	live_wolves.clear()
	live_prey.clear()
	for a in animals():
		if a.is_dead():
			continue
		# the pack hunters, and the wolves' prey (WildlifeSpecies "hunted": any of them, or only a weak one)
		var hunted := String(a.data.get("hunted", ""))
		if String(a.data.get("brain", "")) == "pack":
			live_wolves.append(a)
		elif hunted == "any" or (hunted == "weak" and a.weak()):
			live_prey.append(a)


func _build_cover() -> void:
	var n := COVER_HALF * 2
	_cover.resize(n * n)
	_cover.fill(0.0)
	for t in _trees:
		_cover_add(t, 1.0)
	if vegetation and vegetation.layout:
		for q in vegetation.layout.plant_pos:
			_cover_add(q, 1.6)                  # saplings and shrubs: the thick cover deer bed in


func _cover_add(p: Vector3, w: float) -> void:
	var n := COVER_HALF * 2
	var cx := int(floor(p.x / COVER_CELL)) + COVER_HALF
	var cz := int(floor(p.z / COVER_CELL)) + COVER_HALF
	if cx >= 0 and cz >= 0 and cx < n and cz < n:
		_cover[cz * n + cx] += w


## Cover at (x, z): 0 open ground .. 1 thick (trunks and undergrowth in the 18 m round it).
func cover(x: float, z: float) -> float:
	if _cover.is_empty():
		return 0.5
	var n := COVER_HALF * 2
	var cx := int(floor(x / COVER_CELL)) + COVER_HALF
	var cz := int(floor(z / COVER_CELL)) + COVER_HALF
	var s := 0.0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var i := cx + dx
			var j := cz + dz
			if i >= 0 and j >= 0 and i < n and j < n:
				s += _cover[j * n + i]
	return clampf(s / 12.0, 0.0, 1.0)


## A place in the group's range for its activity: "open" (feeding: little cover), "cover" (bedding: thick cover) or
## "any" (a wolf patrol), away from the danger the group remembers and (prey) from the player; not far off.
func find_place(g: WildGroup, kind: String) -> Vector3:
	var best := Vector3.INF
	var bs := -INF
	var from := g.centroid()
	var prey := WildlifeSpecies.brain(g.species) != "pack"
	# deer feed where their food grows (ForageField; user 2026-09-26: "plants and herbs will be the same things deer
	# eat so we know where they will be"): the feeding spots in the range are candidates too, the richest pulling most
	if forage == null and is_inside_tree():
		forage = ForageField.find(get_tree())
	var spots := forage.deer_spots(g.home, 75.0, 8) if kind == "open" and WildlifeSpecies.get_data(g.species).get("forage", false) and forage else []
	var home_sq := WorldSquares.square_at(g.home)
	var r := _rng_for(g.home)
	# (a big herd ranges wider: its members' room, WildlifeSpecies "spacing")
	var reach := 75.0 * maxf(float(WildlifeSpecies.get_data(g.species).get("spacing", 1.0)) * 0.5, 1.0)
	for i in 28 + spots.size():
		var p: Vector3
		var food := 0.0
		if i < 28:
			var a := r.randf() * TAU
			var d := r.randf_range(8.0, reach if kind != "any" else 110.0)
			p = _ground(g.home.x + cos(a) * d, g.home.z + sin(a) * d)
		else:
			# (a spot's own offset, not the spawner's rng: the herds' other random choices stay as they were)
			var s: Dictionary = spots[i - 28]
			var o := Vector2.from_angle(float(int(s.patch) * 7919 % 628) / 100.0) * 0.8
			p = _ground(float(s.pos.x) + o.x, float(s.pos.z) + o.y)
			food = float(s.food)
		if not _ok(p, g.home.distance_to(RANGE_HERD_HOME) < 20.0, home_sq):
			continue
		var cv := cover(p.x, p.z)
		var sc := 0.0
		match kind:
			"open":
				sc = 1.0 - cv + minf(food / 4.0, 1.0) * 1.2
			"cover":
				sc = cv
			_:
				sc = 0.5 + r.randf() * 0.4
		sc -= g.danger_at(p, now) * 1.5
		sc -= from.distance_to(p) * 0.003
		if prey and player:
			sc -= clampf(1.0 - player.global_position.distance_to(p) / 60.0, 0.0, 1.0) * 0.8
		if sc > bs:
			bs = sc
			best = p
	return best


## The prey a pack goes after: the nearest deer, the wounded first; the player's wounded only when the land is short of
## deer (WildPlanner.TRACK_HUNGER: plenty, the wolves do not steal his game).
func pick_prey(pos: Vector3, r: float) -> WildAnimal:
	var best: WildAnimal = null
	var bs := INF
	var take_his := ecology.wolf_hunger() >= WildPlanner.TRACK_HUNGER
	for a in live_prey:
		if not is_instance_valid(a) or a.is_queued_for_deletion() or (not take_his and players_game(a)):
			continue
		var d := a.global_position.distance_to(pos)
		if d > r:
			continue
		var sc := d - (1.0 - a.health / float(a.data.health)) * 80.0
		if sc < bs:
			bs = sc
			best = a
	return best


## The nearest carcass with meat within r of pos: for a fox only one no wolf is at and the player is not near; for the
## wolves the player's kill only when the land is short of deer (WildPlanner.TRACK_HUNGER), and with him at it only when
## they are starving (STARVE_HUNGER: then they turn on him there, WildAnimal._predator).
func nearest_carcass(pos: Vector3, r: float, who: String) -> Node3D:
	var best: Node3D = null
	var bd := r
	var hunger := ecology.wolf_hunger()
	for n in get_tree().get_nodes_in_group(&"carcasses"):
		var c := n as Node3D
		if c == null or c.is_queued_for_deletion() or float(c.get(&"meat_left")) <= 0.1 or c.get_meta("bones", false) \
				or c.get_meta(&"on_chain", false) or c.has_meta(&"hunted_by"):
			continue   # (hunted_by: a household hunter's kill, left while she fetches the horse or the barrow: HuntRun)
		if who == "wolf" and players_game(c) and (hunger < WildPlanner.TRACK_HUNGER or (hunger < WildPlanner.STARVE_HUNGER
				and player != null and player.global_position.distance_to(c.global_position) < WildPlanner.KILL_GUARD_M)):
			continue
		if who == "wolf" and hunger < WildPlanner.STARVE_HUNGER and not people_near(c.global_position, WildPlanner.KILL_GUARD_M, player).is_empty():
			continue   # (PEOPLE: a worker at it keeps the pack off, as the player does)
		var d := c.global_position.distance_to(pos)
		if d < bd and (who != "fox" or safe_for_fox(c)):
			bd = d
			best = c
	return best


func safe_for_fox(c: Node3D) -> bool:
	for w in wolves_now():
		if w.global_position.distance_to(c.global_position) < 25.0:
			return false
	return people_near(c.global_position, 30.0).is_empty()


## PEOPLE: the humans the wild keeps away from as it does from the player (user 2026-09-29: "the scavengers should be scared
## of the npc like human, the same things as the player model"): the player and the household's and the recruits' bodies,
## each in the group PEOPLE. Those alive within `r` of `pos` (not `but`).
const PEOPLE := &"people"


func people_near(pos: Vector3, r: float, but: Node = null) -> Array:
	var out := []
	for n in get_tree().get_nodes_in_group(PEOPLE):
		var b := n as Node3D
		if b == null or b == but or not is_instance_valid(b) or b.is_queued_for_deletion() or b.get(&"is_dead") == true:
			continue
		if b.global_position.distance_to(pos) < r:
			out.append(b)
	return out


## A call at pos (the recorded wolf chorus, fox, raven; Sfx), logged for the tests.
func sound(id: StringName, pos: Vector3) -> void:
	sound_log.append([String(id), now])
	if sound_log.size() > 200:
		sound_log.pop_front()
	if Sfx.has(id):
		Sfx.play_3d(id, pos)


## Ravens to the carcasses: a few per carcass (more on a big one), flying in from afar after RAVEN_AFTER s.
func _ravens() -> void:
	var count := {}
	var total := 0
	for n in get_tree().get_nodes_in_group(&"ravens"):
		var r := n as Raven
		if r and is_instance_valid(r.carcass):
			count[r.carcass] = int(count.get(r.carcass, 0)) + 1
		total += 1
	if total >= MAX_RAVENS:
		return
	for n in get_tree().get_nodes_in_group(&"carcasses"):
		var c := n as Node3D
		if c == null or c.is_queued_for_deletion():
			continue
		var meat := float(c.get(&"meat_left"))
		if meat <= 0.05 or now - float(c.get_meta("died_at", now)) < RAVEN_AFTER or c.get_meta(&"on_chain", false) \
				or c.has_meta(&"hunted_by"):
			continue
		if player and c.global_position.distance_to(player.global_position) > ACTIVE_D:
			continue
		# more on a big one: a deer, a mammoth (its meat in deer: several)
		var want := 2 + (1 if meat > 0.5 else 0) + (1 if str(c.get(&"species")) in ["deer", "stag"] else 0) \
				+ (2 if meat > 3.0 else 0)
		if int(count.get(c, 0)) < want and rng.randf() < 0.35:
			var rv := Raven.new()
			_serial += 1
			rv.name = "Raven_%d" % _serial
			rv.setup(self, c, 1765 + _serial * 31)
			add_child(rv)
			var a := rng.randf() * TAU
			rv.global_position = c.global_position + Vector3(cos(a) * 90.0, 35.0, sin(a) * 90.0)
			return


# --- Blood, notes --------------------------------------------------------------------------------

## Where a hit lands: blood splashed ahead of it (`who`: the animal hit, its trail begins here; `look`: its wound's).
func blood_splash(point: Vector3, dir: Vector3, who: WildAnimal = null, look := "") -> void:
	for i in 3:
		var off := Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35)) + dir.normalized() * 0.6
		blood_drop(point + off, 1.4, who, look)


## A drop of the player's blood (PlayerBloodTrail): on the ground as any, and kept (where, when) for the wolves' noses.
func player_blood_drop(pos: Vector3, size := 1.0) -> void:
	blood_drop(pos, size)
	player_blood.append({"pos": pos, "t": now})
	if player_blood.size() > PLAYER_BLOOD_MAX:
		player_blood.pop_front()


## The freshest drop of a wounded animal's blood (not a wolf's, none in `skip`: instance ids) within `r` m of any of `at`
## no older than `age` seconds: {pos, t, who}, or {}: a trail for a pack short of deer (WildPlanner).
func fresh_trail(at: Array, r: float, age: float, skip := {}) -> Dictionary:
	for i in range(animal_blood.size() - 1, -1, -1):
		var b: Dictionary = animal_blood[i]
		if now - float(b.t) > age:
			break
		var who = b.who
		if not is_instance_valid(who) or (who as WildAnimal).species == "wolf" or skip.has((who as Object).get_instance_id()):
			continue
		for q: Vector3 in at:
			if (b.pos as Vector3).distance_to(q) < r:
				return b
	return {}


## The newest drop of `who`'s blood within `r` m of `from` no older than `age` seconds (the trail on ahead of a wolf that
## has it), or {}.
func trail_ahead(who: WildAnimal, from: Vector3, r: float, age: float) -> Dictionary:
	for i in range(animal_blood.size() - 1, -1, -1):
		var b: Dictionary = animal_blood[i]
		if now - float(b.t) > age:
			break
		if b.who == who and (b.pos as Vector3).distance_to(from) < r:
			return b
	return {}


## The newest drop of `who`'s blood (where its trail ends so far), or {}.
func trail_end(who: WildAnimal) -> Dictionary:
	for i in range(animal_blood.size() - 1, -1, -1):
		if animal_blood[i].who == who:
			return animal_blood[i]
	return {}


## The player's: an animal he wounded (alive) or killed (dead) that still has its meat on it (not butchered). The wolves
## let it be while the land has deer enough (WildPlanner.TRACK_HUNGER).
static func players_game(a: Node) -> bool:
	var w := a as WildAnimal
	if w == null:
		return false
	return (w.killed_by == "player" and w.dress_step < 2) if w.is_dead() else w.hurt_by == "player"


## The freshest drop of the player's blood within `r` m of `pos` no older than `age` seconds: {pos, t}, or {}.
func fresh_player_blood(pos: Vector3, r: float, age: float) -> Dictionary:
	for i in range(player_blood.size() - 1, -1, -1):
		var b: Dictionary = player_blood[i]
		if now - float(b.t) > age:
			break
		if (b.pos as Vector3).distance_to(pos) < r:
			return b
	return {}


## A drop of blood on the ground at pos (x, z; the height is the terrain's): the trail of a wounded animal (`who`, kept
## for the wolves: animal_blood), as its wound bleeds (`look`: DROP_LOOKS; `size` x the drop's).
func blood_drop(pos: Vector3, size := 1.0, who: WildAnimal = null, look := "") -> void:
	if who != null:
		animal_blood.append({"pos": pos, "t": now, "who": who})
		if animal_blood.size() > ANIMAL_BLOOD_MAX:
			animal_blood.pop_front()
	var d := Decal.new()
	d.texture_albedo = _blood_texture(look)
	d.modulate = Color(1.0, 1.0, 1.0, 0.95)
	var s := rng.randf_range(0.12, 0.22) * size * float((DROP_LOOKS.get(look, DROP_LOOKS[""]) as Array)[2])
	d.size = Vector3(s, 0.8, s)
	d.cull_mask = 1
	_on_ground_only(d)
	add_child(d)
	d.global_position = _ground(pos.x, pos.z) + Vector3.UP * 0.03
	d.rotation.y = rng.randf() * TAU
	adopt_drop(d, look, who.get_instance_id() if who else -1)


## A drop of blood on the ground made elsewhere (BloodFx, the melee's) kept with the rest: it ages (DROP_FRESH_S..) and
## counts in MAX_DROPS, `trail` the id of whose blood it is (its trail: the one with the most drops loses its oldest).
func adopt_drop(d: Decal, look := "", trail := -1) -> void:
	d.set_meta(&"born_s", now)
	d.set_meta(&"born_day", game_day())
	d.set_meta(&"look", look)
	d.set_meta(&"trail", trail)
	d.distance_fade_enabled = true
	d.distance_fade_begin = DROP_SEEN_M - 15.0
	d.distance_fade_length = 15.0
	_drops.append(d)
	if _drops.size() > MAX_DROPS:
		_drop_oldest_of_longest()


## Over MAX_DROPS: the trail with the most drops on the ground loses its oldest one.
func _drop_oldest_of_longest() -> void:
	var count := {}
	for x in _drops:
		if is_instance_valid(x):
			var t: int = x.get_meta(&"trail", -1)
			count[t] = int(count.get(t, 0)) + 1
	var longest := -1
	var most := -1
	for t: int in count:
		if int(count[t]) > most:
			most = int(count[t])
			longest = t
	for i in _drops.size():
		var x: Decal = _drops[i]
		if not is_instance_valid(x) or int(x.get_meta(&"trail", -1)) == longest:
			_drops.remove_at(i)
			if is_instance_valid(x):
				x.queue_free()
			return


## How old drop `d` is (s): by the game's clock or by the time played, whichever is more.
func drop_age(d: Decal) -> float:
	var played := now - float(d.get_meta(&"born_s", now))
	var clock := (game_day() - float(d.get_meta(&"born_day", game_day()))) * GAME_DAY_S
	return maxf(played, clock)


## Every drop to its age's look; those older than DROP_GONE_S gone.
func _age_drops() -> void:
	for i in range(_drops.size() - 1, -1, -1):
		var d: Decal = _drops[i]
		if not is_instance_valid(d):
			_drops.remove_at(i)
			continue
		var age := drop_age(d)
		if age >= DROP_GONE_S:
			_drops.remove_at(i)
			d.queue_free()
			continue
		d.modulate = drop_modulate(String(d.get_meta(&"look", "")), age)


## A drop's colour at `age` (s) over its look's fresh one (its texture's): white while fresh, toward the look's dried
## brown (DROP_DRY) till DROP_DARK_S, then fading out.
static func drop_modulate(look: String, age: float) -> Color:
	var base: Color = (DROP_LOOKS.get(look, DROP_LOOKS[""]) as Array)[0]
	var dry: Color = DROP_DRY.get(look, DROP_DRY[""])
	var k := clampf((age - DROP_FRESH_S) / (DROP_DARK_S - DROP_FRESH_S), 0.0, 1.0)
	var m := Vector3(clampf(dry.r / maxf(base.r, 0.001), 0.2, 3.0), clampf(dry.g / maxf(base.g, 0.001), 0.2, 3.0),
			clampf(dry.b / maxf(base.b, 0.001), 0.2, 3.0))
	var a := 0.95 * (1.0 - clampf((age - DROP_FADE_S) / (DROP_GONE_S - DROP_FADE_S), 0.0, 1.0))
	return Color(lerpf(1.0, m.x, k), lerpf(1.0, m.y, k), lerpf(1.0, m.z, k), a)


## The level's wildlife spawner, or null (a level without wildlife).
static func find(tree: SceneTree) -> WildlifeSpawner:
	return tree.get_first_node_in_group(&"wildlife_spawner") as WildlifeSpawner if tree else null


## A drop's decal on the ground itself: centred on it (full strength there) and fading out a hand above it, so the
## grass standing in it stays clean (not smeared up the blades), and off steep faces.
static func _on_ground_only(d: Decal) -> void:
	d.upper_fade = 6.0
	d.lower_fade = 0.5
	d.normal_fade = 0.3


## A drop's texture for `look` (DROP_LOOKS; made once): a ragged blot in its colour, with the look's marks (the
## heart's spatter flung round it, the lungs' bubbles, the gut's flecks).
func _blood_texture(look := "") -> Texture2D:
	if _drop_texs.has(look):
		return _drop_texs[look]
	var cols: Array = DROP_LOOKS.get(look, DROP_LOOKS[""])
	var base: Color = cols[0]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.12
	noise.seed = look.hash()
	var r2 := RandomNumberGenerator.new()
	r2.seed = look.hash()
	var marks: Array = []                   # [centre (-1..1), radius, colour]
	match look:
		"red":
			for i in 6:
				var ang := r2.randf() * TAU
				marks.append([Vector2(cos(ang), sin(ang)) * r2.randf_range(0.66, 0.9), r2.randf_range(0.05, 0.1), base])
		"froth":
			for i in 11:
				marks.append([Vector2(r2.randf_range(-0.42, 0.42), r2.randf_range(-0.42, 0.42)), r2.randf_range(0.05, 0.11), cols[1]])
		"gut":
			for i in 7:
				marks.append([Vector2(r2.randf_range(-0.4, 0.4), r2.randf_range(-0.4, 0.4)), r2.randf_range(0.03, 0.05), cols[1]])
	for y in n:
		for x in n:
			var v := Vector2(x - n * 0.5, y - n * 0.5) / (n * 0.5)
			var edge := 0.6 + 0.25 * noise.get_noise_2d(x, y)
			var a := clampf((edge - v.length()) * 6.0, 0.0, 1.0)
			var col := base
			for m: Array in marks:
				var k := clampf(((m[1] as float) - v.distance_to(m[0] as Vector2)) / (m[1] as float) * 3.0, 0.0, 1.0)
				if look == "red":
					a = maxf(a, k)            # (spatter round the blot)
				elif a > 0.2:
					col = col.lerp(m[2] as Color, k)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a * (0.85 if look == "gut" else 1.0)))
	_drop_texs[look] = ImageTexture.create_from_image(img)
	return _drop_texs[look]


func _build_note() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_note_label = Label.new()
	_note_label.anchor_left = 0.5
	_note_label.anchor_right = 0.5
	_note_label.anchor_top = 0.72
	_note_label.anchor_bottom = 0.72
	_note_label.offset_left = -300.0
	_note_label.offset_right = 300.0
	_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note_label.add_theme_font_size_override("font_size", 22)
	_note_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_note_label.add_theme_constant_override("outline_size", 6)
	_note_label.modulate.a = 0.0
	layer.add_child(_note_label)


## A line on screen for a few seconds ("+4 Venison, +1 Deer Hide").
func note(text: String) -> void:
	_note_label.text = text
	_note_label.modulate.a = 1.0
	_note_t = 3.5
