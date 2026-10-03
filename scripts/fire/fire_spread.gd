class_name FireSpread
extends Node3D
## Fire and ruin (scripts/fire; the story audit's item 5, for the raid of 1757 and the burnings after it): built pieces
## (BuildWorld's BuiltPieces, the fort's palisade, gate, firing step and blockhouses among them: the fort is built from
## pieces, FortPlan) and anything a story tags burnable (BURNABLE_GROUP) catch fire, burn, set their neighbours alight
## and fall to ruins. One manager node under the level (the level installs it; FireSpread.of() makes one where there is
## none), found by its group; no autoload.
##
##   var fire := FireSpread.of(get_tree())
##   fire.ignite(piece)                     # a BuiltPiece, its body or any node under it, a piece id, a burnable node
##   fire.ignite_area(pos, 6.0)             # everything burnable within 6 m (a raid's torches thrown)
##   fire.is_burning(piece)                 # or a point: inside a burning piece's box
##   fire.put_out(piece)                    # beaten out while it is still catching (force: at any stage, a story's)
##   fire.burned_count()                    # pieces burnt to ruins in this game (saved)
## Only built pieces of wood and nodes in BURNABLE_GROUP burn (anything else handed to ignite is refused: the player,
## a horse, a tree).
##
## A burning piece goes through:
##   catching   CATCH_S (each piece its own pace, PACE: a raid's pieces do not all move on together; slower in rain):
##              small flames where it caught, smoke starting; it can still be beaten out (FireTorch, put_out)
##   burning    BURN_S[type] (x its pace, longer in rain): flames all over it (FireFx), dark smoke, embers; CHAR_AT of the
##              way through its look turns to charred wood (FireRuin's charred material: the material swap), what is on
##              it too (a woodpile's logs, a smokehouse's racks, the boat on its stand); it heats its neighbours meanwhile
##   collapse   it is taken down (BuildWorld.remove_piece: a shared world takes it down too) and leaves a FireRuin, its
##              charred stubs and a scorched patch of ground; whatever rested on it (BuildWorld.dependents: a roof on
##              the walls, the walls on a floor) burns and falls within FALL_S. At most FALLS_PER_TICK fall in one tick
##              (the rest a tick later): each fall re-dresses neighbours and rebakes the household's paths.
## What is in a piece when it burns: a chest's stock, a woodpile's logs, a smokehouse's meat and the boat on its stand
## burn with it (a chest alight tells the player near it, while there is still time to beat it out or empty it); the
## weapons in a rack are laid on the ground as it goes (WeaponRack's own); a cradle, a bed or a lean-to alight is no
## place to lay the baby, sleep or shelter (out of those groups while it burns: BabyLink takes the baby elsewhere).
## Spread: each burning piece heats the burnables within SPREAD_R of its box (the gap between their boxes, so touching
## pieces heat the most) at SPREAD_RATE (x its strength, x how close); a piece catches when its heat reaches 1 and cools
## at COOL_RATE while nothing heats it. Downwind it heats up to WIND_GAIN times faster and reaches farther (WIND_REACH),
## upwind slower (the weather's ground wind, WeatherSystem.wind_ground_*, else the project's wind globals); fire climbs
## (CLIMB: a roof over a burning wall); rain (TorchState.rain_at: the weather's) slows the heating, the catching and the
## burning (RAIN_*).
## The player sets fire on purpose only (FireTorch): a lit torch in the hand, the crosshair on a burnable, E holds it
## there and after TORCH_S it catches; a torch carried past a wall never does.
## Cheap (budget: 20 pieces alight within 1 ms a frame on medium): the work is a tick every TICK_S, not every frame;
## the neighbours are looked for again every NEAR_EVERY s, at most SCANS_PER_TICK burns a tick; the particles are GPU
## particles (FireFx), their shaders compiled while the level loads (_warm_up); ONE shared light (no shadows) at the
## burning area nearest the camera and one crackle (the torch's loop, deeper) with it; one smoke column per burning area
## (CLUSTER_M square, FireFx.column) seen from far off, smouldering on after the fires there are out.
## Saved (SaveParts.save_fire / load_fire, the "fire" part, after the building): the ruins, the pieces alight (by id:
## stage and how far through), the count; a story's burnable not there yet when the part loads (a mission's cabin) is
## waited for. A shared world (NetSession) is sent each piece that catches ("ignite") and is put out ("put_out"); the
## collapse is the building's own "unbuild" (a piece taken down there while alight here leaves its ruin here too, and
## what rested on it falls); a player joining gets the fire part with the world.

signal ignited(target: Node3D)
signal put_out_fire(target: Node3D)
signal collapsed(type: String, at: Vector3)

const GROUP := &"fire_spread"
const NODE_NAME := "Fire"
## Nodes that burn though they are not built pieces (a story's cabin): their meshes char and are cut where they stand,
## their colliders go off.
const BURNABLE_GROUP := &"burnable"
## Pieces of stone and earth: they do not burn.
const NOT_BURNABLE := ["hearth", "campfire", "work_stone", "charcoal_mound", "forge", "trap_steel", "trap_snare"]
## Seconds a piece burns once alight all over (real time at speed 1; the game's day is 48 minutes): its wood.
const BURN_S := {"wall": 75.0, "wall_window": 70.0, "wall_door": 70.0, "floor": 90.0, "roof": 55.0, "gable": 45.0,
		"post": 40.0, "palisade": 75.0, "palisade_gate": 85.0, "walkway": 55.0, "walkway_ramp": 50.0, "ladder": 25.0,
		"blockhouse": 160.0, "flagpole": 40.0, "lean_to": 20.0, "bough_bed": 18.0, "pole_bed": 22.0, "drying_rack": 20.0,
		"woodpile": 70.0, "smokehouse": 50.0, "storage_chest": 30.0, "cradle": 20.0, "boat_stand": 35.0}
const DEFAULT_BURN_S := 40.0
const CATCH_S := 8.0
## Each burn's own pace: its catching and burning times x 1 +- PACE (from where it stands: the same on every machine
## and after a load), so pieces lit together do not char and fall in the same tick.
const PACE := 0.15
## Of the way through the burning: the look turns to charred wood; the fire dies down after FADE_AT.
const CHAR_AT := 0.3
const FADE_AT := 0.85
## A piece whose support fell burns this much longer at most, then falls too.
const FALL_S := 2.5
## At most this many pieces fall in one tick (the rest the next).
const FALLS_PER_TICK := 2
## Spread: the reach (m, the gap between the boxes), the heat a second a fully burning piece gives one touching it
## (catches in 1 / SPREAD_RATE s: 12.5 s), the cooling a second, the climb, the wind and the rain.
const SPREAD_R := 2.5
const SPREAD_RATE := 0.08
const COOL_RATE := 0.02
const CLIMB := 1.5
const WIND_GAIN := 1.6
const WIND_REACH := 0.6
const RAIN_SPREAD := 0.75
const RAIN_CATCH := 0.6
const RAIN_BURN := 0.8
const TICK_S := 0.25
## Neighbours are looked for this far (m) past a burning piece's own half size, again every NEAR_EVERY s (x its pace)
## and when a piece is built near it; at most SCANS_PER_TICK burns look in one tick.
const NEAR_M := 9.0
const NEAR_EVERY := 3.0
const SCANS_PER_TICK := 4
const CLUSTER_M := 16.0
## A torch held to a burnable this long (FireTorch) sets it alight; the torch is looked at every TORCH_POLL s.
const TORCH_S := 3.0
const TORCH_POLL := 0.25
const LIGHT_COLOR := Color(1.0, 0.55, 0.26)
const LIGHT_ENERGY := 3.4
const LIGHT_RANGE := 22.0
const LIGHT_UP := 1.6
## Seconds a smoke column smoulders on (thinning) after the fires under it are out.
const COLUMN_SMOULDER_S := 90.0
const STAGE_CATCHING := 0
const STAGE_BURNING := 1
const COLLAPSE_SFX := &"gather_rec_tree_crack"
const IGNITE_SFX := &"torch_ignite"
## Groups a piece alight is taken out of while it burns (Cradle.GROUP: the baby is not laid in it; beds; lean-tos as
## shelters), back in when it is put out.
const PLACE_GROUPS := [&"cradles", &"camp_stations", &"shelters"]
## A chest alight tells the player within this many metres.
const TELL_M := 40.0
## Frames the warm-up fire is drawn for (as PlayerTorch.WARM_FRAMES).
const WARM_FRAMES := 4


## One thing alight.
class Burn:
	extends RefCounted
	var node: Node3D
	var piece: BuiltPiece
	var type := ""
	var stage := 0
	## Seconds in the stage; the burning's seconds left of `total`.
	var t := 0.0
	var left := 0.0
	var total := 1.0
	## Its catching time (CATCH_S x its pace) and its pace (1 +- PACE).
	var catch_s := FireSpread.CATCH_S
	var pace := 1.0
	## Where it caught (world) and its box (world AABB).
	var at := Vector3.ZERO
	var box := AABB()
	var fx: FireFx
	var charred := false
	var rain := 0.0
	## [[node, box]] of the burnables within reach, looked for again every few seconds (and when a piece is built near).
	var neighbors: Array = []
	var near_t := 0.0
	## Its tree_exiting hook (FireSpread._on_gone, bound to its id).
	var gone_cb: Callable
	## [[node, group]] it was taken out of while it burns (PLACE_GROUPS).
	var groups_out: Array = []

	func progress() -> float:
		return 1.0 - clampf(left / maxf(total, 0.01), 0.0, 1.0) if stage == 1 else 0.0

	## 0..1: how hard it burns now (the heat it gives, the flames shown).
	func intensity() -> float:
		if stage == 0:
			return lerpf(0.15, 0.5, clampf(t / maxf(catch_s, 0.01), 0.0, 1.0))
		var p := progress()
		if p > FireSpread.FADE_AT:
			return lerpf(1.0, 0.45, (p - FireSpread.FADE_AT) / (1.0 - FireSpread.FADE_AT))
		return 1.0


## The fire's clock x this (tests, a story that wants a fast fire).
var speed := 1.0
## Tests: step() is called by hand, not every TICK_S.
var manual := false
## >= 0: the rain on every fire (tests); < 0: the weather's (TorchState.rain_at).
var rain_override := -1.0
## Not INF: the wind on every fire (tests, a story's gale): toward where it blows, its length the strength 0..1; INF:
## the weather's.
var wind_override := Vector3.INF
## The level's quality preset ("low": half the particles, no embers).
var quality := "medium"
## Pieces burnt to ruins in this game.
var burned_total := 0
var ruins: Array[FireRuin] = []
## The player's torch and hands at a fire (setting it, beating it out).
var torch: FireTorch
## The last tick's cost and a running mean (µs; the budget check); the pieces that fell in the last tick.
var last_step_us := 0
var mean_step_us := 0.0
var last_falls := 0

var _burns := {}              ## instance id -> Burn
var _heat := {}               ## instance id -> heat 0..1 of a burnable not yet alight
var _heat_node := {}          ## instance id -> its node
var _heat_at := {}            ## instance id -> where the heat reaches it (world)
var _heated := {}             ## heated this tick
var _ruined := {}             ## instance id -> true: a burnable node burnt where it stands
var _boxes := {}              ## instance id -> world AABB (pieces do not move)
var _columns := {}            ## Vector2i -> {"p": GPUParticles3D, "idle": s}
var _dying: Array[FireFx] = []
## Pieces just built (BuildWorld's child_entered_tree), looked at on the next tick: the ruins they cover cleared, the
## burns near them looking for neighbours again.
var _added: Array = []
## Saved entries whose burnable is not in the level yet (a story's cabin, made after the fire part loads):
## [{"ruin": e} or {"burn": e}], tried again every second.
var _pending: Array = []
## Bumped by clear(): what was deferred before it (a ruin of a piece gone) is dropped.
var _gen := 0
var _acc := 0.0
var _ruin_acc := 0.0
var _removing := -1
var _rechar := false
var _world_ref: BuildWorld
var _fx_root: Node3D
var _ruins_root: Node3D
var _light: OmniLight3D
var _crackle: AudioStreamPlayer3D
var _crackle_db := 0.0
var _light_at := Vector3.ZERO
var _light_power := 0.0
var _light_shown := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0
var _torch_poll := 0.0
var _dim := -1.0


## The level's fire (installed as the level is built; the one there already when something made it first, of()).
static func install(level: Node) -> FireSpread:
	var f := find(level.get_tree()) if level.is_inside_tree() else null
	if f == null:
		f = FireSpread.new()
		f.name = NODE_NAME
		level.add_child(f)
	var s: Variant = level.get("settings")
	if s is WorldSettings:
		f.quality = (s as WorldSettings).quality
	return f


static func find(tree: SceneTree) -> FireSpread:
	return tree.get_first_node_in_group(GROUP) as FireSpread if tree else null


## The level's fire, made under the current scene when there is none (`create`).
static func of(tree: SceneTree, create := true) -> FireSpread:
	var f := find(tree)
	if f != null or not create or tree == null or tree.current_scene == null:
		return f
	f = FireSpread.new()
	f.name = NODE_NAME
	tree.current_scene.add_child(f)
	return f


## Whether `x` (a piece, a node) is alight in the level's fire (build mode's Take down asks).
static func alight(x: Node) -> bool:
	var f := find(x.get_tree()) if x and x.is_inside_tree() else null
	return f != null and f.is_burning(x)


func _ready() -> void:
	add_to_group(GROUP)
	_fx_root = Node3D.new()
	_fx_root.name = "Fires"
	add_child(_fx_root)
	_ruins_root = Node3D.new()
	_ruins_root.name = "Ruins"
	add_child(_ruins_root)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = 1757
	_light = OmniLight3D.new()
	_light.name = "FireLight"
	_light.light_color = LIGHT_COLOR
	_light.light_energy = 0.0
	_light.omni_range = LIGHT_RANGE
	_light.omni_attenuation = 1.2
	_light.light_specular = 0.3
	_light.shadow_enabled = false
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 90.0
	_light.distance_fade_length = 30.0
	_light.visible = false
	add_child(_light)
	if Sfx.has(TorchFire.CRACKLE):
		_crackle = Sfx.make_player_3d(TorchFire.CRACKLE, self)
		if _crackle:
			# a building's roar: the torch's crackle deeper, louder and heard farther
			_crackle.name = "FireCrackle"
			_crackle.pitch_scale = 0.72
			_crackle.unit_size = 7.0
			_crackle.max_distance = 90.0
			_crackle_db = _crackle.volume_db + 12.0
	torch = FireTorch.new()
	torch.name = "Torch"
	torch.fire = self
	add_child(torch)
	_hook_world.call_deferred()
	if DisplayServer.get_name() != "headless":
		_warm_up.call_deferred()


func _exit_tree() -> void:
	FireFx.release()
	FireRuin.release()


## Compiles the fire's shaders while the level loads (as PlayerTorch._warm_up: the first fire of a game would otherwise
## build them on the spot, a hitch just as the raid starts): a fire's flames, smoke and embers, a smoke column and a
## charred card drawn for WARM_FRAMES frames right in front of the camera, shrunk to a speck (their particles in the
## speck's own frame, so they shrink with it), then freed.
func _warm_up() -> void:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null:
		return
	var speck := Node3D.new()
	speck.name = "FireWarmUp"
	cam.add_child(speck)
	speck.position = Vector3(0.0, 0.0, -0.5)
	speck.scale = Vector3.ONE * 0.01
	var fx := FireFx.make(speck, AABB(speck.global_position, Vector3.ONE * 0.01), quality)
	fx.strength = 1.0
	FireFx.column(speck, speck.global_position, quality)
	var card := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	card.mesh = q
	speck.add_child(card)
	FireRuin.char_geometry([card], INF, 1.0)
	for p in speck.find_children("*", "GPUParticles3D", true, false):
		(p as GPUParticles3D).local_coords = true
		(p as Node3D).position = Vector3.ZERO
	fx.position = Vector3.ZERO
	for i in WARM_FRAMES:
		await get_tree().process_frame
	if is_instance_valid(speck):
		speck.queue_free()


# --- The API ----------------------------------------------------------------------------------------------------

## Sets `target` alight (a BuiltPiece, a node under one such as its body, a piece id, or a node in BURNABLE_GROUP or
## under one), catching at `at` (world; INF: low on its middle). True when it caught now (false: it does not burn, it
## burns already, or it is a ruin).
func ignite(target: Variant, at := Vector3.INF) -> bool:
	var n := _resolve(target)
	if n == null or not burnable(n):
		return false
	return _start(n, at)


## Sets alight everything burnable whose box is within `radius` of `pos`; returns how many caught (one sound for all).
func ignite_area(pos: Vector3, radius: float) -> int:
	var count := 0
	var cands: Array = []
	var w := _world()
	if w:
		cands.append_array(w.near(pos, radius + NEAR_M))
	cands.append_array(get_tree().get_nodes_in_group(BURNABLE_GROUP))
	var first := Vector3.INF
	for c in cands:
		var n := c as Node3D
		if n == null or not burnable(n):
			continue
		var box := _box_of(n)
		var q := _closest(box, pos)
		if q.distance_to(pos) <= radius and _start(n, q, false, false):
			count += 1
			if first == Vector3.INF or q.distance_to(pos) < first.distance_to(pos):
				first = q
	if count > 0 and Sfx.has(IGNITE_SFX):
		Sfx.play_3d(IGNITE_SFX, first, 3.0, 0.75)
	return count


## Puts out `x` (as ignite takes it): only while it is still catching (beaten out) unless `force` (a story's, at any
## stage: what is charred stays charred). True when it was alight and is out now. Its heat is gone too (a neighbour
## still burning heats it again).
func put_out(x: Variant, force := false) -> bool:
	var n := _resolve(x)
	var b: Burn = _burns.get(n.get_instance_id()) if n else null
	if b == null or (b.stage != STAGE_CATCHING and not force):
		return false
	_end_burn(n.get_instance_id(), b)
	_forget_heat(n.get_instance_id())
	put_out_fire.emit(n)
	if b.piece:
		NetSession.world_event(get_tree(), "put_out", {"key": NetSession.piece_key(b.piece)})
	return true


## Whether `x` burns now: a piece or node (as ignite takes them), or a point (inside a burning one's box, 0.5 m round).
func is_burning(x: Variant) -> bool:
	if x is Vector3:
		for b: Burn in _burns.values():
			if b.box.grow(0.5).has_point(x):
				return true
		return false
	var n := _resolve(x)
	return n != null and _burns.has(n.get_instance_id())


## "catching", "burning", "charred" (burning, the look charred), "" (not alight).
func stage_of(x: Variant) -> String:
	var n := _resolve(x)
	var b: Burn = _burns.get(n.get_instance_id()) if n else null
	if b == null:
		return ""
	if b.stage == STAGE_CATCHING:
		return "catching"
	return "charred" if b.charred else "burning"


## Pieces burnt to ruins in this game.
func burned_count() -> int:
	return burned_total


func burning_count() -> int:
	return _burns.size()


## 0..1 of the heat `x` has taken (1: it catches).
func heat_of(x: Variant) -> float:
	var n := _resolve(x)
	return float(_heat.get(n.get_instance_id(), 0.0)) if n else 0.0


## Whether `n` can burn: a built piece of wood, or a node in BURNABLE_GROUP; not a ruin.
func burnable(n: Node3D) -> bool:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree() or _ruined.has(n.get_instance_id()):
		return false
	if n is BuiltPiece:
		return not ((n as BuiltPiece).type in NOT_BURNABLE)
	return n.is_in_group(BURNABLE_GROUP)


## Seconds a `type` burns.
static func burn_time(type: String) -> float:
	return float(BURN_S.get(type, DEFAULT_BURN_S))


## 1 +- PACE: how much longer or shorter than the rest a burnable at `pos` catches (`salt` 0) and burns (`salt` 1).
static func pace_at(pos: Vector3, salt := 0) -> float:
	var h := hash([roundi(pos.x * 10.0), roundi(pos.y * 10.0), roundi(pos.z * 10.0), salt])
	return 1.0 + PACE * (float(absi(h) % 2001) / 1000.0 - 1.0)


## The heat a second a burning box `from` (at `intensity` 0..1) gives a box `to`: the gap between them within the reach,
## the wind (toward where it blows, x its strength 0..1: faster and farther downwind, slower upwind), the climb, the rain.
static func spread_rate(from: AABB, to: AABB, intensity: float, wind: Vector3, rain: float) -> float:
	var gap := box_gap(from, to)
	var d := to.get_center() - from.get_center()
	var flat := Vector3(d.x, 0.0, d.z)
	var along := flat.normalized().dot(Vector3(wind.x, 0.0, wind.z)) if flat.length() > 0.05 else 0.0
	var reach := SPREAD_R * (1.0 + WIND_REACH * maxf(along, 0.0))
	if gap >= reach:
		return 0.0
	var k := 1.0 - gap / reach
	var wf := clampf(1.0 + WIND_GAIN * along, 0.3, 3.0)
	var up := CLIMB if d.y > 0.5 else 1.0
	return SPREAD_RATE * intensity * k * wf * up * (1.0 - RAIN_SPREAD * clampf(rain, 0.0, 1.0))


## The gap between two boxes (0 where they touch or overlap).
static func box_gap(a: AABB, b: AABB) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	var dz := maxf(0.0, maxf(a.position.z - b.end.z, b.position.z - a.end.z))
	return Vector3(dx, dy, dz).length()


## The rain on a fire at `pos` now (0..1).
func rain_at(pos: Vector3) -> float:
	if rain_override >= 0.0:
		return clampf(rain_override, 0.0, 1.0)
	return TorchState.rain_at(get_tree(), pos)


## The ground wind now: toward where it blows, its length the strength 0..1.
func wind_now() -> Vector3:
	if wind_override != Vector3.INF:
		return wind_override
	for n in get_tree().get_nodes_in_group(TorchState.WEATHER_GROUP):
		var wx: Variant = n.get("weather")
		if wx is WeatherSystem:
			var d: Vector2 = (wx as WeatherSystem).wind_ground_dir
			return Vector3(d.x, 0.0, d.y).normalized() * clampf((wx as WeatherSystem).wind_ground_strength, 0.0, 1.0)
	return TorchFire._wind()


## Takes ruin `r` away (build mode's Take down on it, a piece built over it).
func clear_ruin(r: FireRuin) -> void:
	ruins.erase(r)
	if is_instance_valid(r):
		r.queue_free()


# --- The tick ---------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	if not manual:
		_acc += delta
		if _acc >= TICK_S:
			step(_acc)
			_acc = 0.0
	_light_frame(delta)


## One tick of the fire (`dt` real seconds; x speed on the fire's clock): the stages, the spread, the catching, the
## falls, the effects, the columns, the light's place, the ruins' embers, the pieces just built, what a load waits for.
func step(dt: float) -> void:
	if _burns.is_empty() and _heat.is_empty() and _columns.is_empty() and _dying.is_empty() and ruins.is_empty() \
			and _pending.is_empty():
		_light_power = 0.0
		_added.clear()
		last_falls = 0
		return
	var t0 := Time.get_ticks_usec()
	var fdt := dt * speed
	_hook_world()
	var wind := wind_now()
	var cam := _camera_pos()
	if not _added.is_empty():
		var added := _added
		_added = []
		for v: Variant in added:
			if is_instance_valid(v) and (v as Node).is_inside_tree() and not (v as Node).is_queued_for_deletion():
				_on_built(v as BuiltPiece)
	if _rechar:
		_rechar = false
		for b: Burn in _burns.values():
			if b.charred:
				_char(b, true)
	var falls: Array[Burn] = []
	var scans := SCANS_PER_TICK
	_heated.clear()
	for id: int in _burns.keys():
		var b: Burn = _burns[id]
		if not is_instance_valid(b.node) or not b.node.is_inside_tree():
			_drop(id)
			continue
		var rain := rain_at(b.box.get_center())
		b.rain = rain
		if b.stage == STAGE_CATCHING:
			b.t += fdt * (1.0 - RAIN_CATCH * rain)
			if b.t >= b.catch_s:
				b.stage = STAGE_BURNING
				b.t = 0.0
				b.fx.spread_over(b.box)
		else:
			b.t += fdt
			b.left -= fdt / (1.0 + RAIN_BURN * rain)
			if not b.charred and b.progress() >= CHAR_AT:
				_char(b)
			if b.left <= 0.0:
				falls.append(b)
		b.near_t -= fdt
		if b.near_t <= 0.0 and scans > 0:
			b.neighbors = _neighbors(b)
			b.near_t = NEAR_EVERY * b.pace
			scans -= 1
		_spread_from(b, fdt, wind, rain)
		b.fx.strength = b.intensity()
		b.fx.set_wind(wind)
		b.fx.set_distance(b.box.get_center().distance_to(cam))
	# what nothing heats this tick cools
	for id: int in _heat.keys():
		if not _heated.has(id):
			_heat[id] = float(_heat[id]) - COOL_RATE * fdt
			if float(_heat[id]) <= 0.0:
				_forget_heat(id)
	# what has taken heat enough catches
	for id: int in _heat.keys():
		if float(_heat[id]) >= 1.0:
			var v: Variant = _heat_node.get(id)
			var at: Vector3 = _heat_at.get(id, Vector3.INF)
			_forget_heat(id)
			if is_instance_valid(v) and v is Node3D and burnable(v as Node3D):
				_start(v as Node3D, at)
	# the most overdue first, a few a tick
	falls.sort_custom(func(x: Burn, y: Burn) -> bool: return x.left < y.left)
	last_falls = mini(falls.size(), FALLS_PER_TICK)
	for i in last_falls:
		_collapse(falls[i])
	_tick_effects(dt, wind, cam)
	_ruin_acc += fdt
	if _ruin_acc >= 1.0:
		for i in range(ruins.size() - 1, -1, -1):
			if is_instance_valid(ruins[i]):
				ruins[i].step(_ruin_acc)
			else:
				ruins.remove_at(i)
		_ruin_acc = 0.0
		if not _pending.is_empty():
			_try_pending()
	last_step_us = Time.get_ticks_usec() - t0
	mean_step_us = lerpf(mean_step_us, float(last_step_us), 0.1) if mean_step_us > 0.0 else float(last_step_us)


func _spread_from(b: Burn, fdt: float, wind: Vector3, rain: float) -> void:
	var src := b.intensity()
	if src <= 0.0:
		return
	var c := b.box.get_center()
	for e: Array in b.neighbors:
		# (untyped first: a burnable freed since the list was made is a freed instance here)
		var v: Variant = e[0]
		if not is_instance_valid(v):
			continue
		var n := v as Node3D
		if n == null or not n.is_inside_tree():
			continue
		var id := n.get_instance_id()
		if _burns.has(id) or _ruined.has(id):
			continue
		var nb: AABB = e[1]
		var rate := spread_rate(b.box, nb, src, wind, rain)
		if rate <= 0.0:
			continue
		_heat[id] = float(_heat.get(id, 0.0)) + rate * fdt
		_heat_node[id] = n
		_heat_at[id] = _closest(nb, c)
		_heated[id] = true


## The burnables within reach of `b`: [[node, box]].
func _neighbors(b: Burn) -> Array:
	var out: Array = []
	var c := b.box.get_center()
	var r := NEAR_M + b.box.size.length() * 0.5
	var w := _world()
	if w:
		for p in w.near(c, r):
			if p != b.node and burnable(p):
				out.append([p, _box_of(p)])
	for g in get_tree().get_nodes_in_group(BURNABLE_GROUP):
		var n := g as Node3D
		if n and n != b.node and burnable(n):
			var nb := _box_of(n)
			if box_gap(b.box, nb) < SPREAD_R * (1.0 + WIND_REACH):
				out.append([n, nb])
	return out


func _forget_heat(id: int) -> void:
	_heat.erase(id)
	_heat_node.erase(id)
	_heat_at.erase(id)


## A piece just built: the ruins it stands over cleared away (no charred stubs through a new wall), the burns near it
## looking for their neighbours again on this tick or the next.
func _on_built(p: BuiltPiece) -> void:
	var box := _box_of(p)
	var c := box.get_center()
	for b: Burn in _burns.values():
		if b.node != p and b.box.get_center().distance_to(c) < NEAR_M + b.box.size.length() * 0.5 + box.size.length() * 0.5:
			b.near_t = 0.0
	for i in range(ruins.size() - 1, -1, -1):
		var r := ruins[i]
		if is_instance_valid(r) and r.covered_by(box):
			clear_ruin(r)


# --- Catching, charring, falling --------------------------------------------------------------------------------

func _start(n: Node3D, at := Vector3.INF, quiet := false, sound := true) -> bool:
	var id := n.get_instance_id()
	if _burns.has(id) or _ruined.has(id) or not n.is_inside_tree():
		return false
	var b := Burn.new()
	b.node = n
	b.piece = n as BuiltPiece
	b.type = b.piece.type if b.piece else String(n.name)
	b.box = _box_of(n)
	b.pace = pace_at(n.global_position)
	b.catch_s = CATCH_S * b.pace
	b.total = burn_time(b.type) * pace_at(n.global_position, 1)
	b.left = b.total
	# (the first look for neighbours spread over the next ticks: a raid lights twenty at once)
	b.near_t = 0.0
	var low := b.box.get_center() - Vector3(0.0, b.box.size.y * 0.3, 0.0)
	b.at = _closest(b.box, at) if at != Vector3.INF else low
	b.fx = FireFx.make(_fx_root, b.box, quality)
	b.fx.catch_at(b.at)
	b.fx.strength = b.intensity()
	_burns[id] = b
	_forget_heat(id)
	_leave_places(b)
	b.gone_cb = _on_gone.bind(id)
	if not n.tree_exiting.is_connected(b.gone_cb):
		n.tree_exiting.connect(b.gone_cb, CONNECT_ONE_SHOT)
	if not quiet:
		if sound and Sfx.has(IGNITE_SFX):
			Sfx.play_3d(IGNITE_SFX, b.at, 2.0, 0.8)
		ignited.emit(n)
		_warn_contents(b)
		if b.piece:
			NetSession.world_event(get_tree(), "ignite", {"key": NetSession.piece_key(b.piece), "at": SaveParts.v3(b.at)})
	return true


## A burn over (put out, or its node gone): its hook off, its flames dying, back in the groups it left.
func _end_burn(id: int, b: Burn) -> void:
	_burns.erase(id)
	if is_instance_valid(b.node) and b.gone_cb.is_valid() and b.node.tree_exiting.is_connected(b.gone_cb):
		b.node.tree_exiting.disconnect(b.gone_cb)
	_retire_fx(b)
	_back_in_places(b)


## Out of the groups that make it a place (PLACE_GROUPS: a cradle, a bed, a lean-to) while it burns.
func _leave_places(b: Burn) -> void:
	b.groups_out.append_array(_out_of_places(b.node))


## Takes `root` and what is under it out of PLACE_GROUPS: [[node, group]] of what it took out.
static func _out_of_places(root: Node) -> Array:
	var out: Array = []
	var nodes: Array = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for nd: Node in nodes:
		for g: StringName in PLACE_GROUPS:
			if nd.is_in_group(g):
				nd.remove_from_group(g)
				out.append([nd, g])
	return out


func _back_in_places(b: Burn) -> void:
	for e: Array in b.groups_out:
		var v: Variant = e[0]
		if is_instance_valid(v) and (v as Node).is_inside_tree():
			(v as Node).add_to_group(e[1])
	b.groups_out.clear()


## A chest alight with something in it: the player near it is told (there is time to empty it, or beat it out).
func _warn_contents(b: Burn) -> void:
	if b.piece == null or b.piece.type != "storage_chest":
		return
	var ch := b.piece.get_node_or_null("Chest") as StorageChest
	var p := _player()
	if ch and ch.total() > 0 and p and p.global_position.distance_to(b.box.get_center()) < TELL_M:
		tell("The storage chest is alight: what is in it will burn")


## Its look turns to charred wood (the material swap; again after a re-dress, `again`: only what lost it).
func _char(b: Burn, again := false) -> void:
	b.charred = true
	var gis := _geoms(b)
	if again:
		gis = gis.filter(func(g: Variant) -> bool: return is_instance_valid(g) and (g as GeometryInstance3D).material_override != FireRuin.material())
		if gis.is_empty():
			return
	FireRuin.char_geometry(gis, INF, 1.0)


## The burning has gone through: the ruin, the piece taken down, what rested on it falling after.
func _collapse(b: Burn) -> void:
	var id := b.node.get_instance_id()
	if not _burns.has(id):
		return
	_burns.erase(id)
	burned_total += 1
	_retire_fx(b)
	var at := b.box.get_center()
	if b.piece and is_instance_valid(b.piece):
		var w := b.piece.get_parent() as BuildWorld
		var deps: Array[BuiltPiece] = []
		if w:
			deps = w.dependents(b.piece)
		_ruin_piece(FireRuin.record(b.piece, b.box), _gen)
		_removing = id
		if w:
			w.remove_piece(b.piece)
		else:
			b.piece.queue_free()
		_removing = -1
		for d in deps:
			_fall(d)
	elif is_instance_valid(b.node):
		# (burnt where it stands: it stays out of the groups that made it a place)
		ruins.append(FireRuin.of_node(_ruins_root, b.node, b.box, _path_of(b.node)))
		_ruined[id] = true
	if Sfx.has(COLLAPSE_SFX):
		Sfx.play_3d(COLLAPSE_SFX, at, 0.0, 0.75)
	collapsed.emit(b.type, at)


## A piece whose support fell: alight all over now (if it was not), and down within FALL_S.
func _fall(p: BuiltPiece) -> void:
	if not is_instance_valid(p) or not burnable(p):
		return
	var id := p.get_instance_id()
	if not _burns.has(id):
		_start(p, Vector3.INF, true)
	var b: Burn = _burns.get(id)
	if b == null:
		return
	if b.stage == STAGE_CATCHING:
		b.stage = STAGE_BURNING
		b.t = 0.0
		b.fx.spread_over(b.box)
	b.left = minf(b.left, FALL_S)
	b.total = maxf(b.total, b.left)
	if not b.charred:
		_char(b)


## A burning piece left the tree without the fire taking it down (pulled down by hand, another machine's fire got there
## first and its "unbuild" came): burning all over by then, it leaves its ruin all the same and what rested on it comes
## down after it (as its own collapse would); only catching, it is just gone. (A hand's Take down needs nothing resting
## on it; another machine's removal does not take what rests on it down here.)
func _on_gone(id: int) -> void:
	if id == _removing:
		return
	var b: Burn = _burns.get(id)
	if b == null:
		return
	_burns.erase(id)
	_retire_fx(b)
	if not _level_live() or b.piece == null or not is_instance_valid(b.piece) or b.stage != STAGE_BURNING:
		return
	burned_total += 1
	var deps: Array = []
	var w := b.piece.get_parent() as BuildWorld
	if w:
		deps.append_array(w.dependents(b.piece))
	# (deferred: the piece is in the middle of leaving its parent)
	_ruin_piece.call_deferred(FireRuin.record(b.piece, b.box), _gen)
	_fall_after.call_deferred(deps, _gen)


func _fall_after(deps: Array, gen: int) -> void:
	if gen != _gen:
		return
	for d: Variant in deps:
		if is_instance_valid(d):
			_fall(d as BuiltPiece)


func _ruin_piece(rec: Dictionary, gen: int) -> void:
	if not is_inside_tree() or gen != _gen:
		return
	ruins.append(FireRuin.from_save(_ruins_root, rec, _detail()))


func _drop(id: int) -> void:
	var b: Burn = _burns.get(id)
	_burns.erase(id)
	if b:
		_retire_fx(b)


func _retire_fx(b: Burn) -> void:
	if b.fx and is_instance_valid(b.fx):
		b.fx.die()
		_dying.append(b.fx)
	b.fx = null


# --- Effects: the dying flames, the columns, the shared light and sound ----------------------------------------

func _tick_effects(dt: float, wind: Vector3, cam: Vector3) -> void:
	for i in range(_dying.size() - 1, -1, -1):
		var fx := _dying[i]
		if not is_instance_valid(fx) or not fx.tick(dt):
			_dying.remove_at(i)
	# the flames' and the embers' brightness for the eye (1 / the exposure: as bright on the screen at night as by day,
	# under the glow's threshold); one shared material each
	var dim := snappedf(Fx._fire_dim(self), 0.01)
	if dim != _dim:
		_dim = dim
		FireFx.flame_material().set_shader_parameter(&"intensity", 2.0 * dim)
		FireRuin.material().set_shader_parameter(&"dim", dim)
	# the burning areas: one column each; the light and the crackle at the one nearest the camera
	var areas := {}
	for b: Burn in _burns.values():
		var c := b.box.get_center()
		var k := Vector2i(floori(c.x / CLUSTER_M), floori(c.z / CLUSTER_M))
		var a: Array = areas.get(k, [Vector3.ZERO, 0, 0.0, -INF])
		a[0] = (a[0] as Vector3) + c
		a[1] = int(a[1]) + 1
		a[2] = float(a[2]) + b.intensity()
		a[3] = maxf(float(a[3]), b.box.end.y)
		areas[k] = a
	var best := INF
	_light_power = 0.0
	for k: Vector2i in areas:
		var a: Array = areas[k]
		var mid := (a[0] as Vector3) / float(a[1])
		var top := Vector3(mid.x, float(a[3]) + 0.5, mid.z)
		var col: Dictionary = _columns.get(k, {})
		if col.is_empty() or not is_instance_valid(col.get("p")):
			col = {"p": FireFx.column(_fx_root, top, quality), "idle": 0.0}
			_columns[k] = col
		var p: GPUParticles3D = col.p
		col.idle = 0.0
		p.global_position = p.global_position.lerp(top, 0.3)
		p.amount_ratio = clampf(0.3 + 0.12 * float(a[2]), 0.3, 1.0)
		p.emitting = true
		FireFx.set_column_wind(p, wind)
		var d := mid.distance_to(cam)
		if d < best:
			best = d
			_light_at = mid + Vector3(0, LIGHT_UP, 0)
			_light_power = clampf(float(a[2]) * 0.5, 0.35, 1.5)
	for k: Vector2i in _columns.keys():
		if areas.has(k):
			continue
		var col: Dictionary = _columns[k]
		var pv: Variant = col.get("p")
		if not is_instance_valid(pv):
			_columns.erase(k)
			continue
		var p := pv as GPUParticles3D
		col.idle = float(col.idle) + dt * speed
		p.amount_ratio = clampf(0.3 * (1.0 - float(col.idle) / COLUMN_SMOULDER_S), 0.02, 0.3)
		if float(col.idle) > COLUMN_SMOULDER_S:
			p.emitting = false
		if float(col.idle) > COLUMN_SMOULDER_S + FireFx.COLUMN_LIFE:
			p.queue_free()
			_columns.erase(k)


## Every frame: the one light (and the crackle) eases to the burning area nearest the camera and flickers.
func _light_frame(delta: float) -> void:
	_light_shown = move_toward(_light_shown, _light_power, delta * 0.8)
	var on := _light_shown > 0.01
	_light.visible = on
	if _crackle:
		if on and not _crackle.playing:
			_crackle.play(randf() * 5.0)
		elif not on and _crackle.playing:
			_crackle.stop()
	if not on:
		return
	var far := _light.position.distance_to(_light_at) > 30.0
	_light.position = _light_at if far else _light.position.lerp(_light_at, 1.0 - exp(-3.0 * delta))
	var n1 := _noise.get_noise_1d(_t * 6.0)
	var n2 := _noise.get_noise_1d(_t * 17.0 + 40.0)
	var flick := 0.82 + 0.12 * n1 + 0.06 * n2
	_light.light_energy = LIGHT_ENERGY * _light_shown * flick
	_light.omni_range = LIGHT_RANGE * (0.8 + 0.2 * minf(_light_shown, 1.5))
	if _crackle:
		_crackle.position = _light.position
		_crackle.volume_db = _crackle_db + linear_to_db(clampf(_light_shown, 0.05, 1.5))


# --- The torch (FireTorch: on purpose, with E) -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_torch_poll -= delta
	if _torch_poll > 0.0:
		return
	_torch_poll = TORCH_POLL
	if torch:
		torch.poll(TORCH_POLL)


## The burnable whose colliders are within `r` of `pos` (null: none).
func burnable_at(pos: Vector3, r := 0.3) -> Node3D:
	if not is_inside_tree():
		return null
	var sphere := SphereShape3D.new()
	sphere.radius = r
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis(), pos)
	q.collide_with_bodies = true
	q.collide_with_areas = false
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var n := _resolve(hit.get("collider"))
		if n != null and burnable(n):
			return n
	return null


## What the player calls `n` ("notched log wall", "test hut").
func name_of(n: Node3D) -> String:
	if n is BuiltPiece:
		var nm := BuildData.get_default().name_of((n as BuiltPiece).type)
		if nm != "":
			return nm.to_lower()
	return String(n.name).capitalize().to_lower()


## A line for the player at the bottom of the screen (PlayerInteractor.notice).
func tell(text: String) -> void:
	var p := _player()
	var it: Node = p.get("interactor") if p else null
	if it and it.has_method(&"notice"):
		it.call(&"notice", text, 2.5)


# --- Save ------------------------------------------------------------------------------------------------------

func save_data() -> Dictionary:
	var rs := []
	for r in ruins:
		if is_instance_valid(r):
			rs.append(r.to_save())
	var bs := []
	for b: Burn in _burns.values():
		if not is_instance_valid(b.node):
			continue
		var e := {"stage": b.stage, "t": b.t, "left": b.left, "total": b.total, "at": SaveParts.v3(b.at)}
		if b.piece:
			e["id"] = b.piece.piece_id
		else:
			e["path"] = _path_of(b.node)
		bs.append(e)
	# (what a load still waits for goes on being waited for)
	for pe: Dictionary in _pending:
		if pe.has("ruin"):
			rs.append(pe.ruin)
		else:
			bs.append(pe.burn)
	return {"burned": burned_total, "ruins": rs, "burning": bs}


func load_data(d: Dictionary) -> void:
	clear()
	burned_total = int(d.get("burned", 0))
	for e: Dictionary in d.get("ruins", []):
		if e.has("path"):
			if not _load_ruin_in_place(e):
				_pending.append({"ruin": e})
		else:
			ruins.append(FireRuin.from_save(_ruins_root, e, _detail()))
	for e: Dictionary in d.get("burning", []):
		if not _load_burn(e) and e.has("path"):
			_pending.append({"burn": e})


## A burnable charred where it stands, from its save entry: false when its node is not in the level (yet).
func _load_ruin_in_place(e: Dictionary) -> bool:
	var n := _node_at(String(e.path))
	if n == null:
		return false
	var b: Array = e.get("box", [])
	var box := AABB(SaveParts.to_v3(b[0]), SaveParts.to_v3(b[1])) if b.size() == 2 else _box_of(n)
	var r := FireRuin.of_node(_ruins_root, n, box, String(e.path))
	r.age = float(e.get("age", 0.0))
	_ruined[n.get_instance_id()] = true
	_out_of_places(n)
	ruins.append(r)
	return true


## A burn from its save entry: false when its piece or node is not there (a piece: gone; a node: not yet, perhaps).
func _load_burn(e: Dictionary) -> bool:
	var n: Node3D = null
	if e.has("id"):
		var w := _world()
		n = w.by_id(int(e.id)) if w else null
	else:
		n = _node_at(String(e.get("path", "")))
	if n == null or not burnable(n) or not _start(n, SaveParts.to_v3(e.get("at"), Vector3.INF), true):
		return false
	var b: Burn = _burns[n.get_instance_id()]
	b.stage = int(e.get("stage", STAGE_CATCHING))
	b.t = float(e.get("t", 0.0))
	b.total = float(e.get("total", b.total))
	b.left = float(e.get("left", b.total))
	if b.stage == STAGE_BURNING:
		b.fx.spread_over(b.box)
		if b.progress() >= CHAR_AT:
			_char(b)
	b.fx.strength = b.intensity()
	return true


## What a load waits for, tried again (every second): a story's cabin made since.
func _try_pending() -> void:
	var still: Array = []
	for pe: Dictionary in _pending:
		var done := _load_ruin_in_place(pe.ruin) if pe.has("ruin") else _load_burn(pe.burn)
		if not done:
			still.append(pe)
	_pending = still


## Everything put out and every ruin gone (a save loading over the level).
func clear() -> void:
	_gen += 1
	for id: int in _burns.keys():
		var b: Burn = _burns[id]
		if is_instance_valid(b.node) and b.gone_cb.is_valid() and b.node.tree_exiting.is_connected(b.gone_cb):
			b.node.tree_exiting.disconnect(b.gone_cb)
		_back_in_places(b)
		if b.fx and is_instance_valid(b.fx):
			b.fx.queue_free()
	_burns.clear()
	_heat.clear()
	_heat_node.clear()
	_heat_at.clear()
	for r in ruins:
		if is_instance_valid(r):
			r.queue_free()
	ruins.clear()
	_ruined.clear()
	_pending.clear()
	_added.clear()
	for k: Vector2i in _columns:
		var p: Variant = (_columns[k] as Dictionary).get("p")
		if is_instance_valid(p):
			(p as Node).queue_free()
	_columns.clear()
	for fx in _dying:
		if is_instance_valid(fx):
			fx.queue_free()
	_dying.clear()
	burned_total = 0
	_light_power = 0.0
	if torch:
		torch.stop()


# --- Helpers ---------------------------------------------------------------------------------------------------

## The burnable `x` stands for: a BuiltPiece (itself, a node under it such as its body, its id), a node in
## BURNABLE_GROUP (or one under it); null for anything else (the player, a horse, a tree burn nowhere).
func _resolve(x: Variant) -> Node3D:
	if x is int:
		var w := _world()
		return w.by_id(int(x)) if w else null
	if typeof(x) != TYPE_OBJECT or not is_instance_valid(x) or not (x is Node):
		return null
	var n: Node = x
	var scene := get_tree().current_scene if is_inside_tree() else null
	while n != null and n != scene:
		if n is BuiltPiece:
			return n as BuiltPiece
		if n.is_in_group(BURNABLE_GROUP) and n is Node3D:
			return n as Node3D
		n = n.get_parent()
	return null


func _world() -> BuildWorld:
	if _world_ref == null or not is_instance_valid(_world_ref):
		_world_ref = BuildWorld.of(get_tree(), false) if is_inside_tree() else null
	return _world_ref


## Listens to the building: a re-dress gives a charred piece its old look back (charred again); a piece built is looked
## at on the next tick (_on_built).
func _hook_world() -> void:
	var w := _world()
	if w == null:
		return
	if not w.changed.is_connected(_on_building_changed):
		w.changed.connect(_on_building_changed)
	if not w.child_entered_tree.is_connected(_on_piece_added):
		w.child_entered_tree.connect(_on_piece_added)


func _on_building_changed() -> void:
	_rechar = not _burns.is_empty()


func _on_piece_added(c: Node) -> void:
	if c is BuiltPiece:
		_added.append(c)


func _detail() -> bool:
	var w := _world()
	return w.detail if w else true


## What a burning `b` looks like: its meshes, stakes and door leaves, and what is on it of wood and stuff (a woodpile's
## logs, a smokehouse's racks and meat, a chest's lid, the boat on its stand); not the weapons in a rack, the baby, a
## torch, a label or the particles.
func _geoms(b: Burn) -> Array:
	var out: Array = []
	if b.piece and is_instance_valid(b.piece):
		out = b.piece.highlight_targets()
	if not is_instance_valid(b.node):
		return out
	for c in b.node.find_children("*", "GeometryInstance3D", true, false):
		if c in out or c is GPUParticles3D or c is CPUParticles3D or c is Label3D or c is SpriteBase3D:
			continue
		if not _kept_from_fire(c, b.node):
			out.append(c)
	return out


## Whether `c` (under `root`) is something the fire's look leaves as it is: a weapon in a rack, a thrown thing, a torch,
## the baby.
static func _kept_from_fire(c: Node, root: Node) -> bool:
	var n := c
	while n != null and n != root:
		if n is PlacedWeapon or n is ThrownPickup or n is DroppedTorch or n is BabyModel or n is FireFx:
			return true
		n = n.get_parent()
	return false


## A burnable's box (world AABB; kept: pieces do not move): its meshes and its colliders.
func _box_of(n: Node3D) -> AABB:
	var id := n.get_instance_id()
	if _boxes.has(id):
		return _boxes[id]
	var box := AABB()
	var any := false
	var gis: Array = (n as BuiltPiece).highlight_targets() if n is BuiltPiece else n.find_children("*", "GeometryInstance3D", true, false)
	for g in gis:
		var gi := g as GeometryInstance3D
		if gi == null or gi is GPUParticles3D or gi is CPUParticles3D:
			continue
		var bb := gi.global_transform * gi.get_aabb()
		if bb.size.length() < 0.01:
			continue
		box = bb if not any else box.merge(bb)
		any = true
	for c in n.find_children("*", "CollisionShape3D", true, false):
		var cs := c as CollisionShape3D
		var bb := _shape_box(cs)
		if bb.size.length() < 0.01:
			continue
		box = bb if not any else box.merge(bb)
		any = true
	if not any:
		box = AABB(n.global_position - Vector3(1.0, 0.0, 1.0), Vector3(2.0, 2.5, 2.0))
	_boxes[id] = box
	if _boxes.size() > 4000:
		_boxes.clear()
	return box


static func _shape_box(cs: CollisionShape3D) -> AABB:
	var s := cs.shape
	var local := AABB()
	if s is BoxShape3D:
		var e := (s as BoxShape3D).size
		local = AABB(-e * 0.5, e)
	elif s is CylinderShape3D:
		var cy := s as CylinderShape3D
		local = AABB(Vector3(-cy.radius, -cy.height * 0.5, -cy.radius), Vector3(cy.radius * 2.0, cy.height, cy.radius * 2.0))
	elif s is CapsuleShape3D:
		var ca := s as CapsuleShape3D
		local = AABB(Vector3(-ca.radius, -ca.height * 0.5, -ca.radius), Vector3(ca.radius * 2.0, ca.height, ca.radius * 2.0))
	elif s is SphereShape3D:
		var r := (s as SphereShape3D).radius
		local = AABB(-Vector3.ONE * r, Vector3.ONE * r * 2.0)
	elif s is ConvexPolygonShape3D:
		var pts := (s as ConvexPolygonShape3D).points
		if pts.is_empty():
			return AABB()
		local = AABB(pts[0], Vector3.ZERO)
		for p in pts:
			local = local.expand(p)
	else:
		return AABB()
	return cs.global_transform * local


## The point of `box` nearest `p`.
static func _closest(box: AABB, p: Vector3) -> Vector3:
	return p.clamp(box.position, box.end)


func _camera_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		return cam.global_position
	var p := _player()
	return p.global_position if p else Vector3.ZERO


func _player() -> FrontierPlayer:
	var scene := get_tree().current_scene if is_inside_tree() else null
	return scene.get_node_or_null("Player") as FrontierPlayer if scene else null


func _path_of(n: Node) -> String:
	var scene := get_tree().current_scene
	return String(scene.get_path_to(n)) if scene else String(n.get_path())


func _node_at(path: String) -> Node3D:
	var scene := get_tree().current_scene
	return scene.get_node_or_null(NodePath(path)) as Node3D if scene and path != "" else null


## The level is still there (not being taken down: a scene change frees every piece too).
func _level_live() -> bool:
	if not is_inside_tree():
		return false
	var scene := get_tree().current_scene
	return scene != null and (scene == self or scene.is_ancestor_of(self))
