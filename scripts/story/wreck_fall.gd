class_name WreckFall
extends Node3D
## The second fire (docs/main_story.md mission 11, Two Fires): a burning sky galleon streaks across the night and comes
## down in the pines, and lies there broken and burning: the wreck the player reaches, where Captain Ithel is dying, a
## stranger (Rook) is pinned under a spar, and the keel's cracked stone glows.
##   var wf := WreckFall.begin(level, at)          # the fall at `at` (on the ground there), then the wreck: `landed`
##   WreckFall.begin_from(level, at, ship, opts)   # the fall from a ship already up there (SkyBattle's cutter), not the streak
##   WreckFall.place_wreck(level, at)              # a save loaded after the fall: the wreck as it lies, no streak
##   wf.spar() / wf.ithel() / wf.rook()            # the loose yard (RigidBody3D), the captain, the stranger (NpcBody)
##   wf.lift_spar()                                # the first lock's effect: the spar thrown off, the stranger crawls free
## Both take an optional `heading` (radians: the bow's yaw, the way it was going: forward = (-sin, 0, -cos)), default
## DEFAULT_HEADING (out of the north, where the lanes come down under the Wheel: docs 7.2); the same `at` and heading
## give the same wreck, trees cleared and spar on the same man (a save keeps `at` and `heading`).
## STORY EFFECTS can call it by name: {"do": ...} matches begin(level, at) by parameter names.
##
## THE FALL (FALL_S): the intact model (assets/sky/sky_galleon.glb) from START_BACK m behind `at` and START_UP m up, along a
## curve that starts shallow and ends steep (a quadratic Bezier), quickening, bow along its course, rolling to port as it
## comes; burning (a FireFx on it, its flames made big), a fire trail and a smoke trail (GPU particles in world space, so
## they stay behind it), a soft glow round it, the roar of its fire (the torch's crackle, deep), a rush as it comes low.
## LANDING: the intact ship swaps for the wreck (assets/sky/sky_galleon_wreck.glb, tools/models/sky_galleon_wreck.py) laid on
## the ground there: on the plane fitted to the terrain under its footprint (tilted at most MAX_TILT_DEG), its bow along
## the heading; the trees, saplings and rocks in its footprint and under its fallen tops go (VegHarvest), those in the swath
## behind it are snapped (tall stumps: FelledTree.make_stump); a crash (the felling sounds, deep, and a far boom), dust, a
## flash of the light; colliders (convex hulls of its two hull parts, capsules for the fallen tops and the keelstone).
## THE WRECK: burning (one FireFx over each Burn_* part's box, the timber ones charred with live embers, FireRuin's look;
## one smoke column), holding for BURN_HOLD_S and dying down over BURN_FADE_S to SMOULDER; the keelstone glowing (its
## EtheriumGlow breathing, brighter in the dark) with a thin gold smoke off its crack; ONE light for all of it (the fall's,
## then at KEEL_LIGHT_UP over the KeelGlow empty, no shadow, flickering with the fire): the one shared light of the budget.
## The spar: a RigidBody3D frozen across the stranger's thighs (one end on the ground), in group SWAY_TARGETS with meta
## sway_move = "first_lock" (and "sway_cast": lift_spar, "pins": the stranger). The stranger is Rook: an NpcBody lying on his
## back (the first frame of the get-up from the back), resting (nothing runs), none of his meshes casting a shadow (he has
## none under our sun: docs 9.2). Captain Ithel: an NpcBody sat against the hull bottom, leaned back along it (the Ithel
## empty's frame), slow in the floor-sit loop, with a StoryContact on him ("Captain Ithel", convo ITHEL_CONVO; its lantern
## hidden: the keel's is the light).
## Cheap: one light, ~6 small fires and a column (GPU particles), the wreck ~33k triangles (its fans' WingSails and the
## crystal cast no shadow; everything past VIS_END m hidden: the column and the light's glow say where it is), the two
## bodies' clips (Rook's not at all). Seen from afar (past FAR_GLOW_M.x, full past .y) its fire's glow on the smoke over
## the treetops (one billboard FAR_GLOW_UP m over it, sized for the eye, wide and low, the trees in front of its lower
## half): the camp sees where it burns. Nothing here is saved: the story keeps `at` (and heading) and calls place_wreck.

signal landed
signal spar_lifted
signal stranger_freed

enum Phase { IDLE, FALLING, LANDED }

const GROUP := &"wreck_fall"
const SHIP_MODEL := "res://assets/sky/sky_galleon.glb"
const WRECK_MODEL := "res://assets/sky/sky_galleon_wreck.glb"
const SWAY_TARGETS := &"sway_targets"
const SWAY_MOVE := "first_lock"
const ITHEL_CONVO := "two_fires/ithel"
const ITHEL_NAME := "Captain Ithel"
## The two men's clips (Actor_B's), in a small library of their own on each body ("wreck/<key>").
const CLIP_LIB := "wreck"
const CLIP_SIT := "actor_b-cap-casual-sit-floor-loop"
const CLIP_PINNED := "actor_b-ground-recover-back"
## Looks: [peoples preset, the costume they wear (data/story/costumes.json, StoryWalker.person_look): Ithel the Drift set's
## sea officer's dress, Rook his Act 2 sailor's dress, the one RookWalk's Rook wears] (no Native presets: usable_preset).
const ROOK_LOOK := ["palatine_m_b", "rook"]
const ITHEL_LOOK := ["english_m_a", "ithel"]
const DEFAULT_HEADING := PI - 0.4
## The fall: seconds, where it starts (m back along the heading and up), the curve's middle point, where it ends (m up).
const FALL_S := 11.0
const START_BACK := 1700.0
const START_UP := 560.0
const MID_BACK := 520.0
const MID_UP := 470.0
const IMPACT_UP := 2.5
const ROLL_DEG := 25.0
## begin_from: its fall's seconds by default, and how steeply it goes into the ground (degrees below level).
const FALL_FROM_S := 9.0
const FROM_DIVE_DEG := 38.0
const FROM_DIVE_MAX := 62.0
const SHIP_LOD_M := 450.0
const FALL_FLAME_SCALE := 3.0
## The ground fit (wreck frame samples, m) and its limit.
const FIT_X := [-5.0, 0.0, 5.0]
const FIT_Z := [-14.0, -7.0, 0.0, 7.0, 14.0]
const MAX_TILT_DEG := 12.0
## The hull's footprint (wreck frame x, z) and the fallen tops' reach: trees, saplings and rocks there go.
const FOOTPRINT := Rect2(-7.5, -18.0, 17.0, 35.0)
const FALLEN_CLEAR_R := 5.5
## The swath it ploughed through behind its stern (wreck frame): trees there are snapped, standing SNAP_H m.
const SWATH := Rect2(-6.0, 17.0, 12.0, 55.0)
const SNAP_H := Vector2(1.2, 3.6)
## The one light.
const KEEL_LIGHT_UP := 1.2
const KEEL_LIGHT_COLOR := Color(1.0, 0.6, 0.26)
const KEEL_LIGHT_ENERGY := 3.2
const KEEL_LIGHT_RANGE := 26.0
const FALL_LIGHT_ENERGY := 8.0
const FALL_LIGHT_RANGE := 160.0
## The fires: a Burn_* part's box past this (m a side) is cut down to it round its middle; how long they hold, fade, and
## what they smoulder at; the timber parts that char.
const FIRE_MAX_BOX := 7.0
const BURN_HOLD_S := 900.0
const BURN_FADE_S := 600.0
const SMOULDER := 0.3
const TIMBER_BURNS := ["Burn_BreakFore", "Burn_BreakAft", "Burn_Debris"]
const NO_SHADOW := ["WingSails", "Keelstone", "Furrow"]
const VIS_END := 700.0
const KEEL_YAW_DEG := 18.0          ## the crystal lies this far round from the wreck's z (tools/models/sky_galleon_wreck.py)
const SPAR_MASS := 80.0
const SPAR_R := 0.17
const SPAR_LEN := 6.0
const TICK_S := 0.5
## The fire's glow seen from afar: this high (m) over the wreck, faded in from .x to .y m off, its size x the distance.
const FAR_GLOW_UP := 36.0
const FAR_GLOW_M := Vector2(90.0, 180.0)
const FAR_GLOW_SIZE := 0.2

## The fall's clock x this (tests).
var speed := 1.0
## Seconds the fall takes (begin_from's opts.fall_s; FALL_S for the streak).
var fall_s := FALL_S
var at := Vector3.ZERO
var heading := DEFAULT_HEADING
var phase := Phase.IDLE
var quality := "medium"
## The wreck's frame: on the ground at `at`, its bow (-Z) along the heading.
var frame := Transform3D.IDENTITY
## The wreck model (the glb's root) once it is down; the intact ship while it falls.
var wreck: Node3D
var ship: Node3D
var contact: StoryContact
var fires: Array[FireFx] = []
var column: GPUParticles3D
## The one light (the fall's, then the keel's).
var light: OmniLight3D
## What the landing cleared: trees, snapped (stumps), saplings, rocks.
var cleared := {"trees": 0, "snapped": 0, "saplings": 0, "rocks": 0}
## 0..1: how hard the wreck burns now (its fires' strength).
var burn := 0.0

var _t := 0.0
var _p0 := Vector3.ZERO
var _p1 := Vector3.ZERO
var _p2 := Vector3.ZERO
var _spar: RigidBody3D
var _ithel: NpcBody
var _rook: NpcBody
var _ship_fire: FireFx
var _fire_trail: GPUParticles3D
var _smoke_trail: GPUParticles3D
var _glow: MeshInstance3D
var _glow_mat: StandardMaterial3D
var _trail_mat: StandardMaterial3D
var _roar: AudioStreamPlayer3D
var _rushed := false
var _tick := 0.0
var _lod_t := 0.0
## The falling ship's meshes, listed once: its far one (Galleon_LOD1) and the near ones; which shows (-1: not yet set).
var _lod_far_m: Array[MeshInstance3D] = []
var _lod_near_m: Array[MeshInstance3D] = []
var _lod_is := -1
## The two in the wreck (Rook, Ithel) built ahead, hidden and idle (begin_from's opts people: SkyBattle builds them as
## its ships come in; else while it falls, at PREBUILD_AT of the fall, one in a frame), and taken by _body as it lands,
## so the landing's frame does not build them (20-45 ms each).
var _pre := {}
const PREBUILD_AT := {"Rook": 0.35, "Ithel": 0.55}
const PEOPLE := ["Rook", "Ithel"]
var _burn_t := 0.0
var _burn_start := 1.0
var _flash := 0.0
var _keel_smoke: GPUParticles3D
var _glow_mats: Array[StandardMaterial3D] = []
var _far_glow: MeshInstance3D
var _far_mat: StandardMaterial3D
var _noise := FastNoiseLite.new()
var _clock := 0.0
var _freed := false
## begin_from: the ship (Node3D) or its transform (Transform3D) the fall starts from; the curve is then a cubic
## (_p0.._p3: from the ship along its bow, into the ground along the heading), eased from its speed (_ease_a), its roll
## at the start (_roll0) easing into the fall's own.
var _from: Variant = null
var _cubic := false
var _p3 := Vector3.ZERO
var _ease_a := 0.0
var _roll0 := 0.0


# --- The API ----------------------------------------------------------------------------------------------------

## The fall at `at` (on the ground there) under `level`: the burning ship streaks down and the wreck lies there after
## (`landed`). One wreck at a time: one there already is taken away.
static func begin(level: Node, at: Vector3, heading := NAN) -> WreckFall:
	var wf := _make(level, at, heading)
	if wf != null:
		wf._start_fall()
	return wf


## The fall from a ship already in the sky (SkyBattle's cutter, hit): `from` is the intact ship (sky_galleon.glb's root,
## taken over: moved under the WreckFall, where it is kept) or a Transform3D (a new ship there). It comes down on a curve
## from where it is, at first along its bow (never climbing), into the ground at `at` along the heading, quickening
## from opts.speed; burning, trailing and lit as begin()'s; then the wreck (`landed`). opts: heading (radians, as
## begin's), fall_s (seconds, default FALL_FROM_S), speed (m/s along its bow at the start), roll (radians: its roll then,
## eased into the fall's own), people ({name: NpcBody}: Rook and Ithel built ahead, prebuild_body's; taken over).
static func begin_from(level: Node, at: Vector3, from: Variant, opts := {}) -> WreckFall:
	var wf := _make(level, at, float(opts.get("heading", NAN)))
	if wf != null:
		var ppl: Variant = opts.get("people", {})
		if ppl is Dictionary:
			for nm: String in ppl:
				var b: Variant = ppl[nm]
				if b is NpcBody and is_instance_valid(b):
					(b as NpcBody).reparent(wf, true)
					wf._pre[nm] = b
		wf._from = from if (from is Transform3D or (from is Node3D and is_instance_valid(from))) else null
		wf.fall_s = maxf(float(opts.get("fall_s", FALL_FROM_S)), 1.0)
		wf._roll0 = float(opts.get("roll", 0.0))
		wf._ease_a = float(opts.get("speed", 0.0))     # (m/s here: _start_fall makes it the ease's start)
		wf._start_fall()
	return wf


## The wreck as it lies at `at` (a save loaded after the fall): no streak, no crash; burning at `burning` (0..1: 0 cold).
## `landed` is sent before this returns (is_landed() is true).
static func place_wreck(level: Node, at: Vector3, heading := NAN, burning := 1.0) -> WreckFall:
	var wf := _make(level, at, heading)
	if wf != null:
		wf._land(false, burning)
	return wf


static func find(tree: SceneTree) -> WreckFall:
	return tree.get_first_node_in_group(GROUP) as WreckFall if tree else null


## A heading for a fall seen from `viewer`: it crosses their sky from their left, coming in at ~70 deg to their line of
## sight to `at`.
static func heading_seen_from(viewer: Vector3, at: Vector3) -> float:
	var look := Vector3(at.x - viewer.x, 0.0, at.z - viewer.z)
	if look.length() < 1.0:
		return DEFAULT_HEADING
	var go := look.normalized().rotated(Vector3.UP, deg_to_rad(-70.0))
	return atan2(-go.x, -go.z)


## The loose yard pinning the stranger: a RigidBody3D (frozen until lift_spar), in SWAY_TARGETS.
func spar() -> RigidBody3D:
	return _spar


## Captain Ithel, sat dying against the hull (an NpcBody; `contact` is his StoryContact).
func ithel() -> NpcBody:
	return _ithel


## Rook, the stranger under the spar (an NpcBody casting no shadow).
func rook() -> NpcBody:
	return _rook


func is_landed() -> bool:
	return phase == Phase.LANDED


## The keel crystal's centre (the KeelGlow empty), world.
func keel_point() -> Vector3:
	var n := _wreck_node("KeelGlow")
	return n.global_position if n else frame.origin


## The first lock's effect: the spar unfrozen and thrown up and off the stranger (`push`: the way, world; ZERO: out
## from the hull), then he crawls free (`stranger_freed` once he is up). Again does nothing.
func lift_spar(push := Vector3.ZERO) -> void:
	if _spar == null or not _spar.freeze:
		return
	_spar.freeze = false
	var out := push if push != Vector3.ZERO else frame.basis.x
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.RIGHT
	_spar.apply_central_impulse((Vector3.UP * 4.5 + out * 1.8) * SPAR_MASS)
	_spar.apply_torque_impulse(_spar.global_basis.z * 0.4 * SPAR_MASS)
	spar_lifted.emit()
	get_tree().create_timer(0.6).timeout.connect(_free_stranger)


## The first lock landed by the Sway on the spar (SwayCaster's cast: SwayEffects lifts it and lets it fall itself): the
## stranger crawls free as after lift_spar. Again does nothing.
func spar_cast() -> void:
	if _spar == null or _freed or _spar.has_meta(&"cast"):
		return
	_spar.set_meta(&"cast", true)
	spar_lifted.emit()
	get_tree().create_timer(0.6).timeout.connect(_free_stranger)


## The fall over now (a skipped scene): the wreck lies there at once.
func skip() -> void:
	if phase == Phase.FALLING:
		_impact()


# --- Making it ----------------------------------------------------------------------------------------------------

static func _make(level: Node, p_at: Vector3, p_heading: float) -> WreckFall:
	if level == null or not level.is_inside_tree():
		push_warning("WreckFall: no level")
		return null
	var old := find(level.get_tree())
	if old != null:
		old.remove_from_group(GROUP)
		old.queue_free()
	var wf := WreckFall.new()
	wf.name = "WreckFall"
	wf.at = p_at
	wf.heading = p_heading if not is_nan(p_heading) else DEFAULT_HEADING
	var s: Variant = level.get("settings")
	if s is WorldSettings:
		wf.quality = (s as WorldSettings).quality
	level.add_child(wf)
	return wf


func _ready() -> void:
	add_to_group(GROUP)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = 1757
	frame = ground_frame(at, heading)


## The wreck's frame at `p` for `yaw`: on the plane fitted to the terrain under its footprint (FIT_X x FIT_Z samples,
## least squares), tilted at most MAX_TILT_DEG, its -Z along the yaw.
static func ground_frame(p: Vector3, yaw: float) -> Transform3D:
	var flat := Basis(Vector3.UP, yaw)
	# y = a + b x + c z over the samples (wreck-frame x, z)
	var n := 0.0
	var sx := 0.0
	var sz := 0.0
	var sy := 0.0
	var sxx := 0.0
	var szz := 0.0
	var sxy := 0.0
	var szy := 0.0
	for x: float in FIT_X:
		for z: float in FIT_Z:
			var w := p + flat * Vector3(x, 0.0, z)
			var y := FrontierTerrain.height_at(w.x, w.z)
			n += 1.0
			sx += x
			sz += z
			sy += y
			sxx += x * x
			szz += z * z
			sxy += x * y
			szy += z * y
	# (the sample grid is symmetric: x and z are uncorrelated and centred)
	var a := sy / n
	var b := (sxy - sx * sy / n) / maxf(sxx - sx * sx / n, 0.001)
	var c := (szy - sz * sy / n) / maxf(szz - sz * sz / n, 0.001)
	var up := (flat * Vector3(-b, 1.0, -c)).normalized()
	var tilt := up.angle_to(Vector3.UP)
	var lim := deg_to_rad(MAX_TILT_DEG)
	if tilt > lim:
		var axis := Vector3.UP.cross(up).normalized()
		up = Vector3.UP.rotated(axis, lim)
	var back := flat.z
	back = (back - up * back.dot(up)).normalized()
	var right := up.cross(back).normalized()
	return Transform3D(Basis(right, up, right.cross(up).normalized()), Vector3(p.x, a, p.z))


func _start_fall() -> void:
	var taken: Node3D = _from if _from is Node3D else null
	var scene := load(SHIP_MODEL) as PackedScene if ResourceLoader.exists(SHIP_MODEL) else null
	if scene == null and taken == null:
		push_warning("WreckFall: no %s; the wreck is placed without its fall" % SHIP_MODEL)
		_land(false, 1.0)
		return
	phase = Phase.FALLING
	_t = 0.0
	var fwd := -frame.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var g := frame.origin
	_p0 = g - fwd * START_BACK + Vector3.UP * START_UP
	_p1 = g - fwd * MID_BACK + Vector3.UP * MID_UP
	_p2 = g + Vector3.UP * IMPACT_UP
	if _from != null:
		var xf: Transform3D = taken.global_transform if taken else _from
		_from_curve(xf, g, fwd)
	if taken != null:
		ship = taken
		if ship.get_parent() != null:
			ship.reparent(self)                   # (its transform kept)
		else:
			add_child(ship)
	else:
		ship = scene.instantiate() as Node3D
		add_child(ship)
	ship.name = "FallingShip"
	_pose_ship(0.0)
	_lod_far_m.clear()
	_lod_near_m.clear()
	_lod_is = -1
	for c in ship.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if c is MeshInstance3D:
			(_lod_far_m if c.name.begins_with("Galleon_LOD1") else _lod_near_m).append(c as MeshInstance3D)
	_ship_lod(INF)
	# its fire: flames all along the hull, made big (it is seen from far off)
	var box := AABB(ship.global_position - Vector3(4.0, 0.0, 13.0), Vector3(8.0, 8.0, 26.0))
	_ship_fire = FireFx.make(ship, box, quality)
	var fpm := _ship_fire.flames.process_material as ParticleProcessMaterial
	fpm.scale_min *= FALL_FLAME_SCALE
	fpm.scale_max *= FALL_FLAME_SCALE
	fpm.initial_velocity_max *= 2.0
	_ship_fire.strength = 1.0
	for p in _ship_fire.find_children("*", "GPUParticles3D", true, false):
		(p as GPUParticles3D).visibility_aabb = AABB(Vector3(-400, -400, -400), Vector3(800, 800, 800))
	_fire_trail = _trail(true)
	_smoke_trail = _trail(false)
	_glow = _make_glow()
	ship.add_child(_glow)
	light = _make_light()
	ship.add_child(light)
	light.position = Vector3(0.0, 4.0, 0.0)
	light.light_energy = FALL_LIGHT_ENERGY
	light.omni_range = FALL_LIGHT_RANGE
	if Sfx.has(TorchFire.CRACKLE):
		_roar = Sfx.make_player_3d(TorchFire.CRACKLE, ship)
		if _roar:
			_roar.name = "Roar"
			_roar.pitch_scale = 0.38
			_roar.unit_size = 80.0
			_roar.max_distance = 4000.0
			_roar.volume_db += 14.0
			_roar.play()


func _process(delta: float) -> void:
	_clock += delta
	match phase:
		Phase.FALLING:
			_t += delta * speed
			var tau := _t / fall_s
			if tau >= 1.0:
				_impact()
			else:
				_pose_ship(tau)
				_fall_frame(delta, tau)
				_prebuild(tau)
		Phase.LANDED:
			_wreck_frame(delta)


func _bez(s: float) -> Vector3:
	var u := 1.0 - s
	if _cubic:
		return _p0 * (u * u * u) + _p1 * (3.0 * u * u * s) + _p2 * (3.0 * u * s * s) + _p3 * (s * s * s)
	return _p0 * (u * u) + _p1 * (2.0 * u * s) + _p2 * (s * s)


func _bez_d(s: float) -> Vector3:
	if _cubic:
		var u := 1.0 - s
		return (_p1 - _p0) * (3.0 * u * u) + (_p2 - _p1) * (6.0 * u * s) + (_p3 - _p2) * (3.0 * s * s)
	return (_p1 - _p0) * (2.0 * (1.0 - s)) + (_p2 - _p1) * (2.0 * s)


## begin_from's curve (a cubic): from `xf` (the ship) along its bow (bent toward the place when it points away, never
## up), into the ground at `g` along the heading (`fwd`), diving FROM_DIVE_DEG down (steeper, to FROM_DIVE_MAX, when it
## falls from high up close by); no control point higher than the one before (so it only comes down), nor back over the
## ground. The ease s = a tau + (1 - a) tau^2 starts at the ship's speed (in _ease_a, m/s, until here).
func _from_curve(xf: Transform3D, g: Vector3, fwd: Vector3) -> void:
	_cubic = true
	_p0 = xf.origin
	_p3 = g + Vector3.UP * IMPACT_UP
	var to := _p3 - _p0
	var flat_to := Vector3(to.x, 0.0, to.z)
	flat_to = flat_to.normalized() if flat_to.length() > 1.0 else fwd
	var bow := -xf.basis.z.normalized()
	bow.y = minf(bow.y, 0.0)
	var bf := Vector3(bow.x, 0.0, bow.z)
	if bf.length() < 0.2 or bf.normalized().dot(flat_to) < 0.2:
		bow += flat_to * 1.5
	bow = bow.normalized()
	var hd := maxf(Vector2(to.x, to.z).length(), 20.0)
	var dive := clampf(atan2(maxf(-to.y, 0.0), hd) + deg_to_rad(6.0), deg_to_rad(FROM_DIVE_DEG), deg_to_rad(FROM_DIVE_MAX))
	var into := (fwd * cos(dive) - Vector3.UP * sin(dive)).normalized()
	_p1 = _p0 + bow * (hd * 0.35)
	_p2 = _p3 - into * minf(to.length() * 0.45, hd * 0.6 / cos(dive))   # (short of _p1 over the ground: no doubling back)
	_p1.y = minf(_p1.y, _p0.y)
	_p2.y = minf(_p2.y, _p1.y)
	_ease_a = clampf(_ease_a * fall_s / maxf(3.0 * _p0.distance_to(_p1), 1.0), 0.0, 1.0)


## The ship at `tau` (0..1) of its fall: quickening along the curve, bow along it, rolled to port as it comes.
func _pose_ship(tau: float) -> void:
	var c := clampf(tau, 0.0, 1.0)
	var s := (_ease_a * c + (1.0 - _ease_a) * c * c) if _cubic else pow(c, 1.35)
	var p := _bez(s)
	var d := _bez_d(s).normalized()
	var b := Basis.looking_at(d, Vector3.UP)
	var roll := deg_to_rad(ROLL_DEG) * smoothstep(0.25, 1.0, tau) + 0.05 * sin(_clock * 1.9)
	if _cubic:
		roll = lerpf(_roll0, deg_to_rad(ROLL_DEG), smoothstep(0.0, 1.0, tau)) + 0.05 * sin(_clock * 1.9)
	b = b * Basis(Vector3(0, 0, 1), roll)
	ship.global_transform = Transform3D(b, p)


## While it falls: its LOD, its glow's size for the eye, the trails' brightness, the rush as it comes low.
func _fall_frame(delta: float, tau: float) -> void:
	var cam := _camera_pos()
	var dist := cam.distance_to(ship.global_position)
	_lod_t -= delta
	if _lod_t <= 0.0:
		_lod_t = 0.25
		_ship_lod(dist)
		if _ship_fire:
			_ship_fire.set_wind(Vector3.ZERO)
	var dim := Fx._fire_dim(self)
	_glow.scale = Vector3.ONE * clampf(dist * 0.05, 12.0, 60.0)
	var gc := Color(1.0, 0.55, 0.22) * (1.3 * dim)
	_glow_mat.albedo_color = Color(gc.r, gc.g, gc.b, 0.8)
	_trail_mat.albedo_color = Color(1.6 * dim, 1.6 * dim, 1.6 * dim)
	FireFx.flame_material().set_shader_parameter(&"intensity", 2.0 * dim)
	light.light_energy = FALL_LIGHT_ENERGY * (0.85 + 0.15 * _noise.get_noise_1d(_clock * 8.0))
	if not _rushed and tau > 0.82:
		_rushed = true
		if Sfx.has(&"gather_rec_tree_fall"):
			Sfx.play_3d(&"gather_rec_tree_fall", ship.global_position, 12.0, 0.5)


## Near meshes in, the far one out, and the other way past SHIP_LOD_M (as SkyTraffic's; only when it changes).
func _ship_lod(dist: float) -> void:
	var far := 1 if dist > SHIP_LOD_M else 0
	if far == _lod_is:
		return
	_lod_is = far
	for m in _lod_far_m:
		if is_instance_valid(m):
			m.visible = far == 1
	for m in _lod_near_m:
		if is_instance_valid(m):
			m.visible = far == 0


## Rook and Ithel built ahead as the fall passes their PREBUILD_AT (one a frame), hidden and idle under the crash.
func _prebuild(tau: float) -> void:
	for nm: String in PREBUILD_AT:
		if not _pre.has(nm) and tau >= float(PREBUILD_AT[nm]):
			var b := _new_body(nm, ROOK_LOOK if nm == "Rook" else ITHEL_LOOK, Transform3D(frame.basis, frame.origin))
			b.visible = false
			b.rest()
			_pre[nm] = b
			return


## A trail behind the falling ship (fire: glowing puffs that burn out in a couple of seconds; smoke: big dark puffs that
## hang and spread); world-space particles off its hull.
func _trail(fire: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "FireTrail" if fire else "SmokeTrail"
	p.amount = int((90.0 if fire else 70.0) * (0.5 if quality == "low" else 1.0))
	p.lifetime = 2.5 if fire else 9.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	p.visibility_aabb = AABB(Vector3(-1500, -900, -1500), Vector3(3000, 1800, 3000))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 6.0 if fire else 5.0
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 6.0 if fire else 3.0
	pm.gravity = Vector3(0, 2.0, 0) if fire else Vector3(0, 0.4, 0)
	pm.damping_min = 0.5
	pm.damping_max = 1.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.scale_min = 6.0 if fire else 9.0
	pm.scale_max = 12.0 if fire else 16.0
	pm.scale_curve = FireFx._curve_tex([Vector2(0, 0.8), Vector2(0.2, 1.0), Vector2(1, 2.2)], 3.0) if fire \
			else FireFx._curve_tex([Vector2(0, 0.6), Vector2(1, 3.5)], 4.0)
	if fire:
		pm.color_ramp = FireFx._ramp_tex([[0.0, Color(1.0, 0.78, 0.4, 0.95)], [0.3, Color(1.0, 0.42, 0.1, 0.7)],
				[0.7, Color(0.3, 0.1, 0.04, 0.3)], [1.0, Color(0.0, 0.0, 0.0, 0.0)]])
	else:
		pm.color_ramp = FireFx._ramp_tex([[0.0, Color(0.12, 0.1, 0.09, 0.0)], [0.08, Color(0.1, 0.09, 0.08, 0.6)],
				[0.6, Color(0.2, 0.19, 0.18, 0.3)], [1.0, Color(0.25, 0.24, 0.23, 0.0)]])
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	if fire:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_texture = Fx._soft_dot()
		m.disable_fog = true
		_trail_mat = m
	else:
		m.albedo_texture = Fx._puff()
		m.roughness = 1.0
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	q.material = m
	p.draw_pass_1 = q
	ship.add_child(p)
	p.position = Vector3(0.0, 3.0, 4.0)
	return p


func _make_glow() -> MeshInstance3D:
	var g := MeshInstance3D.new()
	g.name = "Glow"
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	g.mesh = q
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glow_mat.billboard_keep_scale = true                # (sized for the eye: its scale is the glow's size)
	_glow_mat.disable_fog = true
	_glow_mat.disable_receive_shadows = true
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gr.add_point(0.3, Color(1, 1, 1, 0.4))
	var t := GradientTexture2D.new()
	t.gradient = gr
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_glow_mat.albedo_texture = t
	g.material_override = _glow_mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g


func _make_light() -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = "WreckLight"
	l.light_color = KEEL_LIGHT_COLOR
	l.omni_attenuation = 1.1
	l.light_specular = 0.3
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 400.0
	l.distance_fade_length = 100.0
	return l


## The fall is over: the intact ship goes (its trails left to burn out where they are), the wreck lies there.
func _impact() -> void:
	_retire_ship()
	_land(true, 1.0)


func _retire_ship() -> void:
	if ship == null:
		return
	for p: GPUParticles3D in [_fire_trail, _smoke_trail]:
		if p != null and is_instance_valid(p):
			p.reparent(self)
			p.emitting = false
			get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)
	if _ship_fire != null and is_instance_valid(_ship_fire):
		_ship_fire.reparent(self)
		_ship_fire.die()
		get_tree().create_timer(FireFx.SMOKE_LIFE + 0.5).timeout.connect(_ship_fire.queue_free)
	if light != null and is_instance_valid(light):
		light.reparent(self)
	if _roar != null and is_instance_valid(_roar):
		_roar.stop()
	ship.queue_free()
	ship = null
	_ship_fire = null
	_fire_trail = null
	_smoke_trail = null


## The wreck down at `frame`: the model, the ground cleared, colliders, the spar and the stranger, Ithel, the fires and the
## keel's light; with `crash` the crash's sound, dust and flash. Sends `landed`.
func _land(crash: bool, burning: float) -> void:
	if phase == Phase.LANDED:
		return
	phase = Phase.LANDED
	var scene := BackgroundLoad.take(WRECK_MODEL) as PackedScene if ResourceLoader.exists(WRECK_MODEL) else null
	if scene == null:
		push_error("WreckFall: no %s" % WRECK_MODEL)
		landed.emit()
		return
	wreck = scene.instantiate() as Node3D
	wreck.name = "Wreck"
	add_child(wreck)
	wreck.global_transform = frame
	for c in wreck.find_children("*", "GeometryInstance3D", true, false):
		var gi := c as GeometryInstance3D
		gi.visibility_range_end = VIS_END
		if String(gi.name) in NO_SHADOW:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clear_ground()
	_colliders()
	_make_rook()
	_make_spar()
	_make_ithel()
	if light == null or not is_instance_valid(light):
		light = _make_light()
		add_child(light)
	light.global_position = keel_point() + Vector3.UP * KEEL_LIGHT_UP
	light.omni_range = KEEL_LIGHT_RANGE
	light.distance_fade_begin = 140.0
	light.distance_fade_length = 40.0
	_glow_materials()
	_make_fires(clampf(burning, 0.0, 1.0))
	_keel_smoke = _make_keel_smoke()
	if burning > 0.0:
		var keep := _glow_mat
		_far_glow = _make_glow()
		_far_mat = _glow_mat
		_glow_mat = keep
		# (a soft haze, no bright core: the fire's light on its smoke, not a moon rising)
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 0.55))
		gr.set_color(1, Color(1, 1, 1, 0))
		gr.add_point(0.45, Color(1, 1, 1, 0.22))
		(_far_mat.albedo_texture as GradientTexture2D).gradient = gr
		_far_glow.name = "FarGlow"
		add_child(_far_glow)
		_far_glow.global_position = frame.origin + Vector3.UP * FAR_GLOW_UP
		_far_glow.visible = false
	if crash:
		_crash()
	_tick = 0.0
	landed.emit()


func _wreck_node(nm: String) -> Node3D:
	return wreck.find_child(nm, true, false) as Node3D if wreck else null


## The trees, saplings and rocks in the hull's footprint and under the fallen tops go; the trees in the swath behind it are
## snapped (tall stumps). (VegHarvest: its instances hidden, its collider gone; not saved: place_wreck does it again.)
func _clear_ground() -> void:
	var h := VegHarvest.find(get_tree())
	if h == null:
		return
	var inv := frame.affine_inverse()
	var segs: Array = []
	for k: String in ["Fore", "Main"]:
		var a := _wreck_node("Fallen%s_A" % k)
		var b := _wreck_node("Fallen%s_B" % k)
		if a and b:
			segs.append([Vector2(a.position.x, a.position.z), Vector2(b.position.x, b.position.z)])
	var mid := frame * Vector3(0.0, 0.0, (FOOTPRINT.position.y + SWATH.end.y) * 0.5)
	var reach := (SWATH.end.y - FOOTPRINT.position.y) * 0.5 + 25.0
	var visuals := DisplayServer.get_name() != "headless"
	for d: Dictionary in h.near(mid, reach):
		var l := inv * (d.pos as Vector3)
		var q := Vector2(l.x, l.z)
		var under := FOOTPRINT.has_point(q)
		if not under:
			for s: Array in segs:
				if _seg_dist(q, s[0], s[1]) < FALLEN_CLEAR_R:
					under = true
					break
		var swath := not under and SWATH.has_point(q)
		if not under and not swath:
			continue
		match String(d.type):
			"tree":
				var td := h.remove_tree(int(d.i))
				if td.is_empty():
					continue
				if swath:
					var hh := lerpf(SNAP_H.x, SNAP_H.y, _hash(td.pos))
					h.stump_h[int(d.i)] = hh
					var st := FelledTree.make_stump(td, hh, visuals)
					st.name = "Snapped_%d" % int(d.i)
					add_child(st)
					cleared["snapped"] += 1
				else:
					cleared["trees"] += 1
			"sapling":
				if not h.remove_sapling(String(d.src), int(d.i)).is_empty():
					cleared["saplings"] += 1
			"rock":
				if under:
					h.shrink_rock(int(d.i), 0.0)
					cleared["rocks"] += 1


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _hash(p: Vector3) -> float:
	var x := sin(p.x * 12.9898 + p.z * 78.233) * 43758.5453
	return x - floorf(x)


## Colliders: the two hull parts' convex hulls (made at import from the model's *_Col-convcolonly meshes; built here from
## the meshes only when the model has none), capsules for the fallen tops and the keelstone; on the world's layer, wood.
func _colliders() -> void:
	var body := StaticBody3D.new()
	body.name = "WreckBody"
	body.set_meta(&"surface", "wood")
	wreck.add_child(body)
	var to_local := wreck.global_transform.affine_inverse()
	var made := wreck.find_children("*", "StaticBody3D", true, false).filter(func(b: Node) -> bool: return b != body)
	for b: Node in made:
		b.set_meta(&"surface", "wood")
	for nm: String in ([] if not made.is_empty() else ["Hull_Fore", "Hull_Aft"]):
		var mi := _wreck_node(nm) as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var cs := CollisionShape3D.new()
		cs.name = nm
		var inner := Transform3D.IDENTITY
		var shape: Shape3D = mi.mesh.create_convex_shape(true, true)
		if shape == null or (shape is ConvexPolygonShape3D and (shape as ConvexPolygonShape3D).points.size() < 4):
			var bx := BoxShape3D.new()          # (a mesh that gives no points: a box round it)
			bx.size = mi.get_aabb().size
			shape = bx
			inner.origin = mi.get_aabb().get_center()
		cs.shape = shape
		body.add_child(cs)
		cs.transform = to_local * mi.global_transform * inner
	for k: String in ["Fore", "Main"]:
		var a := _wreck_node("Fallen%s_A" % k)
		var b := _wreck_node("Fallen%s_B" % k)
		if a and b:
			body.add_child(_capsule("Fallen" + k, a.position, b.position, 0.35))
	var kg := _wreck_node("KeelGlow")
	if kg:
		var ax := Basis(Vector3.UP, deg_to_rad(KEEL_YAW_DEG)) * Vector3(0, 0, 1)
		body.add_child(_capsule("Keelstone", kg.position - ax * 1.4, kg.position + ax * 1.4, 0.8))


static func _capsule(nm: String, a: Vector3, b: Vector3, r: float) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.name = nm
	var c := CapsuleShape3D.new()
	c.radius = r
	c.height = a.distance_to(b) + 2.0 * r
	cs.shape = c
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	cs.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	return cs


## A body dressed in `spec` ([preset, faction]), its own two clips in, no hit parts (nobody here is a target).
func _body(nm: String, spec: Array, xf: Transform3D) -> NpcBody:
	var pre: Variant = _pre.get(nm)
	_pre.erase(nm)
	if pre is NpcBody and is_instance_valid(pre):
		var pb := pre as NpcBody
		pb.global_transform = xf
		pb.visible = true
		pb.animate = true                             # (woken from its rest: it steps its clips and drives its bones again)
		pb.set_process(true)
		return pb
	return _new_body(nm, spec, xf)


func _new_body(nm: String, spec: Array, xf: Transform3D) -> NpcBody:
	return _make_body(self, nm, spec, xf)


## One of the wreck's people (PEOPLE: Rook, Ithel) built ahead under `parent` at `at`, hidden and at rest (NpcBody.rest:
## no clip stepped, no bone driven, its skeleton by hand: it costs nothing a frame), for a fall to take (begin_from's
## opts people).
static func prebuild_body(parent: Node, nm: String, at: Vector3) -> NpcBody:
	var b := _make_body(parent, nm, ROOK_LOOK if nm == "Rook" else ITHEL_LOOK, Transform3D(Basis.IDENTITY, at))
	b.visible = false
	b.rest()
	return b


static func _make_body(parent: Node, nm: String, spec: Array, xf: Transform3D) -> NpcBody:
	var b := NpcBody.new()
	b.name = nm
	parent.add_child(b)
	b.global_transform = xf
	var preset := String(spec[0]) if NpcFactions.usable_preset(String(spec[0])) else "palatine_m_a"
	b.build(StoryWalker.person_look(preset, String(spec[1])))
	b.drop_parts()
	if b.ap != null:
		b.ap.add_animation_library(CLIP_LIB, _clips())
	return b


static var _clip_lib: AnimationLibrary


static func _clips() -> AnimationLibrary:
	if _clip_lib != null:
		return _clip_lib
	_clip_lib = AnimationLibrary.new()
	var src := load(NpcBody.ACTOR_LIB) as AnimationLibrary
	for e: Array in [["sit", CLIP_SIT, true], ["pinned", CLIP_PINNED, false]]:
		if src == null or not src.has_animation(String(e[1])):
			continue
		var a := (src.get_animation(String(e[1])) as Animation).duplicate() as Animation
		a.loop_mode = Animation.LOOP_LINEAR if bool(e[2]) else Animation.LOOP_NONE
		_clip_lib.add_animation(String(e[0]), a)
	return _clip_lib


func _play(b: NpcBody, key: String, at_s := 0.0, rate := 1.0) -> void:
	if b == null or b.ap == null or not b.ap.has_animation(CLIP_LIB + "/" + key):
		return
	b.clip = ""
	b.ap.speed_scale = rate
	b.ap.play(CLIP_LIB + "/" + key, 0.0)
	b.ap.seek(at_s, true)
	b.ap.advance(0.0)


## Rook: on his back where the stranger lies (the Pinned empty, on the ground there), lying along the hull with his head
## toward the bow; resting (nothing runs) with no shadow.
func _make_rook() -> void:
	var pin := _wreck_node("Pinned")
	var p := pin.global_position if pin else frame * Vector3(6.3, 0.0, 5.0)
	p.y = FrontierTerrain.height_at(p.x, p.z)
	_rook = _body("Rook", ROOK_LOOK, Transform3D(frame.basis, p))
	_play(_rook, "pinned", 0.0, 0.0)
	# lie him along the hull, head to the bow
	var up := frame.basis.y
	var d := _rook.bone_pos("heada") - _rook.bone_pos("pelvis")
	d -= up * d.dot(up)
	var want := -frame.basis.z
	if d.length() > 0.2:
		var ang := d.normalized().signed_angle_to(want, up)
		_rook.global_basis = Basis(up, ang) * _rook.global_basis
		_rook.ap.advance(0.0)
	for g in _rook.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rook.rest.call_deferred()


## The spar across his thighs: one end on the ground out from the hull, over him, its far end up off the ground; frozen
## until the first lock lifts it (lift_spar).
func _make_spar() -> void:
	var mi := _wreck_node("Spar") as MeshInstance3D
	var up := frame.basis.y
	var pelvis := _rook.bone_pos("pelvis") if _rook else frame * Vector3(6.3, 0.2, 5.0)
	var head := _rook.bone_pos("heada") if _rook else pelvis - frame.basis.z
	var feet := pelvis - head
	feet -= up * feet.dot(up)
	feet = feet.normalized() if feet.length() > 0.1 else frame.basis.z
	var across := up.cross(feet).normalized()
	if across.dot(frame.basis.x) < 0.0:
		across = -across                      # (its grounded end out from the hull)
	var over := pelvis + feet * 0.32
	over.y = FrontierTerrain.height_at(over.x, over.z) + 0.33
	var end_a := over + across * 1.9
	end_a.y = FrontierTerrain.height_at(end_a.x, end_a.z) + SPAR_R * 0.9
	var dir := (over - end_a).normalized()
	var centre := end_a + dir * (SPAR_LEN * 0.5)
	var y := (up - dir * up.dot(dir)).normalized()
	_spar = RigidBody3D.new()
	_spar.name = "Spar"
	_spar.mass = SPAR_MASS
	_spar.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	_spar.freeze = true
	_spar.add_to_group(SWAY_TARGETS)
	_spar.set_meta(&"sway_move", SWAY_MOVE)
	_spar.set_meta(&"sway_cast", lift_spar)
	_spar.set_meta(&"pins", _rook)
	_spar.set_meta(&"surface", "wood")
	add_child(_spar)
	_spar.global_transform = Transform3D(Basis(dir, y, dir.cross(y)), centre)
	if mi != null:
		mi.reparent(_spar, false)
		mi.transform = Transform3D.IDENTITY
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var cy := CylinderShape3D.new()
	cy.radius = SPAR_R
	cy.height = SPAR_LEN
	cs.shape = cy
	cs.rotation = Vector3(0.0, 0.0, PI * 0.5)    # (the cylinder's Y along the spar's X)
	_spar.add_child(cs)


func _free_stranger() -> void:
	if _rook == null or _freed:
		return
	_freed = true
	_rook.animate = true
	_rook.set_process(true)
	_play(_rook, "pinned", 0.0, 1.0)
	var length := _rook.ap.current_animation_length if _rook.ap else 0.0
	get_tree().create_timer(maxf(length - 0.15, 0.1)).timeout.connect(func() -> void:
		if is_instance_valid(_rook):
			_rook.play("idle", 0.3)
		stranger_freed.emit())


## Ithel: sat against the hull bottom, leaned back along it (the Ithel empty's frame; on the ground there), slow in the
## floor-sit loop; his StoryContact (its lantern hidden: the keel's light is his).
func _make_ithel() -> void:
	var seat := _wreck_node("Ithel")
	var xf := seat.global_transform if seat else Transform3D(frame.basis, frame * Vector3(1.5, 0.0, -1.0))
	xf.basis = xf.basis.orthonormalized()
	xf.origin.y = FrontierTerrain.height_at(xf.origin.x, xf.origin.z)
	_ithel = _body("Ithel", ITHEL_LOOK, xf)
	_play(_ithel, "sit", 0.7, 0.45)
	contact = StoryContact.at_person(_ithel, ITHEL_CONVO, ITHEL_NAME, "ithel")
	var lantern := contact.get_node_or_null("Lantern") as Node3D
	if lantern:
		lantern.visible = false
	var tag := contact.get_node_or_null("NameTag") as Node3D
	if tag:
		tag.position.y = 1.35


## The keelstone's and the fans' glow (EtheriumGlow), their own copies to breathe.
func _glow_materials() -> void:
	_glow_mats.clear()
	for c in wreck.find_children("*", "MeshInstance3D", true, false):
		var m := c as MeshInstance3D
		if m.mesh == null:
			continue
		for si in m.mesh.get_surface_count():
			var mat := m.get_active_material(si) as StandardMaterial3D
			if mat and String(mat.resource_name).begins_with("EtheriumGlow"):
				mat = mat.duplicate() as StandardMaterial3D
				m.set_surface_override_material(si, mat)
				_glow_mats.append(mat)


## One fire over each Burn_* part (its box cut down to FIRE_MAX_BOX), the timber ones charred with live embers; a column.
func _make_fires(level: float) -> void:
	burn = level
	_burn_start = level
	_burn_t = 0.0
	if level <= 0.0:
		return
	var top := frame.origin
	for c in wreck.find_children("Burn_*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb()
		var size := box.size.min(Vector3.ONE * FIRE_MAX_BOX)
		box = AABB(box.get_center() - size * 0.5, size)
		var fx := FireFx.make(self, box, quality)
		fx.name = "Fire_" + String(mi.name)
		fx.strength = level
		fires.append(fx)
		top.y = maxf(top.y, box.end.y)
		if String(mi.name) in TIMBER_BURNS:
			FireRuin.char_geometry([mi], INF, level)
	column = FireFx.column(self, Vector3(frame.origin.x, top.y + 1.0, frame.origin.z), quality)
	column.amount_ratio = clampf(0.3 + 0.6 * level, 0.3, 1.0)


## A thin gold smoke off the keelstone's crack: the "bright, sweet smoke" (docs 7.1) the player breathes.
func _make_keel_smoke() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "KeelSmoke"
	p.amount = 14
	p.lifetime = 6.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	p.visibility_aabb = AABB(Vector3(-8, -1, -8), Vector3(16, 20, 16))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, 0.15, 0)
	pm.damping_min = 0.05
	pm.damping_max = 0.15
	pm.scale_min = 0.8
	pm.scale_max = 1.4
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.scale_curve = FireFx._curve_tex([Vector2(0, 0.4), Vector2(1, 2.6)], 3.0)
	pm.color_ramp = FireFx._ramp_tex([[0.0, Color(1.0, 0.85, 0.5, 0.0)], [0.15, Color(1.0, 0.8, 0.45, 0.35)],
			[0.7, Color(0.9, 0.75, 0.5, 0.15)], [1.0, Color(0.8, 0.7, 0.5, 0.0)]])
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Fx._puff()
	m.disable_receive_shadows = true
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	p.global_position = keel_point() + Vector3.UP * 0.6
	return p


## The crash: the felling's sounds deep and loud, a far boom, the snapped trees cracking after; dust along the hull; the
## light's flash.
func _crash() -> void:
	var p := frame.origin + Vector3.UP
	for e: Array in [[&"gather_rec_tree_land", 18.0, 0.42], [&"gather_rec_tree_crack", 14.0, 0.55],
			[&"musket_tail_fort", 10.0, 0.45]]:
		if Sfx.has(e[0]):
			Sfx.play_3d(e[0], p, float(e[1]), float(e[2]))
	if Sfx.has(&"gather_rec_tree_crack"):
		for k in mini(int(cleared["snapped"]), 5):
			Sfx.play_3d(&"gather_rec_tree_crack", frame * Vector3(0.0, 2.0, SWATH.position.y + 8.0 * k), 6.0, 0.8,
					{"delay": 0.15 + 0.18 * k})
	for z: float in [-12.0, -2.0, 8.0]:
		GatherFx.fall_dust(self, frame * Vector3(0.0, 0.0, z), 7.0)
	_flash = 1.0


func _wreck_frame(delta: float) -> void:
	# the one light: flickering with the fire, a flash at the crash
	_flash = move_toward(_flash, 0.0, delta / 1.4)
	if light != null:
		var n1 := _noise.get_noise_1d(_clock * 6.0)
		var n2 := _noise.get_noise_1d(_clock * 17.0 + 40.0)
		var flick := 0.86 + 0.1 * n1 + 0.04 * n2
		light.light_energy = KEEL_LIGHT_ENERGY * (0.6 + 0.4 * burn) * flick + 26.0 * _flash * _flash
		light.omni_range = KEEL_LIGHT_RANGE * (1.0 + 1.5 * _flash)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK_S
	_far_glow_tick()
	# the fire dying down
	_burn_t += TICK_S
	var f := 1.0
	if _burn_t > BURN_HOLD_S:
		f = lerpf(1.0, SMOULDER, clampf((_burn_t - BURN_HOLD_S) / BURN_FADE_S, 0.0, 1.0))
	burn = _burn_start * f
	var cam := _camera_pos()
	var fs := FireSpread.find(get_tree())
	var wind := fs.wind_now() if fs else Vector3(0.25, 0.0, 0.1)
	for fx in fires:
		if is_instance_valid(fx):
			fx.strength = burn
			fx.set_wind(wind)
			fx.set_distance(cam.distance_to(fx.global_position))
	if column != null and is_instance_valid(column):
		column.amount_ratio = clampf(0.3 + 0.6 * burn, 0.2, 1.0)
		FireFx.set_column_wind(column, wind)
	# the flames' and the charred embers' brightness for the eye (as FireSpread sets them: the same shared materials)
	var dim := Fx._fire_dim(self)
	FireFx.flame_material().set_shader_parameter(&"intensity", 2.0 * dim)
	FireRuin.material().set_shader_parameter(&"dim", dim)
	# the keelstone breathes, brighter in the dark
	var night := 1.0 if dim < 0.5 else 0.0
	var e := (2.6 + 0.6 * sin(_clock * 1.1)) * lerpf(1.0, 1.6, night)
	for m in _glow_mats:
		m.emission_energy_multiplier = e


## The fire's glow over the treetops for an eye far off: faded in past FAR_GLOW_M.x, sized for the eye, with the fire.
func _far_glow_tick() -> void:
	if _far_glow == null or not is_instance_valid(_far_glow):
		return
	var dist := _camera_pos().distance_to(_far_glow.global_position)
	var a := smoothstep(FAR_GLOW_M.x, FAR_GLOW_M.y, dist) * burn
	_far_glow.visible = a > 0.01
	if not _far_glow.visible:
		return
	var size := clampf(dist * FAR_GLOW_SIZE, 30.0, 120.0)
	_far_glow.scale = Vector3(size * 1.8, size, size)
	var flick := 0.9 + 0.1 * _noise.get_noise_1d(_clock * 3.0)
	var gc := Color(1.0, 0.42, 0.14) * (1.5 * Fx._fire_dim(self) * a * flick)
	_far_mat.albedo_color = Color(gc.r, gc.g, gc.b, 0.6)


func _camera_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam else frame.origin
