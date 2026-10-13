class_name CameraShake
extends Node
## A shake of the view (user 2026-09-27: "if the mammoth kneels i want the screen to shake for the players within the
## area"). quake() shakes the view of every player within `radius` of a place: in full within a third of it, fading to
## nothing at its edge. The shake is the camera's own screen offsets (h_offset, v_offset): the view jolts, the camera
## does not turn and the aim does not move. A trauma (0..1) that runs down over the shake's seconds, the jolt its square
## (hard at the start, settling), from smooth noise. One CameraShake under a player's camera, made when first needed.
## ROUND 4 (IMPACT; the owner's "camera kick" for the ring's hits): jolt(amount, secs, dir) on the same offset path: the view
## knocked `amount` m along `dir` (screen x right, y up) at once, springing back in a few damped swings over `secs`. Never a
## turn: the camera's basis and the aim (FrontierPlayer.get_aim_point: the camera node's own position and basis) are the
## same through it, bit for bit (tests/ring/test_ring_feel.gd). For a hit nothing calls kick() or sustain() (they turn the
## camera, and so the aim; spec §3). The offsets this writes are its own share only (taken back out each frame), so an
## offset someone else gives the camera is kept. The quake's noise is seeded from the camera's id, not the global RNG.

const MAX_OFFSET := 0.22         ## m of screen offset at full trauma
const FREQ := 14.0               ## how fast it jolts (noise per second)

var camera: Camera3D
var trauma := 0.0
## The tremble (user 2026-10-01: "the camera shake should be like the bow and arrow hold", Bow.tremble_offset()): the view turned
## by a fine fast shake of waves, not jolted aside. A kick (kick(): a shot) starts at its full and settles over its seconds (its
## square); a steady one (sustain(): the sprint) is held while it is asked for, eased in and out. Turns the camera itself (pitch,
## yaw), as the bow's turns the view.
var _sustain := 0.0
var _sustain_want := 0.0
var _sustain_hold := 0.0         ## s the last request holds (it comes on physics ticks, the shake runs on frames)
var _kick := 0.0
var _kick_fall := 1.0
var _tt := 0.0
const KICK_DEG := 1.6            ## the turn at a full kick (the bow's held tremble is 0.9)
const SUSTAIN_DEG := 0.35        ## at a full steady tremble
const SUSTAIN_EASE_S := 0.35
var _fall := 1.0
var _t := 0.0
var _noise := FastNoiseLite.new()
## Round 4: the jolt now (m at its start, s long, its way on the screen, s since it began; JOLT_FREQ swings a second), and the
## offsets this node put on the camera last frame (taken back before the next are put on).
var jolt_amount := 0.0
var _jolt_secs := 0.25
var _jolt_dir := Vector2(0.0, -1.0)
var _jolt_t := 0.0
var _applied := Vector2.ZERO
const JOLT_FREQ := 9.0


## Shakes the view of each player within `radius` m of `at`, `strength` (0..1) close by, over `secs` seconds.
static func quake(tree: SceneTree, at: Vector3, strength: float, radius: float, secs := 1.0) -> void:
	for n in tree.get_nodes_in_group(&"player"):
		var p := n as Node3D
		if p == null:
			continue
		var cam := p.get("camera") as Camera3D
		var d := p.global_position.distance_to(at)
		if cam == null or d >= radius:
			continue
		of(cam).add(strength * (1.0 - smoothstep(radius / 3.0, radius, d)), secs)


## The shake of `cam` (made on first use).
static func of(cam: Camera3D) -> CameraShake:
	var s := cam.get_node_or_null(^"CameraShake") as CameraShake
	if s == null:
		s = CameraShake.new()
		s.name = "CameraShake"
		s.camera = cam
		cam.add_child(s)
	return s


## A tremble kick of `amount` (0..1, the stronger of it and what is left of the last), settling over `secs`.
func kick(amount: float, secs: float) -> void:
	if amount <= _kick:
		return
	_kick = clampf(amount, 0.0, 1.0)
	_kick_fall = _kick / maxf(secs, 0.05)


## A steady tremble of `amount` (0..1) for as long as it is asked for each frame (0: none); it eases in and out.
func sustain(amount: float) -> void:
	_sustain_want = clampf(amount, 0.0, 1.0)
	_sustain_hold = 0.1


## Round 4: the view knocked `amount` m along `dir` (screen: x right, y up), springing back over `secs` (the stronger of it and
## what is left of the last). Offsets only: never a turn.
func jolt(amount: float, secs: float, dir := Vector2(0.0, -1.0)) -> void:
	if amount <= jolt_left():
		return
	jolt_amount = amount
	_jolt_secs = maxf(secs, 0.05)
	_jolt_dir = dir.normalized() if dir.length_squared() > 1e-6 else Vector2(0.0, -1.0)
	_jolt_t = 0.0


## What is left of the jolt now (m).
func jolt_left() -> float:
	if jolt_amount <= 0.0 or _jolt_t >= _jolt_secs:
		return 0.0
	var k := 1.0 - _jolt_t / _jolt_secs
	return jolt_amount * k * k


## The jolt's offset now (m, screen x / y).
func jolt_offset() -> Vector2:
	if jolt_amount <= 0.0 or _jolt_t >= _jolt_secs:
		return Vector2.ZERO
	var k := 1.0 - _jolt_t / _jolt_secs
	# (a knock at once, then damped swings back: cos, the envelope squared)
	return _jolt_dir * jolt_amount * k * k * cos(TAU * JOLT_FREQ * _jolt_t)


## A jolt of `amount` (0..1; the stronger of it and what is left of the last), running down over `secs`.
func add(amount: float, secs: float) -> void:
	if amount <= trauma:
		return
	trauma = clampf(amount, 0.0, 1.0)
	_fall = trauma / maxf(secs, 0.05)


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	# (round 4: from the camera's id, never the global RNG: a test's or a match's dice stay its own)
	_noise.seed = int((camera.get_instance_id() if camera != null else get_instance_id()) % 2147483647)


func _process(dt: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	_tremble(dt)
	var off := Vector2.ZERO
	if trauma > 0.0:
		_t += dt
		trauma = maxf(trauma - _fall * dt, 0.0)
		var a := trauma * trauma * MAX_OFFSET
		off = Vector2(a * _noise.get_noise_2d(_t * FREQ, 0.0) * 1.4, a * _noise.get_noise_2d(0.0, 50.0 + _t * FREQ) * 1.4)
	if jolt_amount > 0.0:
		_jolt_t += dt
		off += jolt_offset()
		if _jolt_t >= _jolt_secs:
			jolt_amount = 0.0
	# (only this node's share: last frame's taken back, this frame's put on; an offset of someone else's is kept)
	if off != _applied:
		camera.h_offset = camera.h_offset - _applied.x + off.x
		camera.v_offset = camera.v_offset - _applied.y + off.y
		_applied = off


## The tremble's turn of the camera (the bow's waves: Bow.tremble_offset()).
func _tremble(dt: float) -> void:
	_sustain_hold -= dt
	if _sustain_hold <= 0.0:
		_sustain_want = 0.0          # (held only while it is asked for)
	_sustain = move_toward(_sustain, _sustain_want, dt / SUSTAIN_EASE_S)
	_kick = maxf(_kick - _kick_fall * dt, 0.0)
	if _kick <= 0.0 and _sustain <= 0.0:
		if camera.rotation.x != 0.0 or camera.rotation.y != 0.0:
			camera.rotation.x = 0.0
			camera.rotation.y = 0.0
		return
	_tt += dt
	var k := deg_to_rad(KICK_DEG) * _kick * _kick
	var s2 := deg_to_rad(SUSTAIN_DEG) * _sustain
	# the kick on the bow's fast waves; the steady one slower (footfalls, not a held bowstring)
	camera.rotation.x = k * (sin(_tt * 23.0) * 0.6 + sin(_tt * 37.0) * 0.4) + s2 * (sin(_tt * 11.0) * 0.6 + sin(_tt * 17.0) * 0.4)
	camera.rotation.y = k * (sin(_tt * 19.0 + 1.3) * 0.6 + sin(_tt * 31.0) * 0.4) + s2 * (sin(_tt * 9.0 + 1.3) * 0.6 + sin(_tt * 15.0) * 0.4)
