class_name BirdLife
extends Node3D
## The woods' birds beyond the ambience's calls (user 2026-09-26: "add in fireflys and Owls and birds in the game to make
## it more legit"; the calls are AmbienceBed's, from the recordings of birds_rec.py):
##   owls    at night OWLS_AT_NIGHT great horned owls perched in the level's trees OWL_RING from the player (Owl:
##           yellow eyes shining in the dark; they watch the player, hoot, and vanish when he comes close, shoots or
##           stares, to turn up later on another tree, now and then hooting from behind him first); one far off is
##           moved to a tree nearer; at dawn they are gone. Barred owls are only heard (AmbienceBed).
##   flocks  by day a flock of small birds crosses the sky every FLOCK_EVERY s (BirdFlock); a gunshot sends one up from
##           the tree line (flush(), from AmbienceBed.scare and the weapons' shots)
## Fireflies are Fireflies'. Off with the user arg birdlife=off; tool and test scripts (-s) run without it unless they
## pass birdlife=on.
##
##   var b := BirdLife.new(); b.name = "BirdLife"; b.setup(player, vegetation, environment_rig); add_child(b)

const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")
const OWLS_AT_NIGHT := 3
const OWL_RING := Vector2(35.0, 140.0)
const OWL_FAR := 230.0
const NIGHT_SUN := -6.0
const FLOCK_EVERY := Vector2(70.0, 190.0)
const LOUD := ["musket", "over_under", "pistol"]

var player: FrontierPlayer
var vegetation: FrontierVegetation
var environment_rig: EnvironmentRig
var rng := RandomNumberGenerator.new()
var now := 0.0
var last_shot_time := -1e9
var last_shot_pos := Vector3.ZERO
## [id, time] of every call played (tests).
var sound_log: Array = []
## The sun's height to use instead of the clock's (tests; INF = the clock). Headless runs have no clock (DayNight).
var sun_override := INF

## The trunk of the last perch perch_near() found.
var last_trunk := Vector3.ZERO
var _owl_t := 0.0
var _flock_in := 25.0
var _serial := 0


static func enabled() -> bool:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("birdlife="):
			var v := s.get_slice("=", 1)
			return v != "off" and v != "0"
	var args := OS.get_cmdline_args()
	return not ("-s" in args or "--script" in args)


func setup(p: FrontierPlayer, veg: FrontierVegetation, rig: EnvironmentRig) -> void:
	player = p
	vegetation = veg
	environment_rig = rig
	rng.seed = 1766


func _ready() -> void:
	add_to_group(&"birdlife")
	_hook_weapons.call_deferred()


func sun_elevation() -> float:
	if sun_override != INF:
		return sun_override
	if environment_rig and environment_rig.clock_driver and environment_rig.clock_driver.clock:
		return environment_rig.clock_driver.clock.sun_elevation_deg()
	return WorldClock.DEFAULT_SUN_ELEVATION_DEG


func is_night() -> bool:
	return sun_elevation() < NIGHT_SUN


func _process(dt: float) -> void:
	now += dt
	_owl_t -= dt
	if _owl_t <= 0.0:
		_owl_t = 2.0
		_owls()
	if not is_night() and sun_elevation() > 0.0:
		_flock_in -= dt
		if _flock_in <= 0.0:
			_flock_in = rng.randf_range(FLOCK_EVERY.x, FLOCK_EVERY.y)
			_crossing_flock()


# --- Owls ----------------------------------------------------------------------------------------

func owls() -> Array[Owl]:
	var out: Array[Owl] = []
	for n in get_tree().get_nodes_in_group(&"owls"):
		if n is Owl and is_instance_valid(n):
			out.append(n)
	return out


func _owls() -> void:
	if player == null:
		return
	var list := owls()
	if not is_night():
		# dawn: they are gone
		for o in list:
			o.queue_free()
		return
	var pp := player.global_position
	for o in list:
		var back := o.mode == Owl.Mode.GONE and now >= o.gone_until
		if back or (o.mode == Owl.Mode.PERCH and o.global_position.distance_to(pp) > OWL_FAR):
			var np := perch_near(pp, OWL_RING.x, OWL_RING.y)
			if np != Vector3.INF:
				o.reappear(np, last_trunk)
	while list.size() < OWLS_AT_NIGHT:
		var at := perch_near(pp, OWL_RING.x, OWL_RING.y)
		if at == Vector3.INF:
			break
		var o := Owl.new()
		_serial += 1
		o.name = "Owl_%d" % _serial
		o.setup(self, "horned", at, 1766 + _serial * 13, last_trunk)
		add_child(o)
		list.append(o)


## A perch on one of the level's big trees min_d..max_d from pos: on a low limb at the crown's foot, just off the trunk.
func perch_near(pos: Vector3, min_d: float, max_d: float) -> Vector3:
	if vegetation == null or vegetation.layout == null:
		return Vector3.INF
	var lay = vegetation.layout
	var n: int = lay.tree_pos.size()
	if n == 0:
		return Vector3.INF
	for i in 60:
		var k := rng.randi() % n
		if int(lay.tree_kind[k]) >= Assets.SAPLING_PINE:
			continue
		var base: Vector3 = lay.tree_pos[k]
		var d := Vector2(base.x - pos.x, base.z - pos.z).length()
		if d < min_d or d > max_d:
			continue
		var info := Assets.tree(int(lay.tree_kind[k]), int(lay.tree_variant[k]))
		var sc: float = lay.tree_scale[k]
		var a := rng.randf() * TAU
		var out := float(info.get("trunk_radius", 0.3)) * sc + 0.3
		var h := float(info.get("crown_bottom", 5.0)) * sc * rng.randf_range(0.75, 0.95)
		last_trunk = base
		return base + Vector3(cos(a) * out, maxf(h, 3.0), sin(a) * out)
	return Vector3.INF


## An owl hoots; another near by may answer (great horned owls hoot in duets).
func call_from(o: Owl) -> void:
	_sound(Owl.CALLS[o.kind], o.global_position)
	o.hoot()
	if rng.randf() < 0.5:
		for other in owls():
			if other != o and other.mode == Owl.Mode.PERCH and other.global_position.distance_to(o.global_position) < 260.0:
				var who := other
				get_tree().create_timer(rng.randf_range(2.5, 5.5)).timeout.connect(func() -> void:
					if is_instance_valid(who):
						_sound(Owl.CALLS[who.kind], who.global_position)
						who.hoot()
						who.call_in = rng.randf_range(30.0, 70.0))
				break


## An owl just vanished: now and then it hoots a few seconds later from somewhere behind the player.
func owl_vanished(o: Owl) -> void:
	if player == null or rng.randf() > 0.4:
		return
	get_tree().create_timer(rng.randf_range(4.0, 9.0)).timeout.connect(func() -> void:
		if player == null or not is_instance_valid(player):
			return
		var cam := player.get_viewport().get_camera_3d()
		var back := cam.global_basis.z if cam else Vector3.BACK
		back.y = 0.0
		var at := player.global_position + back.normalized().rotated(Vector3.UP, rng.randf_range(-0.6, 0.6)) * rng.randf_range(20.0, 40.0)
		_sound(Owl.CALLS["horned"], at + Vector3.UP * 8.0))


func shot_near(pos: Vector3, r: float) -> bool:
	return now - last_shot_time < 3.0 and last_shot_pos.distance_to(pos) < r


# --- Flocks --------------------------------------------------------------------------------------

func _crossing_flock() -> void:
	if player == null:
		return
	var pp := player.global_position
	var a := rng.randf() * TAU
	var side := Vector3(cos(a), 0.0, sin(a))
	var across := side.cross(Vector3.UP)
	var off := rng.randf_range(-50.0, 50.0)
	var h := FrontierTerrain.height_at(pp.x, pp.z) + rng.randf_range(28.0, 55.0)
	var from := pp - side * 170.0 + across * off
	var to := pp + side * 170.0 + across * (off + rng.randf_range(-40.0, 40.0))
	from.y = h
	to.y = h + rng.randf_range(-6.0, 6.0)
	_spawn_flock(from, to, rng.randi_range(12, 32), false)


## A shot: a flock bursts up from the tree line 25-45 m away and flies off.
func flush() -> void:
	if player == null or rng.randf() > 0.7:
		return
	var pp := player.global_position
	var a := rng.randf() * TAU
	var at := pp + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(25.0, 45.0)
	at.y = FrontierTerrain.height_at(at.x, at.z) + rng.randf_range(8.0, 13.0)
	var away := Vector3(cos(a), 0.0, sin(a)) * 150.0 + Vector3(rng.randf_range(-40, 40), 25.0, rng.randf_range(-40, 40))
	_spawn_flock(at, at + away, rng.randi_range(10, 24), true)


func _spawn_flock(from: Vector3, to: Vector3, count: int, is_flush: bool) -> void:
	var f := BirdFlock.new()
	_serial += 1
	f.name = "Flock_%d" % _serial
	f.setup(from, to, count, 1766 + _serial * 7, is_flush)
	f.speed = 13.0 if is_flush else 11.0
	add_child(f)


func _hook_weapons() -> void:
	if player == null:
		return
	for key: String in player.weapons:
		var w: Weapon = player.weapons[key]
		if w and not w.fired.is_connected(_on_fired):
			w.fired.connect(_on_fired.bind(key))


func _on_fired(key: String) -> void:
	last_shot_time = now
	last_shot_pos = player.global_position
	if key in LOUD:
		flush()


func _sound(id: StringName, pos: Vector3) -> void:
	sound_log.append([String(id), now])
	if sound_log.size() > 200:
		sound_log.pop_front()
	if Sfx.has(id):
		Sfx.play_3d(id, pos)
