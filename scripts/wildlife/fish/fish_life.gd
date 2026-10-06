class_name FishLife
extends Node3D
## The fish in the water near the player, each with a mind of its own (user 2026-09-27: "we should have actual fish in
## the ponds and rivers with there own intelligence we mimic and try to catch"). As many of each species as the water's
## numbers hold there (FishStock, the square's: its share of them for the stretch within NEAR_M of the player); the rest
## are the numbers only. Each fish, by its species (data/world/fish.json):
##   lies       keeps a lie in its habitat (FishSpecies: seam behind a boulder, head of a pool, riffle, pool, bank), at its
##              layer (bottom, low, mid), facing into the current and swimming against it to hold there (the river's
##              flow: faster at the rapids and mid-channel, slack behind the boulders)
##   ways       trout hold and dart for nymphs, and rise to the insects on the water (the hatch: FishSpecies.hatch, the
##              evening's strongest), a ring on the surface where one is taken; perch and suckers school, suckers grubbing
##              the bottom; pike wait still along the edges and strike at smaller fish (a kill takes one off the numbers);
##              eels lie hidden under the banks by day and come out at night; salmon in the fall run rest in the pools
##              below the rapids and try them, leaping the white water; sturgeon in their run roll and breach there
##   wariness   a fish sees what shows above the water within its window (above ~10 degrees over the surface): a person
##              standing on the bank shows from farther off than one crouched, one moving more than one still, and one
##              coming up from below, behind it (it faces the current), least; one wading shakes the water near it. Put
##              down, it bolts for deeper water or cover (in the shallows a wake shows), those near it bolt with it, and
##              it hides a while before it creeps back; the water's wariness (FishStock.wary: fished hard) makes them all
##              shyer. alarm(at, r): a splash, a shot
##   bait       a bait in the water (add_bait: the angler's) is seen within SIGHT_M in front, smelt downstream of it
##              within SMELL_M (worms, roe: the bottom feeders by night): a fish that wants it (its food, hungry, active,
##              calm, the water not fished hard) comes to look, follows it, and takes it or turns away: a bait dragged
##              across the current (natural low) is refused, the pickier the species the surer; refusing makes it
##              warier. Taken, `bite` is emitted and the angler has the species' `hold_s` to set the hook (set_hook) before
##              it is spat out; hooked, it fights: pulls for cover away from the line, trout and salmon leaping, and tires
##              (stamina) the harder it is held; land() takes it off the water (and one off the numbers), release() lets
##              it go (a broken line)
## The signs of the numbers (no bar: user 2026-09-27 "No bar, only signs") are these fish themselves: the rises, the
## leaping salmon, the fish seen holding in the clear shallows, the wakes of a water fished hard and put down.
## In a still reach (WorldRiver.still_amount over a half; Thủy Vân's S1) a fish hangs where it is: no swimming, no
## fright, its tail still; the rings on the water stay where they are (drift_at).
## Only the river has water today (WorldRiver); the lake and ponds want theirs.
## Drawn a MultiMesh a species (FishMesh; shaders/wildlife/fish.gdshader waves them), the rings another
## (shaders/water/rise_ring.gdshader). Its numbers are the spawner's (WildlifeSpawner.land) when there is one, else its
## own (run on the game's days).

signal bite(fish, bait)
signal rose(at: Vector3, species: String)
signal leapt(at: Vector3, species: String)
signal landed(fish)

const GROUP := &"fish_life"
const BOULDERS_PATH := "res://data/world/river_boulders.json"
const RING_SHADER_PATH := "res://shaders/water/rise_ring.gdshader"
## Along the water either way of the player: its fish in the water.
const NEAR_M := 70.0
const DRAW_M := 60.0
const MAX_FISH := 72
const THINK_S := 0.1
const RESTOCK_S := 2.0
## The river's current (m/s): in the pools, at the rapids (less in the shallows, slack behind a boulder).
const POOL_FLOW := 0.45
const RAPID_FLOW := 1.6
## Insects landing on the water a second, a metre of river, at a full hatch.
const HATCH_PER_M := 0.015
const BUG_LIFE_S := 30.0
const MAX_BUGS := 48
const MAX_RINGS := 64
## How far a fish sees a bait in the clear river (in front and to the sides), smells one upstream of it.
const SIGHT_M := 3.0
const SMELL_M := 4.5
## Above this angle over the water (degrees) a fish sees out of it (Snell's window).
const WINDOW_DEG := 10.0
const GRAVITY := 9.8
## A spooked fish's fright passes to those this near it.
const ALARM_M := 2.6
const TABLE_M := 0.5
## Fish farther than this from the player, about nothing quick, move every third frame.
const LOD_M := 30.0
## Fish put in at a restock at most (the rest at the next, a moment after).
const SPAWN_BATCH := 12

enum State { HOLD, CRUISE, SCHOOL, DART, RISE, RETURN, FLEE, HIDE, AMBUSH, STRIKE, INSPECT, BITTEN, HOOKED, LEAP, RUN }


## A bait in the water: the angler's (FishingLine), or a test's.
class Bait:
	var pos := Vector3.ZERO
	## worm, fly, minnow, roe
	var kind := "worm"
	## 0..1: how like the real thing it moves (drifting with the current: 1; dragged across it: low)
	var natural := 1.0
	var surface := false
	## The fish that has it (bitten, hooked), and whether hooked.
	var fish = null
	var hooked := false
	## The angler's pull on the fish (m/s over the ground toward them); the fish's pull on the line (0.. its strength).
	var pull := Vector3.ZERO
	var tension := 0.0


class Fish:
	var id := 0
	var sp := ""
	var spec := {}
	var length := 0.3
	var lb := 1.0
	var pos := Vector3.ZERO
	## Its own speed through the water (the current carries it besides).
	var swim := Vector3.ZERO
	var yaw := 0.0
	var pitch := 0.0
	var lie := Vector3.ZERO
	var habitat := ""
	var base := State.HOLD
	var state := State.HOLD
	var t := 0.0
	var until := 0.0
	var goal := Vector3.ZERO
	var speed := 0.3
	var burst := false
	var wary := 0.0
	var hunger := 0.5
	var school := -1
	var slot := Vector3.ZERO
	var phase := 0.0
	var effort := 0.3
	var bend := 0.0
	var hidden := false
	var air := false
	var vel := Vector3.ZERO
	var current := Vector3.ZERO
	var bed_y := 0.0
	var surf_y := 0.0
	var think_t := 0.0
	var bug := -1
	var bait: Bait = null
	var prey: Fish = null
	var stamina := 1.0
	var refused := 0
	var after_leap := State.RETURN
	var gone := false
	## Time not yet moved (the far ones move every third frame).
	var lag := 0.0

	func forward() -> Vector3:
		return Vector3(-sin(yaw), 0.0, -cos(yaw))


var player: FrontierPlayer
var environment_rig: EnvironmentRig
var land: WildlifeLand
var own_land := false
var fish: Array[Fish] = []
var baits: Array[Bait] = []
var schools := {}
## Insects on the water: [pos, age].
var bugs: Array = []
## Rings on the water: [pos, age, life, strength, size].
var rings: Array = []
## [x, z, radius, top] (the rapids' boulders).
var boulders: Array = []
## Tests, tools: the hour (0-24) and month (1-12) instead of the clock's; -1: the clock's.
var hour_override := -1.0
var month_override := -1
## Tests: false keeps the water's fish as they are put (no restocking to the numbers).
var restock_on := true
## Tools (a film's camera in its own viewport): draw the fish near this instead of the viewport's camera.
var eye_override: Node3D
var rng := RandomNumberGenerator.new()
## Counts (tests, the debug log).
var rises := 0
var leaps := 0
var spooks := 0
var kills := 0
var takes := 0
var refusals := 0

var _mm := {}
var _ring_mm: MultiMeshInstance3D
var _restock_t := 0.0
var _eco_t := 0.0
var _eco_day := -1.0
var _next_id := 1
var _school_id := 1
var _alarms: Array = []
var _now := 0.0
var _bug_acc := 0.0
var _filled := false
var _zr := Vector2.ZERO
var _bank := 14.0
## The river every TABLE_M along its length (its middle, its level, its rapids, its way), read instead of WorldRiver's
## sums each time; the boulders in 10 m bins along it.
var _tx := PackedFloat32Array()
var _tl := PackedFloat32Array()
var _tr := PackedFloat32Array()
var _tfx := PackedFloat32Array()
var _tfz := PackedFloat32Array()
var _bins := {}
## This frame's: the water's numbers here, each species' activity.
var _stock: FishStock
var _acts := {}
var _frame := 0


func setup(p: FrontierPlayer, env: EnvironmentRig) -> void:
	player = p
	environment_rig = env


static func find(tree: SceneTree) -> FishLife:
	return tree.get_first_node_in_group(GROUP) as FishLife if tree else null


func _ready() -> void:
	add_to_group(GROUP)
	rng.seed = 1765
	_build_table()
	if FileAccess.file_exists(BOULDERS_PATH):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOULDERS_PATH))
		if d is Dictionary:
			boulders = (d as Dictionary).get("boulders", [])
	for b: Array in boulders:
		var k := floori(float(b[1]) / 10.0)
		if not _bins.has(k):
			_bins[k] = []
		_bins[k].append(b)
	for id in FishSpecies.ids():
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Fish_" + id
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = FishMesh.mesh(id)
		mm.instance_count = 48
		mm.visible_instance_count = 0
		mmi.multimesh = mm
		mmi.material_override = FishMesh.material(id)
		add_child(mmi)
		_mm[id] = mmi
	_ring_mm = MultiMeshInstance3D.new()
	_ring_mm.name = "Rings"
	var rm := MultiMesh.new()
	rm.transform_format = MultiMesh.TRANSFORM_3D
	rm.use_custom_data = true
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	rm.mesh = plane
	rm.instance_count = MAX_RINGS
	rm.visible_instance_count = 0
	_ring_mm.multimesh = rm
	var mat := ShaderMaterial.new()
	mat.shader = load(RING_SHADER_PATH)
	_ring_mm.material_override = mat
	_ring_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring_mm)


# --- Time ---------------------------------------------------------------------------------------------------------

func _clock() -> WorldClock:
	if environment_rig and environment_rig.clock_driver:
		return environment_rig.clock_driver.clock
	return null


func hour() -> float:
	if hour_override >= 0.0:
		return hour_override
	var c := _clock()
	return c.hour if c else 12.0


func month() -> int:
	if month_override > 0:
		return month_override
	var c := _clock()
	return WorldClock.month_of(c.day_of_year) + 1 if c else 9


## How light it is (1 by day, low at night): what a fish sees by.
func daylight() -> float:
	var h := hour()
	return lerpf(0.3, 1.0, smoothstep(5.0, 7.0, h) * smoothstep(20.5, 18.5, h))


# --- The water ----------------------------------------------------------------------------------------------------

func _build_table() -> void:
	_zr = WorldRiver.z_range()
	_bank = WorldRiver.bank()
	if _zr == Vector2.ZERO:
		return
	var n := int(ceil((_zr.y - _zr.x) / TABLE_M)) + 2
	for a: PackedFloat32Array in [_tx, _tl, _tr, _tfx, _tfz]:
		a.resize(n)
	for i in n:
		var z := _zr.x + float(i) * TABLE_M
		var fl := WorldRiver.dir_at(z)
		_tx[i] = WorldRiver.x_at(z)
		_tl[i] = WorldRiver.level_at(z)
		_tr[i] = WorldRiver.rapid_at(z)
		_tfx[i] = fl.x
		_tfz[i] = fl.z


func _look(a: PackedFloat32Array, z: float) -> float:
	var t := clampf((z - _zr.x) / TABLE_M, 0.0, float(a.size() - 1))
	var i := int(t)
	return lerpf(a[i], a[mini(i + 1, a.size() - 1)], t - float(i))


## The river's middle, level, rapid (0..1) and way (flat, downstream) at z.
func river_x(z: float) -> float:
	return _look(_tx, z) if not _tx.is_empty() else WorldRiver.x_at(z)


func river_level(z: float) -> float:
	return _look(_tl, z) if not _tl.is_empty() else WorldRiver.level_at(z)


func river_rapid(z: float) -> float:
	return _look(_tr, z) if not _tr.is_empty() else WorldRiver.rapid_at(z)


func river_flow(z: float) -> Vector3:
	if _tfx.is_empty():
		return WorldRiver.dir_at(z)
	return Vector3(_look(_tfx, z), 0.0, _look(_tfz, z)).normalized()


## The current on top of the water at p (what carries an insect, a ring): the river's, faster at the rapids (none in a
## still reach).
func drift_at(p: Vector3) -> Vector3:
	return river_flow(p.z) * lerpf(POOL_FLOW, RAPID_FLOW, river_rapid(p.z)) * WorldRiver.flow_scale(p.z)


## Whether `f` hangs in a still reach (more than half still where it is; not on a line, not in the air): then it does
## not swim, take fright or beat its tail.
func _suspended(f: Fish) -> bool:
	if WorldRiver.reach_state == "" or f.air or f.state == State.HOOKED or f.state == State.BITTEN:
		return false
	if WorldRiver.still_amount(f.pos.z) <= 0.5:
		return false
	f.swim = Vector3.ZERO
	f.burst = false
	f.effort = 0.15
	f.bend = 0.0
	return true


func surface(z: float) -> float:
	return river_level(z)


func bed(x: float, z: float) -> float:
	return FrontierTerrain.height_at(x, z)


## How deep the water is at (x, z): 0 off it (its banks, the rocks over it, past its ends).
func depth(x: float, z: float) -> float:
	if z < _zr.x or z > _zr.y or absf(x - river_x(z)) > _bank:
		return 0.0
	return maxf(surface(z) - bed(x, z), 0.0)


## The current at p (m/s, over the ground): the river's way there, faster at the rapids, slower in the shallows and
## along the bottom (where the fish hold), slack behind a boulder.
func current_at(p: Vector3) -> Vector3:
	var d := depth(p.x, p.z)
	var s := lerpf(POOL_FLOW, RAPID_FLOW, river_rapid(p.z)) * clampf(d / 0.8, 0.2, 1.0)
	s *= lerpf(0.45, 1.0, smoothstep(0.05, 0.45, p.y - bed(p.x, p.z)))
	s *= 1.0 - 0.8 * shelter(p)
	return river_flow(p.z) * s


## 0..1: how sheltered from the current p is, in a boulder's lee (the seam behind it).
func shelter(p: Vector3) -> float:
	var k0 := floori(p.z / 10.0)
	if not (_bins.has(k0) or _bins.has(k0 - 1)):
		return 0.0
	var f := river_flow(p.z)
	var best := 0.0
	for b: Array in (_bins.get(k0, []) as Array) + (_bins.get(k0 - 1, []) as Array):
		var rx := p.x - float(b[0])
		var rz := p.z - float(b[1])
		var along := rx * f.x + rz * f.z
		var across := absf(-rx * f.z + rz * f.x)
		var r := float(b[2])
		if along > 0.0 and along < r * 3.5 and across < r * 1.1:
			best = maxf(best, (1.0 - along / (r * 3.5)) * (1.0 - across / (r * 1.1)))
	return best


func _min_depth(f: Fish) -> float:
	return maxf(0.12, f.length * 0.22) + 0.04


## Where a fish of its size keeps at (x, z) by its layer: on the bottom, low, mid-water; never out of the top.
func layer_y(f: Fish, x: float, z: float) -> float:
	var b := bed(x, z)
	var s := surface(z)
	var d := s - b
	var bh := f.length * 0.11
	var y := b + d * 0.5
	match String(f.spec.get("layer", "mid")):
		"bottom":
			y = b + bh + 0.03
		"low":
			y = b + maxf(bh + 0.04, d * 0.28)
	return clampf(y, b + bh + 0.02, s - bh - 0.05)


# --- Where fish keep ----------------------------------------------------------------------------------------------

## A habitat by the species' weights (its run's, in its run).
func pick_habitat(sp: String) -> String:
	var spec := FishSpecies.spec(sp)
	var hw: Dictionary = spec.get("habitat", {"pool": 1.0})
	var run: Dictionary = (spec.get("runs", {}) as Dictionary).get("river", {})
	if run.has("habitat") and FishSpecies.run_share(sp, "river", month()) >= 0.99:
		hw = run.habitat
	var total := 0.0
	for k: String in hw:
		total += float(hw[k])
	var x := rng.randf() * total
	for k: String in hw:
		x -= float(hw[k])
		if x <= 0.0:
			return k
	return "pool"


## A lie of `habitat` within `span` m (along the river) of z: Vector3.INF where none is found.
func find_lie(f: Fish, habitat: String, z0: float, span: float) -> Vector3:
	var rs := WorldRiver.rapids()
	for tries in 30:
		var z := clampf(z0 + rng.randf_range(-span, span), _zr.x + 2.0, _zr.y - 2.0)
		var cx := river_x(z)
		var x := cx
		match habitat:
			"seam":
				var near: Array = []
				for b: Array in boulders:
					if absf(float(b[1]) - z0) < span:
						near.append(b)
				if near.is_empty():
					continue
				var b: Array = near[rng.randi() % near.size()]
				var fl := river_flow(float(b[1]))
				var r := float(b[2])
				var off := fl * rng.randf_range(r + 0.5, r * 2.4) + Vector3(-fl.z, 0.0, fl.x) * rng.randf_range(-0.45, 0.45) * r
				x = float(b[0]) + off.x
				z = float(b[1]) + off.z
			"head", "riffle":
				var here: Array = []
				for r: Dictionary in rs:
					if absf(float(r.z) - z0) < span + float(r.length):
						here.append(r)
				if here.is_empty():
					continue
				var r: Dictionary = here[rng.randi() % here.size()]
				if habitat == "head":
					z = float(r.z) + float(r.length) * 0.5 + rng.randf_range(4.0, 22.0)
				else:
					z = float(r.z) + rng.randf_range(-0.45, 0.45) * float(r.length)
				x = river_x(z) + rng.randf_range(-5.5, 5.5)
			"bank":
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				var o := 2.0
				while o < WorldRiver.bank() and depth(cx + side * (o + 0.5), z) > 0.55:
					o += 0.5
				x = cx + side * (o - rng.randf_range(0.0, 1.0))
			"pool":
				if river_rapid(z) > 0.05:
					continue
				x = cx + rng.randf_range(-5.0, 5.0)
			_:
				x = cx + rng.randf_range(-5.0, 5.0)
		if z < _zr.x + 1.0 or z > _zr.y - 1.0 or depth(x, z) < _min_depth(f) + 0.08:
			continue
		return Vector3(x, layer_y(f, x, z), z)
	return Vector3.INF


# --- Fish in and out of the water ---------------------------------------------------------------------------------

func _stock_here() -> FishStock:
	if _stock != null:
		return _stock
	return _find_stock()


func _find_stock() -> FishStock:
	if land == null or player == null:
		return null
	var pz := clampf(player.global_position.z, _zr.x, _zr.y)
	return land.fish_at(Vector3(river_x(pz), 0.0, pz))


## A fish of `sp` put at `at` (Vector3.INF: a lie of its habitat near z0), in its species' ways. null: nowhere for it.
func spawn_fish(sp: String, at := Vector3.INF, z0 := 0.0, span := 40.0) -> Fish:
	var spec := FishSpecies.spec(sp)
	if spec.is_empty():
		return null
	var f := Fish.new()
	f.id = _next_id
	_next_id += 1
	f.sp = sp
	f.spec = spec
	var ln: Array = spec.get("len", [0.2, 0.4])
	var lbs: Array = spec.get("lb", [0.5, 1.0])
	var k := pow(rng.randf(), 1.6)
	f.length = lerpf(float(ln[0]), float(ln[1]), k)
	f.lb = lerpf(float(lbs[0]), float(lbs[1]), k)
	f.habitat = pick_habitat(sp)
	var lie := at
	if lie == Vector3.INF:
		lie = find_lie(f, f.habitat, z0, span)
		# none of its first choice here: another of its habitats
		for hb: String in spec.get("habitat", {}):
			if lie != Vector3.INF:
				break
			if hb != f.habitat:
				lie = find_lie(f, hb, z0, span)
				if lie != Vector3.INF:
					f.habitat = hb
		if lie == Vector3.INF:
			return null
	f.lie = lie
	f.pos = lie
	f.goal = lie
	f.hunger = rng.randf_range(0.3, 0.7)
	f.phase = rng.randf()
	f.think_t = rng.randf() * THINK_S
	f.speed = float(spec.get("cruise", 0.3))
	f.yaw = atan2(river_flow(lie.z).x, river_flow(lie.z).z)
	f.base = _base_state(f)
	f.state = f.base
	f.bed_y = bed(lie.x, lie.z)
	f.surf_y = surface(lie.z)
	# an eel come by day: already under the bank
	if bool(spec.get("hides", false)) and at == Vector3.INF and FishSpecies.activity(sp, hour(), month()) < 0.08:
		var bl := find_lie(f, "bank", lie.z, 6.0)
		if bl != Vector3.INF:
			f.lie = bl
			f.pos = bl
			f.habitat = "bank"
		f.hidden = true
	fish.append(f)
	return f


func _base_state(f: Fish) -> State:
	if bool(f.spec.get("ambush", false)):
		return State.AMBUSH
	var sc: Array = f.spec.get("school", [1, 1])
	if int(sc[1]) > 1:
		return State.SCHOOL
	if f.sp in ["eel", "sturgeon"]:
		return State.CRUISE
	return State.HOLD


## A school of `n` of `sp` about a lie of its habitat near z0.
func spawn_school(sp: String, n: int, z0: float, span: float) -> int:
	var lead := spawn_fish(sp, Vector3.INF, z0, span)
	if lead == null:
		return 0
	var sid := _school_id
	_school_id += 1
	schools[sid] = {"home": lead.lie, "goal": lead.lie, "t": 0.0, "until": 0.0, "sp": sp, "members": [lead]}
	lead.school = sid
	lead.state = State.SCHOOL
	var made := 1
	for i in n - 1:
		var at := lead.lie + Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.2, 1.2))
		if depth(at.x, at.z) < _min_depth(lead) + 0.05:
			at = lead.lie
		var f := spawn_fish(sp, Vector3(at.x, layer_y(lead, at.x, at.z), at.z))
		if f:
			f.school = sid
			f.habitat = lead.habitat
			f.state = State.SCHOOL
			f.slot = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * 0.9
			(schools[sid].members as Array).append(f)
			made += 1
	return made


## Keeps the water near the player to the numbers: fish past reach go (they are still in the numbers), the missing come
## in (at the stretch's far ends once it is filled: out of sight).
func _restock() -> void:
	if player == null or not WorldRiver.has_water():
		return
	var pp := player.global_position
	var pz := clampf(pp.z, _zr.x, _zr.y)
	var far := absf(pp.x - river_x(pz)) > 260.0
	for f in fish:
		if f.state == State.HOOKED or f.state == State.BITTEN:
			continue
		if far or absf(f.pos.z - pp.z) > NEAR_M + 15.0:
			f.gone = true
	_sweep()
	if far:
		_filled = false
		return
	var stock := _stock_here()
	if stock == null:
		return
	var lo := maxf(pz - NEAR_M, _zr.x)
	var hi := minf(pz + NEAR_M, _zr.y)
	var share := (hi - lo) / maxf(_zr.y - _zr.x, 1.0)
	var want := {}
	var total := 0
	for s: String in stock.caps:
		want[s] = int(round(float(stock.pop[s]) * share))
		total += int(want[s])
	if total > MAX_FISH:
		for s: String in want:
			want[s] = int(floor(float(want[s]) * MAX_FISH / total))
	var have := {}
	for f in fish:
		have[f.sp] = int(have.get(f.sp, 0)) + 1
	var made := 0
	for s: String in want:
		var n := int(have.get(s, 0))
		var tries := 0
		while n < int(want[s]) and tries < 30 and made < SPAWN_BATCH:
			tries += 1
			# a fish comes in: anywhere the first time; after, at the far ends
			var z0 := rng.randf_range(lo, hi)
			if _filled:
				z0 = pz + (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(NEAR_M - 20.0, NEAR_M)
			var sc: Array = FishSpecies.spec(s).get("school", [1, 1])
			var n0 := n
			if int(sc[1]) > 1:
				n += spawn_school(s, mini(rng.randi_range(int(sc[0]), int(sc[1])), int(want[s]) - n), z0, 10.0)
			elif spawn_fish(s, Vector3.INF, z0, 12.0) != null:
				n += 1
			made += n - n0
		while n > int(want[s]):
			var worst: Fish = null
			for f in fish:
				if f.sp == s and not f.gone and f.state != State.HOOKED and f.state != State.BITTEN:
					if worst == null or absf(f.pos.z - pp.z) > absf(worst.pos.z - pp.z):
						worst = f
			if worst == null:
				break
			worst.gone = true
			n -= 1
	_sweep()
	if made >= SPAWN_BATCH:
		# more to come in: soon, not all in one frame
		_restock_t = 0.2
	else:
		_filled = true


func _sweep() -> void:
	var keep: Array[Fish] = []
	for f in fish:
		if not f.gone:
			keep.append(f)
		else:
			if f.bait:
				f.bait.fish = null
				f.bait.hooked = false
			if schools.has(f.school):
				var mem: Array = schools[f.school].members
				mem.erase(f)
				if mem.is_empty():
					schools.erase(f.school)
	fish = keep


# --- The frame ----------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_now += dt
	if land == null:
		_find_land()
	_eco_t -= dt
	if own_land and _eco_t <= 0.0:
		_eco_t = 2.0
		_own_days()
	_restock_t -= dt
	if _restock_t <= 0.0 and restock_on:
		_restock_t = RESTOCK_S
		_restock()
	var h := hour()
	var m := month()
	_frame += 1
	_stock = _find_stock()
	_acts.clear()
	_hatch(dt, h, m)
	_fire_alarms()
	var pp := player.global_position if player else Vector3.ZERO
	var any_gone := false
	for f in fish:
		# (in a still reach it hangs where it is)
		if _suspended(f):
			continue
		f.think_t += dt
		if f.think_t >= THINK_S:
			f.think_t -= THINK_S
			if not _acts.has(f.sp):
				_acts[f.sp] = FishSpecies.activity(f.sp, h, m)
			_think(f, float(_acts[f.sp]), h, m)
		# the far and idle: every third frame
		f.lag += dt
		var quick := f.burst or f.air or f.state in [State.RISE, State.INSPECT, State.BITTEN, State.HOOKED]
		if quick or (_frame + f.id) % 3 == 0 or absf(f.pos.z - pp.z) + absf(f.pos.x - pp.x) < LOD_M:
			_move(f, minf(f.lag, 0.1))
			f.lag = 0.0
		any_gone = any_gone or f.gone
	if any_gone:
		_sweep()
	_age_rings(dt)
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		_draw_fish()


func _find_land() -> void:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene:
		for n in scene.get_children():
			if n is WildlifeSpawner:
				land = (n as WildlifeSpawner).land
				return
	land = WildlifeLand.new()
	own_land = true


func _own_days() -> void:
	var c := _clock()
	if c == null:
		return
	var d := float(c.year) * 366.0 + c.day_of_year + c.hour / 24.0
	if _eco_day >= 0.0 and d > _eco_day and d - _eco_day < 60.0:
		land.advance(d - _eco_day, month())
	_eco_day = d


# --- A fish's mind ------------------------------------------------------------------------------------------------

func _think(f: Fish, act: float, h: float, m: int) -> void:
	f.current = current_at(f.pos)
	f.bed_y = bed(f.pos.x, f.pos.z)
	f.surf_y = surface(f.pos.z)
	f.hunger = minf(f.hunger + THINK_S * 0.004 * maxf(act, 0.1), 1.0)
	f.wary = maxf(f.wary - THINK_S / 90.0, 0.0)
	if f.air or f.state == State.HOOKED or f.state == State.LEAP:
		if f.state == State.HOOKED:
			_fight_think(f)
		return
	# eels by day: under the banks, out of sight
	if bool(f.spec.get("hides", false)):
		if act < 0.08 and not f.hidden and f.state != State.BITTEN:
			if f.habitat != "bank":
				var bl := find_lie(f, "bank", f.pos.z, 6.0)
				if bl != Vector3.INF:
					f.lie = bl
					f.habitat = "bank"
			_go(f, State.RETURN, f.lie, float(f.spec.cruise) * 1.8)
			if Vector2(f.pos.x - f.lie.x, f.pos.z - f.lie.z).length() < 1.0:
				f.hidden = true
			return
		if f.hidden:
			if act < 0.08:
				return
			f.hidden = false
			_go(f, State.CRUISE, f.pos, float(f.spec.cruise))
	if f.hidden:
		return
	# something on the bank, a wader (in cover already, only much nearer)
	if f.state != State.FLEE and _threatened(f, 0.5 if f.state == State.HIDE else 1.0):
		_spook(f, player.global_position)
		return
	# a bait
	if f.state in [State.HOLD, State.CRUISE, State.SCHOOL, State.AMBUSH, State.RETURN] and not baits.is_empty():
		if _consider_baits(f, act):
			return
	match f.state:
		State.HOLD:
			_hold(f, act, h, m)
		State.CRUISE:
			_cruise(f, act)
		State.SCHOOL:
			_school(f, act)
		State.AMBUSH:
			_ambush(f, act)
		State.DART:
			if f.t >= f.until:
				_go(f, State.RETURN, f.lie, float(f.spec.cruise) * 1.4)
		State.RISE:
			_rise(f)
		State.RETURN:
			if f.pos.distance_to(f.lie) < 0.45 or f.t > 30.0:
				_go(f, f.base, f.lie, float(f.spec.cruise))
			elif f.base == State.AMBUSH:
				# on its way back, still quick to a fish in front of it
				_prey_check(f, act)
		State.FLEE:
			if f.t >= f.until:
				_hide(f)
		State.HIDE:
			if f.t >= f.until:
				if _threatened(f, 1.3):
					f.until += 15.0
				else:
					f.wary = 0.6
					_go(f, State.RETURN, f.lie, float(f.spec.cruise))
		State.STRIKE:
			_strike(f)
		State.INSPECT:
			_inspect(f, act)
		State.BITTEN:
			if f.bait == null or not f.bait.hooked and f.t >= float(f.spec.get("hold_s", 0.8)):
				_spit(f)
		State.RUN:
			_run(f)


func _go(f: Fish, s: State, goal: Vector3, speed: float, burst := false, until := 0.0) -> void:
	f.state = s
	f.t = 0.0
	f.goal = goal
	f.speed = speed
	f.burst = burst
	f.until = until


func _hold(f: Fish, act: float, h: float, m: int) -> void:
	# a little sway in its lie
	var side := Vector3(-f.current.z, 0.0, f.current.x).normalized() if f.current.length() > 0.01 else Vector3.RIGHT
	f.goal = f.lie + side * sin(_now * 0.35 + f.id) * 0.18
	f.speed = float(f.spec.cruise)
	f.burst = false
	# the salmon's run: a try at the rapid above
	if f.sp == "salmon" and FishSpecies.run_share(f.sp, "river", m) >= 0.99 and rng.randf() < THINK_S / 70.0 * maxf(act, 0.3):
		if _start_run(f):
			return
	# rising to an insect coming down to it
	if bool(f.spec.get("rises", false)) and f.wary < 0.3 and f.hunger > 0.15:
		var bi := _bug_for(f)
		if bi >= 0 and rng.randf() < clampf(act * f.hunger * 1.4, 0.0, 0.9):
			f.bug = bi
			_go(f, State.RISE, bugs[bi][0], float(f.spec.burst) * 0.5, true)
			return
	# a nymph going by: a dart out and back
	if rng.randf() < THINK_S * 0.12 * act * f.hunger:
		var fw := f.forward()
		var to := f.pos + fw * rng.randf_range(0.3, 1.1) + Vector3(-fw.z, 0.0, fw.x) * rng.randf_range(-0.7, 0.7)
		to.y = clampf(f.pos.y + rng.randf_range(-0.15, 0.2), f.bed_y + 0.06, f.surf_y - 0.08)
		if depth(to.x, to.z) > _min_depth(f):
			f.hunger = maxf(f.hunger - 0.03, 0.0)
			_go(f, State.DART, to, float(f.spec.burst) * 0.45, true, rng.randf_range(0.35, 0.6))


func _cruise(f: Fish, act: float) -> void:
	if f.t >= f.until or f.pos.distance_to(f.goal) < 0.5:
		# a new place along the bottom near its lie (or a rest where it is)
		if rng.randf() < 0.35:
			_go(f, State.CRUISE, f.pos, 0.05, false, rng.randf_range(2.0, 6.0))
			return
		var to := f.lie + Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-8.0, 8.0))
		if depth(to.x, to.z) < _min_depth(f) + 0.05:
			to = f.lie
		to.y = layer_y(f, to.x, to.z)
		_go(f, State.CRUISE, to, float(f.spec.cruise) * lerpf(0.5, 1.0, act), false, rng.randf_range(8.0, 20.0))


func _school(f: Fish, act: float) -> void:
	var sc: Dictionary = schools.get(f.school, {})
	if sc.is_empty():
		f.school = -1
		f.base = State.CRUISE
		_go(f, State.CRUISE, f.pos, float(f.spec.cruise))
		return
	# the school's way: now and then on to another place near its home
	if _now >= float(sc.until):
		var home: Vector3 = sc.home
		var to := home + Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-8.0, 8.0))
		if depth(to.x, to.z) < _min_depth(f) + 0.1:
			to = home
		to.y = layer_y(f, to.x, to.z)
		sc.goal = to
		sc.until = _now + rng.randf_range(6.0, 18.0) / maxf(act, 0.3)
	var g: Vector3 = sc.goal + f.slot
	# apart from the others (not in one another)
	for o: Fish in sc.members:
		if o != f and not o.gone:
			var d := f.pos - o.pos
			if d.length() < f.length * 1.2 and d.length() > 0.001:
				g += d.normalized() * f.length
	g.y = layer_y(f, g.x, g.z)
	f.goal = g
	f.speed = float(f.spec.cruise) * lerpf(0.6, 1.2, act)
	f.burst = false


func _ambush(f: Fish, act: float) -> void:
	f.goal = f.lie
	f.speed = float(f.spec.cruise)
	f.burst = false
	_prey_check(f, act)


## A smaller fish close in front of a hungry pike: a strike at it.
func _prey_check(f: Fish, act: float) -> void:
	if f.hunger < 0.35 or act < 0.2:
		return
	# a smaller fish in front of it, near
	var fw := f.forward()
	for o in fish:
		if o == f or o.hidden or o.air or o.length > f.length * 0.45 or o.state == State.HOOKED:
			continue
		var d := o.pos - f.pos
		if d.length() < 1.7 and fw.dot(Vector3(d.x, 0.0, d.z).normalized()) > 0.55:
			if rng.randf() < THINK_S * 2.0 * act * f.hunger:
				f.prey = o
				_go(f, State.STRIKE, o.pos, float(f.spec.burst), true, 0.4)
				# the prey may see it coming
				if rng.randf() < 0.5:
					_spook(o, f.pos, false)
				return


func _strike(f: Fish) -> void:
	var o := f.prey
	var mouth := f.pos + f.forward() * f.length * 0.45
	var reach := maxf(0.15, (o.length if o else 0.2) * 0.8)
	if o and not o.gone:
		f.goal = o.pos - f.forward() * f.length * 0.45
	if f.t < f.until and not (o and mouth.distance_to(o.pos) < reach):
		return
	if o and not o.gone and mouth.distance_to(o.pos) < reach and rng.randf() < 0.55:
		# taken
		o.gone = true
		kills += 1
		f.hunger = 0.0
		var st := _stock_here()
		if st:
			st.eaten(o.sp)
		if o.pos.y > o.surf_y - 0.5:
			_ring(o.pos, 0.9, 0.7)
		_alarm_near(o.pos, ALARM_M, f)
	f.prey = null
	_go(f, State.RETURN, f.lie, float(f.spec.cruise))


# --- The hatch: rises -------------------------------------------------------------------------------------------

func _hatch(dt: float, h: float, m: int) -> void:
	# new insects on the water
	if player and WorldRiver.has_water():
		var pz := clampf(player.global_position.z, _zr.x, _zr.y)
		var lo := maxf(pz - NEAR_M, _zr.x)
		var hi := minf(pz + NEAR_M, _zr.y)
		_bug_acc += FishSpecies.hatch(h, m) * HATCH_PER_M * (hi - lo) * dt
		while _bug_acc >= 1.0 and bugs.size() < MAX_BUGS:
			_bug_acc -= 1.0
			var z := rng.randf_range(lo, hi)
			var x := river_x(z) + rng.randf_range(-7.0, 7.0)
			if depth(x, z) > 0.2:
				bugs.append([Vector3(x, surface(z), z), 0.0])
		_bug_acc = minf(_bug_acc, 1.0)
	# down the river with the surface water
	var keep := []
	for b: Array in bugs:
		var p: Vector3 = b[0]
		b[1] = float(b[1]) + dt
		p += drift_at(p) * 1.05 * dt
		p.y = surface(p.z)
		b[0] = p
		if float(b[1]) < BUG_LIFE_S and depth(p.x, p.z) > 0.05:
			keep.append(b)
	if keep.size() != bugs.size():
		# the fish rising to one that went: their index moves
		var moved := {}
		var j := 0
		for i in bugs.size():
			if keep.has(bugs[i]):
				moved[i] = j
				j += 1
		for f in fish:
			if f.bug >= 0:
				f.bug = int(moved.get(f.bug, -1))
	bugs = keep


## An insect coming down to the fish from upstream within its reach (a few metres, in front), or -1.
func _bug_for(f: Fish) -> int:
	var fw := f.forward()
	var best := -1
	var bd := 3.5
	for i in bugs.size():
		var p: Vector3 = bugs[i][0]
		var d := Vector3(p.x - f.pos.x, 0.0, p.z - f.pos.z)
		if d.length() < bd and fw.dot(d.normalized()) > 0.3:
			var taken := false
			for o in fish:
				if o.bug == i and o != f:
					taken = true
			if not taken:
				best = i
				bd = d.length()
	return best


func _rise(f: Fish) -> void:
	if f.bug < 0 or f.bug >= bugs.size() or f.t > 3.5:
		f.bug = -1
		_go(f, State.RETURN, f.lie, float(f.spec.cruise) * 1.3)
		return
	var p: Vector3 = bugs[f.bug][0]
	f.goal = Vector3(p.x, p.y - f.length * 0.08, p.z)
	var flat := Vector2(p.x - f.pos.x, p.z - f.pos.z).length()
	if flat < maxf(0.18, f.length * 0.5) and f.pos.y > p.y - f.length * 0.35:
		# taken off the top: a ring (a leap, now and then at dusk)
		bugs.remove_at(f.bug)
		for o in fish:
			if o.bug > f.bug:
				o.bug -= 1
		f.bug = -1
		rises += 1
		f.hunger = maxf(f.hunger - 0.08, 0.0)
		_ring(Vector3(f.pos.x, p.y, f.pos.z), 0.55 + f.length, 0.35 + f.length * 1.2)
		rose.emit(p, f.sp)
		if rng.randf() < float(f.spec.get("leap", 0.0)):
			_leap(f, f.forward() * 1.2 + Vector3.UP * 2.4, State.RETURN)
			return
		_go(f, State.RETURN, f.lie, float(f.spec.cruise) * 1.3)


# --- Salmon at the rapids -----------------------------------------------------------------------------------------

## A try at the rapid above it (from the pool below it): up into the white water to its steep middle, then a leap.
func _start_run(f: Fish) -> bool:
	for r: Dictionary in WorldRiver.rapids():
		var below := f.pos.z - (float(r.z) + float(r.length) * 0.5)
		if below > -2.0 and below < 35.0:
			var z := float(r.z) + rng.randf_range(-0.1, 0.25) * float(r.length)
			var x := river_x(z) + rng.randf_range(-3.0, 3.0)
			if depth(x, z) < 0.25:
				x = river_x(z)
			_go(f, State.RUN, Vector3(x, surface(z) - 0.25, z), float(f.spec.burst) * 0.85, true, 40.0)
			return true
	return false


func _run(f: Fish) -> void:
	var near := Vector2(f.goal.x - f.pos.x, f.goal.z - f.pos.z).length() < 3.0
	if near or depth(f.pos.x, f.pos.z) < 0.3 and f.t > 2.0:
		var up := -river_flow(f.pos.z)
		var ok := rng.randf() < 0.35
		if ok:
			# over: a lie in the pool above
			for r: Dictionary in WorldRiver.rapids():
				if absf(float(r.z) - f.pos.z) < float(r.length):
					var z := float(r.z) - float(r.length) * 0.5 - rng.randf_range(6.0, 22.0)
					var lie := Vector3(river_x(z) + rng.randf_range(-3.0, 3.0), 0.0, z)
					if depth(lie.x, lie.z) > _min_depth(f):
						lie.y = layer_y(f, lie.x, lie.z)
						f.lie = lie
		_leap(f, up * rng.randf_range(2.0, 2.8) + Vector3.UP * rng.randf_range(3.0, 3.8), State.RETURN)
	elif f.t >= f.until:
		_go(f, State.RETURN, f.lie, float(f.spec.cruise) * 1.3)


## Out of the water: along `v` (m/s), falling back in; splashes both ways.
func _leap(f: Fish, v: Vector3, then: State) -> void:
	f.air = true
	f.vel = v
	f.after_leap = then
	f.state = State.LEAP if f.state != State.HOOKED else State.HOOKED
	f.t = 0.0
	f.pos.y = maxf(f.pos.y, surface(f.pos.z) - 0.05)
	leaps += 1
	_splash(f.pos, f.length)
	leapt.emit(f.pos, f.sp)


# --- Fright -------------------------------------------------------------------------------------------------------

## Whether it sees (or feels) the player near enough to bolt: `k` x the distance it lets one come.
func _threatened(f: Fish, k := 1.0) -> bool:
	if player == null:
		return false
	var pp := player.global_position
	var d := Vector2(pp.x - f.pos.x, pp.z - f.pos.z).length()
	var r := float(f.spec.get("wary_m", 6.0)) * k
	var st := _stock_here()
	if st:
		r *= 1.0 + 0.8 * st.wary
	r *= 1.0 + 0.5 * f.wary
	var spd := Vector2(player.velocity.x, player.velocity.z).length()
	# wading: the water shakes about the legs
	if depth(pp.x, pp.z) > 0.1:
		return d < maxf(2.0 + 1.6 * spd, r * 0.55)
	if d > r * 1.3:
		return false
	# on the bank: seen only above the window's edge
	var eye := pp.y + (1.0 if player.is_crouching else 1.65) - f.surf_y
	if rad_to_deg(atan2(eye, maxf(d, 0.1))) < WINDOW_DEG:
		return false
	r *= 1.25 if spd > 3.5 else (1.0 if spd > 0.4 else 0.65)
	if player.is_crouching:
		r *= 0.6
	# behind it (it faces the current): the angler come up from below it is in its blind cone
	var to := Vector3(pp.x - f.pos.x, 0.0, pp.z - f.pos.z).normalized()
	if f.forward().dot(to) < -0.75:
		r *= 0.45
	r *= daylight()
	return d < r


## Put down by something at `from`: away for deeper water or cover, fast; `spread`: those near it go too.
func _spook(f: Fish, from: Vector3, spread := true) -> void:
	if f.state == State.HOOKED or f.air:
		return
	spooks += 1
	f.wary = 1.0
	f.bug = -1
	if f.bait and f.bait.fish == f:
		f.bait.fish = null
	f.bait = null
	var st := _stock_here()
	if st:
		st.spooked()
	var away := Vector3(f.pos.x - from.x, 0.0, f.pos.z - from.z).normalized()
	if away.length() < 0.5:
		away = river_flow(f.pos.z)
	var cx := river_x(f.pos.z)
	away += Vector3(signf(cx - f.pos.x) * 0.6, 0.0, 0.0)
	away = away.normalized()
	# the deepest place along its way out
	var best := f.pos + away * 3.0
	var bd := -1.0
	for i in 7:
		var a := away.rotated(Vector3.UP, rng.randf_range(-0.8, 0.8)) * rng.randf_range(3.0, 7.0)
		var p := f.pos + a
		var d := depth(p.x, p.z)
		if d > bd:
			bd = d
			best = p
	if bd < _min_depth(f):
		best = Vector3(cx, 0.0, f.pos.z) + away * 2.0
	best.y = layer_y(f, best.x, best.z) if depth(best.x, best.z) > 0.05 else f.pos.y
	_go(f, State.FLEE, best, float(f.spec.burst), true, rng.randf_range(0.8, 1.5))
	if spread:
		_alarm_near(f.pos, ALARM_M, f)


func _hide(f: Fish) -> void:
	var st := _stock_here()
	var w := 1.0 + (st.wary if st else 0.0)
	_go(f, State.HIDE, f.pos, float(f.spec.cruise) * 0.5, false, rng.randf_range(20.0, 60.0) * w)


## Every fish within r of `at` bolts from it, a moment after (a fright passing).
func alarm(at: Vector3, r: float) -> void:
	_alarm_near(at, r, null)


func _alarm_near(at: Vector3, r: float, except: Fish) -> void:
	for o in fish:
		if o != except and not o.hidden and o.state != State.FLEE and o.state != State.HOOKED and o.pos.distance_to(at) < r:
			_alarms.append([_now + rng.randf_range(0.12, 0.35), o, at])


func _fire_alarms() -> void:
	if _alarms.is_empty():
		return
	var keep := []
	for a: Array in _alarms:
		if _now >= float(a[0]):
			var o: Fish = a[1]
			if not o.gone and o.state != State.FLEE:
				_spook(o, a[2], false)
		else:
			keep.append(a)
	_alarms = keep


# --- Bait: looking, taking, fighting ------------------------------------------------------------------------------

func add_bait(b: Bait) -> void:
	if not baits.has(b):
		baits.append(b)


func remove_bait(b: Bait) -> void:
	baits.erase(b)
	if b.fish:
		var f: Fish = b.fish
		b.fish = null
		f.bait = null
		if f.state in [State.INSPECT, State.BITTEN, State.HOOKED]:
			f.wary = 1.0
			_go(f, State.RETURN, f.lie, float(f.spec.cruise) * 1.4)


## How much `f` wants bait `b` now, 0..1 (its food? hungry? active? calm? the water fished hard? the drift natural?).
## `look`: enough to come and look at it (a bait moving oddly still draws the eye; it is turned away from close to).
func interest(f: Fish, b: Bait, act: float, look := false) -> float:
	var diet: Array = f.spec.get("diet", [])
	var food := 1.0 if diet.has(b.kind) else 0.08
	# a salmon in its run hardly feeds, but strikes at a fly or a minnow from temper
	var want := clampf(f.hunger * 1.3, 0.1, 1.0)
	if f.sp == "salmon" and b.kind in ["fly", "minnow", "roe"]:
		want = 0.55
	var st := _stock_here()
	var shy := 1.0 - 0.7 * (st.wary if st else 0.0)
	var picky := float(f.spec.get("picky", 1.5))
	var nat := pow(clampf(b.natural, 0.0, 1.0), picky * (0.25 if look else 1.0))
	return clampf(food * want * act * shy * nat * (1.0 - f.wary) / (1.0 + 0.35 * f.refused), 0.0, 1.0)


## Whether it notices a bait (seen in front, smelt upstream) and goes to look at it.
func _consider_baits(f: Fish, act: float) -> bool:
	for b in baits:
		if b.fish != null:
			continue
		var d := b.pos - f.pos
		var flat := Vector3(d.x, 0.0, d.z)
		var seen := d.length() < SIGHT_M * lerpf(0.35, 1.0, daylight()) and f.forward().dot(flat.normalized()) > -0.2
		var smelt := false
		if b.kind in ["worm", "roe"] and flat.length() < SMELL_M:
			# its scent comes down the current to it
			smelt = river_flow(b.pos.z).dot(-flat.normalized()) > 0.6
		if not (seen or smelt):
			continue
		var i := interest(f, b, act, true)
		if i > 0.05 and rng.randf() < i * THINK_S * 6.0:
			f.bait = b
			b.fish = f
			_go(f, State.INSPECT, b.pos, float(f.spec.cruise) * 1.6, false, rng.randf_range(0.6, 2.6))
			return true
	return false


func _inspect(f: Fish, act: float) -> void:
	var b := f.bait
	if b == null or not baits.has(b):
		f.bait = null
		_go(f, State.RETURN, f.lie, float(f.spec.cruise))
		return
	# behind it, a little below, following it
	var dir := (b.pos - f.pos)
	var back := dir.normalized() * f.length * 0.8 if dir.length() > 0.01 else Vector3.ZERO
	f.goal = b.pos - back - Vector3(0.0, 0.05, 0.0)
	f.goal.y = clampf(f.goal.y, f.bed_y + 0.05, f.surf_y - 0.05)
	# dragged: it turns away
	var pick := float(f.spec.get("picky", 1.5))
	if b.natural < 0.5 and rng.randf() < THINK_S * 3.0 * pick * (0.5 - b.natural) * 2.0:
		_refuse(f)
		return
	if f.t < f.until:
		return
	if rng.randf() < clampf(interest(f, b, act) * 1.6, 0.0, 0.95):
		f.state = State.BITTEN
		f.t = 0.0
		f.goal = b.pos
		f.burst = true
		takes += 1
		f.hunger = maxf(f.hunger - 0.2, 0.0)
		bite.emit(f, b)
	else:
		_refuse(f)


func _refuse(f: Fish) -> void:
	refusals += 1
	f.refused += 1
	f.wary = minf(f.wary + 0.3, 1.0)
	if f.bait and f.bait.fish == f:
		f.bait.fish = null
	f.bait = null
	_go(f, State.RETURN, f.lie, float(f.spec.cruise) * 1.2)


func _spit(f: Fish) -> void:
	f.refused += 1
	f.wary = 1.0
	if f.bait and f.bait.fish == f:
		f.bait.fish = null
	f.bait = null
	_go(f, State.RETURN, f.lie, float(f.spec.cruise) * 1.5)


## The angler strikes: hooked, if it still has the bait in its mouth.
func set_hook(b: Bait) -> bool:
	var f: Fish = b.fish
	if f == null or f.state != State.BITTEN:
		return false
	b.hooked = true
	f.state = State.HOOKED
	f.t = 0.0
	f.stamina = 1.0
	f.burst = true
	_fight_goal(f)
	_alarm_near(f.pos, ALARM_M * 1.5, f)
	return true


## The way it pulls: for cover away from the line (deeper, downstream, under the bank).
func _fight_goal(f: Fish) -> void:
	var away := Vector3(f.pos.x - player.global_position.x, 0.0, f.pos.z - player.global_position.z).normalized() if player else Vector3.FORWARD
	away = (away + river_flow(f.pos.z) * 0.6).rotated(Vector3.UP, rng.randf_range(-0.9, 0.9)).normalized()
	var g := f.pos + away * rng.randf_range(3.0, 7.0)
	if depth(g.x, g.z) < _min_depth(f):
		g = Vector3(river_x(f.pos.z), 0.0, f.pos.z) + away * 2.0
	g.y = layer_y(f, g.x, g.z) if depth(g.x, g.z) > 0.05 else f.pos.y
	f.goal = g


func _fight_think(f: Fish) -> void:
	var b := f.bait
	if b == null:
		return
	var fight_s := float(f.spec.get("fight_s", 20.0))
	var pulled := b.pull.length()
	f.stamina = maxf(f.stamina - THINK_S / fight_s * (0.5 + pulled), 0.0)
	f.speed = float(f.spec.burst) * lerpf(0.15, 0.8, f.stamina)
	b.tension = f.stamina * clampf(f.lb / 3.0, 0.2, 3.0)
	if f.t > 1.2 or f.pos.distance_to(f.goal) < 0.6:
		f.t = 0.0
		_fight_goal(f)
	# a trout or salmon on the line leaps
	if f.sp in ["brook_trout", "salmon"] and not f.air and f.stamina > 0.3 and rng.randf() < THINK_S * 0.12 * f.stamina:
		_leap(f, f.forward() * 1.5 + Vector3.UP * lerpf(2.2, 3.4, f.stamina), State.HOOKED)


## The hooked fish off the water: gone from it and from the numbers. Its species, length and weight, or {}.
func land_fish(b: Bait) -> Dictionary:
	var f: Fish = b.fish
	if f == null or f.state != State.HOOKED:
		return {}
	f.gone = true
	b.fish = null
	b.hooked = false
	var st := _stock_here()
	if st:
		st.take(f.sp)
	landed.emit(f)
	_sweep()
	return {"species": f.sp, "name": String(f.spec.get("name", f.sp)), "length": f.length, "lb": f.lb}


## The line gone (broken, cut): the fish free, put down.
func release(b: Bait) -> void:
	var f: Fish = b.fish
	b.fish = null
	b.hooked = false
	if f:
		f.bait = null
		f.state = State.RETURN
		_spook(f, player.global_position if player else f.pos)


# --- Moving -------------------------------------------------------------------------------------------------------

func _move(f: Fish, dt: float) -> void:
	f.t += dt
	if f.hidden:
		return
	if f.air:
		f.vel.y -= GRAVITY * dt
		f.pos += f.vel * dt
		f.pitch = atan2(f.vel.y, Vector2(f.vel.x, f.vel.z).length())
		f.effort = 1.6
		f.phase += 6.0 * dt
		var sy := surface(f.pos.z)
		if f.vel.y < 0.0 and f.pos.y < sy - 0.05:
			f.air = false
			f.vel = Vector3.ZERO
			f.pos.y = sy - 0.15
			_splash(f.pos, f.length)
			if f.state == State.LEAP:
				_go(f, f.after_leap, f.lie, float(f.spec.cruise) * 1.2)
		return
	var cur := f.current
	if f.state == State.STRIKE or f.state == State.FLEE or f.state == State.RUN:
		cur = current_at(f.pos)
	# through the water toward its goal at its speed (holding: against the current)
	var to := f.goal - f.pos
	var over := to.normalized() * minf(to.length() * 1.6, f.speed) if to.length() > 0.02 else Vector3.ZERO
	# a strike: flat out at it, no easing off
	if f.state == State.STRIKE and to.length() > 0.02:
		over = to.normalized() * f.speed
	var want := over - cur
	var top := float(f.spec.burst) if f.burst else float(f.spec.cruise) * 3.0
	if f.state == State.HOOKED and f.bait:
		want = over - cur
		top = f.speed
	if want.length() > top:
		want = want.normalized() * top
	var acc := (40.0 if f.state == State.STRIKE else 14.0) if f.burst else 3.0
	f.swim = f.swim.move_toward(want, acc * dt)
	var step := (f.swim + cur) * dt
	if f.state == State.HOOKED and f.bait:
		step += f.bait.pull * dt
	var np := f.pos + step
	np.z = clampf(np.z, _zr.x + 0.5, _zr.y - 0.5)
	# kept in the water: off the shallows, under the top, over the bottom
	var s := surface(np.z)
	var b := bed(np.x, np.z)
	var md := _min_depth(f)
	if s - b < md or absf(np.x - river_x(np.z)) > _bank:
		var cx := river_x(np.z)
		np.x = f.pos.x + signf(cx - f.pos.x) * absf(step.x)
		b = bed(np.x, np.z)
		if s - b < md:
			np = f.pos
			f.swim = Vector3.ZERO
			s = surface(np.z)
			b = bed(np.x, np.z)
	var bh := f.length * 0.1
	np.y = clampf(np.y, b + bh + 0.02, s - bh - 0.03)
	f.pos = np
	if f.bait and (f.state == State.BITTEN or f.state == State.HOOKED):
		f.bait.pos = f.pos + f.forward() * f.length * 0.5
	# facing the way it swims through the water; its tail's beat by how hard
	var sw := Vector2(f.swim.x, f.swim.z).length()
	if sw > 0.05:
		var ty := atan2(-f.swim.x, -f.swim.z)
		var turn := wrapf(ty - f.yaw, -PI, PI)
		var rate := (7.0 if f.burst else 2.2) * dt
		var dy := clampf(turn, -rate, rate)
		f.yaw = wrapf(f.yaw + dy, -PI, PI)
		f.bend = lerpf(f.bend, clampf(dy / maxf(dt, 0.001) * 0.18, -1.0, 1.0), 0.2)
	else:
		f.bend = lerpf(f.bend, 0.0, 0.1)
	var tp := clampf(atan2(f.swim.y, maxf(sw, 0.05)), -0.5, 0.5)
	if f.spec.get("layer", "") == "bottom" and f.state in [State.SCHOOL, State.CRUISE] and sw < 0.2:
		tp = -0.25
	f.pitch = lerpf(f.pitch, tp, 0.1)
	var through := f.swim.length()
	f.effort = clampf(0.18 + through / maxf(float(f.spec.cruise) * 1.4, 0.05), 0.15, 2.0)
	f.phase += (0.9 + 2.2 * through / maxf(f.length, 0.1)) * dt
	# a wake in the shallows as it bolts
	if f.burst and through > 1.2 and f.surf_y - f.pos.y < 0.35 and fmod(f.t, 0.14) < dt:
		_ring(Vector3(f.pos.x, f.surf_y, f.pos.z), 0.5, 0.25 + f.length)


# --- Rings and splashes -------------------------------------------------------------------------------------------

## A ring on the water at `at`: `strength` 0..1, out to `size` m.
func _ring(at: Vector3, strength: float, size: float) -> void:
	if rings.size() >= MAX_RINGS:
		rings.pop_front()
	rings.append([at, 0.0, lerpf(1.6, 3.2, clampf(size, 0.0, 1.0)), clampf(strength, 0.0, 1.0), size])


func _age_rings(dt: float) -> void:
	var keep := []
	for r: Array in rings:
		r[1] = float(r[1]) + dt
		var p: Vector3 = r[0]
		p += drift_at(p) * dt
		p.y = surface(p.z)
		r[0] = p
		if float(r[1]) < float(r[2]):
			keep.append(r)
	rings = keep


func _splash(at: Vector3, size: float) -> void:
	var sy := surface(at.z)
	_ring(Vector3(at.x, sy, at.z), 1.0, 0.6 + size * 1.5)
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = int(10 + size * 30.0)
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.0 + size * 2.0
	p.gravity = Vector3(0.0, -9.0, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1 + size * 0.2
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.06
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 6
	s.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.9, 0.95, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	s.material = m
	p.mesh = s
	add_child(p)
	p.global_position = Vector3(at.x, sy + 0.05, at.z)
	Fx._emit(p, false)


# --- Drawing ------------------------------------------------------------------------------------------------------

func _draw_fish() -> void:
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else (player.global_position if player else Vector3.ZERO)
	if eye_override:
		eye = eye_override.global_position
	var counts := {}
	for id: String in _mm:
		counts[id] = 0
	for f in fish:
		if f.hidden or f.pos.distance_to(eye) > DRAW_M:
			continue
		var mmi: MultiMeshInstance3D = _mm.get(f.sp)
		if mmi == null:
			continue
		var n := int(counts[f.sp])
		var mm := mmi.multimesh
		if n >= mm.instance_count:
			continue
		var bs := Basis(Vector3.UP, f.yaw) * Basis(Vector3.RIGHT, f.pitch)
		mm.set_instance_transform(n, Transform3D(bs.scaled(Vector3.ONE * f.length), f.pos))
		mm.set_instance_custom_data(n, Color(fposmod(f.phase, 1.0), 0.0, f.effort, f.bend))
		counts[f.sp] = n + 1
	for id: String in _mm:
		(_mm[id] as MultiMeshInstance3D).multimesh.visible_instance_count = int(counts[id])
	var rm := _ring_mm.multimesh
	var light := daylight()
	var i := 0
	for r: Array in rings:
		if i >= rm.instance_count:
			break
		var age := float(r[1]) / float(r[2])
		var rad := 0.08 + float(r[4]) * sqrt(age) * 1.1
		rm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(rad * 2.0, 1.0, rad * 2.0)), (r[0] as Vector3) + Vector3.UP * 0.015))
		rm.set_instance_custom_data(i, Color(age, float(r[3]), light, 0.0))
		i += 1
	rm.visible_instance_count = i


func summary() -> String:
	var counts := {}
	var states := {}
	for f in fish:
		counts[f.sp] = int(counts.get(f.sp, 0)) + 1
		var sn: String = State.keys()[f.state]
		states[sn] = int(states.get(sn, 0)) + 1
	return "fish %d %s  states %s  bugs %d rings %d  rises %d leaps %d spooks %d kills %d takes %d refusals %d" % [
			fish.size(), str(counts), str(states), bugs.size(), rings.size(), rises, leaps, spooks, kills, takes, refusals]
